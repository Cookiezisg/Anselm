# EDGE-340 · Vertex service-account 文件校验 · real App L3

## 现场

- session=`/private/tmp/anselm-rig-formal-20260902-06/sessions/20260902-010913`
- workspace=`ws_2239fff3a6986c06`
- App 为当前 checkout 构建的真实 macOS Flutter binary；录屏为
  `screen.mov`，`3104x1848 / 60fps / 168.698333s`。
- 路径：`Settings → Models & keys → Add key → Vertex`；使用隔离 acceptance
  数据目录和不含真实密钥的结构化 fixture。

## L3 判定（A1）

在 Vertex 表单选择 `service-account` JSON 文件。缺少 `private_key` 的无效文件被
前端当场拒绝，显示：`That is not a service-account file (needs type, project_id and
private_key).`；无效阶段没有 backend POST，也没有写入凭证。随后选择包含必需字段的
合法结构 fixture，错误消失，`Save & test` 才可用。

点击 `Save & test` 后，真实 backend 记录 `PATCH 200` 保存凭证，随后探针返回 `422`
（fixture 的 `private_key` 是故意不可解析的 `fixture`，因此不应被记录为认证成功）。
App 保留可修复的连接失败事实，并允许再次测试；服务账号路径不要求用户填写普通 API
key 文本。

60fps 局部测量：记录的交互 frame=`165`，首个超过 `0.001` 变化阈值的可见反馈
frame=`167`，`33.3ms`；变化框为 `(1200,689)-(2168,1350)`，局限于表单反馈区。
action frame 依据录屏内实际交互序列定位，不宣称 Computer Use RPC 的墙钟耗时。

## 五通道

- 帧：真实窗口连续 `screen.mov`，并提取 `evidence/vertex-action2-60fps/` 与
  `evidence/vertex-save-60fps/`。
- backend：创建隔离 Vertex key 后，保存路径为 `PATCH 200`；随后真实 probe 为
  `POST /api/v1/api-keys/{id}:test`=`422`，日志明确记录 `ok=false`。
- SSE：messages/entities/notifications 三流均建立连接并正常收台；设置页路径不
  产生业务 durable 事件，因此没有伪造 durable 帧证据。
- frontend：console/录制日志无 `Dart`、`FlutterError`、`RenderFlex`、overflow、
  `Unhandled`、`Exception`、panic 或 fatal 红线。
- LLM wire：受管网关 challenge/quota 请求均 `200`；本设置路径不需要 completion，
  未虚构模型调用。

SQLite `integrity_check=ok`，`foreign_key_check` 为空；backend、SSE、LLM tap、录屏
和进程收台均来自同一 session。

## 修复与回归

本轮补上了 service-account JSON 校验与 Save gate：类型、`project_id`、`private_key`
不是完整合法结构时不能提交；非字符串 `private_key` 也不会触发类型错误。相关 focused
Flutter 测试 `vertex_credential_test.dart` 3/3 通过，相关 Go 包测试通过。
