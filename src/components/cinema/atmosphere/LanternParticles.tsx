'use client'

import { useMemo, useRef } from 'react'
import { useFrame } from '@react-three/fiber'
import * as THREE from 'three'

/**
 * LanternParticles — 40 schwebende Laternenlichter.
 *
 * THREE.Points mit BufferGeometry. Jedes Partikel hat eigene Phase und
 * Frequenz, pulsiert eigenständig. Größere Punkte (= nähere Laternen)
 * haben Bokeh-Hellring am Rand.
 */
const COUNT = 40
const COLORS = [
  new THREE.Color('#F59E0B'), // amber
  new THREE.Color('#FBBF24'), // amber-warm
  new THREE.Color('#FDE68A'), // amber-soft
  new THREE.Color('#D4A054'), // trust
]

const VERT = /* glsl */ `
  attribute float aSize;
  attribute float aPhase;
  attribute float aFreq;
  attribute vec3  aColor;
  uniform float uTime;
  varying float vSize;
  varying vec3  vColor;
  varying float vPulse;

  void main() {
    vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);
    float pulse = 0.55 + 0.45 * sin(uTime * aFreq + aPhase);
    vPulse = pulse;
    vSize  = aSize;
    vColor = aColor;
    gl_PointSize = aSize * (1.0 + 0.35 * pulse) * (300.0 / -mvPosition.z);
    gl_Position  = projectionMatrix * mvPosition;
  }
`

const FRAG = /* glsl */ `
  varying float vSize;
  varying vec3  vColor;
  varying float vPulse;

  void main() {
    vec2 c = gl_PointCoord - 0.5;
    float d = length(c);
    if (d > 0.5) discard;

    // Weicher Kern
    float core = smoothstep(0.5, 0.0, d);
    // Bokeh-Ring (nur für größere Partikel sichtbar wirkend)
    float ring = smoothstep(0.42, 0.48, d) - smoothstep(0.48, 0.50, d);
    float ringStrength = clamp((vSize - 8.0) / 8.0, 0.0, 0.5);

    float a = (core * 0.55 + ring * ringStrength) * (0.45 + 0.55 * vPulse);
    vec3 col = vColor + ring * ringStrength * 0.4;
    gl_FragColor = vec4(col, a);
  }
`

export default function LanternParticles() {
  const matRef = useRef<THREE.ShaderMaterial>(null)

  const { positions, sizes, phases, freqs, colors } = useMemo(() => {
    const positions = new Float32Array(COUNT * 3)
    const sizes     = new Float32Array(COUNT)
    const phases    = new Float32Array(COUNT)
    const freqs     = new Float32Array(COUNT)
    const colors    = new Float32Array(COUNT * 3)

    for (let i = 0; i < COUNT; i++) {
      const edgeBias = Math.random() < 0.55 ? 1 : 0
      // Mehr oben und an den Seiten
      const x = (Math.random() - 0.5) * 14 * (edgeBias ? 1.1 : 0.85)
      const y = Math.random() * 6 + (Math.random() < 0.6 ? 1 : -1)
      const z = -(Math.random() * 4 + 1)
      positions[i * 3 + 0] = x
      positions[i * 3 + 1] = y
      positions[i * 3 + 2] = z

      // 5 Hauptlaternen sind groß, Rest kleiner
      const isHero = i < 5
      sizes[i]  = isHero
        ? 14 + Math.random() * 6
        : 3 + Math.random() * 7
      phases[i] = Math.random() * Math.PI * 2
      freqs[i]  = 0.2 + Math.random() * 0.6

      const c = COLORS[(Math.random() * COLORS.length) | 0]
      colors[i * 3 + 0] = c.r
      colors[i * 3 + 1] = c.g
      colors[i * 3 + 2] = c.b
    }
    return { positions, sizes, phases, freqs, colors }
  }, [])

  const uniforms = useMemo(() => ({ uTime: { value: 0 } }), [])

  useFrame(({ clock }) => {
    if (matRef.current) {
      matRef.current.uniforms.uTime.value = clock.elapsedTime
    }
  })

  return (
    <points frustumCulled={false} renderOrder={-1}>
      <bufferGeometry>
        <bufferAttribute attach="attributes-position" args={[positions, 3]} />
        <bufferAttribute attach="attributes-aSize"    args={[sizes,     1]} />
        <bufferAttribute attach="attributes-aPhase"   args={[phases,    1]} />
        <bufferAttribute attach="attributes-aFreq"    args={[freqs,     1]} />
        <bufferAttribute attach="attributes-aColor"   args={[colors,    3]} />
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
