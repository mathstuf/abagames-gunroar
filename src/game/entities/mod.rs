// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

extern crate gfx;

pub mod field;
pub mod letter;

use super::render::RenderContext;

pub struct Entities<R>
    where R: gfx::Resources,
{
    pub field: field::Field<R>,
    pub letter: letter::Letter<R>,
}

impl<R> Entities<R>
    where R: gfx::Resources,
{
    pub fn new<F>(factory: &mut F, view: gfx::handle::RenderTargetView<R, gfx::format::Srgba8>,
                  context: &RenderContext<R>) -> Self
        where F: gfx::Factory<R>,
    {
        Entities {
            field: field::Field::new(factory, view.clone(), context),
            letter: letter::Letter::new(factory, view.clone(), context),
        }
    }
}
