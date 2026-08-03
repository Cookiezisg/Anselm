// Package tool defines the Tool contract every system tool implements and the framework
// machinery for LLM tool-call handling: standard-field injection/stripping (summary /
// danger / execution_group) and the resident/lazy Toolset partition. It is a pure
// app-layer interface module — no domain, no store, no persistence — depended on by the
// loop, every tool adapter, and chat.
//
// Package tool 定义每个 system tool 实现的 Tool 契约，以及 LLM 工具调用处理的 framework 设施：
// 标准字段注入/剥离（summary / danger / execution_group）+ resident/lazy 的 Toolset 分组。
// 纯 app 层接口模块——无 domain、无 store、无持久化——被 loop、每个工具适配器、chat 依赖。
package tool

import (
	"context"
	"encoding/json"
	"fmt"
)

// DangerLevel is the LLM's reported risk for one tool call (the injected `danger` field). Most
// tools use that report directly, while a tool may provide a non-bypassable DangerFloorer floor
// when risk is an operation fact. The loop gates on the effective level: dangerous blocks for user
// approval, cautious is surfaced but not blocked, safe runs silently.
//
// DangerLevel 是 LLM 对一次工具调用报告的危险度（注入的 `danger` 字段）。多数工具直接使用该报告；风险由
// 操作事实决定时，工具可提供不可绕过的 DangerFloorer 下限。loop 据有效等级设闸：dangerous 阻塞等用户同意、
// cautious 标记不阻塞、safe 静默执行。
type DangerLevel string

const (
	// DangerSafe — read-only or trivially reversible, and free beyond ordinary tokens; runs silently.
	// DangerSafe —— 只读或可逆、且除常规 token 外不花钱；静默执行。
	DangerSafe DangerLevel = "safe"
	// DangerCautious — modifies recoverable state, or spends a small metered amount; runs but is
	// surfaced prominently, no block.
	// DangerCautious —— 改可恢复状态、或花掉一笔有计量的小钱；执行但前端显著标记、不阻塞。
	DangerCautious DangerLevel = "cautious"
	// DangerDangerous — irreversible, an external write, or spends at a rate the user would want to
	// be asked about; blocks for user approval. SPENDING COUNTS: money cannot be un-spent, so a call
	// that only writes a file is still dangerous when that file cost real money (WRK-082 H5.6).
	// DangerDangerous —— 不可逆、外部写、或以用户会想被问一句的费率花钱；阻塞等用户同意。**花钱算数**：
	// 钱花掉就收不回,故一次「只是写了个文件」的调用,在那个文件要花真钱时**依然是** dangerous（H5.6）。
	DangerDangerous DangerLevel = "dangerous"
)

// DangerFloorer is an optional tool contract for calls whose risk is a fact of the operation,
// not a model opinion. The loop raises the reported level to this floor before gating, ledger
// deduplication, or presenting the call. It deliberately stays optional so S18's five-method Tool
// interface does not grow.
//
// DangerFloorer 是可选工具契约，给那些风险由操作事实决定、不是模型意见的调用设下限。loop 在设闸、台账去重
// 和展示调用前把自报等级抬到这个下限。它刻意保持可选，故 S18 的五方法 Tool 接口不扩张。
type DangerFloorer interface {
	MinimumDanger() DangerLevel
}

// CallIdentityer is an optional contract for tools whose business identity is narrower than their
// full JSON shape. The loop uses it to suppress a repeated guarded mutation even when a model changes
// irrelevant or invalid fields between attempts (for example delete_workflow + file_path).
//
// CallIdentityer 是可选契约，给业务身份比完整 JSON 更窄的工具使用。loop 据此压制同一受保护 mutation
// 的重复调用，即使模型在重试间改了无关或非法字段（例如 delete_workflow + file_path）。
type CallIdentityer interface {
	CallIdentity(args json.RawMessage) string
}

// ArgumentNormalizer is an optional, narrow compatibility seam for a tool that can repair a
// provider-produced argument key without changing its business meaning. The loop applies it before
// the call is persisted or executed, so the visible tool card, audit trail, and execution all agree.
// A normalizer must be conservative: return changed=false unless the supplied value is unambiguous.
//
// ArgumentNormalizer 是工具可选的、窄范围兼容缝，用于修复 provider 产出的参数键而不改变业务含义。
// loop 在落盘和执行前应用它，使可见 tool card、审计和执行三者一致。normalizer 必须保守：只有值无歧义
// 时才返回 changed=true。
type ArgumentNormalizer interface {
	NormalizeArguments(args json.RawMessage) (normalized json.RawMessage, changed bool)
}

