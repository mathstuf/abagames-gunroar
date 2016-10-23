#version 150

uniform Screen {
    mat4 projmat;
};

attribute float flip;

attribute vec2 pos;

void main() {
    gl_Position = projmat * (vec4(pos.x * flip, pos.y, 0., 1.));
}
