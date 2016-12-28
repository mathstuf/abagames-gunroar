// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

extern crate abagames_util;
use self::abagames_util::Pool;

extern crate gfx;

pub mod field;
pub mod letter;
pub mod reel;
pub mod score_indicator;
pub mod title;

use super::render::RenderContext;

pub struct Entities<R>
    where R: gfx::Resources,
{
    pub field: field::Field<R>,
    pub indicators: Pool<score_indicator::ScoreIndicator>,
    pub letter: letter::Letter<R>,
    pub reel: reel::ScoreReel,
    pub title: title::Title<R>,
}

impl<R> Entities<R>
    where R: gfx::Resources,
{
    pub fn new<F>(factory: &mut F, view: gfx::handle::RenderTargetView<R, gfx::format::Srgba8>,
                  context: &RenderContext<R>)
                  -> Self
        where F: gfx::Factory<R>,
    {
        Entities {
            field: field::Field::new(factory, view.clone(), context),
            indicators: Pool::new(50, score_indicator::ScoreIndicator::new),
            letter: letter::Letter::new(factory, view.clone(), context),
            reel: reel::ScoreReel::new(),
            title: title::Title::new(factory, view.clone(), context),
        }
    }
}
