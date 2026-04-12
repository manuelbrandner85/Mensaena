# A7 Modul-spezifische Bugs: Analyse & Fixes
> Erstellt: 2026-04-12 | Status: Erledigt | Commit: 11b79f1

## Zusammenfassung

Unter A7 waren Bugs in einzelnen Modulen gemeldet: Tiere-Logik, Wohnen-Query,
und der Dashboard-Bot-Tipp. Die Untersuchung zeigte, dass Tiere und Wohnen
korrekt funktionieren; der einzige echte Bug war der `bot_scheduled_messages`-Query
im Dashboard-Hook.

## 1. bot_scheduled_messages (useDashboard.ts) -- BEHOBEN

### Problem

Der Dashboard-Hook fragte nicht existierende Spalten ab:

```ts
// VORHER (fehlerhaft):
supabase.from('bot_scheduled_messages')
  .select('message_content')     // ❌ Spalte heisst "content"
  .eq('sent', false)             // ❌ Spalte heisst "status"
  .eq('user_id', userId)         // ❌ Spalte existiert nicht
  .order('created_at', { ascending: false })
  .limit(1)
```

Dies fuehrte zu Supabase-Fehler `42703` (column does not exist), wodurch der
Bot-Tipp auf dem Dashboard nie geladen wurde.

### Tatsaechliches DB-Schema

| Spalte | Typ | Beschreibung |
|---|---|---|
| id | uuid | Primary Key |
| message_type | text | z.B. 'daily_tip' |
| title | text | Titel der Nachricht |
| **content** | text | Nachrichteninhalt (NICHT message_content) |
| target_audience | text | Zielgruppe (NICHT user_id) |
| scheduled_for | timestamptz | Geplanter Zeitpunkt |
| sent_at | timestamptz | Tatsaechlicher Sendezeitpunkt |
| **status** | text | 'pending', 'sent', etc. (NICHT sent boolean) |
| created_by | uuid | Ersteller |
| created_at | timestamptz | Erstellungszeitpunkt |

### Fix (useDashboard.ts Zeile 105-111)

```ts
// NACHHER (korrekt):
// [11] Bot tip – columns: content (not message_content), status (not sent), no user_id column
supabase.from('bot_scheduled_messages')
  .select('content')
  .eq('status', 'pending')
  .eq('message_type', 'daily_tip')
  .order('created_at', { ascending: false })
  .limit(1)
```

**Aenderungen:**
- `message_content` -> `content`
- `sent = false` -> `status = 'pending'`
- `user_id`-Filter entfernt (Spalte existiert nicht, Bot-Tipps sind global)

## 2. Tiere-Modul (animals/page.tsx) -- KEIN FIX NOETIG

### Pruefung

Die `AnimalStatusWidget` laedt Posts mit:
```ts
.or('type.eq.animal,and(type.in.(rescue,crisis),category.eq.animals)')
```

Das `ModulePage`-Pattern wird mit passendem `moduleFilter` aufgerufen:
```ts
moduleFilter={[
  { type: 'animal' },
  { type: 'rescue', categories: ['animals'] },
  { type: 'crisis', categories: ['animals'] },
]}
```

**Ergebnis:** Die Logik ist korrekt. Posts vom Typ `animal` werden immer angezeigt,
`rescue` und `crisis` nur wenn die Kategorie `animals` ist. Kein Bug gefunden.

### ModuleFilterRule-System

Das `ModuleFilterRule`-Interface in `ModulePage.tsx` stellt sicher, dass Posts
nur in den Modulen erscheinen, zu denen sie gehoeren:

```ts
export interface ModuleFilterRule {
  type: string
  categories?: string[]  // wenn leer, passt JEDER Post dieses Typs
}
```

Ein Post wird angezeigt, wenn mindestens eine Regel zutrifft:
1. `post.type === rule.type`
2. Wenn `rule.categories` definiert: `rule.categories.includes(post.category)`

## 3. Wohnen-Modul (housing/page.tsx) -- KEIN FIX NOETIG

### Pruefung

Die `HousingSplitView` laedt zwei separate Listen:
- **Angebote:** `type = 'housing'`
- **Gesuche:** `type IN ('rescue', 'crisis')` AND `category IN ('housing', 'moving', 'everyday', 'emergency')`

Das `ModulePage`-Pattern filtert ebenfalls korrekt:
```ts
moduleFilter={[
  { type: 'housing' },
  { type: 'rescue', categories: ['housing', 'moving', 'everyday'] },
  { type: 'crisis', categories: ['housing', 'moving', 'emergency'] },
]}
```

**Ergebnis:** Die `HousingSplitView` hat eigene Queries (nicht dieselben wie `ModulePage`),
was potenziell doppelte Posts verursachen koennte -- aber durch die Tab-Struktur
(die SplitView ist ein zusaetzliches Widget oberhalb der normalen Post-Liste)
stoert dies nicht. Kein Fix noetig.

## Betroffene Dateien

| Datei | Aenderung |
|---|---|
| `src/app/dashboard/hooks/useDashboard.ts` | bot_scheduled_messages Query korrigiert |
| `src/app/dashboard/animals/page.tsx` | Verifiziert, kein Fix |
| `src/app/dashboard/housing/page.tsx` | Verifiziert, kein Fix |
| `src/components/shared/ModulePage.tsx` | moduleFilter-System dokumentiert |

## Navigation-Relevanz

- **Tiere:** `navGroups[2].items[0]` -> `/dashboard/animals` (Gemeinschaft-Gruppe)
- **Wohnen:** `navGroups[1].items[0]` -> `/dashboard/housing` (Versorgung & Alltag)
- **Dashboard:** `mainNavItems[0]` -> `/dashboard` (Hauptmenue)

Alle Pfade sind in `navigationConfig.ts` korrekt definiert.

## AI_CONTEXT.md-Aenderung

Zur Vermeidung kuenftiger Spalten-Fehler wurde das Schema von `bot_scheduled_messages`
in AI_CONTEXT.md mit einer ACHTUNG-Zeile versehen:
```
bot_scheduled_messages[...] ACHTUNG: KEIN user_id, KEIN sent, KEIN message_content
```
