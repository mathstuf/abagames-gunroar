// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

extern crate abagames_util;
use self::abagames_util::{Audio, Input, Scancode, StepResult};

extern crate gfx;

use super::render::{EncoderContext, RenderContext};
use super::entities::Entities;
use super::entities::field::FieldMode;
use super::entities::letter::{LetterDirection, LetterStyle};

pub enum GameMode {
    Normal,
    TwinStick,
    DoublePlay,
    DoublePlayTouch,
    Touch,
    Tilt,
    Mouse,
}

pub enum GameState {
    TitleState,
    PlayingState,
}

pub struct GameStateContext<'a, 'b: 'a, R>
    where R: gfx::Resources,
{
    pub audio: Option<&'a mut Audio<'b>>,

    pub entities: &'a mut Entities<R>,
}

static SCROLL_SPEED_BASE: f32 = 0.025;

impl GameState {
    pub fn init<R>(&self, context: &mut GameStateContext<R>)
        where R: gfx::Resources,
    {
        match *self {
            GameState::TitleState => self.init_title(context),
            GameState::PlayingState => self.init_game(context),
        }
    }

    fn init_title<R>(&self, context: &mut GameStateContext<R>)
        where R: gfx::Resources,
    {
        if let Some(ref mut audio) = context.audio {
            audio.set_music_enabled(false)
                .set_sfx_enabled(false)
                .halt();
        }

        context.entities.field.init(0);
    }

    fn init_game<R>(&self, context: &mut GameStateContext<R>)
        where R: gfx::Resources,
    {
        context.entities.field.init(0);
    }

    pub fn step<R>(&mut self, context: &mut GameStateContext<R>, input: &Input) -> StepResult
        where R: gfx::Resources,
    {
        match *self {
            GameState::TitleState => self.step_title(context, input),
            GameState::PlayingState => self.step_game(context, input),
        }
    }

    pub fn step_title<R>(&mut self, context: &mut GameStateContext<R>, input: &Input) -> StepResult
        where R: gfx::Resources,
    {
        context.entities.field.step();
        context.entities.field.scroll(SCROLL_SPEED_BASE, FieldMode::Demo);

        if input.keyboard.is_scancode_pressed(Scancode::Escape) {
            *self = GameState::PlayingState;
            StepResult::Done
        } else {
            StepResult::Slowdown(0.)
        }
    }

    pub fn step_game<R>(&mut self, context: &mut GameStateContext<R>, input: &Input) -> StepResult
        where R: gfx::Resources,
    {
        if input.keyboard.is_scancode_pressed(Scancode::Escape) {
            *self = GameState::TitleState;
        }

        StepResult::Slowdown(0.)
    }

    pub fn prep_draw<R, F>(&self, entities: &mut Entities<R>, factory: &mut F)
        where R: gfx::Resources,
              F: gfx::Factory<R>,
    {
        match *self {
            GameState::TitleState => self.prep_draw_title(entities, factory),
            GameState::PlayingState => self.prep_draw_game(entities, factory),
        }
    }

    pub fn prep_draw_title<R, F>(&self, entities: &mut Entities<R>, factory: &mut F)
        where R: gfx::Resources,
              F: gfx::Factory<R>,
    {
        entities.field.prep_draw(factory);
    }

    pub fn prep_draw_game<R, F>(&self, entities: &mut Entities<R>, factory: &mut F)
        where R: gfx::Resources,
              F: gfx::Factory<R>,
    {
        entities.field.prep_draw(factory);
    }

    pub fn draw<R, C>(&self, entities: &Entities<R>, context: &mut EncoderContext<R, C>)
        where R: gfx::Resources,
              C: gfx::CommandBuffer<R>,
    {
        match *self {
            GameState::TitleState => self.draw_title(entities, context),
            GameState::PlayingState => self.draw_game(entities, context),
        }
    }

    pub fn draw_title<R, C>(&self, entities: &Entities<R>, context: &mut EncoderContext<R, C>)
        where R: gfx::Resources,
              C: gfx::CommandBuffer<R>,
    {
        entities.field.draw_panels(context);
    }

    pub fn draw_game<R, C>(&self, entities: &Entities<R>, context: &mut EncoderContext<R, C>)
        where R: gfx::Resources,
              C: gfx::CommandBuffer<R>,
    {
        entities.field.draw_panels(context);
    }

    pub fn draw_luminous<R, C>(&self, entities: &Entities<R>, context: &mut EncoderContext<R, C>)
        where R: gfx::Resources,
              C: gfx::CommandBuffer<R>,
    {
    }

    pub fn draw_front<R, C>(&self, entities: &Entities<R>, context: &mut EncoderContext<R, C>)
        where R: gfx::Resources,
              C: gfx::CommandBuffer<R>,
    {
    }

    pub fn draw_ortho<R, C>(&self, entities: &Entities<R>, context: &mut EncoderContext<R, C>)
        where R: gfx::Resources,
              C: gfx::CommandBuffer<R>,
    {
    }
}
