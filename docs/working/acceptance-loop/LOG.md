---
id: WRK-092
type: working
status: active
owner: "@weilin"
created: 2026-08-01
reviewed: 2026-08-01
review-due: 2026-10-30
audience: [human, ai]
landed-into:
---

# WRK-092 · 验收战役日志

本页只记录**已经发生的日级事实与前线位置**，不复制 WRK-087 的规则。每日收台后追加一节；细粒度
格子结论只进 COVERAGE 与 `~/.anselm-rig/judgments.jsonl`，证据只放专机 session 目录。

## 2026-08-01 · Day 0 收口

- 前线：Day 0 完成；下一步从 COVERAGE 第一条未裁决格开始一期主循环。
- 基线：`main@b47fe0cb`；清册 848 行、4240 格；47 条旅程只作一期路线，400+ 扩写推迟二期。
- 台架：真实 App + Flutter console + 屏幕录像 + sidecar + 动态全 workspace SSE + LLM wire 全由
  conductor 托管；全新数据完成 onboarding、受管开通与五通道自检，收台后无幸存进程。
- 证据：隔离冒烟 session `/tmp/anselm-rig-smoke-2/sessions/`；最终会话 MOV 78.02s、ffprobe 可读；
  challenge/install/models 均穿 llmtap 返回 200，三路 SSE 均建立连接。
- 台架修复：动态 workspace 接管、detached 进程组、Flutter console 入 manifest、录像正确封口、
  WebSocket Hijacker 透明转发、measure ROI、L2 五通道物理门禁、警报 ack 水位、锚点四小时解锁。
- 产品发现：受管额度面直接显示原始十亿整数与 ISO reset 时间，已纳入锚点 A05；主循环到设置面
  时按 stop-and-fix 修复，不在 Day 0 台架施工中夹带产品改动。
- 配置：持久 Goal 已创建并保持 active；Loop 执行协议见 [`LOOP.md`](LOOP.md)。本日志记录的是
  Day 0 收口和配置完成，第一次正式唤醒前不宣称任何产品覆盖格已完成。
- 批次策略：按用户 P15，首批为 `0 / 50` 个 COVERAGE 单格裁决；单格证据与 stop-and-fix 不变，
  第 50 格后统一运行长门禁、完整 testend、警报复核和 git commit。

## 2026-08-01 · Goal/Loop 配置恢复

- 持久 Goal 经系统核对仍为 `active`；本次没有创建第二个 Goal，避免双前线和重复施工。
- Loop 协议经系统核对仍为 `active`，已幂等重新装载；50 格批次门禁、逐格 stop-and-fix 和不降标准规则保持不变。
- 当前批次计数保持 `35 / 50`，下一前线保持 `SURF-014 chat/log-drawer`；本次只恢复配置，不推进 App 操作或 COVERAGE 裁决。

## 2026-08-01 · 首个产品切片发现与修复进行中

- 首轮真实 App + 受管网关会话发现：主聊天回复完整落库，但 auto-title 请求在 10 秒预算内只收到
  `reasoning_content`，没有正文，故对话 REST 保持 `title:""/autoTitled:false`，UI 永远显示 `New chat`。
- 五通道证据：请求体 `/tmp/anselm-rig-formal-20260801-2/sessions/20260801-011544/llm-bodies/00005_v1_chat_completions.bin`；
  真实响应 `/tmp/anselm-rig-formal-20260801-2/sessions/20260801-011544/llm-responses/00005_v1_chat_completions.bin`；
  SSE durable seq 1–8 与 UI/REST 均证明主回合完成，响应体尾部证明标题预算到期时仍在 thinking。
- 前线冻结：已直接改 `backend/internal/app/chat/autotitle.go`，utility 标题失败、超时、无正文或未配置时
  回落到首条用户请求的本地可读标题；新增 reasoning-only 守卫测试。待单测、编译和新台架逐帧复验后，
  才允许继续本切片或写 COVERAGE 裁决。

## 2026-08-01 · 首个产品切片复验完成

- 新台架会话：`/tmp/anselm-rig-formal-20260801-3/sessions/20260801-012108`；真实 App、真实受管网关、
  Computer Use 录像和五通道均已收台封存，`screen.mov` 128.975s 且 ffprobe 可读。
- 修复复验：utility 真实响应再次只有 reasoning；后端记录 `using local fallback`，首条用户请求生成标题。
  UI、SQLite、REST、notifications SSE 的标题一致；主助手回复和三路 SSE durable close 均完成。
