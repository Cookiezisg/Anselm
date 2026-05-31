export const meta = {
  name: 'judge-round2-newdim',
  description: 'Round-2 new dimensions: long-context entity-pick, injected fields (destructive/execution_group), knowledge/skill mounting',
  phases: [{ title: 'Judge', detail: '3 judges per scenario, of-attempts + CI' }],
}
const SCENARIOS = ['lc_pick_email', 'lc_pick_wf', 'lc_pick_handler', 'inj_destructive', 'inj_parallel', 'inj_mixed', 'km_knowledge', 'km_skill']
const JUDGE_SCHEMA = { type: 'object', required: ['per_rep'], additionalProperties: false, properties: { per_rep: { type: 'array', items: {
  type: 'object', required: ['rep', 'correct'], additionalProperties: false,
  properties: { rep: { type: 'integer' }, correct: { type: 'boolean' }, failed_criteria: { type: 'array', items: { type: 'string' } }, why: { type: 'string' } } } } } }

const judgePrompt = (id) => `Adversarial semantic judge (Round-2 new dimensions, n≈30). Read /tmp/r2n/${id}.json: intent, rubric, reps[] (model tool_calls args + content).
For EACH rep check EVERY rubric criterion.
- lc_* (long-context): did it target the RIGHT existing entity id among the ~60-entity catalog (e.g. fn_send_email not sms/slack; wf_order_pipeline; hd_db_pool)? no hallucinated id? not confused by the big catalog?
- inj_* (injected fields): is destructive correct (true ONLY for delete/irreversible; false for read/test-run)? execution_group correct (independent ops share a group = parallel; dependent ops ascending)? summary present?
- km_* (knowledge/skill): create_agent with set_knowledge (doc refs, NOT pasted into prompt) / set_skill correctly; prompt still present; no platform tools.
correct=true ONLY if it genuinely satisfies the rubric. Default skeptical. No-tool-call → "clarified-not-attempted".
Return per schema: per_rep[] {rep, correct, failed_criteria[], why}. Cover every rep.`

phase('Judge')
const results = await pipeline(SCENARIOS, async (id) => {
  const judges = await parallel([0, 1, 2].map((j) => () => agent(judgePrompt(id), { label: `judge${j}:${id}`, phase: 'Judge', schema: JUDGE_SCHEMA })))
  return { id, judges: judges.filter(Boolean) }
})
function ci(p, n) { return n ? +(1.96 * Math.sqrt(p * (1 - p) / n)).toFixed(3) : 0 }
function agg(r) {
  const idx = new Set(); for (const j of r.judges) for (const p of (j.per_rep || [])) idx.add(p.rep)
  const reps = [...idx].sort((a, b) => a - b); let correct = 0, clar = 0; const fails = {}
  for (const rep of reps) { let yes = 0, tot = 0, c = 0; for (const j of r.judges) { const p = (j.per_rep || []).find((x) => x.rep === rep); if (!p) continue; tot++; if (p.correct) yes++; else { if ((p.failed_criteria || []).includes('clarified-not-attempted')) c++; for (const f of (p.failed_criteria || [])) fails[f] = (fails[f] || 0) + 1 } } if (tot && yes >= 2) correct++; else if (c >= 2) clar++ }
  const att = reps.length - clar, rate = att ? correct / att : 0
  return { id: r.id, n: reps.length, attempted: att, ofAttempts: +rate.toFixed(3), ci95: ci(rate, att), topFails: Object.entries(fails).filter(([f]) => f !== 'clarified-not-attempted').sort((a, b) => b[1] - a[1]).slice(0, 3) }
}
const a = results.filter(Boolean).map(agg)
log('Round-2 new dimensions (n≈30, temp=default, of-attempts ±95%CI):')
for (const x of a) log(`  ${x.id}: ${(x.ofAttempts * 100).toFixed(0)}% ±${(x.ci95 * 100).toFixed(0)} (${x.attempted}) ${x.topFails.map(([f, c]) => f.slice(0, 26) + '×' + c).join('|')}`)
return { scenarios: a }
