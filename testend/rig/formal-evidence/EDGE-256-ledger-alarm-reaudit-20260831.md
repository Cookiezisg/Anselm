# EDGE-256 · 账本 / 警报复核

本格 L2-L5 逐级写账后，警报脚本均按原算法打开 `discovery-collapse`：近 50 条
live judgment 的 fail-share 为 `2.0% < 5%`。该信号没有被忽略，也没有通过修改阈值、
法典、锚点、五级标准或顺序 gate 来消除。

- L2 `F2`：复核真实 App session 的同一 manifest 归属、缺失驻地状态、backend/SSE/frontend/LLM
  journal 和收台结果；证据为 `sessions/20260831-201616/evidence/EDGE-256-moved-workdir-real-app.md`。
- L3 `B2`：复核 45-90 秒录屏的 5 秒抽帧；外部移目录后没有未挂图标闪回、空白或旧状态二次跳回。
- L4 `C5`：复核真实菜单中的路径、缺失状态、动作禁用态、图标文字中线和固定几何，没有探测结果
  导致的重排。
- L5 `G1`：复核从普通 Chat 入口打开驻地按钮即可发现原路径、缺失状态和下一步动作，不依赖内部
  协议或文档知识。

四条 `discovery-collapse` 均已使用独立复核说明 ack；最终
`RIG_HOME=/private/tmp/anselm-rig-formal-20260831-11 python3 testend/rig/alarms.py check`
为 `clean (167 live judgments; 4240 baseline judgments excluded from drift curves)`。
复核结论是“统计保护信号已审阅并销账”，不是把低 fail-share 当成产品自动通过。
