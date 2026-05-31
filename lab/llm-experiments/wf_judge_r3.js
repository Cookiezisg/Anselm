export const meta = {
  name: 'judge-r3-coverage',
  description: 'Stage-3 per-tool coverage judge: for each tool, 3 judges batch-score every scenario (called-right-tool + usage-correct per rubric). Majority. Reports per-tool coverage/selection/usage.',
  phases: [{ title: 'Judge', detail: '91 tools × 3 judges, batch over ~50 scenarios each' }],
}
const DIR = '/tmp/r3res'
const args0 = (typeof args !== 'undefined' && args) || {}
const ONLY = args0.only || null // optional substring filter

const SCHEMA = { type: 'object', required: ['per'], additionalProperties: false, properties: { per: { type: 'array', items: {
  type: 'object', required: ['id', 'called_right', 'usage_correct'], additionalProperties: false,
  properties: { id: { type: 'string' }, called_right: { type: 'boolean' }, usage_correct: { type: 'boolean' }, why: { type: 'string' } } } } } }

const judgePrompt = (tool) => `Adversarial coverage judge for the tool \`${tool}\`. Read /tmp/r3res/${tool}.json — an array of scenarios, each {id, user, intent, rubric, expected_tool:"${tool}", called:[tool names the model invoked], tool_calls:[{name,args}], content_head}.
For EACH scenario score TWO things:
- called_right = did the model call the expected tool \`${tool}\` (it appears in called[])? (A correct search-first then ${tool} also counts as called_right. Pure clarification with NO call when the request genuinely lacked needed info may be reasonable — but if the info was present and it still didn't call, called_right=false.)
- usage_correct = given it called ${tool}, are the ARGS / artifact semantically correct per the scenario's rubric & intent? (forge: artifact is correct & runnable; usage: right id/query/args, no hallucination). If it didn't call the tool, usage_correct=false.
Default skeptical on usage_correct. Cover EVERY scenario in the file. Return per schema: per[]{id, called_right, usage_correct, why}.`

phase('Judge')
// the 91 tools (judged only if /tmp/r3res/<tool>.json exists — judge agent returns empty otherwise).
const TOOLS = ['create_function','edit_function','get_function','get_function_versions','revert_function','accept_pending_function','run_function','search_functions','search_function_executions','get_function_execution','delete_function','create_handler','edit_handler','get_handler','get_handler_versions','revert_handler','accept_pending_handler','call_handler','update_handler_config','search_handlers','search_handler_calls','get_handler_call','delete_handler','create_agent','edit_agent','get_agent','get_agent_versions','revert_agent','accept_pending_agent','run_agent','search_agents','search_agent_executions','get_agent_execution','delete_agent','create_workflow','edit_workflow','get_workflow','get_workflow_versions','revert_workflow','accept_pending_workflow','search_workflows','delete_workflow','capability_check_workflow','activate_workflow','deactivate_workflow','trigger_workflow','get_flowrun','get_flowrun_nodes','get_flowrun_trace','search_flowruns','cancel_flowrun','list_dead_letters','get_dead_letter','clear_dead_letters','replay_message','query_events','list_mcp_servers','search_mcp_tools','call_mcp_tool','health_check_mcp','install_mcp_from_registry','search_skills','get_skill','activate_skill','create_document','edit_document','read_document','list_documents','search_documents','move_document','delete_document','write_memory','read_memory','forget_memory','Read','Write','Edit','Glob','Grep','Bash','BashOutput','KillShell','WebFetch','WebSearch','Subagent','AskUserQuestion','TodoCreate','TodoGet','TodoList','TodoUpdate','activate_tools']

// 1 careful judge per tool over its ~56 scenarios (91 agents, tractable). Low/contested tools are
// additionally raw-read by the orchestrator (human-in-loop adversarial check).
const results = await parallel(TOOLS.filter((t) => !ONLY || t.includes(ONLY)).map((tool) => () =>
  agent(judgePrompt(tool), { label: `j:${tool}`, phase: 'Judge', schema: SCHEMA })
    .then((j) => ({ tool, judges: j ? [j] : [] }))
    .catch(() => ({ tool, judges: [] }))))

function ci(p, n) { return n ? +(1.96 * Math.sqrt(p * (1 - p) / n)).toFixed(3) : 0 }
function agg(r) {
  const idx = new Set(); for (const j of r.judges) for (const p of (j.per || [])) idx.add(p.id)
  const ids = [...idx]; let sel = 0, use = 0, n = 0
  for (const id of ids) {
    let s = 0, u = 0, tot = 0
    for (const j of r.judges) { const p = (j.per || []).find((x) => x.id === id); if (!p) continue; tot++; if (p.called_right) s++; if (p.usage_correct) u++ }
    if (!tot) continue
    const need = Math.ceil(tot / 2) // majority of however many judges replied (1 → 1, 3 → 2)
    n++; if (s >= need) sel++; if (u >= need) use++
  }
  return { tool: r.tool, n, selectionPct: n ? Math.round(100 * sel / n) : 0, usagePct: n ? Math.round(100 * use / n) : 0,
    selCI: ci(sel / (n || 1), n), useCI: ci(use / (n || 1), n) }
}
const a = results.filter(Boolean).map(agg).filter((x) => x.n > 0)
a.sort((x, y) => x.usagePct - y.usagePct)
log(`R3 per-tool coverage (n scenarios each; selection% = called right tool; usage% = correct args/artifact):`)
for (const x of a) log(`  ${x.tool}: n=${x.n} sel=${x.selectionPct}% use=${x.usagePct}%±${Math.round(x.useCI * 100)}`)
const weak = a.filter((x) => x.usagePct < 80)
log(`\nWEAK (usage<80%): ${weak.map((x) => x.tool + ' ' + x.usagePct + '%').join(' | ') || 'NONE'}`)
const coverageOK = a.filter((x) => x.n >= 50).length
log(`\nCOVERAGE: ${coverageOK}/${a.length} tools have ≥50 scenarios judged.`)
return { perTool: a, weak: weak.map((x) => [x.tool, x.usagePct]), coverageOK, totalTools: a.length }
