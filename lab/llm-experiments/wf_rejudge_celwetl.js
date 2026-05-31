export const meta = {
  name: 'rejudge-celw-etl',
  description: 'Corrected re-judge: celw_timewindow/multifield (logic-focused, has()-optional, ||≡in) + bigwf_etl (true wiring check) — separate LOGIC-correctness from judge-strictness artifacts',
  phases: [{ title: 'Rejudge', detail: '3 logic-focused judges per scenario, of-attempts + CI' }],
}
const SCEN = ['celw_timewindow', 'celw_multifield', 'bigwf_etl']
const JUDGE_SCHEMA = { type: 'object', required: ['per_rep'], additionalProperties: false, properties: { per_rep: { type: 'array', items: {
  type: 'object', required: ['rep', 'correct'], additionalProperties: false,
  properties: { rep: { type: 'integer' }, correct: { type: 'boolean' }, failed_criteria: { type: 'array', items: { type: 'string' } }, why: { type: 'string' } } } } } }

const celwRules = `
THIS IS A LOGIC-CORRECTNESS judge — strip out style/artifact criteria that the previous judge over-penalized:
- has() wrappers are OPTIONAL, NOT required: the platform's case evaluator treats a guard that ERRORS (no-such-key) as false (falls through to the final when:true default). So a guard WITHOUT has() is SAFE and correct. Do NOT fail a rep for missing has().
- region=='US' || region=='EU' is LOGICALLY IDENTICAL to region in ["US","EU"]. Do NOT fail a rep for using OR instead of in[]. Both are correct.
- <18 vs <=18 boundary: rubric allows either if internally consistent. Do NOT fail on this.
correct=true if: (a) the boolean LOGIC of each branch matches the intent, (b) there is a final default branch (when:"true" or equivalent catch-all), (c) it uses per-branch when-guards (NOT a single expression that must key-match a branch name). Fail ONLY on genuinely wrong boolean logic, missing default, or key-match-instead-of-when.`

const etlRules = `
THIS IS A WIRING-CORRECTNESS judge for a large ETL workflow. Extract the REAL graph: add_node ops (id,type), add_edge ops (from→to), and each case node's branches[] (when + to). Then verify the actual data/control flow:
- cron/trigger → extract → validate in order (follow edges).
- validate routes via a case (when guards): fail-branch → quarantine + notify; pass-branch → transform.
- transform has a BOUNDED retry: a case routing retry-exhausted → deadletter, else (success) → load. Retry must EMIT an incremented counter on the back-edge AND be bounded (e.g. attempt<2/3). A retry with no emit, or unbounded, FAILS.
- load happens ONLY after transform success (load's inbound edge comes from the transform-success branch, never directly from transform-fail or validate).
- load → refresh_cache + notify_done.
- terminal nodes omit 'to' (no dangling). Every 'to'/'from'/branch target must reference a node that EXISTS in this workflow (no dangling ref).
correct=true ONLY if the wiring genuinely realizes this pipeline AND has no dangling refs AND retry is bounded+emitting. Be rigorous — this is the hardest forge task. But judge the ACTUAL edges/branches, not node naming style.`

const judgePrompt = (id) => `Adversarial semantic re-judge (logic/wiring-focused). Read /tmp/r2c/${id}.json: intent, rubric, reps[] (model tool_calls[0].args — for celw: args.branches{name:{when}}; for etl: args.ops[] with add_node/add_edge/case branches).
${id.startsWith('celw') ? celwRules : etlRules}
For EACH rep return {rep, correct, failed_criteria[], why}. Default skeptical on genuine logic/wiring errors, but do NOT penalize the artifacts called out above. No-tool-call → correct=false, failed_criteria=["clarified-not-attempted"]. Cover every rep.`

phase('Rejudge')
const results = await pipeline(SCEN, async (id) => {
  const judges = await parallel([0, 1, 2].map((j) => () => agent(judgePrompt(id), { label: `rejudge${j}:${id}`, phase: 'Rejudge', schema: JUDGE_SCHEMA })))
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
log('CORRECTED re-judge (logic/wiring-focused, n=30, of-attempts ±95%CI):')
for (const x of a) log(`  ${x.id}: ${(x.ofAttempts * 100).toFixed(0)}% ±${(x.ci95 * 100).toFixed(0)} (${x.attempted}) ${x.topFails.map(([f, c]) => f.slice(0, 30) + '×' + c).join('|')}`)
return { scenarios: a }
