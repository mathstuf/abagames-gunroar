// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

use crates::abagames_util::{self, Pool, Rand, TargetFormat};
use crates::cgmath::{Angle, ElementWise, Rad, Matrix4, MetricSpace, Vector2, Vector3};
use crates::gfx;
use crates::gfx::traits::FactoryExt;
use crates::itertools::Itertools;
use crates::rayon::prelude::*;

use game::entities::bullet::Bullet;
use game::entities::field::Field;
use game::entities::particles::{Fragment, Smoke, SmokeKind, Spark};
use game::entities::shapes::bullet::BulletShapeKind;
use game::entities::shapes::turret::TurretShapes;
use game::entities::shapes::ShapeDraw;
use game::entities::ship::Ship;
use game::entities::shot::Shot;
use game::render::{EncoderContext, RenderContext};
use game::render::{Brightness, ScreenTransform};
use game::state::GameStateContext;

use std::f32;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TurretKind {
    Main,
    Sub,
    SubDestructive,
    Small,
    Moving,
}

struct TurretParams {
    size_offset: f32,
    size_range: Option<f32>,
    burst_factor: f32,
    nway_factor: Option<f32>,
    interval_numerator: f32,
    interval_factor: f32,
    speed_factor_rt: f32,
    speed_factor: f32,
    shield: u32,
}

impl TurretKind {
    fn is_sub(&self) -> bool {
        match *self {
            TurretKind::Sub | TurretKind::SubDestructive => true,
            _ => false,
        }
    }

    fn init_spec_phase1(&self, rank: f32, spec: &mut TurretSpec, rand: &mut Rand) -> f32 {
        match *self {
            TurretKind::Small => {
                spec.min_range = 8.;
                spec.bullet_shape = BulletShapeKind::Small;
                spec.blind = true;
                spec.invisible = true;
                rank
            },
            TurretKind::Moving => {
                spec.min_range = 6.;
                spec.bullet_shape = BulletShapeKind::MovingTurret;
                spec.blind = true;
                spec.invisible = true;
                spec.turn_speed = Rad(0.);
                spec.max_range = 9. + rand.next_float(12.);
                rank * (10. / spec.max_range.sqrt())
            },
            kind => {
                spec.max_range = 9. + rand.next_float(16.);
                spec.min_range = spec.max_range / (4. + rand.next_float(0.5));
                if kind.is_sub() {
                    spec.max_range *= 0.72;
                    spec.min_range *= 0.9;
                }
                let mut rank = rank * (10. / spec.max_range.sqrt());
                if rand.next_int(4) == 0 {
                    let lar = f32::min(rank * 0.1, 1.);
                    let lar = rand.next_float(lar / 2.) + lar / 2.;
                    spec.look_ahead_ratio = Some(lar);
                    rank /= 1. + lar * 0.3;
                }
                if rand.next_int(3) == 0 && spec.look_ahead_ratio.is_none() {
                    spec.blind = false;
                    rank *= 1.5;
                } else {
                    spec.blind = true;
                }
                spec.turn_range = Rad(f32::consts::FRAC_PI_4 + rand.next_float(f32::consts::FRAC_PI_4));
                if kind == TurretKind::Main {
                    spec.turn_range *= 1.2;
                }
                spec.turn_speed = Rad(0.005 + rand.next_float(0.015));
                if rand.next_int(4) == 0 {
                    spec.burst_turn_ratio = rand.next_float(0.66) + 0.33;
                }
                rank
            },
        }
    }

    fn init_spec_phase2(&self, rank: f32, spec: &mut TurretSpec, rand: &mut Rand) {
        let params = match *self {
            TurretKind::Main => {
                TurretParams {
                    size_offset: 0.42,
                    size_range: Some(0.05),
                    burst_factor: 0.3,
                    nway_factor: Some(0.33),
                    interval_numerator: 120.,
                    interval_factor: 0.1,
                    speed_factor_rt: 0.6,
                    speed_factor: 0.12,
                    shield: 20,
                }
            },
            TurretKind::Sub => {
                TurretParams {
                    size_offset: 0.36,
                    size_range: Some(0.025),
                    burst_factor: 0.4,
                    nway_factor: Some(0.2),
                    interval_numerator: 120.,
                    interval_factor: 0.2,
                    speed_factor_rt: 0.7,
                    speed_factor: 0.2,
                    shield: 12,
                }
            },
            TurretKind::SubDestructive => {
                spec.burst_interval = ((spec.burst_interval as f32) * 0.88) as i32;
                spec.bullet_shape = BulletShapeKind::Destructible;
                spec.bullet_destructive = true;

                TurretParams {
                    size_offset: 0.36,
                    size_range: Some(0.025),
                    burst_factor: 0.4,
                    nway_factor: Some(0.2),
                    interval_numerator: 60.,
                    interval_factor: 0.2,
                    speed_factor_rt: 0.7,
                    speed_factor: 0.33,
                    shield: 12,
                }
            },
            TurretKind::Small => {
                TurretParams {
                    size_offset: 0.33,
                    size_range: None,
                    burst_factor: 0.33,
                    nway_factor: None,
                    interval_numerator: 120.,
                    interval_factor: 0.2,
                    speed_factor_rt: 1.,
                    speed_factor: 0.24,
                    shield: 99999,
                }
            },
            TurretKind::Moving => {
                TurretParams {
                    size_offset: 0.36,
                    size_range: None,
                    burst_factor: 0.3,
                    nway_factor: Some(0.1),
                    interval_numerator: 120.,
                    interval_factor: 0.33,
                    speed_factor_rt: 0.7,
                    speed_factor: 0.2,
                    shield: 99999,
                }
            },
        };

        let size_diff = params.size_range.map(|size_range| rand.next_float(size_range)).unwrap_or(0.);
        spec.size = params.size_offset + size_diff;
        let br = rank * params.burst_factor * (1. + rand.next_float_signed(0.2));
        spec.nway = params.nway_factor
            .map(|nway_factor| {
                let nr = rank * nway_factor * rand.next_float_signed(1.);
                (nr * 0.66 + 1.) as i32
            })
            .unwrap_or(1);
        let ir = rank * params.interval_factor * (1. + rand.next_float_signed(0.2));
        spec.burst_num = (br as i32) + 1;
        spec.interval = ((params.interval_numerator / (ir * 2. + 1.)) as i32) + 1;
        let nway_diff = if params.nway_factor.is_some() {
            ((spec.nway - 1) as f32) / 0.66
        } else {
            0.
        };
        let sr = f32::max(0., rank - (spec.burst_num as f32) + 1. - nway_diff - ir);
        spec.speed = params.speed_factor * (sr * params.speed_factor_rt).sqrt();
        spec.shield = params.shield;
    }
}

