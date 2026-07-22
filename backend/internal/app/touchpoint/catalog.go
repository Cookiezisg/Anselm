// The tool → touch catalog: the SINGLE place that says which tool call touches which item
// kind with which verb, and where the item id lives (args key / output JSON key / derived).
// The loop's choke point runs every executed tool through ExtractTouches — tools themselves
// stay untouched (S18's five-method interface is closed). Drift is fenced by a bootstrap
// gate test: every registered tool must appear here or in the explicit no-touch list, so a
// new tool cannot ship without declaring its ledger stance.
//
// 工具→触碰目录:**唯一**声明「哪个工具调用以哪个动词碰哪类物、物 id 在哪(args 键/输出 JSON 键/
// 派生)」之处。loop 咽喉把每个已执行工具过一遍 ExtractTouches——工具本身零改动(S18 五方法接口
// 封闭)。漂移由 bootstrap 门禁测试围住:每个注册工具必须出现在本目录或显式 no-touch 清单,
// 新工具不表态就无法过门禁。
package touchpoint

import (
	"encoding/json"
	"regexp"
	"strings"

	relationdomain "github.com/sunweilin/anselm/backend/internal/domain/relation"
	touchpointdomain "github.com/sunweilin/anselm/backend/internal/domain/touchpoint"
)

// ItemRef is one extracted touch target (the catalog's output; the hook fills the rest of
// the Touch from ctx). Name is set only when the id IS the human name (skill / mcp short
// name) — otherwise the Service hydrates via Namers.
//
// ItemRef 是一次提取出的触碰目标(目录的输出;hook 从 ctx 补齐 Touch 其余字段)。仅当 id 本身
// 就是人名(skill / mcp 短名)时才带 Name——其余由 Service 经 Namers hydrate。
type ItemRef struct {
	Kind string
	ID   string
	Name string
	Verb string
}

// rule locates one tool's touch target. Exactly one of argKey / outputKey / special is set.
// Optional-filter args (e.g. search_agent_executions.agentId) yield no touch when absent —
// extraction is total, never erroring.
//
// rule 定位一个工具的触碰目标。argKey / outputKey / special 三者恰一。可选过滤参数
// (如 search_agent_executions.agentId)缺席时不产触碰——提取是全函数、永不报错。
type rule struct {
	kind      string
	verb      string
	argKey    string // id in args[argKey]
	outputKey string // id in the tool's output JSON at [outputKey]
	nameIsID  bool   // the id doubles as the display name (skill / mcp short name)
}

// docIDRe extracts the id from create_document's plain-text output — the one create tool
// whose output is prose, not JSON (`Created document "NAME" (id=doc_…, path=…)`).
//
// docIDRe 从 create_document 的纯文本输出抽 id——唯一输出是散文而非 JSON 的 create 工具。
var docIDRe = regexp.MustCompile(`id=(doc_[0-9a-f]{16})`)

