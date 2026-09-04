# EDGE-226 | 受管档视频路由：真实 App 证据

## 判定

- L2 `pass`，法条 `F4`
- L3 `pass`，法条 `A4`
- L4 `pass`，法条 `C4`
- L5 `pass`，法条 `G1`

L1 focused 路由证据仍由既有 `EDGE-226-managed-video-route-20260826.md` 承载；本证据补齐
真实 App 与真实受管网关现场。

## 真实场景

- session：`/private/tmp/anselm-rig-formal-20260905-edge236d/sessions/20260905-055901`
- 真实 App、sidecar、三路 SSE witness、LLM tap 和 conductor-owned recorder 均属于同一 session
- 只有受管 `anselm` key；真实 gateway：`https://api.anselm.website`
- 真实用户回合在危险确认后调用一次 `generate_video`，上游返回真实 `video/mp4` 附件

本 session 的 LLM wire 记录 challenge/install/models 全部成功；模型的 30 秒意图经 Anselm 的
受管路由发出实际 15 秒 submit，随后通过受管 opaque handle 轮询并下载真实产物。tool-result
包含真实 `attachmentId`、`mime:video/mp4`、`provider:anselm`、`seconds:15` 和
`sizeBytes:10062772`，不是本地生成或伪造 receipt。

## 用户可见结果与五通道

Computer Use 最终画面显示真实视频卡片 `Saved as a video attachment · 15s`，正文同步说明
实际 15 秒；生成期间 Composer 可用，中心持续显示 `running…` 与 elapsed，结束后回到可继续
输入的稳定态。没有能力缺席误报、假成功、裸上游 payload 或残留 generating。

- **Channel 1**：`497.560000s` 真实 App 录屏封口，`rig-check` 确认无外部窗口遮挡。
- **Channel 2**：backend 记录受管视频提交、轮询、下载和附件收口，无应用级 panic/FATAL/未解释错误。
- **Channel 3**：messages durable close 序列覆盖 tool call、长进度、tool-result 和 assistant close，单调且与 REST/UI 一致。
- **Channel 4**：frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception 应用红线，唯一 IMK 为已分类宿主诊断。
- **Channel 5**：LLM tap 记录真实 managed proof/install/models 与视频请求，受管 key 是唯一可用路由；提交、轮询、下载响应均真实通过。

## 五级结论

- **L2 / F4**：受管凭证、模型调用、Anselm 路由、真实上游产物、SSE、REST、SQLite 和 UI 对同一视频任务一致。
- **L3 / A4**：长任务持续提供 running/elapsed 反馈，结束后产物和附件状态稳定收口。
- **L4 / C4**：视频卡、正文、Composer 和状态变化保持既有几何、圆角、层级、对齐和留白，无跳变或遮挡。
- **L5 / G1**：用户能从 Chat 的自然语言回合和可见视频卡找到受管生成入口、理解结果并继续操作，无需阅读网关协议。

任务完成后已执行 `rig-check`/`rig-down`，owned processes/listeners 收台归零。
