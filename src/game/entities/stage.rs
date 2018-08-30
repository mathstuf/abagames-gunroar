// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

use crates::abagames_util::{self, Pool, Rand};
use crates::cgmath::Vector2;
use crates::gfx;
use crates::itertools::Itertools;
use crates::rayon::prelude::*;

use game::entities::enemy::{Enemy, EnemyAppearance, EnemySpec, EnemyState, ShipClass};
use game::entities::field::{Field, NEXT_BLOCK_AREA_SIZE_F32};
use game::entities::letter::{self, Letter};
use game::entities::ship::Ship;
use game::render::EncoderContext;
use game::state::GameStateContext;

use std::cmp;

const RANK_INC_BASE: f32 = 0.0018;
const BLOCK_DENSITY_MIN: i32 = 0;
const BLOCK_DENSITY_MAX: i32 = 3;
const MAX_ENEMY_APPEARANCES: usize = 3;

#[derive(Debug, Clone, Copy)]
struct Appearance {
    spec: Option<EnemySpec>,
    next_dist: f32,
    next_dist_interval: f32,
    kind: EnemyAppearance,
}

impl Appearance {
    fn new() -> Self {
        Appearance {
            spec: None,
            next_dist: 0.,
            next_dist_interval: 1.,
            kind: EnemyAppearance::Top,
        }
    }

    fn init(&mut self, spec: EnemySpec, num: i32, kind: EnemyAppearance, rand: &mut Rand) {
        self.spec = Some(spec);
        self.next_dist_interval = NEXT_BLOCK_AREA_SIZE_F32 / (num as f32);
        self.next_dist = rand.next_float(self.next_dist_interval);
        self.kind = kind;
    }

    fn reset(&mut self) {
        self.spec = None;
    }

    fn step(&mut self, field: &Field, enemies: &mut Pool<Enemy>, rand: &mut Rand) {
        if let Some(spec) = self.spec {
            self.next_dist -= field.last_scroll_y();
            if self.next_dist <= 0. {
                self.next_dist += self.next_dist_interval;
                if let Some(state) = EnemyState::appear(&spec, self.kind, field, enemies, rand) {
                    enemies.get()
                        .map(|enemy| enemy.init(spec, state));
                }
            }
        }
    }
}

#[derive(Debug, Clone, Copy)]
pub struct Stage {
    rank: f32,
    rank_base: f32,
    rank_add: f32,
    rank_velocity: f32,
    rank_increment: f32,

    density: i32,
    num_batteries: u32,

    boss_timer_base: u32,
    boss_timer: Option<u32>,
    boss_app_count: u32,

    background_timer: u32,

    appearances: [Appearance; 3],
    platform_spec: EnemySpec,
}

impl Stage {
    pub fn new() -> Self {
        Stage {
            rank: 1.,
            rank_base: 1.,
            rank_add: 0.,
            rank_velocity: 0.,
            rank_increment: 0.,

            density: 2,
            num_batteries: 0,

            boss_timer_base: 60 * 1000,
            boss_timer: Some(60 * 1000),
            boss_app_count: 0,

            background_timer: 0,

            appearances: [Appearance::new(); MAX_ENEMY_APPEARANCES],
            platform_spec: EnemySpec::new(),
        }
    }

    pub fn init(&mut self, rank_inc_ratio: f32, context: &mut GameStateContext, rand: &mut Rand) {
        self.rank = 1.;
        self.rank_base = 1.;
        self.rank_add = 0.;
        self.rank_velocity = 0.;
        self.rank_increment = RANK_INC_BASE * rank_inc_ratio;
        self.density = ((rand.next_int((BLOCK_DENSITY_MAX - BLOCK_DENSITY_MIN + 1) as u32)) as i32) + BLOCK_DENSITY_MIN;
        self.boss_timer_base = 60 * 1000;
        self.reset_boss(context);
    }

    fn start_boss(&mut self, context: &mut GameStateContext) {
        self.boss_timer = None;
        self.boss_app_count = 2;
        context.audio.fade();
        self.background_timer = 120;
        self.rank_velocity = 0.;
    }

