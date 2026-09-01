# EDGE-179 L2 账本告警独立复审

- **Rig home:** `/private/tmp/anselm-rig-formal-20260801-4`
- **New judgment:** `EDGE|首用下载途中关停|L2|pass|F2`
- **Alarm:** `discovery-collapse`
- **Anchor check:** `10/10` passed using `anchors.py check`

## 复审结果

本次新裁决后，排除 `coverage-baseline` 的 live journal 共 `2139` 条；最近 50 条为：

```text
pass=29, na=19, fail=2, fail-share=4.0%
```

触发阈值是 `fail-share < 5%`，并不等价于产品质量变好。两条 fail 均为真实 stop-and-fix
结果且有独立证据：

1. `EDGE|MCP 进度关联|L5`：真实 App 发现性红证据
   `EDGE-174-mcp-progress-correlation-l5-discovery-red-20260830.md`。
2. `EDGE|MCP 失败附 stderr 尾|L4`：错误详情视觉层红证据
   `EDGE-175-mcp-stderr-tail-l4-red-20260830.md`。

新增的 EDGE-179 L2 不是无证绿章：同一封存 session 具备 manifest、backend.log、
sse.jsonl、frontend.log、llm.jsonl 和 screen.mov，且五通道交叉核对显示真实首次下载、
SIGTERM、installer `context canceled`、lexical fallback 与快速 sidecar 退出。该格明确
未把 onboarding 录屏冒充下载状态 UI，L3-L5 仍开放。

因此本告警属于已识别的统计阈值信号，不发现裁判停止寻找证据或证据污染；未修改阈值、
算法、法典、锚点、顺序门或覆盖清册生成规则。按 `alarms.py ack` 销账，继续时仍受
同一套 gate 约束。