- 逐帧结果：抽查 onboarding、Shell 过渡、流式中间态、完成态；未发现已有内容漂移、composer 被遮挡、
  视口抢夺、骨架闪现或完成后仍停留 `New chat`。前端仅有已分类的 macOS runner/platform 噪声，无 Dart/Flutter
  异常；后端无未解释 WARN/ERROR/panic/fatal。
- 本切片已通过 `judge.py` 独立登记 `EDGE-325 空工作区名册`、`EDGE-326 首启创建过渡`、`SURF-003
  shell/workspace-onboarding`、`SURF-010 chat/landing`、`SURF-011 chat/transcript` 各五格；每格均有
  独立法条与证据指针。`SURF-012 chat/composer` 尚未因未走过附件、mention、工作目录、git 和流式输入而裁决。
  证据目录：`/tmp/anselm-rig-formal-20260801-3/evidence/`；裁决 journal：
  `/tmp/anselm-rig-formal-20260801-3/judgments.jsonl`。
- 批次前线：`25 / 50`；尚未运行长门禁、完整 testend、警报复核或提交，继续留在同一批次。

## 2026-08-01 · composer 模态焦点缺陷修复与真实复验

- 缺陷：真实会话 `/tmp/anselm-rig-formal-20260801-4/sessions/20260801-013602` 中，从驻地菜单打开「新建分支」后，
  对话框没有取得键盘焦点；直接输入的 `acceptance-ui-probe` 落进了背后的 composer。前线冻结，未判 composer 或 git 格。
- 根因：`AnMenu` 在 action 前关闭 `AnPopover`，而 popover 退场动画结束时才把焦点归还原触发器，后者覆盖了新模态的
  初始焦点；命名模态单靠 `autofocus` 也不足以对抗 `RawDialogRoute` scope 时序。
- 修复：`AnPopoverController.closeAndWait()` 以退场动画和焦点归还为完成边界；普通 `AnMenuItem` 先跨过该边界再执行
  action，`keepOpen` 保持原语义；`anPanelRoute` 不再先抢内容字段焦点；`ChatGitNameDialog` 持有自己的 `FocusNode` 并在首帧后显式请求。
- 守卫：`chat_work_dir_button_test.dart` 增加「打开命名模态后 EditableText 必须 hasFocus 且输入落入该 controller」断言；
  `flutter test` 运行 `chat_work_dir_button_test.dart`、`an_menu_test.dart`、`an_dialog_test.dart`，48 项全绿。
- 真实复验：新会话 `/tmp/anselm-rig-formal-20260801-4/sessions/20260801-015325` 重新启动真实 App；Computer Use 直接输入
  `acceptance-ui-probe` 后 AX 明确报告 focused element 为模态 text field，截图显示光标与文本均在字段内；点击 Cancel 后 composer 未被污染。
  证据：`/tmp/anselm-rig-formal-20260801-4/evidence/git-dialog-focus-fixed.png`、`git-dialog-focus-fixed-ax.txt`、
  `git-dialog-focus-fixed.txt`。
- 通道：后端无 WARN/ERROR/panic/fatal；SSE 与 conductor 均存活；Flutter journal 仅保留 macOS runner/IMK 与
  accessibility bridge 平台噪声，未发现 Dart exception。该噪声继续作为前端台架观察项，不拿它冒充产品绿灯。
- 批次前线：仍为 `25 / 50`；本修复未新增 COVERAGE 裁决，继续沿 `SURF-012` 完整切片推进。

## 2026-08-01 · composer 完整切片收尾与 mention 真实复验

- 新台架会话：`/tmp/anselm-rig-formal-20260801-4/sessions/20260801-015325`；由同一 conductor 托管真实 App、
  Flutter console、屏幕录像、后端、动态全 workspace SSE tap 与 LLM tap；收台后 `screen.mov` 已封口，
  `ffprobe` 时长 `1201.320000s`，五通道 journal 均存在。
- 附件路径：从 composer 附件菜单进入原生文件选择器，选取 `anselm-acceptance-attachment.txt`，看到 `TXT · 91 B`
  预览 chip，发送后助手准确回读文件名和原句；附件完成态截图/AX 证据在
  `/tmp/anselm-rig-formal-20260801-4/evidence/composer-attachment-final.*`。
