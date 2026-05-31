export const meta = {
  name: 'judge-wave1',
  description: 'Wave-1: execute generated code + adversarial 3-judge semantic verdict over crown-jewel forge trajectories',
  phases: [
    { title: 'Execute', detail: 'really run generated function/handler code with mocks' },
    { title: 'Judge', detail: '3 adversarial semantic judges per scenario, majority vote per rep' },
  ],
}

// Wave-1 scenarios (trajectories already generated to /tmp/w1/<id>.json by wave1_gen.py)
const SCENARIOS = [
  { id: 'wf_clear_triage', surface: 'create_workflow', mode: 'ARTIFACT' },
  { id: 'wf_vague_daily', surface: 'create_workflow', mode: 'ARTIFACT' },
  { id: 'wf_retry_loop', surface: 'create_workflow', mode: 'ARTIFACT' },
  { id: 'wf_branch_signup', surface: 'create_workflow', mode: 'ARTIFACT' },
  { id: 'ag_enum_sentiment', surface: 'create_agent', mode: 'ARTIFACT' },
  { id: 'ag_json_extract', surface: 'create_agent', mode: 'ARTIFACT' },
  { id: 'ag_trap_web', surface: 'create_agent', mode: 'ARTIFACT' },
  { id: 'fn_workdays', surface: 'create_function', mode: 'CODE' },
  { id: 'fn_csv_parse', surface: 'create_function', mode: 'CODE' },
  { id: 'fp_rss', surface: 'create_function', mode: 'CODE' },
  { id: 'fp_dirwatch', surface: 'create_function', mode: 'CODE' },
  { id: 'hd_oauth', surface: 'create_handler', mode: 'CODE' },
  { id: 'hd_cache_ttl', surface: 'create_handler', mode: 'CODE' },
  { id: 'cel_vip_approval', surface: 'cel_case', mode: 'ARTIFACT' },
  { id: 'cel_retry_deadletter', surface: 'cel_case', mode: 'ARTIFACT' },
  { id: 'cel_nullsafe_items', surface: 'cel_case', mode: 'ARTIFACT' },
]

const EXEC_SCHEMA = {
  type: 'object', required: ['results'], additionalProperties: false,
  properties: {
    results: {
      type: 'array',
      items: {
        type: 'object', required: ['rep', 'status', 'detail'], additionalProperties: false,
        properties: {
          rep: { type: 'integer' },
          status: { type: 'string', enum: ['clean_correct', 'wrong_output', 'runtime_error', 'no_code'] },
          detail: { type: 'string' },
          actual: { type: 'string' },
        },
      },
    },
  },
}

const JUDGE_SCHEMA = {
  type: 'object', required: ['per_rep'], additionalProperties: false,
  properties: {
    per_rep: {
      type: 'array',
      items: {
        type: 'object', required: ['rep', 'correct', 'why'], additionalProperties: false,
        properties: {
          rep: { type: 'integer' },
          correct: { type: 'boolean' },
          failed_criteria: { type: 'array', items: { type: 'string' } },
          why: { type: 'string' },
        },
      },
    },
  },
}

const execPrompt = (id) => `You are a strict-but-fair CODE EXECUTION harness for Forgify's LLM tool-design research.

Read the trajectory file with the Read tool: /tmp/w1/${id}.json
It contains: intent (what the user asked), code_test {expected_behavior, test_inputs, mocks_hint}, and reps[] where each rep has tool_calls[0].args holding the generated Python (args.code; for functions also args.kind; for handlers also args.init_schema / args.methods_schema).

For EACH rep, ACTUALLY RUN the generated code:
1. Extract the generated Python from the rep's tool_calls.
2. Write a self-contained test file /tmp/exec/${id}_rep<r>.py that: (a) mocks external deps MINIMALLY per mocks_hint so no real network/files are needed, (b) includes the generated code verbatim, (c) exercises it per test_inputs and prints clearly-labeled outputs.
3. Run it with Bash: \`mkdir -p /tmp/exec && cd /tmp && python3 /tmp/exec/${id}_rep<r>.py\`
4. Classify status for that rep:
   - clean_correct: runs without error AND output matches expected_behavior
   - wrong_output: runs but output is semantically wrong vs expected_behavior
   - runtime_error: raises / fails to run (include the error in detail)
   - no_code: no extractable code in that rep
Be a REAL executor: if code calls an external dependency, STUB it per the hint — do NOT fail it merely for missing network/library; judge the LOGIC. For polling: call poll twice to check cursor advance + no duplicate emission. For handler: instantiate + call methods across simulated time (pass now= or monkeypatch time).

Return JSON per schema: results[] with {rep, status, detail (one line), actual (observed output, truncated)}. Cover every rep present in the file.`

