// ════════════════════════════════════════════════════════════════════════
// admin-dev-agent — Code-Agent aus dem Admin-Dashboard.
//
// Ein Admin formuliert eine Aufgabe (Feature, Bugfix, UI/UX, Konfiguration),
// optional mit Screenshots (Vision). Diese Function:
//   1. verifiziert role='admin' (NICHT moderator),
//   2. legt eine Zeile in admin_dev_tasks an (status='queued'),
//   3. triggert die GitHub Action `admin_agent.yml` via workflow_dispatch.
//
// Weitere Aktionen (body.action):
//   • 'delete' { id }   — einzelnen Auftrag löschen
//   • 'clear'           — alle abgeschlossenen Auftragszeilen löschen
//   • 'cancel' { id }   — laufenden Auftrag abbrechen (Workflow + PR)
//   • 'merge'  { id }   — wartenden Auftrag (await_review) freigeben & mergen
//   • 'diff'   { id }   — Diff/geänderte Dateien des PRs zurückgeben
//
// Secrets (Supabase Project Secrets, NIEMALS in GitHub):
//   GH_AGENT_TOKEN  — fine-grained PAT (contents:write, pull-requests:write,
//                     actions:write) auf manuelbrandner85/Mensaena.
// ════════════════════════════════════════════════════════════════════════
import { CORS, json, getUser, adminClient } from '../_shared/util.ts'
import { callAiChain, parseAiJson } from '../_shared/ai.ts'

const GH_OWNER = 'manuelbrandner85'
const GH_REPO = 'Mensaena'
const GH_WORKFLOW = 'admin_agent.yml'
const GH_ROLLBACK_WORKFLOW = 'admin_rollback.yml'
const GH_REF = 'main'
const GH_API = `https://api.github.com/repos/${GH_OWNER}/${GH_REPO}`

// Berechnet den nächsten Lauf-Zeitpunkt (UTC) für einen Schedule.
// deno-lint-ignore no-explicit-any
function computeNextRun(s: any): string {
  const now = new Date()
  const next = new Date(Date.UTC(
    now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(),
    Number(s.hour_utc ?? 6), 0, 0, 0,
  ))
  const cadence = String(s.cadence ?? 'weekly')
  if (cadence === 'daily') {
    if (next <= now) next.setUTCDate(next.getUTCDate() + 1)
  } else if (cadence === 'weekly') {
    const target = Number(s.day_of_week ?? 1) // 0=So..6=Sa
    let delta = (target - next.getUTCDay() + 7) % 7
    if (delta === 0 && next <= now) delta = 7
    next.setUTCDate(next.getUTCDate() + delta)
  } else { // monthly
    const dom = Math.min(Math.max(Number(s.day_of_month ?? 1), 1), 28)
    next.setUTCDate(dom)
    if (next <= now) next.setUTCMonth(next.getUTCMonth() + 1, dom)
  }
  return next.toISOString()
}

function ghHeaders(token: string): HeadersInit {
  return {
    'Authorization': `Bearer ${token}`,
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'Content-Type': 'application/json',
    'User-Agent': 'mensaena-admin-dev-agent',
  }
}

// run_id aus einer Actions-Run-URL extrahieren (…/actions/runs/<id>).
function runIdFromUrl(url: string | null | undefined): string | null {
  if (!url) return null
  const m = String(url).match(/\/runs\/(\d+)/)
  return m ? m[1] : null
}

type Phase = { title: string; instruction: string }

// ── Auto-Phasen: zerlegt einen zu großen Auftrag in unabhängige Phasen ──
// Liefert {single:true} wenn ein PR reicht, sonst {single:false, phases:[…]}.
// Jede Phase MUSS für sich kompilieren + CI grün bekommen (sonst merged Phase 1
// kaputten Code). Bei Planner-Fehler → sicherer Fallback auf ein PR.
async function planPhases(
  instruction: string,
): Promise<{ single: true } | { single: false; phases: Phase[] }> {
  const sys = `Du bist ein Senior-Softwarearchitekt für die Flutter-App Mensaena.
Beurteile, ob die Aufgabe des Admins in EINEM Pull Request umsetzbar ist oder
ob sie zu groß ist und in mehrere Phasen zerlegt werden sollte.

REGELN:
- Zerlege NUR, wenn die Aufgabe wirklich groß ist (mehrere Screens/Module,
  Datenmodell + UI + Übersetzungen + Logik zusammen). Kleine und mittlere
  Aufgaben bleiben EIN PR.
- Wenn du zerlegst: 2 bis 5 Phasen. JEDE Phase MUSS für sich allein
  kompilieren und das CI grün bekommen — die App bleibt nach jeder Phase
  lauffähig. NIEMALS eine Phase, die ohne die nächste kaputten Code merged.
- Jede Phase ist eine eigenständige, vollständige Handlungsanweisung in
  natürlicher deutscher Sprache (so wie der Admin sie formuliert hätte).
- Reihenfolge logisch aufbauend (z. B. erst Datenmodell+Migration, dann
  Repository/Provider, dann UI, dann Feinschliff/Übersetzungen).

Antworte AUSSCHLIESSLICH als JSON:
- Wenn ein PR reicht:  {"single": true}
- Wenn Phasen nötig:   {"single": false, "phases": [{"title": "...", "instruction": "..."}, ...]}`
  try {
    const { text } = await callAiChain(sys, instruction, {
      jsonMode: true, timeoutMs: 22_000,
    })
    const parsed = parseAiJson<{ single?: boolean; phases?: Phase[] }>(text ?? '')
    if (!parsed || parsed.single === true || !Array.isArray(parsed.phases)) {
      return { single: true }
    }
    const phases = parsed.phases
      .map((p) => ({
        title: String(p?.title ?? '').slice(0, 120).trim(),
        instruction: String(p?.instruction ?? '').slice(0, 2000).trim(),
      }))
      .filter((p) => p.instruction.length > 4)
      .slice(0, 5)
    if (phases.length < 2) return { single: true }
    return { single: false, phases }
  } catch {
    return { single: true }
  }
}

