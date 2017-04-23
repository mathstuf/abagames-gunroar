#version 150

uniform Screen {
    mat4 screenmat;
};

struct Smoke {
    vec4 color;
    vec3 pos;
    float size;
};
uniform Smokes {
    Smoke smokes[NUM_SMOKES];
};

attribute vec2 diff;

varying vec4 f_color;

void main() {
    Smoke smoke = smokes[gl_InstanceID];
    gl_Position = screenmat * vec4(smoke.pos + vec3(smoke.size * diff, 0.), 1.);
    f_color = smoke.color;
}
