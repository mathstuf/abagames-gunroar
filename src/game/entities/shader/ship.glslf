#version 150

uniform Brightness {
    float brightness;
};

in vec4 f_color;

out vec4 Target0;

void main() {
    Target0 = f_color * vec4(vec3(brightness), 1.);
}
