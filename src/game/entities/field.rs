// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying LICENSE file for details.

use crates::abagames_util::{self, Pool, Rand, TargetFormat};
use crates::cgmath::{Angle, ElementWise, Rad, Vector2, Vector3};
use crates::gfx;
use crates::gfx::traits::FactoryExt;
use crates::itertools::Itertools;
use crates::rayon::prelude::*;

use game::entities::enemy::Enemy;
use game::entities::ship::Ship;
use game::entities::stage::Stage;
use game::render::{Brightness, ScreenTransform};
use game::render::{EncoderContext, RenderContext};
use game::state::GameStateContext;

use std::f32;

const BLOCK_SIZE_X: usize = 20;
const BLOCK_SIZE_Y: usize = 64;
const BLOCK_SIZE_X_F32: f32 = BLOCK_SIZE_X as f32;
const BLOCK_SIZE_Y_F32: f32 = BLOCK_SIZE_Y as f32;
const NEXT_BLOCK_AREA_SIZE: usize = 16;
pub const NEXT_BLOCK_AREA_SIZE_F32: f32 = NEXT_BLOCK_AREA_SIZE as f32;

pub const FIELD_SIZE: Vector2<f32> = Vector2::new(
    ((SCREEN_BLOCK_SIZE_X / 2) as f32) * 0.9,
    ((SCREEN_BLOCK_SIZE_Y / 2) as f32) * 0.8,
);
pub const FIELD_OUTER_SIZE: Vector2<f32> = Vector2::new(
    (SCREEN_BLOCK_SIZE_X / 2) as f32,
    (SCREEN_BLOCK_SIZE_Y / 2) as f32,
);

const SIDEWALL_X1: f32 = 18.;
const SIDEWALL_X2: f32 = 9.3;
const SIDEWALL_Y: f32 = 15.;

const TIME_COLOR_SIZE: usize = 5;
const TIME_CHANGE_RATIO: f32 = 0.00033;

const SCREEN_BLOCK_SIZE_X: usize = 20;
const SCREEN_BLOCK_SIZE_Y: usize = 24;
const BLOCK_WIDTH: f32 = 1.;

const MAX_PLATFORMS: usize = SCREEN_BLOCK_SIZE_X * NEXT_BLOCK_AREA_SIZE;

const PANEL_WIDTH: f32 = 1.8;
const PANEL_HEIGHT_BASE: f32 = 0.66;

const BASE_COLOR_TIME: [[Vector3<f32>; 6]; TIME_COLOR_SIZE] = [
    [
        Vector3::new(0.15, 0.15, 0.3),
        Vector3::new(0.25, 0.25, 0.5),
        Vector3::new(0.35, 0.35, 0.45),
        Vector3::new(0.6, 0.7, 0.35),
        Vector3::new(0.45, 0.8, 0.3),
        Vector3::new(0.2, 0.6, 0.1),
    ],
    [
        Vector3::new(0.1, 0.1, 0.3),
        Vector3::new(0.2, 0.2, 0.5),
        Vector3::new(0.3, 0.3, 0.4),
        Vector3::new(0.5, 0.65, 0.35),
        Vector3::new(0.4, 0.7, 0.3),
        Vector3::new(0.1, 0.5, 0.1),
    ],
    [
        Vector3::new(0.1, 0.1, 0.3),
        Vector3::new(0.2, 0.2, 0.5),
        Vector3::new(0.3, 0.3, 0.4),
        Vector3::new(0.5, 0.65, 0.35),
        Vector3::new(0.4, 0.7, 0.3),
        Vector3::new(0.1, 0.5, 0.1),
    ],
    [
        Vector3::new(0.2, 0.15, 0.25),
        Vector3::new(0.35, 0.2, 0.4),
        Vector3::new(0.5, 0.35, 0.45),
        Vector3::new(0.7, 0.6, 0.3),
        Vector3::new(0.6, 0.65, 0.25),
        Vector3::new(0.2, 0.45, 0.1),
    ],
    [
        Vector3::new(0., 0., 0.1),
        Vector3::new(0.1, 0.1, 0.3),
        Vector3::new(0.2, 0.2, 0.3),
        Vector3::new(0.2, 0.3, 0.15),
        Vector3::new(0.2, 0.2, 0.1),
        Vector3::new(0., 0.15, 0.),
    ],
];

