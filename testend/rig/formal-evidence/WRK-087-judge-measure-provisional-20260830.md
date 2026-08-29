# WRK-087 · judge gate：measure provisional note

## Finding

清册中的 provisional `~` 不只使用 `L2:na→note:`，也使用 `L2:measure:<id>→note:`。旧解析器只匹配前一种形式，会把“本轮只有本地测试、尚无真实 App/五通道证据”的后一种记录误判为 settled，顺序门因此可能越过仍未验收的格子。

## Fix and evidence

- `testend/rig/judge.py:na_note_for_level` 现在读取同一 level 的任意 `...→note:` 指针，保留“取最新 level 指针”的规则。
- `testend/rig/test_judge.py:test_measure_note_reopens_the_autonomous_frontier` 锁定 `measure→note` 会重新打开前线。
- 同一测试文件普通回归 `20/20` 通过；明确“不拥有 Flutter 视觉表面”的 `na` 仍被识别为 settled。

## Result

修复后的顺序门重算：`848` 行、`41` 个人工后置项、`111` 行未收口；自主 `70` 行、`206` 格；当前自动前线为 `EDGE-222|生成 origin 从凭证派生`。这一步只修正验收仪器，不放宽五级标准，也不把真实 App 缺失证据改成通过。
