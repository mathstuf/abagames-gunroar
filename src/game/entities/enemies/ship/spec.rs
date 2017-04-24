// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

use crates::abagames_util::Rand;
use crates::cgmath::{Angle, Rad};
use crates::itertools::Itertools;

use game::entities::enemies::turret::{MovingTurretGroupSpec, MovingTurretGroupSpecBuilder, TurretGroupAlignment, TurretGroupSpec, TurretGroupSpecBuilder, TurretKind, TurretMovement};
use game::entities::shapes::enemy::{EnemyShape, EnemyShapeKind};

use std::cmp;
use std::f32;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EnemyKind {
    SmallShip,
    Ship,
    Platform,
}

impl EnemyKind {
    pub fn is_small(&self) -> bool {
        if let EnemyKind::SmallShip = *self {
            true
        } else {
            false
        }
    }
}

pub const MAX_TURRET_GROUPS: usize = 10;
pub const MAX_MOVING_TURRET_GROUPS: usize = 4;

#[derive(Debug, Clone, Copy)]
pub struct BaseEnemySpec {
    kind: EnemyKind,
    distance_ratio: f32,

    normal_shape: EnemyShape,
    damaged_shape: EnemyShape,
    destroyed_shape: Option<EnemyShape>,
    bridge_shape: EnemyShape,

    turret_groups: [TurretGroupSpec; MAX_TURRET_GROUPS],
    num_turret_groups: usize,

    moving_turret_groups: [MovingTurretGroupSpec; MAX_MOVING_TURRET_GROUPS],
    num_moving_turret_groups: usize,
}

#[derive(Debug, Clone, Copy)]
struct MovingTurretAddData {
    align: Rad<f32>,
    rotate_velocity: Rad<f32>,
    amplitude: f32,
    amplitude_velocity: f32,
}

impl BaseEnemySpec {
    fn new() -> Self {
        BaseEnemySpec {
            kind: EnemyKind::SmallShip,
            distance_ratio: 0.,

            normal_shape: EnemyShape::new(EnemyShapeKind::Small),
            damaged_shape: EnemyShape::new(EnemyShapeKind::SmallDamaged),
            destroyed_shape: None,
            bridge_shape: EnemyShape::new(EnemyShapeKind::SmallBridge),

            turret_groups: [TurretGroupSpecBuilder::default().into(); MAX_TURRET_GROUPS],
            num_turret_groups: 0,

            moving_turret_groups: [MovingTurretGroupSpecBuilder::default().into(); MAX_MOVING_TURRET_GROUPS],
            num_moving_turret_groups: 0,
        }
    }

