# EDGE-230 · 第一轮红证据

第一轮 session=`/private/tmp/anselm-rig-formal-20260831-13-edge230/sessions/20260831-132421` 使用了真实 App、真实 managed gateway 和五通道台架，但第一版 `llmtap` 注入器没有产生 `wav_metadata_injected` 事件。原因是上游真实语音响应的 `data` chunk 使用 `0x7fffff9b` 的未知长度哨兵，注入器在定位 `data` 之前先按声明长度拒绝了它。

该 session 的真实响应头为 `RIFF/WAVE/fmt/data`，但不含本项所需的受控 `LIST/fact` 扰动，因此不写入 EDGE-230 绿格。修复内容为让测试扰动器复用后端 parser 的 EOF 兼容边界，并新增 `TestInjectWAVMetadataAcceptsUnknownLengthDataChunk`；随后在全新 session 重跑并取得 `EDGE-230-parse-wav-chunks-injected-real-app-20260831.md` 的三次注入和最终 PCM 等式。
