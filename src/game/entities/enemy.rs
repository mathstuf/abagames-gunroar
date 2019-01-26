// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying LICENSE file for details.

use crates::abagames_util::{self, Pool, PoolChainIter, PoolRemoval, Rand};
use crates::cgmath::{Angle, Matrix4, Rad, Vector2, Vector3};
use crates::gfx;
use crates::itertools::{FoldWhile, Itertools};
use crates::rayon::prelude::*;

use game::entities::bullet::Bullet;
use game::entities::crystal::Crystal;
use game::entities::field::{Field, FIELD_OUTER_SIZE, FIELD_SIZE};
use game::entities::letter::{self, Letter};
use game::entities::particles::{Fragment, Smoke, SmokeKind, Spark, SparkFragment, Wake};
use game::entities::reel::ScoreReel;
use game::entities::score_indicator::{FlyingTo, Indicator, ScoreIndicator, ScoreTarget};
use game::entities::shapes::enemy::EnemyShapes;
use game::entities::shapes::ShapeDraw;
use game::entities::ship::Ship;
use game::entities::shot::{Shot, SHOT_SPEED};
use game::entities::stage::Stage;
use game::entities::turret::{
    MovingTurretGroup, MovingTurretGroupSpec, MovingTurretGroupSpecBuilder, TurretDraw,
    TurretGroup, TurretGroupAlignment, TurretGroupSpec, TurretGroupSpecBuilder, TurretKind,
    TurretMovement, TurretState,
};
use game::render::EncoderContext;
use game::state::GameStateContext;

use std::cmp;
use std::f32;
use std::iter;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EnemyKind {
    SmallShip,
    Ship,
    Platform,
}

impl EnemyKind {
    fn is_ship(&self) -> bool {
        if let EnemyKind::Platform = *self {
            false
        } else {
            true
        }
    }

    fn is_small(&self) -> bool {
        if let EnemyKind::SmallShip = *self {
            true
        } else {
            false
        }
    }
}

const MAX_TURRET_GROUPS: usize = 10;
const MAX_MOVING_TURRET_GROUPS: usize = 4;

#[derive(Debug, Clone, Copy)]
struct BaseEnemySpec {
    kind: EnemyKind,
    distance_ratio: f32,

    shapes: EnemyShapes,

    turret_groups: [TurretGroupSpec; MAX_TURRET_GROUPS],
    num_turret_groups: usize,

    moving_turret_groups: [MovingTurretGroupSpec; MAX_MOVING_TURRET_GROUPS],
    num_moving_turret_groups: usize,
}

#[derive(Debug, Clone, Copy)]
struct MovingTurretAddData {
    align: Rad<f32>,
    rotate_velocity: Rad<f32>,
    amplitude: Rad<f32>,
    amplitude_velocity: Rad<f32>,
}

impl BaseEnemySpec {
    fn new() -> Self {
        BaseEnemySpec {
            kind: EnemyKind::SmallShip,
            distance_ratio: 0.,

            shapes: EnemyShapes::new(EnemyKind::SmallShip),

            turret_groups: [TurretGroupSpec::default(); MAX_TURRET_GROUPS],
            num_turret_groups: 0,

            moving_turret_groups: [MovingTurretGroupSpec::default(); MAX_MOVING_TURRET_GROUPS],
            num_moving_turret_groups: 0,
        }
    }

    fn init(&mut self, kind: EnemyKind) {
        self.kind = kind;
        self.distance_ratio = 0.;
        self.shapes = EnemyShapes::new(kind);

        self.num_turret_groups = 0;
        self.num_moving_turret_groups = 0;
    }

    fn add_moving_turret(&mut self, rank: f32, is_boss: bool, rand: &mut Rand) {
        let potential_moving_turrets = cmp::min((rank * 0.2) as usize, MAX_MOVING_TURRET_GROUPS);
        let num_moving_turrets = if potential_moving_turrets >= 2 {
            1 + rand.next_int((potential_moving_turrets - 1) as u32)
        } else {
            1
        };
        let br = rank / (num_moving_turrets as f32);
        let kind = if is_boss {
            TurretMovement::Roll
        } else {
            match rand.next_int(4) {
                0 | 1 => TurretMovement::Roll,
                2 => TurretMovement::SwingFix,
                3 => TurretMovement::SwingAim,
                _ => unreachable!(),
            }
        };

        let mut radius = 0.9 + rand.next_float(0.4) - (num_moving_turrets as f32) * 0.1;
        let radius_inc = 0.5 + rand.next_float(0.25);

        let mut data = match kind {
            TurretMovement::Roll => {
                MovingTurretAddData {
                    align: Rad::full_turn(),
                    rotate_velocity: Rad(0.01 + rand.next_float(0.04)),
                    amplitude: Rad(0.01 + rand.next_float(0.04)),
                    amplitude_velocity: Rad(0.01 + rand.next_float(0.03)),
                }
            },
            TurretMovement::SwingFix => {
                MovingTurretAddData {
                    align: Rad::turn_div_2() / 10. + Rad(rand.next_float(f32::consts::PI / 15.)),
                    rotate_velocity: Rad(0.01 + rand.next_float(0.02)),
                    amplitude: Rad(0.),
                    amplitude_velocity: Rad(0.01 + rand.next_float(0.03)),
                }
            },
            TurretMovement::SwingAim => {
                let vel = if rand.next_int(5) == 0 {
                    0.01 + rand.next_float(0.01)
                } else {
                    0.
                };
                MovingTurretAddData {
                    align: Rad::turn_div_2() / 10. + Rad(rand.next_float(f32::consts::PI / 15.)),
                    rotate_velocity: Rad(vel),
                    amplitude: Rad(0.),
                    amplitude_velocity: Rad(0.01 + rand.next_float(0.02)),
                }
            },
        };

        (0..num_moving_turrets).foreach(|_| {
            let mut builder = MovingTurretGroupSpecBuilder::default();
            builder.with_radius(radius);

            let turret_rank = match kind {
                TurretMovement::Roll => {
                    let count = 4 + rand.next_int(6);

                    builder.with_alignment(data.align).with_count(count);

                    if rand.next_int(2) == 0 {
                        if rand.next_int(2) == 0 {
                            builder.as_roll(data.rotate_velocity, Rad(0.), Rad(0.));
                        } else {
                            builder.as_roll(-data.rotate_velocity, Rad(0.), Rad(0.));
                        }
                    } else {
                        if rand.next_int(2) == 0 {
                            builder.as_roll(Rad(0.), data.amplitude, data.amplitude_velocity);
                        } else {
                            builder.as_roll(Rad(0.), -data.amplitude, data.amplitude_velocity);
                        }
                    }

                    if rand.next_int(3) == 0 {
                        builder.with_radius_amplitude(
                            1. + rand.next_float(1.),
                            Rad(0.01 + rand.next_float(0.03)),
                        );
                    }
                    if rand.next_int(2) == 0 {
                        builder.with_distance_ratio(0.8 + rand.next_float_signed(0.3));
                    }

                    br / (count as f32)
                },
                TurretMovement::SwingFix => {
                    let count = 3 + rand.next_int(5);

                    builder
                        .with_alignment(data.align * ((count as f32) * 0.1 + 0.3))
                        .with_count(count);

                    if rand.next_int(2) == 0 {
                        builder.as_swing(data.rotate_velocity, data.amplitude_velocity, false);
                    } else {
                        builder.as_swing(-data.rotate_velocity, data.amplitude_velocity, false);
                    }

                    if rand.next_int(6) == 0 {
                        builder.with_radius_amplitude(
                            1. + rand.next_float(1.),
                            Rad(0.01 + rand.next_float(0.03)),
                        );
                    }
                    if rand.next_int(4) == 0 {
                        builder.with_align_amplitude(
                            0.25 + rand.next_float(0.25),
                            Rad(0.01 + rand.next_float(0.02)),
                        );
                    }

                    br / (count as f32) * 0.6
                },
                TurretMovement::SwingAim => {
                    let count = 3 + rand.next_int(4);

                    builder
                        .with_alignment(data.align * ((count as f32) * 0.1 + 0.3))
                        .with_count(count);

                    if rand.next_int(2) == 0 {
                        builder.as_swing(data.rotate_velocity, data.amplitude_velocity, true);
                    } else {
                        builder.as_swing(-data.rotate_velocity, data.amplitude_velocity, true);
                    }

                    if rand.next_int(4) == 0 {
                        builder.with_radius_amplitude(
                            1. + rand.next_float(1.),
                            Rad(0.01 + rand.next_float(0.03)),
                        );
                    }
                    if rand.next_int(5) == 0 {
                        builder.with_align_amplitude(
                            0.25 + rand.next_float(0.25),
                            Rad(0.01 + rand.next_float(0.02)),
                        );
                    }

                    br / (count as f32) * 0.4
                },
            };

            if rand.next_int(4) == 0 {
                builder.with_reverse_x();
            }

            builder.init_spec(turret_rank, TurretKind::Moving, rand);

            if is_boss {
                builder.as_boss();
            }

            self.add_moving_turret_group(builder.into());

            radius += radius_inc;
            data.align *= 1. + rand.next_float_signed(0.2);
        });
    }

