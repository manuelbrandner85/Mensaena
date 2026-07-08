// ════════════════════════════════════════════════════════════════════════
// admin-dev-cron — von pg_cron (stündlich) aufgerufen. Findet fällige
// wiederkehrende Godmode-Aufträge (admin_dev_schedules, next_run_at <= now,
// enabled), legt je einen admin_dev_tasks-Auftrag an (origin='schedule'),
// triggert admin_agent.yml und setzt last_run_at + next_run_at neu.
//
// Kein User-JWT (interner Cron-Call) — nutzt adminClient() wie die auto-* Fns.
// Secret: GH_AGENT_TOKEN (Workflow-Dispatch).
// ════════════════════════════════════════════════════════════════════════
import { CORS, json, adminClient } from '../_shared/util.ts'

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
    'User-Agent': 'mensaena-admin-dev-cron',
  }
}

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
    const target = Number(s.day_of_week ?? 1)
    let delta = (target - next.getUTCDay() + 7) % 7
    if (delta === 0 && next <= now) delta = 7
    next.setUTCDate(next.getUTCDate() + delta)
  } else {
    const dom = Math.min(Math.max(Number(s.day_of_month ?? 1), 1), 28)
    next.setUTCDate(dom)
    if (next <= now) next.setUTCMonth(next.getUTCMonth() + 1, dom)
  }
  return next.toISOString()
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const admin = adminClient()
  const token = Deno.env.get('GH_AGENT_TOKEN') ?? ''
  const nowIso = new Date().toISOString()

  // Fällige, aktive Schedules.
  const { data: due, error } = await admin
    .from('admin_dev_schedules')
    .select('*')
    .eq('enabled', true)
    .lte('next_run_at', nowIso)
    .limit(20)
  if (error) return json({ error: 'query_failed', detail: error.message }, 500)
  if (!due || due.length === 0) return json({ ok: true, dispatched: 0 })

  let dispatched = 0
  for (const s of due) {
    // Auftrag anlegen.
    const { data: task, error: tErr } = await admin
      .from('admin_dev_tasks')
      .insert({
        created_by: s.created_by,
        instruction: s.instruction,
        status: 'queued',
        origin: 'schedule',
        await_review: s.await_review === true,
      })
      .select('id').single()
    if (tErr || !task) continue

    // Workflow dispatchen (best-effort).
    let ok = false
    if (token) {
      const res = await fetch(
        `${GH_API}/actions/workflows/${GH_WORKFLOW}/dispatches`,
        {
          method: 'POST', headers: ghHeaders(token),
          body: JSON.stringify({
            ref: GH_REF,
            inputs: { instruction: s.instruction, task_id: task.id, image_urls: '[]' },
          }),
        },
      ).catch(() => null)
      ok = !!res && res.status === 204
    }
    if (!ok) {
      await admin.from('admin_dev_tasks')
        .update({ status: 'failed', error: 'Schedule-Dispatch fehlgeschlagen.', updated_at: nowIso })
        .eq('id', task.id)
    } else {
      dispatched++
    }

    // next_run_at fortschreiben (auch bei Dispatch-Fehler, sonst Endlos-Retry).
    await admin.from('admin_dev_schedules')
      .update({
        last_run_at: nowIso,
        next_run_at: computeNextRun(s),
        updated_at: nowIso,
      })
      .eq('id', s.id)
  }

  // ── Überwachter Autopilot ──────────────────────────────────────────────────
  // Max. 1×/Tag: nimmt den Top-Quick-Win-Vorschlag und legt EINEN Auftrag mit
  // await_review=true an (CI baut, Merge erst nach Admin-Freigabe = Veto).
  // Gedrosselt auf autopilot_max_open gleichzeitig offene Autopilot-Aufträge.
  let autopilot = 'off'
  try {
    const { data: settings } = await admin
      .from('godmode_settings').select('*').eq('id', 1).maybeSingle()
    if (settings?.autopilot_enabled === true) {
      const last = settings.autopilot_last_run_at
        ? new Date(settings.autopilot_last_run_at).getTime() : 0
      if ((Date.now() - last) / 3600000 >= 20) {
        // deno-lint-ignore no-explicit-any
        const score = (s: any) =>
          Number(s.impact ?? 3) * 2 - Number(s.effort ?? 3)
        const { data: openTasks } = await admin
          .from('admin_dev_tasks')
          .select('id')
          .eq('origin', 'autopilot')
          .in('status', ['queued', 'running', 'phased', 'pr_open', 'awaiting_review'])
        const maxOpen = Number(settings.autopilot_max_open ?? 1)
        if ((openTasks?.length ?? 0) < maxOpen) {
          const { data: sugg } = await admin
            .from('admin_dev_suggestions')
            .select('id,title,instruction,impact,effort,created_by')
            .eq('status', 'pending')
            .limit(100)
          if (sugg && sugg.length) {
            sugg.sort((a, b) => score(b) - score(a))
            const top = sugg[0]
            const instr = String(top.instruction || top.title || '').trim()
            if (instr.length > 4) {
              const { data: task } = await admin.from('admin_dev_tasks').insert({
                created_by: top.created_by,
                instruction: instr,
                status: 'queued',
                origin: 'autopilot',
                await_review: true,
              }).select('id').single()
              if (task) {
                await admin.from('admin_dev_suggestions')
                  .update({ status: 'accepted', task_id: task.id, updated_at: nowIso })
                  .eq('id', top.id)
                if (token) {
                  await fetch(
                    `${GH_API}/actions/workflows/${GH_WORKFLOW}/dispatches`,
                    {
                      method: 'POST', headers: ghHeaders(token),
                      body: JSON.stringify({
                        ref: GH_REF,
                        inputs: { instruction: instr, task_id: task.id, image_urls: '[]' },
                      }),
                    },
                  ).catch(() => null)
                }
                autopilot = 'dispatched'
              }
            }
          } else {
            autopilot = 'no_suggestions'
          }
        } else {
          autopilot = 'throttled_open'
        }
        // Tagestaktung: last_run immer fortschreiben.
        await admin.from('godmode_settings')
          .update({ autopilot_last_run_at: nowIso, updated_at: nowIso })
          .eq('id', 1)
      } else {
        autopilot = 'throttled_daily'
      }
    }
  } catch (_) { autopilot = 'error' }

  // ── Regressions-Wächter (#1) ───────────────────────────────────────────────
  // Nach einer Auslieferung ('live') prüft der Wächter, ob seit dem live_at
  // ein NEUER Fehler auftaucht, den es im 24-h-Fenster DAVOR nicht gab. Wenn
  // ja (mit genug Häufung), öffnet er EINEN Fix-Auftrag (origin='regression',
  // await_review=true → nie Auto-Merge) und verweist auf den auslösenden PR.
  // Konservativ: max. 1 Fix-Auftrag pro Lauf, nur bei klarer Häufung, jeder
  // live-Auftrag wird genau einmal geprüft (regression_checked_at).
  let regression = 'off'
  try {
    const { data: rset } = await admin
      .from('godmode_settings')
      .select('regression_watch_enabled').eq('id', 1).maybeSingle()
    if (rset?.regression_watch_enabled !== false) {
      regression = 'clean'
      const sixAgo = new Date(Date.now() - 6 * 3600000).toISOString()
      const oneAgo = new Date(Date.now() - 1 * 3600000).toISOString()
      // Fertig ausgelieferte, noch ungeprüfte Aufträge (1–6 h alt: genug Zeit,
      // dass echte Fehler aufgetaucht sind).
      const { data: liveTasks } = await admin
        .from('admin_dev_tasks')
        .select('id,pr_number,location,live_at,instruction')
        .eq('status', 'live')
        .is('regression_checked_at', null)
        .gte('live_at', sixAgo)
        .lte('live_at', oneAgo)
        .order('live_at', { ascending: true })
        .limit(5)

      // deno-lint-ignore no-explicit-any
      const sig = (t: string, m: string) =>
        `${(t || '?').slice(0, 40)} | ${(m || '').slice(0, 80)}`

      for (const lt of (liveTasks ?? [])) {
        const liveAt = new Date(lt.live_at).getTime()
        const beforeFrom = new Date(liveAt - 24 * 3600000).toISOString()
        const beforeTo = new Date(liveAt).toISOString()
        // Basislinie: Fehler-Signaturen der 24 h VOR der Auslieferung.
        const baseline = new Set<string>()
        for (const src of [
          { tbl: 'error_logs', t: 'error_type', m: 'message' },
          { tbl: 'crash_logs', t: 'error_type', m: 'error_message' },
        ]) {
          const { data } = await admin.from(src.tbl)
            .select(`${src.t},${src.m}`)
            .gte('created_at', beforeFrom).lt('created_at', beforeTo).limit(1000)
          // deno-lint-ignore no-explicit-any
          for (const r of (data ?? []) as any[]) baseline.add(sig(r[src.t], r[src.m]))
        }
        // Nach der Auslieferung: neue Signaturen zählen.
        const afterCount = new Map<string, number>()
        for (const src of [
          { tbl: 'error_logs', t: 'error_type', m: 'message' },
          { tbl: 'crash_logs', t: 'error_type', m: 'error_message' },
        ]) {
          const { data } = await admin.from(src.tbl)
            .select(`${src.t},${src.m}`)
            .gte('created_at', beforeTo).limit(1000)
          // deno-lint-ignore no-explicit-any
          for (const r of (data ?? []) as any[]) {
            const k = sig(r[src.t], r[src.m])
            if (!baseline.has(k)) afterCount.set(k, (afterCount.get(k) ?? 0) + 1)
          }
        }
        // Häufigste neue Signatur mit ≥4 Vorkommen = Verdacht.
        let worst = ''; let worstN = 0
        for (const [k, n] of afterCount) if (n > worstN) { worst = k; worstN = n }

        // Auftrag als geprüft markieren (einmalig, egal ob Fund).
        await admin.from('admin_dev_tasks')
          .update({ regression_checked_at: nowIso })
          .eq('id', lt.id)

        if (worstN >= 4) {
          const prRef = lt.pr_number ? `PR #${lt.pr_number}` : 'der letzten Änderung'
          const loc = lt.location ? `\nBetroffener Bereich: ${lt.location}` : ''
          const instr =
            `[Bugfix] Mögliche Regression nach ${prRef}: Seit der Auslieferung ` +
            `häuft sich ein Fehler, der im 24-h-Fenster davor NICHT auftrat ` +
            `(${worstN}× seit ${lt.live_at}):\n\n${worst}\n${loc}\n\n` +
            `Ursprünglicher Auftrag: "${String(lt.instruction || '').slice(0, 160)}".\n` +
            `Untersuche, ob ${prRef} diesen Fehler verursacht, und behebe die ` +
            `Ursache. Besteht KEIN Zusammenhang, schreibe .godmode_already_done.txt ` +
            `mit kurzer Begründung statt eines PRs.`
          const { data: fixTask } = await admin.from('admin_dev_tasks').insert({
            instruction: instr,
            status: 'queued',
            origin: 'regression',
            await_review: true,
          }).select('id').single()
          if (fixTask && token) {
            await fetch(
              `${GH_API}/actions/workflows/${GH_WORKFLOW}/dispatches`,
              {
                method: 'POST', headers: ghHeaders(token),
                body: JSON.stringify({
                  ref: GH_REF,
                  inputs: { instruction: instr, task_id: fixTask.id, image_urls: '[]' },
                }),
              },
            ).catch(() => null)
            regression = 'fix_dispatched'
          }
          break // max. 1 Fix-Auftrag pro Lauf
        }
      }
    }
  } catch (_) { regression = 'error' }

  return json({ ok: true, dispatched, autopilot, regression })
})
