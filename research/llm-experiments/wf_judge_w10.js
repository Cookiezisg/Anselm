export const meta = {
  name: 'judge-wave10',
  description: 'Wave-10: validate when:-branch case design — judge per-branch boolean guards (vs key-match 0-18%)',
  phases: [{ title: 'Judge', detail: '3 judges per when:-scenario' }],
}
const SCENARIOS = ['when_compound', 'when_nullguard', 'when_3way']
const JUDGE_SCHEMA = { type: 'object', required: ['per_rep'], additionalProperties: false, properties: { per_rep: { type: 'array', items: {
  type: 'object', required: ['rep', 'correct', 'why'], additionalProperties: false,
  properties: { rep: { type: 'integer' }, correct: { type: 'boolean' }, failed_criteria: { type: 'array', items: { type: 'string' } }, why: { type: 'string' } } } } } }

const judgePrompt = (id) => `Adversarial semantic judge. The case node uses per-branch \`when:\` boolean guards (first true wins; final when:"true" = default) — NOT key matching. Read /tmp/w10/${id}.json: intent, rubric, reps[] (model's set_case_branches args.branches).
For EACH rep check EVERY rubric criterion: is each branch's \`when\` a CORRECT boolean CEL for that branch's intent? is there a default (when:"true")? is the ORDER correct (e.g. high>=80 before mid>=50 so 90→high)? null-safe with has() where needed? targets correct?
correct=true ONLY if the per-branch when guards genuinely implement the routing. Default skeptical; name failed criteria. If no tool call, correct=false "clarified-not-attempted".
Return per schema: per_rep[] {rep, correct, failed_criteria[], why}.`

phase('Judge')
const results = await pipeline(SCENARIOS, async (id) => {
  const judges = await parallel([0, 1, 2].map((j) => () => agent(judgePrompt(id), { label: `judge${j}:${id}`, phase: 'Judge', schema: JUDGE_SCHEMA })))
  return { id, judges: judges.filter(Boolean) }
})
function agg(r) {
  const idx = new Set(); for (const j of r.judges) for (const p of (j.per_rep || [])) idx.add(p.rep)
  const reps = [...idx].sort((a, b) => a - b); let correct = 0; const fails = {}
  for (const rep of reps) { let yes = 0, tot = 0; for (const j of r.judges) { const p = (j.per_rep || []).find((x) => x.rep === rep); if (!p) continue; tot++; if (p.correct) yes++; else for (const f of (p.failed_criteria || [])) fails[f] = (fails[f] || 0) + 1 } if (tot && yes >= 2) correct++ }
  return { id: r.id, reps: reps.length, correct, rate: reps.length ? +(correct / reps.length).toFixed(2) : 0, topFails: Object.entries(fails).sort((a, b) => b[1] - a[1]).slice(0, 3) }
}
const a = results.filter(Boolean).map(agg)
log('Wave-10 when:-branch design (key-match was: compound 0%, nullguard 18%, 3way 100%):')
for (const x of a) log(`  ${x.id}: ${(x.rate * 100).toFixed(0)}% (${x.correct}/${x.reps}) ${x.topFails.map(([f, n]) => f.slice(0, 30) + '×' + n).join('|')}`)
return { scenarios: a, mean: +(a.reduce((s, x) => s + x.rate, 0) / a.length).toFixed(2) }
