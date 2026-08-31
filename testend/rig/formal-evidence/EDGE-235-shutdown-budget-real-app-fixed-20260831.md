# EDGE-235 · 关停预算格

## 结论

本格按“focused 预算锁 + 真实在途 workflow + 修复后的真实 App 现场”收口。没有把
一次 64ms 的正常取消冒充“预算耗尽”；最坏串行预算由 focused golden test 锁住，真实现场只证明
在途节点进入关停后不会把 App 留在无限等待，也不会升级为 SIGKILL。两轮现场形成完整的
发现、停修、复验链。

## 真实现场

- 初次现场：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-145945/`。
  由 conductor 真实启动 App、backend、`ssetap`、`llmtap` 和窗口录屏；通过公共 HTTP 夹具
  创建 `surf031_dispatch_*` 四个 webhook workflow，其中 slow function 声明为 45 秒。
  App 的 Scheduler 画面真实显示 `Running 3`，并列出三条 running workflow。
- 该现场随后向真实 backend PID `98782` 发送 SIGTERM。`edge235-shutdown-timing.txt` 记录
  `shutdown_requested_at=2026-08-31T07:01:37.267936000Z`、
  `shutdown_process_gone_at=2026-08-31T07:01:37.332245000Z`；未发送 SIGKILL。
- backend journal 记录 `shutting down gracefully`，三条 resident SSE 在同一时刻均记录
  clean EOF；随后记录 `sandbox shutdown: all handles killed`。进程组收台后归零。
- 同一现场的 SQLite 真相保留三条在途 run 为 `running`。这是关停设计的可恢复中间态：
  预算窗口结束时不补写伪造 node 结果，由下一次 boot 的 Recover 重新接管；它没有被错误地标成
  completed，也没有被静默丢失。

## 停修红线与复验

- 初次现场的 App 在 backend 被外部停止后显示了错误的启动文案：backend 已经正常服务过，
  却显示“backend didn't start”。这被记录为产品语义红线，没有计入绿色证据。
- 修复为 `BackendFailureReason`：启动失败、已运行后失联、重启熔断分别保留原因；启动门对
  已运行后失联显示“本地引擎已停止响应。点击重试以重新连接。”，不再误导为启动失败。
- 修复复验：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-150438/`。
  新编译真实 App 先完成 ready，随后真实 backend PID `99829` 被 SIGTERM；Computer Use
  画面和 AX 树均显示 `The local engine stopped responding. Retry to reconnect.`，同时不存在
  startup hint。该 session 的窗口录屏、backend、三路 SSE、frontend console、managed
  gateway tap 均由 conductor 托管并已正常收台。

## 五通道对账

- **帧**：两轮均为 Anselm 窗口级 `screen.mov`；初轮捕获 Scheduler 的三条 running 行，
  修复轮捕获最终失联文案，均由 ffprobe 验证可读。
- **后端**：初轮有序关停、sandbox 收尾、无 panic/FATAL/未解释 WARN；慢 run 的 durable
  `running` 状态由 SQLite 复核。
- **SSE**：初轮 `messages`、`entities`、`notifications` 三条流均收到 EOF；durable
  run-started 与 stream disconnect 时间可在 `sse.jsonl` 对齐。
- **前端**：初轮暴露误导性文案；修复轮重新编译并实测正确的“停止响应”文案。两轮没有
  Dart/Flutter/RenderFlex/unhandled 错误；修复轮只保留本次刻意停止 backend 后的连接失败提示。
- **LLM 线缆**：两轮 managed challenge/install/models 请求均经 `llmtap` 到真实
  `https://api.anselm.website`；本格没有把没有发生的 chat completion 写成证据。

## 判据映射

- L1=`A4`：`EDGE-235-shutdown-budget-20260826.md` 的预算格、shell pipe floor 和 Flutter
  SIGKILL 分支 focused 测试通过。
- L2=`F2`：真实在途 workflow 的五通道事实交叉一致，且修复轮验证用户可理解的断线文案。
- L3=`A4`：关停在 6 秒 backend budget 与 8 秒 App grace 内结束；没有长时间假死或 SIGKILL
  升级，修复后的断线反馈为单一、可行动的 Retry。
- L4=`C4`：关停画面没有残留半渲染的 Scheduler 内容或截断的浮层；错误态保持既有明确
  图标、留白和主按钮层级，修复轮确认文案换行稳定。
- L5=`na`：本格是 bootstrap/transport 生命周期预算，不产生独立用户入口或 discoverability
  对象；将后台收台日志判成发现性证据会把内部证据冒充产品证据。

没有改变 CODEX、anchor、告警阈值、ledger gate、sequence 或五级标准；初轮产品红线已先修
再复验，未用 waiver 抹平。
