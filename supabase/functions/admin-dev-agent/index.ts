// ════════════════════════════════════════════════════════════════════════
// admin-dev-agent — Code-Agent aus dem Admin-Dashboard.
//
// Ein Admin formuliert eine Aufgabe (Feature, Bugfix, UI/UX, Konfiguration).
// Diese Function:
//   1. verifiziert role='admin' (NICHT moderator),
//   2. legt eine Zeile in admin_dev_tasks an (status='queued'),
//   3. triggert die GitHub Action `admin_agent.yml` via workflow_dispatch,
//      die den Code via Claude Code CLI ändert → PR → grünes CI → Auto-Merge
//      → Shorebird-OTA an die Flutter-App.
//
// Secrets (Supabase Project Secrets, NIEMALS in GitHub):
//   GH_AGENT_TOKEN  — fine-grained PAT (contents:write, pull-requests:write,
//                     actions:write) auf manuelbrandner85/Mensaena.
// ════════════════════════════════════════════════════════════════════════
import { CORS, json, getUser, adminClient } from '../_shared/util.ts'

const GH_OWNER = 'manuelbrandner85'
const GH_REPO = 'Mensaena'
const GH_WORKFLOW = 'admin_agent.yml'
const GH_REF = 'main'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const user = await getUser(req)
  if (!user) return json({ error: 'unauthorized' }, 401)

  const admin = adminClient()

  // ── Nur Admins (kein moderator) ──────────────────────────────────────────
  const { data: prof } = await admin
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!prof || prof.role !== 'admin') return json({ error: 'forbidden' }, 403)

  const body = await req.json().catch(() => ({}))
  const action = String(body?.action ?? 'create')

  // ── Auftrag(e) löschen ─────────────────────────────────────────────────────
  // Damit sich die Liste im Dashboard nicht endlos füllt, kann der Admin
  // einzelne Aufträge ('delete' { id }) oder alle abgeschlossenen Aufträge
  // ('clear') entfernen. Nur abgeschlossene Zustände dürfen gelöscht werden,
  // damit laufende Aufträge nicht versehentlich verschwinden.
  const DONE_STATES = ['merged', 'failed', 'no_changes']

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

  const instruction = String(body?.instruction ?? '').trim().slice(0, 4000)
  if (instruction.length < 5) return json({ error: 'instruction_required' }, 400)

  const token = Deno.env.get('GH_AGENT_TOKEN') ?? ''
  if (!token) return json({ error: 'agent_not_configured' }, 503)

  // ── Task anlegen ─────────────────────────────────────────────────────────
  const { data: task, error: insErr } = await admin
    .from('admin_dev_tasks')
    .insert({ created_by: user.id, instruction, status: 'queued' })
    .select('id')
    .single()

  if (insErr || !task) {
    return json({ error: 'insert_failed', detail: insErr?.message }, 500)
  }

  // ── GitHub Action triggern (workflow_dispatch) ─────────────────────────────
  try {
    const res = await fetch(
      `https://api.github.com/repos/${GH_OWNER}/${GH_REPO}/actions/workflows/${GH_WORKFLOW}/dispatches`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'Content-Type': 'application/json',
          'User-Agent': 'mensaena-admin-dev-agent',
        },
        body: JSON.stringify({
          ref: GH_REF,
          inputs: { instruction, task_id: task.id },
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
