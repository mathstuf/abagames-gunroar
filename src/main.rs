// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

#[macro_use]
extern crate clap;

#[macro_use]
extern crate error_chain;

#[macro_use]
extern crate gfx;

#[macro_use]
extern crate lazy_static;

mod crates {
    pub extern crate abagames_util;
    pub extern crate cgmath;
    pub extern crate clap;
    pub extern crate gfx;
    pub extern crate image;
    pub extern crate itertools;
    pub extern crate log;
    pub extern crate sdl2;
}

use crates::abagames_util::SdlBuilder;
use crates::clap::{App, Arg};
use crates::log::{Log, LogLevel, LogLevelFilter, LogMetadata, LogRecord, set_logger};

mod game;
use game::Gunroar;

use std::error::Error;

fn setup_logging() {
    struct SimpleLogger;

    impl Log for SimpleLogger {
        fn enabled(&self, metadata: &LogMetadata) -> bool {
            metadata.level() <= LogLevel::Debug
        }

        fn log(&self, record: &LogRecord) {
            if self.enabled(record.metadata()) {
                println!("[{}] {}", record.level(), record.args());
            }
        }
    }

    // Since the tests run in parallel, this may get called multiple times. Just ignore errors.
    let _ = set_logger(|max_level| {
        max_level.set(LogLevelFilter::Debug);
        Box::new(SimpleLogger)
    });
}

fn try_main() -> Result<(), Box<Error>> {
    let matches = App::new("gunroar")
        .version(crate_version!())
        .about("360-degree gunboat shooter")
        .author("Ben Boeckel <mathstuf@gmail.com>")
        .arg(Arg::with_name("BRIGHTNESS")
            .short("b")
            .long("brightness")
            .help("Set the brightness of the screen")
            .takes_value(true))
        .arg(Arg::with_name("LUMINOSITY")
            .short("l")
            .long("luminosity")
            .help("Set the luminosity of the screen")
            .takes_value(true))
        .arg(Arg::with_name("RESOLUTION")
            .short("r")
            .long("resolution")
            .help("Set the resolution of the screen")
            .takes_value(true))
        .arg(Arg::with_name("NO_SOUND")
            .long("no-sound")
            .help("Disable spund"))
        .arg(Arg::with_name("WINDOWED")
            .short("w")
            .long("windowed")
            .help("Use a window rather than fullscreen"))
        .arg(Arg::with_name("EXCHANGE_KEYS")
            .short("e")
            .long("exchange-keys")
            .help("Exchange the gun and lance keys"))
        .arg(Arg::with_name("TURN_SPEED")
            .short("t")
            .long("turn-speed")
            .help("Turning speed")
            .takes_value(true))
        .arg(Arg::with_name("FIRE_REAR")
            .short("f")
            .long("fire-rear")
            .help("Fire from the rear of the ship"))
        .get_matches();

    setup_logging();

    let brightness = matches.value_of("BRIGHTNESS")
        .map_or(100., |s| s.parse().expect("could not parse brightness as an integer"));

    let mut builder = try!(SdlBuilder::new("gunroar", env!("CARGO_MANIFEST_DIR")));
    let (mut info, mainloop) = try!(builder
        .with_audio(!matches.is_present("NO_SOUND"))
        //.windowed_mode(matches.is_present("WINDOWED"))
        .windowed_mode(true)
        .build());
    let game = try!(Gunroar::new(&mut info, brightness / 100.));
    try!(mainloop.run(game));

    Ok(())
}

fn main() {
    try_main().expect("an error occurred during the game")
}
