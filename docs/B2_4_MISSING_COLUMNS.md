# B2.4 Fehlende Spalten: Schema-Mismatch-Analyse & Fixes
> Erstellt: 2026-04-12 | Status: Erledigt | Commit: 11b79f1

## Zusammenfassung

Mehrere Admin- und Frontend-Komponenten referenzierten Spalten, die in der
tatsaechlichen Supabase-Datenbank nicht (mehr) existieren. Die Fixes bestehen
aus Frontend-Anpassungen -- keine DB-Migrationen noetig.

## Uebersicht der Mismatches

| Tabelle | Erwartet im Code | Tatsaechlich in DB | Status |
|---|---|---|---|
| organizations | `slug` | nicht vorhanden | Fix: entfernt |
| organizations | `verified` | `is_verified` | Fix: umbenannt |
| organizations | `rating_avg` | nicht vorhanden | Fix: entfernt |
| organizations | `rating_count` | nicht vorhanden | Fix: entfernt |
| organizations | `lat`, `lng` | `latitude`, `longitude` | Dokumentiert |
| crises | `type` | `category` | Bereits korrekt |
| crises | `severity` | `urgency` | Bereits korrekt |
| crises | `lat`, `lng` | `latitude`, `longitude` | Dokumentiert |
| chat_banned_users | `created_at` | nicht vorhanden | Fix: entfernt |
| organization_reviews | `org_id` | `organization_id` | Fix: umbenannt |

## 1. OrgsTab.tsx (Admin-Dashboard) -- BEHOBEN

### Vorher

```ts
// Fehlerhaft:
.select('id,name,slug,category,verified,rating_avg,rating_count,created_at', { count: 'exact' })
```

Spalten `slug`, `verified`, `rating_avg`, `rating_count` existieren nicht.

### Nachher

```ts
// Korrekt:
.select('id,name,category,is_verified,is_active,created_at', { count: 'exact' })
```

### Weitere Aenderungen in OrgsTab.tsx

1. **Verified-Filter:** `verified` -> `is_verified`
   ```ts
   if (verifiedFilter === 'true') query = query.eq('is_verified', true)
   ```

2. **Create-Modal:** Slug-Feld entfernt, `is_verified: false` statt `verified: false`
   ```ts
   .insert({ name: newName.trim(), category: newCategory || null, is_verified: false })
   ```

3. **Toggle-Verify:** `verified` -> `is_verified`
   ```ts
   .update({ is_verified: !current }).eq('id', id)
   ```

