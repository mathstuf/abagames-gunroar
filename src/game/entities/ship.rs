// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying LICENSE file for details.

use abagames_util::{self, TargetFormat};
use cgmath::{Angle, Deg, InnerSpace, Matrix4, MetricSpace, Rad, Vector2, Vector3};
use gfx;
use gfx::traits::FactoryExt;
use gfx::*;
use lazy_static::lazy_static;
use rayon::prelude::*;

use crate::game::entities::shapes::shield::ShieldDraw;
use crate::game::entities::shapes::{BaseShape, Shape, ShapeDraw, ShapeKind};
use crate::game::render::{Brightness, ScreenTransform};
use crate::game::render::{EncoderContext, RenderContext};

const MAX_BOATS: usize = 2;

const SCROLL_SPEED_BASE: f32 = 0.01;
const SCROLL_SPEED_MAX: f32 = 0.1;
const SCROLL_SPEED_Y: f32 = 2.5;

lazy_static! {
    static ref ROUNDTAIL_0: BaseShape = BaseShape::new(
        ShapeKind::ShipRoundTail,
        0.7,
        0.6,
        0.6,
        (0.5, 0.7, 0.5).into()
    );
    static ref ROUNDTAIL_1: BaseShape = BaseShape::new(
        ShapeKind::ShipRoundTail,
        0.7,
        0.6,
        0.6,
        (0.4, 0.3, 0.8).into()
    );
    static ref BRIDGE_0: BaseShape =
        BaseShape::new(ShapeKind::Bridge, 0.3, 0.6, 0.6, (0.3, 0.7, 0.3).into());
    static ref BRIDGE_1: BaseShape =
        BaseShape::new(ShapeKind::Bridge, 0.3, 0.6, 0.6, (0.2, 0.3, 0.6).into());
    static ref SHIP_BRIDGE: BaseShape =
        BaseShape::new(ShapeKind::Bridge, 0.3, 0.2, 0.1, (0.3, 0.7, 0.7).into());
}

#[derive(Debug, Clone, Copy)]
pub struct Ship {
    scroll_speed_base: f32,
    bridge_shape: Shape,

    boats: [Boat; MAX_BOATS],
    num_boats: usize,
}

impl Ship {
    pub fn new() -> Self {
        Ship {
            scroll_speed_base: SCROLL_SPEED_BASE,
            bridge_shape: Shape::new(&SHIP_BRIDGE),

            boats: [Boat::new(0), Boat::new(1)],
            num_boats: 1,
        }
    }

    pub fn init(&mut self) {}

    pub fn scroll_speed_base(&self) -> f32 {
        self.scroll_speed_base
    }

    pub fn nearest_boat(&self, pos: Vector2<f32>) -> &Boat {
        self.boats[0..self.num_boats]
            .par_iter()
            .map(|boat| (boat, abagames_util::fast_distance(boat.pos, pos)))
            .min_by(|&(_, dist_a), &(_, dist_b)| {
                dist_a
                    .partial_cmp(&dist_b)
                    .expect("distances should not be NaN")
            })
            .expect("expected there to be at least one distance")
            .0
    }

    pub fn highest_y(&self) -> f32 {
        self.boats[0..self.num_boats]
            .par_iter()
            .map(|boat| boat.pos.y)
            .max_by(|&y_a, &y_b| y_a.partial_cmp(&y_b).expect("positions should not be NaN"))
            .expect("expected there to be at least one position")
    }

    pub fn mid_pos(&self) -> Vector2<f32> {
        let sum: Vector2<f32> = self.boats[0..self.num_boats]
            .par_iter()
            .map(|boat| boat.pos)
            .sum();

        sum / (self.num_boats as f32)
    }

    pub fn is_hit(&self, pos: Vector2<f32>, prev_pos: Vector2<f32>) -> bool {
        self.boats[0..self.num_boats]
            .par_iter()
            .any(|boat| boat.is_hit(pos, prev_pos))
    }
}

#[derive(Debug, Clone, Copy)]
pub struct Boat {
    pos: Vector2<f32>,
    vel: Vector2<f32>,
    count: u32,
    angle: Rad<f32>,
    fire_angle: Option<Rad<f32>>,
    shield_count: u32,
    shape: Shape,
    bridge_shape: Shape,
}

