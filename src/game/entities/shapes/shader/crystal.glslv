#version 150

uniform Screen {
    mat4 screenmat;
};

attribute vec4 shapemat_col0;
attribute vec4 shapemat_col1;
attribute vec4 shapemat_col2;
attribute vec4 shapemat_col3;

attribute vec2 pos;

void main() {
    mat4 shapemat = mat4(shapemat_col0, shapemat_col1, shapemat_col2, shapemat_col3);
    gl_Position = screenmat * shapemat * vec4(pos, 0., 1.);
}
