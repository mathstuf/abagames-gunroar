// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

extern crate abagames_util;

extern crate cgmath;
use self::cgmath::{Deg, Matrix4, Rad, vec3};

extern crate gfx;
use self::gfx::traits::FactoryExt;

extern crate itertools;
use self::itertools::FoldWhile::{Continue, Done};
use self::itertools::Itertools;

use super::render::{EncoderContext, RenderContext};
pub use super::render::{Brightness, OrthographicScreen};

use std::borrow::Cow;
use std::iter;

gfx_defines! {
    vertex Vertex {
        pos: [f32; 2] = "pos",
    }

    constant Color {
        color: [f32; 4] = "color",
    }

    constant LetterTransforms {
        drawmat: [[f32; 4]; 4] = "drawmat",
    }

    constant LetterSegments {
        boxmat: [[f32; 4]; 4] = "boxmat",
        size: [f32; 2] = "size",
    }

    pipeline pipe {
        vbuf: gfx::VertexBuffer<Vertex> = (),
        color: gfx::ConstantBuffer<Color> = "Color",
        screen: gfx::ConstantBuffer<OrthographicScreen> = "Screen",
        brightness: gfx::ConstantBuffer<Brightness> = "Brightness",
        letter: gfx::ConstantBuffer<LetterTransforms> = "LetterTransforms",
        segment: gfx::ConstantBuffer<LetterSegments> = "LetterSegments",
        out_color: gfx::BlendTarget<gfx::format::Srgba8> =
            ("Target0", gfx::state::MASK_ALL, gfx::state::Blend::new(gfx::state::Equation::Add,
                                                                     gfx::state::Factor::One,
                                                                     gfx::state::Factor::Zero)),
    }
}

static LETTER_WIDTH: f32 = 2.1;
static LETTER_HEIGHT: f32 = 3.;

