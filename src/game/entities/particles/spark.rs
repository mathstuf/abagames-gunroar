// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying LICENSE file for details.

use crates::abagames_util::{self, Pool, PoolRemoval, TargetFormat};
use crates::cgmath::{Vector2, Vector3};
use crates::gfx;
use crates::gfx::traits::FactoryExt;

use game::render::{Brightness, ScreenTransform};
use game::render::{EncoderContext, RenderContext};

use std::str;

#[derive(Debug, Clone, Copy)]
pub struct Spark {
    pos: Vector2<f32>,
    vel: Vector2<f32>,
    color: Vector3<f32>,
    count: u32,
}

impl Spark {
    fn new() -> Self {
        Spark {
            pos: (0., 0.).into(),
            vel: (0., 0.).into(),
            color: (0., 0., 0.).into(),
            count: 0,
        }
    }

    pub fn new_pool() -> Pool<Self> {
        Pool::new(MAX_SPARK_SIZE, Self::new)
    }

    pub fn init(&mut self, pos: Vector2<f32>, vel: Vector2<f32>, color: Vector3<f32>, count: u32) {
        self.pos = pos;
        self.vel = vel;
        self.color = color;
        self.count = count;
    }

    pub fn step(&mut self) -> PoolRemoval {
        self.count = self.count.saturating_sub(1);
        if self.count == 0 || abagames_util::fast_distance_origin(self.vel) < 0.005 {
            PoolRemoval::Remove
        } else {
            self.pos += self.vel;
            self.vel *= 0.95;
            PoolRemoval::Keep
        }
    }
}

const MAX_SPARK_SIZE: usize = 120;

gfx_defines! {
    vertex Vertex {
        vel_factor: [f32; 2] = "vel_factor",
        vel_flip: i32 = "vel_flip",
        color_factor: [f32; 4] = "color_factor",
    }

    constant PerSpark {
        pos: [f32; 2] = "pos",
        vel: [f32; 2] = "vel",
        color: [f32; 3] = "color",
        // Alignment element.
        _dummy: f32 = "_dummy",
    }

    pipeline pipe {
        vbuf: gfx::VertexBuffer<Vertex> = (),
        screen: gfx::ConstantBuffer<ScreenTransform> = "Screen",
        brightness: gfx::ConstantBuffer<Brightness> = "Brightness",
        sparks: gfx::ConstantBuffer<PerSpark> = "Sparks",
        out_color: gfx::BlendTarget<TargetFormat> =
            ("Target0",
             gfx::state::ColorMask::all(),
             gfx::state::Blend::new(gfx::state::Equation::Add,
                                    gfx::state::Factor::ZeroPlus(gfx::state::BlendValue::SourceAlpha),
                                    gfx::state::Factor::One)),
    }
}

pub struct SparkDraw<R>
where
    R: gfx::Resources,
{
    slice: gfx::Slice<R>,
    pso: gfx::PipelineState<R, <pipe::Data<R> as gfx::pso::PipelineData<R>>::Meta>,
    data: pipe::Data<R>,
}

impl<R> SparkDraw<R>
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
        let data = [
            Vertex {
                vel_factor: [-2., -2.],
                vel_flip: 0,
                color_factor: [1., 1., 1., 1.],
            },
            Vertex {
                vel_factor: [-1., 1.],
                vel_flip: 1,
                color_factor: [0.5, 0.5, 0.5, 0.],
            },
            Vertex {
                vel_factor: [1., -1.],
                vel_flip: 1,
                color_factor: [0.5, 0.5, 0.5, 0.],
            },
        ];

        let vbuf = factory.create_vertex_buffer(&data);
        let slice = abagames_util::slice_for_fan::<R, F>(factory, data.len() as u32);

        let vert_source = str::from_utf8(include_bytes!("shader/spark.glslv"))
            .expect("invalid utf-8 in spark vertex shader");
        let frag_source = str::from_utf8(include_bytes!("shader/spark.glslf"))
            .expect("invalid utf-8 in spark fragment shader");
        let size_str = format!("{}", MAX_SPARK_SIZE);
        let pso = factory
            .create_pipeline_simple(
                vert_source.replace("NUM_SPARKS", &size_str).as_bytes(),
                frag_source.replace("NUM_SPARKS", &size_str).as_bytes(),
                pipe::new(),
            )
            .expect("failed to create the pipeline for spark");

        let data = pipe::Data {
            vbuf: vbuf,
            sparks: factory
                .create_upload_buffer(MAX_SPARK_SIZE)
                .expect("failed to create the pipeline for spark"),
            screen: context.perspective_screen_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            out_color: view,
        };

        SparkDraw {
            slice: slice,
            pso: pso,
            data: data,
        }
    }

    pub fn prep_draw<F>(&mut self, factory: &mut F, sparks: &Pool<Spark>)
    where
        F: gfx::Factory<R>,
    {
        let mut writer = factory
            .write_mapping(&self.data.sparks)
            .expect("could not get a writeable mapping to the spark buffer");

        let num_sparks = sparks
            .iter()
            .enumerate()
            .map(|(idx, spark)| {
                writer[idx] = PerSpark {
                    pos: spark.pos.into(),
                    vel: spark.vel.into(),
                    color: spark.color.into(),
                    _dummy: 0.,
                };
            })
            .count();

        self.slice.instances = Some((num_sparks as gfx::InstanceCount, 0));
    }

    pub fn draw<C>(&self, context: &mut EncoderContext<R, C>)
    where
        C: gfx::CommandBuffer<R>,
    {
        context.encoder.draw(&self.slice, &self.pso, &self.data);
    }
}
