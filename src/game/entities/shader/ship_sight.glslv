#version 150

uniform Screen {
    mat4 screenmat;
};

attribute vec2 pos;
attribute float size;
attribute vec4 color;

attribute vec2 size_factor;

varying vec4 f_color;

void main() {
    gl_Position = screenmat * vec4(pos + size * size_factor, 0., 1.);
    f_color = color;
}
