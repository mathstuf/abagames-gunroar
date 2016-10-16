# Gunroar

360-degree gunboat shooter, Gunroar.

# How to play

Steer a boat and sink the enemy fleet.

You can select a game mode by pressing the up and down keys or a lance key at
the title screen.

## All modes

  - Pause: `P`
  - Quit: `Escape`

### Bonus multiplier

In the upper right of the screen, there is a bonus multiplier that increases
with the difficulty of the game. Moving forward faster will increase the bonus
faster.

### Boss timer

In the upper left of the screen a timer counts down to the arrival of a boss
ship.

## Normal mode

  - Move: Arrow, Numpad, `WASD`, `IJKL`, joystick.
  - Fire: `Z`, `L-Ctrl`, `R-Ctrl`, or `.`. Hold a key to open automatic file
    and hold the direction of the boat. Tap a key to turn while firing.
  - Fire lance: `X`, `L-Alt`, `R-Alt`, `L-Shift`, `R-Shift`, `/`, `Return`,
    Trigger, any joystick button 2, 3, 6, 7, 10, or 11. The lance is a
    single-shot weapon. Only a single lance may be on the screen at a time.

## Twin stick mode

It is strongly recommended to use twin analog sticks for this mode.

  - Move: `WASD`, joystick 1 axes 1 and 2.
  - Fire: `IJKL`, joystick 2 axes 3 and 4.

You can control the concentration of guns by using the analog stick. See the
`--rotate-stick-2` and `--reverse-stick-2` options for assistance. Some
gamepads may need the `--enable-axis-5` option.

## Double play mode

Control two boats at a time.

  - Move: `WASD`, joystick 1 axes 1 and 2.
  - Fire: `IJKL`, joystick 2 axes 3 and 4.

## Mouse mode

Steer with a keyboard or pad and control with a mouse.

  - Move: Arrow, Numpad, `WASD`, `IJKL`, joystick.
  - Sight: Mouse
  - Fire (narrow): Left button
  - Fire (wide): Right button

# Options

The following command line options may be given to modify the game:

  - `--brightness <N>`: Set the brightness of the screen (`0 ≤ N ≤ 100`,
    default `100`)
  - `--luminosity <N>`: Set the luminos intensity (`0 ≤ N ≤ 100`, default `0`)
  - `--resolution <X> <Y>`: Set the screen resolution to `XxY`, default `640
    480`.
  - `--no-sound`: Disable the sound.
  - `--windowed`: Use a window rather than fullscreen.
  - `--exchange-keys`: Exchange the gun and lance keys.
  - `--turn-speed <N>`: Adjust the turning speed (`0 ≤ N ≤ 500`, default
    `100`). `Normal` mode only.
  - `--fire-rear`: Fire from the rear of the ship. `Normal` mode only.
  - `--rotate-stick-2 <N>`: Rotate the direction of joystick 2 by `N` degrees.
    `Twin stick` and `Double play` modes only.
  - `--reverse-stick-2`: Reverse the direction of joystick 2. `Twin stick` and
    `Double play` modes only.
  - `--enable-axis-5`: Use axis 5 instead of axis 3 for joystick 2. `Twin
    stick` and `Double play` modes only.
