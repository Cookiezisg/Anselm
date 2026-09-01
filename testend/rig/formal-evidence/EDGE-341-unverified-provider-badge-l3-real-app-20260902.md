# EDGE-341 · 未验证供应商诚实徽标 · real App L3

## 现场

- session=`/private/tmp/anselm-rig-formal-20260902-07/sessions/20260902-012607`
- workspace=`ws_b07c35ce3aa1ca0e`
- App 为当前 checkout 构建的真实 macOS Flutter binary；录屏为
  `screen.mov`，`3104x1848 / 60fps / 90.246667s`。
- 路径：`Settings → Models & keys → Add key → 302.AI`；使用隔离 fixture
  `EDGE341 probe` / `fixturekey`，不含真实凭证。

## L3 判定（A1）

供应商目录中的 302.AI 卡片显示 `Untested`，进入表单后执行真实 `Save & test`。
保存先成功，连接探针随后返回失败；App 先给出保存与探针状态，最终显示：

- `The key was saved, but its connectivity probe failed. Check the key or Base URL and try again.`
- `api key probe failed`
- `We have never tested this provider. If your key is right, the fault may be on our side.`

这条路径没有把未验证供应商的失败归咎于用户，也没有静默等待网络。录屏局部测量以
保存动作前一帧为基线：action=`139`，首个可见反馈 frame=`141`，`33.3ms`，变化框
`(1200,856)-(1681,912)`；该反馈是 `Saving & probing…` 与 spinner，最终探针文案在
之后出现。测量基于录屏帧，不宣称 Computer Use RPC 的墙钟耗时。

## 五通道

- 帧：真实窗口连续 `screen.mov`，提取 `evidence/edge341-2fps/`、
  `evidence/edge341-action60/` 和 `evidence/edge341-save60/`；最终错误状态帧为
  `evidence/edge341-save60/frame-0157.png`。
- backend：供应商读取 `GET /api/v1/providers`=`200`；隔离 key 创建
  `POST /api/v1/api-keys`=`201`，随后真实 probe=`422`，日志记录 provider=`302ai`
  且 `ok=false`。
- SSE：messages/entities/notifications 三流均连接并正常收台；本场景没有业务 durable
  事件，不伪造 durable seq。
- frontend：无 Dart/Flutter/RenderFlex/overflow/Unhandled/Exception 应用级红线；仅有
  macOS IMK 宿主提示，已按采集环境噪声分类，不是产品错误。
- LLM wire：managed challenge/install/models/quota 请求均 `200`；本设置路径不需要
  completion，未虚构模型调用。

SQLite `integrity_check=ok`，`foreign_key_check` 为空；`rig-check`、`rig-down`、录屏
封口和 owned-process 收台均通过。