// catalog maps every entity-touching tool. Kinds reuse relation's vocabulary verbatim.
//
// catalog 映射每个触实体工具。kind 逐字复用 relation 词表。
var catalog = map[string]rule{
	// --- created:new id rides the build output (create_document / create_skill special-cased) 新 id 在输出里 ---
	"create_function":    {kind: relationdomain.EntityKindFunction, verb: touchpointdomain.VerbCreated, outputKey: "id"},
	"create_handler":     {kind: relationdomain.EntityKindHandler, verb: touchpointdomain.VerbCreated, outputKey: "id"},
	"create_agent":       {kind: relationdomain.EntityKindAgent, verb: touchpointdomain.VerbCreated, outputKey: "id"},
	"create_control":     {kind: relationdomain.EntityKindControl, verb: touchpointdomain.VerbCreated, outputKey: "id"},
	"create_approval":    {kind: relationdomain.EntityKindApproval, verb: touchpointdomain.VerbCreated, outputKey: "id"},
	"create_workflow":    {kind: relationdomain.EntityKindWorkflow, verb: touchpointdomain.VerbCreated, outputKey: "id"},
	"create_trigger":     {kind: relationdomain.EntityKindTrigger, verb: touchpointdomain.VerbCreated, outputKey: "id"},
	"create_skill":       {kind: relationdomain.EntityKindSkill, verb: touchpointdomain.VerbCreated, argKey: "name", nameIsID: true},
	"install_mcp_server": {kind: relationdomain.EntityKindMCP, verb: touchpointdomain.VerbCreated, outputKey: "id"},

	// --- edited:target in args(revert/meta/config/lifecycle state changes are edit-class) 目标在 args ---
	"edit_function":         {kind: relationdomain.EntityKindFunction, verb: touchpointdomain.VerbEdited, argKey: "functionId"},
	"edit_handler":          {kind: relationdomain.EntityKindHandler, verb: touchpointdomain.VerbEdited, argKey: "handlerId"},
	"edit_agent":            {kind: relationdomain.EntityKindAgent, verb: touchpointdomain.VerbEdited, argKey: "agentId"},
	"edit_control":          {kind: relationdomain.EntityKindControl, verb: touchpointdomain.VerbEdited, argKey: "controlId"},
	"edit_approval":         {kind: relationdomain.EntityKindApproval, verb: touchpointdomain.VerbEdited, argKey: "approvalId"},
	"edit_workflow":         {kind: relationdomain.EntityKindWorkflow, verb: touchpointdomain.VerbEdited, argKey: "workflowId"},
	"edit_trigger":          {kind: relationdomain.EntityKindTrigger, verb: touchpointdomain.VerbEdited, argKey: "triggerId"},
	"edit_document":         {kind: relationdomain.EntityKindDocument, verb: touchpointdomain.VerbEdited, argKey: "id"},
	"edit_skill":            {kind: relationdomain.EntityKindSkill, verb: touchpointdomain.VerbEdited, argKey: "name", nameIsID: true},
	"update_function_meta":  {kind: relationdomain.EntityKindFunction, verb: touchpointdomain.VerbEdited, argKey: "functionId"},
	"update_handler_meta":   {kind: relationdomain.EntityKindHandler, verb: touchpointdomain.VerbEdited, argKey: "handlerId"},
	"update_handler_config": {kind: relationdomain.EntityKindHandler, verb: touchpointdomain.VerbEdited, argKey: "handlerId"},
	"update_agent_meta":     {kind: relationdomain.EntityKindAgent, verb: touchpointdomain.VerbEdited, argKey: "agentId"},
	"revert_function":       {kind: relationdomain.EntityKindFunction, verb: touchpointdomain.VerbEdited, argKey: "functionId"},
	"revert_handler":        {kind: relationdomain.EntityKindHandler, verb: touchpointdomain.VerbEdited, argKey: "handlerId"},
	"revert_agent":          {kind: relationdomain.EntityKindAgent, verb: touchpointdomain.VerbEdited, argKey: "agentId"},
	"revert_workflow":       {kind: relationdomain.EntityKindWorkflow, verb: touchpointdomain.VerbEdited, argKey: "workflowId"},
	"revert_control":        {kind: relationdomain.EntityKindControl, verb: touchpointdomain.VerbEdited, argKey: "controlId"},
	"revert_approval":       {kind: relationdomain.EntityKindApproval, verb: touchpointdomain.VerbEdited, argKey: "approvalId"},
	"move_document":         {kind: relationdomain.EntityKindDocument, verb: touchpointdomain.VerbEdited, argKey: "id"},
	"stage_workflow":        {kind: relationdomain.EntityKindWorkflow, verb: touchpointdomain.VerbEdited, argKey: "workflowId"},
	"activate_workflow":     {kind: relationdomain.EntityKindWorkflow, verb: touchpointdomain.VerbEdited, argKey: "workflowId"},
	"deactivate_workflow":   {kind: relationdomain.EntityKindWorkflow, verb: touchpointdomain.VerbEdited, argKey: "workflowId"},
	"kill_workflow":         {kind: relationdomain.EntityKindWorkflow, verb: touchpointdomain.VerbEdited, argKey: "workflowId"},

	// --- deleted 删 ---
	"delete_function":      {kind: relationdomain.EntityKindFunction, verb: touchpointdomain.VerbDeleted, argKey: "functionId"},
	"delete_handler":       {kind: relationdomain.EntityKindHandler, verb: touchpointdomain.VerbDeleted, argKey: "handlerId"},
	"delete_agent":         {kind: relationdomain.EntityKindAgent, verb: touchpointdomain.VerbDeleted, argKey: "agentId"},
	"delete_workflow":      {kind: relationdomain.EntityKindWorkflow, verb: touchpointdomain.VerbDeleted, argKey: "workflowId"},
	"delete_trigger":       {kind: relationdomain.EntityKindTrigger, verb: touchpointdomain.VerbDeleted, argKey: "triggerId"},
	"delete_control":       {kind: relationdomain.EntityKindControl, verb: touchpointdomain.VerbDeleted, argKey: "controlId"},
	"delete_approval":      {kind: relationdomain.EntityKindApproval, verb: touchpointdomain.VerbDeleted, argKey: "approvalId"},
	"delete_document":      {kind: relationdomain.EntityKindDocument, verb: touchpointdomain.VerbDeleted, argKey: "id"},
	"delete_skill":         {kind: relationdomain.EntityKindSkill, verb: touchpointdomain.VerbDeleted, argKey: "name", nameIsID: true},
	"uninstall_mcp_server": {kind: relationdomain.EntityKindMCP, verb: touchpointdomain.VerbDeleted, argKey: "name", nameIsID: true},

	// --- executed:operational actions(restart/reconnect included) 执行/运维动作 ---
	"run_function":     {kind: relationdomain.EntityKindFunction, verb: touchpointdomain.VerbExecuted, argKey: "functionId"},
	"call_handler":     {kind: relationdomain.EntityKindHandler, verb: touchpointdomain.VerbExecuted, argKey: "handlerId"},
	"invoke_agent":     {kind: relationdomain.EntityKindAgent, verb: touchpointdomain.VerbExecuted, argKey: "agentId"},
	"trigger_workflow": {kind: relationdomain.EntityKindWorkflow, verb: touchpointdomain.VerbExecuted, argKey: "workflowId"},
	"fire_trigger":     {kind: relationdomain.EntityKindTrigger, verb: touchpointdomain.VerbExecuted, argKey: "triggerId"},
	"restart_handler":  {kind: relationdomain.EntityKindHandler, verb: touchpointdomain.VerbExecuted, argKey: "handlerId"},
	"activate_skill":   {kind: relationdomain.EntityKindSkill, verb: touchpointdomain.VerbExecuted, argKey: "name", nameIsID: true},
	"run_skill_script": {kind: relationdomain.EntityKindSkill, verb: touchpointdomain.VerbExecuted, argKey: "name", nameIsID: true},
	"reconnect_mcp":    {kind: relationdomain.EntityKindMCP, verb: touchpointdomain.VerbExecuted, argKey: "name", nameIsID: true},

	// --- viewed:reads with a single addressable target(log searches count as viewing the entity's ops) 看 ---
	"get_function":               {kind: relationdomain.EntityKindFunction, verb: touchpointdomain.VerbViewed, argKey: "functionId"},
	"get_handler":                {kind: relationdomain.EntityKindHandler, verb: touchpointdomain.VerbViewed, argKey: "handlerId"},
	"get_agent":                  {kind: relationdomain.EntityKindAgent, verb: touchpointdomain.VerbViewed, argKey: "agentId"},
	"get_workflow":               {kind: relationdomain.EntityKindWorkflow, verb: touchpointdomain.VerbViewed, argKey: "workflowId"},
	"get_trigger":                {kind: relationdomain.EntityKindTrigger, verb: touchpointdomain.VerbViewed, argKey: "triggerId"},
	"get_control":                {kind: relationdomain.EntityKindControl, verb: touchpointdomain.VerbViewed, argKey: "controlId"},
	"get_approval":               {kind: relationdomain.EntityKindApproval, verb: touchpointdomain.VerbViewed, argKey: "approvalId"},
	"read_document":              {kind: relationdomain.EntityKindDocument, verb: touchpointdomain.VerbViewed, argKey: "id"},
	"get_skill":                  {kind: relationdomain.EntityKindSkill, verb: touchpointdomain.VerbViewed, argKey: "name", nameIsID: true},
	"read_attachment":            {kind: touchpointdomain.ItemKindAttachment, verb: touchpointdomain.VerbViewed, argKey: "id"},
	"capability_check_workflow":  {kind: relationdomain.EntityKindWorkflow, verb: touchpointdomain.VerbViewed, argKey: "workflowId"},
	"search_function_executions": {kind: relationdomain.EntityKindFunction, verb: touchpointdomain.VerbViewed, argKey: "functionId"},
	"search_handler_calls":       {kind: relationdomain.EntityKindHandler, verb: touchpointdomain.VerbViewed, argKey: "handlerId"},
	"search_agent_executions":    {kind: relationdomain.EntityKindAgent, verb: touchpointdomain.VerbViewed, argKey: "agentId"},
	"search_activations":         {kind: relationdomain.EntityKindTrigger, verb: touchpointdomain.VerbViewed, argKey: "triggerId"},
	"search_firings":             {kind: relationdomain.EntityKindTrigger, verb: touchpointdomain.VerbViewed, argKey: "triggerId"},
	"search_flowruns":            {kind: relationdomain.EntityKindWorkflow, verb: touchpointdomain.VerbViewed, argKey: "workflowId"},
	"search_mcp_calls":           {kind: relationdomain.EntityKindMCP, verb: touchpointdomain.VerbViewed, argKey: "serverId"},
}

