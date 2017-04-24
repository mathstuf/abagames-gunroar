// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

use crates::abagames_util::{self, Pool};
use crates::cgmath::Matrix4;
use crates::gfx;
use crates::gfx::traits::FactoryExt;

use game::entities::crystal::{Crystal, MAX_CRYSTAL_SIZE};
use game::render::{EncoderContext, RenderContext};
use game::render::{Brightness, ScreenTransform};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BulletShapeKind {
    Normal,
    Small,
    MovingTurret,
    Destructible,
}

impl BulletShapeKind {
    fn outline_color(&self) -> [f32; 3] {
        match *self {
            BulletShapeKind::Normal => [1., 1., 0.3],
            BulletShapeKind::Small => [0.6, 0.9, 0.3],
            BulletShapeKind::MovingTurret => [0.7, 0.5, 0.9],
            BulletShapeKind::Destructible => [0.9, 0.9, 0.6],
        }.into()
    }

    fn fill_color(&self) -> [f32; 3] {
        match *self {
            BulletShapeKind::Normal => [0.5, 0.2, 0.1],
            BulletShapeKind::Small => [0.2, 0.4, 0.1],
            BulletShapeKind::MovingTurret => [0.2, 0.2, 0.3],
            BulletShapeKind::Destructible => [0.7, 0.5, 0.4],
        }
    }
}

gfx_defines! {
    constant ModelMat {
        modelmat: [[f32; 4]; 4] = "modelmat",
    }

    constant Color {
        color: [f32; 3] = "color",
    }

    vertex Vertex2 {
        pos: [f32; 2] = "pos",
    }

    vertex Vertex3 {
        pos: [f32; 3] = "pos",
    }

    vertex PerCrystal {
        modelmat_col0: [f32; 4] = "modelmat_col0",
        modelmat_col1: [f32; 4] = "modelmat_col1",
        modelmat_col2: [f32; 4] = "modelmat_col2",
        modelmat_col3: [f32; 4] = "modelmat_col3",
    }

    pipeline pipe2 {
        vbuf: gfx::VertexBuffer<Vertex2> = (),
        screen: gfx::ConstantBuffer<ScreenTransform> = "Screen",
        brightness: gfx::ConstantBuffer<Brightness> = "Brightness",
        modelmat: gfx::ConstantBuffer<ModelMat> = "ModelMat",
        color: gfx::ConstantBuffer<Color> = "Color",
        out_color: gfx::BlendTarget<gfx::format::Srgba8> =
            ("Target0",
             gfx::state::MASK_ALL,
             gfx::state::Blend::new(gfx::state::Equation::Add,
                                    gfx::state::Factor::ZeroPlus(gfx::state::BlendValue::SourceAlpha),
                                    gfx::state::Factor::One)),
    }

    pipeline pipe2_outline {
        vbuf: gfx::VertexBuffer<Vertex2> = (),
        screen: gfx::ConstantBuffer<ScreenTransform> = "Screen",
        brightness: gfx::ConstantBuffer<Brightness> = "Brightness",
        modelmat: gfx::ConstantBuffer<ModelMat> = "ModelMat",
        color: gfx::ConstantBuffer<Color> = "Color",
        out_color: gfx::RenderTarget<gfx::format::Srgba8> = "Target0",
    }

    pipeline pipe3 {
        vbuf: gfx::VertexBuffer<Vertex3> = (),
        screen: gfx::ConstantBuffer<ScreenTransform> = "Screen",
        brightness: gfx::ConstantBuffer<Brightness> = "Brightness",
        modelmat: gfx::ConstantBuffer<ModelMat> = "ModelMat",
        color: gfx::ConstantBuffer<Color> = "Color",
        out_color: gfx::BlendTarget<gfx::format::Srgba8> =
            ("Target0",
             gfx::state::MASK_ALL,
             gfx::state::Blend::new(gfx::state::Equation::Add,
                                    gfx::state::Factor::ZeroPlus(gfx::state::BlendValue::SourceAlpha),
                                    gfx::state::Factor::One)),
    }

    pipeline pipe3_outline {
        vbuf: gfx::VertexBuffer<Vertex3> = (),
        screen: gfx::ConstantBuffer<ScreenTransform> = "Screen",
        brightness: gfx::ConstantBuffer<Brightness> = "Brightness",
        modelmat: gfx::ConstantBuffer<ModelMat> = "ModelMat",
        color: gfx::ConstantBuffer<Color> = "Color",
        out_color: gfx::RenderTarget<gfx::format::Srgba8> = "Target0",
    }

    pipeline crystal_pipe {
        vbuf: gfx::VertexBuffer<Vertex2> = (),
        screen: gfx::ConstantBuffer<ScreenTransform> = "Screen",
        brightness: gfx::ConstantBuffer<Brightness> = "Brightness",
        instances: gfx::InstanceBuffer<PerCrystal> = (),
        color: gfx::ConstantBuffer<Color> = "Color",
        out_color: gfx::BlendTarget<gfx::format::Srgba8> =
            ("Target0",
             gfx::state::MASK_ALL,
             gfx::state::Blend::new(gfx::state::Equation::Add,
                                    gfx::state::Factor::ZeroPlus(gfx::state::BlendValue::SourceAlpha),
                                    gfx::state::Factor::OneMinus(gfx::state::BlendValue::SourceAlpha))),
    }
}

