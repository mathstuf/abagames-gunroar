// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

extern crate abagames_util;
use self::abagames_util::{Audio, Input, Scancode, StepResult};

extern crate cgmath;
use self::cgmath::Vector2;

extern crate gfx;

use super::render::{EncoderContext, RenderContext};
use super::entities::Entities;
use super::entities::field::FieldMode;
use super::entities::letter;

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum GameMode {
    Normal,
    TwinStick,
    DoublePlay,
    DoublePlayTouch,
    Touch,
    Tilt,
    Mouse,
}

impl GameMode {
    pub fn name(&self) -> &str {
        match *self {
            GameMode::Normal => "NORMAL",
            GameMode::TwinStick => "TWIN STICK",
            GameMode::DoublePlay => "DOUBLE PLAY",
            GameMode::DoublePlayTouch => "DOUBLE PLAY TOUCH",
            GameMode::Touch => "TOUCH",
            GameMode::Tilt => "TILT",
            GameMode::Mouse => "MOUSE",
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum GameState {
    TitleState,
    PlayingState,
}

pub struct Scores;

impl Scores {
    pub fn high_for_mode(&self, mode: GameMode) -> u32 {
        // TODO: Implement.
        0
    }

    pub fn last(&self) -> u32 {
        // TODO: Implement.
        0
    }
}

pub struct GameData {
    reel_size: f32,
}

impl Default for GameData {
    fn default() -> Self {
        GameData {
            reel_size: REEL_SIZE_DEFAULT,
        }
    }
}

impl GameData {
    fn update_reel(&mut self) {
        self.reel_size += (REEL_SIZE_DEFAULT - self.reel_size) * 0.05;
    }

    fn shrink_reel(&mut self) {
        self.reel_size += (REEL_SIZE_SMALL - self.reel_size) * 0.08;
    }
}

pub struct GameStateContext<'a, 'b: 'a, R>
    where R: gfx::Resources,
{
    pub audio: Option<&'a mut Audio<'b>>,

    pub entities: &'a mut Entities<R>,

    pub data: &'a mut GameData,
}

static SCROLL_SPEED_BASE: f32 = 0.025;
static REEL_SIZE_DEFAULT: f32 = 0.5;
static REEL_SIZE_SMALL: f32 = 0.01;

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

        context.entities.title.init();
        context.entities.field.init(0);
    }

    fn init_game<R>(&self, context: &mut GameStateContext<R>)
        where R: gfx::Resources,
    {
        context.entities.field.init(0);
        context.entities.reel.init(0);
        context.entities.reel.clear(9);
        context.entities.reel.set_score(0);
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
        context.entities.title.step();
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

        context.entities.field.step();
        context.entities.reel.step();

        context.data.update_reel();

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

    pub fn draw<R, C>(&self, entities: &mut Entities<R>, encoder: &mut EncoderContext<R, C>)
        where R: gfx::Resources,
              C: gfx::CommandBuffer<R>,
    {
        match *self {
            GameState::TitleState => self.draw_title(entities, encoder),
            GameState::PlayingState => self.draw_game(entities, encoder),
        }
    }

    pub fn draw_title<R, C>(&self, entities: &mut Entities<R>, encoder: &mut EncoderContext<R, C>)
        where R: gfx::Resources,
              C: gfx::CommandBuffer<R>,
    {
        entities.field.draw_panels(encoder);
    }

    pub fn draw_game<R, C>(&self, entities: &mut Entities<R>, encoder: &mut EncoderContext<R, C>)
        where R: gfx::Resources,
              C: gfx::CommandBuffer<R>,
    {
        entities.field.draw_panels(encoder);
    }

    pub fn draw_luminous<R, C>(&self, entities: &mut Entities<R>,
                               encoder: &mut EncoderContext<R, C>)
        where R: gfx::Resources,
              C: gfx::CommandBuffer<R>
    {
    }

    pub fn draw_front<R, C>(&self, entities: &mut Entities<R>,
                            encoder: &mut EncoderContext<R, C>, data: &GameData)
        where R: gfx::Resources,
              C: gfx::CommandBuffer<R>,
    {
        match self.state {
            State::Title => self.draw_front_title(entities, encoder, data),
            State::Playing => self.draw_front_game(entities, encoder, data),
        }
    }

    pub fn draw_front_title<C>(&mut self, entities: &mut Entities<R>,
                               encoder: &mut EncoderContext<R, C>, data: &GameData)
        where C: gfx::CommandBuffer<R>,
    {
    }

    pub fn draw_front_game<C>(&mut self, entities: &mut Entities<R>,
                              encoder: &mut EncoderContext<R, C>, data: &GameData)
        where C: gfx::CommandBuffer<R>,
    {
        let reel_size_offset = (REEL_SIZE_DEFAULT - data.reel_size) * 3.;
        entities.reel.draw(encoder,
                           &entities.letter,
                           Vector2::new(11.5 + reel_size_offset,
                                        -8.2 - reel_size_offset),
                           data.reel_size);
    }

    pub fn draw_ortho<R, C>(&self, entities: &mut Entities<R>, encoder: &mut EncoderContext<R, C>)
        where R: gfx::Resources,
              C: gfx::CommandBuffer<R>,
    {
        match *self {
            GameState::TitleState => self.draw_ortho_title(entities, encoder),
            GameState::PlayingState => self.draw_ortho_game(entities, encoder),
        }
    }

    pub fn draw_ortho_title<R, C>(&self, entities: &mut Entities<R>,
                                  encoder: &mut EncoderContext<R, C>)
        where R: gfx::Resources,
              C: gfx::CommandBuffer<R>,
    {
        // TODO: Store this somewhere.
        let scores = Scores;
        entities.title.draw(encoder, &entities.letter, &scores);
    }

    pub fn draw_ortho_game<R, C>(&self, entities: &mut Entities<R>,
                                 encoder: &mut EncoderContext<R, C>)
        where R: gfx::Resources,
              C: gfx::CommandBuffer<R>,
    {
    }
}
