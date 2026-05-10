'use client'

import { useMemo, useRef } from 'react'
import { useFrame } from '@react-three/fiber'
import * as THREE from 'three'

/**
 * Fireflies — 10 Glühwürmchen mit Lissajous-Bewegung.
 *
 * Optional via prop deaktivierbar (Dashboard/Chat nutzt false).
 */
const COUNT = 10
const FIREFLY_COLOR = new THREE.Color('#FDE68A')

const VERT = /* glsl */ `
  attribute float aPhase;
  attribute float aCycle;
  attribute vec2  aAmp;
  attribute vec2  aFreq;
  uniform float uTime;
  varying float vAlpha;

  void main() {
    vec3 p = position;
    float t = uTime;
    // Lissajous mit Phase-Offset
    p.x += aAmp.x * sin(aFreq.x * t + aPhase);
    p.y += aAmp.y * sin(aFreq.y * t);
    // Sanftes Höhen-Driften
    p.y += 0.15 * sin(t * 0.3 + aPhase);

    vec4 mv = modelViewMatrix * vec4(p, 1.0);
    gl_PointSize = (3.0 + 1.0 * sin(t * aCycle + aPhase)) * (300.0 / -mv.z);
    gl_Position = projectionMatrix * mv;

    // Alpha pulsiert sin-basiert 0 → 0.65 → 0
    float pulse = 0.5 + 0.5 * sin(t * aCycle + aPhase);
    vAlpha = pulse * 0.65;
  }
`

const FRAG = /* glsl */ `
  varying float vAlpha;
  void main() {
    vec2 c = gl_PointCoord - 0.5;
    float d = length(c);
    if (d > 0.5) discard;
    float core = smoothstep(0.5, 0.0, d);
    gl_FragColor = vec4(0.992, 0.902, 0.541, core * vAlpha);
  }
`

export default function Fireflies({ enabled = true }: { enabled?: boolean }) {
  const matRef = useRef<THREE.ShaderMaterial>(null)

  const { positions, phases, cycles, amps, freqs } = useMemo(() => {
    const positions = new Float32Array(COUNT * 3)
    const phases    = new Float32Array(COUNT)
    const cycles    = new Float32Array(COUNT)
    const amps      = new Float32Array(COUNT * 2)
    const freqs     = new Float32Array(COUNT * 2)

    for (let i = 0; i < COUNT; i++) {
      positions[i * 3 + 0] = (Math.random() - 0.5) * 8
      positions[i * 3 + 1] = (Math.random() - 0.5) * 4 + 0.5
      positions[i * 3 + 2] = -(Math.random() * 2 + 1)

      phases[i] = Math.random() * Math.PI * 2
      // 7-12s Zyklus → Frequenz 2π / cycleSeconds
      const cycleSec = 7 + Math.random() * 5
      cycles[i] = (Math.PI * 2) / cycleSec

      amps[i * 2 + 0] = 0.6 + Math.random() * 0.8
      amps[i * 2 + 1] = 0.3 + Math.random() * 0.5
      freqs[i * 2 + 0] = 0.2 + Math.random() * 0.4
      freqs[i * 2 + 1] = 0.1 + Math.random() * 0.3
    }
    return { positions, phases, cycles, amps, freqs }
  }, [])

  const uniforms = useMemo(() => ({ uTime: { value: 0 } }), [])

  useFrame(({ clock }) => {
    if (matRef.current) matRef.current.uniforms.uTime.value = clock.elapsedTime
  })

  if (!enabled) return null

  return (
    <points frustumCulled={false} renderOrder={0}>
      <bufferGeometry>
        <bufferAttribute attach="attributes-position" args={[positions, 3]} />
        <bufferAttribute attach="attributes-aPhase"   args={[phases,    1]} />
        <bufferAttribute attach="attributes-aCycle"   args={[cycles,    1]} />
        <bufferAttribute attach="attributes-aAmp"     args={[amps,      2]} />
        <bufferAttribute attach="attributes-aFreq"    args={[freqs,     2]} />
      </bufferGeometry>
      <shaderMaterial
        ref={matRef}
        vertexShader={VERT}
        fragmentShader={FRAG}
        uniforms={uniforms}
        transparent
        depthWrite={false}
        blending={THREE.AdditiveBlending}
      />
    </points>
  )
}

// Suppress unused import warning for FIREFLY_COLOR (kept for future tuning)
void FIREFLY_COLOR
