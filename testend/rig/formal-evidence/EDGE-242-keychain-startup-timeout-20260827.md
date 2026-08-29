# EDGE-242 · keychain 授权挂起时启动有界

## 事实

- formal session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-014259`。
- session 启动时 `SecurityAgent` 占据 Anselm 录制区域；`rig-check` 按规则拒绝外部窗口重叠，故本文件不是五级绿证据。
- App 在等待授权期间曾永久停留在“正在连接本地引擎…”，且没有启动 `anselm-server` 子进程。
- 系统授权窗口无法由本工具操作；不能绕过 macOS 授权机制，也不能把该 session 当作产品录屏。

## stop-and-fix

`MasterKey.resolve()` 对 keychain read、write 和 read-back 分别增加 3 秒有界等待。超时与异常统一返回 `null`，继续使用既有 legacy fingerprint 路径；已有数据库仍绝不铸新钥，写入超时也不进入读回。

守卫：`frontend/test/core/process/master_key_test.dart` 覆盖读挂起与写挂起；测试通过。重建后的真实 App 已从连接页进入主界面，开发后端健康，说明启动不再被 keychain future 无限冻结。

## 当前结论

- code fix：通过 focused test + 真实 App 启动复核。
- Always Allow：仍待用户在 macOS 授权窗口中完成；当前 formal session 的 `rig-check` 为失败，未写 `judge.py`，未改 COVERAGE，未计入批次。
