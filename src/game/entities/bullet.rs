// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

use crates::abagames_util::{Pool, PoolRemoval, Rand};
use crates::cgmath::{Angle, Deg, Rad, Matrix4, Vector2, Vector3};

use game::entities::crystal::Crystal;
use game::entities::field::{Block, Field};
use game::entities::particles::{Smoke, SmokeKind, Wake, WakeDirection};
use game::entities::shapes::bullet::BulletShapeKind;
use game::entities::ship::Ship;
use game::entities::shot::Shot;

use std::f32;

#[derive(Debug, Clone, Copy)]
pub struct BulletShape {
    kind: BulletShapeKind,
    size: f32,
}

impl BulletShape {
    fn new() -> Self {
        BulletShape {
            kind: BulletShapeKind::Normal,
            size: 1.,
        }
    }

    fn of_kind(kind: BulletShapeKind, size: f32) -> Self {
        BulletShape {
            kind: kind,
            size: size,
        }
    }
}

#[derive(Debug, Clone, Copy)]
pub struct Bullet {
    pos: Vector2<f32>,
    prev_pos: Vector2<f32>,
    angle: Rad<f32>,
    speed: f32,
    target_angle: Rad<f32>,
    target_speed: f32,
    size: f32,
    count: u32,
    range: f32,
    shape: BulletShape,
    index: u32,
    done: bool,
}

const MAX_BULLET_SIZE: usize = 240;

impl Bullet {
    fn new() -> Self {
        Bullet {
            pos: (0., 0.).into(),
            prev_pos: (0., 0.).into(),
            angle: Rad(0.),
            speed: 1.,
            target_angle: Rad(0.),
            target_speed: 1.,
            size: 1.,
            count: 0,
            range: 1.,
            shape: BulletShape::new(),
            index: 0,
            done: false,
        }
    }

    pub fn new_pool() -> Pool<Self> {
        Pool::new(MAX_BULLET_SIZE, Self::new)
    }

    pub fn init(&mut self, index: u32, pos: Vector2<f32>, angle: Rad<f32>, speed: f32, size: f32,
                kind: BulletShapeKind, range: f32, start_speed: f32, start_angle: Option<Rad<f32>>) {
        self.index = index;
        self.pos = pos;
        self.prev_pos = pos;
        self.speed = start_speed;
        self.angle = start_angle.unwrap_or(angle);
        self.target_angle = angle;
        self.target_speed = speed;
        self.size = size;
        self.range = range;
        self.shape = BulletShape::of_kind(kind, size);
        self.count = 0;
    }

    pub fn step(&mut self, field: &Field, ship: &Ship, smokes: &mut Pool<Smoke>, wakes: &mut Pool<Wake>, rand: &mut Rand) -> PoolRemoval {
        self.prev_pos = self.pos;

        if self.count < 29 {
            self.speed += (self.target_speed - self.speed) * 0.066;
            self.angle += ((self.target_angle - self.angle).normalize() - Rad::turn_div_2()) * 0.066;
        } else if self.count == 29 {
            self.speed = self.target_speed;
            self.angle = self.target_angle;
        }

        if field.is_in_outer_field(self.pos) {
            // gameManager.addSlowdownRatio(self.speed * 0.24);
            unimplemented!()
        }

        let angle_comps: Vector2<f32> = self.angle.sin_cos().into();
        self.pos += angle_comps * self.speed;
        self.pos.y -= field.last_scroll_y();

        if ship.is_hit(self.pos, self.prev_pos) || !field.is_in_outer_field_no_top(self.pos) {
            return PoolRemoval::Remove;
        }

        self.count += 1;
        self.range -= self.speed;

        let block = field.block(self.pos);
        if self.range <= 0.|| block.is_land() {
            self.start_disappear(block, field, smokes, wakes, rand)
        } else {
            PoolRemoval::Keep
        }
    }

    fn start_disappear(&self, block: Block, field: &Field, smokes: &mut Pool<Smoke>, wakes: &mut Pool<Wake>, rand: &mut Rand) -> PoolRemoval {
        if block.is_land() {
            let angle_comps: Vector2<f32> = self.angle.sin_cos().into();
            let vel = angle_comps * self.speed * 0.2;
            smokes.get_force()
                .init(self.pos.extend(0.), vel.extend(0.), SmokeKind::Sand, 30, self.size * 0.5, rand);
        } else {
            wakes.get_force()
                .init(field, self.pos, self.angle, self.speed, 60, self.size * 3., WakeDirection::Reverse);
        }
        PoolRemoval::Remove
    }

    pub fn check_shot_hit(&self, shot: &Shot, smokes: &mut Pool<Smoke>, rand: &mut Rand) -> PoolRemoval {
        let offset = shot.pos() - self.pos();
        if offset.x.abs() + offset.y.abs() < 0.5 {
            smokes.get()
                .map(|smoke| {
                    let angle_comps: Vector2<f32> = self.angle.sin_cos().into();
                    smoke.init_2d(shot.pos(), (angle_comps * self.speed).extend(0.), SmokeKind::Spark, 30, self.size * 0.5, rand);
                });
            PoolRemoval::Remove
        } else {
            PoolRemoval::Keep
        }
    }

    pub fn into_crystal(&mut self, crystals: &mut Pool<Crystal>) {
        crystals.get()
            .map(|crystal| crystal.init(self.pos));
        self.done = true;
    }

    pub fn index(&self) -> u32 {
        self.index
    }

    pub fn pos(&self) -> Vector2<f32> {
        self.pos
    }

    pub fn is_destructible(&self) -> bool {
        self.shape().is_destructible()
    }

    pub fn shape(&self) -> BulletShapeKind {
        self.shape.kind
    }

    pub fn modelmat(&self) -> Matrix4<f32> {
        let translation = Matrix4::from_translation(self.pos.extend(0.));
        let z_rotation = Matrix4::from_axis_angle(Vector3::unit_z(), Deg((self.count as f32) * 13.));
        if self.is_destructible() {
            translation * z_rotation
        } else {
            let y_rotation = Matrix4::from_axis_angle(Vector3::unit_y(), self.angle);
            translation * y_rotation * z_rotation
        }
    }
}