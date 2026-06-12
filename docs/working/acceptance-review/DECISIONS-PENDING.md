---
id: WRK-015
type: working
status: active
owner: @weilin
created: 2026-06-12
reviewed: 2026-06-12
review-due: 2026-09-12
expires: 2026-09-12
landed-into: ""
audience: [human, ai]
---

# DECISIONS-PENDING —— 验收期产品裁决台账

| 编号 | 问题 | 选项/建议 | 状态 |
|---|---|---|---|
| AC-PD-1 | function/handler 创建与 edit 同步阻塞 env 物化 | **裁决：by-design 维持同步**——前提「阻塞期间用户可见」实测成立（created+env_status_changed 实时推，TestFunction_CreateEnvVisibility 钉死） | ✅ 关闭 |
