# EDGE-239 · CHECK 加词整表重建 · 真实 App 升级证据

## 结论

本证据验证的是一个真实桌面 App 从旧 SQLite 安装启动时的升级路径：
`trigger_firings.status` 接受 `missed`、`flowrun_nodes.status` 接受 `cancelled`、
`message_blocks.type` 接受 `marker`。三张表的旧 CHECK 在启动前被刻意恢复，当前 App
sidecar 的 boot migration 在同一真实 session 内完成重建；原有消息、索引和 SQLite
完整性均保留。L2 以 F1 结算。L3-L5 是该后台迁移本身的适用性边界，不把普通 Chat
画面当成迁移专属的顺滑、视觉或发现性证据。

## Session

- 正式 session：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-162419`
- App data：`/Users/sunweilin/Library/Containers/website.anselm.app/Data/.anselm-edge239-legacy-data-3`
- 真实 App：`frontend/build/macos/Build/Products/Debug/anselm.app`
- 录屏：`screen.mov`，`3104x1844 / 60fps / 74.541667s`
- 稳定 Chat 证据帧：`sessions/20260831-162419/evidence/EDGE-239-upgraded-app-chat.png`
- 启动帧：`sessions/20260831-162419/evidence/startup-frames/t0.2.png`、`t1.0.png`、
  `t2.5.png`、`t4.0.png`

第一次尝试使用 `/private/tmp` 数据目录，真实 App 沙箱拒绝 sidecar 打开数据库并在
监听前退出；该 session 不计入任何产品格。正式 session 改用 App 容器允许的 Data
目录，且 `rig-check` 和 `rig-down` 均通过。

## Upgrade fixture and result

1. 从上一轮真实 App 数据目录复制出独立副本，没有修改源目录。
2. 在副本中只移除三张目标表的一个 CHECK 词，并按原表列与索引复制回旧形状：
   `missed`、`cancelled`、`marker` 启动前均不在对应 `sqlite_master` DDL 中。
3. 启动当前真实 App。sidecar 完成正常 `Migrate` 后的三次 `MigrateRebuild`。
4. 启动后 SQLite 观察结果：
   - `trigger_firings` 的 status CHECK 包含 `missed`，5 个索引存在；
   - `flowrun_nodes` 的 status CHECK 包含 `cancelled`，3 个索引存在；
   - `message_blocks` 的 type CHECK 包含 `marker`，2 个索引存在；
   - `message_blocks` 的既有行数仍为 `3`；
   - `PRAGMA integrity_check` 为 `ok`，`PRAGMA foreign_key_check` 为空。

## Product observation

录屏启动早期显示带 spinner 的 `Setting up your workspace...`，随后稳定落到
`Storage & logs`，再通过 Computer Use 进入 Chat。Chat 的 AX 树显示既有会话、
`New chat`、`Attach files` 和 composer；画面没有白屏、迁移后的空 workspace、窗口
消失或持续 loading。该观察证明升级后产品仍可用和历史仍可见，不扩张为迁移自身的
独立动效或入口结论。

## Five channels

- Channel 1：同一 manifest 的 App-window recorder，窗口无外部覆盖，封口录像可读。
- Channel 2：App-owned sidecar PID=`17979`，监听端口与 PID 一致，health probe 为 200；
  sidecar 日志通过 `frontend.log` 的 `[backend]` 前缀保留。
- Channel 3：ssetap PID=`18027`，三路 SSE 均连接；启动与收台事件保存在 `sse.jsonl`。
- Channel 4：direct macOS App PID=`17939`，frontend console 与 App 由 conductor 归属。
- Channel 5：llmtap PID=`17475`，managed key 仍指向本 session 的 tap；本路径没有新
  LLM completion，`llm.jsonl` 的 readiness 记录保留，不伪造模型调用。

## Level boundary

- L2 `F1`：真实 App 启动后的可用画面、SQLite DDL/行数/完整性与同一 session manifest
  交叉一致。
- L3 `na`：这是后台 schema migration，不定义独立用户动作、反馈交互或动效对象；
  启动可用性已由本证据的 L2 事实覆盖，不能从普通页面稳定帧推出迁移动效质量。
- L4 `na`：该路径不产生独立视觉几何、排版或色彩对象；Storage & logs/Chat 的视觉
  craft 由对应 surface 验收覆盖。
- L5 `na`：用户不能从导航中寻找“执行 CHECK 重建”这一内部动作；迁移后的可用入口由
  Chat 和设置旅程覆盖，不能把内部 boot 行为写成可发现性旅程。