const judgePrompt = (id, mode, execJson) => {
  const execNote = mode === 'CODE'
    ? `\n- exec_results: the code was REALLY EXECUTED. Per-rep run outcomes (weight runtime_error / wrong_output heavily): ${execJson}`
    : ''
  return `You are an ADVERSARIAL semantic judge for Forgify's LLM tool-design research. A weak model (DeepSeek V4-flash) was asked to do a task; judge whether each attempt SEMANTICALLY accomplishes it — NOT merely whether the JSON shape is valid. Structural validity is not the bar; real correctness is.

Read /tmp/w1/${id}.json with the Read tool:
- intent: what was asked
- rubric: the list of semantic criteria — check EVERY one
- reps[]: each rep = the model's tool_calls (args) + content + reasoning${execNote}

For EACH rep:
- Check every rubric criterion against the rep's ACTUAL output.
- correct = true ONLY if it genuinely does what was asked AND would actually work/run.
- Default SKEPTICAL: if any criterion is violated, dubious, or only superficially satisfied, set correct=false and name the failed criteria with the specific defect (quote the offending part). Example real defects: a workflow that feeds an empty payload to a classifier; a dangling/null branch target; a CEL using > instead of >=; a polling fn that re-emits old items; a handler taking a dict instead of bare-named params.

If a rep made NO tool call (it asked a reasonable clarifying question instead of producing the artifact), set correct=false and put exactly "clarified-not-attempted" as the sole failed_criteria — this is NOT a quality defect, it just produced no artifact to judge (we track it separately).

Return JSON per schema: per_rep[] with {rep, correct, failed_criteria[], why}. Be concrete; name the exact defect. Cover every rep in the file.`
}

// ---- run ----
phase('Execute')
const results = await pipeline(
  SCENARIOS,
  // stage 1: execute code (CODE scenarios only)
  async (sc) => {
    let execResult = null
    if (sc.mode === 'CODE') {
      execResult = await agent(execPrompt(sc.id), {
        label: `exec:${sc.id}`, phase: 'Execute', schema: EXEC_SCHEMA,
      })
    }
    return { sc, execResult }
  },
  // stage 2: 3 adversarial judges, majority vote
  async (prev) => {
    const { sc, execResult } = prev
    const execJson = execResult ? JSON.stringify(execResult.results || execResult) : ''
    const judges = await parallel(
      [0, 1, 2].map((j) => () =>
        agent(judgePrompt(sc.id, sc.mode, execJson), {
          label: `judge${j}:${sc.id}`, phase: 'Judge', schema: JUDGE_SCHEMA,
        })
      )
    )
    return { id: sc.id, surface: sc.surface, mode: sc.mode, execResult, judges: judges.filter(Boolean) }
  }
)

// ---- aggregate (plain JS, no agent) ----
function aggregate(r) {
  const judges = r.judges || []
  // collect rep indices seen
  const repIdx = new Set()
  for (const j of judges) for (const p of (j.per_rep || [])) repIdx.add(p.rep)
  const reps = [...repIdx].sort((a, b) => a - b)
  let correctCount = 0
  const failClusters = {}
  const perRep = []
  for (const rep of reps) {
    let yes = 0, total = 0
    const fails = []
    for (const j of judges) {
      const p = (j.per_rep || []).find((x) => x.rep === rep)
      if (!p) continue
      total++
      if (p.correct) yes++
      else for (const fc of (p.failed_criteria || [])) { fails.push(fc); failClusters[fc] = (failClusters[fc] || 0) + 1 }
    }
    const majority = total > 0 && yes >= Math.ceil(total / 2) && yes >= 2
    if (majority) correctCount++
    perRep.push({ rep, yes, total, majority, fails })
  }
  const rate = reps.length ? correctCount / reps.length : 0
  // exec summary
  let execSummary = null
  if (r.execResult && r.execResult.results) {
    execSummary = {}
    for (const e of r.execResult.results) execSummary[e.status] = (execSummary[e.status] || 0) + 1
  }
  const topFails = Object.entries(failClusters).sort((a, b) => b[1] - a[1]).filter(([f]) => f !== 'clarified-not-attempted').slice(0, 6)
  // clarified = rep where majority judges said "clarified-not-attempted" (no artifact; NOT a quality failure)
  let clarified = 0
  for (const pr of perRep) {
    if (!pr.majority) {
      const cl = pr.fails.filter((f) => f === 'clarified-not-attempted').length
      if (cl >= Math.ceil(pr.total / 2)) clarified++
    }
  }
  const attempted = reps.length - clarified
  const ofAttempts = attempted ? +(correctCount / attempted).toFixed(3) : 0
  return { id: r.id, surface: r.surface, mode: r.mode, reps: reps.length, attempted, clarified, semantic_rate: rate, ofAttemptsRate: ofAttempts, correctReps: correctCount, perRep, execSummary, topFails }
}

const agg = results.filter(Boolean).map(aggregate)
const bySurface = {}
for (const a of agg) {
  if (!bySurface[a.surface]) bySurface[a.surface] = { reps: 0, correct: 0, attempted: 0 }
  bySurface[a.surface].reps += a.reps
  bySurface[a.surface].correct += a.correctReps
  bySurface[a.surface].attempted += a.attempted
}
const surfaceRates = Object.fromEntries(
  Object.entries(bySurface).map(([s, v]) => [s, { rate: v.reps ? +(v.correct / v.reps).toFixed(3) : 0, ofAttempts: v.attempted ? +(v.correct / v.attempted).toFixed(3) : 0, n: v.reps, attempted: v.attempted }])
)

log(`Wave-1 judged: ${agg.length} scenarios`)
for (const a of agg) log(`  ${a.id}: semantic ${(a.semantic_rate * 100).toFixed(0)}% (${a.correctReps}/${a.reps})${a.execSummary ? ' exec=' + JSON.stringify(a.execSummary) : ''}`)

return { scenarios: agg, surfaceRates }
