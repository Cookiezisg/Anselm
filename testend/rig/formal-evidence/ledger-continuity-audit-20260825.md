---
id: EVD-087-ledger-continuity-20260825
type: evidence
status: active
audience: [human, ai]
---

# WRK-087 正式账本连续性审计

## 结论

当前正式 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 缺少历史
`judgments.jsonl`。用户目录旧台架根 `~/.anselm-rig/judgments.jsonl` 虽然存在，
但只有 76 条、只覆盖 16 个项目，仍不能作为完整正式 journal。仓内
`docs/working/acceptance-loop/COVERAGE.md` 仍带有
历史裁决，但不能据此重造带有可信时间戳、警报曲线和原始证据绑定的正式 journal。
账本 gate 必须保持拒绝。

## 审计输入

- 清册：`docs/working/acceptance-loop/COVERAGE.md`
- 正式账本根：`/private/tmp/anselm-rig-formal-20260801-3`
- 审计命令：解析每个已裁决行的五级列和证据指针，并对每个指针执行 `Path.exists()`。
- 未读取或改写任何清册格、journal 或警报状态。

## 结果

| 项目 | 数值 |
|---|---:|
| 已裁决清册行 | 460 |
| 清册裁决指针 | 2355 |
| 唯一证据路径 | 763 |
| 当前仍存在的证据路径 | 23 |
| 已不存在的证据路径（按指针计） | 2332 |
| 原始 `judgments.jsonl` | 缺失 |
| 可发现的旧 journal 残片 | 76 条 / 16 个项目 |

`README.md`/`LOOP.md` 中记录的 `2335 judgments` 仅是历史工作记录，不是可重放
的原始 journal；`alarms.py check` 在空 journal 上返回 clean 也不代表历史连续 clean。

## 处置

1. 不执行 `judge.py`，不把 `SURF-078` 五通道证据写成绿账。
2. `testend/rig/judge.py` 增加正式连续性硬闸：正式清册已有 carried verdict 而
   journal 缺失或 journal 未覆盖全部 carried 单格时，任何新 `pass`、`fail` 或 `na` 都拒绝。
3. 只有恢复原始 journal，或完成单独记录、逐条有证据的全量重验后，才允许解除本闸。

验证：`python3 -m unittest testend/rig/test_judge.py -v`=`12/12`，
`python3 -m unittest testend/rig/test_scope.py -v`=`19/19`，
`python3 testend/rig/gen_coverage.py --check`=`848 rows / 460 carried judgments / 0 tombstones`。
