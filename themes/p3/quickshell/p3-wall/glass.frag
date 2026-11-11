// p3-wall: liquid glass for the strip behind the top bar. The bar reserves its space, so the
// only thing ever behind it is this wallpaper; p3-wall therefore draws the glass itself, from
// its own picture: the image bends (lenses) toward the bottom edge with a slight colour
// fringe, a very light blur, a saturation lift, a specular sheen over the top, a cyan glow and
// a bright rim along the edge, and a soft shadow cast just below the glass.
// Compile after editing:  /usr/lib/qt6/bin/qsb --qt6 -o glass.frag.qsb glass.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // effect size in logical px (glass + shadow below it)
    float glassH;   // height of the glass strip (the bar's height)
};

layout(binding = 1) uniform sampler2D source;   // the wallpaper under this effect, same size

vec3 tap(vec2 p) {
    return texture(source, clamp(p / size, vec2(0.0), vec2(1.0))).rgb;
}

// light 5-tap blur so the glass reads as glass but stays clear
vec3 soft(vec2 p) {
    const float r = 0.9;
    return (tap(p) * 2.0 + tap(p + vec2(r, 0.0)) + tap(p - vec2(r, 0.0))
            + tap(p + vec2(0.0, r)) + tap(p - vec2(0.0, r))) / 6.0;
}

void main() {
    vec2 p = qt_TexCoord0 * size;

    // below the glass: the wallpaper with a soft shadow fading out
    if (p.y > glassH) {
        float s = 1.0 - clamp((p.y - glassH) / (size.y - glassH), 0.0, 1.0);
        fragColor = vec4(tap(p) * (1.0 - 0.36 * s * s), 1.0) * qt_Opacity;
        return;
    }

    float d = glassH - p.y;                       // distance up from the glass edge
    const float L = 28.0;                         // lens zone above the edge
    float t = clamp(1.0 - d / L, 0.0, 1.0);       // 1 at the edge, 0 above the zone
    float bend = t * t * 22.0;                    // px: pull the picture up near the edge

    // whole strip slightly magnified around its middle, then the edge lens on top
    vec2 c = vec2(size.x * 0.5, glassH * 0.5);
    vec2 q = c + (p - c) * vec2(0.985, 0.86);
    q.y -= bend;

    // colour fringe grows toward the edge
    float ca = bend * 0.18 + 0.4;
    vec3 col;
    col.r = soft(q + vec2(0.0, -ca)).r;
    col.g = soft(q).g;
    col.b = soft(q + vec2(0.0, ca)).b;

    // glass lifts colour, then tames bright areas (clouds, sky) so white text stays readable
    float l = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(l), col, 1.25);
    col *= mix(1.0, 0.72, smoothstep(0.55, 1.0, l));
    col = mix(col, vec3(0.10, 0.22, 0.55), 0.06);   // very light tint: mostly clear glass

    // specular sheen over the upper part, and light caught along the top (screen) edge
    col += vec3(1.0) * smoothstep(glassH * 0.62, 0.0, p.y) * 0.10;
    col = mix(col, vec3(1.0), smoothstep(1.6, 0.0, p.y) * 0.45);

    // two soft diagonal reflection streaks, fading toward the bottom
    float u = p.x + p.y * 2.4;
    float streak = exp(-pow((u - size.x * 0.24) / 46.0, 2.0)) * 0.11
                 + exp(-pow((u - size.x * 0.27) / 14.0, 2.0)) * 0.08
                 + exp(-pow((u - size.x * 0.64) / 30.0, 2.0)) * 0.07;
    col += vec3(1.0) * streak * (1.0 - p.y / glassH * 0.6);

    // cyan light gathering at the edge; the glass's thickness as a thin dark line, then a
    // bright rim at the very edge
    col = mix(col, vec3(0.19, 0.95, 1.0), t * t * 0.28);
    col *= 1.0 - 0.30 * exp(-pow((d - 3.2) / 1.1, 2.0));
    col = mix(col, vec3(1.0), smoothstep(1.8, 0.0, d) * 0.8);

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * qt_Opacity;
}
