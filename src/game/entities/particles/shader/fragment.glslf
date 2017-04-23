#version 150

uniform Brightness {
    float brightness;
};

uniform Alpha {
    float alpha;
};

out vec4 Target0;

void main() {
    Target0 = vec4(vec3(0.7, 0.5, 0.5) * brightness, alpha);
}
