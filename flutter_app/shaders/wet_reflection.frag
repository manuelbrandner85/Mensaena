#version 460 core

// Nasser Asphalt — Illusion einer feuchten Strasse am unteren Screen-Rand.
// Kein echtes Mirror, sondern dezenter Amber-Gradient mit sin-Wellenverzerrung.

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;

out vec4 fragColor;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

void main() {
    vec2 fragCoord = FlutterFragCoord();
    vec2 uv = fragCoord / uSize;

    // Nur untere 15% des Screens reflektieren.
    float bandStart = 0.85;
    float band = smoothstep(bandStart, 1.0, uv.y);

    // Horizontale Wellenverzerrung (sin, niedrige Frequenz).
    float wave = sin(uv.x * 18.0 + uTime * 0.6) * 0.3;

    // Pfuetzen-Noise: ungleichmaessig.
    float puddle = hash(floor(uv * vec2(8.0, 32.0)));

    // Horizontaler Amber-Verlauf, Mitte staerker.
    float centerStrength = 1.0 - abs(uv.x - 0.5) * 1.4;
    centerStrength = max(0.0, centerStrength);

    float intensity = band * centerStrength * (0.05 + puddle * 0.04) + wave * band * 0.005;
    intensity = clamp(intensity, 0.0, 0.10);

    vec3 amber = vec3(0.961, 0.620, 0.043);
    fragColor = vec4(amber, intensity);
}
