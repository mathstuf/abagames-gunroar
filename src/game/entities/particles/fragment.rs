// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying LICENSE file for details.

use crates::abagames_util::{self, Pool, PoolRemoval, Rand, TargetFormat};
use crates::cgmath::{Angle, Matrix4, Rad, Vector2, Vector3};
use crates::gfx;
use crates::gfx::traits::FactoryExt;
use crates::itertools::Itertools;

use game::entities::field::Field;
use game::entities::particles::{Smoke, SmokeKind};
use game::render::{EncoderContext, RenderContext};
use game::render::{Brightness, ScreenTransform};

use std::str;

#[derive(Debug, Clone, Copy)]
pub struct Fragment {
    pos: Vector3<f32>,
    vel: Vector3<f32>,
    size: f32,
    angle: Rad<f32>,
    angle_rate: Rad<f32>,
}

impl Fragment {
    fn new() -> Self {
        Fragment {
            pos: (0., 0., 0.).into(),
            vel: (0., 0., 0.).into(),
            size: 1.,
            angle: Rad(0.),
            angle_rate: Rad(0.),
        }
    }

    pub fn new_pool() -> Pool<Self> {
        Pool::new(MAX_FRAGMENT_SIZE, Self::new)
    }

    pub fn init(&mut self, pos: Vector2<f32>, vel: Vector3<f32>, size: f32, rand: &mut Rand) {
        self.pos = pos.extend(0.);
        self.vel = vel;
        self.size = f32::min(5., size);
        self.angle = Rad(rand.next_float(Rad::full_turn().0));
        self.angle_rate = Rad(rand.next_float_signed(Rad::<f32>::full_turn().0 / 18.));
    }

    pub fn step(&mut self, field: &Field, smokes: &mut Pool<Smoke>, rand: &mut Rand) -> PoolRemoval {
        if !field.is_in_outer_field(self.pos.truncate()) {
            return PoolRemoval::Remove;
        }

        self.vel = [
            self.vel.x * 0.96,
            self.vel.y * 0.96,
            self.vel.z + (-0.04 - self.vel.z) * 0.01,
        ].into();
        self.pos += self.vel;

        if self.pos.z < 0. {
            let (kind, size_factor) = if field.block(self.pos.truncate()).is_dry() {
                (SmokeKind::Sand, 0.75)
            } else {
                (SmokeKind::Wake, 0.66)
            };
            smokes.get_force()
                .init(self.pos, [0., 0., 0.].into(), kind, 60, self.size * size_factor, rand);
            return PoolRemoval::Remove;
        }
        self.pos.y -= field.last_scroll_y();
        self.angle += self.angle_rate;

        PoolRemoval::Keep
    }

    fn modelmat(&self) -> Matrix4<f32> {
        Matrix4::from_translation(self.pos) *
            Matrix4::from_axis_angle(Vector3::unit_x(), -self.angle) *
            Matrix4::from_nonuniform_scale(self.size, self.size, 1.)
    }
}

const MAX_FRAGMENT_SIZE: usize = 200;

gfx_defines! {
    vertex Vertex {
        pos: [f32; 2] = "pos",
    }

    constant Alpha {
        alpha: f32 = "alpha",
    }

    constant ModelMat {
        modelmat: [[f32; 4]; 4] = "modelmat",
    }

    pipeline pipe {
        vbuf: gfx::VertexBuffer<Vertex> = (),
        screen: gfx::ConstantBuffer<ScreenTransform> = "Screen",
        brightness: gfx::ConstantBuffer<Brightness> = "Brightness",
        alpha: gfx::ConstantBuffer<Alpha> = "Alpha",
        modelmat: gfx::ConstantBuffer<ModelMat> = "ModelMat",
        out_color: gfx::BlendTarget<TargetFormat> =
            ("Target0",
             gfx::state::ColorMask::all(),
             gfx::state::Blend::new(gfx::state::Equation::Add,
                                    gfx::state::Factor::ZeroPlus(gfx::state::BlendValue::SourceAlpha),
                                    gfx::state::Factor::OneMinus(gfx::state::BlendValue::SourceAlpha))),
    }
}

pub struct FragmentDraw<R>
    where R: gfx::Resources,
{
    fan_slice: gfx::Slice<R>,
    fan_pso: gfx::PipelineState<R, <pipe::Data<R> as gfx::pso::PipelineData<R>>::Meta>,

    outline_slice: gfx::Slice<R>,
    outline_pso: gfx::PipelineState<R, <pipe::Data<R> as gfx::pso::PipelineData<R>>::Meta>,

    data: pipe::Data<R>,
}

impl<R> FragmentDraw<R>
    where R: gfx::Resources,
{
    pub fn new<F>(factory: &mut F, view: gfx::handle::RenderTargetView<R, TargetFormat>,
                  context: &RenderContext<R>)
                  -> Self
        where F: gfx::Factory<R>,
    {
        let data = [
            Vertex { pos: [-0.5, -0.25] },
            Vertex { pos: [ 0.5, -0.25] },
            Vertex { pos: [ 0.5,  0.25] },
            Vertex { pos: [-0.5,  0.25] },
        ];

        let vbuf = factory.create_vertex_buffer(&data);
        let outline_slice = abagames_util::slice_for_loop::<R, F>(factory,
                                                                  data.len() as u32);
        let fan_slice = abagames_util::slice_for_fan::<R, F>(factory, data.len() as u32);

        let program = factory.link_program(
            include_bytes!("shader/fragment.glslv"),
            include_bytes!("shader/fragment.glslf"))
            .expect("could not link the fragment shader");
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
            .expect("failed to create the outline pipeline for letter");
        let fan_pso = factory.create_pipeline_from_program(
            &program,
            gfx::Primitive::TriangleList,
            gfx::state::Rasterizer::new_fill(),
            pipe::new())
            .expect("failed to create the fill pipeline for letter");

        let data = pipe::Data {
            vbuf: vbuf,
            alpha: factory.create_constant_buffer(1),
            modelmat: factory.create_constant_buffer(1),
            screen: context.perspective_screen_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            out_color: view,
        };

        FragmentDraw {
            fan_slice: fan_slice,
            fan_pso: fan_pso,

            outline_slice: outline_slice,
            outline_pso: outline_pso,

            data: data,
        }
    }

    pub fn draw<C>(&self, context: &mut EncoderContext<R, C>, fragments: &Pool<Fragment>)
        where C: gfx::CommandBuffer<R>,
    {
        fragments.iter()
            .foreach(|fragment| {
                let modelmat = ModelMat {
                    modelmat: fragment.modelmat().into(),
                };
                context.encoder.update_constant_buffer(&self.data.modelmat, &modelmat);

                let alpha = Alpha {
                    alpha: 0.5,
                };
                context.encoder.update_constant_buffer(&self.data.alpha, &alpha);
                context.encoder.draw(&self.fan_slice, &self.fan_pso, &self.data);

                let alpha = Alpha {
                    alpha: 0.9,
                };
                context.encoder.update_constant_buffer(&self.data.alpha, &alpha);
                context.encoder.draw(&self.outline_slice, &self.outline_pso, &self.data);
            });
    }
}
