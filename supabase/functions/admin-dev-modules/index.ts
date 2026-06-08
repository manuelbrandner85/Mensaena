// ════════════════════════════════════════════════════════════════════════
// admin-dev-modules — Modul-Intelligenz für das Admin-Dashboard.
//
// Aktionen (body.action):
//   • 'scan_start'            — Modul-Intelligenz-Scan starten.
//   • 'scan_status'           — Letzten Scan-Lauf abfragen.
//   • 'list'     (default)    — Erkenntnisse laden (nur pending).
//   • 'accept'   { id }       — Erkenntnis annehmen → Dev-Task erstellen.
//   • 'dismiss'  { id }       — Erkenntnis verwerfen.
//   • 'delete'   { id }       — Erkenntnis löschen.
//   • 'clear_dismissed'       — Alle verworfenen Erkenntnisse löschen.
//
// Nur role='admin'. Schreib-Zugriff ausschließlich serverseitig.
//
// Supabase Secrets: GH_AGENT_TOKEN (actions:write, contents:write).
// ════════════════════════════════════════════════════════════════════════
import { CORS, json, getUser, adminClient } from '../_shared/util.ts'

const GH_OWNER   = 'manuelbrandner85'
const GH_REPO    = 'Mensaena'
const GH_REF     = 'main'
const GH_MODULE_SCAN_WORKFLOW = 'admin_module_scan.yml'
const GH_AGENT_WORKFLOW       = 'admin_agent.yml'

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
        'Accept':        'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'Content-Type':  'application/json',
        'User-Agent':    'mensaena-admin-dev-modules',
      },
      body: JSON.stringify({ ref: GH_REF, inputs }),
    },
  )
  if (res.status === 204) return { ok: true, status: 204 }
  const detail = await res.text().catch(() => '')
  return { ok: false, status: res.status, detail: detail.slice(0, 400) }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const user = await getUser(req)
  if (!user) return json({ error: 'unauthorized' }, 401)

  const admin = adminClient()
  const { data: prof } = await admin
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!prof || prof.role !== 'admin') return json({ error: 'forbidden' }, 403)

  const body   = await req.json().catch(() => ({}))
  const action = String(body?.action ?? 'list')

  // ── LIST ──────────────────────────────────────────────────────────────────
  if (action === 'list') {
    const { data, error } = await admin
      .from('admin_module_insights')
      .select('id, module_name, screen_path, insight_type, title, description, '
        + 'instruction, severity, category, source, reference_url, status, '
        + 'scan_run_id, task_id, created_at')
      .eq('status', 'pending')
      .order('created_at', { ascending: false })
      .limit(80)
    if (error) return json({ error: 'list_failed', detail: error.message }, 500)

    const { data: scan } = await admin
      .from('admin_module_scan_runs')
      .select('id, status, run_url, insights_count, current_module, started_at, completed_at, error')
      .order('started_at', { ascending: false })
      .limit(1)
      .maybeSingle()

    return json({ ok: true, insights: data ?? [], scan: scan ?? null })
  }

  // ── SCAN STATUS ────────────────────────────────────────────────────────────
  if (action === 'scan_status') {
    const { data: scan } = await admin
      .from('admin_module_scan_runs')
      .select('id, status, run_url, insights_count, current_module, started_at, completed_at, error')
      .order('started_at', { ascending: false })
      .limit(1)
      .maybeSingle()
    return json({ ok: true, scan: scan ?? null })
  }

  // ── SCAN START ─────────────────────────────────────────────────────────────
  if (action === 'scan_start') {
    const token = Deno.env.get('GH_AGENT_TOKEN') ?? ''
    if (!token) return json({ error: 'not_configured' }, 503)

    // Doppel-Scan verhindern.
    const { data: running } = await admin
      .from('admin_module_scan_runs')
      .select('id, status')
      .in('status', ['queued', 'running'])
      .limit(1)
      .maybeSingle()
    if (running) return json({ ok: true, scan_id: running.id, already_running: true })

    const { data: scan, error: insErr } = await admin
      .from('admin_module_scan_runs')
      .insert({ status: 'queued' })
      .select('id')
      .single()
    if (insErr || !scan) return json({ error: 'insert_failed' }, 500)

    const r = await dispatchWorkflow(token, GH_MODULE_SCAN_WORKFLOW, { scan_id: scan.id })
    if (!r.ok) {
      await admin.from('admin_module_scan_runs')
        .update({ status: 'failed', error: `dispatch ${r.status}: ${r.detail}`, updated_at: new Date().toISOString() })
        .eq('id', scan.id)
      return json({ error: 'dispatch_failed', status: r.status }, 502)
    }

    return json({ ok: true, scan_id: scan.id })
  }

  // ── ACCEPT ────────────────────────────────────────────────────────────────
  if (action === 'accept') {
    const id    = String(body?.id ?? '')
    const token = Deno.env.get('GH_AGENT_TOKEN') ?? ''
    if (!id)    return json({ error: 'id_required' }, 400)
    if (!token) return json({ error: 'not_configured' }, 503)

    const { data: insight } = await admin
      .from('admin_module_insights')
      .select('id, title, instruction, status')
      .eq('id', id)
      .maybeSingle()
    if (!insight) return json({ error: 'not_found' }, 404)
    if (insight.status !== 'pending') return json({ error: 'already_reviewed' }, 409)

    const instruction = (insight.instruction || insight.title) as string

    const { data: task, error: tErr } = await admin
      .from('admin_dev_tasks')
      .insert({ created_by: user.id, instruction, status: 'queued' })
      .select('id').single()
    if (tErr || !task) return json({ error: 'task_insert_failed' }, 500)

    const r = await dispatchWorkflow(token, GH_AGENT_WORKFLOW, {
      instruction, task_id: task.id,
    })
    if (!r.ok) {
      await admin.from('admin_dev_tasks')
        .update({ status: 'failed', error: `dispatch ${r.status}`, updated_at: new Date().toISOString() })
        .eq('id', task.id)
      return json({ error: 'dispatch_failed' }, 502)
    }

    await admin.from('admin_module_insights')
      .update({ status: 'accepted', task_id: task.id, updated_at: new Date().toISOString() })
      .eq('id', id)

    return json({ ok: true, task_id: task.id })
  }

  // ── DISMISS ───────────────────────────────────────────────────────────────
  if (action === 'dismiss') {
    const id = String(body?.id ?? '')
    if (!id) return json({ error: 'id_required' }, 400)
    const { error } = await admin.from('admin_module_insights')
      .update({ status: 'dismissed', updated_at: new Date().toISOString() })
      .eq('id', id)
    if (error) return json({ error: 'dismiss_failed' }, 500)
    return json({ ok: true })
  }

  // ── DELETE ────────────────────────────────────────────────────────────────
  if (action === 'delete') {
    const id = String(body?.id ?? '')
    if (!id) return json({ error: 'id_required' }, 400)
    const { error } = await admin.from('admin_module_insights').delete().eq('id', id)
    if (error) return json({ error: 'delete_failed' }, 500)
    return json({ ok: true })
  }

  // ── CLEAR DISMISSED ───────────────────────────────────────────────────────
  if (action === 'clear_dismissed') {
    const { error } = await admin.from('admin_module_insights')
      .delete().eq('status', 'dismissed')
    if (error) return json({ error: 'clear_failed' }, 500)
    return json({ ok: true })
  }

  return json({ error: 'unknown_action' }, 400)
})
