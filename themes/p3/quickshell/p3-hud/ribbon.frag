// p3-hud ghost word + waves, composited together so the waves can INVERT the word, as in P3R:
//   above the waves      letters solid navy, gaps clear (wallpaper)
//   light wave band      gaps medium blue, letters a darker blue
//   main wave band       gaps vivid blue, letters LIGHTER azure (gradient light → mid)
//   bottom fade          periwinkle fading to clear, letters a shade darker
// Colours measured from a P3R screenshot. `word` is the ghost word rendered offscreen (alpha).
// Compile after editing: /usr/lib/qt6/bin/qsb --qt6 -o ribbon.frag.qsb ribbon.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;   // 0 .. 2pi, loops
    vec2 size;     // item size in logical px
    float dark;    // 0 normal … 1 Dark Hour (every colour blends to its green twin)
};
layout(binding = 1) uniform sampler2D word;

const float TAU = 6.2831853;
vec3 hex(float r, float g, float b) { return vec3(r, g, b) / 255.0; }

void main() {
    vec2 p = qt_TexCoord0 * size;
    float aa = max(fwidth(p.y), 1.4);   // soft edges
    float h = 118.0;          // layout height; the window is taller so the fade can run below it
    float L = texture(word, qt_TexCoord0).a;           // inside a letter

    // wave edges (top of the light band, top of the main band, bottom of the main band)
    float e1 = h * 0.11 + 3.0 * sin(p.x / 320.0 * TAU + phase);
    float e2 = h * 0.34 + 3.0 * sin(p.x / 280.0 * TAU + phase + 2.4);
    float e3 = h * 0.76 + 2.0 * sin(p.x / 300.0 * TAU + phase + 0.7);
    float below1 = clamp((p.y - e1) / aa + 0.5, 0.0, 1.0);
    float below2 = clamp((p.y - e2) / aa + 0.5, 0.0, 1.0);
    float below3 = smoothstep(e3 - 4.0, e3 + 8.0, p.y);

    // zone colours: (gap, letter) premultiplied-ready with alpha
    // normal palette (P3R blue) and its Dark Hour twin (P3R green), mixed by `dark`
    vec4 navy = vec4(mix(hex(23, 33, 102), hex(27, 76, 42), dark), 1.0);
    vec4 lightGap = vec4(mix(hex(31, 95, 214), hex(30, 139, 41), dark), 0.92);
    vec4 lightLet = vec4(mix(hex(20, 56, 202), hex(26, 102, 39), dark), 0.96);
    vec4 mainGap = vec4(mix(hex(5, 47, 229), hex(29, 135, 30), dark), 1.0);
    float t = clamp((p.y - e2) / max(1.0, e3 - e2), 0.0, 1.0);
    vec4 mainLet = vec4(mix(mix(hex(1, 166, 225), hex(0, 96, 230), t), mix(hex(77, 233, 38), hex(42, 164, 24), t), dark), 1.0);
    float f = clamp((p.y - e3) / max(1.0, size.y - 2.0 - e3), 0.0, 1.0);
    // stays saturated blue and fades out by transparency only: pale tints over a dark
    // wallpaper read as grey, so no lavender/white in the tail
    vec3 g = mix(mix(hex(30, 70, 225), hex(55, 110, 245), f), mix(hex(35, 117, 48), hex(31, 75, 60), f), dark);
    float ga = 0.85 * pow(1.0 - f, 1.6);
    vec4 fadeGap = vec4(g, ga);
    vec4 fadeLet = vec4(g * 0.86, ga);                     // letters a shade darker

    vec4 top = mix(vec4(0.0), navy, L);                // above the waves
    vec4 z1 = mix(lightGap, lightLet, L);
    vec4 z2 = mix(mainGap, mainLet, L);
    vec4 z3 = mix(fadeGap, fadeLet, L);
    vec4 c = mix(top, z1, below1);
    c = mix(c, z2, below2);
    c = mix(c, z3, below3);
    float crest = exp(-pow((p.y - e2 - 1.5) / 1.6, 2.0)) * dark;
    c = mix(c, vec4(hex(85, 252, 38), 1.0), crest * 0.85);

    // the whole thing fades in from the left (the word and waves run off screen-left in P3R)
    c.a *= smoothstep(0.0, 0.16, p.x / size.x);
    fragColor = vec4(c.rgb * c.a, c.a) * qt_Opacity;
}
