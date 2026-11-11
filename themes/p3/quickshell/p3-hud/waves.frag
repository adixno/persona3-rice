// p3-hud wave bands: two lighter bands flowing across the corner calendar, clipped to the
// panel's diagonal bottom edge and faded in from its hazy left end. Drawn on the GPU so the
// animation only costs a uniform update per frame. Compile after editing:
//   /usr/lib/qt6/bin/qsb --qt6 -o waves.frag.qsb waves.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;   // 0 .. 2pi, loops
    float leftY;   // panel bottom edge height at x = 0 (rises to size.y at the right)
    vec2 size;     // item size in logical px
};

const float TAU = 6.2831853;

// coverage of one band at p (antialiased over aa px)
float band(vec2 p, float aa, float y0, float thick, float amp, float len, float off) {
    float top = y0 + amp * sin(p.x / len * TAU + off + phase);
    float bot = top + thick + amp * 0.6 * sin(p.x / (len * 0.7) + off + phase);
    return clamp((p.y - top) / aa + 0.5, 0.0, 1.0) * clamp((bot - p.y) / aa + 0.5, 0.0, 1.0);
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    float aa = max(fwidth(p.y), 0.35);

    float edge = leftY + (size.y - leftY) * p.x / size.x;
    float inside = clamp((edge - p.y) / aa + 0.5, 0.0, 1.0);
    float haze = smoothstep(0.0, 0.22, p.x / size.x);

    float a1 = band(p, aa, size.y * 0.30, 18.0, 7.0, 150.0, 0.6) * 0.55;
    float a2 = band(p, aa, size.y * 0.44, 12.0, 6.0, 120.0, 2.1) * 0.35;
    vec3 c1 = vec3(0.227, 0.553, 1.0);   // #3a8dff
    vec3 c2 = vec3(0.373, 0.706, 1.0);   // #5fb4ff

    // band 2 over band 1, premultiplied
    vec4 col = vec4(c1 * a1, a1);
    col = vec4(c2 * a2, a2) + col * (1.0 - a2);
    fragColor = col * inside * haze * qt_Opacity;
}
