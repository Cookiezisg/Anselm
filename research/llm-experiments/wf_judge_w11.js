export const meta = {
  name: 'judge-wave11',
  description: 'Wave-11: judge FRESH diverse workflows (when: design) — anti-overfit confirmation create_workflow generalizes',
  phases: [{ title: 'Judge', detail: '3 judges per fresh workflow, of-attempts' }],
}
const SCENARIOS = ['wf_order_fulfill', 'wf_content_mod', 'wf_lead_scoring', 'wf_backup_retry', 'wf_expense_approval']
const JUDGE_SCHEMA = { type: 'object', required: ['per_rep'], additionalProperties: false, properties: { per_rep: { type: 'array', items: {
  type: 'object', required: ['rep', 'correct', 'why'], additionalProperties: false,
  properties: { rep: { type: 'integer' }, correct: { type: 'boolean' }, failed_criteria: { type: 'array', items: { type: 'string' } }, why: { type: 'string' } } } } } }

const judgePrompt = (id) => `Adversarial semantic judge for Forgify workflow generation. The case nodes use per-branch \`when\` boolean guards (first true wins; final when:"true" default). Read /tmp/w11/${id}.json: intent, rubric, reps[] (model's create_workflow ops).
For EACH rep check EVERY rubric criterion against the actual graph. correct=true ONLY if it genuinely implements the intent and would run. Watch: a fetch/data step BEFORE any node that needs data (no empty payload to agent); per-branch \`when\` guards correct + ordered (e.g. >5000 before >1000); no dangling/null branch targets; case routes via branches not redundant connect; retry loops bounded + emit attempt+1.
If a rep made NO tool call (clarified), correct=false sole failed_criteria "clarified-not-attempted".
Return per schema: per_rep[] {rep, correct, failed_criteria[], why}. Cover every rep.`

phase('Judge')
const results = await pipeline(SCENARIOS, async (id) => {
  const judges = await parallel([0, 1, 2].map((j) => () => agent(judgePrompt(id), { label: `judge${j}:${id}`, phase: 'Judge', schema: JUDGE_SCHEMA })))
  return { id, judges: judges.filter(Boolean) }
})
function agg(r) {
  const idx = new Set(); for (const j of r.judges) for (const p of (j.per_rep || [])) idx.add(p.rep)
  const reps = [...idx].sort((a, b) => a - b); let correct = 0, clar = 0; const fails = {}
  for (const rep of reps) { let yes = 0, tot = 0, c = 0; for (const j of r.judges) { const p = (j.per_rep || []).find((x) => x.rep === rep); if (!p) continue; tot++; if (p.correct) yes++; else { if ((p.failed_criteria || []).includes('clarified-not-attempted')) c++; for (const f of (p.failed_criteria || [])) fails[f] = (fails[f] || 0) + 1 } } if (tot && yes >= 2) correct++; else if (c >= 2) clar++ }
  const att = reps.length - clar
  return { id: r.id, reps: reps.length, attempted: att, correct, ofAttempts: att ? +(correct / att).toFixed(2) : 0, topFails: Object.entries(fails).filter(([f]) => f !== 'clarified-not-attempted').sort((a, b) => b[1] - a[1]).slice(0, 3) }
}
const a = results.filter(Boolean).map(agg)
log('Wave-11 fresh workflows (anti-overfit; when: design):')
let s = 0, n = 0
for (const x of a) { log(`  ${x.id}: ofAttempts ${(x.ofAttempts * 100).toFixed(0)}% (${x.correct}/${x.attempted}) ${x.topFails.map(([f, c]) => f.slice(0, 26) + '×' + c).join('|')}`); s += x.correct; n += x.attempted }
log(`  OVERALL of-attempts: ${(100 * s / n).toFixed(0)}% (${s}/${n})`)
return { scenarios: a, overall: +(s / n).toFixed(2) }
