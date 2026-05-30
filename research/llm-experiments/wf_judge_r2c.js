export const meta = {
  name: 'judge-round2-complex',
  description: 'Round-2 complex single-shot: large workflows / complex CEL-when / complex handlers+polling — code-exec + 3-judge + CI',
  phases: [{ title: 'Execute', detail: 'batch-run CODE scenarios' }, { title: 'Judge', detail: '3 judges per scenario' }],
}
const ARTIFACT = ['bigwf_ecommerce', 'bigwf_support', 'bigwf_etl', 'celw_timewindow', 'celw_multifield', 'celw_5way']
const CODE = ['hd_sliding', 'hd_connpool', 'fp_multisource']
const SCENARIOS = [...ARTIFACT.map((id) => ({ id, mode: 'ARTIFACT' })), ...CODE.map((id) => ({ id, mode: 'CODE' }))]

const EXEC_SCHEMA = { type: 'object', required: ['results'], additionalProperties: false, properties: { results: { type: 'array', items: {
  type: 'object', required: ['rep', 'status'], additionalProperties: false,
  properties: { rep: { type: 'integer' }, status: { type: 'string', enum: ['clean_correct', 'wrong_output', 'runtime_error', 'no_code'] }, detail: { type: 'string' } } } } } }
const JUDGE_SCHEMA = { type: 'object', required: ['per_rep'], additionalProperties: false, properties: { per_rep: { type: 'array', items: {
  type: 'object', required: ['rep', 'correct'], additionalProperties: false,
  properties: { rep: { type: 'integer' }, correct: { type: 'boolean' }, failed_criteria: { type: 'array', items: { type: 'string' } }, why: { type: 'string' } } } } } }

const execPrompt = (id) => `Batch CODE execution harness. Read /tmp/r2c/${id}.json: code_test + reps[] (tool_calls[0].args.code). Write ONE /tmp/r2cexec/${id}.py (mkdir -p) that loads the json, LOOPS all reps, runs each per code_test (mock deps per mocks_hint; identify the ENTRY function/class NOT imported names; sliding-window/conn-pool/polling: exercise per test_inputs incl edge cases; wrap each rep in try/except), prints "rep<i>\\t<status>" (clean_correct|wrong_output|runtime_error|no_code). Run ONCE: \`cd /tmp && python3 /tmp/r2cexec/${id}.py\`. Return per schema for EVERY rep.`

const judgePrompt = (id, mode, ex) => {
  const note = mode === 'CODE' ? `\n- exec_results (real run, all reps): ${ex}` : ''
  return `Adversarial semantic judge (Round-2 complex, n≈30). Read /tmp/r2c/${id}.json: intent, rubric, reps[].${note}
For EACH rep check EVERY rubric criterion. correct=true ONLY if genuinely correct + runnable. These are HARD: large workflows (≥10 nodes, multi-case/loop/approval, data flows, when guards, no dangling), complex when-guards (time-window/multi-field/5-way ordered), complex stateful code (sliding-window NOT fixed, conn-pool maxing, multi-source dedup + restart-safe cursor). Weight exec_results heavily for CODE. No-tool-call → "clarified-not-attempted".
Return per schema: per_rep[] {rep, correct, failed_criteria[], why}. Cover every rep.`
}

phase('Execute')
const results = await pipeline(SCENARIOS,
  async (sc) => ({ sc, ex: sc.mode === 'CODE' ? await agent(execPrompt(sc.id), { label: `exec:${sc.id}`, phase: 'Execute', schema: EXEC_SCHEMA }) : null }),
  async (prev) => {
    const { sc, ex } = prev
    const ej = ex ? JSON.stringify(ex.results || ex).slice(0, 4000) : ''
    const judges = await parallel([0, 1, 2].map((j) => () => agent(judgePrompt(sc.id, sc.mode, ej), { label: `judge${j}:${sc.id}`, phase: 'Judge', schema: JUDGE_SCHEMA })))
    return { id: sc.id, mode: sc.mode, ex, judges: judges.filter(Boolean) }
  }
)
function ci(p, n) { return n ? +(1.96 * Math.sqrt(p * (1 - p) / n)).toFixed(3) : 0 }
function agg(r) {
  const idx = new Set(); for (const j of r.judges) for (const p of (j.per_rep || [])) idx.add(p.rep)
  const reps = [...idx].sort((a, b) => a - b); let correct = 0, clar = 0; const fails = {}
  for (const rep of reps) { let yes = 0, tot = 0, c = 0; for (const j of r.judges) { const p = (j.per_rep || []).find((x) => x.rep === rep); if (!p) continue; tot++; if (p.correct) yes++; else { if ((p.failed_criteria || []).includes('clarified-not-attempted')) c++; for (const f of (p.failed_criteria || [])) fails[f] = (fails[f] || 0) + 1 } } if (tot && yes >= 2) correct++; else if (c >= 2) clar++ }
  const att = reps.length - clar, rate = att ? correct / att : 0
  let es = null; if (r.ex && r.ex.results) { es = {}; for (const e of r.ex.results) es[e.status] = (es[e.status] || 0) + 1 }
  return { id: r.id, mode: r.mode, n: reps.length, attempted: att, ofAttempts: +rate.toFixed(3), ci95: ci(rate, att), execSummary: es, topFails: Object.entries(fails).filter(([f]) => f !== 'clarified-not-attempted').sort((a, b) => b[1] - a[1]).slice(0, 3) }
}
const a = results.filter(Boolean).map(agg)
log('Round-2 COMPLEX (n≈30, temp=default, of-attempts ±95%CI):')
for (const x of a) log(`  ${x.id}: ${(x.ofAttempts * 100).toFixed(0)}% ±${(x.ci95 * 100).toFixed(0)} (${x.attempted})${x.execSummary ? ' ' + JSON.stringify(x.execSummary) : ''} ${x.topFails.map(([f, c]) => f.slice(0, 22) + '×' + c).join('|')}`)
return { scenarios: a }
