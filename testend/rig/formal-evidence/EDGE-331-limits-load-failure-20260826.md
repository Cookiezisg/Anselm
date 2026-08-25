# EDGE-331 · 限额面板载入失败

## L1 focused evidence

- `frontend/test/features/settings/s5_storage_limits_test.dart` 通过：限额 schema 失败仍落在可解释的产品错误面，不显示空白或假数据，重试后恢复服务端值。
- `frontend/lib/features/settings/ui/panels/limits_panel.dart` 的失败分支使用 `AnState`；人话标题/下一步在主面，wire 错误码只进入 tooltip，符合 E1。

## 判定

L1=`E1`：schema 读取失败时用户知道发生了什么、可以怎么做，技术细节不污染主界面。L2-L5 本批未启动真实 App，记 `na`。
