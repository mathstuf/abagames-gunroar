#version 150

uniform Brightness {
    float brightness;
};

in vec3 f_color;
in vec4 f_color_factor;

out vec4 Target0;

void main() {
    Target0 = vec4(f_color * brightness, 1) * f_color_factor;
}
