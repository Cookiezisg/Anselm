package chat

import (
	"context"
	"fmt"
	"strings"

	"go.uber.org/zap"

	mentiondomain "github.com/sunweilin/forgify/backend/internal/domain/mention"
	messagesdomain "github.com/sunweilin/forgify/backend/internal/domain/messages"
)

// attrMentions is the Message.Attrs key under which Send freezes a user turn's @-mention
// snapshots; LoadHistory reads them back to render the <mentions> block.
//
// attrMentions 是 Send 把 user 回合 @ mention 快照冻结进 Message.Attrs 的键；LoadHistory 读回以
// 渲染 <mentions> 块。
const attrMentions = "mentions"

// RegisterMentionResolver registers a domain's @-mention resolver, keyed by the type it handles
// (document / function / handler / workflow / agent / trigger / control / approval). Each owning
// app registers its own, so chat never imports the entity packages. Re-registering a type replaces
// it; a nil resolver is ignored.
//
// RegisterMentionResolver 注册某域的 @ mention resolver，按它处理的类型分键（document / function /
// handler / workflow / agent / trigger / control / approval）。各拥有方 app 注册自己的，故 chat 永不
// import 实体包。重复注册同类型即替换；nil resolver 忽略。
func (s *Service) RegisterMentionResolver(r mentiondomain.Resolver) {
	if r == nil {
		return
	}
	s.mentionResolvers[r.Type()] = r
}

// resolveMentions freezes each mention's content at send time (snapshot, not a live reference):
// it resolves via the registry and stores name + content. A missing resolver or a resolve error
// degrades to a stub snapshot — a broken @-reference never blocks sending the message.
//
// resolveMentions 在发送时冻结每个 mention 的内容（快照、非 live 引用）：经注册表解析、存 name +
// content。resolver 缺失或解析出错降级为 stub 快照——坏的 @ 引用绝不阻断发消息。
func (s *Service) resolveMentions(ctx context.Context, mentions []mentiondomain.MentionInput) []map[string]any {
	if len(mentions) == 0 {
		return nil
	}
	out := make([]map[string]any, 0, len(mentions))
	for _, m := range mentions {
		snap := map[string]any{"type": string(m.Type), "id": m.ID, "name": "(unavailable)"}
		if r, ok := s.mentionResolvers[m.Type]; ok {
			if ref, err := r.Resolve(ctx, m.ID); err == nil && ref != nil {
				snap["name"] = ref.Name
				snap["content"] = ref.Content
			} else if err != nil {
				s.log.Warn("chatapp.resolveMentions: resolve failed; stub",
					zap.String("type", string(m.Type)), zap.String("id", m.ID), zap.Error(err))
			}
		}
		out = append(out, snap)
	}
	return out
}

// mentionSnapshot is the read-back form of one frozen mention.
type mentionSnapshot struct{ Type, ID, Name, Content string }

// renderMentions renders a user turn's frozen mention snapshots into a <mentions> block prepended
// to the message text, so the LLM sees the referenced entities' content inline. Empty when the
// turn had no mentions.
//
// renderMentions 把一个 user 回合冻结的 mention 快照渲成前置到消息文本的 <mentions> 块，使 LLM
// 内联看到被引用实体的内容。回合无 mention 时为空。
func renderMentions(m *messagesdomain.Message) string {
	snaps := mentionSnapshotsOf(m)
	if len(snaps) == 0 {
		return ""
	}
	var b strings.Builder
	b.WriteString("<mentions>")
	for _, s := range snaps {
		fmt.Fprintf(&b, "\n<mention type=%q id=%q name=%q>", s.Type, s.ID, s.Name)
		if s.Content != "" {
			b.WriteString("\n" + s.Content)
		}
		b.WriteString("\n</mention>")
	}
	b.WriteString("\n</mentions>")
	return b.String()
}

// mentionSnapshotsOf reads the frozen mention snapshots from Attrs. Send stores []map[string]any;
// a JSON round-trip (store persists Attrs as JSON) yields []any of map[string]any, so both are
// handled.
//
// mentionSnapshotsOf 从 Attrs 读冻结的 mention 快照。Send 存 []map[string]any；JSON 往返（store 把
// Attrs 存为 JSON）产出 []any of map[string]any，故两种都处理。
func mentionSnapshotsOf(m *messagesdomain.Message) []mentionSnapshot {
	raw, ok := m.Attrs[attrMentions]
	if !ok {
		return nil
	}
	var items []any
	switch v := raw.(type) {
	case []any:
		items = v
	case []map[string]any:
		for _, e := range v {
			items = append(items, e)
		}
	default:
		return nil
	}
	out := make([]mentionSnapshot, 0, len(items))
	for _, it := range items {
		mp, ok := it.(map[string]any)
		if !ok {
			continue
		}
		out = append(out, mentionSnapshot{
			Type:    mentionStr(mp["type"]),
			ID:      mentionStr(mp["id"]),
			Name:    mentionStr(mp["name"]),
			Content: mentionStr(mp["content"]),
		})
	}
	return out
}

func mentionStr(v any) string {
	s, _ := v.(string)
	return s
}
