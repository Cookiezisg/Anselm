# SURF-097 账本警报复审

## 复审对象

`i18n/graph` 的五级裁决刚由 `judge.py` 串行写入，正式警报打开 `gap-too-fast` 与 `discovery-collapse`。本复审不修改阈值、算法、法典、锚点或 gate。

## 独立证据复核

- session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-062648` 已由 `rig-check.sh` 证明五通道物理接线完整，`rig-down.sh` 已收台，`screen.mov` 可由 `ffprobe` 读取，时长 `270.311667s`。
- 录屏帧重新检查了 workflow detail、图编辑器、添加节点菜单和触发节点检查器；标签为中文且节点卡、连线、面板无明显裁切、重叠或跳变。
- focused Flutter tests `14` 项通过，双语 `NodeKind` 六项断言包含 `unknown` fallback；没有把不可添加的 unknown 伪造成 UI 路径。
- SSE journal 真实记录 fixture 的 `entry.body.*` payload 失配和 `run_terminal failed`。该红事实被保留，未被本格的图编辑器绿证据覆盖。
- backend journal 无应用级 WARN/ERROR/panic/fatal/exception，frontend journal 只有正常启动输出；llmtap 的真实网关探针与 completion 均为 `200`。
- anchors 仍为冻结集合 `10/10`；`gen_coverage.py --check` 为 `848 rows / 480 carried judgments / 0 tombstones`。

## 结论

两条警报来自既有机制：连续五级裁决是同一原子格子的串行脚本动作，间隔中位数为 `0s`；最近窗口没有 fail 也触发 discovery 复核。证据本身充分，且红事实已明确分类，不因警报而改判，也不因想继续推进而放宽门槛。按流程 ack 后继续下一前线。