const HIT_DISTANCE: f32 = 0.2;
const INVINCIBLE_COUNT: u32 = 228;
const RESTART_COUNT: u32 = 300;

impl Boat {
    fn new(index: u32) -> Self {
        let (base_shape, base_bridge_shape): (&BaseShape, &BaseShape) = match index {
            0 => (&ROUNDTAIL_0, &BRIDGE_0),
            1 => (&ROUNDTAIL_1, &BRIDGE_1),
            _ => unreachable!(),
        };

        Boat {
            pos: (0., 0.).into(),
            vel: (0., 0.).into(),
            count: INVINCIBLE_COUNT,
            angle: Rad(0.),
            fire_angle: None,
            shield_count: 0,
            shape: Shape::new(base_shape),
            bridge_shape: Shape::new(base_bridge_shape),
        }
    }

    pub fn pos(&self) -> Vector2<f32> {
        self.pos
    }

    pub fn vel(&self) -> Vector2<f32> {
        self.vel
    }

    fn is_hit(&self, pos: Vector2<f32>, prev_pos: Vector2<f32>) -> bool {
        if 0 < self.count {
            return false;
        }

        let bullet_travel = prev_pos - pos;
        let bullet_travel_dist = bullet_travel.dot(bullet_travel);
        if bullet_travel_dist > 0.00001 {
            let ship_offset = self.pos - pos;
            let ship_bullet_proj = bullet_travel.dot(ship_offset);
            if 0. <= ship_bullet_proj && ship_bullet_proj <= bullet_travel_dist {
                let ship_dist = ship_offset.dot(ship_offset);
                let hit_distance =
                    ship_dist - ship_bullet_proj * ship_bullet_proj / bullet_travel_dist;
                if 0. <= hit_distance && hit_distance <= HIT_DISTANCE {
                    return true;
                }
            }
        }

        false
    }

    fn is_in_reset(&self) -> bool {
        INVINCIBLE_COUNT < self.count
    }

    fn is_blinked(&self) -> bool {
        0 < self.count && (self.count % 32) < 16
    }
}

gfx_defines! {
    constant Rotation {
        rotmat: [[f32; 4]; 4] = "rotmat",
    }

    vertex ShipData {
        pos: f32 = "pos",
        color: [f32; 4] = "color",
    }

    constant LineData {
        pos: [f32; 2] = "pos",
        angle: f32 = "angle",
    }

    vertex Line {
        rotation: f32 = "rotation",
        color: [f32; 4] = "color",
    }

    vertex Sight {
        size_factor: [f32; 2] = "size_factor",
    }

    vertex PerSight {
        pos: [f32; 2] = "pos",
        size: f32 = "size",
        color: [f32; 4] = "color",
    }

    pipeline ship_pipe {
        vbuf: gfx::VertexBuffer<ShipData> = (),
        rotation: gfx::ConstantBuffer<Rotation> = "Rotation",
        screen: gfx::ConstantBuffer<ScreenTransform> = "Screen",
        brightness: gfx::ConstantBuffer<Brightness> = "Brightness",
        out_color: gfx::RenderTarget<TargetFormat> = "Target0",
    }

    pipeline line_pipe {
        vbuf: gfx::VertexBuffer<Line> = (),
        line: gfx::ConstantBuffer<LineData> = "LineData",
        screen: gfx::ConstantBuffer<ScreenTransform> = "Screen",
        brightness: gfx::ConstantBuffer<Brightness> = "Brightness",
        out_color: gfx::RenderTarget<TargetFormat> = "Target0",
    }

    pipeline sight_pipe {
        vbuf: gfx::VertexBuffer<Sight> = (),
        instances: gfx::InstanceBuffer<PerSight> = (),
        screen: gfx::ConstantBuffer<ScreenTransform> = "Screen",
        brightness: gfx::ConstantBuffer<Brightness> = "Brightness",
        out_color: gfx::RenderTarget<TargetFormat> = "Target0",
    }
}

