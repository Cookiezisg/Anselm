# EDGE-222 生成 origin 从凭证派生：真实 App L2

- 日期：2026-08-30
- 判定：L2 `pass`；L3-L5 保持未收口
- 法条：`F4`
- session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-052929`
- 关键帧：`evidence/EDGE-222-result.jpeg`、`evidence/EDGE-222-viewer.jpeg`

## 产品结果

在真实 Anselm App 中，用自然语言目标请求只调用一次 `generate_image`，目标是白底红圆。
真实结果在对话中出现 `Generated image` / `Saved as attachment`，随后模型只回复一条短句；
点击结果卡后能打开预览，再进入全尺寸查看器。录像中的结果帧显示白底单个红圆，未出现空卡、
错误卡或第二次生成调用，用户目标实际完成。

同一 session 中，Computer Use 的输入桥接把工具名中的下划线显示为缺失，但模型仍依据自然语言
目标调用了正确的 `generate_image`；App、SSE 和 wire 中的有效工具名一致。该桥接现象不在本格
归因成 Anselm 产品缺陷，也不掩盖它，后续若需评估输入桥本身应单独建格。

## 五通道交叉证据

1. **帧**：`screen.mov` 已封口，时长 `122.823333s`，编码 `h264`，`3104x1844`，`60fps`。
   结果卡和全尺寸查看器均在同一 Anselm 窗口录制；抽出的两帧保留在 session 的 `evidence/`。
2. **后端**：`backend.log` 为 conductor 亲启的 PID `20482`，D1 归属通过；未发现
   `panic|fatal|FlutterError|DartError|RenderFlex|Unhandled` 等应用级红线。
3. **SSE**：`sse.jsonl` 记录三条流连接。messages durable seq `1..14` 连续，其中
   seq `6/7` 为 `generate_image` tool call，seq `8/9` 为成功 tool result，seq `12/13`
   为最终文本，seq `14` 为 `status=completed, stopReason=end_turn`。
4. **前端**：`frontend.log` 未出现 Flutter/Dart/layout/unhandled 错误；仅有 macOS IMK/TSM
   宿主诊断行，未在静置期增长。
5. **LLM 线缆**：`llmtap.log` 明确为 `127.0.0.1:8788 → https://api.anselm.website`。
   `llm.jsonl` 记录一次 `POST /v1/images/generations`，请求体为 `1024x1024`，响应 `200`；
   随后媒体上传完成，`POST .../complete` 返回 `201`，再回到 chat completion。生成响应的
   receipt 与 SSE seq `9` 的 `attachmentId=att_303b4eca52a18ffb`、尺寸和文件名一致。

## 未声称的等级

本次没有把稳定态截图当作独立时延/动效测量，也没有从零用户发现能力入口。因此 L3 的顺滑、
L4 的完整 craft 复核、L5 的 discoverability 仍未收口；本证据只证明真实 App 的五通道事实
一致性和用户目标完成。