// noTouch is the explicit "this tool touches nothing" list — target-less searches/lists,
// non-item domains (memory / todo / model / flowrun / subagent trace), the humanloop ask,
// resident file/shell/web plumbing, and self-targeting conversation management. Being here
// is a REVIEWED stance, not an omission — the gate test fails on any tool in neither set.
//
// noTouch 是显式「此工具不碰任何物」清单——无目标的搜索/列表、非 item 域(memory/todo/model/
// flowrun/subagent trace)、人在环提问、resident 文件/shell/web 管道、以及自指的对话管理。
// 在此即**已审视**的表态、非遗漏——门禁测试对两边都不在的工具直接红。
var noTouch = map[string]bool{
	// target-less queries 无目标查询
	"search_function": true, "search_handler": true, "search_agent": true,
	"search_control": true, "search_approval": true, "search_workflow": true,
	"search_triggers": true, "search_documents": true, "search_conversations": true,
	"search_blocks": true, "search_tools": true,
	"list_documents": true, "list_attachments": true, "list_conversations": true,
	"list_mcp_marketplace": true, "list_approval_inbox": true,
	// execution-log点查:参数是 execution/call/activation id,非实体 id 单点查日志
	"get_function_execution": true, "get_handler_call": true, "get_activation": true,
	"get_mcp_call": true, "get_agent_execution": true,
	// flowrun-addressed(flowrun 非 item kind;不做二跳换 workflow)
	"get_flowrun": true, "replay_flowrun": true, "decide_approval": true,
	// non-item domains 非 item 域
	"read_memory": true, "write_memory": true, "forget_memory": true,
	"todo_read": true, "todo_write": true, "get_model_config": true,
	"get_subagent_trace": true,
	// self-targeting(current conversation)自指
	"manage_conversation": true,
	// resident plumbing 常驻管道
	"Read": true, "Write": true, "Edit": true, "Glob": true, "Grep": true, "LS": true,
	"Bash": true, "BashOutput": true, "KillShell": true, "ask_user": true,
	"Subagent": true, "WebFetch": true, "WebSearch": true,
}