#[derive(Debug, Clone, Copy)]
pub struct TurretSpec {
    /// The kind of turret.
    kind: TurretKind,
    /// How often the turret fires a bullet.
    interval: i32,
    speed: f32,
    speed_accel: f32,
    min_range: f32,
    max_range: f32,
    turn_speed: Rad<f32>,
    turn_range: Rad<f32>,
    burst_num: i32,
    burst_interval: i32,
    burst_turn_ratio: f32,
    blind: bool,
    look_ahead_ratio: Option<f32>,
    nway: i32,
    nway_angle: Rad<f32>,
    nway_change: bool,
    bullet_shape: BulletShapeKind,
    bullet_destructive: bool,
    shield: u32,
    invisible: bool,
    size: f32,

    shapes: TurretShapes,
}

impl TurretSpec {
    fn new() -> Self {
        TurretSpec {
            kind: TurretKind::Main,
            interval: 0,
            speed: 1.,
            speed_accel: 0.,
            min_range: 0.,
            max_range: 0.,
            turn_speed: Rad(0.),
            turn_range: Rad(0.),
            burst_num: 1,
            burst_interval: 0,
            burst_turn_ratio: 0.,
            blind: false,
            look_ahead_ratio: None,
            nway: 1,
            nway_angle: Rad(0.),
            nway_change: false,
            bullet_shape: BulletShapeKind::Normal,
            bullet_destructive: false,
            shield: 0,
            invisible: false,
            size: 1.,

            shapes: TurretShapes::new(),
        }
    }

    fn init(&mut self, rank: f32, kind: TurretKind, rand: &mut Rand) {
        self.kind = kind;

        let rank = kind.init_spec_phase1(rank, self, rand);
        self.burst_interval = (6 + rand.next_int(6)) as i32;
        kind.init_spec_phase2(rank, self, rand);

        self.speed = if self.speed < 0.1 {
            0.1
        } else {
            (10. * self.speed).sqrt() / 10.
        };

        if self.burst_num > 2 {
            if rand.next_int(4) == 0 {
                self.speed *= 0.8;
                self.burst_interval = (0.7 * (self.burst_interval as f32)) as i32;
                self.speed_accel = self.speed * (0.4 + rand.next_float(0.3)) / (self.burst_num as f32);
                if rand.next_int(2) == 0 {
                    self.speed_accel *= -1.;
                }
                self.speed -= self.speed_accel * (self.burst_num as f32) / 2.;
            }
            if rand.next_int(5) == 0 && self.nway > 1 {
                self.nway_change = true;
            }
        }

        self.nway_angle = Rad(0.1 + rand.next_float(0.33)) / (1. + 0.1 * (self.nway as f32));
    }

    fn as_boss(&mut self) {
        self.min_range = 0.;
        self.max_range *= 1.5;
        self.shield = ((self.shield as f32) * 2.1) as u32;
    }

    fn set_color(&mut self, color: Vector3<f32>) {
        self.shapes.set_color(color);
    }
}

#[derive(Debug, Clone, Copy)]
pub struct Turret {
    spec: TurretSpec,
    pos: Vector2<f32>,
    angle: Rad<f32>,
    base_angle: Rad<f32>,
    count: i32,
    appear_count: u32,
    start_count: u32,
    shield: u32,
    destroyed_count: Option<u32>,
    damaged: bool,
    damaged_count: u32,
    speed: f32,
    burst_count: u32,
    color: Vector3<f32>,

    is_boss: bool,
    index: u32,

    damage_offset: Vector2<f32>,
}

#[derive(Debug, Clone, Copy)]
pub struct TurretScore {
    score: u32,
    multiplier: f32,
}

impl TurretScore {
    pub fn score(&self) -> u32 {
        self.score
    }

    pub fn multiplier(&self) -> f32 {
        self.multiplier
    }
}

impl Turret {
    fn new() -> Self {
        Turret {
            spec: TurretSpec::new(),
            pos: (0., 0.).into(),
            angle: Rad(0.),
            base_angle: Rad(0.),
            count: 0,
            appear_count: 0,
            start_count: 0,
            shield: 0,
            destroyed_count: None,
            damaged: false,
            damaged_count: 0,
            speed: 0.,
            burst_count: 0,
            color: (0., 0., 0.).into(),

            is_boss: false,
            index: 0,
            damage_offset: (0., 0.).into(),
        }
    }

    fn init(&mut self, spec: TurretSpec, is_boss: bool, index: u32) {
        self.spec = spec;
        self.shield = spec.shield;
        self.appear_count = 0;
        self.count = 0;
        self.start_count = 0;
        self.damaged = false;
        self.damaged_count = 0;
        self.destroyed_count = None;
        self.speed = 1.;
        self.burst_count = 0;

        self.is_boss = is_boss;
        self.index = index;
    }

