package todo

import (
	"fmt"
	"strings"

	tododomain "github.com/sunweilin/forgify/backend/internal/domain/todo"
)

// normalize trims and validates a write: content required, status defaulted to pending
// and whitelisted, activeForm falling back to content. Rejects oversized lists. Returns a
// fresh non-nil slice (an empty write is a deliberate clear, not a no-op).
//
// normalize trim 并校验一次写入：content 必填，status 缺省 pending 且白名单校验，activeForm
// 回退到 content。拒绝超量清单。返回新的非 nil 切片（空写是刻意清空、非 no-op）。
func normalize(items []tododomain.Item) ([]tododomain.Item, error) {
	if len(items) > tododomain.MaxItems {
		return nil, tododomain.ErrTooManyItems
	}
	out := make([]tododomain.Item, 0, len(items))
	for _, it := range items {
		content := strings.TrimSpace(it.Content)
		if content == "" {
			return nil, tododomain.ErrEmptyContent
		}
		status := it.Status
		if status == "" {
			status = tododomain.StatusPending
		}
		if !tododomain.IsValidStatus(status) {
			return nil, tododomain.ErrInvalidStatus
		}
		active := strings.TrimSpace(it.ActiveForm)
		if active == "" {
			active = content
		}
		out = append(out, tododomain.Item{Content: content, ActiveForm: active, Status: status})
	}
	return out, nil
}

// render draws the whole checklist as a compact markdown list for the TodoWrite tool
// result — the model sees its just-written plan echoed back.
//
// render 把整张清单画成紧凑 markdown 列表给 TodoWrite tool 结果——模型看到刚写的计划被回显。
func render(items []tododomain.Item) string {
	if len(items) == 0 {
		return "(todo list cleared — no tasks)"
	}
	var b strings.Builder
	for i, it := range items {
		if i > 0 {
			b.WriteByte('\n')
		}
		b.WriteString(line(it))
	}
	return b.String()
}

// reminder renders the open (non-completed) tasks as a system-reminder block for per-turn
// injection, plus whether to inject (false when nothing is open). Completed tasks are
// summarised as a count so the model sees progress without re-reading them.
//
// reminder 把未完成任务渲染成 system-reminder 块供每轮注入，外加是否注入（无未完成时 false）。
// 已完成任务汇总为计数，让模型看到进度而不必重读。
func reminder(items []tododomain.Item) (string, bool) {
	open, done := 0, 0
	for _, it := range items {
		if it.Status == tododomain.StatusCompleted {
			done++
		} else {
			open++
		}
	}
	if open == 0 {
		return "", false
	}
	var b strings.Builder
	fmt.Fprintf(&b, "Current todo list (%d open, %d done):\n", open, done)
	for _, it := range items {
		b.WriteString(line(it))
		b.WriteByte('\n')
	}
	b.WriteString("Keep exactly one task in_progress; mark a task completed as soon as it is done. Use TodoWrite to update the whole list.")
	return b.String(), true
}

// line renders one item: [ ] pending, [→] in_progress (shows the activeForm), [x] completed.
//
// line 渲染一项：[ ] pending、[→] in_progress（显示 activeForm）、[x] completed。
func line(it tododomain.Item) string {
	switch it.Status {
	case tododomain.StatusInProgress:
		return "- [→] " + it.ActiveForm
	case tododomain.StatusCompleted:
		return "- [x] " + it.Content
	default:
		return "- [ ] " + it.Content
	}
}
