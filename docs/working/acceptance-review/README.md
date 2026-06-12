---
id: WRK-012
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

# acceptance-review —— 全产品真机验收 + 体验审查（2026-06-12）

## 定位

第四种审查：前三种（实现正确性 / 设计自洽 / 闭环配对）都是读码推演，本轮**真开机真打**——全部 feature × 全部情况 × 涟漪面，三列判定（用户面 / 产品逻辑 / LLM 面），外加六视角×六状态体验审查。完整计划见 [PLAN.md](PLAN.md)。

> **换 agent 接手？先读 [HANDOFF.md](HANDOFF.md)** —— 操作手册 + 方法论 + harness/llmmock API 速查 + bug 模式图谱 + W5 逐步接手指南。读它即可无缝续跑、标准不变。

## 规则

- 分支 `acceptance-review`；场景即 go test（testend/scenarios，黑盒零 backend import）；发现 PR-N 亲验落 [findings.md](findings.md)；能修顺手修、产品裁决留 [DECISIONS-PENDING.md](DECISIONS-PENDING.md)；每波 verify+testend 双绿收口提交。
- 永久资产：testend/ 验收套件（make testend）+ 金标套件（make evals）+ promptdump。

## 波次

| 波 | 范围 | 状态 |
|---|---|---|
| W0 | 环境+座架（harness/sse/smoke；llmmock/promptdump 随 W4 进场） | ✅ |
| W1 | 锻造域 A1-A3（function/handler/control/approval） | ✅ |
| W2 | 编排域 A5（workflow/trigger/flowrun，含 kill -9 恢复） | ✅ |
| W3 | 集成域 A6+A7（MCP 真装真调 + Search） | ✅ 首验；A7 缺格见 R1 |
| W4 | 对话域 A8（chat 全链/压缩/todo/错误路径）——llmmock+promptdump 进场 | ✅ 首验；缺格见 R3 |
| W5 | 平台域 A9 + 涟漪 A10 | ✅ 首验；缺格见 R4/R5 |
| W6 | 体验静态（柱 B） | ✅ 首验；缺格见 R6 |
| W7 | 金标旅程（柱 C：deepseek-v4-flash 7/12） | ✅ 首验；缺 5 旅程见 R7 |
| W8 | 首轮收口 | ✅（被 R 重开取代） |

**程序重开（2026-06-13 用户裁定）**：A7 起标准滑坡——首轮只覆盖 happy path + 部分错误码，未按 PLAN.md 逐格穷尽"必验情况"。重开为 **R1-R8 高标准重验波次**，缺口矩阵与执行纪律见 [R-PLAN.md](R-PLAN.md)。W0-W7 首验结论仍有效（抓到的 24 条 finding 与修复不回退），但**覆盖完整性以 R 波次收口为准**。
