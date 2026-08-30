# EDGE-192 ledger/alarm re-audit · real App L2 · 2026-08-31

- `EDGE|不认的 mime 抽取 L2` 使用独立真实 session=`/private/tmp/anselm-rig-formal-20260801-7/sessions/20260831-014702`，不是沿用 EDGE-191 的附件抽取事实。
- 真实 `.odt` 上传走到 unsupported MIME 分支；App 显示明确的替代说明，没有 `inspect_media` 实际工具调用，原始 fixture sentinel 未进入 LLM wire；backend、SSE、managed gateway、frontend console 和录屏均属于同一 conductor session，`rig-check`/`rig-down` 已通过。
- 本轮承接并保留 stop-and-fix：前次真实画面把普通文案 `LibreOffice` 误判为 `EOF`，修复为 token-boundary 检查并由前端回归测试锁定；修复后画面没有错误 handoff 卡，未用“最终回答正确”掩盖原缺陷。
- `gap-too-fast` 与 `discovery-collapse` 的打开只来自连续写入一个真实 L2 判断，复审未降低阈值、删除历史 fail、修改报警算法、CODEX、anchors、五级标准或顺序 gate。
- 后续 L3 仍使用同一真实 session 的独立等待证据：assistant-open 到 thought=`6.09s`、完成=`9.96s`，录屏明确显示进行态；L3 按 `A4` 判定，不把完成时间冒充 A1。该层证据与 L2 的数据真相分开保存。
- L4 使用稳定尾帧 `/private/tmp/edge192-fixed-final.png` 单独复审附件 chip、层级、列表缩进、文案换行和 Composer 收尾，按 `C4` 判定；没有把 L2 的原始字节不出线或 L3 的等待时间重复当成视觉证据。
- L5 使用同一真实 App 的普通 Chat→附件入口→原生文件选择器→unsupported MIME 结果路径单独复审，按 `G1` 判定；用户只接触人类可理解的格式限制和替代动作，不需要知道 extractor、MIME 或 `inspect_media`。

处置：按原机制 ack 当前打开的 alarm；后续判断从新的 evidence watermark 继续。
