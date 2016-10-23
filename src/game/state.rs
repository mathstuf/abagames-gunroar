// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

extern crate abagames_util;
use self::abagames_util::{Audio, Input};

extern crate gfx;

use super::entities::Entities;
use super::render::{EncoderContext, RenderContext};

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
    }

    fn init_game<R>(&self, context: &mut GameStateContext<R>)
        where R: gfx::Resources,
    {
    }

    pub fn step<R>(&self, context: &mut GameStateContext<R>, input: &Input)
        where R: gfx::Resources,
    {
        match *self {
            GameState::TitleState => self.step_title(context, input),
            GameState::PlayingState => self.step_game(context, input),
        }
    }

    pub fn step_title<R>(&self, context: &mut GameStateContext<R>, input: &Input)
        where R: gfx::Resources,
    {
    }

    pub fn step_game<R>(&self, context: &mut GameStateContext<R>, input: &Input)
        where R: gfx::Resources,
    {
    }

    pub fn draw<R, C>(&self, entities: &Entities<R>, context: &mut EncoderContext<R, C>)
        where R: gfx::Resources,
              C: gfx::CommandBuffer<R>,
    {
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