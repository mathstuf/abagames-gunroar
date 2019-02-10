// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying LICENSE file for details.

use crates::cgmath::{Vector2, Vector3};

use game::entities::shapes::{BaseShape, Shape, ShapeKind};

lazy_static! {
    static ref NORMAL: BaseShape =
        BaseShape::new(ShapeKind::Turret, 1., 0., 0., (1., 0.8, 0.8).into());
    static ref DAMAGED: BaseShape =
        BaseShape::new(ShapeKind::TurretDamaged, 1., 0., 0., (0.9, 0.9, 1.).into());
    static ref DESTROYED: BaseShape = BaseShape::new(
        ShapeKind::TurretDestroyed,
        1.,
        0.,
        0.,
        (0.8, 0.33, 0.66).into()
    );

    static ref NORMAL_SHAPE: Shape = Shape::new_collidable(&NORMAL);
    static ref DAMAGED_SHAPE: Shape = Shape::new(&DAMAGED);
}

#[derive(Debug, Clone, Copy)]
pub struct TurretShapes {
    normal: &'static Shape,
    damaged: &'static Shape,
    destroyed: Shape,
}

impl TurretShapes {
    pub fn new() -> Self {
        TurretShapes {
            normal: &*NORMAL_SHAPE,
            damaged: &*DAMAGED_SHAPE,
            destroyed: Shape::new(&DESTROYED),
        }
    }

    pub fn normal(&self) -> &Shape {
        self.normal
    }

    pub fn damaged(&self) -> &Shape {
        self.damaged
    }

    pub fn destroyed(&self) -> &Shape {
        &self.destroyed
    }

    pub fn set_color(&mut self, color: Vector3<f32>) {
        self.destroyed.set_color(color);
    }

    pub fn collides(&self, hit: Vector2<f32>, collision: Vector2<f32>) -> bool {
        self.normal.collides(hit, collision)
    }
}
