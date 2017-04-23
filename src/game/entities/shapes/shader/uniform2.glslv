#version 150

uniform Screen {
    mat4 screenmat;
};

uniform ModelMat {
    mat4 modelmat;
};

attribute vec2 pos;

void main() {
    gl_Position = screenmat * modelmat * vec4(pos, 0., 1.);
}
