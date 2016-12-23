#version 150

uniform Brightness {
    float brightness;
};

out vec4 Target0;

void main() {
    Target0 = vec4(vec3(brightness), 1.);
}
