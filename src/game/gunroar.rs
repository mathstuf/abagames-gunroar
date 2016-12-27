// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

extern crate abagames_util;
use self::abagames_util::{Event, Game, Input, Resources, SdlInfo, StepResult};

extern crate gfx;

extern crate sdl2;
use self::sdl2::event::WindowEvent;

use super::entities::Entities;
use super::render::RenderContext;
use super::state::{GameData, GameState, GameStateContext};

error_chain! {}

pub struct Gunroar<'a, 'b: 'a> {
    global_render: RenderContext<Resources>,
    entities: Entities<Resources>,
    state: GameState,

    info: &'a mut SdlInfo<'b>,

    backgrounded: bool,

    data: GameData,
}

impl<'a, 'b> Gunroar<'a, 'b> {
    pub fn new(info: &'a mut SdlInfo<'b>, brightness: f32) -> Result<Self> {
        let (render, entities) = {
            let (factory, view) = info.video.factory_view();
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

            data: Default::default(),
        })
    }
}

impl<'a, 'b> Game for Gunroar<'a, 'b> {
    type Error = Error;

    fn init(&mut self) -> Result<()> {
        let mut context = GameStateContext {
            audio: self.info.audio.as_mut(),

            entities: &mut self.entities,

            data: &mut self.data,
        };

        self.state.init(&mut context);

        Ok(())
    }

    fn handle_event(&mut self, event: &Event) -> Result<bool> {
        Ok(match *event {
            Event::AppTerminating { .. } => true,
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
            Event::Window { win_event: WindowEvent::Resized(width, height), .. } => {
                self.info.video.resize(width as u32, height as u32);
                false
            },
            _ => false,
        })
    }

    fn step(&mut self, input: &Input) -> Result<StepResult> {
        let mut context = GameStateContext {
            audio: self.info.audio.as_mut(),

            entities: &mut self.entities,

            data: &mut self.data,
        };

        Ok(self.state.step(&mut context, input))
    }

    fn draw(&mut self) -> Result<()> {
        if self.backgrounded {
            return Ok(());
        }

        self.state.prep_draw(&mut self.entities, self.info.video.factory());

        let mut draw_context = self.info.video.context();
        let mut context = &mut draw_context.context;
        self.global_render.update(&mut context);

        self.state.draw(&mut self.entities, &mut context);
        self.state.draw_luminous(&mut self.entities, &mut context);
        self.entities.field.draw_sidebars(&mut context);
        self.state.draw_front(&mut self.entities, &mut context, &self.data);
        self.state.draw_ortho(&mut self.entities, &mut context);

        Ok(())
    }

    fn quit(&mut self) -> Result<()> {
        Ok(())
    }
}
