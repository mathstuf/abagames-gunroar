// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

//! Shape handling
//!
//! The original codebase use a routine which heavily intertwined the code logic with the drawing
//! code. This would require making the drawing routine mutable in here, so instead, all of that
//! logic is abstracted out and done in a setup.
//!
//! This causes the code to be quite tangled, but the logic is also quite tangled.

use crates::abagames_util;
use crates::cgmath::{Angle, Matrix4, Rad, SquareMatrix, Vector2, Vector3};
use crates::gfx::{self, IntoIndexBuffer};
use crates::gfx::traits::FactoryExt;
use crates::itertools::Itertools;

use game::render::{EncoderContext, RenderContext};
use game::render::{Brightness, ScreenTransform};

use std::collections::hash_map::HashMap;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
/// The kinds of shapes used by other entities in the game.
///
/// Other entities are made up of various shapes which are used as their drawing base.
pub enum ShapeKind {
    Ship,
    ShipRoundTail,
    ShipShadow,
    Platform,
    Turret,
    Bridge,
    ShipDamaged,
    ShipDestroyed,
    PlatformDamaged,
    PlatformDestroyed,
    TurretDamaged,
    TurretDestroyed,
}

impl ShapeKind {
    /// Whether the shape indicates a destroyed object or not.
    fn is_destroyed(&self) -> bool {
        match *self {
            ShapeKind::ShipDestroyed | ShapeKind::PlatformDestroyed | ShapeKind::TurretDestroyed => true,
            _ => false,
        }
    }

