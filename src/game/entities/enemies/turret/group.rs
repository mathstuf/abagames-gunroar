// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

use crates::cgmath::Vector2;

use game::entities::enemies::turret::TurretSpec;

use std::f32;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TurretGroupAlignment {
    Round,
    Straight,
}

#[derive(Debug, Clone, Copy)]
pub struct TurretGroupSpec {
    spec: TurretSpec,
    num: u32,
    alignment: TurretGroupAlignment,
    align_degrees: f32,
    align_width: f32,
    radius: f32,
    distance_ratio: f32,
    offset: Vector2<f32>,
}

#[derive(Debug, Clone, Copy)]
pub struct TurretGroupSpecBuilder {
    spec: TurretGroupSpec,
}

impl TurretGroupSpecBuilder {
    pub fn with_spec(spec: TurretSpec) -> Self {
        TurretGroupSpecBuilder {
            spec: TurretGroupSpec {
                spec: spec,
                offset: (0., 0.).into(),
                num: 1,
                alignment: TurretGroupAlignment::Round,
                align_width: 0.,
                align_degrees: 0.,
                radius: 0.,
                distance_ratio: 0.,
            },
        }
    }

    pub fn with_num(&mut self, num: u32) -> &mut Self {
        self.spec.num = num;
        self
    }

    pub fn with_alignment(&mut self, alignment: TurretGroupAlignment) -> &mut Self {
        self.spec.alignment = alignment;
        self
    }

    pub fn with_sized_alignment(&mut self, degrees: f32, width: f32) -> &mut Self {
        self.spec.align_degrees = degrees;
        self.spec.align_width = width;
        self
    }

    pub fn with_radius(&mut self, radius: f32) -> &mut Self {
        self.spec.radius = radius;
        self
    }

    pub fn with_distance_ratio(&mut self, ratio: f32) -> &mut Self {
        self.spec.distance_ratio = ratio;
        self
    }

    pub fn for_boss(&mut self) -> &mut Self {
        self.spec.spec = self.spec.spec.into_boss();
        self
    }

    pub fn with_y_offset(&mut self, offset: f32) -> &mut Self {
        self.spec.offset.y = offset;
        self
    }
}

impl Default for TurretGroupSpecBuilder {
    fn default() -> Self {
        TurretGroupSpecBuilder {
            spec: TurretGroupSpec {
                spec: TurretSpec::default(),
                offset: (0., 0.).into(),
                num: 1,
                alignment: TurretGroupAlignment::Round,
                align_width: 0.,
                align_degrees: 0.,
                radius: 0.,
                distance_ratio: 0.,
            },
        }
    }
}

impl From<TurretGroupSpecBuilder> for TurretGroupSpec {
    fn from(builder: TurretGroupSpecBuilder) -> Self {
        builder.spec
    }
}
