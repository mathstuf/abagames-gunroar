// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying LICENSE file for details.

use crates::abagames_util::{self, Rand};
use crates::cgmath::{Angle, Deg, Matrix4, Vector2, Vector3};
use crates::gfx;
use crates::itertools::Itertools;
use crates::rayon::prelude::*;

use game::entities::letter::{self, Letter};
use game::render::EncoderContext;

use std::f32;

const MAX_DIGIT: usize = 16;

#[derive(Debug, Clone, Copy)]
pub struct ScoreReel {
    score: u32,
    target_score: u32,
    actual_score: u32,
    digits: usize,

    reels: [NumberReel; MAX_DIGIT],
}

impl ScoreReel {
    pub fn new() -> Self {
        ScoreReel {
            score: 0,
            target_score: 0,
            actual_score: 0,
            digits: 1,

            reels: [NumberReel::new(); MAX_DIGIT],
        }
    }

    pub fn init(&mut self, digits: usize) {
        self.score = 0;
        self.target_score = 0;
        self.actual_score = 0;
        self.digits = digits;
        self.reels
            .par_iter_mut()
            .take(self.digits)
            .for_each(NumberReel::clear)
    }

    pub fn step(&mut self) {
        self.reels
            .par_iter_mut()
            .take(self.digits)
            .for_each(NumberReel::step)
    }

    pub fn draw<R, C>(&mut self, context: &mut EncoderContext<R, C>, letter: &Letter<R>,
                      pos: Vector2<f32>, scale: f32, rand: &mut Rand)
        where R: gfx::Resources,
              C: gfx::CommandBuffer<R>,
    {
        self.reels
            .iter_mut()
            .take(self.digits)
            .enumerate()
            .foreach(|(idx, reel)| {
                reel.draw(context,
                          letter,
                          pos - Vector2::unit_x() * (2. * (idx as f32) * scale),
                          scale,
                          rand)
            })
    }

    pub fn add_score(&mut self, score: u32) {
        self.target_score += score;
        self.reels
            .iter_mut()
            .take(self.digits)
            .fold(self.target_score, |score, reel| {
                reel.set_target(Deg((score * 360 / 10) as f32));
                score / 10
            });
    }

    pub fn accelerate(&mut self) {
        self.reels
            .par_iter_mut()
            .take(self.digits)
            .for_each(NumberReel::accelerate)
    }

    pub fn add_actual_score(&mut self, score: u32) {
        self.actual_score += score;
    }

    pub fn score(&self) -> u32 {
        self.actual_score
    }
}

const MIN_VELOCITY: f32 = 5.;

#[derive(Debug, Clone, Copy)]
struct NumberReel {
    degrees: Deg<f32>,
    target_degrees: Deg<f32>,
    ofs: f32,
    velocity_ratio: f32,
}

impl NumberReel {
    fn new() -> Self {
        NumberReel {
            degrees: Deg(0.),
            target_degrees: Deg(0.),
            ofs: 0.,
            velocity_ratio: 1.,
        }
    }

    fn clear(&mut self) {
        self.degrees = Deg(0.);
        self.target_degrees = Deg(0.);
        self.ofs = 0.;
        self.velocity_ratio = 1.;
    }

    fn step(&mut self) {
        let degrees_velocity = f32::max(MIN_VELOCITY,
                                        0.05 * (self.target_degrees - self.degrees).0);
        self.degrees = Deg(f32::min(self.degrees.0 + degrees_velocity * self.velocity_ratio,
                                    self.target_degrees.0));
    }

    // FIXME: Move calculations into a prep_draw method. This does mean that storage is higher
    // for the matrix bits.
    fn draw<R, C>(&mut self, context: &mut EncoderContext<R, C>, letter: &Letter<R>,
                  pos: Vector2<f32>, scale: f32, rand: &mut Rand)
        where R: gfx::Resources,
              C: gfx::CommandBuffer<R>,
    {
        let number = abagames_util::wrap_inc((self.degrees.0 * 10. / 360. + 0.99) as u32, 10);
        let norm_degrees = self.degrees.normalize();
        let rotation_base = Deg((norm_degrees.0 - (number as f32) * 360. / 10.) - 15.)
            .normalize() * 1.5;
        let scaling =
            Matrix4::from_translation(Vector3::unit_z() * -scale * 2.4) *
            Matrix4::from_nonuniform_scale(scale, scale, scale);
        let diff = 360. / 10. * 1.5;

        (0..3).fold((rotation_base, number), |(rotation, number), _| {
            let offset_pos = if self.ofs > 0.005 {
                pos +
                (Vector2::new(rand.next_int_signed(1) as f32,
                              rand.next_int_signed(1) as f32)) * self.ofs
            } else {
                pos
            };

            let transform =
                Matrix4::from_translation(offset_pos.extend(0.)) *
                Matrix4::from_axis_angle(Vector3::unit_x(), rotation) *
                scaling;

            let outline_color = f32::max(0., 1. - f32::abs((rotation.0 + 15.) / diff) / 2.);
            // FIXME: The calculation above seems to always be between -3 and -2, so hardcode
            // "white" here.
            let outline_color = 1.;
            let fill_color = outline_color / 2.;

            let digit = Self::for_digit(number);
            letter.draw_letter_with(context,
                                    transform,
                                    digit,
                                    letter::Style::Outline(&[outline_color,
                                                             outline_color,
                                                             outline_color,
                                                             1.]),
                                    letter::Screen::Perspective);
            letter.draw_letter_with(context,
                                    transform,
                                    digit,
                                    letter::Style::Filled(&[fill_color,
                                                            fill_color,
                                                            fill_color,
                                                            1.]),
                                    letter::Screen::Perspective);

            ((rotation + Deg(diff)).normalize(), abagames_util::wrap_dec(number, 10))
        });

        self.ofs *= 0.95;
    }

    fn set_target(&mut self, target: Deg<f32>) {
        if target.0 - self.target_degrees.0 > 1. {
            self.ofs += 0.1
        }

        self.target_degrees = target;
    }

    fn accelerate(&mut self) {
        self.velocity_ratio = 4.;
    }

    fn for_digit(digit: u32) -> char {
        match digit % 10 {
            0 => '0',
            1 => '1',
            2 => '2',
            3 => '3',
            4 => '4',
            5 => '5',
            6 => '6',
            7 => '7',
            8 => '8',
            9 => '9',
            _ => unreachable!(),
        }
    }
}
