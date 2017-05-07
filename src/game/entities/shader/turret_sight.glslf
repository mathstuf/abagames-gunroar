#version 150

uniform Brightness {
    float brightness;
};

uniform Alpha {
    float alpha;
};

uniform Color {
    vec3 color;
};

in float f_alpha_factor;

out vec4 Target0;

void main() {
    Target0 = vec4(color * vec3(brightness), alpha * f_alpha_factor);
}
