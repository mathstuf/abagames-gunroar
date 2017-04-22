// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

use game::entities::enemies::turret::TurretSpec;

use std::f32;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TurretMovement {
    Roll,
    SwingFix,
    SwingAim,
}

#[derive(Debug, Clone, Copy)]
pub struct MovingTurretGroupSpec {
    spec: TurretSpec,
    num: u32,
    align_degrees: f32,
    align_amplitude: f32,
    align_amplitude_velocity: f32,
    radius_base: f32,
    radius_amplitude: f32,
    radius_amplitude_velocity: f32,
    kind: TurretMovement,
    roll_degrees_velocity: f32,
    roll_amplitude: f32,
    roll_amplitude_velocity: f32,
    swing_degrees_velocity: f32,
    swing_amplitude_velocity: f32,
    distance_ratio: f32,
    x_reverse: f32,
}

#[derive(Debug, Clone, Copy)]
pub struct MovingTurretGroupSpecBuilder {
    spec: MovingTurretGroupSpec,
}

impl MovingTurretGroupSpecBuilder {
    pub fn with_align_amplitude(&mut self, amplitude: f32, velocity: f32) -> &mut Self {
        self.spec.align_amplitude = amplitude;
        self.spec.align_amplitude_velocity = velocity;
        self
    }

    pub fn with_radius_amplitude(&mut self, amplitude: f32, velocity: f32) -> &mut Self {
        self.spec.radius_amplitude = amplitude;
        self.spec.radius_amplitude_velocity = velocity;
        self
    }

    pub fn with_reverse_x(&mut self) -> &mut Self {
        self.spec.x_reverse = -1.;
        self
    }

    pub fn as_roll(mut self, degrees_velocity: f32, amplitude: f32, velocity: f32) -> MovingTurretGroupSpec {
        self.spec.kind = TurretMovement::Roll;
        self.spec.roll_degrees_velocity = degrees_velocity;
        self.spec.roll_amplitude = amplitude;
        self.spec.roll_amplitude_velocity = velocity;
        self.spec
    }

    pub fn as_swing(mut self, degrees_velocity: f32, amplitude: f32, aiming: bool) -> MovingTurretGroupSpec {
        self.spec.kind = if aiming {
            TurretMovement::SwingAim
        } else {
            TurretMovement::SwingFix
        };
        self.spec.swing_degrees_velocity = degrees_velocity;
        self.spec.swing_amplitude_velocity = amplitude;
        self.spec
    }
}

impl Default for MovingTurretGroupSpecBuilder {
    fn default() -> Self {
        MovingTurretGroupSpecBuilder {
            spec: MovingTurretGroupSpec {
                spec: TurretSpec::default(),
                num: 1,
                align_degrees: 2. * f32::consts::PI,
                align_amplitude: 0.,
                align_amplitude_velocity: 0.,
                radius_base: 2.,
                radius_amplitude: 0.,
                radius_amplitude_velocity: 0.,
                kind: TurretMovement::SwingFix,
                roll_degrees_velocity: 0.,
                roll_amplitude: 0.,
                roll_amplitude_velocity: 0.,
                swing_degrees_velocity: 0.,
                swing_amplitude_velocity: 0.,
                distance_ratio: 0.,
                x_reverse: 1.,
            },
        }
    }
}
