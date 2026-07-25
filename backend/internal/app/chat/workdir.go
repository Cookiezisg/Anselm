package chat

import (
	"context"
	"fmt"

	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	gitinfoinfra "github.com/sunweilin/anselm/backend/internal/infra/gitinfo"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
)

// MarkWorkDirSwitch appends the durable in-line mark for a mid-thread residency change — the
// conversationapp.WorkDirMarker port. It is a synthetic assistant turn carrying ONE `marker` block,
// exactly the shape the compaction anchor uses (contextmgr.writeAnchor), because both answer the same
// need: something about the conversation itself changed, and a reader scrolling back must see where.
//
// It writes NOTHING on a thread with no messages yet. A mark is a boundary between a before and an
// after, and a thread whose first message hasn't been sent has no before — the mark would render as the
// opening line of an empty conversation, which is noise, not history. Mounting a residency before the
// first send is in fact the COMMON path (pick the directory, then start talking).
//
// No SSE frame is emitted, on purpose: the block rides the ordinary `GET /{id}/messages` read like the
// compaction anchor does, so `events.md`'s messages node.type vocabulary is untouched and E1/E2 hold
// (no new stream, no new frame type). A client that is looking at the thread when the switch happens
// re-reads through the conversation lifecycle echo the PATCH already broadcasts.
//
// Attrs carry `{kind:"workdir", from, to}` and Content stays EMPTY — the label is rendered client-side
// from attrs so it appears in the user's own language (a Go-side string would hardcode a locale into a
// durable row). `from` is empty on the first mount and `to` is empty on unmount; both ends being
// meaningful is why the pair is stored rather than just the new value.
//
// MarkWorkDirSwitch 为线程中途的驻地变更追加持久行内标记——即 conversationapp.WorkDirMarker 端口。它是
// 一个合成 assistant 回合、携带**一个** `marker` 块,与 compaction 锚（contextmgr.writeAnchor）完全同形,
// 因为两者答的是同一个需求:关于对话本身的某件事变了,往回翻的读者必须看见它变在哪里。
//
// 对**尚无消息**的线程它什么都不写。标记是「之前」与「之后」之间的界线,而首条消息还没发的线程没有「之前」
// ——那条标记会渲成一个空对话的开场白,那是噪音、不是历史。而首发之前就挂驻地恰恰是**常见**路径（先选目录、
// 再开口）。
//
// **刻意不发 SSE 帧**:该块像 compaction 锚一样随普通的 `GET /{id}/messages` 读取,故 `events.md` 的
// messages node.type 词表分毫不动、E1/E2 成立（不加新流、不加新帧型）。切换发生时正看着线程的客户端,靠
// PATCH 本就广播的对话生命周期回声重读。
//
// attrs 承载 `{kind:"workdir", from, to}`,Content **保持为空**——标签由客户端据 attrs 渲染,故它以用户
// 自己的语言出现（Go 侧写字符串等于把一种语言硬编码进一条持久行）。首次挂载时 `from` 为空、退出驻地时
// `to` 为空;两端都有意义,正是这一对被存下来、而不是只存新值的原因。
func (s *Service) MarkWorkDirSwitch(ctx context.Context, conversationID, from, to string) error {
	thread, err := s.messages.LoadThread(ctx, conversationID)
	if err != nil {
		return fmt.Errorf("chatapp.MarkWorkDirSwitch: load thread: %w", err)
	}
	if len(thread) == 0 {
		return nil
	}
	mark := &messagesdomain.Message{
		ID:             idgenpkg.New("msg"),
		ConversationID: conversationID,
		Role:           messagesdomain.RoleAssistant,
		Status:         messagesdomain.StatusCompleted,
	}
	block := messagesdomain.Block{
		Type: messagesdomain.BlockTypeMarker,
		Attrs: map[string]any{
			messagesdomain.MarkerAttrKind: messagesdomain.MarkerKindWorkDir,
			messagesdomain.MarkerAttrFrom: from,
			messagesdomain.MarkerAttrTo:   to,
		},
	}
	if err := s.messages.CreateMessage(ctx, mark, []messagesdomain.Block{block}); err != nil {
		return fmt.Errorf("chatapp.MarkWorkDirSwitch: write marker: %w", err)
	}
	return nil
}

// workDirSection renders the residency for the turn's system prompt: where "here" is, and the branch if
// it is a git repo. The model needs it because the two behaviours it enables are otherwise invisible to
// it — a relative path now resolves somewhere specific, and Bash now starts somewhere specific.
//
// It states the ZOOM honestly rather than implying a jail: the agent is told it may still read anywhere,
// because it can, and a prompt that implied confinement would make it refuse work it is allowed to do
// (and then argue with the user about it). The write gate is named too — a forced confirmation the model
// was not warned about reads as a random stall.
//
// Only the CHEAP git probe runs here (`rev-parse --abbrev-ref HEAD`, O(1)). Dirtiness is deliberately
// absent: it needs a work-tree walk, it changes between the prompt and the model's first tool call
// anyway, and the model can just run `git status` — whereas the residency PATH is something it cannot
// discover on its own.
//
// Empty when nothing is mounted, and buildSystemPrompt drops empty sections, so an unmounted thread's
// prompt is byte-identical to what it was before WD1.
//
// workDirSection 为该回合的 system prompt 渲染驻地:「这里」是哪儿,以及若是 git 仓库则给出分支。模型需要
// 它,因为它启用的那两个行为对模型本来是不可见的——相对路径现在会解析到一个具体地方、Bash 现在从一个具体
// 地方起步。
//
// 它诚实地陈述 **zoom**、而非暗示一座牢:明确告诉 agent 它仍可读任何地方,因为它确实可以;一个暗示禁闭的
// prompt 会让它拒掉它本被允许做的事（然后为此与用户争辩）。越界写闸也点明——一次没被预告的强制确认读起来
// 就是一次随机卡顿。
//
// 此处**只**跑廉价 git 探针（`rev-parse --abbrev-ref HEAD`，O(1)）。**刻意不给脏态**:它要走整个工作树、
// 而且在 prompt 与模型首次工具调用之间本就会变,模型自己跑一次 `git status` 即可——而驻地**路径**是它
// 无从自行发现的东西。
//
// 未挂时返空,而 buildSystemPrompt 会丢掉空段,故未挂线程的 prompt 与 WD1 之前逐字节相同。
func workDirSection(ctx context.Context, workDir string) string {
	if workDir == "" {
		return ""
	}
	line := "Working directory: " + workDir + "."
	if branch, isRepo := gitinfoinfra.Branch(ctx, workDir); isRepo && branch != "" {
		line += "\nGit branch: " + branch + "."
	}
	return line + "\nRelative paths resolve against this directory and Bash starts here. " +
		"You may still read anywhere on the machine with absolute paths — this is a focus, not a restriction. " +
		"Writing OUTSIDE this directory asks the user to confirm first, so prefer paths inside it."
}
