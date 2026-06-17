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
	rendered := substitute(sk.Body, substituteVars{
		Arguments: arguments,
		NamedArgs: sk.Frontmatter.Arguments,
		SessionID: convID,
	})

	// Pre-authorize this skill's allowed-tools for the rest of the run (consumed by the danger
	// confirmation flow). allowed-tools = pre-approval, NOT a restriction whitelist.
	//
	// 把本 skill 的 allowed-tools 预授权到本次运行剩余部分（由危险确认流消费）。
	// allowed-tools = 预授权，不是限制白名单。
	if state, ok := reqctxpkg.GetAgentState(ctx); ok {
		state.SetActiveSkill(sk.Name, sk.Frontmatter.AllowedTools)
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
	return substitute(sk.Body, substituteVars{SessionID: convID}), nil
}

// substituteVars carries the values for placeholder expansion.
//
// substituteVars 承载占位替换的取值。
type substituteVars struct {
	Arguments []string
	NamedArgs []string
	SessionID string
}

// substitute expands $ARGUMENTS / $1..$n / named placeholders / ${CLAUDE_SESSION_ID}.
// ${CLAUDE_SKILL_DIR} and !`cmd` shell injection are intentionally NOT supported (the former
// has no attached-files surface to point at; the latter is an arbitrary-exec surface we decline).
//
// substitute 展开 $ARGUMENTS / $1..$n / 命名占位 / ${CLAUDE_SESSION_ID}。
// 刻意不支持 ${CLAUDE_SKILL_DIR}（无附加文件目录可指）与 !`cmd` shell 注入（任意执行面，拒绝）。
func substitute(body string, v substituteVars) string {
	pairs := []string{
		"${CLAUDE_SESSION_ID}", v.SessionID,
		"$ARGUMENTS", strings.Join(v.Arguments, " "),
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
