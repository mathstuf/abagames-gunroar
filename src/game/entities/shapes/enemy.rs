// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

use game::entities::shapes::{BaseShape, Shape, ShapeKind};

use std::ops::{Deref, DerefMut};

const MIDDLE_COLOR_R: f32 = 1.;
const MIDDLE_COLOR_G: f32 = 0.6;
const MIDDLE_COLOR_B: f32 = 0.5;

lazy_static! {
    static ref SMALL: BaseShape =
        BaseShape::new(ShapeKind::Ship, 1., 0.5, 0.1, (0.9, 0.7, 0.5).into());
    static ref SMALL_DAMAGED: BaseShape =
        BaseShape::new(ShapeKind::ShipDamaged, 1., 0.5, 0.1, (0.5, 0.5, 0.9).into());
    static ref SMALL_BRIDGE: BaseShape =
        BaseShape::new(ShapeKind::Bridge, 0.66, 0., 0., (1., 0.2, 0.3).into());
    static ref MIDDLE: BaseShape =
        BaseShape::new(ShapeKind::Ship, 1., 0.7, 0.33, (MIDDLE_COLOR_R, MIDDLE_COLOR_G, MIDDLE_COLOR_B).into());
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

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EnemyShapeKind {
    Small,
    SmallDamaged,
    SmallBridge,
    Middle,
    MiddleDamaged,
    MiddleDestroyed,
    MiddleBridge,
    Platform,
    PlatformDamaged,
    PlatformDestroyed,
    PlatformBridge,
}

#[derive(Debug, Clone, Copy)]
pub struct EnemyShape {
    kind: EnemyShapeKind,
    small: Shape,
    small_damaged: Shape,
    small_bridge: Shape,
    middle: Shape,
    middle_damaged: Shape,
    middle_destroyed: Shape,
    middle_bridge: Shape,
    platform: Shape,
    platform_damaged: Shape,
    platform_destroyed: Shape,
    platform_bridge: Shape,
}

impl EnemyShape {
    pub fn new(kind: EnemyShapeKind) -> Self {
        EnemyShape {
            kind: kind,
            small: Shape::new(&SMALL),
            small_damaged: Shape::new(&SMALL_DAMAGED),
            small_bridge: Shape::new_collidable(&SMALL_BRIDGE),
            middle: Shape::new(&MIDDLE),
            middle_damaged: Shape::new(&MIDDLE_DAMAGED),
            middle_destroyed: Shape::new(&MIDDLE_DESTROYED),
            middle_bridge: Shape::new_collidable(&MIDDLE_BRIDGE),
            platform: Shape::new(&PLATFORM),
            platform_damaged: Shape::new(&PLATFORM_DAMAGED),
            platform_destroyed: Shape::new(&PLATFORM_DESTROYED),
            platform_bridge: Shape::new_collidable(&PLATFORM_BRIDGE),
        }
    }

    pub fn update(&mut self, kind: EnemyShapeKind) {
        self.kind = kind;
    }
}

impl Deref for EnemyShape {
    type Target = Shape;

    fn deref(&self) -> &Shape {
        match self.kind {
            EnemyShapeKind::Small => &self.small,
            EnemyShapeKind::SmallDamaged => &self.small_damaged,
            EnemyShapeKind::SmallBridge => &self.small_bridge,
            EnemyShapeKind::Middle => &self.middle,
            EnemyShapeKind::MiddleDamaged => &self.middle_damaged,
            EnemyShapeKind::MiddleDestroyed => &self.middle_destroyed,
            EnemyShapeKind::MiddleBridge => &self.middle_bridge,
            EnemyShapeKind::Platform => &self.platform,
            EnemyShapeKind::PlatformDamaged => &self.platform_damaged,
            EnemyShapeKind::PlatformDestroyed => &self.platform_destroyed,
            EnemyShapeKind::PlatformBridge => &self.platform_bridge,
        }
    }
}

impl DerefMut for EnemyShape {
    fn deref_mut(&mut self) -> &mut Shape {
        match self.kind {
            EnemyShapeKind::Small => &mut self.             small,
            EnemyShapeKind::SmallDamaged => &mut self.small_damaged,
            EnemyShapeKind::SmallBridge => &mut self.small_bridge,
            EnemyShapeKind::Middle => &mut self.middle,
            EnemyShapeKind::MiddleDamaged => &mut self.middle_damaged,
            EnemyShapeKind::MiddleDestroyed => &mut self.middle_destroyed,
            EnemyShapeKind::MiddleBridge => &mut self.middle_bridge,
            EnemyShapeKind::Platform => &mut self.platform,
            EnemyShapeKind::PlatformDamaged => &mut self.platform_damaged,
            EnemyShapeKind::PlatformDestroyed => &mut self.platform_destroyed,
            EnemyShapeKind::PlatformBridge => &mut self.platform_bridge,
        }
    }
}
