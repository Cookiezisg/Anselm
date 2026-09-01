# EDGE-230 · ParseWAV 遍历 chunk 表：真实 App + 受控元数据扰动

日期：2026-08-31
正式 session：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-132910-edge230`
源 session：`/private/tmp/anselm-rig-formal-20260831-13-edge230b/sessions/20260831-132910`

## 目的

验证真实 App 的多块朗读链路在每个上游 WAV 响应夹带 `LIST`/`fact` 元数据时，后端不会把元数据当成 PCM 样本，最终仍产生一个可播放的单一 WAV。上游为真实 `https://api.anselm.website`；`llmtap` 的 `-inject-wav-metadata` 只在本 session 打开，是本地受控扰动，不是上游行为声明。

## 五通道证据

- **帧 / App**：真实 App 完成 onboarding 后，使用自然语言任务“make a playable audio version of the complete passage”，未在用户文本中指定工具名。处理中帧=`evidence/edge230-synthesizing.png`，终态帧=`evidence/edge230-final.png`；终态显示单一 `Synthesized speech` 音频附件、约 `65 seconds`，composer 已恢复可用。
- **后端**：`backend.log` 记录同一 conversation 的 `POST /api/v1/conversations/.../messages=202`，随后正常完成；无 `panic`、`ERROR`、`WARN`。
- **SSE**：`sse.jsonl` 由独立 ssetap 连接 `messages`、`entities`、`notifications` 三条流；messages durable seq=`1..14`，包含 user open/close、assistant open/close、tool/reasoning/text close；最终 message close 为 `completed`。
- **前端**：`frontend.log` 无 Dart/Flutter/Layout 应用级错误；唯一 `IMKCFRunLoopWakeUpReliable` 为 macOS 输入法诊断噪声，未伴随 Flutter/Dart/RenderFlex 异常。录屏为 H.264 `3104x1844 / 60fps / 204.156667s`，已由 `rig-down.sh` 封口。
- **LLM 线缆**：`llm.jsonl` 的同一 session 记录真实 managed `/v1/chat/completions=200`、3 次真实 `/v1/audio/speech=200`，并记录 3 条 `event=wav_metadata_injected`，每条 `size=24`。注入后的三个响应文件均为 `RIFF/WAVE`，chunk 顺序为 `fmt / LIST / fact / data`。

## 字节测量

三个被扰动响应的实际 PCM 区分别为 `1,350,240`、`1,384,800`、`414,720` bytes，合计 `3,149,760` bytes。真实 App/后端落盘的最终 blob 为：

`/private/tmp/anselm-data-edge230b-20260831/workspaces/ws_c721643cb4c9de8b/blobs/0d/0de9a4dc4932dd52a2933748fc0689faf530726a086c63749e9b55ecd7a495bd`

最终文件大小 `3,149,804` bytes，`RIFF` size=`3,149,796`，`data` 区=`3,149,760` bytes；`RIFF` 出现 1 次、`data` chunk 出现 1 次、`LIST/fact` 出现 0 次。最终 PCM 与三个真实响应的 PCM 总和完全相等，证明 `ParseWAV` 遍历并丢弃了元数据 chunk，同时 `ConcatAudio` 没有把中间 RIFF 头或元数据带进最终音频。

真实网关响应使用了超大 `data` 长度哨兵并以 HTTP EOF 结束；这也是本项必须覆盖的真实边界。后端 parser 按实际可覆盖范围读取，最终产物可播放且时长约 `65s`，与 App 文案一致。

## 判定

- L2：真实 App、真实 managed gateway、独立三流 SSE、backend、frontend、LLM wire 和最终字节测量均属于同一封存 session；按 `measure:edge230-parse-wav-chunks` 判通过。
- L3-L5：该项是内部 WAV chunk 解析不变量；用户可见的朗读等待、终态卡片、格式/时长和可播放性已由 `EDGE-229` 的独立 L3-L5 验收覆盖，本项不存在可独立归属的顺滑、视觉 craft 或 discoverability 表面，按适用性说明记 `na`，不是缺证据 waiver。

## 失败与修复轨迹

前一 session=`/private/tmp/anselm-rig-formal-20260831-13-edge230/sessions/20260831-132421` 的第一版注入器把真实 `data` 长度哨兵误判为截断，因此没有产生注入事件；该 session 不计入产品格。修复为先识别 `data` chunk、保留 EOF 语义后，新增未知长度边界单测并以全新 session 重跑；修复后的注入事件和最终 PCM 等式如上。
