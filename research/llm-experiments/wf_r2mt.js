export const meta = {
  name: 'round2-multiturn-complex',
  description: 'Round-2 complex multi-turn: deep multi-entity systems, cascading error recovery, dirty/contradictory input (Claude-as-backend), 3-judge',
  phases: [{ title: 'Drive', detail: 'Claude drives + plays backend (incl. cascading error injection)' }, { title: 'Judge', detail: '3 judges per episode' }],
}
const RESEARCH = '/Users/SP14921/Documents/Personal/PersonalCodeBase/Forgify/research/llm-experiments'
const IDS = ['deep_support_system', 'cascading_diag', 'dirty_contradictory']
const REPS = 3
const JOBS = IDS.flatMap((id) => Array.from({ length: REPS }, (_, r) => ({ id, rep: r })))

const DRIVE_SCHEMA = { type: 'object', required: ['turns', 'toolCallsMade', 'accomplished', 'summary'], additionalProperties: false,
  properties: { turns: { type: 'integer' }, toolCallsMade: { type: 'array', items: { type: 'string' } }, accomplished: { type: 'boolean' }, summary: { type: 'string' }, finalText: { type: 'string' } } }
const JUDGE_SCHEMA = { type: 'object', required: ['correct', 'why'], additionalProperties: false,
  properties: { correct: { type: 'boolean' }, failed_criteria: { type: 'array', items: { type: 'string' } }, why: { type: 'string' } } }

const drivePrompt = (id, rep) => `You run ONE complex multi-turn episode and PLAY THE BACKEND + USER. Variation seed rep ${rep}.

Read spec: /tmp/r2mt_specs/${id}.json — system, user, tools, backend_notes (HOW you respond — follow it EXACTLY), max_turns.

PROTOCOL (loop):
1. messages=[{system},{user}]; offered tools = spec.tools.
2. Write /tmp/r2mt_run/${id}_${rep}.json = {messages, tools, max_tokens:16000}. (mkdir -p /tmp/r2mt_run)
3. Bash: \`cd ${RESEARCH} && export DEEPSEEK_API_KEY=$(cat /tmp/.ds_key) && python3 ds_turn.py /tmp/r2mt_run/${id}_${rep}.json\`
4. Append assistant msg verbatim (content + reasoning_content if present + tool_calls).
5. For each tool_call, ACK as backend STRICTLY per spec.backend_notes. CRITICAL for cascading_diag: inject the CURRENT round's error and keep returning it until the model actually fixes that specific cause, THEN advance to the next error in the sequence (do NOT skip ahead; each replay before a fix returns the same error). For deep builds: search→empty, create→ids (reuse the model's names), accept→active, capability_check→ok iff refs accepted else error+next_step. For dirty_contradictory: if the model asks to clarify, answer as the user per backend_notes. Append one tool result per call. Loop to step 2.
6. Stop when no tool_call (done) or max_turns.

Write full trajectory to /tmp/r2mt/${id}_${rep}.json (mkdir -p /tmp/r2mt): {id, rep, intent, rubric, user, turns:[{assistant tool_calls(name+args), tool_results}], final}.
Return StructuredOutput: turns, toolCallsMade (ordered), accomplished, summary (step-by-step incl. each error round + recovery, or how it handled the contradiction), finalText.`

const judgePrompt = (id, rep) => `Adversarial semantic judge. Read /tmp/r2mt/${id}_${rep}.json: intent, rubric, user, every turn (tool_calls + backend results).
Check EVERY rubric criterion against what the model ACTUALLY did across turns. For cascading_diag: did it recover through ALL 3 sequential errors (each round addressing the NEW error, not blind re-replay)? For deep_support_system: did it forge all 6 interdependent entities + wire coherently with real refs? For dirty_contradictory: did it SURFACE the contradiction + resolve, not silently build nonsense?
correct=true ONLY if it genuinely accomplished the task end-to-end. Default skeptical; name failed criteria with the specific defect.
Return per schema: {correct, failed_criteria[], why}.`

phase('Drive')
const results = await pipeline(JOBS,
  async (job) => ({ ...job, drive: await agent(drivePrompt(job.id, job.rep), { label: `drive:${job.id}#${job.rep}`, phase: 'Drive', schema: DRIVE_SCHEMA }) }),
  async (prev) => {
    const { id, rep, drive } = prev
    const judges = await parallel([0, 1, 2].map((j) => () => agent(judgePrompt(id, rep), { label: `judge${j}:${id}#${rep}`, phase: 'Judge', schema: JUDGE_SCHEMA })))
    const v = judges.filter(Boolean); const yes = v.filter((x) => x.correct).length
    return { id, rep, accomplished: drive?.accomplished, turns: drive?.turns, toolCallsMade: drive?.toolCallsMade, majority: yes >= 2, votes: `${yes}/${v.length}`, fails: v.flatMap((x) => x.failed_criteria || []).slice(0, 4), summary: drive?.summary }
  }
)
const agg = results.filter(Boolean)
const byId = {}
for (const a of agg) { if (!byId[a.id]) byId[a.id] = { pass: 0, n: 0 }; byId[a.id].n++; if (a.majority) byId[a.id].pass++ }
log('Round-2 complex multi-turn:')
for (const [id, s] of Object.entries(byId)) log(`  ${id}: ${s.pass}/${s.n}`)
for (const a of agg) log(`  ${a.id}#${a.rep}: ${a.majority ? 'PASS' : 'FAIL'} (${a.votes}) turns=${a.turns}`)
return { byId, agg }
