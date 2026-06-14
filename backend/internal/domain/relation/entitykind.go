package relation

import "strings"

// EntityKind enumerates the node types that can appear in the topology graph. The
// graph shows the Quadrinity (function/handler/workflow/agent) plus the resources
// they reference (document/skill/mcp), the conversation that forged them, the
// trigger signal sources that drive workflows, and the control/approval entities a
// workflow's nodes reference.
//
// EntityKind 枚举可出现在拓扑图中的节点类型：Quadrinity（function/handler/workflow/agent）
// 加上它们引用的资源（document/skill/mcp）、锻造它们的 conversation、驱动 workflow 的
// trigger 信号源，以及 workflow 节点引用的 control/approval 实体。
const (
	EntityKindFunction     = "function"
	EntityKindHandler      = "handler"
	EntityKindWorkflow     = "workflow"
	EntityKindAgent        = "agent"
	EntityKindDocument     = "document"
	EntityKindConversation = "conversation"
	EntityKindSkill        = "skill"
	EntityKindMCP          = "mcp"
	EntityKindTrigger      = "trigger"
	EntityKindControl      = "control"  // ctl_：workflow control 节点引用的路由逻辑实体
	EntityKindApproval     = "approval" // apf_：workflow approval 节点引用的审批渲染实体（非 apv_=运行时）
)

// IsValidEntityKind reports whether k is one of the 11 node kinds.
//
// IsValidEntityKind 报告 k 是否 11 种节点类型之一。
func IsValidEntityKind(k string) bool {
	switch k {
	case EntityKindFunction, EntityKindHandler, EntityKindWorkflow, EntityKindAgent,
		EntityKindDocument, EntityKindConversation, EntityKindSkill, EntityKindMCP,
		EntityKindTrigger, EntityKindControl, EntityKindApproval:
		return true
	}
	return false
}

// Edge kind is the verb of a directed edge. The two endpoints' types already live
// in the from_kind/to_kind columns, so a kind needs only the verb — not the pair.
// Hence four verbs cover every relationship, and the DB CHECK stays a 4-value set
// no matter how many entity kinds exist.
//
// 边类型是有向边的动词。两端类型已在 from_kind/to_kind 列里，故 kind 只需动词、不必编码
// 端对——四个动词即覆盖全部关系，无论实体类型增加多少，DB CHECK 恒为 4 值集。
const (
	KindCreate = "create" // conversation 创造实体（产生 v1）
	KindEdit   = "edit"   // conversation 编辑实体（改出新版本）
	KindEquip  = "equip"  // workflow/agent 挂载工具/知识
	KindLink   = "link"   // document 文本性外链（仅提及）
)

// IsValidKind reports whether k is one of the 4 edge verbs.
//
// IsValidKind 报告 k 是否 4 个边动词之一。
func IsValidKind(k string) bool {
	switch k {
	case KindCreate, KindEdit, KindEquip, KindLink:
		return true
	}
	return false
}

// prefixKind maps a generated id's "<prefix>_<hex>" prefix to its EntityKind — the
// routing inherited from idgen so the whole codebase reads an entity's kind off its
// id. All 11 node kinds are registered. skill is file-based (name-as-id, no table);
// the rest are DB entities. Fixing every prefix HERE as the rule lets document
// wikilinks [[tag]] any kind with resolution that needs no per-kind change.
//
// prefixKind 把生成 id 的 "<前缀>_<hex>" 前缀映射到 EntityKind——从 idgen 收编的路由，
// 让全仓据 id 读出实体类型。11 种节点类型全部登记。skill 是文件式（name 即 id、无表），
// 其余为 DB 实体。每个前缀在此定死为规矩，使 document wikilink 能 [[tag]] 任意 kind、
// 解析无需逐 kind 改动。
var prefixKind = map[string]string{
	"fn":  EntityKindFunction,
	"hd":  EntityKindHandler,
	"wf":  EntityKindWorkflow,
	"ag":  EntityKindAgent,
	"doc": EntityKindDocument,
	"cv":  EntityKindConversation,
	"sk":  EntityKindSkill,
	"mcp": EntityKindMCP,
	"trg": EntityKindTrigger,
	"ctl": EntityKindControl,
	"apf": EntityKindApproval,
}

// KindForID returns the EntityKind for an id like "fn_a1b2…"; ok=false when the
// prefix is unknown (or the id has no "_" separator).
//
// KindForID 取 "fn_a1b2…" 形式 id 的 EntityKind；前缀未知（或无 "_" 分隔）时 ok=false。
func KindForID(id string) (string, bool) {
	i := strings.IndexByte(id, '_')
	if i <= 0 {
		return "", false
	}
	kind, ok := prefixKind[id[:i]]
	return kind, ok
}
