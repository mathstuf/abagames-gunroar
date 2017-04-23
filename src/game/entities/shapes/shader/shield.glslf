#version 150

uniform Brightness {
    float brightness;
};

varying vec3 f_color;

void main() {
    gl_FragColor = vec4(f_color * vec3(brightness), 1.);
}
