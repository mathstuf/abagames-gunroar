// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying LICENSE file for details.

use std::borrow::Cow;
use std::iter;

use abagames_util::{self, TargetFormat};
use cgmath::{Deg, ElementWise, Matrix4, Rad, Vector2, Vector3};
use gfx;
use gfx::traits::FactoryExt;
use gfx::*;

use crate::game::render::{Brightness, ScreenTransform};
use crate::game::render::{EncoderContext, RenderContext};

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
        screen: gfx::ConstantBuffer<ScreenTransform> = "Screen",
        brightness: gfx::ConstantBuffer<Brightness> = "Brightness",
        letter: gfx::ConstantBuffer<LetterTransforms> = "LetterTransforms",
        segment: gfx::ConstantBuffer<LetterSegments> = "LetterSegments",
        out_color: gfx::BlendTarget<TargetFormat> =
            ("Target0",
             gfx::state::ColorMask::all(),
             gfx::state::Blend::new(gfx::state::Equation::Add,
                                    gfx::state::Factor::ZeroPlus(gfx::state::BlendValue::SourceAlpha),
                                    gfx::state::Factor::One)),
    }
}

const LETTER_WIDTH: f32 = 2.1;
const LETTER_HEIGHT: f32 = 3.;
const LETTER_OFFSET: Vector2<f32> = Vector2::new(LETTER_WIDTH, LETTER_HEIGHT);

