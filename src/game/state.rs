// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

use crates::abagames_util::{self, Audio, Input, Pool, Rand, Scancode, StepResult, TargetFormat};
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
    lives: u32,

    rand: Rand,

    field: entities::field::Field,
    sparks: Pool<entities::particles::Spark>,
    wakes: Pool<entities::particles::Wake>,
    smokes: Pool<entities::particles::Smoke>,
    fragments: Pool<entities::particles::Fragment>,
    spark_fragments: Pool<entities::particles::SparkFragment>,
    crystals: Pool<entities::crystal::Crystal>,
    bullets: Pool<entities::bullet::Bullet>,
    enemies: Pool<entities::enemy::Enemy>,
    shots: Pool<entities::shot::Shot>,
    indicators: Pool<entities::score_indicator::ScoreIndicator>,

    stage: entities::stage::Stage,
    ship: entities::ship::Ship,

    field_draw: entities::field::FieldDraw<R>,
    sparks_draw: entities::particles::SparkDraw<R>,
    wakes_draw: entities::particles::WakeDraw<R>,
    smokes_draw: entities::particles::SmokeDraw<R>,
    fragments_draw: entities::particles::FragmentDraw<R>,
    spark_fragments_draw: entities::particles::SparkFragmentDraw<R>,
    shape_draw: entities::shapes::ShapeDraw<R>,
    bullet_draw: entities::shapes::bullet::BulletDraw<R>,
    shield_draw: entities::shapes::shield::ShieldDraw<R>,
    ship_draw: entities::ship::ShipDraw<R>,
    turret_draw: entities::turret::TurretDraw<R>,

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

const SCROLL_SPEED_BASE: f32 = 0.025;
const REEL_SIZE_DEFAULT: f32 = 0.5;
const REEL_SIZE_SMALL: f32 = 0.01;
const INDICATOR_Y_MIN: f32 = -7.;
const INDICATOR_Y_MAX: f32 = 7.;
const INDICATOR_Y_INTERVAL: f32 = 1.;

