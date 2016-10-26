// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

extern crate abagames_util;
pub use self::abagames_util::EncoderContext;

extern crate cgmath;
use self::cgmath::{Matrix4, Point3, Vector3};

extern crate gfx;
use self::gfx::traits::FactoryExt;

gfx_defines! {
    constant PerspectiveScreen {
        projmat: [[f32; 4]; 4] = "projmat",
    }

    constant OrthographicScreen {
        orthomat: [[f32; 4]; 4] = "orthomat",
    }

    constant Brightness {
        brightness: f32 = "brightness",
    }
}

pub struct RenderContext<R>
    where R: gfx::Resources,
{
    brightness: f32,

    pub perspective_screen_buffer: gfx::handle::Buffer<R, PerspectiveScreen>,
    pub orthographic_screen_buffer: gfx::handle::Buffer<R, OrthographicScreen>,
    pub brightness_buffer: gfx::handle::Buffer<R, Brightness>,
}

impl<R> RenderContext<R>
    where R: gfx::Resources,
{
    pub fn new<F>(factory: &mut F, brightness: f32) -> Self
        where F: gfx::Factory<R>,
    {
        RenderContext {
            brightness: brightness,

            perspective_screen_buffer: factory.create_constant_buffer(1),
            orthographic_screen_buffer: factory.create_constant_buffer(1),
            brightness_buffer: factory.create_constant_buffer(1),
        }
    }

    pub fn update<C>(&self, context: &mut EncoderContext<R, C>)
        where C: gfx::CommandBuffer<R>,
    {
        let eye = Point3::new(0., 0., 13.);
        let center = Point3::new(0., 0., 0.);
        let up = Vector3::unit_y();

        let perspective_screen = PerspectiveScreen {
            projmat: (context.perspective_matrix * Matrix4::look_at(eye, center, up)).into(),
        };
        context.encoder.update_constant_buffer(&self.perspective_screen_buffer, &perspective_screen);

        let orthographic_screen = OrthographicScreen {
            orthomat: context.orthographic_matrix.clone().into(),
        };
        context.encoder.update_constant_buffer(&self.orthographic_screen_buffer, &orthographic_screen);

        let brightness = Brightness {
            brightness: self.brightness,
        };
        context.encoder.update_constant_buffer(&self.brightness_buffer, &brightness);
    }
}