impl From<Matrix4<f32>> for PerCrystal {
    fn from(matrix: Matrix4<f32>) -> Self {
        PerCrystal {
            modelmat_col0: matrix.x.into(),
            modelmat_col1: matrix.y.into(),
            modelmat_col2: matrix.z.into(),
            modelmat_col3: matrix.w.into(),
        }
    }
}

pub struct BulletDraw<R>
    where R: gfx::Resources,
{
    pipe2_pso: gfx::PipelineState<R, <pipe2::Data<R> as gfx::pso::PipelineData<R>>::Meta>,
    pipe2_outline_pso: gfx::PipelineState<R, <pipe2_outline::Data<R> as gfx::pso::PipelineData<R>>::Meta>,

    pipe3_pso: gfx::PipelineState<R, <pipe3::Data<R> as gfx::pso::PipelineData<R>>::Meta>,
    pipe3_outline_pso: gfx::PipelineState<R, <pipe3_outline::Data<R> as gfx::pso::PipelineData<R>>::Meta>,

    outline_slice_a: gfx::Slice<R>,
    outline_slice_b: gfx::Slice<R>,
    destructible_outline_slice: gfx::Slice<R>,

    fill_slice: gfx::Slice<R>,
    destructible_fill_slice: gfx::Slice<R>,

    modelmat: gfx::handle::Buffer<R, ModelMat>,
    color: gfx::handle::Buffer<R, Color>,

    normal_outline_data: pipe3_outline::Data<R>,
    small_outline_data: pipe3_outline::Data<R>,
    destructible_outline_data: pipe2_outline::Data<R>,

    normal_data: pipe3::Data<R>,
    small_data: pipe3::Data<R>,
    destructible_data: pipe2::Data<R>,

    crystal_slice: gfx::Slice<R>,
    crystal_pso: gfx::PipelineState<R, <crystal_pipe::Data<R> as gfx::pso::PipelineData<R>>::Meta>,
    crystal_data: crystal_pipe::Data<R>,
    crystal_instances: gfx::handle::Buffer<R, PerCrystal>,
}

