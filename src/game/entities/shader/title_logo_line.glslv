#version 150

uniform Screen {
    mat4 orthomat;
};

uniform ModelTransform {
    mat4 modelmat;
};

attribute vec2 pos;

void main() {
    gl_Position = orthomat * modelmat * vec4(pos, 0., 1.);
}
