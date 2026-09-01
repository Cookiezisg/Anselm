# EDGE-178 · L5 ledger/alarm re-audit

- `judge.py` 已以 `G1` 写入 `搜索 embedder 缺席降级` 的 L5；证据来自同一 formal real-App
  session，`CODEX.md` 中的 G1 存在，且 anchor calibration 已通过 `10/10`。
- `discovery-collapse` 因近 50 个裁决的 fail share 为 `4.0%` 而打开。复审保留这条反橡皮图章
  信号，不把低 fail share 当作质量证明，也没有通过修改阈值、算法或裁决顺序来消警报。
- L5 的实际产品问题已重新核对：新 workspace 从 onboarding 进入空白 Chat，用户无需文档、内部
  术语或 Settings 入口即可提出检索目标；模型真实调用搜索并给出 lexical/semantic 的诚实边界。
  “没有 search/embedder Settings 控件”不构成此自动能力的 discoverability 缺陷，也没有被隐藏。
- L2/F2、L3/B2、L4/C4 和 L5/G1 各自的证据边界均保持独立；没有把一次精确词法命中夸大成
  semantic 状态确定，也没有把同一稳定帧重复包装成多个视觉结论之外的额外事实。
- `anchors.py check`=`10/10`；未修改 alarm 阈值、法典、anchor set、ledger sequence 或
  coverage generator。按原机制允许 ack 并继续下一项。
