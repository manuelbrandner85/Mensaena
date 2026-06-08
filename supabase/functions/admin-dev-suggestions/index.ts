// ════════════════════════════════════════════════════════════════════════
// admin-dev-suggestions — KI-Tiefenanalyse-Vorschläge für das Admin-Dashboard.
//
// Aktionen (body.action):
//   • 'list'   (default) — offene Vorschläge laden (optional nach category).
//   • 'scan'              — Tiefenanalyse der GESAMTEN App starten. Triggert
//                           die GitHub Action `admin_scan.yml`, die die Claude
//                           Code CLI den kompletten Code lesen lässt und
//                           Vorschläge (Bugs, logische Fehler, Verbesserungen)
//                           in admin_dev_suggestions schreibt.
//   • 'accept' { id }     — Vorschlag annehmen → erzeugt einen admin_dev_tasks
//                           -Auftrag (triggert admin_agent.yml → PR → OTA).
//   • 'reject' { id }     — Vorschlag ablehnen.
//   • 'accept_many' {ids} — mehrere Vorschläge auf einmal annehmen.
//   • 'reject_many' {ids} — mehrere Vorschläge auf einmal ablehnen.
//
// Nur role='admin'. Schreibzugriff ausschließlich serverseitig (service_role).
//
// Secrets (Supabase Project Secrets, NIEMALS in GitHub):
//   GH_AGENT_TOKEN — fine-grained PAT (contents:write, pull-requests:write,
//                    actions:write) auf manuelbrandner85/Mensaena.
// ════════════════════════════════════════════════════════════════════════
import { CORS, json, getUser, adminClient } from '../_shared/util.ts'

const GH_OWNER = 'manuelbrandner85'
const GH_REPO = 'Mensaena'
const GH_REF = 'main'
const GH_AGENT_WORKFLOW = 'admin_agent.yml'
const GH_SCAN_WORKFLOW = 'admin_scan.yml'

async function dispatchWorkflow(
  token: string,
  workflow: string,
  inputs: Record<string, string>,
): Promise<{ ok: boolean; status: number; detail?: string }> {
  const res = await fetch(
    `https://api.github.com/repos/${GH_OWNER}/${GH_REPO}/actions/workflows/${workflow}/dispatches`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'Content-Type': 'application/json',
        'User-Agent': 'mensaena-admin-dev-suggestions',
      },
      body: JSON.stringify({ ref: GH_REF, inputs }),
    },
  )
  if (res.status === 204) return { ok: true, status: 204 }
  const detail = await res.text().catch(() => '')
  return { ok: false, status: res.status, detail: detail.slice(0, 400) }
}

