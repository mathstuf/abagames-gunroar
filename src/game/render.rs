// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

extern crate abagames_util;
use self::abagames_util::EncoderContext;

extern crate cgmath;
use self::cgmath::{Matrix4, Point3};

extern crate gfx;

gfx_defines! {
    constant Screen {
        projmat: [[f32; 4]; 4] = "projmat",
    }

    constant Brightness {
        brightness: f32 = "brightness",
    }
}

pub struct RenderContext<'a: 'b, 'b, R, C: 'a>
    where R: gfx::Resources,
          C: gfx::CommandBuffer<R>,
{
    context: &'b mut EncoderContext<'a, R, C>,
    brightness: f32,
    perspective_matrix: Matrix4<f32>,
    orthographic_matrix: Matrix4<f32>,
}

impl<'a, 'b, R, C> RenderContext<'a, 'b, R, C>
    where R: gfx::Resources,
          C: gfx::CommandBuffer<R>,
{
    pub fn new(context: &'b mut EncoderContext<'a, R, C>, brightness: f32) -> Self {
        let eye = Point3::new(0., 0., 13.);
        let center = Point3::new(0., 0., 0.);
        let up = cgmath::vec3(0., 1., 0.);

        RenderContext {
            perspective_matrix: context.perspective_matrix * Matrix4::look_at(eye, center, up),
            orthographic_matrix: context.orthographic_matrix,
            context: context,
            brightness: brightness,
        }
    }

    pub fn brightness(&self) -> f32 {
        self.brightness
    }

    pub fn perspective_matrix(&self) -> &Matrix4<f32> {
        &self.perspective_matrix
    }

    pub fn orthographic_matrix(&self) -> &Matrix4<f32> {
        &self.orthographic_matrix
    }

    pub fn context(&mut self) -> &mut EncoderContext<'a, R, C> {
        &mut self.context
    }

    pub fn encoder(&mut self) -> &mut gfx::Encoder<R, C> {
        &mut self.context.encoder
    }
}