// Baut die finale Instruction für eine einzelne Phase (mit Kontext zu den
// bereits gemergten Vorphasen, damit der Agent nicht doppelt arbeitet).
function buildPhaseInstruction(baseTitle: string, phases: Phase[], idx: number): string {
  const total = phases.length
  const prior = phases.slice(0, idx)
    .map((x, i) => `  ${i + 1}. ${x.title} (bereits erledigt & in main gemergt)`)
    .join('\n')
  const priorBlock = idx > 0
    ? `\n\nBereits abgeschlossene Phasen (Code ist schon im main):\n${prior}`
    : ''
  return `Dies ist Phase ${idx + 1} von ${total} eines größeren Auftrags („${baseTitle}").` +
    priorBlock +
    `\n\nSetze JETZT NUR diese Phase um — nicht mehr, nicht weniger:\n${phases[idx].instruction}` +
    `\n\nWICHTIG: Die App MUSS nach dieser Phase kompilieren und das CI grün sein. ` +
    `Liefere ausschließlich den Code für genau diese Phase.`
}

// Legt einen Phase-Child-Task an und dispatcht admin_agent.yml dafür.
// deno-lint-ignore no-explicit-any
async function dispatchPhase(
  admin: any, token: string, parentId: string, createdBy: string,
  baseTitle: string, phases: Phase[], idx: number,
  imageUrls: string[], awaitReview: boolean,
): Promise<{ ok: boolean; childId?: string; error?: string }> {
  const instr = buildPhaseInstruction(baseTitle, phases, idx)
  const imgs = idx === 0 ? imageUrls : []
  const { data: child, error } = await admin
    .from('admin_dev_tasks')
    .insert({
      created_by: createdBy,
      instruction: instr,
      status: 'queued',
      image_urls: imgs,
      await_review: awaitReview,
      origin: 'phase',
      parent_task_id: parentId,
      plan: { phase_index: idx, phase_total: phases.length, phase_title: phases[idx].title },
    })
    .select('id').single()
  if (error || !child) return { ok: false, error: error?.message }

  const res = await fetch(
    `${GH_API}/actions/workflows/${GH_WORKFLOW}/dispatches`,
    {
      method: 'POST', headers: ghHeaders(token),
      body: JSON.stringify({
        ref: GH_REF,
        inputs: { instruction: instr, task_id: child.id, image_urls: JSON.stringify(imgs) },
      }),
    },
  )
  if (res.status !== 204) {
    const detail = await res.text().catch(() => '')
    await admin.from('admin_dev_tasks').update({
      status: 'failed', error: `dispatch ${res.status}: ${detail.slice(0, 300)}`,
      updated_at: new Date().toISOString(),
    }).eq('id', child.id)
    return { ok: false, childId: child.id, error: `dispatch_${res.status}` }
  }
  return { ok: true, childId: child.id }
}

