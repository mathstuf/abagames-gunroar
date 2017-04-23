#version 150

uniform Screen {
    mat4 screenmat;
};

uniform ModelMat {
    mat4 modelmat;
};

uniform Size {
    float size;
};

uniform Shape {
    float size_factor;
    float z;
};

uniform Loop {
    float distance_ratio;
    float spiny_ratio;
};

attribute vec2 sweep_pos;
attribute float angle;

void main() {
    vec2 rot = vec2(sin(angle), cos(angle));
    vec2 fpos = (1. - spiny_ratio) * rot + sweep_pos * spiny_ratio;
    vec2 ratio = vec2(1. - distance_ratio, 1.);
    vec4 pos4 = vec4(fpos * size * size_factor * ratio, z, 1.);
    gl_Position = screenmat * modelmat * pos4;
}
