package agent

import toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"

// Forge marks create/edit_agent as forge tools (SSE-C): the streaming agent config (prompt /
// tools / knowledge) mirrors onto the entities stream so the agent panel fills in live.
//
// Forge 标记 create/edit_agent 为 forge 工具（SSE-C）：流式 agent 配置（prompt/tools/knowledge）镜像到
// entities 流，使 agent 面板实时填充。
func (*CreateAgent) Forge() toolapp.ForgeSpec { return toolapp.ForgeSpec{Kind: "agent", Op: "create"} }
func (*EditAgent) Forge() toolapp.ForgeSpec   { return toolapp.ForgeSpec{Kind: "agent", Op: "edit"} }
