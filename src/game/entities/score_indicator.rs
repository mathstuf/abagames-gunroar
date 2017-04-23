// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

use crates::abagames_util::{PoolRemoval, Rand};
use crates::cgmath::Vector2;
use crates::gfx;

use game::render::EncoderContext;
use game::state::GameStateContext;

use game::entities::letter::{self, Letter};
use game::entities::reel::ScoreReel;

use std::mem;
use std::ptr;

pub enum Indicator {
    Score,
    Multiplier,
}

pub enum FlyingTo {
    Right,
    Bottom,
}

pub struct Target {
    pub pos: Vector2<f32>,
    pub flying_to: FlyingTo,
    pub initial_velocity_ratio: f32,
    pub scale: f32,
    pub value: u64,
    pub count: u32,
}

impl Target {
    fn new() -> Self {
        Target {
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

pub struct ScoreIndicator {
    pos: Vector2<f32>,
    vel: Vector2<f32>,
    value: u64,
    indicator_type: Indicator,
    scale: f32,
    count: u32,
    alpha: f32,
    targets: [Target; MAX_TARGETS],
    target_index: usize,
    target_count: Option<usize>,
}

impl ScoreIndicator {
    pub fn new() -> Self {
        let mut targets: [Target; MAX_TARGETS];

        unsafe {
            targets = mem::uninitialized();

            for target in &mut targets[..] {
                ptr::write(target, Target::new());
            }
        }

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

            targets: targets,
        }
    }

    pub fn expire(&mut self, reel: &mut ScoreReel, context: &mut GameStateContext) {
        if let Some(target_count) = self.target_count {
            if let Indicator::Score = self.indicator_type {
                let target = &self.targets[target_count - 1];
                if let FlyingTo::Right = target.flying_to {
                    context.data.indicator_target_decrement();
                }
                reel.add_score(target.value);
            }
        }
    }

    pub fn set(&mut self, value: u64, indicator: Indicator, pos: Vector2<f32>, scale: f32) {
        self.value = value;
        self.indicator_type = indicator;
        self.scale = scale;
        self.pos = pos;
        self.alpha = 0.1;
    }

    pub fn add_targets<I>(&mut self, targets: I)
        where I: IntoIterator<Item = Target>,
    {
        let len = self.targets
            .iter_mut()
            .zip(targets.into_iter())
            .map(|(w, r)| {
                *w = r;
            })
            .collect::<Vec<_>>()
            .len();
        self.target_count = Some(len);
    }

    pub fn step(&mut self, reel: &mut ScoreReel, context: &mut GameStateContext, rand: &mut Rand) -> PoolRemoval {
        if self.target_count.is_none() {
            return PoolRemoval::Remove;
        }

        self.update_position();

        self.count -= 1;
        if self.count == 0 {
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

        // let vn = (((target.value - self.value) as f32) * 0.2) as u32;
        let vn = (target.value as i64 - self.value as i64) / 5;
        if -10 < vn && vn < 10 {
            self.value = target.value;
        } else {
            // self.value += vn;
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
        self.target_index += 1;
        if self.target_index > 0 {
            if let Some(ref mut audio) = context.audio {
                audio.mark_sfx("score_up.wav");
            }
        }

        if self.target_index >= self.target_count.expect("expected to have a target count") {
            let target = &self.targets[self.target_index];
            if let FlyingTo::Bottom = target.flying_to {
                reel.add_score(target.value);
            }
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
        let (prefix_char, floating_digits) = match self.indicator_type {
            Indicator::Score => (None, None),
            Indicator::Multiplier => (Some('x'), Some(3)),
        };
        let number_style = letter::NumberStyle {
            pad_to: None,
            prefix_char: prefix_char,
            floating_digits: floating_digits,
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
