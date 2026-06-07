// ai-user-risk — analysiert Nutzerverhalten und berechnet KI-Risikoprofile.
// Schaut auf: direkte Nutzermeldungen, gemeldete Inhalte, Report-Spam-Muster.
// Speichert in ai_user_risk (upsert). Admin-only. Flag: 'risk_profiling'.
import { callAiChain } from '../_shared/ai.ts'
import { CORS, json, getUser, adminClient } from '../_shared/util.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const user = await getUser(req)
  if (!user) return json({ error: 'unauthorized' }, 401)

  const admin = adminClient()

  const { data: prof } = await admin
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!prof || prof.role !== 'admin') return json({ error: 'forbidden' }, 403)

  const { data: enabled } = await admin
    .rpc('ai_feature_enabled', { p_key: 'risk_profiling' })
  if (enabled === false) return json({ error: 'feature_disabled', disabled: true }, 200)

  const since30d = new Date(Date.now() - 30 * 86400_000).toISOString()
  const since7d  = new Date(Date.now() - 7  * 86400_000).toISOString()

  // ── Signal 1: Nutzer die direkt gemeldet wurden ─────────────────────────
  const { data: userReports } = await admin
    .from('reports')
    .select('content_id')
    .eq('content_type', 'user')
    .gte('created_at', since30d)

  const reportCounts: Record<string, number> = {}
  for (const r of (userReports ?? [])) {
    reportCounts[r.content_id] = (reportCounts[r.content_id] || 0) + 1
  }

  // ── Signal 2: Nutzer die auffällig viele Meldungen einreichen (Spam) ───
  const { data: spamReporters } = await admin
    .from('reports')
    .select('reporter_id')
    .gte('created_at', since7d)

  const reporterCounts: Record<string, number> = {}
  for (const r of (spamReporters ?? [])) {
    if (!r.reporter_id) continue
    reporterCounts[r.reporter_id] = (reporterCounts[r.reporter_id] || 0) + 1
  }

  // Kandidaten = direkt gemeldete Nutzer + Reporter-Spammer (>5 in 7 Tagen)
  const candidates = new Set([
    ...Object.keys(reportCounts),
    ...Object.entries(reporterCounts).filter(([, c]) => c > 5).map(([id]) => id),
  ])

  if (!candidates.size) return json({ analyzed: 0, profiles: [] })

  // ── Profil-Daten für Kandidaten holen ──────────────────────────────────
  const { data: profiles } = await admin
    .from('profiles')
    .select('id, display_name, created_at, role')
    .in('id', [...candidates])
    .limit(20)

  const SYSTEM =
    'Du bist Sicherheitsanalyst einer Nachbarschaftshilfe-App (Mensaena). ' +
    'Bewerte das Nutzerrisiko basierend auf den gegebenen Signalen. ' +
    'Antworte NUR mit validem JSON (kein Markdown):\n' +
    '{"risk_score":0-100,"level":"low|medium|high","reason":"max 120 Zeichen Deutsch"}\n\n' +
    'Skala: 0-30=low (harmlos), 31-60=medium (beobachten), 61-100=high (Handlung nötig)\n' +
    'Berücksichtige: Meldungen sind Hinweise, kein Beweis. Neu-Accounts bekommen Benefit of Doubt.'

  const results: Record<string, unknown>[] = []

  for (let i = 0; i < (profiles ?? []).length; i += 5) {
    const batch = (profiles ?? []).slice(i, i + 5)
    const analyzed = await Promise.all(batch.map(async (p) => {
      const reportsReceived = reportCounts[p.id] ?? 0
      const reportsSubmitted = reporterCounts[p.id] ?? 0
      const accountAgeDays = Math.round(
        (Date.now() - new Date(p.created_at).getTime()) / 86400_000,
      )

      const signals = { reports_received: reportsReceived, reports_submitted: reportsSubmitted, account_age_days: accountAgeDays }

      const userMsg =
        `Nutzer: ${p.display_name || 'anonym'} | Rolle: ${p.role || 'user'}\n` +
        `Account-Alter: ${accountAgeDays} Tage\n` +
        `Meldungen gegen ihn (30 Tage): ${reportsReceived}\n` +
        `Meldungen von ihm (7 Tage): ${reportsSubmitted}`

      let riskScore = 0
      let level = 'low'
      let reason = 'Automatisch berechnet'

      try {
        const { text } = await callAiChain(SYSTEM, userMsg, { timeoutMs: 10_000 })
        const parsed = JSON.parse(text.replace(/```json\n?|```/g, '').trim())
        riskScore = Math.max(0, Math.min(100, Number(parsed.risk_score) || 0))
        level = ['low', 'medium', 'high'].includes(parsed.level) ? parsed.level : 'low'
        reason = String(parsed.reason || '').slice(0, 120)
      } catch { /* use defaults */ }

      await admin.from('ai_user_risk').upsert({
        user_id: p.id,
        risk_score: riskScore,
        level,
        signals: { ...signals, reason },
        updated_at: new Date().toISOString(),
      }, { onConflict: 'user_id' })

      return { ...p, risk_score: riskScore, level, signals: { ...signals, reason } }
    }))
    results.push(...analyzed)
  }

  results.sort((a, b) => (b['risk_score'] as number) - (a['risk_score'] as number))

  try {
    await admin.from('ai_admin_audit').insert({
      feature: 'risk_profiling',
      actor_id: user.id,
      action: 'analyze_risks',
      summary: `${results.length} Profile analysiert, ${results.filter((r) => r['level'] === 'high').length} hoch`,
      provider: 'ai-chain',
      meta: { analyzed: results.length },
    })
  } catch { /* best-effort */ }

  return json({ analyzed: results.length, profiles: results })
})