// NormalizeArguments applies a tool's optional argument repair hook.
//
// NormalizeArguments 应用工具可选的参数修复钩子。
func NormalizeArguments(t Tool, args json.RawMessage) (json.RawMessage, bool) {
	normalizer, ok := t.(ArgumentNormalizer)
	if !ok {
		return args, false
	}
	normalized, changed := normalizer.NormalizeArguments(args)
	if !changed || len(normalized) == 0 {
		return args, false
	}
	return normalized, true
}

// CallIdentity returns a tool-defined business identity, or an empty string when the tool has no
// narrower identity contract. The empty result falls back to the full normalized argument object.
//
// CallIdentity 返回工具定义的业务身份；没有更窄契约时返回空串，调用方回退到完整规范化参数对象。
func CallIdentity(t Tool, args json.RawMessage) string {
	if identity, ok := t.(CallIdentityer); ok {
		return identity.CallIdentity(args)
	}
	return ""
}

// MinimumDanger returns a tool's non-bypassable static danger floor.
//
// MinimumDanger 返回工具不可绕过的静态危险下限。
func MinimumDanger(t Tool) DangerLevel {
	if floorer, ok := t.(DangerFloorer); ok {
		floor := floorer.MinimumDanger()
		if IsValidDanger(string(floor)) {
			return floor
		}
	}
	return DangerSafe
}

// RaiseDanger applies a static floor to a model-reported danger level. Invalid or missing model
// values retain the existing fail-open safe default; a valid floor can only raise, never lower.
//
// RaiseDanger 把静态下限应用到模型自报等级。非法/缺失自报仍保留既有 fail-open safe 默认；有效下限只升不降。
func RaiseDanger(reported, floor DangerLevel) DangerLevel {
	if !IsValidDanger(string(reported)) {
		reported = DangerSafe
	}
	if !IsValidDanger(string(floor)) {
		floor = DangerSafe
	}
	if dangerRank(floor) > dangerRank(reported) {
		return floor
	}
	return reported
}

func dangerRank(level DangerLevel) int {
	switch level {
	case DangerDangerous:
		return 2
	case DangerCautious:
		return 1
	default:
		return 0
	}
}

// EffectiveDanger returns the model report after applying the tool's static floor.
//
// EffectiveDanger 返回应用工具静态下限后的模型自报等级。
func EffectiveDanger(t Tool, reported DangerLevel) DangerLevel {
	return RaiseDanger(reported, MinimumDanger(t))
}

// IsValidDanger reports whether s is one of the three levels.
//
// IsValidDanger 报告 s 是否三级之一。
func IsValidDanger(s string) bool {
	switch DangerLevel(s) {
	case DangerSafe, DangerCautious, DangerDangerous:
		return true
	}
	return false
}

// Tool is the contract every system tool implements — exactly these five methods. The
// three standard fields (summary / danger / execution_group) are NOT methods: the
// framework injects them into the schema (ToLLMDef) and strips them from args
// (StripStandardFields), so a tool only ever declares and receives its own business
// parameters.
//
// Tool 是每个 system tool 实现的契约——恰这五个方法。三个标准字段（summary / danger /
// execution_group）**不是方法**：framework 注入进 schema（ToLLMDef）、从 args 剥离
// （StripStandardFields），故工具只声明、只收到自己的业务参数。
type Tool interface {
	// Name is the tool's call name (e.g. "Read", "run_function").
	//
	// Name 是工具调用名（如 "Read"、"run_function"）。
	Name() string

	// Description is the LLM-facing usage doc; may be large — the reason a Toolset can
	// load it lazily.
	//
	// Description 是给 LLM 的用法说明；可能很大——正是 Toolset 可懒加载它的理由。
	Description() string

	// Parameters is the JSON Schema of the tool's business args, WITHOUT the standard fields.
	//
	// Parameters 是工具业务参数的 JSON Schema，**不含**标准字段。
	Parameters() json.RawMessage

	// ValidateInput cheaply rejects bad business args pre-Execute; the error is surfaced
	// to the LLM for retry.
	//
	// ValidateInput 在 Execute 前廉价拒绝坏业务参数；错误反馈给 LLM 重试。
	ValidateInput(args json.RawMessage) error

	// Execute runs the tool against the stripped (business-only) args and returns the
	// result text shown back to the LLM.
	//
	// Execute 以剥离后（只含业务）的 args 运行工具，返回回显给 LLM 的结果文本。
	Execute(ctx context.Context, argsJSON string) (string, error)
}

