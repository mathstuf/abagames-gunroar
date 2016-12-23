// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

extern crate abagames_util;

extern crate cgmath;
use self::cgmath::{Deg, Matrix4, Rad, Vector2};

extern crate gfx;
use self::gfx::traits::FactoryExt;

extern crate image;

extern crate itertools;
use self::itertools::FoldWhile::{Continue, Done};
use self::itertools::Itertools;

use super::super::render::{EncoderContext, RenderContext};
use super::super::state::{GameMode, Scores};
pub use super::super::render::{Brightness, OrthographicScreen};

use super::letter::{Letter, LetterDirection, LetterOrientation, LetterStyle};
// use super::letter::{Letter, LetterDirection, LetterStyle};

use std::borrow::Cow;
use std::io::Cursor;
use std::iter;

gfx_defines! {
    vertex LogoVertex {
        pos: [f32; 2] = "pos",
        tex: [f32; 2] = "tex",
    }

    vertex LogoLineVertex {
        pos: [f32; 2] = "pos",
    }

    vertex LogoFillVertex {
        pos: [f32; 2] = "pos",
        color: [f32; 3] = "color",
    }

    constant ModelTransform {
        modelmat: [[f32; 4]; 4] = "modelmat",
    }

    constant LetterSegments {
        boxmat: [[f32; 4]; 4] = "boxmat",
        size: [f32; 2] = "size",
    }

    pipeline logo_pipe {
        vbuf: gfx::VertexBuffer<LogoVertex> = (),
        screen: gfx::ConstantBuffer<OrthographicScreen> = "Screen",
        model: gfx::ConstantBuffer<ModelTransform> = "ModelTransform",
        brightness: gfx::ConstantBuffer<Brightness> = "Brightness",
        sampler: gfx::TextureSampler<[f32; 4]> = "sampler",
        out_color: gfx::BlendTarget<gfx::format::Srgba8> =
            ("Target0",
             gfx::state::MASK_ALL,
             gfx::state::Blend::new(gfx::state::Equation::Add,
                                    gfx::state::Factor::ZeroPlus(gfx::state::BlendValue::SourceAlpha),
                                    gfx::state::Factor::One)),
    }

    pipeline logo_line_pipe {
        vbuf: gfx::VertexBuffer<LogoLineVertex> = (),
        screen: gfx::ConstantBuffer<OrthographicScreen> = "Screen",
        model: gfx::ConstantBuffer<ModelTransform> = "ModelTransform",
        brightness: gfx::ConstantBuffer<Brightness> = "Brightness",
        out_color: gfx::BlendTarget<gfx::format::Srgba8> =
            ("Target0",
             gfx::state::MASK_ALL,
             gfx::state::Blend::new(gfx::state::Equation::Add,
                                    gfx::state::Factor::ZeroPlus(gfx::state::BlendValue::SourceAlpha),
                                    gfx::state::Factor::One)),
    }

    pipeline logo_fill_pipe {
        vbuf: gfx::VertexBuffer<LogoFillVertex> = (),
        screen: gfx::ConstantBuffer<OrthographicScreen> = "Screen",
        model: gfx::ConstantBuffer<ModelTransform> = "ModelTransform",
        brightness: gfx::ConstantBuffer<Brightness> = "Brightness",
        out_color: gfx::BlendTarget<gfx::format::Srgba8> =
            ("Target0",
             gfx::state::MASK_ALL,
             gfx::state::Blend::new(gfx::state::Equation::Add,
                                    gfx::state::Factor::ZeroPlus(gfx::state::BlendValue::SourceAlpha),
                                    gfx::state::Factor::One)),
    }
}

#[derive(Clone, Copy)]
pub enum TitleState {
    Replay,
    GameSelection(GameMode),
}

pub struct Title<R>
    where R: gfx::Resources,
{
    count: u32,
    state: TitleState,

    model_buffer: gfx::handle::Buffer<R, ModelTransform>,

    logo_bundle: gfx::Bundle<R, logo_pipe::Data<R>>,
    logo_line_bundle: gfx::Bundle<R, logo_line_pipe::Data<R>>,
    logo_fill_bundle: gfx::Bundle<R, logo_fill_pipe::Data<R>>,
}