- mention 路径：先用后端创建最小 function fixture `mention-fixture-fn`，再从 composer 输入 `@mention`；候选面板正确出现，
  选择后变成蓝色 `@mention-fixture-fn` 药丸，发送后 messages SSE 写入用户消息和 `mentioned` touchpoint，LLM wire
  收到函数摘要，助手随后通过 `get_function` 回读并正确回答。候选/完成态证据在
  `/tmp/anselm-rig-formal-20260801-4/evidence/composer-mention-{candidate,final}.*`。
- 工作目录与 git 路径：隔离临时仓库中真实创建并切换分支，菜单显示仓库路径、分支和 clean 状态；随后在同一会话发送
  `pwd` 核验请求，助手返回 `/private/tmp/anselm-acceptance-git-fixture`，证明驻地状态、git 动作和聊天上下文连续。
- 数据核对：SSE durable seq 单调，`function.created`、`mentioned` touchpoint、`get_function` tool call/result、
  assistant close 均在 journal；后端无未解释 WARN/ERROR/panic/fatal。Flutter journal 有 1091 条 macOS
  `accessibility_bridge` AXTree 平台红行及一条 foreground/IMK 平台行，没有 Dart/Flutter framework exception；该噪声
  明确留作台架观察项，本轮 `SURF-012` L2 只援引 F2，不用 F3 冒充 console 零红行。
- `judge.py` 已独立落账 `SURF-012 chat/composer` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`；
  批次从 `25 / 50` 推进到 **30 / 50**。下一前线为 `SURF-013 chat/toc`，未到 50 格不跑批次长门禁、不提交。

## 2026-08-01 · chat/toc 全量 keyset 分页与深跳复验

- 新台架会话：`/tmp/anselm-rig-formal-20260801-5/sessions/20260801-021909`；真实 App、受管网关、Computer Use
  录屏、后端、三路 SSE tap、LLM tap 均由同一 conductor 托管，收台后 `screen.mov` 封口时长 `937.505s`。
- 构造数据：通过真实 composer 逐轮发送 `TOC fixture turn 001` 至 `turn 051`，每轮重新读取 AX、等待助手终态再发下一轮；首轮
  误触发 `ask_user`，在 UI 内回答后正常收尾。后端 `GET /anchors?limit=50` 返回第一页 50 条 `hasMore=true`，续页 2 条
  `hasMore=false`；场次条 AX 全量包含最新 `turn 051`、最早 `turn 001` 与折叠的 10 operations 行，证明 provider 循环拉完
  keyset 页而非停在第一文页。
- 逐帧路径：打开 Scenes 后场次条呈 newest-first 时间线；点击最早 `turn 001` 整扇替换 transcript 窗并显示 `Jump to present`；
  点击中段 `turn 027` 同样以目标为中心深跳；点击回到现场恢复最新 `turn 051`，未出现历史拼接、视口抢夺或假终态。
- 五通道：SSE journal 2550 行且三流均有 connect；LLM journal 192 行、128 个状态记录全为 200；后端无 panic/FATAL/WARN/ERROR；
  Flutter journal 只有 macOS foreground/IMK 平台行，无 Dart/Flutter framework exception。完整证据在
  `/tmp/anselm-rig-formal-20260801-5/evidence/`，包括 `toc-full-list.png`、`toc-mid-jump.png`、`toc-jump-present.png`、
  对应 AX 文本和 session summary。
- `judge.py` 已独立落账 `SURF-013 chat/toc` 五格：L1 `G1`、L2 `F2`、L3 `B2`、L4 `C4`、L5 `G2`；批次从 `30 / 50`
  推进到 **35 / 50**。下一前线为 `SURF-014 chat/log-drawer`，未到 50 格不跑批次长门禁、不提交。

## 2026-08-01 · SURF-014 日志抽屉 stop-and-fix 与真实复验

- 前置冻结：旧会话 `/tmp/anselm-rig-formal-20260801-7/sessions/20260801-024012` 在长失败日志展开/滚动时出现重复的
  `accessibility_bridge.cc` AXTree 红行；同时红色失败摘要被中间日志行占满，用户看不到尾部的真实 traceback。该格未判绿。
- 修复：`frontend/lib/features/chat/ui/tool_card_exec.dart` 将 `ExecutionResult.errorMsg` 与 tool-result 独立 `error` 字段
  合并到同一条 20 行 head+tail 摘要路径；`frontend/lib/features/chat/ui/tool_card_catalog.dart` 将 `run_function`
  标为 `ownsError`，底盘不再重复追加无界原文；`frontend/test/features/chat/ui/tool_card_exec_test.dart` 新增硬错误单次呈现
  与长失败尾部保留守卫。目标 Flutter widget suite 21 项全绿，`git diff --check` 全绿。
- 修复后真实会话：`/tmp/anselm-rig-formal-20260801-8/sessions/20260801-030652` 由 conductor 托管真实 App、受管网关、
  Computer Use、屏幕录制、后端、三路 SSE tap 和 LLM tap；真实完成成功函数日志、长失败函数日志、MCP 失败 dossier、stderr
  抽屉展开和 Copy→Copied。画面证据在 `/tmp/anselm-rig-formal-20260801-8/evidence/`，包含四组 PNG/AX 文本及
  `surf-014-session-summary.txt`。
- 五通道收台结果：`frontend.log` 无 Flutter/Dart/AXTree/RenderFlex 错误；`backend.log` 无 WARN/ERROR/panic/FATAL；LLM
  journal 42 条记录中的 28 个 HTTP 响应全为 200；entities/messages/notifications 三流分别记录 8/66/11 个 durable 帧，
  各流序列单调、无回退；`screen.mov` 时长 `469.55s`，六件 L2 journal 均真实存在且可读。
- `judge.py` 已独立落账 `SURF-014 chat/log-drawer` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`；批次从 `35 / 50`
  推进到 **40 / 50**。下一格从 COVERAGE 当前首个未裁决项读取；未到 50 格不跑批次长门禁、不提交。

