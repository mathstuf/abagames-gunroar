// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

extern crate abagames_util;

extern crate cgmath;
use self::cgmath::{Deg, ElementWise, Matrix4, Rad, Vector2, Vector3};

extern crate gfx;
use self::gfx::traits::FactoryExt;

extern crate itertools;
use self::itertools::FoldWhile::{Continue, Done};
use self::itertools::Itertools;

use super::super::render::{EncoderContext, RenderContext};
pub use super::super::render::{Brightness, OrthographicScreen};

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
            ("Target0",
             gfx::state::MASK_ALL,
             gfx::state::Blend::new(gfx::state::Equation::Add,
                                    gfx::state::Factor::ZeroPlus(gfx::state::BlendValue::SourceAlpha),
                                    gfx::state::Factor::One)),
    }
}

const LETTER_WIDTH: f32 = 2.1;
const LETTER_HEIGHT: f32 = 3.;
const LETTER_OFFSET: Vector2<f32> = Vector2 {
    x: LETTER_WIDTH,
    y: LETTER_HEIGHT,
};

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
    pos: Vector2<f32>,
    size: Vector2<f32>,
    deg: f32,
}

impl LetterSegmentData {
    // FIXME: Use a const fn to generate these at construction time.
    fn constant_buffer(&self) -> LetterSegments {
        // TODO: Put this back into the segment data.
        let pos = self.pos.mul_element_wise(Vector2::new(1., -0.9));
        let size = self.size.mul_element_wise(Vector2::new(1.4, 1.05));
        let deg = Deg(self.deg % 180.);
        let trans = pos - size / 2.;

        let boxmat =
            Matrix4::from_translation(trans.extend(0.)) *
            Matrix4::from_axis_angle(Vector3::unit_z(), deg);
        LetterSegments {
            boxmat: boxmat.into(),
            size: size.into(),
        }
    }
}

