// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying LICENSE file for details.

#[macro_use]
extern crate clap;

#[macro_use]
extern crate failure;

#[macro_use]
extern crate gfx;

#[macro_use]
extern crate lazy_static;

mod crates {
    pub extern crate abagames_util;
    pub extern crate cgmath;
    pub extern crate clap;
    pub extern crate failure;
    pub extern crate gfx;
    pub extern crate image;
    pub extern crate itertools;
    pub extern crate log;
    pub extern crate rayon;
    pub extern crate sdl2;
}

use crates::abagames_util::SdlBuilder;
use crates::clap::{App, Arg};
use crates::failure::Error;
use crates::log::{self, Level, LevelFilter, Log, Metadata, Record};

mod game;
use game::Gunroar;

fn setup_logging() {
    struct SimpleLogger;

    impl Log for SimpleLogger {
        fn enabled(&self, metadata: &Metadata) -> bool {
            metadata.level() <= Level::Debug
        }

        fn log(&self, record: &Record) {
            if self.enabled(record.metadata()) {
                println!("[{}] {}", record.level(), record.args());
            }
        }

        fn flush(&self) {}
    }

    static LOGGER: SimpleLogger = SimpleLogger;

    let _ = log::set_logger(&LOGGER);
    log::set_max_level(LevelFilter::Debug);
}

fn try_main() -> Result<(), Error> {
    let matches = App::new("gunroar")
        .version(crate_version!())
        .about("360-degree gunboat shooter")
        .author("Ben Boeckel <mathstuf@gmail.com>")
        .arg(
            Arg::with_name("BRIGHTNESS")
                .short("b")
                .long("brightness")
                .help("Set the brightness of the screen")
                .takes_value(true),
        )
        .arg(
            Arg::with_name("LUMINOSITY")
                .short("l")
                .long("luminosity")
                .help("Set the luminosity of the screen")
                .takes_value(true),
        )
        .arg(
            Arg::with_name("RESOLUTION")
                .short("r")
                .long("resolution")
                .help("Set the resolution of the screen")
                .takes_value(true),
        )
        .arg(
            Arg::with_name("NO_SOUND")
                .long("no-sound")
                .help("Disable spund"),
        )
        .arg(
            Arg::with_name("WINDOWED")
                .short("w")
                .long("windowed")
                .help("Use a window rather than fullscreen"),
        )
        .arg(
            Arg::with_name("EXCHANGE_KEYS")
                .short("e")
                .long("exchange-keys")
                .help("Exchange the gun and lance keys"),
        )
        .arg(
            Arg::with_name("TURN_SPEED")
                .short("t")
                .long("turn-speed")
                .help("Turning speed")
                .takes_value(true),
        )
        .arg(
            Arg::with_name("FIRE_REAR")
                .short("f")
                .long("fire-rear")
                .help("Fire from the rear of the ship"),
        )
        .get_matches();

    setup_logging();

    let brightness = matches.value_of("BRIGHTNESS").map_or(100., |s| {
        s.parse().expect("could not parse brightness as an integer")
    });

    let mut builder = SdlBuilder::new("gunroar")?;
    let (mut info, mainloop) = builder
        //.windowed_mode(matches.is_present("WINDOWED"))
        .windowed_mode(true)
        .build()?;
    let game = Gunroar::new(
        &mut info,
        brightness / 100.,
        !matches.is_present("NO_SOUND"),
    );
    mainloop.run(game)?;

    Ok(())
}

fn main() {
    try_main().expect("an error occurred during the game")
}
