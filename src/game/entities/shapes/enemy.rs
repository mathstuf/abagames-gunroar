// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying LICENSE file for details.

use crates::abagames_util::{Pool, Rand};
use crates::cgmath::{Angle, Rad, Vector2, Vector3};

use game::entities::enemy::EnemyKind;
use game::entities::field::Field;
use game::entities::particles::{Wake, WakeDirection};
use game::entities::shapes::{BaseShape, Shape, ShapeKind};

const MIDDLE_COLOR: Vector3<f32> = Vector3 { x: 1., y: 0.6, z: 0.5, };

lazy_static! {
    static ref SMALL: BaseShape =
        BaseShape::new(ShapeKind::Ship, 1., 0.5, 0.1, (0.9, 0.7, 0.5).into());
    static ref SMALL_DAMAGED: BaseShape =
        BaseShape::new(ShapeKind::ShipDamaged, 1., 0.5, 0.1, (0.5, 0.5, 0.9).into());
    static ref SMALL_BRIDGE: BaseShape =
        BaseShape::new(ShapeKind::Bridge, 0.66, 0., 0., (1., 0.2, 0.3).into());
    static ref MIDDLE: BaseShape =
        BaseShape::new(ShapeKind::Ship, 1., 0.7, 0.33, MIDDLE_COLOR);
    static ref MIDDLE_DAMAGED: BaseShape =
        BaseShape::new(ShapeKind::ShipDamaged, 1., 0.7, 0.33, (0.5, 0.5, 0.9).into());
    static ref MIDDLE_DESTROYED: BaseShape =
        BaseShape::new(ShapeKind::ShipDestroyed, 1., 0.7, 0.33, (0., 0., 0.).into());
    static ref MIDDLE_BRIDGE: BaseShape =
        BaseShape::new(ShapeKind::Bridge, 0.66, 0., 0., (1., 0.2, 0.3).into());
    static ref PLATFORM: BaseShape =
        BaseShape::new(ShapeKind::Platform, 1., 0., 0., (1., 0.6, 0.7).into());
    static ref PLATFORM_DAMAGED: BaseShape =
        BaseShape::new(ShapeKind::PlatformDamaged, 1., 0., 0., (0.5, 0.5, 0.9).into());
    static ref PLATFORM_DESTROYED: BaseShape =
        BaseShape::new(ShapeKind::PlatformDestroyed, 1., 0., 0., (1., 0.6, 0.7).into());
    static ref PLATFORM_BRIDGE: BaseShape =
        BaseShape::new(ShapeKind::Bridge, 0.5, 0., 0., (1., 0.2, 0.3).into());
}

#[derive(Debug, Clone, Copy)]
pub struct EnemyShapes {
    normal: Shape,
    damaged: Shape,
    destroyed: Option<Shape>,
    bridge: Shape,
}

impl EnemyShapes {
    pub fn new(kind: EnemyKind) -> Self {
        match kind {
            EnemyKind::SmallShip => {
                EnemyShapes {
                    normal: Shape::new(&SMALL),
                    damaged: Shape::new(&SMALL_DAMAGED),
                    destroyed: None,
                    bridge: Shape::new_collidable(&SMALL_BRIDGE),
                }
            },
            EnemyKind::Ship => {
                EnemyShapes {
                    normal: Shape::new(&MIDDLE),
                    damaged: Shape::new(&MIDDLE_DAMAGED),
                    destroyed: Some(Shape::new(&MIDDLE_DESTROYED)),
                    bridge: Shape::new_collidable(&MIDDLE_BRIDGE),
                }
            },
            EnemyKind::Platform => {
                EnemyShapes {
                    normal: Shape::new(&PLATFORM),
                    damaged: Shape::new(&PLATFORM_DAMAGED),
                    destroyed: Some(Shape::new(&PLATFORM_DESTROYED)),
                    bridge: Shape::new_collidable(&PLATFORM_BRIDGE),
                }
            },
        }
    }

    pub fn normal(&self) -> &Shape {
        &self.normal
    }

    pub fn damaged(&self) -> &Shape {
        &self.damaged
    }

    pub fn destroyed(&self) -> Option<&Shape> {
        self.destroyed.as_ref()
    }

    pub fn bridge(&self) -> &Shape {
        &self.bridge
    }

    pub fn color(factor: f32) -> Vector3<f32> {
        MIDDLE_COLOR * factor * 0.5
    }

    pub fn set_color(&mut self, color: Vector3<f32>) {
        self.destroyed.as_mut().map(|shape| shape.set_color(color));
    }

    pub fn collides(&self, hit: Vector2<f32>, collision: Vector2<f32>) -> bool {
        self.bridge.collides(hit, collision)
    }

    pub fn add_wake(&self, field: &Field, pos: Vector2<f32>, angle: Rad<f32>, speed: f32, size_factor: f32, wakes: &mut Pool<Wake>, rand: &mut Rand) {
        let speed = f32::min(0.1, speed);
        let size = f32::min(10., self.normal.size());

        let inner_angle = Rad::turn_div_4() + Rad(0.7);
        let pos_size = size * 0.5 * size_factor;

        let angle_comps: Vector2<f32> = (angle + inner_angle).sin_cos().into();
        let wake_pos = pos + angle_comps * pos_size;
        wakes.get_force()
            .init(field, wake_pos, angle + Rad::turn_div_2() - Rad(0.2 + rand.next_float_signed(0.1)), speed, 40, size * 32. * size_factor, WakeDirection::Forward);

        let angle_comps: Vector2<f32> = (angle - inner_angle).sin_cos().into();
        let wake_pos = pos + angle_comps * pos_size;
        wakes.get_force()
            .init(field, wake_pos, angle + Rad::turn_div_2() + Rad(0.2 + rand.next_float_signed(0.1)), speed, 40, size * 32. * size_factor, WakeDirection::Forward);
    }
}