// BuildTool is an optional interface for create/edit tools whose streaming args ARE an entity's
// content being written (a function's code, a workflow's graph …). When a tool implements it, the
// loop mirrors that arg delta onto the entities SSE stream (SSE-C) so the entity panel fills in
// live as the LLM types. A build tool only declares its entity Kind + Op — the loop stays generic
// (no arg parsing) and the front end parses the streamed args to render the entity.
//
// BuildTool 是 create/edit 工具的可选接口——它们的流式 args 本身就是某实体正被写出的内容（function 的代码、
// workflow 的图…）。实现它后，loop 把那份 arg delta 镜像到 entities SSE 流（SSE-C），使实体面板随 LLM 打字
// 实时填充。build 工具只声明实体 Kind + Op——loop 保持通用（不解析 args），前端解析流式 args 渲染实体。
type BuildTool interface {
	Build() BuildSpec
}

// BuildSpec is a build tool's self-description: the entities-stream scope Kind it builds and whether
// this call creates or edits.
//
// BuildSpec 是 build 工具的自描述：它构建的 entities 流 scope Kind + 本次是创建还是编辑。
type BuildSpec struct {
	Kind string // entities-stream scope kind: "function" | "handler" | "agent" | "workflow" | "control" | "approval" | "document" | "skill"
	Op   string // "create" | "edit"
}

// FileWriteTool is an optional interface for tools whose call physically writes ONE file at a path
// carried in its own args (Write / Edit). It exists for the residency's write gate (WRK-077 WD1): when a
// conversation has a work dir mounted, a write landing OUTSIDE that subtree is escalated to a human
// confirmation no matter what danger level the LLM self-reported — an out-of-root write is a fact about
// the TARGET PATH, and the model's own honesty about it cannot be the last line of defence.
//
// The loop asserts this exactly the way it asserts BuildTool: the gate stays generic (it cannot tell a
// `file_path` from a `content`) and each tool answers for its own arg shape. Returning "" — unparseable
// args, no path — falls through to the normal danger gate, which is correct: a write whose target cannot
// be determined will fail in Execute anyway, and inventing a confirmation for it would train the user to
// click through prompts that mean nothing.
//
// NOT one of Tool's five methods (which stay exactly five, S18): an optional capability interface is how
// this codebase already extends a tool without widening the contract every tool must satisfy.
//
// FileWriteTool 是可选接口，用于「一次调用物理地写**一个**文件、且路径就在自己 args 里」的工具
// （Write / Edit）。它为驻地的越界写闸而存在（WRK-077 WD1）：当对话挂了工作目录时，落在该子树**之外**的
// 写会被升级为一次人工确认，**无论** LLM 自报了哪个 danger 等级——越界写是关于**目标路径**的一个事实，
// 模型对此的诚实不能是最后一道防线。
//
// loop 断言它的方式与断言 BuildTool 完全一致：闸保持通用（它分不清 `file_path` 与 `content`）、每个工具
// 为自己的 args 形状负责。返回 "" ——args 解不开、没有路径——会落回普通 danger 闸，这是对的：一次目标都
// 定不下来的写在 Execute 里本来也会失败，而为它凭空造一次确认，只会训练用户闭眼点掉什么都不代表的弹窗。
//
// 它**不在** Tool 的五方法里（五个仍是恰五个，S18）：可选能力接口正是本仓库既有的「扩展一个工具而不加宽
// 每个工具都必须满足的契约」的做法。
type FileWriteTool interface {
	// WriteTarget returns the raw, UNRESOLVED path from args (the ~ / relative / absolute form the LLM
	// wrote). Resolution is the caller's job so that exactly ONE place applies the residency root —
	// resolving here would duplicate fspath and let the two copies drift.
	//
	// WriteTarget 返回 args 里**未解析**的原始路径（LLM 写下的 ~ / 相对 / 绝对形态）。解析是调用方的活，
	// 使施加驻地根的地方**恰有一处**——在此解析会复制一份 fspath、让两份逐渐走偏。
	WriteTarget(argsJSON json.RawMessage) string
}

// ToJSON renders any value as a compact JSON string for a tool result. Marshal failure (only
// possible for non-JSON-able values like channels — a programming error, not runtime input)
// degrades to fmt %v so the LLM still sees something rather than an empty string. One shared
// helper instead of a per-package copy in each tool package.
//
// ToJSON 把任意值渲染成紧凑 JSON 字符串作工具结果。Marshal 失败（仅 channel 等不可 JSON 值——
// 编程错误而非运行期输入）降级 fmt %v，让 LLM 至少看到内容而非空串。一个共享 helper 代替各工具
// 包各自一份副本。
func ToJSON(v any) string {
	b, err := json.Marshal(v)
	if err != nil {
		return fmt.Sprintf("%v", v)
	}
	return string(b)
}
