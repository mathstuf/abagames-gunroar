// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

use crates::abagames_util::{self, Pool, PoolRemoval};
use crates::cgmath::{Angle, Rad, Vector2};
use crates::gfx;
use crates::gfx::traits::FactoryExt;

use game::entities::field::Field;
use game::render::{EncoderContext, RenderContext};
use game::render::{Brightness, ScreenTransform};

use std::str;

pub enum WakeDirection {
    Forward,
    Reverse,
}

impl WakeDirection {
    fn factor(&self) -> i32 {
        match *self {
            WakeDirection::Forward => 0,
            WakeDirection::Reverse => 1,
        }
    }
}

pub struct Wake {
    pos: Vector2<f32>,
    vel: Vector2<f32>,
    angle: Rad<f32>,
    speed: f32,
    size: f32,
    count: u32,
    direction: WakeDirection,
}

impl Wake {
    fn new() -> Self {
        Wake {
            pos: (0., 0.).into(),
            vel: (0., 0.).into(),
            size: 1.,
            angle: Rad(0.),
            speed: 0.,
            count: 0,
            direction: WakeDirection::Forward,
        }
    }

    pub fn init(&mut self, field: &Field, pos: Vector2<f32>, angle: Rad<f32>, speed: f32, count: u32, size: f32, direction: WakeDirection) {
        if !field.is_in_outer_field(self.pos) {
            self.count = 0;
            return;
        }

        self.pos = pos;
        self.angle = angle;
        self.speed = speed;
        let angle_comps: Vector2<f32> = angle.sin_cos().into();
        self.vel = angle_comps * speed;
        self.count = count;
        self.size = size;
        self.direction = direction;
    }

    pub fn step(&mut self, field: &Field) -> PoolRemoval {
        self.count.saturating_sub(1);
        if self.count == 0 || abagames_util::fast_distance_origin(self.vel) < 0.005 || field.is_in_outer_field(self.pos) {
            PoolRemoval::Remove
        } else {
            self.pos += self.vel;
            self.pos.y -= field.last_scroll_y();
            self.vel *= 0.96;
            self.size *= 1.02;
            PoolRemoval::Keep
        }
    }
}

const MAX_WAKE_SIZE: usize = 100;

pub struct WakePool {
    pool: Pool<Wake>,
}

impl WakePool {
    pub fn new(size: usize) -> Self {
        if size > MAX_WAKE_SIZE {
            panic!();
        }

        WakePool {
            pool: Pool::new(size, Wake::new),
        }
    }
}

gfx_defines! {
    vertex Vertex {
        vel_factor: [f32; 2] = "vel_factor",
        vel_flip: f32 = "vel_flip",
        color: [f32; 4] = "color",
    }

    constant PerWake {
        pos: [f32; 2] = "pos",
        vel: [f32; 2] = "vel",
        size: f32 = "size",
        reverse: i32 = "reverse",
        _dummy: [f32; 2] = "_dummy",
    }

    pipeline pipe {
        vbuf: gfx::VertexBuffer<Vertex> = (),
        screen: gfx::ConstantBuffer<ScreenTransform> = "Screen",
        brightness: gfx::ConstantBuffer<Brightness> = "Brightness",
        wakes: gfx::ConstantBuffer<PerWake> = "Wakes",
        out_color: gfx::BlendTarget<gfx::format::Srgba8> =
            ("Target0",
             gfx::state::MASK_ALL,
             gfx::state::Blend::new(gfx::state::Equation::Add,
                                    gfx::state::Factor::ZeroPlus(gfx::state::BlendValue::SourceAlpha),
                                    gfx::state::Factor::One)),
    }
}

pub struct WakePoolDraw<R>
    where R: gfx::Resources,
{
    slice: gfx::Slice<R>,
    pso: gfx::PipelineState<R, <pipe::Data<R> as gfx::pso::PipelineData<R>>::Meta>,
    data: pipe::Data<R>,
    wakes: gfx::handle::Buffer<R, PerWake>,
}

impl<R> WakePoolDraw<R>
    where R: gfx::Resources,
{
    pub fn new<F>(factory: &mut F, view: gfx::handle::RenderTargetView<R, gfx::format::Srgba8>,
                  context: &RenderContext<R>)
                  -> Self
        where F: gfx::Factory<R>,
    {
        let data = [
            Vertex {
                vel_factor: [-1., -1.],
                vel_flip: 0.,
                color: [0.33, 0.33, 1., 1.],
            },
            Vertex {
                vel_factor: [-0.2, 0.2],
                vel_flip: 1.,
                color: [0.2, 0.2, 0.6, 0.5],
            },
            Vertex {
                vel_factor: [0.2, -0.2],
                vel_flip: 1.,
                color: [0.2, 0.2, 0.6, 0.5],
            },
        ];

        let vbuf = factory.create_vertex_buffer(&data);
        let slice = abagames_util::slice_for_fan::<R, F>(factory,
                                                             data.len() as u32);

        let wakes =
            factory.create_buffer(MAX_WAKE_SIZE,
                                  gfx::buffer::Role::Constant,
                                  gfx::memory::Usage::Dynamic,
                                  gfx::Bind::empty())
                .expect("failed to create the buffer for wake");

        let vert_source = str::from_utf8(include_bytes!("shader/wake.glslv")).expect("invalid utf-8 in wake vertex shader");
        let frag_source = str::from_utf8(include_bytes!("shader/wake.glslf")).expect("invalid utf-8 in wake fragment shader");
        let size_str = format!("{}", MAX_WAKE_SIZE);
        let pso = factory.create_pipeline_simple(
            vert_source.replace("NUM_WAKES", &size_str).as_bytes(),
            frag_source.replace("NUM_WAKES", &size_str).as_bytes(),
            pipe::new())
            .expect("failed to create the pipeline for wake");

        let data = pipe::Data {
            vbuf: vbuf,
            wakes: wakes.clone(),
            screen: context.perspective_screen_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            out_color: view,
        };

        WakePoolDraw {
            slice: slice,
            pso: pso,
            data: data,
            wakes: wakes,
        }
    }

    pub fn prep_draw<F>(&mut self, factory: &mut F, wakes: &WakePool)
        where F: gfx::Factory<R>,
    {
        let mut writer = factory.write_mapping(&self.wakes)
            .expect("could not get a writeable mapping to the wake buffer");

        let num_wakes = wakes.pool
            .iter()
            .enumerate()
            .map(|(idx, wake)| {
                writer[idx] = PerWake {
                    pos: wake.pos.into(),
                    vel: wake.vel.into(),
                    size: wake.size,
                    reverse: wake.direction.factor(),
                    _dummy: [0., 0.],
                };
            })
            .count();

        self.slice.instances = Some((num_wakes as gfx::InstanceCount, 0));
    }

    pub fn draw<C>(&self, context: &mut EncoderContext<R, C>)
        where C: gfx::CommandBuffer<R>,
    {
        context.encoder.draw(&self.slice, &self.pso, &self.data);
    }
}