    fn step(&mut self, pos: Vector2<f32>, angle: Rad<f32>, fire_speed: f32, fire_angle: Option<Rad<f32>>, field: &Field, bullets: &mut Pool<Bullet>, smokes: &mut Pool<Smoke>, ship: &Ship, rand: &mut Rand) -> TurretState {
        self.pos = pos;
        self.base_angle = angle;

        self.destroyed_count
            .as_mut()
            .map(|count| *count += 1);
        if let Some(count) = self.destroyed_count {
            let interval = 5 + count / 12;
            if interval < 60 && count % interval == 0 {
                smokes.get()
                    .map(|smoke| {
                        smoke.init_2d(self.pos,
                                      Vector3::new(0., 0., 0.01 + rand.next_float(0.01)),
                                      SmokeKind::Fire,
                                      90 + rand.next_int(30),
                                      self.spec.size,
                                      rand);
                    });
            }

            return TurretState::Dead;
        }

        let boat = ship.nearest_boat(self.pos);
        let ship_pos = boat.pos();

        let aim = if let Some(lar) = self.spec.look_ahead_ratio {
            let ship_vel = boat.vel();
            let rotate = abagames_util::fast_distance_origin(ship_pos) / self.spec.speed * 1.2;
            (ship_pos - self.pos) + ship_vel * lar * rotate
        } else {
            ship_pos - self.pos
        };

        let aim_angle = if aim.x.abs() + aim.y.abs() < 0.1 {
            Rad(0.)
        } else {
            Rad::turn_div_4() - Rad::atan2(aim.y, aim.x)
        };

        let turn_speed = if self.count >= 0 {
            self.spec.turn_speed
        } else {
            self.spec.turn_speed * self.spec.burst_turn_ratio
        };

        // Calculate the difference between our total angle and where we want to aim.
        let raw_diff_angle = (self.base_angle + self.angle - aim_angle).normalize();
        // Normalize it to [-half, half).
        let diff_angle = if Rad::<f32>::turn_div_2().0 < raw_diff_angle.0 {
            raw_diff_angle - Rad::full_turn()
        } else {
            raw_diff_angle
        };
        // Check the difference against our allowed turn speed.
        let raw_new_angle = if diff_angle.0.abs() <= turn_speed.0 {
            // We can fully turn.
            aim_angle - self.base_angle
        } else if diff_angle.0 < 0. {
            // Move as much as possible towards our target.
            self.angle + turn_speed
        } else {
            // Move as much as possible towards our target.
            self.angle - turn_speed
        }.normalize();
        // Normalize it to [-half, half).
        let new_angle = if Rad::<f32>::turn_div_2().0 < raw_new_angle.0 {
            raw_new_angle - Rad::full_turn()
        } else {
            raw_new_angle
        };
        self.angle = Rad(f32::min(f32::max(new_angle.0, -self.spec.turn_range.0), self.spec.turn_range.0));

        self.count += 1;

        let ship_dist = abagames_util::fast_distance(self.pos, ship_pos);
        let in_field = field.is_in_field(self.pos);
        let in_outer_field = field.is_in_outer_field(self.pos);
        let in_main_field = field.is_in_field_no_top(self.pos);

        if in_field || (self.is_boss && self.count % 4 == 0) {
            self.appear_count = self.appear_count.saturating_add(1);
        }

        if self.count >= self.spec.interval {
            if self.spec.blind || (diff_angle.0.abs() <= self.spec.turn_speed.0 &&
                                   ship_dist < self.spec.max_range * 1.1 &&
                                   ship_dist > self.spec.min_range) {
                self.count = -(self.spec.burst_num - 1) * self.spec.burst_interval;
                self.speed = self.spec.speed;
                self.burst_count = 0;
            }
        } else if self.count <= 0 && -self.count % self.spec.burst_interval == 0 &&
           ((self.spec.invisible && in_field) ||
            (self.spec.invisible && self.is_boss && in_outer_field) ||
            (!self.spec.invisible && in_main_field)) &&
           ship_dist > self.spec.min_range {
            let mut bullet_angle = self.base_angle + self.angle;
            smokes.get()
                .map(|smoke| {
                    let angle_comps: Vector2<f32> = bullet_angle.sin_cos().into();
                    smoke.init_2d(self.pos,
                                  (angle_comps * self.speed).extend(0.),
                                  SmokeKind::Spark,
                                  20,
                                  self.spec.size * 2.,
                                  rand);
                });

            let nway = if self.spec.nway_change && self.burst_count % 2 == 1 {
                self.spec.nway - 1
            } else {
                self.spec.nway
            };

            bullet_angle -= Rad(self.spec.nway_angle.0 * (((nway - 1) / 2) as f32));

            (0..nway).fold(bullet_angle, |angle, _| {
                bullets.get()
                    .map(|bullet| {
                        bullet.init(self.index,
                                    self.pos,
                                    angle,
                                    self.speed,
                                    self.spec.size * 3.,
                                    self.spec.bullet_shape,
                                    self.spec.max_range,
                                    fire_speed,
                                    fire_angle);
                    });
                angle + self.spec.nway_angle
            });

            self.speed += self.spec.speed_accel;
            self.burst_count += 1;
        }

        self.damaged = false;
        self.damaged_count = self.damaged_count.saturating_sub(1);
        self.start_count = self.start_count.saturating_add(1);

        TurretState::Alive
    }

    fn damage(&mut self, damage: u32, smokes: &mut Pool<Smoke>, sparks: &mut Pool<Spark>, fragments: &mut Pool<Fragment>, context: &mut GameStateContext, rand: &mut Rand) -> Option<TurretScore> {
        self.shield = self.shield.saturating_sub(damage);
        if self.shield == 0 {
            Some(self.destroyed(smokes, sparks, fragments, context, rand))
        } else {
            self.damaged = true;
            self.damaged_count = 7;
            None
        }
    }

