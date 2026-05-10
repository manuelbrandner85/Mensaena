'use client'

import { Canvas } from '@react-three/fiber'
import VolumetricFog from './VolumetricFog'
import LanternParticles from './LanternParticles'
import Fireflies from './Fireflies'
import WetAsphaltReflection from './WetAsphaltReflection'

type Props = {
  /** Glühwürmchen ein/aus (Landing/Auth = an, Dashboard/Chat = aus). */
  fireflies?: boolean
  /** Wet-Asphalt-Reflection ein/aus. */
  asphalt?: boolean
}

/**
 * AtmosphericCanvas — Fixed Hintergrund hinter dem gesamten Content.
 *
 * Pointer-events: none, z-0. Lädt lazy via dynamic import.
 * Renders Three.js Scene mit Fog + Laternen + Glühwürmchen + Asphalt.
 */
export default function AtmosphericCanvas({
  fireflies = true,
  asphalt   = true,
}: Props) {
  return (
    <Canvas
      className="!fixed inset-0 !z-0 pointer-events-none"
      gl={{
        alpha:            true,
        antialias:        false,
        powerPreference:  'high-performance',
      }}
      dpr={[1, 1.5]}
      camera={{ position: [0, 0, 8], fov: 55 }}
      frameloop="always"
      aria-hidden="true"
    >
      <VolumetricFog />
      <LanternParticles />
      <Fireflies enabled={fireflies} />
      {asphalt && <WetAsphaltReflection />}
    </Canvas>
  )
}
