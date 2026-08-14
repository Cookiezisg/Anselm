---
id: WRK-091
type: working
status: active
owner: "@weilin"
created: 2026-08-01
reviewed: 2026-08-01
review-due: 2026-10-30
audience: [human, ai]
landed-into:
---

# WRK-091 · 验收裁判锚点集

本页落实 WRK-087 §4.4。锚点不是产品覆盖样本，而是**裁判刻度**：固定包含该过与该扣、机械与
craft、画面与数据真相。题集在 [`testend/rig/anchors.json`](../../../testend/rig/anchors.json)，
任何 agent 开始裁决前都必须完成一次无答案答卷：

```bash
export RIG_HOME=/private/tmp/anselm-rig-formal-<session>
python3 testend/rig/anchors.py quiz
# 编辑 $RIG_HOME/anchor-quiz.json 中每题的 verdict / law / reason
python3 testend/rig/anchors.py check "$RIG_HOME/anchor-quiz.json"
```

校验通过后生成 `$RIG_HOME/anchor-check.json`。`anchors.py`、`alarms.py` 和 `judge.py` 均要求显式绝对
`RIG_HOME`；缺失、相对路径或 `~` 路径会直接拒绝，防止校准和正式账本落到个人默认目录。凭证绑定题集
SHA-256、有效四小时；题集变化、凭证过期、漏题、空理由或任一 verdict/法条偏离都会使 `judge.py` 物理拒绝
新 `pass`。失败后的处理只有一个：停前线、重读 CODEX、回审近期裁决、重做整套锚点；不得改答案迁就当下判断。

## 冻结刻度

| 锚点 | 刻度 | 主要法条 |
|---|---|---|
| A01–A02 | 33ms 可见反馈该过；480ms 无反馈该扣 | A1 |
| A03–A04 | 等高零缝选区该过；高度漂移且有白缝该扣 | C1 |
| A05 | 原始十亿整数与 ISO 时戳直接暴露给用户该扣 | E5 |
| A06 | 不可用能力仍可点且只吐错误码该扣 | E4 |
| A07–A08 | UI 自述与线缆冲突该扣；五通道相互一致才该过 | F4 / F3 |
| A09 | 流式中仍可输入、滚动且反馈及时该过 | A5 |
| A10 | 同类工具连续误用而不修引导面该扣 | H2 |

**冻结规则**：锚点的情境、期望 verdict 和主法条不随施工改写。行业标准或仓内宪法收紧时只可新增
锚点；若确需翻案，必须由用户拍板并在 WRK-087 §6 留原话。题集本身入 git，校准答卷与凭证只落
专机本地，不进入提交。
