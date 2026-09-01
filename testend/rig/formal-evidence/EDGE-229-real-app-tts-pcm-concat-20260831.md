# EDGE-229 多块 TTS PCM 拼接：真实 App 五级验收

## 结论

`EDGE-229` 在真实 macOS App、真实受管 Anselm gateway 和五通道台架上通过 L2-L5。
本格验证的是：用户提出一个超过单次 provider 上限的长语音请求时，产品仍完成一次用户目的，
上游被拆为多块调用，服务端在 PCM 层重接，最后只落一个可播放的 WAV 附件；用户不需要知道
provider 上限、分块或 PCM 细节。

## 正式 sessions

- 显式工具指令交叉场景：`/private/tmp/anselm-rig-formal-20260831-12-edge229/sessions/20260831-130336`
- 主要自然语言场景：`/private/tmp/anselm-rig-formal-20260831-12-edge229b/sessions/20260831-130955`
- 主账本归档身份：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-130955-edge229-natural`
- 两次均为 conductor 启动的 Go sidecar、三路 SSE witness、managed LLM tap、真实 Flutter App、
  窗口录屏；两次 `rig-check` 和 `rig-down` 均通过，收台无残留 Anselm/tap/recorder 进程。

主要判定使用自然语言场景：用户只说“请把下面完整段落做成可播放音频，不要总结或省略”，
没有写出 `generate_speech` 工具名。App 真实选择该能力并返回“single playable audio file”，
覆盖全部 10 个部分，最终显示 WAV 附件可播放。

## 五通道交叉证据

- **LLM wire**：自然语言场景的受管握手 `challenge/install/models` 均为 `200`；同一工具调用产生
  5 次 `POST /v1/audio/speech`，每次返回 `200`。请求字符分块为 `480` 上限内的 5 块，响应原始
  WAV 字节分别为 `1,553,804`、`1,357,964`、`1,254,284`、`1,231,244`、`1,116,044`。
  显式工具场景同样产生 5 次 `200` 语音调用，证明不是单次短文本路径偶然通过。
- **PCM / DB**：自然语言场景的最终附件为 `att_fb8b5acac2b9e772`，`audio/wav`，`6,513,164`
  bytes，`24kHz/16bit/mono`，时长 `135.69s`。最终 WAV 的 data 区为 `6,513,120` bytes，正好等于
  五个原始响应实际 PCM payload（各响应去掉 44-byte WAV 头）的总和；最终文件只有一个 `RIFF`
  和一个 `WAVE` 标记，chunk 表只有 `fmt ` 与 `data`，没有中间 stranded header。
- **SSE / durable**：messages 流只记录一个 `generate_speech` tool call、一个 tool result 和一个
  completed assistant close；tool result 的 `characters=1860`、`durationMs=135690`、attachment
  ID、文件名、大小与 REST/SQLite 一致。三路流均连接且 durable seq 单调。
- **Frame / Computer Use**：录屏为 H.264、`3104x1844`、`60fps`、`186.296667s`。loading 帧显示
  `Synthesizing speech…`、已耗时计时和 Stop 控件；完成帧显示单个音频卡、`WAV`、`2:16` 和播放
  入口。关键帧=`sessions/20260831-130955-edge229-natural/evidence/edge229-natural-synthesizing.png`
  与 `edge229-natural-final.png`。
- **Backend / frontend**：backend journal 无应用级 `ERROR`、`FATAL`、panic；frontend journal 无
  `DartError`、`FlutterError`、`RenderFlex`、`Unhandled` 或应用级异常，仅保留已知 macOS IMK
  平台诊断。`rig-check` 五通道归属通过。

## 产品级判定

- **L2 `F2` pass**：真实 App、真实 managed gateway、SSE、backend、frontend、LLM wire、录屏和
  durable attachment 属于同一 manifest，五块输入与单一输出交叉相符。
- **L3 `A4` pass**：这是超过 10 秒的操作，App 在合成期间持续显示明确的 `Synthesizing speech…`
  与耗时，并保留 Stop generating；没有假装静止或让用户误以为输入丢失。完成后在同一线程
  继续显示结果，未阻塞为错误终态。
- **L4 `C4` pass**：最终音频使用既有附件卡语言，标题、类型、大小、时长和播放控件层级稳定；
  关键帧无 clipping、重叠、孤儿 RIFF 片段或内部 provider 字段。合成中的工具行与完成后的
  收据行也保持同一紧凑几何。
- **L5 `G1` pass**：自然语言请求不包含内部工具名或 API 术语，用户只表达“做成可播放音频”就
  到达正确能力；App 返回覆盖完整内容的可播放 WAV，并说明结果已附加，不要求用户阅读内部
  文档或先寻找设置开关。

L1 focused PCM/WAV 回归继续由 `EDGE-229-tts-pcm-concat-20260826.md` 提供；本次真实证据不
冒充 provider 音质主观评价，只证明产品链路、字节结构、状态反馈、视觉结果和自然入口。
