package skill

import toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"

// Forge marks create/edit_skill as forge tools (SSE-C): the streaming skill body mirrors onto the
// entities stream so the skill panel fills in live.
//
// Forge 标记 create/edit_skill 为 forge 工具（SSE-C）：流式 skill 正文镜像到 entities 流，使 skill 面板实时填充。
func (*CreateSkill) Forge() toolapp.ForgeSpec { return toolapp.ForgeSpec{Kind: "skill", Op: "create"} }
func (*EditSkill) Forge() toolapp.ForgeSpec   { return toolapp.ForgeSpec{Kind: "skill", Op: "edit"} }
