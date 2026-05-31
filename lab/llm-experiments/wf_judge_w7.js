export const meta = {
  name: 'judge-wave7',
  description: 'Wave-7: judge create_workflow difficulty gradient (linear→complex) — map where the 55% comes from',
  phases: [{ title: 'Judge', detail: '3 adversarial judges per gradient scenario, majority + of-attempts' }],
}

const SCENARIOS = [
  { id: 'g1_linear', c: '1-linear' }, { id: 'g2_one_case', c: '2-one-case' }, { id: 'g3_two_case', c: '3-two-case' },
  { id: 'g4_loop', c: '4-loop' }, { id: 'g5_approval_timeout', c: '5-approval' }, { id: 'g6_complex', c: '6-complex' },
]

const JUDGE_SCHEMA = {
  type: 'object', required: ['per_rep'], additionalProperties: false,
  properties: { per_rep: { type: 'array', items: {
    type: 'object', required: ['rep', 'correct', 'why'], additionalProperties: false,
    properties: { rep: { type: 'integer' }, correct: { type: 'boolean' }, failed_criteria: { type: 'array', items: { type: 'string' } }, why: { type: 'string' } },
  } } },
}

const judgePrompt = (id) => `Adversarial semantic judge for Forgify workflow generation. Read /tmp/w7/${id}.json: intent, rubric, reps[] (each = the model's create_workflow tool_calls args, i.e. the graph ops).

For EACH rep, check EVERY rubric criterion against the actual graph the model built. correct=true ONLY if the graph genuinely implements the intent and would run. Watch for: dangling/null branch targets; case/approval nodes with redundant connect edges (should route via branches only); a node fed empty payload (missing fetch/data step); wrong/absent CEL conditions; unbounded loops; missing terminal handling.

If a rep made NO tool call (asked a clarifying question), set correct=false with sole failed_criteria "clarified-not-attempted" (not a quality defect).

Return per schema: per_rep[] with {rep, correct, failed_criteria[], why}. Cover every rep.`

phase('Judge')
const results = await pipeline(SCENARIOS, async (sc) => {
  const judges = await parallel([0, 1, 2].map((j) => () =>
    agent(judgePrompt(sc.id), { label: `judge${j}:${sc.id}`, phase: 'Judge', schema: JUDGE_SCHEMA })))
  return { ...sc, judges: judges.filter(Boolean) }
})

function agg(r) {
  const idx = new Set()
  for (const j of r.judges) for (const p of (j.per_rep || [])) idx.add(p.rep)
  const reps = [...idx].sort((a, b) => a - b)
  let correct = 0, clarified = 0
  const fails = {}
  for (const rep of reps) {
    let yes = 0, tot = 0, clar = 0
    for (const j of r.judges) {
      const p = (j.per_rep || []).find((x) => x.rep === rep); if (!p) continue
      tot++; if (p.correct) yes++
      else { if ((p.failed_criteria || []).includes('clarified-not-attempted')) clar++; for (const f of (p.failed_criteria || [])) fails[f] = (fails[f] || 0) + 1 }
    }
    if (tot && yes >= 2) correct++
    else if (clar >= 2) clarified++
  }
  const attempted = reps.length - clarified
  return { id: r.id, c: r.c, reps: reps.length, attempted, correct, raw: reps.length ? +(correct / reps.length).toFixed(2) : 0, ofAttempts: attempted ? +(correct / attempted).toFixed(2) : 0, topFails: Object.entries(fails).filter(([f]) => f !== 'clarified-not-attempted').sort((a, b) => b[1] - a[1]).slice(0, 3) }
}

const a = results.filter(Boolean).map(agg).sort((x, y) => x.c.localeCompare(y.c))
log('Wave-7 create_workflow difficulty gradient (of-attempts):')
for (const x of a) log(`  ${x.c}: ${(x.ofAttempts * 100).toFixed(0)}% (${x.correct}/${x.attempted})  ${x.topFails.map(([f, n]) => f.slice(0, 30) + '×' + n).join(' | ')}`)
return { gradient: a }
