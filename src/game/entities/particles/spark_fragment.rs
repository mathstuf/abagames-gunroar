// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying LICENSE file for details.

use std::str;

use abagames_util::{self, Pool, PoolRemoval, Rand, TargetFormat};
use cgmath::{Angle, Matrix4, Rad, Vector2, Vector3};
use gfx;
use gfx::traits::FactoryExt;
use gfx::*;

use crate::game::entities::field::Field;
use crate::game::entities::particles::{Smoke, SmokeKind};
use crate::game::render::{Brightness, ScreenTransform};
use crate::game::render::{EncoderContext, RenderContext};

#[derive(Debug, Clone, Copy)]
pub struct SparkFragment {
    pos: Vector3<f32>,
    vel: Vector3<f32>,
    size: f32,
    angle: Rad<f32>,
    angle_rate: Rad<f32>,
    count: u32,
    has_smoke: bool,
}

impl SparkFragment {
    const fn new() -> Self {
        SparkFragment {
            pos: Vector3::new(0., 0., 0.),
            vel: Vector3::new(0., 0., 0.),
            size: 1.,
            angle: Rad(0.),
            angle_rate: Rad(0.),
            count: 0,
            has_smoke: false,
        }
    }

    pub fn new_pool() -> Pool<Self> {
        Pool::new(MAX_SPARK_FRAGMENT_SIZE, Self::new)
    }

    pub fn init(&mut self, pos: Vector2<f32>, vel: Vector3<f32>, size: f32, rand: &mut Rand) {
        self.pos = pos.extend(0.);
        self.vel = vel;
        self.size = f32::min(5., size);
        self.angle = Rad(rand.next_float(Rad::full_turn().0));
        self.angle_rate = Rad(rand.next_float_signed(Rad::<f32>::full_turn().0 / 24.));
        self.count = 0;
        self.has_smoke = rand.next_int(4) == 0;
    }

    pub fn step(
        &mut self,
        field: &Field,
        smokes: &mut Pool<Smoke>,
        rand: &mut Rand,
    ) -> PoolRemoval {
        self.vel = [
            self.vel.x * 0.99,
            self.vel.y * 0.99,
            self.vel.z + (-0.08 - self.vel.z) * 0.01,
        ]
        .into();
        self.pos += self.vel;

        if self.pos.z < 0. {
            let (kind, size_factor) = if field.block(self.pos.truncate()).is_dry() {
                (SmokeKind::Sand, 0.75)
            } else {
                (SmokeKind::Wake, 0.66)
            };

            smokes.get_force().init(
                self.pos,
                [0., 0., 0.].into(),
                kind,
                60,
                self.size * size_factor,
                rand,
            );
            return PoolRemoval::Remove;
        }

        self.pos.y -= field.last_scroll_y();
        self.angle += self.angle_rate;

        self.count += 1;
        if self.has_smoke && self.count % 5 == 0 {
            smokes.get().map(|smoke| {
                smoke.init(
                    self.pos,
                    [0., 0., 0.].into(),
                    SmokeKind::Smoke,
                    90 + rand.next_int(60),
                    self.size * 0.5,
                    rand,
                );
            });
        }

        PoolRemoval::Keep
    }

    fn modelmat(&self) -> Matrix4<f32> {
        Matrix4::from_translation(self.pos)
            * Matrix4::from_nonuniform_scale(self.size, self.size, 1.)
            * Matrix4::from_axis_angle(Vector3::unit_x(), -self.angle)
    }
}

const MAX_SPARK_FRAGMENT_SIZE: usize = 40;

gfx_defines! {
    vertex Vertex {
        pos: [f32; 2] = "pos",
    }

    constant PerSparkFragment {
        modelmat: [[f32; 4]; 4] = "modelmat",
        color: [f32; 4] = "color",
    }

    pipeline pipe {
        vbuf: gfx::VertexBuffer<Vertex> = (),
        screen: gfx::ConstantBuffer<ScreenTransform> = "Screen",
        brightness: gfx::ConstantBuffer<Brightness> = "Brightness",
        spark_fragments: gfx::ConstantBuffer<PerSparkFragment> = "SparkFragments",
        out_color: gfx::BlendTarget<TargetFormat> =
            ("Target0",
             gfx::state::ColorMask::all(),
             gfx::state::Blend::new(gfx::state::Equation::Add,
                                    gfx::state::Factor::ZeroPlus(gfx::state::BlendValue::SourceAlpha),
                                    gfx::state::Factor::OneMinus(gfx::state::BlendValue::SourceAlpha))),
    }
}

pub struct SparkFragmentDraw<R>
where
    R: gfx::Resources,
{
    slice: gfx::Slice<R>,
    pso: gfx::PipelineState<R, <pipe::Data<R> as gfx::pso::PipelineData<R>>::Meta>,
    data: pipe::Data<R>,
}

impl<R> SparkFragmentDraw<R>
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
        let data = [
            Vertex { pos: [-0.25, -0.25] },
            Vertex { pos: [ 0.25, -0.25] },
            Vertex { pos: [ 0.25,  0.25] },
            Vertex { pos: [-0.25,  0.25] },
        ];

        let vbuf = factory.create_vertex_buffer(&data);
        let slice = abagames_util::slice_for_fan::<R, F>(factory, data.len() as u32);

        let vert_source = str::from_utf8(include_bytes!("shader/spark_fragment.glslv"))
            .expect("invalid utf-8 in spark fragment vertex shader");
        let frag_source = str::from_utf8(include_bytes!("shader/spark_fragment.glslf"))
            .expect("invalid utf-8 in spark fragment fragment shader");
        let size_str = format!("{}", MAX_SPARK_FRAGMENT_SIZE);
        let pso = factory
            .create_pipeline_simple(
                vert_source
                    .replace("NUM_SPARK_FRAGMENTS", &size_str)
                    .as_bytes(),
                frag_source
                    .replace("NUM_SPARK_FRAGMENTS", &size_str)
                    .as_bytes(),
                pipe::new(),
            )
            .expect("failed to create the pipeline for spark");

        let data = pipe::Data {
            vbuf,
            spark_fragments: factory
                .create_upload_buffer(MAX_SPARK_FRAGMENT_SIZE)
                .expect("failed to create the pipeline for spark fragment"),
            screen: context.perspective_screen_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            out_color: view,
        };

        SparkFragmentDraw {
            slice,
            pso,
            data,
        }
    }

    pub fn prep_draw<F>(
        &mut self,
        factory: &mut F,
        spark_fragments: &Pool<SparkFragment>,
        rand: &mut Rand,
    ) where
        F: gfx::Factory<R>,
    {
        let mut writer = factory
            .write_mapping(&self.data.spark_fragments)
            .expect("could not get a writeable mapping to the spark fragment buffer");

        let num_spark_fragments = spark_fragments
            .iter()
            .enumerate()
            .map(|(idx, spark_fragment)| {
                writer[idx] = PerSparkFragment {
                    modelmat: spark_fragment.modelmat().into(),
                    color: [1., rand.next_float(1.), 0., 0.8],
                };
            })
            .count();

        self.slice.instances = Some((num_spark_fragments as gfx::InstanceCount, 0));
    }

    pub fn draw<C>(&self, context: &mut EncoderContext<R, C>)
    where
        C: gfx::CommandBuffer<R>,
    {
        context.encoder.draw(&self.slice, &self.pso, &self.data);
    }
}