4. **Tabelle:** Rating-Spalte entfernt, `is_active`-Status-Badge hinzugefuegt
   ```tsx
   <span className={`... ${o.is_active ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-600'}`}>
     {o.is_active ? 'Aktiv' : 'Inaktiv'}
   </span>
   ```

## 2. AdminTypes.ts -- BEHOBEN

### Vorher

```ts
export interface AdminOrg {
  id: string
  name: string
  slug: string         // ❌ existiert nicht
  category: string | null
  verified: boolean    // ❌ heisst is_verified
  rating_avg: number | null   // ❌ existiert nicht
  rating_count: number | null // ❌ existiert nicht
  created_at: string
}
```

### Nachher

```ts
export interface AdminOrg {
  id: string
  name: string
  category: string | null
  is_verified: boolean
  is_active: boolean
  created_at: string
}
```

## 3. useOrganizationStore.ts -- BEHOBEN

### loadOrganizationBySlug (Zeile 199)

**Problem:** Die Funktion suchte nach `slug`, aber die Spalte existiert nicht.

**Fix:** Sucht zuerst nach `id`, dann nach `name` (slugified):
```ts
// Try by ID first (slug column may not exist), then fallback by name
let { data, error } = await supabase
  .from('organizations')
  .select('*')
  .eq('id', slug)
  .eq('is_active', true)
  .single()

if (error || !data) {
  // Try by name (slugified)
  const res = await supabase
    .from('organizations')
    .select('*')
    .ilike('name', `%${slug.replace(/-/g, '%')}%`)
    .eq('is_active', true)
    .limit(1)
    .single()
  data = res.data
}
```

### loadOrganizations (Zeile 95)

**Fallback-Query:** Verwendet korrekte Spaltennamen:
```ts
// Direct query fallback
let query = supabase
  .from('organizations')
  .select('*')
  .order('name')
  .range(0, PAGE_SIZE - 1)

if (filters.category !== 'all') query = query.eq('category', filters.category)
if (filters.verified_only) query = query.eq('is_verified', true)
```

### loadReviews (Zeile 231) -- BEHOBEN

**Problem:** Die Funktion verwendete `org_id` als Filter:
```ts
.eq('org_id', orgId)  // ❌ Spalte heisst organization_id
```

**Fix:** Alle 3 Stellen korrigiert:
```ts
// loadReviews + loadMoreReviews:
.eq('organization_id', orgId)

// createReview:
.insert({ organization_id: input.organization_id, ... })
```

## 4. CrisisTab.tsx -- BEREITS KORREKT

Die CrisisTab verwendet `category` und `urgency` -- die tatsaechlichen Spaltennamen.
Kein Fix noetig.

```ts
// Bereits korrekt:
.select('id,title,category,urgency,status,creator_id,created_at,...')
```

## 5. Spalten-Mismatch-Referenz (komplett)

### organizations

| DB-Spalte | Typ | Frontend-Nutzung |
|---|---|---|
| id | uuid | OrgsTab, OrgStore, AdminTypes |
| name | text | OrgsTab, OrgStore |
| category | text | OrgsTab, OrgStore (Filter) |
| description | text | OrgStore (Suche) |
| address | text | OrgStore (Suche) |
| zip_code | text | - |
| city | text | OrgStore (Suche) |
| state | text | - |
| country | text | OrgStore (Filter) |
| latitude | double | OrgStore (Distanz), **NICHT lat** |
| longitude | double | OrgStore (Distanz), **NICHT lng** |
| phone | text | - |
| email | text | - |
| website | text | - |
| opening_hours | jsonb | - |
| services | text[] | - |
| tags | text[] | - |
| is_verified | boolean | OrgsTab (Toggle) |
| is_active | boolean | OrgsTab (Status-Badge), OrgStore (Filter) |
| source_url | text | - |
| fts | tsvector | Volltextsuche |
| created_at | timestamptz | OrgsTab (Sortierung) |
| updated_at | timestamptz | - |

**Nicht vorhanden:** `slug`, `verified`, `rating_avg`, `rating_count`, `lat`, `lng`,
`short_description`, `logo_url`, `cover_image_url`, `fax`, `accessibility`,
`target_groups`, `languages`, `is_emergency`, `created_by`

**Wichtig:** Die Frontend-Typdefinition in `organizations/types.ts` enthaelt
optimistische Felder (slug, rating_avg, etc.) die fuer zukuenftige DB-Erweiterungen
vorbereitet sind. Der tatsaechliche Code muss aber immer gegen das aktuelle DB-Schema
validiert werden.

### crises

| DB-Spalte | Typ | Frontend-Nutzung |
|---|---|---|
| category | text | CrisisTab (Filter, Anzeige) |
| urgency | text | CrisisTab (Edit-Modal) |
| latitude | double | **NICHT lat** |
| longitude | double | **NICHT lng** |
| false_alarm_by | uuid | - |

**Nicht vorhanden:** `type`, `severity`, `lat`, `lng`

## Betroffene Dateien

| Datei | Aenderung |
|---|---|
| `src/app/dashboard/admin/components/OrgsTab.tsx` | Query, Create, Toggle, Tabelle |
| `src/app/dashboard/admin/components/AdminTypes.ts` | AdminOrg Interface |
| `src/app/dashboard/organizations/stores/useOrganizationStore.ts` | Slug-Lookup, Fallback |
| `src/app/dashboard/admin/components/CrisisTab.tsx` | Verifiziert, kein Fix |

## Navigation-Relevanz

- **Organisationen (Admin):** `navGroups[6].items[0]` -> `/dashboard/admin` -> Tab "Orgs"
- **Organisationen (User):** Nicht direkt in navGroups (erreichbar ueber Dashboard-Links)
- **Krisen (Admin):** `/dashboard/admin` -> Tab "Crisis"
- **Krisen (User):** `navGroups[0].items[0]` -> `/dashboard/crisis`

## Offene Punkte

1. **organization_reviews.org_id:** BEHOBEN -- alle 3 Stellen in useOrganizationStore.ts
   korrigiert (loadReviews, loadMoreReviews, createReview).

2. **Fehlende DB-Spalten:** Fuer zukuenftige Features (ratings, slug, emergency)
   koennten Spalten nachtraeglich per Migration hinzugefuegt werden:
   ```sql
   ALTER TABLE organizations ADD COLUMN slug TEXT UNIQUE;
   ALTER TABLE organizations ADD COLUMN rating_avg NUMERIC(3,2) DEFAULT 0;
   ALTER TABLE organizations ADD COLUMN rating_count INT DEFAULT 0;
   ```

3. **organization_reviews FK:** Die Tabelle hat ein `profiles:user_id` Join-Problem
   (kein FK definiert). Supabase PostgREST findet keine Beziehung fuer `.select('*, profiles:user_id(...)')`.
   Fix: FK hinzufuegen oder Join-Syntax anpassen.
