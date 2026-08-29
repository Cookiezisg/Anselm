# EDGE-346 · 音色库存 2 槽上限 · 真实 App 五通道验收

## 结论

`EDGE-346` 的 L2 通过。真实 Flutter macOS App 在真实受管 Anselm 网关上登记两个克隆音色，
再用一个明确要求直接调用工具的请求验证第三个登记被库存闸拒绝。两个成功登记、库存上限、
失败原因、UI 文案、SSE 工具结果、LLM wire 和 SQLite 行互相一致；没有第三次上游登记或媒体上传。

本格只把 L2 判为通过。L3-L5 不由一次库存边界回合冒充顺滑、美学和新用户可发现性覆盖。

## 有效台架

- session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-230853/`
- 隔离数据目录：`/private/tmp/anselm-data-edge346-fixed3-20260827`
- workspace：`ws_a1b3492ac692ea95`，`EDGE-346 voice inventory clean`
- 上游：真实 `https://api.anselm.website`
- 设备：conductor 管理的 Go sidecar、独立三路 SSE witness、LLM tap、真实 Flutter macOS App、
  Computer Use 和连续窗口录屏
- 录屏：`screen.mov`，录制时长 `509.656667s`；`rig-check.sh` 通过，`rig-down.sh` 收台后无残留

## 用户目的与真实路线

1. 在全新 onboarding 后上传同一个 WAV 夹具 `/tmp/anselm-voice-345.wav`。
2. 发送登记第一个音色的请求并完成危险操作确认；App 显示登记成功、受管 provider、库存还剩 1 个。
3. 再次上传同一夹具并登记第二个具名音色；App 显示两个名称、状态和剩余库存为 0。
4. 第三个普通提示先得到“库存已满”的解释，但模型没有发起必然失败的工具调用。这是合理的
   避错行为，不计作库存后端分支已执行。
5. 随后发送明确的直接调用请求：
   `Call enroll_voice directly now with this exact uploaded attachment and name edge346-fixed3-force. Do not search for tools or only explain; I need the actual inventory gate result even if it returns full.`
   该请求只发起一次 `enroll_voice`，后端返回 `voice inventory is full — delete a voice to make room`。
6. App 的工具卡显示明确失败原因，助手正文说明需要先删除一个已注册音色；Composer 在回合收尾后恢复可用。

## 五通道交叉证据

- **画面 / Computer Use**：真实 App 显示两个成功登记结果，第二次登记后显示剩余 0；强制负路径
  显示一张 `enroll_voice · 失败` 工具卡及“删一个已注册的语音才能腾出空间”的可行动解释，
  没有第三个成功音色、重复 mutation 或卡死的停止状态。录屏完整保留。
- **Backend journal**：唯一相关 WARN 是预期的工具失败：
  `tool execute failed ... voice inventory is full — delete a voice to make room`；无 panic、
  fatal、未解释 ERROR。该 WARN 是本格刻意负路径的事实，不隐藏、不改写成成功。
- **SSE**：`sse.jsonl` 共 624 条解析记录，包含 `entities`、`messages`、`notifications` 三流；
  messages durable seq 单调至 68。强制负路径为 seq 60 的 tool call open、seq 61 的参数 close、
  seq 62 的 tool result open、seq 63 的 error close、seq 67 的助手正文 close、seq 68 的
  completed/end_turn close；错误文本与后端、UI 相同。
- **LLM wire**：同一 SHA-256 的音频发生两次独立 staging 上传，随后两次 `/v1/voices` 均为 200，
  lease 分别为 `mls_7dbf8bb54354bbaaff52d292e85d350d` 和
  `mls_4482e973f289e5e437e134ce97923491`。没有第三次媒体上传，也没有第三个 `/v1/voices` 成功请求。
  这同时证明登记绕过已消耗的一次性 lease，且没有把库存失败误判为网关配额失败。
- **DB / REST**：SQLite 只有两条 live voice 行：
  `edge346-fixed3-first`、`edge346-fixed3-second`，provider 均为 `anselm`；UI 的两个名称和
  `capacity=2, remaining=0` 与持久化真相一致。
- **Frontend console**：没有 Flutter、Dart、RenderFlex、Unhandled、Exception 或 ERROR 红线。
  `IMKCFRunLoopWakeUpReliable` 是 macOS 输入法框架的系统级噪声，不是 App runtime 错误，已在日志中
  原样保留。

## Stop-and-fix

- 前置复验发现，使用已消耗的 managed media lease 再登记时会错误复用旧 lease；修复为
  `UploadFresh`，登记每次强制取得一次新 lease，不污染缓存，并补
  `TestMediaClientUploadFresh_DoesNotReuseSpentLease`。
- 前置复验还发现真实网关返回的 Markdown 粗体列表行
  `- **语音 ID**：vce_...` 没有被音色字段脱敏规则覆盖，用户正文出现机器值和“这个输入”。
  修复 `redact.go` 的窄规则，补完整文本和跨 chunk 回归；本次有效 session 未再出现该泄漏。
- 修复后的 focused 测试、`-race` 测试均通过：
  `go test ./internal/app/loop ./internal/infra/llm ./internal/app/tool/generate -count=1`
  和对应 `go test -race` 命令。

## 判定与范围

- L1：保留原有契约证据 `testend/rig/formal-evidence/EDGE-346-voice-inventory-cap-20260826.md`。
- L2：本证据支持通过，法条为 `F1`。
- L3-L5：保持 `na`，不把一次真实边界回合冒充完整顺滑、美学或 discoverability 验收。
- 产品判断：库存上限是音色数量闸，不是费用/配额闸；失败结果必须指出删除一个音色才能继续，
  且失败不得留下第三条 DB 行、第三次上游登记或不可见的半成功状态。
