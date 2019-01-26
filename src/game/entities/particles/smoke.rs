// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying LICENSE file for details.

use crates::abagames_util::{self, Pool, PoolRemoval, Rand, TargetFormat};
use crates::cgmath::{Angle, ElementWise, InnerSpace, Rad, Vector2, Vector3, Vector4};
use crates::gfx;
use crates::gfx::traits::FactoryExt;

use game::entities::field::{Block, Field};
use game::entities::particles::{Wake, WakeDirection};
use game::render::{EncoderContext, RenderContext};
use game::render::{Brightness, ScreenTransform};

use std::str;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SmokeKind {
    Fire,
    Explosion,
    Sand,
    Spark,
    Wake,
    Smoke,
    LanceSpark,
}

impl SmokeKind {
    fn color(&self, rand: &mut Rand) -> Vector4<f32> {
        match *self {
            SmokeKind::Fire => {
                [
                    rand.next_float(0.1) + 0.9,
                    rand.next_float(0.2) + 0.2,
                    0.,
                    1.,
                ]
            },
            SmokeKind::Explosion => {
                [
                    rand.next_float(0.3) + 0.7,
                    rand.next_float(0.3) + 0.3,
                    0.,
                    1.,
                ]
            },
            SmokeKind::Sand => {
                [0.8, 0.8, 0.6, 0.6]
            },
            SmokeKind::Spark => {
                [
                    rand.next_float(0.3) + 0.7,
                    rand.next_float(0.5) + 0.5,
                    0.,
                    1.,
                ]
            },
            SmokeKind::Wake => {
                [0.8, 0.6, 0.8, 0.6]
            },
            SmokeKind::Smoke => {
                [
                    rand.next_float(0.1) + 0.1,
                    rand.next_float(0.1) + 0.1,
                    0.1,
                    0.5,
                ]
            },
            SmokeKind::LanceSpark => {
                [
                    0.4,
                    rand.next_float(0.2) + 0.7,
                    rand.next_float(0.2) + 0.7,
                    1.,
                ]
            },
        }.into()
    }
}

const WIND_VELOCITY: Vector3<f32> = Vector3 {
    x: 0.04,
    y: 0.04,
    z: 0.02,
};

#[derive(Debug, Clone, Copy)]
pub struct Smoke {
    pos: Vector3<f32>,
    vel: Vector3<f32>,
    kind: SmokeKind,
    count: u32,
    start_count: u32,
    size: f32,
    color: Vector4<f32>,
}

impl Smoke {
    fn new() -> Self {
        Smoke {
            pos: (0., 0., 0.).into(),
            vel: (0., 0., 0.).into(),
            kind: SmokeKind::Fire,
            count: 0,
            start_count: 1,
            size: 1.,
            color: (0., 0., 0., 0.).into(),
        }
    }

    pub fn new_pool() -> Pool<Self> {
        Pool::new(MAX_SMOKE_SIZE, Self::new)
    }

    pub fn init_2d(&mut self, pos: Vector2<f32>, vel: Vector3<f32>, kind: SmokeKind, count: u32, size: f32, rand: &mut Rand) {
        self.init(Vector3::new(pos.x, pos.y, 0.), vel, kind, count, size, rand)
    }

    pub fn init(&mut self, pos: Vector3<f32>, vel: Vector3<f32>, kind: SmokeKind, count: u32, size: f32, rand: &mut Rand) {
        self.pos = pos;
        self.vel = vel;
        self.kind = kind;
        self.start_count = count;
        self.count = count;
        self.size = size;
        self.color = kind.color(rand);
    }

    pub fn step(&mut self, field: &Field, wakes: &mut Pool<Wake>, rand: &mut Rand) -> PoolRemoval {
        self.count = self.count.saturating_sub(1);
        if self.count == 0 || !field.is_in_outer_field(self.pos.truncate()) {
            return PoolRemoval::Remove;
        }

        if self.kind != SmokeKind::Wake {
            self.vel += (WIND_VELOCITY - self.vel) * 0.01;
        }

        self.pos += self.vel;
        self.pos.y -= field.last_scroll_y();

        match self.kind {
            SmokeKind::Fire | SmokeKind::Explosion | SmokeKind::Smoke => {
                let color_factor = if self.count < self.start_count / 2 {
                    Vector4::new(0.95, 0.95, 0.95, 1. as f32)
                } else {
                    Vector4::new(1., 1., 1., 0.97 as f32)
                };
                self.color.mul_assign_element_wise(color_factor);
                self.size *= 1.01;
            },
            SmokeKind::Sand => {
                self.color *= 0.98;
            },
            SmokeKind::Spark => {
                self.color.mul_assign_element_wise(Vector4::new(0.92, 0.92, 1., 0.95 as f32));
                self.vel *= 0.9;
            },
            SmokeKind::Wake => {
                self.color.w *= 0.98;
                self.size *= 1.005;
            },
            SmokeKind::LanceSpark => {
                self.color.w *= 0.95;
                self.size *= 0.97;
            },
        }

        self.size = f32::min(5., self.size);

        if self.kind == SmokeKind::Explosion && self.pos.z < 0.01 {
            let block = field.block(self.pos.truncate());
            if block >= Block::Shore {
                self.vel *= 0.8;
            }
            if self.count % 3 == 0 && block < Block::Shore {
                let speed = self.vel.magnitude();
                if speed > 0.3 {
                    let angle = Rad::atan2(self.vel.y, self.vel.x);
                    let pos2d = self.pos.truncate();
                    let left_vec: Vector2<f32> = (angle + Rad::turn_div_4()).sin_cos().into();
                    let right_vec: Vector2<f32> = (angle - Rad::turn_div_4()).sin_cos().into();
                    let wake_pos = pos2d + left_vec * self.size * 0.25;
                    wakes.get_force()
                        .init(field,
                              wake_pos,
                              angle + Rad::turn_div_2() - Rad(0.2 + rand.next_float_signed(0.1)),
                              speed * 0.33,
                              20 + rand.next_int(12),
                              self.size * (7. + rand.next_float(3.)),
                              WakeDirection::Forward);
                    let wake_pos = pos2d + right_vec * self.size * 0.25;
                    wakes.get_force()
                        .init(field,
                              wake_pos,
                              angle + Rad::turn_div_2() - Rad(0.2 + rand.next_float_signed(0.1)),
                              speed * 0.33,
                              20 + rand.next_int(12),
                              self.size * (7. + rand.next_float(3.)),
                              WakeDirection::Forward);
                }
            }
        }

        PoolRemoval::Keep
    }
}