const ANGLE_BLOCK_OFFSET: [[i32; 2]; 4] = [[0, -1], [1, 0], [0, 1], [-1, 0]];

#[derive(Clone, Copy)]
struct Panel {
    pub position: Vector3<f32>,
    pub color: Vector3<f32>,
    pub color_index: usize,
}

impl Panel {
    const fn new() -> Self {
        Panel {
            position: Vector3::new(0., 0., 0.),
            color: Vector3::new(0., 0., 0.),
            color_index: 0,
        }
    }
}

pub enum FieldMode {
    Demo,
    Live,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum Block {
    DeepWater,
    Water,
    Shore,
    Beach,
    Inland,
    DeepInland,
}

impl Block {
    fn factor(&self) -> f32 {
        match *self {
            Block::DeepWater => -3.,
            Block::Water => -2.,
            Block::Shore => -1.,
            Block::Beach => 0.,
            Block::Inland => 1.,
            Block::DeepInland => 2.,
        }
    }

    fn color_index(&self) -> usize {
        match *self {
            Block::DeepWater => 0,
            Block::Water => 1,
            Block::Shore => 2,
            Block::Beach => 3,
            Block::Inland => 4,
            Block::DeepInland => 5,
        }
    }

    pub fn is_dry(&self) -> bool {
        match *self {
            Block::DeepWater |
            Block::Water |
            Block::Shore |
            Block::Beach => false,
            Block::Inland |
            Block::DeepInland => true,
        }
    }

    pub fn is_land(&self) -> bool {
        match *self {
            Block::DeepWater |
            Block::Water |
            Block::Shore => false,
            Block::Beach |
            Block::Inland |
            Block::DeepInland => true,
        }
    }

    fn transform_for_count(&mut self, count: usize) -> Self {
        *self = match (self.is_land(), count) {
            (true, 0) => Block::Water,
            (true, 1) |
            (true, 2) |
            (true, 3) => Block::Beach,
            (true, 4) => Block::DeepInland,
            (false, 0) => Block::DeepWater,
            (false, 1) |
            (false, 2) |
            (false, 3) |
            (false, 4) => Block::Shore,
            _ => unreachable!(),
        };

        *self
    }
}

#[derive(Debug, Clone, Copy)]
enum GroundType {
    Zero,
    One,
    Two,
}

impl From<u32> for GroundType {
    fn from(i: u32) -> Self {
        match i {
            0 => GroundType::Zero,
            1 => GroundType::One,
            2 => GroundType::Two,
            _ => unreachable!(),
        }
    }
}

fn between<T>(low: T, expect: T, high: T) -> bool
where
    T: PartialOrd,
{
    low <= expect && expect < high
}

#[derive(Debug, Clone, Copy)]
pub struct Platform {
    position: Vector2<usize>,
    angle: Rad<f32>,
    in_use: bool,
}

impl Platform {
    const fn new() -> Self {
        Platform {
            position: Vector2::new(0, 0),
            angle: Rad(0.),
            in_use: false,
        }
    }

    fn init(&mut self, pos: Vector2<usize>, angle: Rad<f32>) {
        self.position = pos;
        self.angle = angle;
        self.in_use = false;
    }

    pub fn in_use(&self) -> bool {
        self.in_use
    }

    pub fn too_close(&self, other: Vector2<usize>) -> bool {
        if self.in_use {
            let x = if self.position.x < other.x {
                other.x - self.position.x
            } else {
                self.position.x - other.x
            };
            let y = if self.position.y < other.y {
                other.y - self.position.y
            } else {
                self.position.y - other.y
            };
            if x <= 1 && y <= 1 {
                true
            } else {
                false
            }
        } else {
            false
        }
    }