## 2026-08-01 · TOOL-001 Read 真实工具切片

- 新台架会话：`/tmp/anselm-rig-formal-20260801-9/sessions/20260801-032022`；真实 App、受管网关、Computer Use、屏幕录像、
  后端、三路 SSE tap 和 LLM tap 由同一 conductor 托管。
- 构造数据：在真实 workspace 驻地 `/tmp/anselm-read-fixture-9` 创建 notes.txt、paged.txt、嵌套文件和干扰文件；真实对话中
  调用 Read 默认整读与 `offset=2 limit=2`，画面准确展示四行编号、分页行 `2–3+` 和截断语义；随后验证不存在文件的人话错误，以及
  `/etc/hosts` 越界请求被安全 guard 拒绝并在 UI 呈现原因。
- 五通道收台：`frontend.log` 无 Flutter/Dart/AXTree/RenderFlex 错误；`backend.log` 无 WARN/ERROR/panic/FATAL；LLM journal
  27 条记录中的 18 个 HTTP 响应全为 200；notifications/messages/entities 均连接，观察到 durable 2/46/0 帧，所有观察到的
  stream seq 单调无回退；`screen.mov` 时长 `203.135s`。证据在 `/tmp/anselm-rig-formal-20260801-9/evidence/`，包括
  `read-tool-final.png`、AX 文本和 `tool-001-read-session-summary.txt`。
- `judge.py` 已独立落账 `TOOL-001 Read` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`；批次从 `40 / 50` 推进到 **45 / 50**。
  下一前线为 `TOOL-002 Write`；未到 50 格不跑批次长门禁、不提交。

## 2026-08-01 · TOOL-002 Write 真实工具切片与 stop-and-fix

- 新台架会话：`/tmp/anselm-rig-formal-20260801-12/sessions/20260801-033935`；真实 App、受管网关、Computer Use、屏幕录像、
  后端、三路 SSE tap 和 LLM tap 由同一 conductor 托管，收台后 `screen.mov` 时长 `220.8s`，六件 L2 journal 均真实存在且可读。
- 构造数据：驻地 `/tmp/anselm-write-fixture-12` 中的 `existing.txt` 预置为 `ORIGINAL_CONTENT`。真实请求要求只调用一次 Write
  覆盖而不先 Read；SSE/持久事实确认实际只有 1 次 Write、0 次 Read，后端安全闸拒绝覆盖，磁盘内容保持不变。
- 首轮真实缺陷：后端按契约以 `tool_result status=completed + refusal string` 返回安全拒绝；前端虽已有红色 `fsErrorReceipt`，但主行仍
  渲染成功动词 `Wrote existing.txt · read first`，造成“红色拒绝旁的假成功语义”。前线冻结，未把首轮当成产品通过。
- 修复：`ToolCardSpec` 增加失败动词通道；文件系统拒绝由 `fsErrorKind` 触发 `resultFailed` 重分类；`ChatToolCard` 对 payload failure
  使用 `failedVerb`，因此画面改为 `Write failed existing.txt · read first`。新增 completed-refusal widget 守卫；Flutter 正确测试链
  `tool_card_write_test.dart`、`chat_tool_card_test.dart`、`tool_card_family_test.dart` 共 23 项全绿，`dart format` 通过。
- 修复后逐帧复验：证据 `/tmp/anselm-rig-formal-20260801-12/evidence/write-refusal-fixed.png`、AX 文本和
  `tool-002-write-session-summary.txt`；画面没有 `Wrote`，拒绝散文清楚可见；SSE 各流 durable seq 单调（notifications 1–2、
  messages 1–14），LLM tap 状态全 200，backend/frontend 无 WARN/ERROR/panic/FlutterError/RenderFlex/Unhandled Exception。
- `judge.py` 已独立落账 `TOOL-002 Write` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`；批次从 `45 / 50` 推进到 **50 / 50**。
  按 P15 现在进入统一 `alarms.py check`、完整门禁、完整 testend、修复场景回归、工作树审计和提交；门禁未完成前不提交。