impl<R> GameState<R>
    where R: gfx::Resources,
{
    pub fn new<F>(factory: &mut F, view: gfx::handle::RenderTargetView<R, TargetFormat>,
                  context: &RenderContext<R>)
                  -> Self
        where F: gfx::Factory<R>,
    {
        GameState {
            state: State::default(),
            lives: 2,

            rand: Rand::new(),

            field: entities::field::Field::new(),
            sparks: entities::particles::Spark::new_pool(),
            wakes: entities::particles::Wake::new_pool(),
            smokes: entities::particles::Smoke::new_pool(),
            fragments: entities::particles::Fragment::new_pool(),
            spark_fragments: entities::particles::SparkFragment::new_pool(),
            crystals: entities::crystal::Crystal::new_pool(),
            bullets: entities::bullet::Bullet::new_pool(),
            enemies: entities::enemy::Enemy::new_pool(),
            shots: entities::shot::Shot::new_pool(),
            indicators: entities::score_indicator::ScoreIndicator::new_pool(),
            stage: entities::stage::Stage::new(),
            ship: entities::ship::Ship::new(),

            field_draw: entities::field::FieldDraw::new(factory, view.clone(), context),
            sparks_draw: entities::particles::SparkDraw::new(factory, view.clone(), context),
            wakes_draw: entities::particles::WakeDraw::new(factory, view.clone(), context),
            smokes_draw: entities::particles::SmokeDraw::new(factory, view.clone(), context),
            fragments_draw: entities::particles::FragmentDraw::new(factory, view.clone(), context),
            spark_fragments_draw: entities::particles::SparkFragmentDraw::new(factory, view.clone(), context),
            shape_draw: entities::shapes::ShapeDraw::new(factory, view.clone(), context),
            bullet_draw: entities::shapes::bullet::BulletDraw::new(factory, view.clone(), context),
            shield_draw: entities::shapes::shield::ShieldDraw::new(factory, view.clone(), context),
            ship_draw: entities::ship::ShipDraw::new(factory, view.clone(), context),
            turret_draw: entities::turret::TurretDraw::new(factory, view.clone(), context),

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
        self.field.init(&mut self.rand);
    }

    fn init_game(&mut self, context: &mut GameStateContext) {
        self.stage.init(1., context, &mut self.rand);
        self.field.init(&mut self.rand);
        // self.ship.init();
        self.reel.init(9);
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
        self.field.scroll(SCROLL_SPEED_BASE, entities::field::FieldMode::Demo, &mut self.stage, &mut self.enemies, &self.ship, context, &mut self.rand);

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
        self.field.scroll(SCROLL_SPEED_BASE, entities::field::FieldMode::Demo, &mut self.stage, &mut self.enemies, &self.ship, context, &mut self.rand);
        // self.ship.step();
        {
            let (stage, field, ship, enemies, rand) = (&mut self.stage,
                                                       &self.field,
                                                       &self.ship,
                                                       &mut self.enemies,
                                                       &mut self.rand);
            stage.step(field, ship, enemies, context, rand);
        }
        {
            let (enemies, field, bullets, ship, smokes, sparks, spark_fragments, wakes, rand) =
                (&mut self.enemies, &self.field, &mut self.bullets, &self.ship, &mut self.smokes, &mut self.sparks, &mut self.spark_fragments, &mut self.wakes, &mut self.rand);
            enemies.run_ref(|ref mut enemy, other| enemy.step(field, bullets, ship, smokes, sparks, spark_fragments, wakes, other, context, rand));
        }
        {
            let (shots, field, stage, bullets, enemies, crystals, fragments, smokes, sparks, indicators, reel, rand) =
                (&mut self.shots, &self.field, &self.stage, &mut self.bullets, &mut self.enemies, &mut self.crystals, &mut self.fragments, &mut self.smokes, &mut self.sparks, &mut self.indicators, &mut self.reel, &mut self.rand);
            shots.run(|ref mut shot| shot.step(field, stage, bullets, enemies, crystals, fragments, smokes, sparks, indicators, reel, context, rand));
        }
        {
            let (bullets, field, ship, smokes, wakes, rand) = (&mut self.bullets,
                                                               &self.field,
                                                               &self.ship,
                                                               &mut self.smokes,
                                                               &mut self.wakes,
                                                               &mut self.rand);
            bullets.run(|ref mut bullet| bullet.step(field, ship, smokes, wakes, rand));
        }
        {
            let (crystals, ship) = (&mut self.crystals,
                                    &self.ship);
            crystals.run(|ref mut crystal| crystal.step(ship));
        }
        {
            let (indicators, reel, rand) = (&mut self.indicators,
                                            &mut self.reel,
                                            &mut self.rand);
            indicators.run(|ref mut indicator| indicator.step(reel, context, rand));
        }
        self.sparks.run(entities::particles::Spark::step);
        {
            let (smokes, field, wakes, rand) = (&mut self.smokes,
                                                &self.field,
                                                &mut self.wakes,
                                                &mut self.rand);
            smokes.run(|ref mut smoke| smoke.step(field, wakes, rand));
        }
        {
            let (fragments, field, smokes, rand) = (&mut self.fragments,
                                                    &self.field,
                                                    &mut self.smokes,
                                                    &mut self.rand);
            fragments.run(|ref mut fragment| fragment.step(field, smokes, rand));
        }
        {
            let (spark_fragments, field, smokes, rand) = (&mut self.spark_fragments,
                                                          &self.field,
                                                          &mut self.smokes,
                                                          &mut self.rand);
            spark_fragments.run(|ref mut spark_fragment| spark_fragment.step(field, smokes, rand));
        }
        {
            let (wakes, field) = (&mut self.wakes, &self.field);
            wakes.run(|ref mut wake| wake.step(field));
        }
        // self.screen.step();
        self.reel.step();

        context.data.update_reel();
        context.audio.as_mut().map(|audio| audio.play_sfx());

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
        self.smokes_draw.prep_draw(factory, &self.smokes);
        // self.fragments_draw.prep_draw(factory, &self.fragments);
        self.spark_fragments_draw.prep_draw(factory, &self.spark_fragments, &mut self.rand);
        self.bullet_draw.prep_draw_crystals(factory, &self.crystals);
        {
            let (enemies, rand) = (&mut self.enemies, &mut self.rand);
            enemies.iter_mut().foreach(|enemy| enemy.prep_draw(rand))
        }
        self.bullet_draw.prep_draw_shots(factory, &self.shots);
        self.ship_draw.prep_draw(factory, None, &self.ship);
        // self.bullet_draw.prep_draw(factory, &self.bullets);
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

        //
        self.wakes_draw.draw(encoder);
        self.sparks_draw.draw(encoder);
        self.smokes_draw.draw(encoder);
        self.fragments_draw.draw(encoder, &self.fragments);
        self.spark_fragments_draw.draw(encoder);
        self.bullet_draw.draw_crystals(encoder);
        self.enemies.iter().foreach(|enemy| enemy.draw(encoder, &self.shape_draw, &self.turret_draw, &self.letter));
        self.bullet_draw.draw_shots(encoder);
        self.ship_draw.draw(encoder, &self.shape_draw, &self.shield_draw, &self.ship);
        self.bullet_draw.draw_bullets(encoder, &self.field, &self.bullets);
    }

    pub fn draw_game<C>(&self, encoder: &mut EncoderContext<R, C>)
        where C: gfx::CommandBuffer<R>,
    {
        self.field_draw.draw_panels(encoder);
        self.wakes_draw.draw(encoder);
        self.sparks_draw.draw(encoder);
        self.smokes_draw.draw(encoder);
        self.fragments_draw.draw(encoder, &self.fragments);
        self.spark_fragments_draw.draw(encoder);
        self.bullet_draw.draw_crystals(encoder);
        self.enemies.iter().foreach(|enemy| enemy.draw(encoder, &self.shape_draw, &self.turret_draw, &self.letter));
        self.bullet_draw.draw_shots(encoder);
        self.ship_draw.draw(encoder, &self.shape_draw, &self.shield_draw, &self.ship);
        self.bullet_draw.draw_bullets(encoder, &self.field, &self.bullets);
    }

    pub fn draw_luminous<C>(&self, encoder: &mut EncoderContext<R, C>)
        where C: gfx::CommandBuffer<R>,
    {
        // self.sparks_draw.draw_luminous(encoder);
        // self.spark_fragments_draw.draw_luminous(encoder);
        // self.smokes_draw.draw_luminous(encoder);
    }

    pub fn draw_sidebars<C>(&self, encoder: &mut EncoderContext<R, C>)
        where C: gfx::CommandBuffer<R>,
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
        self.ship_draw.draw_front(encoder);

        let reel_size_offset = (REEL_SIZE_DEFAULT - data.reel_size) * 3.;
        self.reel.draw(encoder,
                       &self.letter,
                       Vector2::new(11.5 + reel_size_offset,
                                    -8.2 - reel_size_offset),
                       data.reel_size,
                       &mut self.rand);

        self.ship_draw.draw_lives(encoder, &self.shape_draw, self.lives, &self.ship);

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
        self.stage.draw(encoder, &self.letter);
    }
}
