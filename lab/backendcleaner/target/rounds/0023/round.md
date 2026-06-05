# Round 0023 — mention（波次 1 · M1.6）@ 引用快照契约

类型 / 目标：M1.6 mention 模块新建——@ 引用快照的 domain 契约。迄今最薄模块（纯 domain，无 app/store/handler）。

## 核心方针（一句话）
**mention 是纯 domain 契约：5 种可 @ 类型 + Resolver 接口；发送即冻结快照，解析/渲染下放各域 resolver(波次 3) + chat(波次 5)。**

## 关键设计决策（经讨论拍板）
1. **纯 domain 契约**：mention 只定义 `MentionType`(5) + `MentionInput` + `Reference` + `Resolver` 接口。无 app/store/handler/error——逻辑全在消费方。
2. **可 @ 5 种**：document/function/handler/workflow/agent（四件套 + 知识文档，有可注入内容快照）。conversation/skill/mcp 不可 @（无单一快照 / 是调用非引用）。
3. **Freeze-on-Send**：发送瞬间抓内容快照注入、定格不变（非动态引用）。
4. **错误归 chat**：domain 无 error；resolver 未注册/input 非法/解析失败由 chat 处理。加 `IsValidMentionType` 给 chat 校验用。

## 考古发现（旧文档历史错误）
- §3/§4「Relation 记 `message_mentions_entity` 边 / 建活跃度热力图」——relation 现仅 4 动词、无 mentions 边，**纯虚构**。
- §2.2「差异化渲染」（各类型不同标签）——代码实为**统一** `<mention>` 标签 + snapshot 标记。
- §1.1 漏 agent；§1.2 Reference 缺 Content；§5 列 3 error 但 domain 根本无 error。

## 新实现
- **domain/mention**：`MentionType`(5) + `IsValidMentionType` + `MentionInput{Type,ID}` + `Reference{Type,ID,Name,Content}` + `Resolver{Type,Resolve}`。**仅此一个文件**。

## 测试
domain 1：`IsValidMentionType`（5 白名单 + conversation/skill/mcp/空/大小写 拒）。

## 验证
`gofmt -l` 干净 · `go build ./...` 0 · `go vet ./...` 0 · `go test ./... -race` 全 ok。

## 契约（无对外端点/表/错误）
domains/mention.md 整篇重写（删虚构 relation 边/活跃度、改差异化渲染→统一标签、补 agent+Content）；api/database/error-codes **均不涉及**（mention 无端点/表/独立 error）。

## 是否更干净
旧：文档虚构 relation 依赖 + 差异化渲染 + 漏 agent/Content + 列不存在的 error。
新：纯契约一个文件、5 种封闭集、Freeze-on-Send 明确、错误归 chat、文档据实。✅

## 遗留 / 下一步
- **M1.7 memory**（波次 1 续）。
- 5 个实体域 `AsMentionResolver()` 实现 → 波次 3；chat 注册表 + `<mentions>` 渲染 + mention 错误处理 + `Reference` 存 `messages.attrs` → 波次 5。（见 deps-todo）
