export const meta = {
  name: 'wave2-multiturn',
  description: 'Wave-2: real multi-turn ReAct with Claude-as-backend (edit/diagnosis/lazy/cross-entity/recovery), then 3-judge semantic verdict',
  phases: [
    { title: 'Drive', detail: 'Claude drives each episode as backend+user, looping ds_turn.py' },
    { title: 'Judge', detail: '3 adversarial judges per scenario vs rubric' },
  ],
}

const RESEARCH = '/Users/SP14921/Documents/Personal/PersonalCodeBase/Forgify/research/llm-experiments'

// scenario ids (specs at /tmp/w2_specs/<id>.json, built by wave2_build.py)
const ALL = ['edit_wf_add_retry', 'edit_agent_add_tool', 'edit_fn_extend', 'diag_orders_crash', 'lazy_mcp_slack', 'cross_add_capability', 'recover_capability_check']
const SCENARIOS = (Array.isArray(args) && args.length) ? args : ALL

const DRIVE_SCHEMA = {
  type: 'object', required: ['turns', 'toolCallsMade', 'accomplished', 'summary'], additionalProperties: false,
  properties: {
    turns: { type: 'integer' },
    toolCallsMade: { type: 'array', items: { type: 'string' }, description: 'ordered tool names the model called across the episode' },
    accomplished: { type: 'boolean', description: 'did the model functionally accomplish the task by the end' },
    summary: { type: 'string', description: 'what the model did, step by step, incl. any recovery or mistake' },
    finalText: { type: 'string' },
  },
}
const JUDGE_SCHEMA = {
  type: 'object', required: ['correct', 'why'], additionalProperties: false,
  properties: {
    correct: { type: 'boolean' },
    failed_criteria: { type: 'array', items: { type: 'string' } },
    why: { type: 'string' },
  },
}

const drivePrompt = (id) => `You run ONE multi-turn ReAct episode to test DeepSeek as Forgify's chat brain, and YOU PLAY THE BACKEND + USER. This is the real environment — be realistic and consistent; do NOT help the model beyond what a real backend/user would.

Read the spec with Read: /tmp/w2_specs/${id}.json — fields: system, user, tools (initial offered), lazy (group→tools, gated behind activate_tools), backend_notes (how YOU respond, incl. error injection), initial_state (entities that exist), max_turns.

PROTOCOL (loop):
1. Build messages = [{"role":"system","content":<system>}, {"role":"user","content":<user>}]. Maintain a current offered-tools list = spec.tools.
2. Write /tmp/w2_run/${id}.json = {"messages":<messages>, "tools":<offered-tools>, "max_tokens":16000}. (mkdir -p /tmp/w2_run)
3. Run with Bash: \`cd ${RESEARCH} && export DEEPSEEK_API_KEY=$(cat /tmp/.ds_key) && python3 ds_turn.py /tmp/w2_run/${id}.json\`
4. Parse the JSON stdout. If budget_exhausted → stop, report.
5. Append the assistant message to messages EXACTLY as: {"role":"assistant","content":<content or null>,"reasoning_content":<reasoning_content if non-empty>,"tool_calls":<the tool_calls array verbatim from output, if any>}.
   (reasoning_content MUST be echoed back when present, or DeepSeek 400s next turn.)
6. If the assistant made tool_calls: for EACH tool_call, YOU are the backend — produce a REALISTIC result JSON per backend_notes + initial_state:
   - get_*/search_* → return the matching entity/graph from initial_state (as {"data":...}); search with no match → {"data":[]}.
   - create_*/edit_* → {"data":{"id":<plausible id, reuse if given>, "pending_version":"v_next"}}.
   - activate_tools(category) → {"data":{"activated":category}} AND add spec.lazy[category] (if any) to the offered-tools list for subsequent turns.
   - INJECT the scripted error from backend_notes exactly (e.g. an error envelope {"error":{"code","message","next_step"}}) to test recovery.
   Append one {"role":"tool","tool_call_id":<id>,"content":<result json string>} per tool_call. Go to step 2.
7. If the assistant made NO tool_call: if it asked the USER a question, answer briefly + realistically as the user (per intent), append {"role":"user","content":...}, go to step 2. If it's a final answer / task done, STOP.
8. Stop also at max_turns.

Then WRITE the full trajectory to /tmp/w2/${id}.json (mkdir -p /tmp/w2): {"id":"${id}","intent":<intent>,"rubric":<rubric>,"user":<user>,"turns":[{"assistant":...,"tool_results":[...]}],"final":<last text>}. Include every turn's assistant tool_calls (name+args) + the results you returned.

Return the StructuredOutput: turns, toolCallsMade (ordered tool names), accomplished (did it functionally do the task), summary (step-by-step incl. mistakes/recovery), finalText.`

const judgePrompt = (id) => `You are an ADVERSARIAL semantic judge for Forgify's LLM tool-design research. A weak model (DeepSeek) ran a MULTI-TURN episode; judge whether it SEMANTICALLY accomplished the task — real correctness, not just plausible-looking calls.

Read the trajectory: /tmp/w2/${id}.json (Read tool) — has intent, rubric, user, and every turn (assistant tool_calls + the backend results).

Check EVERY rubric criterion against what the model actually did across turns. correct=true ONLY if it genuinely accomplished the task end-to-end (right tools, right order, real ids not hallucinated, preserved existing config on edits, recovered correctly from any injected error, didn't blindly retry). Default SKEPTICAL: name each failed criterion with the specific defect.

Return per schema: {correct, failed_criteria[], why}. Be concrete.`

phase('Drive')
const results = await pipeline(
  SCENARIOS,
  async (id) => {
    const drive = await agent(drivePrompt(id), { label: `drive:${id}`, phase: 'Drive', schema: DRIVE_SCHEMA })
    return { id, drive }
  },
  async (prev) => {
    const { id, drive } = prev
    const judges = await parallel([0, 1, 2].map((j) => () =>
      agent(judgePrompt(id), { label: `judge${j}:${id}`, phase: 'Judge', schema: JUDGE_SCHEMA })
    ))
    const v = judges.filter(Boolean)
    const yes = v.filter((x) => x.correct).length
    const majority = yes >= 2
    const fails = {}
    for (const x of v) for (const f of (x.failed_criteria || [])) fails[f] = (fails[f] || 0) + 1
    return { id, accomplished: drive?.accomplished, turns: drive?.turns, toolCallsMade: drive?.toolCallsMade, majority, votes: `${yes}/${v.length}`, topFails: Object.entries(fails).sort((a, b) => b[1] - a[1]).slice(0, 5), driveSummary: drive?.summary }
  }
)

const agg = results.filter(Boolean)
const passed = agg.filter((a) => a.majority).length
log(`Wave-2: ${passed}/${agg.length} scenarios semantically correct (multi-turn)`)
for (const a of agg) log(`  ${a.id}: ${a.majority ? 'PASS' : 'FAIL'} (${a.votes}) turns=${a.turns} tools=[${(a.toolCallsMade || []).join(',')}]`)
return { agg, passed, total: agg.length }
