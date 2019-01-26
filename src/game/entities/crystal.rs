// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying LICENSE file for details.

use crates::abagames_util::{self, Pool, PoolRemoval};
use crates::cgmath::{Angle, Matrix4, Rad, Vector2};

use game::entities::ship::Ship;

const COUNT: u32 = 60;
const PULLIN_COUNT: u32 = COUNT * 4 / 5;

pub const MAX_CRYSTAL_SIZE: usize = 80;

pub struct Crystal {
    pos: Vector2<f32>,
    vel: Vector2<f32>,
    count: u32,
}

impl Crystal {
    fn new() -> Self {
        Crystal {
            pos: (0., 0.).into(),
            vel: (0., 0.).into(),
            count: 0,
        }
    }

    pub fn new_pool() -> Pool<Self> {
        Pool::new(MAX_CRYSTAL_SIZE, Self::new)
    }

    pub fn init(&mut self, pos: Vector2<f32>) {
        self.pos = pos;
        self.count = COUNT;
        self.vel = (0., 0.1).into();
    }

    pub fn step(&mut self, ship: &Ship) -> PoolRemoval {
        self.count = self.count.saturating_sub(1);
        if self.count < PULLIN_COUNT {
            let dist = f32::max(0.1, abagames_util::fast_distance(self.pos, ship.mid_pos()));
            self.vel += (ship.mid_pos() - self.pos) / dist * 0.07;
            if self.count == 0 || dist < 2. {
                return PoolRemoval::Remove;
            }
        }

        self.vel *= 0.95;
        self.pos += self.vel;

        PoolRemoval::Keep
    }

    pub fn modelmats(&self) -> [Matrix4<f32>; 4] {
        let r = if self.count > PULLIN_COUNT {
            0.25 * (((COUNT - self.count) / (COUNT - PULLIN_COUNT)) as f32)
        } else {
            0.25
        };
        let angle = Rad((self.count as f32) * 0.1);

        [
            Matrix4::from_translation((self.pos + r * Self::sin_cos(angle)).extend(0.)),
            Matrix4::from_translation((self.pos + r * Self::sin_cos(angle + Rad::turn_div_4())).extend(0.)),
            Matrix4::from_translation((self.pos + r * Self::sin_cos(angle + Rad::turn_div_2())).extend(0.)),
            Matrix4::from_translation((self.pos + r * Self::sin_cos(angle - Rad::turn_div_4())).extend(0.)),
        ]
    }

    fn sin_cos(angle: Rad<f32>) -> Vector2<f32> {
        angle.sin_cos().into()
    }
}
