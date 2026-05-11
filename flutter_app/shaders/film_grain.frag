#version 460 core

// Cinema 35mm-Filmkorn. Pro Frame neu generierter White-Noise mit
// leichtem Warm-Tint. BlendMode in Dart auf overlay/screen setzen.

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;

out vec4 fragColor;

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 fragCoord = FlutterFragCoord();
    vec2 uv = fragCoord / uSize;

    float grain = rand(uv * uSize + uTime * 60.0);
    grain = (grain - 0.5) * 0.07;

    // Warmer Tint: leichter Amber-Shift.
    vec3 warm = vec3(grain * 1.10, grain * 1.00, grain * 0.85);
    fragColor = vec4(warm, abs(grain) * 12.0);
}
