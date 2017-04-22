// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

use crates::abagames_util::Rand;

use game::entities::bullet::BulletShape;

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
                spec.bullet_shape = BulletShape::Small;
                spec.blind = true;
                spec.invisible = true;
                rank
            },
            TurretKind::Moving => {
                spec.min_range = 6.;
                spec.bullet_shape = BulletShape::MovingTurret;
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
                spec.bullet_shape = BulletShape::Destructive;
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
    bullet_shape: BulletShape,
    bullet_destructive: bool,
    shield: u32,
    invisible: bool,
    size: f32,
}

impl TurretSpec {
    fn new(rank: f32, kind: TurretKind, rand: &mut Rand) -> Self {
        let mut spec = Self::default();

        spec.kind = Some(kind);

        let rank = kind.init_spec_phase1(rank, &mut spec, rand);
        spec.burst_interval = (6 + rand.next_int(6)) as i32;
        kind.init_spec_phase2(rank, &mut spec, rand);

        spec.speed = if spec.speed < 0.1 {
             0.1
        } else {
            (10. * spec.speed).sqrt() / 10.
        };

        if spec.burst_num > 2 {
            if rand.next_int(4) == 0 {
                spec.speed *= 0.8;
                spec.burst_interval = (0.7 * (spec.burst_interval as f32)) as i32;
                spec.speed_accel = spec.speed * (0.4 + rand.next_float(0.3)) / (spec.burst_num as f32);
                if rand.next_int(2) == 0 {
                    spec.speed_accel *= -1.;
                }
                spec.speed -= spec.speed_accel * (spec.burst_num as f32) / 2.;
            }
            if rand.next_int(5) == 0 && spec.nway > 1 {
                spec.nway_change = true;
            }
        }

        spec.nway_angle = Rad(0.1 + rand.next_float(0.33)) / (1. + 0.1 * (spec.nway as f32));

        spec
    }

    fn new_dummy() -> Self {
        let mut spec = Self::default();
        spec.invisible = true;

        spec
    }

    pub fn into_boss(mut self) -> Self {
        self.min_range = 0.;
        self.max_range *= 1.5;
        self.shield = ((self.shield as f32) * 2.1) as u32;

        self
    }
}

impl Default for TurretSpec {
    fn default() -> Self {
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
            bullet_shape: BulletShape::Normal,
            bullet_destructive: false,
            shield: 99999,
            invisible: false,
            size: 1.,
        }
    }
}
