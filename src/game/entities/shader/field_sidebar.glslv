#version 150

uniform Screen {
    mat4 screenmat;
};

attribute float flip;

attribute vec2 pos;

void main() {
    gl_Position = screenmat * (vec4(pos.x * flip, pos.y, 0., 1.));
}
