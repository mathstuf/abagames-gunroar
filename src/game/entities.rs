// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

extern crate gfx;

use super::field::Field;
use super::letter::Letter;
use super::render::RenderContext;

pub struct Entities<R>
    where R: gfx::Resources,
{
    pub field: Field<R>,
    letter: Letter<R>,
}

impl<R> Entities<R>
    where R: gfx::Resources,
{
    pub fn new<F>(factory: &mut F, view: gfx::handle::RenderTargetView<R, gfx::format::Srgba8>,
                  context: &RenderContext<R>) -> Self
        where F: gfx::Factory<R>,
    {
        Entities {
            field: Field::new(factory, view.clone(), context),
            letter: Letter::new(factory, view.clone(), context),
        }
    }
}
