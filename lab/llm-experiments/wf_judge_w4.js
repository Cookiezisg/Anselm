export const meta = {
  name: 'judge-wave4',
  description: 'Wave-4: adversarial 3-judge semantic verdict over CONTENT/utility outputs (auto-title/rerank/compaction/env-fix/web-summary/doc/memory)',
  phases: [{ title: 'Judge', detail: '3 judges per utility scenario, majority vote per rep' }],
}

const SCENARIOS = ['auto_title', 'rerank_fn', 'rerank_skill', 'compaction', 'env_fix', 'web_summary', 'doc_create', 'mem_write']

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

const judgePrompt = (id) => `You are an ADVERSARIAL semantic judge for Forgify's LLM tool-design research. The weak model (DeepSeek) produced UTILITY/CONTENT outputs; judge whether each output actually does what was asked — content correctness, not just plausible shape.

Read /tmp/w4/${id}.json (Read tool): it has the prompt context, rubric (criteria to check), expected_hint, and reps[] (each = the model's raw output string).

For EACH rep, check every rubric criterion against the rep's output:
- For JSON-output tasks (rerank/env_fix/mem_write): the output MUST be valid parseable JSON of the right shape (a JSON array of ids, or {deps:[...]}, or {name,content}) with NO surrounding prose/markdown fences — if it's wrapped in prose or a \`\`\`json fence, note it (borderline) but judge the core content; if it's not parseable JSON at all, fail "valid JSON".
- For auto_title: ≤6 words, on-topic, no surrounding quotes, no trailing punctuation/markdown.
- For compaction: must preserve the specific key facts in the rubric (ids, task state, open questions, root cause) and not invent facts.
- For env_fix: must map bs4→beautifulsoup4 (the pip name), correct packages.
- For web_summary: accurate to the page, no hallucinated numbers.
- correct=true ONLY if it genuinely satisfies the rubric. Default SKEPTICAL; name failed criteria with the specific defect (quote the offending part).

Return per schema: per_rep[] with {rep, correct, failed_criteria[], why}. Cover every rep.`

phase('Judge')
const results = await pipeline(
  SCENARIOS,
  async (id) => {
    const judges = await parallel([0, 1, 2].map((j) => () =>
      agent(judgePrompt(id), { label: `judge${j}:${id}`, phase: 'Judge', schema: JUDGE_SCHEMA })
    ))
    return { id, judges: judges.filter(Boolean) }
  }
)

function agg(r) {
  const idx = new Set()
  for (const j of r.judges) for (const p of (j.per_rep || [])) idx.add(p.rep)
  const reps = [...idx].sort((a, b) => a - b)
  let correct = 0
  const fails = {}
  for (const rep of reps) {
    let yes = 0, tot = 0
    for (const j of r.judges) {
      const p = (j.per_rep || []).find((x) => x.rep === rep)
      if (!p) continue
      tot++
      if (p.correct) yes++
      else for (const f of (p.failed_criteria || [])) fails[f] = (fails[f] || 0) + 1
    }
    if (tot && yes >= 2) correct++
  }
  return { id: r.id, reps: reps.length, correct, rate: reps.length ? +(correct / reps.length).toFixed(3) : 0, topFails: Object.entries(fails).sort((a, b) => b[1] - a[1]).slice(0, 4) }
}

const a = results.filter(Boolean).map(agg)
log(`Wave-4 utility/content judged: ${a.length} scenarios`)
for (const x of a) log(`  ${x.id}: ${(x.rate * 100).toFixed(0)}% (${x.correct}/${x.reps})`)
return { scenarios: a, mean: +(a.reduce((s, x) => s + x.rate, 0) / a.length).toFixed(3) }
