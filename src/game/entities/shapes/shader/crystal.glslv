#version 150

uniform Screen {
    mat4 screenmat;
};

attribute vec4 modelmat_col0;
attribute vec4 modelmat_col1;
attribute vec4 modelmat_col2;
attribute vec4 modelmat_col3;

attribute vec2 pos;

void main() {
    mat4 modelmat = mat4(modelmat_col0, modelmat_col1, modelmat_col2, modelmat_col3);
    gl_Position = screenmat * modelmat * vec4(pos, 0., 1.);
}
