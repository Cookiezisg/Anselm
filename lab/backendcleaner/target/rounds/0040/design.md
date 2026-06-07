# R0040 design — skill 重写（文件式指令载体，对齐 memory 范式）

> 调研见同目录 `survey.md`（deep-research 104 agent）。本文是用户拍板后的最终设计。

## 定位（一句话）
skill 是**指令载体**，本性是 **memory 的近亲**（文件式注入物），**不是 function 的近亲**（执行实体）。所以纯文件式、零 DB 表、零 LLM 依赖。

## 用户拍板（2026-06-07）
1. **砍 execution 审计**（整张 `skill_executions` 表 + store + `search/get_execution` 工具）——skill 的「激活」非真执行（inline=文本替换 / fork=委托 subagent），记它是校验剧场。
2. **砍 search**（LLM rerank + 整个 model/apikey/llm/llmparse 依赖）——skill 已在 catalog 概览全量曝光，再加检索冗余。
3. **砍常驻轮询/缓存/fingerprint** → **纯按需扫描**（catalog source 触发 / HTTP List 时现扫，无 goroutine、无缓存）。
4. **无版本**（文件式，编辑即覆盖；对不齐 function 的方案 A，本质如此，Anthropic skill 也无版本）。
5. allowed-tools = **预授权**（免 danger 确认）非限制白名单；存 `activeSkill`，消费留 ask 波次 6。
6. **AI 可创建**（create/edit/delete 工具，`source=ai` 区分人工）。
7. **disable-model-invocation 实装**（发现层过滤，标了的不进 LLM 概览、只人工触发）。
8. 不加 `` !`cmd` `` shell 注入（占位替换 `$ARGUMENTS`/`$1`/`${CLAUDE_*}` 已是更安全子集）。

## 与 function 的 3 处本质不对称（不强行对齐）
1. **版本/revert**：无（文件式）。
2. **mention**：不可 @（mention domain 5 种不含 skill）。
3. **存储**：纯文件（零 DB 表、零 LLM）。

## relation id 决策
skill 文件式无生成 id → **name(slug) 作 relation 节点 id**（对齐「name 即身份」）。R0021 预留的 `sk_` 前缀对文件式 skill 不启用（skill 不被 wikilink 引用，`KindForID` 的 `sk_` 反查对 skill 无消费点）；登记 deps-todo。

## fork 的 SubagentRunner 端口（自包含，不依赖未来类型）
```go
type SubagentRunner interface {
    Spawn(ctx context.Context, agentType, prompt string) (result string, err error)
}
```
subagent 在波次 5 实现并注入；nil → fork 返 `ErrSubagentUnavailable`（inline 完整可用）。

## 文件清单
- `domain/skill/skill.go`：Skill + Frontmatter(Anthropic 全字段镜像) + 6 errorsdomain + Repository + SubagentRunner 端口
- `infra/fs/skill/{skill,frontmatter}.go`：目录式 SKILL.md 文件 store（yaml.v3 解析、原子写、workspace 分桶、slug 防穿越）
- `app/skill/{skill,activate,mutate,catalog_source,relations}.go`
- `app/tool/skill/{skill,activate,crud}.go`：5 工具
- `transport/.../handlers/skill.go`：REST CRUD + `:activate`
- `pkg/agentstate`：+activeSkill 字段 + SetActiveSkill + IsToolPreApprovedBySkill

## 工具组（5，无 search/execution）
`activate_skill`（核心）· `get_skill` · `create_skill` · `edit_skill` · `delete_skill`

## 数据流
- 发现：catalog source 现扫 → 概览注入系统提示（disable-model-invocation 跳过）
- 激活 inline：读 SKILL.md → 占位替换 → 设 activeSkill → 返回正文进对话
- 激活 fork：→ SubagentRunner.Spawn（端口留空 nil 降级）
- 管理：create/edit/delete 写文件 → 发 notification → 下次 List 现扫发现
