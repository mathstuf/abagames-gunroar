// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

use crates::abagames_util::Rand;
use crates::cgmath::{Angle, Vector2, Rad};

use game::entities::shapes::bullet::BulletShapeKind;

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
                spec.turn_speed = 0.;
                spec.max_range = 0. + rand.next_float(12.);
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
                spec.turn_range = f32::consts::FRAC_PI_4 + rand.next_float(f32::consts::FRAC_PI_4);
                if kind == TurretKind::Main {
                    spec.turn_range *= 1.2;
                }
                spec.turn_speed = 0.005 * rand.next_float(0.015);
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

        spec.size = params.size_offset + params.size_range.map(|size_range| rand.next_float(size_range)).unwrap_or(0.);
        let br = rank * params.burst_factor * (1. + rand.next_float_signed(0.2));
        let nr = params.nway_factor
            .map(|nway_factor| rank * nway_factor * rand.next_float_signed(1.))
            .unwrap_or(1.);
        let ir = rank * params.interval_factor * (1. + rand.next_float_signed(0.2));
        spec.burst_num = (br as i32) + 1;
        spec.nway = (nr * 0.66 + 1.) as u32;
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
    kind: Option<TurretKind>,
    /// How often the turret fires a bullet.
    interval: i32,
    speed: f32,
    speed_accel: f32,
    min_range: f32,
    max_range: f32,
    turn_speed: f32,
    turn_range: f32,
    burst_num: i32,
    burst_interval: i32,
    burst_turn_ratio: f32,
    blind: bool,
    look_ahead_ratio: Option<f32>,
    nway: u32,
    nway_angle: Rad<f32>,
    nway_change: bool,
    bullet_shape: BulletShapeKind,
    bullet_destructive: bool,
    shield: u32,
    invisible: bool,
    size: f32,
}

impl TurretSpec {
    fn new() -> Self {
        TurretSpec {
            kind: None,
            interval: 99999,
            speed: 1.,
            speed_accel: 0.,
            min_range: 0.,
            max_range: 99999.,
            turn_speed: 99999.,
            turn_range: 99999.,
            burst_num: 1,
            burst_interval: 99999,
            burst_turn_ratio: 0.,
            blind: false,
            look_ahead_ratio: None,
            nway: 1,
            nway_angle: Rad(0.),
            nway_change: false,
            bullet_shape: BulletShapeKind::Normal,
            bullet_destructive: false,
            shield: 99999,
            invisible: false,
            size: 1.,
        }
    }

    fn init(&mut self, rank: f32, kind: TurretKind, rand: &mut Rand) {
        self.kind = Some(kind);

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

    pub fn as_boss(&mut self) {
        self.min_range = 0.;
        self.max_range *= 1.5;
        self.shield = ((self.shield as f32) * 2.1) as u32;
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
pub enum TurretMovement {
    Roll,
    SwingFix,
    SwingAim,
}

#[derive(Debug, Clone, Copy)]
enum MovingTurretData {
    Roll {
        roll_velocity: Rad<f32>,
        roll_amplitude: f32,
        roll_amplitude_velocity: f32,
    },
    Swing {
        swing_velocity: Rad<f32>,
        swing_amplitude_velocity: f32,
        aim: bool,
    },
}

#[derive(Debug, Clone, Copy)]
pub struct MovingTurretGroupSpec {
    spec: TurretSpec,
    impl_data: MovingTurretData,
    count: u32,
    align: Rad<f32>,
    align_amplitude: f32,
    align_amplitude_velocity: f32,
    radius_base: f32,
    radius_amplitude: f32,
    radius_amplitude_velocity: f32,
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

    pub fn with_align_amplitude(&mut self, amplitude: f32, velocity: f32) -> &mut Self {
        self.spec.align_amplitude = amplitude;
        self.spec.align_amplitude_velocity = velocity;
        self
    }

    pub fn with_radius_amplitude(&mut self, amplitude: f32, velocity: f32) -> &mut Self {
        self.spec.radius_amplitude = amplitude;
        self.spec.radius_amplitude_velocity = velocity;
        self
    }

    pub fn with_reverse_x(&mut self) -> &mut Self {
        self.spec.x_reverse = -1.;
        self
    }

    pub fn as_roll(&mut self, roll_velocity: Rad<f32>, amplitude: f32, velocity: f32) -> &mut Self {
        self.spec.impl_data = MovingTurretData::Roll {
            roll_velocity: roll_velocity,
            roll_amplitude: amplitude,
            roll_amplitude_velocity: velocity,
        };
        self
    }

    pub fn as_swing(&mut self, swing_velocity: Rad<f32>, amplitude: f32, aiming: bool) -> &mut Self {
        self.spec.impl_data = MovingTurretData::Swing {
            swing_velocity: swing_velocity,
            swing_amplitude_velocity: amplitude,
            aim: aiming,
        };
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
                align_amplitude_velocity: 0.,
                radius_base: 2.,
                radius_amplitude: 0.,
                radius_amplitude_velocity: 0.,
                impl_data: MovingTurretData::Roll {
                    roll_velocity: Rad(0.),
                    roll_amplitude: 0.,
                    roll_amplitude_velocity: 0.,
                },
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
