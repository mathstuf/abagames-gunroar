#version 150

uniform Screen {
    mat4 screenmat;
};

struct SparkFragment {
    mat4 modelmat;
    vec4 color;
};
uniform SparkFragments {
    SparkFragment spark_fragments[NUM_SPARK_FRAGMENTS];
};

attribute vec2 pos;

varying vec4 f_color;

void main() {
    SparkFragment spark_fragment = spark_fragments[gl_InstanceID];
    gl_Position = screenmat * spark_fragment.modelmat * vec4(pos, 0., 1.);
    f_color = spark_fragment.color;
}
