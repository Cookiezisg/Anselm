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

	// Pre-authorize this skill's allowed-tools for the rest of the run (consumed by the danger
	// confirmation flow). allowed-tools = pre-approval, NOT a restriction whitelist. TRUST GATE
	// (WRK-076 B4): an INSTALLED skill's allowed-tools are a REQUESTED grant until the user
	// approves them — before that the body still injects, but the pre-approval is withheld and
	// dangerous calls keep walking the per-call confirmation.
	//
	// 把本 skill 的 allowed-tools 预授权到本次运行剩余部分（由危险确认流消费）。
	// allowed-tools = 预授权，不是限制白名单。**信任门**（WRK-076 B4）：**安装来源**的 skill，
	// allowed-tools 在用户授权前只是请求——正文照常注入，但预授权不装、危险调用照走逐次确认。
	if state, ok := reqctxpkg.GetAgentState(ctx); ok {
		allowed := sk.Frontmatter.AllowedTools
		if sk.Source == skilldomain.SourceInstalled {
			if prov, pErr := s.repo.ReadProvenance(ctx, name); pErr != nil || prov == nil || !prov.ToolsApproved {
				allowed = nil // 门关着：active skill 仍记名，预授权集为空
			}
		}
		state.SetActiveSkill(sk.Name, allowed)
	}

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
