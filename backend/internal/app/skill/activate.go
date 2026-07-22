package skill

import (
	"context"
	"fmt"
	"strconv"
	"strings"

	skilldomain "github.com/sunweilin/anselm/backend/internal/domain/skill"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// Activate loads a skill, substitutes placeholders, records it as the run's active skill (so
// its allowed-tools become pre-approved), then either returns the rendered body (inline →
// injected into the current dialogue) or dispatches an isolated subagent (fork).
//
// Activate 加载 skill、替换占位、把它记为本次运行的 active skill（其 allowed-tools 即成预授权），
// 然后要么返回渲染后的正文（inline → 注入当前对话），要么派一个隔离 subagent（fork）。
func (s *Service) Activate(ctx context.Context, name string, arguments []string) (string, error) {
	sk, err := s.repo.Get(ctx, name)
	if err != nil {
		return "", fmt.Errorf("skillapp.Activate: %w", err)
	}

	convID, _ := reqctxpkg.GetConversationID(ctx)
	rendered := s.renderWithSkillDir(ctx, sk, substituteVars{
		Arguments: arguments,
		NamedArgs: sk.Frontmatter.Arguments,
		SessionID: convID,
	})

	s.applyActiveSkill(ctx, sk)

	if sk.Context == skilldomain.ContextFork {
		agentType := strings.TrimSpace(sk.Frontmatter.Agent)
		if agentType == "" {
			return "", skilldomain.ErrForkRequiresAgent
		}
		if s.subagent == nil {
			return "", skilldomain.ErrSubagentUnavailable // subagent runner 未注入时 fork 降级
		}
		result, serr := s.subagent.Spawn(ctx, agentType, rendered)
		if serr != nil {
			return "", fmt.Errorf("skillapp.Activate fork: %w", serr)
		}
		return result, nil
	}

	return rendered, nil
}

// applyActiveSkill records sk as the run's active skill and pre-authorizes its allowed-tools
// (consumed by the danger-confirmation flow). allowed-tools = pre-approval, NOT a restriction
// whitelist. TRUST GATE (WRK-076 B4): an INSTALLED skill's allowed-tools are a REQUESTED grant
// until the user approves them — before that the pre-approval is withheld (the active skill is
// still recorded, but with an empty grant), so dangerous calls keep walking the per-call
// confirmation. No agent state → no-op. Shared by Activate (the tool path) and
// PreauthorizeActiveSkill (the @-mention path).
//
// applyActiveSkill 把 sk 记为本次运行的 active skill 并预授权其 allowed-tools（由危险确认流消费）。
// allowed-tools = 预授权、非限制白名单。**信任门**（WRK-076 B4）：**安装来源**的 skill，其
// allowed-tools 在用户授权前只是请求——授权前预授权不装（active skill 仍记名、但授权集空），危险
// 调用照走逐次确认。无 agent state → no-op。由 Activate（工具路径）与 PreauthorizeActiveSkill
// （@ 提及路径）共用。
func (s *Service) applyActiveSkill(ctx context.Context, sk *skilldomain.Skill) {
	state, ok := reqctxpkg.GetAgentState(ctx)
	if !ok {
		return
	}
	allowed := sk.Frontmatter.AllowedTools
	if sk.Source == skilldomain.SourceInstalled {
		if prov, pErr := s.repo.ReadProvenance(ctx, sk.Name); pErr != nil || prov == nil || !prov.ToolsApproved {
			allowed = nil // 门关着：active skill 仍记名，预授权集为空
		}
	}
	state.SetActiveSkill(sk.Name, allowed)
}

// PreauthorizeActiveSkill is the side-effect half of a @-mention activation (WRK-076): it records
// the @-mentioned skill as the run's active skill and pre-authorizes its allowed-tools, WITHOUT
// rendering or forking — the CONTENT half already rode the mention snapshot (the resolver's
// Guide-rendered body). FORK skills are skipped: a fork's activation is a subagent dispatch, not
// an @ semantic (the model drives fork via activate_skill); an @-mentioned fork skill injects its
// instructions but grants no pre-authorization. Missing skill → error (best-effort at the caller).
//
// PreauthorizeActiveSkill 是 @ 提及激活的副作用半（WRK-076）：把被 @ 的 skill 记为本次运行的
// active skill 并预授权其 allowed-tools，**不**渲染、**不** fork——内容半已随 mention 快照注入
// （resolver 的 Guide 渲染 body）。**fork** skill 跳过：fork 的激活是派 subagent、非 @ 语义
// （模型经 activate_skill 驱动 fork）；被 @ 的 fork skill 注入指令但不授予预授权。缺失 skill → 报错
// （调用方 best-effort）。
func (s *Service) PreauthorizeActiveSkill(ctx context.Context, name string) error {
	sk, err := s.repo.Get(ctx, name)
	if err != nil {
		return fmt.Errorf("skillapp.PreauthorizeActiveSkill: %w", err)
	}
	if sk.Context == skilldomain.ContextFork {
		return nil // fork 非 @ 激活语义——不设预授权
	}
	s.applyActiveSkill(ctx, sk)
	return nil
}

// Guide renders a skill's body as a mounted execution guide (the agent-mount path): rendered
// with no invocation arguments, NOT recorded as the run's active skill (an agent's tools are
// explicit mounts — there is no allowed-tools pre-approval to install, and writing into a parent
// chat's AgentState would leak the pre-approval across runs), and never forked (a guide is text
// for THIS run, whatever the skill's own context mode says).
//
// Guide 把 skill 正文渲染为挂载的执行指南（agent 挂载路径）：无调用参数渲染、**不**记为本次运行的
// active skill（agent 的工具是显式挂载——没有 allowed-tools 预授权可装，写进父 chat 的 AgentState
// 会把预授权泄漏到别的运行）、也绝不 fork（指南就是给**本次**运行的文本，无论 skill 自己的 context
// 模式是什么）。
func (s *Service) Guide(ctx context.Context, name string) (string, error) {
	sk, err := s.repo.Get(ctx, name)
	if err != nil {
		return "", fmt.Errorf("skillapp.Guide: %w", err)
	}
	convID, _ := reqctxpkg.GetConversationID(ctx)
	return s.renderWithSkillDir(ctx, sk, substituteVars{SessionID: convID}), nil
}

// renderWithSkillDir renders the body with the directory anchor resolved: ${CLAUDE_SKILL_DIR}
// substitutes to the skill directory's absolute path (ecosystem skills write this exact
// placeholder — it must work verbatim, WRK-076 B2), and a skill that has bundled files but
// never wrote the placeholder gets ONE preamble line naming the directory — without an anchor
// the LLM cannot resolve the relative `references/…` / `scripts/…` paths its body cites.
// Single-file skills get no preamble (nothing to point at — pure token cost).
//
// renderWithSkillDir 渲染正文并解决目录锚点：${CLAUDE_SKILL_DIR} 替换为 skill 目录绝对路径
// （生态 skill 写的就是这个占位符——必须原名生效，WRK-076 B2）；带捆绑文件却没写占位符的
// skill 前置**一行**目录说明——没有锚点，LLM 无从解析正文引用的 `references/…`/`scripts/…`
// 相对路径。单文件 skill 不加前导（无物可指——纯 token 开销）。
func (s *Service) renderWithSkillDir(ctx context.Context, sk *skilldomain.Skill, v substituteVars) string {
	dir, dErr := s.repo.Dir(ctx, sk.Name)
	if dErr != nil {
		return substitute(sk.Body, v) // 拿不到目录（刚被删的竞态）→ 退化为纯替换
	}
	v.SkillDir = dir
	out := substitute(sk.Body, v)
	if !strings.Contains(sk.Body, "${CLAUDE_SKILL_DIR}") {
		if files, fErr := s.repo.ListFiles(ctx, sk.Name); fErr == nil && len(files) > 1 {
			out = "This skill's directory (its bundled files live here): " + dir + "\n\n" + out
		}
	}
	return out
}

// substituteVars carries the values for placeholder expansion.
//
// substituteVars 承载占位替换的取值。
type substituteVars struct {
	Arguments []string
	NamedArgs []string
	SessionID string
	SkillDir  string // ${CLAUDE_SKILL_DIR} 取值；空 = 占位符字面保留（不抹空）
}

// substitute expands $ARGUMENTS / $1..$n / named placeholders / ${CLAUDE_SESSION_ID} /
// ${CLAUDE_SKILL_DIR}. !`cmd` shell injection is intentionally NOT supported (activation-time
// arbitrary exec — worse in a world of third-party installed skills, we decline).
//
// substitute 展开 $ARGUMENTS / $1..$n / 命名占位 / ${CLAUDE_SESSION_ID} / ${CLAUDE_SKILL_DIR}。
// 刻意不支持 !`cmd` shell 注入（激活期任意执行——在三方安装 skill 的世界里更危险，拒绝）。
func substitute(body string, v substituteVars) string {
	pairs := []string{
		"${CLAUDE_SESSION_ID}", v.SessionID,
		"$ARGUMENTS", strings.Join(v.Arguments, " "),
	}
	if v.SkillDir != "" {
		pairs = append(pairs, "${CLAUDE_SKILL_DIR}", v.SkillDir)
	}
	// 高位优先，避免 $1 抢吃 $12 的前缀
	for i := len(v.Arguments); i >= 1; i-- {
		pairs = append(pairs, "$"+strconv.Itoa(i), v.Arguments[i-1])
	}
	for i, name := range v.NamedArgs {
		if i >= len(v.Arguments) {
			break
		}
		if name == "" {
			continue
		}
		pairs = append(pairs, "$"+name, v.Arguments[i])
	}
	return strings.NewReplacer(pairs...).Replace(body)
}
