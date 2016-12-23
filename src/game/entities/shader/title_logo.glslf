#version 150

uniform Brightness {
    float brightness;
};

uniform sampler2D sampler;

in vec2 f_tc;

out vec4 Target0;

void main() {
    Target0 = texture2D(sampler, f_tc) * vec4(vec3(brightness), 1.);
}
