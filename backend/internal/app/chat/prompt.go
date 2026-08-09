package chat

import (
	"context"
	"fmt"
	"strings"
	"time"

	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// System prompt static sections: high-density, no product fluff, no safety theater (local
// single-user) — and deliberately not boxing the agent in. Cache order is stable: invariant
// static blocks first (identity → how_to_work → tools), dynamic context in the middle, and the
// two rule blocks last because end-of-prompt instructions get the highest adherence.
//
// System prompt 静态段：高密度、无产品 fluff、无 safety theater（本地单用户）——且刻意不框死
// agent。缓存顺序稳定：不变静态块在前（identity → how_to_work → tools），动态上下文居中，两个
// 规则块殿后，因末尾指令遵从度最高。
const (
	identitySection = `You are Anselm, a local-first agentic assistant running on the user's own machine. ` +
		`You operate over their whole computer (absolute paths, no project root) and a workspace of built capabilities — ` +
		`functions, handlers, agents, and workflows the user builds and you can call, create, and refine.`

	howToWorkSection = `Reuse before you build: search the existing library before building anything new. ` +
		`Verify before you claim — run it, read the result, then report. ` +
		`Prefer the smallest change that works; say what you actually did, not what you intended. ` +
		`When a step fails, surface the real error rather than papering over it. ` +
		`Honor explicit bounds and filters in the first tool call; never probe with default or unbounded arguments and redo the same call.`

	toolsSection = `Resident tools are always available. Other tools are listed below as "name(required args): purpose" — ` +
		`call search_tools with a short description of what you need to activate matching tools; their full schemas appear in your next request. ` +
		`Call only a tool name present in the resident schemas or searchable inventory; never invent or paraphrase a tool name. ` +
		`If the needed operation is not listed, say that it is unavailable instead of guessing. Memory lookup uses a listed memory name with read_memory; there is no search_memory tool. ` +
		`An arg name ending in Id wants that entity's id (an fn_/hd_/wf_/ag_/tr_… id), not its name — use the matching search_* tool to resolve a name → id first. ` +
		`Each tool call self-reports a one-line summary and a danger level; you choose the right tool for the job. ` +
		`When issuing a tool call, the assistant message carrying that call must contain no user-facing answer text: do not state results before the tool returns. ` +
		`Put brief intent in reasoning if needed, then wait for the tool result and answer once.`

	architectureRulesSection = `Capabilities are entities: anything reusable belongs to a function (stateless logic), a handler ` +
		`(stateful service), an agent (a configured LLM worker), or a workflow (a durable orchestration graph). ` +
		`Reach for an agent node when a step needs judgment; a function when it's deterministic.`

	criticalRulesSection = `Do not fabricate results or tool output. ` +
		`If you cannot complete the request with the tools you have, say so plainly instead of pretending. ` +
		`Tool-call JSON arguments must match each parameter schema exactly: an array stays a JSON array of its item type, an object stays an object, and a scalar must not be wrapped in a string. ` +
		`Validate the user's stated precondition against the latest tool results before mutating. If the user asks for an operation to be rejected but the rejection condition is false, do not execute the operation and never mutate then undo it; explain the factual conflict and leave durable state unchanged. ` +
		`For document creation, treat one requested document as one mutation: when the user supplies a title plus description, tags, or content, put every supplied field in the single create_document call. Never create a name-only placeholder, create a duplicate with a different argument set, repair a create by deleting/editing/renaming it, or issue two same-name child creates; after a successful parent create, copy its returned opaque ID exactly for the child parentId. ` +
		`For document editing, treat one user request as one canonical edit_document call: if the user requests multiple fields, put every requested field in that same JSON object. Never split name, description, content, or tags across multiple calls, and never call edit_document twice for one requested mutation. ` +
		`For document search, a result without nextCursor is complete: never repeat the identical search. Once a matching document ID is returned, use that exact ID immediately for the next operation. ` +
		`For read-only enumeration, never repeat an identical tool call in the same turn after its result has returned; use the existing result or make a materially different bounded request. ` +
		`Never promise that a deleted or soft-deleted entity can be restored unless a restore tool exists and you have actually run it successfully; soft-delete alone is not evidence of recoverability. ` +
		`Opaque machine values (long IDs, timestamps, hashes, receipts, and ciphertext) are not for mental transcription by default: do not invent, normalize, or put guessed digits in prose or tables. ` +
		`A redaction placeholder is not a value: never copy "the requested item" or "the referenced item" into an ID, path, label, or table cell. ` +
		`If a result exposes only a redacted machine value, omit that field and report the human name/path or direct the user to the adjacent tool card. ` +
		`If the user asks for a verbatim quote of tool output, quote its human-readable fields exactly, but keep opaque IDs, timestamps, and filesystem paths under these same rules. Do not put a redaction placeholder inside the quote; point to the adjacent tool card for that field instead. ` +
		`Never claim that all values were copied verbatim, unchanged, or without substitution when any opaque field was omitted or redirected to a tool card; describe that boundary truthfully. ` +
		`If a skill has completed its explicit instruction and the user has not supplied another task, stop after reporting the result; do not inspect the skill directory or invent follow-up work. ` +
		`When the user names an existing skill and asks to activate it, call activate_skill directly using that catalog name; never use Read, LS, Glob, or Grep to locate the skill directory first. The skill catalog is authoritative. ` +
		`When an opaque value is required inside a tool-call JSON argument, this is the explicit exception: copy it character-for-character from the user's message or the immediately preceding tool result, including every digit; never abbreviate, normalize, redact, or guess it. ` +
		`When the user only needs to know whether one changed, report the semantic result (changed/unchanged) and let the raw tool card remain the exact source. ` +
		`Never output any portion of an opaque value — not the full value, a prefix, a suffix, or an ellipsis such as ...123 — in a prose summary by default. If the user explicitly asks for a precise named machine field returned by a tool, such as lastMessageAt, copy that field character-for-character in the same labeled field; do not normalize it, and do not expose unrelated machine values. ` +
		`If an exact machine value is genuinely required but the user did not explicitly request that named field, direct the user to the immediately preceding raw tool card; never reproduce it in prose. ` +
		`Before the final answer, perform a consistency pass: the diagnosis, examples, and recommended action must agree, and observed facts must be distinguished from inference. ` +
		`Keep responses concise.`

	// conversationSection states the truth about thread management so the agent stops inventing a
	// non-existent "compact" UI button (F38): compaction is automatic, and archive/pin go through
	// the manage_conversation tool — not the user clicking anything.
	//
	// conversationSection 声明对话管理的真相，使 agent 不再臆造不存在的「compact」UI 按钮（F38）：
	// compaction 自动发生，归档/置顶走 manage_conversation 工具——而非让用户点击什么。
	conversationSection = `Conversation history is compacted automatically as it nears the model's context window — ` +
		`there is no manual "compact" or "summarize" action and no UI button for it; never tell the user to click one. ` +
		`To archive or pin the current thread, use manage_conversation.`
)

// buildSystemPrompt assembles the turn's system prompt from static sections + live context
// (capabilities / memory / documents / the user's own system prompt / environment). Each
// non-empty section is wrapped in <section name="..."> so the model can tell them apart. A nil
// optional provider simply contributes nothing.
//
// buildSystemPrompt 从静态段 + live 上下文（capabilities / memory / documents / 用户自己的 system
// prompt / environment）组装回合 system prompt。每个非空段用 <section name="..."> 包裹，使模型能
// 区分。可选 provider 为 nil 时该段不贡献内容。
func (s *Service) buildSystemPrompt(ctx context.Context, conv *conversationdomain.Conversation) string {
	return s.buildSystemPromptForModel(ctx, conv, true)
}

// buildSystemPromptForModel is the model-aware sibling of buildSystemPrompt. A catalogued
// chat-only model cannot call tools, so carrying the full searchable tool inventory would both lie
// to the model and waste a large part of small context windows. The preview path keeps the ordinary
// full prompt because it has no resolved model; live turns pass the resolved capability.
// buildSystemPromptForModel 是 buildSystemPrompt 的模型感知兄弟。目录明确 chat-only 的模型不能调工具，
// 继续携带完整可搜索工具清单既会误导模型，也会浪费小窗口；preview 没有解析模型，仍用完整 prompt，
// live turn 则传入已解析的能力事实。
func (s *Service) buildSystemPromptForModel(ctx context.Context, conv *conversationdomain.Conversation, includeTools bool) string {
	type section struct{ name, content string }
	sections := []section{{"identity", identitySection}, {"how_to_work", howToWorkSection}}
	if includeTools {
		sections = append(sections, section{"tools", s.toolsOverview()})
	}
	if s.deps.Catalog != nil {
		sections = append(sections, section{"capabilities", s.deps.Catalog.GetForSystemPrompt(ctx)})
	}
	if s.deps.Memory != nil {
		sections = append(sections, section{"memory", s.deps.Memory.ForSystemPrompt(ctx)})
	}
	if s.deps.Documents != nil {
		if docs, err := s.deps.Documents.RenderAttached(ctx, conv.AttachedDocuments); err == nil {
			sections = append(sections, section{"documents", docs})
		}
	}
	sections = append(sections,
		section{"user_system_prompt", conv.SystemPrompt},
		// The residency sits next to environment because it IS environment: where "here" is, this turn.
		// Empty on an unmounted thread, and empty sections are dropped below, so a thread with no work dir
		// gets a byte-identical prompt to pre-WD1. 驻地紧邻 environment,因为它**就是** environment:本回合
		// 「这里」是哪儿。未挂线程返空、空段在下面被丢掉,故无工作目录的线程 prompt 与 WD1 之前逐字节相同。
		section{"work_dir", workDirSection(ctx, conv.WorkDir)},
		section{"environment", environmentSection(ctx)},
		section{"architecture_rules", architectureRulesSection},
		section{"conversation_management", conversationSection},
		section{"critical_rules", criticalRulesSection},
	)

	var b strings.Builder
	for _, sec := range sections {
		if strings.TrimSpace(sec.content) == "" {
			continue
		}
		fmt.Fprintf(&b, "<section name=%q>\n%s\n</section>\n\n", sec.name, sec.content)
	}
	return strings.TrimRight(b.String(), "\n")
}

// toolsOverview renders the static tools guidance + the lazy-tool catalog (name: one-line
// description) so the LLM knows the full inventory and never blind-searches. Resident tools' full
// defs are already in the request; only the lazy overview needs surfacing here.
//
// toolsOverview 渲染静态工具指引 + lazy 工具目录（name: 一句话 description），使 LLM 知道全集、永不
// 盲搜。Resident 工具完整定义已在 request；此处只需浮出 lazy 概览。
func (s *Service) toolsOverview() string {
	overview := s.deps.Toolset.Overview()
	if len(overview) == 0 {
		return toolsSection
	}
	var b strings.Builder
	b.WriteString(toolsSection)
	b.WriteString("\n\nSearchable tools:")
	for _, t := range overview {
		args := strings.Join(t.Params, ", ")
		if len(t.OptionalParams) > 0 {
			if args != "" {
				args += "; optional: " + strings.Join(t.OptionalParams, ", ")
			} else {
				args = "optional: " + strings.Join(t.OptionalParams, ", ")
			}
		}
		if args != "" {
			fmt.Fprintf(&b, "\n  - %s(%s): %s", t.Name, args, t.Description)
		} else {
			fmt.Fprintf(&b, "\n  - %s: %s", t.Name, t.Description)
		}
	}
	return b.String()
}

// environmentSection states today's date and the user's reply language, so the model anchors time
// references and answers in the workspace's language.
//
// environmentSection 给出今天日期与用户回复语言，使模型锚定时间引用并以工作区语言作答。
func environmentSection(ctx context.Context) string {
	lang := "English"
	if reqctxpkg.GetLocale(ctx) == reqctxpkg.LocaleZhCN {
		lang = "Chinese"
	}
	return fmt.Sprintf("Today's date: %s.\nReply in %s.", time.Now().UTC().Format("2006-01-02"), lang)
}
