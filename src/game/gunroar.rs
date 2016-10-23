// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

extern crate abagames_util;
use self::abagames_util::{Event, Input, Game, Resources, SdlInfo, StepResult};

extern crate gfx;

extern crate sdl2;
use self::sdl2::event::WindowEventId;

use std::error::Error;

use super::entities::Entities;
use super::render::RenderContext;
use super::state::{GameState, GameStateContext};

pub struct Gunroar<'a, 'b: 'a> {
    global_render: RenderContext<Resources>,
    entities: Entities<Resources>,
    state: GameState,

    info: &'a mut SdlInfo<'b>,

    backgrounded: bool,
}

impl<'a, 'b> Gunroar<'a, 'b> {
    pub fn new(info: &'a mut SdlInfo<'b>, brightness: f32) -> Result<Self, Box<Error>> {
        let (render, entities) = {
            let (factory, view) = info.video.factory();
            let render = RenderContext::new(factory, brightness);
            let entities = Entities::new(factory, view.clone(), &render);

            (render, entities)
        };

        Ok(Gunroar {
            global_render: render,
            entities: entities,
            state: GameState::TitleState,

            info: info,

            backgrounded: false,
        })
    }
}

impl<'a, 'b> Game for Gunroar<'a, 'b> {
    fn init(&mut self) -> Result<(), Box<Error>> {
        let mut context = GameStateContext {
            audio: self.info.audio.as_mut(),

            entities: &mut self.entities,
        };

        self.state.init(&mut context);

        Ok(())
    }

    fn handle_event(&mut self, event: &Event) -> Result<bool, Box<Error>> {
        Ok(match *event {
            Event::AppTerminating { .. } => {
                true
            },
            Event::AppWillEnterBackground { .. } |
            Event::AppDidEnterBackground { .. } => {
                self.backgrounded = true;
                false
            },
            Event::AppDidEnterForeground { .. } => {
                self.backgrounded = false;
                false
            },
            Event::AppWillEnterForeground { .. } => {
                // Ready...
                false
            },
            Event::Window { win_event_id: WindowEventId::Resized, data1: width, data2: height, .. } => {
                self.info.video.resize(width as u32, height as u32);
                false
            },
            _ => false,
        })
    }

    fn step(&mut self, input: &Input) -> Result<StepResult, Box<Error>> {
        let mut context = GameStateContext {
            audio: self.info.audio.as_mut(),

            entities: &mut self.entities,
        };

        Ok(self.state.step(&mut context, input))
    }

    fn draw(&mut self) -> Result<(), Box<Error>> {
        if self.backgrounded {
            return Ok(());
        }

        self.state.prep_draw(&mut self.entities);

        let mut draw_context = self.info.video.context();
        let mut context = &mut draw_context.context;
        self.global_render.update(&mut context);

        self.state.draw(&self.entities, &mut context);

        Ok(())
    }

    fn quit(&mut self) -> Result<(), Box<Error>> {
        Ok(())
    }
}
