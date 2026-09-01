# EDGE-331 限额面板载入失败：L5 真实 App 可发现性证据

- session: `/private/tmp/anselm-rig-formal-20260901-14/sessions/20260901-233914`
- representative frames: session `evidence/frames-error-60-small/0075.png` and
  `evidence/frames-retry-60-small/0088.png`
- law: `G1`（入口一个新用户不读文档能自己走到）
- verdict: `pass` for L5

## Blind product path

以普通用户目标“查看并调整这台机器的限额”为目标，不依赖 API 路径、内部 endpoint、代理注入名或
实现术语：从 Settings 目录可直接找到 `Advanced limits`。首次载入失败后，错误态明确告诉用户发生
了什么，并提供唯一直接恢复动作 `Retry`；点击后页面回到可读的 machine-wide 说明和限额字段，不需要
重启 App、切换页面或猜测内部状态。

错误面没有把用户引向不存在的“联系开发者”路径，也没有把 503 或日志代码当成操作说明。普通用户
可以从入口、错误解释和 Retry 形成闭环，并在恢复后看到可操作的字段。

## Five-channel cross-check

- **frames / Computer Use**: 真实点击路径从 Settings → Advanced limits → Retry 完成；错误态和恢复态均可直接读懂。
- **backend**: `backend.log` 无应用级 WARN/ERROR/panic/fatal；失败与恢复请求由 app proxy journal 精确记录。
- **SSE**: messages/entities/notifications 三流连接完整；该设置操作没有伪造通知或消息来暗示成功。
- **frontend console**: 无 Flutter/Dart、RenderFlex、RenderBox、Unhandled、Exception 或 overflow。
- **LLM wire**: managed challenge/install/models 为真实 `200`，无模型输出替代 UI 事实。
- **durable truth**: 第二次 schema/limits 成功和画面字段同时证明恢复，不以按钮点击本身冒充成功。
- **rig lifecycle**: `rig-check`、录屏和 `rig-down` 均通过，session 目录保留全部复核材料。

## Verdict

`L5 pass (G1)`。普通用户无需阅读文档即可找到入口、理解失败、执行恢复并确认结果；错误态的
技术细节被隔离在观测通道，不污染产品文案。
