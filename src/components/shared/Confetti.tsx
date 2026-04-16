'use client'

import { useEffect, useState } from 'react'

interface Particle {
  id: number
  x: number
  y: number
  color: string
  size: number
  rotation: number
  speedX: number
  speedY: number
}

const COLORS = ['#1EAAA6', '#147170', '#FFD700', '#FF6B6B', '#4ECDC4', '#FF9F43', '#A855F7', '#3B82F6']

export default function Confetti({ active, duration = 3000 }: { active: boolean; duration?: number }) {
  const [particles, setParticles] = useState<Particle[]>([])

  useEffect(() => {
    if (!active) return
    const newParticles: Particle[] = Array.from({ length: 60 }, (_, i) => ({
      id: i,
      x: 50 + (Math.random() - 0.5) * 40,
      y: -10,
      color: COLORS[Math.floor(Math.random() * COLORS.length)],
      size: 4 + Math.random() * 6,
      rotation: Math.random() * 360,
      speedX: (Math.random() - 0.5) * 6,
      speedY: 2 + Math.random() * 4,
    }))
    setParticles(newParticles)
    const timer = setTimeout(() => setParticles([]), duration)
    return () => clearTimeout(timer)
  }, [active, duration])

  if (particles.length === 0) return null

  return (
    <div className="fixed inset-0 pointer-events-none z-[100] overflow-hidden">
      {particles.map(p => (
        <div
          key={p.id}
          className="absolute animate-confetti"
          style={{
            left: `${p.x}%`,
            top: `${p.y}%`,
            width: p.size,
            height: p.size * 0.6,
            backgroundColor: p.color,
            borderRadius: '2px',
            transform: `rotate(${p.rotation}deg)`,
            '--speed-x': `${p.speedX}px`,
            '--speed-y': `${p.speedY}px`,
            animationDuration: `${2 + Math.random() * 2}s`,
          } as React.CSSProperties}
        />
      ))}
    </div>
  )
}
