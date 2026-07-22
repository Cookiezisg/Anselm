// Package mention is the domain contract for @-mention references in chat: when a
// user @-mentions an entity, its content is snapshotted at send time and injected
// into that message's LLM context (freeze-on-send — the snapshot stays fixed even
// if the entity later changes). This package is pure contract: the MentionType set,
// the wire input, the resolved Reference, and the Resolver interface each entity
// app implements. Resolution and rendering live in the consumers (per-domain
// resolvers + chat), not here.
//
// Package mention 是 chat 中 @ 引用的 domain 契约：用户 @ 一个实体时，其内容在发送时刻快照、
// 注入该消息的 LLM 上下文（freeze-on-send——快照定格，实体日后改了也不变）。本包是纯契约：
// MentionType 集合、前端 input、解析后的 Reference、各实体 app 实现的 Resolver 接口。解析与
// 渲染在消费方（各域 resolver + chat），不在此。
package mention

import "context"

// MentionType is the closed set of @-mentionable entity kinds: the Quadrinity + document +
// trigger / control / approval + skill — kinds that carry an injectable content snapshot (the
// build entities so AI :iterate can seed them by reference; skill so a user can ACTIVATE it by
// @-mention, its rendered body becoming the snapshot). @-mention semantics diverge by type: a
// document is a reference, a skill is an ACTIVATION (the pre-authorization side-effect rides a
// separate chat hook — WRK-076). conversation/mcp are NOT mentionable (no single content snapshot).
//
// MentionType 是可被 @ 的实体类型封闭集：四件套 + document + trigger / control / approval + skill
// ——有可注入内容快照的类型（build 实体使 AI :iterate 能按引用种入；skill 使用户可 @ **激活**它、
// 其渲染后 body 即快照）。@ 语义按类型分岔：document 是引用，skill 是**激活**（预授权副作用走 chat
// 另一钩子——WRK-076）。conversation/mcp 不可 @（无单一内容快照）。
type MentionType string

const (
	MentionDocument MentionType = "document"
	MentionFunction MentionType = "function"
	MentionHandler  MentionType = "handler"
	MentionWorkflow MentionType = "workflow"
	MentionAgent    MentionType = "agent"
	// trigger / control / approval are build entities too — mentionable so the AI :iterate verb
	// can seed them by reference, exactly like the five above.
	//
	// trigger / control / approval 也是 build 实体——可 @，使 AI :iterate 能像上面五个一样按引用种入它们。
	MentionTrigger  MentionType = "trigger"
	MentionControl  MentionType = "control"
	MentionApproval MentionType = "approval"
	// skill is @-mentionable as an ACTIVATION handle (WRK-076): its rendered body is the injected
	// snapshot, and chat pre-authorizes the skill's allowed-tools for that turn. Id = the slug name.
	//
	// skill 作为**激活**句柄可 @（WRK-076）：其渲染 body 是注入快照，chat 为该回合预授权其 allowed-tools。id = slug 名。
	MentionSkill MentionType = "skill"
)

// IsValidMentionType reports whether t is one of the mentionable built kinds. Consumers
// (chat) validate incoming MentionInput against it.
//
// IsValidMentionType 报告 t 是否可 @ 的构建类型之一。消费方（chat）据此校验 MentionInput。
func IsValidMentionType(t MentionType) bool {
	switch t {
	case MentionDocument, MentionFunction, MentionHandler, MentionWorkflow, MentionAgent,
		MentionTrigger, MentionControl, MentionApproval, MentionSkill:
		return true
	}
	return false
}

// MentionInput is the per-mention wire shape the frontend sends: type + id only.
//
// MentionInput 是前端每个 mention 发来的形状：只 type + id。
type MentionInput struct {
	Type MentionType `json:"type"`
	ID   string      `json:"id"`
}

// Reference is the resolved snapshot stored on the message and rendered into the
// transcript. Content is the type-specific body (doc markdown / function code /
// handler methods / workflow graph / agent config), captured at send time.
//
// Reference 是已解析快照，存进消息并渲进 transcript。Content 是各类型自渲内文（doc markdown
// / function 代码 / handler 方法 / workflow 图 / agent 配置），发送时刻捕获。
type Reference struct {
	Type    MentionType `json:"type"`
	ID      string      `json:"id"`
	Name    string      `json:"name"`
	Content string      `json:"content"`
}

// Resolver is implemented by each capability app; chat holds a type→resolver
// registry and calls Resolve at send time to snapshot the mentioned entity.
//
// Resolver 由各能力 app 实现；chat 持 type→resolver 注册表，发送时调 Resolve 抓取被 @ 实体快照。
type Resolver interface {
	Type() MentionType
	Resolve(ctx context.Context, id string) (*Reference, error)
}
