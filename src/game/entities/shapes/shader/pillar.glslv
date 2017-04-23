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

uniform Pillar {
    vec2 pos;
};

attribute float angle;

void main() {
    vec4 pos4 = vec4(pos + size_factor * vec2(sin(angle), cos(angle)), z, 1.);
    gl_Position = screenmat * modelmat * pos4;
}
