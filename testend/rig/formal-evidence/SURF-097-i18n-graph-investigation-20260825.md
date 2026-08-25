# SURF-097 i18n/graph 调查

## Stop-and-fix 边界

静态检查确认图编辑器的 `NodeKind` 六项均由生成的 i18n 资源提供，真实调用点覆盖 workflow editor、inspector 和 graph canvas。新增节点菜单真实显示五个可添加类型；`unknown` 只作为开放枚举 fallback 保留。

## Real App

正式 session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-062648`。

真实操作路径为 Entities → `surf041_terminal_workflow` → `进入图编辑器`，观察新增节点菜单、触发节点检查器和动作节点检查器。没有点击保存，没有改变 fixture 图。录屏帧与同 session 五通道记录见：

- `evidence/frames/SURF-097-graph-menu.png`
- `evidence/frames/SURF-097-graph-final.png`
- `evidence/SURF-097-i18n-graph-five-channel.md`

## 验证

`mise exec -- flutter test test/core/settings/locale_boot_test.dart test/features/entities/ui/detail/workflow_editor_page_test.dart` 通过，共 `14` 项；新增双语断言覆盖 `Trigger/Action/Agent/Branch/Approval/Unknown` 与 `触发/动作/智能体/分支/审批/未知`。

`rig-check.sh` 通过五通道物理检查；`rig-down.sh` 通过并 finalized `screen.mov`。本 session 的 fixture 预置在执行阶段因 `entry.body.*` 与当前真实 payload 形状不一致而失败，SSE journal 原样记录 `no such key: body`。该红事实不被本格隐藏，也不被错误归入图编辑器 i18n 缺陷。

## Ledger boundary

本格五级裁决只对图编辑器可见标签、入口和稳定呈现负责；工作流 payload 映射属于后续执行契约格，不能由本格绿证据代替。锚点、法典、阈值与警报算法均未修改。