pub struct ShipDraw<R>
where
    R: gfx::Resources,
{
    ship_slice: gfx::Slice<R>,
    ship_pso: gfx::PipelineState<R, <ship_pipe::Data<R> as gfx::pso::PipelineData<R>>::Meta>,
    ship_data: ship_pipe::Data<R>,
    rotation_buffer: gfx::handle::Buffer<R, Rotation>,

    line_slice: gfx::Slice<R>,
    line_pso: gfx::PipelineState<R, <line_pipe::Data<R> as gfx::pso::PipelineData<R>>::Meta>,
    line_data: line_pipe::Data<R>,
    line_buffer: gfx::handle::Buffer<R, LineData>,

    sight_slice_a: gfx::Slice<R>,
    sight_slice_b: gfx::Slice<R>,
    sight_slice_c: gfx::Slice<R>,
    sight_slice_d: gfx::Slice<R>,
    sight_pso: gfx::PipelineState<R, <sight_pipe::Data<R> as gfx::pso::PipelineData<R>>::Meta>,
    sight_instances: gfx::handle::Buffer<R, PerSight>,
    sight_data: sight_pipe::Data<R>,
}

impl<R> ShipDraw<R>
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
        #[rustfmt::skip]
        let ship_vertex_data = [
            ShipData { pos: 0., color: [0.5, 0.5, 0.9, 0.8], },
            ShipData { pos: 0.5, color: [0.5, 0.5, 0.9, 0.3], },
            ShipData { pos: 1., color: [0.5, 0.5, 0.9, 0.8], },
        ];
        let ship_vbuf = factory.create_vertex_buffer(&ship_vertex_data);

        let ship_slice =
            abagames_util::slice_for_loop::<R, F>(factory, ship_vertex_data.len() as u32);

        #[rustfmt::skip]
        let line_vertex_data = [
            Line { rotation: 0., color: [0.5, 0.9, 0.7, 0.4], },
            Line { rotation: 1., color: [0.5, 0.9, 0.7, 0.8], },
        ];
        let line_vbuf = factory.create_vertex_buffer(&line_vertex_data);
        let line_slice =
            abagames_util::slice_for_loop::<R, F>(factory, line_vertex_data.len() as u32);

        #[rustfmt::skip]
        let sight_vertex_data = [
            Sight { size_factor: [-1., -0.5], },
            Sight { size_factor: [-1., -1.], },
            Sight { size_factor: [-0.5, -1.], },

            Sight { size_factor: [1., -0.5], },
            Sight { size_factor: [1., -1.], },
            Sight { size_factor: [0.5, -1.], },

            Sight { size_factor: [1., 0.5], },
            Sight { size_factor: [1., 1.], },
            Sight { size_factor: [0.5, 1.], },

            Sight { size_factor: [-1., 0.5], },
            Sight { size_factor: [-1., 1.], },
            Sight { size_factor: [-0.5, 1.], },
        ];
        let sight_vbuf = factory.create_vertex_buffer(&sight_vertex_data);
        let sight_slice_a = abagames_util::slice_for_loop::<R, F>(factory, 3);
        let mut sight_slice_b = sight_slice_a.clone();
        sight_slice_b.base_vertex = 3;
        let mut sight_slice_c = sight_slice_a.clone();
        sight_slice_c.base_vertex = 6;
        let mut sight_slice_d = sight_slice_a.clone();
        sight_slice_d.base_vertex = 9;

        let sight_instances = factory
            .create_buffer(
                MAX_BOATS * 2,
                gfx::buffer::Role::Vertex,
                gfx::memory::Usage::Upload,
                gfx::memory::Bind::empty(),
            )
            .expect("failed to create the buffer for sights");

        let ship_shader = factory
            .create_shader_vertex(include_bytes!("shader/ship.glslv"))
            .expect("failed to compile the vertex shader for ships");
        let line_shader = factory
            .create_shader_vertex(include_bytes!("shader/ship_line.glslv"))
            .expect("failed to compile the vertex shader for lines");
        let sight_shader = factory
            .create_shader_vertex(include_bytes!("shader/ship_sight.glslv"))
            .expect("failed to compile the vertex shader for sights");

        let frag_shader = factory
            .create_shader_pixel(include_bytes!("shader/ship.glslf"))
            .expect("failed to compile the fragment shader for ships");

        let ship_program = factory
            .create_program(&gfx::ShaderSet::Simple(ship_shader, frag_shader.clone()))
            .expect("failed to link the ship shader");
        let line_program = factory
            .create_program(&gfx::ShaderSet::Simple(line_shader, frag_shader.clone()))
            .expect("failed to link the line shader");
        let sight_program = factory
            .create_program(&gfx::ShaderSet::Simple(sight_shader, frag_shader.clone()))
            .expect("failed to link the sight shader");

        let ship_pso = factory
            .create_pipeline_from_program(
                &ship_program,
                gfx::Primitive::LineStrip,
                gfx::state::Rasterizer {
                    front_face: gfx::state::FrontFace::CounterClockwise,
                    cull_face: gfx::state::CullFace::Nothing,
                    method: gfx::state::RasterMethod::Line(1),
                    offset: None,
                    samples: None,
                },
                ship_pipe::new(),
            )
            .expect("failed to create the pipeline for ships");
        let line_pso = factory
            .create_pipeline_from_program(
                &line_program,
                gfx::Primitive::LineStrip,
                gfx::state::Rasterizer {
                    front_face: gfx::state::FrontFace::CounterClockwise,
                    cull_face: gfx::state::CullFace::Nothing,
                    method: gfx::state::RasterMethod::Line(1),
                    offset: None,
                    samples: None,
                },
                line_pipe::new(),
            )
            .expect("failed to create the pipeline for lines");
        let sight_pso = factory
            .create_pipeline_from_program(
                &sight_program,
                gfx::Primitive::LineStrip,
                gfx::state::Rasterizer {
                    front_face: gfx::state::FrontFace::CounterClockwise,
                    cull_face: gfx::state::CullFace::Nothing,
                    method: gfx::state::RasterMethod::Line(2),
                    offset: None,
                    samples: None,
                },
                sight_pipe::new(),
            )
            .expect("failed to create the pipeline for sights");

        let rotation_buffer = factory.create_constant_buffer(1);
        let line_buffer = factory.create_constant_buffer(1);

        let ship_data = ship_pipe::Data {
            vbuf: ship_vbuf,
            rotation: rotation_buffer.clone(),
            screen: context.perspective_screen_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            out_color: view.clone(),
        };
        let line_data = line_pipe::Data {
            vbuf: line_vbuf,
            line: line_buffer.clone(),
            screen: context.perspective_screen_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            out_color: view.clone(),
        };
        let sight_data = sight_pipe::Data {
            vbuf: sight_vbuf,
            instances: sight_instances.clone(),
            screen: context.orthographic_screen_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            out_color: view,
        };

        ShipDraw {
            ship_slice,
            ship_pso,
            ship_data,
            rotation_buffer,

            line_slice,
            line_pso,
            line_data,
            line_buffer,

            sight_slice_a,
            sight_slice_b,
            sight_slice_c,
            sight_slice_d,
            sight_pso,
            sight_instances,
            sight_data,
        }
    }

    pub fn prep_draw<F>(&mut self, factory: &mut F, mouse_pos: Option<Vector2<f32>>, ship: &Ship)
    where
        F: gfx::Factory<R>,
    {
        let sights = if let Some(mouse_pos) = mouse_pos {
            let mut writer = factory
                .write_mapping(&self.sight_instances)
                .expect("could not get a writable mapping to the sight buffer");
            2 * ship.boats[0..ship.num_boats]
                .iter()
                .filter(|boat| boat.count <= INVINCIBLE_COUNT)
                .enumerate()
                .map(|(i, boat)| {
                    writer[i] = PerSight {
                        pos: mouse_pos.into(),
                        size: 0.3,
                        color: [0.7, 0.9, 0.8, 1.],
                    };
                    writer[i + 1] = PerSight {
                        pos: mouse_pos.into(),
                        size: 0.9 - 0.8 * (((32 - (boat.count % 32)) / 32) as f32),
                        color: [0.7, 0.9, 0.8, 1.],
                    };
                })
                .count() as u32
        } else {
            0
        };
        self.sight_slice_a.instances = Some((sights, 0));
        self.sight_slice_b.instances = Some((sights, 0));
        self.sight_slice_c.instances = Some((sights, 0));
        self.sight_slice_d.instances = Some((sights, 0));
    }

    fn draw_boat<C>(
        &self,
        context: &mut EncoderContext<R, C>,
        shape_draw: &ShapeDraw<R>,
        shield_draw: &ShieldDraw<R>,
        boat: &Boat,
    ) where
        C: gfx::CommandBuffer<R>,
    {
        if boat.is_in_reset() {
            return;
        }

        if let Some(angle) = boat.fire_angle {
            let line_data = LineData {
                pos: boat.pos.into(),
                angle: angle.0,
            };
            context
                .encoder
                .update_constant_buffer(&self.line_buffer, &line_data);

            context
                .encoder
                .draw(&self.line_slice, &self.line_pso, &self.line_data);
        }

        if boat.is_blinked() {
            return;
        }

        let modelmat = Matrix4::from_axis_angle(Vector3::unit_z(), boat.angle)
            * Matrix4::from_translation(boat.pos.extend(0.));

        shape_draw.draw(context, &boat.shape, modelmat);
        shape_draw.draw(context, &boat.bridge_shape, modelmat);

        if boat.shield_count > 0 {
            let size = if boat.shield_count < 120 {
                0.66 * (boat.shield_count as f32) / 120.
            } else {
                0.66
            };
            let modelmat =
                Matrix4::from_axis_angle(Vector3::unit_z(), Deg((boat.shield_count as f32) * -5.))
                    * Matrix4::from_scale(size);

            shield_draw.draw(context, modelmat);
        }
    }

    pub fn draw<C>(
        &self,
        context: &mut EncoderContext<R, C>,
        shape_draw: &ShapeDraw<R>,
        shield_draw: &ShieldDraw<R>,
        ship: &Ship,
    ) where
        C: gfx::CommandBuffer<R>,
    {
        ship.boats[0..ship.num_boats]
            .iter()
            .for_each(|boat| self.draw_boat(context, shape_draw, shield_draw, boat));

        if
        /*ship.mode.uses_two_ships() &&*/
        !ship.boats[0].is_in_reset() {
            let start_pos = ship.boats[0].pos;
            let end_pos = ship.boats[1].pos;
            let dist = start_pos.distance(end_pos);
            let fast_dist = abagames_util::fast_distance(start_pos, end_pos);
            let angle = if fast_dist < 0.1 {
                Rad(0.)
            } else {
                let diff = end_pos - start_pos;
                Rad::atan2(diff.y, diff.x)
            };
            let rotation_mat = Matrix4::from_axis_angle(Vector3::unit_z(), angle);
            let rotmat = Matrix4::from_translation(start_pos.extend(0.))
                * rotation_mat
                * Matrix4::from_nonuniform_scale(dist, 0., 0.);

            let rotation = Rotation {
                rotmat: rotmat.into(),
            };
            context
                .encoder
                .update_constant_buffer(&self.rotation_buffer, &rotation);

            context
                .encoder
                .draw(&self.ship_slice, &self.ship_pso, &self.ship_data);

            let shapemat = Matrix4::from_translation(ship.mid_pos().extend(0.)) * rotation_mat;
            shape_draw.draw(context, &ship.bridge_shape, shapemat);
        }
    }

    pub fn draw_lives<C>(
        &self,
        context: &mut EncoderContext<R, C>,
        shape_draw: &ShapeDraw<R>,
        lives: u32,
        ship: &Ship,
    ) where
        C: gfx::CommandBuffer<R>,
    {
        let scale = Matrix4::from_scale(0.7);
        (0..lives).fold(-12., |x, _| {
            let translate = Matrix4::from_translation(Vector3::new(x, -9., 0.));
            shape_draw.draw_front(context, &ship.boats[0].shape, scale * translate);
            x + 0.7
        });
    }

    pub fn draw_front<C>(&self, context: &mut EncoderContext<R, C>)
    where
        C: gfx::CommandBuffer<R>,
    {
        context
            .encoder
            .draw(&self.sight_slice_a, &self.sight_pso, &self.sight_data);
        context
            .encoder
            .draw(&self.sight_slice_b, &self.sight_pso, &self.sight_data);
        context
            .encoder
            .draw(&self.sight_slice_c, &self.sight_pso, &self.sight_data);
        context
            .encoder
            .draw(&self.sight_slice_d, &self.sight_pso, &self.sight_data);
    }
}
