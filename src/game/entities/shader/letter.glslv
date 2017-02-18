#version 150

uniform Screen {
    mat4 screenmat;
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
    gl_Position = screenmat * drawmat * boxmat * vec4(pos * size, 0., 1.);
}
