package chat

import (
	"context"
	"strings"
	"time"

	"go.uber.org/zap"

	loopapp "github.com/sunweilin/anselm/backend/internal/app/loop"
	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

const autoTitleMaxLen = 80

// autoTitleTimeout budgets the SLOW half — loading the thread and generating the title (a network
// call). A var, not a const, so a test can shrink it and drive the "the generate step ate the whole
// budget" case deterministically instead of sleeping ten real seconds.
//
// autoTitleTimeout 为**慢的那半**编预算——读线程 + 生成标题(一次网络调用)。用 var 而非 const,好让测试把它
// 调小、确定性地驱动「生成步吃光了预算」那个情形,而不是真睡十秒。
var autoTitleTimeout = 10 * time.Second

// autoTitlePersistTimeout budgets the FAST half — one local SQLite read + write. It gets its OWN
// deadline, freshly derived from the DETACHED context, because sharing the generate budget means the
// slow step can starve the final write (real machine, WRK-083 L11 —
// `set title failed: conversationstore.Get: context deadline exceeded`). This applies equally to a
// utility-generated title and the local request-derived fallback. This is S9's rule read to its end:
// an async finalize must not be cancelled by what preceded it.
//
// autoTitlePersistTimeout 为**快的那半**编预算——一次本地 SQLite 读+写。它拿**自己的** deadline、从 detached
// context 新derive,因为与生成步共用预算意味着慢的会把最后的写入**饿死**(真机,WRK-083 L11)。这同时保护
// utility 生成的标题和本地首句兜底标题。这是把 S9 读到底:异步 finalize 不该被它之前的那一步取消。
const autoTitlePersistTimeout = 5 * time.Second

// autoTitleSystem instructs the utility model to produce a bare title. End-of-prompt phrasing +
// "output only the title" keeps small models from adding quotes / preamble.
//
// autoTitleSystem 指示 utility 模型产出裸标题。末尾措辞 +「只输出标题」使小模型不加引号 / 前言。
const autoTitleSystem = "Generate a concise title (5-10 words) for the conversation below, " +
	"written in the same language the conversation is in. " +
	"Output only the title text — no quotes, no surrounding punctuation, no preamble."

// maybeAutoTitle kicks off a background title for a conversation's FIRST turn (still untitled and
// not yet auto-titled). It is best-effort + detached — a title is never on the critical path, so
// every failure is swallowed — and tracked by s.wg so Shutdown waits for it. No Titler/Resolver
// wired → no-op.
//
// maybeAutoTitle 为对话的**首回合**（仍无标题且未自动标题）起后台标题。best-effort + detached
// ——标题不在关键路径，故所有失败吞掉——并被 s.wg 追踪使 Shutdown 等它。无 Titler/Resolver → no-op。
func (s *Service) maybeAutoTitle(conv *conversationdomain.Conversation, workspaceID string) {
	if s.deps.Titler == nil || s.deps.Resolver == nil {
		return
	}
	if conv.AutoTitled || strings.TrimSpace(conv.Title) != "" {
		return
	}
	s.wg.Add(1)
	go func() {
		defer s.wg.Done()
		s.autoTitle(conv.ID, workspaceID)
	}()
}

// autoTitle generates and persists a conversation's auto title from its first exchange, on a
// detached + time-boxed context. The utility model is preferred, but a local request-derived title
// is the honest fallback when the utility route is unavailable, times out, or emits no text: a
// one-turn conversation must not stay "New chat" forever because an optional background chore failed.
//
// autoTitle 在 detached + 限时 context 上从对话首次交流生成并落标题。优先用 utility 模型；utility
// 不可用、超时或只吐 reasoning 时，诚实回落到本地首条请求标题——一次性对话不能因为可选的后台杂活失败
// 就永远叫「New chat」。
func (s *Service) autoTitle(conversationID, workspaceID string) {
	dctx := reqctxpkg.Detached(workspaceID)
	dctx = reqctxpkg.SetConversationID(dctx, conversationID)
	ctx, cancel := context.WithTimeout(dctx, autoTitleTimeout)
	defer cancel()

	thread, err := s.messages.LoadThread(ctx, conversationID)
	if err != nil || len(thread) == 0 {
		return
	}
	excerpt := titleExcerpt(thread)
	if excerpt == "" {
		return
	}

	// The workspace utility model (a small, cheap model, seeded to the managed default at
	// provisioning). No utility default configured → MODEL_NOT_CONFIGURED, dropped best-effort.
	// workspace utility 模型（小而廉价，provisioning 时已播成 managed 默认）。未配则 MODEL_NOT_CONFIGURED、best-effort 丢弃。
	title := ""
	fallback := fallbackTitle(thread)
	fallbackReason := ""
	bundle, err := s.deps.Resolver.ResolveUtility(ctx)
	if err != nil {
		fallbackReason = "utility model unavailable"
	} else {
		req := bundle.Request
		req.System = autoTitleSystem
		req.Messages = []llminfra.LLMMessage{{Role: llminfra.RoleUser, Content: excerpt}}

		raw, generateErr := llminfra.Generate(ctx, bundle.Client, req)
		if generateErr != nil {
			fallbackReason = "utility generation failed"
		} else {
			title = cleanTitle(raw)
			if title == "" {
				fallbackReason = "utility produced no text"
			}
		}
	}
	if title == "" {
		title = fallback
		if title == "" {
			return
		}
		s.log.Info("chatapp.autoTitle: using local fallback", zap.String("reason", fallbackReason))
	}
	// SetAutoTitle persists Title+AutoTitled AND emits conversation.auto_titled on the
	// notifications stream (the frontend re-reads the row + arms the title typewriter). That is
	// the sole emit — chat no longer double-notifies.
	// SetAutoTitle 落 Title+AutoTitled 并在 notifications 流发 conversation.auto_titled（前端据此重读
	// 行 + 触发标题打字机）。这是唯一发信——chat 不再重复通知。
	// The persist gets a FRESH deadline off the DETACHED context — never the leftover of the generate
	// budget (WRK-083 L11). 落盘从 **detached** context 取一个**新鲜的** deadline——绝不是生成预算的残额。
	pctx, pcancel := context.WithTimeout(dctx, autoTitlePersistTimeout)
	defer pcancel()
	if err := s.deps.Titler.SetAutoTitle(pctx, conversationID, title); err != nil {
		s.log.Warn("chatapp.autoTitle: set title failed", zap.Error(err))
		return
	}
}

// fallbackTitle returns a concise, local title from the first user request. It is deliberately
// independent of the model route so the conversation remains identifiable during gateway outage,
// utility timeout, or a thinking-only response.
//
// fallbackTitle 从首条用户请求生成简洁本地标题。它刻意不依赖模型路由，故网关故障、utility 超时或只返回
// thinking 时，对话仍然可识别。
func fallbackTitle(thread []*messagesdomain.Message) string {
	for _, m := range thread {
		if m.Role != messagesdomain.RoleUser {
			continue
		}
		if title := cleanTitle(userText(m)); title != "" {
			return title
		}
	}
	return ""
}

// titleExcerpt renders the first user + first assistant text into a compact prompt for titling.
//
// titleExcerpt 把首条 user + 首条 assistant 文本渲成给标题用的紧凑 prompt。
func titleExcerpt(thread []*messagesdomain.Message) string {
	var user, assistant string
	for _, m := range thread {
		if user == "" && m.Role == messagesdomain.RoleUser {
			user = userText(m)
		}
		if assistant == "" && m.Role == messagesdomain.RoleAssistant {
			assistant = loopapp.ExtractTextContent(m.Blocks)
		}
		if user != "" && assistant != "" {
			break
		}
	}
	var b strings.Builder
	if user != "" {
		b.WriteString("User: " + user)
	}
	if assistant != "" {
		if b.Len() > 0 {
			b.WriteString("\n")
		}
		b.WriteString("Assistant: " + assistant)
	}
	return b.String()
}

// cleanTitle strips quotes / surrounding punctuation / extra lines and caps the length, so a
// chatty small model's output still lands as a tidy one-line title.
//
// cleanTitle 去引号 / 首尾标点 / 多余行并截断长度，使啰嗦小模型的输出仍落成整洁单行标题。
func cleanTitle(s string) string {
	s = strings.TrimSpace(s)
	if i := strings.IndexAny(s, "\n\r"); i >= 0 {
		s = s[:i]
	}
	s = strings.TrimSpace(strings.Trim(strings.TrimSpace(s), `"'`))
	s = strings.TrimRight(s, ".。!！?？ ")
	if len([]rune(s)) > autoTitleMaxLen {
		s = strings.TrimSpace(string([]rune(s)[:autoTitleMaxLen]))
	}
	return s
}
