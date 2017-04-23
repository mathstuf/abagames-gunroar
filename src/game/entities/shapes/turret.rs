// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

use game::entities::shapes::{BaseShape, Shape, ShapeKind};

use std::ops::{Deref, DerefMut};

lazy_static! {
    static ref NORMAL: BaseShape =
        BaseShape::new(ShapeKind::Turret, 1., 0., 0., (1., 0.8, 0.8).into());
    static ref DAMAGED: BaseShape =
        BaseShape::new(ShapeKind::TurretDamaged, 1., 0., 0., (0.9, 0.9, 1.).into());
    static ref DESTROYED: BaseShape =
        BaseShape::new(ShapeKind::TurretDestroyed, 1., 0., 0., (0.8, 0.33, 0.66).into());
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TurretShapeKind {
    Normal,
    Damaged,
    Destroyed,
}

#[derive(Debug, Clone, Copy)]
pub struct TurretShape {
    kind: TurretShapeKind,
    normal: Shape,
    damaged: Shape,
    destroyed: Shape,
}

impl TurretShape {
    pub fn new(kind: TurretShapeKind) -> Self {
        TurretShape {
            kind: kind,
            normal: Shape::new_collidable(&NORMAL),
            damaged: Shape::new(&DAMAGED),
            destroyed: Shape::new(&DESTROYED),
        }
    }

    pub fn update(&mut self, kind: TurretShapeKind) {
        self.kind = kind;
    }
}

impl Deref for TurretShape {
    type Target = Shape;

    fn deref(&self) -> &Shape {
        match self.kind {
            TurretShapeKind::Normal => &self.normal,
            TurretShapeKind::Damaged => &self.damaged,
            TurretShapeKind::Destroyed => &self.destroyed,
        }
    }
}

impl DerefMut for TurretShape {
    fn deref_mut(&mut self) -> &mut Shape {
        match self.kind {
            TurretShapeKind::Normal => &mut self.normal,
            TurretShapeKind::Damaged => &mut self.damaged,
            TurretShapeKind::Destroyed => &mut self.destroyed,
        }
    }
}
