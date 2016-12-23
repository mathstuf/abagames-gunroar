#version 150

uniform Screen {
    mat4 orthomat;
};

uniform ModelTransform {
    mat4 modelmat;
};

attribute vec2 pos;
attribute vec3 color;

varying vec3 f_color;

void main() {
    gl_Position = orthomat * modelmat * vec4(pos, 0., 1.);
    f_color = color;
}
