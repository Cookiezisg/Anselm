# Round 0067 — D8：工作流节点 input 祖先可见性 lint

类型 / 目标：散落 D8 收尾——把「节点 input CEL 只可引用祖先节点」从运行时坑提前到 create/edit 编译期拦下。

## 现状的洞

`compileGraphCEL` 此前用**全图所有 node id** 作 CEL 根编译每条 `node.Input`。于是：
- 语法错 / 引用根本不存在的名字 → 拦 ✅
- 引用「存在、但非自己祖先」的节点 → **编译能过**，运行时才出问题。

运行时 `scopeFor`（walk.go）把**所有 completed 节点**的结果塞进 scope（不限祖先），故引用并行分支节点能不能读到**全靠批次顺序碰运气**——非确定、破坏重放确定性。D8 把这类拦在编写期。

## 解法（绕开原 TODO 的拦路石）

原 TODO 以为要「从 CEL AST 抽出引用了哪些 node id 再查祖先」，需 `cel.ReferencedRoots`，`pkg/cel` 没暴露 → 推迟。

**换角度绕开**：给每个节点用「**恰为其祖先 node id**（+ `NewScopedEnv` 恒加的 `ctx`）」作根的 env 编译它的 input。引用非祖先 → 那名字未声明 → **编译当场失败**。无需 AST、无需 pkg/cel 改动。

## 祖先定义（对齐运行时）

`workflowdomain.Ancestors(g, nodeID)`：沿全图边（含**回边**）反向 BFS、sorted。
- **含回边** → 循环内可携带引用（B 读上一轮 C）、环上节点可引用自己上一轮——对齐 `scopeFor`「循环内取当前轮 ≤ iter 最大、循环外取固定 result」。
- 同 `BackEdges`，是导出纯函数（一个「祖先」定义供任何后续消费者）。跳过缺端点边（ValidateGraph 另报），未校验图安全。

## 形状

- **domain**（graph.go）：`Ancestors(g, nodeID) []string`（反向 BFS + sort）。
- **app**（crud.go `compileGraphCEL`）：两段编译——先全图 env（区分「名字不存在」=`invalid CEL`），后祖先 env（抓「非祖先」=`references a non-ancestor node`，错误列出可见祖先供 LLM 自纠）。去 buildGraph TODO。
- **测试**：`TestAncestors`（linear / diamond-siblings-互不可见 / loop-carried+self）+ `TestCreate_NonAncestorRefRejected`（并行兄弟 a 读 b 被拒）+ `TestCreate_AncestorRefAccepted`（菱形 join 读双祖先过）+ 更新 `NonNodeRefRejected` 注释。

## 分期

| 期 | 内容 | 状态 |
|---|---|---|
| 实现 | domain Ancestors + compileGraphCEL 祖先 scoped 两段编译 + 去 TODO | ✅ `f1d6dec9` |
| 测试 | Ancestors（3 形状）+ Create 非祖先拒/菱形过 | ✅ `f1d6dec9` |
| 文档 | workflow.md §3.1/§5/§12 as-built + contract #51 + STATE/ROUNDS/order(D8✅) | ✅ 本提交 |

## 不做（明确）
- **不改运行时**：scheduler 的 `celScopedEnv`（全图 node id）保持——lint 已保证 input 只引用祖先，运行时的全 completed scope 是不会被错用的超集，无需收紧、不碰热路径。
- **不动 pkg/cel**：per-node 祖先 env 编译绕开了 `cel.ReferencedRoots` AST 需求。
- 无 API/schema/wire 变更。零历史包袱（项目未上线、无存量坏图，下次 edit 会重校全图）。

**R0067 全完成 = 散落 D 在 v1 范围内的最后一块清掉**（剩 D4 明确 v2、D5–D7 低优先；接下来是覆盖回 backend + 前端联调）。
