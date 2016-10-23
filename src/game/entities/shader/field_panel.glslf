#version 150

uniform Brightness {
    float brightness;
};

in vec3 f_color;

out vec4 Target0;

void main() {
    Target0 = vec4(f_color * brightness, .5);
}