## 2026-08-01 · 首批长门禁 stop-and-fix

- 批次达到 `50 / 50` 后先运行 `alarms.py check`。历史裁决的时间间隔过快与发现率塌方两条警报均经过证据审计后写入复核结论并销账；销账后警报检查干净，未绕过 gate。
- `make verify` 首轮真实暴露两类回归：`AnNodeGantt` 在 150px 宽度的标签列加间距超过可用行宽并产生多个 RenderFlex overflow；`AnMenu` 将普通命令绑定到不稳定的退场动画 Future，造成 PanelHead、Workflow Editor 与 Scheduler 的动作在固定帧窗口内不执行。
- 修复：Gantt 标签列通过 `LayoutBuilder` 在窄宽度让出轨道空间，极窄态隐藏不可容纳的标签内容，并把窄屏测试升级为“无任何异常”守卫；菜单改为先发起退场、同一事件循环执行用户命令，`AnPopover` 仅在浮层仍持焦时恢复触发器焦点，Dialog 焦点不被抢回。
- 快速回归：Gantt 3 项、PanelHead、Workflow Editor add-node、Scheduler kill-confirm、AnMenu WCAG 焦点用例均通过。随后完整 `make verify` 通过：backend、frontend 全量（core/group2/group3）、docs、demo 全绿。
- 当前状态：长门禁已通过，正在进入完整 `make -C backend testend`、修复场景回归和工作树审计；仍未提交。
- 完整黑盒 `make -C backend testend` 通过（scenarios `319.533s`）；根级 `cd testend && mise exec -- go test -count=1 ./...` 通过（scenarios `323.535s`，同时覆盖 cmd/golden/harness/proxycore）。
- `alarms.py check` 再次确认 `clean (50 judgments on record)`；`git diff --check` 与 `python3 -m py_compile testend/rig/*.py` 通过。
- 文档同步后的最终 `make verify` 再次全绿：backend、frontend 全量、docs、demo；当前长门禁与 testend 均收口，进入工作树审计和提交。

## 2026-08-01 · 修复场景真实 App 回放

- 回放会话：`/tmp/anselm-rig-formal-20260801-13/sessions/20260801-042830`。使用最新构建真实启动 Flutter App，受管网关经 llmtap 接线，ssetap 动态接入 workspace 的三路 SSE，屏幕录像和前端 console 均由同一 conductor 托管；收台录像 `168.430s`，无残留进程。
- 真实路径一：Settings → Models & keys → Dialogue → Change → Anselm Auto。逐帧确认菜单展开、选项文本完整、选择后菜单收起，未出现焦点丢失或 action 延迟；证据 `evidence/model-menu-open.png` 与 `model-menu-closed.png`。
- 真实路径二：构造 `Gantt visual probe` workflow 后进入 Entities → Workflow → Overview，确认真实 Gantt 节点卡片、连线、右侧 run terminal 和左侧实体导航均稳定；证据 `evidence/gantt-real.png`。
- 五通道：llmtap 记录的 8 个响应全为 HTTP 200；backend journal 无 WARN/ERROR/panic；frontend journal 无 Dart/Flutter/RenderFlex/Unhandled Exception，唯一 `error messaging the mach port for IMKCFRunLoopWakeUpReliable` 为已知 macOS 输入法平台噪声；三路 SSE 均真实连接但本回放未触发 durable 业务帧，不能将其记作业务流覆盖。
- 该回放只作为已修场景回归证据，不新增 COVERAGE 格子；当前批次 50/50，全部长门禁和真实回放均通过，下一步仅剩最终工作树审计与提交。
