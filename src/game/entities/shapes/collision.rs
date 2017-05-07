// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

use crates::cgmath::Vector2;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CollisionResult {
    Hit,
    Miss,
}

pub trait Collidable {
    fn collision(&self) -> Vector2<f32>;

    fn collides_at(&self, pos: Vector2<f32>) -> CollisionResult {
        let collide = self.collision();
        pos.x <= collide.x && pos.y <= collide.y
    }

    fn collides_with(&self, pos: Vector2<f32>, other: &Collidable) -> CollisionResult {
        let collide = self.collision() + other.collision();
        pos.x <= collide.x && pos.y <= collide.y
    }
}

pub trait MaybeCollidable {
    fn collision(&self) -> Option<Vector2<f32>>;

    fn collides_at(&self, pos: Vector2<f32>) -> CollisionResult {
        let collide = self.collision();
        pos.x <= collide.x && pos.y <= collide.y
    }

    fn collides_with(&self, pos: Vector2<f32>, other: &Collidable) -> CollisionResult {
        let collide = self.collision() + other.collision();
        pos.x <= collide.x && pos.y <= collide.y
    }
}
