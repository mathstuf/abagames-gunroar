// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying LICENSE file for details.

use crates::abagames_util::{self, TargetFormat};
use crates::cgmath::{Angle, Matrix4, Rad};
use crates::gfx;
use crates::gfx::traits::FactoryExt;

use game::render::{Brightness, ScreenTransform};
use game::render::{EncoderContext, RenderContext};

use std::iter;

gfx_defines! {
    constant ModelMat {
        modelmat: [[f32; 4]; 4] = "modelmat",
    }

    vertex Pos {
        pos: [f32; 2] = "pos",
    }

    vertex Color {
        color: [f32; 3] = "color",
    }

    pipeline pipe {
        pos: gfx::VertexBuffer<Pos> = (),
        color: gfx::VertexBuffer<Color> = (),
        screen: gfx::ConstantBuffer<ScreenTransform> = "Screen",
        brightness: gfx::ConstantBuffer<Brightness> = "Brightness",
        modelmat: gfx::ConstantBuffer<ModelMat> = "ModelMat",
        out_color: gfx::BlendTarget<TargetFormat> =
            ("Target0",
             gfx::state::ColorMask::all(),
             gfx::state::Blend::new(gfx::state::Equation::Add,
                                    gfx::state::Factor::ZeroPlus(gfx::state::BlendValue::SourceAlpha),
                                    gfx::state::Factor::One)),
    }
}

pub struct ShieldDraw<R>
where
    R: gfx::Resources,
{
    outline_bundle: gfx::Bundle<R, pipe::Data<R>>,
    fill_bundle: gfx::Bundle<R, pipe::Data<R>>,

    modelmat: gfx::handle::Buffer<R, ModelMat>,
}

impl<R> ShieldDraw<R>
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
        let pos_vertex_data = (0..9)
            .map(|i| {
                let pos = if i == 0 {
                    [0., 0.]
                } else {
                    let (sin, cos) = (Rad::full_turn() * (i as f32) / 8.).sin_cos();
                    [sin, cos]
                };

                Pos {
                    pos: pos,
                }
            })
            .collect::<Vec<_>>();
        let pos_vbuf = factory.create_vertex_buffer(&pos_vertex_data);

        let outline_vertex_data = iter::repeat(Color {
            color: [0.5, 0.5, 0.7],
        })
        .take(8)
        .collect::<Vec<_>>();
        let outline_vbuf = factory.create_vertex_buffer(&outline_vertex_data);

        let fill_vertex_data = iter::once(Color {
            color: [0., 0., 0.],
        })
        .chain(iter::repeat(Color {
            color: [0.3, 0.3, 0.5],
        }))
        .take(pos_vertex_data.len())
        .collect::<Vec<_>>();
        let fill_vbuf = factory.create_vertex_buffer(&fill_vertex_data);

        let program = factory
            .link_program(
                include_bytes!("shader/shield.glslv"),
                include_bytes!("shader/shield.glslf"),
            )
            .expect("could not link the shield shader");

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
            .expect("failed to create the outline pipeline for shield");
        let fill_pso = factory
            .create_pipeline_from_program(
                &program,
                gfx::Primitive::TriangleList,
                gfx::state::Rasterizer::new_fill(),
                pipe::new(),
            )
            .expect("failed to create the fan pipeline for shield");

        let mut outline_slice =
            abagames_util::slice_for_loop::<R, F>(factory, outline_vertex_data.len() as u32);
        outline_slice.start += 1;
        outline_slice.end += 1;
        let fill_slice =
            abagames_util::slice_for_fan::<R, F>(factory, fill_vertex_data.len() as u32);

        let modelmat = factory.create_constant_buffer(1);

        let outline_data = pipe::Data {
            pos: pos_vbuf.clone(),
            color: outline_vbuf,
            screen: context.perspective_screen_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            modelmat: modelmat.clone(),
            out_color: view.clone(),
        };
        let fill_data = pipe::Data {
            pos: pos_vbuf,
            color: fill_vbuf,
            screen: context.perspective_screen_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            modelmat: modelmat.clone(),
            out_color: view,
        };

        ShieldDraw {
            outline_bundle: gfx::Bundle::new(outline_slice, outline_pso, outline_data),
            fill_bundle: gfx::Bundle::new(fill_slice, fill_pso, fill_data),

            modelmat: modelmat,
        }
    }

    pub fn draw<C>(&self, context: &mut EncoderContext<R, C>, modelmat: Matrix4<f32>)
    where
        C: gfx::CommandBuffer<R>,
    {
        let modelmat = ModelMat {
            modelmat: modelmat.into(),
        };
        context
            .encoder
            .update_constant_buffer(&self.modelmat, &modelmat);

        self.outline_bundle.encode(context.encoder);
        self.fill_bundle.encode(context.encoder);
    }
}
