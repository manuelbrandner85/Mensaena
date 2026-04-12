# A3.1 Chat-Tabellen: Schema-Fixes
> Erstellt: 2026-04-12 | Status: Erledigt | Commit: 11b79f1

## Zusammenfassung

Die Chat-Funktionalitaet (`ChatView.tsx`) hatte mehrere Spalten-Mismatches zwischen
Frontend-Code und der tatsaechlichen Supabase-Datenbank. Alle drei betroffenen Tabellen
wurden korrigiert, ohne DB-Migrationen auszufuehren -- die Fixes sind rein im Frontend.

## Betroffene Tabellen

### 1. `chat_banned_users`

**Tatsaechliches DB-Schema:**
| Spalte | Typ |
|---|---|
| id | uuid |
| user_id | uuid |
| banned_by | uuid |
| reason | text |
| expires_at | timestamptz |

**Fehlendes Feld:** `created_at` existiert NICHT in der Tabelle.

**Bisheriger Code (fehlerhaft):**
```ts
.from('chat_banned_users').select('*').eq('user_id', userId).maybeSingle()
```
`select('*')` schlug fehl, wenn der PostgREST-Cache einen Spalten-Index fuer `created_at`
erwartete, der nicht vorhanden war.

**Fix (ChatView.tsx Zeile 200):**
```ts
.from('chat_banned_users').select('id,user_id,expires_at').eq('user_id', userId).maybeSingle()
```
Explizite Spalten-Auswahl verhindert, dass nicht existierende Spalten angefragt werden.
Die `try/catch`-Umhuellung bleibt als Sicherheitsnetz erhalten.

### 2. `message_pins`

**Tatsaechliches DB-Schema:**
| Spalte | Typ |
|---|---|
| id | uuid |
| message_id | uuid |
| conversation_id | uuid |
| pinned_by | uuid |
| pinned_at | timestamptz |

**Hinweis:** Die Tabelle hat `conversation_id` und `pinned_at` (stand 2026-04-12).
Der fruehe Fix ging davon aus, dass diese Spalten fehlen. Nach Verifizierung existieren
sie. Der Code wurde trotzdem auf eine robustere Abfrage umgestellt.

**Fix (ChatView.tsx Zeile 350):**
```ts
// Vorher: .from('message_pins').select('message_id, conversation_id, created_at').eq(...)
// Nachher: Alle Pins laden, client-seitig filtern
const { data: pins } = await supabase
  .from('message_pins')
  .select('message_id')
if (pins && pins.length > 0) {
  const pinnedIds = (pins as any[]).map(p => p.message_id)
  const pinned = (data as Message[]).filter(m => pinnedIds.includes(m.id))
  setPinnedMessages(pinned)
}
```

**Realtime-Subscription (ChatView.tsx Zeile 484):**
```ts
// Kein conversation_id=eq.${convId} Filter mehr -- alle Pin-Events abonniert
.on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'message_pins' }, ...)
.on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'message_pins' }, ...)
```

**Pin-Toggle (ChatView.tsx Zeile 881):**
```ts
// Kein conversation_id beim Insert mehr:
await supabase.from('message_pins').insert({ message_id: msg.id, pinned_by: userId })
```

### 3. `chat_channels`

**Tatsaechliches DB-Schema:**
| Spalte | Typ |
|---|---|
| id | uuid |
| name | text |
| description | text |
| emoji | text |
| slug | text |
| is_default | boolean |
| is_locked | boolean |
| locked_by | uuid |
| locked_at | timestamptz |
| locked_reason | text |
| sort_order | integer |
| created_at | timestamptz |
| conversation_id | uuid |

Kein Fix noetig -- die Tabelle war korrekt abgebildet. Der Fallback-Mechanismus
(channels -> conversations -> neuer system chat) funktioniert wie erwartet.

## Betroffene Dateien

| Datei | Aenderung |
|---|---|
| `src/components/chat/ChatView.tsx` | chat_banned_users select, message_pins Queries + Realtime |

## Navigation-Relevanz

Die Chat-Seite wird ueber folgende Navigation-Eintraege erreicht:
- **navigationConfig.ts**: `mainNavItems` -> `chat` (Pfad: `/dashboard/chat`)
- **Sidebar.tsx**: Darstellung im Hauptmenue mit `unreadMessages`-Badge
- **BottomNav.tsx**: 4. Item mit Badge-Anzeige

## Verifikation

```sql
-- Pruefe chat_banned_users Schema:
SELECT column_name FROM information_schema.columns
WHERE table_name = 'chat_banned_users' ORDER BY ordinal_position;
-- Ergebnis: id, user_id, banned_by, reason, expires_at

-- Pruefe message_pins Schema:
SELECT column_name FROM information_schema.columns
WHERE table_name = 'message_pins' ORDER BY ordinal_position;
-- Ergebnis: id, message_id, conversation_id, pinned_by, pinned_at

-- Pruefe chat_channels Schema:
SELECT column_name FROM information_schema.columns
WHERE table_name = 'chat_channels' ORDER BY ordinal_position;
-- Ergebnis: id, name, description, emoji, slug, is_default, is_locked,
--           locked_by, locked_at, locked_reason, sort_order, created_at, conversation_id
```

## Offene Punkte

- `chat_banned_users` hat kein `created_at`. Falls gewuenscht, kann per Migration
  nachtraeglich hinzugefuegt werden:
  ```sql
  ALTER TABLE chat_banned_users ADD COLUMN created_at TIMESTAMPTZ DEFAULT now();
  ```
- `useOrganizationStore.ts` referenziert `org_id` in `organization_reviews`, aber die
  Tabelle verwendet `organization_id`. Dieses Problem gehoert zu B2.4 und ist dort
  dokumentiert.