    pub fn peek(&self) -> (Vector2<usize>, Rad<f32>) {
        (self.position, self.angle)
    }

    pub fn spawned(&mut self) {
        self.in_use = true;
    }
}

pub struct Field {
    color_step: f32,
    screen_y: f32,
    block_count: f32,
    next_block_y: usize,
    last_scroll_y: f32,

    blocks: [[Block; BLOCK_SIZE_Y]; BLOCK_SIZE_X],
    panels: [[Panel; BLOCK_SIZE_Y]; BLOCK_SIZE_X],

    platforms: [Platform; MAX_PLATFORMS],
    num_platforms: usize,
}

impl Field {
    pub const fn new() -> Self {
        Field {
            color_step: 0.,
            screen_y: 0.,
            block_count: 0.,
            next_block_y: 0,
            last_scroll_y: 0.,

            blocks: [[Block::DeepWater; BLOCK_SIZE_Y]; BLOCK_SIZE_X],
            panels: [[Panel::new(); BLOCK_SIZE_Y]; BLOCK_SIZE_X],

            platforms: [Platform::new(); MAX_PLATFORMS],
            num_platforms: 0,
        }
    }

    pub fn init(&mut self, rand: &mut Rand) {
        self.screen_y = NEXT_BLOCK_AREA_SIZE as f32;
        self.block_count = 0.;
        self.next_block_y = 0;

        (0..BLOCK_SIZE_Y)
            .cartesian_product(0..BLOCK_SIZE_X)
            .foreach(|(y, x)| {
                self.blocks[x][y] = Block::DeepWater;

                self.create_panel(x, y, rand);
            });

        self.color_step = rand.next_float(TIME_COLOR_SIZE as f32);
    }

    fn create_panel(&mut self, x: usize, y: usize, rand: &mut Rand) {
        let block = self.blocks[x][y];
        let panel = &mut self.panels[x][y];

        panel.position = Vector3::new(
            rand.next_float(1.) - 0.75,
            rand.next_float(1.) - 0.75,
            block.factor() * PANEL_HEIGHT_BASE + rand.next_float(PANEL_HEIGHT_BASE),
        );
        panel.color = Vector3::new(
            1. + rand.next_float_signed(0.1),
            1. + rand.next_float_signed(0.1),
            1. + rand.next_float_signed(0.1),
        ) * 0.33;
        panel.color_index = block.color_index();
    }

    pub fn block(&self, pos: Vector2<f32>) -> Block {
        let y = pos.y - self.screen_y.fract();
        let block_x =
            ((pos.x + (BLOCK_WIDTH * (SCREEN_BLOCK_SIZE_X as f32) / 2.)) / BLOCK_WIDTH) as i32;
        let block_y = (self.screen_y
            + (-y + (BLOCK_WIDTH * (SCREEN_BLOCK_SIZE_Y as f32) / 2.)) / BLOCK_WIDTH)
            as i32;

        if !between(0, block_x, BLOCK_SIZE_X as i32) {
            return Block::Shore;
        }

        let block_y = block_y
            + if block_y < 0 {
                BLOCK_SIZE_Y as i32
            } else if block_y >= (BLOCK_SIZE_Y as i32) {
                -(BLOCK_SIZE_Y as i32)
            } else {
                0
            };

        self.blocks[block_x as usize][block_y as usize]
    }

    pub fn screen_pos(&self, block_pos: Vector2<usize>) -> Vector2<f32> {
        let y = self.screen_y.fract();
        let block_y =
            abagames_util::wrap_dec_by(block_pos.y, BLOCK_SIZE_Y, self.screen_y.trunc() as usize);

        Vector2::new(
            (block_pos.x as f32) * BLOCK_WIDTH - BLOCK_WIDTH * ((SCREEN_BLOCK_SIZE_X / 2) as f32)
                + BLOCK_WIDTH / 2.,
            ((block_y as f32) - BLOCK_SIZE_Y_F32) * -BLOCK_WIDTH
                + BLOCK_WIDTH * ((SCREEN_BLOCK_SIZE_Y / 2) as f32)
                + y
                - BLOCK_WIDTH / 2.,
        )
    }

