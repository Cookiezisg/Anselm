package tool

import (
	"context"
	"fmt"

	relationdomain "github.com/sunweilin/anselm/backend/internal/domain/relation"
)

// DependentCounter reports the live entities that reference (mounted/linked) a given entity — the
// honest "what breaks if I delete this" signal (incoming equip/link relation edges). The relation
// app Service satisfies it. A delete tool reads this BEFORE deleting (the purge erases the edges)
// so its result can name which dependents may now fail (F48/F160). One shared port instead of a
// per-package copy, mirroring how ToJSON is shared.
//
// DependentCounter 报告引用（挂载/外链）某实体的存活实体——诚实的「删了它什么会坏」信号（入向 equip/link
// 边）。relation app Service 满足之。delete 工具在删**前**读它（purge 会抹掉边），使结果能点名哪些依赖可能
// 失效（F48/F160）。一个共享端口、非各包各抄一份（同 ToJSON 共享思路）。
type DependentCounter interface {
	CountDependents(ctx context.Context, kind, id string) (int, error)
	ListDependents(ctx context.Context, kind, id string) ([]*relationdomain.Relation, error)
}

// DependentRefs returns the {kind,id} refs of every live entity referencing (kind,id), or nil when
// the counter is nil / the read fails — advisory only, a delete must never fail because this did. A
// delete tool calls it BEFORE deleting (the purge erases the edges) so it can tell the agent EXACTLY
// which entities to repair, not just a count it can no longer expand (F160).
//
// DependentRefs 返回引用 (kind,id) 的每个存活实体的 {kind,id} ref；counter 为 nil / 读失败时返 nil——仅
// advisory，绝不因此让 delete 失败。delete 工具在删**前**调它，使其能告诉 agent **究竟**修哪些实体、而非一个
// 删后再也展不开的计数（F160）。
func DependentRefs(ctx context.Context, counter DependentCounter, kind, id string) []map[string]string {
	if counter == nil {
		return nil
	}
	edges, err := counter.ListDependents(ctx, kind, id)
	if err != nil {
		return nil
	}
	refs := make([]map[string]string, 0, len(edges))
	for _, e := range edges {
		refs = append(refs, map[string]string{"kind": e.FromKind, "id": e.FromID})
	}
	return refs
}

// DependentCount returns how many live entities reference (kind,id) via equip/link edges, or 0 when
// the counter is nil (delete tool wired without relations) or the read fails — advisory only, a
// delete must never fail because the dependent-count read did.
//
// DependentCount 返回有多少存活实体经 equip/link 边引用 (kind,id)，counter 为 nil（delete 工具未接
// relations）或读失败时返 0——仅 advisory，绝不因依赖计数读失败而让 delete 失败。
func DependentCount(ctx context.Context, counter DependentCounter, kind, id string) int {
	if counter == nil {
		return 0
	}
	n, err := counter.CountDependents(ctx, kind, id)
	if err != nil || n < 0 {
		return 0
	}
	return n
}

// AnnotateDependents folds the dependents' {kind,id} refs + a count + a repair note into a delete
// tool's result map when any live entity still references the just-deleted one — so the agent learns
// EXACTLY which entities may now break and can repair each by id (the edges are already purged, so a
// bare count would be unfollowable, F160). No dependents → the map is returned unchanged (no false alarm).
//
// AnnotateDependents 在仍有存活实体引用刚删实体时，给 delete 工具结果 map 折入依赖的 {kind,id} ref + 计数 +
// 修复提示——使 agent 知道**究竟**哪些实体可能坏、可按 id 逐个修（边已 purge，裸计数无从追，F160）。无依赖 →
// map 原样返回（不虚惊）。
func AnnotateDependents(out map[string]any, refs []map[string]string) map[string]any {
	if len(refs) > 0 {
		out["dependents"] = refs
		out["dependentCount"] = len(refs)
		out["note"] = dependentsNote
	}
	return out
}

// DependentSuffix is the string-result counterpart of AnnotateDependents for delete tools that return
// a human sentence (e.g. delete_agent) rather than a JSON map. It names the referencing refs so the
// agent can repair them. Empty when there are no dependents.
//
// DependentSuffix 是 AnnotateDependents 的字符串对应物，供返回人话句子（如 delete_agent）而非 JSON map 的
// delete 工具用。它点名引用方 ref 使 agent 能逐个修。无依赖时为空。
func DependentSuffix(refs []map[string]string) string {
	if len(refs) == 0 {
		return ""
	}
	ids := make([]string, 0, len(refs))
	for _, r := range refs {
		ids = append(ids, r["id"])
	}
	return fmt.Sprintf(" Note: %s. Referencing entities: %v.", dependentsNote, ids)
}

const dependentsNote = "this entity was referenced by other entities (workflows/agents that equipped it, or documents that linked it); they may now fail — the referencing entities are listed in `dependents`; edit each to drop or repoint the now-dead reference"
