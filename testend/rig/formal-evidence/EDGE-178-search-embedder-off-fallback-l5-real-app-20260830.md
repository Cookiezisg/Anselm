# EDGE-178 · 搜索 embedder 缺席降级 · L5 真实 App 可发现性证据

## 结论

`pass`，依据 CODEX `G1`。这里的产品能力是“用户在 Chat 中提出检索目标，系统透明地完成
检索并诚实回答”，不是要求用户发现或理解内部 `embedder` 开关。当前 Settings 没有该内部
设置面板，因此本证据不把内部实现开关的可见性冒充成产品功能。

## 从零用户路径

- Formal session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-205857`
- 新 workspace: `ws_8e2b400de75043d1`
- App 通过真实 onboarding 创建 workspace 后直接落在空白 Chat；没有预置对话、搜索教程或
  手工打开搜索设置。
- 首次用户目标是自然语言：

  ```text
  Find the document containing EDGE178LEXICALFALLBACK and explain whether semantic search is unavailable but lexical search still works.
  ```

- 用户只需要使用主 Chat composer；模型自行选择 `search_documents`，找到唯一 fixture 后再用
  `read_document` 读取正文。用户没有被要求知道 BM25、embedder、reindex 或 REST API。
- 最终回答没有把精确词法命中夸大为“语义搜索已关闭”，而是明确说 lexical path 已被确认，
  semantic 状态仅凭这次命中不能确定，并解释需要怎样的非词法重叠查询才能隔离语义路径。
  这让用户既达成“找出文档”的目标，也得到不会误导后续决策的边界。

## 五通道交叉证据

- **frames / Computer Use**: 录屏从 onboarding 后的空 Chat、首次自然目标、工具链到最终可读
  回答连续覆盖；Composer 是唯一用户入口，最终页面没有引导死路或内部诊断泄漏。
- **REST/DB**: fixture 的唯一搜索命中、文档正文和 tags 与 App 最终回答相符；无手工改库或
  预填对话替代用户路径。
- **SSE**: messages durable seq=`1..33`、notifications `1..3` 单调，无 gap；entities 流
  生命周期完整，用户目标对应的工具链可追溯。
- **Backend / frontend**: backend journal `271` 行、frontend journal `5` 行；无应用级 panic、
  Flutter/Dart、RenderFlex、RenderBox、Unhandled 或 exception 红线。
- **LLM wire**: `llmtap` `28` 条，managed challenge/install/models 与四次 streamed completion
  均为 HTTP `200`；模型的工具选择和最终回答不是 UI 猜测。

## Judgment boundary

- **L5 `pass (G1)`**：新 workspace 的首次 Chat 用户无需文档、设置入口或内部术语即可提出
  检索目标并获得正确、可解释的 lexical fallback 结果；产品不把内部引擎状态伪装成已知事实。
- 不宣称 Settings 中存在 search/embedder 控件；本格验证的是自动能力的可发现性和用户目的达成，
  不是内部配置的可见性。L2-L4 的数据、动态和 craft 证据分别保留，不被本格覆盖。