    fn recolor(&mut self, color_factor: f32) {
        let color = EnemyShapes::color(color_factor);
        self.shapes.set_color(color);
        self.turret_groups[0..self.num_turret_groups]
            .par_iter_mut()
            .for_each(|group| group.set_color(color));
    }

    fn add_turret_group(&mut self, spec: TurretGroupSpec) {
        self.turret_groups[self.num_turret_groups] = spec;
        self.num_turret_groups += 1;
    }

    fn add_moving_turret_group(&mut self, spec: MovingTurretGroupSpec) {
        self.moving_turret_groups[self.num_moving_turret_groups] = spec;
        self.num_moving_turret_groups += 1;
    }
}

#[derive(Debug, Clone, Copy)]
struct StopAndGoMovement {
    accel: f32,
    max_speed: f32,
    stay_speed: f32,
    move_duration: u32,
    stay_duration: u32,
}

#[derive(Debug, Clone, Copy)]
struct ChaseMovement {
    speed: f32,
    turn_velocity: Rad<f32>,
}

#[derive(Debug, Clone, Copy)]
enum SmallShipMovement {
    StopAndGo(StopAndGoMovement),
    Chase(ChaseMovement),
}

impl SmallShipMovement {
    fn speed(&self) -> f32 {
        match *self {
            SmallShipMovement::StopAndGo(..) => 0.,
            SmallShipMovement::Chase(chase) => chase.speed,
        }
    }

    fn mode(&self) -> SmallShipMode {
        match *self {
            SmallShipMovement::StopAndGo(..) => {
                SmallShipMode::StopAndGo {
                    state: SmallShipMoveState::Moving,
                }
            },
            SmallShipMovement::Chase(..) => SmallShipMode::Chase,
        }
    }

    fn stop_and_go(&self) -> Option<&StopAndGoMovement> {
        if let SmallShipMovement::StopAndGo(ref data) = *self {
            Some(data)
        } else {
            None
        }
    }

