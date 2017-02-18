#version 150

uniform Screen {
    mat4 screenmat;
};

uniform ModelTransform {
    mat4 modelmat;
};

attribute vec2 pos;
attribute vec2 tex;

varying vec2 f_tc;

void main() {
    gl_Position = screenmat * modelmat * vec4(pos, 0., 1.);
    f_tc = tex;
}
