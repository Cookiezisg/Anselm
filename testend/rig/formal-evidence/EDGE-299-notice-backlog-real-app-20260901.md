# EDGE-299 · 顶带 5000 条积压：真实 App L2-L5

## 判定范围

本证据判定 `COVERAGE` 中 `EDGE-299|顶带 5000 条积压` 的 L2-L5。L1 的 focused
implementation/race 证据已存在；本次补的是真实 App 在大量通知压力下的产品行为，不把后端
“能写入 5000 条”替代为 UI 已承受 5000 条。

## 正式现场

- session=`/private/tmp/anselm-rig-formal-20260901-edge299/sessions/20260901-141545`
- workspace=`ws_744cd655fd92d20d`
- backend PID=`41248`，`:8742` 的监听归属与 manifest 相同；App PID=`41717`，录屏窗口
  `12961`，bounds=`0,30,1440,810`；ssetap PID=`41300`；llmtap PID=`41210`，上游为
  `https://api.anselm.website`。
- `screen.mov` 独立 `ffprobe`：H.264、`3104x1844`、`60/1 fps`、`313.828333s`。
  `rig-down` 已完成 recorder lifecycle 封口；录像存在且可独立解码。低频复核帧位于
  `sessions/20260901-141545/evidence/edge299-frames/`，不是从实时截图冒充封存证据。

## 压力构造与事实

1. 通过真实 HTTP `POST /api/v1/skills` 并行创建 `edge299-1` 至 `edge299-5000`，随后创建
   `edge299-5001` 至 `edge299-10000`。后端 journal 的这批请求共 `10000` 条，HTTP status
   全为 `201`；同一 journal 中另有 `2` 条准备阶段的 201，因此全 session 的匹配数是
   `10002`。
2. 第一批验证了通知托盘的大量历史分页；随后在真实 App 的 Settings → Notifications 将
   通知级别临时切到 `All`，再执行第二批，以便验证 neutral `skill.created` 事件实际进入
   顶带，而不是只落在 inbox。测试结束后恢复持久设置为 `important`，没有改变产品默认设置。
3. 独立 SSE witness 的 `sse.jsonl` 有 `10008` 行，其中三条流的连接/断开控制记录之外，
   notifications durable frames 为 `10000` 条：`skill.created` 为 `10000`，seq 从 `16`
   连续到 `10015`，`unique_seq=10000`，`seq_gaps=0`。三条流均出现并在收台时 clean EOF；
   不以通知流事件数量推断 App 一定渲染了 10000 个 widget。
4. 真实 App 在顶带压力期间显示一张当前卡片、最多两个 cue 点和视觉溢出计数 `999+`；
   Computer Use AX snapshot 同时提供可操作的精确语义，例如
   `Clear all 4985 top notifications`。连续五次、每次相隔约 2 秒的采样中，当前卡片随队列
   轮转，清空动作保持稳定，AX 树没有暴露数千个独立通知 widget。应用可继续响应，composer
   与左岛没有冻结、溢出或被队列数量推离。

## 封存画面

以下帧从封存 `screen.mov` 以低频方式抽取，展示压力期仍在工作的真实 App，而非 mock：

- `sessions/20260901-141545/evidence/edge299-frames/frame-220.png`
- `sessions/20260901-141545/evidence/edge299-frames/frame-240.png`
- `sessions/20260901-141545/evidence/edge299-frames/frame-250.png`
- `sessions/20260901-141545/evidence/edge299-frames/frame-280.png`

各帧都保留当前通知胶囊、cue 投影和 composer；抽帧展示工具曾对 `t=260` 给出黑色预览，
但该 PNG 的 signalstats 与相邻帧一致，且 `blackdetect` 在 210-290 秒窗口没有检测到黑屏区间，
所以不将该工具预览异常计为产品黑帧，也不靠它支撑正面结论。

## 五通道交叉核对

- **Channel 1 / Computer Use + screen recording**：真实 App 在压力期显示固定成本的顶带投影；
  当前卡片持续轮转，视觉计数封顶为 `999+`，没有把 5000 条扩成屏幕上的 5000 个控件。
- **Channel 2 / backend journal**：10000 条创建请求均为 201；backend journal 无
  `WARN|ERROR|panic|fatal` 应用红线。
- **Channel 3 / independent SSE tap**：notifications/messages/entities 三流都被独立订阅；
  通知 durable seq 连续，无 gap，收台为 EOF。
- **Channel 4 / frontend console**：frontend journal 没有 `Unhandled|Exception|RenderFlex|FlutterError|DartError`
  红线；仅有 Dart VM service 和已分类的 macOS IMK 关闭期平台诊断。
- **Channel 5 / LLM wire**：本压力路径不需要 completion；managed challenge/install/models
  均成功，llmtap 仍归属于本 session，不能把“无 completion”误报成聊天成功。

## 实现与产品判断

现场行为与 `/Users/sunweilin/Developer/Anselm/frontend/lib/core/notice/notice_center.dart`、
`/Users/sunweilin/Developer/Anselm/frontend/lib/core/ui/an_notice_queue_tail.dart`、
`/Users/sunweilin/Developer/Anselm/frontend/lib/app/app_shell.dart` 的实现相互吻合：内部使用
两个 `ListQueue`，当前卡片与队列尾部投影分离，cue 最多两个，视觉数量封顶但 accessibility
label 保留精确语义；因此积压增长不会线性增加 widget 数量，也不会使主 composer 重新布局。

本次没有发现需要 stop-and-fix 的产品缺陷。`999+` 是视觉防止长数字破坏布局的合理封顶，
而 `Clear all <exact count>` 保留了精确可操作语义，二者没有互相冒充。该结论只覆盖本次
真实 App 的 10000 条通知压力和观察窗口，不外推到未测试的系统通知权限边界。

## 五级写账映射

- L2=`F2`：真实 App、五通道 journal、封存录屏和后端结果在同一 manifest/session 互证。
- L3=`A4`：压力期间持续有当前状态/通知反馈，操作未变成无反馈等待；以录屏与连续 Computer Use
  采样为证，不虚构 action-to-first-feedback 数值。
- L4=`C4`：当前卡片、cue 点、composer 与左岛保持既定圆角/层级和固定投影几何，`999+` 没有
  撑破胶囊；以封存帧和实现 token 交叉核对。
- L5=`G1`：当前通知提供 `View`，顶带提供 `Dismiss` 与 `Clear all`，精确数量在可访问语义中
  可读；新用户无需知道内部 SSE/REST 名称即可理解下一步。
