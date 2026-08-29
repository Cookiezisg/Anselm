# EDGE-345 · 音色登记→指名说话全链 · 真实 App 五通道验收

## 结论

`EDGE-345` 的 L2 通过。真实 Flutter macOS App 在受管 Anselm 网关上完成了同一个用户目的：上传音频、登记为具名克隆音色、再用该音色朗读指定文本。首次复验发现 assistant prose 把脱敏后的 `voiceId` 残留为 `voiceId: 这个输入`，该事实不计绿；修复后用新二进制和新隔离数据目录重跑，最终正文自然、无机器字段或占位词。

## 有效台架

- 有效 session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-222501/`
- 环境：conductor 启动的 Go sidecar、真实 `https://api.anselm.website`、独立三路 SSE witness、LLM tap、Flutter macOS Debug App、窗口录屏。
- 数据：隔离 workspace `ws_1c75acaacbfca89b` 的副本数据；音频夹具为 `/private/tmp/anselm-voice-345.wav`，WAV 190.7 KB。
- `rig-check.sh`：五通道通过；收台后使用 `rig-down.sh`，日志与录屏保留。

## 用户目的与画面

1. Computer Use 在真实 App 中进入新对话，选择 `anselm-auto · Anselm Free`，上传 `anselm-voice-345.wav`。
2. 用户发送：`Please register this uploaded audio as a cloned voice named acceptance-narrator-fix then read exactly: The acceptance chain is working.`
3. App 先显示 `enroll_voice` 的危险确认；点击“允许”后，登记完成，随后自动调用 `generate_speech`。
4. 最终用户正文显示：
   - `声音注册成功 — 上传的音频已注册为名为 acceptance-narrator-fix 的克隆声音。`
   - `语音生成成功 — 使用该声音朗读了指定文本 "The acceptance chain is working."，生成了约 2 秒的音频。`
   没有 `voiceId`、真实 `vce_...`、`the requested item` 或 `这个输入`。
5. 设置页“模型与密钥 → 克隆音色”显示 `acceptance-narrator-fix`，并显示 `还能留 1 个(共 2)`；聊天中的上传音频保留“播放音频”入口，生成结果显示为已存储音频附件。

## 五通道交叉证据

- **LLM wire**：真实受管上游的 `POST /v1/voices` 返回 200，`POST /v1/audio/speech` 返回 200、96044 bytes；上传 staging 的创建、写入、complete 也分别成功。最终 `generate_speech` 参数为 `{"text":"The acceptance chain is working.","voice":"acceptance-narrator-fix"}`。
- **SSE**：messages durable seq `1..31` 连续；有效链路包含 `enroll_voice` tool call/result（seq `17..20`）、`generate_speech` tool call/result（seq `23..26`）和最终 text close（seq `30`）。tool result 精确包含本次附件、`vce_390d9c9806c21f83` 和生成附件 `att_2bcbcb1427f438a7`；assistant prose 未携带这些机器值。
- **DB/REST**：`GET /api/v1/voices` 返回 `acceptance-narrator-fix`、本地 voice id `vce_390d9c9806c21f83`、上游 voice id、源附件 `att_18588e2158c93d66`、capacity `2`、remaining `1`；工具结果与设置页一致。
- **Backend**：有效 session 无 `WARN`、`ERROR`、panic 或 fatal；只读 `/voices` 请求均为 200。
- **Frontend/Computer Use**：`frontend.log` 仅有正常 Dart VM service 行，无 Flutter、Dart、RenderFlex、Unhandled、Exception 或 ERROR；AX 树确认成功正文、两张工具卡、音色设置项和 Composer 可用。
- **录屏**：有效 session 的 `screen.mov` 由窗口录制器持有；全程没有外部窗口覆盖 Anselm 录制区域。

## Stop-and-fix

- 红事实：前置真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-221530/` 的最终正文出现 `voiceId: 这个输入`；它与既有 chat 脱敏法条冲突，不计绿。
- 修复：`backend/internal/app/loop/redact.go` 增加 `voiceId` parenthetical 的窄规则，完整文本和跨 chunk 流式出口均移除整段机器字段括号，只保留人话音色名；`redact_test.go` 增加直接与分片回归；`docs/references/backend/domains/chat.md` 同步契约。
- 修复后二进制的 `go test -count=1 ./internal/app/loop` 通过，真实 App 新 session 复验通过。

## 判定

- L1：原 focused 契约证据 `testend/rig/formal-evidence/EDGE-345-voice-enroll-to-speak-20260826.md` 保留。
- L2：本证据支持通过；五通道、设置页可发现性、上传附件、登记、指名合成和最终正文均交叉一致。
- L3-L5：本格不以一次成功回合冒充完整顺滑、美学和新用户可发现性覆盖；本轮仅记录设置页可发现性观察，剩余等级按 COVERAGE 继续单独取证。
