'use client'

import { useEffect, useRef } from 'react'
import { getPostTypeColor, getPostTypeEmoji } from '@/lib/utils'

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type AnyPost = Record<string, any>

// Leaflet wird nur client-side importiert
let L: typeof import('leaflet')

export default function MapComponent({
  posts,
  onSelectPost,
  selectedPost,
}: {
  posts: AnyPost[]
  onSelectPost: (post: AnyPost | null) => void
  selectedPost: AnyPost | null
}) {
  const mapRef = useRef<HTMLDivElement>(null)
  const mapInstanceRef = useRef<import('leaflet').Map | null>(null)
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const markersRef = useRef<any>(null)

  useEffect(() => {
    if (!mapRef.current || mapInstanceRef.current) return

    const initMap = async () => {
      L = (await import('leaflet')).default
      // Leaflet CSS wird via globals.css geladen
      try {
        await import('leaflet.markercluster')
        await import('leaflet.markercluster/dist/MarkerCluster.css')
        await import('leaflet.markercluster/dist/MarkerCluster.Default.css')
      } catch {}

      const map = L.map(mapRef.current!, {
        center: [48.2, 11.5],
        zoom: 12,
        zoomControl: true,
        attributionControl: true,
      })

      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
        maxZoom: 19,
      }).addTo(map)

      mapInstanceRef.current = map
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const LL = L as any
      markersRef.current = LL.markerClusterGroup
        ? LL.markerClusterGroup({
            maxClusterRadius: 50,
            showCoverageOnHover: false,
            spiderfyOnMaxZoom: true,
            iconCreateFunction: (cluster: { getAllChildMarkers: () => { options: { postType?: string } }[] }) => {
              const children = cluster.getAllChildMarkers()
              // Tally types to find dominant one
              const counts: Record<string, number> = {}
              children.forEach(m => {
                const t = m.options.postType ?? 'community'
                counts[t] = (counts[t] ?? 0) + 1
              })
              const dominant = Object.entries(counts).sort((a, b) => b[1] - a[1])[0]?.[0] ?? 'community'
              const color = getPostTypeColor(dominant)
              const total = children.length
              const size = total < 10 ? 40 : total < 100 ? 48 : 56
              return L.divIcon({
                html: `<div style="
                  width:${size}px;height:${size}px;
                  background:${color};
                  border:3px solid white;
                  border-radius:50%;
                  display:flex;align-items:center;justify-content:center;
                  color:white;font-weight:700;font-size:${total < 100 ? 14 : 13}px;
                  box-shadow:0 4px 14px rgba(0,0,0,0.28);
                  font-family:system-ui;
                  letter-spacing:-0.02em;
                ">${total}</div>`,
                className: 'mensaena-cluster',
                iconSize: [size, size],
                iconAnchor: [size / 2, size / 2],
              })
            },
          })
        : L.layerGroup()
      mapInstanceRef.current.addLayer(markersRef.current)

      // Try to get user location
      if (navigator.geolocation) {
        navigator.geolocation.getCurrentPosition(
          (pos) => {
            map.setView([pos.coords.latitude, pos.coords.longitude], 13)
            // User location marker
            const userIcon = L.divIcon({
              html: `<div style="
                width: 18px; height: 18px;
                background: #4F6D8A;
                border: 3px solid white;
                border-radius: 50%;
                box-shadow: 0 2px 8px rgba(0,0,0,0.3);
              "></div>`,
              className: '',
              iconSize: [18, 18],
              iconAnchor: [9, 9],
            })
            L.marker([pos.coords.latitude, pos.coords.longitude], { icon: userIcon })
              .addTo(map)
              .bindPopup('📍 Dein Standort')
          },
          (err) => {
            // Permission denied / timeout — silently keep default center, log for debugging
            console.warn('geolocation unavailable:', err.message)
          },
          { timeout: 8000, maximumAge: 60000 }
        )
      }
    }

    initMap()

    return () => {
      mapInstanceRef.current?.remove()
      mapInstanceRef.current = null
    }
  }, [])

  // Update markers when posts change
  useEffect(() => {
    if (!markersRef.current || !L) return

    markersRef.current.clearLayers()

    posts.forEach((post) => {
      if (!post.latitude || !post.longitude) return

      const color = getPostTypeColor(post.type)
      const emoji = getPostTypeEmoji(post.type)
      const isSelected = selectedPost?.id === post.id
      const size = isSelected ? 34 : 28

      // Marker = colored circle with the post-type emoji inside,
      // matching the legend entries 1:1.
      const icon = L.divIcon({
        html: `<div style="
          width: ${size}px;
          height: ${size}px;
          background: ${color};
          border: ${isSelected ? '3px' : '2px'} solid white;
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: ${isSelected ? 16 : 14}px;
          line-height: 1;
          box-shadow: 0 ${isSelected ? 4 : 2}px ${isSelected ? '14px' : '6px'} rgba(0,0,0,${isSelected ? '0.35' : '0.22'});
          transition: all 0.2s;
          cursor: pointer;
        ">${emoji}</div>`,
        className: '',
        iconSize: [size, size],
        iconAnchor: [size / 2, size / 2],
      })

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const marker = L.marker([post.latitude, post.longitude], { icon, postType: post.type } as any)
      marker.on('click', () => onSelectPost(post))
      marker.bindTooltip(post.title, {
        direction: 'top',
        offset: [0, -10],
        className: 'leaflet-tooltip-custom',
      })

      markersRef.current!.addLayer(marker)
    })
  }, [posts, selectedPost, onSelectPost])

  return (
    <div
      ref={mapRef}
      className="w-full h-full min-h-[520px]"
      style={{ zIndex: 1 }}
    />
  )
}
