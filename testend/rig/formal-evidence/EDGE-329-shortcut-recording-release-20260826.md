# EDGE-329 · 快捷键录制后吞键

## L1 focused evidence

- `frontend/test/features/settings/s6_shortcuts_test.dart` 通过：录制 ⌘J 后，未重新进入录制态的杂散 ⌘K 不会再次改绑原命令。
- 同文件覆盖录制 UI、当前 keycap、冲突拒绝和录制完成后的键盘释放契约。

## 判定

L1=`A5`：录制结束后键盘控制权归还 shell，后续操作不会被设置行静默吞掉。L2-L5 本批未启动真实 App，记 `na`。
