// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying LICENSE file for details.

pub use abagames_util::EncoderContext;
use cgmath::{Matrix4, Point3, Vector3};
use gfx;
use gfx::traits::FactoryExt;
use gfx::*;

gfx_defines! {
    constant ScreenTransform {
        screenmat: [[f32; 4]; 4] = "screenmat",
    }

    constant Brightness {
        brightness: f32 = "brightness",
    }
}

pub struct RenderContext<R>
where
    R: gfx::Resources,
{
    brightness: f32,

    pub perspective_screen_buffer: gfx::handle::Buffer<R, ScreenTransform>,
    pub orthographic_screen_buffer: gfx::handle::Buffer<R, ScreenTransform>,
    pub brightness_buffer: gfx::handle::Buffer<R, Brightness>,
}

impl<R> RenderContext<R>
where
    R: gfx::Resources,
{
    pub fn new<F>(factory: &mut F, brightness: f32) -> Self
    where
        F: gfx::Factory<R>,
    {
        RenderContext {
            brightness: brightness,

            perspective_screen_buffer: factory.create_constant_buffer(1),
            orthographic_screen_buffer: factory.create_constant_buffer(1),
            brightness_buffer: factory.create_constant_buffer(1),
        }
    }

    pub fn update<C>(&self, context: &mut EncoderContext<R, C>)
    where
        C: gfx::CommandBuffer<R>,
    {
        let eye = Point3::new(0., 0., 13.);
        let center = Point3::new(0., 0., 0.);
        let up = Vector3::unit_y();

        let perspective_screen = ScreenTransform {
            screenmat: (context.perspective_matrix * Matrix4::look_at(eye, center, up)).into(),
        };
        context
            .encoder
            .update_constant_buffer(&self.perspective_screen_buffer, &perspective_screen);

        let orthographic_screen = ScreenTransform {
            screenmat: context.orthographic_matrix.into(),
        };
        context
            .encoder
            .update_constant_buffer(&self.orthographic_screen_buffer, &orthographic_screen);

        let brightness = Brightness {
            brightness: self.brightness,
        };
        context
            .encoder
            .update_constant_buffer(&self.brightness_buffer, &brightness);
    }
}
