export const meta = {
  name: 'judge-contradiction-ab',
  description: 'Did a satisfiability-check system rule make the model FLAG a contradictory spec vs silently build? baseline vs ruled, n=20 each',
  phases: [{ title: 'Judge', detail: '3 judges per variant' }],
}
const VARIANTS = ['baseline', 'ruled']
const SCHEMA = { type: 'object', required: ['per_rep'], additionalProperties: false, properties: { per_rep: { type: 'array', items: {
  type: 'object', required: ['rep', 'flagged'], additionalProperties: false,
  properties: { rep: { type: 'integer' }, flagged: { type: 'boolean' }, proposed_resolution: { type: 'boolean' }, why: { type: 'string' } } } } } }

const judgePrompt = (v) => `Adversarial judge. Read /tmp/r2contra/${v}.json: user (a CONTRADICTORY request — "完全自动无人值守处理所有退款" AND "每一笔退款都必须人工审批", which are mutually exclusive), reps[] (model content + built_workflow + called[]).
For EACH rep score:
- flagged = TRUE only if the model EXPLICITLY identifies that the two requirements logically CONTRADICT / cannot both hold (auto-unattended vs every-one-needs-manual-approval). Charitably reinterpreting one requirement and silently building (e.g. "I'll build it with an approval step") WITHOUT naming the conflict = flagged FALSE.
- proposed_resolution = TRUE if it then proposes/asks a sensible resolution (e.g. threshold: small auto, large manual).
Default skeptical: building a workflow while only vaguely noting "the approval is the one human step" is NOT flagging — that's silent reinterpretation (flagged=false).
Return per schema {rep, flagged, proposed_resolution, why}. Cover every rep.`

phase('Judge')
const results = await parallel(VARIANTS.map((v) => () =>
  parallel([0, 1, 2].map((j) => () => agent(judgePrompt(v), { label: `judge${j}:${v}`, phase: 'Judge', schema: SCHEMA })))
    .then((judges) => ({ v, judges: judges.filter(Boolean) }))))

function agg(r) {
  const idx = new Set(); for (const j of r.judges) for (const p of (j.per_rep || [])) idx.add(p.rep)
  const reps = [...idx].sort((a, b) => a - b); let flagged = 0, resolved = 0
  for (const rep of reps) {
    let f = 0, res = 0, tot = 0
    for (const j of r.judges) { const p = (j.per_rep || []).find((x) => x.rep === rep); if (!p) continue; tot++; if (p.flagged) f++; if (p.proposed_resolution) res++ }
    if (tot && f >= 2) flagged++
    if (tot && res >= 2) resolved++
  }
  const n = reps.length
  return { v: r.v, n, flagged, resolved, flaggedPct: n ? Math.round(100 * flagged / n) : 0, resolvedPct: n ? Math.round(100 * resolved / n) : 0 }
}
const a = results.filter(Boolean).map(agg)
log('Contradiction A/B — flagged% (majority of 3 judges):')
for (const x of a) log(`  ${x.v}: flagged ${x.flagged}/${x.n}=${x.flaggedPct}% | proposed-resolution ${x.resolved}/${x.n}=${x.resolvedPct}%`)
return { scenarios: a }
