'use client'

import { useMemo, useRef } from 'react'
import { useFrame, useThree } from '@react-three/fiber'
import * as THREE from 'three'

/**
 * VolumetricFog — Bodennebel der durch eine Straße zieht.
 *
 * Fullscreen-Quad mit Custom-Shader. 3 Oktaven FBM-Noise, langsame
 * horizontale Drift, vertikal gewichtet (dichter unten). Maximale
 * Opazität 0.10. Farbmischung: 85% amber + 15% teal.
 */
const FRAG = /* glsl */ `
  uniform float uTime;
  uniform vec2  uRes;
  uniform float uScroll;
  varying vec2  vUv;

  // 2D-Hash & Value-Noise
  float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
  }
  float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash(i + vec2(0.0, 0.0));
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
  }
  float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 3; i++) {
      v += a * noise(p);
      p *= 2.05;
      a *= 0.5;
    }
    return v;
  }

  void main() {
    vec2 uv = vUv;
    // Horizontale Drift (Wind)
    vec2 p = uv * vec2(2.6, 1.4);
    p.x += uTime * 0.015;
    p.y += uTime * 0.004;

    float n = fbm(p);
    n = smoothstep(0.35, 0.85, n);

    // Vertikal gewichtet: dichter unten
    float vertWeight = smoothstep(0.85, 0.10, uv.y);
    // Scroll macht Nebel leicht dichter
    float scrollBoost = clamp(uScroll * 0.06, 0.0, 0.04);

    vec3 amber = vec3(0.961, 0.620, 0.043);
    vec3 teal  = vec3(0.055, 0.647, 0.914);
    vec3 col   = mix(amber, teal, 0.15);

    float alpha = (n * 0.10 + scrollBoost) * vertWeight;
    gl_FragColor = vec4(col, alpha);
  }
`

const VERT = /* glsl */ `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = vec4(position.xy, 0.0, 1.0);
  }
`

export default function VolumetricFog() {
  const meshRef = useRef<THREE.Mesh>(null)
  const matRef  = useRef<THREE.ShaderMaterial>(null)
  const { size } = useThree()

  const uniforms = useMemo(
    () => ({
      uTime:   { value: 0 },
      uRes:    { value: new THREE.Vector2(size.width, size.height) },
      uScroll: { value: 0 },
    }),
    [size.width, size.height],
  )

  useFrame(({ clock }) => {
    if (matRef.current) {
      matRef.current.uniforms.uTime.value = clock.elapsedTime
      matRef.current.uniforms.uScroll.value =
        typeof window !== 'undefined'
          ? window.scrollY / Math.max(1, window.innerHeight)
          : 0
    }
  })

  return (
    <mesh ref={meshRef} frustumCulled={false} renderOrder={-2}>
      <planeGeometry args={[2, 2]} />
      <shaderMaterial
        ref={matRef}
        vertexShader={VERT}
        fragmentShader={FRAG}
        uniforms={uniforms}
        transparent
        depthWrite={false}
        depthTest={false}
      />
    </mesh>
  )
}