#[derive(Clone)]
pub enum LetterStyle<'a> {
    White,
    OffWhite,
    Outline(&'a [f32; 4]),
    Filled(&'a [f32; 4]),
}

impl<'a> LetterStyle<'a> {
    fn color(&'a self, alpha: f32) -> Cow<'a, [f32; 4]> {
        match *self {
            LetterStyle::White => Cow::Owned([1., 1., 1., alpha]),
            LetterStyle::OffWhite => Cow::Owned([0.9, 0.7, 0.5, alpha]),
            LetterStyle::Outline(ref data) |
            LetterStyle::Filled(ref data) => Cow::Borrowed(data),
        }
    }

    fn is_outline(&self) -> bool {
        match *self {
            LetterStyle::White |
            LetterStyle::OffWhite |
            LetterStyle::Outline(_) => true,
            LetterStyle::Filled(_) => false,
        }
    }

    fn is_fill(&self) -> bool {
        match *self {
            LetterStyle::White |
            LetterStyle::OffWhite |
            LetterStyle::Filled(_) => true,
            LetterStyle::Outline(_) => false,
        }
    }
}

struct LetterSegmentData {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    deg: f32,
}

impl LetterSegmentData {
    // FIXME: Use a const fn to generate these at construction time.
    fn constant_buffer(&self) -> LetterSegments {
        // TODO: Put this back into the segment data.
        let x = self.x;
        let y = -0.9 * self.y;
        let width = 1.4 * self.width;
        let height = 1.05 * self.height;
        let deg = Deg(self.deg % 180.);

        let boxmat =
            Matrix4::from_translation(vec3(x - width / 2., y - height / 2., 0.)) *
            Matrix4::from_axis_angle(vec3(0., 0., 1.), -deg);
        LetterSegments {
            boxmat: boxmat.into(),
            size: [width, height],
        }
    }
}

static LETTER_DATA: [&'static [LetterSegmentData]; 44] = [
    &[
        LetterSegmentData { x: 0., y: 1.15, width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.6, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.6, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: -0.6, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.6, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: -1.15, width: 0.65, height: 0.3, deg: 0., },
    ],
    &[
        LetterSegmentData { x: 0.5, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.5, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
    ],
    &[
        LetterSegmentData { x: 0., y: 1.15, width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: 0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: 0., width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: -1.15, width: 0.65, height: 0.3, deg: 0., },
    ],
    &[
        LetterSegmentData { x: 0., y: 1.15, width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: 0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: 0., width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: 0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: -1.15, width: 0.65, height: 0.3, deg: 0., },
    ],
    &[
        LetterSegmentData { x: -0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: 0., width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: 0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
    ],
    &[
        LetterSegmentData { x: 0., y: 1.15, width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: 0., width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: 0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: -1.15, width: 0.65, height: 0.3, deg: 0., },
    ],
    &[
        LetterSegmentData { x: 0., y: 1.15, width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: 0., width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: -1.15, width: 0.65, height: 0.3, deg: 0., },
    ],
    &[
        LetterSegmentData { x: 0., y: 1.15, width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: 0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
    ],
    &[
        LetterSegmentData { x: 0., y: 1.15, width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: 0., width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: -1.15, width: 0.65, height: 0.3, deg: 0., },
    ],
    &[
        LetterSegmentData { x: 0., y: 1.15, width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: 0., width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: 0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: -1.15, width: 0.65, height: 0.3, deg: 0., },
    ],
    &[//A
        LetterSegmentData { x: 0., y: 1.15, width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: 0., width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
    ],
    &[
        LetterSegmentData { x: -0.18, y: 1.15, width: 0.45, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.45, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: -0.18, y: 0., width: 0.45, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: -1.15, width: 0.65, height: 0.3, deg: 0., },
    ],
    &[
        LetterSegmentData { x: 0., y: 1.15, width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: -0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: -1.15, width: 0.65, height: 0.3, deg: 0., },
    ],
    &[
        LetterSegmentData { x: -0.15, y: 1.15, width: 0.45, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.45, y: 0.45, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: -0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: -1.15, width: 0.65, height: 0.3, deg: 0., },
    ],
    &[
        LetterSegmentData { x: 0., y: 1.15, width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: 0., width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: -1.15, width: 0.65, height: 0.3, deg: 0., },
    ],
    &[//F
        LetterSegmentData { x: 0., y: 1.15, width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: 0., width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
    ],
    &[
        LetterSegmentData { x: 0., y: 1.15, width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.05, y: 0., width: 0.3, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: -1.15, width: 0.65, height: 0.3, deg: 0., },
    ],
    &[
        LetterSegmentData { x: -0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: 0., width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
    ],
    &[
        LetterSegmentData { x: 0., y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: -0.55, width: 0.65, height: 0.3, deg: 90., },
    ],
    &[
        LetterSegmentData { x: 0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: -0.7, y: -0.7, width: 0.3, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: -1.15, width: 0.65, height: 0.3, deg: 0., },
    ],
    &[//K
        LetterSegmentData { x: -0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.4, y: 0.55, width: 0.65, height: 0.3, deg: 100., },
        LetterSegmentData { x: -0.25, y: 0., width: 0.45, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.6, y: -0.55, width: 0.65, height: 0.3, deg: 80., },
    ],
    &[
        LetterSegmentData { x: -0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: -0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: -1.15, width: 0.65, height: 0.3, deg: 0., },
    ],
    &[
        LetterSegmentData { x: -0.5, y: 1.15, width: 0.3, height: 0.3, deg: 0., },
        LetterSegmentData { x: 0.1, y: 1.15, width: 0.3, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: -0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: -0.55, width: 0.65, height: 0.3, deg: 90., },
    ],
    &[
        LetterSegmentData { x: 0., y: 1.15, width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: -0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
    ],
    &[
        LetterSegmentData { x: 0., y: 1.15, width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: -0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: -1.15, width: 0.65, height: 0.3, deg: 0., },
    ],
    &[//P
        LetterSegmentData { x: 0., y: 1.15, width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: 0., width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
    ],
    &[
        LetterSegmentData { x: 0., y: 1.15, width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: -0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: -1.15, width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: 0.05, y: -0.55, width: 0.45, height: 0.3, deg: 60., },
    ],
    &[
        LetterSegmentData { x: 0., y: 1.15, width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: -0.2, y: 0., width: 0.45, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.45, y: -0.55, width: 0.65, height: 0.3, deg: 80., },
    ],
    &[
        LetterSegmentData { x: 0., y: 1.15, width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: -0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: 0., width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: 0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: -1.15, width: 0.65, height: 0.3, deg: 0., },
    ],
    &[
        LetterSegmentData { x: -0.5, y: 1.15, width: 0.55, height: 0.3, deg: 0., },
        LetterSegmentData { x: 0.5, y: 1.15, width: 0.55, height: 0.3, deg: 0., },
        LetterSegmentData { x: 0.1, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.1, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
    ],
    &[//U
        LetterSegmentData { x: -0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: -0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: -1.15, width: 0.65, height: 0.3, deg: 0., },
    ],
    &[
        LetterSegmentData { x: -0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: -0.5, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.5, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: -0.1, y: -1.15, width: 0.45, height: 0.3, deg: 0., },
    ],
    &[
        LetterSegmentData { x: -0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: -0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.65, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: -0.5, y: -1.15, width: 0.3, height: 0.3, deg: 0., },
        LetterSegmentData { x: 0.1, y: -1.15, width: 0.3, height: 0.3, deg: 0., },
        LetterSegmentData { x: 0., y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: -0.55, width: 0.65, height: 0.3, deg: 90., },
    ],
    &[
        LetterSegmentData { x: -0.4, y: 0.6, width: 0.85, height: 0.3, deg: 240., },
        LetterSegmentData { x: 0.4, y: 0.6, width: 0.85, height: 0.3, deg: 300., },
        LetterSegmentData { x: -0.4, y: -0.6, width: 0.85, height: 0.3, deg: 120., },
        LetterSegmentData { x: 0.4, y: -0.6, width: 0.85, height: 0.3, deg: 60., },
    ],
    &[
        LetterSegmentData { x: -0.4, y: 0.6, width: 0.85, height: 0.3, deg: 240., },
        LetterSegmentData { x: 0.4, y: 0.6, width: 0.85, height: 0.3, deg: 300., },
        LetterSegmentData { x: -0.1, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
    ],
    &[
        LetterSegmentData { x: 0., y: 1.15, width: 0.65, height: 0.3, deg: 0., },
        LetterSegmentData { x: 0.3, y: 0.4, width: 0.65, height: 0.3, deg: 120., },
        LetterSegmentData { x: -0.3, y: -0.4, width: 0.65, height: 0.3, deg: 120., },
        LetterSegmentData { x: 0., y: -1.15, width: 0.65, height: 0.3, deg: 0., },
    ],
    &[// .
        LetterSegmentData { x: 0., y: -1.15, width: 0.3, height: 0.3, deg: 0., },
    ],
    &[// _
        LetterSegmentData { x: 0., y: -1.15, width: 0.8, height: 0.3, deg: 0., },
    ],
    &[// -
        LetterSegmentData { x: 0., y: 0., width: 0.9, height: 0.3, deg: 0., },
    ],
    &[// +
        LetterSegmentData { x: -0.5, y: 0., width: 0.45, height: 0.3, deg: 0., },
        LetterSegmentData { x: 0.45, y: 0., width: 0.45, height: 0.3, deg: 0., },
        LetterSegmentData { x: 0.1, y: 0.55, width: 0.65, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0.1, y: -0.55, width: 0.65, height: 0.3, deg: 90., },
    ],
    &[// '
        LetterSegmentData { x: 0., y: 1.0, width: 0.4, height: 0.2, deg: 90., },
    ],
    &[// "
        LetterSegmentData { x: -0.19, y: 1.0, width: 0.4, height: 0.2, deg: 90., },
        LetterSegmentData { x: 0.2, y: 1.0, width: 0.4, height: 0.2, deg: 90., },
    ],
    &[// !
        LetterSegmentData { x: 0.56, y: 0.25, width: 1.1, height: 0.3, deg: 90., },
        LetterSegmentData { x: 0., y: -1.0, width: 0.3, height: 0.3, deg: 90., },
    ],
    &[// /
        LetterSegmentData { x: 0.8, y: 0., width: 1.75, height: 0.3, deg: 120., },
    ],
];

impl LetterSegmentData {
    fn segment_data_for(ch: char) -> &'static [LetterSegmentData] {
        let ch_u8 = ch as u8;
        let idx = match ch {
            '0'...'9' => ch_u8 - 10,
            'A'...'Z' => ch_u8 - ('A' as u8) + 10,
            'a'...'z' => ch_u8 - ('a' as u8) + 10,
            '.' => 36,
            '_' => 37,
            '-' => 38,
            '+' => 39,
            '\'' => 40,
            '\"' => 41,
            '!' => 42,
            '/' => 43,
            ' ' | _ => return &[],
        } as usize;

        &LETTER_DATA[idx]
    }
}

pub enum LetterDirection {
    Right,
    Down,
    Left,
    Up,
}

impl LetterDirection {
    fn angle(&self) -> Rad<f32> {
        Deg(match *self {
            LetterDirection::Right => 0.,
            LetterDirection::Down => 90.,
            LetterDirection::Left => 180.,
            LetterDirection::Up => 270.,
        }).into()
    }

    fn change(&self, pos: (f32, f32), delta: (f32, f32)) -> (f32, f32) {
        let (x, y) = pos;
        let (dx, dy) = delta;

        match *self {
            LetterDirection::Right => (x + dx, y),
            LetterDirection::Down => (x, y + dy),
            LetterDirection::Left => (x - dx, y),
            LetterDirection::Up => (x, y - dy),
        }
    }
}

pub struct Letter<R>
    where R: gfx::Resources,
{
    outline_slice: gfx::Slice<R>,
    outline_pso: gfx::PipelineState<R, <pipe::Data<R> as gfx::pso::PipelineData<R>>::Meta>,

    fan_slice: gfx::Slice<R>,
    fan_pso: gfx::PipelineState<R, <pipe::Data<R> as gfx::pso::PipelineData<R>>::Meta>,

    data: pipe::Data<R>,
}

impl<R> Letter<R>
    where R: gfx::Resources,
{
    pub fn new<F>(factory: &mut F, view: gfx::handle::RenderTargetView<R, gfx::format::Srgba8>,
                  context: &RenderContext<R>) -> Self
        where F: gfx::Factory<R>,
    {
        let vertex_data = [
            Vertex { pos: [-0.5,   0.], },
            Vertex { pos: [-0.33, -0.5], },
            Vertex { pos: [ 0.33, -0.5], },
            Vertex { pos: [ 0.5,   0.], },
            Vertex { pos: [ 0.33,  0.5], },
            Vertex { pos: [-0.33,  0.5], },
        ];

        let vbuf = factory.create_vertex_buffer(&vertex_data);
        let outline_slice = abagames_util::slice_for_loop::<R, F>(factory, vertex_data.len() as u32);
        let fan_slice = abagames_util::slice_for_fan::<R, F>(factory, vertex_data.len() as u32);

        let program = factory.link_program(
            include_bytes!("shader/letter.glslv"),
            include_bytes!("shader/letter.glslf"))
            .unwrap();
        let outline_pso = factory.create_pipeline_from_program(
            &program,
            gfx::Primitive::LineStrip,
            gfx::state::Rasterizer::new_fill(),
            pipe::new())
            .unwrap();
        let fan_pso = factory.create_pipeline_from_program(
            &program,
            gfx::Primitive::TriangleList,
            gfx::state::Rasterizer::new_fill(),
            pipe::new())
            .unwrap();

        let data = pipe::Data {
            vbuf: vbuf,
            color: factory.create_constant_buffer(1),
            screen: context.orthographic_screen_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            letter: factory.create_constant_buffer(1),
            segment: factory.create_constant_buffer(1),
            out_color: view,
        };

        Letter {
            outline_slice: outline_slice,
            outline_pso: outline_pso,

            fan_slice: fan_slice,
            fan_pso: fan_pso,

            data: data,
        }
    }

    pub fn draw_letter<C>(&self, context: &mut EncoderContext<R, C>, letter: char,
                              style: &LetterStyle)
        where C: gfx::CommandBuffer<R>,
    {
        self.draw_letter_at(context, letter, style, 0., 0., 1., Rad(0.))
    }

    pub fn draw_letter_at<C, A>(&self, context: &mut EncoderContext<R, C>,
                                       letter: char, style: &LetterStyle, x: f32, y: f32,
                                       scale: f32, rotate: A)
        where C: gfx::CommandBuffer<R>,
              A: Into<Rad<f32>>,
    {
        self.draw_letter_internal(context, letter, style, x, y, scale, rotate, 1.)
    }

    pub fn draw_letter_at_reverse<C, A>(&self, context: &mut EncoderContext<R, C>, letter: char,
                                        style: &LetterStyle, x: f32, y: f32, scale: f32, rotate: A)
        where C: gfx::CommandBuffer<R>,
              A: Into<Rad<f32>>,
    {
        self.draw_letter_internal(context, letter, style, x, y, scale, rotate, -1.)
    }

    pub fn draw_string<C>(&self, context: &mut EncoderContext<R, C>, string: &str, x: f32, y: f32,
                      scale: f32, direction: LetterDirection, style: &LetterStyle, reverse: bool)
        where C: gfx::CommandBuffer<R>,
    {
        let x = x + LETTER_WIDTH * scale / 2.;
        let y = y + LETTER_HEIGHT * scale / 2.;
        let angle = direction.angle();
        let method = if reverse {
            Self::draw_letter_at_reverse
        } else {
            Self::draw_letter_at
        };
        let offset = (scale * LETTER_WIDTH, scale * LETTER_HEIGHT);

        string.chars()
            .fold((x, y), |pos, ch| {
                method(self, context, ch, style, pos.0, pos.1, scale, angle);

                direction.change(pos, offset)
            });
    }

    pub fn draw_number<C>(&self, context: &mut EncoderContext<R, C>, num: u32, x: f32, y: f32,
                          scale: f32, style: &LetterStyle, pad_to: Option<u8>,
                          prefix_char: Option<char>, floating_digits: Option<u8>)
        where C: gfx::CommandBuffer<R>,
    {
        self.draw_number_internal(context, num, x, y, scale, style, pad_to, prefix_char,
                                  floating_digits, false)
    }

    pub fn draw_number_sign<C>(&self, context: &mut EncoderContext<R, C>, num: u32, x: f32, y: f32,
                               scale: f32, style: &LetterStyle, prefix_char: Option<char>,
                               floating_digits: Option<u8>)
        where C: gfx::CommandBuffer<R>,
    {
        self.draw_number_internal(context, num, x, y, scale, style, None, prefix_char,
                                  floating_digits, true)
    }

    pub fn draw_time<C>(&self, context: &mut EncoderContext<R, C>, time: u32, x: f32, y: f32,
                        scale: f32, style: &LetterStyle)
        where C: gfx::CommandBuffer<R>,
    {
        let x_offset = scale * LETTER_WIDTH;
        let x_offset_wide = x_offset * 1.3;
        let x_offset_quotes = scale * 1.16;
        let angle = LetterDirection::Right.angle();

        (0..)
            .fold_while((x, y, time), |(x, y, time), idx| {
                let new_time = if idx != 4 {
                    let letter = Self::for_digit(time % 10);
                    self.draw_letter_at(context, letter, style, x, y, scale, angle);
                    time / 10
                } else {
                    let letter = Self::for_digit(time % 6);
                    self.draw_letter_at(context, letter, style, x, y, scale, angle);
                    time / 6
                };

                let x_offset = if idx == 0 || (idx & 1) == 1 {
                    if idx == 3 {
                        self.draw_letter_at(context, '\"', style, x + x_offset_quotes, y, scale, angle)
                    } else if idx == 5 {
                        self.draw_letter_at(context, '\'', style, x + x_offset_quotes, y, scale, angle)
                    };

                    x_offset
                } else {
                    x_offset_wide
                };

                if new_time != 0 {
                    Continue((x - x_offset, y, new_time))
                } else {
                    Done((x, y, new_time))
                }
            });
    }

    fn draw_number_internal<C>(&self, context: &mut EncoderContext<R, C>, num: u32, x: f32,
                                   y: f32, scale: f32, style: &LetterStyle, pad_to: Option<u8>,
                                   prefix_char: Option<char>, floating_digits: Option<u8>,
                                   reverse: bool)
        where C: gfx::CommandBuffer<R>,
    {
        let x = x + LETTER_WIDTH * scale / 2.;
        let y = y + LETTER_HEIGHT * scale / 2.;
        let offset = (scale * LETTER_WIDTH, scale * LETTER_HEIGHT);
        let dir = LetterDirection::Right;
        let angle = dir.angle();
        let fp_offset = (offset.0 * 0.5, offset.1 * 0.25);
        let method = if reverse {
            Self::draw_letter_at_reverse
        } else {
            Self::draw_letter_at
        };

        let (x, y, _, _, _) = iter::repeat(())
            .fold_while((x, y, num, pad_to, floating_digits), |(x, y, num, pad, fd), _| {
                let digit = Self::for_digit(num % 10);
                let next_num = num / 10;

                let (x_offset, fd) = if let Some(fd) = fd {
                    method(self, context, digit, style, x, y + fp_offset.1, scale, angle);
                    let new_fp = fd - 1;
                    if new_fp == 0 {
                        method(self, context, '.', style, x, y + fp_offset.1, scale, angle);
                        (2. * fp_offset.0, None)
                    } else {
                        (fp_offset.0, Some(new_fp))
                    }
                } else {
                    method(self, context, digit, style, x, y, scale, angle);
                    (offset.0, None)
                };

                let pad = pad.and_then(|pad| {
                    let new_pad = pad - 1;
                    if new_pad != 0 {
                        Some(new_pad)
                    } else {
                        None
                    }
                });

                let new_x = x - x_offset;
                if next_num != 0 || pad.is_some() || fd.is_some() {
                    Continue((new_x, y, next_num, pad, fd))
                } else {
                    Done((new_x, y, next_num, pad, fd))
                }
            });

        if let Some(prefix) = prefix_char {
            let prefix_offset = scale * LETTER_WIDTH * 0.2;
            method(self, context, prefix, style, x + prefix_offset, y + prefix_offset, scale * 0.6,
                   angle);
        }
    }

    fn draw_letter_internal<C, A>(&self, context: &mut EncoderContext<R, C>, letter: char,
                                  style: &LetterStyle, x: f32, y: f32, scale: f32, rotate: A,
                                  flip: f32)
        where C: gfx::CommandBuffer<R>,
              A: Into<Rad<f32>>,
    {
        let drawmat =
            Matrix4::from_translation(vec3(x, y, 0.)) *
            Matrix4::from_nonuniform_scale(scale, scale * flip, scale) *
            Matrix4::from_axis_angle(vec3(0., 0., 1.), -rotate.into());
        let letter_trans = LetterTransforms {
            drawmat: drawmat.into(),
        };
        context.encoder.update_constant_buffer(&self.data.letter, &letter_trans);

        self.draw_letter_segments(context, letter, style)
    }

    fn draw_letter_segments<C>(&self, context: &mut EncoderContext<R, C>, letter: char,
                               style: &LetterStyle)
        where C: gfx::CommandBuffer<R>,
    {
        LetterSegmentData::segment_data_for(letter).iter()
            // Get the constant buffer for the segment.
            .map(LetterSegmentData::constant_buffer)
            .map(|data| {
                context.encoder.update_constant_buffer(&self.data.segment, &data);

                // TODO: Factor color setting out for custom colors.
                if style.is_fill() {
                    let color = Color {
                        color: style.color(0.5).into_owned(),
                    };
                    context.encoder.update_constant_buffer(&self.data.color, &color);

                    context.encoder.draw(&self.fan_slice, &self.fan_pso, &self.data);
                }

                if style.is_outline() {
                    let color = Color {
                        color: style.color(1.).into_owned(),
                    };
                    context.encoder.update_constant_buffer(&self.data.color, &color);

                    context.encoder.draw(&self.outline_slice, &self.outline_pso, &self.data);
                }
            })
            .count();
    }

    fn for_digit(digit: u32) -> char {
        match digit {
            0 => '0',
            1 => '1',
            2 => '2',
            3 => '3',
            4 => '4',
            5 => '5',
            6 => '6',
            7 => '7',
            8 => '8',
            9 => '9',
            _ => unreachable!(),
        }
    }
}
