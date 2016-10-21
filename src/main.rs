// Distributed under the OSI-approved BSD 2-Clause License.
// See accompanying file LICENSE for details.

extern crate clap;
use clap::{App, Arg};

extern crate log;
use self::log::{Log, LogLevel, LogLevelFilter, LogMetadata, LogRecord, set_logger};

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
    let matches = App::with_defaults("gunroar")
        .about("360-degree gunboat shooter")
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

    Ok(())
}

fn main() {
    try_main().unwrap()
}