    fn destroyed(&mut self, smokes: &mut Pool<Smoke>, sparks: &mut Pool<Spark>, fragments: &mut Pool<Fragment>, context: &mut GameStateContext, rand: &mut Rand) -> TurretScore {
        context.audio.as_mut().map(|audio| audio.mark_sfx("turret_destroyed"));
        self.destroyed_count = Some(0);

        (0..6).foreach(|_| {
            let vel = Vector3::new(rand.next_float_signed(0.1),
                                   rand.next_float_signed(0.1),
                                   rand.next_float(0.04));
            smokes.get_force()
                .init_2d(self.pos, vel, SmokeKind::Explosion, 30 + rand.next_int(10), self.spec.size, rand);
        });

        (0..32).foreach(|_| {
            let vel = Vector2::new(rand.next_float_signed(0.5),
                                   rand.next_float_signed(0.5));
            let color = Vector3::new(0.5 + rand.next_float(0.5),
                                     0.5 + rand.next_float(0.5),
                                     0.);
            sparks.get_force()
                .init(self.pos, vel, color, 30 + rand.next_int(30));
        });

        (0..7).foreach(|_| {
            let vel = Vector3::new(rand.next_float_signed(0.25),
                                   rand.next_float_signed(0.25),
                                   0.05 + rand.next_float(0.05));
            fragments.get_force()
                .init(self.pos, vel, self.spec.size * (0.5 + rand.next_float(0.5)), rand);
        });

        match self.spec.kind {
            TurretKind::Main => {
                TurretScore {
                    multiplier: 2.,
                    score: 40,
                }
            },
            TurretKind::Sub | TurretKind::SubDestructive => {
                TurretScore {
                    multiplier: 1.,
                    score: 20,
                }
            },
            _ => unreachable!(),
        }
    }

    pub fn collides(&mut self, shot: &Shot, smokes: &mut Pool<Smoke>, sparks: &mut Pool<Spark>, fragments: &mut Pool<Fragment>, context: &mut GameStateContext, rand: &mut Rand) -> Option<TurretScore> {
        if self.destroyed_count.is_some() || self.spec.invisible {
            return None;
        }

        let offset = self.pos - shot.pos();
        let offset = Vector2::new(offset.x.abs(), offset.y.abs());
        if self.spec.shapes.collides(offset, shot.collision()) {
            self.damage(shot.damage(), smokes, sparks, fragments, context, rand)
        } else {
            None
        }
    }

    pub fn destroy(&mut self) {
        if self.destroyed_count.is_none() {
            self.destroyed_count = Some(999);
        }
    }

    pub fn prep_draw(&mut self, rand: &mut Rand) {
        if self.spec.invisible {
            return;
        }

        let is_damaged = self.damaged_count > 0;
        let is_destroyed = self.destroyed_count.is_some();
        self.damage_offset = if !is_destroyed && is_damaged {
            let count = (self.damaged_count as f32) * 0.015;
            (rand.next_float_signed(count), rand.next_float_signed(count))
        } else {
            (0., 0.)
        }.into();
    }

