#version 460 core

// Mensaena Cinema 3.0 — Atmosphaerischer Bodennebel.
// Volumetrische Nacht-Atmosphaere: 3 Oktaven Fractal Brownian Motion,
// langsame horizontale Drift, dichter unten / transparent oben.

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;       // FragmentShader-Resolution
uniform float uTime;      // Sekunden seit Start
uniform float uScroll;    // 0..1 normalisierter Scroll-Offset
uniform float uCrisis;    // 0..1 Crisis-Crossfade (rot-Tint hochfahren)

out vec4 fragColor;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 fragCoord = FlutterFragCoord();
    vec2 uv = fragCoord / uSize;

    // Drift: langsam horizontal, leicht vertikal mit Zeit.
    vec2 driftedUv = uv * 2.5 + vec2(uTime * 0.015, uTime * 0.005);
    float n = fbm(driftedUv);

    // Vertikales Profil: dicht unten, transparent oben.
    float vertical = smoothstep(1.0, 0.25, uv.y);

    // Scroll fadet den Bodennebel weiter nach unten beim Scrollen.
    vertical *= mix(1.0, 0.6, uScroll);

    float fog = n * vertical * 0.10;

    // Farbmischung: warmes Amber mit dezentem Teal-Anteil.
    vec3 amber = vec3(0.961, 0.620, 0.043);
    vec3 teal  = vec3(0.055, 0.647, 0.914);
    vec3 herzrot = vec3(0.937, 0.267, 0.267);
    vec3 base = mix(amber, teal, 0.15);

    // Crisis-Shift: Crossfade zu Herzrot wenn Krise aktiv.
    base = mix(base, herzrot, uCrisis);

    fragColor = vec4(base, fog);
}
