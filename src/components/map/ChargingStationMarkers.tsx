'use client'

/**
 * Charging-station marker layer for the map.
 *
 * Like WaterLevelMarkers, this is an imperative Leaflet helper rather than
 * a React component – it builds a (clustered) layer group with EV charging
 * station markers, color-coded by max power output.
 *
 * Power buckets:
 *   < 22 kW  – Normal  (blue)
 *   22–50 kW – Schnell (yellow)
 *   ≥ 50 kW  – Ultra   (green)
 */

import type * as L from 'leaflet'
import {
  type ChargingStation,
  getMaxPower,
  getPowerColor,
  getPowerLabel,
  getStatusLabel,
} from '@/lib/api/chargingstations'

function buildPopupHtml(station: ChargingStation): string {
  const maxKW       = getMaxPower(station)
  const color       = getPowerColor(maxKW)
  const powerLabel  = getPowerLabel(maxKW)
  const statusLabel = getStatusLabel(station.status)
  const connCount   = station.connections.length
  const addrLine    = [station.address, [station.postcode, station.city].filter(Boolean).join(' ')]
                        .filter(Boolean).join(', ')
  const navUrl      = `https://www.google.com/maps/dir/?api=1&destination=${station.lat},${station.lon}`

  return [
    `<div style="min-width:200px;max-width:240px;font-family:system-ui,sans-serif;padding:2px">`,
    `<div style="display:flex;align-items:center;gap:8px;margin-bottom:8px">`,
    `<div style="width:32px;height:32px;background:${color};border-radius:50%;display:flex;align-items:center;justify-content:center;flex-shrink:0;font-size:16px;color:white">⚡</div>`,
    `<strong style="font-size:13px;color:#111;line-height:1.3">${station.name}</strong>`,
    `</div>`,
    addrLine
      ? `<p style="font-size:12px;color:#555;margin:0 0 4px">📍 ${addrLine}</p>`
      : '',
    `<p style="font-size:12px;color:#555;margin:0 0 4px">🔌 ${connCount} Anschluss${connCount === 1 ? '' : 'punkte'}</p>`,
    `<p style="font-size:12px;color:${color};margin:0 0 4px;font-weight:600">${powerLabel}</p>`,
    `<p style="font-size:12px;color:#555;margin:0 0 10px">${statusLabel}</p>`,
    `<a href="${navUrl}" target="_blank" rel="noopener" style="display:inline-flex;align-items:center;gap:5px;background:${color};color:white;font-size:12px;font-weight:600;padding:6px 12px;border-radius:20px;text-decoration:none">`,
    `🗺️ Navigation starten`,
    `</a>`,
    `</div>`,
  ].join('')
}

/**
 * Add charging-station markers to a Leaflet map and return the layer group
 * (so callers can remove it later). Uses MarkerCluster when available.
 */
export function addChargingStationLayer(
  L: typeof import('leaflet'),
  map: import('leaflet').Map,
  stations: ChargingStation[],
): L.Layer {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const LL = L as any
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const group: any = LL.markerClusterGroup
    ? LL.markerClusterGroup({
        maxClusterRadius:    60,
        showCoverageOnHover: false,
        spiderfyOnMaxZoom:   true,
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        iconCreateFunction:  (cluster: any) => {
          const count = cluster.getChildCount()
          const size  = count < 10 ? 32 : count < 100 ? 38 : 44
          return L.divIcon({
            html: `<div style="width:${size}px;height:${size}px;background:#16A34A;border:2px solid white;border-radius:50%;display:flex;align-items:center;justify-content:center;color:white;font-weight:700;font-size:12px;box-shadow:0 3px 10px rgba(0,0,0,0.25)">⚡${count}</div>`,
            className: '',
            iconSize:   [size, size],
            iconAnchor: [size / 2, size / 2],
          })
        },
      })
    : L.layerGroup()

  for (const station of stations) {
    const maxKW = getMaxPower(station)
    const color = getPowerColor(maxKW)
    const icon  = L.divIcon({
      html: `<div style="width:30px;height:30px;background:${color};border:2px solid white;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:15px;line-height:1;box-shadow:0 2px 6px rgba(0,0,0,0.22);cursor:pointer;color:white">⚡</div>`,
      className: '',
      iconSize:   [30, 30],
      iconAnchor: [15, 15],
    })
    L.marker([station.lat, station.lon], { icon })
      .bindPopup(buildPopupHtml(station), { maxWidth: 260, className: 'mensaena-poi-popup' })
      .addTo(group)
  }

  group.addTo(map)
  return group
}
