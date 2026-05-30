export const meta = {
  name: 'judge-r3-complex',
  description: 'Judge the 300 HARD/COMPLEX forge scenarios. CODE surfaces (function/handler) batch-exec + 3 judges; ARTIFACT (workflow/cel/agent) 3 semantic judges. Per-surface of-attempts + CI.',
  phases: [{ title: 'Execute', detail: 'batch-run CODE surfaces' }, { title: 'Judge', detail: '3 judges/surface' }],
}
const ARTIFACT = ['create_workflow', 'cel_when', 'create_agent']
const CODE = ['create_function', 'create_handler']
const SURFACES = [...ARTIFACT.map((s) => ({ s, mode: 'ARTIFACT' })), ...CODE.map((s) => ({ s, mode: 'CODE' }))]

const EXEC_SCHEMA = { type: 'object', required: ['results'], additionalProperties: false, properties: { results: { type: 'array', items: {
  type: 'object', required: ['id', 'status'], additionalProperties: false,
  properties: { id: { type: 'string' }, status: { type: 'string', enum: ['clean_correct', 'wrong_output', 'runtime_error', 'no_code'] }, detail: { type: 'string' } } } } } }
const JUDGE_SCHEMA = { type: 'object', required: ['per'], additionalProperties: false, properties: { per: { type: 'array', items: {
  type: 'object', required: ['id', 'correct'], additionalProperties: false,
  properties: { id: { type: 'string' }, correct: { type: 'boolean' }, failed: { type: 'array', items: { type: 'string' } } } } } } }

const execPrompt = (s) => `Batch CODE-exec harness. Read /tmp/r3cxres/${s}.json: array of {id, code, code_test, intent, rubric}. Write ONE /tmp/r3cxexec/${s}.py (mkdir -p) that loads the json, LOOPS all items, for each: exec the item.code, identify the entry function/class, exercise it per item.code_test (inputs/scenario + edge cases; for handlers mock a clock if it takes 'now'/uses time; wrap each in try/except), print "<id>\\t<status>" (clean_correct|wrong_output|runtime_error|no_code). Run ONCE: \`cd /tmp && python3 /tmp/r3cxexec/${s}.py\`. Return EXEC_SCHEMA for EVERY item.`

const judgePrompt = (s, mode, ex) => {
  const note = mode === 'CODE' ? `\n- exec_results (real run): ${ex}` : ''
  return `Adversarial semantic judge — HARD/COMPLEX forge scenarios for ${s}. Read /tmp/r3cxres/${s}.json: array of {id, user, intent, rubric, called, tool_calls, code}.${note}
For EACH item: correct=true ONLY if it called the right forge tool AND the artifact genuinely satisfies EVERY rubric check (these are HARD: large multi-node graphs with when-guards/retry/no-dangling; complex null-safe when-guards; complex stateful handlers; complex algorithms). Weight exec_results heavily for CODE. No-tool-call with a genuine clarification need → failed:["clarified"]. Default skeptical.
Return JUDGE_SCHEMA: per[]{id, correct, failed[]}. Cover EVERY item.`
}

phase('Execute')
const results = await pipeline(SURFACES,
  async (sc) => ({ sc, ex: sc.mode === 'CODE' ? await agent(execPrompt(sc.s), { label: `exec:${sc.s}`, phase: 'Execute', schema: EXEC_SCHEMA }).catch(() => null) : null }),
  async (prev) => {
    const { sc, ex } = prev
    const ej = ex ? JSON.stringify(ex.results || ex).slice(0, 5000) : ''
    const judges = await parallel([0, 1, 2].map((j) => () => agent(judgePrompt(sc.s, sc.mode, ej), { label: `j${j}:${sc.s}`, phase: 'Judge', schema: JUDGE_SCHEMA }).catch(() => null)))
    return { s: sc.s, mode: sc.mode, ex, judges: judges.filter(Boolean) }
  })
function ci(p, n) { return n ? +(1.96 * Math.sqrt(p * (1 - p) / n)).toFixed(3) : 0 }
function agg(r) {
  const idx = new Set(); for (const j of r.judges) for (const p of (j.per || [])) idx.add(p.id)
  const ids = [...idx]; let correct = 0, clar = 0; const fails = {}
  for (const id of ids) {
    let yes = 0, tot = 0, c = 0
    for (const j of r.judges) { const p = (j.per || []).find((x) => x.id === id); if (!p) continue; tot++; if (p.correct) yes++; else { if ((p.failed || []).includes('clarified')) c++; for (const f of (p.failed || [])) fails[f] = (fails[f] || 0) + 1 } }
    if (!tot) continue
    if (yes >= Math.ceil(tot / 2)) correct++; else if (c >= Math.ceil(tot / 2)) clar++
  }
  const n = ids.length, att = n - clar, rate = att ? correct / att : 0
  let es = null; if (r.ex && r.ex.results) { es = {}; for (const e of r.ex.results) es[e.status] = (es[e.status] || 0) + 1 }
  return { s: r.s, n, attempted: att, ofAttempts: +rate.toFixed(2), ci95: ci(rate, att), execSummary: es,
    topFails: Object.entries(fails).filter(([f]) => f !== 'clarified').sort((a, b) => b[1] - a[1]).slice(0, 3) }
}
const a = results.filter(Boolean).map(agg)
log('R3 COMPLEX (hard forge, of-attempts ±95%CI):')
for (const x of a) log(`  ${x.s}: ${(x.ofAttempts * 100).toFixed(0)}% ±${Math.round(x.ci95 * 100)} (${x.attempted}/${x.n})${x.execSummary ? ' ' + JSON.stringify(x.execSummary) : ''} ${x.topFails.map(([f, c]) => f.slice(0, 24) + '×' + c).join('|')}`)
return { surfaces: a }