    fn init(&mut self, kind: EnemyKind) {
        self.kind = kind;
        self.distance_ratio = 0.;

        match self.kind {
            EnemyKind::SmallShip => {
              self.normal_shape.update(EnemyShapeKind::Small);
              self.damaged_shape.update(EnemyShapeKind::SmallDamaged);
              self.destroyed_shape = None;
              self.bridge_shape.update(EnemyShapeKind::SmallBridge);
            },
            EnemyKind::Ship => {
              self.normal_shape.update(EnemyShapeKind::Middle);
              self.damaged_shape.update(EnemyShapeKind::MiddleDamaged);
              self.destroyed_shape = Some(EnemyShape::new(EnemyShapeKind::MiddleDestroyed));
              self.bridge_shape.update(EnemyShapeKind::MiddleBridge);
            },
            EnemyKind::Platform => {
              self.normal_shape.update(EnemyShapeKind::Platform);
              self.damaged_shape.update(EnemyShapeKind::PlatformDamaged);
              self.destroyed_shape = Some(EnemyShape::new(EnemyShapeKind::PlatformDestroyed));
              self.bridge_shape.update(EnemyShapeKind::PlatformBridge);
            },
        }

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
                    amplitude: 0.01 + rand.next_float(0.04),
                    amplitude_velocity: 0.01 + rand.next_float(0.03),
                }
            },
            TurretMovement::SwingFix => {
                MovingTurretAddData {
                    align: Rad::turn_div_2() / 10. + Rad(rand.next_float(f32::consts::PI / 15.)),
                    rotate_velocity: Rad(0.01 + rand.next_float(0.02)),
                    amplitude: 0.,
                    amplitude_velocity: 0.01 + rand.next_float(0.03),
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
                    amplitude: 0.,
                    amplitude_velocity: 0.01 + rand.next_float(0.02),
                }
            },
        };

        (0..num_moving_turrets)
            .foreach(|_| {
                let mut builder = MovingTurretGroupSpecBuilder::default();
                builder.with_radius(radius);

                let turret_rank = match kind {
                    TurretMovement::Roll => {
                        let count = 4 + rand.next_int(6);

                        builder.with_alignment(data.align)
                            .with_count(count);

                        if rand.next_int(2) == 0 {
                            if rand.next_int(2) == 0 {
                                builder.as_roll(data.rotate_velocity, 0., 0.);
                            } else {
                                builder.as_roll(-data.rotate_velocity, 0., 0.);
                            }
                        } else {
                            if rand.next_int(2) == 0 {
                                builder.as_roll(Rad(0.), data.amplitude, data.amplitude_velocity);
                            } else {
                                builder.as_roll(Rad(0.), -data.amplitude, data.amplitude_velocity);
                            }
                        }

                        if rand.next_int(3) == 0 {
                            builder.with_radius_amplitude(1. + rand.next_float(1.),
                                                          0.01 + rand.next_float(0.03));
                        }
                        if rand.next_int(2) == 0 {
                            builder.with_distance_ratio(0.8 + rand.next_float_signed(0.3));
                        }

                        br / (count as f32)
                    },
                    TurretMovement::SwingFix => {
                        let count = 3 + rand.next_int(5);

                        builder.with_alignment(data.align * ((count as f32) * 0.1 + 0.3))
                            .with_count(count);

                        if rand.next_int(2) == 0 {
                            builder.as_swing(data.rotate_velocity, data.amplitude_velocity, false);
                        } else {
                            builder.as_swing(-data.rotate_velocity, data.amplitude_velocity, false);
                        }

                        if rand.next_int(6) == 0 {
                            builder.with_radius_amplitude(1. + rand.next_float(1.),
                                                          0.01 + rand.next_float(0.03));
                        }
                        if rand.next_int(4) == 0 {
                            builder.with_align_amplitude(0.25 + rand.next_float(0.25),
                                                         0.01 + rand.next_float(0.02));
                        }

                        br / (count as f32) * 0.6
                    },
                    TurretMovement::SwingAim => {
                        let count = 3 + rand.next_int(4);

                        builder.with_alignment(data.align * ((count as f32) * 0.1 + 0.3))
                            .with_count(count);

                        if rand.next_int(2) == 0 {
                            builder.as_swing(data.rotate_velocity, data.amplitude_velocity, true);
                        } else {
                            builder.as_swing(-data.rotate_velocity, data.amplitude_velocity, true);
                        }

                        if rand.next_int(4) == 0 {
                            builder.with_radius_amplitude(1. + rand.next_float(1.),
                                                          0.01 + rand.next_float(0.03));
                        }
                        if rand.next_int(5) == 0 {
                            builder.with_align_amplitude(0.25 + rand.next_float(0.25),
                                                         0.01 + rand.next_float(0.02));
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

    fn resize(&mut self, size: f32) {
        self.normal_shape.resize(size);
        self.damaged_shape.resize(size);
        self.destroyed_shape
            .map(|mut shape| shape.resize(size));
        self.bridge_shape.resize(0.9 * 1. - self.distance_ratio);
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
enum SmallShipMovement {
    StopAndGo {
        accel: f32,
        max_speed: f32,
        stay_speed: f32,
        move_duration: u32,
        stay_duration: u32,
    },
    Chase {
        speed: f32,
        turn_velocity: Rad<f32>,
    },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum SmallShipMoveState {
    Staying,
    Moving,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum ShipClass {
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

    fn is_boss(&self) -> bool {
        ShipClass::Boss == *self
    }
}

#[derive(Debug, Clone, Copy)]
enum EnemySpecData {
    SmallShip {
        movement: SmallShipMovement,
    },
    Ship {
        class: ShipClass,
        speed: f32,
        turn_velocity: Rad<f32>,
    },
    Platform,
}

impl EnemySpecData {
    fn score(&self) -> u32 {
        match *self {
            EnemySpecData::SmallShip { .. } => 50,
            EnemySpecData::Ship { ref class, .. } => class.score(),
            EnemySpecData::Platform => 100,
        }
    }

    fn is_boss(&self) -> bool {
        if let EnemySpecData::Ship { ref class, .. } = *self {
            class.is_boss()
        } else {
            false
        }
    }
}

#[derive(Debug, Clone, Copy)]
pub struct EnemySpec {
    spec: BaseEnemySpec,
    spec_data: EnemySpecData,

    shield: u32,
}

pub enum EnemyAppearResult {
    Done,
    Invalid,
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
            shield: 0,
        }
    }

    pub fn init_small_ship(&mut self, rank: f32, rand: &mut Rand) {
        self.spec.init(EnemyKind::SmallShip);
        self.spec.distance_ratio = 0.5;

        let speed_factor = f32::min(25., rand.next_float(rank * 0.8));
        self.spec_data = EnemySpecData::SmallShip {
            movement: if rand.next_int(2) == 0 {
                self.spec.resize(0.47 + rand.next_float(0.1));
                SmallShipMovement::StopAndGo {
                    accel: 0.5 - 0.5 / (2. + rand.next_float(rank)),
                    max_speed: 0.05 * (1. + speed_factor),
                    stay_speed: 0.03,
                    move_duration: (32 + rand.next_int_signed(12)) as u32,
                    stay_duration: (32 + rand.next_int_signed(12)) as u32,
                }
            } else {
                self.spec.resize(0.5 + rand.next_float(0.1));
                SmallShipMovement::Chase {
                    speed: 0.036 * (1. + speed_factor),
                    turn_velocity: Rad(0.02 + rand.next_float_signed(0.04)),
                }
            },
        };

        let mut builder = TurretGroupSpecBuilder::default();
        builder.init_spec(rank - speed_factor * 0.5, TurretKind::Small, rand);
        self.spec.add_turret_group(builder.into());
    }

    pub fn init_ship(&mut self, rank: f32, class: ShipClass, /*ship: &Ship,*/ rand: &mut Rand) {
        self.spec.init(EnemyKind::Ship);
        self.spec.distance_ratio = 0.7;

        let main_turret_num = 0;
        let sub_turret_num = 0;

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

                // let speed = ship.scroll_speed_base() + 0.0025 + rand.next_float_signed(0.001);
                let speed = 0.;
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
        self.spec.resize(count.size);
        self.spec_data = EnemySpecData::Ship {
            class: class,
            speed: count.speed,
            turn_velocity: count.turn_velocity,
        };
        self.shield = (count.size * 10.) as u32;
        if class.is_boss() {
            self.shield = ((self.shield as f32) * 2.4) as u32;
        }

        if count.main + count.sub > 0 {
            let sub_turret_rank = count.rank / ((3 * count.main + count.sub) as f32);
            let main_turret_rank = sub_turret_rank * 2.5;
            if class.is_boss() {
                let main_turret_rank = main_turret_rank * 2.5;
                let sub_turret_rank = sub_turret_rank * 2.;

                if count.main > 0 {
                    let num_front_main_turret = (count.main + 2) / 4;
                    let num_rear_main_turret = (count.main - num_front_main_turret * 2) / 2;

                    let angles = [
                        -Rad::full_turn() / 8.,
                        Rad::full_turn() * 3. / 8.,
                        Rad::full_turn() * 7. / 8.,
                        Rad::full_turn() * 11. / 8.,
                    ];

                    let mut builder = TurretGroupSpecBuilder::default();
                    builder.init_spec(main_turret_rank, TurretKind::Main, rand)
                        .as_boss()
                        .with_count(num_front_main_turret)
                        .with_alignment(TurretGroupAlignment::Round)
                        .with_sized_alignment(angles[0], f32::consts::FRAC_PI_6 + rand.next_float(f32::consts::FRAC_PI_8))
                        .with_radius(count.size * 0.45)
                        .with_distance_ratio(self.spec.distance_ratio);
                    let mut mirror = builder;
                    mirror
                        .with_sized_alignment(angles[1], f32::consts::FRAC_PI_6 + rand.next_float(f32::consts::FRAC_PI_8));
                    let mut alt_builder = builder;
                    self.spec.add_turret_group(builder.into());
                    self.spec.add_turret_group(mirror.into());

                    alt_builder.with_count(num_rear_main_turret)
                        .with_sized_alignment(angles[2], f32::consts::FRAC_PI_6 + rand.next_float(f32::consts::FRAC_PI_8));
                    let mut mirror = alt_builder;
                    mirror
                        .with_sized_alignment(angles[3], f32::consts::FRAC_PI_6 + rand.next_float(f32::consts::FRAC_PI_8));
                    self.spec.add_turret_group(alt_builder.into());
                    self.spec.add_turret_group(mirror.into());
                }

                if count.sub > 0 {
                    let num_front_sub_turret = (count.sub + 2) / 6;
                    let num_mid_sub_turret = (count.sub - num_front_sub_turret * 2) / 4;
                    let num_rear_sub_turret = (count.sub - num_front_sub_turret * 2 - num_mid_sub_turret * 2) / 2;

                    let angles = [
                        Rad::full_turn() / 8.,
                        -Rad::full_turn() / 8.,
                        Rad::turn_div_4(),
                        -Rad::turn_div_4(),
                        Rad::full_turn() * 3. / 8.,
                        -Rad::full_turn() * 3. / 8.,
                    ];

                    let turret_kind = if rand.next_int(2) == 0 {
                        TurretKind::Sub
                    } else {
                        TurretKind::SubDestructive
                    };
                    let mut builder = TurretGroupSpecBuilder::default();
                    builder.init_spec(sub_turret_rank, turret_kind, rand)
                        .as_boss()
                        .with_count(num_front_sub_turret)
                        .with_alignment(TurretGroupAlignment::Round)
                        .with_sized_alignment(angles[0], f32::consts::PI / 7. + rand.next_float(f32::consts::PI / 9.))
                        .with_radius(count.size * 0.75)
                        .with_distance_ratio(self.spec.distance_ratio);
                    let mut mirror = builder;
                    mirror
                        .with_sized_alignment(angles[1], f32::consts::PI / 7. + rand.next_float(f32::consts::PI / 9.));
                    let mut alt_builder = builder;
                    self.spec.add_turret_group(builder.into());
                    self.spec.add_turret_group(mirror.into());

                    let turret_kind = if rand.next_int(2) == 0 {
                        TurretKind::Sub
                    } else {
                        TurretKind::SubDestructive
                    };
                    alt_builder.with_count(num_mid_sub_turret)
                        .with_sized_alignment(angles[2], f32::consts::PI / 7. + rand.next_float(f32::consts::PI / 9.));
                    let mut mirror = alt_builder;
                    mirror
                        .with_sized_alignment(angles[3], f32::consts::PI / 7. + rand.next_float(f32::consts::PI / 9.));
                    let mut alt2_builder = builder;
                    self.spec.add_turret_group(alt_builder.into());
                    self.spec.add_turret_group(mirror.into());

                    let turret_kind = if rand.next_int(2) == 0 {
                        TurretKind::Sub
                    } else {
                        TurretKind::SubDestructive
                    };
                    alt2_builder.with_count(num_rear_sub_turret)
                        .with_sized_alignment(angles[4], f32::consts::PI / 7. + rand.next_float(f32::consts::PI / 9.));
                    let mut mirror = alt_builder;
                    mirror
                        .with_sized_alignment(angles[5], f32::consts::PI / 7. + rand.next_float(f32::consts::PI / 9.));
                    self.spec.add_turret_group(alt2_builder.into());
                    self.spec.add_turret_group(mirror.into());
                }
            } else {
                let num_front_main_turret = (((count.main / 2) as f32) + 0.99) as u32;
                let num_rear_main_turret = count.main - num_front_main_turret;

                if num_front_main_turret > 0 {
                    let mut builder = TurretGroupSpecBuilder::default();
                    builder.init_spec(main_turret_rank, TurretKind::Main, rand)
                        .with_count(num_front_main_turret)
                        .with_alignment(TurretGroupAlignment::Straight)
                        .with_y_offset(-count.size * (0.9 + rand.next_float_signed(0.05)));
                    self.spec.add_turret_group(builder.into());
                }

                if num_rear_main_turret > 0 {
                    let mut builder = TurretGroupSpecBuilder::default();
                    builder.init_spec(main_turret_rank, TurretKind::Main, rand)
                        .with_count(num_rear_main_turret)
                        .with_alignment(TurretGroupAlignment::Straight)
                        .with_y_offset(-count.size * (0.9 + rand.next_float_signed(0.05)));
                    self.spec.add_turret_group(builder.into());
                }

                if count.sub > 0 {
                    let num_front_sub_turret = (count.sub + 2) / 4;
                    let num_rear_sub_turret = (count.sub - num_front_sub_turret * 2) / 4;

                    let angles = [
                        -Rad::full_turn() / 8.,
                        Rad::full_turn() * 3. / 8.,
                        Rad::full_turn() * 7. / 8.,
                        Rad::full_turn() * 11. / 8.,
                    ];

                }

                if count.sub > 0 {
                    let num_front_sub_turret = (count.sub + 2) / 6;
                    let num_mid_sub_turret = (count.sub - num_front_sub_turret * 2) / 4;
                    let num_rear_sub_turret = (count.sub - num_front_sub_turret * 2 - num_mid_sub_turret * 2) / 2;

                    let angles = [
                        Rad::full_turn() / 8.,
                        -Rad::full_turn() / 8.,
                        Rad::turn_div_4(),
                        -Rad::turn_div_4(),
                        Rad::full_turn() * 3. / 8.,
                        -Rad::full_turn() * 3. / 8.,
                    ];

                    let turret_kind = if rand.next_int(2) == 0 {
                        TurretKind::Sub
                    } else {
                        TurretKind::SubDestructive
                    };
                    let mut builder = TurretGroupSpecBuilder::default();
                    builder.init_spec(sub_turret_rank, turret_kind, rand)
                        .as_boss()
                        .with_count(num_front_sub_turret)
                        .with_alignment(TurretGroupAlignment::Round)
                        .with_sized_alignment(angles[0], f32::consts::FRAC_PI_6 + rand.next_float(f32::consts::FRAC_PI_8))
                        .with_radius(count.size * 0.75)
                        .with_distance_ratio(self.spec.distance_ratio);
                    let mut mirror = builder;
                    mirror
                        .with_sized_alignment(angles[1], f32::consts::FRAC_PI_6 + rand.next_float(f32::consts::FRAC_PI_8));
                    let mut alt_builder = builder;
                    self.spec.add_turret_group(builder.into());
                    self.spec.add_turret_group(mirror.into());

                    let turret_kind = if rand.next_int(2) == 0 {
                        TurretKind::Sub
                    } else {
                        TurretKind::SubDestructive
                    };
                    alt_builder.with_count(num_mid_sub_turret)
                        .with_sized_alignment(angles[2], f32::consts::FRAC_PI_6 + rand.next_float(f32::consts::FRAC_PI_8));
                    let mut mirror = alt_builder;
                    mirror
                        .with_sized_alignment(angles[3], f32::consts::FRAC_PI_6 + rand.next_float(f32::consts::FRAC_PI_8));
                    let mut alt2_builder = builder;
                    self.spec.add_turret_group(alt_builder.into());
                    self.spec.add_turret_group(mirror.into());

                    let turret_kind = if rand.next_int(2) == 0 {
                        TurretKind::Sub
                    } else {
                        TurretKind::SubDestructive
                    };
                    alt2_builder.with_count(num_rear_sub_turret)
                        .with_sized_alignment(angles[4], f32::consts::PI / 7. + rand.next_float(f32::consts::PI / 9.));
                    let mut mirror = alt_builder;
                    mirror
                        .with_sized_alignment(angles[5], f32::consts::PI / 7. + rand.next_float(f32::consts::PI / 9.));
                    self.spec.add_turret_group(alt2_builder.into());
                    self.spec.add_turret_group(mirror.into());
                }
            }
        }

        if count.moving_ratio > 0. {
            self.spec.add_moving_turret(rank * count.moving_ratio, class.is_boss(), rand);
        }
    }

    pub fn init_platform(&mut self, rank: f32, rand: &mut Rand) {
        self.spec.init(EnemyKind::Platform);
        self.spec.distance_ratio = 0.;
        self.spec_data = EnemySpecData::Platform;

        let try_size = 1. + rank / 30. + rand.next_float(rank / 30.);
        let max_size = 1. + rand.next_float(0.25);
        let size = f32::min(max_size, try_size);
        self.spec.resize(size);

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
            builder.init_spec(main_turret_rank, TurretKind::Main, rand)
                .with_count(count.main)
                .with_alignment(TurretGroupAlignment::Round)
                .with_sized_alignment(Rad(0.), f32::consts::PI * 0.66 + rand.next_float(f32::consts::FRAC_PI_2))
                .with_radius(size * 0.7)
                .with_distance_ratio(self.spec.distance_ratio);
            self.spec.add_turret_group(builder.into());
        }

        if count.front > 0 {
            let mut builder = TurretGroupSpecBuilder::default();
            builder.init_spec(sub_turret_rank, TurretKind::Sub, rand)
                .with_count(count.front)
                .with_alignment(TurretGroupAlignment::Round)
                .with_sized_alignment(Rad(0.), f32::consts::PI / 5. + rand.next_float(f32::consts::FRAC_PI_6))
                .with_radius(size * 0.8)
                .with_distance_ratio(self.spec.distance_ratio);
            self.spec.add_turret_group(builder.into());
        }

        let side_turret_count = count.side / 2;
        if side_turret_count > 0 {
            let mut builder = TurretGroupSpecBuilder::default();
            builder.init_spec(sub_turret_rank, TurretKind::Sub, rand)
                .with_count(side_turret_count)
                .with_alignment(TurretGroupAlignment::Round)
                .with_sized_alignment(Rad::turn_div_4(), f32::consts::PI / 5. + rand.next_float(f32::consts::FRAC_PI_6))
                .with_radius(size * 0.75)
                .with_distance_ratio(self.spec.distance_ratio);
            let mut mirror = builder;
            mirror
                .with_sized_alignment(-Rad::turn_div_4(), f32::consts::PI / 5. + rand.next_float(f32::consts::FRAC_PI_6));
            self.spec.add_turret_group(builder.into());
            self.spec.add_turret_group(mirror.into());
        }

        if count.moving_ratio > 0. {
            self.spec.add_moving_turret(rank * count.moving_ratio, false, rand);
        }
    }

    pub fn turret_group_specs(&self) -> &[TurretGroupSpec] {
        self.spec.turret_groups[0..self.spec.num_turret_groups]
    }

    pub fn moving_turret_group_specs(&self) -> &[MovingTurretGroupSpec] {
        self.spec.moving_turret_groups[0..self.spec.num_moving_turret_groups]
    }

    pub fn score(&self) -> u32 {
        self.spec_data.score()
    }

    pub fn is_boss(&self) -> bool {
        self.spec_data.is_boss()
    }
}
