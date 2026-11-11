// p3 bar: the corner calendar's two wave bands, continued along the bar. Same shape, colours
// and phase as p3-hud/waves.frag, with x measured from where the calendar starts (calX), so the
// waves run out of the bar straight into the calendar as one. Both drive `phase` from the wall
// clock (9 s cycle) so they stay in step across the two processes. Compile after editing:
//   /usr/lib/qt6/bin/qsb --qt6 -o barwave.frag.qsb barwave.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;   // 0 .. 2pi, loops
    float calX;    // x (bar coords) where the corner calendar's panel starts
    float calH;    // the calendar's height (its wave rows are fractions of it)
    vec2 size;     // item size in logical px
};

const float TAU = 6.2831853;

float band(float x, float y, float aa, float y0, float thick, float amp, float len, float off) {
    float top = y0 + amp * sin(x / len * TAU + off + phase);
    float bot = top + thick + amp * 0.6 * sin(x / (len * 0.7) + off + phase);
    return clamp((y - top) / aa + 0.5, 0.0, 1.0) * clamp((bot - y) / aa + 0.5, 0.0, 1.0);
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    float aa = max(fwidth(p.y), 0.35);
    float x = p.x - calX;                       // the calendar's own x
    float haze = smoothstep(0.0, 0.10, p.x / size.x);

    float a1 = band(x, p.y, aa, calH * 0.30, 18.0, 7.0, 150.0, 0.6) * 0.55;
    float a2 = band(x, p.y, aa, calH * 0.44, 12.0, 6.0, 120.0, 2.1) * 0.35;
    vec3 c1 = vec3(0.227, 0.553, 1.0);   // #3a8dff
    vec3 c2 = vec3(0.373, 0.706, 1.0);   // #5fb4ff

    vec4 col = vec4(c1 * a1, a1);
    col = vec4(c2 * a2, a2) + col * (1.0 - a2);
    fragColor = col * haze * qt_Opacity;
}
