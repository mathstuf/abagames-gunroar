#version 150

uniform Screen {
    mat4 projmat;
};

attribute vec3 pos;
attribute float diff_factor;
attribute vec2 offset;
attribute vec3 color;

attribute vec2 diff;

varying vec3 f_color;

void main() {
    gl_Position = projmat * vec4(pos + vec3(diff_factor * diff + offset, 0.), 1.);
    f_color = color;
}