    pub fn is_in_field(&self, pos: Vector2<f32>) -> bool {
        abagames_util::contains(FIELD_SIZE, pos, 1.)
    }

    pub fn is_in_field_no_top(&self, pos: Vector2<f32>) -> bool {
        -FIELD_SIZE.x <= pos.x && pos.x <= FIELD_SIZE.x && -FIELD_SIZE.y <= pos.y
    }

    pub fn is_in_outer_field(&self, pos: Vector2<f32>) -> bool {
        abagames_util::contains(FIELD_OUTER_SIZE, pos, 1.)
    }

    pub fn is_in_outer_field_no_top(&self, pos: Vector2<f32>) -> bool {
        -FIELD_OUTER_SIZE.x <= pos.x && pos.x <= FIELD_OUTER_SIZE.x && -FIELD_OUTER_SIZE.y <= pos.y
    }

    pub fn is_in_outer_height_field(&self, pos: Vector2<f32>) -> bool {
        -FIELD_SIZE.x <= pos.x
            && pos.x <= FIELD_SIZE.x
            && -FIELD_OUTER_SIZE.y <= pos.y
            && pos.y <= FIELD_OUTER_SIZE.y
    }

    pub fn last_scroll_y(&self) -> f32 {
        self.last_scroll_y
    }

    pub fn step(&mut self) {
        self.color_step =
            abagames_util::wrap_inc_by(self.color_step, TIME_COLOR_SIZE as f32, TIME_CHANGE_RATIO);
    }

    pub fn scroll(
        &mut self,
        speed: f32,
        mode: FieldMode,
        stage: &mut Stage,
        enemies: &mut Pool<Enemy>,
        ship: &Ship,
        context: &mut GameStateContext,
        rand: &mut Rand,
    ) {
        self.last_scroll_y = speed;
        self.screen_y = abagames_util::wrap_dec_by(self.screen_y, BLOCK_SIZE_Y as f32, speed);
        self.block_count -= speed;
        if self.block_count < 0. {
            let density = stage.next_block_area(self, ship, enemies, context, rand);
            self.create_blocks(density as usize, rand);
            if let FieldMode::Live = mode {
                stage.add_batteries(self, enemies, rand);
            }
            self.next_block_area();
        }
    }

    pub fn platform(&self, i: usize) -> &Platform {
        assert!(i < self.num_platforms);
        &self.platforms[i]
    }

    pub fn platform_mut(&mut self, i: usize) -> &mut Platform {
        assert!(i < self.num_platforms);
        &mut self.platforms[i]
    }

    pub fn num_platforms(&self) -> usize {
        self.num_platforms
    }

