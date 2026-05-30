export const meta = {
  name: 'judge-wave9',
  description: 'Wave-9 breadth: confirm strong-surface rates generalize on diverse scenarios — code-exec + 3-judge semantic + of-attempts',
  phases: [{ title: 'Execute', detail: 'run CODE scenarios' }, { title: 'Judge', detail: '3 judges per scenario, of-attempts' }],
}

const SCENARIOS = [
  { id: 'ag_router', mode: 'ARTIFACT' }, { id: 'ag_extract_invoice', mode: 'ARTIFACT' }, { id: 'ag_trap_pdf', mode: 'ARTIFACT' },
  { id: 'fn_dedup', mode: 'CODE' }, { id: 'fn_validate_email', mode: 'CODE' }, { id: 'fp_status_poll', mode: 'CODE' }, { id: 'hd_ratelimit', mode: 'CODE' },
  { id: 'cel_3way', mode: 'ARTIFACT' }, { id: 'cel_compound', mode: 'ARTIFACT' }, { id: 'cel_nullguard', mode: 'ARTIFACT' },
]

const EXEC_SCHEMA = { type: 'object', required: ['results'], additionalProperties: false, properties: { results: { type: 'array', items: {
  type: 'object', required: ['rep', 'status', 'detail'], additionalProperties: false,
  properties: { rep: { type: 'integer' }, status: { type: 'string', enum: ['clean_correct', 'wrong_output', 'runtime_error', 'no_code'] }, detail: { type: 'string' }, actual: { type: 'string' } } } } } }
const JUDGE_SCHEMA = { type: 'object', required: ['per_rep'], additionalProperties: false, properties: { per_rep: { type: 'array', items: {
  type: 'object', required: ['rep', 'correct', 'why'], additionalProperties: false,
  properties: { rep: { type: 'integer' }, correct: { type: 'boolean' }, failed_criteria: { type: 'array', items: { type: 'string' } }, why: { type: 'string' } } } } } }

const execPrompt = (id) => `Strict-but-fair CODE EXECUTION harness. Read /tmp/w9/${id}.json (Read tool): intent, code_test {expected_behavior, test_inputs, mocks_hint}, reps[] each with tool_calls[0].args (generated Python in args.code; functions also args.kind; handlers args.init_schema/methods_schema).
For EACH rep: extract the code, write /tmp/exec9/${id}_rep<r>.py that mocks deps per mocks_hint, includes the code verbatim, exercises it per test_inputs printing labeled outputs; run \`mkdir -p /tmp/exec9 && cd /tmp && python3 /tmp/exec9/${id}_rep<r>.py\`. IMPORTANT: call the ENTRY function the user asked for (NOT imported names like List/StringIO). Classify: clean_correct / wrong_output / runtime_error / no_code. Stub external deps per hint; judge LOGIC. polling: poll twice (transition + no-dup). handler: instantiate + call across simulated time (pass now=).
Return per schema: results[] {rep, status, detail, actual}.`

const judgePrompt = (id, mode, execJson) => {
  const note = mode === 'CODE' ? `\n- exec_results (code REALLY executed): ${execJson}` : ''
  return `Adversarial semantic judge. Read /tmp/w9/${id}.json: intent, rubric, reps[] (model's tool_calls args + content).${note}
For EACH rep check EVERY rubric criterion against actual output. correct=true ONLY if it genuinely does what was asked AND would work/run. Default skeptical; name failed criteria. For agents: outputSchema kind + fields + no-platform-tools + the impossible-capability trap (ag_trap_pdf: must NOT assume file-reading). For CEL: expression-value-must-equal-branch-key (boolean expr needs true/false keys or ternary returning key). If a rep made NO tool call (clarified), correct=false with sole failed_criteria "clarified-not-attempted".
Return per schema: per_rep[] {rep, correct, failed_criteria[], why}. Cover every rep.`
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
    const execJson = ex ? JSON.stringify(ex.results || ex) : ''
    const judges = await parallel([0, 1, 2].map((j) => () => agent(judgePrompt(sc.id, sc.mode, execJson), { label: `judge${j}:${sc.id}`, phase: 'Judge', schema: JUDGE_SCHEMA })))
    return { id: sc.id, mode: sc.mode, ex, judges: judges.filter(Boolean) }
  }
)

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
    if (tot && yes >= 2) correct++; else if (clar >= 2) clarified++
  }
  const attempted = reps.length - clarified
  let execSummary = null
  if (r.ex && r.ex.results) { execSummary = {}; for (const e of r.ex.results) execSummary[e.status] = (execSummary[e.status] || 0) + 1 }
  return { id: r.id, mode: r.mode, reps: reps.length, attempted, correct, ofAttempts: attempted ? +(correct / attempted).toFixed(2) : 0, execSummary, topFails: Object.entries(fails).filter(([f]) => f !== 'clarified-not-attempted').sort((a, b) => b[1] - a[1]).slice(0, 3) }
}

const a = results.filter(Boolean).map(agg)
log('Wave-9 breadth (does strong-surface quality generalize?):')
for (const x of a) log(`  ${x.id}: ofAttempts ${(x.ofAttempts * 100).toFixed(0)}% (${x.correct}/${x.attempted})${x.execSummary ? ' exec=' + JSON.stringify(x.execSummary) : ''} ${x.topFails.map(([f, n]) => f.slice(0, 28) + '×' + n).join('|')}`)
return { scenarios: a }
