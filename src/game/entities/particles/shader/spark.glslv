#version 150

uniform Screen {
    mat4 screenmat;
};

struct Spark {
    vec2 pos;
    vec2 vel;
    vec3 color;
    // This is required to make the alignment in the shader match Rust's
    // alignment calculations.
    float _dummy;
};
uniform Sparks {
    Spark sparks[NUM_SPARKS];
};

attribute vec2 vel_factor;
attribute int vel_flip;
attribute vec4 color_factor;

varying vec3 f_color;
varying vec4 f_color_factor;

void main() {
    Spark spark = sparks[gl_InstanceID];
    vec2 rvel = (vel_flip > 0) ? spark.vel.yx : spark.vel.xy;
    gl_Position = screenmat * vec4(spark.pos + vel_factor * rvel, 0., 1.);
    f_color = spark.color;
    f_color_factor = color_factor;
}