    fn create_blocks(&mut self, density: usize, rand: &mut Rand) {
        let nby = self.next_block_y;
        let rows = (0..NEXT_BLOCK_AREA_SIZE)
            .map(|y| abagames_util::wrap_inc_by(y, BLOCK_SIZE_Y, nby))
            .collect::<Vec<_>>();
        let indices = rows
            .iter()
            .cloned()
            .cartesian_product(0..BLOCK_SIZE_X)
            .collect::<Vec<_>>();

        // Clear out the blocks in the current strip.
        indices
            .iter()
            .foreach(|&(y, x)| self.blocks[x][y] = Block::DeepWater);

        // Add ground.
        let ground_type = rand.next_int(3).into();
        (0..density).foreach(|_| self.add_ground(ground_type, rand));

        // Clear out the blocks at the edges of the current strip.
        indices
            .iter()
            .filter(|&&(y, _)| y == nby || y == nby + NEXT_BLOCK_AREA_SIZE - 1)
            .foreach(|&(y, x)| self.blocks[x][y] = Block::DeepWater);

        self.num_platforms = 0;
        rows.into_iter().foreach(|y| {
            for x in 0..BLOCK_SIZE_X {
                if self.blocks[x][y] == Block::Beach
                    && self.count_around_block(x, y, Block::Beach) <= 1
                {
                    self.blocks[x][y] = Block::Water;
                }
            }
            for x in (0..BLOCK_SIZE_X).rev() {
                if self.blocks[x][y] == Block::Beach
                    && self.count_around_block(x, y, Block::Beach) <= 1
                {
                    self.blocks[x][y] = Block::Water;
                }
            }

            (0..BLOCK_SIZE_X).foreach(|x| {
                let count = self.count_around_block(x, y, Block::Beach);
                let new_block = self.blocks[x][y].transform_for_count(count);

                // FIXME: Use (2..BLOCK_SIZE_X - 2).contains(x)
                if new_block == Block::Shore && between(2, x, BLOCK_SIZE_X - 2) {
                    let pos = Vector2::new(x, y);
                    if let Some(angle) = self.platform_angle(pos, rand) {
                        self.platforms[self.num_platforms].init(pos, angle);
                        self.num_platforms += 1;
                    }
                }
            })
        });

        indices.iter().foreach(|&(y, x)| {
            if self.blocks[x][y] == Block::DeepWater
                && self.count_around_block(x, y, Block::Shore) > 0
            {
                self.blocks[x][y] = Block::Water;
            } else if self.blocks[x][y] == Block::DeepInland
                && self.count_around_block(x, y, Block::Inland) > 0
            {
                self.blocks[x][y] = Block::Inland;
            }
            self.create_panel(x, y, rand);
        });
    }

    fn platform_angle(&mut self, pos: Vector2<usize>, rand: &mut Rand) -> Option<Rad<f32>> {
        let d = rand.next_int(4) as usize;
        (0..4)
            .into_iter()
            .filter_map(|i| {
                let new_i = abagames_util::wrap_inc_by(i, 4, d);
                let (ox, oy) = (
                    (pos.x as i32) + ANGLE_BLOCK_OFFSET[new_i][0],
                    (pos.y as i32) + ANGLE_BLOCK_OFFSET[new_i][1],
                );
                if self.check_block(ox, oy, Block::Shore).unwrap_or(true) {
                    let prev = abagames_util::wrap_dec(new_i, 4);
                    let next = abagames_util::wrap_inc(new_i, 4);

                    let prev_block_ok = self
                        .check_block(
                            ox + ANGLE_BLOCK_OFFSET[prev][0],
                            oy + ANGLE_BLOCK_OFFSET[prev][1],
                            Block::Shore,
                        )
                        .unwrap_or(true);
                    let next_block_ok = self
                        .check_block(
                            ox + ANGLE_BLOCK_OFFSET[next][0],
                            oy + ANGLE_BLOCK_OFFSET[next][1],
                            Block::Shore,
                        )
                        .unwrap_or(true);

                    let angle_offset = match (prev_block_ok, next_block_ok) {
                        (false, true) => -Rad::turn_div_4(),
                        (true, false) => Rad::turn_div_4(),
                        _ => Rad(0.),
                    };

                    Some((Rad::turn_div_2() * (d as f32) + angle_offset).normalize())
                } else {
                    None
                }
            })
            .next()
    }

