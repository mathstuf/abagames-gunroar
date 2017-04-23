#version 150

uniform Brightness {
    float brightness;
};

uniform Color {
    vec3 color;
};

void main() {
    gl_FragColor = vec4(color * vec3(brightness), 1.);
}