impl<R> Title<R>
    where R: gfx::Resources,
{
    pub fn new<F>(factory: &mut F, view: gfx::handle::RenderTargetView<R, gfx::format::Srgba8>,
                  context: &RenderContext<R>)
                  -> Self
        where F: gfx::Factory<R>,
    {
        let logo_data = [
            LogoVertex { pos: [  0., -63.], tex: [0., 0.], },
            LogoVertex { pos: [255., -63.], tex: [1., 0.], },
            LogoVertex { pos: [255.,   0.], tex: [1., 1.], },
            LogoVertex { pos: [  0.,   0.], tex: [0., 1.], },
        ];

        let logo_vbuf = factory.create_vertex_buffer(&logo_data);
        let logo_slice = abagames_util::slice_for_fan::<R, F>(factory, logo_data.len() as u32);

        let logo_pso = factory.create_pipeline_simple(
            include_bytes!("shader/title_logo.glslv"),
            include_bytes!("shader/title_logo.glslf"),
            logo_pipe::new())
            .unwrap();

        let logo_bmp_data = include_bytes!("images/title.bmp");
        let logo_img = image::load(Cursor::new(&logo_bmp_data[..]), image::BMP).unwrap().to_rgba();
        let (logo_width, logo_height) = logo_img.dimensions();
        let logo_tex_kind = gfx::texture::Kind::D2(
            logo_width as gfx::texture::Size,
            logo_height as gfx::texture::Size,
            gfx::texture::AaMode::Single);
        let (_, logo_tex) =
            factory.create_texture_immutable_u8::<gfx::format::Rgba8>(logo_tex_kind, &[&logo_img])
                .unwrap();
        let logo_sampler = factory.create_sampler(gfx::texture::SamplerInfo::new(
            gfx::texture::FilterMethod::Mipmap,
            gfx::texture::WrapMode::Tile
        ));

        let logo_line_data = [
            LogoLineVertex { pos: [-80.,  -7.], },
            LogoLineVertex { pos: [-20.,  -7.], },
            LogoLineVertex { pos: [-20.,  -7.], }, // Duplicated.
            LogoLineVertex { pos: [ 10., -70.], },
            LogoLineVertex { pos: [ 45.,  -2.], },
            LogoLineVertex { pos: [-15.,  -2.], },
            LogoLineVertex { pos: [-15.,  -2.], }, // Duplicated.
            LogoLineVertex { pos: [-45.,  61.], },
        ];

        let (logo_line_vbuf, logo_line_slice) =
            factory.create_vertex_buffer_with_slice(&logo_line_data, ());

        let logo_line_program = factory.link_program(include_bytes!("shader/title_logo_line.glslv"),
                          include_bytes!("shader/title_logo_line.glslf"))
            .unwrap();
        let logo_line_pso = factory.create_pipeline_from_program(
            &logo_line_program,
            gfx::Primitive::LineList,
            gfx::state::Rasterizer {
                front_face: gfx::state::FrontFace::CounterClockwise,
                cull_face: gfx::state::CullFace::Nothing,
                method: gfx::state::RasterMethod::Line(3),
                offset: None,
                samples: None,
            },
            logo_line_pipe::new())
            .unwrap();

        let logo_fill_data = [
            LogoFillVertex { pos: [-19.,  -6.], color: [1., 1., 1.], },
            LogoFillVertex { pos: [-79.,  -6.], color: [0., 0., 0.], },
            LogoFillVertex { pos: [ 11., -69.], color: [0., 0., 0.], },
            LogoFillVertex { pos: [-16.,  -3.], color: [1., 1., 1.], },
            LogoFillVertex { pos: [ 44.,  -3.], color: [0., 0., 0.], },
            LogoFillVertex { pos: [-46.,  60.], color: [0., 0., 0.], },
        ];

        let (logo_fill_vbuf, logo_fill_slice) =
            factory.create_vertex_buffer_with_slice(&logo_fill_data, ());
        let logo_fill_pso = factory.create_pipeline_simple(
            include_bytes!("shader/title_logo_fill.glslv"),
            include_bytes!("shader/title_logo_fill.glslf"),
            logo_fill_pipe::new())
            .unwrap();

        let model_buffer = factory.create_constant_buffer(1);

        let logo_data = logo_pipe::Data {
            vbuf: logo_vbuf,
            screen: context.orthographic_screen_buffer.clone(),
            model: model_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            sampler: (logo_tex, logo_sampler),
            out_color: view.clone(),
        };

        let logo_line_data = logo_line_pipe::Data {
            vbuf: logo_line_vbuf,
            screen: context.orthographic_screen_buffer.clone(),
            model: model_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            out_color: view.clone(),
        };

        let logo_fill_data = logo_fill_pipe::Data {
            vbuf: logo_fill_vbuf,
            screen: context.orthographic_screen_buffer.clone(),
            model: model_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            out_color: view,
        };

        Title {
            count: 0,
            state: TitleState::Replay,

            model_buffer: model_buffer,

            logo_bundle: gfx::Bundle::new(logo_slice, logo_pso, logo_data),
            logo_line_bundle: gfx::Bundle::new(logo_line_slice, logo_line_pso, logo_line_data),
            logo_fill_bundle: gfx::Bundle::new(logo_fill_slice, logo_fill_pso, logo_fill_data),
        }
    }

    pub fn init(&mut self) {
        self.count = 0;

        self.state = TitleState::GameSelection(GameMode::Mouse);
    }

    pub fn step(&mut self) -> TitleState {
        self.count = self.count.saturating_add(1);

        self.state
    }

    pub fn draw<C>(&self, context: &mut EncoderContext<R, C>, letter: &Letter<R>, scores: &Scores)
        where C: gfx::CommandBuffer<R>,
    {
        match self.state {
            TitleState::Replay => {
                letter.draw_string(context,
                                   "REPLAY",
                                   Vector2::new(3., 400.),
                                   5.,
                                   LetterDirection::Right,
                                   &LetterStyle::White,
                                   LetterOrientation::Normal)
            },
            TitleState::GameSelection(mode) => self.draw_title(context, letter, scores, mode),
        }
    }

    fn draw_title<C>(&self, context: &mut EncoderContext<R, C>, letter: &Letter<R>,
                     scores: &Scores, mode: GameMode)
        where C: gfx::CommandBuffer<R>,
    {
        let translation_factor = if self.count > 120 {
            f32::max(1. - ((self.count - 120) as f32) * 0.015, 0.5)
        } else {
            1.
        };
        let modelmat =
            Matrix4::from_translation((80. * translation_factor, 240., 0.).into()) *
            Matrix4::from_nonuniform_scale(translation_factor, translation_factor, 0.);
        let model = ModelTransform {
            modelmat: modelmat.into(),
        };
        context.encoder.update_constant_buffer(&self.model_buffer, &model);

        self.logo_bundle.encode(context.encoder);
        self.logo_line_bundle.encode(context.encoder);
        self.logo_fill_bundle.encode(context.encoder);

        if self.count > 150 {
            self.draw_score(context,
                            letter,
                            Vector2::new(3., 305.),
                            "HIGH",
                            scores.high_for_mode(mode));
        }
        if self.count > 200 {
            self.draw_score(context,
                            letter,
                            Vector2::new(3., 345.),
                            "LAST",
                            scores.last());
        }
        letter.draw_string(context,
                           mode.name(),
                           Vector2::new(3., 400.),
                           5.,
                           LetterDirection::Right,
                           &LetterStyle::White,
                           LetterOrientation::Normal);
    }

    fn draw_score<C>(&self, context: &mut EncoderContext<R, C>, letter: &Letter<R>,
                     pos: Vector2<f32>, label: &str, score: u32)
        where C: gfx::CommandBuffer<R>,
    {
        letter.draw_string(context,
                           label,
                           pos,
                           4.,
                           LetterDirection::Right,
                           &LetterStyle::OffWhite,
                           LetterOrientation::Normal);
        letter.draw_number(context,
                           score,
                           pos + Vector2::new(77., 15.),
                           4.,
                           &LetterStyle::OffWhite,
                           Some(9),
                           None,
                           None);
    }
}