// mcpDynamicPrefix marks per-server dynamic tools (`mcp__<server>__<tool>`); the server
// short name between the first two `__` pairs is the touch target.
//
// mcpDynamicPrefix 标记按 server 的动态工具(`mcp__<server>__<tool>`);头两个 `__` 之间的
// server 短名即触碰目标。
const mcpDynamicPrefix = "mcp__"

// specials are the two tools ExtractTouches handles in code, not table: get_relations
// (its item kind rides in args) and create_document (the one prose-output create).
//
// specials 是 ExtractTouches 用代码而非表处理的两个工具:get_relations(kind 在 args 里)、
// create_document(唯一散文输出的 create)。
var specials = map[string]bool{"get_relations": true, "create_document": true}

// Covers reports whether the catalog has a reviewed stance on the tool — the gate test's
// single question.
//
// Covers 报告目录对该工具是否已有审视过的表态——门禁测试问的唯一问题。
func Covers(name string) bool {
	if _, ok := catalog[name]; ok {
		return true
	}
	return noTouch[name] || specials[name] || strings.HasPrefix(name, mcpDynamicPrefix)
}

// ExtractTouches derives the touch targets of one SUCCESSFUL tool execution. Total function:
// unknown tools, absent optional args, and unparsable outputs yield nil — extraction may
// under-report but never errors and never blocks the loop. get_relations is the one
// args-typed special (its kind rides in args); mcp dynamic tools derive the server name.
//
// ExtractTouches 派生一次**成功**工具执行的触碰目标。全函数:未知工具、缺席的可选参数、解析
// 不了的输出一律 nil——提取可少报、绝不报错、绝不阻断 loop。get_relations 是唯一 kind 在 args
// 里的特例;mcp 动态工具派生 server 名。
func ExtractTouches(name string, args map[string]any, output string) []ItemRef {
	if strings.HasPrefix(name, mcpDynamicPrefix) {
		server, _, ok := strings.Cut(strings.TrimPrefix(name, mcpDynamicPrefix), "__")
		if !ok || server == "" {
			return nil
		}
		return []ItemRef{{Kind: relationdomain.EntityKindMCP, ID: server, Name: server, Verb: touchpointdomain.VerbExecuted}}
	}
	if name == "get_relations" {
		kind, _ := args["kind"].(string)
		id, _ := args["id"].(string)
		if id == "" || !touchpointdomain.IsValidItemKind(kind) {
			return nil
		}
		return []ItemRef{{Kind: kind, ID: id, Verb: touchpointdomain.VerbViewed}}
	}
	if name == "create_document" {
		m := docIDRe.FindStringSubmatch(output)
		if m == nil {
			return nil
		}
		return []ItemRef{{Kind: relationdomain.EntityKindDocument, ID: m[1], Verb: touchpointdomain.VerbCreated}}
	}
	r, ok := catalog[name]
	if !ok {
		return nil
	}
	var id string
	switch {
	case r.argKey != "":
		id, _ = args[r.argKey].(string)
	case r.outputKey != "":
		var out map[string]any
		if json.Unmarshal([]byte(output), &out) != nil {
			return nil
		}
		id, _ = out[r.outputKey].(string)
	}
	if id == "" {
		return nil // absent optional filter / unparsable output — under-report, never error 缺席/不可解析:少报不报错
	}
	ref := ItemRef{Kind: r.kind, ID: id, Verb: r.verb}
	if r.nameIsID {
		ref.Name = id
	}
	return []ItemRef{ref}
}
