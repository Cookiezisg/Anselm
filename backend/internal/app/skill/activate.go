package skill

import (
	"context"
	"fmt"
	"strconv"
	"strings"

	skilldomain "github.com/sunweilin/forgify/backend/internal/domain/skill"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
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
	// confirmation flow, ask 波次 6). allowed-tools = pre-approval, NOT a restriction whitelist.
	//
	// 把本 skill 的 allowed-tools 预授权到本次运行剩余部分（由危险确认流消费，ask 波次 6）。
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
			return "", skilldomain.ErrSubagentUnavailable // subagent 在波次 5 注入前 fork 降级
		}
		result, serr := s.subagent.Spawn(ctx, agentType, rendered)
		if serr != nil {
			return "", fmt.Errorf("skillapp.Activate fork: %w", serr)
		}
		return result, nil
	}

	return rendered, nil
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
// awaits L3 attached files; the latter is an arbitrary-exec surface we decline).
//
// substitute 展开 $ARGUMENTS / $1..$n / 命名占位 / ${CLAUDE_SESSION_ID}。
// 刻意不支持 ${CLAUDE_SKILL_DIR}（待 L3 附加文件）与 !`cmd` shell 注入（任意执行面，拒绝）。
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
