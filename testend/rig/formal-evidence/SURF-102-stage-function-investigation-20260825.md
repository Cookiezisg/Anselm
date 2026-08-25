# SURF-102 · stage/function · 正式调查记录

## 受验对象

`SURF-102 stage/function`：函数编辑舞台是否按产品顺序呈现旧真相地层、操作进度、活代码窗，
并在落定后保留同一代码壳、显示真实 before/after diff，且不把中间状态冒充成功。

## 静态与 focused test

- `FunctionStageBody` 的编辑路径从 `functionBaselineProvider` 读取按编辑 block 冻结的旧真相；
  live 状态显示 `AnLayerDiff` 和中性空心 OpTicker，`AnCodeEditor(live:true)` 负责活代码窗。
- settle 只解除同一 editor 的贴底状态，并以冻结 before 与落地 after 的逐行 diff 计算 `+n/−m`；
  failed 状态不使用成功色点，保留可读残稿。
- `functionBaselineProvider` 在取到后 keep-alive，真相缓存失效不能洗掉编辑前基线。
- focused command：
  `cd frontend && mise exec -- flutter test test/features/chat/ui/stages_w2_test.dart test/features/chat/ui/stage_alignment_test.dart test/features/chat/state/stage_director_provider_test.dart test/features/chat/ui/scene_from_truth_test.dart`
  通过，`+40`，无失败。

## 真实 App 路径

formal session：
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-073701`

在全新数据目录、真实 Flutter macOS App、真实 Anselm managed gateway、Computer Use、独立
SSE witness 和 LLM tap 下，建立临时函数 `surf102_stage_probe`，以真实 REST 仅精确投递用户
消息，再从 App 打开场次：

1. 受控短编辑把函数从 v4 改到 v5，单一 `set_code` 成功，UI 显示 `已更新函数 · v5`，环境
   `ready`，没有重复失败卡片；活动侧幕显示 `surf102_stage_probe 编辑`，代码窗内容与后端
   真相一致。
2. 另一条真实场次先观察到 `正在修改函数…`、活动侧幕 `edit_function 进行中` 和
   `实时聆听中 · 落定以真相为准`，随后打开落定舞台，代码窗保持同一宽度和行号结构，未见
   composer 跳变、横向溢出或布局红线。
3. focused widget test 直接覆盖了窄时间窗内 Computer Use 难以稳定采样的旧地层、中性
   OpTicker、live editor 和最终真实 diff；未用静态测试替代真实 App 的成功路径，只将其作为
   对窄帧的补充证据。

## 五通道事实

- Screen：真实 App 连续录制已启动并由 `rig-down.sh` 正常收台；起始 live frame、落定代码
  窗和活动侧幕均由 Computer Use 观察。macOS 输入法噪声只有已知
  `IMKCFRunLoopWakeUpReliable`。
- Backend：session `backend.log` 883 行。健康检查通过。三条 WARN 均可归因：早期故意的
  malformed `ops`、故意缺失函数 ID 的负 probe，以及长代码 probe 中模型先发的错误参数形状；
  没有 panic、fatal 或未解释的错误。干净短编辑本身无失败结果。
- SSE：`sse.jsonl` 1211 行；messages durable `1..162`、notifications `16..43`、entities
  `7..28`，均单调、唯一、无 gap；`seq=0` delta 未被误计为 durable。
- LLM wire：真实 managed proof challenge 和 chat completions 均为 HTTP 200；没有上游拒绝。
- Frontend：Flutter log 只有已知 macOS IMK 平台桥接噪声，无 Dart exception、RenderBox/
  RenderFlex overflow、Unhandled、SEVERE 或布局错误。
- `rig-check.sh`、`rig-down.sh` 通过；D1 backend attribution、health、三流、LLM tap、App
  窗口和录制均由台架检查，收台后无残留进程。

## 产品裁决

阶段自身通过：真实成功编辑达成用户目的，旧基线和真实落地结果的职责由代码和 focused
测试锁住，成功/失败色彩与状态语义没有混淆。长代码 probe 中模型多发了一次错误形状调用，
后端如实记录 WARN，重进场次也如实显示红色失败尝试；这不是被隐藏的后端错误，但属于模型
工具遵循的单独风险，不在本格擅自改 UI 或吞掉失败事实。后续模型工具链覆盖将把“错误调用后
自动重试是否应在产品层合并呈现”作为独立边界，不把它伪装成 SURF-102 的绿证据。
