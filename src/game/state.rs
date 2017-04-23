// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

use crates::abagames_util::{self, Audio, Input, Pool, Scancode, StepResult};
use crates::cgmath::Vector2;
use crates::itertools::Itertools;
use crates::gfx;

use game::render::{EncoderContext, RenderContext};
use game::entities;

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
enum State {
    Title,
    Playing,
}

impl Default for State {
    fn default() -> Self {
        State::Title
    }
}

pub struct GameState<R>
    where R: gfx::Resources,
{
    state: State,

    field: entities::field::Field,
    sparks: Pool<entities::particles::Spark>,
    wakes: Pool<entities::particles::Wake>,
    smokes: Pool<entities::particles::Smoke>,

    field_draw: entities::field::FieldDraw<R>,
    sparks_draw: entities::particles::SparkDraw<R>,
    wakes_draw: entities::particles::WakeDraw<R>,
    smokes_draw: entities::particles::SmokeDraw<R>,

    indicators: Pool<entities::score_indicator::ScoreIndicator>,
    letter: entities::letter::Letter<R>,
    reel: entities::reel::ScoreReel,
    title: entities::title::Title<R>,
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
    indicator_target: f32,
}

impl Default for GameData {
    fn default() -> Self {
        GameData {
            reel_size: REEL_SIZE_DEFAULT,
            indicator_target: INDICATOR_Y_MIN,
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

    pub fn indicator_target(&mut self) -> f32 {
        let range = INDICATOR_Y_MAX - INDICATOR_Y_MIN;
        self.indicator_target = abagames_util::wrap_inc_by(self.indicator_target,
                                                           range,
                                                           INDICATOR_Y_INTERVAL) +
            INDICATOR_Y_MIN;
        self.indicator_target
    }

    pub fn indicator_target_decrement(&mut self) {
        let range = INDICATOR_Y_MAX - INDICATOR_Y_MIN;
        self.indicator_target = abagames_util::wrap_dec_by(self.indicator_target,
                                                           range,
                                                           INDICATOR_Y_INTERVAL) +
            INDICATOR_Y_MIN;
    }
}

pub struct GameStateContext<'a, 'b: 'a> {
    pub audio: Option<&'a mut Audio<'b>>,

    pub data: &'a mut GameData,
}

static SCROLL_SPEED_BASE: f32 = 0.025;
static REEL_SIZE_DEFAULT: f32 = 0.5;
static REEL_SIZE_SMALL: f32 = 0.01;
static INDICATOR_Y_MIN: f32 = -7.;
static INDICATOR_Y_MAX: f32 = 7.;
static INDICATOR_Y_INTERVAL: f32 = 1.;

impl<R> GameState<R>
    where R: gfx::Resources,
{
    pub fn new<F>(factory: &mut F, view: gfx::handle::RenderTargetView<R, gfx::format::Srgba8>,
                  context: &RenderContext<R>)
                  -> Self
        where F: gfx::Factory<R>,
    {
        GameState {
            state: State::default(),

            field: entities::field::Field::new(),
            sparks: entities::particles::Spark::new_pool(),
            wakes: entities::particles::Wake::new_pool(),
            smokes: entities::particles::Smoke::new_pool(),

            field_draw: entities::field::FieldDraw::new(factory, view.clone(), context),
            sparks_draw: entities::particles::SparkDraw::new(factory, view.clone(), context),
            wakes_draw: entities::particles::WakeDraw::new(factory, view.clone(), context),
            smokes_draw: entities::particles::SmokeDraw::new(factory, view.clone(), context),

            indicators: Pool::new(50, entities::score_indicator::ScoreIndicator::new),
            letter: entities::letter::Letter::new(factory, view.clone(), context),
            reel: entities::reel::ScoreReel::new(),
            title: entities::title::Title::new(factory, view.clone(), context),
        }
    }

    pub fn init(&mut self, context: &mut GameStateContext) {
        match self.state {
            State::Title => self.init_title(context),
            State::Playing => self.init_game(context),
        }
    }

    fn init_title(&mut self, context: &mut GameStateContext) {
        if let Some(ref mut audio) = context.audio {
            audio.set_music_enabled(false)
                .set_sfx_enabled(false)
                .halt();
        }

        self.title.init();
        self.field.init(0);
    }

    fn init_game(&mut self, context: &mut GameStateContext) {
        self.field.init(0);
        self.reel.init(0);
        self.reel.clear(9);
        self.reel.set_score(0);
    }

    pub fn step(&mut self, context: &mut GameStateContext, input: &Input) -> StepResult {
        match self.state {
            State::Title => self.step_title(context, input),
            State::Playing => self.step_game(context, input),
        }
    }

    pub fn step_title(&mut self, context: &mut GameStateContext, input: &Input) -> StepResult {
        self.title.step();
        self.field.step();
        self.field.scroll(SCROLL_SPEED_BASE, entities::field::FieldMode::Demo);

        if input.keyboard.is_scancode_pressed(Scancode::Escape) {
            self.state = State::Playing;
            StepResult::Done
        } else {
            StepResult::Slowdown(0.)
        }
    }

    pub fn step_game(&mut self, context: &mut GameStateContext, input: &Input) -> StepResult {
        if input.keyboard.is_scancode_pressed(Scancode::Escape) {
            self.state = State::Title;
        }

        self.field.step();
        {
            let (indicators, reel) = (&mut self.indicators,
                                      &mut self.reel);
            indicators.run(|ref mut indicator| indicator.step(reel, context));
        }
        self.reel.step();

        context.data.update_reel();

        StepResult::Slowdown(0.)
    }

    pub fn prep_draw<F>(&mut self, factory: &mut F)
        where F: gfx::Factory<R>,
    {
        match self.state {
            State::Title => self.prep_draw_title(factory),
            State::Playing => self.prep_draw_game(factory),
        }
    }

    pub fn prep_draw_title<F>(&mut self, factory: &mut F)
        where F: gfx::Factory<R>,
    {
        self.field_draw.prep_draw(factory, &self.field);
    }

    pub fn prep_draw_game<F>(&mut self, factory: &mut F)
        where F: gfx::Factory<R>,
    {
        self.field_draw.prep_draw(factory, &self.field);
        self.wakes_draw.prep_draw(factory, &self.wakes);
        self.sparks_draw.prep_draw(factory, &self.sparks);
    }

    pub fn draw<C>(&self, encoder: &mut EncoderContext<R, C>)
        where C: gfx::CommandBuffer<R>,
    {
        match self.state {
            State::Title => self.draw_title(encoder),
            State::Playing => self.draw_game(encoder),
        }
    }

    pub fn draw_title<C>(&self, encoder: &mut EncoderContext<R, C>)
        where C: gfx::CommandBuffer<R>,
    {
        self.field_draw.draw_panels(encoder);
        self.wakes_draw.draw(encoder);
        self.sparks_draw.draw(encoder);
        self.smokes_draw.draw(encoder);
    }

    pub fn draw_game<C>(&self, encoder: &mut EncoderContext<R, C>)
        where C: gfx::CommandBuffer<R>,
    {
        self.field_draw.draw_panels(encoder);
        self.wakes_draw.draw(encoder);
        self.sparks_draw.draw(encoder);
        self.smokes_draw.draw(encoder);
    }

    pub fn draw_luminous<C>(&self, encoder: &mut EncoderContext<R, C>)
        where C: gfx::CommandBuffer<R>
    {
        // self.sparks_draw.draw_luminous(encoder);
        // self.smokes_draw.draw_luminous(encoder);
    }

    pub fn draw_sidebars<C>(&self, encoder: &mut EncoderContext<R, C>)
        where C: gfx::CommandBuffer<R>
    {
        self.field_draw.draw_sidebars(encoder);
    }

    pub fn draw_front<C>(&mut self, encoder: &mut EncoderContext<R, C>, data: &GameData)
        where C: gfx::CommandBuffer<R>,
    {
        match self.state {
            State::Title => self.draw_front_title(encoder, data),
            State::Playing => self.draw_front_game(encoder, data),
        }
    }

    pub fn draw_front_title<C>(&mut self, encoder: &mut EncoderContext<R, C>, data: &GameData)
        where C: gfx::CommandBuffer<R>,
    {
    }

    pub fn draw_front_game<C>(&mut self, encoder: &mut EncoderContext<R, C>, data: &GameData)
        where C: gfx::CommandBuffer<R>,
    {
        let reel_size_offset = (REEL_SIZE_DEFAULT - data.reel_size) * 3.;
        self.reel.draw(encoder,
                       &self.letter,
                       Vector2::new(11.5 + reel_size_offset,
                                    -8.2 - reel_size_offset),
                       data.reel_size);

        let (indicators, letter) = (&mut self.indicators,
                                    &self.letter);

        indicators
            .iter_mut()
            .foreach(|indicator| {
                indicator.draw(encoder, letter)
            })
    }

    pub fn draw_ortho<C>(&self, encoder: &mut EncoderContext<R, C>)
        where C: gfx::CommandBuffer<R>,
    {
        match self.state {
            State::Title => self.draw_ortho_title(encoder),
            State::Playing => self.draw_ortho_game(encoder),
        }
    }

    pub fn draw_ortho_title<C>(&self, encoder: &mut EncoderContext<R, C>)
        where C: gfx::CommandBuffer<R>,
    {
        // TODO: Store this somewhere.
        let scores = Scores;
        self.title.draw(encoder, &self.letter, &scores);
    }

    pub fn draw_ortho_game<C>(&self, encoder: &mut EncoderContext<R, C>)
        where C: gfx::CommandBuffer<R>,
    {
    }
}