    fn chase(&self) -> Option<&ChaseMovement> {
        if let SmallShipMovement::Chase(ref data) = *self {
            Some(data)
        } else {
            None
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum SmallShipMoveState {
    Staying,
    Moving,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ShipClass {
    Middle,
    Large,
    Boss,
}

impl ShipClass {
    fn score(&self) -> u32 {
        match *self {
            ShipClass::Middle => 100,
            ShipClass::Large => 300,
            ShipClass::Boss => 1000,
        }
    }

    fn is_large(&self) -> bool {
        ShipClass::Large == *self
    }

    fn is_boss(&self) -> bool {
        ShipClass::Boss == *self
    }
}

#[derive(Debug, Clone, Copy)]
struct SmallShipData {
    movement: SmallShipMovement,
}

#[derive(Debug, Clone, Copy)]
struct ShipData {
    class: ShipClass,
    speed: f32,
    turn_velocity: Rad<f32>,
}

#[derive(Debug, Clone, Copy)]
enum EnemySpecData {
    SmallShip(SmallShipData),
    Ship(ShipData),
    Platform,
}

impl EnemySpecData {
    fn score(&self) -> u32 {
        match *self {
            EnemySpecData::SmallShip(..) => 50,
            EnemySpecData::Ship(data) => data.class.score(),
            EnemySpecData::Platform => 100,
        }
    }

    fn is_large(&self) -> bool {
        if let EnemySpecData::Ship(ref data) = *self {
            data.class.is_large()
        } else {
            false
        }
    }

    fn is_boss(&self) -> bool {
        if let EnemySpecData::Ship(ref data) = *self {
            data.class.is_boss()
        } else {
            false
        }
    }

    fn small_ship(&self) -> Option<&SmallShipData> {
        if let EnemySpecData::SmallShip(ref data) = *self {
            Some(data)
        } else {
            None
        }
    }

    fn ship(&self) -> Option<&ShipData> {
        if let EnemySpecData::Ship(ref data) = *self {
            Some(data)
        } else {
            None
        }
    }
}

#[derive(Debug, Clone, Copy)]
pub struct EnemySpec {
    spec: BaseEnemySpec,
    spec_data: EnemySpecData,

    size: f32,
    bridge_size: f32,
    shield: u32,
}

#[derive(Debug, Clone, Copy)]
struct ShipTurretCount {
    main: u32,
    sub: u32,
    size: f32,
    rank: f32,
    moving_ratio: f32,
    speed: f32,
    turn_velocity: Rad<f32>,
}

#[derive(Debug, Clone, Copy)]
struct PlatformTurretCount {
    main: u32,
    front: u32,
    side: u32,
    rank: f32,
    moving_ratio: f32,
}

impl EnemySpec {
    pub fn new() -> Self {
        EnemySpec {
            spec: BaseEnemySpec::new(),
            spec_data: EnemySpecData::Platform,
            size: 0.,
            bridge_size: 0.,
            shield: 0,
        }
    }

    pub fn small_ship(rank: f32, rand: &mut Rand) -> Self {
        let mut spec = EnemySpec::new();
        spec.init_small_ship(rank, rand);
        spec
    }

    pub fn ship(rank: f32, class: ShipClass, ship: &Ship, rand: &mut Rand) -> Self {
        let mut spec = EnemySpec::new();
        spec.init_ship(rank, class, ship, rand);
        spec
    }

    fn resize(&mut self, size: f32) -> &mut Self {
        self.size = size;
        self.bridge_size = 0.9 * (1. - self.spec.distance_ratio);
        self
    }

    fn init_small_ship(&mut self, rank: f32, rand: &mut Rand) {
        self.spec.init(EnemyKind::SmallShip);
        self.spec.distance_ratio = 0.5;

        let speed_factor = f32::min(25., rand.next_float(rank * 0.8));
        self.spec_data = EnemySpecData::SmallShip(SmallShipData {
            movement: if rand.next_int(2) == 0 {
                self.resize(0.47 + rand.next_float(0.1));
                SmallShipMovement::StopAndGo(StopAndGoMovement {
                    accel: 0.5 - 0.5 / (2. + rand.next_float(rank)),
                    max_speed: 0.05 * (1. + speed_factor),
                    stay_speed: 0.03,
                    move_duration: (32 + rand.next_int_signed(12)) as u32,
                    stay_duration: (32 + rand.next_int_signed(12)) as u32,
                })
            } else {
                self.resize(0.5 + rand.next_float(0.1));
                SmallShipMovement::Chase(ChaseMovement {
                    speed: 0.036 * (1. + speed_factor),
                    turn_velocity: Rad(0.02 + rand.next_float_signed(0.04)),
                })
            },
        });

        let mut builder = TurretGroupSpecBuilder::default();
        builder.init_spec(rank - speed_factor * 0.5, TurretKind::Small, rand);
        self.spec.add_turret_group(builder.into());
    }

    fn init_ship(&mut self, rank: f32, class: ShipClass, ship: &Ship, rand: &mut Rand) {
        self.spec.init(EnemyKind::Ship);
        self.spec.distance_ratio = 0.7;

        let count = match class {
            ShipClass::Middle => {
                let try_size = 1.5 + rank / 15. + rand.next_float(rank / 15.);
                let max_size = 2. + rand.next_float(0.5);
                let size = f32::min(max_size, try_size);

                let speed = 0.015 + rand.next_float_signed(0.005);
                let turn_vel = Rad(0.005 + rand.next_float_signed(0.003));

                let (main, sub, turret_rank, moving_ratio) = match rand.next_int(3) {
                    0 => {
                        let main = (size * (1. + rand.next_float_signed(0.25)) + 1.) as u32;
                        (main, 0, rank, 0.)
                    },
                    1 => {
                        let sub = (size * 1.6 * (1. + rand.next_float_signed(0.5)) + 2.) as u32;
                        (0, sub, rank, 0.)
                    },
                    2 => {
                        let ratio = 0.5 + rand.next_float(0.25);
                        let main = (size * (0.5 + rand.next_float_signed(0.12)) + 1.) as u32;
                        (main, 0, rank * (1. - ratio), 2. * ratio)
                    },
                    _ => unreachable!(),
                };

                ShipTurretCount {
                    main: main,
                    sub: sub,
                    size: size,
                    rank: turret_rank,
                    moving_ratio: moving_ratio,
                    speed: speed,
                    turn_velocity: turn_vel,
                }
            },
            ShipClass::Large => {
                let try_size = 2.5 + rank / 24. + rand.next_float(rank / 24.);
                let max_size = 3. + rand.next_float(1.);
                let size = f32::min(max_size, try_size);

                let speed = 0.01 + rand.next_float_signed(0.005);
                let turn_vel = Rad(0.003 + rand.next_float_signed(0.002));
                let main = (size * (0.7 + rand.next_float_signed(0.2)) + 1.) as u32;
                let sub = (size * 1.6 * (0.7 + rand.next_float_signed(0.33)) + 2.) as u32;
                let ratio = 0.25 + rand.next_float(0.5);

                ShipTurretCount {
                    main: main,
                    sub: sub,
                    size: size,
                    rank: rank * (1. - ratio),
                    moving_ratio: 3. * ratio,
                    speed: speed,
                    turn_velocity: turn_vel,
                }
            },
            ShipClass::Boss => {
                let try_size = 5. + rank / 30. + rand.next_float(rank / 30.);
                let max_size = 9. + rand.next_float(3.);
                let size = f32::min(max_size, try_size);

                let speed = ship.scroll_speed_base() + 0.0025 + rand.next_float_signed(0.001);
                let turn_vel = Rad(0.003 + rand.next_float_signed(0.002));
                let main = (size * 0.8 * (1.5 + rand.next_float_signed(0.4)) + 2.) as u32;
                let sub = (size * 0.8 * (2.4 + rand.next_float_signed(0.6)) + 2.) as u32;
                let ratio = 0.2 + rand.next_float(0.3);

                ShipTurretCount {
                    main: main,
                    sub: sub,
                    size: size,
                    rank: rank * (1. - ratio),
                    moving_ratio: 2.5 * ratio,
                    speed: speed,
                    turn_velocity: turn_vel,
                }
            },
        };
        self.resize(count.size);
        self.spec_data = EnemySpecData::Ship(ShipData {
            class: class,
            speed: count.speed,
            turn_velocity: count.turn_velocity,
        });
        self.shield = (count.size * 10.) as u32;
        if class.is_boss() {
            self.shield = ((self.shield as f32) * 2.4) as u32;
        }

        if count.main + count.sub > 0 {
            let sub_turret_rank = count.rank / ((3 * count.main + count.sub) as f32);
            let main_turret_rank = sub_turret_rank * 2.5;
            if class.is_boss() {
                if count.main > 0 {
                    let main_turret_rank = main_turret_rank * 2.5;

                    let angles = [
                        -Rad::full_turn() / 8.,
                        Rad::full_turn() / 8.,
                        Rad::full_turn() * 3. / 8.,
                        Rad::full_turn() * 5. / 8.,
                    ];

                    let num_front_main_turret = (count.main + 2) / 4;
                    if 0 < num_front_main_turret {
                        let mut builder = TurretGroupSpecBuilder::default();
                        builder
                            .init_spec(main_turret_rank, TurretKind::Main, rand)
                            .with_count(num_front_main_turret)
                            .with_alignment(TurretGroupAlignment::Round)
                            .with_sized_alignment(
                                angles[0],
                                f32::consts::FRAC_PI_6 + rand.next_float(f32::consts::FRAC_PI_8),
                            )
                            .with_radius(count.size * 0.45)
                            .with_distance_ratio(self.spec.distance_ratio);
                        let mut mirror = builder;
                        mirror.with_sized_alignment(
                            angles[1],
                            f32::consts::FRAC_PI_6 + rand.next_float(f32::consts::FRAC_PI_8),
                        );
                        self.spec.add_turret_group(builder.into());
                        self.spec.add_turret_group(mirror.into());

                        if num_front_main_turret * 2 + 1 <= count.main {
                            let num_rear_main_turret = (count.main - num_front_main_turret * 2) / 2;
                            builder
                                .init_spec(main_turret_rank, TurretKind::Main, rand)
                                .with_count(num_rear_main_turret)
                                .with_alignment(TurretGroupAlignment::Round)
                                .with_sized_alignment(
                                    angles[2],
                                    f32::consts::FRAC_PI_6
                                        + rand.next_float(f32::consts::FRAC_PI_8),
                                )
                                .with_radius(count.size * 0.45)
                                .with_distance_ratio(self.spec.distance_ratio);
                            let mut mirror = builder;
                            mirror.with_sized_alignment(
                                angles[3],
                                f32::consts::FRAC_PI_6 + rand.next_float(f32::consts::FRAC_PI_8),
                            );
                            self.spec.add_turret_group(builder.into());
                            self.spec.add_turret_group(mirror.into());
                        }
                    }
                }

                if count.sub > 0 {
                    let sub_turret_rank = sub_turret_rank * 2.;

                    let angles = [
                        Rad::full_turn() / 8.,
                        -Rad::full_turn() / 8.,
                        Rad::turn_div_4(),
                        -Rad::turn_div_4(),
                        Rad::full_turn() * 3. / 8.,
                        -Rad::full_turn() * 3. / 8.,
                    ];

                    let num_front_sub_turret = (count.sub + 2) / 6;
                    let turret_kind = if rand.next_int(2) == 0 {
                        TurretKind::Sub
                    } else {
                        TurretKind::SubDestructive
                    };
                    let mut builder = TurretGroupSpecBuilder::default();
                    builder
                        .init_spec(sub_turret_rank, turret_kind, rand)
                        .as_boss()
                        .with_count(num_front_sub_turret)
                        .with_alignment(TurretGroupAlignment::Round)
                        .with_sized_alignment(
                            angles[0],
                            f32::consts::PI / 7. + rand.next_float(f32::consts::PI / 9.),
                        )
                        .with_radius(count.size * 0.75)
                        .with_distance_ratio(self.spec.distance_ratio);
                    let mut mirror = builder;
                    mirror.with_sized_alignment(
                        angles[1],
                        f32::consts::PI / 7. + rand.next_float(f32::consts::PI / 9.),
                    );
                    self.spec.add_turret_group(builder.into());
                    self.spec.add_turret_group(mirror.into());

                    if num_front_sub_turret * 2 + 3 <= count.sub {
                        let num_mid_sub_turret = (count.sub - num_front_sub_turret * 2) / 4;
                        let turret_kind = if rand.next_int(2) == 0 {
                            TurretKind::Sub
                        } else {
                            TurretKind::SubDestructive
                        };
                        let mut builder = TurretGroupSpecBuilder::default();
                        builder
                            .init_spec(sub_turret_rank, turret_kind, rand)
                            .as_boss()
                            .with_count(num_mid_sub_turret)
                            .with_alignment(TurretGroupAlignment::Round)
                            .with_sized_alignment(
                                angles[2],
                                f32::consts::PI / 7. + rand.next_float(f32::consts::PI / 9.),
                            )
                            .with_radius(count.size * 0.75)
                            .with_distance_ratio(self.spec.distance_ratio);
                        let mut mirror = builder;
                        mirror.with_sized_alignment(
                            angles[3],
                            f32::consts::PI / 7. + rand.next_float(f32::consts::PI / 9.),
                        );
                        self.spec.add_turret_group(builder.into());
                        self.spec.add_turret_group(mirror.into());

                        if (num_front_sub_turret + num_mid_sub_turret) * 2 + 1 <= count.sub {
                            let num_rear_sub_turret =
                                (count.sub - (num_front_sub_turret + num_mid_sub_turret) * 2) / 2;
                            let turret_kind = if rand.next_int(2) == 0 {
                                TurretKind::Sub
                            } else {
                                TurretKind::SubDestructive
                            };
                            let mut builder = TurretGroupSpecBuilder::default();
                            builder
                                .init_spec(sub_turret_rank, turret_kind, rand)
                                .as_boss()
                                .with_count(num_rear_sub_turret)
                                .with_alignment(TurretGroupAlignment::Round)
                                .with_sized_alignment(
                                    angles[4],
                                    f32::consts::PI / 7. + rand.next_float(f32::consts::PI / 9.),
                                )
                                .with_radius(count.size * 0.75)
                                .with_distance_ratio(self.spec.distance_ratio);
                            let mut mirror = builder;
                            mirror.with_sized_alignment(
                                angles[5],
                                f32::consts::PI / 7. + rand.next_float(f32::consts::PI / 9.),
                            );
                            self.spec.add_turret_group(builder.into());
                            self.spec.add_turret_group(mirror.into());
                        }
                    }
                }
            } else {
                let num_front_main_turret = count.main / 2;
                if 0 < num_front_main_turret {
                    let mut builder = TurretGroupSpecBuilder::default();
                    builder
                        .init_spec(main_turret_rank, TurretKind::Main, rand)
                        .with_count(num_front_main_turret)
                        .with_alignment(TurretGroupAlignment::Straight)
                        .with_y_offset(-count.size * (0.9 + rand.next_float_signed(0.05)));
                    self.spec.add_turret_group(builder.into());
                }

                if num_front_main_turret < count.main {
                    let num_rear_main_turret = count.main - num_front_main_turret;
                    let mut builder = TurretGroupSpecBuilder::default();
                    builder
                        .init_spec(main_turret_rank, TurretKind::Main, rand)
                        .with_count(num_rear_main_turret)
                        .with_alignment(TurretGroupAlignment::Straight)
                        .with_y_offset(count.size * (0.9 + rand.next_float_signed(0.05)));
                    self.spec.add_turret_group(builder.into());
                }

                if count.sub > 0 {
                    let angles = [
                        -Rad::full_turn() / 8.,
                        Rad::full_turn() / 8.,
                        Rad::full_turn() * 3. / 8.,
                        Rad::full_turn() * 5. / 8.,
                    ];

                    let num_front_sub_turret = (count.sub + 2) / 4;
                    if 0 < num_front_sub_turret {
                        let turret_kind = if rand.next_int(2) == 0 {
                            TurretKind::Sub
                        } else {
                            TurretKind::SubDestructive
                        };
                        let mut builder = TurretGroupSpecBuilder::default();
                        builder
                            .init_spec(sub_turret_rank, turret_kind, rand)
                            .with_count(num_front_sub_turret)
                            .with_alignment(TurretGroupAlignment::Round)
                            .with_sized_alignment(
                                angles[0],
                                f32::consts::FRAC_PI_6 + rand.next_float(f32::consts::FRAC_PI_8),
                            )
                            .with_radius(count.size * 0.75)
                            .with_distance_ratio(self.spec.distance_ratio);
                        let mut mirror = builder;
                        mirror.with_sized_alignment(
                            angles[1],
                            f32::consts::FRAC_PI_6 + rand.next_float(f32::consts::FRAC_PI_8),
                        );
                        self.spec.add_turret_group(builder.into());
                        self.spec.add_turret_group(mirror.into());

                        if num_front_sub_turret * 2 + 1 <= count.sub {
                            let turret_kind = if rand.next_int(2) == 0 {
                                TurretKind::Sub
                            } else {
                                TurretKind::SubDestructive
                            };
                            let num_rear_sub_turret = (count.sub - num_front_sub_turret * 2) / 2;
                            builder
                                .init_spec(sub_turret_rank, turret_kind, rand)
                                .with_count(num_rear_sub_turret)
                                .with_alignment(TurretGroupAlignment::Round)
                                .with_sized_alignment(
                                    angles[2],
                                    f32::consts::FRAC_PI_6
                                        + rand.next_float(f32::consts::FRAC_PI_8),
                                )
                                .with_radius(count.size * 0.75)
                                .with_distance_ratio(self.spec.distance_ratio);
                            let mut mirror = builder;
                            mirror.with_sized_alignment(
                                angles[3],
                                f32::consts::FRAC_PI_6 + rand.next_float(f32::consts::FRAC_PI_8),
                            );
                            self.spec.add_turret_group(builder.into());
                            self.spec.add_turret_group(mirror.into());
                        }
                    }
                }
            }
        }

        if count.moving_ratio > 0. {
            self.spec
                .add_moving_turret(rank * count.moving_ratio, class.is_boss(), rand);
        }
    }

    pub fn init_platform(&mut self, rank: f32, rand: &mut Rand) {
        self.spec.init(EnemyKind::Platform);
        self.spec.distance_ratio = 0.;
        self.spec_data = EnemySpecData::Platform;

        let try_size = 1. + rank / 30. + rand.next_float(rank / 30.);
        let max_size = 1. + rand.next_float(0.25);
        let size = f32::min(max_size, try_size);
        self.resize(size);

        let count = match rand.next_int(3) {
            0 => {
                let ratio = 0.33 + rand.next_float(0.46);
                PlatformTurretCount {
                    main: 0,
                    front: (size * (2. + rand.next_float_signed(0.5)) + 1.) as u32,
                    side: 0,
                    rank: rank * (1. - ratio),
                    moving_ratio: ratio * 2.5,
                }
            },
            1 => {
                PlatformTurretCount {
                    main: 0,
                    front: (size * (0.5 + rand.next_float_signed(0.2)) + 1.) as u32,
                    side: 2 * ((size * (0.5 + rand.next_float_signed(0.2)) + 1.) as u32),
                    rank: rank,
                    moving_ratio: 0.,
                }
            },
            2 => {
                PlatformTurretCount {
                    main: (size * (1. + rand.next_float_signed(0.33)) + 1.) as u32,
                    front: 0,
                    side: 0,
                    rank: rank,
                    moving_ratio: 0.,
                }
            },
            _ => unreachable!(),
        };
        self.shield = (size * 20.) as u32;
        let sub_turret_num = count.front + count.side;
        let sub_turret_rank = count.rank / ((count.main * 3 + sub_turret_num) as f32);
        let main_turret_rank = sub_turret_rank * 2.5;

        if count.main > 0 {
            let mut builder = TurretGroupSpecBuilder::default();
            builder
                .init_spec(main_turret_rank, TurretKind::Main, rand)
                .with_count(count.main)
                .with_alignment(TurretGroupAlignment::Round)
                .with_sized_alignment(
                    Rad(0.),
                    f32::consts::PI * 0.66 + rand.next_float(f32::consts::FRAC_PI_2),
                )
                .with_radius(size * 0.7)
                .with_distance_ratio(self.spec.distance_ratio);
            self.spec.add_turret_group(builder.into());
        }

        if count.front > 0 {
            let mut builder = TurretGroupSpecBuilder::default();
            builder
                .init_spec(sub_turret_rank, TurretKind::Sub, rand)
                .with_count(count.front)
                .with_alignment(TurretGroupAlignment::Round)
                .with_sized_alignment(
                    Rad(0.),
                    f32::consts::PI / 5. + rand.next_float(f32::consts::FRAC_PI_6),
                )
                .with_radius(size * 0.8)
                .with_distance_ratio(self.spec.distance_ratio);
            self.spec.add_turret_group(builder.into());
        }

        let side_turret_count = count.side / 2;
        if side_turret_count > 0 {
            let mut builder = TurretGroupSpecBuilder::default();
            builder
                .init_spec(sub_turret_rank, TurretKind::Sub, rand)
                .with_count(side_turret_count)
                .with_alignment(TurretGroupAlignment::Round)
                .with_sized_alignment(
                    Rad::turn_div_4(),
                    f32::consts::PI / 5. + rand.next_float(f32::consts::FRAC_PI_6),
                )
                .with_radius(size * 0.75)
                .with_distance_ratio(self.spec.distance_ratio);
            let mut mirror = builder;
            mirror.with_sized_alignment(
                -Rad::turn_div_4(),
                f32::consts::PI / 5. + rand.next_float(f32::consts::FRAC_PI_6),
            );
            self.spec.add_turret_group(builder.into());
            self.spec.add_turret_group(mirror.into());
        }

        if count.moving_ratio > 0. {
            self.spec
                .add_moving_turret(rank * count.moving_ratio, false, rand);
        }
    }

    pub fn turret_group_specs(&self) -> &[TurretGroupSpec] {
        &self.spec.turret_groups[0..self.spec.num_turret_groups]
    }

    pub fn moving_turret_group_specs(&self) -> &[MovingTurretGroupSpec] {
        &self.spec.moving_turret_groups[0..self.spec.num_moving_turret_groups]
    }

    fn shield(&self) -> u32 {
        self.shield
    }

    fn distance_ratio(&self) -> f32 {
        self.spec.distance_ratio
    }

    fn score(&self) -> u32 {
        self.spec_data.score()
    }

    fn is_large(&self) -> bool {
        self.spec_data.is_large()
    }

    fn is_boss(&self) -> bool {
        self.spec_data.is_boss()
    }
}

const MULTIPLIER_DECREASE_RATIO: f32 = 0.005;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EnemyAppearance {
    Top,
    Side,
    Center,
}

#[derive(Debug, Clone, Copy)]
enum SmallShipMode {
    Chase,
    StopAndGo { state: SmallShipMoveState },
}

#[derive(Debug, Clone, Copy)]
struct ShipTurn {
    turn_direction: TurnDirection,
    turn_velocity: Rad<f32>,
}

#[derive(Debug, Clone, Copy)]
struct BossTurn {
    target_angle: Rad<f32>,
    turn_count: u32,
}

impl BossTurn {
    fn new(rand: &mut Rand) -> Self {
        let angle = Rad(rand.next_float(0.1) + 0.1);
        let factor = if rand.next_int(2) == 0 { -1. } else { 1. };

        BossTurn {
            target_angle: angle * factor,
            turn_count: 250 + rand.next_int(150),
        }
    }
}

#[derive(Debug, Clone, Copy)]
enum TurnDirection {
    Clockwise,
    CounterClockwise,
}

impl TurnDirection {
    fn from_pos(pos: Vector2<f32>) -> Self {
        if pos.x < 0. {
            TurnDirection::CounterClockwise
        } else {
            TurnDirection::Clockwise
        }
    }

    fn factor(&self) -> f32 {
        match *self {
            TurnDirection::CounterClockwise => -1.,
            TurnDirection::Clockwise => 1.,
        }
    }
}

#[derive(Debug, Clone, Copy)]
struct DestroyData {
    count: u32,
    explode_count: u32,
    explode_interval: u32,
}

impl DestroyData {
    const fn new() -> Self {
        DestroyData {
            count: 0,
            explode_count: 1,
            explode_interval: 3,
        }
    }

    fn step(&mut self, rand: &mut Rand) -> Option<u32> {
        self.count = self.count.saturating_add(1);
        self.explode_count = self.explode_count.saturating_sub(1);

        if self.explode_count == 0 {
            self.explode_interval =
                (((self.explode_interval + 2) as f32) * (1.2 + rand.next_float(1.))) as u32;
            self.explode_count = self.explode_interval + 1;
            Some(self.explode_interval)
        } else {
            None
        }
    }
}

#[derive(Debug, Clone, Copy)]
struct SmallShipStateData {
    speed: f32,
    velocity_angle: Rad<f32>,
    count: u32,
    mode: SmallShipMode,
}

#[derive(Debug, Clone, Copy)]
enum ShipTurnStateData {
    Ship(ShipTurn),
    Boss(BossTurn),
}

#[derive(Debug, Clone, Copy)]
struct ShipStateData {
    speed: f32,
    wake_count: u32,
    destroyed: Option<DestroyData>,
    turn_data: ShipTurnStateData,
}

#[derive(Debug, Clone, Copy)]
struct PlatformStateData {
    destroyed: Option<DestroyData>,
}

#[derive(Debug, Clone, Copy)]
enum EnemyStateData {
    SmallShip(SmallShipStateData),
    Ship(ShipStateData),
    Platform(PlatformStateData),
}

impl EnemyStateData {
    const fn new() -> Self {
        EnemyStateData::Platform(PlatformStateData {
            destroyed: None,
        })
    }

    fn is_ok(&self) -> bool {
        self.destroyed().is_none()
    }

    fn destroy(&mut self) -> bool {
        match *self {
            EnemyStateData::SmallShip(..) => false,
            EnemyStateData::Ship(ShipStateData {
                ref mut destroyed, ..
            })
            | EnemyStateData::Platform(PlatformStateData {
                ref mut destroyed, ..
            }) => {
                *destroyed = Some(DestroyData::new());
                true
            },
        }
    }

    fn destroyed(&self) -> Option<DestroyData> {
        match *self {
            EnemyStateData::SmallShip(..) => None,
            EnemyStateData::Ship(ShipStateData {
                destroyed, ..
            })
            | EnemyStateData::Platform(PlatformStateData {
                destroyed,
            }) => destroyed,
        }
    }

    fn destroyed_mut(&mut self) -> Option<&mut DestroyData> {
        match *self {
            EnemyStateData::SmallShip(..) => None,
            EnemyStateData::Ship(ShipStateData {
                ref mut destroyed, ..
            })
            | EnemyStateData::Platform(PlatformStateData {
                ref mut destroyed,
            }) => destroyed.as_mut(),
        }
    }
}

const SINK_INTERVAL: u32 = 120;

#[derive(Debug, Clone, Copy)]
pub struct EnemyState {
    index: u32,
    data: EnemyStateData,
    shield: u32,
    pub pos: Vector2<f32>,
    prev_pos: Vector2<f32>,
    angle: Rad<f32>,
    damaged: bool,
    damaged_count: u32,
    multiplier: f32,

    turret_groups: [TurretGroup; MAX_TURRET_GROUPS],
    num_turret_groups: usize,

    moving_turret_groups: [MovingTurretGroup; MAX_MOVING_TURRET_GROUPS],
    num_moving_turret_groups: usize,
}

impl EnemyState {
    fn new() -> Self {
        EnemyState {
            index: 0,
            data: EnemyStateData::new(),
            shield: 0,
            pos: Vector2::new(0., 0.),
            prev_pos: Vector2::new(0., 0.),
            angle: Rad(0.),
            damaged: false,
            damaged_count: 0,
            multiplier: 1.,

            turret_groups: [TurretGroup::new(); MAX_TURRET_GROUPS],
            num_turret_groups: 0,

            moving_turret_groups: [MovingTurretGroup::new(); MAX_MOVING_TURRET_GROUPS],
            num_moving_turret_groups: 0,
        }
    }

    pub fn appear(
        spec: &EnemySpec,
        appearance: EnemyAppearance,
        field: &Field,
        enemies: &Pool<Enemy>,
        rand: &mut Rand,
    ) -> Option<Self> {
        assert!(spec.spec.kind.is_ship());

        let mut state = Self::new();

        let can_spawn = (0..8).any(|_| {
            let (pos, angle) = match appearance {
                EnemyAppearance::Top => {
                    let pos = Vector2::new(
                        rand.next_float_signed(FIELD_SIZE.x),
                        FIELD_OUTER_SIZE.x * 0.99 + spec.size,
                    );
                    let angle = if pos.x < 0. {
                        Rad::turn_div_2() - Rad(rand.next_float(0.5))
                    } else {
                        Rad::turn_div_2() + Rad(rand.next_float(0.5))
                    };

                    (pos, angle)
                },
                EnemyAppearance::Side => {
                    let factor = if rand.next_int(2) == 0 { 1. } else { -1. };

                    let pos = Vector2::new(-factor * FIELD_OUTER_SIZE.x * 0.99, 0.);
                    let angle = (Rad::turn_div_2() + Rad(rand.next_float(0.66))) * factor;

                    (pos, angle)
                },
                EnemyAppearance::Center => {
                    let pos = Vector2::new(0., FIELD_OUTER_SIZE.y * 0.99 + spec.size);

                    (pos, Rad(0.))
                },
            };

            state.pos = pos;
            state.prev_pos = pos;
            state.angle = angle;

            appearance == EnemyAppearance::Center
                || state.check_front(true, spec, field, enemies.iter())
        });

        if !can_spawn {
            return None;
        }

        state.data = match spec.spec_data {
            EnemySpecData::SmallShip(data) => {
                EnemyStateData::SmallShip(SmallShipStateData {
                    speed: data.movement.speed(),
                    velocity_angle: state.angle,
                    count: 0,
                    mode: data.movement.mode(),
                })
            },
            EnemySpecData::Ship(data) => {
                EnemyStateData::Ship(ShipStateData {
                    speed: data.speed,
                    wake_count: 0,
                    destroyed: None,
                    turn_data: if spec.is_boss() {
                        ShipTurnStateData::Boss(BossTurn::new(rand))
                    } else {
                        ShipTurnStateData::Ship(ShipTurn {
                            turn_direction: TurnDirection::from_pos(state.pos),
                            turn_velocity: data.turn_velocity,
                        })
                    },
                })
            },
            _ => unreachable!(),
        };

        Some(state)
    }

    pub fn for_platform(
        spec: &EnemySpec,
        pos: Vector2<f32>,
        angle: Rad<f32>,
        field: &Field,
        enemies: &Pool<Enemy>,
    ) -> Option<Self> {
        assert_eq!(spec.spec.kind, EnemyKind::Platform);

        let mut state = Self::new();
        state.pos = pos;
        state.angle = angle;
        state.data = EnemyStateData::Platform(PlatformStateData {
            destroyed: None,
        });

        if state.check_front(true, spec, field, enemies.iter()) {
            Some(state)
        } else {
            None
        }
    }

    fn init(&mut self, spec: &EnemySpec, index: u32) {
        self.shield = spec.shield();
        self.damaged = false;
        self.damaged_count = 0;
        self.multiplier = 1.;
        self.index = index;

        let group_specs = spec.turret_group_specs();
        group_specs
            .par_iter()
            .cloned()
            .zip(self.turret_groups.par_iter_mut())
            .for_each(|(turret_spec, group)| group.init(turret_spec, spec.is_boss(), index));
        self.num_turret_groups = group_specs.len();

        let moving_group_specs = spec.moving_turret_group_specs();
        moving_group_specs
            .par_iter()
            .cloned()
            .zip(self.moving_turret_groups.par_iter_mut())
            .for_each(|(turret_spec, group)| group.init(turret_spec, spec.is_boss(), index));
        self.num_moving_turret_groups = moving_group_specs.len();
    }

    fn is_destroyed(&self) -> bool {
        !self.data.is_ok()
    }

    fn turret_groups(&self) -> &[TurretGroup] {
        &self.turret_groups[0..self.num_turret_groups]
    }

    fn turret_groups_mut(&mut self) -> &mut [TurretGroup] {
        &mut self.turret_groups[0..self.num_turret_groups]
    }

    fn collides(
        &mut self,
        spec: &EnemySpec,
        shot: &Shot,
        stage: &Stage,
        bullets: &mut Pool<Bullet>,
        crystals: &mut Pool<Crystal>,
        fragments: &mut Pool<Fragment>,
        smokes: &mut Pool<Smoke>,
        sparks: &mut Pool<Spark>,
        indicators: &mut Pool<ScoreIndicator>,
        reel: &mut ScoreReel,
        context: &mut GameStateContext,
        rand: &mut Rand,
    ) -> bool {
        let offset = shot.pos() - self.pos;
        let offset = Vector2::new(offset.x.abs(), offset.y.abs());
        if offset.x + offset.y > 2. * spec.size {
            return false;
        }

        let scores = self
            .turret_groups
            .iter_mut()
            .take(self.num_turret_groups)
            .filter_map(|group| {
                let scores = group.collides(shot, smokes, sparks, fragments, context, rand);

                if scores.is_empty() {
                    None
                } else {
                    Some(scores)
                }
            })
            .next();

        if let Some(scores) = scores {
            scores.into_iter().foreach(|score| {
                self.multiplier += score.multiplier();
                self.add_score_indicator(score.score(), 1., stage, indicators, reel, context, rand);
            });
            true
        } else if spec.spec.shapes.collides(offset, shot.collision()) {
            self.damage(
                spec, stage, shot, bullets, crystals, fragments, smokes, sparks, indicators, reel,
                context, rand,
            );
            true
        } else {
            false
        }
    }

    fn damage(
        &mut self,
        spec: &EnemySpec,
        stage: &Stage,
        shot: &Shot,
        bullets: &mut Pool<Bullet>,
        crystals: &mut Pool<Crystal>,
        fragments: &mut Pool<Fragment>,
        smokes: &mut Pool<Smoke>,
        sparks: &mut Pool<Spark>,
        indicators: &mut Pool<ScoreIndicator>,
        reel: &mut ScoreReel,
        context: &mut GameStateContext,
        rand: &mut Rand,
    ) {
        self.shield = self.shield.saturating_sub(shot.damage());
        if self.shield == 0 {
            self.destroyed(
                spec,
                Some(shot),
                stage,
                bullets,
                crystals,
                fragments,
                smokes,
                sparks,
                indicators,
                reel,
                context,
                rand,
            );
        } else {
            self.damaged_count = 7;
        }
    }

    fn check_front<'a, I>(&self, current: bool, spec: &EnemySpec, field: &Field, enemies: I) -> bool
    where
        I: Clone + IntoIterator<Item = &'a Enemy>,
    {
        let angle: Vector2<f32> = self.angle.sin_cos().into();
        let angle = spec.size * angle;
        let start: u32 = if current { 0 } else { 1 };

        (start..5).all(|i| {
            let pos = self.pos + angle * (i as f32);

            if field.block(pos).is_land() {
                return false;
            }

            enemies
                .clone()
                .into_iter()
                .filter_map(|enemy| {
                    if !enemy.spec.is_large() {
                        None
                    } else if enemy.state.is_destroyed() {
                        None
                    } else {
                        Some(enemy.collides(pos - enemy.state.pos, enemy.state.angle, 1.))
                    }
                })
                .all(|i| i)
        })
    }

    fn step(
        &mut self,
        spec: &EnemySpec,
        field: &Field,
        bullets: &mut Pool<Bullet>,
        ship: &Ship,
        smokes: &mut Pool<Smoke>,
        sparks: &mut Pool<Spark>,
        spark_fragments: &mut Pool<SparkFragment>,
        wakes: &mut Pool<Wake>,
        other_enemies: PoolChainIter<Enemy>,
        context: &mut GameStateContext,
        rand: &mut Rand,
    ) -> PoolRemoval {
        if let EnemyStateData::Ship(ref data) = self.data {
            if let Some(destroyed) = data.destroyed {
                if destroyed.count >= SINK_INTERVAL {
                    return PoolRemoval::Remove;
                }
            }
        }

        self.prev_pos = self.pos;
        self.multiplier = f32::max(1., self.multiplier - MULTIPLIER_DECREASE_RATIO);

        let interval = self
            .data
            .destroyed_mut()
            .and_then(|destroy| destroy.step(rand));

        if let Some(interval) = interval {
            context.audio.mark_sfx("explode");

            let n = cmp::min(
                48,
                (spec.size.sqrt() * 27. / ((interval as f32) * 0.1 + 1.)) as usize,
            );
            let points = spec.spec.shapes.normal().points();
            let i = rand.next_int(points.len() as u32) as usize;
            let pos = points[i].pos * spec.size + self.pos;
            let size = f32::min(1., spec.size * 0.5);

            (0..n).foreach(|i| {
                let velocity_factor = rand.next_float(0.5);
                let angle = points[i].angle + Rad(rand.next_float_signed(0.2));
                let angle_comps: Vector2<f32> = angle.sin_cos().into();
                let vel = angle_comps * velocity_factor;

                smokes.get_force().init_2d(
                    pos,
                    vel.extend(-0.004),
                    SmokeKind::Explosion,
                    75 + rand.next_int(25),
                    size,
                    rand,
                );

                (0..2).foreach(|_| {
                    let color = (0.5 + rand.next_float(0.5), 0.5 + rand.next_float(0.5), 0.).into();
                    sparks
                        .get_force()
                        .init(pos, vel * 2., color, 30 + rand.next_int(30));
                });

                if i % 2 == 0 {
                    spark_fragments.get_force().init(
                        pos,
                        (vel * 0.5).extend(0.06 + rand.next_float(0.07)),
                        0.2 + rand.next_float(0.1),
                        rand,
                    );
                }
            })
        }

        self.damaged = false;
        self.damaged_count = self.damaged_count.saturating_sub(1);

        let mut dead = true;
        for group in self.turret_groups.iter_mut().take(self.num_turret_groups) {
            let state = group.step(self.pos, self.angle, field, bullets, smokes, ship, rand);

            if state == TurretState::Alive {
                dead = false;
            }
        }
        for group in self
            .moving_turret_groups
            .iter_mut()
            .take(self.num_moving_turret_groups)
        {
            group.step(self.pos, self.angle, field, bullets, smokes, ship, rand);
        }

        if dead && self.data.is_ok() {
            return PoolRemoval::Remove;
            // return self.destroyed(None);
        }

        self.data = match self.data {
            EnemyStateData::SmallShip(old_data) => {
                let mut data = old_data;
                let mut angle_comps: Vector2<f32> = data.velocity_angle.sin_cos().into();

                self.pos += angle_comps * data.speed;
                self.pos.y -= field.last_scroll_y();

                if self.pos.y <= -FIELD_OUTER_SIZE.y {
                    return PoolRemoval::Remove;
                }

                if field.block(self.pos).is_land() || !field.is_in_outer_field(self.pos) {
                    data.velocity_angle += Rad::turn_div_2();
                    angle_comps = data.velocity_angle.sin_cos().into();
                    self.pos += angle_comps * data.speed * 2.;
                }

                let ship_spec_data = spec
                    .spec_data
                    .small_ship()
                    .expect("expected the spec to have small ship data");

                match data.mode {
                    SmallShipMode::StopAndGo {
                        ref mut state,
                    } => {
                        let spec_data = ship_spec_data
                            .movement
                            .stop_and_go()
                            .expect("expected the spec to have stop and go data");

                        match *state {
                            SmallShipMoveState::Moving => {
                                data.speed += (spec_data.max_speed - data.speed) * spec_data.accel;

                                data.count = data.count.saturating_add(1);
                                if data.count == spec_data.move_duration {
                                    data.velocity_angle = Rad(rand.next_float(Rad::full_turn().0));
                                    data.count = 0;
                                    *state = SmallShipMoveState::Staying;
                                }
                            },
                            SmallShipMoveState::Staying => {
                                data.speed += (spec_data.stay_speed - data.speed) * spec_data.accel;

                                data.count = data.count.saturating_add(1);
                                if data.count == spec_data.stay_duration {
                                    data.count = 0;
                                    *state = SmallShipMoveState::Moving;
                                }
                            },
                        }
                    },
                    SmallShipMode::Chase => {
                        let spec_data = ship_spec_data
                            .movement
                            .chase()
                            .expect("expected the spec to have chase data");

                        let ship_pos = ship.nearest_boat(self.pos).pos();
                        let fast_dist = abagames_util::fast_distance(ship_pos, self.pos);
                        let ship_angle = if fast_dist < 0.1 {
                            Rad(0.)
                        } else {
                            let diff = ship_pos - self.pos;
                            Rad::atan2(diff.y, diff.x)
                        };
                        let diff_angle = (ship_angle - data.velocity_angle).normalize();
                        data.velocity_angle = if diff_angle.0.abs() <= spec_data.turn_velocity.0 {
                            ship_angle
                        } else if diff_angle.0 < 0. {
                            data.velocity_angle - spec_data.turn_velocity
                        } else {
                            data.velocity_angle + spec_data.turn_velocity
                        }
                        .normalize();
                        data.count = data.count.wrapping_add(1);
                    },
                }

                let offset_angle = (data.velocity_angle - self.angle).normalize();
                self.angle = (self.angle + offset_angle * 0.05).normalize();

                if data.count % 6 == 0 && data.speed >= 0.03 {
                    spec.spec.shapes.add_wake(
                        field, self.pos, self.angle, data.speed, spec.size, wakes, rand,
                    )
                }

                EnemyStateData::SmallShip(data)
            },
            EnemyStateData::Ship(old_data) => {
                let mut data = old_data;

                let spec_data = spec
                    .spec_data
                    .ship()
                    .expect("expected the spec to have ship data");

                let angle_comps: Vector2<f32> = self.angle.sin_cos().into();
                self.pos += angle_comps * data.speed;
                self.pos.y -= field.last_scroll_y();

                let size = spec.size;
                if self.pos.x <= -FIELD_OUTER_SIZE.x - size
                    || FIELD_OUTER_SIZE.x + size <= self.pos.x
                    || self.pos.y <= -FIELD_OUTER_SIZE.y - size
                {
                    return PoolRemoval::Remove;
                }

                self.pos.y = f32::min(self.pos.y, FIELD_OUTER_SIZE.y * 2.2 + size);

                match data.turn_data {
                    ShipTurnStateData::Boss(ref mut boss) => {
                        boss.turn_count = boss.turn_count.saturating_sub(1);
                        if boss.turn_count == 0 {
                            boss.turn_count = 250 + rand.next_int(150);
                            boss.target_angle = if self.pos.x > 0. {
                                -Rad(rand.next_float(0.1) + 0.2)
                            } else {
                                Rad(rand.next_float(0.1) + 0.2)
                            };
                        }

                        self.angle += (boss.target_angle - self.angle) * 0.0025;

                        data.speed = if ship.highest_y() > self.pos.y {
                            data.speed + (spec_data.speed * 2. - data.speed) * 0.005
                        } else {
                            data.speed + (spec_data.speed - data.speed) * 0.01
                        };
                    },
                    ShipTurnStateData::Ship(ref mut ship) => {
                        if !self.check_front(false, spec, field, other_enemies) {
                            self.angle += ship.turn_velocity * ship.turn_direction.factor();
                            data.speed *= 0.98;
                        } else {
                            if data.destroyed.is_some() {
                                data.speed *= 0.98;
                            } else {
                                data.speed += (spec_data.speed - data.speed) * 0.01;
                            }
                        }
                    },
                }

                data.wake_count = data.wake_count.saturating_add(1);
                if data.wake_count % 6 == 0
                    && data.speed >= 0.01
                    && data
                        .destroyed
                        .map(|destroyed| destroyed.count < SINK_INTERVAL / 2)
                        .unwrap_or(true)
                {
                    spec.spec.shapes.add_wake(
                        field, self.pos, self.angle, data.speed, spec.size, wakes, rand,
                    );
                }

                EnemyStateData::Ship(data)
            },
            EnemyStateData::Platform(data) => {
                self.pos.y -= field.last_scroll_y();

                if self.pos.y <= -FIELD_OUTER_SIZE.y {
                    return PoolRemoval::Remove;
                }

                EnemyStateData::Platform(data)
            },
        };

        PoolRemoval::Keep
    }

    fn destroyed(
        &mut self,
        spec: &EnemySpec,
        shot: Option<&Shot>,
        stage: &Stage,
        bullets: &mut Pool<Bullet>,
        crystals: &mut Pool<Crystal>,
        fragments: &mut Pool<Fragment>,
        smokes: &mut Pool<Smoke>,
        sparks: &mut Pool<Spark>,
        indicators: &mut Pool<ScoreIndicator>,
        reel: &mut ScoreReel,
        context: &mut GameStateContext,
        rand: &mut Rand,
    ) -> PoolRemoval {
        let (explode_vel, z_vel) = if let Some(shot) = shot {
            let angle_comps: Vector2<f32> = shot.angle().sin_cos().into();
            (angle_comps * SHOT_SPEED / 2., 0.)
        } else {
            ((0., 0.).into(), 0.05)
        };

        let size = f32::min(2., spec.size * 1.5);
        let particle_count_base = f32::min(
            3.,
            if spec.size < 1. {
                spec.size
            } else {
                spec.size.sqrt()
            },
        );

        (0..((particle_count_base * 8.) as usize)).foreach(|_| {
            let vel_offset = Vector2::new(rand.next_float_signed(0.1), rand.next_float_signed(0.1));
            let vel = (vel_offset + explode_vel).extend(rand.next_float(z_vel));
            smokes.get_force().init_2d(
                self.pos,
                vel,
                SmokeKind::Explosion,
                32 + rand.next_int(30),
                size,
                rand,
            );
        });

        (0..((particle_count_base * 36.) as usize)).foreach(|_| {
            let vel_offset = Vector2::new(rand.next_float_signed(0.8), rand.next_float_signed(0.8));
            let color = Vector3::new(0.5 + rand.next_float(0.5), 0.5 + rand.next_float(0.5), 0.);
            sparks.get_force().init(
                self.pos,
                vel_offset + explode_vel,
                color,
                30 + rand.next_int(30),
            );
        });

        (0..((particle_count_base * 12.) as usize)).foreach(|_| {
            let vel_offset =
                Vector2::new(rand.next_float_signed(0.33), rand.next_float_signed(0.33));
            let vel = (vel_offset + explode_vel).extend(0.05 + rand.next_float(0.1));
            fragments
                .get_force()
                .init(self.pos, vel, 0.2 + rand.next_float(0.33), rand);
        });

        self.turret_groups[0..self.num_turret_groups]
            .par_iter_mut()
            .for_each(|group| group.destroy());
        self.moving_turret_groups[0..self.num_moving_turret_groups]
            .par_iter_mut()
            .for_each(|group| group.destroy());

        let sfx = if let EnemyKind::SmallShip = spec.spec.kind {
            "small_destroyed"
        } else {
            "destroyed"
        };
        context.audio.mark_sfx(sfx);

        let (score, res) = if self.data.destroy() {
            let mut num_bullets = 0;
            bullets.run(|ref mut bullet| {
                if bullet.index() == self.index {
                    bullet.into_crystal(crystals);
                    num_bullets += 1;
                    PoolRemoval::Remove
                } else {
                    PoolRemoval::Keep
                }
            });

            if spec.is_boss() {
                // screen.shake(45, 0.04);
            }

            (spec.score() + num_bullets * 10, PoolRemoval::Keep)
        } else {
            (spec.score(), PoolRemoval::Remove)
        };

        self.add_score_indicator(
            score,
            self.multiplier,
            stage,
            indicators,
            reel,
            context,
            rand,
        );

        res
    }

    fn add_score_indicator(
        &self,
        score: u32,
        multiplier: f32,
        stage: &Stage,
        indicators: &mut Pool<ScoreIndicator>,
        reel: &mut ScoreReel,
        context: &mut GameStateContext,
        rand: &mut Rand,
    ) {
        let target_y = context.data.indicator_target();
        let final_score = if multiplier > 1. {
            let mid_score = ((score as f32) * multiplier) as u32;
            let final_score = ((score as f32) * multiplier * stage.rank()) as u32;

            let targets = [
                ScoreTarget {
                    pos: (8., target_y).into(),
                    flying_to: FlyingTo::Right,
                    initial_velocity_ratio: 1.,
                    scale: 0.5,
                    value: score,
                    count: 40,
                },
                ScoreTarget {
                    pos: (11., target_y).into(),
                    flying_to: FlyingTo::Right,
                    initial_velocity_ratio: 0.5,
                    scale: 0.75,
                    value: mid_score,
                    count: 30,
                },
                ScoreTarget {
                    pos: (13., target_y).into(),
                    flying_to: FlyingTo::Right,
                    initial_velocity_ratio: 0.25,
                    scale: 1.,
                    value: final_score,
                    count: 20,
                },
                ScoreTarget {
                    pos: (12., -8.).into(),
                    flying_to: FlyingTo::Bottom,
                    initial_velocity_ratio: 0.5,
                    scale: 0.1,
                    value: final_score,
                    count: 40,
                },
            ];
            indicators.get_force().init(
                score,
                Indicator::Score,
                self.pos,
                0.5,
                targets.into_iter(),
                reel,
                context,
                rand,
            );

            let multiplier_value = (1000. * multiplier) as u32;
            let targets = [ScoreTarget {
                pos: (10.5, target_y).into(),
                flying_to: FlyingTo::Right,
                initial_velocity_ratio: 0.5,
                scale: 0.2,
                value: multiplier_value,
                count: 70,
            }];
            indicators.get_force().init(
                multiplier_value,
                Indicator::Multiplier,
                self.pos,
                0.7,
                targets.into_iter(),
                reel,
                context,
                rand,
            );

            final_score
        } else {
            let final_score = ((score as f32) * stage.rank()) as u32;

            let targets = [
                ScoreTarget {
                    pos: (11., target_y).into(),
                    flying_to: FlyingTo::Right,
                    initial_velocity_ratio: 1.5,
                    scale: 0.2,
                    value: score,
                    count: 40,
                },
                ScoreTarget {
                    pos: (13., target_y).into(),
                    flying_to: FlyingTo::Right,
                    initial_velocity_ratio: 0.25,
                    scale: 0.25,
                    value: final_score,
                    count: 20,
                },
                ScoreTarget {
                    pos: (12., -8.).into(),
                    flying_to: FlyingTo::Bottom,
                    initial_velocity_ratio: 0.5,
                    scale: 0.1,
                    value: final_score,
                    count: 40,
                },
            ];
            indicators.get_force().init(
                score,
                Indicator::Score,
                self.pos,
                0.3,
                targets.into_iter(),
                reel,
                context,
                rand,
            );

            final_score
        };

        let rank_value = (1000. * stage.rank()) as u32;
        let targets = [ScoreTarget {
            pos: (13., target_y).into(),
            flying_to: FlyingTo::Right,
            initial_velocity_ratio: 0.5,
            scale: 0.2,
            value: rank_value,
            count: 40,
        }];
        indicators.get_force().init(
            rank_value,
            Indicator::Multiplier,
            (11., 8.).into(),
            0.4,
            targets.into_iter(),
            reel,
            context,
            rand,
        );

        reel.add_actual_score(final_score);
    }
}

#[derive(Debug, Clone, Copy)]
pub struct Enemy {
    spec: EnemySpec,
    state: EnemyState,
    index: u32,
    damage_offset: Vector2<f32>,
}

impl Enemy {
    fn new(index: usize) -> Self {
        Enemy {
            spec: EnemySpec::new(),
            state: EnemyState::new(),
            index: index as u32,
            damage_offset: Vector2::new(0., 0.),
        }
    }

    pub fn new_pool() -> Pool<Self> {
        Pool::new_indexed(40, Self::new)
    }

    pub fn is_boss(&self) -> bool {
        self.spec.is_boss()
    }

    pub fn init(&mut self, spec: EnemySpec, state: EnemyState) {
        self.spec = spec;
        self.state = state;
        self.state.init(&self.spec, self.index);
    }

    fn collides(&self, pos: Vector2<f32>, angle: Rad<f32>, size_ratio: f32) -> bool {
        let check_size = self.spec.size * (1. - self.spec.distance_ratio()) * 1.1 * size_ratio;
        if abagames_util::fast_distance_origin(pos) < check_size {
            true
        } else {
            let angle_comps: Vector2<f32> = angle.sin_cos().into();
            iter::repeat(())
                .fold_while((0., check_size, true), |(offset, check_size, _), _| {
                    if check_size < 0.2 {
                        FoldWhile::Done((offset, check_size, false))
                    } else {
                        let ref_pos = angle_comps * offset;
                        if abagames_util::fast_distance(pos, ref_pos) < check_size
                            || abagames_util::fast_distance(pos, -ref_pos) < check_size
                        {
                            FoldWhile::Done((offset, check_size, true))
                        } else {
                            FoldWhile::Continue((
                                offset + check_size,
                                check_size * self.spec.distance_ratio(),
                                true,
                            ))
                        }
                    }
                })
                .into_inner()
                .2
        }
    }

    pub fn check_shot_hit(
        &mut self,
        shot: &Shot,
        stage: &Stage,
        bullets: &mut Pool<Bullet>,
        crystals: &mut Pool<Crystal>,
        fragments: &mut Pool<Fragment>,
        smokes: &mut Pool<Smoke>,
        sparks: &mut Pool<Spark>,
        indicators: &mut Pool<ScoreIndicator>,
        reel: &mut ScoreReel,
        context: &mut GameStateContext,
        rand: &mut Rand,
    ) -> PoolRemoval {
        if !self.state.is_destroyed()
            && self.state.collides(
                &self.spec, shot, stage, bullets, crystals, fragments, smokes, sparks, indicators,
                reel, context, rand,
            )
        {
            if self.spec.spec.kind.is_small() && shot.is_lance() {
                PoolRemoval::Keep
            } else {
                PoolRemoval::Remove
            }
        } else {
            PoolRemoval::Keep
        }
    }

    pub fn step(
        &mut self,
        field: &Field,
        bullets: &mut Pool<Bullet>,
        ship: &Ship,
        smokes: &mut Pool<Smoke>,
        sparks: &mut Pool<Spark>,
        spark_fragments: &mut Pool<SparkFragment>,
        wakes: &mut Pool<Wake>,
        other_enemies: PoolChainIter<Enemy>,
        context: &mut GameStateContext,
        rand: &mut Rand,
    ) -> PoolRemoval {
        self.state.step(
            &self.spec,
            field,
            bullets,
            ship,
            smokes,
            sparks,
            spark_fragments,
            wakes,
            other_enemies,
            context,
            rand,
        )
    }

    pub fn prep_draw(&mut self, rand: &mut Rand) {
        let is_damaged = self.state.damaged_count > 0;
        let destroyed_data = self.state.data.destroyed();
        let is_destroyed = destroyed_data.is_some();
        self.damage_offset = if !is_destroyed && is_damaged {
            (
                rand.next_float_signed((self.state.damaged_count as f32) * 0.01),
                rand.next_float_signed((self.state.damaged_count as f32) * 0.01),
            )
        } else {
            (0., 0.)
        }
        .into();

        if let Some(data) = destroyed_data {
            self.spec
                .spec
                .recolor((data.count as f32) / (SINK_INTERVAL as f32));
            return;
        }

        self.state
            .turret_groups_mut()
            .iter_mut()
            .foreach(|group| group.prep_draw(rand));
    }

    pub fn draw<R, C>(
        &self,
        context: &mut EncoderContext<R, C>,
        shape_draw: &ShapeDraw<R>,
        turret_draw: &TurretDraw<R>,
        letter: &Letter<R>,
    ) where
        R: gfx::Resources,
        C: gfx::CommandBuffer<R>,
    {
        let is_damaged = self.state.damaged_count > 0;
        let is_destroyed = self.state.is_destroyed();
        let modelmat = Matrix4::from_translation((self.state.pos + self.damage_offset).extend(0.))
            * Matrix4::from_axis_angle(Vector3::unit_z(), self.state.angle);
        let scalemat = Matrix4::from_scale(self.spec.size);

        let shape = if self.state.data.destroyed().is_some() {
            self.spec
                .spec
                .shapes
                .destroyed()
                .expect("the state says to draw a damaged ship, but no shape is available")
        } else if is_damaged {
            self.spec.spec.shapes.damaged()
        } else {
            self.spec.spec.shapes.normal()
        };
        shape_draw.draw(context, shape, modelmat * scalemat);

        if is_destroyed {
            return;
        }

        let bridge_scalemat = Matrix4::from_scale(self.spec.bridge_size);
        shape_draw.draw(
            context,
            self.spec.spec.shapes.bridge(),
            modelmat * bridge_scalemat,
        );

        self.state
            .turret_groups()
            .iter()
            .foreach(|group| group.draw(context, shape_draw, turret_draw));

        if self.state.multiplier > 1. {
            let offset_x = if self.state.multiplier < 10. {
                2.1
            } else {
                1.4
            };
            let offset: Vector2<f32> = if self.spec.is_boss() {
                (offset_x + 4., 0.)
            } else {
                (offset_x, 1.25)
            }
            .into();

            letter.draw_number(
                context,
                (self.state.multiplier * 1000.) as u32,
                letter::Style::OffWhite,
                letter::Location::new(self.state.pos + offset, 0.33),
                letter::NumberStyle::multiplier(),
            );
        }
    }
}
