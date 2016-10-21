#version 150

uniform Screen {
    mat4 projmat;
};

uniform LetterTransforms {
    mat4 drawmat;
};

uniform LetterSegments {
    mat4 boxmat;
    vec2 size;
};

attribute vec2 pos;

void main() {
    gl_Position = projmat * drawmat * boxmat * vec4(pos * size, 0., 1.);
}
