// p3-links living backdrop: the cloth sways and the water ripples, the card never moves.
//   mask R = water, G = cloth sway weight (0 attached .. 1 free end), B = card (frozen)
// The mask is in frame-00 space; the frames are drawn zoomed by `zoom` about the centre.
// Compile: /usr/lib/qt6/bin/qsb --qt6 -o living.frag.qsb living.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float aspect;
    float zoom;
};

layout(binding = 1) uniform sampler2D src;
layout(binding = 2) uniform sampler2D mask;

vec4 maskAt(vec2 uv) { return texture(mask, vec2(0.5) + (uv - vec2(0.5)) / zoom); }

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 m = maskAt(uv);
    float cloth = m.g * (1.0 - m.b);

    // cloth: a wave travelling down the fabric (sideways sway + a little lift), with a
    // slower gust underneath so it never looks mechanical
    float gust = 0.65 + 0.35 * sin(time * 0.37);
    float wave = sin(uv.y * 15.0 - time * 1.9) * 0.7 + sin(uv.y * 31.0 - time * 3.1 + 1.3) * 0.3;
    vec2 d = vec2(wave * 0.0062, cos(uv.y * 11.0 - time * 1.4) * 0.0022) * cloth * gust;

    // water: small ripple
    float water = m.r * (1.0 - m.b);
    d += vec2(sin(uv.y * 46.0 + time * 1.35) + 0.6 * sin(uv.x * 23.0 - time * 0.9),
              cos(uv.x * 34.0 + time * 1.1)) * 0.0014 * water;

    vec4 c = texture(src, uv + d);

    // caustic glints in the water
    vec2 q = vec2(uv.x * aspect, uv.y) * 7.0 + vec2(time * 0.12, -time * 0.05);
    float v = 0.0;
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        q += vec2(sin(q.y * 1.3 + time * 0.55 + fi * 1.7), cos(q.x * 1.1 - time * 0.45 + fi * 2.3)) * 0.55;
        v += abs(sin(q.x + q.y * 0.6 + fi));
    }
    c.rgb += water * pow(1.0 - v / 3.0, 4.5) * 0.3 * vec3(0.75, 1.0, 1.0);

    fragColor = vec4(min(c.rgb, vec3(1.0)), 1.0) * qt_Opacity;
}