    pub fn draw<R, C>(&self, context: &mut EncoderContext<R, C>, shape_draw: &ShapeDraw<R>, turret_draw: &TurretDraw<R>)
        where R: gfx::Resources,
              C: gfx::CommandBuffer<R>,
    {
        if self.spec.invisible {
            return;
        }

        let is_damaged = self.damaged_count > 0;
        let is_destroyed = self.destroyed_count.is_some();
        let angle = self.base_angle + self.angle;
        let modelmat = Matrix4::from_translation((self.pos + self.damage_offset).extend(0.)) *
            Matrix4::from_axis_angle(Vector3::unit_z(), -angle);
        let scalemat = Matrix4::from_scale(self.spec.size);

        let shape = if is_destroyed {
            self.spec.shapes.destroyed()
        } else if is_damaged {
            self.spec.shapes.damaged()
        } else {
            self.spec.shapes.normal()
        };
        shape_draw.draw(context, shape, modelmat * scalemat);

        if is_destroyed || self.appear_count > 120 {
            return
        }

        let alpha = if self.start_count < 12 {
            (self.start_count as f32) / 12.
        } else {
            1. - (self.appear_count as f32) / 120.
        };

        if 1 < self.spec.nway {
            let angle_step = self.spec.nway_angle;
            let start_angle = angle - angle_step * (((self.spec.nway) / 2) as f32);
            turret_draw.draw_sight_sweep(context, self.spec.min_range, self.spec.max_range, self.pos, alpha, start_angle, angle_step, self.spec.nway);
        } else {
            turret_draw.draw_sight_line(context, self.spec.min_range, self.spec.max_range, self.pos, alpha, angle);
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TurretGroupAlignment {
    Round,
    Straight,
}

#[derive(Debug, Clone, Copy)]
pub struct TurretGroupSpec {
    spec: TurretSpec,
    count: u32,
    alignment: TurretGroupAlignment,
    align: Rad<f32>,
    align_width: f32,
    radius: f32,
    distance_ratio: f32,
    offset: Vector2<f32>,
}

impl TurretGroupSpec {
    pub fn set_color(&mut self, color: Vector3<f32>) {
        self.spec.shapes.set_color(color);
    }
}

#[derive(Debug, Clone, Copy)]
pub struct TurretGroupSpecBuilder {
    spec: TurretGroupSpec,
}

impl TurretGroupSpecBuilder {
    pub fn with_count(&mut self, count: u32) -> &mut Self {
        self.spec.count = count;
        self
    }

    pub fn with_alignment(&mut self, alignment: TurretGroupAlignment) -> &mut Self {
        self.spec.alignment = alignment;
        self
    }

    pub fn with_sized_alignment(&mut self, align: Rad<f32>, width: f32) -> &mut Self {
        self.spec.align = align;
        self.spec.align_width = width;
        self
    }

    pub fn with_radius(&mut self, radius: f32) -> &mut Self {
        self.spec.radius = radius;
        self
    }

    pub fn with_distance_ratio(&mut self, ratio: f32) -> &mut Self {
        self.spec.distance_ratio = ratio;
        self
    }

    pub fn as_boss(&mut self) -> &mut Self {
        self.spec.spec.as_boss();
        self
    }

    pub fn with_y_offset(&mut self, offset: f32) -> &mut Self {
        self.spec.offset.y = offset;
        self
    }

    pub fn init_spec(&mut self, rank: f32, kind: TurretKind, rand: &mut Rand) -> &mut Self {
        self.spec.spec.init(rank, kind, rand);
        self
    }
}

impl Default for TurretGroupSpecBuilder {
    fn default() -> Self {
        TurretGroupSpecBuilder {
            spec: TurretGroupSpec {
                spec: TurretSpec::new(),
                offset: (0., 0.).into(),
                count: 1,
                alignment: TurretGroupAlignment::Round,
                align_width: 0.,
                align: Rad(0.),
                radius: 0.,
                distance_ratio: 0.,
            },
        }
    }
}

impl From<TurretGroupSpecBuilder> for TurretGroupSpec {
    fn from(builder: TurretGroupSpecBuilder) -> Self {
        builder.spec
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TurretState {
    Alive,
    Dead,
}

const MAX_TURRETS_GROUP: usize = 16;

#[derive(Debug, Clone, Copy)]
enum TurretGroupData {
    Round {
        angle: Rad<f32>,
        angle_step: Rad<f32>,
    },
    Straight {
        y: f32,
        y_step: f32,
    },
}

#[derive(Debug, Clone, Copy)]
pub struct TurretGroup {
    spec: TurretGroupSpec,
    turrets: [Turret; MAX_TURRETS_GROUP],
}

impl TurretGroup {
    pub fn new() -> Self {
        TurretGroup {
            spec: TurretGroupSpecBuilder::default().into(),
            turrets: [Turret::new(); MAX_TURRETS_GROUP],
        }
    }

    fn turrets(&self) -> &[Turret] {
        &self.turrets[0..self.spec.count as usize]
    }

    fn turrets_mut(&mut self) -> &mut [Turret] {
        &mut self.turrets[0..self.spec.count as usize]
    }

    pub fn init(&mut self, spec: TurretGroupSpec, is_boss: bool, index: u32) {
        self.spec = spec;
        self.turrets_mut()
            .par_iter_mut()
            .for_each(|turret| turret.init(spec.spec.clone(), is_boss, index));
    }

    pub fn step(&mut self, pos: Vector2<f32>, base_angle: Rad<f32>, field: &Field, bullets: &mut Pool<Bullet>, smokes: &mut Pool<Smoke>, ship: &Ship, rand: &mut Rand) -> TurretState {
        let mut data = match self.spec.alignment {
            TurretGroupAlignment::Round => {
                if self.spec.count > 1 {
                    TurretGroupData::Round {
                        angle: self.spec.align - Rad(self.spec.align_width / 2.),
                        angle_step: Rad(self.spec.align_width / ((self.spec.count - 1) as f32)),
                    }
                } else {
                    TurretGroupData::Round {
                        angle: self.spec.align,
                        angle_step: Rad(0.),
                    }
                }
            },
            TurretGroupAlignment::Straight => {
                TurretGroupData::Straight {
                    y: 0.,
                    y_step: self.spec.offset.y / ((self.spec.count + 1) as f32),
                }
            }
        };

        let mut dead = true;
        let (sin, cos) = base_angle.sin_cos();
        for turret in self.turrets.iter_mut().take(self.spec.count as usize) {
            let (new_data, base_pos, angle) = match data {
                TurretGroupData::Round { angle, angle_step } => {
                    let new_data = TurretGroupData::Round {
                        angle: angle + angle_step,
                        angle_step: angle_step,
                    };

                    let angle_comps: Vector2<f32> = angle.sin_cos().into();
                    (new_data, angle_comps * self.spec.radius, angle)
                },
                TurretGroupData::Straight { y, y_step } => {
                    let new_y = y + y_step;
                    let new_data = TurretGroupData::Straight {
                        y: new_y,
                        y_step: y_step,
                    };

                    let pos = Vector2::new(self.spec.offset.x, new_y);
                    (new_data, pos, Rad::atan2(pos.y, pos.x))
                },
            };
            let base_pos = Vector2::new(base_pos.x * (1. - self.spec.distance_ratio), base_pos.y);
            let pos_offset = Vector2::new(base_pos.x * cos - base_pos.y * sin,
                                          base_pos.x * sin + base_pos.y * cos);
            let state = turret.step(pos + pos_offset, angle + base_angle, 0., None, field, bullets, smokes, ship, rand);

            if state == TurretState::Alive {
                dead = false;
            }
            data = new_data;
        }

        if dead {
            TurretState::Dead
        } else {
            TurretState::Alive
        }
    }

    pub fn collides(&mut self, shot: &Shot, smokes: &mut Pool<Smoke>, sparks: &mut Pool<Spark>, fragments: &mut Pool<Fragment>, context: &mut GameStateContext, rand: &mut Rand) -> Vec<TurretScore> {
        self.turrets_mut()
            .iter_mut()
            .filter_map(|turret| turret.collides(shot, smokes, sparks, fragments, context, rand))
            // FIXME: Use `impl Iterator
            .collect()
    }

    pub fn destroy(&mut self) {
        self.turrets_mut()
            .par_iter_mut()
            .for_each(|turret| turret.destroy())
    }

    pub fn prep_draw(&mut self, rand: &mut Rand) {
        self.turrets_mut()
            .iter_mut()
            .foreach(|turret| turret.prep_draw(rand))
    }

    pub fn draw<R, C>(&self, context: &mut EncoderContext<R, C>, shape_draw: &ShapeDraw<R>, turret_draw: &TurretDraw<R>)
        where R: gfx::Resources,
              C: gfx::CommandBuffer<R>,
    {
        self.turrets()
            .iter()
            .foreach(|turret| turret.draw(context, shape_draw, turret_draw))
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TurretMovement {
    Roll,
    SwingFix,
    SwingAim,
}

#[derive(Debug, Clone, Copy)]
struct RollData {
    roll_velocity: Rad<f32>,
    roll_amplitude: Rad<f32>,
    roll_amplitude_velocity: Rad<f32>,
}

#[derive(Debug, Clone, Copy)]
struct SwingData {
    swing_velocity: Rad<f32>,
    swing_amplitude_velocity: Rad<f32>,
    aim: bool,
}

#[derive(Debug, Clone, Copy)]
enum MovingTurretData {
    Roll(RollData),
    Swing(SwingData),
}

impl MovingTurretData {
    fn roll(&self) -> Option<&RollData> {
        if let MovingTurretData::Roll(ref data) = *self {
            Some(data)
        } else {
            None
        }
    }

    fn swing(&self) -> Option<&SwingData> {
        if let MovingTurretData::Swing(ref data) = *self {
            Some(data)
        } else {
            None
        }
    }
}

#[derive(Debug, Clone, Copy)]
pub struct MovingTurretGroupSpec {
    spec: TurretSpec,
    data: MovingTurretData,
    count: u32,
    align: Rad<f32>,
    align_amplitude: f32,
    align_amplitude_velocity: Rad<f32>,
    radius_base: f32,
    radius_amplitude: f32,
    radius_amplitude_velocity: Rad<f32>,
    distance_ratio: f32,
    x_reverse: f32,
}

#[derive(Debug, Clone, Copy)]
pub struct MovingTurretGroupSpecBuilder {
    spec: MovingTurretGroupSpec,
}

impl MovingTurretGroupSpecBuilder {
    pub fn with_radius(&mut self, radius: f32) -> &mut Self {
        self.spec.radius_base = radius;
        self
    }

    pub fn with_count(&mut self, count: u32) -> &mut Self {
        self.spec.count = count;
        self
    }

    pub fn with_alignment(&mut self, align: Rad<f32>) -> &mut Self {
        self.spec.align = align;
        self
    }

    pub fn with_distance_ratio(&mut self, ratio: f32) -> &mut Self {
        self.spec.distance_ratio = ratio;
        self
    }

    pub fn with_align_amplitude(&mut self, amplitude: f32, velocity: Rad<f32>) -> &mut Self {
        self.spec.align_amplitude = amplitude;
        self.spec.align_amplitude_velocity = velocity;
        self
    }

    pub fn with_radius_amplitude(&mut self, amplitude: f32, velocity: Rad<f32>) -> &mut Self {
        self.spec.radius_amplitude = amplitude;
        self.spec.radius_amplitude_velocity = velocity;
        self
    }

    pub fn with_reverse_x(&mut self) -> &mut Self {
        self.spec.x_reverse = -1.;
        self
    }

    pub fn as_roll(&mut self, roll_velocity: Rad<f32>, amplitude: Rad<f32>, velocity: Rad<f32>) -> &mut Self {
        self.spec.data = MovingTurretData::Roll(RollData {
            roll_velocity: roll_velocity,
            roll_amplitude: amplitude,
            roll_amplitude_velocity: velocity,
        });
        self
    }

    pub fn as_swing(&mut self, swing_velocity: Rad<f32>, amplitude: Rad<f32>, aiming: bool) -> &mut Self {
        self.spec.data = MovingTurretData::Swing(SwingData {
            swing_velocity: swing_velocity,
            swing_amplitude_velocity: amplitude,
            aim: aiming,
        });
        self
    }

    pub fn init_spec(&mut self, rank: f32, kind: TurretKind, rand: &mut Rand) -> &mut Self {
        self.spec.spec.init(rank, kind, rand);
        self
    }

    pub fn as_boss(&mut self) -> &mut Self {
        self.spec.spec.as_boss();
        self
    }
}

impl Default for MovingTurretGroupSpecBuilder {
    fn default() -> Self {
        MovingTurretGroupSpecBuilder {
            spec: MovingTurretGroupSpec {
                spec: TurretSpec::new(),
                count: 1,
                align: Rad::full_turn(),
                align_amplitude: 0.,
                align_amplitude_velocity: Rad(0.),
                radius_base: 2.,
                radius_amplitude: 0.,
                radius_amplitude_velocity: Rad(0.),
                data: MovingTurretData::Roll(RollData {
                    roll_velocity: Rad(0.),
                    roll_amplitude: Rad(0.),
                    roll_amplitude_velocity: Rad(0.),
                }),
                distance_ratio: 0.,
                x_reverse: 1.,
            },
        }
    }
}

impl From<MovingTurretGroupSpecBuilder> for MovingTurretGroupSpec {
    fn from(builder: MovingTurretGroupSpecBuilder) -> Self {
        builder.spec
    }
}

#[derive(Debug, Clone, Copy)]
struct RollStateData {
    roll_amplitude: Rad<f32>,
}

#[derive(Debug, Clone, Copy)]
struct SwingStateData {
    swing_amplitude: Rad<f32>,
    swing_angle: Rad<f32>,
}

#[derive(Debug, Clone, Copy)]
enum MovingTurretStateData {
    Roll(RollStateData),
    Swing(SwingStateData),
}

impl MovingTurretStateData {
    fn new() -> Self {
        MovingTurretStateData::Roll(RollStateData {
            roll_amplitude: Rad(0.),
        })
    }
}

const MAX_MOVING_TURRET_GROUPS: usize = 16;

#[derive(Debug, Clone, Copy)]
pub struct MovingTurretGroup {
    spec: MovingTurretGroupSpec,
    radius: f32,
    radius_amplitude: Rad<f32>,
    angle: Rad<f32>,
    align_amplitude: Rad<f32>,
    data: MovingTurretStateData,
    turrets: [Turret; MAX_MOVING_TURRET_GROUPS],
}

impl MovingTurretGroup {
    pub fn new() -> Self {
        MovingTurretGroup {
            spec: MovingTurretGroupSpecBuilder::default().into(),
            radius: 0.,
            radius_amplitude: Rad(0.),
            angle: Rad(0.),
            align_amplitude: Rad(0.),
            data: MovingTurretStateData::new(),
            turrets: [Turret::new(); MAX_MOVING_TURRET_GROUPS],
        }
    }

    fn turrets(&self) -> &[Turret] {
        &self.turrets[0..self.spec.count as usize]
    }

    fn turrets_mut(&mut self) -> &mut [Turret] {
        &mut self.turrets[0..self.spec.count as usize]
    }

    pub fn init(&mut self, spec: MovingTurretGroupSpec, is_boss: bool, index: u32) {
        self.spec = spec;
        self.radius = spec.radius_base;
        self.radius_amplitude = Rad(0.);
        self.angle = Rad(0.);
        self.align_amplitude = Rad(0.);

        self.data = match spec.data {
            MovingTurretData::Roll(..) => {
                MovingTurretStateData::Roll(RollStateData {
                    roll_amplitude: Rad(0.),
                })
            },
            MovingTurretData::Swing(..) => {
                MovingTurretStateData::Swing(SwingStateData {
                    swing_amplitude: Rad(0.),
                    swing_angle: Rad(0.),
                })
            },
        };

        self.turrets_mut()
            .par_iter_mut()
            .for_each(|turret| turret.init(spec.spec.clone(), is_boss, index));
    }

    pub fn step(&mut self, pos: Vector2<f32>, step_angle: Rad<f32>, field: &Field, bullets: &mut Pool<Bullet>, smokes: &mut Pool<Smoke>, ship: &Ship, rand: &mut Rand) {
        if self.spec.radius_amplitude > 0. {
            self.radius_amplitude += self.spec.radius_amplitude_velocity;
            self.radius = self.spec.radius_base + self.spec.radius_amplitude * self.radius_amplitude.sin();
        }

        self.angle += match self.data {
            MovingTurretStateData::Roll(ref mut data) => {
                let spec_data = self.spec.data.roll()
                    .expect("expected the spec to have roll data");

                if spec_data.roll_amplitude.0 != 0. {
                    data.roll_amplitude += spec_data.roll_amplitude_velocity;
                    spec_data.roll_velocity + spec_data.roll_amplitude * data.roll_amplitude.sin()
                } else {
                    spec_data.roll_velocity
                }
            },
            MovingTurretStateData::Swing(ref mut data) => {
                let spec_data = self.spec.data.swing()
                    .expect("expected the spec to have swing data");

                data.swing_amplitude += spec_data.swing_amplitude_velocity;
                data.swing_angle += if data.swing_amplitude.cos() > 0. {
                    spec_data.swing_velocity
                } else {
                    -spec_data.swing_velocity
                };

                let base_angle = if spec_data.aim {
                    let ship_pos = ship.nearest_boat(pos).pos();
                    let offset_angle = if abagames_util::fast_distance(ship_pos, pos) < 0.1 {
                        Rad(0.)
                    } else {
                        let diff = ship_pos - pos;
                        Rad::atan2(diff.y, diff.x)
                    };
                    offset_angle
                } else {
                    step_angle
                };

                (base_angle + data.swing_angle - self.angle).normalize() * 0.1
            },
        };

        self.align_amplitude += self.spec.align_amplitude_velocity;
        let align = self.spec.align * (1. + self.align_amplitude.sin() * self.spec.align_amplitude);
        let angle_step = if self.spec.count > 1 {
            if let MovingTurretStateData::Roll(_) = self.data {
                align / (self.spec.count as f32)
            } else {
                align / ((self.spec.count - 1) as f32)
            }
        } else {
            Rad(0.)
        };

        let mut angle = self.angle - align / 2.;
        let offset = self.radius * Vector2::new(self.spec.x_reverse,
                                                1. - self.spec.distance_ratio);
        for turret in self.turrets[0..self.spec.count as usize].iter_mut() {
            let angle_comps: Vector2<f32> = angle.sin_cos().into();
            let b = angle_comps.mul_element_wise(offset);

            let (fire_speed, fire_angle) = if b.x.abs() + b.y.abs() < 0.1 {
                (self.radius, angle)
            } else {
                (b.distance((0., 0.).into()), Rad::atan2(b.y, b.x))
            };

            turret.step(pos, angle, fire_speed * 0.06, Some(fire_angle), field, bullets, smokes, ship, rand);

            angle += angle_step;
        }
    }

    pub fn destroy(&mut self) {
        self.turrets_mut()
            .par_iter_mut()
            .for_each(|turret| turret.destroy())
    }
}

gfx_defines! {
    constant TurretData {
        min_range: f32 = "min_range",
        max_range: f32 = "max_range",
        pos: [f32; 2] = "pos",
    }

    constant Color {
        color: [f32; 3] = "color",
    }

    constant Alpha {
        alpha: f32 = "alpha",
    }

    constant AlphaFactor {
        min_alpha: f32 = "min_alpha",
        max_alpha: f32 = "max_alpha",
    }

    constant SightAngle {
        angle: f32 = "angle",
    }

    constant NextAngle {
        next_angle: f32 = "next_angle",
    }

    vertex Vertex {
        minmax: f32 = "minmax",
        angle_choice: f32 = "angle_choice",
    }

    pipeline pipe {
        vbuf: gfx::VertexBuffer<Vertex> = (),
        turret: gfx::ConstantBuffer<TurretData> = "TurretData",
        color: gfx::ConstantBuffer<Color> = "Color",
        alpha: gfx::ConstantBuffer<Alpha> = "Alpha",
        alpha_factor: gfx::ConstantBuffer<AlphaFactor> = "AlphaFactor",
        angle: gfx::ConstantBuffer<SightAngle> = "SightAngle",
        next_angle: gfx::ConstantBuffer<NextAngle> = "NextAngle",
        screen: gfx::ConstantBuffer<ScreenTransform> = "Screen",
        brightness: gfx::ConstantBuffer<Brightness> = "Brightness",
        out_color: gfx::RenderTarget<TargetFormat> = "Target0",
    }
}

pub struct TurretDraw<R>
    where R: gfx::Resources,
{
    line_slice: gfx::Slice<R>,
    sweep_slice: gfx::Slice<R>,

    line_pso: gfx::PipelineState<R, <pipe::Data<R> as gfx::pso::PipelineData<R>>::Meta>,
    sweep_pso: gfx::PipelineState<R, <pipe::Data<R> as gfx::pso::PipelineData<R>>::Meta>,

    data: pipe::Data<R>,
}

impl<R> TurretDraw<R>
    where R: gfx::Resources,
{
    pub fn new<F>(factory: &mut F, view: gfx::handle::RenderTargetView<R, TargetFormat>,
                  context: &RenderContext<R>)
                  -> Self
        where F: gfx::Factory<R>,
    {
        let vertex_data = [
            Vertex { minmax: 0., angle_choice: 0., },
            Vertex { minmax: 1., angle_choice: 0., },
            Vertex { minmax: 1., angle_choice: 1., },
            Vertex { minmax: 0., angle_choice: 1., },
        ];
        let vbuf = factory.create_vertex_buffer(&vertex_data);

        let line_slice = abagames_util::slice_for_line::<R>(2);
        let sweep_slice = abagames_util::slice_for_fan::<R, F>(factory,
                                                               vertex_data.len() as u32);

        let program = factory.link_program(
            include_bytes!("shader/turret_sight.glslv"),
            include_bytes!("shader/turret_sight.glslf"))
            .expect("could not link the turret sight shader");
        let line_pso = factory.create_pipeline_from_program(
            &program,
            gfx::Primitive::LineStrip,
            gfx::state::Rasterizer {
                front_face: gfx::state::FrontFace::CounterClockwise,
                cull_face: gfx::state::CullFace::Nothing,
                method: gfx::state::RasterMethod::Line(1),
                offset: None,
                samples: None,
            },
            pipe::new())
            .expect("failed to create the line pipeline for turret sight");
        let sweep_pso = factory.create_pipeline_from_program(
            &program,
            gfx::Primitive::TriangleList,
            gfx::state::Rasterizer::new_fill(),
            pipe::new())
            .expect("failed to create the sweep pipeline for turret sight");

        let data = pipe::Data {
            vbuf: vbuf,
            turret: factory.create_constant_buffer(1),
            color: factory.create_constant_buffer(1),
            alpha: factory.create_constant_buffer(1),
            alpha_factor: factory.create_constant_buffer(1),
            angle: factory.create_constant_buffer(1),
            next_angle: factory.create_constant_buffer(1),
            screen: context.perspective_screen_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            out_color: view,
        };

        TurretDraw {
            line_slice: line_slice,
            sweep_slice: sweep_slice,

            line_pso: line_pso,
            sweep_pso: sweep_pso,

            data: data,
        }
    }

    fn draw_sight_line<C>(&self, context: &mut EncoderContext<R, C>, min_range: f32, max_range: f32, pos: Vector2<f32>, alpha: f32, angle: Rad<f32>)
        where C: gfx::CommandBuffer<R>,
    {
        let turret = TurretData {
            min_range: min_range,
            max_range: max_range,
            pos: pos.into(),
        };
        let color = Color {
            color: [0.9, 0.1, 0.1],
        };
        let alpha = Alpha {
            alpha: alpha,
        };
        let angle = SightAngle {
            angle: angle.0,
        };
        let alpha_factor = AlphaFactor {
            min_alpha: 1.,
            max_alpha: 0.5,
        };
        context.encoder.update_constant_buffer(&self.data.turret, &turret);
        context.encoder.update_constant_buffer(&self.data.color, &color);
        context.encoder.update_constant_buffer(&self.data.alpha, &alpha);
        context.encoder.update_constant_buffer(&self.data.angle, &angle);
        context.encoder.update_constant_buffer(&self.data.alpha_factor, &alpha_factor);

        context.encoder.draw(&self.line_slice, &self.line_pso, &self.data);
    }

    fn draw_sight_sweep<C>(&self, context: &mut EncoderContext<R, C>, min_range: f32, max_range: f32, pos: Vector2<f32>, alpha: f32, start_angle: Rad<f32>, angle_step: Rad<f32>, nway: i32)
        where C: gfx::CommandBuffer<R>,
    {
        let turret = TurretData {
            min_range: min_range,
            max_range: max_range,
            pos: pos.into(),
        };
        let alpha = Alpha {
            alpha: alpha,
        };
        context.encoder.update_constant_buffer(&self.data.turret, &turret);
        context.encoder.update_constant_buffer(&self.data.alpha, &alpha);

        let line_alpha_factor = AlphaFactor {
            min_alpha: 0.75,
            max_alpha: 0.25,
        };

        let angle = SightAngle {
            angle: start_angle.0,
        };
        context.encoder.update_constant_buffer(&self.data.angle, &angle);
        context.encoder.update_constant_buffer(&self.data.alpha_factor, &line_alpha_factor);

        context.encoder.draw(&self.line_slice, &self.line_pso, &self.data);

        let sweep_alpha_factor = AlphaFactor {
            min_alpha: 0.3,
            max_alpha: 0.05,
        };
        context.encoder.update_constant_buffer(&self.data.alpha_factor, &sweep_alpha_factor);

        let end_angle = (0..nway - 1)
            .fold(start_angle, |angle, _| {
                let next_angle = angle + angle_step;

                let angle = SightAngle {
                    angle: angle.0,
                };
                let next_angle_buf = NextAngle {
                    next_angle: next_angle.0,
                };
                context.encoder.update_constant_buffer(&self.data.angle, &angle);
                context.encoder.update_constant_buffer(&self.data.next_angle, &next_angle_buf);

                context.encoder.draw(&self.sweep_slice, &self.sweep_pso, &self.data);

                next_angle
            });

        let angle = SightAngle {
            angle: end_angle.0,
        };
        context.encoder.update_constant_buffer(&self.data.angle, &angle);
        context.encoder.update_constant_buffer(&self.data.alpha_factor, &line_alpha_factor);

        context.encoder.draw(&self.line_slice, &self.line_pso, &self.data);
    }
}
