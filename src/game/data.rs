// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying LICENSE file for details.

macro_rules! music {
    ( $name:expr ) => {
        (
            $name,
            include_bytes!(concat!("sounds/musics/", $name, ".ogg")),
        )
    };
}

macro_rules! sfx {
    ( $name:expr, $channel:expr ) => {
        (
            $name,
            include_bytes!(concat!("sounds/chunks/", $name, ".wav")),
        )
    };
}

lazy_static! {
    pub static ref MUSIC_DATA: Vec<(&'static str, &'static [u8])> = vec![
        music!("gr0"),
        music!("gr1"),
        music!("gr2"),
        music!("gr3"),
    ];

    pub static ref SFX_DATA: Vec<(&'static str, &'static [u8])> = vec![
        sfx!("destroyed", 4),
        sfx!("explode", 6),
        sfx!("hit", 2),
        sfx!("lance", 1),
        sfx!("score_up", 6),
        sfx!("ship_destroyed", 7),
        sfx!("ship_shield_lost", 7),
        sfx!("shot", 0),
        sfx!("small_destroyed", 5),
        sfx!("turret_destroyed", 3),

        // sfx!("turret_shot", ???),
    ];
}
