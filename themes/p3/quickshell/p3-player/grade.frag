// Dark Hour colour grade: remaps a picture's brightness onto P3R's Dark Hour greens (deep
// forest → green → lime → pale mint), keeping a little of the original hue, mixed in by
// `dark` (0 normal … 1 Dark Hour). Used as a layer.effect on backdrops (source = the layer).
// IDENTICAL COPIES in several p3 dirs. Compile: /usr/lib/qt6/bin/qsb --qt6 -o grade.frag.qsb grade.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float dark;
};
layout(binding = 1) uniform sampler2D source;

vec3 ramp(float l) {
    vec3 c0 = vec3(0.016, 0.078, 0.047);   // #04140c
    vec3 c1 = vec3(0.118, 0.545, 0.161);   // #1e8b29
    vec3 c2 = vec3(0.333, 0.988, 0.149);   // #55fc26
    vec3 c3 = vec3(0.86, 1.0, 0.88);
    if (l < 0.42) return mix(c0, c1, l / 0.42);
    if (l < 0.78) return mix(c1, c2, (l - 0.42) / 0.36);
    return mix(c2, c3, (l - 0.78) / 0.22);
}

void main() {
    vec4 s = texture(source, qt_TexCoord0);
    vec3 c = s.a > 0.0 ? s.rgb / s.a : s.rgb;          // un-premultiply
    float l = dot(c, vec3(0.299, 0.587, 0.114));
    vec3 g = mix(ramp(l), c * vec3(0.55, 1.0, 0.6), 0.18);
    c = mix(c, g, dark);
    fragColor = vec4(c * s.a, s.a) * qt_Opacity;
}
