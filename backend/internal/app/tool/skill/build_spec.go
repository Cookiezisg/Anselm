package skill

import toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"

// Build marks create/edit_skill as build tools (SSE-C): the streaming skill body mirrors onto the
// entities stream so the skill panel fills in live.
//
// Build 标记 create/edit_skill 为 build 工具（SSE-C）：流式 skill 正文镜像到 entities 流，使 skill 面板实时填充。
func (*CreateSkill) Build() toolapp.BuildSpec { return toolapp.BuildSpec{Kind: "skill", Op: "create"} }
func (*EditSkill) Build() toolapp.BuildSpec   { return toolapp.BuildSpec{Kind: "skill", Op: "edit"} }
