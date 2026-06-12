#version 460 core
// SKILL: mensaena-design — Film-Grain als GPU-Shader (Impeller/Skia).
// Ersetzt den CPU-CustomPainter: identische Optik (weiches 12.5fps-Korn
// kommt weiterhin vom AnimationController, der uTime quantisiert),
// aber 0 Dart-Arbeit pro Frame.
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform float uTime;     // quantisierte Zeit (12.5 fps Steps)
uniform float uOpacity;  // 0.0 - 0.03 wie beim CPU-Painter

out vec4 fragColor;

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
  vec2 uv = FlutterFragCoord().xy;
  float g = hash(uv + vec2(uTime * 731.0, uTime * 577.0));
  // Korn um Mittelgrau zentriert: hellt und dunkelt gleichermassen.
  float v = 0.5 + (g - 0.5);
  // Premultiplied Alpha (Flutter-Konvention).
  fragColor = vec4(vec3(v) * uOpacity, uOpacity);
}
