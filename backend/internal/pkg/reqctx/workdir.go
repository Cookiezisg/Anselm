package reqctx

import "context"

type workDirKey struct{}

// SetWorkDir returns a copy of ctx carrying the conversation's mounted work dir (the "residency").
// It lives in ctx rather than in AgentState because it is per-turn IMMUTABLE CONFIG read off the
// conversation row — not mutable cross-tool state — and because ctx is what makes inheritance free:
// a subagent run derives its ctx from the parent turn's, so it lands inside the same residency
// without a single line of plumbing (agentstate is deliberately reset per subagent, which would
// have LOST the residency).
//
// Empty = not mounted, and that is the whole-machine status quo: tools keep taking absolute paths
// anywhere, Bash keeps inheriting the backend's own cwd.
//
// SetWorkDir 返回携带该对话已挂驻地的 ctx 拷贝。它住在 ctx 而非 AgentState,因为它是从对话行读来的
// **逐回合不可变配置**、不是可变的跨工具状态;更因为 ctx 让「继承」免费:subagent 运行的 ctx 由父回合
// 派生,故它自动落在同一驻地里、零管线代码(agentstate 是刻意每个 subagent 重置的,走它会**丢掉**驻地)。
//
// 空 = 未挂,即整台机器的现状:工具照旧收任意绝对路径、Bash 照旧继承后端自己的 cwd。
func SetWorkDir(ctx context.Context, dir string) context.Context {
	return context.WithValue(ctx, workDirKey{}, dir)
}

// GetWorkDir returns the mounted work dir, or "" when the turn has none. It returns ONE value (like
// GetLocale, unlike the id getters) because "not seeded" and "seeded empty" are the same fact here —
// no residency — and every consumer (fspath.ExpandIn, fspath.Inside, Bash's cmd.Dir) already treats ""
// as its no-op. An `ok` would only invite a branch that does nothing.
//
// GetWorkDir 返回已挂驻地，无则 ""。它只返**一个**值（同 GetLocale、不同于那些 id getter），因为此处
// 「没种」与「种了空」是同一个事实——无驻地——而每个消费方（fspath.ExpandIn、fspath.Inside、Bash 的
// cmd.Dir）本就把 "" 当作自己的 no-op。多一个 `ok` 只会招来一个什么都不做的分支。
func GetWorkDir(ctx context.Context) string {
	dir, _ := ctx.Value(workDirKey{}).(string)
	return dir
}
