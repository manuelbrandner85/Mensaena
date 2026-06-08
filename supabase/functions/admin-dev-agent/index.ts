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

const GH_OWNER = 'manuelbrandner85'
const GH_REPO = 'Mensaena'
const GH_WORKFLOW = 'admin_agent.yml'
const GH_REF = 'main'
const GH_API = `https://api.github.com/repos/${GH_OWNER}/${GH_REPO}`

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
  const token = Deno.env.get('GH_AGENT_TOKEN') ?? ''

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
    await admin.from('admin_dev_tasks').update({
      status: 'merged', ci_status: 'success',
      summary: `Manuell freigegeben & gemergt (PR #${t.pr_number}). OTA-Auslieferung läuft.`,
      updated_at: new Date().toISOString(),
    }).eq('id', id)
    return json({ ok: true, status: 'merged' })
  }

  // ── Neuen Auftrag anlegen (default) ──────────────────────────────────────
  const instruction = String(body?.instruction ?? '').trim().slice(0, 4000)
  if (instruction.length < 5) return json({ error: 'instruction_required' }, 400)
  if (!token) return json({ error: 'agent_not_configured' }, 503)

  // Optionale Screenshots (Vision) + Review-Gate.
  const imageUrls: string[] = Array.isArray(body?.image_urls)
    ? body.image_urls.map((x: unknown) => String(x)).filter(Boolean).slice(0, 6)
    : []
  const awaitReview = body?.await_review === true

  const { data: task, error: insErr } = await admin
    .from('admin_dev_tasks')
    .insert({
      created_by: user.id,
      instruction,
      status: 'queued',
      image_urls: imageUrls,
      await_review: awaitReview,
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
            instruction,
            task_id: task.id,
            image_urls: JSON.stringify(imageUrls),
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
