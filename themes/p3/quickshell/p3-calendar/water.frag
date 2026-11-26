// p3-calendar backdrop: white paper with a huge disc of water coming in from the top-left.
// Inside the disc: deep-blue gradient, slow slanted light shafts and soft caustics near the
// top (kept faint lower down so the day numbers stay readable), and a light rim.
// p is in design units (720 high). `grow` (0 → 1) swells the disc on open.
// Compile: /usr/lib/qt6/bin/qsb --qt6 -o water.frag.qsb water.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float u;
    float grow;
    vec2 size;
};

float caustic(vec2 p, float t) {
    vec2 q = p;
    q += 0.35 * vec2(sin(q.y * 1.7 + t * 0.6), cos(q.x * 1.3 - t * 0.5));
    q += 0.25 * vec2(sin(q.y * 3.1 - t * 0.4), cos(q.x * 2.7 + t * 0.7));
    float v = sin(q.x * 2.0) * sin(q.y * 2.0);
    return pow(1.0 - abs(v), 6.0);
}

void main() {
    vec2 p = qt_TexCoord0 * size / u;
    // a very large circle centred far off the top-left corner: its edge runs from the top
    // of the screen (x 923) down to the bottom (x 627) as a long shallow curve
    vec2 c = vec2(-696.0, -246.0);
    float R = 1638.0 - 240.0 * (1.0 - grow);
    float d = length(p - c) - R;

    // paper: near-white, a breath of blue towards the bottom-right
    float pg = clamp((p.x / (size.x / u)) * 0.5 + (p.y / 720.0) * 0.5, 0.0, 1.0);
    vec3 paper = mix(vec3(0.985, 0.992, 1.0), vec3(0.86, 0.93, 0.985), smoothstep(0.55, 1.0, pg));

    // water
    float depth = clamp(p.y / 720.0, 0.0, 1.0);
    vec3 water = mix(vec3(0.07, 0.36, 0.95), vec3(0.02, 0.13, 0.80), smoothstep(0.0, 0.85, depth));
    water = mix(water, vec3(0.03, 0.20, 0.90), smoothstep(250.0, 900.0, p.x) * 0.5);
    float top = 1.0 - smoothstep(60.0, 420.0, p.y);            // effects live near the surface
    float shafts = 0.0;
    float sx = p.x + p.y * 0.55;
    shafts += smoothstep(0.55, 1.0, sin(sx * 0.011 + time * 0.13));
    shafts += 0.6 * smoothstep(0.6, 1.0, sin(sx * 0.023 - time * 0.09 + 1.7));
    water += vec3(0.10, 0.28, 0.30) * shafts * (0.25 + 0.75 * top) * 0.55;
    water += vec3(0.25, 0.45, 0.40) * caustic(p / 70.0, time) * top * 0.3;
    // light rim just inside the edge
    water += vec3(0.20, 0.45, 0.50) * smoothstep(-26.0, 0.0, d) * 0.55;

    float edge = smoothstep(-0.8, 0.8, d);
    vec3 col = mix(water, paper, edge);
    // soft shadow the disc casts on the paper
    col *= 1.0 - 0.10 * (1.0 - smoothstep(0.0, 26.0, d)) * edge;
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