static LETTER_DATA: [&'static [LetterSegmentData]; 44] = [
    &[
        LetterSegmentData { pos: Vector2 { x: 0., y: 1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.6, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.6, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: -0.6, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.6, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: -1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: 0.5, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.5, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: 0., y: 1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: 0., }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: -1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: 0., y: 1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: 0., }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: -1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: -0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: 0., }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: 0., y: 1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: 0., }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: -1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: 0., y: 1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: 0., }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: -1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: 0., y: 1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: 0., y: 1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: 0., }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: -1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: 0., y: 1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: 0., }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: -1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
    ],
    &[//A
        LetterSegmentData { pos: Vector2 { x: 0., y: 1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: 0., }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: -0.18, y: 1.15, }, size: Vector2 { x: 0.45, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.45, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: -0.18, y: 0., }, size: Vector2 { x: 0.45, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: -1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: 0., y: 1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: -1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: -0.15, y: 1.15, }, size: Vector2 { x: 0.45, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.45, y: 0.45, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: -1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: 0., y: 1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: 0., }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: -1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
    ],
    &[//F
        LetterSegmentData { pos: Vector2 { x: 0., y: 1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: 0., }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: 0., y: 1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.05, y: 0., }, size: Vector2 { x: 0.3, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: -1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: -0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: 0., }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: 0., y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: 0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: -0.7, y: -0.7, }, size: Vector2 { x: 0.3, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: -1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
    ],
    &[//K
        LetterSegmentData { pos: Vector2 { x: -0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.4, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 100., },
        LetterSegmentData { pos: Vector2 { x: -0.25, y: 0., }, size: Vector2 { x: 0.45, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.6, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 80., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: -0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: -1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: -0.5, y: 1.15, }, size: Vector2 { x: 0.3, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: 0.1, y: 1.15, }, size: Vector2 { x: 0.3, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: 0., y: 1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: 0., y: 1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: -1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
    ],
    &[//P
        LetterSegmentData { pos: Vector2 { x: 0., y: 1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: 0., }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: 0., y: 1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: -1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: 0.05, y: -0.55, }, size: Vector2 { x: 0.45, y: 0.3, }, deg: 60., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: 0., y: 1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: -0.2, y: 0., }, size: Vector2 { x: 0.45, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.45, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 80., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: 0., y: 1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: 0., }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: -1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: -0.5, y: 1.15, }, size: Vector2 { x: 0.55, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: 0.5, y: 1.15, }, size: Vector2 { x: 0.55, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: 0.1, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.1, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
    ],
    &[//U
        LetterSegmentData { pos: Vector2 { x: -0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: -1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: -0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: -0.5, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.5, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: -0.1, y: -1.15, }, size: Vector2 { x: 0.45, y: 0.3, }, deg: 0., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: -0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: -0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.65, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: -0.5, y: -1.15, }, size: Vector2 { x: 0.3, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: 0.1, y: -1.15, }, size: Vector2 { x: 0.3, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: 0., y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: -0.4, y: 0.6, }, size: Vector2 { x: 0.85, y: 0.3, }, deg: 240., },
        LetterSegmentData { pos: Vector2 { x: 0.4, y: 0.6, }, size: Vector2 { x: 0.85, y: 0.3, }, deg: 300., },
        LetterSegmentData { pos: Vector2 { x: -0.4, y: -0.6, }, size: Vector2 { x: 0.85, y: 0.3, }, deg: 120., },
        LetterSegmentData { pos: Vector2 { x: 0.4, y: -0.6, }, size: Vector2 { x: 0.85, y: 0.3, }, deg: 60., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: -0.4, y: 0.6, }, size: Vector2 { x: 0.85, y: 0.3, }, deg: 240., },
        LetterSegmentData { pos: Vector2 { x: 0.4, y: 0.6, }, size: Vector2 { x: 0.85, y: 0.3, }, deg: 300., },
        LetterSegmentData { pos: Vector2 { x: -0.1, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
    ],
    &[
        LetterSegmentData { pos: Vector2 { x: 0., y: 1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: 0.3, y: 0.4, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 120., },
        LetterSegmentData { pos: Vector2 { x: -0.3, y: -0.4, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 120., },
        LetterSegmentData { pos: Vector2 { x: 0., y: -1.15, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 0., },
    ],
    &[// .
        LetterSegmentData { pos: Vector2 { x: 0., y: -1.15, }, size: Vector2 { x: 0.3, y: 0.3, }, deg: 0., },
    ],
    &[// _
        LetterSegmentData { pos: Vector2 { x: 0., y: -1.15, }, size: Vector2 { x: 0.8, y: 0.3, }, deg: 0., },
    ],
    &[// -
        LetterSegmentData { pos: Vector2 { x: 0., y: 0., }, size: Vector2 { x: 0.9, y: 0.3, }, deg: 0., },
    ],
    &[// +
        LetterSegmentData { pos: Vector2 { x: -0.5, y: 0., }, size: Vector2 { x: 0.45, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: 0.45, y: 0., }, size: Vector2 { x: 0.45, y: 0.3, }, deg: 0., },
        LetterSegmentData { pos: Vector2 { x: 0.1, y: 0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.1, y: -0.55, }, size: Vector2 { x: 0.65, y: 0.3, }, deg: 90., },
    ],
    &[// '
        LetterSegmentData { pos: Vector2 { x: 0., y: 1.0, }, size: Vector2 { x: 0.4, y: 0.2, }, deg: 90., },
    ],
    &[// "
        LetterSegmentData { pos: Vector2 { x: -0.19, y: 1.0, }, size: Vector2 { x: 0.4, y: 0.2, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0.2, y: 1.0, }, size: Vector2 { x: 0.4, y: 0.2, }, deg: 90., },
    ],
    &[// !
        LetterSegmentData { pos: Vector2 { x: 0.56, y: 0.25, }, size: Vector2 { x: 1.1, y: 0.3, }, deg: 90., },
        LetterSegmentData { pos: Vector2 { x: 0., y: -1.0, }, size: Vector2 { x: 0.3, y: 0.3, }, deg: 90., },
    ],
    &[// /
        LetterSegmentData { pos: Vector2 { x: 0.8, y: 0., }, size: Vector2 { x: 1.75, y: 0.3, }, deg: 120., },
    ],
];

impl LetterSegmentData {
    fn segment_data_for(ch: char) -> &'static [LetterSegmentData] {
        let ch_u8 = ch as u8;
        let idx = match ch {
            '0'...'9' => ch_u8 - ('0' as u8),
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

    fn change(&self, pos: Vector2<f32>, delta: Vector2<f32>) -> Vector2<f32> {
        let dx = delta.x * Vector2::unit_x();
        let dy = delta.y * Vector2::unit_y();

        match *self {
            LetterDirection::Right => pos + dx,
            LetterDirection::Down => pos + dy,
            LetterDirection::Left => pos - dx,
            LetterDirection::Up => pos - dy,
        }
    }
}

#[derive(Clone, Copy)]
pub enum LetterOrientation {
    Normal,
    Reverse,
}

impl LetterOrientation {
    fn y_flip(self) -> f32 {
        match self {
            LetterOrientation::Normal => 1.,
            LetterOrientation::Reverse => -1.,
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
                  context: &RenderContext<R>)
                  -> Self
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
        let outline_slice = abagames_util::slice_for_loop::<R, F>(factory,
                                                                  vertex_data.len() as u32);
        let fan_slice = abagames_util::slice_for_fan::<R, F>(factory, vertex_data.len() as u32);

        let program = factory.link_program(
            include_bytes!("shader/letter.glslv"),
            include_bytes!("shader/letter.glslf"))
            .unwrap();
        let outline_pso = factory.create_pipeline_from_program(
            &program,
            gfx::Primitive::LineStrip,
            gfx::state::Rasterizer {
                front_face: gfx::state::FrontFace::CounterClockwise,
                cull_face: gfx::state::CullFace::Nothing,
                method: gfx::state::RasterMethod::Line(1),
                offset: None,
                samples: None,
            },
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
        self.draw_letter_at(context,
                            letter,
                            style,
                            Vector2::new(0., 0.),
                            1.,
                            Rad(0.),
                            LetterOrientation::Normal)
    }

    pub fn draw_letter_at<C, A>(&self, context: &mut EncoderContext<R, C>, letter: char,
                                style: &LetterStyle, pos: Vector2<f32>, scale: f32, rotate: A,
                                orientation: LetterOrientation)
        where C: gfx::CommandBuffer<R>,
              A: Into<Rad<f32>>,
    {
        let drawmat =
            Matrix4::from_translation(pos.extend(0.)) *
            Matrix4::from_nonuniform_scale(scale, scale * orientation.y_flip(), scale) *
            Matrix4::from_axis_angle(Vector3::unit_z(), -rotate.into());
        self.draw_letter_with(context, drawmat, letter, style)
    }

    pub fn draw_letter_with<C>(&self, context: &mut EncoderContext<R, C>, matrix: Matrix4<f32>,
                               letter: char, style: &LetterStyle)
        where C: gfx::CommandBuffer<R>,
    {
        let letter_trans = LetterTransforms {
            drawmat: matrix.into(),
        };
        context.encoder.update_constant_buffer(&self.data.letter, &letter_trans);

        self.draw_letter_segments(context, letter, style)
    }

    pub fn draw_string<C>(&self, context: &mut EncoderContext<R, C>, string: &str,
                          pos: Vector2<f32>, scale: f32, direction: LetterDirection,
                          style: &LetterStyle, orientation: LetterOrientation)
        where C: gfx::CommandBuffer<R>,
    {
        let offset = LETTER_OFFSET * scale;
        let pos = pos + offset / 2.;
        let angle = direction.angle();

        string.chars()
            .fold(pos, |pos, ch| {
                self.draw_letter_at(context, ch, style, pos, scale, angle, orientation);

                direction.change(pos, offset)
            });
    }

    pub fn draw_number<C>(&self, context: &mut EncoderContext<R, C>, num: u32, pos: Vector2<f32>,
                          scale: f32, style: &LetterStyle, pad_to: Option<u8>,
                          prefix_char: Option<char>, floating_digits: Option<u8>)
        where C: gfx::CommandBuffer<R>,
    {
        self.draw_number_internal(context,
                                  num,
                                  pos,
                                  scale,
                                  style,
                                  pad_to,
                                  prefix_char,
                                  floating_digits,
                                  LetterOrientation::Normal)
    }

    pub fn draw_number_sign<C>(&self, context: &mut EncoderContext<R, C>, num: u32,
                               pos: Vector2<f32>, scale: f32, style: &LetterStyle,
                               prefix_char: Option<char>, floating_digits: Option<u8>)
        where C: gfx::CommandBuffer<R>,
    {
        self.draw_number_internal(context,
                                  num,
                                  pos,
                                  scale,
                                  style,
                                  None,
                                  prefix_char,
                                  floating_digits,
                                  LetterOrientation::Reverse)
    }

    pub fn draw_time<C>(&self, context: &mut EncoderContext<R, C>, time: u32, pos: Vector2<f32>,
                        scale: f32, style: &LetterStyle)
        where C: gfx::CommandBuffer<R>,
    {
        let offset = scale * LETTER_WIDTH * Vector2::unit_x();
        let offset_wide = offset * 1.3;
        let offset_quotes = scale * 1.16 * Vector2::unit_x();
        let angle = LetterDirection::Right.angle();

        (0..).fold_while((pos, time), |(pos, time), idx| {
            let new_time = if idx != 4 {
                let letter = Self::for_digit(time % 10);
                self.draw_letter_at(context,
                                    letter,
                                    style,
                                    pos,
                                    scale,
                                    angle,
                                    LetterOrientation::Normal);
                time / 10
            } else {
                let letter = Self::for_digit(time % 6);
                self.draw_letter_at(context,
                                    letter,
                                    style,
                                    pos,
                                    scale,
                                    angle,
                                    LetterOrientation::Normal);
                time / 6
            };

            let next_offset = if idx == 0 || (idx & 1) == 1 {
                let ch = if idx == 3 {
                    '\"'
                } else {
                    '\''
                };
                self.draw_letter_at(context,
                                    ch,
                                    style,
                                    pos + offset_quotes,
                                    scale,
                                    angle,
                                    LetterOrientation::Normal);

                offset
            } else {
                offset_wide
            };

            if new_time != 0 {
                Continue((pos - next_offset, new_time))
            } else {
                Done((pos, new_time))
            }
        });
    }

    fn draw_number_internal<C>(&self, context: &mut EncoderContext<R, C>, num: u32,
                               pos: Vector2<f32>, scale: f32, style: &LetterStyle,
                               pad_to: Option<u8>, prefix_char: Option<char>,
                               floating_digits: Option<u8>, orientation: LetterOrientation)
        where C: gfx::CommandBuffer<R>,
    {
        let offset = LETTER_OFFSET * scale;
        let pos = pos + offset / 2.;
        let dir = LetterDirection::Right;
        let angle = dir.angle();
        let norm_digit_offset = offset.x * Vector2::unit_x();
        let fp_offset_x = norm_digit_offset * 0.5;
        let fp_offset_y = offset.y * 0.25 * Vector2::unit_y();

        let (pos, _, _, _) = iter::repeat(()).fold_while((pos, num, pad_to, floating_digits),
                                                         |(pos, num, pad, fd), _| {
            let digit = Self::for_digit(num % 10);
            let next_num = num / 10;

            let (digit_offset, fd) = if let Some(fd) = fd {
                let fp_pos = pos + fp_offset_y;
                self.draw_letter_at(context, digit, style, fp_pos, scale, angle, orientation);
                let new_fp = fd - 1;
                if new_fp == 0 {
                    self.draw_letter_at(context, '.', style, fp_pos, scale, angle, orientation);
                    (2. * fp_offset_x, None)
                } else {
                    (fp_offset_x, Some(new_fp))
                }
            } else {
                self.draw_letter_at(context, digit, style, pos, scale, angle, orientation);
                (norm_digit_offset, None)
            };

            let pad = pad.and_then(|pad| {
                let new_pad = pad - 1;
                if new_pad != 0 {
                    Some(new_pad)
                } else {
                    None
                }
            });

            let new_pos = pos - digit_offset;
            if next_num != 0 || pad.is_some() || fd.is_some() {
                Continue((new_pos, next_num, pad, fd))
            } else {
                Done((new_pos, next_num, pad, fd))
            }
        });

        if let Some(prefix) = prefix_char {
            let prefix_offset = scale * LETTER_WIDTH * 0.2;
            let prefix_offset = Vector2::new(prefix_offset, prefix_offset);
            self.draw_letter_at(context,
                                prefix,
                                style,
                                pos + prefix_offset,
                                scale * 0.6,
                                angle,
                                orientation);
        }
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
