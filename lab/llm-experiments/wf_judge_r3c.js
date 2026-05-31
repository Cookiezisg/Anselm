export const meta = {
  name: 'judge-r3c-allfixes',
  description: 'Judge R3-C all-fixes re-run (/tmp/r3cres, create_workflow + cel_when) with IDENTICAL criteria to the baseline complex judge — for a fair pinned-schema-lift comparison.',
  phases: [{ title: 'Judge', detail: '3 judges per surface' }],
}
const SURFACES = ['create_workflow', 'cel_when']
const JUDGE_SCHEMA = { type: 'object', required: ['per'], additionalProperties: false, properties: { per: { type: 'array', items: {
  type: 'object', required: ['id', 'correct'], additionalProperties: false,
  properties: { id: { type: 'string' }, correct: { type: 'boolean' }, failed: { type: 'array', items: { type: 'string' } } } } } } }

const judgePrompt = (s) => `Adversarial semantic judge — HARD/COMPLEX ${s} forge scenarios (this set was built with a G10-pinned schema: case uses per-branch when-guards, node.config pinned per type). Read /tmp/r3cres/${s}.json: array of {id, user, intent, rubric, called, tool_calls}.
For EACH item: correct=true ONLY if it called create_workflow AND the graph genuinely satisfies EVERY rubric check — large multi-node graphs with correct node types & order, case routing via per-branch when guards (no key-match, final when:'true' default), retry bounded+emit if present, terminal omits to, no dangling refs, first node after cron fetches data. Default skeptical. No-tool-call with genuine clarification need → failed:["clarified"].
Return per schema: per[]{id, correct, failed[]}. Cover EVERY item.`

phase('Judge')
const results = await parallel(SURFACES.map((s) => () =>
  parallel([0, 1, 2].map((j) => () => agent(judgePrompt(s), { label: `j${j}:${s}`, phase: 'Judge', schema: JUDGE_SCHEMA }).catch(() => null)))
    .then((judges) => ({ s, judges: judges.filter(Boolean) }))))
function ci(p, n) { return n ? +(1.96 * Math.sqrt(p * (1 - p) / n)).toFixed(3) : 0 }
function agg(r) {
  const idx = new Set(); for (const j of r.judges) for (const p of (j.per || [])) idx.add(p.id)
  const ids = [...idx]; let correct = 0, clar = 0
  for (const id of ids) {
    let yes = 0, tot = 0, c = 0
    for (const j of r.judges) { const p = (j.per || []).find((x) => x.id === id); if (!p) continue; tot++; if (p.correct) yes++; else if ((p.failed || []).includes('clarified')) c++ }
    if (!tot) continue
    if (yes >= Math.ceil(tot / 2)) correct++; else if (c >= Math.ceil(tot / 2)) clar++
  }
  const n = ids.length, att = n - clar, rate = att ? correct / att : 0
  return { s: r.s, n, attempted: att, ofAttempts: +rate.toFixed(2), ci95: ci(rate, att) }
}
const a = results.filter(Boolean).map(agg)
log('R3-C all-fixes (pinned schema, of-attempts ±95%CI):')
for (const x of a) log(`  ${x.s}: ${(x.ofAttempts * 100).toFixed(0)}% ±${Math.round(x.ci95 * 100)} (${x.attempted}/${x.n})`)
return { surfaces: a }
