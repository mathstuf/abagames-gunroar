#version 150

uniform Screen {
    mat4 screenmat;
};

uniform Rotation {
    mat4 rotmat;
};

attribute float pos;
attribute vec4 color;

varying vec4 f_color;

void main() {
    gl_Position = screenmat * rotmat * vec4(pos, 0., 0., 1.);
    f_color = color;
}
