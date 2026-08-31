# EDGE-249 · 后台裸 ctx 播种缺失适用性复核

## L1

- `backend/internal/bootstrap/background_ctx_test.go:TestBackgroundPaths_RequireWorkspaceSeeding` 以 race 模式通过。
- 测试同时证明两半：裸 `context.Background()` 访问 workspace-scoped store 会失败，`reqctx.Detached("ws_1")` 能读到同一 workspace 的种入行。
- 该边界的代码路径使用逐 workspace 的 `Detached` context；不以测试中的裸 context 作为生产路径。

## L2-L5 适用性裁决

本格是后台接线不变量，不是一个独立的用户功能入口。它没有自己的用户操作、独立状态转移、视觉组件或发现入口：

- L2 不适用。后台 context 的身份播种由 owning journey（scheduler、trigger、boot 或 workspace 生命周期）承载；本格没有可独立启动的 App 操作或五通道场景。
- L3 不适用。context 缺失是内部接线错误，不拥有独立等待、进度或动效；所属后台功能的时延由其自身旅程验收。
- L4 不适用。本格不产生独立 UI、错误卡片或几何/色彩表面；用户可见的错误呈现归属实际触发该后台功能的 surface。
- L5 不适用。用户不能从产品入口直接发现或触发“播种 workspace context”；可发现性属于 owning journey 的入口和恢复路径。

这些是适用性结论，不是“本轮未测试”的临时豁免；任何拥有独立用户表面的后台功能仍必须按自己的 COVERAGE 行完成 L2-L5。

## 警报复核

本次四条 NA 写账后，警报脚本按原阈值打开 `pass-burst` 与 `discovery-collapse`。复核结论如下：

- `pass-burst` 只反映裁决写入间隔短，未改变任何法条、阈值或顺序门；本次没有把它当作产品质量证据。
- `discovery-collapse` 的 fail-share 统计包含本次适用性裁决，但本格仍保留 L1 的真实回归事实，且 L2-L5 的不适用理由逐项可审计；没有因警报而把缺失的用户场景改写为通过。
- 两条警报均按原机制独立复核并销账，后续新裁决前仍由 `alarms.py check` 重新检查。