    fn add_ground(&mut self, ground_type: GroundType, rand: &mut Rand) {
        let base_size = (BLOCK_SIZE_X_F32 * 0.4) as u32;
        let mut cx = match ground_type {
            GroundType::Zero => rand.next_int(base_size) + ((BLOCK_SIZE_X_F32 * 0.1) as u32),
            GroundType::One => rand.next_int(base_size) + ((BLOCK_SIZE_X_F32 * 0.5) as u32),
            GroundType::Two => {
                if rand.next_int(2) == 0 {
                    rand.next_int(base_size) + ((BLOCK_SIZE_X_F32 * 0.2) as u32)
                } else {
                    rand.next_int(base_size) + ((BLOCK_SIZE_X_F32 * 0.8) as u32)
                }
            },
        } as isize;
        let mut cy = (rand.next_int((NEXT_BLOCK_AREA_SIZE_F32 * 0.6) as u32)
            + ((NEXT_BLOCK_AREA_SIZE_F32 * 0.2) as u32)) as isize;
        cy += self.next_block_y as isize;

        let width = (rand.next_int((BLOCK_SIZE_X_F32 * 0.33) as u32)
            + ((BLOCK_SIZE_X_F32 * 0.33) as u32)) as isize;
        let height = (rand.next_int((NEXT_BLOCK_AREA_SIZE_F32 * 0.24) as u32)
            + ((NEXT_BLOCK_AREA_SIZE_F32 * 0.33) as u32)) as isize;

        cx -= width / 2;
        cy -= height / 2;

        let nby = self.next_block_y;
        (0..NEXT_BLOCK_AREA_SIZE)
            .map(|y| abagames_util::wrap_inc_by(y, BLOCK_SIZE_Y, nby))
            .cartesian_product(0..BLOCK_SIZE_X)
            .map(|(y, x)| (y as isize, x as isize))
            .filter(|&(y, x)| {
                [cx <= x, x < (cx + width), cy <= y, y < (cy + height)]
                    .into_iter()
                    .all(|&b| b)
            })
            .foreach(|(y, x)| {
                // Determine if there should be an island seeded at this location.
                let island_choice = {
                    let mut hw_rand = || (rand.next_float(0.2) + 0.2, rand.next_float(0.3) + 0.4);

                    [y - cy, cy + height - 1 - y]
                        .into_iter()
                        .cartesian_product([x - cx, cx + width - 1 - x].into_iter())
                        .map(|(&dy, &dx)| (dy as f32, dx as f32))
                        .map(|(dy, dx)| {
                            let (width_rand, height_rand) = hw_rand();
                            dx * width_rand + dy * height_rand
                        })
                        .fold(f32::MAX, f32::min)
                };

                if island_choice > 1. {
                    self.blocks[x as usize][y as usize] = Block::Beach;
                }
            });
    }

    fn count_around_block(&self, x: usize, y: usize, threshold: Block) -> usize {
        let x32 = x as i32;
        let y32 = y as i32;
        [
            self.check_block(x32, y32 - 1, threshold).unwrap_or(false),
            self.check_block(x32 + 1, y32, threshold).unwrap_or(false),
            self.check_block(x32, y32 + 1, threshold).unwrap_or(false),
            self.check_block(x32 - 1, y32, threshold).unwrap_or(false),
        ]
        .into_iter()
        .filter(|&&b| b)
        .count()
    }

    fn check_block(&self, x: i32, mut y: i32, threshold: Block) -> Option<bool> {
        // FIXME: Use !(0..BLOCK_SIZE_X).contains(x)
        if !between(0, x, BLOCK_SIZE_X as i32) {
            return None;
        }
        if y < 0 {
            y += BLOCK_SIZE_Y as i32
        } else if y >= BLOCK_SIZE_Y as i32 {
            y -= BLOCK_SIZE_Y as i32
        };
        Some(self.blocks[x as usize][y as usize] >= threshold)
    }

