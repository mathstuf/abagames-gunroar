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

uniform SquareLoop {
    float y_ratio;
};

attribute float angle;

void main() {
    vec2 pos = size * size_factor * vec2(sin(angle), cos(angle));
    if (pos.y > 0.) {
        pos.y *= y_ratio;
    }
    gl_Position = screenmat * modelmat * vec4(pos, z, 1.);
}