#[derive(Clone, Copy)]
pub enum Style<'a> {
    White,
    OffWhite,
    Outline(&'a [f32; 4]),
    Filled(&'a [f32; 4]),
}

impl<'a> Style<'a> {
    #[rustfmt::skip]
    fn color(&'a self, alpha: f32) -> Cow<'a, [f32; 4]> {
        match *self {
            Style::White => Cow::Owned([1., 1., 1., alpha]),
            Style::OffWhite => Cow::Owned([0.9, 0.7, 0.5, alpha]),
            Style::Outline(data)
            | Style::Filled(data) => Cow::Borrowed(data),
        }
    }

    #[rustfmt::skip]
    fn is_outline(&self) -> bool {
        match *self {
            | Style::White
            | Style::OffWhite
            | Style::Outline(_) => true,
            Style::Filled(_) => false,
        }
    }

    #[rustfmt::skip]
    fn is_fill(&self) -> bool {
        match *self {
            Style::White
            | Style::OffWhite
            | Style::Filled(_) => true,
            Style::Outline(_) => false,
        }
    }
}

struct SegmentData {
    pos: Vector2<f32>,
    size: Vector2<f32>,
    deg: f32,
}

impl SegmentData {
    // FIXME: Use a const fn to generate these at construction time.
    fn constant_buffer(&self) -> LetterSegments {
        // TODO: Put this back into the segment data.
        let pos = self.pos.mul_element_wise(Vector2::new(1., -0.9));
        let size = self.size.mul_element_wise(Vector2::new(1.4, 1.05));
        let angle = Deg(self.deg % 180.);
        let trans = pos - size / 2.;

        let boxmat = Matrix4::from_translation(trans.extend(0.))
            * Matrix4::from_axis_angle(Vector3::unit_z(), angle);
        LetterSegments {
            boxmat: boxmat.into(),
            size: size.into(),
        }
    }
}

#[rustfmt::skip]
const LETTER_DATA: [&'static [SegmentData]; 44] = [
    &[
        SegmentData { pos: Vector2::new(0., 1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.6, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.6, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(-0.6, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.6, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., -1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
    ],
    &[
        SegmentData { pos: Vector2::new(0.5, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.5, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
    ],
    &[
        SegmentData { pos: Vector2::new(0., 1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., 0.), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., -1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
    ],
    &[
        SegmentData { pos: Vector2::new(0., 1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., 0.), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., -1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
    ],
    &[
        SegmentData { pos: Vector2::new(-0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., 0.), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
    ],
    &[
        SegmentData { pos: Vector2::new(0., 1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., 0.), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., -1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
    ],
    &[
        SegmentData { pos: Vector2::new(0., 1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., 0.), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., -1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
    ],
    &[
        SegmentData { pos: Vector2::new(0., 1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
    ],
    &[
        SegmentData { pos: Vector2::new(0., 1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., 0.), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., -1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
    ],
    &[
        SegmentData { pos: Vector2::new(0., 1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., 0.), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., -1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
    ],
    &[//
        SegmentData { pos: Vector2::new(0., 1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., 0.), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
    ],
    &[
        SegmentData { pos: Vector2::new(-0.18, 1.15), size: Vector2::new(0.45, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.45, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(-0.18, 0.), size: Vector2::new(0.45, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., -1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
    ],
    &[
        SegmentData { pos: Vector2::new(0., 1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(-0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., -1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
    ],
    &[
        SegmentData { pos: Vector2::new(-0.15, 1.15), size: Vector2::new(0.45, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.45, 0.45), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(-0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., -1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
    ],
    &[
        SegmentData { pos: Vector2::new(0., 1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., 0.), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., -1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
    ],
    &[//
        SegmentData { pos: Vector2::new(0., 1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., 0.), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
    ],
    &[
        SegmentData { pos: Vector2::new(0., 1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.05, 0.), size: Vector2::new(0.3, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., -1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
    ],
    &[
        SegmentData { pos: Vector2::new(-0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., 0.), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
    ],
    &[
        SegmentData { pos: Vector2::new(0., 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
    ],
    &[
        SegmentData { pos: Vector2::new(0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(-0.7, -0.7), size: Vector2::new(0.3, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., -1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
    ],
    &[//
        SegmentData { pos: Vector2::new(-0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.4, 0.55), size: Vector2::new(0.65, 0.3), deg: 100., },
        SegmentData { pos: Vector2::new(-0.25, 0.), size: Vector2::new(0.45, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.6, -0.55), size: Vector2::new(0.65, 0.3), deg: 80., },
    ],
    &[
        SegmentData { pos: Vector2::new(-0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(-0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., -1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
    ],
    &[
        SegmentData { pos: Vector2::new(-0.5, 1.15), size: Vector2::new(0.3, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(0.1, 1.15), size: Vector2::new(0.3, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(-0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
    ],
    &[
        SegmentData { pos: Vector2::new(0., 1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(-0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
    ],
    &[
        SegmentData { pos: Vector2::new(0., 1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(-0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., -1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
    ],
    &[//
        SegmentData { pos: Vector2::new(0., 1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., 0.), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
    ],
    &[
        SegmentData { pos: Vector2::new(0., 1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(-0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., -1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(0.05, -0.55), size: Vector2::new(0.45, 0.3), deg: 60., },
    ],
    &[
        SegmentData { pos: Vector2::new(0., 1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(-0.2, 0.), size: Vector2::new(0.45, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.45, -0.55), size: Vector2::new(0.65, 0.3), deg: 80., },
    ],
    &[
        SegmentData { pos: Vector2::new(0., 1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(-0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., 0.), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., -1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
    ],
    &[
        SegmentData { pos: Vector2::new(-0.5, 1.15), size: Vector2::new(0.55, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(0.5, 1.15), size: Vector2::new(0.55, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(0.1, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.1, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
    ],
    &[//
        SegmentData { pos: Vector2::new(-0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(-0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., -1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
    ],
    &[
        SegmentData { pos: Vector2::new(-0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(-0.5, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.5, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(-0.1, -1.15), size: Vector2::new(0.45, 0.3), deg: 0., },
    ],
    &[
        SegmentData { pos: Vector2::new(-0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(-0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.65, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(-0.5, -1.15), size: Vector2::new(0.3, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(0.1, -1.15), size: Vector2::new(0.3, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(0., 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
    ],
    &[
        SegmentData { pos: Vector2::new(-0.4, 0.6), size: Vector2::new(0.85, 0.3), deg: 240., },
        SegmentData { pos: Vector2::new(0.4, 0.6), size: Vector2::new(0.85, 0.3), deg: 300., },
        SegmentData { pos: Vector2::new(-0.4, -0.6), size: Vector2::new(0.85, 0.3), deg: 120., },
        SegmentData { pos: Vector2::new(0.4, -0.6), size: Vector2::new(0.85, 0.3), deg: 60., },
    ],
    &[
        SegmentData { pos: Vector2::new(-0.4, 0.6), size: Vector2::new(0.85, 0.3), deg: 240., },
        SegmentData { pos: Vector2::new(0.4, 0.6), size: Vector2::new(0.85, 0.3), deg: 300., },
        SegmentData { pos: Vector2::new(-0.1, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
    ],
    &[
        SegmentData { pos: Vector2::new(0., 1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(0.3, 0.4), size: Vector2::new(0.65, 0.3), deg: 120., },
        SegmentData { pos: Vector2::new(-0.3, -0.4), size: Vector2::new(0.65, 0.3), deg: 120., },
        SegmentData { pos: Vector2::new(0., -1.15), size: Vector2::new(0.65, 0.3), deg: 0., },
    ],
    &[//
        SegmentData { pos: Vector2::new(0., -1.15), size: Vector2::new(0.3, 0.3), deg: 0., },
    ],
    &[//
        SegmentData { pos: Vector2::new(0., -1.15), size: Vector2::new(0.8, 0.3), deg: 0., },
    ],
    &[//
        SegmentData { pos: Vector2::new(0., 0.), size: Vector2::new(0.9, 0.3), deg: 0., },
    ],
    &[//
        SegmentData { pos: Vector2::new(-0.5, 0.), size: Vector2::new(0.45, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(0.45, 0.), size: Vector2::new(0.45, 0.3), deg: 0., },
        SegmentData { pos: Vector2::new(0.1, 0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0.1, -0.55), size: Vector2::new(0.65, 0.3), deg: 90., },
    ],
    &[//
        SegmentData { pos: Vector2::new(0., 1.0), size: Vector2::new(0.4, 0.2), deg: 90., },
    ],
    &[//
        SegmentData { pos: Vector2::new(-0.19, 1.0), size: Vector2::new(0.4, 0.2), deg: 90., },
        SegmentData { pos: Vector2::new(0.2, 1.0), size: Vector2::new(0.4, 0.2), deg: 90., },
    ],
    &[//
        SegmentData { pos: Vector2::new(0.56, 0.25), size: Vector2::new(1.1, 0.3), deg: 90., },
        SegmentData { pos: Vector2::new(0., -1.0), size: Vector2::new(0.3, 0.3), deg: 90., },
    ],
    &[//
        SegmentData { pos: Vector2::new(0.8, 0.), size: Vector2::new(1.75, 0.3), deg: 120., },
    ],
];

impl SegmentData {
    fn segment_data_for(ch: char) -> &'static [SegmentData] {
        let ch_u8 = ch as u8;
        let idx = match ch {
            '0'..='9' => ch_u8 - b'0',
            'A'..='Z' => ch_u8 - b'A' + 10,
            'a'..='z' => ch_u8 - b'a' + 10,
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

        LETTER_DATA[idx]
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum Direction {
    Right,
    Down,
    Left,
    Up,
}

impl Direction {
    fn angle(self) -> Rad<f32> {
        Deg(match self {
            Direction::Right => 0.,
            Direction::Down => 90.,
            Direction::Left => 180.,
            Direction::Up => 270.,
        })
        .into()
    }

    fn offset(self, delta: Vector2<f32>) -> Vector2<f32> {
        let dx = delta.x * Vector2::unit_x();
        let dy = delta.y * Vector2::unit_y();

        match self {
            Direction::Right => dx,
            Direction::Down => dy,
            Direction::Left => -dx,
            Direction::Up => -dy,
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum Orientation {
    Normal,
    Reverse,
}

impl Orientation {
    fn y_flip(self) -> f32 {
        match self {
            Orientation::Normal => 1.,
            Orientation::Reverse => -1.,
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum Screen {
    Orthographic,
    Perspective,
}

#[derive(Clone, Copy)]
pub struct Location {
    position: Vector2<f32>,
    scale: f32,
    direction: Direction,
    orientation: Orientation,
    screen: Screen,
}

impl Location {
    pub const fn new(position: Vector2<f32>, scale: f32) -> Self {
        Location {
            position,
            scale,
            direction: Direction::Right,
            orientation: Orientation::Normal,
            screen: Screen::Orthographic,
        }
    }

    pub const fn new_persp(position: Vector2<f32>, scale: f32) -> Self {
        Location {
            position,
            scale,
            direction: Direction::Right,
            orientation: Orientation::Normal,
            screen: Screen::Perspective,
        }
    }

    fn offset_by(self, offset: Vector2<f32>) -> Self {
        Location {
            position: self.position + offset,
            scale: self.scale,
            direction: self.direction,
            orientation: self.orientation,
            screen: self.screen,
        }
    }

    fn scaled_by(self, scale: f32) -> Self {
        Location {
            position: self.position,
            scale: self.scale * scale,
            direction: self.direction,
            orientation: self.orientation,
            screen: self.screen,
        }
    }
}

impl Default for Location {
    fn default() -> Self {
        Location {
            position: Vector2::new(0., 0.),
            scale: 1.,
            direction: Direction::Right,
            orientation: Orientation::Normal,
            screen: Screen::Orthographic,
        }
    }
}

#[derive(Clone, Copy)]
pub struct NumberStyle {
    pub pad_to: Option<u8>,
    pub prefix_char: Option<char>,
    pub floating_digits: Option<u8>,
}

impl NumberStyle {
    pub const fn score() -> Self {
        NumberStyle {
            pad_to: None,
            prefix_char: None,
            floating_digits: None,
        }
    }

    pub const fn multiplier() -> Self {
        NumberStyle {
            pad_to: None,
            prefix_char: Some('x'),
            floating_digits: Some(3),
        }
    }

    fn reduce_padding(&mut self) {
        if let Some(pad) = self.pad_to {
            let new_pad = pad - 1;
            if new_pad == 0 {
                self.pad_to = None;
            } else {
                self.pad_to = Some(new_pad);
            }
        }
    }

    fn with_digits(&mut self, digits: Option<u8>) {
        self.floating_digits = digits;
    }

    fn is_necessary(self) -> bool {
        self.pad_to.is_some() || self.floating_digits.is_some()
    }
}

pub struct Letter<R>
where
    R: gfx::Resources,
{
    outline_slice: gfx::Slice<R>,
    outline_pso: gfx::PipelineState<R, <pipe::Data<R> as gfx::pso::PipelineData<R>>::Meta>,

    fan_slice: gfx::Slice<R>,
    fan_pso: gfx::PipelineState<R, <pipe::Data<R> as gfx::pso::PipelineData<R>>::Meta>,

    data_ortho: pipe::Data<R>,
    data_persp: pipe::Data<R>,
}

impl<R> Letter<R>
where
    R: gfx::Resources,
{
    pub fn new<F>(
        factory: &mut F,
        view: gfx::handle::RenderTargetView<R, TargetFormat>,
        context: &RenderContext<R>,
    ) -> Self
    where
        F: gfx::Factory<R>,
    {
        #[rustfmt::skip]
        let vertex_data = [
            Vertex { pos: [-0.5,   0.], },
            Vertex { pos: [-0.33, -0.5], },
            Vertex { pos: [ 0.33, -0.5], },
            Vertex { pos: [ 0.5,   0.], },
            Vertex { pos: [ 0.33,  0.5], },
            Vertex { pos: [-0.33,  0.5], },
        ];

        let vbuf = factory.create_vertex_buffer(&vertex_data);
        let outline_slice =
            abagames_util::slice_for_loop::<R, F>(factory, vertex_data.len() as u32);
        let fan_slice = abagames_util::slice_for_fan::<R, F>(factory, vertex_data.len() as u32);

        let program = factory
            .link_program(
                include_bytes!("shader/letter.glslv"),
                include_bytes!("shader/letter.glslf"),
            )
            .expect("could not link the letter shader");
        let outline_pso = factory
            .create_pipeline_from_program(
                &program,
                gfx::Primitive::LineStrip,
                gfx::state::Rasterizer {
                    front_face: gfx::state::FrontFace::CounterClockwise,
                    cull_face: gfx::state::CullFace::Nothing,
                    method: gfx::state::RasterMethod::Line(1),
                    offset: None,
                    samples: None,
                },
                pipe::new(),
            )
            .expect("failed to create the outline pipeline for letter");
        let fan_pso = factory
            .create_pipeline_from_program(
                &program,
                gfx::Primitive::TriangleList,
                gfx::state::Rasterizer::new_fill(),
                pipe::new(),
            )
            .expect("failed to create the fill pipeline for letter");

        let color_buffer = factory.create_constant_buffer(1);
        let letter_buffer = factory.create_constant_buffer(1);
        let segment_buffer = factory.create_constant_buffer(1);
        let data_ortho = pipe::Data {
            vbuf: vbuf.clone(),
            color: color_buffer.clone(),
            screen: context.orthographic_screen_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            letter: letter_buffer.clone(),
            segment: segment_buffer.clone(),
            out_color: view.clone(),
        };
        let data_persp = pipe::Data {
            vbuf,
            color: color_buffer,
            screen: context.perspective_screen_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            letter: letter_buffer,
            segment: segment_buffer,
            out_color: view,
        };

        Letter {
            outline_slice,
            outline_pso,

            fan_slice,
            fan_pso,

            data_ortho,
            data_persp,
        }
    }

    pub fn draw_letter<C>(&self, context: &mut EncoderContext<R, C>, letter: char, style: Style)
    where
        C: gfx::CommandBuffer<R>,
    {
        self.draw_letter_at(context, letter, style, Location::default())
    }

    pub fn draw_letter_at<C>(
        &self,
        context: &mut EncoderContext<R, C>,
        letter: char,
        style: Style,
        loc: Location,
    ) where
        C: gfx::CommandBuffer<R>,
    {
        let drawmat = Matrix4::from_translation(loc.position.extend(0.))
            * Matrix4::from_nonuniform_scale(
                loc.scale,
                loc.scale * loc.orientation.y_flip(),
                loc.scale,
            )
            * Matrix4::from_axis_angle(Vector3::unit_z(), -loc.direction.angle());
        self.draw_letter_with(context, drawmat, letter, style, loc.screen)
    }

    pub fn draw_letter_with<C>(
        &self,
        context: &mut EncoderContext<R, C>,
        matrix: Matrix4<f32>,
        letter: char,
        style: Style,
        screen: Screen,
    ) where
        C: gfx::CommandBuffer<R>,
    {
        let letter_trans = LetterTransforms {
            drawmat: matrix.into(),
        };
        context
            .encoder
            .update_constant_buffer(&self.data_persp.letter, &letter_trans);

        let data = match screen {
            Screen::Perspective => &self.data_persp,
            Screen::Orthographic => &self.data_ortho,
        };
        self.draw_letter_segments(context, letter, style, data)
    }

    pub fn draw_string<C>(
        &self,
        context: &mut EncoderContext<R, C>,
        string: &str,
        style: Style,
        loc: Location,
    ) where
        C: gfx::CommandBuffer<R>,
    {
        let offset = LETTER_OFFSET * loc.scale;

        string.chars().fold(loc.offset_by(offset / 2.), |loc, ch| {
            self.draw_letter_at(context, ch, style, loc);

            loc.offset_by(loc.direction.offset(offset))
        });
    }

    pub fn draw_number<C>(
        &self,
        context: &mut EncoderContext<R, C>,
        num: u32,
        style: Style,
        loc: Location,
        number_style: NumberStyle,
    ) where
        C: gfx::CommandBuffer<R>,
    {
        let offset = LETTER_OFFSET * loc.scale;
        let new_loc = loc.offset_by(offset);
        let norm_digit_offset = offset.x * Vector2::unit_x();
        let fp_offset_x = norm_digit_offset * 0.5;
        let fp_offset_y = offset.y * 0.25 * Vector2::unit_y();

        let res = iter::repeat(()).try_fold(
            (new_loc, num, number_style),
            |(loc, num, mut number_style), _| {
                let digit = Self::for_digit(num % 10);
                let next_num = num / 10;

                let (digit_offset, fd) = if let Some(fd) = number_style.floating_digits {
                    let fp_loc = loc.offset_by(fp_offset_y).scaled_by(0.5);
                    self.draw_letter_at(context, digit, style, fp_loc);
                    let new_fp = fd - 1;
                    if new_fp == 0 {
                        self.draw_letter_at(context, '.', style, fp_loc);
                        (2. * fp_offset_x, None)
                    } else {
                        (fp_offset_x, Some(new_fp))
                    }
                } else {
                    self.draw_letter_at(context, digit, style, loc);
                    (norm_digit_offset, None)
                };

                number_style.reduce_padding();

                let new_loc = loc.offset_by(-digit_offset);
                let ctor = if next_num > 0 || number_style.is_necessary() {
                    Ok
                } else {
                    Err
                };

                number_style.with_digits(fd);

                ctor((new_loc, next_num, number_style))
            },
        );
        let (loc, _, _) = match res {
            Ok(r) | Err(r) => r,
        };

        if let Some(prefix) = number_style.prefix_char {
            let prefix_offset = loc.scale * LETTER_WIDTH * 0.2;
            let prefix_offset = Vector2::new(prefix_offset, prefix_offset);
            let prefix_loc = Location {
                position: loc.position + prefix_offset,
                scale: loc.scale * 0.6,
                direction: Direction::Right,
                orientation: Orientation::Normal,
                screen: loc.screen,
            };
            self.draw_letter_at(context, prefix, style, prefix_loc);
        }
    }

    pub fn draw_time<C>(
        &self,
        context: &mut EncoderContext<R, C>,
        time: u32,
        style: Style,
        loc: Location,
    ) where
        C: gfx::CommandBuffer<R>,
    {
        let offset = loc.scale * LETTER_WIDTH * Vector2::unit_x();
        let offset_wide = offset * 1.3;
        let offset_quotes = loc.scale * 1.16 * Vector2::unit_x();

        let _ = (0..).try_fold((loc, time), |(loc, time), idx| {
            let new_time = if idx == 4 {
                let letter = Self::for_digit(time % 6);
                self.draw_letter_at(context, letter, style, loc);
                time / 6
            } else {
                let letter = Self::for_digit(time % 10);
                self.draw_letter_at(context, letter, style, loc);
                time / 10
            };

            let next_offset = if idx == 0 || (idx & 1) == 1 {
                let ch = if idx == 3 { '\"' } else { '\'' };
                self.draw_letter_at(context, ch, style, loc.offset_by(offset_quotes));

                offset
            } else {
                offset_wide
            };

            if new_time == 0 {
                Err((loc, new_time))
            } else {
                Ok((loc.offset_by(-next_offset), new_time))
            }
        });
    }

    fn draw_letter_segments<C>(
        &self,
        context: &mut EncoderContext<R, C>,
        letter: char,
        style: Style,
        data: &pipe::Data<R>,
    ) where
        C: gfx::CommandBuffer<R>,
    {
        SegmentData::segment_data_for(letter)
            .iter()
            // Get the constant buffer for the segment.
            .map(SegmentData::constant_buffer)
            .for_each(|letter_data| {
                context
                    .encoder
                    .update_constant_buffer(&data.segment, &letter_data);

                // TODO: Factor color setting out for custom colors.
                if style.is_fill() {
                    let color = Color {
                        color: style.color(0.5).into_owned(),
                    };
                    context.encoder.update_constant_buffer(&data.color, &color);

                    context.encoder.draw(&self.fan_slice, &self.fan_pso, data);
                }

                if style.is_outline() {
                    let color = Color {
                        color: style.color(1.).into_owned(),
                    };
                    context.encoder.update_constant_buffer(&data.color, &color);

                    context
                        .encoder
                        .draw(&self.outline_slice, &self.outline_pso, data);
                }
            });
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