// next_phase: wird von agent_automerge.yml nach dem Merge eines Tasks gerufen.
// Ist der gemergte Task ein Phase-Child → nächste Phase dispatchen (oder den
// Parent finalisieren). Bei Einzel-Aufträgen passiert nichts (chained:false).
// deno-lint-ignore no-explicit-any
async function handleNextPhase(admin: any, token: string, body: any): Promise<Response> {
  const mergedId = String(body?.task_id ?? '')
  if (!mergedId) return json({ error: 'task_id_required' }, 400)
  if (!token) return json({ error: 'agent_not_configured' }, 503)

  const { data: merged } = await admin.from('admin_dev_tasks')
    .select('id, parent_task_id, plan, created_by').eq('id', mergedId).maybeSingle()
  if (!merged || !merged.parent_task_id) return json({ ok: true, chained: false })

  const { data: parent } = await admin.from('admin_dev_tasks')
    .select('id, instruction, plan, created_by, image_urls, await_review')
    .eq('id', merged.parent_task_id).maybeSingle()
  if (!parent || !parent.plan?.phases) return json({ ok: true, chained: false })

  const phases = (parent.plan.phases as Phase[]) ?? []
  const doneIdx = Number(merged.plan?.phase_index ?? -1)
  const nextIdx = doneIdx + 1

  if (nextIdx >= phases.length) {
    await admin.from('admin_dev_tasks').update({
      status: 'merged',
      summary: `Alle ${phases.length} Phasen ausgeliefert.`,
      plan: { ...parent.plan, current: phases.length },
      updated_at: new Date().toISOString(),
    }).eq('id', parent.id)
    return json({ ok: true, chained: false, completed: true })
  }

  const baseTitle = String(parent.instruction ?? '').slice(0, 120)
  const r = await dispatchPhase(
    admin, token, parent.id, String(parent.created_by ?? merged.created_by),
    baseTitle, phases, nextIdx,
    Array.isArray(parent.image_urls) ? parent.image_urls : [],
    parent.await_review === true,
  )
  if (!r.ok) return json({ error: 'phase_dispatch_failed', detail: r.error }, 502)

  await admin.from('admin_dev_tasks').update({
    status: 'phased',
    summary: `Phase ${nextIdx + 1}/${phases.length} gestartet: ${phases[nextIdx].title}`,
    plan: { ...parent.plan, current: nextIdx },
    updated_at: new Date().toISOString(),
  }).eq('id', parent.id)

  return json({ ok: true, chained: true, phase: nextIdx + 1, total: phases.length })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const body = await req.json().catch(() => ({}))
  const action = String(body?.action ?? 'create')
  const token = Deno.env.get('GH_AGENT_TOKEN') ?? ''
  const admin = adminClient()

  // ── Service-to-Service: Phasen-Verkettung (von agent_automerge.yml) ───────
  // Authentifiziert via Service-Role-Key statt User-JWT, weil ein GitHub-
  // Workflow kein Admin-User ist. NUR 'next_phase' ist so erreichbar.
  if (action === 'next_phase') {
    const authHeader = req.headers.get('Authorization') ?? ''
    const srk = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    if (!srk || authHeader !== `Bearer ${srk}`) return json({ error: 'forbidden' }, 403)
    return await handleNextPhase(admin, token, body)
  }

  // ── Ab hier: User-authentifizierte Admin-Aktionen ─────────────────────────
  const user = await getUser(req)
  if (!user) return json({ error: 'unauthorized' }, 401)

  // ── Nur Admins (kein moderator) ──────────────────────────────────────────
  const { data: prof } = await admin
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!prof || prof.role !== 'admin') return json({ error: 'forbidden' }, 403)

  // Abgeschlossene Zustände — nur diese dürfen gelöscht werden.
  const DONE_STATES = ['merged', 'failed', 'no_changes', 'cancelled']

  // ── Auftrag(e) löschen ─────────────────────────────────────────────────────
  if (action === 'delete') {
    const id = String(body?.id ?? '')
    if (!id) return json({ error: 'id_required' }, 400)
    const { error } = await admin.from('admin_dev_tasks').delete().eq('id', id)
    if (error) return json({ error: 'delete_failed', detail: error.message }, 500)
    return json({ ok: true, deleted: 1 })
  }

  if (action === 'clear') {
    const { data, error } = await admin
      .from('admin_dev_tasks')
      .delete()
      .in('status', DONE_STATES)
      .select('id')
    if (error) return json({ error: 'clear_failed', detail: error.message }, 500)
    return json({ ok: true, deleted: (data?.length ?? 0) })
  }

  // ── Notizen / Backlog ────────────────────────────────────────────────────
  if (action === 'notes_list') {
    const { data, error } = await admin
      .from('admin_dev_notes')
      .select('id, content, created_at, updated_at')
      .order('updated_at', { ascending: false })
      .limit(100)
    if (error) return json({ error: 'notes_failed', detail: error.message }, 500)
    return json({ ok: true, notes: data ?? [] })
  }

  if (action === 'note_save') {
    const content = String(body?.content ?? '').trim().slice(0, 4000)
    if (content.length < 2) return json({ error: 'content_required' }, 400)
    const id = body?.id ? String(body.id) : null
    if (id) {
      const { error } = await admin.from('admin_dev_notes')
        .update({ content, updated_at: new Date().toISOString() })
        .eq('id', id)
      if (error) return json({ error: 'note_update_failed', detail: error.message }, 500)
      return json({ ok: true, id })
    }
    const { data, error } = await admin.from('admin_dev_notes')
      .insert({ created_by: user.id, content })
      .select('id').single()
    if (error || !data) return json({ error: 'note_insert_failed', detail: error?.message }, 500)
    return json({ ok: true, id: data.id })
  }

  if (action === 'note_delete') {
    const id = String(body?.id ?? '')
    if (!id) return json({ error: 'id_required' }, 400)
    const { error } = await admin.from('admin_dev_notes').delete().eq('id', id)
    if (error) return json({ error: 'note_delete_failed', detail: error.message }, 500)
    return json({ ok: true, deleted: 1 })
  }

  // ── Roadmap / Epics ────────────────────────────────────────────────────────
  if (action === 'epic_save') {
    const title = String(body?.title ?? '').trim().slice(0, 120)
    if (title.length < 2) return json({ error: 'title_required' }, 400)
    const description = String(body?.description ?? '').trim().slice(0, 600) || null
    const allowedColors = ['teal', 'amber', 'herzrot', 'leben', 'trust']
    const color = allowedColors.includes(String(body?.color)) ? String(body.color) : 'teal'
    const allowedStatus = ['active', 'done', 'archived']
    const status = allowedStatus.includes(String(body?.status)) ? String(body.status) : 'active'
    const sortOrder = Number.isFinite(Number(body?.sort_order)) ? Number(body.sort_order) : 0
    const id = body?.id ? String(body.id) : null
    if (id) {
      const { error } = await admin.from('godmode_epics')
        .update({ title, description, color, status, sort_order: sortOrder })
        .eq('id', id)
      if (error) return json({ error: 'epic_update_failed', detail: error.message }, 500)
      return json({ ok: true, id })
    }
    const { data, error } = await admin.from('godmode_epics')
      .insert({ created_by: user.id, title, description, color, status, sort_order: sortOrder })
      .select('id').single()
    if (error || !data) return json({ error: 'epic_insert_failed', detail: error?.message }, 500)
    return json({ ok: true, id: data.id })
  }

  if (action === 'epic_delete') {
    const id = String(body?.id ?? '')
    if (!id) return json({ error: 'id_required' }, 400)
    // FK ist ON DELETE SET NULL → zugeordnete Aufträge/Vorschläge bleiben.
    const { error } = await admin.from('godmode_epics').delete().eq('id', id)
    if (error) return json({ error: 'epic_delete_failed', detail: error.message }, 500)
    return json({ ok: true, deleted: 1 })
  }

  // ── Health-/Metrics-Dashboard ─────────────────────────────────────────────
  if (action === 'metrics') {
    const { data: tasks } = await admin
      .from('admin_dev_tasks')
      .select('status, created_at, updated_at')
      .order('created_at', { ascending: false })
      .limit(500)
    const { data: sugs } = await admin
      .from('admin_dev_suggestions')
      .select('status')
      .limit(1000)

    const rows = tasks ?? []
    const byStatus: Record<string, number> = {}
    let mergedDurSum = 0, mergedDurCount = 0
    for (const t of rows) {
      const s = String(t.status ?? 'queued')
      byStatus[s] = (byStatus[s] ?? 0) + 1
      if (s === 'merged' && t.created_at && t.updated_at) {
        const d = (new Date(t.updated_at).getTime() - new Date(t.created_at).getTime()) / 1000
        if (d > 0 && d < 86400) { mergedDurSum += d; mergedDurCount++ }
      }
    }
    const total = rows.length
    const merged = byStatus['merged'] ?? 0
    const failed = (byStatus['failed'] ?? 0) + (byStatus['no_changes'] ?? 0)
    const finished = merged + failed + (byStatus['cancelled'] ?? 0)
    const successRate = finished > 0 ? Math.round((merged / finished) * 100) : 0
    const avgMergeMin = mergedDurCount > 0 ? Math.round(mergedDurSum / mergedDurCount / 60) : 0

    const sugRows = sugs ?? []
    const accepted = sugRows.filter((s) => s.status === 'accepted').length
    const rejected = sugRows.filter((s) => s.status === 'rejected').length

    return json({
      ok: true,
      metrics: {
        total, merged, failed,
        active: (byStatus['queued'] ?? 0) + (byStatus['running'] ?? 0) +
          (byStatus['pr_open'] ?? 0) + (byStatus['awaiting_review'] ?? 0),
        success_rate: successRate,
        avg_merge_minutes: avgMergeMin,
        suggestions_accepted: accepted,
        suggestions_rejected: rejected,
      },
    })
  }

  // ── Plan-Generierung (Multi-Step) ─────────────────────────────────────────
  // Zerlegt eine Aufgabe in eine nachvollziehbare Schritt-Liste (JSON).
  if (action === 'plan') {
    const instruction = String(body?.instruction ?? '').trim().slice(0, 4000)
    if (instruction.length < 5) return json({ error: 'instruction_required' }, 400)

    const sys = `Du bist ein Senior-Softwarearchitekt für die Flutter-App Mensaena.
Zerlege die Aufgabe des Admins in 2–6 konkrete, logisch aufeinander aufbauende
Umsetzungs-Schritte. Jeder Schritt ist eine kurze, prägnante deutsche
Handlungsanweisung (z. B. "Datenmodell erweitern", "UI-Karte bauen",
"Übersetzungen in 7 Sprachen ergänzen"). Keine Erklärungen, nur die Schritte.
Antworte AUSSCHLIESSLICH als JSON: {"steps":["Schritt 1","Schritt 2", ...]}`
    const { text } = await callAiChain(sys, instruction, {
      jsonMode: true, timeoutMs: 20_000,
    })
    const parsed = parseAiJson<{ steps?: string[] }>(text ?? '')
    const steps = Array.isArray(parsed?.steps)
      ? parsed!.steps.map((s) => String(s).slice(0, 200)).filter(Boolean).slice(0, 6)
      : []
    if (steps.length === 0) {
      return json({ ok: true, steps: [], fallback: true })
    }
    return json({ ok: true, steps })
  }

  // ── Wiederkehrende Aufträge (Schedules) ────────────────────────────────────
  if (action === 'schedules_list') {
    const { data, error } = await admin
      .from('admin_dev_schedules')
      .select('id, title, instruction, cadence, day_of_week, day_of_month, ' +
        'hour_utc, await_review, enabled, last_run_at, next_run_at, created_at')
      .order('created_at', { ascending: false })
      .limit(100)
    if (error) return json({ error: 'schedules_failed', detail: error.message }, 500)
    return json({ ok: true, schedules: data ?? [] })
  }

  if (action === 'schedule_save') {
    const title = String(body?.title ?? '').trim().slice(0, 200)
    const instruction = String(body?.instruction ?? '').trim().slice(0, 4000)
    if (title.length < 2 || instruction.length < 5) {
      return json({ error: 'fields_required' }, 400)
    }
    const row = {
      title,
      instruction,
      cadence: ['daily', 'weekly', 'monthly'].includes(String(body?.cadence))
        ? String(body.cadence) : 'weekly',
      day_of_week: Math.min(Math.max(Number(body?.day_of_week ?? 1), 0), 6),
      day_of_month: Math.min(Math.max(Number(body?.day_of_month ?? 1), 1), 28),
      hour_utc: Math.min(Math.max(Number(body?.hour_utc ?? 6), 0), 23),
      await_review: body?.await_review === true,
      enabled: body?.enabled !== false,
    }
    const next_run_at = computeNextRun(row)
    const id = body?.id ? String(body.id) : null
    if (id) {
      const { error } = await admin.from('admin_dev_schedules')
        .update({ ...row, next_run_at, updated_at: new Date().toISOString() })
        .eq('id', id)
      if (error) return json({ error: 'schedule_update_failed', detail: error.message }, 500)
      return json({ ok: true, id, next_run_at })
    }
    const { data, error } = await admin.from('admin_dev_schedules')
      .insert({ ...row, created_by: user.id, next_run_at })
      .select('id').single()
    if (error || !data) return json({ error: 'schedule_insert_failed', detail: error?.message }, 500)
    return json({ ok: true, id: data.id, next_run_at })
  }

  if (action === 'schedule_toggle') {
    const id = String(body?.id ?? '')
    if (!id) return json({ error: 'id_required' }, 400)
    const enabled = body?.enabled === true
    const { error } = await admin.from('admin_dev_schedules')
      .update({ enabled, updated_at: new Date().toISOString() })
      .eq('id', id)
    if (error) return json({ error: 'toggle_failed', detail: error.message }, 500)
    return json({ ok: true, enabled })
  }

  if (action === 'schedule_delete') {
    const id = String(body?.id ?? '')
    if (!id) return json({ error: 'id_required' }, 400)
    const { error } = await admin.from('admin_dev_schedules').delete().eq('id', id)
    if (error) return json({ error: 'schedule_delete_failed', detail: error.message }, 500)
    return json({ ok: true, deleted: 1 })
  }

  // ── Freie-API-Key-Verwaltung (Roh-Key wird NIE an Clients zurückgegeben) ──
  if (action === 'keys_list') {
    const { data, error } = await admin.from('godmode_api_keys')
      .select('service, label, expires_at, created_at')
      .order('service', { ascending: true })
    if (error) return json({ error: 'keys_list_failed', detail: error.message }, 500)
    return json({ ok: true, keys: data ?? [] })
  }
  if (action === 'key_set') {
    const service = String(body?.service ?? '').trim().toLowerCase().slice(0, 60)
    const apiKey = String(body?.api_key ?? '').trim().slice(0, 400)
    const label = body?.label ? String(body.label).slice(0, 120) : null
    const expiresAt = body?.expires_at ? String(body.expires_at) : null
    if (service.length < 2 || apiKey.length < 2) {
      return json({ error: 'service_and_key_required' }, 400)
    }
    const { error } = await admin.from('godmode_api_keys').upsert({
      service, api_key: apiKey, label, expires_at: expiresAt,
      updated_at: new Date().toISOString(),
    }, { onConflict: 'service' })
    if (error) return json({ error: 'key_set_failed', detail: error.message }, 500)
    return json({ ok: true })
  }
  if (action === 'key_delete') {
    const service = String(body?.service ?? '').trim().toLowerCase()
    if (!service) return json({ error: 'service_required' }, 400)
    const { error } = await admin.from('godmode_api_keys').delete().eq('service', service)
    if (error) return json({ error: 'key_delete_failed', detail: error.message }, 500)
    return json({ ok: true, deleted: 1 })
  }

  // ── Offenen PR per Folge-Anweisung nachbessern ────────────────────────────
  // Wendet eine zusätzliche Anweisung auf den BESTEHENDEN Branch eines offenen
  // Auftrags an (agent/task-<id>) → admin_agent_refine.yml. Kein neuer Task/PR.
  if (action === 'refine') {
    const id = String(body?.id ?? '')
    const instr = String(body?.instruction ?? '').trim().slice(0, 2000)
    if (!id || instr.length < 3) {
      return json({ error: 'id_and_instruction_required' }, 400)
    }
    if (!token) return json({ error: 'agent_not_configured' }, 503)

    const { data: t } = await admin.from('admin_dev_tasks')
      .select('id, status').eq('id', id).maybeSingle()
    if (!t) return json({ error: 'not_found' }, 404)
    if (!['pr_open', 'awaiting_review', 'running', 'phased'].includes(t.status)) {
      return json({ error: 'not_refinable' }, 409)
    }

    const res = await fetch(
      `${GH_API}/actions/workflows/admin_agent_refine.yml/dispatches`,
      {
        method: 'POST', headers: ghHeaders(token),
        body: JSON.stringify({
          ref: GH_REF,
          inputs: { task_id: id, instruction: instr },
        }),
      },
    )
    if (res.status !== 204) {
      const detail = await res.text().catch(() => '')
      return json({ error: 'dispatch_failed', status: res.status, detail: detail.slice(0, 300) }, 502)
    }
    await admin.from('admin_dev_tasks').update({
      status: 'running',
      summary: 'Nachbesserung läuft …',
      updated_at: new Date().toISOString(),
    }).eq('id', id)
    return json({ ok: true })
  }

  // ── Ein-Tap-Rollback ───────────────────────────────────────────────────────
  // Setzt eine gemergte Godmode-Änderung zurück: triggert admin_rollback.yml,
  // das den Merge-Commit per `git revert` rückgängig macht und einen PR öffnet
  // (der dann via agent_automerge bei grünem CI als OTA-Patch live geht).
  if (action === 'rollback') {
    const id = String(body?.id ?? '')
    if (!id) return json({ error: 'id_required' }, 400)
    if (!token) return json({ error: 'agent_not_configured' }, 503)

    const { data: t } = await admin.from('admin_dev_tasks')
      .select('id, status, merge_commit_sha, instruction').eq('id', id).maybeSingle()
    if (!t) return json({ error: 'not_found' }, 404)
    if (t.status !== 'merged') return json({ error: 'not_merged' }, 409)
    if (!t.merge_commit_sha) return json({ error: 'no_merge_commit' }, 409)

    // Neuen Rollback-Auftrag anlegen (eigene Zeile, origin='rollback').
    const { data: rb, error: rbErr } = await admin
      .from('admin_dev_tasks')
      .insert({
        created_by: user.id,
        instruction: `Rollback: macht "${String(t.instruction).slice(0, 200)}" rückgängig.`,
        status: 'queued',
        origin: 'rollback',
        parent_task_id: t.id,
      })
      .select('id').single()
    if (rbErr || !rb) return json({ error: 'insert_failed', detail: rbErr?.message }, 500)

    const res = await fetch(
      `${GH_API}/actions/workflows/${GH_ROLLBACK_WORKFLOW}/dispatches`,
      {
        method: 'POST', headers: ghHeaders(token),
        body: JSON.stringify({
          ref: GH_REF,
          inputs: { task_id: rb.id, sha: t.merge_commit_sha },
        }),
      },
    )
    if (res.status !== 204) {
      const detail = await res.text().catch(() => '')
      await admin.from('admin_dev_tasks')
        .update({ status: 'failed', error: `dispatch ${res.status}: ${detail.slice(0, 300)}`, updated_at: new Date().toISOString() })
        .eq('id', rb.id)
      return json({ error: 'dispatch_failed', status: res.status, detail: detail.slice(0, 300) }, 502)
    }
    return json({ ok: true, task_id: rb.id, status: 'queued' })
  }

  // ── Laufenden Auftrag abbrechen ──────────────────────────────────────────
  if (action === 'cancel') {
    const id = String(body?.id ?? '')
    if (!id) return json({ error: 'id_required' }, 400)
    if (!token) return json({ error: 'agent_not_configured' }, 503)

    const { data: t } = await admin.from('admin_dev_tasks')
      .select('id, status, run_url, pr_number').eq('id', id).maybeSingle()
    if (!t) return json({ error: 'not_found' }, 404)
    if (DONE_STATES.includes(t.status)) {
      return json({ error: 'already_done' }, 409)
    }

    // Laufenden Workflow-Run abbrechen (best-effort).
    const runId = runIdFromUrl(t.run_url)
    if (runId) {
      await fetch(`${GH_API}/actions/runs/${runId}/cancel`, {
        method: 'POST', headers: ghHeaders(token),
      }).catch(() => {})
    }
    // Offenen PR schließen (best-effort).
    if (t.pr_number) {
      await fetch(`${GH_API}/pulls/${t.pr_number}`, {
        method: 'PATCH', headers: ghHeaders(token),
        body: JSON.stringify({ state: 'closed' }),
      }).catch(() => {})
    }

    await admin.from('admin_dev_tasks').update({
      status: 'cancelled',
      summary: 'Vom Admin abgebrochen.',
      updated_at: new Date().toISOString(),
    }).eq('id', id)
    return json({ ok: true, status: 'cancelled' })
  }

  // ── Diff / geänderte Dateien des PRs ─────────────────────────────────────
  if (action === 'diff') {
    const id = String(body?.id ?? '')
    if (!id) return json({ error: 'id_required' }, 400)
    if (!token) return json({ error: 'agent_not_configured' }, 503)

    const { data: t } = await admin.from('admin_dev_tasks')
      .select('pr_number').eq('id', id).maybeSingle()
    if (!t || !t.pr_number) return json({ error: 'no_pr' }, 404)

    const res = await fetch(
      `${GH_API}/pulls/${t.pr_number}/files?per_page=100`,
      { headers: ghHeaders(token) },
    )
    if (!res.ok) return json({ error: 'diff_failed', status: res.status }, 502)
    // deno-lint-ignore no-explicit-any
    const files = (await res.json()) as any[]
    const out = files.slice(0, 60).map((f) => ({
      filename: String(f.filename ?? ''),
      status: String(f.status ?? ''),
      additions: Number(f.additions ?? 0),
      deletions: Number(f.deletions ?? 0),
      // Patch auf 8000 Zeichen begrenzen (große Dateien nicht voll laden).
      patch: f.patch ? String(f.patch).slice(0, 8000) : null,
    }))
    return json({ ok: true, pr_number: t.pr_number, files: out })
  }

  // ── Wartenden Auftrag freigeben & mergen (await_review) ──────────────────
  if (action === 'merge') {
    const id = String(body?.id ?? '')
    if (!id) return json({ error: 'id_required' }, 400)
    if (!token) return json({ error: 'agent_not_configured' }, 503)

    const { data: t } = await admin.from('admin_dev_tasks')
      .select('pr_number, status').eq('id', id).maybeSingle()
    if (!t || !t.pr_number) return json({ error: 'no_pr' }, 404)

    const res = await fetch(`${GH_API}/pulls/${t.pr_number}/merge`, {
      method: 'PUT', headers: ghHeaders(token),
      body: JSON.stringify({ merge_method: 'squash' }),
    })
    if (!res.ok) {
      const detail = await res.text().catch(() => '')
      return json({ error: 'merge_failed', status: res.status, detail: detail.slice(0, 300) }, 502)
    }
    // Merge-Commit-SHA für späteren Rollback merken.
    const mergeData = await res.json().catch(() => ({} as Record<string, unknown>))
    const sha = mergeData?.sha ? String(mergeData.sha) : null
    await admin.from('admin_dev_tasks').update({
      status: 'merged', ci_status: 'success', merge_commit_sha: sha,
      summary: `Manuell freigegeben & gemergt (PR #${t.pr_number}). OTA-Auslieferung läuft.`,
      updated_at: new Date().toISOString(),
    }).eq('id', id)
    // War das eine Phase eines größeren Auftrags? Dann nächste Phase anstoßen.
    // (Der manuelle Merge läuft nicht über agent_automerge.yml, daher hier.)
    try { await handleNextPhase(admin, token, { task_id: id }) } catch { /* best-effort */ }
    return json({ ok: true, status: 'merged' })
  }

  // ── Neuen Auftrag anlegen (default) ──────────────────────────────────────
  const instruction = String(body?.instruction ?? '').trim().slice(0, 4000)
  if (instruction.length < 5) return json({ error: 'instruction_required' }, 400)
  if (!token) return json({ error: 'agent_not_configured' }, 503)

  // Optionale Screenshots (Vision) + Review-Gate + Multi-Step-Plan.
  const imageUrls: string[] = Array.isArray(body?.image_urls)
    ? body.image_urls.map((x: unknown) => String(x)).filter(Boolean).slice(0, 6)
    : []
  const awaitReview = body?.await_review === true
  const wantScreens = body?.want_screens === true
  const planSteps: string[] = Array.isArray(body?.plan)
    ? body.plan.map((x: unknown) => String(x).slice(0, 200)).filter(Boolean).slice(0, 6)
    : []
  // Modellwahl pro Task: UI sendet eine Stufe, hier auf konkrete Modell-ID
  // gemappt (insuliert die App vor ID-Aenderungen). Leer = Action-Default.
  // Godmode arbeitet BEWUSST nur mit zwei Modellen (kein Haiku mehr) —
  // Sonnet 5 für Standard-Aufträge, Opus 4.8 für gründliche/komplexe.
  const MODEL_MAP: Record<string, string> = {
    standard: 'claude-sonnet-5',
    thorough: 'claude-opus-4-8',
  }
  // Standard ist IMMER Opus 4.8 (beste Qualität), solange der Admin nicht
  // bewusst 'standard' (Sonnet 5) wählt.
  const model = MODEL_MAP[String(body?.model ?? '')] ?? 'claude-opus-4-8'
  // Optionale Epic-Zuordnung (Roadmap). Leer = nicht zugeordnet.
  const epicId = body?.epic_id ? String(body.epic_id) : null

  // ── Auto-Phasen DEAKTIVIERT ───────────────────────────────────────────────
  // Früher zerlegte ein Planner große Aufträge in Phasen-Parents und dispatchte
  // nur Phase 1; die Folgephasen sollten via next_phase nachgekettet werden.
  // Das ist mehrfach hängengeblieben (status='phased', nie weiter) → Aufträge
  // erreichten die App NIE. Jeder Auftrag läuft jetzt als EIN PR durch (CI +
  // Auto-Merge + OTA sind dafür zuverlässig). KEINE Phasen mehr — egal welcher
  // Aufrufpfad (manuell, Vorschlag, Schedule, Autopilot). Das Flag no_split
  // bleibt aus Kompatibilität akzeptiert, ist aber faktisch immer aktiv.
  if (false) {
    const decision = await planPhases(instruction)
    if (!decision.single) {
      const { data: parent, error: pErr } = await admin
        .from('admin_dev_tasks')
        .insert({
          created_by: user.id,
          instruction,
          status: 'phased',
          image_urls: imageUrls,
          await_review: awaitReview,
          origin: ['manual', 'suggestion', 'schedule', 'rollback'].includes(String(body?.origin))
            ? String(body.origin) : 'manual',
          epic_id: epicId,
          model,
          plan: { phases: decision.phases, total: decision.phases.length, current: 0 },
        })
        .select('id').single()
      if (pErr || !parent) return json({ error: 'insert_failed', detail: pErr?.message }, 500)

      const r = await dispatchPhase(
        admin, token, parent.id, user.id, instruction.slice(0, 120),
        decision.phases, 0, imageUrls, awaitReview,
      )
      if (!r.ok) {
        await admin.from('admin_dev_tasks').update({
          status: 'failed', error: `phase1 dispatch: ${r.error}`,
          updated_at: new Date().toISOString(),
        }).eq('id', parent.id)
        return json({ error: 'phase_dispatch_failed', detail: r.error }, 502)
      }

      try {
        await admin.from('ai_admin_audit').insert({
          feature: 'dev_agent', actor_id: user.id, action: 'task_phased',
          target_type: 'admin_dev_tasks', target_id: parent.id,
          summary: `${decision.phases.length} Phasen: ${instruction.slice(0, 240)}`,
        })
      } catch { /* best-effort */ }

      return json({
        ok: true, task_id: parent.id, status: 'phased',
        phases: decision.phases.length,
      })
    }
  }

  // Wenn ein Plan vorliegt: hänge ihn an die Instruction (Agent arbeitet ihn ab).
  let finalInstruction = instruction
  if (planSteps.length > 0) {
    finalInstruction = `${instruction}\n\nArbeite diesen Plan strikt Schritt für Schritt ab:\n` +
      planSteps.map((s, i) => `${i + 1}. ${s}`).join('\n')
  }
  if (wantScreens) {
    finalInstruction += `\n\nWICHTIG (Screenshots): Wenn du UI-Dateien änderst, ` +
      `lege/aktualisiere für die wichtigste geänderte Komponente einen Golden-` +
      `Test unter flutter_app/test/golden/ an und führe ihn aus, damit ` +
      `Vorher/Nachher-Bilder als CI-Artefakt entstehen.`
  }

  const { data: task, error: insErr } = await admin
    .from('admin_dev_tasks')
    .insert({
      created_by: user.id,
      instruction: finalInstruction,
      status: 'queued',
      image_urls: imageUrls,
      await_review: awaitReview,
      origin: ['manual', 'suggestion', 'schedule', 'rollback'].includes(String(body?.origin))
        ? String(body.origin) : 'manual',
      epic_id: epicId,
      model,
      plan: planSteps.length > 0 ? planSteps : null,
    })
    .select('id')
    .single()

  if (insErr || !task) {
    return json({ error: 'insert_failed', detail: insErr?.message }, 500)
  }

  // ── GitHub Action triggern (workflow_dispatch) ─────────────────────────────
  try {
    const res = await fetch(
      `${GH_API}/actions/workflows/${GH_WORKFLOW}/dispatches`,
      {
        method: 'POST',
        headers: ghHeaders(token),
        body: JSON.stringify({
          ref: GH_REF,
          inputs: {
            instruction: finalInstruction,
            task_id: task.id,
            image_urls: JSON.stringify(imageUrls),
            model,
          },
        }),
      },
    )

    if (res.status !== 204) {
      const detail = await res.text().catch(() => '')
      await admin.from('admin_dev_tasks')
        .update({ status: 'failed', error: `dispatch ${res.status}: ${detail.slice(0, 400)}`, updated_at: new Date().toISOString() })
        .eq('id', task.id)
      return json({ error: 'dispatch_failed', status: res.status, detail: detail.slice(0, 400) }, 502)
    }
  } catch (e) {
    await admin.from('admin_dev_tasks')
      .update({ status: 'failed', error: String(e).slice(0, 400), updated_at: new Date().toISOString() })
      .eq('id', task.id)
    return json({ error: 'dispatch_error', detail: String(e) }, 502)
  }

  // Audit (best-effort)
  try {
    await admin.from('ai_admin_audit').insert({
      feature: 'dev_agent',
      actor_id: user.id,
      action: 'task_created',
      target_type: 'admin_dev_tasks',
      target_id: task.id,
      summary: instruction.slice(0, 280),
    })
  } catch { /* best-effort */ }

  return json({ ok: true, task_id: task.id, status: 'queued' })
})
