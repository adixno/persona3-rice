// p3-skills animated backdrop (copy of p3-equip/backdrop.frag; wipe unused).
//   water (mask R): gentle ripple + drifting caustic light
//   character (mask G): slow breathing bob/sway, pivoting at the bottom edge
//   wipe: the "slot selected" art (srcB) sweeps in behind a 45-degree front parallel to the
//   diamond's own edges (x + y = const), with a thin cyan leading edge
// The mask (equip-mask.png) comes from tools/make-mask.py, so the EQUIP lettering and the
// white diamond stay perfectly still. Compile after editing:
//   /usr/lib/qt6/bin/qsb --qt6 -o backdrop.frag.qsb backdrop.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;    // seconds
    float aspect;  // width / height
    float wipe;    // 0 = plain art, 1 = selected-state art
};

layout(binding = 1) uniform sampler2D src;
layout(binding = 2) uniform sampler2D mask;
layout(binding = 3) uniform sampler2D srcB;

const float TAU = 6.2831853;

// cheap layered caustic pattern, 0..1, bright thin lines
float caustic(vec2 p, float t) {
    vec2 q = p;
    float v = 0.0;
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        q += vec2(sin(q.y * 1.3 + t * 0.55 + fi * 1.7), cos(q.x * 1.1 - t * 0.45 + fi * 2.3)) * 0.55;
        v += abs(sin(q.x + q.y * 0.6 + fi));
    }
    v /= 3.0;
    return pow(1.0 - v, 4.5);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 m = texture(mask, uv);
    float water = m.r;
    float chr = m.g;

    // breathing: tiny scale about a pivot at the bottom of the character, plus a slow sway
    float breath = sin(time * TAU / 4.8);
    vec2 pivot = vec2(0.80, 1.0);
    uv = pivot + (uv - pivot) * (1.0 - chr * 0.0065 * breath);
    uv.x += chr * 0.0018 * sin(time * TAU / 7.3 + 1.1);

    // water ripple
    vec2 w = vec2(sin(uv.y * 46.0 + time * 1.35) + 0.6 * sin(uv.x * 23.0 - time * 0.9),
                  cos(uv.x * 34.0 + time * 1.1) + 0.6 * sin(uv.y * 19.0 + time * 0.7));
    uv += w * 0.0017 * water;

    vec4 c = texture(src, uv);

    // selected-state sweep, measured on the unwarped frame so the front stays crisp
    vec2 p0 = qt_TexCoord0;
    float dd = (p0.x * aspect + p0.y) / (aspect + 1.0);      // 0 top-left .. 1 bottom-right
    float front = wipe * 1.08 - 0.04;
    float aa = max(fwidth(dd), 1e-4);
    float rev = clamp((front - dd) / aa + 0.5, 0.0, 1.0);
    if (rev > 0.0)
        c = mix(c, texture(srcB, uv), rev);
    float edge = (wipe > 0.0 && wipe < 1.0) ? clamp(1.0 - abs(dd - front - 0.0025) / 0.0022, 0.0, 1.0) : 0.0;
    c.rgb = mix(c.rgb, vec3(0.37, 0.89, 1.0), edge);

    // caustic light sliding through the water
    vec2 cp = vec2(uv.x * aspect, uv.y) * 7.0;
    float k = caustic(cp + vec2(time * 0.12, -time * 0.05), time);
    c.rgb += water * k * 0.34 * vec3(0.75, 1.0, 1.0);

    fragColor = vec4(min(c.rgb, vec3(1.0)), 1.0) * qt_Opacity;
}