    fn next_block_area(&mut self) {
        self.block_count += NEXT_BLOCK_AREA_SIZE_F32;
        if self.next_block_y < NEXT_BLOCK_AREA_SIZE {
            self.next_block_y += BLOCK_SIZE_Y;
        }
        self.next_block_y -= NEXT_BLOCK_AREA_SIZE;
    }
}

gfx_defines! {
    vertex Position {
        pos: [f32; 2] = "pos",
    }

    vertex PerSidebar {
        flip: f32 = "flip",
    }

    vertex Difference {
        diff: [f32; 2] = "diff",
    }

    vertex PerPanel {
        pos: [f32; 3] = "pos",
        diff_factor: f32 = "diff_factor",
        offset: [f32; 2] = "offset",
        color: [f32; 3] = "color",
    }

    pipeline sidebar_pipe {
        vbuf: gfx::VertexBuffer<Position> = (),
        instances: gfx::InstanceBuffer<PerSidebar> = (),
        screen: gfx::ConstantBuffer<ScreenTransform> = "Screen",
        out_color: gfx::RenderTarget<TargetFormat> = "Target0",
    }

    pipeline panel_pipe {
        vbuf: gfx::VertexBuffer<Difference> = (),
        instances: gfx::InstanceBuffer<PerPanel> = (),
        screen: gfx::ConstantBuffer<ScreenTransform> = "Screen",
        brightness: gfx::ConstantBuffer<Brightness> = "Brightness",
        out_color: gfx::BlendTarget<TargetFormat> =
            ("Target0",
             gfx::state::ColorMask::all(),
             gfx::state::Blend::new(gfx::state::Equation::Add,
                                    gfx::state::Factor::ZeroPlus(gfx::state::BlendValue::SourceAlpha),
                                    gfx::state::Factor::One)),
    }
}

pub struct FieldDraw<R>
where
    R: gfx::Resources,
{
    sidebar_bundle: gfx::Bundle<R, sidebar_pipe::Data<R>>,
    panel_bundle: gfx::Bundle<R, panel_pipe::Data<R>>,
    panel_instances: gfx::handle::Buffer<R, PerPanel>,
}

impl<R> FieldDraw<R>
where
    R: gfx::Resources,
{
    pub fn new<F>(
        factory: &mut F,
        view: gfx::handle::RenderTargetView<R, TargetFormat>,
        context: &RenderContext<R>,
    ) -> Self
    where
        F: gfx::Factory<R>,
    {
        let sidebar_data = [
            Position { pos: [SIDEWALL_X1,  SIDEWALL_Y], },
            Position { pos: [SIDEWALL_X2,  SIDEWALL_Y], },
            Position { pos: [SIDEWALL_X2, -SIDEWALL_Y], },
            Position { pos: [SIDEWALL_X1, -SIDEWALL_Y], },
        ];

        let sidebar_vbuf = factory.create_vertex_buffer(&sidebar_data);
        let mut sidebar_slice =
            abagames_util::slice_for_fan::<R, F>(factory, sidebar_data.len() as u32);
        sidebar_slice.instances = Some((2, 0));

        let sidebar_instance_data = [
            PerSidebar { flip: 1., },
            PerSidebar { flip: -1., },
        ];

        let sidebar_instance_buffer = factory.create_vertex_buffer(&sidebar_instance_data);

        let sidebar_pso = factory
            .create_pipeline_simple(
                include_bytes!("shader/field_sidebar.glslv"),
                include_bytes!("shader/field_sidebar.glslf"),
                sidebar_pipe::new(),
            )
            .expect("failed to create the pipeline for field_sidebar");

        let sidebar_data = sidebar_pipe::Data {
            vbuf: sidebar_vbuf,
            instances: sidebar_instance_buffer.clone(),
            screen: context.perspective_screen_buffer.clone(),
            out_color: view.clone(),
        };

        let panel_data = [
            Difference { diff: [0.,  0.], },
            Difference { diff: [1.,  0.], },
            Difference { diff: [1., -1.], },
            Difference { diff: [0., -1.], },
        ];

        let panel_vbuf = factory.create_vertex_buffer(&panel_data);
        let mut panel_slice =
            abagames_util::slice_for_fan::<R, F>(factory, panel_data.len() as u32);
        let num_panel_instances = BLOCK_SIZE_Y * BLOCK_SIZE_X * 2;
        panel_slice.instances = Some((num_panel_instances as gfx::InstanceCount, 0));

        let panel_instances = factory
            .create_buffer(
                num_panel_instances,
                gfx::buffer::Role::Vertex,
                gfx::memory::Usage::Upload,
                gfx::memory::Bind::empty(),
            )
            .expect("failed to create the buffer for panels");

        let panel_pso = factory
            .create_pipeline_simple(
                include_bytes!("shader/field_panel.glslv"),
                include_bytes!("shader/field_panel.glslf"),
                panel_pipe::new(),
            )
            .expect("failed to create the pipeline for field_panel");

        let panel_data = panel_pipe::Data {
            vbuf: panel_vbuf,
            instances: panel_instances.clone(),
            screen: context.perspective_screen_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            out_color: view,
        };

        FieldDraw {
            sidebar_bundle: gfx::Bundle::new(sidebar_slice, sidebar_pso, sidebar_data),
            panel_bundle: gfx::Bundle::new(panel_slice, panel_pso, panel_data),
            panel_instances: panel_instances,
        }
    }

    pub fn prep_draw<F>(&mut self, factory: &mut F, field: &Field)
    where
        F: gfx::Factory<R>,
    {
        let color_index = field.color_step as usize;
        let next_color_index = abagames_util::wrap_inc(color_index, TIME_COLOR_SIZE);
        let blend = field.color_step.fract();

        let colors = BASE_COLOR_TIME[color_index]
            .par_iter()
            .zip(BASE_COLOR_TIME[next_color_index].par_iter())
            .map(|(color_0, color_1)| color_0 * (1. - blend) + color_1 * blend)
            .collect::<Vec<_>>();

        let screen_y_base = abagames_util::wrap_dec(field.screen_y as usize, BLOCK_SIZE_Y);
        let offset_x_base = -BLOCK_WIDTH * (SCREEN_BLOCK_SIZE_X as f32) / 2.;
        let offset_y_base =
            BLOCK_WIDTH * (SCREEN_BLOCK_SIZE_Y as f32) / 2. + BLOCK_WIDTH + field.screen_y.fract();

        // FIXME: Use inclusive syntax.
        let y_info = (0..SCREEN_BLOCK_SIZE_Y + NEXT_BLOCK_AREA_SIZE + 1).map(|block_y| {
            let new_block_y = abagames_util::wrap_inc_by(block_y, BLOCK_SIZE_Y, screen_y_base);

            (new_block_y, offset_y_base - (block_y as f32) * BLOCK_WIDTH)
        });

        let x_info = (0..SCREEN_BLOCK_SIZE_X)
            .map(|block_x| (block_x, offset_x_base + (block_x as f32) * BLOCK_WIDTH))
            .collect::<Vec<_>>();

        y_info
            .cartesian_product(x_info)
            .foreach(|((block_y, offset_y), (block_x, offset_x))| {
                let panel = &field.panels[block_x][block_y];

                let base_color = &colors[panel.color_index];
                let base_pos = &panel.position;
                let base_idx = 2 * (block_y * BLOCK_SIZE_X + block_x);

                let mut writer = factory
                    .write_mapping(&self.panel_instances)
                    .expect("could not get a writable mapping to the panel buffer");
                writer[base_idx] = PerPanel {
                    pos: [base_pos.x, -base_pos.y, base_pos.z],
                    diff_factor: PANEL_WIDTH,
                    offset: [offset_x, offset_y],
                    color: (base_color.mul_element_wise(panel.color) * 0.66).into(),
                };
                writer[base_idx + 1] = PerPanel {
                    pos: [base_pos.x, -base_pos.y, 0.],
                    diff_factor: BLOCK_WIDTH,
                    offset: [offset_x, offset_y],
                    color: (base_color * 0.33).into(),
                };
            });
    }

    pub fn draw_sidebars<C>(&self, context: &mut EncoderContext<R, C>)
    where
        C: gfx::CommandBuffer<R>,
    {
        self.sidebar_bundle.encode(context.encoder);
    }

    pub fn draw_panels<C>(&self, context: &mut EncoderContext<R, C>)
    where
        C: gfx::CommandBuffer<R>,
    {
        self.panel_bundle.encode(context.encoder);
    }
}
