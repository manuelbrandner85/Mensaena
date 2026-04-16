/**
 * Chat Feature Utilities
 * Hilfsfunktionen für erweiterte Chat-Features
 */

// ── Markdown-artige Formatierung ─────────────────────────────
export function formatChatMessage(text: string): string {
  let html = text
    // Code-Blöcke (```code```)
    .replace(/```([\s\S]*?)```/g, '<code class="bg-gray-100 px-1.5 py-0.5 rounded text-xs font-mono">$1</code>')
    // Inline-Code (`code`)
    .replace(/`([^`]+)`/g, '<code class="bg-gray-100 px-1 py-0.5 rounded text-xs font-mono">$1</code>')
    // Fett (**text**)
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    // Kursiv (*text*)
    .replace(/\*(.+?)\*/g, '<em>$1</em>')
    // Durchgestrichen (~~text~~)
    .replace(/~~(.+?)~~/g, '<del class="text-gray-400">$1</del>')
    // Links (automatisch klickbar)
    .replace(
      /(https?:\/\/[^\s<]+)/g,
      '<a href="$1" target="_blank" rel="noopener noreferrer" class="text-primary-600 hover:underline break-all">$1</a>'
    )
  return html
}

// ── Link-Preview Daten extrahieren ───────────────────────────
export function extractUrls(text: string): string[] {
  const urlRegex = /https?:\/\/[^\s<]+/g
  return text.match(urlRegex) || []
}

export interface LinkPreviewData {
  url: string
  title?: string
  description?: string
  image?: string
  domain?: string
}

// ── Nachrichten-Permalink ────────────────────────────────────
export function getMessagePermalink(convId: string, msgId: string): string {
  return `/dashboard/chat?conv=${convId}&msg=${msgId}`
}

// ── Skeleton-Daten ───────────────────────────────────────────
export function generateSkeletonMessages(count: number = 5) {
  return Array.from({ length: count }, (_, i) => ({
    id: `skeleton-${i}`,
    isOwnMessage: i % 3 === 0,
    width: 40 + Math.random() * 50,
  }))
}

// ── Chat-Export ──────────────────────────────────────────────
export function exportChatAsText(
  messages: Array<{ content: string; created_at: string; profiles?: { name?: string | null } | null }>,
  title: string,
): string {
  const header = `=== ${title} ===\nExportiert am ${new Date().toLocaleDateString('de-DE')}\n${'='.repeat(40)}\n\n`
  const body = messages.map(m => {
    const name = m.profiles?.name || 'Unbekannt'
    const date = new Date(m.created_at).toLocaleString('de-DE')
    return `[${date}] ${name}: ${m.content}`
  }).join('\n')
  return header + body
}

export function downloadTextFile(content: string, filename: string) {
  const blob = new Blob([content], { type: 'text/plain;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}
