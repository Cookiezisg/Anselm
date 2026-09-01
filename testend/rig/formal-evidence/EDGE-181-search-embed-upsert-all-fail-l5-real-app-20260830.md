# EDGE-181 整批 embed upsert 全失败：L5 真实 App 可发现性

- 结论：`pass`。
- 正式路径：`/private/tmp/anselm-rig-formal-20260801-7/sessions/20260830-220606`。

从用户视角，这不是一个需要寻找“embedder 状态”或理解 SQLite 的维护任务。用户继续在真实 App 中使用搜索目标即可得到 `EDGE181` 文档和高亮结果；后台向量回填写失败没有把正常检索入口藏起来、没有要求用户重启、删除索引或打开终端，也没有把内部失败术语推给用户。

该路径证明的是“能力部分受损时，核心用户目的仍可发现并完成”的产品行为。后台 worker 会在后续独立 kick 重试，用户无需知道 retry 机制；真实 REST、backend、SSE、LLM tap 和 Computer Use 画面属于同一 manifest，互相没有矛盾。

判定依据：`CODEX G1`。
