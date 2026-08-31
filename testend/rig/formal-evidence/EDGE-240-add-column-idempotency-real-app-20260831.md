# EDGE-240 · ADD COLUMN 结果幂等 · 真实 App 证据

## Session

- 正式 session：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-165453`
- 数据目录：`/Users/sunweilin/Library/Containers/website.anselm.app/Data/.anselm-edge240-legacy-data-1`
- 真实 App、App-owned backend、三路 SSE observer、frontend console、managed LLM tap 和窗口录屏由同一 manifest 归属。
- `rig-check` 与 `rig-down` 通过，录屏封口时长 `32.213333s`，无 conductor-owned survivor。

## Fixture and first boot

测试前从有效旧安装复制 fixture，并重建 `conversations` 为缺少
`forked_from_conversation_id`、`forked_from_message_id`、`work_dir` 三列的旧 schema；保留原有 1 条
conversation 及 `idx_conversations_ws_list`、`idx_conversations_ws_title`、`idx_conversations_ws_created`
三个旧索引。fixture 启动前 `PRAGMA integrity_check`=`ok`，三列均不存在。

第一次真实 App 启动后，backend 正常绑定 listener，App 完成 startup spinner 并稳定进入 Chat；SQLite
显示三列均已添加，且生成依赖 `idx_conversations_ws_workdir`。原有 conversation 仍为 1 条，
`PRAGMA integrity_check`=`ok`，`PRAGMA foreign_key_check` 为空。

## Second boot and product observation

关闭第一轮后用同一个已经升级的 data directory 再次启动真实 App。第二次启动重新执行包含三条
`ALTER TABLE ... ADD COLUMN` 的 schema 列表，SQLite 的 `duplicate column name` 结果被 `Migrate` 精确
视为已应用；App 再次经过启动过渡后稳定进入 Chat，没有迁移错误、白屏、黑屏、卡死或布局重叠。

第二轮最终 schema 仍只有各一份目标列和依赖索引，conversation 数仍为 1，SQLite 两项完整性检查继续
通过。五通道 journal 均可读；frontend journal 只有已知 macOS App sandbox 阻止本地 `llama-server` 的
search fallback WARN，本格未发起聊天，不将该环境限制误报为 ADD COLUMN 失败。

## Five-level judgment

- L2 `F1`：真实旧安装首次补列、同一安装第二次重复启动、数据/索引/完整性结果与 App 稳定状态互相交叉验证；
  不是 focused test 或 mock 代替现场证据。
- L3 `na`：schema migration 是后台启动动作，没有独立用户动作、等待反馈或交互流程对象；启动可用性已由 L2
  的真实 App 事实覆盖，不能从普通页面稳定帧推出迁移动效质量。
- L4 `na`：该内部迁移不产生独立的几何、排版、色彩或选择状态对象；Chat 的视觉 craft 由对应 surface 验收覆盖。
- L5 `na`：用户不能从产品导航中寻找“执行 ADD COLUMN 迁移”这一内部动作；迁移后的可用入口由 Chat/设置旅程覆盖，
  不把内部维护实现伪装成用户可发现功能。

## Related focused evidence

`testend/rig/formal-evidence/EDGE-240-add-column-idempotency-20260826.md` 保留 L1 focused 回归；本文件只
补充真实旧安装、两次真实 App 启动和五通道观察，不改既有五级标准、告警算法、锚点或顺序门。
