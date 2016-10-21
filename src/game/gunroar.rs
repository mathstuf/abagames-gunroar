// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

extern crate abagames_util;
use self::abagames_util::{Event, Game, Resources, SdlInfo};

extern crate gfx;

use std::error::Error;

use super::entities::Entities;
use super::render::RenderContext;

pub struct Gunroar<'a, 'b: 'a> {
    entities: Entities<Resources>,

    info: &'a mut SdlInfo<'b>,
    brightness: f32,
}

impl<'a, 'b> Gunroar<'a, 'b> {
    pub fn new(info: &'a mut SdlInfo<'b>, brightness: f32) -> Result<Self, Box<Error>> {
        let entities = {
            let (factory, view) = info.video.factory();
            Entities::new(factory, view.clone())
        };

        Ok(Gunroar {
            entities: entities,

            info: info,
            brightness: brightness,
        })
    }
}

impl<'a, 'b> Game for Gunroar<'a, 'b> {
    fn init(&mut self) -> Result<(), Box<Error>> {
        Ok(())
    }

    fn handle_event(&mut self, event: &Event) -> Result<bool, Box<Error>> {
        //unimplemented!()
        Ok(false)
    }

    fn step_frame(&mut self) -> Result<f32, Box<Error>> {
        //unimplemented!()
        Ok(0.)
    }

    fn draw(&mut self) -> Result<(), Box<Error>> {
        let mut draw_context = self.info.video.context();
        let mut context = RenderContext::new(&mut draw_context.context, self.brightness);

        self.entities.draw(&mut context);

        Ok(())
    }

    fn quit(&mut self) -> Result<(), Box<Error>> {
        Ok(())
    }
}