    fn reset_boss(&mut self, context: &mut GameStateContext) {
        if self.boss_mode() {
            context.audio.fade();
            self.background_timer = 120;
            self.boss_timer_base += 30 * 1000;
        }
        self.boss_timer = Some(self.boss_timer_base);
    }

    pub fn step(&mut self, field: &Field, ship: &Ship, enemies: &mut Pool<Enemy>, context: &mut GameStateContext, rand: &mut Rand) {
        self.background_timer = self.background_timer.saturating_sub(1);
        if self.background_timer == 0 {
            if self.boss_mode() {
                context.audio.play_music("gr0");
            } else {
                // context.audio.play_next();
            }
        }
        if self.boss_mode() {
            self.boss_step(enemies, context)
        } else {
            self.level_step(field, ship, context)
        }

        self.rank = self.rank_base + self.rank_add;
        self.appearances
            .iter_mut()
            .filter(|appear| appear.spec.is_some())
            .foreach(|appearances| {
                appearances.step(field, enemies, rand)
            })
    }

    fn boss_step(&mut self, enemies: &Pool<Enemy>, context: &mut GameStateContext) {
        self.rank_add *= 0.999;
        if self.boss_app_count == 0 && enemies.par_iter().any(Enemy::is_boss) {
            self.reset_boss(context);
        }
    }

    fn level_step(&mut self, field: &Field, ship: &Ship, context: &mut GameStateContext) {
        let timer = self.boss_timer.unwrap();
        if timer <= 17 {
            self.boss_timer = None;
            self.start_boss(context);
        } else {
            self.boss_timer = Some(timer - 17);
        }

        let rv = field.last_scroll_y() / ship.scroll_speed_base() - 2.;
        if rv > 0. {
            self.rank_velocity += rv * rv * 0.0004 * self.rank_base;
        } else {
            self.rank_velocity += rv * self.rank_base;
            self.rank_velocity = f32::max(0., self.rank_velocity);
        }

        self.rank_add += self.rank_increment * (self.rank_velocity + 1.);
        self.rank_add *= 0.999;
        self.rank_base += self.rank_increment + self.rank_add * 0.0001;
    }

    pub fn next_block_area(&mut self, field: &Field, ship: &Ship, enemies: &mut Pool<Enemy>, context: &mut GameStateContext, rand: &mut Rand) -> u32 {
        if self.boss_mode() {
            self.next_block_area_boss(field, ship, enemies, context, rand);
            0
        } else {
            self.next_block_area_regular(ship, rand);
            self.density as u32
        }
    }

    fn next_block_area_boss(&mut self, field: &Field, ship: &Ship, enemies: &mut Pool<Enemy>, context: &mut GameStateContext, rand: &mut Rand) {
        self.boss_app_count = self.boss_app_count.saturating_sub(1);
        if self.boss_app_count == 0 {
            let spec = EnemySpec::ship(self.rank, ShipClass::Boss, ship, rand);
            if let Some(state) = EnemyState::appear(&spec, EnemyAppearance::Center, field, enemies, rand) {
                if let Some(enemy) = enemies.get() {
                    enemy.init(spec, state);
                } else {
                    self.reset_boss(context);
                }
            }
        }
        self.appearances
            .par_iter_mut()
            .for_each(Appearance::reset);
    }

