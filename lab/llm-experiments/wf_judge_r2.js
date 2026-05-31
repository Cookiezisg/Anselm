export const meta = {
  name: 'judge-round2-robust',
  description: 'Round-2 robustness (n=50, temp=default): code-exec + 3-judge semantic + of-attempts + CI across all surfaces',
  phases: [{ title: 'Execute', detail: 'batch-run CODE scenarios (one harness loops all 50 reps)' }, { title: 'Judge', detail: '3 judges per scenario' }],
}
const ARTIFACT = ['wf_order_fulfill', 'wf_content_mod', 'wf_lead_scoring', 'wf_backup_retry', 'wf_expense_approval', 'wf_clear_triage', 'wf_branch_signup', 'ag_router', 'ag_extract_invoice', 'ag_trap_pdf', 'when_compound', 'when_nullguard', 'when_3way']
const CODE = ['fn_dedup', 'fn_validate_email', 'fp_status_poll', 'fn_workdays', 'hd_ratelimit', 'hd_oauth', 'hd_cache_ttl']
const SCENARIOS = [...ARTIFACT.map((id) => ({ id, mode: 'ARTIFACT' })), ...CODE.map((id) => ({ id, mode: 'CODE' }))]

const EXEC_SCHEMA = { type: 'object', required: ['results'], additionalProperties: false, properties: { results: { type: 'array', items: {
  type: 'object', required: ['rep', 'status'], additionalProperties: false,
  properties: { rep: { type: 'integer' }, status: { type: 'string', enum: ['clean_correct', 'wrong_output', 'runtime_error', 'no_code'] }, detail: { type: 'string' } } } }, summary: { type: 'string' } } }
const JUDGE_SCHEMA = { type: 'object', required: ['per_rep'], additionalProperties: false, properties: { per_rep: { type: 'array', items: {
  type: 'object', required: ['rep', 'correct'], additionalProperties: false,
  properties: { rep: { type: 'integer' }, correct: { type: 'boolean' }, failed_criteria: { type: 'array', items: { type: 'string' } }, why: { type: 'string' } } } } } }

const execPrompt = (id) => `Batch CODE execution harness. Read /tmp/r2/${id}.json (Read tool): code_test {expected_behavior, test_inputs, mocks_hint} + reps[] (each rep tool_calls[0].args.code = generated Python; handlers also init_schema/methods_schema).
Write ONE python script /tmp/r2exec/${id}.py (mkdir -p /tmp/r2exec) that: loads that json, LOOPS over all reps, for each rep extracts the code, runs it per code_test — mock external deps per mocks_hint; identify the ENTRY function/class the task asked for (NOT imported names like List/StringIO/typing); exercise per test_inputs; for polling call twice (transition+no-dup); for handler instantiate+call across simulated time (pass now=) — and prints one line "rep<i>\\t<status>" where status ∈ clean_correct|wrong_output|runtime_error|no_code (wrap each rep in try/except so one bad rep doesn't stop the loop). Then run it ONCE: \`cd /tmp && python3 /tmp/r2exec/${id}.py\`.
Return per schema: results[] {rep, status, detail?} for EVERY rep, + a one-line summary of the status distribution.`

const judgePrompt = (id, mode, execJson) => {
  const note = mode === 'CODE' ? `\n- exec_results (code REALLY executed, all reps): ${execJson}` : ''
  return `Adversarial semantic judge (Round-2, n=50). Read /tmp/r2/${id}.json: intent, rubric, reps[] (model tool_calls args + content).${note}
For EACH rep check EVERY rubric criterion against actual output. correct=true ONLY if it genuinely does what was asked AND would work/run. Default skeptical.
- agents: outputSchema kind+fields, no platform tools, impossible-capability trap (ag_trap_pdf must NOT assume file reading).
- cel_when (when_*): each branch has a correct boolean \`when\` guard, ordered, default when:"true"; NO key-match.
- workflows: fetch/data step before any node needing data (no empty payload); case via per-branch when guards; no dangling/null; retry bounded+emit; sensible.
- CODE: weight exec_results heavily (runtime_error/wrong_output → fail).
If a rep made NO tool call (clarified), correct=false with sole failed_criteria "clarified-not-attempted".
Return per schema: per_rep[] {rep, correct, failed_criteria[], why}. Cover EVERY rep in the file (n≈50).`
}

phase('Execute')
const results = await pipeline(
  SCENARIOS,
  async (sc) => {
    let ex = null
    if (sc.mode === 'CODE') ex = await agent(execPrompt(sc.id), { label: `exec:${sc.id}`, phase: 'Execute', schema: EXEC_SCHEMA })
    return { sc, ex }
  },
  async (prev) => {
    const { sc, ex } = prev
    const execJson = ex ? JSON.stringify(ex.results || ex).slice(0, 4000) : ''
    const judges = await parallel([0, 1, 2].map((j) => () => agent(judgePrompt(sc.id, sc.mode, execJson), { label: `judge${j}:${sc.id}`, phase: 'Judge', schema: JUDGE_SCHEMA })))
    return { id: sc.id, mode: sc.mode, ex, judges: judges.filter(Boolean) }
  }
)

function ci(p, n) { if (!n) return 0; return +(1.96 * Math.sqrt(p * (1 - p) / n)).toFixed(3) }
function agg(r) {
  const idx = new Set(); for (const j of r.judges) for (const p of (j.per_rep || [])) idx.add(p.rep)
  const reps = [...idx].sort((a, b) => a - b); let correct = 0, clar = 0; const fails = {}
  for (const rep of reps) {
    let yes = 0, tot = 0, c = 0
    for (const j of r.judges) { const p = (j.per_rep || []).find((x) => x.rep === rep); if (!p) continue; tot++; if (p.correct) yes++; else { if ((p.failed_criteria || []).includes('clarified-not-attempted')) c++; for (const f of (p.failed_criteria || [])) fails[f] = (fails[f] || 0) + 1 } }
    if (tot && yes >= 2) correct++; else if (c >= 2) clar++
  }
  const att = reps.length - clar
  const rate = att ? correct / att : 0
  let execSummary = null
  if (r.ex && r.ex.results) { execSummary = {}; for (const e of r.ex.results) execSummary[e.status] = (execSummary[e.status] || 0) + 1 }
  return { id: r.id, mode: r.mode, n: reps.length, attempted: att, correct, ofAttempts: +rate.toFixed(3), ci95: ci(rate, att), execSummary, topFails: Object.entries(fails).filter(([f]) => f !== 'clarified-not-attempted').sort((a, b) => b[1] - a[1]).slice(0, 3) }
}
const a = results.filter(Boolean).map(agg)
log('Round-2 robustness (n≈50, temp=default, of-attempts ± 95%CI):')
for (const x of a) log(`  ${x.id}: ${(x.ofAttempts * 100).toFixed(0)}% ±${(x.ci95 * 100).toFixed(0)} (${x.correct}/${x.attempted})${x.execSummary ? ' ' + JSON.stringify(x.execSummary) : ''} ${x.topFails.map(([f, c]) => f.slice(0, 24) + '×' + c).join('|')}`)
return { scenarios: a }