const MAX_SMOKE_SIZE: usize = 200;

gfx_defines! {
    vertex Vertex {
        diff: [f32; 2] = "diff",
    }

    constant PerSmoke {
        color: [f32; 4] = "color",
        pos: [f32; 3] = "pos",
        size: f32 = "size",
    }

    pipeline pipe {
        vbuf: gfx::VertexBuffer<Vertex> = (),
        screen: gfx::ConstantBuffer<ScreenTransform> = "Screen",
        brightness: gfx::ConstantBuffer<Brightness> = "Brightness",
        smokes: gfx::ConstantBuffer<PerSmoke> = "Smokes",
        out_color: gfx::BlendTarget<TargetFormat> =
            ("Target0",
             gfx::state::ColorMask::all(),
             gfx::state::Blend::new(gfx::state::Equation::Add,
                                    gfx::state::Factor::ZeroPlus(gfx::state::BlendValue::SourceAlpha),
                                    gfx::state::Factor::OneMinus(gfx::state::BlendValue::SourceAlpha))),
    }
}

pub struct SmokeDraw<R>
    where R: gfx::Resources,
{
    slice: gfx::Slice<R>,
    pso: gfx::PipelineState<R, <pipe::Data<R> as gfx::pso::PipelineData<R>>::Meta>,
    data: pipe::Data<R>,
}

impl<R> SmokeDraw<R>
    where R: gfx::Resources,
{
    pub fn new<F>(factory: &mut F, view: gfx::handle::RenderTargetView<R, TargetFormat>,
                  context: &RenderContext<R>)
                  -> Self
        where F: gfx::Factory<R>,
    {
        let data = [
            Vertex { diff: [-0.5, -0.5] },
            Vertex { diff: [ 0.5, -0.5] },
            Vertex { diff: [ 0.5,  0.5] },
            Vertex { diff: [-0.5,  0.5] },
        ];

        let vbuf = factory.create_vertex_buffer(&data);
        let slice = abagames_util::slice_for_fan::<R, F>(factory,
                                                         data.len() as u32);

        let vert_source = str::from_utf8(include_bytes!("shader/smoke.glslv")).expect("invalid utf-8 in smoke vertex shader");
        let frag_source = str::from_utf8(include_bytes!("shader/smoke.glslf")).expect("invalid utf-8 in smoke fragment shader");
        let size_str = format!("{}", MAX_SMOKE_SIZE);
        let pso = factory.create_pipeline_simple(
            vert_source.replace("NUM_SMOKES", &size_str).as_bytes(),
            frag_source.replace("NUM_SMOKES", &size_str).as_bytes(),
            pipe::new())
            .expect("failed to create the pipeline for smoke");

        let data = pipe::Data {
            vbuf: vbuf,
            smokes: factory.create_upload_buffer(MAX_SMOKE_SIZE)
                .expect("failed to create the buffer for smoke"),
            screen: context.perspective_screen_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            out_color: view,
        };

        SmokeDraw {
            slice: slice,
            pso: pso,
            data: data,
        }
    }

    pub fn prep_draw<F>(&mut self, factory: &mut F, smokes: &Pool<Smoke>)
        where F: gfx::Factory<R>,
    {
        let mut writer = factory.write_mapping(&self.data.smokes)
            .expect("could not get a writeable mapping to the smoke buffer");

        let num_smokes = smokes.iter()
            .enumerate()
            .map(|(idx, smoke)| {
                writer[idx] = PerSmoke {
                    color: smoke.color.into(),
                    pos: smoke.pos.into(),
                    size: smoke.size,
                };
            })
            .count();

        self.slice.instances = Some((num_smokes as gfx::InstanceCount, 0));
    }

    pub fn draw<C>(&self, context: &mut EncoderContext<R, C>)
        where C: gfx::CommandBuffer<R>,
    {
        context.encoder.draw(&self.slice, &self.pso, &self.data);
    }
}
