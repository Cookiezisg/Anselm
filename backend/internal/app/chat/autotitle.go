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
// slow step can starve the fast one: the title was already produced, and it was then thrown away at
// the last inch by a deadline that had nothing to do with writing it (real machine, WRK-083 L11 —
// `set title failed: conversationstore.Get: context deadline exceeded`). A one-turn conversation
// stays named "New chat" forever in that case, while its perfectly good title dies in memory.
// This is S9's rule read to its end: an async finalize must not be cancelled by what preceded it.
//
// autoTitlePersistTimeout 为**快的那半**编预算——一次本地 SQLite 读+写。它拿**自己的** deadline、从 detached
// context 新derive,因为与生成步共用预算意味着慢的会把快的**饿死**:标题**已经生成出来了**,却在最后一寸被一个
// 与「写它」毫无关系的 deadline 丢掉(真机,WRK-083 L11)。那种情况下,只发过一轮的对话会永远叫「New chat」,
// 而它那个完全可用的标题死在内存里。这是把 S9 读到底:异步 finalize 不该被它之前的那一步取消。
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
// detached + time-boxed context. Any failure (no thread / resolve / generate / persist) is logged
// and dropped — the conversation simply stays untitled.
//
// autoTitle 在 detached + 限时 context 上从对话首次交流生成并落标题。任何失败（无线程 / 解析 /
// 生成 / 落盘）记日志后丢弃——对话就保持无标题。
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
	bundle, err := s.deps.Resolver.ResolveUtility(ctx)
	if err != nil {
		s.log.Warn("chatapp.autoTitle: resolve utility failed", zap.Error(err))
		return
	}
	req := bundle.Request
	req.System = autoTitleSystem
	req.Messages = []llminfra.LLMMessage{{Role: llminfra.RoleUser, Content: excerpt}}

	raw, err := llminfra.Generate(ctx, bundle.Client, req)
	if err != nil {
		s.log.Warn("chatapp.autoTitle: generate failed", zap.Error(err))
		return
	}
	title := cleanTitle(raw)
	if title == "" {
		return
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
	if len(s) > autoTitleMaxLen {
		s = strings.TrimSpace(s[:autoTitleMaxLen])
	}
	return s
}
