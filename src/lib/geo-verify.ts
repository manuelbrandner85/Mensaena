export interface VerifyResult {
  success: boolean
  distance: number
  message: string
}

function haversineDistance(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371000
  const toRad = (deg: number) => (deg * Math.PI) / 180
  const dLat = toRad(lat2 - lat1)
  const dLng = toRad(lng2 - lng1)
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

function getCurrentPosition(): Promise<GeolocationPosition> {
  return new Promise((resolve, reject) => {
    navigator.geolocation.getCurrentPosition(resolve, reject, {
      enableHighAccuracy: true,
      timeout: 10000,
    })
  })
}

export async function verifyLocation(
  profileLat: number,
  profileLng: number,
): Promise<VerifyResult> {
  if (typeof navigator === 'undefined' || !navigator.geolocation) {
    return { success: false, distance: -1, message: 'GPS-Zugriff nicht möglich' }
  }

  try {
    const position = await getCurrentPosition()
    const { latitude, longitude } = position.coords
    const distance = Math.round(haversineDistance(profileLat, profileLng, latitude, longitude))

    if (distance <= 2000) {
      return { success: true, distance, message: 'Standort verifiziert' }
    }
    return {
      success: false,
      distance,
      message: 'Du bist zu weit von deinem eingetragenen Standort entfernt',
    }
  } catch {
    return { success: false, distance: -1, message: 'GPS-Zugriff nicht möglich' }
  }
}
