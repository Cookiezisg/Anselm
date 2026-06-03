# Round 0002 — pkg/tokencount（波次 0 · M0.1 续）

类型 / 目标：迁移 `tokencount` —— 本地启发式 token 估算器 + 自适应校准。

依赖扫描：
- 上游：`unicode`（stdlib）。零上层依赖。
- 下游：`app/contextmgr/estimate.go`（核心，M5.3）+ handler `prompts`/`context_stats`/`conversation`（各自 handler 轮）。
- 考古发现：纯函数叶子，无反向依赖，与「图 vs RAG / 5-node / quadrinity」无关 —— 通用底层工具，不绑任何废弃设计。

旧实现历史包袱：**无**。三个纯函数、单一职责，本就干净。

修改后完整逻辑（给人看的）：
- `Estimate(s) int`：CJK 字 = 1 token，其余按 `runes/4`；空串→0，非空保底→1。
- `Calibrate(actual, estimated) float64`：真实/估算 比例，clamp 到 `[0.5, 3.0]`；非法输入→1.0。
- `MergeCalibration(prev, fresh) float64`：指数平滑 α=0.3（偏稳定）并入历史；首次观测直采。
- 自适应循环：Estimate 粗估 → LLM 真实 usage → Calibrate 得比例 → MergeCalibration 平滑 → 下次更准。`0.5/3.0/α=0.3` 为经验常数，无物理理由动。

删除 / 移出：**无**（零移出，不进 deps-todo）。

契约变更：无对外 API。三函数签名是内部契约（4 下游），迁移时签名不动。

新测试：原样搬（Estimate 空/英≈4字符每token/CJK/混合/保底；Calibrate happy/clamp低/clamp高/非法；Merge 首次/平滑）。

验证：`gofmt -l` 净；`go build -o /dev/null ./...` OK；`go vet` OK；`go test ./internal/pkg/tokencount` 绿。

是否更干净：本就干净 —— **判定为非重灾区，原样保留，不为改而改**（项目原则：只做有物理价值的改动）。这是与 reqctx/idgen/pagination「混杂+反向依赖」的反例。

覆盖状态：tokencount 标 cleaned。

下一步：`pathguard` 考古 → 余 userpath/wikilink/jsonrepair/limits + `modelcaps` 判定 → M0.2 `infra/db`。
