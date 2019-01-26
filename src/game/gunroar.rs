// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying LICENSE file for details.

use crates::abagames_util::{Audio, Event, Game, Input, Resources, SdlInfo, StepResult};
use crates::sdl2::event::WindowEvent;

use std::fmt::{self, Display};

use game::data;
use game::render::RenderContext;
use game::state::{GameData, GameState, GameStateContext};

#[derive(Debug, Copy, Clone, PartialEq, Eq, Fail)]
pub struct Error;

impl Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "Error")
    }
}

pub struct Gunroar<'a> {
    global_render: RenderContext<Resources>,
    state: GameState<Resources>,

    info: &'a mut SdlInfo,
    audio: Audio,

    backgrounded: bool,

    data: GameData,
}

impl<'a> Gunroar<'a> {
    pub fn new(info: &'a mut SdlInfo, brightness: f32, with_sound: bool) -> Self {
        let (render, state) = {
            let (factory, view) = info.video.factory_view();
            let render = RenderContext::new(factory, brightness);
            let state = GameState::new(factory, view.clone(), &render, with_sound);

            (render, state)
        };
        let mut audio = Audio::new(data::MUSIC_DATA.iter(), data::SFX_DATA.iter())
            .expect("failed to decode audio data?");

        Gunroar {
            global_render: render,
            state: state,

            info: info,
            audio: audio,

            backgrounded: false,

            data: GameData::default(),
        }
    }
}

impl<'a> Game for Gunroar<'a> {
    type Error = Error;

    fn init(&mut self) -> Result<(), Error> {
        let mut context = GameStateContext {
            audio: &mut self.audio,

            data: &mut self.data,
        };

        self.state.init(&mut context);

        Ok(())
    }

    fn handle_event(&mut self, event: &Event) -> Result<bool, Error> {
        Ok(match *event {
            Event::AppTerminating {
                ..
            } => true,
            Event::AppWillEnterBackground {
                ..
            }
            | Event::AppDidEnterBackground {
                ..
            } => {
                self.backgrounded = true;
                false
            },
            Event::AppDidEnterForeground {
                ..
            } => {
                self.backgrounded = false;
                false
            },
            Event::AppWillEnterForeground {
                ..
            } => {
                // Ready...
                false
            },
            Event::Window {
                win_event: WindowEvent::Resized(width, height),
                ..
            } => {
                self.info.video.resize((width as u32, height as u32).into());
                false
            },
            _ => false,
        })
    }

    fn step(&mut self, input: &Input) -> Result<StepResult, Error> {
        let mut context = GameStateContext {
            audio: &mut self.audio,

            data: &mut self.data,
        };

        Ok(self.state.step(&mut context, input))
    }

    fn draw(&mut self) -> Result<(), Error> {
        if self.backgrounded {
            return Ok(());
        }

        self.state.prep_draw(self.info.video.factory());

        let mut draw_context = self.info.video.context();
        let mut context = &mut draw_context.context;
        self.global_render.update(&mut context);

        self.state.draw(&mut context);
        self.state.draw_luminous(&mut context);
        self.state.draw_sidebars(&mut context);
        self.state.draw_front(&mut context, &self.data);
        self.state.draw_ortho(&mut context);

        Ok(())
    }

    fn quit(&mut self) -> Result<(), Error> {
        Ok(())
    }
}