impl<R> BulletDraw<R>
    where R: gfx::Resources,
{
    pub fn new<F>(factory: &mut F, view: gfx::handle::RenderTargetView<R, gfx::format::Srgba8>,
                  context: &RenderContext<R>)
                  -> Self
        where F: gfx::Factory<R>,
    {
        let normal_vertex_data = [
            Vertex3 { pos: [0.2, -0.25, 0.2], },
            Vertex3 { pos: [0., 0.33, 0.], },
            Vertex3 { pos: [-0.2, -0.25, -0.2], },

            Vertex3 { pos: [-0.2, -0.25, 0.2], },
            Vertex3 { pos: [0., 0.33, 0.], },
            Vertex3 { pos: [0.2, -0.25, -0.2], },

            Vertex3 { pos: [0., 0.33, 0.], },
            Vertex3 { pos: [0.2, -0.25, 0.2], },
            Vertex3 { pos: [-0.2, -0.25, 0.2], },
            Vertex3 { pos: [-0.2, -0.25, -0.2], },
            Vertex3 { pos: [0.2, -0.25, -0.2], },
            Vertex3 { pos: [0.2, -0.25, 0.2], },
        ];
        let normal_vbuf = factory.create_vertex_buffer(&normal_vertex_data);

        let small_vertex_data = [
            Vertex3 { pos: [0.25, -0.25, 0.25], },
            Vertex3 { pos: [0., 0.33, 0.], },
            Vertex3 { pos: [-0.25, -0.25, -0.25], },

            Vertex3 { pos: [-0.25, -0.25, 0.25], },
            Vertex3 { pos: [0., 0.33, 0.], },
            Vertex3 { pos: [0.25, -0.25, -0.25], },

            Vertex3 { pos: [0., 0.33, 0.], },
            Vertex3 { pos: [0.25, -0.25, 0.25], },
            Vertex3 { pos: [-0.25, -0.25, 0.25], },
            Vertex3 { pos: [-0.25, -0.25, -0.25], },
            Vertex3 { pos: [0.25, -0.25, -0.25], },
            Vertex3 { pos: [0.25, -0.25, 0.25], },
        ];
        let small_vbuf = factory.create_vertex_buffer(&small_vertex_data);

        let destructible_vertex_data = [
            Vertex2 { pos: [0.2, 0.], },
            Vertex2 { pos: [0., 0.4], },
            Vertex2 { pos: [-0.2, 0.], },
            Vertex2 { pos: [0., -0.4], },
        ];
        let destructible_vbuf = factory.create_vertex_buffer(&destructible_vertex_data);

        let crystal_vertex_data = [
            Vertex2 { pos: [-0.2, 0.2], },
            Vertex2 { pos: [0.2, 0.2], },
            Vertex2 { pos: [0.2, -0.2], },
            Vertex2 { pos: [-0.2, -0.2], },
        ];
        let crystal_vbuf = factory.create_vertex_buffer(&crystal_vertex_data);

        let frag_shader = factory.create_shader_pixel(include_bytes!("shader/uniform3.glslf"))
            .expect("failed to compile the fragment shader for bullet shapes");
        let vert2_shader = factory.create_shader_vertex(include_bytes!("shader/uniform2.glslv"))
            .expect("failed to compile the vertex shader for 2-pos bullet shapes");
        let vert3_shader = factory.create_shader_vertex(include_bytes!("shader/uniform3.glslv"))
            .expect("failed to compile the vertex shader for 3-pos bullet shapes");
        let crystal_shader = factory.create_shader_vertex(include_bytes!("shader/crystal.glslv"))
            .expect("failed to compile the vertex shader for crystals");

        let pipe2_program = factory.create_program(&gfx::ShaderSet::Simple(vert2_shader, frag_shader.clone()))
            .expect("failed to link the 2-pos shader");
        let pipe3_program = factory.create_program(&gfx::ShaderSet::Simple(vert3_shader, frag_shader.clone()))
            .expect("failed to link the 3-pos shader");

        let crystal_program = factory.create_program(&gfx::ShaderSet::Simple(crystal_shader, frag_shader.clone()))
            .expect("failed to link the crystal shader");

        let pipe2_outline_pso = factory.create_pipeline_from_program(
            &pipe2_program,
            gfx::Primitive::LineStrip,
            gfx::state::Rasterizer {
                front_face: gfx::state::FrontFace::CounterClockwise,
                cull_face: gfx::state::CullFace::Nothing,
                method: gfx::state::RasterMethod::Line(1),
                offset: None,
                samples: None,
            },
            pipe2_outline::new())
            .expect("failed to create the outline pipeline for 2-pos");
        let pipe2_pso = factory.create_pipeline_from_program(
            &pipe2_program,
            gfx::Primitive::TriangleList,
            gfx::state::Rasterizer::new_fill(),
            pipe2::new())
            .expect("failed to create the fan pipeline for 2-pos");

        let pipe3_outline_pso = factory.create_pipeline_from_program(
            &pipe3_program,
            gfx::Primitive::LineStrip,
            gfx::state::Rasterizer {
                front_face: gfx::state::FrontFace::CounterClockwise,
                cull_face: gfx::state::CullFace::Nothing,
                method: gfx::state::RasterMethod::Line(1),
                offset: None,
                samples: None,
            },
            pipe3_outline::new())
            .expect("failed to create the outline pipeline for 3-pos");
        let pipe3_pso = factory.create_pipeline_from_program(
            &pipe3_program,
            gfx::Primitive::TriangleList,
            gfx::state::Rasterizer::new_fill(),
            pipe3::new())
            .expect("failed to create the fan pipeline for 3-pos");

        let crystal_pso = factory.create_pipeline_from_program(
            &crystal_program,
            gfx::Primitive::LineStrip,
            gfx::state::Rasterizer {
                front_face: gfx::state::FrontFace::CounterClockwise,
                cull_face: gfx::state::CullFace::Nothing,
                method: gfx::state::RasterMethod::Line(1),
                offset: None,
                samples: None,
            },
            crystal_pipe::new())
            .expect("failed to create the pipeline for crystal");

        let outline_slice_a = abagames_util::slice_for_loop::<R, F>(factory, 3);
        let mut outline_slice_b = outline_slice_a.clone();
        outline_slice_b.base_vertex = 3;
        let mut fill_slice = abagames_util::slice_for_fan::<R, F>(factory, 6);
        fill_slice.base_vertex = 6;

        let destructible_outline_slice = abagames_util::slice_for_loop::<R, F>(factory,
                                                                               destructible_vertex_data.len() as u32);
        let destructible_fill_slice = abagames_util::slice_for_fan::<R, F>(factory,
                                                                           destructible_vertex_data.len() as u32);

        let crystal_slice = abagames_util::slice_for_loop::<R, F>(factory,
                                                                  crystal_vertex_data.len() as u32);
        let crystal_instances =
            factory.create_buffer(4 * MAX_CRYSTAL_SIZE,
                                  gfx::buffer::Role::Vertex,
                                  gfx::memory::Usage::Upload,
                                  gfx::Bind::empty())
                .expect("failed to create the instance buffer for crystals");

        let modelmat = factory.create_constant_buffer(1);
        let color = factory.create_constant_buffer(1);

        let normal_outline_data = pipe3_outline::Data {
            vbuf: normal_vbuf.clone(),
            screen: context.perspective_screen_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            modelmat: modelmat.clone(),
            color: color.clone(),
            out_color: view.clone(),
        };
        let normal_data = pipe3::Data {
            vbuf: normal_vbuf.clone(),
            screen: context.perspective_screen_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            modelmat: modelmat.clone(),
            color: color.clone(),
            out_color: view.clone(),
        };

        let small_outline_data = pipe3_outline::Data {
            vbuf: small_vbuf.clone(),
            screen: context.perspective_screen_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            modelmat: modelmat.clone(),
            color: color.clone(),
            out_color: view.clone(),
        };
        let small_data = pipe3::Data {
            vbuf: small_vbuf.clone(),
            screen: context.perspective_screen_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            modelmat: modelmat.clone(),
            color: color.clone(),
            out_color: view.clone(),
        };

        let destructible_outline_data = pipe2_outline::Data {
            vbuf: destructible_vbuf.clone(),
            screen: context.perspective_screen_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            modelmat: modelmat.clone(),
            color: color.clone(),
            out_color: view.clone(),
        };
        let destructible_data = pipe2::Data {
            vbuf: destructible_vbuf.clone(),
            screen: context.perspective_screen_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            modelmat: modelmat.clone(),
            color: color.clone(),
            out_color: view.clone(),
        };

        let crystal_data = crystal_pipe::Data {
            vbuf: crystal_vbuf.clone(),
            screen: context.perspective_screen_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            instances: crystal_instances.clone(),
            color: color.clone(),
            out_color: view.clone(),
        };

        BulletDraw {
            pipe2_pso: pipe2_pso,
            pipe2_outline_pso: pipe2_outline_pso,

            pipe3_pso: pipe3_pso,
            pipe3_outline_pso: pipe3_outline_pso,

            outline_slice_a: outline_slice_a,
            outline_slice_b: outline_slice_b,
            destructible_outline_slice: destructible_outline_slice,

            fill_slice: fill_slice,
            destructible_fill_slice: destructible_fill_slice,

            modelmat: modelmat,
            color: color,

            normal_outline_data: normal_outline_data,
            small_outline_data: small_outline_data,
            destructible_outline_data: destructible_outline_data,

            normal_data: normal_data,
            small_data: small_data,
            destructible_data: destructible_data,

            crystal_slice: crystal_slice,
            crystal_pso: crystal_pso,
            crystal_data: crystal_data,
            crystal_instances: crystal_instances,
        }
    }

    fn draw_bullet_impl<C>(&self, encoder: &mut gfx::Encoder<R, C>, kind: BulletShapeKind)
        where C: gfx::CommandBuffer<R>,
    {
        let color = Color {
            color: kind.outline_color(),
        };
        encoder.update_constant_buffer(&self.color, &color);

        match kind {
            BulletShapeKind::Normal => {
                encoder.draw(&self.outline_slice_a, &self.pipe3_outline_pso, &self.normal_outline_data);
                encoder.draw(&self.outline_slice_b, &self.pipe3_outline_pso, &self.normal_outline_data);
            },
            BulletShapeKind::Small | BulletShapeKind::MovingTurret => {
                encoder.draw(&self.outline_slice_a, &self.pipe3_outline_pso, &self.small_outline_data);
                encoder.draw(&self.outline_slice_b, &self.pipe3_outline_pso, &self.small_outline_data);
            },
            BulletShapeKind::Destructible => {
                encoder.draw(&self.destructible_outline_slice, &self.pipe2_outline_pso, &self.destructible_outline_data);
            },
        }

        let color = Color {
            color: kind.fill_color(),
        };
        encoder.update_constant_buffer(&self.color, &color);

        match kind {
            BulletShapeKind::Normal => {
                encoder.draw(&self.fill_slice, &self.pipe3_pso, &self.normal_data);
            },
            BulletShapeKind::Small | BulletShapeKind::MovingTurret => {
                encoder.draw(&self.fill_slice, &self.pipe3_pso, &self.small_data);
            },
            BulletShapeKind::Destructible => {
                encoder.draw(&self.destructible_fill_slice, &self.pipe2_pso, &self.destructible_data);
            },
        }
    }

    pub fn draw_bullet<C>(&self, context: &mut EncoderContext<R, C>, kind: BulletShapeKind, modelmat: Matrix4<f32>)
        where C: gfx::CommandBuffer<R>,
    {
        let modelmat = ModelMat {
            modelmat: modelmat.into(),
        };
        context.encoder.update_constant_buffer(&self.modelmat, &modelmat);

        self.draw_bullet_impl(context.encoder, kind)
    }

    pub fn prep_draw_crystals<F>(&mut self, factory: &mut F, crystals: &Pool<Crystal>)
        where F: gfx::Factory<R>,
    {
        let mut writer = factory.write_mapping(&self.crystal_instances).expect("could not get a writable mapping to the crystal buffer");

        let mut count = 0;
        for (i, crystal) in crystals.iter().enumerate() {
            let modelmats = crystal.modelmats();
            writer[4 * i] = modelmats[0].into();
            writer[4 * i + 1] = modelmats[1].into();
            writer[4 * i + 2] = modelmats[2].into();
            writer[4 * i + 3] = modelmats[3].into();
            count += 4;
        }

        self.crystal_slice.instances = Some((count, 0));
    }

    pub fn draw_crystals<C>(&self, context: &mut EncoderContext<R, C>)
        where C: gfx::CommandBuffer<R>,
    {
        let color = Color {
            color: [0.6, 1., 0.7],
        };
        context.encoder.update_constant_buffer(&self.color, &color);

        context.encoder.draw(&self.crystal_slice, &self.crystal_pso, &self.crystal_data);
    }
}
