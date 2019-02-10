// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying LICENSE file for details.

use crates::abagames_util::{Pool, PoolRemoval, Rand};
use crates::cgmath::{Angle, Deg, Matrix4, Rad, Vector2, Vector3};
use crates::itertools::Itertools;

use game::entities::bullet::Bullet;
use game::entities::crystal::Crystal;
use game::entities::enemy::Enemy;
use game::entities::field::{Field, FIELD_SIZE};
use game::entities::particles::{Fragment, Smoke, SmokeKind, Spark};
use game::entities::reel::ScoreReel;
use game::entities::score_indicator::ScoreIndicator;
use game::entities::stage::Stage;
use game::state::GameStateContext;

pub const SHOT_SPEED: f32 = 0.6;
const LANCE_SPEED: f32 = 0.5;

pub const MAX_SHOT_SIZE: usize = 50;

#[derive(Debug, Clone, Copy)]
pub struct Shot {
    pos: Vector2<f32>,
    count: u32,
    hit_count: u32,
    angle: Rad<f32>,
    damage: u32,
    lance: bool,
    collision: Vector2<f32>,
}

impl Shot {
    const fn new() -> Self {
        Shot {
            pos: Vector2::new(0., 0.),
            count: 0,
            hit_count: 0,
            angle: Rad(0.),
            damage: 0,
            lance: false,
            collision: Vector2::new(0., 0.),
        }
    }

    pub fn new_pool() -> Pool<Self> {
        Pool::new(MAX_SHOT_SIZE, Self::new)
    }

    pub fn init(&mut self, pos: Vector2<f32>, angle: Rad<f32>, lance: bool, damage: Option<u32>) {
        self.pos = pos;
        self.count = 0;
        self.hit_count = 0;
        self.angle = angle;
        self.damage = if let Some(damage) = damage {
            damage
        } else if lance {
            10
        } else {
            1
        };
        self.lance = lance;
        self.collision = if lance { (0.66, 0.66) } else { (0.33, 0.33) }.into();
    }

    pub fn step(
        &mut self,
        field: &Field,
        stage: &Stage,
        bullets: &mut Pool<Bullet>,
        enemies: &mut Pool<Enemy>,
        crystals: &mut Pool<Crystal>,
        fragments: &mut Pool<Fragment>,
        smokes: &mut Pool<Smoke>,
        sparks: &mut Pool<Spark>,
        indicators: &mut Pool<ScoreIndicator>,
        reel: &mut ScoreReel,
        context: &mut GameStateContext,
        rand: &mut Rand,
    ) -> PoolRemoval {
        self.count = self.count.saturating_add(1);
        if self.hit_count > 0 {
            self.hit_count = self.hit_count.saturating_add(1);
            if self.hit_count > 30 {
                return self.remove();
            }
        }

        let speed = if self.lance {
            if self.count < 10 {
                LANCE_SPEED * ((self.count / 10) as f32)
            } else {
                LANCE_SPEED
            }
        } else {
            SHOT_SPEED
        };

        let angle_comps: Vector2<f32> = self.angle.sin_cos().into();
        self.pos += angle_comps * speed;
        self.pos.y -= field.last_scroll_y();

        let mut remove = field.block(self.pos).is_dry()
            || !field.is_in_outer_field(self.pos)
            || self.pos.y > FIELD_SIZE.y;

        if !self.lance {
            bullets.run(|bullet| {
                if bullet.is_destructible() {
                    let ret = bullet.check_shot_hit(self, smokes, rand);
                    remove = remove || ret == PoolRemoval::Remove;
                    ret
                } else {
                    PoolRemoval::Keep
                }
            });
        }
        let remove_enemy = enemies.iter_mut().any(|enemy| {
            enemy.check_shot_hit(
                self, stage, bullets, crystals, fragments, smokes, sparks, indicators, reel,
                context, rand,
            ) == PoolRemoval::Remove
        });

        if remove_enemy {
            context.audio
                .as_mut()
                .map(|audio| audio.mark_sfx("hit"));
        }

        if remove {
            if self.lance {
                (0..10).foreach(|_| {
                    let angle = self.angle + Rad(rand.next_float_signed(0.1));
                    let angle_comps: Vector2<f32> = angle.sin_cos().into();
                    let speed = rand.next_float(LANCE_SPEED);
                    smokes.get_force().init_2d(
                        self.pos,
                        (angle_comps * speed).extend(0.),
                        SmokeKind::LanceSpark,
                        30 + rand.next_int(30),
                        1.,
                        rand,
                    );
                    let angle = self.angle + Rad(rand.next_float_signed(0.1));
                    let angle_comps: Vector2<f32> = angle.sin_cos().into();
                    let speed = rand.next_float(LANCE_SPEED);
                    smokes.get_force().init_2d(
                        self.pos,
                        (-angle_comps * speed).extend(0.),
                        SmokeKind::LanceSpark,
                        30 + rand.next_int(30),
                        1.,
                        rand,
                    );
                });
            } else {
                let angle = self.angle + Rad(rand.next_float_signed(0.5));
                let angle_comps: Vector2<f32> = angle.sin_cos().into();
                let color = Vector3::new(
                    0.6 + rand.next_float_signed(0.4),
                    0.6 + rand.next_float_signed(0.4),
                    0.1,
                );
                sparks
                    .get_force()
                    .init(self.pos, angle_comps * SHOT_SPEED, color, 20);
                let angle = self.angle + Rad(rand.next_float_signed(0.5));
                let angle_comps: Vector2<f32> = angle.sin_cos().into();
                let color = Vector3::new(
                    0.6 + rand.next_float_signed(0.4),
                    0.6 + rand.next_float_signed(0.4),
                    0.1,
                );
                sparks
                    .get_force()
                    .init(self.pos, -angle_comps * SHOT_SPEED, color, 20);
            }

            PoolRemoval::Remove
        } else {
            PoolRemoval::Keep
        }
    }

    fn remove(&mut self) -> PoolRemoval {
        if self.lance && self.hit_count == 0 {
            self.hit_count = 1;
            PoolRemoval::Keep
        } else {
            PoolRemoval::Remove
        }
    }

    pub fn pos(&self) -> Vector2<f32> {
        self.pos
    }

    pub fn angle(&self) -> Rad<f32> {
        self.angle
    }

    pub fn damage(&self) -> u32 {
        self.damage
    }

    pub fn collision(&self) -> Vector2<f32> {
        self.collision
    }

    pub fn is_lance(&self) -> bool {
        self.lance
    }

    pub fn modelmat(&self) -> Matrix4<f32> {
        Matrix4::from_translation(self.pos.extend(0.))
            * Matrix4::from_axis_angle(Vector3::unit_z(), self.angle)
            * Matrix4::from_axis_angle(Vector3::unit_y(), Deg((self.count * 31) as f32))
    }
}
