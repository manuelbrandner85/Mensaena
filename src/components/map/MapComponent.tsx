'use client'

import { useEffect, useRef } from 'react'
import { getPostTypeColor, getPostTypeEmoji } from '@/lib/utils'
import {
  fetchOverpassLayer,
  bboxAround,
  LAYER_META,
  type OverpassLayer,
} from '@/lib/services/overpass'

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type AnyPost = Record<string, any>

// Leaflet wird nur client-side importiert
let L: typeof import('leaflet')

function buildPopupHtml(
  meta: { emoji: string; label: string; color: string },
  pt: { id: string; name?: string; tags: Record<string, string> },
): string {
  const name = pt.name ?? meta.label
  const oh = pt.tags.opening_hours
  const phone = pt.tags.phone ?? pt.tags['contact:phone']
  const website = pt.tags.website ?? pt.tags['contact:website'] ?? pt.tags.url
  const addr = [pt.tags['addr:street'], pt.tags['addr:housenumber']].filter(Boolean).join(' ')
  const [osmType, osmId] = pt.id.split('/')
  const osmUrl = `https://www.openstreetmap.org/${osmType}/${osmId}`

  const rows = [
    addr && `<p style="font-size:12px;color:#555;margin:0 0 3px">📍 ${addr}</p>`,
    oh && `<p style="font-size:12px;color:#555;margin:0 0 3px">🕐 ${oh}</p>`,
    phone && `<p style="font-size:12px;color:#555;margin:0 0 3px">📞 <a href="tel:${phone}" style="color:#1EAAA6">${phone}</a></p>`,
    website && `<p style="font-size:12px;color:#555;margin:0 0 6px">🌐 <a href="${website}" target="_blank" rel="noopener" style="color:#1EAAA6">${website.replace(/^https?:\/\//, '').slice(0, 28)}</a></p>`,
  ].filter(Boolean).join('')

  return [
    `<div style="min-width:170px;max-width:220px;font-family:system-ui,sans-serif;padding:2px">`,
    `<div style="display:flex;align-items:center;gap:7px;margin-bottom:${rows ? 8 : 4}px">`,
    `<span style="font-size:22px;line-height:1;flex-shrink:0">${meta.emoji}</span>`,
    `<strong style="font-size:13px;color:#111;line-height:1.3">${name}</strong>`,
    `</div>`,
    rows,
    `<div style="border-top:1px solid #f0f0f0;padding-top:5px;margin-top:${rows ? 4 : 0}px">`,
    `<a href="${osmUrl}" target="_blank" rel="noopener" style="font-size:11px;color:#9ca3af;text-decoration:none">OpenStreetMap ansehen →</a>`,
    `</div></div>`,
  ].join('')
}