    /// The loop category of the shape.
    ///
    /// This is used to select the appropriate element index array for the shape.
    fn loop_category(&self) -> LoopCategory {
        match *self {
            ShapeKind::Ship | ShapeKind::ShipDamaged | ShapeKind::ShipDestroyed => LoopCategory::Ship,
            ShapeKind::Turret | ShapeKind::TurretDamaged | ShapeKind::TurretDestroyed => LoopCategory::Turret,
            _ => LoopCategory::Other,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
/// Categories of loops.
///
/// Each of these categories uses different points of the generic loop array.
enum LoopCategory {
    Ship,
    Turret,
    Other,
}

impl LoopCategory {
    /// Whether the category uses the given index or not.
    fn uses_index(&self, i: usize) -> bool {
        !((*self != LoopCategory::Ship && POINT_NUM_Q25 < i && i <= POINT_NUM_Q35) ||
          (*self == LoopCategory::Turret && (i <= POINT_NUM_Q15 || POINT_NUM_Q45 < i)))
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
/// Whether a shape should be closed or not.
enum Closure {
    Open,
    Closed,
}

impl Closure {
    /// The maximum offset used by any closure method.
    fn max_offset() -> usize {
        1
    }

    /// The offset against the base length for the closure method.
    fn offset(&self) -> usize {
        match *self {
            Closure::Open => 0,
            Closure::Closed => 1,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
/// The unique slices generated by the code.
enum SliceKind {
    ShipLoop(Closure),
    TurretLoop(Closure),
    OtherLoop(Closure),
    SquareLoop(Closure),
    Pillar,
}

#[derive(Debug, Clone)]
/// The buffer to use for the loop.
///
/// This is used to set up the buffers for use by the element arrays.
enum SliceBuffer {
    /// Create a new buffer associated with the given category.
    New {
        category: LoopCategory,
        data: Vec<u16>,
    },
    /// Use the same buffer already generated for the same category.
    Share(LoopCategory),
    /// Element indices are not used.
    All,
}

impl SliceKind {
    /// The indicies to use for a given loop category.
    fn loop_index_buffer(category: LoopCategory) -> Vec<u16> {
        let mut indices = (0..POINT_NUM)
            .filter_map(|i| {
                if category.uses_index(i) {
                    Some(i as u16)
                } else {
                    None
                }
            })
            .collect::<Vec<_>>();

        // Closed loops need the first index listed again, so add it to the array.
        {
            let first = indices[0];
            indices.push(first);
        }

        indices
    }

    /// The closure used by the slice.
    fn closure(&self) -> Closure {
        match *self {
            SliceKind::ShipLoop(closure) |
            SliceKind::TurretLoop(closure) |
            SliceKind::OtherLoop(closure) |
            SliceKind::SquareLoop(closure) => closure,
            SliceKind::Pillar => Closure::Open,
        }
    }

    /// The loop category of the slice.
    fn loop_category(&self) -> Option<LoopCategory> {
        match *self {
            SliceKind::ShipLoop(_) => Some(LoopCategory::Ship),
            SliceKind::TurretLoop(_) => Some(LoopCategory::Turret),
            SliceKind::OtherLoop(_) => Some(LoopCategory::Other),
            _ => None,
        }
    }

    /// The buffer to use for a slice.
    fn index_buffer(&self) -> SliceBuffer {
        self.loop_category()
            .map_or(SliceBuffer::All, |category| {
                match self.closure() {
                    Closure::Open => SliceBuffer::Share(category),
                    Closure::Closed => {
                        SliceBuffer::New {
                            category: category,
                            data: Self::loop_index_buffer(category),
                        }
                    },
                }
            })
    }

    /// A cache of slices to use for shapes which are drawn.
    ///
    /// This needs to be done so that the draw method can remain non-mutable. It also allows all
    /// resource allocation to occur at the beginning of the program.
    fn slices<R, F>(factory: &mut F) -> HashMap<SliceKind, gfx::Slice<R>>
        where R: gfx::Resources,
              F: gfx::Factory<R>,
    {
        let mut buffer_cache = HashMap::new();
        // Closed versions must be occur before open versions because they create the index array
        // since they have an additional element in their element arrays. The open versions then
        // use the same buffer, but use one fewer element.
        let slice_kinds = [
            SliceKind::ShipLoop(Closure::Closed),
            SliceKind::ShipLoop(Closure::Open),
            SliceKind::TurretLoop(Closure::Closed),
            SliceKind::TurretLoop(Closure::Open),
            SliceKind::OtherLoop(Closure::Closed),
            SliceKind::OtherLoop(Closure::Open),
            SliceKind::SquareLoop(Closure::Closed),
            SliceKind::SquareLoop(Closure::Open),
            SliceKind::Pillar,
        ];

        slice_kinds.into_iter()
            .map(|&kind| {
                let closure = kind.closure();
                // Get the function to create the slice given the closure.
                let make_slice = match closure {
                    Closure::Closed => abagames_util::slice_for_fan,
                    Closure::Open => abagames_util::slice_for_loop,
                };

                (kind, match kind.index_buffer() {
                    SliceBuffer::New { category, data } => {
                        let len = data.len();
                        // Create a new buffer.
                        let buffer = data.into_index_buffer(factory);

                        // Insert it into the cache. The length also needs to be stored because
                        // index buffers cannot be queried for their length.
                        buffer_cache.insert(category, (len, buffer.clone()));
                        let mut slice = make_slice(factory, len as u32);
                        slice.buffer = buffer;
                        slice
                    },
                    SliceBuffer::Share(category) => {
                        let (len, buffer) = buffer_cache.get(&category)
                            .expect("expected there to be a cached buffer")
                            .clone();

                        // Calculate number of indices to use.
                        let elem_len = len - Closure::max_offset() + closure.offset();
                        let mut slice = make_slice(factory, elem_len as u32);
                        slice.buffer = buffer.clone();
                        slice
                    },
                    SliceBuffer::All => {
                        // Get the number of vertices for the slice.
                        let size = match kind {
                            SliceKind::SquareLoop(closure) => SQUARE_LOOP_SIZE + closure.offset(),
                            SliceKind::Pillar => PILLAR_POINT_NUM,
                            // Loops always use buffers.
                            _ => unreachable!(),
                        };

                        make_slice(factory, size as u32)
                    },
                })
            })
            .collect()
    }
}

#[derive(Debug, Clone, Copy)]
/// Per-draw shape information.
///
/// Each draw command may execute a different kind of drawing command. This enumeration contains
/// the data needed for each command.
enum ShapeCategory {
    Loop {
        category: LoopCategory,
        closure: Closure,
    },
    SquareLoop {
        y_ratio: f32,
        closure: Closure,
    },
    Pillar {
        pos: Vector2<f32>,
    },
}

impl ShapeCategory {
    /// The kind of slice to use for the shape.
    fn slice_kind(&self) -> SliceKind {
        match *self {
            ShapeCategory::Loop { category, closure } => {
                match category {
                    LoopCategory::Ship => SliceKind::ShipLoop(closure),
                    LoopCategory::Turret => SliceKind::TurretLoop(closure),
                    LoopCategory::Other => SliceKind::OtherLoop(closure),
                }
            },
            ShapeCategory::SquareLoop { closure, .. } => {
                SliceKind::SquareLoop(closure)
            },
            ShapeCategory::Pillar { .. } => SliceKind::Pillar,
        }
    }
}

#[derive(Debug, Clone, Copy)]
/// A command for the drawing routines.
struct ShapeCommand {
    /// The shape to draw.
    category: ShapeCategory,
    /// The color to use.
    color: Vector3<f32>,
    /// The size factor for size.
    size_factor: f32,
    /// The distance along the `z`-axis.
    z: f32,
}

impl ShapeCommand {
    fn new() -> Self {
        ShapeCommand {
            category: ShapeCategory::Pillar {
                pos: (0., 0.).into(),
            },
            color: (0., 0., 0.).into(),
            size_factor: 0.,
            z: 0.,
        }
    }
}

/// Generic loop information.
///
/// This is used by the shapes themselves as well as the drawing commands to set up queries for
/// later.
struct LoopData {
    /// The index of the point.
    index: usize,
    /// The position of the point.
    pos: Vector2<f32>,
    /// The angle of the point around the loop.
    angle: Rad<f32>,
}

lazy_static! {
    /// Cached loop point data.
    static ref LOOP_DATA: Vec<LoopData> = LoopData::static_data();
}

impl LoopData {
    fn static_data() -> Vec<Self> {
        (0..POINT_NUM)
            .map(|i| {
                let angle = Rad::full_turn() * (i as f32) / POINT_NUM_F32;
                let sy = if i == POINT_NUM_Q14 || i == POINT_NUM_Q34 {
                    0.
                } else if POINT_NUM_Q14 < i && i < POINT_NUM_Q34 {
                    -1. / (1. + angle.tan().abs())
                } else {
                    1. / (1. + angle.tan().abs())
                };
                let sx = if POINT_NUM_Q12 <= i {
                    if i <= POINT_NUM_Q34 {
                        -sy - 1.
                    } else {
                        sy - 1.
                    }
                } else {
                    if POINT_NUM_Q14 <= i {
                        1. + sy
                    } else {
                        1. - sy
                    }
                };

                LoopData {
                    index: i,
                    angle: angle,
                    pos: (sx, sy).into(),
                }
            })
            .collect()
    }
}

#[derive(Debug, Clone, Copy)]
/// Information available to entities which need sub-location precision.
pub struct ShapePoint {
    pub pos: Vector2<f32>,
    pub angle: Rad<f32>,
}

impl ShapePoint {
    fn new() -> Self {
        ShapePoint {
            pos: (0., 0.).into(),
            angle: Rad(0.),
        }
    }
}

/// The most number of commands any shape will require for drawing.
const MAX_SHAPE_COMMANDS: usize = 14;
/// The number of pillars in a turret.
const NUM_PILLARS: usize = 4;

#[derive(Debug, Clone, Copy)]
/// A generic shape.
pub struct BaseShape {
    kind: ShapeKind,
    distance_ratio: f32,
    spiny_ratio: f32,
    size: f32,
    color: Vector3<f32>,

    pillars: [Vector2<f32>; NUM_PILLARS],
    num_pillars: usize,

    points: [ShapePoint; POINT_NUM],
    num_points: usize,
}

impl BaseShape {
    pub fn new(kind: ShapeKind, size: f32, distance_ratio: f32, spiny_ratio: f32, color: Vector3<f32>) -> Self {
        let mut shape = BaseShape {
            kind: kind,
            distance_ratio: distance_ratio,
            spiny_ratio: spiny_ratio,
            size: size,
            color: color,

            pillars: [(0., 0.).into(); NUM_PILLARS],
            num_pillars: 0,

            points: [ShapePoint::new(); POINT_NUM],
            num_points: 0,
        };

        if shape.kind != ShapeKind::Bridge {
            let category = shape.kind.loop_category();
            LOOP_DATA.iter()
                .foreach(|data| {
                    let i = data.index;
                    if !category.uses_index(data.index) {
                        return;
                    }

                    let distance_factor = 1. - shape.distance_ratio;
                    let (sin, cos) = data.angle.sin_cos();
                    let rotate = Vector2::new(sin * distance_factor, cos);
                    let base_pos = Vector2::new(data.pos.x * distance_factor, data.pos.y);
                    let pos = size * (rotate * (1. - shape.spiny_ratio) + base_pos * shape.spiny_ratio);

                    if i == POINT_NUM_Q18 || i == POINT_NUM_Q38 ||
                       i == POINT_NUM_Q58 || i == POINT_NUM_Q78 {
                        shape.pillars[shape.num_pillars] = pos * 0.8;
                        shape.num_pillars += 1;
                    }
                    shape.points[shape.num_points] = ShapePoint {
                        pos: pos,
                        angle: data.angle,
                    };
                    shape.num_points += 1;
                })
        }

        shape
    }

    pub fn points(&self) -> &[ShapePoint] {
        &self.points[0..self.num_points]
    }
}

#[derive(Debug, Clone, Copy)]
/// A generic shape.
pub struct Shape {
    base: &'static BaseShape,
    size: f32,
    color: Vector3<f32>,
    modelmat: Matrix4<f32>,

    commands: [ShapeCommand; MAX_SHAPE_COMMANDS],
    num_commands: usize,
}

impl Shape {
    pub fn new(base: &'static BaseShape) -> Self {
        Shape {
            base: base,
            size: base.size,
            color: base.color,
            modelmat: Matrix4::identity(),

            commands: [ShapeCommand::new(); MAX_SHAPE_COMMANDS],
            num_commands: 0,
        }
    }

    pub fn prep_draw(&mut self) {
        self.num_commands = 0;

        let height = self.size * 0.5;
        let mut z = 0.;
        let mut sf = 1.;

        if self.base.kind == ShapeKind::Bridge {
            z += height;
        }

        let mut color = if self.base.kind == ShapeKind::ShipDestroyed {
            self.color
        } else {
            self.base.color
        };

        if self.base.kind == ShapeKind::Bridge {
            self.add_square_loop(sf, z, color, Closure::Open, 1.)
        } else {
            self.add_loop(sf, z, color, Closure::Open)
        }

        if self.base.kind != ShapeKind::ShipShadow && !self.base.kind.is_destroyed() {
            color = 0.4 * self.base.color;
            self.add_loop(sf, z, color, Closure::Closed)
        }

        match self.base.kind {
            ShapeKind::Ship | ShapeKind::ShipRoundTail | ShapeKind::ShipShadow |
            ShapeKind::ShipDamaged | ShapeKind::ShipDestroyed => {
                if self.base.kind != ShapeKind::ShipDestroyed {
                    color = 0.4 * self.base.color;
                }
                (0..3).foreach(|_| {
                    z -= height / 4.;
                    sf -= 0.2;
                    self.add_loop(sf, z, color, Closure::Open)
                })
            },
            ShapeKind::Platform | ShapeKind::PlatformDamaged | ShapeKind::PlatformDestroyed => {
                color = 0.4 * self.base.color;
                (0..3).foreach(|_| {
                    z -= height / 3.;
                    for pillar in 0..self.base.num_pillars {
                        let pos = self.base.pillars[pillar];
                        self.add_pillar(sf * 0.2, z, color, pos)
                    }
                })
            },
            ShapeKind::Bridge | ShapeKind::Turret | ShapeKind::TurretDamaged => {
                color = 0.6 * self.base.color;
                z += height;
                sf -= 0.33;
                if self.base.kind == ShapeKind::Bridge {
                    self.add_square_loop(sf, z, color, Closure::Open, 1.)
                } else {
                    self.add_square_loop(sf, z / 2., color, Closure::Open, 3.)
                }
                color = 0.6 * self.base.color;
                if self.base.kind == ShapeKind::Bridge {
                    self.add_square_loop(sf, z, color, Closure::Closed, 1.)
                } else {
                    self.add_square_loop(sf, z / 2., color, Closure::Closed, 3.)
                }
            },
            ShapeKind::TurretDestroyed => (),
        }
    }

    fn add_loop(&mut self, size_factor: f32, z: f32, color: Vector3<f32>, closure: Closure) {
        let loop_category = self.base.kind.loop_category();
        self.add_command(ShapeCommand {
            category: ShapeCategory::Loop {
                category: loop_category,
                closure: closure,
            },
            color: color,
            size_factor: size_factor,
            z: z,
        })
    }

    fn add_square_loop(&mut self, size_factor: f32, z: f32, color: Vector3<f32>, closure: Closure, y_ratio: f32) {
        self.add_command(ShapeCommand {
            category: ShapeCategory::SquareLoop {
                y_ratio: y_ratio,
                closure: closure,
            },
            color: color,
            size_factor: size_factor,
            z: z,
        })
    }

    fn add_pillar(&mut self, size_factor: f32, z: f32, color: Vector3<f32>, pos: Vector2<f32>) {
        self.add_command(ShapeCommand {
            category: ShapeCategory::Pillar {
                pos: pos,
            },
            color: color,
            size_factor: size_factor,
            z: z,
        })
    }

    /// Queue a command for drawing.
    fn add_command(&mut self, command: ShapeCommand) {
        self.commands[self.num_commands] = command;
        self.num_commands += 1;
    }
}

const POINT_NUM: usize = 16;
const POINT_NUM_Q18: usize = POINT_NUM / 8;
const POINT_NUM_Q15: usize = POINT_NUM / 5;
const POINT_NUM_Q14: usize = POINT_NUM / 4;
const POINT_NUM_Q38: usize = POINT_NUM * 3 / 8;
const POINT_NUM_Q25: usize = POINT_NUM * 2 / 5;
const POINT_NUM_Q12: usize = POINT_NUM / 2;
const POINT_NUM_Q35: usize = POINT_NUM * 3 / 5;
const POINT_NUM_Q58: usize = POINT_NUM * 5 / 8;
const POINT_NUM_Q34: usize = POINT_NUM * 3 / 4;
const POINT_NUM_Q45: usize = POINT_NUM * 4 / 5;
const POINT_NUM_Q78: usize = POINT_NUM * 7 / 8;
const POINT_NUM_F32: f32 = POINT_NUM as f32;

const SQUARE_LOOP_SIZE: usize = 4;
const PILLAR_POINT_NUM: usize = 8;

gfx_defines! {
    constant ModelMat {
        modelmat: [[f32; 4]; 4] = "modelmat",
    }

    constant Size {
        size: f32 = "size",
    }

    constant ShapeData {
        size_factor: f32 = "size_factor",
        z: f32 = "z",
    }

    constant Loop {
        distance_ratio: f32 = "distance_ratio",
        spiny_ratio: f32 = "spiny_ratio",
    }

    constant SquareLoop {
        y_ratio: f32 = "y_ratio",
    }

    constant Pillar {
        pos: [f32; 2] = "pos",
    }

    constant Color {
        color: [f32; 3] = "color",
    }

    vertex VertexAngle {
        angle: f32 = "angle",
    }

    vertex Sweep {
        sweep_pos: [f32; 2] = "sweep_pos",
        angle: f32 = "angle",
    }

    pipeline loop_pipe {
        vbuf: gfx::VertexBuffer<Sweep> = (),
        screen: gfx::ConstantBuffer<ScreenTransform> = "Screen",
        brightness: gfx::ConstantBuffer<Brightness> = "Brightness",
        modelmat: gfx::ConstantBuffer<ModelMat> = "ModelMat",
        loop_: gfx::ConstantBuffer<Loop> = "Loop",
        size: gfx::ConstantBuffer<Size> = "Size",
        shape: gfx::ConstantBuffer<ShapeData> = "Shape",
        color: gfx::ConstantBuffer<Color> = "Color",
        out_color: gfx::BlendTarget<gfx::format::Srgba8> =
            ("Target0",
             gfx::state::MASK_ALL,
             gfx::state::Blend::new(gfx::state::Equation::Add,
                                    gfx::state::Factor::ZeroPlus(gfx::state::BlendValue::SourceAlpha),
                                    gfx::state::Factor::One)),
    }

    pipeline square_loop_pipe {
        vbuf: gfx::VertexBuffer<VertexAngle> = (),
        screen: gfx::ConstantBuffer<ScreenTransform> = "Screen",
        brightness: gfx::ConstantBuffer<Brightness> = "Brightness",
        modelmat: gfx::ConstantBuffer<ModelMat> = "ModelMat",
        size: gfx::ConstantBuffer<Size> = "Size",
        shape: gfx::ConstantBuffer<ShapeData> = "Shape",
        square_loop: gfx::ConstantBuffer<SquareLoop> = "SquareLoop",
        color: gfx::ConstantBuffer<Color> = "Color",
        out_color: gfx::BlendTarget<gfx::format::Srgba8> =
            ("Target0",
             gfx::state::MASK_ALL,
             gfx::state::Blend::new(gfx::state::Equation::Add,
                                    gfx::state::Factor::ZeroPlus(gfx::state::BlendValue::SourceAlpha),
                                    gfx::state::Factor::One)),
    }

    pipeline pillar_pipe {
        vbuf: gfx::VertexBuffer<VertexAngle> = (),
        screen: gfx::ConstantBuffer<ScreenTransform> = "Screen",
        brightness: gfx::ConstantBuffer<Brightness> = "Brightness",
        modelmat: gfx::ConstantBuffer<ModelMat> = "ModelMat",
        size: gfx::ConstantBuffer<Size> = "Size",
        shape: gfx::ConstantBuffer<ShapeData> = "Shape",
        pillar: gfx::ConstantBuffer<Pillar> = "Pillar",
        color: gfx::ConstantBuffer<Color> = "Color",
        out_color: gfx::BlendTarget<gfx::format::Srgba8> =
            ("Target0",
             gfx::state::MASK_ALL,
             gfx::state::Blend::new(gfx::state::Equation::Add,
                                    gfx::state::Factor::ZeroPlus(gfx::state::BlendValue::SourceAlpha),
                                    gfx::state::Factor::One)),
    }
}

pub struct ShapeDraw<R>
    where R: gfx::Resources,
{
    loop_outline_pso: gfx::PipelineState<R, <loop_pipe::Data<R> as gfx::pso::PipelineData<R>>::Meta>,
    loop_fan_pso: gfx::PipelineState<R, <loop_pipe::Data<R> as gfx::pso::PipelineData<R>>::Meta>,

    square_loop_outline_pso: gfx::PipelineState<R, <square_loop_pipe::Data<R> as gfx::pso::PipelineData<R>>::Meta>,
    square_loop_fan_pso: gfx::PipelineState<R, <square_loop_pipe::Data<R> as gfx::pso::PipelineData<R>>::Meta>,

    pillar_pso: gfx::PipelineState<R, <pillar_pipe::Data<R> as gfx::pso::PipelineData<R>>::Meta>,

    slice_map: HashMap<SliceKind, gfx::Slice<R>>,

    modelmat: gfx::handle::Buffer<R, ModelMat>,
    size: gfx::handle::Buffer<R, Size>,
    shape: gfx::handle::Buffer<R, ShapeData>,
    color: gfx::handle::Buffer<R, Color>,

    loop_data: loop_pipe::Data<R>,
    square_loop_data: square_loop_pipe::Data<R>,
    pillar_data: pillar_pipe::Data<R>,
}

impl<R> ShapeDraw<R>
    where R: gfx::Resources,
{
    pub fn new<F>(factory: &mut F, view: gfx::handle::RenderTargetView<R, gfx::format::Srgba8>,
                  context: &RenderContext<R>)
                  -> Self
        where F: gfx::Factory<R>,
    {
        let loop_vertex_data = LOOP_DATA.iter()
            .map(|data| {
                Sweep {
                    angle: data.angle.0,
                    sweep_pos: data.pos.into(),
                }
            })
            .collect::<Vec<_>>();
        let loop_vbuf = factory.create_vertex_buffer(&loop_vertex_data);

        let frag_shader = factory.create_shader_pixel(include_bytes!("shader/uniform3.glslf"))
            .expect("failed to compile the fragment shader for base shapes");
        let loop_shader = factory.create_shader_vertex(include_bytes!("shader/loop.glslv"))
            .expect("failed to compile the loop shader for base shapes");
        let loop_program = factory.create_program(&gfx::ShaderSet::Simple(loop_shader, frag_shader.clone()))
            .expect("failed to link the loop shader");
        let loop_outline_pso = factory.create_pipeline_from_program(
            &loop_program,
            gfx::Primitive::LineStrip,
            gfx::state::Rasterizer {
                front_face: gfx::state::FrontFace::CounterClockwise,
                cull_face: gfx::state::CullFace::Nothing,
                method: gfx::state::RasterMethod::Line(1),
                offset: None,
                samples: None,
            },
            loop_pipe::new())
            .expect("failed to create the outline pipeline for loop");
        let loop_fan_pso = factory.create_pipeline_from_program(
            &loop_program,
            gfx::Primitive::TriangleList,
            gfx::state::Rasterizer::new_fill(),
            loop_pipe::new())
            .expect("failed to create the fan pipeline for loop");

        let square_loop_vertex_data = (0..SQUARE_LOOP_SIZE + 1)
            .map(|i| {
                VertexAngle {
                    angle: (Rad::full_turn() * (i as f32) / 4. + Rad::full_turn() / 8.).0,
                }
            })
            .collect::<Vec<_>>();
        let square_loop_vbuf = factory.create_vertex_buffer(&square_loop_vertex_data);

        let square_loop_shader = factory.create_shader_vertex(include_bytes!("shader/square_loop.glslv"))
            .expect("failed to compile the square loop shader for base shapes");
        let square_loop_program = factory.create_program(&gfx::ShaderSet::Simple(square_loop_shader, frag_shader.clone()))
            .expect("failed to link the square loop shader");
        let square_loop_outline_pso = factory.create_pipeline_from_program(
            &square_loop_program,
            gfx::Primitive::LineStrip,
            gfx::state::Rasterizer {
                front_face: gfx::state::FrontFace::CounterClockwise,
                cull_face: gfx::state::CullFace::Nothing,
                method: gfx::state::RasterMethod::Line(1),
                offset: None,
                samples: None,
            },
            square_loop_pipe::new())
            .expect("failed to create the outline pipeline for square loop");
        let square_loop_fan_pso = factory.create_pipeline_from_program(
            &square_loop_program,
            gfx::Primitive::TriangleList,
            gfx::state::Rasterizer::new_fill(),
            square_loop_pipe::new())
            .expect("failed to create the outline pipeline for square loop");

        let pillar_vertex_data = (0..PILLAR_POINT_NUM)
            .map(|i| {
                VertexAngle {
                    angle: (Rad::full_turn() * (i as f32) / (PILLAR_POINT_NUM as f32)).0,
                }
            })
            .collect::<Vec<_>>();
        let pillar_vbuf = factory.create_vertex_buffer(&pillar_vertex_data);

        let pillar_shader = factory.create_shader_vertex(include_bytes!("shader/pillar.glslv"))
            .expect("failed to compile the pillar shader for base shapes");
        let pillar_program = factory.create_program(&gfx::ShaderSet::Simple(pillar_shader, frag_shader.clone()))
            .expect("failed to link the pillar shader");
        let pillar_pso = factory.create_pipeline_from_program(
            &pillar_program,
            gfx::Primitive::TriangleList,
            gfx::state::Rasterizer::new_fill(),
            pillar_pipe::new())
            .expect("failed to create the outline pipeline for pillar");

        let modelmat = factory.create_constant_buffer(1);
        let size = factory.create_constant_buffer(1);
        let shape = factory.create_constant_buffer(1);
        let color = factory.create_constant_buffer(1);
        let loop_data = loop_pipe::Data {
            vbuf: loop_vbuf,
            screen: context.perspective_screen_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            modelmat: modelmat.clone(),
            size: size.clone(),
            shape: shape.clone(),
            loop_: factory.create_constant_buffer(1),
            color: color.clone(),
            out_color: view.clone(),
        };
        let square_loop_data = square_loop_pipe::Data {
            vbuf: square_loop_vbuf,
            screen: context.perspective_screen_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            modelmat: modelmat.clone(),
            size: size.clone(),
            shape: shape.clone(),
            square_loop: factory.create_constant_buffer(1),
            color: color.clone(),
            out_color: view.clone(),
        };
        let pillar_data = pillar_pipe::Data {
            vbuf: pillar_vbuf,
            screen: context.perspective_screen_buffer.clone(),
            brightness: context.brightness_buffer.clone(),
            modelmat: modelmat.clone(),
            size: size.clone(),
            shape: shape.clone(),
            pillar: factory.create_constant_buffer(1),
            color: color.clone(),
            out_color: view,
        };

        ShapeDraw {
            loop_outline_pso: loop_outline_pso,
            loop_fan_pso: loop_fan_pso,

            square_loop_outline_pso: square_loop_outline_pso,
            square_loop_fan_pso: square_loop_fan_pso,

            pillar_pso: pillar_pso,

            slice_map: SliceKind::slices(factory),

            modelmat: modelmat,
            size: size,
            shape: shape,
            color: color,

            loop_data: loop_data,
            square_loop_data: square_loop_data,
            pillar_data: pillar_data,
        }
    }

    fn draw_command<C>(&self, encoder: &mut gfx::Encoder<R, C>, command: &ShapeCommand)
        where C: gfx::CommandBuffer<R>,
    {
        let color = Color {
            color: command.color.into(),
        };
        let shape = ShapeData {
            size_factor: command.size_factor,
            z: command.z,
        };
        encoder.update_constant_buffer(&self.color, &color);
        encoder.update_constant_buffer(&self.shape, &shape);

        let cmd_category = &command.category;
        let slice = self.slice_map.get(&cmd_category.slice_kind())
            .expect("expected to have a slice for a command");
        match *cmd_category {
            ShapeCategory::Loop { category, closure } => {
                let pso = match closure {
                    Closure::Open => &self.loop_outline_pso,
                    Closure::Closed => &self.loop_fan_pso,
                };
                encoder.draw(slice, pso, &self.loop_data);
            },
            ShapeCategory::SquareLoop { y_ratio, closure } => {
                let square_loop = SquareLoop {
                    y_ratio: y_ratio,
                };
                encoder.update_constant_buffer(&self.square_loop_data.square_loop, &square_loop);

                let pso = match closure {
                    Closure::Open => &self.square_loop_outline_pso,
                    Closure::Closed => &self.square_loop_fan_pso,
                };
                encoder.draw(slice, pso, &self.square_loop_data);
            },
            ShapeCategory::Pillar { pos } => {
                let pillar = Pillar {
                    pos: pos.into(),
                };
                encoder.update_constant_buffer(&self.pillar_data.pillar, &pillar);

                encoder.draw(slice, &self.pillar_pso, &self.pillar_data);
            },
        }
    }

    pub fn draw<C>(&self, context: &mut EncoderContext<R, C>, shape: &Shape)
        where C: gfx::CommandBuffer<R>,
    {
        let modelmat = ModelMat {
            modelmat: shape.modelmat.into(),
        };
        let size = Size {
            size: shape.size,
        };
        let loop_ = Loop {
            distance_ratio: shape.base.distance_ratio,
            spiny_ratio: shape.base.spiny_ratio,
        };
        context.encoder.update_constant_buffer(&self.modelmat, &modelmat);
        context.encoder.update_constant_buffer(&self.size, &size);
        context.encoder.update_constant_buffer(&self.loop_data.loop_, &loop_);

        shape.commands
            .iter()
            .take(shape.num_commands)
            .foreach(|command| self.draw_command(context.encoder, command))
    }
}
