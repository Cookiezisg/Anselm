# EDGE-296 · 账本警报独立复审 · 2026-09-05

## 警报

`alarms.py check` 在 EDGE-296 的 L3 写入后打开 `pass-burst`：最近 10 条裁决的
时间跨度相对历史尾窗基线达到暴冲阈值。该警报按原阈值保留，未修改算法、窗口或
阈值。

## 复审

- 本次新增裁决只有 EDGE-296 的 L2、L3、L4、L5，均由不同层级证据指向同一封口 session，
  不是批量生成或重复命令；`judge.py` 的 journal 去重和顺序锁已生效。
- session `20260905-042111` 的 `manifest.json`、`backend.log`、`sse.jsonl`、
  `frontend.log`、`llm.jsonl` 与封口后的 `screen.mov` 均非空且属于同一台架；
  `rig-check.sh`、`rig-down.sh` 和锚点校准均通过。
- 真实 App 的 Activity 画面、REST touchpoint 行、删除后的 404、三路 SSE、前端
  终端和 LLM wire 已逐项对照，证据文件存在且内容与裁决一致。
- L4 的视觉判定只针对录屏中最终 Activity island、删除行、transcript 的几何和层级；
  未把“最终文本的数字后缀改写”当作视觉通过理由，也未把它从证据中删除。
- L5 的可发现性判定只针对真实 Chat 顶部可见的 Activity 入口及打开后的计数/状态
  呈现，未把用户没有执行的第三方或系统动作计入本次速率复审。

## 处置

这是历史长间隔后恢复台架、当前仅审查一个前线的自然速率变化，不是跳过观察的
橡皮章信号。复审不发现证据缺失或质量下滑，按原阈值销账；后续裁决仍继续接受
`judge.py` 与三曲线警报约束。
