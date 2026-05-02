// FIX-124: Foreground-Service-Plugin komplett entfernt aus Build.
// Verursachte ForegroundServiceTypeNotAllowedException auf Android 14+.
// Stub-Funktionen lassen alte Aufrufe (sollten keine mehr existieren) silent durchlaufen.

export async function startCallForegroundService(): Promise<void> { /* no-op */ }
export async function updateCallForegroundService(): Promise<void> { /* no-op */ }
export async function stopCallForegroundService(): Promise<void> { /* no-op */ }
