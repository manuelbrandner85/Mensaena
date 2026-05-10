'use client'

import { useMemo, useRef } from 'react'
import { useFrame } from '@react-three/fiber'
import * as THREE from 'three'

/**
 * WetAsphaltReflection — Untere 12% des Viewports.
 *
 * Spiegelt nichts wirklich. Nur ein Plane mit Shader das aussieht
 * als würde nasser Asphalt das Licht der Laternen reflektieren.
 * Horizontaler Gradient + Wellenverzerrung + Pfützen-Noise.
 */
const FRAG = /* glsl */ `
  uniform float uTime;
  varying vec2  vUv;

  float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
  }
  float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
  }

  void main() {
    // vUv ist 0..1 nur über die untere 12% Plane
    float wave = sin(vUv.x * 30.0 + uTime * 0.4) * 0.003;
    vec2 p = vUv + vec2(0.0, wave);

    // Horizontaler Gradient: hell in der Mitte, dunkel an den Rändern
    float horiz = 1.0 - smoothstep(0.0, 0.5, abs(p.x - 0.5));

    // Pfützen-Noise (ungleichmäßig)
    float puddles = noise(p * 6.0 + vec2(uTime * 0.05, 0.0));

    // Vertikal abklingen nach oben
    float vertFade = smoothstep(1.0, 0.0, p.y);

    float a = horiz * puddles * vertFade * 0.05;
    vec3 amber = vec3(0.961, 0.620, 0.043);
    gl_FragColor = vec4(amber, a);
  }
`

const VERT = /* glsl */ `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    // Untere 12% des Viewports: Plane belegt y in [-1, -0.76]
    float yMin = -1.0;
    float yMax = -0.76;
    vec2 pos;
    pos.x = position.x;
    pos.y = mix(yMin, yMax, (position.y + 1.0) * 0.5);
    gl_Position = vec4(pos, 0.0, 1.0);
  }
`

export default function WetAsphaltReflection() {
  const matRef = useRef<THREE.ShaderMaterial>(null)
  const uniforms = useMemo(() => ({ uTime: { value: 0 } }), [])

  useFrame(({ clock }) => {
    if (matRef.current) matRef.current.uniforms.uTime.value = clock.elapsedTime
  })

  return (
    <mesh frustumCulled={false} renderOrder={1}>
      <planeGeometry args={[2, 2]} />
      <shaderMaterial
        ref={matRef}
        vertexShader={VERT}
        fragmentShader={FRAG}
        uniforms={uniforms}
        transparent
        depthWrite={false}
        depthTest={false}
        blending={THREE.AdditiveBlending}
      />
    </mesh>
  )
}