    fn next_block_area_regular(&mut self, ship: &Ship, rand: &mut Rand) {
        let no_small_ship = self.density < BLOCK_DENSITY_MAX && rand.next_int(2) == 0;
        self.density = cmp::max(BLOCK_DENSITY_MIN, cmp::min(BLOCK_DENSITY_MAX, self.density + rand.next_int_signed(1)));
        self.num_batteries = ((self.density as f32) + rand.next_float_signed(1.) * 0.75) as u32;
        let mut rank_budget = self.rank;
        let large_ship_factor = if no_small_ship {
            1.5
        } else {
            0.5
        };
        let num_large_ships = (large_ship_factor * ( 2. - (self.density as f32) + rand.next_float_signed(1.) )) as i32;

        let appearance = match rand.next_int(2) {
            0 => EnemyAppearance::Top,
            1 => EnemyAppearance::Side,
            _ => unreachable!(),
        };

        if num_large_ships > 0 {
            let large_rank = if no_small_ship {
                1.5 * rank_budget * (0.25 + rand.next_float(0.15))
            } else {
                rank_budget * (0.25 + rand.next_float(0.15))
            };
            rank_budget -= large_rank;

            let spec = EnemySpec::ship(large_rank / (num_large_ships as f32), ShipClass::Large, ship, rand);
            self.appearances[0].init(spec, num_large_ships, appearance, rand);
        } else {
            self.appearances[0].reset();
        }

        if self.num_batteries > 0 {
            let platform_rank = rank_budget * (0.3 + rand.next_float(0.1));
            self.platform_spec.init_platform(platform_rank / (self.num_batteries as f32), rand);
        }

        let appearance = match appearance {
            EnemyAppearance::Top => EnemyAppearance::Side,
            EnemyAppearance::Side => EnemyAppearance::Center,
            _ => unreachable!(),
        };

        let num_middle_ship = ((4. - (self.density as f32) + rand.next_float_signed(1.)) * 0.66) as i32;
        let num_middle_ship = if no_small_ship {
            2 * num_middle_ship
        } else {
            num_middle_ship
        };
        if num_middle_ship > 0 {
            let middle_rank = if no_small_ship {
                rank_budget
            } else {
                rank_budget * (0.33 + rand.next_float(0.33))
            };
            rank_budget -= middle_rank;

            let spec = EnemySpec::ship(middle_rank / (num_middle_ship as f32), ShipClass::Middle, ship, rand);
            self.appearances[1].init(spec, num_middle_ship, appearance, rand);
        } else {
            self.appearances[1].reset()
        };

        if no_small_ship {
            self.appearances[2].reset();
        } else {
            let num_small_ship = (( (3. + rank_budget).sqrt() * (1. + rand.next_float_signed(0.5)) * 2. ) as i32) + 1;
            let num_small_ship = cmp::min(256, num_small_ship);
            let spec = EnemySpec::small_ship(rank_budget / (num_small_ship as f32), rand);
            self.appearances[2].init(spec, num_small_ship, EnemyAppearance::Top, rand);
        }
    }

    pub fn add_batteries(&self, field: &mut Field, enemies: &mut Pool<Enemy>, rand: &mut Rand) {
        let total_platforms = field.num_platforms();
        let mut num_platforms = total_platforms;
        let mut num_batteries = self.num_batteries;

        for _ in 0..100 {
            if num_platforms == 0 || num_batteries == 0 {
                break;
            }

            let mut i = rand.next_int(total_platforms as u32) as usize;
            for _ in 0..total_platforms {
                if !field.platform(i).in_use() {
                    break;
                }
                i = abagames_util::wrap_inc(i, total_platforms);
            }
            if field.platform(i).in_use() {
                break;
            }

            let (block_pos, angle) = field.platform(i).peek();
            let pos = field.screen_pos(block_pos);
            if let Some(state) = EnemyState::for_platform(&self.platform_spec, pos, angle, field, enemies) {
                if let Some(enemy) = enemies.get() {
                    field.platform_mut(i).spawned();
                    enemy.init(self.platform_spec, state);
                } else {
                    break;
                }

                for j in 0..total_platforms {
                    if field.platform(j).too_close(block_pos) {
                        field.platform_mut(j).spawned();
                        num_platforms -= 1;
                    }
                }

                num_batteries -= 1;
            }
        }
    }

    pub fn boss_mode(&self) -> bool {
        self.boss_timer.is_none()
    }

    pub fn rank(&self) -> f32 {
        self.rank
    }

    fn boss_timer(&self) -> u32 {
        self.boss_timer.unwrap_or(0)
    }

    pub fn draw<R, C>(&self, context: &mut EncoderContext<R, C>, letter: &Letter<R>)
        where R: gfx::Resources,
              C: gfx::CommandBuffer<R>,
    {
        letter.draw_number(context,
                           (1000. * self.rank) as u32,
                           letter::Style::White,
                           letter::Location::new(Vector2::new(620., 10.), 10.),
                           letter::NumberStyle {
                               pad_to: None,
                               prefix_char: Some('x'),
                               floating_digits: Some(3),
                           });
        letter.draw_time(context,
                         self.boss_timer(),
                         letter::Style::White,
                         letter::Location::new(Vector2::new(120., 20.), 7.));
    }
}
