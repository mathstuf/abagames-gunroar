#version 150

uniform Screen {
    mat4 screenmat;
};

struct Wake {
    vec2 pos;
    vec2 vel;
    float size;
    int reverse;
    // This is required to make the alignment in the shader match Rust's
    // alignment calculations.
    vec2 _dummy;
};
uniform Wakes {
    Wake wakes[NUM_WAKES];
};

attribute vec2 vel_factor;
attribute float vel_flip;
attribute vec4 color;

varying vec4 f_color;

void main() {
    Wake wake = wakes[gl_InstanceID];
    vec2 rvel;
    if (vel_flip > 0.) {
        rvel = wake.vel.yx;
    } else if (wake.reverse != 0) {
        rvel = -wake.vel;
    } else {
        rvel = wake.vel;
    }
    gl_Position = screenmat * vec4(wake.pos + (wake.size * vel_factor * rvel), 0., 1.);
    f_color = color;
}
