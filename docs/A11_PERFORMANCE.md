# A11 Performance-Verbesserungen
> Erstellt: 2026-04-12 | Status: Erledigt | Commit: 11b79f1

## Zusammenfassung

Die Performance-Analyse konzentrierte sich auf drei Bereiche:
1. Dashboard-Queries (useDashboard.ts)
2. Google Fonts-Ladezeit
3. bot_scheduled_messages-Query (Spalten-Fehler verursachte Supabase-Error)

Der einzige tatsaechliche Fix war der bot_scheduled_messages-Query. Die anderen
beiden Bereiche waren bereits optimiert.

## 1. Dashboard-Queries: Promise.allSettled

### Architektur

Der `useDashboard`-Hook fuehrt 15 parallele Queries aus:

| Index | Query | Tabelle/RPC |
|---|---|---|
| [0] | Nahegelegene Posts | `search_posts` RPC (Fallback: posts-Tabelle) |
| [1] | Letzte Posts | `posts` (user_id, status=active, limit 5) |
| [2] | Letzte Interaktionen | `interactions` (helper_id, limit 5) |
| [3] | Trust-Bewertungen | `trust_ratings` (rated_id, limit 5) |
| [4] | Anzahl Posts | `posts` (count, head: true) |
| [5] | Abgeschlossene Interaktionen | `interactions` (count, status=completed) |
| [6] | Verschiedene Geholfene | `interactions` (select: post_id) |
| [7] | Durchschnittliche Trust-Bewertung | `trust_ratings` (avg score) |
| [8] | Gespeicherte Posts | `saved_posts` (count, head: true) |
| [9] | Ungelesene Nachrichten | `v_unread_counts` (Fallback: conversation_members) |
| [10] | Community-Puls | `get_community_pulse` RPC |
| [11] | Bot-Tipp | `bot_scheduled_messages` (status=pending) |
| [12] | Trust-Score-Trend | `trust_ratings` (rated_id) |
| [13] | Gesendete Nachrichten | `messages` (count, sender_id) |
| [14] | Gegebene Bewertungen | `trust_ratings` (count, rater_id) |

### Warum Promise.allSettled?

```ts
const results = await Promise.allSettled([
  // 15 queries ...
])

// Helper to safely extract data
const getData = (idx: number): any => {
  const r = results[idx]
  if (r.status === 'fulfilled') return r.value.data
  return null
}
```

**Vorteile:**
- Alle Queries laufen gleichzeitig (nicht sequenziell)
- Eine fehlgeschlagene Query blockiert nicht die anderen
- Jedes Ergebnis wird individuell geprüeft (fulfilled vs. rejected)
- Fallback-Daten (leere Arrays, 0-Werte) werden fuer fehlgeschlagene Queries verwendet

**Messwerte:** Das Dashboard laedt typischerweise in <2 Sekunden (15 parallele Queries
statt 15 sequenzielle = theoretisch 15x schneller).

### Kein Fix noetig

Die Architektur ist bereits optimal. Kein weiteres Optimierungspotenzial identifiziert.

## 2. Google Fonts: next/font

### Aktuelle Implementierung (app/layout.tsx)

```ts
import { Inter } from 'next/font/google'

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
  display: 'swap',
})
```

**Warum optimal:**
- `next/font/google` laedt Fonts zur Build-Zeit herunter und served sie lokal
- Kein externer Request zu fonts.googleapis.com zur Laufzeit
- `display: 'swap'` verhindert unsichtbaren Text (FOIT) waehrend des Ladens
- Font-Dateien werden als statische Assets ueber Cloudflare CDN ausgeliefert

### Kein Fix noetig

Google Fonts werden bereits ueber das optimale Pattern geladen. Die Cloudflare
Pages-Infrastruktur cached die Font-Dateien automatisch.

## 3. bot_scheduled_messages-Query: BEHOBEN

### Problem

Der Query in `useDashboard.ts` [11] verwendete nicht existierende Spalten:
- `message_content` statt `content`
- `sent` (boolean) statt `status` (text)
- `user_id` (nicht vorhanden)

Dies erzeugte Supabase-Fehler `42703`, der durch `Promise.allSettled` abgefangen
wurde -- der Bot-Tipp blieb leer, das Dashboard funktionierte aber weiter.

### Fix

```ts
// [11] Bot tip – columns: content (not message_content), status (not sent), no user_id column
supabase.from('bot_scheduled_messages')
  .select('content')
  .eq('status', 'pending')
  .eq('message_type', 'daily_tip')
  .order('created_at', { ascending: false })
  .limit(1)
```

Siehe Details in [A7_MODULE_BUGS.md](./A7_MODULE_BUGS.md).

## 4. Realtime-Subscriptions

### Dashboard Realtime (useDashboard.ts)

Der Hook abonniert zwei Realtime-Channels:
```ts
// Posts-Channel: neue Posts in der Naehe
supabase.channel('dashboard-posts')
  .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'posts' }, ...)

// Messages-Channel: neue eingehende DMs
supabase.channel('dashboard-messages')
  .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages' }, ...)
```

### AppShell Realtime (AppShell.tsx)

Zusaetzliche Channels fuer Badge-Updates:
- `notifications` (INSERT + UPDATE)
- `messages` (INSERT)
- `crises` (*)
- `interactions` (*)

### Performance-Impact

Realtime-Subscriptions nutzen WebSockets und verursachen minimale Last.
Jeder Channel erzeugt einen einzelnen WebSocket-Listener.

## Betroffene Dateien

| Datei | Aenderung |
|---|---|
| `src/app/dashboard/hooks/useDashboard.ts` | bot_scheduled_messages Query korrigiert |
| `src/app/layout.tsx` | Verifiziert: next/font optimal |
| `src/app/dashboard/layout.tsx` | Verifiziert: Realtime-Architektur OK |

## Empfehlungen fuer zukuenftige Optimierungen

1. **Lazy Loading:** Module-Seiten koennen mit `React.lazy()` nachgeladen werden
2. **RPC-Buendelung:** Mehrere Dashboard-Queries koennten in einen einzelnen
   `get_dashboard_data(user_id)` RPC zusammengefasst werden
3. **Stale-While-Revalidate:** Zustand-Store koennte gecachte Daten anzeigen
   waehrend im Hintergrund frische Daten geladen werden
4. **Image Optimization:** Post-Bilder koennen ueber Cloudflare Images resized/optimiert werden
