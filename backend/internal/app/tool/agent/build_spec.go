package agent

import toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"

// Build marks create/edit_agent as build tools (SSE-C): the streaming agent config (prompt /
// tools / knowledge) mirrors onto the entities stream so the agent panel fills in live.
//
// Build 标记 create/edit_agent 为 build 工具（SSE-C）：流式 agent 配置（prompt/tools/knowledge）镜像到
// entities 流，使 agent 面板实时填充。
func (*CreateAgent) Build() toolapp.BuildSpec { return toolapp.BuildSpec{Kind: "agent", Op: "create"} }
func (*EditAgent) Build() toolapp.BuildSpec   { return toolapp.BuildSpec{Kind: "agent", Op: "edit"} }
