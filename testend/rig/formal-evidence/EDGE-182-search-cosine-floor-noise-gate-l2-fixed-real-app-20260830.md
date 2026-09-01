# EDGE-182 cosineFloor 噪声闸：L2 修复后真实 App 绿场

- 结论：`pass`；本证据替代不了红场，而是记录红场后的实现修复与 fresh session 复验。
- 红场：`testend/rig/formal-evidence/EDGE-182-search-cosine-floor-noise-gate-l2-red-real-app-20260830.md`，session=`/private/tmp/anselm-rig-formal-20260801-7/sessions/20260830-221606`。真实统一搜索曾把自然乱码 `flomptar quendel vaxori` 返回为 3 个不相关实体，最高 raw cosine=`0.721914`。
- 修复：`backend/internal/app/search/semantic.go` 在无词法命中的 semantic-only 路径增加 `semanticMargin=0.03`；仅当 top-1/top-2 过于平坦时拒绝该组高基线候选，不改变 `cosineFloor`、不影响有词法证据的结果，也不以提升阈值掩盖真实召回。
- fresh session：`/private/tmp/anselm-rig-formal-20260801-7/sessions/20260830-222330`，真实 Go sidecar、真实 Flutter App、真实 `EmbeddingGemma-300m`、managed gateway、三路 SSE witness、LLM tap 和 Computer Use 录屏均属于同一 manifest。

## 复验

- 直接对真实 workspace 的 `/api/v1/search?types=document` 查询 `flomptar quendel vaxori`：`total=0`、`hits=[]`，不再返回语义无关文档。
- 真实语义查询 `qualities of a calm reliable interface` 返回 `EDGE182 Semantic Recall Fixture`；不同措辞的 `trustworthy` 被召回，说明修复没有把真实语义召回一刀切掉。
- 真实 App 从新对话执行两条路径：自然乱码路径可见“未找到任何结果”，语义目标路径真实经过 `search_documents`→`read_document` 并展示对应解释。
- backend journal、`sse.jsonl`、`frontend.log`、`llm.jsonl`、`screen.mov` 和收台记录均存在且非空；录屏时长=`209.861667s`，进程组收台后归零。frontend 仅有 macOS IMK 系统噪声，没有 Flutter/Dart/RenderFlex/Unhandled 应用红线。

判定依据：`CODEX F2`。这是同一真实 App session 的五通道交叉证据；旧红场保留，不能被本绿场覆盖或删除。
