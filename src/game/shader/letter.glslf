#version 150

uniform Brightness {
    float brightness;
};

uniform Color {
    vec4 color;
};

out vec4 Target0;

void main() {
    Target0 = color * vec4(vec3(brightness), 1.);
}