export default function MapComponent({
  posts,
  onSelectPost,
  selectedPost,
  activeLayers,
  onLoadingChange,
}: {
  posts: AnyPost[]
  onSelectPost: (post: AnyPost | null) => void
  selectedPost: AnyPost | null
  activeLayers?: Set<OverpassLayer>
  onLoadingChange?: (loading: Set<OverpassLayer>) => void
}) {
  const mapRef = useRef<HTMLDivElement>(null)
  const mapInstanceRef = useRef<import('leaflet').Map | null>(null)
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const markersRef = useRef<any>(null)
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const overpassLayersRef = useRef<globalThis.Map<OverpassLayer, any>>(new globalThis.Map())
  const overpassLoadedRef = useRef<Set<OverpassLayer>>(new Set())
  const activeLayersRef = useRef<Set<OverpassLayer>>(new Set())
  const onLoadingChangeRef = useRef(onLoadingChange)
  const loadingSetRef = useRef<Set<OverpassLayer>>(new Set())
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const loadLayerFnRef = useRef<((layer: OverpassLayer) => Promise<void>) | null>(null)

  // Keep refs in sync with latest props
  useEffect(() => { activeLayersRef.current = activeLayers ?? new Set() }, [activeLayers])
  useEffect(() => { onLoadingChangeRef.current = onLoadingChange }, [onLoadingChange])

  useEffect(() => {
    if (!mapRef.current || mapInstanceRef.current) return

    const initMap = async () => {
      L = (await import('leaflet')).default
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
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            iconCreateFunction: (cluster: any) => {
              // eslint-disable-next-line @typescript-eslint/no-explicit-any
              const children: { options: { postType?: string } }[] = cluster.getAllChildMarkers()
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
                html: `<div style="width:${size}px;height:${size}px;background:${color};border:3px solid white;border-radius:50%;display:flex;align-items:center;justify-content:center;color:white;font-weight:700;font-size:${total < 100 ? 14 : 13}px;box-shadow:0 4px 14px rgba(0,0,0,0.28);font-family:system-ui;letter-spacing:-0.02em">${total}</div>`,
                className: 'mensaena-cluster',
                iconSize: [size, size],
                iconAnchor: [size / 2, size / 2],
              })
            },
          })
        : L.layerGroup()
      map.addLayer(markersRef.current)

      // Per-layer loader — defined here to capture map + L in closure
      const loadLayer = async (layer: OverpassLayer) => {
        if (overpassLoadedRef.current.has(layer)) {
          const existing = overpassLayersRef.current.get(layer)
          if (existing && !map.hasLayer(existing)) existing.addTo(map)
          return
        }

        loadingSetRef.current.add(layer)
        onLoadingChangeRef.current?.(new Set(loadingSetRef.current))

        try {
          const center = map.getCenter()
          const bbox = bboxAround(center.lat, center.lng, 10)
          const points = await fetchOverpassLayer(layer, bbox)
          if (!mapInstanceRef.current) return

          const meta = LAYER_META[layer]
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          const clusterGroup = (L as any).markerClusterGroup
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            ? (L as any).markerClusterGroup({
                maxClusterRadius: 60,
                showCoverageOnHover: false,
                spiderfyOnMaxZoom: true,
                // eslint-disable-next-line @typescript-eslint/no-explicit-any
                iconCreateFunction: (cluster: any) => {
                  const count = cluster.getChildCount()
                  const size = count < 10 ? 32 : count < 100 ? 38 : 44
                  return L.divIcon({
                    html: `<div style="width:${size}px;height:${size}px;background:${meta.color};border:2px solid white;border-radius:50%;display:flex;align-items:center;justify-content:center;color:white;font-weight:700;font-size:12px;box-shadow:0 3px 10px rgba(0,0,0,0.25)">${count}</div>`,
                    className: '',
                    iconSize: [size, size],
                    iconAnchor: [size / 2, size / 2],
                  })
                },
              })
            : L.layerGroup()

          for (const pt of points) {
            const icon = L.divIcon({
              html: `<div style="width:30px;height:30px;background:${meta.color};border:2px solid white;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:15px;line-height:1;box-shadow:0 2px 6px rgba(0,0,0,0.22);cursor:pointer">${meta.emoji}</div>`,
              className: '',
              iconSize: [30, 30],
              iconAnchor: [15, 15],
            })
            const marker = L.marker([pt.lat, pt.lng], { icon })
            marker.bindPopup(buildPopupHtml(meta, pt), {
              maxWidth: 240,
              className: 'mensaena-poi-popup',
            })
            clusterGroup.addLayer(marker)
          }

          overpassLayersRef.current.set(layer, clusterGroup)
          overpassLoadedRef.current.add(layer)
          if (activeLayersRef.current.has(layer)) clusterGroup.addTo(map)
        } catch { /* rate-limited or network error */ }
        finally {
          loadingSetRef.current.delete(layer)
          onLoadingChangeRef.current?.(new Set(loadingSetRef.current))
        }
      }

      loadLayerFnRef.current = loadLayer

      // Debounced reload when user pans more than ~5 km
      let moveTimer: ReturnType<typeof setTimeout>
      let lastCenter = map.getCenter()
      map.on('moveend', () => {
        clearTimeout(moveTimer)
        moveTimer = setTimeout(() => {
          const center = map.getCenter()
          const dist = Math.hypot(center.lat - lastCenter.lat, center.lng - lastCenter.lng)
          if (dist < 0.05) return
          lastCenter = center
          overpassLayersRef.current.forEach((lg) => map.removeLayer(lg))
          overpassLayersRef.current.clear()
          overpassLoadedRef.current.clear()
          activeLayersRef.current.forEach((layer) => loadLayer(layer))
        }, 600)
      })

      // User geolocation
      if (navigator.geolocation) {
        navigator.geolocation.getCurrentPosition(
          (pos) => {
            map.setView([pos.coords.latitude, pos.coords.longitude], 13)
            const userIcon = L.divIcon({
              html: `<div style="width:18px;height:18px;background:#4F6D8A;border:3px solid white;border-radius:50%;box-shadow:0 2px 8px rgba(0,0,0,0.3)"></div>`,
              className: '',
              iconSize: [18, 18],
              iconAnchor: [9, 9],
            })
            L.marker([pos.coords.latitude, pos.coords.longitude], { icon: userIcon })
              .addTo(map)
              .bindPopup('📍 Dein Standort')
          },
          (e) => { console.warn('geolocation unavailable:', e.message) },
          { timeout: 8000, maximumAge: 60000 },
        )
      }
    }

    initMap()

    return () => {
      mapInstanceRef.current?.remove()
      mapInstanceRef.current = null
    }
  }, [])

  // Update post markers when posts or selection changes
  useEffect(() => {
    if (!markersRef.current || !L) return

    markersRef.current.clearLayers()

    posts.forEach((post) => {
      if (!post.latitude || !post.longitude) return

      const color = getPostTypeColor(post.type)
      const emoji = getPostTypeEmoji(post.type)
      const isSelected = selectedPost?.id === post.id
      const size = isSelected ? 34 : 28

      const icon = L.divIcon({
        html: `<div style="width:${size}px;height:${size}px;background:${color};border:${isSelected ? '3px' : '2px'} solid white;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:${isSelected ? 16 : 14}px;line-height:1;box-shadow:0 ${isSelected ? 4 : 2}px ${isSelected ? '14px' : '6px'} rgba(0,0,0,${isSelected ? '0.35' : '0.22'});transition:all 0.2s;cursor:pointer">${emoji}</div>`,
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

  // Activate / deactivate Overpass POI layers
  useEffect(() => {
    const map = mapInstanceRef.current
    if (!map || !L || !activeLayers) return

    // Deactivate removed layers
    overpassLayersRef.current.forEach((lg, layer) => {
      if (!activeLayers.has(layer)) {
        map.removeLayer(lg)
      } else if (!map.hasLayer(lg) && overpassLoadedRef.current.has(layer)) {
        lg.addTo(map)
      }
    })

    // Load layers that are newly active
    activeLayers.forEach((layer) => {
      if (!overpassLoadedRef.current.has(layer)) {
        loadLayerFnRef.current?.(layer)
      }
    })
  }, [activeLayers])

  return (
    <div
      ref={mapRef}
      className="w-full h-full min-h-[520px]"
      style={{ zIndex: 1 }}
    />
  )
}
