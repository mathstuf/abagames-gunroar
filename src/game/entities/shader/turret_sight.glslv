#version 150

uniform Screen {
    mat4 screenmat;
};

uniform TurretData {
    float min_range;
    float max_range;
    vec2 pos;
};

uniform AlphaFactor {
    float min_alpha;
    float max_alpha;
};

uniform SightAngle {
    float angle;
};

uniform NextAngle {
    float next_angle;
};

attribute float minmax;
attribute float angle_choice;

varying float f_alpha_factor;

void main() {
    float factor = ((minmax > 0.) ? max_range : min_range);
    float use_angle = ((angle_choice > 0.) ? next_angle : angle);
    vec2 rot = factor * vec2(sin(use_angle), cos(use_angle));
    gl_Position = screenmat * vec4(pos + rot, 0., 1.);
    float alpha_factor = ((minmax > 0.) ? max_alpha : min_alpha);
    f_alpha_factor = alpha_factor;
}
