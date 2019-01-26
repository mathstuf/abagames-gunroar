// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying LICENSE file for details.

use crates::abagames_util::{Pool, PoolRemoval, Rand};
use crates::cgmath::Vector2;
use crates::gfx;
use crates::itertools::Itertools;

use game::render::EncoderContext;
use game::state::GameStateContext;

use game::entities::letter::{self, Letter};
use game::entities::reel::ScoreReel;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Indicator {
    Score,
    Multiplier,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FlyingTo {
    Right,
    Bottom,
}

#[derive(Debug, Clone, Copy)]
pub struct ScoreTarget {
    pub pos: Vector2<f32>,
    pub flying_to: FlyingTo,
    pub initial_velocity_ratio: f32,
    pub scale: f32,
    pub value: u32,
    pub count: u32,
}

impl ScoreTarget {
    fn new() -> Self {
        ScoreTarget {
            pos: Vector2::new(0., 0.),
            flying_to: FlyingTo::Right,
            initial_velocity_ratio: 0.,
            scale: 0.,
            value: 0,
            count: 0,
        }
    }
}

const MAX_TARGETS: usize = 4;
const MAX_INDICATORS: usize = 50;

#[derive(Debug, Clone, Copy)]
pub struct ScoreIndicator {
    pos: Vector2<f32>,
    vel: Vector2<f32>,
    value: u32,
    indicator_type: Indicator,
    scale: f32,
    count: u32,
    alpha: f32,
    targets: [ScoreTarget; MAX_TARGETS],
    target_index: usize,
    target_count: Option<usize>,
}

impl ScoreIndicator {
    fn new() -> Self {
        ScoreIndicator {
            pos: Vector2::new(0., 0.),
            vel: Vector2::new(0., 0.),
            value: 0,
            indicator_type: Indicator::Score,
            scale: 1.,
            count: 0,
            alpha: 0.,
            target_index: 0,
            target_count: None,

            targets: [ScoreTarget::new(); MAX_TARGETS],
        }
    }

    pub fn new_pool() -> Pool<Self> {
        Pool::new(MAX_INDICATORS, Self::new)
    }

    pub fn init<'a, I>(&mut self, value: u32, indicator: Indicator, pos: Vector2<f32>, scale: f32, targets: I, reel: &mut ScoreReel, context: &mut GameStateContext, rand: &mut Rand)
        where I: IntoIterator<Item = &'a ScoreTarget>,
    {
        if let Some(target_count) = self.target_count {
            if let Indicator::Score = self.indicator_type {
                let target = &self.targets[target_count - 1];
                if let FlyingTo::Right = target.flying_to {
                    context.data.indicator_target_decrement();
                }
                reel.add_score(target.value);
            }
        }

        self.value = value;
        self.indicator_type = indicator;
        self.scale = scale;
        self.pos = pos;
        self.alpha = 0.1;
        self.target_count = Some(0);
        let count = self.targets
            .iter_mut()
            .set_from(targets.into_iter().cloned());
        self.target_count = Some(count);
        self.target_index = 0;
        self.next_target(reel, context, rand);
    }

    pub fn step(&mut self, reel: &mut ScoreReel, context: &mut GameStateContext, rand: &mut Rand) -> PoolRemoval {
        if self.target_count.is_none() {
            return PoolRemoval::Remove;
        }

        self.update_position();

        self.count = self.count.saturating_sub(1);
        if self.count == 0 {
            self.target_index += 1;
            self.next_target(reel, context, rand)
        } else {
            PoolRemoval::Keep
        }
    }

    fn update_position(&mut self) {
        let target = &self.targets[self.target_index];
        let pos_diff = target.pos - self.pos;

        match target.flying_to {
            FlyingTo::Right => {
                self.vel.x += pos_diff.x * 0.0036;
                self.pos.y += pos_diff.y * 0.1;
                if f32::abs(pos_diff.y) < 0.5 {
                    self.pos.y += pos_diff.y * 0.33;
                }
                self.alpha += (1. - self.alpha) * 0.03;
            },
            FlyingTo::Bottom => {
                self.pos.x += pos_diff.x * 0.1;
                self.vel.y += pos_diff.y * 0.0036;
                self.alpha *= 0.97;
            },
        }

        self.vel *= 0.98;
        self.scale += (target.scale - self.scale) * 0.025;
        self.pos += self.vel;

        let vn = (target.value - self.value) / 5;
        if vn < 10 {
            self.value = target.value;
        } else {
            self.value += vn;
        };

        match target.flying_to {
            FlyingTo::Right => {
                if self.pos.x > target.pos.x {
                    self.pos.x = target.pos.x;
                    self.vel.x *= -0.05;
                }
            },
            FlyingTo::Bottom => {
                if self.pos.y < target.pos.y {
                    self.pos.y = target.pos.y;
                    self.vel.y *= -0.05;
                }
            },
        }
    }

    fn next_target(&mut self, reel: &mut ScoreReel, context: &mut GameStateContext, rand: &mut Rand) -> PoolRemoval {
        if self.target_index > 0 {
            context.audio.mark_sfx("score_up");
        }

        if self.target_index >= self.target_count.expect("expected to have a target count") {
            let target = &self.targets[self.target_index];
            if let FlyingTo::Bottom = target.flying_to {
                reel.add_score(target.value);
            }
            self.target_count = None;
            return PoolRemoval::Remove;
        }

        let target = &self.targets[self.target_index];
        match target.flying_to {
            FlyingTo::Right => {
                self.vel = Vector2::new(-0.3 + rand.next_float_signed(0.05),
                                        rand.next_float_signed(0.1));
            },
            FlyingTo::Bottom => {
                self.vel = Vector2::new(rand.next_float_signed(0.1),
                                        -0.3 + rand.next_float_signed(0.05));
                context.data.indicator_target_decrement();
            },
        }

        self.vel *= target.initial_velocity_ratio;
        self.count = target.count;

        PoolRemoval::Keep
    }

    pub fn draw<R, C>(&mut self, context: &mut EncoderContext<R, C>, letter: &Letter<R>)
        where R: gfx::Resources,
              C: gfx::CommandBuffer<R>,
    {
        let number_style = match self.indicator_type {
            Indicator::Score => letter::NumberStyle::score(),
            Indicator::Multiplier => letter::NumberStyle::multiplier(),
        };

        letter.draw_number(context,
                           self.value as u32,
                           letter::Style::Outline(&[self.alpha,
                                                    self.alpha,
                                                    self.alpha,
                                                    1.]),
                           letter::Location::new_persp(self.pos, self.scale),
                           number_style);
    }
}
