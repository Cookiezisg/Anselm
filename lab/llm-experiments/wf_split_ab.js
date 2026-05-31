export const meta = {
  name: 'split-tools-ab',
  description: 'A/B: build complex workflows via incremental split-tools vs monolithic create_workflow; judge assembled graph vs same rubric',
  phases: [
    { title: 'Build', detail: 'Claude drives incremental split-tool graph construction' },
    { title: 'Judge', detail: '3 judges score the assembled graph vs the wave-1 rubric' },
  ],
}

const RESEARCH = '/Users/SP14921/Documents/Personal/PersonalCodeBase/Forgify/research/llm-experiments'
const IDS = ['wf_clear_triage', 'wf_branch_signup', 'wf_retry_loop']
const REPS = 3
const JOBS = IDS.flatMap((id) => Array.from({ length: REPS }, (_, r) => ({ id, rep: r })))

const BUILD_SCHEMA = {
  type: 'object', required: ['turns', 'calls', 'assembledGraph'], additionalProperties: false,
  properties: {
    turns: { type: 'integer' },
    calls: { type: 'array', items: { type: 'string' } },
    assembledGraph: { type: 'string', description: 'JSON of {nodes:[...], edges:[...], cases:[...]} accumulated from the split-tool calls' },
    malformedArgs: { type: 'boolean', description: 'true if ANY split-tool call had malformed/needed-repair JSON args' },
  },
}
const JUDGE_SCHEMA = {
  type: 'object', required: ['correct', 'why'], additionalProperties: false,
  properties: { correct: { type: 'boolean' }, failed_criteria: { type: 'array', items: { type: 'string' } }, why: { type: 'string' } },
}

const buildPrompt = (id, rep) => `You run ONE incremental workflow-build episode (split-tools A/B) and play the BACKEND. Variation seed: rep ${rep}.

Read spec: /tmp/w5_specs/${id}.json (system, user, tools = [create_workflow_shell, add_workflow_node, connect_workflow_nodes, set_case_branches], max_turns).

PROTOCOL (loop, you are the backend):
1. messages = [{role:system, content:spec.system}, {role:user, content:spec.user}]; offered tools = spec.tools.
2. Write /tmp/w5_run/${id}_${rep}.json = {messages, tools, max_tokens:8000}. (mkdir -p /tmp/w5_run)
3. Bash: \`cd ${RESEARCH} && export DEEPSEEK_API_KEY=$(cat /tmp/.ds_key) && python3 ds_turn.py /tmp/w5_run/${id}_${rep}.json\`
4. Parse stdout. Append assistant msg verbatim (content + reasoning_content if present + tool_calls).
5. For each tool_call, ACK as backend + ACCUMULATE into a running graph you maintain:
   - create_workflow_shell → return {data:{id:"wf_split"}};
   - add_workflow_node(node) → add node to graph.nodes; return {data:{ok:true}}
   - connect_workflow_nodes(from,to) → add {from,to} to graph.edges; return {data:{ok:true}}
   - set_case_branches(nodeId,expression,branches) → record to graph.cases; return {data:{ok:true}}
   - NOTE if a call's arguments JSON was malformed / needed repair (set malformedArgs=true).
   Append a tool result per call. Loop to step 2.
6. Stop when the model makes no more tool calls (says done) or max_turns.

Write the assembled graph + trajectory to /tmp/w5/${id}_${rep}.json = {id, rep, rubric:<from spec>, intent:<from spec>, graph:{nodes,edges,cases}, calls:[...]}.
Return StructuredOutput: turns, calls (ordered tool names), assembledGraph (JSON string of {nodes,edges,cases}), malformedArgs.`

const judgePrompt = (id, rep) => `Adversarial semantic judge. A weak model built a workflow INCREMENTALLY via split-tools. Judge the ASSEMBLED graph vs the rubric (real correctness, not shape).

Read /tmp/w5/${id}_${rep}.json: rubric (criteria), intent, graph {nodes, edges, cases}.
Check EVERY rubric criterion against the assembled graph. Especially: no dangling/null branch targets; case nodes route via branches NOT redundant connect edges; data actually flows (no node fed empty payload); conditional branches mutually exclusive & correct; retry bounded.
correct=true ONLY if the assembled graph genuinely implements the intent and would run. Default skeptical; name failed criteria.
Return per schema {correct, failed_criteria[], why}.`

phase('Build')
const results = await pipeline(
  JOBS,
  async (job) => {
    const build = await agent(buildPrompt(job.id, job.rep), { label: `build:${job.id}#${job.rep}`, phase: 'Build', schema: BUILD_SCHEMA })
    return { ...job, build }
  },
  async (prev) => {
    const { id, rep, build } = prev
    const judges = await parallel([0, 1, 2].map((j) => () =>
      agent(judgePrompt(id, rep), { label: `judge${j}:${id}#${rep}`, phase: 'Judge', schema: JUDGE_SCHEMA })
    ))
    const v = judges.filter(Boolean)
    const yes = v.filter((x) => x.correct).length
    return { id, rep, majority: yes >= 2, votes: `${yes}/${v.length}`, malformedArgs: build?.malformedArgs, calls: build?.calls }
  }
)

const agg = results.filter(Boolean)
const byId = {}
for (const r of agg) {
  if (!byId[r.id]) byId[r.id] = { pass: 0, n: 0, malformed: 0 }
  byId[r.id].n++; if (r.majority) byId[r.id].pass++; if (r.malformedArgs) byId[r.id].malformed++
}
log('Split-tools A/B (vs monolithic wave-1: clear_triage 23%, branch_signup 50%, retry_loop 80%):')
for (const [id, s] of Object.entries(byId)) log(`  ${id}: split ${s.pass}/${s.n} pass, malformed-args ${s.malformed}/${s.n}`)
return { byId, detail: agg }
