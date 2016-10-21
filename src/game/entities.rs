// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

extern crate gfx;

use super::render::RenderContext;

pub struct Entities<R>
    where R: gfx::Resources,
{
}

impl<R> Entities<R>
    where R: gfx::Resources,
{
    pub fn new<F>(factory: &mut F, view: gfx::handle::RenderTargetView<R, gfx::format::Srgba8>) -> Self
        where F: gfx::Factory<R>,
    {
        Entities {
        }
    }

    pub fn draw<C>(&self, context: &mut RenderContext<R, C>)
        where C: gfx::CommandBuffer<R>,
    {
    }
}
