export const meta = {
  name: 'wave13-composite',
  description: 'Composite end-to-end: model builds a COMPLETE multi-entity automation from scratch (multi-turn, Claude-as-backend), then 3-judge verdict',
  phases: [{ title: 'Build', detail: 'Claude drives the from-scratch build as backend' }, { title: 'Judge', detail: '3 judges per episode' }],
}
const RESEARCH = '/Users/SP14921/Documents/Personal/PersonalCodeBase/Forgify/research/llm-experiments'
const IDS = ['comp_onboarding', 'comp_daily_report']
const REPS = 2
const JOBS = IDS.flatMap((id) => Array.from({ length: REPS }, (_, r) => ({ id, rep: r })))

const DRIVE_SCHEMA = { type: 'object', required: ['turns', 'toolCallsMade', 'accomplished', 'summary'], additionalProperties: false,
  properties: { turns: { type: 'integer' }, toolCallsMade: { type: 'array', items: { type: 'string' } }, accomplished: { type: 'boolean' }, summary: { type: 'string' }, finalText: { type: 'string' } } }
const JUDGE_SCHEMA = { type: 'object', required: ['correct', 'why'], additionalProperties: false,
  properties: { correct: { type: 'boolean' }, failed_criteria: { type: 'array', items: { type: 'string' } }, why: { type: 'string' } } }

const drivePrompt = (id, rep) => `You run ONE composite end-to-end build episode and PLAY THE BACKEND. Variation seed rep ${rep}. The model must build a COMPLETE multi-entity automation FROM SCRATCH.

Read spec: /tmp/w13_specs/${id}.json — system, user, tools (forge CRUD + accept + capability_check + activate), backend_notes (how YOU respond), max_turns.

PROTOCOL (loop, you are the backend):
1. messages = [{role:system, content:spec.system}, {role:user, content:spec.user}]; offered tools = spec.tools (fixed).
2. Write /tmp/w13_run/${id}_${rep}.json = {messages, tools, max_tokens:16000}. (mkdir -p /tmp/w13_run)
3. Bash: \`cd ${RESEARCH} && export DEEPSEEK_API_KEY=$(cat /tmp/.ds_key) && python3 ds_turn.py /tmp/w13_run/${id}_${rep}.json\`
4. Parse stdout. Append the assistant msg verbatim (content + reasoning_content if present + tool_calls).
5. For each tool_call, ACK as backend per spec.backend_notes — CRUCIALLY: search_* for not-yet-built entities → return EMPTY (forces forging); create_* → return {data:{id, pending_version:v1}} reusing the id the model expects; accept_* → active; capability_check → ok only if all referenced callables were created+accepted, else error envelope naming the missing one + next_step; activate → ok or capability error. Be consistent; reuse the model's ids; don't invent extra entities. Append one tool result per call. Loop to step 2.
6. Stop when the model makes no more tool calls (declares done) or max_turns.

Write the full trajectory to /tmp/w13/${id}_${rep}.json (mkdir -p /tmp/w13): {id, rep, intent, rubric, user, turns:[{assistant tool_calls(name+args), tool_results}], final}.
Return StructuredOutput: turns, toolCallsMade (ordered tool names), accomplished (did it build a coherent complete runnable automation), summary (step-by-step incl. forge order + any recovery), finalText.`

const judgePrompt = (id, rep) => `Adversarial semantic judge. A weak model built a COMPLETE automation FROM SCRATCH across many turns. Read /tmp/w13/${id}_${rep}.json: intent, rubric, user, every turn (tool_calls + backend results).
Check EVERY rubric criterion. correct=true ONLY if it built a coherent, complete, RUNNABLE automation: forged all needed entities (recognized nothing existed), accepted them, wired them into a workflow with correct data flow (no empty payload to agent; fetch before process), case routing via per-branch when guards, capability_check before activate, sensible order (forge→accept→wire→check→activate), real ids (no fictional refs). Default skeptical; name failed criteria with the specific defect.
Return per schema: {correct, failed_criteria[], why}.`

phase('Build')
const results = await pipeline(JOBS,
  async (job) => ({ ...job, drive: await agent(drivePrompt(job.id, job.rep), { label: `build:${job.id}#${job.rep}`, phase: 'Build', schema: DRIVE_SCHEMA }) }),
  async (prev) => {
    const { id, rep, drive } = prev
    const judges = await parallel([0, 1, 2].map((j) => () => agent(judgePrompt(id, rep), { label: `judge${j}:${id}#${rep}`, phase: 'Judge', schema: JUDGE_SCHEMA })))
    const v = judges.filter(Boolean); const yes = v.filter((x) => x.correct).length
    return { id, rep, accomplished: drive?.accomplished, turns: drive?.turns, toolCallsMade: drive?.toolCallsMade, majority: yes >= 2, votes: `${yes}/${v.length}`, fails: v.flatMap((x) => x.failed_criteria || []).slice(0, 4), summary: drive?.summary }
  }
)
const agg = results.filter(Boolean)
const passed = agg.filter((a) => a.majority).length
log(`Wave-13 composite end-to-end: ${passed}/${agg.length} built a coherent complete automation`)
for (const a of agg) log(`  ${a.id}#${a.rep}: ${a.majority ? 'PASS' : 'FAIL'} (${a.votes}) turns=${a.turns} tools=[${(a.toolCallsMade || []).join(',')}]`)
return { agg, passed, total: agg.length }
