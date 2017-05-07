#version 150

uniform Screen {
    mat4 screenmat;
};

uniform LineData {
    vec2 pos;
    float angle;
};

attribute float rotation;
attribute vec4 color;

varying vec4 f_color;

void main() {
    vec2 rot = 20. * rotation * vec2(sin(angle), cos(angle));
    gl_Position = screenmat * vec4(pos + rot, 0., 1.);
    f_color = color;
}
