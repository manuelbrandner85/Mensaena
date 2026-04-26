/**
 * PLZ / Bundesland / AGS mapping utilities for Germany.
 *
 * Re-exports plzToBundesland and BundeslandCode from holidays.ts
 * (single source of truth for the PLZ → Bundesland heuristic).
 */

export type { BundeslandCode } from '@/lib/api/holidays'
export { plzToBundesland, coordsToBundesland } from '@/lib/api/holidays'

import { plzToBundesland } from '@/lib/api/holidays'
import type { BundeslandCode } from '@/lib/api/holidays'

// ── AGS Bundesland prefix (2-digit Amtlicher Gemeindeschlüssel) ──────────────

const BUNDESLAND_TO_AGS: Record<BundeslandCode, string> = {
  SH: '01',
  HH: '02',
  NI: '03',
  HB: '04',
  NW: '05',
  HE: '06',
  RP: '07',
  BW: '08',
  BY: '09',
  SL: '10',
  BE: '11',
  BB: '12',
  MV: '13',
  SN: '14',
  ST: '15',
  TH: '16',
  NATIONAL: '00',
}

/**
 * Returns the 2-digit AGS Bundesland prefix for a given PLZ.
 * Falls back to '00' if the PLZ cannot be mapped.
 */
export function plzToAgs(plz: string | null | undefined): string {
  const code = plzToBundesland(plz)
  return BUNDESLAND_TO_AGS[code] ?? '00'
}

// ── Tagesschau regional IDs ──────────────────────────────────────────────────

const BUNDESLAND_TO_REGION_ID: Record<BundeslandCode, number> = {
  BW: 1,
  BY: 2,
  BE: 3,
  BB: 4,
  HB: 5,
  HH: 6,
  HE: 7,
  MV: 8,
  NI: 9,
  NW: 10,
  RP: 11,
  SL: 12,
  SN: 13,
  ST: 14,
  SH: 15,
  TH: 16,
  NATIONAL: 0,
}

/**
 * Maps a BundeslandCode to a Tagesschau regional news ID (1–16).
 * Returns 0 for NATIONAL / unmapped states.
 */
export function bundeslandToRegionId(state: BundeslandCode): number {
  return BUNDESLAND_TO_REGION_ID[state] ?? 0
}
