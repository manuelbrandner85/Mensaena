'use client'

/**
 * Water-level marker layer for the map.
 *
 * This is NOT a React-rendered component – Leaflet is imperative, so we
 * export a small helper that adds/removes a Leaflet layer group on a
 * given map instance. MapComponent calls these from its own useEffects.
 */

import type * as L from 'leaflet'
import { getWarningLevel, WARNING_COLORS, type WaterStation } from '@/lib/api/waterlevel'

function trendArrow(t: WaterStation['trend']): string {
  if (t === 'rising')  return '↑'
  if (t === 'falling') return '↓'
  return '→'
}

function buildPopupHtml(s: WaterStation): string {
  const c = WARNING_COLORS[getWarningLevel(s.currentLevel)]
  const ts = s.timestamp ? new Date(s.timestamp).toLocaleString('de-DE', {
    day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit',
  }) : ''
  return [
    `<div style="min-width:180px;max-width:240px;font-family:system-ui,sans-serif;padding:2px">`,
    `<div style="display:flex;align-items:center;gap:6px;margin-bottom:4px">`,
    `<span style="display:inline-block;width:10px;height:10px;border-radius:50%;background:${c.hex};box-shadow:0 0 0 2px white,0 0 0 3px ${c.hex}33"></span>`,
    `<strong style="font-size:13px;color:#111;line-height:1.3">${s.name}</strong>`,
    `</div>`,
    s.waterName ? `<p style="font-size:11px;color:#666;margin:0 0 6px">Gewässer: ${s.waterName}</p>` : '',
    `<div style="display:flex;align-items:baseline;gap:4px;margin-bottom:4px">`,
    `<span style="font-size:22px;font-weight:700;color:${c.hex};font-variant-numeric:tabular-nums">${s.currentLevel}</span>`,
    `<span style="font-size:11px;color:#666">${s.unit}</span>`,
    `<span style="font-size:14px;color:${c.hex};margin-left:4px">${trendArrow(s.trend)}</span>`,
    `</div>`,
    `<p style="font-size:11px;color:${c.hex};margin:0 0 4px;font-weight:600">${c.label}</p>`,
    ts ? `<p style="font-size:10px;color:#999;margin:0">Stand: ${ts}</p>` : '',
    `</div>`,
  ].join('')
}

/**
 * Add water-level markers to a Leaflet map and return the layer group
 * (so callers can remove it later).
 */
export function addWaterLevelLayer(
  L: typeof import('leaflet'),
  map: import('leaflet').Map,
  stations: WaterStation[],
): L.LayerGroup {
  const group = L.layerGroup()
  for (const s of stations) {
    const lvl = getWarningLevel(s.currentLevel)
    const c   = WARNING_COLORS[lvl]
    const isWarn = lvl !== 'normal'
    const size = isWarn ? 26 : 20

    const icon = L.divIcon({
      html: [
        `<div style="`,
          `width:${size}px;height:${size}px;`,
          `background:${c.hex};`,
          `border:3px solid white;`,
          `border-radius:50%;`,
          `display:flex;align-items:center;justify-content:center;`,
          `box-shadow:0 2px 8px rgba(0,0,0,0.3);`,
          `font-size:${isWarn ? 12 : 10}px;line-height:1;color:white;font-weight:700;`,
          isWarn ? `animation:pulse-water 1.5s ease-in-out infinite;` : '',
        `">${trendArrow(s.trend)}</div>`,
      ].join(''),
      className: 'mensaena-water-marker',
      iconSize: [size, size],
      iconAnchor: [size / 2, size / 2],
    })

    L.marker([s.lat, s.lon], { icon })
      .bindPopup(buildPopupHtml(s), { maxWidth: 260 })
      .addTo(group)
  }
  group.addTo(map)
  return group
}

/** CSS keyframes injected once for the pulsing warn marker. */
let _stylesInjected = false
export function ensureWaterLevelStyles() {
  if (_stylesInjected || typeof document === 'undefined') return
  _stylesInjected = true
  const style = document.createElement('style')
  style.textContent = `
    @keyframes pulse-water {
      0%, 100% { transform: scale(1);   box-shadow: 0 2px 8px rgba(0,0,0,0.3); }
      50%      { transform: scale(1.15); box-shadow: 0 2px 14px rgba(220,38,38,0.5); }
    }
  `
  document.head.appendChild(style)
}