// Nimmt EINEN Vorschlag an: legt einen Dev-Task an, triggert admin_agent.yml
// und markiert den Vorschlag als 'accepted'. Wird von 'accept' und
// 'accept_many' geteilt. Gibt {ok, task_id?} oder {ok:false, error} zurück.
// deno-lint-ignore no-explicit-any
async function acceptOne(admin: any, token: string, userId: string, id: string) {
  const { data: sug } = await admin
    .from('admin_dev_suggestions')
    .select('id, title, instruction, status')
    .eq('id', id)
    .maybeSingle()
  if (!sug) return { ok: false, error: 'not_found' }
  if (sug.status !== 'pending') return { ok: false, error: 'already_reviewed' }

  const { data: task, error: tErr } = await admin
    .from('admin_dev_tasks')
    .insert({ created_by: userId, instruction: sug.instruction, status: 'queued' })
    .select('id')
    .single()
  if (tErr || !task) return { ok: false, error: 'task_insert_failed' }

  const r = await dispatchWorkflow(token, GH_AGENT_WORKFLOW, {
    instruction: sug.instruction, task_id: task.id,
  })
  if (!r.ok) {
    await admin.from('admin_dev_tasks')
      .update({ status: 'failed', error: `dispatch ${r.status}: ${r.detail}`, updated_at: new Date().toISOString() })
      .eq('id', task.id)
    return { ok: false, error: 'dispatch_failed' }
  }

  await admin.from('admin_dev_suggestions')
    .update({
      status: 'accepted', task_id: task.id,
      reviewed_by: userId, reviewed_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq('id', id)

  try {
    await admin.from('ai_admin_audit').insert({
      feature: 'dev_agent', actor_id: userId, action: 'suggestion_accepted',
      target_type: 'admin_dev_suggestions', target_id: id,
      summary: String(sug.title ?? '').slice(0, 280),
    })
  } catch { /* best-effort */ }

  return { ok: true, task_id: task.id }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const user = await getUser(req)
  if (!user) return json({ error: 'unauthorized' }, 401)

  const admin = adminClient()
  const { data: prof } = await admin
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!prof || prof.role !== 'admin') return json({ error: 'forbidden' }, 403)

  const body = await req.json().catch(() => ({}))
  const action = String(body?.action ?? 'list')

  // ── LIST ──────────────────────────────────────────────────────────────────
  if (action === 'list') {
    const category = body?.category ? String(body.category) : null
    let q = admin
      .from('admin_dev_suggestions')
      .select('id, category, kind, severity, title, description, reason, instruction, file_hint, status, created_at')
      .eq('status', 'pending')
      .order('created_at', { ascending: false })
      .limit(60)
    if (category) q = q.eq('category', category)
    const { data, error } = await q
    if (error) return json({ error: 'list_failed', detail: error.message }, 500)

    // Aktueller Scan-Status inkl. Live-Fortschritt (für „läuft gerade").
    const { data: scan } = await admin
      .from('admin_scan_runs')
      .select('id, status, found, run_url, created_at, phase, current_file, ' +
        'analyzed_files, found_so_far, heartbeat_at')
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle()

    // Selbstlernende Kategorien (vom Agenten entdeckt oder manuell angelegt).
    const { data: cats } = await admin
      .from('admin_dev_categories')
      .select('key, label, description, source')
      .order('created_at', { ascending: true })
      .limit(60)

    return json({
      ok: true,
      suggestions: data ?? [],
      scan: scan ?? null,
      categories: cats ?? [],
    })
  }

  // ── SCAN ──────────────────────────────────────────────────────────────────
  if (action === 'scan') {
    const token = Deno.env.get('GH_AGENT_TOKEN') ?? ''
    if (!token) return json({ error: 'not_configured' }, 503)

    // Doppel-Scan verhindern.
    const { data: running } = await admin
      .from('admin_scan_runs')
      .select('id, status')
      .in('status', ['queued', 'running'])
      .limit(1)
      .maybeSingle()
    if (running) return json({ ok: true, scan_id: running.id, status: running.status, already_running: true })

    const { data: scan, error: insErr } = await admin
      .from('admin_scan_runs')
      .insert({ created_by: user.id, status: 'queued' })
      .select('id')
      .single()
    if (insErr || !scan) return json({ error: 'insert_failed', detail: insErr?.message }, 500)

    const r = await dispatchWorkflow(token, GH_SCAN_WORKFLOW, { scan_id: scan.id })
    if (!r.ok) {
      await admin.from('admin_scan_runs')
        .update({ status: 'failed', error: `dispatch ${r.status}: ${r.detail}`, updated_at: new Date().toISOString() })
        .eq('id', scan.id)
      return json({ error: 'dispatch_failed', status: r.status, detail: r.detail }, 502)
    }

    try {
      await admin.from('ai_admin_audit').insert({
        feature: 'dev_agent', actor_id: user.id, action: 'scan_started',
        target_type: 'admin_scan_runs', target_id: scan.id,
        summary: 'Tiefenanalyse der App gestartet',
      })
    } catch { /* best-effort */ }

    return json({ ok: true, scan_id: scan.id, status: 'queued' })
  }

  // ── ACCEPT ──────────────────────────────────────────────────────────────────
  if (action === 'accept') {
    const id = String(body?.id ?? '')
    if (!id) return json({ error: 'id_required' }, 400)

    const token = Deno.env.get('GH_AGENT_TOKEN') ?? ''
    if (!token) return json({ error: 'not_configured' }, 503)

    const r = await acceptOne(admin, token, user.id, id)
    if (!r.ok) {
      const code = r.error === 'not_found' ? 404
        : r.error === 'already_reviewed' ? 409
        : r.error === 'dispatch_failed' ? 502 : 500
      return json({ error: r.error }, code)
    }
    return json({ ok: true, task_id: r.task_id, status: 'queued' })
  }

  // ── ACCEPT MANY ─────────────────────────────────────────────────────────────
  if (action === 'accept_many') {
    const ids = Array.isArray(body?.ids)
      ? body.ids.map((x: unknown) => String(x)).filter(Boolean).slice(0, 25)
      : []
    if (ids.length === 0) return json({ error: 'ids_required' }, 400)

    const token = Deno.env.get('GH_AGENT_TOKEN') ?? ''
    if (!token) return json({ error: 'not_configured' }, 503)

    let accepted = 0
    const failed: string[] = []
    for (const id of ids) {
      const r = await acceptOne(admin, token, user.id, id)
      if (r.ok) accepted++
      else failed.push(id)
    }
    return json({ ok: true, accepted, failed })
  }

  // ── REJECT ──────────────────────────────────────────────────────────────────
  if (action === 'reject') {
    const id = String(body?.id ?? '')
    if (!id) return json({ error: 'id_required' }, 400)

    const { error } = await admin.from('admin_dev_suggestions')
      .update({
        status: 'rejected',
        reviewed_by: user.id, reviewed_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq('id', id).eq('status', 'pending')
    if (error) return json({ error: 'reject_failed', detail: error.message }, 500)

    try {
      await admin.from('ai_admin_audit').insert({
        feature: 'dev_agent', actor_id: user.id, action: 'suggestion_rejected',
        target_type: 'admin_dev_suggestions', target_id: id,
      })
    } catch { /* best-effort */ }

    return json({ ok: true })
  }

  // ── REJECT MANY ─────────────────────────────────────────────────────────────
  if (action === 'reject_many') {
    const ids = Array.isArray(body?.ids)
      ? body.ids.map((x: unknown) => String(x)).filter(Boolean).slice(0, 60)
      : []
    if (ids.length === 0) return json({ error: 'ids_required' }, 400)

    const { error, count } = await admin.from('admin_dev_suggestions')
      .update({
        status: 'rejected',
        reviewed_by: user.id, reviewed_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }, { count: 'exact' })
      .in('id', ids).eq('status', 'pending')
    if (error) return json({ error: 'reject_failed', detail: error.message }, 500)

    return json({ ok: true, rejected: count ?? 0 })
  }

  return json({ error: 'unknown_action' }, 400)
})
