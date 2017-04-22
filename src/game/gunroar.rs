// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

use crates::abagames_util::{Event, Game, Input, Resources, SdlInfo, StepResult};
use crates::sdl2::event::WindowEvent;

use game::render::RenderContext;
use game::state::{GameData, GameState, GameStateContext};

error_chain! {}

pub struct Gunroar<'a, 'b: 'a> {
    global_render: RenderContext<Resources>,
    state: GameState<Resources>,

    info: &'a mut SdlInfo<'b>,

    backgrounded: bool,

    data: GameData,
}

impl<'a, 'b> Gunroar<'a, 'b> {
    pub fn new(info: &'a mut SdlInfo<'b>, brightness: f32) -> Result<Self> {
        let (render, state) = {
            let (factory, view) = info.video.factory_view();
            let render = RenderContext::new(factory, brightness);
            let state = GameState::new(factory, view.clone(), &render);

            (render, state)
        };

        Ok(Gunroar {
            global_render: render,
            state: state,

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

            data: &mut self.data,
        };

        Ok(self.state.step(&mut context, input))
    }

    fn draw(&mut self) -> Result<()> {
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

    fn quit(&mut self) -> Result<()> {
        Ok(())
    }
}
