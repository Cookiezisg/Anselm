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

// fallbackTitleMaxLen keeps a local title readable when it is derived from a long request.
// fallbackTitleMaxLen 约束本地兜底标题长度，避免把长请求切成半个词。
const fallbackTitleMaxLen = 60

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
// not yet auto-titled). It is best-effort and outside the queue wait group — a title is never on the
// critical path, so shutdown must not spend its whole grace period waiting for a slow utility model.
// The lifecycle context cancels normal clients, and autoTitle checks it before its final write for
// clients that ignore cancellation. No Titler/Resolver wired → no-op.
//
// maybeAutoTitle 为对话的**首回合**（仍无标题且未自动标题）起后台标题。它是 best-effort 且不进 queue
// 的等待组——标题不在关键路径，故关停不能把整个 grace 花在等慢 utility 模型上。lifecycle context 会
// 取消正常 client；对无视取消的 client，autoTitle 会在最后写盘前再检查。无 Titler/Resolver → no-op。
func (s *Service) maybeAutoTitle(conv *conversationdomain.Conversation, workspaceID string) {
	if s.deps.Titler == nil || s.deps.Resolver == nil {
		return
	}
	if conv.AutoTitled || strings.TrimSpace(conv.Title) != "" {
		return
	}
	go func() {
		s.autoTitle(conv.ID, workspaceID)
	}()
}

// autoTitle generates and persists a conversation's auto title from its first exchange, on a
// service-lifecycle-owned + time-boxed context. The utility model is preferred, but a local
// request-derived title is the honest fallback when the utility route is unavailable, times out,
// or emits no text: a one-turn conversation must not stay "New chat" forever because an optional
// background chore failed.
//
// autoTitle 在 service lifecycle + 限时 context 上从对话首次交流生成并落标题。优先用 utility 模型；
// utility 不可用、超时或只吐 reasoning 时，诚实回落到本地首条请求标题——一次性对话不能因为可选的后台
// 杂活失败就永远叫「New chat」。
func (s *Service) autoTitle(conversationID, workspaceID string) {
	dctx := s.lifecycleContext(workspaceID)
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
	// A provider may ignore context cancellation and return after Shutdown. It is then too late
	// to persist anything: the owning service may already be closing its database.
	// provider 可能无视 context cancel、在 Shutdown 后才返回。此时已经不能再落盘：所属 service 可能已经
	// 开始关闭数据库。
	if dctx.Err() != nil {
		return
	}
	// SetAutoTitle persists Title+AutoTitled AND emits conversation.auto_titled on the
	// notifications stream (the frontend re-reads the row + arms the title typewriter). That is
	// the sole emit — chat no longer double-notifies.
	// SetAutoTitle 落 Title+AutoTitled 并在 notifications 流发 conversation.auto_titled（前端据此重读
	// 行 + 触发标题打字机）。这是唯一发信——chat 不再重复通知。
	// The persist gets a FRESH deadline off the lifecycle context — never the leftover of the generate
	// budget (WRK-083 L11). 落盘从 lifecycle context 取一个**新鲜的** deadline——绝不是生成预算的残额。
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
		if title := cleanFallbackTitle(userText(m)); title != "" {
			return title
		}
	}
	return ""
}

// cleanFallbackTitle caps a request-derived title at a readable boundary and marks omission.
// cleanFallbackTitle 在可读边界截断请求标题并标出省略，避免用户误以为半截词是完整标题。
func cleanFallbackTitle(s string) string {
	s = cleanTitle(s)
	runes := []rune(s)
	if len(runes) <= fallbackTitleMaxLen {
		return s
	}

	// Reserve one rune for the omission mark. If the prefix already ends at a word boundary,
	// keep it; otherwise walk back to a boundary only when doing so preserves a useful title.
	// 预留一个 rune 给省略号；前缀恰好落在词边界时保留，否则在标题足够长时回退到词边界。
	cutLen := fallbackTitleMaxLen - 1
	cut := runes[:cutLen]
	if !isFallbackTitleBoundary(runes[cutLen]) {
		boundary := -1
		for i := len(cut) - 1; i >= 0; i-- {
			if isFallbackTitleBoundary(cut[i]) {
				boundary = i
				break
			}
		}
		if boundary >= 30 {
			cut = cut[:boundary]
		}
	}

	result := strings.TrimRight(string(cut), " \t.,;:!?。！？，；：")
	if result == "" {
		return "…"
	}
	return result + "…"
}

func isFallbackTitleBoundary(r rune) bool {
	return r == ' ' || r == '\t'
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
