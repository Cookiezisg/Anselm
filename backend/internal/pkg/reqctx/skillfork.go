package reqctx

import "context"

type skillForkScopeKey struct{}
type skillForkReadPathsKey struct{}

// SetSkillForkScope marks a context as the bounded execution of a fork-mode Skill.
// It is deliberately separate from SubagentID: ordinary Task/Subagent runs retain the
// whole-machine filesystem contract, while Explore used by a Skill gets a narrower search scope.
//
// SetSkillForkScope 标记 fork Skill 的有界执行上下文。它刻意不复用 SubagentID：普通 Task/Subagent
// 仍保留整机文件系统契约，Skill 派出的 Explore 才获得更窄的搜索范围。
func SetSkillForkScope(ctx context.Context, enabled bool) context.Context {
	return context.WithValue(ctx, skillForkScopeKey{}, enabled)
}

// IsSkillForkScope reports whether the current subagent was dispatched by a fork-mode Skill.
func IsSkillForkScope(ctx context.Context) bool {
	enabled, _ := ctx.Value(skillForkScopeKey{}).(bool)
	return enabled
}

// SetSkillForkReadPaths carries the invocation arguments that are explicit absolute file paths.
// Explore may Read these exact files outside a mounted workdir, but may not turn them into a wider
// directory/search authorization.
//
// SetSkillForkReadPaths 携带调用参数中明确给出的绝对文件路径。Explore 可以在驻地外 Read 这些
// 精确文件，但不能把它们扩大成目录/搜索授权。
func SetSkillForkReadPaths(ctx context.Context, paths []string) context.Context {
	copyPaths := append([]string(nil), paths...)
	return context.WithValue(ctx, skillForkReadPathsKey{}, copyPaths)
}

// GetSkillForkReadPaths returns the explicit path arguments for the current fork Skill.
func GetSkillForkReadPaths(ctx context.Context) []string {
	paths, _ := ctx.Value(skillForkReadPathsKey{}).([]string)
	return append([]string(nil), paths...)
}
