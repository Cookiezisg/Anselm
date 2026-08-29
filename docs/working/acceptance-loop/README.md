---
id: WRK-087
type: working
status: active
owner: "@weilin"
created: 2026-07-27
reviewed: 2026-08-14
review-due: 2026-10-30
audience: [human, ai]
landed-into:
---

# WRK-087 · 端到端全产品验收循环(acceptance loop)

## 调度变更（2026-08-30 · 用户授权：人工交互统一后置）

- 用户已明确授权：需要用户物理按键、系统授权或安全确认的验收动作统一放到自主验收完成后再做；主循环现在只推进不依赖用户的代码、接口、真实 App、五通道和视觉验证，不再因这类动作停住等待用户。
- 这不是降低标准，也不是把格子判为 `na`：人工格仍保持未完成，最终必须用真实动作和原五通道证据收口。精确队列由 `testend/rig/ledger-sequence.json` 的 `manual_queue` 控制，损坏即 fail-closed；当前登记的是 `EDGE-031|回合收尾期单槽缓冲`、`EDGE-030|生成中再 Send`、`EDGE-033|关页不留 streaming 孤儿`、`EDGE-037|归档对话发消息自动解档`、`EDGE-038|:retry 重生成分支`、`EDGE-039|:retry 编辑重发分支`、`EDGE-251|删最后一个 workspace`、`EDGE-254|keyset 排序切换丢游标`、`EDGE-256|驻地目录被移走`、`EDGE-257|脏区切分支被拒`、`EDGE-258|新建分支不受脏区门`、`EDGE-259|切分支名拼错` 与 `EDGE-329|快捷键录制后吞键`。
- `judge.py` 的顺序门只在人工队列中有明确条目时跳过该条，先推进自主格；自主格耗尽后自动回到人工队列。现有 `~` 裁决仍表示已记录的不适用，不会被调度规则重解释。
- 台架回归：`python3 -m unittest testend/rig/test_judge.py -v`、JSON 校验和 `py_compile` 均通过。当前批次已推进至 `50/50`（在前述 14 格基础上，补齐 EDGE-032 的 2 格、EDGE-034/035/036 的 6 格，以及 EDGE-252 的 4 格适用性格），统一长门禁已通过并已记录完整 testend 结果；标准、法典、证据要求和最终收口条件不变。

## 当前自动前线重述（2026-08-30 · 50 格批次统一门禁通过；继续自主前线）

- 为防止“缺现场证据”被误当成不适用，`judge.py` 现只把明确不适用的 `~` 视为 settled；凡备注承认尚无真实 App/session、独立时延/顺滑、视觉 craft 或可发现性证据的格子，都会重新进入正式顺序门。标准、五级判据和最终收口条件没有降低。
- 新语义扫描当前清册后，仍有 `82` 个自主未收口项目行（`254` 个未收口单元）；人工队列中的 `EDGE-031|回合收尾期单槽缓冲`、`EDGE-030|生成中再 Send`、`EDGE-033|关页不留 streaming 孤儿`、`EDGE-037|归档对话发消息自动解档`、`EDGE-038|:retry 重生成分支`、`EDGE-039|:retry 编辑重发分支`、`EDGE-251|删最后一个 workspace`、`EDGE-254|keyset 排序切换丢游标`、`EDGE-256|驻地目录被移走`、`EDGE-257|脏区切分支被拒`、`EDGE-258|新建分支不受脏区门`、`EDGE-259|切分支名拼错`、`EDGE-261|worktree 目录已存在`、`EDGE-262|worktree 分支已存在`、`EDGE-263|worktree 建成后切驻地失败`、`EDGE-264|「这里没有 git」四情形`、`EDGE-265|切驻地落 marker 块`、`EDGE-266|空线程/重复 PATCH 不落 marker`、`EDGE-267|切分支不落 marker`、`EDGE-268|驻地分组批量归档重跑` 与 `EDGE-329|快捷键录制后吞键` 继续后置。此前尝试越过 `EDGE-251` 直接写 EDGE-040 被正式顺序门拒绝；`EDGE-253|单连接 panic 事务砖化` 与 `EDGE-255|PageAsc collation 不一致` 已完成普通/race 回归及四格适用性复核，`EDGE-254` 的 L2 已完成契约验证、L3-L5 留在人工队列，`EDGE-256/257/258/259` 保留完整 L2-L5 现场验收；`EDGE-260|前导 - 的合法 ref` 已完成安全 seam 的普通/race 与黑盒回归，并以具体适用性理由收口 L2-L5，未把上层分支错误体验冒充完成；`EDGE-261|worktree 目录已存在` 的普通/race 与黑盒回归通过，但用户可见冲突反馈、视觉和发现性保留人工验收；`EDGE-262|worktree 分支已存在` 的普通/race 与黑盒回归通过，恢复路径的用户反馈、视觉和发现性保留人工验收；`EDGE-263|worktree 建成后切驻地失败` 的故障注入、普通/race 与黑盒回归通过，但半成功状态的用户反馈、恢复指引、视觉和发现性保留人工验收；`EDGE-264|「这里没有 git」四情形` 的普通/race 与黑盒三态写动作回归通过，未宣称当前机器上未复现的无 Git 可执行文件变体已通过；`EDGE-265|切驻地落 marker 块` 的普通/race 与真实黑盒回归通过，但历史 marker 的用户呈现、视觉和发现性保留人工验收；`EDGE-266|空线程/重复 PATCH 不落 marker` 的普通/race 与真实黑盒回归通过，但无痕 no-op 的用户反馈、视觉和发现性保留人工验收；`EDGE-267|切分支不落 marker` 的普通/race 与真实黑盒回归通过，但切分支后的用户反馈、视觉和发现性保留人工验收；`EDGE-268|驻地分组批量归档重跑` 的普通/race 与真实黑盒回归通过，但批量归档的确认反馈、视觉和发现性保留人工验收。下一自动前线由顺序门重新计算。
- 先前 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-005803` 已证明旧缺陷：`run_function` 的 `ok:false + errorMsg` 被 loop 当作 transport 成功，durable `tool_result` 错写为 `status=completed/error=''`，模型把三次调用合并在一个模型步骤，最终 `assistant=completed/end_turn`。本 session 不写 pass，保留为修复前证据。
- loop 修复已落地：标准业务失败信封现在统一写成 `tool_result status=error/error`，保留完整 JSON 回执；`TestRun_ToolErrorStorm_BusinessFailureEnvelope` 与 SQLite round-trip 回归已通过。随后真实复验 session=`/private/tmp/anselm-rig-formal-20260830-012238` 证明三次真实独立 ReAct 失败会产生 `assistant=error/TOOL_ERROR_STORM`、三张 durable error tool_result 和连续失败熔断，但该 session 在 live transcript 中暴露第二个竞态：REST 水化已经占据 settled 根节点时，迟到的 `message_stop` 被完整跳过，导致界面未即时显示终态提示，冷重载后才显示。
- 已停止推进并修复第二个竞态：`ConversationTranscript.applyFrame` 现在对 settled message 根合并 durable close 的 status/error/content，并递增 revision 令落定行身份缓存失效，不创建重复 live 节点；新增纯模型回归锁定 `TOOL_ERROR_STORM` 终态元数据不会丢失。r6 clean session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-013849` 已证明实时和切换后水化画面均展示终态提示；正式证据=`testend/rig/formal-evidence/EDGE-007-tool-error-storm-real-app-20260830.md`，`judge.py` 写入 `L2 ✓ (F1)` 与 `L3 ✓ (B2)`，清册=`✓✓✓✓~`。
- 该真实复验的 L3 以 139 个 1fps 样本和 `measure diff` 收口，末 13 秒无超过 `0.0005` 的非用户变化；L5 仍明确不适用。警报独立复审=`testend/rig/formal-evidence/EDGE-007-ledger-alarm-reaudit-20260830.md`，anchors=`10/10`，`alarms.py check`=`clean (2036 live judgments; 2300 baseline judgments excluded from drift curves)`。
- `RIG_HOME` 下的 session journals 已保留，前线继续只推进不需要用户物理交互的格子；需要点击、按键、系统授权或安全确认的动作不再打断主循环，待自主格耗尽后才回收。
- `EDGE-013` 已完成一次真实 App 非正式探针：台架五通道接通，模型成功执行 seed 函数的原生 object 形态；但两次前置 Computer Use 输入改写了目标 ID/JSON，留下真实 `WARN`，且没有产生 stringified-object wire，因此该 session 仅作非正式/负证据，未写正式 pass。证据=`testend/rig/formal-evidence/EDGE-013-objectmap-real-app-nonqualifying-20260830.md`。
- 复核确认 `ObjectMap` 是 loop 内部的编码兼容边界，不是独立用户入口或独立业务状态；L2（无本条独有持久状态）、L3（无独立反馈时延/动效）、L4（无独立视觉表面）、L5（不可单独评估发现性）已用具体适用性理由正式记为 `na`，L1 保持 focused test pass。`EDGE-013` 整行现为 `✓~~~~`，警报复核=`testend/rig/formal-evidence/EDGE-013-ledger-alarm-reaudit-20260830.md`；标准未降低，已有明确适用性收口的 `EDGE-014` 至 `EDGE-020` 由顺序门自动跳过。
- `EDGE-021..028` 已完成独立适用性复核：删除授权、workdir 安全闸、skill trust gate、非交互 `ask_user` 和 interaction action/幂等边界的 focused 与 race 测试均通过；这些内部 seam 的 L3-L5 以具体理由记 `na`，没有替代对应用户旅程的真实体验验收。证据=`testend/rig/formal-evidence/EDGE-021-028-ledger-alarm-reaudit-20260830.md`。
- `EDGE-029` 已完成独立适用性复核：普通与 race 测试确认重复 resolve 返回 `NO_PENDING_INTERACTION` 且无副作用；新增 L2/L3 适用性记录，既有 L1/L4/L5 结论保持不变。证据=`testend/rig/formal-evidence/EDGE-029-ledger-alarm-reaudit-20260830.md`。
- `EDGE-032` 已完成独立适用性复核：普通与 race 测试确认 idle queue teardown 后再次发送会创建新 queue、完成收尾且不复用旧 task；L2/L3 以具体理由记 `na`，既有 L1/L4/L5 结论保持不变。证据=`testend/rig/formal-evidence/EDGE-032-ledger-alarm-reaudit-20260830.md`。
- `EDGE-034` 已完成独立适用性复核：普通与 race 测试确认 boot sweep 按 workspace 将 pending/streaming 孤儿收为 cancelled，并保留 cancelled block；L2/L3 以具体理由记 `na`，既有 L1/L4/L5 结论保持不变。证据=`testend/rig/formal-evidence/EDGE-034-ledger-alarm-reaudit-20260830.md`。
- `EDGE-035` 已完成独立适用性复核：普通与 race 测试确认标题生成耗尽预算后仍使用独立 detached 持久化预算落盘；L2/L3 以具体理由记 `na`，既有 L1/L4/L5 结论保持不变。证据=`testend/rig/formal-evidence/EDGE-035-ledger-alarm-reaudit-20260830.md`。
- `EDGE-036` 已完成独立适用性复核：普通与 race 测试确认首次标题写入失败后只做一次有界重试、不重复调用模型且最终落盘；L2/L3 以具体理由记 `na`，既有 L1/L4/L5 结论保持不变。证据=`testend/rig/formal-evidence/EDGE-036-ledger-alarm-reaudit-20260830.md`。
- 本轮触发的 `pass-burst` 与 `discovery-collapse` 已按 EDGE-032/252 复核证据销账；期间发现并修复 `alarms.py ack` 未推进 `evidenceThrough` 的 gate 缺陷，新增 `test_ack_advances_watermark_and_check_does_not_reopen` 回归后实际告警重新销账。当前 `alarms.py check`=`clean (2062 live judgments; 2300 baseline judgments excluded)`，anchors=`10/10`。没有修改阈值、算法、CODEX 法条、锚点集、顺序 gate 或五级标准。
- 完整 `make -C backend testend` 已通过（`testend/scenarios`，314.808s）。全量场景首次暴露并修复一处真实产品数据缺陷：`run_function` 返回结构化 `ok:false + errorMsg` 时，工具确已执行但 touchpoint 台账被错误漏记；现保持 `tool_result=error` 与熔断语义，同时按“执行事实”记入 executed touch，新增单测与 race 覆盖，定向场景复验通过。
- `EDGE-253|单连接 panic 事务砖化` 的 `TestTransaction_PanicRollsBackAndFreesConnection` 普通与 race 回归通过；其 L2-L5 均经具体适用性理由复核为 `na`，并单独完成告警复审后保持 clean。`EDGE-254|keyset 排序切换丢游标` 的 ORM 普通/race 与 HTTP acceptance 回归通过，L2 已按无独立持久状态收口；L3-L5 保留到人工队列。`EDGE-255|PageAsc collation 不一致` 的 ORM NOCASE/tie-breaker/cursor 普通与 race 回归通过，L2-L5 以内部 seam 适用性理由收口，并完成告警复审。`EDGE-256|驻地目录被移走` 的 conversation/shell 普通与 race 回归通过，因 L2-L5 都属于真实 App/Terminal 现场语义，整项转入人工队列，不做适用性降级。`EDGE-257|脏区切分支被拒` 的 conversation service/HTTP 普通与 race 回归通过，拒绝文案与用户现场反馈仍完整后置。`gen_coverage.py` 已同步 `848` 行，下一自动前线待顺序门重新计算。
- `EDGE-257|脏区切分支被拒`、`EDGE-258|新建分支不受脏区门` 与 `EDGE-259|切分支名拼错` 的 conversation service/HTTP 普通与 race 回归通过；三项的拒绝/放行文案、用户现场反馈、视觉和发现性仍完整后置。`gen_coverage.py` 已同步 `848` 行，下一自动前线待顺序门重新计算。
- `EDGE-260|前导 - 的合法 ref` 的 conversation service/HTTP 普通与 race 回归通过；该项是防止把合法 Git ref 误传为命令选项的内部安全 seam，不拥有独立持久状态、交互反馈、视觉表面或用户入口，L2-L5 以具体适用性理由记为 `na`。独立告警复审=`testend/rig/formal-evidence/EDGE-260-ledger-alarm-reaudit-20260830.md`，anchors=`10/10`，最终 `alarms.py check`=`clean`；下一自动前线为 `EDGE-261|worktree 目录已存在`。
- `EDGE-261|worktree 目录已存在` 的 conversation service 普通/race 与真实黑盒 `TestChatWorkDirGit_WorktreeOneShot` 回归通过；已有目录返回 `CONVERSATION_WORKTREE_EXISTS`，`details.path` 指向实际冲突目录，驻地不移动且不重复写 marker。其真实 App 冲突反馈、视觉和发现性仍需五通道现场观察，故整项进入人工后置队列，不作 `na` 降级。独立复核=`testend/rig/formal-evidence/EDGE-261-ledger-alarm-reaudit-20260830.md`；下一自动前线为 `EDGE-262|worktree 分支已存在`。
- `EDGE-262|worktree 分支已存在` 的 conversation service 普通/race 与真实黑盒 `TestChatWorkDirGit_ReusesExistingBranch` 回归通过；已有 `wt/<name>` 分支会被复用，按主仓库兄弟规则创建 worktree 并切换对话驻地。恢复路径的真实 App 反馈、视觉和发现性仍需五通道现场观察，故整项进入人工后置队列，不作 `na` 降级。独立复核=`testend/rig/formal-evidence/EDGE-262-ledger-alarm-reaudit-20260830.md`；下一自动前线由顺序门重新计算。
- `EDGE-263|worktree 建成后切驻地失败` 的故障注入、conversation service 普通/race 与真实黑盒 worktree 回归通过；最后一步持久化失败时，已创建 worktree 保留、对话仍在旧驻地且不返回成功投影。半成功状态的真实 App 错误反馈、恢复指引、视觉和发现性仍需五通道现场观察，故整项进入人工后置队列，不作 `na` 降级。独立复核=`testend/rig/formal-evidence/EDGE-263-ledger-alarm-reaudit-20260830.md`；下一自动前线为 `EDGE-264|「这里没有 git」四情形`。
- `EDGE-264|「这里没有 git」四情形` 的 conversation service 普通/race 与新增黑盒 `TestChatWorkDirGit_NotARepoWriteActions` 普通/race 回归通过；未挂、已消失、普通目录三态下的 switch/create/add 三个写动作统一返回 `CONVERSATION_WORK_DIR_NOT_GIT_REPO`。无 Git 可执行文件的环境变体未在当前机器伪造验证；真实 App 错误反馈、视觉和发现性仍需五通道现场观察，故整项进入人工后置队列，不作 `na` 降级。独立复核=`testend/rig/formal-evidence/EDGE-264-ledger-alarm-reaudit-20260830.md`；下一自动前线为 `EDGE-265|切驻地落 marker 块`。
- `EDGE-265|切驻地落 marker 块` 的 conversation service 普通/race 与真实黑盒 `TestChatWorkDir_MidThreadSwitchLeavesADurableMarker` 普通/race 回归通过；marker 的 `from/to` 与持久驻地投影一致。历史 marker 的真实 App 呈现、视觉和发现性仍需五通道现场观察，故整项进入人工后置队列，不作 `na` 降级。独立复核=`testend/rig/formal-evidence/EDGE-265-ledger-alarm-reaudit-20260830.md`；下一自动前线由顺序门重新计算。
- `EDGE-266|空线程/重复 PATCH 不落 marker` 的 conversation service 普通/race 与真实黑盒 `TestChatWorkDir_MidThreadSwitchLeavesADurableMarker` 普通/race 回归通过；空线程首次挂载与同路径重复 PATCH 均无 marker、无生命周期动作，后续真实切换仍正常落 marker。无痕 no-op 的真实 App 反馈、视觉和发现性仍需五通道现场观察，故整项进入人工后置队列，不作 `na` 降级。独立复核=`testend/rig/formal-evidence/EDGE-266-ledger-alarm-reaudit-20260830.md`；下一自动前线为 `EDGE-267|切分支不落 marker`。
- `EDGE-267|切分支不落 marker` 的 conversation service 普通/race 与真实黑盒 `TestChatWorkDirGit_SwitchBranchMovesTheProjectionAndDirtyIsRefused` 普通/race 回归通过；分支投影跟随 Git、驻地保持不变且不产生 workdir marker。切分支后的真实 App 反馈、视觉和发现性仍需五通道现场观察，故整项进入人工后置队列，不作 `na` 降级。独立复核=`testend/rig/formal-evidence/EDGE-267-ledger-alarm-reaudit-20260830.md`；下一自动前线由顺序门重新计算。
- `EDGE-268|驻地分组批量归档重跑` 的 conversation service 普通/race 与真实黑盒 `TestChatWorkDirGroups_ArchiveWholeGroup` 普通/race 回归通过；首次只归档目标组，第二次返回 `archived=0` 且不重复发回声。批量归档的真实 App 确认反馈、视觉和发现性仍需五通道现场观察，故整项进入人工后置队列，不作 `na` 降级。独立复核=`testend/rig/formal-evidence/EDGE-268-ledger-alarm-reaudit-20260830.md`；下一自动前线由顺序门重新计算。
- `EDGE-030` 本轮只形成非合格真实探针：HTTP `409 STREAM_IN_PROGRESS` 和 App 内错误反馈均已观察，但 `rig-check` 因 `SecurityAgent/CoreServicesUIAgent` 覆盖录屏区域而拒绝，故未写 L2/L3 pass。session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-021449`，收台证据=`testend/rig/formal-evidence/EDGE-030-real-app-observed-but-overlay-blocked-20260830.md`；该项进入人工队列，标准不变。
- 自主验证余量：后端 `make verify` 全绿；前端 `make verify` 全绿（`5447` tests）；完整 `testend`、台架 `test_judge`、JSON、Python 编译、coverage clean、anchors `10/10`、alarms clean 均通过。当前 `50/50` 统一长门禁已通过；未完成的真实 App/系统交互格仍保持在人工队列，不被自动化绿灯冒充完成。
- `EDGE-031` 的后端/前端 queue 回归均通过，但第二次真实台架仍被同一系统遮挡阻断，未写 L2/L3 pass。session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-022738`，证据=`testend/rig/formal-evidence/EDGE-031-real-rig-blocked-by-system-overlay-20260830.md`；该项进入人工队列，标准不变。

## 最新收口（2026-08-29 · EDGE-327 workspace 热切换三拍 L3 完成 · 新批次 23/50）

- 真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-231929` 创建 source/target 两个 workspace 和真实对话；在 source 深链打开时切到 target，旧深链先离开、目标空 Chat 落地，稳定 `6s` 后切回 source，原对话仍可回访。正式证据=`testend/rig/formal-evidence/EDGE-327-workspace-hot-switch-l3-real-app-20260829.md`。
- `screen.mov`=`213.288333s / 3104x1846`，抽取 `101` 个 `1fps` 样本，黑帧检测零；workspace 菜单、目标 landing、源回访帧已封存。没有旧右岛/旧正文泄漏、跨 workspace 404 或非用户静止期跳变。
- 五通道通过：backend `368` 行，源读取、目标 `:activate` 和目标列表重取均 `200`；SSE 覆盖两个 workspace，messages durable `1..64`、notifications `1..2` 单调；frontend `4` 行仅已知 IMK 宿主诊断；LLM 真实 completion `200`；启动门和收台通过。
- 锚点=`10/10`；`judge.py` 写入 `EDGE-327 L3 ✓ (B2)`，清册=`✓✓✓~~`；独立复审=`testend/rig/formal-evidence/EDGE-327-workspace-hot-switch-l3-ledger-alarm-reaudit-20260829.md`，`discovery-collapse` 按原阈值复核销账，最终 `alarms.py check`=`clean (2034 live judgments; 2300 baseline judgments excluded)`，标准、阈值、法典和 gate 未改。
- 当前批次由 `22→23/50`；未满 50 不跑统一长门禁、不提交。L4/L5 保持 `na`，P12 的 400+ Journey 扩写按用户裁定推迟二期；下一原子由 formal sequence gate 选择下一未完成等级。

## 最新收口（2026-08-29 · EDGE-324 窗角半径 swizzle 失效 L3 完成 · 新批次 22/50）

- 真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-231353` 已完成临时工作区创建及 Chat、Entities、Library、Settings 往返；Settings 稳定静置 `5s`，没有崩溃、黑屏、白屏、窗口消失或静止期内容跳变。正式证据=`testend/rig/formal-evidence/EDGE-324-window-corner-swizzle-fallback-l3-real-app-20260829.md`。
- 窗口录制 `105.198333s / 3104x1846`，`blackdetect` 零黑段，`1fps` 样本和 Computer Use AX 状态一致。L2 的私有 getter 故障注入继续由既有证据覆盖；本格 L3 只证明降级路径进入真实 App 后的动态稳定性，不把正常构建冒充故障注入。
- 五通道和录屏收台通过：backend `175` 行无应用级红线；frontend `5` 行仅已知 IMK 宿主诊断；SSE 三流正常连接并 EOF；LLM 仅 challenge/install/models 台架生命周期，本格无 completion。启动门、窗口归属和 `rig-down.sh` 均通过。
- 锚点=`10/10`；`judge.py` 写入 `EDGE-324 L3 ✓ (B2)`，清册=`✓✓✓~~`；独立复审=`testend/rig/formal-evidence/EDGE-324-window-corner-swizzle-fallback-l3-ledger-alarm-reaudit-20260829.md`，`discovery-collapse` 按原阈值复核销账，最终 `alarms.py check`=`clean (2033 live judgments; 2300 baseline judgments excluded)`，标准、阈值、法典和 gate 未改。
- 当前批次由 `21→22/50`；未满 50 不跑统一长门禁、不提交。L4/L5 保持 `na`，P12 的 400+ Journey 扩写按用户裁定推迟二期；下一原子由 formal sequence gate 选择下一未完成等级。

## 最新收口（2026-08-29 · EDGE-323 进全屏白带 L3 完成 · 新批次 21/50）

- 复用真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-230609`，在用户已完成 Keychain 授权后的干净环境执行原生全屏进入与退出；Computer Use 的进入/退出 AX 状态正常，稳定帧没有 toolbar 白带、内容丢失、溢出或退出后卡死。
- 窗口绑定 `screen.mov` 为 `59.525000s / 3104x1844`；独立整屏 `evidence/display-screen.mov` 为 `38.333333s / 2880x1800`，`blackdetect` 零黑段。窗口 ID 采集在原生 transition 期间有唯一 `0.666667s` 黑段，已原样记录并与整屏结果交叉核对，判定为仪器盲区，不改产品代码、不隐瞒证据。正式证据=`testend/rig/formal-evidence/EDGE-323-fullscreen-white-band-l3-real-app-20260829.md`。
- 五通道与录屏收台通过：backend `112` 行无应用级红线；frontend `4` 行仅已知 IMK 宿主诊断；SSE 三流连接并正常 EOF；本格不触发 LLM completion。启动门、两次 `rig-check` 和 `rig-down.sh` 均通过。
- 锚点重新校准=`10/10`；`judge.py` 写入 `EDGE-323 L3 ✓ (B2)`，清册=`✓✓✓~~`；独立复审=`testend/rig/formal-evidence/EDGE-323-fullscreen-white-band-l3-ledger-alarm-reaudit-20260829.md`，`discovery-collapse` 按原阈值复核销账，最终 `alarms.py check`=`clean (2032 live judgments; 2300 baseline judgments excluded)`，标准、阈值、法典和 gate 未改。
- 当前批次由 `20→21/50`；未满 50 不跑统一长门禁、不提交。L4/L5 保持 `na`，P12 的 400+ Journey 扩写按用户裁定推迟二期；下一原子为 `EDGE-324` 的下一未完成等级。

## 最新收口（2026-08-29 · EDGE-322 应内缩放到顶 L3 完成 · 新批次 20/50）

- 复用真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-022508`，在设置→通用连续执行 `1.0×→1.1×→1.25×` 尝试→`1.0×` 恢复。
- 1fps/ROI=`500,100,2200,1200` 复核确认整界面变化均绑定用户点击；`1.1×` 内容完整，`1.25×` 保持禁用，恢复后没有二次重排、白带或溢出。正式证据=`testend/rig/formal-evidence/EDGE-322-in-app-zoom-cap-l3-real-app-20260829.md`。
- 五通道和录屏收台通过：backend `243` 行无应用级红线；frontend `3` 行无应用错误；SSE 三流连接且本机偏好路径无业务 durable 帧；LLM challenge/install/models 全 `200`。L4/L5 保持 `na`，没有把边界正确冒充视觉或发现性结论。
- `judge.py` 写入 `EDGE-322 L3 ✓ (B2)`，清册=`✓✓✓~~`；独立警报复审=`testend/rig/formal-evidence/EDGE-322-in-app-zoom-cap-l3-ledger-alarm-reaudit-20260829.md`，`discovery-collapse` 按原阈值销账，最终 `alarms.py check`=`clean (2031 live judgments; 2300 baseline judgments excluded)`；anchors=`10/10`，标准、阈值、法典和 gate 未改。
- 当前批次由 `19→20/50`；未满 50 不跑统一长门禁、不提交。P12 的 400+ Journey 扩写按用户裁定推迟二期；下一原子为 `EDGE-323` 的下一未完成等级。

## 最新收口（2026-08-29 · EDGE-321 草稿文档首次编辑 L3 完成 · 新批次 19/50）

- 复用真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-135745`，从空 `Untitled` 草稿离开/返回，首次输入 `EDGE321 body probe` 后继续输入 ` + continued`，再切换 Chat/Library 返回。
- 1fps/ROI=`760,250,1500,950` 复核确认首次创建、认领和页面切换变化均绑定用户动作；认领后约 `41s` 稳定段无 ROI 变化，正文、单一侧栏行和 `30 B` 属性保持稳定。正式证据=`testend/rig/formal-evidence/EDGE-321-draft-first-edit-l3-real-app-20260829.md`。
- 五通道和录屏收台通过：backend `240` 行无应用级红线；frontend `4` 行仅已知 IMK 宿主诊断；SSE 三流连接且 notifications durable `seq=16..17` 单调；LLM challenge/install/models 全 `200`。L4/L5 保持 `na`，没有把输入即创建冒充视觉或发现性结论。
- `judge.py` 写入 `EDGE-321 L3 ✓ (B2)`，清册=`✓✓✓~~`；独立警报复审=`testend/rig/formal-evidence/EDGE-321-draft-first-edit-l3-ledger-alarm-reaudit-20260829.md`，`pass-burst`/`discovery-collapse` 按原阈值销账，最终 `alarms.py check`=`clean (2030 live judgments; 2300 baseline judgments excluded)`；anchors=`10/10`，标准、阈值、法典和 gate 未改。
- 当前批次由 `18→19/50`；未满 50 不跑统一长门禁、不提交。P12 的 400+ Journey 扩写按用户裁定推迟二期；下一原子为 `EDGE-322` 的下一未完成等级。

## 最新收口（2026-08-29 · EDGE-320 skill 双写者竞态 L3 完成 · 新批次 18/50）

- 复用真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-134830`，在中心 body 与右侧 Arguments 同轮写入 `BODYCLEAN`/`cleanarg`，等待两个 600ms 防抖写入者收敛，离开并返回 skill。
- 1fps/ROI=`760,250,1850,950` 复核确认变化均绑定打开、输入、写入收敛或用户导航；返回后的稳定帧同时保留正文和参数，没有旧快照覆盖、空白恢复、页面重挂或晚到二次重绘。正式证据=`testend/rig/formal-evidence/EDGE-320-skill-dual-writer-window-l3-real-app-20260829.md`。
- 五通道和录屏收台通过：backend `199` 行无应用级红线；frontend `5` 行仅已知 IMK/Caps Lock 宿主诊断；SSE 三流连接且 notifications durable `seq=16..18` 单调；LLM challenge/install/models 全 `200`。L4/L5 保持 `na`，没有把最终一致冒充严格事务或视觉/发现性结论。
- `judge.py` 写入 `EDGE-320 L3 ✓ (B2)`，清册=`✓✓✓~~`；独立警报复审=`testend/rig/formal-evidence/EDGE-320-skill-dual-writer-window-l3-ledger-alarm-reaudit-20260829.md`，`pass-burst`/`discovery-collapse` 按原阈值销账，最终 `alarms.py check`=`clean (2029 live judgments; 2300 baseline judgments excluded)`；anchors=`10/10`，标准、阈值、法典和 gate 未改。
- 当前批次由 `17→18/50`；未满 50 不跑统一长门禁、不提交。P12 的 400+ Journey 扩写按用户裁定推迟二期；下一原子为 `EDGE-321` 的下一未完成等级。

## 最新收口（2026-08-29 · EDGE-319 大纲下标不变式 L3 完成 · 新批次 17/50）

- 复用真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-002006`，打开含 h1-h6、深层后续 h3、围栏/引用伪标题的夹具，逐个点击 8 个 Outline 入口并观察正文滚动和最终收敛。
- 1fps/ROI=`800,300,1500,1100` 复核确认文档首次出现与目录点击产生的变化均绑定用户动作；稳定帧保持 8 项目录、h1-h6 顺序和后续 h3 下标，无目录闪烁、重复重建、二次滚动或标题漂移。正式证据=`testend/rig/formal-evidence/EDGE-319-outline-heading-invariant-l3-real-app-20260829.md`。
- 五通道和录屏收台通过：backend `264` 行无应用级红线；frontend `3` 行仅启动信息；SSE 三流连接且 notifications durable `seq=16..23` 单调；LLM challenge/install/models 全 `200`。L4/L5 保持 `na`，没有把动态稳定性冒充美学或发现性结论。
- `judge.py` 写入 `EDGE-319 L3 ✓ (B2)`，清册=`✓✓✓~~`；独立警报复审=`testend/rig/formal-evidence/EDGE-319-outline-heading-invariant-l3-ledger-alarm-reaudit-20260829.md`，`pass-burst`/`discovery-collapse` 按原阈值销账，最终 `alarms.py check`=`clean (2028 live judgments; 2300 baseline judgments excluded)`；anchors=`10/10`，标准、阈值、法典和 gate 未改。
- 当前批次由 `16→17/50`；未满 50 不跑统一长门禁、不提交。P12 的 400+ Journey 扩写按用户裁定推迟二期；下一原子为 `EDGE-320` 的下一未完成等级。

## 最新收口（2026-08-29 · EDGE-318 原子块双/三击 L3 完成 · 新批次 16/50）

- 复用真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-000303`，对代码块、表格、分隔线分别执行双击/三击后拖动和退格探针，再离开/返回文档；长录屏中每个状态均可继续操作。
- 1fps/内容 ROI 审查确认变化都绑定用户手势或导航，稳定态没有视口跳变、overlay 残留、焦点丢失、第二个 caret 或相邻正文误删；没有把嵌入块未提供的“整块蓝色高亮”冒充为通过。证据=`testend/rig/formal-evidence/EDGE-318-atomic-block-tap-guard-l3-real-app-20260829.md`。
- 五通道、REST/SQLite 原始 `312 B`、原 session 收台均通过；backend `883` 行、frontend `5` 行、SSE 三流 durable 序列单调、LLM challenge/install/models 全 `200`，无未解释应用红线。
- `judge.py` 写入 `EDGE-318 L3 ✓ (B2)`，清册=`✓✓✓~~`；独立警报复审=`testend/rig/formal-evidence/EDGE-318-atomic-block-tap-guard-l3-ledger-alarm-reaudit-20260829.md`，`pass-burst`/`discovery-collapse` 按原阈值销账，最终 `alarms.py check`=`clean (2027 live judgments; 2300 baseline judgments excluded)`；anchors=`10/10`，标准、阈值、法典和 gate 未改。
- 当前批次由 `15→16/50`；未满 50 不跑统一长门禁、不提交。L4/L5 仍为 `na`，P12 的 400+ Journey 扩写按用户裁定推迟二期；下一原子为 `EDGE-319` 的下一未完成等级。

## 最新收口（2026-08-29 · EDGE-317 选区跨块缝隙 L3 完成 · 新批次 15/50）

- 复用真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-235053`，对三段文档从 Library 打开、离开、重开并用真实 `Shift+Down` 跨块选区；历史版本的块间白缝红证据保留，修复后二进制重新复验。
- 1fps/ROI `900,450,1500,900` 审查确认较大变化均绑定用户打开、导航、重开或拖选；最终稳定帧的主选区连通组件为 `x=832,y=530,w=540,h=216,pixels=68884`，蓝色桥接连续、段高一致、末段自然收束。证据=`testend/rig/formal-evidence/EDGE-317-selection-block-gaps-l3-real-app-20260829.md`。
- 五通道、REST/SQLite 字节真相、原 session 收台均通过；backend `539` 行、frontend `5` 行、SSE notifications durable `seq=16`、LLM challenge/install/models 全 `200`，无未解释应用红线。
- `judge.py` 写入 `EDGE-317 L3 ✓ (B2)`，清册=`✓✓✓~~`；独立警报复审=`testend/rig/formal-evidence/EDGE-317-selection-block-gaps-l3-ledger-alarm-reaudit-20260829.md`，`pass-burst`/`discovery-collapse` 按原阈值销账，最终 `alarms.py check`=`clean (2026 live judgments; 2300 baseline judgments excluded)`；anchors=`10/10`，标准、阈值、法典和 gate 未改。
- 当前批次由 `14→15/50`；未满 50 不跑统一长门禁、不提交。L4/L5 仍为 `na`，P12 的 400+ Journey 扩写按用户裁定推迟二期；下一原子为 `EDGE-318` 的下一未完成等级。

## 最新收口（2026-08-29 · EDGE-316 行内代码 CJK 断盒 L3 完成 · 新批次 14/50）

- 复用真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-231212`，对行内中文代码首次出现、稳定阅读、离开和重开做 60fps 录屏的 1fps/内容 ROI 审查；CJK script-run 间灰底连续，前后普通文字未被遮挡或粘连。
- ROI=`900,500,1250,320` 的大变化均落在打开、离开和重开这些用户动作窗口；稳定态没有晚到背景、二次宽度抖动或既有内容位移。证据=`testend/rig/formal-evidence/EDGE-316-inline-code-cjk-l3-real-app-20260829.md`。
- 五通道、REST/SQLite 文档真相和原 session 收台均通过；backend `181` 行、frontend `3` 行、SSE notifications durable `seq=16`、LLM challenge/install/models 全 `200`，无未解释应用红线。
- `judge.py` 写入 `EDGE-316 L3 ✓ (B2)`，清册=`✓✓✓~~`；独立警报复审=`testend/rig/formal-evidence/EDGE-316-inline-code-cjk-l3-ledger-alarm-reaudit-20260829.md`，`pass-burst`/`discovery-collapse` 按原阈值销账，最终 `alarms.py check`=`clean (2025 live judgments; 2300 baseline judgments excluded)`；anchors=`10/10`，标准、阈值、法典和 gate 未改。
- 当前批次由 `13→14/50`；未满 50 不跑统一长门禁、不提交。L4/L5 仍为 `na`，P12 的 400+ Journey 扩写按用户裁定推迟二期；下一原子为 `EDGE-317` 的下一未完成等级。

## 最新收口（2026-08-29 · EDGE-315 空 task 尾空格腐化 L3 完成 · 新批次 13/50）

- 复用真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-230718`，对两轮“点击空 task→输入 `temp`→逐字清空→autosave→离开/重开”做连续录屏与 1fps/ROI 独立审查；中间空行始终保留 checkbox、等高行和可编辑位置。
- ROI=`760,430,1450,600` 的变化均归因于打开、输入/退格或离开/重开：动作窗口最大 `changedFrac=0.02135`，局部 caret/文字变化仅落在当前编辑区域；稳定帧没有历史行漂移、行高跳变、空白行吞并或 caret 逃逸。证据=`testend/rig/formal-evidence/EDGE-315-task-whitespace-heal-l3-real-app-20260829.md`。
- 五通道、REST/SQLite 精确原文 `- [ ] first task\n- [ ] \n- [ ] last task`、原 session 收台均通过；backend `212` 行、frontend `5` 行、SSE notifications durable `16,17,18`、LLM challenge/install/models 全 `200`，唯一 frontend 宿主文本为已分类 IMK 诊断。
- `judge.py` 写入 `EDGE-315 L3 ✓ (B2)`，清册=`✓✓✓~~`；独立警报复审=`testend/rig/formal-evidence/EDGE-315-task-whitespace-heal-l3-ledger-alarm-reaudit-20260829.md`，`pass-burst`/`discovery-collapse` 按原阈值销账，最终 `alarms.py check`=`clean (2024 live judgments; 2300 baseline judgments excluded)`；anchors=`10/10`，标准、阈值、法典和 gate 未改。
- 当前批次由 `12→13/50`；未满 50 不跑统一长门禁、不提交。L4/L5 仍为 `na`，P12 的 400+ Journey 扩写按用户裁定推迟二期；下一原子为 `EDGE-316` 的下一未完成等级。

## 最新收口（2026-08-29 · EDGE-314 编辑器唯一光标 L3 完成 · 新批次 12/50）

- 复用真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-225931`，独立复查正文→代码字段→表格字段→恢复原始 fixture 的全程动态；输入只落在当前嵌入字段，正文没有残留第二根 caret。
- 全屏与内容区 ROI 测量的变化均绑定用户动作窗口；恢复后的连续约 `20s` 稳定段无超过 `threshold=0.0005` 的持续变化。证据=`testend/rig/formal-evidence/EDGE-314-editor-single-caret-l3-real-app-20260829.md`。
- 五通道、原 session 收台、REST/SQLite 真相均通过；`judge.py` 写入 `EDGE-314 L3 ✓ (B2)`，清册=`✓✓✓~~`。告警复审=`testend/rig/formal-evidence/EDGE-314-editor-single-caret-l3-ledger-alarm-reaudit-20260829.md`，最终 clean，标准、阈值、法典和锚点未改。
- 当前批次由 `11→12/50`；未满 50 不跑统一长门禁、不提交。P12 的 400+ Journey 扩写继续按用户裁定推迟二期；下一原子由 formal sequence gate 选择后续未完成等级。

## 最新收口（2026-08-29 · EDGE-313 编辑器 undo 全量重建 L3 完成 · 新批次 11/50）

- 复用真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-225041`，独立复查用户粘贴 `EDITED` 后物理 `Command+Z` 的动态收尾；编辑态、撤销态和最终原正文均稳定可读。
- 1fps/10fps 测量确认变化集中在用户动作窗口，撤销完成后无超过 `threshold=0.0005` 的持续变化；录屏中两次 macOS 整窗缩放已作为宿主/手动观测边界单独标注，不误报为产品动画。证据=`testend/rig/formal-evidence/EDGE-313-editor-undo-rebuild-l3-real-app-20260829.md`。
- 五通道、原 session 收台、REST/SQLite 真相均通过；`judge.py` 写入 `EDGE-313 L3 ✓ (B2)`，清册=`✓✓✓~~`。告警复审=`testend/rig/formal-evidence/EDGE-313-editor-undo-rebuild-l3-ledger-alarm-reaudit-20260829.md`，最终 clean，标准、阈值、法典和锚点未改。
- 当前批次由 `10→11/50`；未满 50 不跑统一长门禁、不提交。P12 的 400+ Journey 扩写继续按用户裁定推迟二期；下一原子由 formal sequence gate 选择后续未完成等级。

## 最新收口（2026-08-29 · EDGE-312 版本组走 retryOf L3 完成 · 新批次 10/50）

- 复用真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-092651` 做版本组逐帧审查；打开线程、点击版本箭头造成的变化均与用户动作绑定，不误报为 B2 跳变。
- 当前/中间/最旧/恢复当前四个状态及各自稳定段均可读、单回合呈现；`000075` 到录屏末尾没有超过 `threshold=0.0005` 的持续变化。证据=`testend/rig/formal-evidence/EDGE-312-retry-version-groups-l3-real-app-20260829.md`。
- 五通道和原 session 收台均通过；`judge.py` 写入 `EDGE-312 L3 ✓ (B2)`，清册行=`✓✓✓~~`；告警复审=`testend/rig/formal-evidence/EDGE-312-retry-version-groups-l3-ledger-alarm-reaudit-20260829.md`，最终 clean，标准、阈值、法典和锚点未改。
- 当前批次由 `9→10/50`；未满 50 不跑统一长门禁、不提交。P12 的 400+ Journey 扩写继续按用户裁定推迟二期；下一原子由 formal sequence gate 选择后续未完成等级。

## 最新收口（2026-08-29 · EDGE-311 归队重钉贴底 L3 完成 · 新批次 9/50）

- 复用真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-091845` 做归队后的独立逐帧审查；用户点击 `Jump to present` 造成的整窗替换被明确区分为用户触发，不能误报为 B2 跳变。
- 归队收尾后从录屏样本 `000055` 至 `000065` 连续约 `10s` 在 `threshold=0.0005` 下无变化输出；最新 head、入口消失和贴底视口保持稳定。证据=`testend/rig/formal-evidence/EDGE-311-back-to-live-reanchor-l3-real-app-20260829.md`。
- 五通道和原 session 收台均通过；`judge.py` 写入 `EDGE-311 L3 ✓ (B2)`，清册行=`✓✓✓~~`；告警复审=`testend/rig/formal-evidence/EDGE-311-back-to-live-reanchor-l3-ledger-alarm-reaudit-20260829.md`，最终 clean，标准、阈值、法典和锚点未改。
- 当前批次由 `8→9/50`；未满 50 不跑统一长门禁、不提交。P12 的 400+ Journey 扩写继续按用户裁定推迟二期；下一原子由 formal sequence gate 选择后续未完成等级。

## 最新收口（2026-08-29 · EDGE-310 深跳 ?around= 整窗替换 L3 完成 · 新批次 8/50）

- 复用真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-062450` 做独立录屏审查；用户主动深跳和回到现场的整窗变化被正确识别为用户触发，不误报为 B2 缺陷。
- 深跳落定后连续 `22` 秒、回现场落定后连续 `15` 秒的 1fps 样本在 `threshold=0.0005` 下均无变化输出；没有自动二次跳转、窗口叠加、视口抖动或回现场入口反复出现。证据=`testend/rig/formal-evidence/EDGE-310-transcript-deep-jump-l3-real-app-20260829.md`。
- 五通道与既有持久真相一致；本格导航不触发模型调用，未虚构 LLM completion 证据。`judge.py` 写入 `EDGE-310 L3 ✓ (B2)`，清册保持 `848/848` clean；告警复审=`testend/rig/formal-evidence/EDGE-310-transcript-deep-jump-l3-ledger-alarm-reaudit-20260829.md`，最终 clean，标准、阈值、法典、锚点和 gate 未改。
- 当前批次由 `7→8/50`；未满 50 不跑统一长门禁、不提交。P12 的 400+ Journey 扩写继续按用户裁定推迟二期。下一原子前线由 formal sequence gate 选择后续未完成等级。

## 最新收口（2026-08-29 · EDGE-309 侧幕分档时钟 L3 完成 · 新批次 7/50）

- 复用同一份已完成的真实 App 长 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-055857`，不重复消耗网关额度；录屏覆盖 14.8 分钟静置，目标活动从 `Just now` 自然迁移为 `Earlier today`。
- 独立 1fps 逐帧测量确认跨档相邻样本 `changedFrac=0.00030`，变化框严格为右侧分组标题 `(2105,288)-(2260,356)`；活动行、中心 transcript、侧幕边界与计数均未重排。证据=`testend/rig/formal-evidence/EDGE-309-sidestage-relative-clock-l3-real-app-20260829.md`。
- 五通道仍齐：backend `965` 行无应用级红线；SSE `82` 行且 messages=`1..16`、entities=`1..2` 无 gap；frontend `4` 行仅已知宿主诊断；LLM wire `10` 行真实请求全 `200`；录屏和 durable 活动真相一致。
- `judge.py` 写入 `EDGE-309 L3 ✓ (B2)`，清册保持 `848/848` clean；告警复审=`testend/rig/formal-evidence/EDGE-309-sidestage-relative-clock-l3-ledger-alarm-reaudit-20260829.md`，`alarms.py check` 最终 clean，标准、阈值、法典、锚点和 gate 未改。
- 当前批次由 `6→7/50`；未满 50 不跑统一长门禁、不提交。P12 的 400+ Journey 扩写继续按用户裁定推迟二期。下一原子前线由 formal sequence gate 选择 `EDGE-310` 的下一未完成等级。

## 最新收口（2026-08-29 · EDGE-308 侧幕失败行清除 L3 完成 · 新批次 6/50）

- 正式真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-164838`：Chat 真实发现并调用一次故意失败的 Function；Activity 先显示 `Failed`、红点和 `Run failed · inspect the error below`，用户清除后同一行变为 `Viewed`。
- 逐帧确认失败态与清除后的历史态稳定、单向且无重复执行；中心 transcript 的完整 traceback、失败结果和执行审计在清除后仍保留。固定帧=`sessions/20260829-164838/evidence/EDGE-308-l3-failed.png`、`EDGE-308-l3-cleared.png`。
- 五通道均齐：录屏 `275.795000s`；SSE `178` 行且 messages=`1..30`、entities=`1..4`、notifications=`1..5` 无 gap；LLM wire `22` 行、真实请求全 `200`；backend `371` 行无应用级红线；frontend `4` 行无 Flutter/Dart/RenderFlex/Unhandled 红线；SQLite 保留一条 `failed` Function execution 与 `ok:false` tool result。
- `judge.py` 写入 `EDGE-308 L3 ✓ (B2)`，清册更新为 `✓✓✓~~`；告警复审=`testend/rig/formal-evidence/EDGE-308-sidestage-failure-clear-l3-ledger-alarm-reaudit-20260829.md`，`alarms.py check` 最终 clean，标准、阈值、法典、锚点和 gate 未改。
- 当前批次由 `5→6/50`；未满 50 不跑统一长门禁、不提交。P12 的 400+ Journey 扩写继续按用户裁定推迟二期。下一原子前线由 formal sequence gate 选择 `EDGE-309` 的下一未完成等级。

## 最新收口（2026-08-29 · EDGE-307 poll 型 202 不谢幕 L3 完成 · 新批次 5/50）

- 正式真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-163519`：通过真实 Chat 发现并调用 `trigger_workflow`，慢 function 制造 12 秒异步窗口；Activity 在 `202` 入队回执后持续显示 `Live`，durable `run_terminal` 后才转为 `Ran` 并收口。
- 逐帧确认长执行期间没有提前谢幕、非用户触发的既有内容跳位或 Live/Ran 往返闪烁；固定帧=`sessions/20260829-163519/evidence/EDGE-307-l3-live.png`、`EDGE-307-l3-terminal.png`、`EDGE-307-l3-settled.png`。真实 opaque ID 脱敏为 `the requested item` 遵循既有 redaction 规则，机器真值仍在 tool result、Activity 卡和 SQLite 中。
- 五通道均齐：录屏 `225.138333s`；SSE `208` 行且 messages=`1..23`、entities=`1..6`、notifications=`1..6` 无 gap；LLM challenge/install/models 与 4 次 chat completion 全 `200`；backend 无应用级红线；frontend 仅 Dart VM 与已知 macOS IMK/TSM 系统行；SQLite flowrun `fr_9bd1ea1577bb2426` 与两个 completed 节点一致。
- `judge.py` 写入 `EDGE-307 L3 ✓ (B2)`，清册更新为 `✓✓✓~~`；告警复审=`testend/rig/formal-evidence/EDGE-307-poll-202-no-farewell-l3-ledger-alarm-reaudit-20260829.md`，`alarms.py check` 最终 clean，标准、阈值、法典、锚点和 gate 未改。
- 当前批次由 `4→5/50`；未满 50 不跑统一长门禁、不提交。P12 的 400+ Journey 扩写继续按用户裁定推迟二期。下一原子前线由 formal sequence gate 选择 `EDGE-308` 的下一未完成等级。

## 最新收口（2026-08-29 · EDGE-306 导演器清 Live 幽灵 L3 完成 · 新批次 4/50）

- 正式真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-162708`：8 个文档的长链执行期间 messages stream 被台架断开，`16:28:29.079` 续连真实返回 `410`，随后 App 重取会话真相。
- 逐帧确认 `410` 后旧 Live 行先被清掉，中心恢复完整宽度；仍真实执行的活动重新经过防抖后单向登台，没有永久幽灵、回弹或闪烁。最终 UI 显示 `8 touched`，正文准确回读 `EDGE306-08`。
- 五通道均齐：录屏 `117.193333s`；独立 SSE witness `455` 行且 messages durable `1..61`、notifications `1..10` 无 gap；LLM challenge/install/models 与 `8` 次 chat completion 全 `200`；backend 无应用级 WARN/ERROR/panic；frontend 仅一条与注入断流对应的预期 connection-closed 诊断及已知 IMK 宿主诊断。
- SQLite 最终真相确认 8 条未删除文档，名称、正文、描述全部精确匹配 `EDGE306-01..08`。正式证据=`testend/rig/formal-evidence/EDGE-306-live-ghost-cleanup-l3-real-app-20260829.md`。
- `judge.py` 写入 `EDGE-306 L3 ✓ (B2)`，清册更新为 `✓✓✓~~`；`pass-burst` 与 `discovery-collapse` 已用独立 proxy、录屏、五通道和 SQLite 证据复核并销账，详情=`testend/rig/formal-evidence/EDGE-306-live-ghost-cleanup-l3-ledger-alarm-reaudit-20260829.md`，最终 `alarms.py check` clean，标准、阈值、法典、锚点和 gate 未改。
- 当前批次由 `3→4/50`；未满 50 不跑统一长门禁、不提交。P12 的 400+ Journey 扩写继续按用户裁定推迟二期。

## 最新收口（2026-08-29 · EDGE-305 侧幕尊重手动关 L3 完成 · 新批次 3/50）

- 正式真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-161757`：`Every time` 下首个文档活动打开 Activity 侧幕，手动关闭后第二个文档活动完成时侧幕保持关闭，`Toggle panel` 入口仍可发现，中心布局不再被重新收窄。
- 逐帧确认首次揭示与手动收回均为单次连续过渡，没有重复开合、反复重排或闪烁；揭示窗口约 `233.3ms`，与 `AnMotion.mid=240ms` 对齐。正式证据=`testend/rig/formal-evidence/EDGE-305-sidestage-manual-close-l3-real-app-20260829.md`。
- 五通道均齐：录屏 `120.246667s`；SSE `166` 行且 `entities 1..2`、`messages 1..30`、`notifications 1..4` 无 gap；LLM wire challenge/install/models 与 `15` 次 chat completion 全 `200`；backend 无应用级 WARN/ERROR/panic；frontend 仅已知 macOS IMK 宿主诊断。
- `judge.py` 写入 `EDGE-305 L3 ✓ (B2)`，清册更新为 `✓✓✓~~`；统计触发的 `discovery-collapse` 已用独立五通道证据复核并销账，详情=`testend/rig/formal-evidence/EDGE-305-sidestage-manual-close-l3-ledger-alarm-reaudit-20260829.md`，最终 `alarms.py check` clean，标准、阈值、法典、锚点和 gate 未改。
- 当前批次由 `2→3/50`；未满 50 不跑统一长门禁、不提交。P12 的 400+ Journey 扩写继续按用户裁定推迟二期。

## 最新收口（2026-08-29 · EDGE-304 侧幕跟随三档 L3 完成 · 新批次 2/50）

- 同一正式真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-160712` 依次验证 `Never`、`First per chat`、`Every time`：前者不自动抢屏，后两者在新会话首个真实文档活动完成后自动打开 Activity 侧幕，条目和 `1 touched` 均与文档动作一致。
- 逐帧测量确认 `First` 与 `Every` 均为单次连续揭示，没有收回再展开或闪烁；`Every` 侧幕连续揭示约 `233.3ms`，与 `AnMotion.mid=240ms` 对齐。正式证据=`testend/rig/formal-evidence/EDGE-304-sidestage-follow-modes-l3-real-app-20260829.md`。
- 五通道均齐：录屏 `321.863333s`；SSE `620` 行且 `messages 1..54`、`notifications 1..10` 无 gap；LLM challenge/install/models 与 `10` 次 continuation 全 `200`；backend 无应用级 WARN/ERROR/panic；frontend 仅已知 macOS IMK 宿主诊断。
- `judge.py` 写入 `EDGE-304 L3 ✓ (B2)`，清册更新为 `✓✓✓~~`；统计触发的 `discovery-collapse` 已用独立五通道证据复核并销账，详情=`testend/rig/formal-evidence/EDGE-304-sidestage-follow-modes-l3-ledger-alarm-reaudit-20260829.md`，最终 `alarms.py check` clean，标准、阈值、法典、锚点和 gate 未改。
- 当前批次由 `1→2/50`；未满 50 不跑统一长门禁、不提交。P12 的 400+ Journey 扩写继续按用户裁定推迟二期。

## 最新收口（2026-08-29 · EDGE-303 侧幕 activity 门控 L3 完成 · 新批次 1/50）

- 在真实 App 中重走空 Chat → `create_document` 活动 → Activity 侧幕揭示。逐帧测量确认侧幕从右侧连续揭示约 `233.3ms`，与 `AnMotion.mid=240ms` 对齐；没有第二次开合跳变或闪烁。
- 严格记录一个边界：`frame-00128→00129` 的 `changedFrac=0.08411` 是一次目标宽度重排，不是零像素变化；它发生在用户发起的 activity 侧幕揭示入口，随后进入稳定目标布局。不能把它改写成“零跳变”，也不能以此擅自删除现行 FollowMode 自动揭示契约。
- 五通道均来自同一正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-154941`；完整证据=`testend/rig/formal-evidence/EDGE-303-sidestage-activity-l3-real-app-20260829.md`。backend、SSE、frontend、LLM wire 与最终收台均通过，frontend 仅有已知 macOS IMK 宿主诊断。
- `judge.py` 写入 `EDGE-303 L3 ✓ (B2)`，清册更新为 `✓✓✓~~`；逐帧证据与产品判定不冒充 L4/L5。新证据触发的 `discovery-collapse` 已独立复核并销账，详情=`testend/rig/formal-evidence/EDGE-303-sidestage-activity-l3-ledger-alarm-reaudit-20260829.md`，最终 `alarms.py check` clean，标准、阈值、法典、锚点和 gate 未改。
- 当前批次由 `0→1/50`；未满 50 不跑统一长门禁、不提交。P12 的 400+ Journey 扩写继续按用户裁定推迟二期。

## 最新收口（2026-08-29 · 批次八十三统一门禁通过 · 已进入下一批 0/50）

- 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-151503`；真实 App 先显示危险删除确认卡，明确 Agent 身份与删除语义，用户点击 `Deny` 后显示“删除操作已被拒绝，如需继续，请告知”。
- 目标 Agent REST 仍为 `200`，touchpoints 为空，notifications 无删除行；SSE 只记录 interaction、resolved 和 denied tool_result，LLM wire 保留 `dangerous` 并明确不得重试，证明没有把意图冒充执行。
- 五通道 `rig-check`/`rig-down` 通过且录屏无外部遮挡；backend/frontend 无应用级红线，正式关键帧=`sessions/20260829-151503/evidence/EDGE-294-denied-delete.jpeg`。正式证据=`sessions/20260829-151503/evidence/EDGE-294-touchpoint-deny-no-delete-real-app-20260829.md`。
- `judge.py` 写入 `EDGE-294 L2 ✓ (F1)`，清册=`✓✓~~~`；L3-L5 保持 `na`。锚点=`10/10`；独立警报复审=`testend/rig/formal-evidence/EDGE-294-ledger-alarm-reaudit-20260829.md`，最终 `alarms.py check`=`clean (2011 live judgments; 2300 baseline excluded)`。
- 批次八十三由 `49→50/50` 后完成统一门禁、完整回归、警报复核和工作树审计；收口证据=`testend/rig/formal-evidence/batch-83-unified-gate-20260829.md`。根门禁、backend testend、rig 自测、锚点、清册、告警和进程审计全绿；下一批从 `0/50` 开始。P12 的 400+ Journey 扩写按用户裁定推迟二期。

## 上一收口（2026-08-29 · EDGE-298 未读徽标绝不据帧 +1 的真实 App L2 完成 · 新批次 49/50）

- 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-151051`；真实 App 通知中心显示唯一新增未读 `Memory "edge298-probe" updated`，旧 seed 通知保留但已读，左下铃铛没有按同类型广播再加一。
- 权威 `unread-count` 实测 `0→1→0→1→1`：持久 create/update 的 Emit 增加未读，pin 的同类型 Broadcast 保持 1；SSE `inbox=true` 与无 `inbox`、REST 通知行和 Memory 行一致。
- 五通道 `rig-check`/`rig-down` 通过且录屏无外部遮挡；backend/frontend 无应用级红线，正式关键帧=`sessions/20260829-151051/evidence/EDGE-298-unread-badge.jpeg`。正式证据=`sessions/20260829-151051/evidence/EDGE-298-unread-authoritative-count-real-app-20260829.md`。
- `judge.py` 写入 `EDGE-298 L2 ✓ (F1)`，清册=`✓✓~~~`；L3-L5 保持 `na`。锚点=`10/10`；独立警报复审=`testend/rig/formal-evidence/EDGE-298-ledger-alarm-reaudit-20260829.md`，最终 `alarms.py check`=`clean (2010 live judgments; 2300 baseline excluded)`。
- 批次由 `48→49/50`，未满 50 格不跑统一长门禁、不提交；下一原子继续选择最后一个尚未具备正式 L2 的 `~` 格。P12 的 400+ Journey 扩写按用户裁定推迟二期。

## 上一收口（2026-08-29 · EDGE-292 todo 全完成后被问清单的真实 App L2 完成 · 新批次 48/50）

- 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-150633`；真实 App 依次显示 `2 items · 0 done`、`2 items · 2 done`、`Read checklist · 2 items · 2 done`，最终准确列出两个已完成任务。
- SSE/消息耐久结果保留 `todo_write` 建立、`todo_write` 完成、`todo_read` 读回三步；REST 与 SQLite 对账一致，未因 0-open 隐藏清单或凭模型记忆编造。
- 五通道 `rig-check`/`rig-down` 通过且录屏无外部遮挡；backend/frontend 无应用级红线，LLM continuation 全 `200`，正式关键帧=`sessions/20260829-150633/evidence/EDGE-292-todo-completed-read.jpeg`。正式证据=`sessions/20260829-150633/evidence/EDGE-292-todo-completed-read-real-app-20260829.md`。
- `judge.py` 写入 `EDGE-292 L2 ✓ (F1)`，清册=`✓✓~~~`；L3-L5 保持 `na`。锚点=`10/10`；独立警报复审=`testend/rig/formal-evidence/EDGE-292-ledger-alarm-reaudit-20260829.md`，最终 `alarms.py check`=`clean (2009 live judgments; 2300 baseline excluded)`。
- 批次由 `47→48/50`，未满 50 格不跑统一长门禁、不提交；下一原子继续选择尚未具备正式 L2 的 `~` 格。P12 的 400+ Journey 扩写按用户裁定推迟二期。

## 上一收口（2026-08-29 · EDGE-291 memory 更新保留策展的真实 App L2 完成 · 新批次 47/50）

- 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-145816`；真实 App 通过一条 Composer 消息调用 `write_memory` 更新已有 `edge291-rule`，回执确认描述和内容已修改，切到 Settings → Memory 后仍显示置顶图钉和 `user` 来源。
- 最终 REST 记忆行保持 `pinned=true`、`source=user`，内容与描述为更新值；SSE 收到 `memory.updated`，LLM wire 有恰好一条正式路径的 `write_memory` 调用并完成 continuation，SQLite 完整性通过。
- 五通道 `rig-check`/`rig-down` 通过且录屏无外部遮挡；backend/frontend 无应用级红线，正式关键帧=`sessions/20260829-145816/evidence/EDGE-291-memory-chat.jpeg` 与 `EDGE-291-memory-panel.jpeg`。正式证据=`sessions/20260829-145816/evidence/EDGE-291-memory-curation-real-app-20260829.md`。
- `judge.py` 写入 `EDGE-291 L2 ✓ (F1)`，清册=`✓✓~~~`；L3-L5 保持 `na`，不把耐久字段保留冒充顺滑、视觉 craft 或可发现性结论。锚点=`10/10`；独立警报复审=`testend/rig/formal-evidence/EDGE-291-ledger-alarm-reaudit-20260829.md`，最终 `alarms.py check`=`clean (2008 live judgments; 2300 baseline excluded)`。
- 批次由 `46→47/50`，未满 50 格不跑统一长门禁、不提交；下一原子继续选择尚未具备正式 L2 的 `~` 格。P12 的 400+ Journey 扩写按用户裁定推迟二期。

## 上一收口（2026-08-29 · EDGE-293 删被依赖实体的真实 App L2 完成 · 新批次 46/50）

- 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-145009`；真实 App 的 Notifications 显示 Function 删除后留下 `4 references dangling`，并点名 `deploy-helper` 与三个 EDGE293 Agent，用户可以直接理解受影响对象。
- 真实后端删除 Function 返回 `204`，relation purge 记录 `removed=4`；SSE notifications 仅发一条聚合 `relation.dependency_broken`，payload 含四个依赖者，REST notifications 与 UI 一致；SQLite 完整性检查通过。
- 五通道 `rig-check`/`rig-down` 通过且录屏无外部遮挡；backend/frontend 无应用级红线，SSE 三流与 llmtap 连接正常，正式关键帧=`sessions/20260829-145009/evidence/EDGE-293-notification-aggregate.jpeg`。正式证据=`sessions/20260829-145009/evidence/EDGE-293-dependency-broken-real-app-20260829.md`。
- `judge.py` 写入 `EDGE-293 L2 ✓ (F1)`，清册=`✓✓~~~`；L3-L5 保持 `na`，不把依赖影响可见性冒充顺滑、视觉 craft 或可发现性结论。锚点=`10/10`；独立警报复审=`testend/rig/formal-evidence/EDGE-293-ledger-alarm-reaudit-20260829.md`，最终 `alarms.py check`=`clean (2007 live judgments; 2300 baseline excluded)`。
- 批次由 `45→46/50`，未满 50 格不跑统一长门禁、不提交；下一原子继续选择尚未具备正式 L2 的 `~` 格。P12 的 400+ Journey 扩写按用户裁定推迟二期。

## 上一收口（2026-08-29 · EDGE-279 对话挂载文档删除后的真实 App L2 完成 · 新批次 45/50）

- 正式 clean session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-144028`；真实 App 中打开已挂载文档的对话，删除文档后实际发送消息。
- LLM wire 明确收到 `<document id="doc_223e10c4a400bc06" missing="true">` 缺失 grounding 标记；真实 App 回答无法读取、说明文档已删除并建议重新上传，没有假装读到正文，也没有让回合失败。
- 五通道 `rig-check`/`rig-down` 通过且录屏无外部遮挡；backend/frontend 无应用级红线，SSE 三流和 LLM tap 证据齐全，SQLite/REST/UI 对账一致。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-144028/evidence/EDGE-279-attached-document-deleted-real-app-20260829.md`。
- `judge.py` 写入 `EDGE-279 L2 ✓ (F1)`，清册=`✓✓~~~`；L3-L5 保持 `na`，不把诚实降级冒充顺滑、视觉 craft 或可发现性结论。锚点=`10/10`；独立警报复审=`testend/rig/formal-evidence/EDGE-279-ledger-alarm-reaudit-20260829.md`，最终 `alarms.py check`=`clean (2006 live judgments; 2300 baseline excluded)`。
- 本格只证明历史挂载文档消失后聊天仍能诚实继续；批次由 `44→45/50`，未满 50 格不跑统一长门禁、不提交。P12 的 400+ Journey 扩写按用户裁定推迟二期。

## 上一收口（2026-08-29 · EDGE-280 Agent 知识文档删除后的 mount-health 真实 App L2 完成 · 新批次 44/50）

- 正式 clean session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-143120`；真实 App 先打开挂载知识文档的 Agent 详情，随后通过真实后端删除该文档，再切换实体并返回详情。
- 刷新后的真实画面明确显示 `1 unhealthy`、`Mount health: 1 unhealthy` 和 `knowledge document does not exist`；REST mount-health 同时返回 `healthy=false`，SSE 收到 `document.deleted` 与 `relation.dependency_broken`，没有把悬空知识挂载伪装成健康。
- 五通道 `rig-check`/`rig-down` 通过且录屏无外部遮挡；backend/frontend 无应用级红线，SSE 三流与 LLM tap 证据齐全，SQLite/REST/UI 对账一致。正式证据=`sessions/20260829-143120/evidence/EDGE-280-agent-knowledge-deleted-real-app.md`。
- `judge.py` 写入 `EDGE-280 L2 ✓ (F1)`，清册=`✓✓~~~`；L3-L5 保持 `na`，不把依赖断裂可见性冒充顺滑、视觉 craft 或可发现性结论。锚点=`10/10`；独立警报复审=`testend/rig/formal-evidence/EDGE-280-ledger-alarm-reaudit-20260829.md`，最终 `alarms.py check`=`clean (2005 live judgments; 2300 baseline excluded)`。
- 本格记录的产品边界：删除文档后已打开的详情不会凭删除事件自动刷新，需重新进入详情才能显示不健康；本轮只按已实现且真实观察到的刷新路径记账，不擅自扩大结论。批次由 `43→44/50`，未满 50 格不跑统一长门禁、不提交。P12 的 400+ Journey 扩写按用户裁定推迟二期。

## 上一收口（2026-08-29 · EDGE-324 窗角半径 swizzle 失效真实 App L2 完成 · 新批次 43/50）

- 正式 clean session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-140606`；临时故障注入构建将 `NSThemeFrame` 四个私有 getter 改为不存在的 selector，真实 macOS App 仍启动并显示完整 Library，随后 Computer Use 在 Library 与 Chat 间切换后仍可用。
- nil 守卫使私有 API 失效时回落系统窗口圆角，没有启动崩溃、黑屏、白屏或不可见窗口；故障注入源码已恢复，`MainFlutterWindow.swift` 无最终 diff。
- 五通道 `rig-check`/`rig-down` 通过且录屏无外部遮挡；backend 无应用级 WARN/ERROR/panic，SSE 三流连接，llmtap challenge/install/models 全 `200`；frontend 无 Flutter/Dart/RenderFlex/Unhandled 应用红线，唯一 IMK 文本为已分类的 macOS 宿主诊断。
- 正式证据=`testend/rig/formal-evidence/EDGE-324-window-corner-swizzle-fallback-real-app-20260829.md`；`judge.py` 写入 `EDGE-324 L2 ✓ (F1)`，清册=`✓✓~~~`，L3-L5=`na`；anchors=`10/10`，警报复审=`testend/rig/formal-evidence/EDGE-324-ledger-alarm-reaudit-20260829.md`，最终 `alarms.py check`=`clean (2004 live judgments; 2300 baseline excluded)`。
- 批次由 `42→43/50`，未满 50 格不跑统一长门禁、不提交；下一原子继续从尚未具备正式 L2 的 `~` 格选择。P12 的 400+ Journey 扩写按用户裁定推迟二期。

## 上一收口（2026-08-29 · EDGE-321 草稿文档首次编辑真实 App L2 完成 · 新批次 42/50）

- 正式 clean session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-135745`；真实 Flutter App 在无选区 Library 草稿态中先执行空稿离开，再输入 `EDGE321 body probe` 转正，继续输入 ` + continued`，切出后重新打开。
- 空稿离开前后文档树均为 2 条，没有幽灵文档；首次编辑只产生一次 `POST /documents` `201`，后续保存为同一 id 的 `PATCH`。AX/录屏显示正文连续、侧栏只有一个 `Untitled`，重开后正文与 REST 均为 `EDGE321 body probe + continued`，大小 `30 B`。
- 五通道 `rig-check`/`rig-down` 通过且录屏无外部遮挡；backend 无应用级 WARN/ERROR/panic，SSE notifications durable `seq=16,17` 单调，llmtap challenge/install/models 全 `200`；frontend 无 Flutter/Dart/RenderFlex/Unhandled 应用红线，唯一 IMK 文本为已分类的 macOS 宿主诊断。
- 正式证据=`testend/rig/formal-evidence/EDGE-321-draft-first-edit-real-app-20260829.md`；`judge.py` 写入 `EDGE-321 L2 ✓ (F1)`，清册=`✓✓~~~`，L3-L5=`na`；anchors=`10/10`，警报复审=`testend/rig/formal-evidence/EDGE-321-ledger-alarm-reaudit-20260829.md`，最终 `alarms.py check`=`clean (2003 live judgments; 2300 baseline excluded)`。
- 批次由 `41→42/50`，未满 50 格不跑统一长门禁、不提交；下一原子继续从尚未具备正式 L2 的 `~` 格选择。P12 的 400+ Journey 扩写按用户裁定推迟二期。

## 上一收口（2026-08-28 · EDGE-316 行内代码 CJK 断盒真实 App L2 完成 · 新批次 37/50）

- 真实 App 打开含 `中文注释：计算总数并返回结果` 的行内代码文档；截图与录屏确认多个 CJK script-run 之间灰色背景连续，无白缝、断盒、前后文字遮挡或粘连。
- 离开并重新打开后 AX 仍显示完整行内代码文本，右侧保持 `44 chars`、`130 B`；session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-231212`，App/window=`8497/5691`，录屏=`98.760000s`。
- 五通道 `rig-check`/`rig-down` 通过；SSE notifications durable seq `16` 单调，LLM challenge/install/models 全 `200`；frontend/backend 无应用红线，关键帧已保存在 session evidence。
- 正式证据=`testend/rig/formal-evidence/EDGE-316-inline-code-cjk-real-app-20260828.md`；`judge.py` 写入 `EDGE-316 L2 ✓ (F1)`，清册=`✓✓~~~`，L3-L5=`na`；anchors `10/10`，警报复核=`testend/rig/formal-evidence/EDGE-316-ledger-alarm-reaudit-20260828.md`，最终 `alarms.py check` clean。
- 批次由 `36/50` 推进到 `37/50`；按规则未满 50 不统一长门禁、不提交。下一原子为 `EDGE-317`；P12 的 400+ Journey 仍按用户裁定推迟二期。

## 上一收口（2026-08-28 · EDGE-315 空 task 尾空格腐化真实 App L2 完成 · 新批次 36/50）

- 全新正式台架打开含前后任务和中间空 task 的真实文档；两轮点击空 task、输入 `temp`、逐字退格清空、等待保存、离开并重开后，画面始终保留三个 checkbox 行，没有 bullet 退化、字面 `[ ]` 或内容吞并。
- 后端两轮 GET 均返回精确原文 `- [ ] first task\n- [ ] \n- [ ] last task`，`sizeBytes=39`；session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-230718`，App/window=`7538/5674`，录屏=`113.558333s`。
- 五通道 `rig-check`/`rig-down` 通过；SSE notifications durable seq `16,17,18` 单调，LLM challenge/install/models 全 `200`；frontend/backend 无应用红线，唯一 frontend 文本为已分类 macOS IMK 宿主提示。
- 正式证据=`testend/rig/formal-evidence/EDGE-315-task-whitespace-heal-real-app-20260828.md`；`judge.py` 写入 `EDGE-315 L2 ✓ (F1)`，清册=`✓✓~~~`，L3-L5=`na`；anchors `10/10`，警报复核=`testend/rig/formal-evidence/EDGE-315-ledger-alarm-reaudit-20260828.md`，最终 `alarms.py check` clean。
- 批次由 `35/50` 推进到 `36/50`；按规则未满 50 不统一长门禁、不提交。下一原子为 `EDGE-316`；P12 的 400+ Journey 仍按用户裁定推迟二期。

## 上一收口（2026-08-28 · EDGE-314 编辑器唯一光标真实 App L2 完成 · 新批次 35/50）

- 在全新正式台架中打开含正文、Dart 代码块和表格的真实文档；先在正文建立 caret，再分别点击代码字段和表格单元格并输入 `Y`/`X`。两条路径的 AX 与录屏都证明内嵌字段拿到键盘后，正文侧没有第二根文档 caret。
- 代码字段、表格字段均真实写入并随后通过 HTTP fixture 恢复；离开并重新打开文档后内容回到原始 Markdown，验收输入没有污染持久化 fixture。录屏=`222.475000s`，App/window=`6366/5642`。
- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-225931`；五通道 `rig-check`/`rig-down` 通过；backend 无应用红线，SSE notifications durable seq `16,17,18,19` 单调，LLM challenge/install/models 全 `200`。唯一 frontend 文本为已分类 macOS IMK 宿主提示。
- 正式证据=`testend/rig/formal-evidence/EDGE-314-editor-single-caret-real-app-20260828.md`；`judge.py` 写入 `EDGE-314 L2 ✓ (F1)`，清册=`✓✓~~~`，L3-L5=`na`；anchors `10/10`，警报复核=`testend/rig/formal-evidence/EDGE-314-ledger-alarm-reaudit-20260828.md`，最终 `alarms.py check` clean。
- 批次由 `34/50` 推进到 `35/50`；按规则未满 50 不统一长门禁、不提交。下一原子为清册中尚未具备正式 L2 的 `EDGE-315`；P12 的 400+ Journey 仍按用户裁定推迟二期。

## 上一收口（2026-08-28 · EDGE-313 编辑器 undo 全量重建真实 App L2 完成 · 新批次 34/50）

- 用户在全新正式台架中先粘贴 `EDITED`，再物理按下 `Command+Z`；真实画面与 AX 最终只保留 `Original paragraph for undo.`，右侧恢复为 `25 chars`、`28 B`。
- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-225041`；data=`/private/tmp/anselm-data-edge313-physical-20260828-r3`；App/window=`5081/5591`；录屏=`75.101667s`，五通道均由同一 manifest 归属并正常收台。
- 后端 PATCH/GET 字节由基线 `256` → 编辑后 `262` → 撤销后 `256`；SSE notifications 的 durable seq `16,17,18` 单调，包含对应的 `document.updated`；frontend/backend 无应用红线，LLM challenge/install/models 全 `200`。
- 正式证据=`testend/rig/formal-evidence/EDGE-313-undo-real-app-20260828.md`；`judge.py` 写入 `EDGE-313 L2 ✓ (F1)`，清册=`✓✓~~~`，L3-L5=`na`。anchors `10/10`，`alarms.py check` clean；宿主 undo 回归后 focused editor/library/error tests `126` 项通过。
- 批次由 `33/50` 推进到 `34/50`；按规则未满 50 不统一长门禁、不提交。下一原子继续从尚未具备正式 L2 的 `~` 格选择；P12 的 400+ Journey 仍按用户裁定推迟二期。

## 历史复验（2026-08-28 · EDGE-313 undo 手动物理结果正确，但正式 L2 暂不通过；批次 33/50 不变）

- 用户在真实 App 中粘贴 `EDITED` 后物理按 `Command+Z`，画面保留原始正文、只撤销 `EDITED`；这证明最近一次独立编辑的产品语义正确。
- 原始 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-210421` 的 frontend journal 有 `16` 条真实 `Null check operator used on a null value`，因此不能写 L2 绿灯；证据=`testend/rig/formal-evidence/EDGE-313-undo-manual-result-revalidation-20260828.md`。
- 当前构建重新启动的正式五通道 session=`20260828-215348` 与再次收台 session=`20260828-220058` 均无 Flutter/Dart/RenderFlex/Unhandled 应用红线；后者画面保持原始正文，但没有可证明的 `EDITED` 中间态与物理快捷键操作链，故不冒充完整撤销证据。
- 为后续红线保留可归因堆栈，`installErrorHandlers` 已将 `FlutterErrorDetails.stack` 写入 frontend console，并同步 [`docs/references/frontend/platform.md`](../../references/frontend/platform.md)；新增宿主 undo 回归后 focused Flutter editor/library/error tests `126` 项通过。
- `EDGE-313` 维持 `✓~~~~`，不写 `judge.py`、不推进批次、不降低标准；下一步必须在同一五通道台架中完成可信物理/Computer Use undo，并且 frontend journal 零未解释应用红线。

## 最新收口（2026-08-28 · EDGE-312 版本组走 retryOf 真实 App L2 完成 · 新批次 33/50）

- 真实 App 从 Recents 打开带三条 assistant durable 版本的会话，默认只显示当前版 `3/3`；沿 `Previous version` 翻到 `2/3`、`1/3` 可读旧版，并显示“后续基于第 3 版”，再沿 `Next version` 回到 `3/3` 后提示消失。AX 树始终只有一个 assistant 回合容器，没有重复三行。
- 隔离数据=`/private/tmp/anselm-data-edge312-20260828-r1`；session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-092651`；App/window=`83133/5155`；录屏=`91.045000s`；关键帧=`evidence/edge312-current-3of3.png`、`edge312-middle-2of3.png`、`edge312-oldest-1of3.png`、`edge312-restored-3of3.png`。
- 正式证据=`testend/rig/formal-evidence/EDGE-312-retry-version-groups-real-app-20260828.md`；`judge.py` 写入 `EDGE-312 L2 ✓ (F1)`，清册=`✓✓~~~`，L3-L5=`na`；无产品代码修改、无产品缺陷。
- `rig-check`/`rig-down` 通过；backend 无应用红线，SSE 三路连接并正常 EOF，frontend 只有已知 macOS IMK 系统行，LLM tap 在线；`anchors=10/10`、`gen_coverage=848/848/0`。警报复审=`testend/rig/formal-evidence/EDGE-312-ledger-alarm-reaudit-20260828.md`，最终 `alarms.py check` clean，标准、阈值、法典与锚点未改。
- 批次由 `32/50` 推进至 `33/50`；未满 50 不统一门禁、不提交。下一原子继续从尚未具备真实 L2 的 `~` 格选择；P12 的 400+ Journey 仍按用户裁定推迟二期。

## 最新收口（2026-08-28 · EDGE-311 归队重钉贴底真实 App L2 完成 · 新批次 32/50）

- 真实 App 从 Scenes 深跳到头部之外的老消息后，立即点击 `Jump to present`；归队沿 back-to-live 路径重拉最新 head，历史态入口消失，视口重新贴近底部，没有新增对话或持久化消息。
- 干净 session 的 Computer Use 关键帧与 AX 状态分别确认深跳入口存在、归队后入口消失；上一段授权未完成时的混合录屏已废弃，不计入本格。正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-091845`，录屏=`66.156667s`，App/window=`81847/5138`。
- 正式证据=`testend/rig/formal-evidence/EDGE-311-back-to-live-reanchor-real-app-20260828.md`；警报复审=`testend/rig/formal-evidence/EDGE-311-ledger-alarm-reaudit-20260828.md`；`judge.py` 写入 `EDGE-311 L2 ✓ (F5)`，清册=`✓✓~~~`，L3-L5=`na`。
- backend、SSE、frontend、LLM tap 与 rig lifecycle 均核验，`rig-check` 在 App 运行时无外部遮挡并通过，`rig-down` 正常收台；`anchors=10/10`、`gen_coverage=848/848/0`、最终 `alarms.py check` clean，标准、阈值、法典与锚点未改。
- 批次由 `31/50` 推进至 `32/50`；按 50 格规则不提前统一长门禁、不提交。下一原子继续从尚未具备真实 L2 的 `~` 格选择；P12 的 400+ Journey 仍按用户裁定推迟二期。

## 最新收口（2026-08-28 · EDGE-310 深跳 `?around=` 整窗替换真实 App L2 完成 · 新批次 31/50）

- 真实 App 打开 64 条长对话，从 Scenes 选择当前头部之外的老消息；修正为真实 Go 时区格式的隔离数据后，`?around=` 整窗替换成功，目标消息只出现一次并落在中心锚位，画面显示整行高亮和 `Jump to present`。
- 点击 `Jump to present` 后恢复最新头部窗口，按钮消失；Computer Use 关键帧与 AX 分别确认 `targetCount=1`、历史态存在、回现场后历史态消失。第一次错误无时区测试造成的重复画面已排除，不计入产品结论，也未修改产品代码。
- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-062450`；录屏=`80.973333s`；App/window=`77687/5044`；正式证据=`testend/rig/formal-evidence/EDGE-310-transcript-deep-jump-real-app-20260828.md`；警报复审=`testend/rig/formal-evidence/EDGE-310-ledger-alarm-reaudit-20260828.md`。
- `judge.py` 写入 `EDGE-310 L2 ✓ (F1)`，清册=`✓✓~~~`，L3-L5=`na`；backend、SSE、frontend、LLM tap 和 rig lifecycle 均已收台，无未解释应用红线。`anchors=10/10`、`gen_coverage=848/848/0`、最终 `alarms.py check` clean，未改标准、阈值、法典或锚点。
- 批次由 `30/50` 推进至 `31/50`；按 50 格规则不提前统一长门禁、不提交。下一原子继续从尚未具备真实 L2 的 `~` 格选择；P12 的 400+ Journey 仍按用户裁定推迟二期。

## 最新收口（2026-08-28 · EDGE-309 侧幕分档时钟真实 App L2 完成 · 新批次 30/50）

- 真实 App 在同一 Activity 侧幕中验证相对时钟迁移：目标活动初始位于 `Just now (1)`，前一天参照位于 `Earlier (1)`；前台无操作静置约 10 分钟后，目标自动迁移到 `Earlier today (1)`，参照保持 `Earlier (1)`。最终 AX 树确认的是右侧 Activity 容器，排除了左侧对话列表的同名 `Just now`。
- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-055857`；data=`/private/tmp/anselm-data-edge309-20260828-r1`；App/window=`75340/5002`；录屏=`891.081667s`；前后帧=`evidence/edge309-initial.png` / `evidence/edge309-migrated.png`；正式证据=`testend/rig/formal-evidence/EDGE-309-sidestage-relative-clock-real-app-20260828.md`。
- `judge.py` 写入 `EDGE-309 L2 ✓ (F1)`，清册=`✓✓~~~`；L3-L5 明确保持 `na`，不冒充顺滑、视觉 craft 或盲走可发现性通过。backend、SSE、frontend、managed LLM wire 与录屏均属同一台架 session；backend 无应用红线，frontend 只有已知 macOS IMK 系统提示。
- 警报复审=`testend/rig/formal-evidence/EDGE-309-ledger-alarm-reaudit-20260828.md`；`anchors=10/10`、`gen_coverage=848/848/0`、最终 `alarms.py check` clean，未修改阈值、法典、锚点或 gate。当前批次由 `29/50` 推进至 `30/50`，未满 50 不统一长门禁、不提交；下一原子继续从尚未具备真实 L2 的 `~` 单元选择。P12 的 400+ Journey 继续按用户裁定推迟二期。

## 最新收口（2026-08-28 · EDGE-308 侧幕失败行清除真实 App L2 完成 · 新批次 29/50）

- 首轮真实 App 发现产品缺陷：执行正文已是 `ok:false` 且中心 transcript 为红色失败，但 Activity 侧幕误显示 `Ran`，失败行没有清除出口。根因是 `tool_result` 外层 status=`completed` 掩盖了执行正文失败。
- stop-and-fix 后，`StageDirectorController` 同时判断外层 `error/cancelled`、执行正文 `ok:false` 和 agent `status=failed|timeout`。定向 provider 回归覆盖 `failedHold` 与 `clearActivity`，Flutter 31/31 全绿。
- 修复版真实 App 通过实体提及执行故障注入 function：侧幕正确显示 `Failed`、红点、`Run failed · inspect the error below`；鼠标移入后真实 AX 出现 `Clear this row`，点击后红色驻留清除，中心 transcript 的失败审计仍保留。session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-052018`；data=`/private/tmp/anselm-data-edge308-20260828-r2`；App/window=`71289/4911`；录屏=`110.498333s`；固定帧=`evidence/edge308-failed.png` / `evidence/edge308-cleared.png`；正式证据=`testend/rig/formal-evidence/EDGE-308-sidestage-failure-clear-real-app-20260828.md`。
- `judge.py` 新增 `EDGE-308 L2 ✓ (F1)`，清册=`✓✓~~~`，L3-L5=`na`；独立警报复审=`testend/rig/formal-evidence/EDGE-308-ledger-alarm-reaudit-20260828.md`，`alarms.py check` clean，未改阈值、法典、锚点或 gate。批次由 `28/50` 推进到 `29/50`，未满 50 不统一长门禁、不提交。P12 的 400+ Journey 继续按用户裁定推迟二期。

## 上一收口（2026-08-28 · EDGE-307 poll 型 202 不谢幕真实 App L2 完成 · 新批次 28/50）

- 真实 App 通过实体提及选择 `edge307_poll_202_probe`，请求只触发并返回 run id；真实 function 故意等待 12 秒。等待期间中心 stage 保持 `Triggered workflow ...`，Activity 保持 `Mentioned · Live` 与 `Listening live · settle follows the truth`，没有提前谢幕；完成后才显示 `Ran` 与 `1 touched · 1 executed`。
- 成功路径的 `trigger_workflow`、flowrun `fr_a40e4146fcdc2fb1`、workflow `wf_10e5d09d369a952c` 在真实 App、backend、三路 SSE、frontend journal、managed LLM wire 和录屏中逐一对齐；entities 顺序为 `run_started → node completed → run_terminal`。
- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-050413`；data=`/private/tmp/anselm-data-edge307-20260828-r1`；App/window=`68891/4858`；录屏=`291.895000s`，固定帧=`evidence/edge307-live.png` / `evidence/edge307-terminal.png`；正式证据=`testend/rig/formal-evidence/EDGE-307-poll-202-real-app-20260828.md`。
- `judge.py` 新增 `EDGE-307 L2 ✓ (F1)`，清册=`✓✓~~~`，L3-L5=`na`；独立警报复审=`testend/rig/formal-evidence/EDGE-307-ledger-alarm-reaudit-20260828.md`，`alarms.py check` 最终 clean，未改阈值、法典、锚点或 gate。早先输入桥接丢下划线的失败探针已在证据中隔离，不计入成功路径。
- `rig-check` 与 `rig-down` 均通过；backend 唯一 warning 属于隔离的早期失败探针，frontend 仅有 Dart VM 与 macOS IMK/TSM 系统行，无 Flutter/Dart/RenderFlex/Unhandled 红线。批次由 `27/50` 推进到 `28/50`，未满 50 不统一长门禁、不提交。P12 的 400+ Journey 继续按用户裁定推迟二期。

## 上一收口（2026-08-28 · EDGE-306 导演器清 Live 幽灵真实 App L2 完成 · 新批次 27/50）

- 真实 App 中先由 `appproxy` 制造 messages stream 断流并返回真实 `410 SEQ_TOO_OLD`，复现同一 Bash 调用同时出现 durable completed 结果和 stale `Running command... 152 s` live 卡片；REST 确认后端工具调用与 tool result 均已 `completed`，问题定位为前端 live layer 重复。
- stop-and-fix 后，`ConversationTranscript.applyFrame` 对 settled tree 中已有 block ID 的所有迟到 frame（包括 ephemeral `open`/`delta`）跳过 live 重建，同时保留 durable user echo reconciliation；重建真实 App 并打开同一会话后，每轮命令只剩一张 `Ran ... · exit 0` 终态卡片，结果文本只出现一次。
- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-043601`；data=`/private/tmp/anselm-data-edge306-20260828-r4`；替换 App/window=`64532/4782 → 66967/4830`；固定终帧=`evidence/edge306-fixed.png`，替换录屏=`screen-rebind-66967.mov`；正式证据=`testend/rig/formal-evidence/EDGE-306-live-ghost-cleanup-real-app-20260828.md`。
- `judge.py` 新增 `EDGE-306 L2 ✓ (F1)`，既有 L1 保持通过，清册=`✓✓~~~`，L3-L5=`na`；本格不冒充顺滑、视觉 craft 或盲走可发现性通过。独立警报复审=`testend/rig/formal-evidence/EDGE-306-ledger-alarm-reaudit-20260828.md`，`alarms.py check` clean，未改阈值、法典、锚点或 gate。
- `rig-check` 与 `rig-down` 均通过；三路 SSE、backend、frontend、LLM wire 和录屏均有归属。frontend journal 中的 connection closed/503/connection refused 是本次刻意断流和收台扰动，已在证据中明示，不计作产品红线；未发现 Flutter/Dart/RenderFlex/Unhandled runtime 红线。
- 批次由 `26/50` 推进到 `27/50`，未满 50 不统一长门禁、不提交。P12 的 400+ Journey 继续按用户裁定推迟二期。

## 上一收口（2026-08-28 · EDGE-305 侧幕尊重手动关真实 App L2 完成 · 新批次 26/50）

- 真实 App 在首条 `create_document` 活动后打开 Activity 侧幕，用户手动关闭后入口仍保留；切到 Entities 再返回 Chat，关闭状态不被海洋切换重置；同一会话第二次真实活动完成后侧幕仍不强制弹出，中心结果与活动数据完整。
- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-041819`；录屏=`96.278333s`，App/window=`60542/4681`，五通道与收台审计通过；证据=`testend/rig/formal-evidence/EDGE-305-sidestage-manual-close-real-app-20260828.md`。
- `judge.py` 写入 `EDGE-305 L1 ✓ (A5)`、`L2 ✓ (F1)`，清册=`✓✓~~~`，L3-L5=`na`。独立警报复核=`testend/rig/formal-evidence/EDGE-305-ledger-alarm-reaudit-20260828.md`，`alarms.py check` clean，未改阈值、法典、锚点或 gate。批次由 `25/50` 到 `26/50`，未满 50 不统一收口、不提交。P12 的 400+ Journey 继续推迟二期。

## 最新收口（2026-08-28 · EDGE-304 侧幕跟随三档真实 App L2 完成 · 新批次 25/50）

- 真实 App 逐档验证 `Never`、`First per conversation`、`Every time`：Never 在干净会话首条活动后只显示入口；First 首次活动自动展开，手动关闭后同会话第二次活动不再弹；Every time 在全新会话活动时自动展开。三档菜单可从 Activity 的 More actions 发现。
- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-040938`；录屏=`318.165000s`，App/window=`59497/4643`，五通道与收台审计通过；证据=`testend/rig/formal-evidence/EDGE-304-sidestage-follow-modes-real-app-20260828.md`。
- `judge.py` 写入 `EDGE-304 L2 ✓ (F1)`，L1 G1 为本次真实路径复核，清册=`✓✓~~~`，L3-L5=`na`。手动关闭优先于自动模式的组合行为与 EDGE-305 一致。
- 独立警报复核=`testend/rig/formal-evidence/EDGE-304-ledger-alarm-reaudit-20260828.md`；`alarms.py check` clean，未改阈值、法典、锚点或 gate。按新增 L2 单元计，批次由 `24/50` 到 `25/50`，未满 50 不统一收口、不提交。P12 的 400+ Journey 继续推迟二期。

- 真实 App 在新建工作区后进入空 Chat：没有工具/触点活动时，右岛及其入口均不存在；新建干净对话并真实创建 `EDGE-303 activity note` 后，首条 `create_document` 活动到达，入口横向出现，Activity 侧幕显示 `1 touched` 与 `Created`，中心结果、侧幕和实体名一致。关闭侧幕后入口仍保留。
- 有效 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-035907`；App PID/window=`58176/4617`，录屏=`470.888333s`，backend=`57719`，ssetap=`57740`，llmtap=`57701`；`rig-check`/`rig-down` 通过，五通道 journal 齐全；证据=`testend/rig/formal-evidence/EDGE-303-sidestage-activity-gate-real-app-20260828.md`。
- `judge.py` 已写入 `EDGE-303 L1 ✓ (G1)`、`L2 ✓ (F1)`，清册为 `✓✓~~~`；L3-L5 继续诚实保持 `na`。本格只证明 activity 门控和五通道真相，不冒充顺滑、视觉 craft 或可发现性深评。
- `rig-check` 中发现的 AXTree bridge churn 已按精确已知形态独立审查并分类为台架/引擎噪声；没有 Flutter/Dart/RenderFlex/Unhandled 红线。独立警报复核=`testend/rig/formal-evidence/EDGE-303-ledger-alarm-reaudit-20260828.md`，`alarms.py check` clean，未改阈值、法典、锚点或 gate。
- 批次由 `23/50` 推进到 `24/50`，未满 50 格不统一收口、不提交。P12 的 400+ Journey 继续按用户裁定推迟二期。

## 最新收口（2026-08-28 · EDGE-340 Vertex service-account 文件校验真实 App L2 完成 · 新批次 23/50）

- 在全新工作区真实启动 App，进入「模型与密钥 → 添加密钥」并选择 Vertex；表单明确显示服务账号 JSON、文件选择与 Base URL 区域占位。输入非敏感缺字段 JSON 后立即显示 `type / project_id / private_key` 校验错误，取消后 Models & keys 保持受管行和 2 个空音色槽，未产生 Vertex 行或远程探测。
- 有效 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-035055`；App PID/window=`56376/4582`，录屏=`85.241667s`，三路 SSE 已连接新 workspace，managed key 经 llmtap，`rig-check`/`rig-down` 与收台进程审计全绿；证据=`testend/rig/formal-evidence/EDGE-340-vertex-service-account-real-app-20260828.md`。
- `judge.py` 已写入 `EDGE-340 L2 ✓ (F1)`，清册为 `✓✓~~~`；L3-L5 继续诚实保持 `na`。本格只证明非法服务账号边界，不冒充合法 Vertex 文件或 completion 成功。
- 首次 session=`20260828-034655` 因 Computer Use 在 Flutter build 期间触发未归属 App，且没有 workspace SSE/LLM 请求，已作为仪器红场拒绝并封存；修复 `rig-up`/`rig-check` 的同 bundle PID 归属后才重跑。红证据=`testend/rig/formal-evidence/EDGE-340-rig-attribution-red-20260828.md`。
- 独立警报复核=`testend/rig/formal-evidence/EDGE-340-ledger-alarm-reaudit-20260828.md`；`discovery-collapse` 按复审销账，最终 `alarms.py check` clean，`anchors=10/10`，未修改阈值、法典、锚点或 gate。台架纪律同步于 [`testend/rig/README.md`](../../../testend/rig/README.md)。
- 批次由 `22/50` 推进到 `23/50`，未满 50 格不统一收口、不提交。P12 的 400+ Journey 继续按用户裁定推迟二期。

### 未计入账本的观察（2026-08-28 · EDGE-329）

真实 App 已进入快捷键录制态，但 Computer Use 的 macOS 修饰键注入在多种写法下均被 App 识别为无修饰键；`rig-check` 因 App 关闭而正确拒绝，未写入 L2。该输入桥限制已封存于 `testend/rig/formal-evidence/EDGE-329-computer-use-input-blocked-20260828.md`，后续必须换物理输入能力重测，不能用 `set_value` 伪造。

### 未计入账本的观察（2026-08-29 · EDGE-275）

真实 App 已进入 Library 空白草稿，但 Computer Use clipboard bridge 在约 1 MiB 和 100 KiB 分块粘贴时均于 App 读取剪贴板前超时；正文仍为空，未触发 `DOCUMENT_CONTENT_TOO_LARGE`，所以不对产品 L2 下结论。现场记录见 `testend/rig/formal-evidence/EDGE-275-large-paste-bridge-blocked-20260829.md`；后续须换可承载大载荷的输入 fixture，不能把桥接超时冒充后端拒绝或 UI 通过。

### 未计入账本的观察（2026-08-29 · 台架前置清理）

一次故意端口冲突复验发现 `rig-up` 的早期 `EXIT` 清理会误杀已有台架 App，且 `RIG_RECORD=0` 的 `rig-check` 会因空窗口 ID 返回 `SIGTRAP(133)`。两处均已修复并复验：冲突的第二套台架返回 `1` 但第一套 App 保持存活；诊断门禁现在返回可解释的 fail-closed。完整记录见 `testend/rig/formal-evidence/rig-up-preflight-cleanup-regression-20260829.md`；不推进 COVERAGE 批次。

## 最新收口（2026-08-28 · EDGE-339 BYOK base URL 模板未填占位真实 App L2 完成 · 新批次 22/50）

- 正式台架复用全新工作区真实启动 App，在「模型与密钥 → 添加密钥」中进入 Azure 模板；表单明确显示 `baseUrlTemplateHint`，指出地址仍需替换，随后取消返回稳定设置面，未写入凭证或半成品 provider 行。
- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-031741`；录屏=`160.780000s`；backend、三路 SSE、frontend、LLM tap、manifest 与 recording lifecycle 均齐全，正式证据=`testend/rig/formal-evidence/EDGE-339-byok-base-url-template-real-app-20260828.md`。
- `judge.py` 已写入 `EDGE-339 L2 ✓ (F1)`，清册为 `✓✓~~~`；L3-L5 继续诚实保持 `na`。本格只证明模板占位与取消无副作用，不冒充 Azure 凭证认证或 completion 成功。
- 独立警报复核=`testend/rig/formal-evidence/EDGE-339-ledger-alarm-reaudit-20260828.md`；`pass-burst` 与 `discovery-collapse` 已按复审销账，最终 `alarms.py check` clean，`anchors=10/10`，未修改阈值、法典、锚点或 gate。
- 批次由 `21/50` 推进到 `22/50`，未满 50 格不统一收口、不提交。P12 的 400+ Journey 继续按用户裁定推迟二期。

## 最新收口（2026-08-28 · EDGE-330 设置项搜索索引漂移真实 App L2 完成 · 新批次 21/50）

- 正式 conductor 在全新工作区真实启动 App、sidecar、三路 SSE witness、LLM tap、frontend journal 与窗口录屏；先在通用设置切到 English，再用真实键盘输入 `zoom`。
- 搜索结果正确按面板分组到 General、Storage & logs、Shortcuts，共 6 个具体设置项；点击 `Reset zoom` 跳到 Shortcuts 目标行并清空搜索，随后输入 `zzzqqxx` 只显示单一 `No matching settings`，无幽灵结果或旧目录残留。
- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-033249`；`rig-check` 在 App 运行期间通过，`rig-down` 收束录屏=`217.146667s`，五通道日志与进程归属完整；正式证据=`testend/rig/formal-evidence/EDGE-330-settings-search-real-app-20260828.md`。
- `judge.py` 已写入 `EDGE-330 L2 ✓ (F1)`，清册为 `✓✓~~~`；L3-L5 继续诚实保持 `na`。独立警报复核=`testend/rig/formal-evidence/EDGE-330-ledger-alarm-reaudit-20260828.md`，`alarms.py check` clean，未修改阈值、法典、锚点或 gate。
- 批次由 `20/50` 推进到 `21/50`，未满 50 格不统一收口、不提交；本轮早先关闭旧 App 造成的系统提示已被台架识别并清除，不进入产品证据。P12 的 400+ Journey 继续按用户裁定推迟二期。

## 最新收口（2026-08-28 · EDGE-341 未验证供应商诚实徽标真实 App L2 完成 · 新批次 20/50）

- 标准 conductor 真实启动全新工作区、Flutter App、sidecar、三路 SSE witness、LLM tap、frontend journal 与连续录屏；在「模型与密钥 → 添加密钥」中观察到真实供应商目录 `0-100 of 213 items`，卡片同时显示供应商名、模型数量与 `未验证` 徽标。
- 进入 `302.AI` 添加表单核对 Name/Key/Base URL/保存与测试控件后取消；没有输入、上传或保存凭证，受管 Anselm key 与工作区状态未被改变。该路径证明诚实缺席与取消无副作用，不冒充真实凭证验证成功。
- formal session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-030900`；`rig-check`/`rig-down` 通过，录屏=`143.845000s / 2784x1808 / 60fps`，五通道证据齐全；正式证据=`testend/rig/formal-evidence/EDGE-341-unverified-provider-real-app-20260828.md`。
- `judge.py` 已写入 `EDGE-341 L2 ✓ (F1)`，清册为 `✓✓~~~`；L3-L5 继续诚实保持 `na`。独立复核=`testend/rig/formal-evidence/EDGE-341-ledger-alarm-reaudit-20260828.md`，警报已复核并 ack，`alarms.py check` clean，未修改阈值、法典、锚点或历史 journal。
- 批次由 `19/50` 推进到 `20/50`，未满 50 格不统一收口、不提交；下一项继续按 `COVERAGE.md` 的可提升 `~` 格选择。P12 的 400+ Journey 继续按用户裁定推迟二期。

## 最新收口（2026-08-28 · EDGE-332 MCP 面板帧不可信真实 App L2 完成 · 新批次 19/50）

- 真实 App 的 entities stream 首次 410 在 MCP provider 已建立后触发权威名册重取；随后真实 MCP server 的 4 次生命周期动作在约 100ms 内产生密集 status 帧，面板只新增 1 次 300ms 合并后的 `GET /mcp-servers`，删除后再次收敛为空态。
- formal session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-025843`；`rig-check`/`rig-down` 通过，录屏=`54.981667s`，五通道证据齐全；正式证据=`testend/rig/formal-evidence/EDGE-332-mcp-frame-coalescing-real-app-20260828.md`。
- `judge.py` 已写入 `EDGE-332 L2 ✓ (G2)`，清册由 `✓~~~~` 变为 `✓✓~~~`；L3-L5 继续诚实保持 `na`。独立复核=`testend/rig/formal-evidence/EDGE-332-ledger-alarm-reaudit-20260828.md`，最终 `alarms.py check` clean。
- 批次由 `18/50` 推进到 `19/50`，未满 50 格不统一收口、不提交；P12 的 400+ Journey 继续按用户裁定推迟二期。

## 最新收口（2026-08-28 · EDGE-331 限额面板载入失败修复后 L2 完成 · 新批次 18/50）

- 真实 App 在代理注入一次 schema 503 后，错误面只显示本地化“无法从引擎读取限额配置”，后端内部诊断和 wire code 均不再上脸；直接点击 Retry 后 schema/limits 完整恢复。
- formal session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-024929`；`rig-check`/`rig-down` 通过，录屏=`59.141667s`，五通道证据齐全；正式证据=`testend/rig/formal-evidence/EDGE-331-limits-load-failure-real-app-20260828.md`。
- `judge.py` 已写入 `EDGE-331 L2 ✓ (G2)`，清册由 `✓~~~~` 变为 `✓✓~~~`；L3-L5 继续诚实保持 `na`。独立复核=`testend/rig/formal-evidence/EDGE-331-ledger-alarm-reaudit-20260828.md`，最终 `alarms.py check` clean。
- 批次由 `17/50` 推进到 `18/50`，未满 50 格不统一收口、不提交；P12 的 400+ Journey 继续按用户裁定推迟二期。

## 已解决红场记录（2026-08-28 · EDGE-331 限额面板载入失败 stop-and-fix）

- formal session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-024219`；真实 App、sidecar、三路 SSE、llmtap、Computer Use 与录屏均已归属。
- 代理首次让 `GET /api/v1/limits/schema` 返回 503 后，限额面进入了可重试错误态，但把后端内部诊断 `acceptance rig injected a transient failure` 直接显示在主面；这是产品红场，不计 judge、不推进批次。
- stop-and-fix 已落地：整面错误态固定使用本地化 `errorHint`，稳定 wire code 只放 tooltip；fixture 回归锁住后端 message 不得上脸，Retry 后恢复 schema。
- 红证据=`testend/rig/formal-evidence/EDGE-331-limits-load-failure-red-scene-20260828.md`；该红场已按同样代理注入重跑并收口，详见上方最新收口。

> **历史基线摘要(2026-08-01):Day 0 已打通。conductor 亲自托管真实 App、Flutter console、屏幕录像、
> 后端、三路 SSE 与网关线缆,并在全新数据目录完成 onboarding → 受管开通 → 五通道自检 →
> 优雅收台的真机闭环。清册为 848 行 × 5 级 = 4240 格;锚点校准已冻结并接入 gate。
> 操作手册 [`testend/rig/README.md`](../../../testend/rig/README.md) 使任何 agent 不带对话记忆也能
> 操作全套台架。400+ 旅程扩写按 P12 推迟二期,一期直接按 COVERAGE 驻停清扫。Goal 已配置为
> active，Loop 执行协议见 [`LOOP.md`](LOOP.md)；首批 50/50 已通过统一长门禁、完整 testend、真实回放、
> 告警复核和工作树审计，并已提交 `b26f623e`；第二批已完成 50/50 个单格，`TOOL-003 Edit` 至
> `TOOL-012 todo_read` 已按真实五通道收尾；统一长门禁已全绿并完成审计。第三批已完成
> `TOOL-013 search_tools`、`TOOL-014 search_function`、`TOOL-015 get_function`、`TOOL-016 create_function`、`TOOL-017 edit_function`、`TOOL-018 revert_function`、`TOOL-019 delete_function`、`TOOL-020 update_function_meta`、`TOOL-021 run_function` 与 `TOOL-022 search_function_executions` 共 50/50 个单格；
> `TOOL-016` 首轮发现新建失败态误显示 edit 专属的“上一版”文案，修复为 create 专属的“尚未创建实体”，并补
> create/edit 对称 widget 回归；`TOOL-017` 又真实覆盖 v1→v2 版本编辑、非法代码拒绝和无 v3 副作用，edit 失败保留上一版真相。
> `TOOL-018` 又真实覆盖 v2→v1 指针回退、v999 不存在版本拒绝、无新版本副作用和历史保留；`TOOL-019` 首轮发现
> delete 的工具描述错误宣称“全版本删除”，冻结后修正为主行软删、不可变版本审计保留、sandbox 回收、后续动作 not-found，
> 并以真实成功/失败路径、SQLite、HTTP、五通道与 native-resolution 画面重跑。`TOOL-020` 首轮发现精确下划线意图在
> Computer Use 输入层丢失，以及 tags 错用字符串的 AI 引导问题；补充数组形状示例与禁止逗号字符串的 schema/描述后，
> 修复后二进制用真实成功/失败路径重跑。`TOOL-021` 首轮发现托管模型把显式版本和对象参数字符串化，修复执行边界后真实一次成功 v2、一次不存在 ID 拒绝、一次缺参数执行失败；`TOOL-022` 首轮发现分页 limit 被托管模型发成字符串，修复执行边界接受精确整数字符串并保留强类型公开 schema，随后真实覆盖分页、failed/version 筛选、空结果和非法 status；第三批已到 50/50，警报复审后 clean(150 judgments)，统一长门禁、完整 testend、专项回归和最终审计均已通过，并已提交 `eb1ee050`；第四批 `TOOL-023 get_function_execution`、`TOOL-024 search_handler`、`TOOL-025 get_handler`、`TOOL-026 create_handler`、`TOOL-027 edit_handler` 与 `TOOL-028 revert_handler` 已完成 30/50。`TOOL-027` 首轮真实会话暴露托管模型发送 `methodName`、`method` 加顶层字段和 camel-case op；冻结后在执行边界加入只针对已观测 hosted-model alias 的窄归一化，公开 schema 仍严格要求 `{op,name,patch}`，补守卫测试、同步工具描述与 handler 文档。`TOOL-028` 的前置真实会话又暴露 `kind:set_method`、`set_method_description` 等不规范 edit 形状以及 `version:"1"` 的标量字符串化；前置 edit 与回退切片分离，回退边界仅兼容精确整数字符串，非整数仍拒绝。最终 session `/private/tmp/anselm-rig-formal-20260801-46/sessions/20260801-132558` 用真实 REST fixture 建 v2，再由真实 App 单次回退到 v1并执行 version 999 负路径；screen.mov `258.636667s`、`2784x1808`，LLM 状态全 200，messages durable `1..91`、entities `7..8`、notifications `16..21` 无 gap，frontend 无 Flutter 红线，backend 仅预期 version-not-found WARN，SQLite/UI/REST/LLM wire 一致。五级裁决为 `G1/F2/A5/C4/G2`，警报复审后 clean(180 judgments)；下一前线为 `TOOL-029 delete_handler`。**
>
> **历史状态(截至 2026-08-02 00:55):** 第五批已完成 50/50 个单格并已提交 `90f51edd`；第六批当时
> **19 / 50**。`TOOL-047 get_control` 的 formal-103 已通过；`TOOL-048 create_control` 的 formal-104
> 首轮冻结为红：托管模型将 branches 发成 JSON 字符串且 UI 留下失败活动；formal-105 修复前重跑又暴露
> branch 键误用 `name` 以及同一 assistant 批次重复 mutation，均保留红证据、不计绿。前线随后修复
> stringified-array 窄兼容 decoder、`port` 精确契约提示和同批完全重复调用抑制，并通过定向 Go 测试。
> formal-106 使用真实 App + 受管网关 + Computer Use + 五通道台架重跑：正向首个真实 create_control
> wire 使用 JSON 字符串数组但每个 branch 为正确 `port`，后端接受并只产生一个成功实体；App 展示一张
> 完整 ordered branches 表，没有红色重试或 duplicate failure。负向同一真实会话只调用一次已存在名称，
> 后端明确返回 `control logic name already exists`，App 同时显示“Draft unsaved · nothing was created”
> 与精确错误解释，无 retry/其它工具。录屏 `230.008333s / 2784x1808 / 60fps`，messages durable `1..29`、
> entities `7..8`、notifications `16..20` 连续，LLM 五个 chat completion request/response 均 200，backend
> 只有刻意负路径 WARN，Flutter journal 无运行时红线。证据与正负终帧封存于
> `/private/tmp/anselm-rig-formal-106/sessions/20260801-232207/`；control fixture 与对话 DELETE=204 后
> GET=404，列表无残留。五级裁决 `G1/F2/A5/C4/G2` 已写入 COVERAGE，中央账本 290 条；统计警报按
> formal-106 五通道证据复审并 ack 后 clean。`TOOL-049 edit_control` 的 formal-107 首轮冻结为红：同一用户
> 意图先生成缺少 `changeReason` 的 v2、再生成带 reason 的 v3，造成两次版本 mutation；formal-108 修复后真实
> App 正向只调用一次并创建 v2，负向缺 reason 在 mutation 前拒绝且没有 v3。formal-108 录屏
> `189.023333s / 2784x1808 / 60fps`，messages `1..29`、entities `7..8`、notifications `16..21` 连续，
> LLM 全 200，backend 只有刻意负路径 WARN，frontend 无运行时红线；证据与正负终帧封存于
> `/private/tmp/anselm-rig-formal-108/sessions/20260801-234249/`，fixture 与 conversation DELETE=204 后 GET=404。
> 五级裁决已写入 COVERAGE，中央账本 `295 judgments`，警报 clean。第六批未到 50 格，不跑统一长门禁、不提交；
> 下一前线为 `TOOL-051 delete_control`。
> `TOOL-050 revert_control` 的 formal-109 首轮冻结为红：托管模型将 integer version 发成字符串，UI 先显示失败卡，
> 随后 retry 成功；formal-110 修复后真实 App 正向只出现一张成功 `↩ v1` activity，负向不存在版本只出现一张
> 可解释失败卡且 active v1 不变。录屏 `147.631667s / 2784x1808 / 60fps`，messages durable `1..29`、
> notifications `1..7` 连续，entities 已连接，LLM 五个 chat completion request/response 全 200，backend 只有
> 刻意负路径 WARN，frontend 无运行时红线；证据与正负终帧封存于
> `/private/tmp/anselm-rig-formal-110/sessions/20260802-000259/`，fixture 与 conversation DELETE=204 后 GET=404。
> 五级裁决已写入 COVERAGE，中央账本 `300 judgments`，警报 clean。`TOOL-051 delete_control` 的 formal-111
> 首轮冻结为红：模型发出空参 `get_control`，destructive delete 缺少可见确认闸，且删除后再次 fetch 已不存在的
> control；红证据为 `/private/tmp/anselm-rig-formal-111/sessions/20260802-001430/evidence/tool-051-formal-111-red-missing-get-control-args.txt`，不计绿。
> stop-and-fix 将 `get_control` 的 `controlId` 必填/只读语义和 `delete_control` 的不可逆、必填 `controlId`、
> `dangerous`/HumanLoop approval 要求写入 schema/描述，并补契约测试与领域文档。formal-112
> `/private/tmp/anselm-rig-formal-112/sessions/20260802-002441` 真实正向先查关系、再只调用一次 delete；App
> 明确停在 `Dangerous · Awaiting your approval` 卡，批准后只有一张 `Allowed` 活动和 `1 refs affected`，无红卡、
> retry、重复 mutation 或 post-delete fetch。REST 证明实体 404、关系清空、版本 v1/v2 历史保留，workflow
> capability-check 明确报告缺失 control；screen.mov `293.141667s / 2784x1808 / 60fps`，messages durable
> `1..24`、notifications `1..7` 单调，entities 已连接，LLM 全 200，backend/frontend journal 无未解释红线。
> 正式证据为 `/private/tmp/anselm-rig-formal-112/sessions/20260802-002441/evidence/tool-051-formal-112-green.txt`。
> 五级裁决 `TOOL-051=G1/F2/A5/C4/G2` 已写入 COVERAGE，中央账本 `305 judgments`，警报逐级复审并串行 ack
> 后 clean；第六批未到 50 格，不跑统一长门禁、不提交；下一前线为 `TOOL-052 search_approval`。
> `TOOL-052 search_approval` 的 formal-113 使用三个 REST fixture 和真实 App 完成三条只读目的：`refund`
> 精确命中并从结果卡进入 Approval 详情看完整 description/template/rules；随机 query 返回明确 0 结果且无
> retry；空 query 返回 3 条并以 name/description 表格展示。wire 三次均各只调用一次 `search_approval`，SSE
> messages durable `1..40`、notifications `1..7` 单调，entities 已连接，LLM 状态全 200，backend 无 WARN/ERROR，
> frontend 无 Flutter runtime 红线；fixture 三条 approval 与两条 conversation 均 DELETE=204，列表清空且实体 GET=404。
> 正式证据为 `/private/tmp/anselm-rig-formal-113/sessions/20260802-003731/evidence/tool-052-formal-113-green.txt`。
> 五级裁决 `TOOL-052=G1/F2/A5/C4/G2` 已写入 COVERAGE，中央账本 `310 judgments`，警报逐级复审并串行 ack
> 后 clean；第六批未到 50 格，不跑统一长门禁、不提交；下一前线为 `TOOL-053 get_approval`。
> `TOOL-053 get_approval` 的 formal-114 使用真实 onboarding 和一个带三字段输入、完整 markdown template、allowReason、2h
> reject timeout 的 approval fixture，真实 App 正向只调用一次并逐层呈现 id/name/description、输入表、完整 template、Behavior Settings；
> 缺失 ID 负向只调用一次，显示明确 not-found 红卡和不编造详情的说明，无 retry。screen.mov `222.798333s / 2784x1808 / 60fps`，SSE
> messages durable `1..29`、notifications `1..5` 连续，entities 已连接，LLM chat completion 响应全 200，backend 仅刻意负路径 WARN，
> frontend 无 Flutter runtime 红线；approval/conversation DELETE=204 后列表为空、GET=404。证据为
> `/private/tmp/anselm-rig-formal-114/sessions/20260802-004855/evidence/tool-053-formal-114-green.txt`。
> `TOOL-054 create_approval` 的 formal-115 首轮冻结为红：托管模型将 `allowReason` 与 `inputs` 字符串化，后端首轮拒绝后模型 retry，真实 App 留下失败活动和成功活动并存；红证据为
> `/private/tmp/anselm-rig-formal-115/sessions/20260802-005845/evidence/tool-054-formal-115-red-stringified-scalars-and-retry.txt`，不计绿。stop-and-fix 在 approval 边界增加只接受 native 或精确 JSON 字符串的 bool/inputs decoder，inputs object 按 key 稳定排序，公开 schema 仍保持 boolean/array，并补定向 Go 测试与领域文档。
> formal-116 `/private/tmp/anselm-rig-formal-116/sessions/20260802-010803` 用新二进制、真实 onboarding、真实受管网关、Computer Use、独立三路 SSE witness、LLM tap 和连续录屏重跑：真实模型只发一次 `create_approval`，无 retry/search/第二次 mutation；App 只显示一张 Created activity 和完整表单结果，三个 typed inputs、template、allowReason、timeout、reject behavior、changeReason 均一致。
> 五通道已封存：screen.mov `245.026667s / 2784x1808 / 60fps`；SSE messages durable `1..15`，包含完成 close 与后续删除通知；LLM 首次 tool call 后下一轮带唯一 assistant call/tool result，最终 `finish_reason=stop`；backend/frontend 无未解释运行时红线。approval/conversation DELETE=204 后列表为空、GET=404。正式证据为 `/private/tmp/anselm-rig-formal-116/sessions/20260802-010803/evidence/tool-054-formal-116-green.txt`。
> 五级裁决 `TOOL-054=G1/F2/A5/C4/G2` 已写入 COVERAGE，中央账本 `320 judgments`，警报复审并串行 ack 后 clean；第六批当前 **24 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线为 `TOOL-055 edit_approval`。
> **最新状态(2026-08-02 02:10):** 第六批当前 **34 / 50**，中央账本 `330 judgments`，锚点校准有效，
> 警报复审后 clean；`TOOL-055 edit_approval` 已完成 formal-117/118 红路径、formal-119 前端语义修复和
> formal-120 正负五通道重跑。formal-117 暴露托管模型省略全量替换字段，formal-118 暴露缺少
> `changeReason`；两轮红证据分别保留在 `/private/tmp/anselm-rig-formal-117/sessions/20260802-011812/evidence/tool-055-formal-117-red-incomplete-edit.txt`
> 与 `/private/tmp/anselm-rig-formal-118/sessions/20260802-012450/evidence/tool-055-formal-118-red-missing-change-reason.txt`。
> formal-119 的真实 App 观察发现 edit 失败错误复用 create/draft 文案并显示可操作审批按钮；修复后失败 edit
> 明确“上一版仍有效”，不再渲染审批预览或按钮，并补 targeted Flutter regression。
> formal-120 session `/private/tmp/anselm-rig-formal-120/sessions/20260802-013952` 由真实 App、受管网关、
> Computer Use、三路 SSE witness、LLM tap 和连续录屏完成：正向只调用一次 `edit_approval` 将 v1→v2；负向只调用一次
> 空 `changeReason`，mutation 前拒绝且无 v3、无 retry。录屏 `417.105000s / 2784x1808 / 60fps`；messages durable
> `1..29`、entities `1..2`、notifications `1..6` 连续，LLM observed responses 全 200，backend 只有刻意负向
> validation WARN，frontend 产品运行时 marker scan clean。严格 `rig-check` 仅因 215 行 Computer Use 读取动态
> macOS AX 树产生的已知 `accessibility_bridge.cc` 观察噪声失败；该事实未隐藏，并与 formal-84 无 Computer Use 基线及
> formal-83/85 同类观察证据一致。fixture/conversation DELETE=204 后 GET=404、列表清空，rig-down 已收台。
> 正式证据为 `/private/tmp/anselm-rig-formal-120/sessions/20260802-013952/evidence/tool-055-formal-120-green.txt`；
> 五级裁决 `G1/F2/A5/C4/G2` 已写入 COVERAGE，下一前线为 `TOOL-056`。
>
> `TOOL-056 revert_approval` 的 formal-121 首轮冻结为红：托管模型将 `version` 发成字符串，后端拒绝并让 App
> 出现失败活动后准备 retry；红证据为 `/private/tmp/anselm-rig-formal-121/sessions/20260802-015701/evidence/tool-056-formal-121-red-stringified-version.txt`，不计绿。
> stop-and-fix 在 approval 工具边界增加 exact decimal integer string 兼容，公开 schema 仍为 integer，浮点/布尔/数组/坏字符串继续拒绝，
> 并补 approval 测试、工具描述和领域文档。formal-122 `/private/tmp/anselm-rig-formal-122/sessions/20260802-020059` 真实正向只出现一张
> `Reverted approval · ↩ v1`，负向 version 999 只出现一张可解释失败卡且 active v1 不变；无 retry、无 v3。录屏
> `100.383333s / 2784x1808 / 60fps`，messages durable `1..29`、notifications `1..7` 连续，entities 已连接，LLM observed responses 全 200，
> backend 只有刻意负向 version-not-found WARN，frontend/AXTree marker scan clean。REST/SQLite/UI/wire 一致，fixture/conversation DELETE=204 后 GET=404、
> 列表清空，rig-down 已收台。正式证据为 `/private/tmp/anselm-rig-formal-122/sessions/20260802-020059/evidence/tool-056-formal-122-green.txt`；
> 五级裁决 `G1/F2/A5/C4/G2` 已写入 COVERAGE，警报复审后 clean；下一前线为 `TOOL-057`。
>
> **最新状态(2026-08-02 02:23):** 第六批当前 **39 / 50**，中央账本 `335 judgments`，锚点校准有效，警报复审后 clean；未到 50 格不跑统一长门禁、不提交。
> `TOOL-057 delete_approval` 的 formal-123 `/private/tmp/anselm-rig-formal-123/sessions/20260802-020830` 首轮冻结为红：真实 App 确实展示了 `Dangerous · Awaiting your approval`，但人批准后模型仍错误声称没有 gate，并把软删除误报成“不可逆、所有版本移除”。红证据为 `/private/tmp/anselm-rig-formal-123/sessions/20260802-020830/evidence/tool-057-formal-123-red-gate-fact-and-delete-semantics.txt`，不计绿。
> stop-and-fix 在工具结果属性中保留真实 `humanApproval` 事实，仅向后续 LLM history 注入 `[Human approval granted before this tool executed.]`，不污染可见 tool card；同时把工具描述、approval 领域/API 文档和抽取清册统一为“软删主行、清关系、版本历史保留、需危险人闸”，并补 loop/approval 测试。
> formal-124 `/private/tmp/anselm-rig-formal-124/sessions/20260802-021702` 使用新二进制、真实 onboarding、受管网关、Computer Use、三路 SSE witness、LLM tap 和连续录屏重跑：真实 UI 一张 `Allowed` activity、`1 refs affected`，助手准确说明 gate 已展示并批准后才执行；REST/SQLite 证明 approval GET=404、versions 仍有 v1/v2、关系清空，临时 capability-check 诚实报告悬空引用。messages durable `1..26`、notifications `1..11` 连续，entities 已连接，LLM observed responses 全 200，backend/frontend 无未解释运行时红线；主 fixture、workflow、trigger、conversation 均 DELETE=204 后 GET=404，rig-down 已收台，证据保留。
> 五级裁决 `TOOL-057=G1/F2/A5/C4/G2` 已写入 COVERAGE；`gap-too-fast`/`discovery-collapse` 依据红绿两轮证据复审并串行 ack，最终 `alarms.py check` 为 clean。下一前线为 `TOOL-058 search_workflow`。
>
> **最新状态(2026-08-02 02:42):** 第六批当前 **44 / 50**，中央账本 `340 judgments`，锚点校准有效，警报复审后 clean；未到 50 格不跑统一长门禁、不提交。
> `TOOL-058 search_workflow` 的 formal-125 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-022906` 首轮冻结为红：直接查询 `invoice` 返回 3 条，其中两个是弱语义邻居；结果卡只给 id/name/description/snippet，缺少工具契约承诺的 tags/lifecycleState/active。红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-022906/evidence/tool-058-formal-125-red-search-fields.txt`，不计绿。
> stop-and-fix 保留统一搜索在无直接命中时的语义召回，但让 workflow 目录的直接关键词命中优先；语义 fallback 对每个结果 hydrate 完整 workflow，结果统一返回 tags/lifecycleState/active，并补 workflow/search 定向测试、工具抽取清册和 COVERAGE 描述。
> formal-126 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-023543` 使用新二进制、真实 onboarding、受管网关、Computer Use、三路 SSE witness、LLM tap 和连续录屏重跑：`invoice` 精确命中 1 条且完整字段可见；随机 query `zzqvulon_058_no_match` 明确 0 条；空 query 列出 3 条且逐行展示 name/tags/lifecycleState/active；点击 invoice 结果正确进入 Workflow 详情，显示 v1、inactive、描述、标签、精确 ID、1 node、No alerts。三次各只调用一次 `search_workflow`，无 retry/其它工具。录屏 `317.481667s`，SSE messages durable `1..38`、notifications `1..9` 单调，LLM observed response 全 200，backend/frontend 无未解释红线；删除通知也被 SSE 观测。conversation 与三个 workflow fixture DELETE=204 后列表为空、GET=404，rig-down 已收台，证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-023543/evidence/tool-058-formal-126-green.txt`。
> 五级裁决 `TOOL-058=G1/F2/A5/C4/G2` 已写入 COVERAGE；`gap-too-fast`/`discovery-collapse` 依据 formal-125 红证据与 formal-126 五通道绿证据复审并串行 ack，最终 `alarms.py check` 为 clean。下一前线为 `TOOL-059 get_workflow`。
>
> **最新状态(2026-08-02 02:53):** 第六批当前 **49 / 50**，中央账本 `345 judgments`，锚点校准有效，警报复审后 clean；未到 50 格不跑统一长门禁、不提交。
> `TOOL-059 get_workflow` 的 formal-127 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-024437` 使用真实 onboarding 建立 function、cron trigger 与含 trigger→action edge 的 workflow。正向真实 App 先读 v1，再把无效的 test-only trigger ref 换成真实 cron source 生成 v2；最终只调用一次 get_workflow，完整展示 active version=2、lifecycleState=inactive、active=false、concurrency=replace、两个 node refs 和一条 edge。点击 `Viewed workflow` 能打开实体信息，滚动后 edge 表完整可见。缺失 ID 与空对象各只调用一次，分别显示 `workflow not found` 和 `workflowId is required`，无 retry/伪造。红/中间帧不计绿：一次未等待结果卡异步展开的 AX 读数只显示表头，等待后 Computer Use 画面与 AX 树均确认完整。
> 五通道已封存：录屏 `430.360000s`；SSE messages durable `1..58`、entities `1..2`、notifications `1..11` 单调，LLM observed response 全 200，backend/frontend 无未解释红线；REST/versions/capability-check 与最终 tool result 一致。workflow、trigger、function、conversation DELETE=204 后列表为空、GET=404，rig-down 已收台，正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-024437/evidence/tool-059-formal-127-green.txt`。
> 五级裁决 `TOOL-059=G1/F2/A5/C4/G2` 已写入 COVERAGE；`gap-too-fast`/`discovery-collapse` 依据 formal-127 正负五通道证据复审并串行 ack，最终 `alarms.py check` 为 clean。下一前线为 `TOOL-060 create_workflow`。
>
> **上一状态(2026-08-02 04:04):** 第六批已完成 **50 / 50**，中央账本 `350 judgments`，锚点校准有效，`alarms.py check` clean；因 formal-129/130 暴露的漏元数据风险又在 `ValidateInput` 增加了写库前存在性/类型门，并通过定向回归。随后按 fixture 审计清掉数据库中遗留的 acceptance conversation（DELETE=204→GET=404，SQLite `deleted_at` 对证）；全量 live 产品实体为零，唯一保留的是契约要求的最后一个 workspace。统一 `make verify`、完整 `testend`、文档、锚点、警报、进程和工作树审计均通过，批次已提交 `8e2c93e4`。第七批从 **0 / 50** 开始，下一前线为 `TOOL-061 edit_workflow`。
> `TOOL-060 create_workflow` 的 formal-128 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-025448` 首轮红：模型将 `ops` 发成字符串且先后两次重试，前端留下两个失败活动；formal-129 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-030431` 修复 ops 后暴露 metadata 槽位被模型静默省略；formal-130 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-030934` 强化描述后仍暴露可选 metadata 被省略。三轮红证据均保留、不计绿。
> stop-and-fix 在 workflow 执行边界加入窄 `tags` decoder：原生字符串数组与精确 JSON 数组字符串均接受，逗号分隔文本、对象、非字符串元素拒绝；同时在 `ValidateInput` 写库前要求 `description`、`tags`、`changeReason` 三个键真实出现，空值只能分别用 `""`/`[]` 表达，显式 `null` 和错误类型拒绝。schema/工具描述、workflow 领域文档、错误码、抽取清册和 Go 守卫测试同步更新。
> formal-131 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-031452` 真实 App 重跑时 metadata 已到达但 `tags` 字符串在通用反序列化阶段失败，红证据为 `evidence/tool-060-formal-131-red-required-metadata-ops-error.txt`，没有 workflow 落盘且没有重试。
> formal-132 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-032142` 用新二进制、真实 onboarding、受管网关、Computer Use、三路 SSE witness、LLM tap 和连续录屏完成绿验证：模型只调用一次 `create_workflow`，真实 wire 同时使用 stringified `ops`/`tags`，后端成功创建 v1 inactive；REST 证明 description、tags、changeReason 逐字保存，graph 为 2 nodes/1 edge，UI 只有一张 `Created · v1 · Not activated` 活动卡，无 retry/get_workflow。backend/frontend 无未解释红线，四类资源 DELETE=204 后 GET=404，rig-down 正常。绿证据为 `evidence/tool-060-formal-132-green-stringified-metadata.txt`。
> **最新状态(2026-08-02 04:53):** 第七批当前 **10 / 50**，中央账本 `360 judgments`；锚点已重新校准，`alarms.py check` 在 formal-062 复审后 clean，未到第 50 格不跑统一长门禁、不提交。
> `TOOL-061 edit_workflow` 正向用户目的与缺失 workflow 失败边界均已用真实 App、受管网关、Computer Use、三路 SSE、backend/frontend journal 和 LLM wire 复核。正向证据来自 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-041823`；正式负向证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-042438/evidence/tool-061-formal-acceptance.txt`，只发一次合法 `edit_workflow`，只出现一张失败活动，无 retry、search、create 或 mutation。
> stop-and-fix 已修复 workflow `edit_workflow` 与文件系统 `Edit` 的工具描述/schema 碰撞，并补了 Go 工具描述回归；同时修复 New chat 清理 landing draft/附件的前端状态泄漏，Flutter 定向测试 22 项、workflow/loop Go 定向测试均通过。探索性错误调用保留为红事实，不计绿。
> `TOOL-062 revert_workflow` 的早期 formal-133 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-043458` 暴露 hosted model 将 version 发成字符串而首轮失败后 retry；formal-134 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-044050` 又暴露模型省略 version、先查 `get_workflow` 再 retry。两轮红证据均不计绿。stop-and-fix 在执行边界加入 native/exact-decimal-string decoder，并强化同一调用双必填、不得 inspect/retry、失败结果权威的工具描述/schema、Go 测试和 workflow 文档。
> formal-135 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-044518` 用真实 App、受管网关、Computer Use、三路 SSE、LLM wire、backend/frontend journal 完成正负五通道重跑：正向一次 stringified version `"1"` 成功回退 v2→v1；负向一次 version `999` 精确失败，无 retry、无 `get_workflow`。REST/SQLite 证明 active v1、v1/v2 两条历史保留；screen.mov `257.141667s`，前端无 runtime marker，后端仅刻意 not-found WARN。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-044518/evidence/tool-062-formal-acceptance.txt`。
> fixture 已按真实 API 清理：conversation `cv_45de987450a07cff`/`cv_d76f4c06c1b1556e` 与 workflow `wf_de4c9d5fd9192998` 均 `DELETE=204` 后 `GET=404`，三类列表均为空；SQLite 仅剩最后一个 live workspace，conversation/workflow live 行为零，messages/message_blocks/workflow_versions/notifications 审计行保留。下一前线为 `TOOL-063 delete_workflow`。
> 五级裁决 `TOOL-060=G1/F2/A5/C4/G2`、`TOOL-061=G1/F2/A5/C4/G2` 与 `TOOL-062=G1/F2/A5/C4/G2` 均已写入 COVERAGE；本批 gap/discovery 警报按证据重审并销账，当前账本为 `360 judgments`，可继续接受新 pass。
>
> **开工前提已满足**:另一团队的后端大改(BYOK 全目录 / 生成收归受管 / 音色 / 媒体子域 …)已并入
> `main`;本仓与隔壁 `Anselm-API-Serve` 均已对齐到各自最新 `main`。
>
> **本页是战役的唯一盘上真相**:对话记忆不是记录,任何会话中断/上下文压缩后,下一轮从本页 +
> 附属账本(Day 0 建)+ git 幂等续跑。战役期间**单一作者会话**(用户裁定,见 P11),施工在主树。

---

## §0 一句话与判据金字塔

**真实起 App、真实联通 Anselm 免费网关,以 Computer Use 逐帧驱动与观测,把产品的每一个角落
——真的全部——端到端测干净、修干净;遇到任何问题(含产品直觉级)停下修好再出发;
预期以一周为预算的连续 loop。**

每个被测点过**五级判据**,全过才算过:

1. **办成了吗**——用户目的达成(最高判据:不是步骤走完,是这件事真办成了)。
2. **真的吗**——五通道互证:UI 呈现 == SSE 帧 == DB 行 == 后端日志 == LLM 线缆,任何一对不一致即 bug。
3. **顺吗**——丝滑军规(跳变/闪/骨架/锚点漂移;录屏抽帧逐帧看)。
4. **美吗**——craft bar,对标 Linear/Things/Craft 级桌面手感;**看着不舒服就是 bug**,
   不需要「违反了哪条既有规范」作为立案理由(判决仍须援引法典或测量值,法不够就先立法)。
5. **一个新用户能自己走到这吗**——引导与可发现性。

## §1 拍板台账(证据分级:带原话 / 未被否决)

> 分级沿 WRK-082 §1 的教训:「带原话」= 引号内是用户对话原文;「未被否决」= 我提议、
> 用户未反对即入宪,效力相同、记录必须分开,随时可翻案。

**带原话(2026-07-27 讨论,按对话序)**:

| # | 决策 | 原话要点 |
|---|---|---|
| P1 | **战役本体**:真实起 App + 真实联通免费网关,Computer Use 监控每一帧,同时健康后端、SSE 流、前端 Terminal;每个问题停下修好再出发,细到打字跳变级 | 「真实起App,真实联通Anselm免费网关」「监控每一帧」「细致到你觉得这里打个字为什么有个跳变,这种问题我们都停下来修好再出发」 |
| P2 | **范围 = 产品真的全部**;难触发路径构造数据测 | 「你看代码发现这里有一个rag,OK那你就要测,即使这个rag是很难触发的,OK那我们构造数据测」 |
| P3 | **产品向修复直接修、无需过问** | 「你测试感觉这里用户等太久了不舒服,OK那你加对应提示。直接修改无需过问」 |
| P4 | **形态 = loop,一周为预期** | 「这个东西我的预期是一个loop,我们照着一周去跑」 |
| P5 | **product-driven 端到端**:判「用户目的达成没有」、跨域组合线在产品里通不通 | 「对话一下,是不是真的能达成用户的目的,比如说生图改图放workflow,这些东西在产品里通不通」 |
| P6 | **judge 标准 = craft 级**,视觉细节不合格即修 | 「Document里你滑一下,高亮一块内容。发现这个蓝色高亮不标准不好看,那就改,改成等高的舒服好看的」 |
| P7 | **两轮方案相乘**:全量清册的「面」×product-driven 五级判据的「深」,每格必填,无浅测点、无降级区 | 「我觉得我要的是我们这两轮说的东西乘起来」 |
| P8 | **网关侧临时去配额** | 「网关我会暂时做成没有配额的」 |
| P9 | **专用机器,24h 独占** | 「机器我单独给你配了一台电脑。这台电脑24小时都是你的,我不会打扰」 |
| P10 | **修复权限边界认可**(直接修 + 代拍台账,产品形状级决策才停下等拍)+ **前置工程认可**(台架与清册各投约一天) | 「产品边界我认。前置工程我也认」 |
| P11 | **单一作者连续施工,不换 agent;质量控制全靠机制**,用户不在场是默认假设;金标准取行业已知 | 「不同意换agent施工。我这边没办法老看你。我想这一切靠机制来控制。很多东西的金标准其实全行业都知道的」 |
| P12 | **旅程目录至少 400 条、非排列组合堆砌、对产品 100% 覆盖**——⏸ **用户 0728 裁定推迟到二期迭代,一期照现有 47 条旅程开跑**。原拍板:「Journey实在是太少太少了,产品的可能性非常多……至少400条,而且不是靠排列组合堆砌的……我希望能够做到对产品100%覆盖」;推迟原话:「那我们抛弃吧,我不想再浪费token了,journey的优化我后面放二期迭代」。**核验器 `testend/rig/check_journeys.py` 已在盘上并自证基线**(读 0%,因 47 条版无「扫」字段),二期照做法直接落:每条旅程带「扫」字段逐字认领清册行,脚本 diff 出未认领行,认领不动的进「幕后」段给理由。**一期不受阻**——清册 848 行仍是覆盖真相源,主循环按 COVERAGE 面矩阵驻停清扫,旅程只作路线 | 见左 |
| P13 | **对齐新 main 时整体清零我方代码差异**——两仓都拉到最新 `main`;`Anselm-API-Serve` 不允许有任何差异;本仓唯一允许的差异是 `docs/working/acceptance-loop/` 这套战役文档。据此撤下:台架三件套与两个 tap、测量脚本箱、gate/警报/核验器/生成器、`proxycore` 重构、后端 `ANSELM_PROOF_HOST`、`api.md` 四处 `[doc-fix]`(后三者原地已被新 main 的改动覆盖或作废) | 「我们这边不要有任何diff,抛弃我们所有其他的commit,对比最新main分支,API Serve不允许有差异,我们这边的差异是,我们这docs里加一下我们新的这个working」 |
| P14 | **P13 的撤下是误点,当日翻案:台架照原标准全量重落**——「标准不能变」;并新增一条硬要求:**台架必须做到任何 agent 都能用**(不依赖单一会话的记忆)——落为 [`testend/rig/README.md`](../../../testend/rig/README.md) 自足操作手册 | 「哦,我需要你给我把这些坐回来。标准不能变的。刚刚点错了……而且还有一个要求,哪个agent来都可以用」 |
| P15 | **以 50 个 COVERAGE 单格为一个施工批次**:单格仍逐个真实验证、发现即停修;累计到 50 格后统一跑门禁、完整 testend、警报复核并提交,不为赶批次降低质量 | 「门禁你也看到了,特别特别长,所以走完50个格子后,才开始统一搞一次门禁+提交」 |

**未被否决(我提议,用户未反对;翻案即改)**:

| # | 提议 | 要点 |
|---|---|---|
| N1 | **五通道观测**全部落盘 journal:帧(截图+录屏抽帧)/ 后端日志 / SSE tap(独立第四只眼)/ 前端 console / **LLM 线缆**(testend `harness.Recorder` 提升为台架常备件) | 「盯着看」过不了诚实律;第五通道是「不采信模型自述」唯一站得住的方式 |
| N2 | **二维矩阵双账**:面矩阵(清册行 × 五级判据列,格=裁决+证据指针,一行全列绿才算完)+ 旅程账(目的达成 **且** 沿途每站整列点亮才 ✅),互相引用、diff 出孤行与只路过未清扫的行 | 乘法的记账形 |
| N3 | **旅程走线 × 驻停清扫**:旅程给路线与产品语境;每到一站打开该面清册页穷尽掉(每状态/控件/边界/构造变体全过五级)才离站;无旅程经过的清册行写构造补线(仍以用户视角写) | 「带着房间清单的深度清扫,沿旅程路线走」 |
| N4 | **三压缩器**:原语级修复(修在 token/原语上,整列翻绿)· 同类横扫(发现一处即横扫同类面)· 现场立法(裁决沉淀成法,后面机械地审) | 乘法体量(万级格子)可行性的来源 |
| N5 | **控制系统六机制**(纯机制、零人力、单一作者,详见 §4):法典先行 / 判断降为测量 / 账本 gate / 锚点机械自校 / 统计警报 / 守卫+夜间门禁压舱 | 承诺的不是「不下滑」,是「下滑活不过一天且有纠偏程序」 |
| N6 | **旅程目录开跑前用户过目一次**——✅ 用户已过目并裁定现版太少；随后按 P12 明确把 400+ 扩写推迟二期，因此一期不再受此触点阻塞 | 唯一保留的用户触点已完成 |
| N7 | **完成判据 = 清册干涸(矩阵全绿),一周 = 预算非判据**;溢出诚实溢出在账上,绝不合并格子宣称测过 | 诚实律 |
| N8 | **AI 引导面也是产品面**:工具描述/system prompt 装配/模型跑偏时的兜底,判「产品聪明不聪明」,在直接修权限内,修完真对话复验 | AI 产品特有的一层 |
| N9 | **停与修分离**:停是义务(前线冻结、格子红着),修不必在同一口气里赶完 | stop-and-fix 的本义是前线不带病推进 |

## §2 战役形状:乘法模型

**旅程为「深」的载体、清册为「面」的保证,逐格相乘**:

- **旅程(Journey)**:一个真实用户带一个真实目的进来,端到端走完。预计 40–60 条主线 +
  死角补充线。示例密度(定稿在 JOURNEYS.md):生图迭代线(画→多轮改→嵌文档→@文档续聊→放 workflow
  日更)· 从零建自动化线(纯对话建 fn/agent/cron→真 fire→通知带图→`:iterate` 改→改坏 replay)·
  真实工作线(驻地挂真 git 仓、越界闸、worktree)· 长跑衰减线(100+ 回合、压缩后记忆、fork/retry/版本翻页)·
  吃进真世界线(PDF→笔记→fn 图表→嵌文档三保真)· 降级不失格线(断网/网关挂/key 失效/模态缺失,
  产品「诚实且体面」)。
- **清册(Coverage)**:从代码机械提取——113+ 工具注册表 / 28 REST 资源域 / 12 sidestage kind /
  7 block 型 / 5 图节点 kind / 4 trigger 源 / 5 overlap 策略 / 5 媒体产地 × 3 模态 × 6 渲染面 /
  13 设置面板 / 四海洋每屏每控件 / **i18n 键全集**(每个 key = 一个必须能到达的画面)/
  错误码按可浮上 UI 的类分层 / 难触发路径清单(RAG·压缩水位·410 重放·fork 重定基·envfix·
  配额边界·断网启动·install 自愈…每条带构造配方)。预估 600–1000 行。
- **乘法语义**:判据不因面偏僻而降级——错误态的措辞/排版/恢复路径/动效同样要过 craft 档;
  一站清完整列点亮,后续旅程再经过不重扫(被修复碰过的除外,触发回归重验)。

## §3 五通道台架(全部落盘,附自检)

| 通道 | 形态 | 答什么 |
|---|---|---|
| 帧 | Computer Use 截图 + `screencapture -v` 录交互段 → ffmpeg 抽帧 filmstrip | 跳变/闪/骨架/漂移——逐帧唯一取证方式 |
| 后端 | sidecar 日志全量 journal;场景收尾「零未解释 WARN/ERROR」+ DB 对证(`make -C backend seed` 的 probe env) | 执行的实际东西是否正确,以行为证 |
| SSE | 独立 tap(token+workspace 头连三条流,逐帧带时戳落 JSONL),不经前端 demux | seq 单调/durable·ephemeral 纪律/close 快照与 DB 一致 |
| 前端 | `flutter run` console 全量 journal;确认 FlutterError.onError/zone error 都汇到 console;任何红行 = issue | 隐藏前端报错 |
| LLM 线缆 | `harness.Recorder` 提升为台架常备件,provider base URL 指过它 | 模型这轮真收到了什么,逐字节,不采信模型自述 |

**台架自检**(F1 教训「先查夹具再报缺陷」):开工首事验台架自己——字体载齐、tap 真连上、
recorder 真在录;自检项常驻,台架变更后重跑。

## §4 控制系统(六机制,纯机制、单一作者)

1. **法典先行(CODEX)**:Day 0 把行业金标准一次性落成可执行法典——macOS HIG / RAIL·Doherty
   时延预算(<100ms 即时感、400ms 注意力阈、16.7ms/帧)/ WCAG 对比度 / 动效时长与 easing 标准区间 /
   Nielsen 错误信息十律 / 选区与文本渲染既知正确形,叠加仓内丝滑军规与 design token。每条法:
   ID + 尽可能机械的判定条件(px/ms/比率)+ 正反例。**裁决必须援引法条 ID 或测量值**,
   账本 lint 强制;援引不了 = 先立新法再判。
2. **判断降为测量**:能量的绝不用看——高亮等高(几何提取)/ 跳变(相邻帧像素 diff)/ 时延
   (操作时戳→首帧反馈差值)/ 对齐(包围盒对网格)/ 对比度(取色计算)/ 骨架时长(vs 160ms 闸)。
   每降一类,它永久退出「会下滑」的集合。眼睛只留给量不了的部分,且那部分也在「适用法律」。
3. **账本 gate**:标绿是脚本动作非文本编辑——校验证据文件真实非空、五通道 journal 齐、法条引用合法、
   该跑的测量脚本跑了且过、修复类格子附守卫测试;前置缺失,绿灯物理打不上。
4. **锚点机械自校**:Day 0 冻结一组锚点格子的裁决(含该过与该扣,craft 档为主);每次会话开工,
   harness 剥掉答案发盲判,脚本 diff 现判 vs 冻结判;不一致 → halt 标志、前线冻结,重读法典 +
   回审近期裁决,锚点全对才解锁。锚点永不更换、永不重判。
5. **统计警报**:夜间脚本算三条曲线,异常开警报单,警报未销则 gate 拒收新格子——通过速率异常偏高
   (橡皮章信号,该时段裁决入重审队列)/ 发现率骤降(更可能是判断失灵而非产品变干净)/
   裁决时戳间隔快得不像真看过录屏。
6. **守卫 + 夜间门禁压舱**:每修必带守卫测试;夜间全量 `make verify` + testend + 已修场景回归重放。
   机械部分不随状态波动。

**用户触点收敛到两点**:产品形状级拍板点(攒着,不阻塞的先代拍记入 §6 台账)+ 想看才看的周报。
系统按用户完全不看来设计(P11)。

## §5 Day 0 交付物清单(前置工程,约 1–2 天,全部入 git、全部过门禁)

1. 五通道台架 + 台架自检项(§3)。
2. 测量脚本箱(§4.2 各测量器)。
3. **CODEX.md** 法典(§4.1)。
4. **COVERAGE.md** 清册与面矩阵(§2;多 agent 机械提取 + 完备性批评家反向 diff)。
5. **JOURNEYS.md** 旅程目录(§2;开跑前用户过目一次,N6)。
6. 账本 gate 脚本(§4.3)。
7. 锚点集(§4.4)。
8. 警报脚本(§4.5)。
9. **[LOG.md](LOG.md)** 逐日日志 + 代拍台账(§6)。

证据(PNG/录屏/journal)落专机本地目录、不入 git,账上记指针;路径 Day 0 定稿后回填本节。

### 5.1 真机闭环(2026-08-01,当前实现)

在隔壁团队大改合并后的最新 `main` 上，以**全新数据目录**执行了一次完整闭环：`rig-up` 建并托管
五个进程组 → App 显示首次 onboarding → Computer Use 创建 `Rig Smoke` workspace → sidecar 经
本机 llmtap 完成 challenge/install/models(均 200)→ ssetap 在 workspace 出现后自动发现并接入
messages/entities/notifications 三流 → `rig-check` 五通道全绿 → `rig-down` 依次收 App、后端、SSE、
llmtap，最后以 SIGINT 封口录像。收台后无幸存进程，`screen.mov` 经 ffprobe 可读(78.02s)。

本轮不是“组件理论可用”，而是确认了以下真实边界：

- `screencapture -v` 录制中不会产生可读 MOV，故 L2 裁决只接受 **rig-down 后**已封口且 ffprobe
  可读的会话。
- onboarding 前没有 workspace；ssetap 必须常驻轮询并动态接管后续创建的每个 workspace，热切换
  也不得丢观察面。
- conductor 派生进程必须独立 session；普通后台子进程会随启动 shell 退出，造成“刚绿即死”。
- 透明代理只转发 `Flush` 不够；`ResponseController` 必须能 `Unwrap` 到 `Hijacker`，否则 SSE 正常而
  WebSocket 语音路径全部 500。真实 101 upgrade 已有守卫测试。
- Flutter runner 与 console、录像、后端和两类 tap 全部由同一 manifest 归属；外部手起 App 或旧
  sidecar 不算验收证据。

### 5.2 Day 0 当前状态(整体重述,2026-08-29 EDGE-312 版本组走 retryOf L3 完成；批次 10/50)

`EDGE-312` 已完成本批次第 `10` 格的 L3 提升：真实 App 的 retryOf 版本组在当前、中间、最旧和恢复当前四种状态间切换，用户触发变化与静止期分离，稳定段无超阈值变化。L1/L2/L3=`✓`，L4/L5=`~`；本格不把未测的 craft 与 discoverability 冒充通过。

正式证据=`testend/rig/formal-evidence/EDGE-312-retry-version-groups-l3-real-app-20260829.md`，告警复审=`testend/rig/formal-evidence/EDGE-312-retry-version-groups-l3-ledger-alarm-reaudit-20260829.md`。session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-092651`，录屏和 backend/frontend/SSE/LLM journal 均属于同一已封口台架会话，锚点=`10/10`。

`judge.py` 已按 `B2` 写入 L3，`gen_coverage.py --check` 应保持 `848/848/0`，`alarms.py check` 必须保持 clean。当前批次由 `9→10/50`；未满 50 不执行统一长门禁、不提交。标准、阈值、法典、锚点和正式序列不变。P12 的 400+ Journey 扩写按用户裁定推迟二期。

#### 2026-08-29 · EDGE-294 触点不记幽灵删除的真实 App L2 完成

正式 clean session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-151503`，workspace=`ws_6b1a68d7272543a9`，conversation=`cv_67b4397afdc3e6d8`。真实后端创建临时 Agent `ag_48d56677797d099a`，真实 App 通过 Composer 请求删除；模型先搜索到唯一目标并展示危险确认卡，说明 `agentId`、删除语义和审计保留。Computer Use 点击 `Deny` 后，App 明确回执“删除操作已被拒绝。如需继续，请告知”，没有自动重试。

五通道 `rig-check`/`rig-down` 通过且录屏无外部遮挡；backend 无应用级 WARN/ERROR/panic/FATAL，frontend 无 Flutter/Dart/RenderFlex/Unhandled 红线；SSE messages 记录 interaction、resolved interaction 和 denied `tool_result`，没有 `agent.deleted` 或 touchpoint deleted 帧；LLM tap 中 `delete_agent` 保持 `dangerous`，工具结果为拒绝且不得重试；收台前 Agent `GET` 为 `200`，touchpoints=`[]`，notifications 无删除行，SQLite `integrity_check=ok`、`foreign_key_check` 为空。正式关键帧=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-151503/evidence/EDGE-294-denied-delete.jpeg`，正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-151503/evidence/EDGE-294-touchpoint-deny-no-delete-real-app-20260829.md`，独立警报复审=`testend/rig/formal-evidence/EDGE-294-ledger-alarm-reaudit-20260829.md`。

`judge.py` 按 `F1` 写入 `L2 ✓`，清册=`✓✓~~~`；L3-L5 保持 `na`，不把安全闸正确冒充顺滑、视觉 craft 或可发现性结论。锚点=`10/10`，写账触发的 `discovery-collapse` 已按原阈值独立复审并 ack，未改变阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2011 live judgments; 2300 baseline excluded)`，`gen_coverage.py --check`=`848/848/0`。批次由 `49→50/50`，开始统一批次门禁、完整回归、工作树审计与提交流程；P12 的 400+ Journey 扩写按用户裁定推迟二期。

#### 2026-08-29 · EDGE-298 未读徽标绝不据帧 +1 的真实 App L2 完成

正式 clean session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-151051`，workspace=`ws_1837441baa7435ac`。真实后端先将 seed 通知全部标已读，权威 `unread-count=0`；创建 Memory 后变 `1`，再次清零；更新同一 Memory 的持久 `memory.updated` 后变 `1`；随后 pin 触发同类型 Broadcast，权威计数保持 `1`。真实 App 通知中心显示唯一新增未读 `Memory "edge298-probe" updated`，左下铃铛只保留一个未读提示点。

五通道 `rig-check`/`rig-down` 通过且录屏无外部遮挡；backend 无应用级 WARN/ERROR/panic/FATAL，frontend 无 Flutter/Dart/RenderFlex/Unhandled 应用红线；SSE notifications 的 `memory.created`=`seq=16` 与持久 `memory.updated`=`seq=17` 带 `inbox=true`，pin 的同类型 Broadcast=`seq=18` 不带 `inbox`，durable seq 单调；REST notifications 只保留一条未读更新行，Memory 行返回 `pinned=true`；SQLite `integrity_check=ok`、`foreign_key_check` 为空。正式关键帧=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-151051/evidence/EDGE-298-unread-badge.jpeg`，正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-151051/evidence/EDGE-298-unread-authoritative-count-real-app-20260829.md`，独立警报复审=`testend/rig/formal-evidence/EDGE-298-ledger-alarm-reaudit-20260829.md`。

`judge.py` 按 `F1` 写入 `L2 ✓`，清册=`✓✓~~~`；L3-L5 保持 `na`，不把未读计数正确冒充顺滑、视觉 craft 或可发现性结论。锚点=`10/10`，写账触发的 `discovery-collapse` 已按原阈值独立复审并 ack，未改变阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2010 live judgments; 2300 baseline excluded)`，`gen_coverage.py --check`=`848/848/0`。批次由 `48→49/50`，未满 50 格不跑统一长门禁、不提交；下一原子继续选择最后一个尚未具备正式 L2 的 `~` 格。P12 的 400+ Journey 扩写按用户裁定推迟二期。

#### 2026-08-29 · EDGE-292 todo 全完成后被问清单的真实 App L2 完成

正式 clean session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-150633`，workspace=`ws_8e85f7b70fb731d4`，conversation=`cv_6105f53dc95842cb`。真实 App 通过一条 Composer 消息依次调用 `todo_write` 建立两个任务、再次调用 `todo_write` 全部完成、最后调用 `todo_read`；画面逐步显示 `2 items · 0 done`、`2 items · 2 done`、`Read checklist · 2 items · 2 done`，最终准确报告 `EDGE292 first task` 与 `EDGE292 second task`。

五通道 `rig-check`/`rig-down` 通过且录屏无外部遮挡；backend/frontend 无应用级 WARN/ERROR/panic/FATAL/Flutter/Dart/RenderFlex/Unhandled 红线；SSE messages durable seq 单调，三次 tool_call 与三份 tool_result 均可见；LLM tap challenge/install/models 与全部 chat-completions continuation 均为 `200`，只调用 `todo_write`、`todo_write`、`todo_read`；REST messages 与 SQLite `integrity_check=ok`、`foreign_key_check` 为空。正式关键帧=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-150633/evidence/EDGE-292-todo-completed-read.jpeg`，正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-150633/evidence/EDGE-292-todo-completed-read-real-app-20260829.md`，独立警报复审=`testend/rig/formal-evidence/EDGE-292-ledger-alarm-reaudit-20260829.md`。

`judge.py` 按 `F1` 写入 `L2 ✓`，清册=`✓✓~~~`；L3-L5 保持 `na`，不把清单读回冒充顺滑、视觉 craft 或可发现性结论。锚点=`10/10`，写账触发的 `discovery-collapse` 已按原阈值独立复审并 ack，未改变阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2009 live judgments; 2300 baseline excluded)`，`gen_coverage.py --check`=`848/848/0`。批次由 `47→48/50`，未满 50 格不跑统一长门禁、不提交；下一原子继续选择尚未具备正式 L2 的 `~` 格。P12 的 400+ Journey 扩写按用户裁定推迟二期。

#### 2026-08-29 · EDGE-291 memory 更新保留策展的真实 App L2 完成

正式 clean session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-145816`，workspace=`ws_c7e240b31152790e`。真实 App 先通过 Memory API 建立 `edge291-rule` 并由用户动作置顶，再在干净新对话中用一条不含换行的 Composer 消息要求 `write_memory` 更新已有记忆。真实 App 回执确认“已更新 edge291-rule 记忆，描述和内容均已修改”，随后打开 Settings → Memory，画面仍显示置顶图钉、更新后的描述、`user` 来源和日期。

五通道 `rig-check`/`rig-down` 通过且录屏无外部遮挡；backend 无应用级 WARN/ERROR/panic/FATAL，frontend 无 Flutter/Dart/RenderFlex/Unhandled 应用红线；SSE notifications 收到最终 `memory.updated`（`seq=27`）且 durable seq 单调；LLM tap 的正式单消息 continuation 链均为 `200`，出现恰好一条 `write_memory` 工具调用并完成回合；SQLite `integrity_check=ok`、`foreign_key_check` 为空。早先含换行的输入实验因 `type_text` 会把换行模拟成 Return 而拆成两条消息，已明确排除，不作为产品证据。正式关键帧=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-145816/evidence/EDGE-291-memory-chat.jpeg`、`EDGE-291-memory-panel.jpeg`，正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-145816/evidence/EDGE-291-memory-curation-real-app-20260829.md`，独立警报复审=`testend/rig/formal-evidence/EDGE-291-ledger-alarm-reaudit-20260829.md`。

`judge.py` 按 `F1` 写入 `L2 ✓`，清册=`✓✓~~~`；L3-L5 保持 `na`，不把 pin/source 保留冒充顺滑、视觉 craft 或可发现性结论。锚点=`10/10`，写账触发的 `discovery-collapse` 已按原阈值独立复审并 ack，未改变阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2008 live judgments; 2300 baseline excluded)`，`gen_coverage.py --check`=`848/848/0`。批次由 `46→47/50`，未满 50 格不跑统一长门禁、不提交；下一原子继续选择尚未具备正式 L2 的 `~` 格。P12 的 400+ Journey 扩写按用户裁定推迟二期。

#### 2026-08-29 · EDGE-293 删被依赖实体的真实 App L2 完成

正式 clean session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-145009`，workspace=`ws_68ea73847fa70778`。真实后端创建三个 Agent 并让它们都挂载 Function `fn_60afa16282a3a131`（`greet`），随后删除该 Function；HTTP 返回 `204`。真实 App 打开 Notifications 后显示 `Function "fn_60afa1..." was deleted, leaving 4 references dangling`，逐一列出 `deploy-helper` 与三个 EDGE293 Agent，同时保留单独的 `Function "greet" deleted` 事件。用户可以从一个通知直接理解删除的影响范围。

五通道 `rig-check`/`rig-down` 通过且录屏无外部遮挡；backend 无应用级 WARN/ERROR/panic/FATAL，relation purge 实际记录 `removed=4`；SSE notifications 只有一条 `relation.dependency_broken`（`seq=21`），payload 的四个 `dependents` 与 REST `/notifications` 完全一致；frontend 真实通知列表无应用级红线；llmtap challenge/install/models 全 `200`，本场景没有虚假 LLM 调用；SQLite `integrity_check=ok`、`foreign_key_check` 为空。正式关键帧=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-145009/evidence/EDGE-293-notification-aggregate.jpeg`，正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-145009/evidence/EDGE-293-dependency-broken-real-app-20260829.md`，独立警报复审=`testend/rig/formal-evidence/EDGE-293-ledger-alarm-reaudit-20260829.md`。

`judge.py` 按 `F1` 写入 `L2 ✓`，清册=`✓✓~~~`；L3-L5 保持 `na`，不把影响范围可见性冒充顺滑、视觉 craft 或可发现性结论。锚点=`10/10`，写账触发的 `discovery-collapse` 已按原阈值独立复审并 ack，未改变阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2007 live judgments; 2300 baseline excluded)`，`gen_coverage.py --check`=`848/848/0`。批次由 `45→46/50`，未满 50 格不跑统一长门禁、不提交；下一原子继续选择尚未具备正式 L2 的 `~` 格。P12 的 400+ Journey 扩写按用户裁定推迟二期。

#### 2026-08-29 · EDGE-279 对话挂载文档删除后的真实 App L2 完成

正式 clean session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-144028`，workspace=`ws_6161a430bf326410`，conversation=`cv_b110ec9c283373f4`。真实后端先创建文档并 PATCH 挂载到对话，再删除该文档；Computer Use 打开该对话，真实键入并发送消息。LLM wire 明确含 `<document id="doc_223e10c4a400bc06" missing="true">(this attached document no longer exists — it was deleted; its content is unavailable)</document>`，真实 App 回答无法读取、解释文档已删除并建议重新上传；回合正常完成，没有假装读到不存在的正文。

五通道 `rig-check`/`rig-down` 通过且录屏无外部遮挡；backend/frontend 无应用级 WARN/ERROR/panic/FATAL/Flutter/Dart/RenderFlex/Unhandled 红线，SSE 三流 durable 帧单调且无 gap，llmtap challenge/install/models 与真实 chat completion 均为 `200`；SQLite/REST/UI 对账一致。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-144028/evidence/EDGE-279-attached-document-deleted-real-app-20260829.md`，独立警报复审=`testend/rig/formal-evidence/EDGE-279-ledger-alarm-reaudit-20260829.md`。`judge.py` 按 `F1` 写入 `L2 ✓`，清册=`✓✓~~~`；L3-L5 保持 `na`，不把诚实降级冒充顺滑、视觉 craft 或可发现性结论。锚点=`10/10`，最终 `alarms.py check`=`clean (2006 live judgments; 2300 baseline excluded)`，`gen_coverage.py --check`=`848/848/0`。批次由 `44→45/50`，未满 50 格不跑统一长门禁、不提交；下一原子继续选择尚未具备正式 L2 的 `~` 格。P12 的 400+ Journey 扩写按用户裁定推迟二期。

#### 2026-08-29 · EDGE-280 Agent 知识文档删除后的 mount-health 真实 App L2 完成

#### 2026-08-29 · EDGE-280 Agent 知识文档删除后的 mount-health 真实 App L2 完成

正式 clean session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-143120`。真实 App 打开挂载知识文档的 Agent 详情；通过真实后端删除该知识文档后，切换到另一 Agent 再返回，详情重新从服务端加载并显示 `1 unhealthy`、`Mount health: 1 unhealthy` 和 `knowledge document does not exist`。REST mount-health 返回 `healthy=false`，SSE 收到对应的 `document.deleted` 与 `relation.dependency_broken`，UI、REST、SQLite 与事件事实一致。

五通道 `rig-check`/`rig-down` 通过且录屏无外部遮挡；backend/frontend 无应用级 WARN/ERROR/panic/FATAL/Flutter/Dart/RenderFlex/Unhandled 红线，SSE 三流和 llmtap 证据齐全。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-143120/evidence/EDGE-280-agent-knowledge-deleted-real-app.md`，独立警报复审=`testend/rig/formal-evidence/EDGE-280-ledger-alarm-reaudit-20260829.md`。`judge.py` 按 `F1` 写入 `L2 ✓`，清册=`✓✓~~~`；L3-L5 保持 `na`，不把依赖断裂可见性冒充顺滑、视觉 craft 或可发现性结论。锚点=`10/10`，最终 `alarms.py check`=`clean (2005 live judgments; 2300 baseline excluded)`，`gen_coverage.py --check`=`848/848/0`。本轮也明确记录：已打开的详情不会凭删除事件自动刷新，必须重新进入详情才能显示不健康；不扩大本格结论。批次由 `43→44/50`，未满 50 格不跑统一长门禁、不提交；下一原子继续选择尚未具备正式 L2 的 `~` 格。P12 的 400+ Journey 扩写按用户裁定推迟二期。

#### 2026-08-29 · EDGE-324 窗角半径 swizzle 失效真实 App L2 完成

通过一次临时故障注入构建，将 `NSThemeFrame` 的 `_cornerRadius`、`_getCachedWindowCornerRadius`、`_topCornerSize`、`_bottomCornerSize` 全部改为不存在的 selector，模拟未来 macOS 改名；真实 App 仍启动并显示完整 Library 空选区草稿态。随后使用 Computer Use 从 Library 切换到 Chat，再切回 Library，页面持续可见、可操作，没有崩溃、黑屏、白屏或启动卡死。nil 守卫在四个私有 getter 都不存在时回落系统窗口圆角；收台后已恢复 `MainFlutterWindow.swift`，该文件最终无 diff。

正式 clean session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-140606`，workspace=`ws_1a9705b29c913e3b`，App/window=`28082/6017`，录屏=`30.895000s`，关键帧=`evidence/EDGE-324-missing-selectors-visible.jpeg`。五通道 `rig-check`/`rig-down` 通过且录屏区域无外部遮挡；backend 无应用级 WARN/ERROR/panic/FATAL，SSE 三流已连接，llmtap challenge/install/models 全 `200`；frontend 无 Flutter/Dart/RenderFlex/Unhandled 应用红线，唯一 IMK 文本为已分类的 macOS 宿主诊断。

正式证据=`testend/rig/formal-evidence/EDGE-324-window-corner-swizzle-fallback-real-app-20260829.md`，独立警报复审=`testend/rig/formal-evidence/EDGE-324-ledger-alarm-reaudit-20260829.md`。`judge.py` 按 `F1` 写入 `L2 ✓`，清册=`✓✓~~~`；L3-L5 保持 `na`，不把故障降级可用性冒充窗口圆角视觉精度、顺滑或可发现性结论。锚点校准=`10/10`；写账触发的 `discovery-collapse` 已按原阈值独立复审并 ack，未改变阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2004 live judgments; 2300 baseline excluded)`。`gen_coverage.py --check`=`848/848/0`。批次由 `42→43/50`，未满 50 格不跑统一长门禁、不提交；下一原子继续选择尚未具备正式 L2 的 `~` 格。P12 的 400+ Journey 扩写按用户裁定推迟二期。

#### 2026-08-29 · EDGE-321 草稿文档首次编辑真实 App L2 完成

全新 clean session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-135745` 使用隔离数据目录和真实 Flutter App。进入 Library 无选区草稿态后，先不输入就切换到 Chat 再返回；前后 `GET /documents/tree` 都只有已播种的 2 条文档，没有空稿幽灵行。随后在真实正文区域输入 `EDGE321 body probe`，只产生一次 `POST /api/v1/documents` `201`，得到 `doc_0c0e4971321227f6`，空标题按规则为 `Untitled`。

创建返回后继续输入 ` + continued`，AX 树与录屏显示正文连续、侧栏只有一个 `Untitled` 行，没有清空、重复、跳回草稿或页面重挂；防抖后同一 id 的 `PATCH` 收口，REST 读到正文 `EDGE321 body probe + continued`、`sizeBytes=30`。切出到 Chat 再回 Library，真实 UI 重新显示同一正文和 `30 B`，固定帧保存在 session evidence。

五通道已封口：`rig-check`/`rig-down` 通过且录屏区域无外部遮挡；backend 健康为 `200`、无 `WARN`/`ERROR`/`panic`/`FATAL`，SSE notifications durable `seq=16,17` 单调，llmtap 的 challenge/install/models 全 `200`；frontend 无 Flutter/Dart/RenderFlex/Unhandled 应用红线，唯一 IMK 文本为已分类的 macOS 宿主诊断。正式证据=`testend/rig/formal-evidence/EDGE-321-draft-first-edit-real-app-20260829.md`，独立警报复审=`testend/rig/formal-evidence/EDGE-321-ledger-alarm-reaudit-20260829.md`。

`judge.py` 按 `F1` 写入 `L2 ✓`，清册=`✓✓~~~`；L3-L5 保持 `na`，不把持久化一致性冒充顺滑、视觉 craft 或可发现性结论。锚点校准=`10/10`；写账触发的 `discovery-collapse` 已按原阈值独立复审并 ack，未改变阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2003 live judgments; 2300 baseline excluded)`。`gen_coverage.py --check`=`848/848/0`。批次由 `41→42/50`，未满 50 格不跑统一长门禁、不提交；下一原子继续选择尚未具备正式 L2 的 `~` 格。P12 的 400+ Journey 扩写按用户裁定推迟二期。

#### 2026-08-29 · EDGE-320 skill 双写者竞态真实 App L2 完成

全新 clean session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-134830` 使用隔离数据目录和真实 Flutter App，打开
`edge320-race` skill。中心 body 编辑器与右侧 Properties 配置表单分别作为两个真实写入者操作：正文插入 `BODYCLEAN`，右侧 Arguments
提交 `cleanarg`；等待防抖后 REST 读到 body 与 frontmatter 两项都已保存。离开进入 `commit-helper` 再返回后，真实 UI 同时恢复正文和
`cleanarg`，没有旧快照覆盖、空白、页面重挂或不可恢复状态。录屏=`94.406667s`，关键帧保存在 session evidence。

五通道已封口：`rig-check`/`rig-down` 通过且录屏区域无外部遮挡；backend 的两次 skill PUT 与后续 GET 均为 200、无应用级 WARN/ERROR；
ssetap 三流与 llmtap 均为当前 session 证据；frontend 没有 Flutter/Dart/RenderFlex/Unhandled 应用级红线，唯一 IMK 文本为已分类的
macOS 输入法框架诊断。正式证据=`testend/rig/formal-evidence/EDGE-320-skill-dual-writer-window-real-app-20260829.md`，独立警报复审=
`testend/rig/formal-evidence/EDGE-320-ledger-alarm-reaudit-20260829.md`。

`judge.py` 按 `F1` 写入 `L2 ✓`，清册=`✓✓~~~`；L3-L5 保持 `na`，不把持久化保留冒充顺滑、视觉 craft 或可发现性结论。锚点重新校准为
`10/10`；写账触发的 `discovery-collapse` 已按原阈值独立复审并 ack，未改变阈值、算法、法典、锚点或 gate，最终
`alarms.py check`=`clean (2002 live judgments; 2300 baseline excluded)`。批次由 `40→41/50`，未满 50 格不跑统一长门禁、不提交；
下一原子继续选择尚未具备正式 L2 的 `~` 格。P12 的 400+ Journey 扩写按用户裁定推迟二期。

#### 2026-08-28 · EDGE-316 行内代码 CJK 断盒真实 App L2 完成

真实 App 打开含 `中文注释：计算总数并返回结果` 的行内代码文档；截图与录屏确认多个 CJK script-run 之间灰色背景连续，无白缝、断盒、前后文字遮挡或粘连。离开并重新打开后 AX 仍显示完整行内代码文本，右侧保持 `44 chars`、`130 B`。

正式证据=`testend/rig/formal-evidence/EDGE-316-inline-code-cjk-real-app-20260828.md`；session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-231212`；录屏=`98.760000s`；App/window=`8497/5691`。五通道 `rig-check`/`rig-down` 通过，SSE notifications durable seq `16` 单调，LLM challenge/install/models 全 `200`；frontend/backend 无应用红线，关键帧已保存。

`judge.py`=`L2 ✓ (F1)`，清册=`✓✓~~~`，L3-L5=`na`；锚点校准 `10/10`，警报复核=`testend/rig/formal-evidence/EDGE-316-ledger-alarm-reaudit-20260828.md`，最终 `alarms.py check`=`clean`。`gen_coverage.py --check`=`848/848/0`。批次由 `36/50` 推进到 `37/50`，未满 50 格不跑统一长门禁、不提交；下一原子=`EDGE-317`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-28 · EDGE-315 空 task 尾空格腐化真实 App L2 完成

全新正式台架打开含前后任务和中间空 task 的真实文档。两轮点击空 task、输入 `temp`、逐字退格清空、等待保存、离开并重开后，画面始终保留三个 checkbox 行，没有 bullet 退化、字面 `[ ]` 或内容吞并；后端两轮 GET 均返回精确原文 `- [ ] first task\n- [ ] \n- [ ] last task`，`sizeBytes=39`。

正式证据=`testend/rig/formal-evidence/EDGE-315-task-whitespace-heal-real-app-20260828.md`；session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-230718`；录屏=`113.558333s`；App/window=`7538/5674`。五通道 `rig-check`/`rig-down` 通过，SSE notifications durable seq `16,17,18` 单调，LLM challenge/install/models 全 `200`；frontend/backend 无应用红线，唯一 frontend 文本为已分类 macOS IMK 宿主提示。

`judge.py`=`L2 ✓ (F1)`，清册=`✓✓~~~`，L3-L5=`na`；锚点校准 `10/10`，警报复核=`testend/rig/formal-evidence/EDGE-315-ledger-alarm-reaudit-20260828.md`，最终 `alarms.py check`=`clean`。`gen_coverage.py --check`=`848/848/0`。批次由 `35/50` 推进到 `36/50`，未满 50 格不跑统一长门禁、不提交；下一原子=`EDGE-316`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-28 · EDGE-314 编辑器唯一光标真实 App L2 完成

全新正式台架打开含正文、Dart 代码块和表格的真实文档。正文先建立 caret，随后分别点击代码字段和表格单元格并输入 `Y`/`X`；AX 与录屏均证明内嵌字段获得键盘后，正文侧没有第二根文档 caret。两条字段路径随后经 fixture 恢复并离开/重开文档，持久化内容回到原始 Markdown。

正式证据=`testend/rig/formal-evidence/EDGE-314-editor-single-caret-real-app-20260828.md`；session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-225931`；录屏=`222.475000s`；App/window=`6366/5642`。五通道 `rig-check`/`rig-down` 通过，backend 无应用红线，SSE notifications durable seq `16,17,18,19` 单调，LLM challenge/install/models 全 `200`；唯一 frontend 文本为已分类 macOS IMK 宿主提示。

`judge.py`=`L2 ✓ (F1)`，清册=`✓✓~~~`，L3-L5=`na`；锚点校准 `10/10`，警报复核=`testend/rig/formal-evidence/EDGE-314-ledger-alarm-reaudit-20260828.md`，最终 `alarms.py check`=`clean`。focused editor/library/error tests `126` 项通过，`gen_coverage.py --check`=`848/848/0`。批次由 `34/50` 推进到 `35/50`，未满 50 格不跑统一长门禁、不提交；下一原子=`EDGE-315`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-28 · EDGE-313 编辑器 undo 全量重建真实 App L2 完成

用户在真实 App 中先粘贴 `EDITED`，再物理按下 `Command+Z`；画面与 AX 最终只保留原始正文，右侧显示 `25 chars`、`28 B`。后端真相为 PATCH/GET `256` → `262` → `256` bytes，三路 SSE witness 的 notifications durable seq `16,17,18` 单调，frontend/backend/LLM wire 均无应用红线。

正式记录=`testend/rig/formal-evidence/EDGE-313-undo-real-app-20260828.md`；session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-225041`；录屏=`75.101667s`；`judge.py`=`L2 ✓ (F1)`，清册=`✓✓~~~`，L3-L5=`na`。
锚点校准 `10/10`，`alarms.py check` clean；focused editor/library/error tests `126` 项通过。旧 session 的 16 条 Null check 红线和输入桥失败均保留为历史不计账证据，不污染本次正式绿证。

#### 2026-08-28 · EDGE-341 未验证供应商诚实徽标真实 App 五通道 L2 完成

标准 conductor 在全新工作区启动真实 Flutter App、sidecar、三路独立 SSE witness、LLM tap、frontend journal 与连续录屏。
Computer Use 进入「模型与密钥 → 添加密钥」，真实目录显示 `0-100 of 213 items`；供应商卡同时展示名称、模型数量和
`未验证` 徽标。打开 `302.AI` 表单核对 Name、Key、Base URL、保存/测试控件后取消，没有输入、上传或保存凭证，受管 key
与 workspace 状态不变。

正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-030900`；录屏=`143.845000s / 2784x1808 /
60fps`；`rig-check`/`rig-down` 均通过，backend、SSE、frontend、LLM 五通道证据齐全，正式证据=
`testend/rig/formal-evidence/EDGE-341-unverified-provider-real-app-20260828.md`。独立账本复核=
`testend/rig/formal-evidence/EDGE-341-ledger-alarm-reaudit-20260828.md`。

`judge.py` 已写入 `EDGE-341 L2=✓ (F1)`，清册由 `✓~~~~` 提升为 `✓✓~~~`；L3（顺滑）、L4（视觉 craft）、L5（从零可发现性）
均保持 `na`，不把一次目录观察冒充完整产品验收。警报复核已 ack，`alarms.py check`=`clean`，未改阈值、算法、法典、锚点或
历史 journal。新批次由 `19/50` 推进至 `20/50`，未满 50 格不跑统一长门禁、不提交；下一项继续由清册可提升的 `~` 格决定。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-28 · EDGE-327 工作区热切换真实 App 五通道 L2 完成

当前版本由标准 conductor 真实启动 App、sidecar、三路 SSE、llmtap 与录屏。真实进入源工作区的 `演示对话` 深链，再从工作区菜单点击目标工作区；旧对话退出视图，目标工作区进入空 Chat landing，目标 workspace 的列表读取与三路观察面均正常，没有跨 workspace 资源残留或运行时红线。

正式证据=`testend/rig/formal-evidence/EDGE-332-mcp-frame-coalescing-real-app-20260828.md`，session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-025843`；警报复审=`testend/rig/formal-evidence/EDGE-332-ledger-alarm-reaudit-20260828.md`。`judge.py` 写入 `L2=✓ (G2)`，`EDGE-332` 清册由 `✓~~~~` 提升为 `✓✓~~~`；L3-L5 继续为 `na`，没有把一次 MCP 帧合并与 410 重同步冒充为完整顺滑、视觉 craft 或从零可发现性通过。批次由 `18/50` 推进到 `19/50`，未满 50 格不跑统一长门禁、不提交。两项统计警报已按独立复审逐项 ack，最终 `alarms.py check`=`clean (1977 live judgments; 2300 baseline judgments excluded from drift curves)`；P12 的 400+ Journey 继续推迟二期。

#### 2026-08-28 · EDGE-323 原生全屏真实 App 五通道 L2 完成

当前版本由标准 conductor 真实启动 App、sidecar、三路 SSE、llmtap 与录屏。直接点击原生全屏按钮，确认窗口从普通态进入全屏态并铺满屏幕，再用原生快捷键退出恢复窗口态；连续录像覆盖 `1280×792 → 2696×1720 → 1280×792`，没有白带、外部遮挡、布局溢出或状态卡死。

正式证据=`testend/rig/formal-evidence/EDGE-323-fullscreen-white-band-real-app-20260828.md`，session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-023137`；警报复审=`testend/rig/formal-evidence/EDGE-323-ledger-alarm-reaudit-20260828.md`。`judge.py` 写入 `L2=✓ (G2)`，`EDGE-323` 清册由 `✓~~~~` 提升为 `✓✓~~~`；L3-L5 继续为 `na`，没有把一次全屏切换成功冒充为完整顺滑、视觉 craft 或从零可发现性通过。批次由 `15/50` 推进到 `16/50`，未满 50 格不跑统一长门禁、不提交。三项统计警报已按独立复审逐项 ack，最终 `alarms.py check`=`clean (1974 live judgments; 2300 baseline judgments excluded from drift curves)`；P12 的 400+ Journey 继续推迟二期。

#### 2026-08-28 · EDGE-322 应内缩放到顶真实 App 五通道 L2 完成

当前版本由标准 conductor 真实启动 App、sidecar、三路 SSE、llmtap 与录屏。在「设置 → 通用」中点击 `1.1×`，确认整套 UI 同步重排且没有溢出；再点击灰置的 `1.25×`，当前值保持 `1.1×`，最后点击 `1.0×` 恢复。五通道收台、前后端日志与进程审计均通过，无 App 运行时红线。

正式证据=`testend/rig/formal-evidence/EDGE-322-in-app-zoom-cap-real-app-20260828.md`，session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-022508`；警报复审=`testend/rig/formal-evidence/EDGE-322-ledger-alarm-reaudit-20260828.md`。`judge.py` 写入 `L2=✓ (G2)`，`EDGE-322` 清册由 `✓~~~~` 提升为 `✓✓~~~`；L3-L5 继续为 `na`，没有把一次缩放边界成功冒充为完整顺滑、视觉 craft 或从零可发现性通过。批次由 `14/50` 推进到 `15/50`，未满 50 格不跑统一长门禁、不提交。三项统计警报已按独立复审逐项 ack，最终 `alarms.py check`=`clean (1973 live judgments; 2300 baseline judgments excluded from drift curves)`；P12 的 400+ Journey 继续推迟二期。

#### 2026-08-28 · EDGE-328 快捷键冷启动真实 App 五通道 L2 完成

当前版本由标准 conductor 真实启动 App、sidecar、三路 SSE、llmtap 与录屏。在不点击任何控件的冷启动状态下直接按 `⌘B`，左岛实际折叠；再次按 `⌘B` 后恢复。截图确认真实窗口几何变化，AX 树保留隐藏语义节点不作为视觉状态判据。五通道收台、前后端日志与进程审计均通过，无 App 运行时红线。

正式证据=`testend/rig/formal-evidence/EDGE-328-shortcut-cold-start-real-app-20260828.md`，session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-021456`；警报复审=`testend/rig/formal-evidence/EDGE-328-ledger-alarm-reaudit-20260828.md`。`judge.py` 写入 `L2=✓ (G2)`，`EDGE-328` 清册由 `✓~~~~` 提升为 `✓✓~~~`；L3-L5 继续为 `na`，没有把一次快捷键成功冒充为完整顺滑、视觉 craft 或从零可发现性通过。批次由 `13/50` 推进到 `14/50`，未满 50 格不跑统一长门禁、不提交。下一项继续由清册中的可提升 `~` 格选择；P12 的 400+ Journey 继续推迟二期。

#### 2026-08-28 · EDGE-333 保留面板真实 App 复验（不新增账本格）

当前版本由标准 conductor 真实启动 App、sidecar、三路 SSE、llmtap 与录屏，在 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-015950` 中走完“存储与日志 → 运行历史保留”的完整操作：读取 `90 天`，改为 `30 天`，再恢复 `90 天`。后端两次 PATCH 与两次 GET 全为 200；录屏 `164.161667s / 2784x1808 / 60fps`；五通道收台和进程审计通过，未发现 App 红线、布局溢出或状态卡死。

正式复验=`testend/rig/formal-evidence/EDGE-333-retention-real-app-l345-20260828.md`。本次不重复写 `judge.py`：L3 没有动作帧到首反馈帧的独立 `measure latency`，L4 没有 ROI 测量，L5 不是从零盲走，因此 `EDGE-333` 的 L3-L5 仍保持 `na`，批次仍为 `13/50`。操作调用墙钟约 `1039ms/456ms` 只作边界记录，不能冒充 A1 通过。

#### 2026-08-28 当前前线重述：EDGE-353 workflow 停用排空双类已完成 L2

本轮没有改测试 fixture 以外的产品行为；在当前代码上重新启动标准 conductor，使用隔离数据目录真实启动 Flutter App、sidecar、三路独立
SSE、llmtap 和窗口录屏。workflow=`wf_b0bf4d07dabdd910`，workspace=`ws_bca3098cf8eda0c3`，trigger=
`trg_e7705c64d3809f0c`，formal session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-014157`。

真实产品路径为：在 App 中确认 workflow 初始为 inactive；通过真实 webhook 送入第一个事件，App 显示 active 和审批卡，第一条 run
进入 parked；再送入第二个事件，第二条 firing 在 serial 策略下保持 pending；从 App 行菜单点击“下线”，界面进入 draining 且显示
在途已停；连续在 App 中批准两张审批卡，第二条 pending 被接纳并完成；最终 App 与 REST 都收口为 inactive。停用后再次 POST
webhook 得到 404，且没有新增 firing 或 flowrun。整个过程没有红色错误卡、重试残留、重复执行或丢失 pending firing。

REST/SQLite 真相为：本轮新增 firing=`trf_fa184a4a8bd50d8f`、`trf_60fc52a34c1cff98`，分别关联
flowrun=`fr_ecbd9c939f36c4a3`、`fr_df4c377bda0f5e5d`；中间快照确实同时有一个 running run 与一个 pending firing，最终两条
新 run 均 completed、两条新 firing 均 started，workflow=`active=false,state=inactive`。旧 fixture 历史行仍保留，未被错误清理。

五通道结果：录屏=`350.406667s`；backend journal 无 `WARN|ERROR|panic|FATAL`；ssetap 观察到 notifications durable seq=`1..5`、
entities durable seq=`1..4`，均单调且无 gap，另有预期的 ephemeral seq=0；messages 流本场景无帧。frontend journal 的 126 条
macOS AXTree bridge churn 已在 Computer Use 观察后单独复核，3 秒 idle 未继续增长，且无 `Unhandled exception`、Dart/Flutter/layout
运行时红线；llmtap ready、场景无模型调用。`rig-check` 与 `rig-down` 均通过，收台后无 Anselm 进程残留。

正式证据=`testend/rig/formal-evidence/EDGE-353-workflow-deactivate-drains-both-20260828.md`，session 内证据同名；独立账本复核=
`testend/rig/formal-evidence/EDGE-353-ledger-alarm-reaudit-20260828.md`，前端 AX 复核在 session evidence 中。`judge.py` 已写入
`L2=✓ (F1)`；L3（顺滑）=`na`，L4（视觉 craft）=`na`，L5（从零可发现性）=`na`，因为本轮没有对应的独立测量、ROI craft 审查或
从零走查，不能把功能成功冒充为完整产品通过。L2 之前错误使用旧 session 的记录仍留在历史链中，本条新证据已追加而非覆盖。

本轮账本写入后统计警报按机制短暂打开，已分别 ack：连续分级写入造成 `gap-too-fast`，本轮无产品 fail 且 `na` 不等于 fail 造成
`discovery-collapse`；没有修改任何阈值、算法、法条或锚点。最终 `alarms.py check`=`clean (1971 live judgments; 2300 baseline excluded)`，
`anchors=10/10`，`gen_coverage=848/848/0`。本轮将批次从 `12/50` 推进到 `13/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线不硬编码编号，由 `COVERAGE.md` 的 formal sequence gate 选择下一项可提升的 `~` 格（`EDGE-354` 仅为历史媒体复验记录、不是清册行；`EDGE-003` 也已有完整账本判定）。P12 的 400+ Journey 继续按用户裁定推迟二期，COVERAGE 清册仍是覆盖真相源。

#### 2026-08-28 当前前线重述：EDGE-352 分叉携带附件与 subagent 树已完成 L2

本轮先在隔离数据目录预置了一条合法 durable 源线程：一个 user 回合同时带附件 ID 与冻结 @ 快照，包含一个
`Subagent` tool_call、对应父 `tool_result` 和 subagent 子树。附件复用内容寻址行，不复制 blob。早期启动只发现并修正
fixture 的非法 `stopReason`、缺失父 `tool_result` 和缺失 `parentBlockId`；均为测试数据形状问题，未改产品代码，最终
session 使用校正后的完整形状。

正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-013112`，workspace=`ws_a0c08e8dc49d9a60`，
由标准 conductor 启动真实 Flutter App、sidecar、三路独立 SSE、llmtap 和窗口录屏。真实 App 打开源对话后，附件卡、
`edge352_reference` @ 药丸和“已派子代理”均正确可见；展开 subagent 卡能看到任务/回复/回答。点击“从这里分叉”后新线程
立即打开，源线程仍在 rail；fork 线程再次展开同一 subagent 树，血缘菜单显示“分叉自 EDGE-352 fork source”，点击后可回源。

SQLite/REST 对证：`fork=cv_8628f3ef127bf9c3`、`source=cv_edge352_src`；两边均为 5 messages/8 blocks；fork 保留 1 条
subagent 行、同一附件与 mention snapshot，`parentBlockId` 和 block parent 均 remap 到 fork 自己的 block；fork seq=`1..8`，
source 原始 IDs/links/seq 不变，附件表该 ID 只有 1 行。复制历史由导航后的 REST 重读，不伪装成 messages durable SSE；SSE
只记录新 fork 的 `conversation.created`。

五通道 `rig-check`/`rig-down` 通过，录屏=`142.600000s`；backend 无 `WARN|ERROR|panic|FATAL`，frontend 无 Flutter/Dart/布局
运行时红线，仅有已审阅的 macOS IMK 宿主 warning；ssetap 三流连接，llmtap ready 且本场景没有模型调用。正式证据=
`testend/rig/formal-evidence/EDGE-352-fork-attachments-subagent-tree-20260828.md`，账本复核=
`testend/rig/formal-evidence/EDGE-352-ledger-alarm-reaudit-20260828.md`。`judge.py` 写入 L2=`✓`，证据列明 F1-F4；
`anchors=10/10`，`gen_coverage=848/848/0`，最终 `alarms.py check`=`clean (1967 live judgments; 2300 baseline excluded)`。

`EDGE-352` 清册为 `✓✓~~~`；L3-L5 诚实保持 `na`，本轮没有独立连续操作时延、视觉 craft ROI 或从零可发现性判定。
新批次由 `11/50` 推进至 `12/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EDGE-353`。P12 的 400+ Journey
继续按用户裁定推迟二期。

#### 上一前线覆盖声明（2026-08-28 · EDGE-351 429 不动钱 L2 完成 · 新批次 11/50）

#### 2026-08-28 当前前线重述：EDGE-351 429 不动钱已完成 L2

首轮真实 App 复验发现产品红场：限流终态直接把 `Something went wrong · LLM_RATE_LIMITED · llm: rate limited (429)`
展示给用户，内部码和上游错误不应进入主时间线。stop-and-fix 将 `LLM_RATE_LIMITED` 纳入既有诊断字段隔离规则，增加中英文
本地化文案“模型服务暂时繁忙，请稍后重试”，保留可见重试入口；补 transcript widget 回归与 Chat 文档同步。

正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-011403`，workspace=`ws_a0c08e8dc49d9a60`，
由标准 conductor 启动真实 Flutter App、sidecar、三路 SSE、llmtap 和窗口录屏。受控上游对 `/v1/chat/completions`
稳定返回结构化 `RATE_LIMITED` 429；App 发送 `rate limit quota test` 后，逐帧最终只显示“模型服务暂时繁忙，请稍后重试”，
重试按钮存在，Composer 回到发送态，无卡死、无伪成功。

配额前后 REST 快照完全一致：`limit=10000, used=1234, remaining=8766, resetAt=2099-01-01T00:00:00Z, available=true`。
LLM tap 记录首请求加三次退避重试共 4 个 429；SSE messages durable `1..4` 为 user completed、assistant error
(`LLM_RATE_LIMITED`, `inputTokens=0`, `outputTokens=0`)，notifications 后续自动标题，无成功 completion 或生成调用。
五通道 `rig-check`/`rig-down` 通过，录屏=`77.245000s`，backend/frontend 无应用运行时红线；一条 macOS IMK 宿主警告已审阅，
不属于 Flutter/Dart 错误。

正式证据=`testend/rig/formal-evidence/EDGE-351-rate-limit-no-spend-20260828.md`，session 内证据同名；警报复审=
`testend/rig/formal-evidence/EDGE-351-ledger-alarm-reaudit-20260828.md`。`judge.py` 写入 `EDGE-351 L2=✓ (E1/F1/F2/F3/F4)`；
`anchors.py check`=`10/10`，`gen_coverage.py --check`=`848/848/0`，最终 `alarms.py check`=`clean (1963 live judgments; 2300 baseline excluded)`。

`EDGE-351` 清册保持 `✓✓~~~`；L3-L5 诚实保持 `na`，不把受控限流错误收口冒充完整顺滑、独立视觉 craft 或可发现性结论。
新批次由 `10/50` 推进至 `11/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EDGE-352`。P12 的 400+ Journey
继续按用户裁定推迟二期。

#### 2026-08-28 当前前线重述：EDGE-350 语音帧越界已完成 L2

代码审查先发现真实红场：`SetReadLimit(256 KiB)` 会在业务层看见超限帧之前吞掉
`SPEECH_AUDIO_FRAME_INVALID`；前端协议错误也只显示“语音输入启动失败”，缺少原因与下一步。
修复为 `NextReader` + `LimitReader(256 KiB+1)`，先观察越界首字节，再返回闭集
`SPEECH_AUDIO_FRAME_INVALID` 并关闭；未知控制帧返回 `SPEECH_CONTROL_INVALID`，两者均不转发上游。
前端增加两个错误码映射，保留已转写草稿并给出可重试的人话文案；补 Go handler 与 Flutter state
回归测试，backend/frontend 文档同步。

正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-005848`，workspace=`ws_a0c08e8dc49d9a60`，
由标准 conductor 启动真实 Flutter App、sidecar、三路 SSE、llmtap 和窗口录屏；独立 witness 注入
`256 KiB+1` binary audio 与 `{"type":"pause"}` control。前者收到 `SPEECH_AUDIO_FRAME_INVALID`，
后者收到 `SPEECH_CONTROL_INVALID`，两条坏帧均未转发上游；录屏=`52.511667s`。

五通道结果：backend/frontend 无应用红线；SSE `notifications/messages/entities` 全连接并在收台时 EOF；
LLM tap challenge=`200`、两次 speech upgrade=`101`；`rig-check` 五通道通过，`rig-down` 正常封口且无残留。
正式证据=`testend/rig/formal-evidence/EDGE-350-speech-frame-bounds-20260828.md`，session 内证据同名；
警报复审=`testend/rig/formal-evidence/EDGE-350-ledger-alarm-reaudit-20260828.md`。`anchors.py check`=`10/10`，
`gen_coverage.py --check`=`848/848/0`，最终 `alarms.py check`=`clean (1962 live judgments; 2300 baseline excluded)`。

`EDGE-350` 由 `✓~~~~` 提升为 `✓✓~~~`；L3-L5 诚实保持 `na`，不把受控协议注入冒充完整顺滑、
视觉 craft 或可发现性结论。新批次由 `9/50` 推进至 `10/50`，未满 50 格不跑统一长门禁、不提交；下一原子
前线为 `EDGE-351`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 历史记录：2026-08-27 EDGE-344 直连生成整体退场已完成 L2

用户已完成 macOS `SecurityAgent` 的 `Always Allow` 授权。新的 conductor session 在产品操作前通过五通道
`rig-check`。上一格 `EDGE-343` 已验证同一 function 对 object/string 两种参数线缆均真实执行并完成；本格
在全新隔离 workspace 走真实 onboarding，首次受管 provision 指向关闭回环 gateway，随后只添加 BYOK
`qwen` key，构造“无受管 install、仅 BYOK”的真实产品状态。

有效 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-220925`，录屏
`156.893333s / 2784x1808 / 60fps`；workspace key 列表没有 `anselm`，model capabilities 只有
`qwen-plus · EDGE-344 BYOK`。真实 App 模型菜单只有 `自动` 与该 BYOK 模型，没有 `Anselm Free`；
两轮探测生成能力均以普通文本完成，不显示生成入口、生成卡片或隐藏必败按钮。

provider wire=`/private/tmp/edge344-provider-wire.jsonl`：第二轮真实请求的 13 个工具只有基础工具，明确
不含 `generate_image`、`generate_speech`、`generate_video`；第一轮为零工具请求。SSE messages 两轮
durable 分别为 `1..6`、`7..12`，无 tool call/result 或生成附件；backend 仅有构造关闭 gateway 必然产生的
两条 provision WARN，无应用 ERROR/panic/fatal，frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception
红线。正式证据=`testend/rig/formal-evidence/EDGE-344-direct-generation-real-app-20260827.md`，警报复审
=`testend/rig/formal-evidence/EDGE-344-ledger-alarm-reaudit-20260827.md`；`rig-check`、`rig-down` 均通过。

`EDGE-344` 由 `✓~~~~` 提升为 `✓✓~~~`；L3-L5 继续写明 `na`，不把一次无生成路径冒充独立的全局顺滑、
craft 或可发现性结论。`anchors=10/10`，`gen_coverage.py --check`=`848/848/0`，`alarms.py check` 在
独立复审并串行 ack 后为 `clean`。账本新批次由 `3/50` 推进至 `4/50`，未满 50 格不跑统一长门禁、不提交；
下一原子前线为 `EDGE-345`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 历史记录：2026-08-27 EDGE-242 keychain 授权挂起 stop-and-fix（已解除）

正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-014259` 已启动完整五通道台架。真实 App 曾停在“正在连接本地引擎…”，检查发现 macOS `SecurityAgent` 钥匙串授权窗口覆盖 Anselm 录制区域；backend、ssetap、llmtap、App 归属均正常，但 `rig-check` 按外部窗口重叠规则失败，不能开始产品操作或写绿账。App 在开发 attach 重建后已进入真实主界面，正式 session 的遮挡仍未消失，故不把它当作录屏绿证据。

stop-and-fix 已给 `MasterKey.resolve()` 的 keychain read、write、read-back 各加 3 秒有界等待；超时/异常继续返回 `null` 走 legacy fingerprint，旧装机不铸新钥，写入超时不读回。新增读挂起、写挂起守卫测试均通过，前端真实 App 重建后可进入主界面。正式证据=`testend/rig/formal-evidence/EDGE-242-keychain-startup-timeout-20260827.md`。

历史结论：启动修复通过；当时的 macOS `SecurityAgent` 授权曾阻塞 `rig-check`，因此该 session 不计
COVERAGE。用户随后已完成 `Always Allow`，后续新 session 已通过五通道 `rig-check` 并继续按顺序推进；
P12 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-27 当前前线重述：EDGE-354 媒体元数据与 Composer 收尾 stop-and-fix 完成

真实生图红场发现两个产品问题：工具 durable result 正确返回真实 `attachmentId`，但中文元数据表把被用户面脱敏的 ID 显示成“这个输入”；同时消息已经收到 durable close，Composer 仍停在“停止生成”，用户无法继续发送。前者破坏元数据可信度，后者把已完成的回合伪装成进行中，均冻结前线处理。

修复包括：服务端二列表格脱敏识别 `attachmentId`/`imageId`/`mediaId`，对不可展示的机器字段物理移除整行，并补完整文本与跨 provider 分片测试；前端归并已 REST 水化的 user echo 与后到的 optimistic pending bubble，即使 durable 节点已在 settled 集合也必须消费 pending。同步更新 Chat 参考文档。

修复后二进制在真实 Flutter App、真实 managed gateway、Computer Use 和全程录屏下重新完成同一生图请求：图片卡显示真实预览、文件名、1344×768 与约 1.2 MB，工具卡可展开并打开大图；用户可见元数据表保留 filename、mime、width × height、sizeBytes、aspect、source、provider，`attachmentId` 整行不再出现“这个输入”。Composer 在 `message close(status=completed, stopReason=end_turn)` 后恢复可发送状态。

正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-012031`，证据=`testend/rig/formal-evidence/EDGE-354-media-metadata-redaction-20260827.md`。LLM tap 记录 chat、image generation 与三步 media upload 全部成功，tool-result/SSE 仍保留真实 attachment ID；messages durable `seq=1..14` 单调无缺口，notifications 自动标题随后到达。`rig-check` 在 session 存活期间五通道通过，录屏=`115.456667s / 2784x1808 / 60fps`；backend/frontend 无业务错误，`rig-down` 无残留。

这是 `TOOL-119` 与 `SURF-070` 的代码变更后 revalidation，不新增 50 格；`gen_coverage.py --check` 保持 `848/848/0`，formal journal 保持 `4252`，当前批次仍=`1/50`，未满 50 不跑统一长门禁、不提交。P12 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-27 当前前线重述：EDGE-353 workflow 停用排空双类 stop-and-fix 完成

本轮先用全新数据目录和真实 App 复现 `:deactivate` 同时面对 running run 与 accepted pending firing 的路径。首轮发现数据库已从 `draining` 进入 `inactive`，但 notifications 没有最终 inactive durable 帧，App 因而停留在 `draining`；该红场被保留，没有写绿。修复为 store 条件更新返回是否实际改行，app 只有赢得 `draining → inactive` 的调用才发布一次 `workflow.lifecycle_changed`，重复 reconcile 不重复发帧；补 store/app 回归测试并通过 scheduler 编译回归。

修复后二进制重新走真实 App：serial workflow 连续接收两次 webhook，第一条 run 停在审批、第二条 accepted firing pending；停用中间态 REST/App 均为 `active=false,lifecycleState=draining`；在 App 先后批准两条审批后，workflow 详情最终逐帧显示 `inactive`。REST 确认两条 firing 均 started、两条 flowrun 均 completed；notifications `seq=23` 是唯一最终 inactive durable 帧，三路 SSE durable seq 单调无缺口；停用后第三次 webhook 返回 404，无新增 run；backend/frontend/LLM journal 无未解释错误。录屏=`181.991667s / 2784x1808 / 60fps`，正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-002414/evidence/EDGE-353-workflow-deactivate-drains-both-20260827.md`，仓内副本=`testend/rig/formal-evidence/EDGE-353-workflow-deactivate-drains-both-20260827.md`。

`EDGE-353` 清册由 `✓~~~~` 提升为 `✓✓~~~`；L3-L5 按本边界覆盖政策继续明确 `na`，不冒充独立视觉 craft、动效或可发现性证据。`anchors.py check`=`10/10`，警报独立复审后 `alarms.py check`=`clean`，`gen_coverage.py --check`=`848 rows / 848 carried judgments / 0 tombstones`，formal journal=`4252`（2300 baseline + 1952 live）。这是当前批次第一项新裁决，批次=`1/50`，未满 50 不跑统一长门禁、不提交；P12 400+ Journey 继续按用户裁定推迟二期。当前清册没有 `·/✗` 未决格，后续继续按工作记录选择可提升的 `~` 格做真实产品复验；不将“无未决”误写成全产品验收完成。

#### 2026-08-27 当前前线重述：EDGE-020 `approve_always` stop-and-fix 复验完成

本轮完成已收口旧格 `EDGE-020 approve_always 会话白名单` 的真实 App 五通道复验，不计入新 50 格批次。用 App 原生「新对话」入口后，首个 `run_function` 危险调用真实出现确认卡；Computer Use 点击「总是允许」后函数成功执行。随后同一对话再次调用同一工具，SSE 出现新的 tool call 和成功 tool result，中间没有第二个 interaction signal，durable REST 的第二个结果也没有 `humanApproval`，触点计数为 2。目标行由 `✓~~~~` 提升为 `✓✓~~~`；L3-L5 仍诚实保留 `na`，因为本条是会话授权协议，不冒充未独立测量的流式顺滑、视觉几何或入口可发现性。

正式主证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-000103/evidence/EDGE-020-approve-always-real-app-20260827.md`，仓内副本=`testend/rig/formal-evidence/EDGE-020-approve-always-real-app-20260826.md`；独立警报复审=`testend/rig/formal-evidence/EDGE-020-ledger-alarm-reaudit-20260826.md`。本 session 录屏时长 `93.046667s`，收台前 `rig-check` 五通道通过，`rig-down` 无残留；干净路径的 messages/entities durable seq 单调，managed LLM tap 为真实 `https://api.anselm.website` 且请求返回 `200`。旧现场中一次下划线被吞导致的 `function not found`、一次静态危险 `delete_workflow` 再次拦截，以及 REST 外部建会话后的选中态错位均明确排除，不作为绿证据。

`gen_coverage.py --check`=`848 rows / 848 carried judgments / 0 tombstones`，formal journal=`4251`
（2300 baseline + 1951 live），`EDGE-020=✓✓~~~`，`anchors.py check`=`10/10`，最终
`alarms.py check`=`clean`。本次是 settled 旧格 revalidation，批次八十二保持已提交状态，当前新批次=`0/50`，不提前跑统一长门禁、不提交。上一批统一长门禁证据=`testend/rig/formal-evidence/batch-82-unified-gate-20260826.md`，已提交=`af912dcd`。后续继续按 COVERAGE 的真实五通道提升和 stop-and-fix 推进；P12 400+ Journey 继续按用户裁定推迟二期。

#### 历史收口：EDGE-333..342 批次八十一已完成，统一长门禁通过

批次八十一已按序完成 `EDGE-333..342` 共 10 个边界、50 个账本格。L1 由 retention wire、真实 Kill9/recovery、
testend 进程收容、provider market、model/key 与 chat-only focused 证据支持，目标行均为 `✓~~~~`；没有把本轮
测试或源码检查冒充新的真实 App 五通道，故 L2-L5 全部明确为 `na`。覆盖内容依次为：保留面板无客户端默认、
Kill9 崩溃半场、进程组泄漏自检、死亡轮次收容、缓存剥 pid、关闭网关隔离、BYOK 模板占位、Vertex service account
校验、未验证供应商徽标、chat-only 模型工具面。

正式证据分别为 `testend/rig/formal-evidence/EDGE-333-retention-wire-default-20260826.md` 至
`EDGE-342-chat-only-tool-surface-20260826.md`；独立警报复审=
`testend/rig/formal-evidence/batch-81-ledger-alarm-reaudit-20260826.md`。formal journal=`4186`
（2300 baseline + 1886 live），`gen_coverage.py --check`=`848 rows / 837 carried judgments / 0 tombstones`，
目标行均=`✓~~~~`，`anchors=10/10`，警报已按复审销账，最终 `alarms.py check`=`clean`。批次八十一已满=`50/50`；
统一长门禁证据=`testend/rig/formal-evidence/batch-81-unified-gate-20260826.md`，根门禁、完整 backend testend、rig
自测、backend/docs verify、格式与进程审计全绿，已提交=`3071083d`。下一原子前线=`EDGE-343`。P12 400+ Journey
继续按用户裁定推迟二期。

#### 历史收口：EDGE-301..310 批次七十八已完成，统一长门禁通过

批次七十八按序完成 `EDGE-301..310` 共 10 个边界、50 个账本格。十格的 L1 均由通知顶带、OS 路由、
sidestage、stage director 和 transcript jump 的 Flutter 聚焦测试支持，目标行均为 `✓~~~~`；没有把本轮
单测、源代码检查或 demo playback 冒充新的真实 App 五通道，故 L2-L5 全部明确为 `na`。覆盖内容依次为：
清场水位、unsigned dev bundle 的 OS 通知边界、activity 门控、三档自动跟随、手动关闭记忆、Live 幽灵清理、
202 回执不谢幕、失败行清除、侧幕分档时钟和 `?around=` 深跳整窗替换。

正式证据分别为 `testend/rig/formal-evidence/EDGE-301-notice-clear-watermark-20260826.md` 至
`EDGE-310-transcript-deep-jump-20260826.md`；独立警报复审=
`testend/rig/formal-evidence/batch-78-ledger-alarm-reaudit-20260826.md`。formal journal=`4036`
（2300 baseline + 1736 live），`gen_coverage.py --check`=`848 rows / 807 carried judgments / 0 tombstones`，
批次目标十行均=`✓~~~~`，`anchors=10/10`，`alarms.py check`=`clean`。批次七十八已满=`50/50`；统一长门禁证据=
`testend/rig/formal-evidence/batch-78-unified-gate-20260826.md`，根门禁、完整 backend testend、rig 自测、backend/docs
verify、格式与进程审计全绿，已提交=`a81491a8`。下一原子前线=`EDGE-311`。P12 400+ Journey 继续按用户裁定推迟二期。

#### 历史收口：EDGE-291..300 批次七十七已完成，统一长门禁通过

批次七十七按序完成 `EDGE-291..300` 共 10 个边界、50 个账本格。十格的 L1 均由 memory/todo/relation/
touchpoint 后端聚焦测试、touchpoint testend 黑盒链路和通知中心 Flutter 测试支持，目标行均为
`✓~~~~`；没有把本轮单测、源代码检查或黑盒场景冒充新的真实 App 五通道，故 L2-L5 全部明确为
`na`。覆盖内容依次为：memory 用户策展保留、todo 完成态读取、依赖断裂聚合通知、触点拒绝不记幽灵删除、
失败执行仍记触点、删除实体不借名、触点目录穷尽性、未读徽标权威计数、顶带大积压和 priority/normal 公平调度。

正式证据分别为 `testend/rig/formal-evidence/EDGE-291-memory-curation-20260826.md` 至
`EDGE-300-notice-fairness-20260826.md`；独立警报复审=
`testend/rig/formal-evidence/batch-77-ledger-alarm-reaudit-20260826.md`。formal journal=`3986`
（2300 baseline + 1686 live），`gen_coverage.py --check`=`848 rows / 797 carried judgments / 0 tombstones`，
批次目标十行均=`✓~~~~`，`anchors=10/10`，`alarms.py check`=`clean`。批次七十七已满=`50/50`；统一长门禁证据=
`testend/rig/formal-evidence/batch-77-unified-gate-20260826.md`，根门禁、完整 backend testend、rig 自测、backend/docs
verify、格式与进程审计全绿，已提交=`cff3af3c`。下一原子前线=`EDGE-301`。P12 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-26 历史收口：EDGE-281..290 批次七十六已收口，统一长门禁通过

批次七十六按序完成 `EDGE-281..290` 共 10 个边界、50 个账本格。十格的 L1 均由可定位的 skill
安装/文件系统/脚本执行 focused 回归与 `TestSkillInstall_FullChain` 黑盒证据支持，目标行均为
`✓~~~~`；没有把本轮单测、源代码检查或黑盒场景冒充新的真实 App 五通道，故 L2-L5 全部明确为
`na`。覆盖内容依次为：安装炸弹四道护栏、installed skill 本地漂移与信任门重置、路径穿越/symlink
越界、manifest 拒删、大小写不敏感文件系统、目录前导/占位符、脚本扩展名拒绝、fork 无 runner、
fork skill 的 @ 语义隔离，以及未知 frontmatter 键保真。

正式证据分别为 `testend/rig/formal-evidence/EDGE-281-skill-install-bomb-20260826.md` 至
`EDGE-290-skill-frontmatter-unknown-keys-20260826.md`；独立警报复审=
`testend/rig/formal-evidence/batch-76-ledger-alarm-reaudit-20260826.md`。formal journal=`3936`
（2300 baseline + 1636 live），`gen_coverage.py --check`=`848 rows / 787 carried judgments / 0 tombstones`，
批次目标十行均=`✓~~~~`，`anchors=10/10`，`alarms.py check`=`clean`。批次七十六已满=`50/50`；
统一长门禁证据=`testend/rig/formal-evidence/batch-76-unified-gate-20260826.md`，根门禁、完整 backend
testend、rig 自测与审计全绿，已提交=`810ddd99`。下一原子前线=`EDGE-291`，批次七十七=`0/50`。P12
400+ Journey 继续按用户裁定推迟二期。

#### 历史收口：EDGE-271..280 批次七十五已完成

批次七十五按序完成 `EDGE-271..280` 共 10 个边界、50 个账本格。十格的 L1 均由可定位的 focused
回归与 testend 黑盒证据支持，五格均为 `✓~~~~`；没有把本轮单测、源代码检查或黑盒场景冒充新的真实 App
五通道，故 L2-L5 全部明确为 `na`。覆盖内容依次为：分组事务原子性、分组计数跨分页、workDir 三态过滤、
删除线程读消息、文档大小/并发 position/path 级联/Move 防环，以及对话/Agent 挂载文档删除后的诚实降级。

正式证据分别为 `testend/rig/formal-evidence/EDGE-271-workdir-transaction-crosscheck-20260826.md` 至
`EDGE-280-agent-knowledge-deleted-20260826.md`；独立警报复审=`testend/rig/formal-evidence/batch-75-ledger-alarm-reaudit-20260826.md`。
formal journal=`3886`（2300 baseline + 1586 live），`gen_coverage.py --check`=`848 rows / 777 carried judgments / 0 tombstones`，
批次目标十行均=`✓~~~~`，`anchors=10/10`，`alarms.py check` clean。批次七十五已满=`50/50`；统一长门禁
证据=`testend/rig/formal-evidence/batch-75-unified-gate-20260826.md`，根门禁、完整 backend testend、rig
自测与审计全绿，已提交=`8cb72f0a`。下一原子前线=`EDGE-281`，批次七十六=`0/50`。P12 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-26 当前前线重述：EDGE-229 多块 TTS PCM 拼接

`EDGE-229` 已完成多块 TTS PCM 拼接的 L1 focused regression：多个 WAV 在 PCM 层重接成一个 WAV、只保留
一个 RIFF 头；LIST metadata 不被当样本，混合采样率大声拒绝，单块原样透传，各 provider 均有显式 chunk
limit。独立正式 App/真实 TTS 和五通道 session 尚未执行，L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-229-tts-pcm-concat-20260826.md`；五级=
`measure:edge229-tts-pcm-concat/na/na/na/na`；formal journal=`3631`（2300 baseline + 1331 live），
`gen_coverage.py --check`=`848 rows / 726 carried judgments / 0 tombstones`，目标行=`✓~~~~`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-229-ledger-alarm-reaudit-20260826.md`。
- 批次七十当前=`45/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-230`。P12 400+ Journey 继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-228 ASR sidecar 无受管凭证

`EDGE-228` 已完成 ASR 诚实缺席的 L1 focused regression：语音服务没有 managed key 时不可用，HTTP
`GET /api/v1/speech/asr` 明确返回 `503` + `SPEECH_UNAVAILABLE`，不会拿 BYOK fallback，也不会建立半配置
WebSocket；有 managed key 的正常代理回归同时通过。独立正式 App/真实语音输入和五通道 session 尚未执行，
L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-228-asr-no-managed-credential-20260826.md`；五级=
`measure:edge228-asr-no-managed-credential/na/na/na/na`；formal journal=`3626`（2300 baseline + 1326 live），
`gen_coverage.py --check`=`848 rows / 725 carried judgments / 0 tombstones`，目标行=`✓~~~~`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-228-ledger-alarm-reaudit-20260826.md`。
- 批次七十当前=`40/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-229`。P12 400+ Journey 继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-227 语音配额与限流分流

`EDGE-227` 已完成语音错误 taxonomy 的 L1 focused regression：QUOTA/BUDGET/INSTALL_CAP 映射为
`SPEECH_QUOTA_EXHAUSTED` 且不可重试，RATE_LIMITED/UPSTREAM_BUSY 映射为可重试的 `SPEECH_RATE_LIMITED`，
ACCOUNT_BANNED 映射为 `SPEECH_ACCOUNT_BANNED`；握手前、HTTP 402/429 和流内错误保持同一分流。独立正式
App/真实语音网关和五通道 session 尚未执行，L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-227-speech-error-taxonomy-20260826.md`；五级=
`measure:edge227-speech-error-taxonomy/na/na/na/na`；formal journal=`3621`（2300 baseline + 1321 live），
`gen_coverage.py --check`=`848 rows / 724 carried judgments / 0 tombstones`，目标行=`✓~~~~`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-227-ledger-alarm-reaudit-20260826.md`。
- 批次七十当前=`35/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-228`。P12 400+ Journey 继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-226 受管档视频路由

`EDGE-226` 已完成受管视频路由的 L1 focused regression：只有 managed key 时 video/image/speech 能力可用，
video route 使用 install id、桌面侧不伪造 model；本地 TLS 网关完整 submit/poll/fetch/receipt 回归确认线缆
带 `X-Anselm-Install-ID`，text-to-video 与 image-to-video 的 endpoint/payload 也分别锁定，图生视频只在显式
capability 时出现。独立正式 App/真实受管视频和五通道 session 尚未执行，L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-226-managed-video-route-20260826.md`；五级=
`measure:edge226-managed-video-route/na/na/na/na`；formal journal=`3616`（2300 baseline + 1316 live），
`gen_coverage.py --check`=`848 rows / 723 carried judgments / 0 tombstones`，目标行=`✓~~~~`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-226-ledger-alarm-reaudit-20260826.md`。
- 批次七十当前=`30/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-227`。P12 400+ Journey 继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-225 能力工具诚实缺席

`EDGE-225` 已完成出图能力诚实缺席的 L1 focused regression：空 key/probe 集合时，`generate_image` 的
逐请求 availability 为 false，不进入能力工具集；模拟旧回合直接调用则返回 typed `IMAGE_NO_ROUTE`，不偷偷
换路由、不让模型看到必然失败的工具。独立正式 App/工具回合和五通道 session 尚未执行，L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-225-image-capability-honest-absence-20260826.md`；五级=
`measure:edge225-image-capability-honest-absence/na/na/na/na`；formal journal=`3611`（2300 baseline + 1311 live），
`gen_coverage.py --check`=`848 rows / 722 carried judgments / 0 tombstones`，目标行=`✓~~~~`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-225-ledger-alarm-reaudit-20260826.md`。
- 批次七十当前=`25/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-226`。P12 400+ Journey 继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-224 不可能的生成组合钳制

`EDGE-224` 已完成生成时长钳制的 L1 focused regression。当前 main 的生成已收敛到受管网关，硬上限为 15 秒；
本地 TLS 网关完整走 `GenerateVideo.Execute` 的 submit → poll → fetch → receipt 路径，输入 30 秒时实际提交
15 秒，最终 receipt 也报告 15 秒。旧清册例子中的 Veo 直连不再是当前可用能力，已在正式证据中明确，不把历史
路径伪装成现行产品。独立正式 App/真实生成和五通道 session 尚未执行，L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-224-video-duration-clamp-20260826.md`；五级=
`measure:edge224-video-duration-clamp/na/na/na/na`；formal journal=`3606`（2300 baseline + 1306 live），
`gen_coverage.py --check`=`848 rows / 721 carried judgments / 0 tombstones`，目标行=`✓~~~~`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-224-ledger-alarm-reaudit-20260826.md`。
- 批次七十当前=`20/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-225`。P12 400+ Journey 继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-223 视频轮询超时诚实话

`EDGE-223` 已完成视频异步任务超时/取消的 L1 focused regression：本地 HTTP server 模拟网关已 `202 Accepted`
并返回 opaque handle，随后取消本地回合；实现返回 `VIDEO_GEN_FAILED`，错误中明确写出上游任务可能仍会完成，
且不会继续发起首次轮询。时长钳制与受管视频路由回归同时通过。独立正式 App/真实视频生成和五通道 session
尚未执行，L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-223-video-poll-timeout-20260826.md`；五级=
`measure:edge223-video-poll-timeout/na/na/na/na`；formal journal=`3601`（2300 baseline + 1301 live），
`gen_coverage.py --check`=`848 rows / 720 carried judgments / 0 tombstones`，目标行=`✓~~~~`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-223-ledger-alarm-reaudit-20260826.md`。
- 批次七十当前=`15/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-224`。P12 400+ Journey 继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-222 生成 origin 从凭证派生

`EDGE-222` 已完成生成 origin 的 L1 focused regression：Qwen/DashScope 图片、语音、视频生成路由均从
凭证聊天 base URL 剥离 `/compatible-mode/v1` 派生原生 origin，覆盖新加坡、北京、workspace 域、尾斜杠、
代理路径和空 base fallback；实际 Qwen 兼容请求也保留配置的区域 endpoint。独立正式 App/生成调用和五通道
session 尚未执行，L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-222-llm-generation-origin-20260826.md`；五级=
`measure:edge222-llm-generation-origin/na/na/na/na`；formal journal=`3596`（2300 baseline + 1296 live），
`gen_coverage.py --check`=`848 rows / 719 carried judgments / 0 tombstones`，目标行=`✓~~~~`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-222-ledger-alarm-reaudit-20260826.md`。
- 批次七十当前=`10/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-223`。P12 400+ Journey 继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-221 写时校 apiKeyId 存在性

`EDGE-221` 已完成 model reference 写时存在性校验的 L1 focused regression：conversation override、agent override、
workspace scenario default 和 search default 四条路径均在写入时拒绝悬空 `apiKeyId` 并返回 `API_KEY_NOT_FOUND`，
真实 key 和清除操作仍可用。独立正式多实体 API/App session 尚未执行，L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-221-modelref-key-existence-write-20260826.md`；五级=
`measure:edge221-modelref-key-existence-write/na/na/na/na`；formal journal=`3591`（2300 baseline + 1291 live），
`gen_coverage.py --check`=`848 rows / 718 carried judgments / 0 tombstones`，目标行=`✓~~~~`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-221-ledger-alarm-reaudit-20260826.md`。
- 批次七十当前=`5/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-222`。P12 400+ Journey 继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-220 未探测/custom 模型

`EDGE-220` 已完成未探测/custom 模型的 L1 focused regression：空 options 的未列模型仍可保存/运行，不硬套
不存在的目录；一旦带 native option 则必须有公开契约，拼错 model id 保持 invoke 时 fail-loud。独立正式 model-picker/
invoke session 尚未执行，L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-220-model-custom-unprobed-empty-options-20260826.md`；五级=
`measure:edge220-model-custom-unprobed-empty-options/na/na/na/na`；formal journal=`3586`（2300 baseline + 1286 live），
`gen_coverage.py --check`=`848 rows / 717 carried judgments / 0 tombstones`，目标行=`✓~~~~`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-220-ledger-alarm-reaudit-20260826.md`。
- 批次六十九当前=`50/50`；统一收口证据=`testend/rig/formal-evidence/batch-69-unified-gate-20260826.md`，
  `make verify`、完整 testend、rig 51 项、后端 verify、锚点、警报、脚本语法、gofmt 与工作树审计均通过，
- 批次六十九已提交=`a9ef3e30`；下一原子前线=`EDGE-221`（写时校 apiKeyId 存在性），批次七十当前=`0/50`。
  P12 400+ Journey 继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-219 native knob 校验

`EDGE-219` 已完成 native model option 的 L1 focused regression：精确已探测 key/model 对只接受公开旋钮和值，
未知旋钮返回 `MODEL_OPTION_UNSUPPORTED`，非法值返回 `MODEL_OPTION_VALUE_INVALID`；未探测/custom 模型空 options
仍可用。独立正式 model-picker session 尚未执行，L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-219-model-native-knob-validation-20260826.md`；五级=
`measure:edge219-model-native-knob-validation/na/na/na/na`；formal journal=`3581`（2300 baseline + 1281 live），
`gen_coverage.py --check`=`848 rows / 716 carried judgments / 0 tombstones`，目标行=`✓~~~~`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-219-ledger-alarm-reaudit-20260826.md`。
- 批次六十九当前=`45/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-220`。P12 400+ Journey 继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-218 播种只填未设

`EDGE-218` 已完成受管默认播种边界的 L1 focused regression：用户已选的 dialogue 模型保持不变，未设置的
scenario 才被填入 managed model，重复播种无副作用。独立正式 model-picker session 尚未执行，L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-218-freetier-seed-unset-only-20260826.md`；五级=
`measure:edge218-freetier-seed-unset-only/na/na/na/na`；formal journal=`3576`（2300 baseline + 1276 live），
`gen_coverage.py --check`=`848 rows / 715 carried judgments / 0 tombstones`，目标行=`✓~~~~`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-218-ledger-alarm-reaudit-20260826.md`。
- 批次六十九当前=`40/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-219`。P12 400+ Journey 继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-217 旋转 key 重探失败

`EDGE-217` 已完成 key rotation 与重探失败分离的 L1 focused regression：PATCH 旋转已成功持久化，即使
后续 probe 失败也不回滚新凭证，而是把 `testStatus` 诚实落为 error，避免状态脑裂。独立正式设置/API session
尚未执行，L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-217-apikey-rotation-probe-failure-20260826.md`；五级=
`measure:edge217-apikey-rotation-probe-failure/na/na/na/na`；formal journal=`3571`（2300 baseline + 1271 live），
`gen_coverage.py --check`=`848 rows / 714 carried judgments / 0 tombstones`，目标行=`✓~~~~`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-217-ledger-alarm-reaudit-20260826.md`。
- 批次六十九当前=`35/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-218`。P12 400+ Journey 继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-216 被引用的 key 拒删

`EDGE-216` 已完成被引用 key 删除边界的 L1 focused regression：reference scanner 报告 scenario/default 等
引用时，删除被拒并携带结构化引用详情；未引用普通 key 仍可删除，未扩大守卫范围。独立正式设置/API session
尚未执行，L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-216-apikey-in-use-delete-20260826.md`；五级=
`measure:edge216-apikey-in-use-delete/na/na/na/na`；formal journal=`3566`（2300 baseline + 1266 live），
`gen_coverage.py --check`=`848 rows / 713 carried judgments / 0 tombstones`，目标行=`✓~~~~`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-216-ledger-alarm-reaudit-20260826.md`。
- 批次六十九当前=`30/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-217`。P12 400+ Journey 继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-215 受管 key 不可变

`EDGE-215` 已完成受管 `anselm` key 不可变的 L1 focused regression：即使零引用，用户 PATCH/DELETE 也被
拒绝；provider 元数据保持 managed，同时普通用户 key 仍可编辑/删除，守卫没有过宽。独立正式设置 UI/API
session 尚未执行，L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-215-apikey-managed-immutable-20260826.md`；五级=
`measure:edge215-apikey-managed-immutable/na/na/na/na`；formal journal=`3561`（2300 baseline + 1261 live），
`gen_coverage.py --check`=`848 rows / 712 carried judgments / 0 tombstones`，目标行=`✓~~~~`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-215-ledger-alarm-reaudit-20260826.md`。
- 批次六十九当前=`25/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-216`。P12 400+ Journey 继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-214 开通降级不挂 boot

`EDGE-214` 已完成免费档开通降级的 L1 focused regression：无机器指纹、网关安装失败和持久化竞争均不阻塞
boot/onboarding；后台 ensure best-effort 返回 nil，前台在没有 managed 行时诚实返回 `false,nil`，竞争胜者保持幂等。
独立真实 App 冷启动/onboarding session 尚未执行，L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-214-freetier-provision-degraded-20260826.md`；五级=
`measure:edge214-freetier-provision-degraded/na/na/na/na`；formal journal=`3556`（2300 baseline + 1256 live），
`gen_coverage.py --check`=`848 rows / 711 carried judgments / 0 tombstones`，目标行=`✓~~~~`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-214-ledger-alarm-reaudit-20260826.md`。
- 批次六十九当前=`20/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-215`。P12 400+ Journey 继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-213 未开通读配额

`EDGE-213` 已完成未开通免费档读配额的 L1 focused regression：没有 managed `anselm` 行时，quota reader
在解析凭证或访问网关前返回 typed `FREETIER_NOT_PROVISIONED`，设置页据此隐藏仪表而不是渲染误导性的零。
独立真实 App 设置页 session 尚未执行，L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-213-freetier-quota-not-provisioned-20260826.md`；五级=
`measure:edge213-freetier-quota-not-provisioned/na/na/na/na`；formal journal=`3551`（2300 baseline + 1251 live），
`gen_coverage.py --check`=`848 rows / 710 carried judgments / 0 tombstones`，目标行=`✓~~~~`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-213-ledger-alarm-reaudit-20260826.md`。
- 批次六十九当前=`15/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-214`。P12 400+ Journey 继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-212 瞬时失败绝不轮换

`EDGE-212` 已完成受管 install 瞬时失败边界的 L1 focused regression：断网、HTTP 429 限流、健康探测和
重装失败均不轮换既有 install，只有独立的 `INVALID_INSTALL` 分支允许自愈；失败保持原行并可重试。
独立真实 App repair session 尚未执行，L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-212-freetier-transient-no-rotation-20260826.md`；五级=
`measure:edge212-freetier-transient-no-rotation/na/na/na/na`；formal journal=`3546`（2300 baseline + 1246 live），
`gen_coverage.py --check`=`848 rows / 709 carried judgments / 0 tombstones`，目标行=`✓~~~~`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-212-ledger-alarm-reaudit-20260826.md`。
- 批次六十九当前=`10/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-213`。P12 400+ Journey 继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-211 网关 install 自愈

`EDGE-211` 已完成受管 install 自愈的 L1 focused regression：网关明确返回 `INVALID_INSTALL` 时重新登记
设备并用 `RotateManagedCredential` 原位轮换同一 managed row；网络失败、限流、健康结果不轮换，重装失败保留
原行。独立真实 App repair session 尚未执行，L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-211-freetier-install-heal-20260826.md`；五级=
`measure:edge211-freetier-install-heal/na/na/na/na`；formal journal=`3541`（2300 baseline + 1241 live），
`gen_coverage.py --check`=`848 rows / 708 carried judgments / 0 tombstones`，目标行=`✓~~~~`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-211-ledger-alarm-reaudit-20260826.md`。
- 批次六十九当前=`5/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-212`。P12 400+ Journey 继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-210 免费档配额耗尽

`EDGE-210` 已完成免费档耗尽错误边界回归：HTTP 402、HTTP 429 耗尽码与流内
`BUDGET_EXHAUSTED` 统一为 `LLM_QUOTA_EXHAUSTED`，不把耗尽误当瞬时限流重试；真实无配额网关耗尽
session 尚未计入 L2-L5。

正式证据=`testend/rig/formal-evidence/EDGE-210-freetier-quota-exhausted-20260826.md`；五级=
`measure:edge210-freetier-quota-exhausted/na/na/na/na`；formal journal=`3536`
（2300 baseline + 1236 live），`gen_coverage.py --check`=`848 rows / 707 carried judgments / 0 tombstones`，
目标行=`✓~~~~`，`anchors=10/10`，`alarms.py check` clean；警报复审=
`testend/rig/formal-evidence/EDGE-210-ledger-alarm-reaudit-20260826.md`。
- 批次六十八当前=`50/50`；统一收口证据=`testend/rig/formal-evidence/batch-68-unified-gate-20260826.md`，
  `make verify`、完整 testend、rig 51 项、后端 verify、锚点、警报、脚本语法、gofmt 与工作树审计均通过，
- 批次六十八已提交=`cb1d630f`；下一原子前线=`EDGE-211`（网关 install 自愈），批次六十九当前=`0/50`。
  P12 400+ Journey 继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-203 非 audio 签发 playback

`EDGE-203` 已完成 playback 媒体类型门禁回归：文本附件请求 playback lease 在 token 生成前返回 `415
Unsupported Media Type`，不产生可被 bearerless fetch 使用的播放 token。

正式证据=`testend/rig/formal-evidence/EDGE-203-attachment-non-audio-playback-reject-20260826.md`；五级=
`measure:edge203-attachment-non-audio-playback-reject/na/na/na/na`；formal journal=`3501`
（2300 baseline + 1201 live），`gen_coverage.py --check`=`848 rows / 700 carried judgments / 0 tombstones`，
目标行=`✓~~~~`，`anchors=10/10`，`alarms.py check` clean；警报复审=
`testend/rig/formal-evidence/EDGE-203-ledger-alarm-reaudit-20260826.md`。
- 批次六十八当前=`15/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-204`。P12 400+ Journey
  继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-202 audio playback token 过期

`EDGE-202` 已完成音频播放 lease 过期回归：可控时钟推进到过期后，bearerless playback fetch 返回 404，
不会继续读取音频；未过期路径仍支持无 bearer/workspace header 的原生播放器访问和 Range seek。

正式证据=`testend/rig/formal-evidence/EDGE-202-attachment-audio-playback-token-expiry-20260826.md`；五级=
`measure:edge202-attachment-audio-playback-token-expiry/na/na/na/na`；formal journal=`3496`
（2300 baseline + 1196 live），`gen_coverage.py --check`=`848 rows / 699 carried judgments / 0 tombstones`，
目标行=`✓~~~~`，`anchors=10/10`，`alarms.py check` clean；警报复审=
`testend/rig/formal-evidence/EDGE-202-ledger-alarm-reaudit-20260826.md`。
- 批次六十八当前=`10/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-203`。P12 400+ Journey
  继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-201 缺失/不可读 blob

`EDGE-201` 已完成附件重放完整性回归：metadata 行仍在但 blob 被清扫后，`ToContentParts` 写告警并插入
明确的 `no longer available` 文本说明，不让整轮失败；后续仍可读的附件保持原顺序继续送入模型。metadata
缺失与 blob 不可读两条分支分别覆盖，不能静默消失。

正式证据=`testend/rig/formal-evidence/EDGE-201-attachment-missing-blob-replay-20260826.md`；五级=
`measure:edge201-attachment-missing-blob-replay/na/na/na/na`；formal journal=`3491`
（2300 baseline + 1191 live），`gen_coverage.py --check`=`848 rows / 698 carried judgments / 0 tombstones`，
目标行=`✓~~~~`，`anchors=10/10`，`alarms.py check` clean；警报复审=
`testend/rig/formal-evidence/EDGE-201-ledger-alarm-reaudit-20260826.md`。
- 批次六十八当前=`5/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-202`。P12 400+ Journey
  继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-200 blob GC 只在 boot 跑

`EDGE-200` 已完成附件 blob 生命周期回归：删除只软删附件行，不在删除时扫描或删除 blob；GC 按每个
workspace 的 live SHA 保留集执行，仍被活跃附件共享的 SHA 保留，孤儿 blob 才清除；启动期先完成
attachment GC，再启动 media worker，避开上传 `Put → row Create` 的竞态。

正式证据=`testend/rig/formal-evidence/EDGE-200-attachment-blob-gc-boot-only-20260826.md`；五级=
`measure:edge200-attachment-blob-gc-boot-only/na/na/na/na`；formal journal=`3486`
（2300 baseline + 1186 live），`gen_coverage.py --check`=`848 rows / 697 carried judgments / 0 tombstones`，
目标行=`✓~~~~`，`anchors=10/10`，`alarms.py check` clean；警报复审=
`testend/rig/formal-evidence/EDGE-200-ledger-alarm-reaudit-20260826.md`。
- 批次六十七=`50/50`；统一长门禁全绿，收口证据=`testend/rig/formal-evidence/batch-67-unified-gate-20260826.md`，
  本批已完成提交；下一原子前线=`EDGE-201`。P12 400+ Journey 继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-199 代理图未 ready

`EDGE-199` 已完成准备时序回归：model-default proxy worker 被阻塞时，调用最多等待约 2 秒后返回
`ready=false`，本回合可用原图继续；解除阻塞后后台 worker 仍将 durable derivative 处理为 ready；ready
proxy 路径继续进入 managed staging。准备慢与 staging 失败保持不同语义。

正式证据=`testend/rig/formal-evidence/EDGE-199-attachment-proxy-not-ready-20260826.md`；五级=
`measure:edge199-attachment-proxy-not-ready/na/na/na/na`；formal journal=`3481`
（2300 baseline + 1181 live），`gen_coverage.py --check`=`848 rows / 696 carried judgments / 0 tombstones`，
目标行=`✓~~~~`，`anchors=10/10`，`alarms.py check` clean；警报复审=
`testend/rig/formal-evidence/EDGE-199-ledger-alarm-reaudit-20260826.md`。
- 批次六十七已完成=`50/50`；统一长门禁待执行，门禁通过后提交；下一原子前线=`EDGE-201`。P12 400+ Journey
  继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-198 staging 失败大声失败

`EDGE-198` 已完成失败传播回归：受管 uploader 返回错误时，attachment 不生成成功媒体 part，chat history
保留 `render attachments` 上下文，loop 唯一收尾落 `StatusError / StopReasonError / INTERNAL_ERROR`
并发出终止帧；不会静默丢媒体、伪装成功或把系统故障降级成 HEIC/AVIF 的正常占位。

正式证据=`testend/rig/formal-evidence/EDGE-198-attachment-staging-failure-20260826.md`；五级=
`measure:edge198-attachment-staging-failure/na/na/na/na`；formal journal=`3476`
（2300 baseline + 1176 live），`gen_coverage.py --check`=`848 rows / 695 carried judgments / 0 tombstones`，
目标行=`✓~~~~`，`anchors=10/10`，`alarms.py check` clean；警报复审=
`testend/rig/formal-evidence/EDGE-198-ledger-alarm-reaudit-20260826.md`。
- 批次六十七当前=`40/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-199`。P12 400+ Journey
  继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-197 lease 临期刷新

`EDGE-197` 已完成 safety-window 与生命周期 focused 回归：lease 进入 30 秒窗口会重新 staging，刷新
上传的 bytes 与原附件逐字节一致；新建 `MediaClient`（模拟 sidecar 重启）不会复用旧进程的内存 lease。
`inspect_media` 同样复用 relative lease gate，绝对路径不会绕过视觉复查边界。

正式证据=`testend/rig/formal-evidence/EDGE-197-attachment-lease-refresh-20260826.md`；五级=
`measure:edge197-attachment-lease-refresh/na/na/na/na`；formal journal=`3471`
（2300 baseline + 1171 live），`gen_coverage.py --check`=`848 rows / 694 carried judgments / 0 tombstones`，
目标行=`✓~~~~`，`anchors=10/10`，`alarms.py check` clean；警报复审=
`testend/rig/formal-evidence/EDGE-197-ledger-alarm-reaudit-20260826.md`。
- 批次六十七当前=`35/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-198`。P12 400+ Journey
  继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-196 受管 remote media lease

`EDGE-196` 已完成应用层、resumable media client 和 device-proof focused 回归：受管图片经
create → chunk → complete 取短期 lease，模型输入只保留 `/v1/media/leases/...?...` 相对路径；
`MediaClient` 与 `ToContentParts` 两层均拒绝 scheme/host/错误前缀，图片 bytes/base64 不进入受管
媒体引用。旧 attachment fake 已同步为相对路径，新增绝对路径拒绝回归；当前工作区无
`EVALS_MANAGED=1` 凭证，未伪造本轮真实网关五通道证据。

正式证据=`testend/rig/formal-evidence/EDGE-196-attachment-managed-media-lease-20260826.md`；五级=
`measure:edge196-attachment-managed-media-lease/na/na/na/na`；formal journal=`3466`
（2300 baseline + 1166 live），`gen_coverage.py --check`=`848 rows / 693 carried judgments / 0 tombstones`，
目标行=`✓~~~~`，`anchors=10/10`，`alarms.py check` clean；警报复审=
`testend/rig/formal-evidence/EDGE-196-ledger-alarm-reaudit-20260826.md`。
- 批次六十七当前=`30/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-197`。P12 400+ Journey
  继续推迟二期。

#### 2026-08-26 当前前线重述：EDGE-195 不可交付格式（HEIC/AVIF）

`EDGE-195` 已通过 managed media focused 回归：上传 `IMG_0001.HEIC` 后投影到受管模型输入，格式闭集
守卫在 uploader 前识别 `image/heic`，返回点名文件和 MIME 的诚实文字占位，uploader 调用数为零，
不会把一次网关必拒请求拖成整轮失败。正式边界没有独立受管 App/五通道 session，故严格只判
`L1=measure:edge195-attachment-undeliverable-format`，`L2=na`、`L3=na`、`L4=na`、`L5=na`。

正式证据=`testend/rig/formal-evidence/EDGE-195-attachment-undeliverable-format-20260826.md`；警报复审=
`testend/rig/formal-evidence/EDGE-195-ledger-alarm-reaudit-20260826.md`。formal journal=`3461`
（2300 baseline + 1161 live），`gen_coverage.py --check`=`848 rows / 692 carried judgments / 0 tombstones`，
目标行=`✓~~~~`，`anchors=10/10`，`alarms.py check` clean。批次六十七当前=`25/50`；未满 50 格不跑统一长门禁、
不提交。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-26 当前前线重述：EDGE-194 单回合媒体额度耗尽

`EDGE-194` 已通过 focused 本地与远端 envelope 回归：同一回合两张图片、`MaxMediaParts=1` 时第一张
保持 native image part，第二张按原顺序变成含文件名和 `item limit` 的文字占位；远端 managed staging
同样按最终 staging 字节预算拒绝超额项，不创建 lease、不把整轮打死。由于本格没有独立正式受管 App/五通道
额度耗尽 session，严格只判 `L1=measure:edge194-attachment-media-envelope`，`L2=na`、`L3=na`、
`L4=na`、`L5=na`。

正式证据=`testend/rig/formal-evidence/EDGE-194-attachment-media-envelope-20260826.md`；警报复审=
`testend/rig/formal-evidence/EDGE-194-ledger-alarm-reaudit-20260826.md`。formal journal=`3456`
（2300 baseline + 1156 live），`gen_coverage.py --check`=`848 rows / 691 carried judgments / 0 tombstones`，
目标行=`✓~~~~`，`anchors=10/10`，`alarms.py check` clean。批次六十七当前=`25/50`；未满 50 格不跑统一长门禁、
不提交。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-26 当前前线重述：EDGE-193 模型能力缺失诚实降级

`EDGE-193` 已通过 focused、provider wire 与真实 HTTP/chat 黑盒：把默认模型切换到 mock 未列出的
text-only fixture，使解析能力明确为 `Vision=false`；上传图片并发送聊天后，真实 `role=user` content
只包含文件名和 `no native vision input` 占位，没有 `image_url` 或 PNG base64，回合最终 `completed`，附件
仍可通过 HTTP 下载且字节不变。DeepSeek 的 all-text parts 坍缩也由 focused 回归锁住，避免纯文本端点因
数组形 content 永久 400。

本格没有独立正式 App/五通道无 vision session，故严格只判
`L1=measure:edge193-attachment-no-vision-degrade`，`L2=na`、`L3=na`、`L4=na`、`L5=na`。

正式证据=`testend/rig/formal-evidence/EDGE-193-attachment-no-vision-degrade-20260826.md`；警报复审=
`testend/rig/formal-evidence/EDGE-193-ledger-alarm-reaudit-20260826.md`。formal journal=`3451`
（2300 baseline + 1151 live），`gen_coverage.py --check`=`848 rows / 690 carried judgments / 0 tombstones`，
目标行=`✓~~~~`，`anchors=10/10`，`alarms.py check` clean。批次六十七当前=`25/50`；未满 50 格不跑统一长门禁、
不提交。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-26 当前前线重述：EDGE-192 不认的 mime 抽取

`EDGE-192` 已通过 focused 与真实 HTTP/chat 黑盒：抽取器对不在 handler 闭集内的
`application/vnd.oasis.opendocument.text` 立即返回 `ATTACHMENT_EXTRACTION_UNSUPPORTED`，且不启动共享
Python 环境；真实上传 ODT 后在聊天中引用，后端记录 `extraction unsupported for this mime`，LLM wire
只出现诚实的 `could not be extracted` 占位，不出现原始字节，回合最终 `completed`。

本格没有独立正式 App/五通道 unsupported-MIME session，故严格只判
`L1=measure:edge192-attachment-unsupported-mime`，`L2=na`、`L3=na`、`L4=na`、`L5=na`。

正式证据=`testend/rig/formal-evidence/EDGE-192-attachment-unsupported-mime-20260826.md`；警报复审=
`testend/rig/formal-evidence/EDGE-192-ledger-alarm-reaudit-20260826.md`。formal journal=`3446`
（2300 baseline + 1146 live），`gen_coverage.py --check`=`848 rows / 689 carried judgments / 0 tombstones`，
目标行=`✓~~~~`，`anchors=10/10`，`alarms.py check` clean。批次六十七当前=`25/50`；未满 50 格不跑统一长门禁、
不提交。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-26 当前前线重述：EDGE-191 附件 sandbox 提取路径

`EDGE-191` 已通过真实 testend 黑盒：动态构造最小合法 `.docx`，上传为 Office Open XML 附件，真实发送带
`attachmentIds` 的聊天回合；共享 Python sandbox 通过 `python-docx` 抽取正文并注入 LLM wire。正文包含头部
哨兵、超过 400K rune 的长正文和尾部哨兵；wire 能看到文件名、`text-extracted, truncated` 和头部哨兵，
400K 截断点之后的尾部哨兵未越界，回合最终 `completed`。同一 testend 文件已有真实 `.odt` 不支持 MIME
降级：只给诚实占位、原始字节不上 wire、回合仍 completed。

本格没有独立正式 App/五通道 sandbox session，故严格只判 `L1=measure:edge191-attachment-sandbox-docx`，
`L2=na`、`L3=na`、`L4=na`、`L5=na`，不把 testend 证据冒充产品视觉验收。

正式证据=`testend/rig/formal-evidence/EDGE-191-attachment-sandbox-docx-20260826.md`；警报复审=
`testend/rig/formal-evidence/EDGE-191-ledger-alarm-reaudit-20260826.md`。formal journal=`3441`
（2300 baseline + 1141 live），`gen_coverage.py --check`=`848 rows / 688 carried judgments / 0 tombstones`，
目标行=`✓~~~~`，`anchors=10/10`，`alarms.py check` clean。批次六十七当前=`15/50`；未满 50 格不跑统一长门禁、
不提交。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-26 批次六十六收口与提交

批次六十六 `EDGE-181..190` 共 50 格已逐格登记，统一长门禁全绿，收口证据=`testend/rig/formal-evidence/batch-66-unified-gate-20260825.md`，
已提交=`1be292f9`（`test(rig): close batch 66 search edges`）。提交后工作树保持 clean；当前 formal journal=`3436`
（2300 baseline + 1136 live），COVERAGE=`848/687/0`，anchors=`10/10`，`alarms.py check` clean。批次六十七
从 `0/50` 开始，已收口 `EDGE-191..195` 为 `25/50`，下一原子前线=`EDGE-196`；P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-190 sifter 缺席回退

`EDGE-190` 已验证 utility 模型缺席时 `search_blocks` 的诚实回退：focused 与真实 LLM/HTTP 场景均确认
两级 sifter 不可用后回到纯索引排序，仍返回 function 与可接线 handler method ref；同名 document/skill
诱饵不泄漏。当前没有独立正式 App/五通道 utility 缺席 session，因此 L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-190-search-sifter-absent-fallback-20260825.md`。五级严格为
`L1=measure:edge190-search-sifter-absent-fallback`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；formal journal=`3436`
（2300 baseline + 1136 live），`gen_coverage.py --check`=`848 rows / 687 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-190-ledger-alarm-reaudit-20260825.md`。
批次六十六已达到=`50/50`；统一长门禁已通过，收口证据见上方，随后已提交。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-189 Changed 队满丢事件

`EDGE-189` 已验证搜索写侧队列的丢事件自愈：focused `-race` 回归先填满 1024 项队列，真实
`Notifier.Changed` 在队满时 100ms 内返回；随后启动 worker 执行 stamps 对账，恢复被丢的 live entity，
并将只存在索引中的 orphan 投影为空清除。当前没有独立正式 App/五通道批量写入 session，因此 L2-L5
保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-189-search-changed-queue-reconcile-20260825.md`。五级严格为
`L1=measure:edge189-search-changed-queue-reconcile`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；formal journal=`3431`
（2300 baseline + 1131 live），`gen_coverage.py --check`=`848 rows / 686 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-189-ledger-alarm-reaudit-20260825.md`。
批次六十六当前=`45/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-190`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-188 密文红线

`EDGE-188` 已通过真实 HTTP 黑盒验证密文不进搜索投影：创建带 secret 的 API key、webhook trigger、MCP
env 后，trigger 明文名和 MCP 明文描述正控可搜，三个 secret token 均零命中；真实 Encryptor、落盘和
search projection 均经过。当前没有独立正式 App/五通道密文搜索 session，因此 L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-188-search-encrypted-redline-20260825.md`。五级严格为
`L1=measure:edge188-search-encrypted-redline`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；formal journal=`3426`
（2300 baseline + 1126 live），`gen_coverage.py --check`=`848 rows / 685 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-188-ledger-alarm-reaudit-20260825.md`。
批次六十六当前=`40/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-189`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-187 fts_schema_version 不匹配

`EDGE-187` 已验证搜索索引 schema 版本漂移的启动处置：focused `-race` 回归把 `fts_schema_version`
置为旧值并预置旧 lexical hit 与旧 embedding；启动只执行一次全量 `DropAll`，写入当前版本，再从 live
source 恢复投影，旧词法命中与旧向量均不残留；该包完整 race 回归也通过。当前没有独立正式旧库启动
App/五通道 session，因此 L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-187-search-schema-version-rebuild-20260825.md`。五级严格为
`L1=measure:edge187-search-schema-version-rebuild`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；formal journal=`3421`
（2300 baseline + 1121 live），`gen_coverage.py --check`=`848 rows / 684 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-187-ledger-alarm-reaudit-20260825.md`。
批次六十六当前=`35/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-188`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-186 :reindex 并发与就地重建

`EDGE-186` 已验证搜索重建的并发与数据连续性：focused `-race` 回归确认同一 workspace 第二次
reindex 冲突、不同 workspace 不互相阻塞、完成后锁可再次取得，force-reconcile 不调用 purge；真实
HTTP 场景得到 204 且重建后命中恢复，并继续验证设置/降级对照。当前没有独立正式 App/五通道并发
reindex session，因此 L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-186-search-reindex-singleflight-inplace-20260825.md`。五级严格为
`L1=measure:edge186-search-reindex-singleflight-inplace`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；formal journal=`3416`
（2300 baseline + 1116 live），`gen_coverage.py --check`=`848 rows / 683 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-186-ledger-alarm-reaudit-20260825.md`。
批次六十六当前=`30/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-187`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-185 异查询游标

`EDGE-185` 已验证搜索 cursor 与 query 的绑定：focused `-race` 回归确认 page 1→page 2 不重复，异
query cursor 返回 `ErrCursorInvalid`，合法 base64 padding 仍可继续；真实 HTTP 场景创建 25 个 function
完成 `10+10+5` 分页，total 稳定无重复，异 query 和坏 cursor 均返回 400 `SEARCH_CURSOR_INVALID`。
当前没有独立正式 App/五通道分页 session，因此 L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-185-search-cursor-query-binding-20260825.md`。五级严格为
`L1=measure:edge185-search-cursor-query-binding`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；formal journal=`3411`
（2300 baseline + 1111 live），`gen_coverage.py --check`=`848 rows / 682 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-185-ledger-alarm-reaudit-20260825.md`。
批次六十六当前=`25/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-186`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-184 短词 LIKE 回退

`EDGE-184` 已验证搜索的短词回退：focused `-race` 回归确认两字符中文在 trigram FTS 零命中时仍经
LIKE 命中并生成高亮 snippet；长 token 走 MATCH、短 token 叠加 LIKE 后保持合取，只保留同时满足两者的
实体；tokenizer 同时锁住两字符中英文进入 short bucket。当前没有独立正式 App/五通道搜索 session，
因此 L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-184-search-short-token-like-fallback-20260825.md`。五级严格为
`L1=measure:edge184-search-short-token-like-fallback`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；formal journal=`3406`
（2300 baseline + 1106 live），`gen_coverage.py --check`=`848 rows / 681 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-184-ledger-alarm-reaudit-20260825.md`。
批次六十六当前=`20/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-185`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-183 换 embedder 重嵌

`EDGE-183` 已验证切换语义 embedder 的 model-key 闭包：新增 focused `-race` 回归先加载 builtin `m1`
cache，再切换到 `ollama:embeddinggemma`，确认 workspace cache 失效并重新扫描，旧 model 向量不混入新
集合；相邻 settings 回归确认 adapter 使用生效参数且 kick fan-out 覆盖已索引 workspace。真实 HTTP
场景再次验证 reindex 命中、`off` 后词法搜索可用、Ollama 死端口软降级。当前没有独立正式 App/五通道
模型切换 session，因此 L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-183-search-embedder-switch-reembed-20260825.md`。五级严格为
`L1=measure:edge183-search-embedder-switch-reembed`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；formal journal=`3401`
（2300 baseline + 1101 live），`gen_coverage.py --check`=`848 rows / 680 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-183-ledger-alarm-reaudit-20260825.md`。
批次六十六当前=`15/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-184`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-182 cosineFloor 噪声闸

`EDGE-182` 已验证搜索噪声闸的两条边界：focused `-race` 回归确认自然语言乱码的 cosine `0.53` 被
`0.55` floor 拦截，同时 identifier-shaped 乱码即使 cosine `0.63` 高于 floor、没有 lexical evidence，
也不能召回 semantic-only agent；cosine `0.62` 的 genuine match 仍保留，避免噪声修复伤害 recall。
当前没有独立正式 App/五通道语义检索 session，因此 L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-182-search-cosine-floor-noise-gate-20260825.md`。五级严格为
`L1=measure:edge182-search-cosine-floor-noise-gate`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；formal journal=`3396`
（2300 baseline + 1096 live），`gen_coverage.py --check`=`848 rows / 679 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-182-ledger-alarm-reaudit-20260825.md`。
批次六十六当前=`10/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-183`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-181 整批 embed upsert 全失败

`EDGE-181` 已验证向量补算的失败收敛：focused `-race` 回归让整批 `UpsertEmbedding` 全部失败，确认
backfill 在预算内结束当前轮次，只尝试该批一次，不对同一缺失行立即热循环重嵌；失败行留待下一次 kick。
当前没有真实盘满/表损与 App 五通道黑盒，因此 L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-181-search-embed-upsert-all-fail-20260825.md`。五级严格为
`L1=measure:edge181-search-embed-upsert-all-fail`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；formal journal=`3391`
（2300 baseline + 1091 live），`gen_coverage.py --check`=`848 rows / 678 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-181-ledger-alarm-reaudit-20260825.md`。
批次六十六当前=`5/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-182`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-180 embedder 孤儿回收

`EDGE-180` 已验证 builtin embedder 的异常退出收容：Unix focused `-race` 回归把一个 `sleep` 进程
作为上次遗留的 embedder，写入 `embedder.pid` 后确认 `reapStalePID` 杀掉记录的 survivor；不存在 pid
文件和垃圾 pid 内容均安全 no-op，不误伤其它进程。当前没有执行真实 backend `kill -9` 后再启动的
五通道黑盒，因此 L2-L5 保持 `na`。

正式证据=`testend/rig/formal-evidence/EDGE-180-search-embedder-orphan-reap-20260825.md`。五级严格为
`L1=measure:edge180-search-embedder-orphan-reap`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；formal journal=`3386`
（2300 baseline + 1086 live），`gen_coverage.py --check`=`848 rows / 677 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-180-ledger-alarm-reaudit-20260825.md`。
批次六十五当前=`50/50`，统一门禁已通过，收口证据=`testend/rig/formal-evidence/batch-65-unified-gate-20260825.md`，
根 `make verify`、完整 testend、rig 51 项、backend verify、coverage/anchors/alarms、脚本语法、gofmt、
diff 和残留进程审计全绿；本批已提交=`1f16b056`。下一原子前线=`EDGE-181`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-179 首用下载途中关停

`EDGE-179` 已验证 builtin embedder 首用下载撞上关停时的 bounded shutdown：focused `-race` 回归用
无限阻塞的 installer 模拟真实首次下载，确认 `Builtin.Close` 在预算内返回、取消 installer context、
释放下载锁，避免 `db.Close` 被首用模型下载拖死。当前没有执行真实 600MB 下载中的 App/SIGTERM 黑盒，
因此没有把 L2-L5 写成绿。

正式证据=`testend/rig/formal-evidence/EDGE-179-search-first-download-shutdown-20260825.md`。五级严格为
`L1=measure:edge179-search-first-download-shutdown`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格没有独立
正式 rig 的真实首用下载、Computer Use 时序、视觉 craft 或 discoverability 证据。formal journal=`3381`
（2300 baseline + 1081 live），`gen_coverage.py --check`=`848 rows / 676 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-179-ledger-alarm-reaudit-20260825.md`。
批次六十五当前=`45/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-180`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-178 搜索 embedder 缺席降级

`EDGE-178` 已验证语义 embedder 缺席时搜索的诚实降级：focused 回归先让 provider 失败，确认原有
lexical hit 仍返回且无 error；再将 `embedder` 设为 `off`，确认完全跳过融合后仍返回同一 lexical hit。
真实 testend 进一步验证 reindex 后命中、设置回显、跨 workspace 机器级一致性、`off` 状态下词法搜索
继续可用，以及 Ollama 指向关闭端口时仍软降级而不打断搜索。测试使用 `127.0.0.1:1` 作为刻意无网关
fixture，日志中的 free-tier install warning 已在证据中隔离，不作为搜索失败。

正式证据=`testend/rig/formal-evidence/EDGE-178-search-embedder-off-fallback-20260825.md`。五级严格为
`L1=measure:edge178-search-embedder-off-fallback`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格没有独立
正式 rig 的 Computer Use 五通道 session、逐帧时序、视觉 craft 或 discoverability 证据。formal journal=`3376`
（2300 baseline + 1076 live），`gen_coverage.py --check`=`848 rows / 675 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-178-ledger-alarm-reaudit-20260825.md`。
批次六十五当前=`40/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-179`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-177 无可跑 package

`EDGE-177` 已验证 no-runnable 安装计划的 fail-loud 边界：自定义 registry fixture 只有不支持的
runtime 且无 remote 时，focused app 测试返回 `MCP_NO_RUNNABLE_PACKAGE`，repository 保持零 server
行；curated catalog 的全条目 plannability 门禁同时确认正式 marketplace 不会把这种状态暴露给用户。
没有把被 catalog overlay 成 `npx` 的条目伪装成 no-runnable 黑盒证据。

正式证据=`testend/rig/formal-evidence/EDGE-177-mcp-no-runnable-package-20260825.md`。五级严格为
`L1=measure:edge177-mcp-no-runnable-package`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格没有独立
正式 rig 的 Computer Use 五通道 session、错误逐帧时序、视觉 craft 或 discoverability 证据。formal journal=`3371`
（2300 baseline + 1071 live），`gen_coverage.py --check`=`848 rows / 674 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-177-ledger-alarm-reaudit-20260825.md`。
批次六十五当前=`35/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-178`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-176 MCP 市场缺必填 env

`EDGE-176` 已验证 marketplace 的凭据缺失门：focused 安装测试确认 `details.missing` 结构化列出
缺失变量且 repository 不落半行；真实 registry 安装 Firecrawl 空 env 在任何 runtime 下载前返回
`422 MCP_ENV_MISSING`，HTTP body 明确包含 `FIRECRAWL_API_KEY`，没有静默启动零认证 server。

正式证据=`testend/rig/formal-evidence/EDGE-176-mcp-marketplace-missing-env-20260825.md`。五级严格为
`L1=measure:edge176-mcp-marketplace-missing-env`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格没有独立
正式 rig 的 Computer Use 五通道 session、错误逐帧时序、视觉 craft 或 discoverability 证据。formal journal=`3366`
（2300 baseline + 1066 live），`gen_coverage.py --check`=`848 rows / 673 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-176-ledger-alarm-reaudit-20260825.md`。
批次六十五当前=`30/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-177`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-175 MCP 失败附 stderr 尾

`EDGE-175` 已验证 MCP 失败调用的 stderr 证据边界：focused 回归确认 stderr 尾按字节封顶 8 KiB
且保留最新字节；真实 stdio MCP `boom` 失败调用的 durable logs 同时含
`server stderr tail (server-level, may predate this call)` 来源说明与真实 stderr 内容，避免把
server 历史日志误报成当前调用精确时序。

正式证据=`testend/rig/formal-evidence/EDGE-175-mcp-stderr-tail-20260825.md`。五级严格为
`L1=measure:edge175-mcp-stderr-tail`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格没有独立
正式 rig 的 Computer Use 五通道 session、错误日志逐帧时序、视觉 craft 或 discoverability 证据。formal journal=`3361`
（2300 baseline + 1061 live），`gen_coverage.py --check`=`848 rows / 672 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-175-ledger-alarm-reaudit-20260825.md`。
批次六十五当前=`25/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-176`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-174 MCP 进度关联

`EDGE-174` 已验证 session 级 MCP progress handler 的 per-call token 关联：infra `-race` 回归
交错两个 token 时，call-a 只收到 alpha、call-b 只收到 beta，未知 token 被丢弃；真实 HTTP 黑盒
在同一 stdio server 上并发执行 alpha/beta 两个 `echo`，两个调用都成功，两个 durable `mcp_calls`
详情分别只保留自己的 progress 文本，没有串台。

正式证据=`testend/rig/formal-evidence/EDGE-174-mcp-progress-correlation-20260825.md`。五级严格为
`L1=measure:edge174-mcp-progress-correlation`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格没有独立
正式 rig 的 Computer Use 五通道 session、并发进度逐帧时序、视觉 craft 或 discoverability 证据。formal journal=`3356`
（2300 baseline + 1056 live），`gen_coverage.py --check`=`848 rows / 671 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-174-ledger-alarm-reaudit-20260825.md`。
批次六十五当前=`20/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-175`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-173 MCP name-or-id 双键 purge

`EDGE-173` 已验证 MCP 删除的关系清理闭包：focused service 测试确认 `RemoveServer` 同时按
`srv.ID`（`mcp_...`）与 `srv.Name`（`mcp:<name>/tool` 的常见键）调用 purge；真实 HTTP relation
场景先把 `relmcp` 挂到 agent，再删除 server，随后 server 返回 `MCP_SERVER_NOT_FOUND` 且 agent
邻域不再包含 `relmcp`，没有留下关系孤儿。

正式证据=`testend/rig/formal-evidence/EDGE-173-mcp-name-id-purge-20260825.md`。五级严格为
`L1=measure:edge173-mcp-name-id-purge`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格没有独立
正式 rig 的 Computer Use 五通道 session、逐帧时序、视觉 craft 或 discoverability 证据。formal journal=`3351`
（2300 baseline + 1051 live），`gen_coverage.py --check`=`848 rows / 670 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-173-ledger-alarm-reaudit-20260825.md`。
批次六十五当前=`15/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-174`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-172 无 uploader 时的 MCP 媒体

`EDGE-172` 已验证没有 attachment uploader 时的诚实降级：同一 MCP media 调用在 uploader 已接线
时产生 receipt，在 `uploader=nil` 时仍成功但保留原始 `[image: image/png]` 占位，不伪造
`attachmentId` 或 `mcp_media` 产物，也不把可选落地能力缺席升级成整次调用失败。

正式证据=`testend/rig/formal-evidence/EDGE-172-mcp-media-no-uploader-20260825.md`。五级严格为
`L1=measure:edge172-mcp-media-no-uploader`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格没有独立
Computer Use 五通道 session、无 uploader 逐帧时序、视觉成品或 discoverability 证据。formal journal=`3346`
（2300 baseline + 1046 live），`gen_coverage.py --check`=`848 rows / 669 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-172-ledger-alarm-reaudit-20260825.md`。
批次六十五当前=`10/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-173`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-171 MCP 媒体逐件 best-effort

`EDGE-171` 已验证 MCP 多媒体的部分成功语义：一次调用返回 PNG/MP3/JPEG 三件媒体时，第二件
附件故意落库失败，调用仍为成功；两件成功媒体各自成为一等附件并追加 `mcp_media` receipt，
失败件保留原始 `[audio: failed]` 占位叙事。既有真实 stdio→attachment→vision wire 也重跑通过，
同一 PNG 字节确实进入下一次模型的 native image part。无 uploader 的诚实降级仍保留在相邻回归。

正式证据=`testend/rig/formal-evidence/EDGE-171-mcp-media-best-effort-20260825.md`。五级严格为
`L1=measure:edge171-mcp-media-best-effort`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格没有独立
Computer Use 五通道 session、多件失败逐帧时序、视觉成品或 discoverability 证据。formal journal=`3341`
（2300 baseline + 1041 live），`gen_coverage.py --check`=`848 rows / 668 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-171-ledger-alarm-reaudit-20260825.md`。
批次六十五当前=`5/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-172`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-170 MCP 连接失败仍落盘

`EDGE-170` 已验证失败安装的诚实半状态：坏 stdio 与不可达 remote 的 PUT 都先保留 server 行，
运行态为 `failed` 且有 `lastError`；`:reconnect` 仍可尝试但不会伪报恢复，failed server 调工具
明确返回 `MCP_SERVER_DOWN`。focused 还核对了失败重连通知带 outcome status，真实 HTTP 路径核对了
删除/未知动作边界。harness 的无配额回环拒绝和收台 embedder cancel 仍按隔离设计披露。

正式证据=`testend/rig/formal-evidence/EDGE-170-mcp-failed-persists-20260825.md`。五级严格为
`L1=measure:edge170-mcp-failed-persists`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格没有独立
Computer Use 五通道 session、失败重连逐帧时序、视觉成品或 discoverability 证据。formal journal=`3336`
（2300 baseline + 1036 live），`gen_coverage.py --check`=`848 rows / 667 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-170-ledger-alarm-reaudit-20260825.md`。
批次六十四已达到=`50/50`；统一长门禁已通过，收口证据=`testend/rig/formal-evidence/batch-64-unified-gate-20260825.md`，
本批代码/测试/证据已提交=`50c1c9c4`；下一原子前线暂为=`EDGE-171`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-169 MCP degraded 态

`EDGE-169` 已验证 MCP 健康状态与前端实时反馈同源：连续三次工具失败后 server 变为
`degraded`，仍允许调用；entities bridge 收到一条 ephemeral `status` signal；成功调用后连续
失败计数归零、状态恢复 `ready` 并再发恢复 signal。真实 HTTP 生命周期还核对了 mcp_calls 的
成功/失败聚合、stderr tail、reconnect 与删除后的 not-found。harness 的无配额回环拒绝和收台
embedder cancel 均按隔离设计原样记录，没有冒充产品红线或绿证据。

正式证据=`testend/rig/formal-evidence/EDGE-169-mcp-degraded-20260825.md`。五级严格为
`L1=measure:edge169-mcp-degraded`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格没有独立
Computer Use 五通道 session、状态点逐帧时序、视觉成品或 discoverability 证据。formal journal=`3331`
（2300 baseline + 1031 live），`gen_coverage.py --check`=`848 rows / 666 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-169-ledger-alarm-reaudit-20260825.md`。
批次六十四当前=`45/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-170`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-168 每租户模板 URL

`EDGE-168` 已验证 Glean 类 `Remote.URLEnv` 不是目录装饰：catalog plan 暴露唯一必填 URL env；
真实 `InstallFromRegistry` 流程先将 `{MCP_URL}` 展开，再以展开后的 `/mcp` 进入 401/PRM、AS
metadata、DCR、PKCE、loopback callback 和 token exchange。持久 server 的 URL 与 OAuth resource
均绑定展开后的租户地址，未把占位符带进授权受众。

正式证据=`testend/rig/formal-evidence/EDGE-168-mcp-tenant-url-template-20260825.md`。五级严格为
`L1=measure:edge168-mcp-tenant-url-template`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格没有
独立 Computer Use 五通道 session、浏览器逐帧时序、视觉成品或 discoverability 证据。formal journal=`3326`
（2300 baseline + 1026 live），`gen_coverage.py --check`=`848 rows / 665 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-168-ledger-alarm-reaudit-20260825.md`。
批次六十四当前=`40/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-169`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-167 自带客户端固定端口被占

`EDGE-167` 已真实占住 BYO OAuth 注册便利端口 `127.0.0.1:47100`，再启动 callback server；
实现没有把端口占用误报成 OAuth 失败，而是退到随机 loopback 端口，并成功接收 code/state。固定
端口继续服务于确定 redirect URI，但不再是可用性的单点故障。

正式证据=`testend/rig/formal-evidence/EDGE-167-mcp-oauth-port-fallback-20260825.md`。五级严格为
`L1=measure:edge167-mcp-oauth-port-fallback`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格没有
独立 Computer Use 五通道 session、浏览器逐帧时序、视觉成品或 discoverability 证据。formal journal=`3321`
（2300 baseline + 1021 live），`gen_coverage.py --check`=`848 rows / 664 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-167-ledger-alarm-reaudit-20260825.md`。
批次六十四当前=`35/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-168`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-166 OAuth refresh 失效

`EDGE-166` 补齐了 OAuth refresh 被吊销的真实失败分支：受控 token endpoint 返回 HTTP 401 +
`invalid_grant` 时，token source 明确返回 `ErrOAuthReauthRequired`，不带死 token 继续请求，也不
伪造成功；正常 refresh 轮换、无 refresh token 也保持原有契约。新增回归已用 `-race` 通过。

正式证据=`testend/rig/formal-evidence/EDGE-166-mcp-oauth-refresh-revoked-20260825.md`。五级严格为
`L1=measure:edge166-mcp-oauth-refresh-revoked`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格没有
独立 Computer Use 五通道 session、设置页逐帧时序、视觉成品或 discoverability 证据。formal journal=`3316`
（2300 baseline + 1016 live），`gen_coverage.py --check`=`848 rows / 663 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-166-ledger-alarm-reaudit-20260825.md`。
批次六十四当前=`30/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-167`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-165 MCP OAuth 全流程

`EDGE-165` 已用受控 authorization server 完成 OAuth 全链路：401 后 RFC 9728/8414 discovery、
DCR、PKCE S256/state、loopback callback、authorization-code exchange、refresh；同时覆盖 BYO
client 与无 DCR/无 client 的明确拒绝。infra 层补齐 path-aware well-known、跨 host PRM 防护、错误
体截断和 token rotation。没有把 fake server 冒充第三方 App/浏览器视觉验收。

正式证据=`testend/rig/formal-evidence/EDGE-165-mcp-oauth-full-flow-20260825.md`。五级严格为
`L1=measure:edge165-mcp-oauth-full-flow`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格没有独立
Computer Use 五通道 session、浏览器逐帧时序、视觉成品或 discoverability 证据。formal journal=`3311`
（2300 baseline + 1011 live），`gen_coverage.py --check`=`848 rows / 662 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-165-ledger-alarm-reaudit-20260825.md`。
批次六十四当前=`25/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-166`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-164 被取消的 subagent 落终态

`EDGE-164` 已验证取消链：父端取消正在运行的 subagent 后，父消息和子消息都在有限窗口内落
durable terminal，detached finalize 发出 `message_stop`，没有 pending/streaming 孤儿；父层得到
明确的 partial/non-authoritative 提示。真实场景故意让 mock provider stall 30 秒，测试替身收台的
`httptest.Server blocked in Close` warning 已原样保留并标明不是 sidecar 残留。

正式证据=`testend/rig/formal-evidence/EDGE-164-subagent-cancel-terminal-20260825.md`。五级严格为
`L1=measure:edge164-subagent-cancel-terminal`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格没有
独立 Computer Use 五通道 session、逐帧取消时序、视觉成品或 discoverability 证据。formal journal=`3306`
（2300 baseline + 1006 live），`gen_coverage.py --check`=`848 rows / 661 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-164-ledger-alarm-reaudit-20260825.md`。
批次六十四当前=`20/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-165`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-163 get_subagent_trace 隔离

`EDGE-163` 已验证 trace 读取权限边界：父对话可列出和读取自己的 subagent trace；subagent 工具
面同时剔除 `get_subagent_trace` 与 `Subagent`，不能读取父对话中其它子运行的隐藏 trace。真实
HTTP 父子隔离回归和 focused list/detail/错误输入契约均通过，子树仍按 `SubagentID` 正常落父树。

正式证据=`testend/rig/formal-evidence/EDGE-163-subagent-trace-isolation-20260825.md`。五级严格为
`L1=measure:edge163-subagent-trace-isolation`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格没有
独立 Computer Use 五通道 session、逐帧时序、视觉成品或 discoverability 证据。formal journal=`3301`
（2300 baseline + 1001 live），`gen_coverage.py --check`=`848 rows / 660 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-163-ledger-alarm-reaudit-20260825.md`。
批次六十四当前=`15/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-164`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-162 subagent 深度守卫

`EDGE-162` 已验证 subagent 深度固定为 1：Explore/Plan/general-purpose 的工具过滤都剔除
`Subagent` 与 `get_subagent_trace`，service 层对已有 subagent context 的递归 `Spawn` 也明确拒绝。
真实 HTTP 子树回归读取子请求工具列表，确认没有递归工具，并验证子结果仍回到父对话树。

正式证据=`testend/rig/formal-evidence/EDGE-162-subagent-depth-guard-20260825.md`。五级严格为
`L1=measure:edge162-subagent-depth-guard`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格没有独立
Computer Use 五通道 session、逐帧时序、视觉成品或 discoverability 证据。formal journal=`3296`
（2300 baseline + 996 live），`gen_coverage.py --check`=`848 rows / 659 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-162-ledger-alarm-reaudit-20260825.md`。
批次六十四当前=`10/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-163`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-161 subagent 墙钟

`EDGE-161` 已用 focused 与真实 HTTP 双路径确认：从没有父回合 deadline 的路径进入 `Spawn` 时，
subagent 自己建立 `ChatTurnSec` 墙钟；永不返回的 provider 在 1 秒预算后被切断，子 message
落为 `cancelled` 终态，截断原因回传父层。真实 HTTP 子树同时确认父工具调用、子消息 `SubagentID`、
子工具集剔除 `Subagent` 和结果回喂均接线正确。

正式证据=`testend/rig/formal-evidence/EDGE-161-subagent-wall-clock-20260825.md`。五级严格为
`L1=measure:edge161-subagent-wall-clock`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格没有独立
Computer Use 五通道 session、逐帧时序、视觉成品或 discoverability 证据，不越级把 runtime/HTTP
证据冒充产品层证据。formal journal=`3291`（2300 baseline + 991 live），
`gen_coverage.py --check`=`848 rows / 658 carried judgments / 0 tombstones`，`anchors=10/10`，
`alarms.py check` clean；警报复审=`testend/rig/formal-evidence/EDGE-161-ledger-alarm-reaudit-20260825.md`。
批次六十四当前=`5/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-162`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-160 agent 墙钟压过自报终态

`EDGE-160` 已用 focused 与真实 HTTP 双路径确认 agent invocation 的总墙钟是硬边界：focused
将 deadline 缩为 1 秒切断阻塞流，真实产品 HTTP 将 `agentInvokeSec` PATCH 为 2 秒后给 6 秒
stall；两者都返回非 OK `timeout`，耐久 execution 同样可查询为 timeout，后端随后优雅收台。

正式证据=`testend/rig/formal-evidence/EDGE-160-agent-wall-clock-terminal-20260825.md`。五级严格为
`L1=measure:edge160-agent-wall-clock-terminal`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格
没有独立 Computer Use 五通道 session、视觉成品或 discoverability 证据，不越级把 service/HTTP
timeout 证据冒充产品层证据。formal journal=`3286`（2300 baseline + 986 live），
`gen_coverage.py --check`=`848 rows / 657 carried judgments / 0 tombstones`，`anchors=10/10`，
`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按 focused/HTTP timeout 双路径
及 L2-L5 na 边界复核 ack）。批次六十三 `EDGE-151..EDGE-160` 已达到=`50/50`，统一长门禁
全绿，收口证据=`testend/rig/formal-evidence/batch-63-unified-gate-20260825.md`，代码/证据提交=`3e02e4ff`；
下一原子前线=`EDGE-161`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-159 sys: 能力工具无路由

`EDGE-159` 已验证能力工具的诚实缺席：当 workspace 没有任何图像生成路由时，resolver
拒绝 `sys:generate_image`，mount-health 报 unhealthy 并说明 `no usable route`；真实 HTTP
创建 agent 也返回 `422 AGENT_MOUNT_INVALID`，告诉配置 capable key 或启用免费档，避免 agent
先承诺、到 invoke 最后一跳才失败。

正式证据=`testend/rig/formal-evidence/EDGE-159-agent-sys-image-no-route-20260825.md`。五级严格为
`L1=measure:edge159-agent-sys-image-no-route`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格
没有独立 Computer Use 五通道 session、时序测量、视觉成品或 discoverability 证据，不越级把
resolver/HTTP agent 证据冒充产品层证据。formal journal=`3281`（2300 baseline + 981 live），
`gen_coverage.py --check`=`848 rows / 676 carried judgments / 0 tombstones`，`anchors=10/10`，
`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按 resolver/HTTP 双路径及 L2-L5
na 边界复核 ack）。批次六十三当前=`45/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线
已达到 `50/50`，进入统一长门禁。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-158 agent 非 OK 终态置空输出

`EDGE-158` 已验证声明 outputs 的失败终态不污染结构化结果：provider error 让执行明确非 OK，
`Output` 为 nil，partial narration 仍保留在 transcript；不会让裸文本冒充下游可消费的声明
对象。max-steps 与 tool-error-storm 的真实 loop 终止码由独立 loop 回归锁住，本格不把重复
覆盖冒充新产品证据。

正式证据=`testend/rig/formal-evidence/EDGE-158-agent-non-ok-output-null-20260825.md`。五级严格为
`L1=measure:edge158-agent-non-ok-output-null`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格
没有独立 Computer Use 五通道 session、时序测量、视觉成品或 discoverability 证据，不越级把
agent service/loop focused 证据冒充产品层证据。formal journal=`3276`（2300 baseline + 976 live），
`gen_coverage.py --check`=`848 rows / 671 carried judgments / 0 tombstones`，`anchors=10/10`，
`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按 non-OK output 边界及 L2-L5
na 边界复核 ack）。批次六十三当前=`40/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线
为 `EDGE-160`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-157 agent 声明输出回解析

`EDGE-157` 已验证 declared outputs 的完整终态边界：成功的裸 JSON 与 prose 前 fenced JSON
均回解析为声明字段；多字段自由 prose 大声失败，provider error/max-steps 等非 OK 终态的
`Output` 置空而不是留下裸文本；原始叙述仍在 transcript。真实 HTTP agent seat 同时证明
prompt 明确要求单一 JSON object，返回 `{"verdict":"pass"}` 能成功落结构化输出。

正式证据=`testend/rig/formal-evidence/EDGE-157-agent-declared-output-parse-20260825.md`。五级严格为
`L1=measure:edge157-agent-declared-output-parse`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格
没有独立 Computer Use 五通道 session、时序测量、视觉成品或 discoverability 证据，不越级把
agent parser/HTTP 证据冒充产品层证据。formal journal=`3271`（2300 baseline + 971 live），
`gen_coverage.py --check`=`848 rows / 666 carried judgments / 0 tombstones`，`anchors=10/10`，
`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按 parser/terminal/HTTP 三面
及 L2-L5 na 边界复核 ack）。批次六十三当前=`35/50`，未满 50 格不跑统一长门禁、不提交；
下一原子前线为 `EDGE-159`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-156 agent 离线 MCP 挂载归因

`EDGE-156` 已在真实 agent seat 走完 MCP 的 ready→offline→reconnect→invoke 链：server
离线后 `mount-health` 与 agent invoke 都给出 `not connected`，invoke 在 LLM 前 fail-fast，
不误报 `tool-not-found`；恢复 server 后挂载回绿，`mcp__recover__echo` 真调成功，MCP calls
台账明确标记为 agent 触发。

正式证据=`testend/rig/formal-evidence/EDGE-156-agent-offline-mcp-attribution-20260825.md`。五级严格为
`L1=measure:edge156-agent-offline-mcp-attribution`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格
没有独立 Computer Use 五通道 session、时序测量、视觉成品或 discoverability 证据，不越级把
agent/MCP HTTP 证据冒充产品层证据。formal journal=`3266`（2300 baseline + 966 live），
`gen_coverage.py --check`=`848 rows / 661 carried judgments / 0 tombstones`，`anchors=10/10`，
`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按 offline/reconnect/tool-call
双路径及 L2-L5 na 边界复核 ack）。批次六十三当前=`30/50`，未满 50 格不跑统一长门禁、不提交；
下一原子前线为 `EDGE-158`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-155 agent 挂载目标被删

`EDGE-155` 已验证挂载目标消失时的两种真实后果：function 被删除后，agent 再次 invoke
明确落为 failed 并保留 `not found` 原因；knowledge 被删除后，focused mount-health 仍保留
该挂载行并标 unhealthy，create/edit 对 dangling knowledge/tool 也大声拒绝，不把缺能力吞成
成功运行。

正式证据=`testend/rig/formal-evidence/EDGE-155-agent-deleted-mount-target-20260825.md`。五级严格为
`L1=measure:edge155-agent-deleted-mount-target`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格
没有独立 Computer Use 五通道 session、时序测量、视觉成品或 discoverability 证据，不越级把
agent HTTP/focused 证据冒充产品层证据。formal journal=`3261`（2300 baseline + 961 live），
`gen_coverage.py --check`=`848 rows / 656 carried judgments / 0 tombstones`，`anchors=10/10`，
`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按删除 function、knowledge
双路径及 L2-L5 na 边界复核 ack）。批次六十三当前=`25/50`，未满 50 格不跑统一长门禁、不提交；
下一原子前线为 `EDGE-157`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-154 agent 挂载撞名

`EDGE-154` 已在真实 agent invoke 与 mount-health 双路径收口：function `greeter__hello` 和
handler `greeter.hello` 合成同一工具名时，创建或执行路径均大声报告 collision，绝不静默
last-write-wins；mount-health 逐挂载收集，第一挂载保持健康，第二挂载 unhealthy 且带
`collides`，删除 knowledge 的 unhealthy 也不污染其它健康挂载。

正式证据=`testend/rig/formal-evidence/EDGE-154-agent-mount-name-collision-20260825.md`。五级严格为
`L1=measure:edge154-agent-mount-name-collision`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格
没有独立 Computer Use 五通道 session、时序测量、视觉成品或 discoverability 证据，不越级把
agent HTTP/mount-health 证据冒充产品层证据。formal journal=`3256`（2300 baseline + 956 live），
`gen_coverage.py --check`=`848 rows / 651 carried judgments / 0 tombstones`，`anchors=10/10`，
`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按 invoke/mount-health 双路径
及 L2-L5 na 边界复核 ack）。批次六十三当前=`20/50`，未满 50 格不跑统一长门禁、不提交；
下一原子前线为 `EDGE-156`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-153 env 在用时删除

`EDGE-153` 已用 service `-race` 与真实 HTTP 双路径验证占用 env 的删除闸：真实 env 被标成
resident 后，产品 DELETE 返回 `409 SANDBOX_ENV_IN_USE`，env、running PID 和 owner lock
均保留；释放 PID 后同一 DELETE 才返回 `204`，两 workspace 的读侧随后均为 404，重复 DELETE
也明确返回 404。批量 reset-all 另验证遇到 running sibling 时不会先删 idle sibling。

正式证据=`testend/rig/formal-evidence/EDGE-153-sandbox-env-delete-in-use-20260825.md`。五级严格为
`L1=measure:edge153-sandbox-env-delete-in-use`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格
没有独立 Computer Use 五通道 session、时序测量、视觉成品或 discoverability 证据，不越级把
sandbox service/HTTP 证据冒充产品层证据。formal journal=`3251`（2300 baseline + 951 live），
`gen_coverage.py --check`=`848 rows / 650 carried judgments / 0 tombstones`，`anchors=10/10`，
`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按 resident 拒删/恢复双路径
及 L2-L5 na 边界复核 ack）。批次六十三当前=`15/50`，未满 50 格不跑统一长门禁、不提交；
下一原子前线为 `EDGE-155`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-152 uvx/npx 孙进程整组杀

`EDGE-152` 已把清册配方走成真实产品链：全新 sandbox 通过 `npx` 启动官方 filesystem MCP，
真实发现工具并读取临时文件，随后从产品 HTTP DELETE 删除 server，GET 与工具调用均诚实返回
`MCP_SERVER_NOT_FOUND`。sandbox 的 `-race` 回归另起独立进程组并派生同组孙进程，boot reaper
后孙进程消失且 `running_pid` 清零，证明不是只杀 wrapper 组长。

正式证据=`testend/rig/formal-evidence/EDGE-152-sandbox-uvx-npx-process-group-reap-20260825.md`。五级严格为
`L1=measure:edge152-sandbox-uvx-npx-process-group-reap`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；
本格没有独立 Computer Use 五通道 session、时序测量、视觉成品或 discoverability 证据，不越级
把 MCP/进程组证据冒充产品层证据。formal journal=`3246`（2300 baseline + 946 live），
`gen_coverage.py --check`=`848 rows / 649 carried judgments / 0 tombstones`，`anchors=10/10`，
`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按真实 npx 产品路径、进程组
证据及 L2-L5 na 边界复核 ack）。批次六十三当前=`10/50`，未满 50 格不跑统一长门禁、不提交；
下一原子前线为 `EDGE-154`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-151 boot 回收 run_in_background 孤儿

`EDGE-151` 已用真实 `run_in_background` 进程组回归收口：异常退出留下的 pid 清单会在下一次
boot 被 `ReapStaleOnBoot` 读取，并按负 pgid 收割整组；zombie leader 仍能收割，PID 被无辜
进程复用时则经过进程组归属校验而不误杀。bootstrap 应用装配层回归同时通过，旧 `.pid`
记录被清理。

正式证据=`testend/rig/formal-evidence/EDGE-151-shell-boot-reap-background-orphans-20260825.md`。五级严格为
`L1=measure:edge151-shell-boot-reap-background-orphans`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；
本格没有独立 Computer Use 五通道 session、时序测量、视觉成品或 discoverability 证据，不越级
把进程/清单/进程组证据冒充产品层证据。formal journal=`3241`（2300 baseline + 941 live），
`gen_coverage.py --check`=`848 rows / 648 carried judgments / 0 tombstones`，`anchors=10/10`，
`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按真实进程组证据及 L2-L5
na 边界复核 ack）。批次六十三当前=`5/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线
为 `EDGE-153`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：批次六十二已提交

批次六十二（`EDGE-141..EDGE-150`）已完成 50/50，统一长门禁全绿并提交为
`ed269a1e test(rig): close batch 62 sandbox and handler edges`。正式门禁证据为
`testend/rig/formal-evidence/batch-62-unified-gate-20260825.md`；working 文档随后以本次
docs 收口提交同步。批次六十三已从 `0/50` 开始并收口 `EDGE-151`，下一原子前线为 `EDGE-152`；P12 的 400+ Journey
继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-150 boot 回收残留 running_pid

`EDGE-150` 已用真实进程回归收口：boot manifest 记录的 `sleep` survivor 被整组收割，`Wait`
立即返回非正常退出，且 `running_pid` 清零；另一条回归模拟 `uvx/npx` wrapper，在同一进程组
派生孙进程，确认 boot reaper 连孙进程也杀掉，不留下隐形后台服务。

正式证据=`testend/rig/formal-evidence/EDGE-150-sandbox-boot-reclaim-running-pid-20260825.md`。五级严格为
`L1=measure:edge150-sandbox-boot-reclaim-running-pid`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；
本格没有独立 Computer Use 五通道 session、时序测量、视觉成品或 discoverability 证据，不越级把
进程/manifest/process-group 证据冒充产品层证据。formal journal=`3236`（2300 baseline + 936 live），
`gen_coverage.py --check`=`848 rows / 647 carried judgments / 0 tombstones`，`anchors=10/10`，
`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按单 PID/整组收割及 na 边界复核 ack）。
批次六十二已达到=`50/50`。统一门禁证据=`testend/rig/formal-evidence/batch-62-unified-gate-20260825.md`：
根验证、完整 testend、rig 51 项自测、backend verify、coverage/anchors/alarms、语法、diff 与残留
进程审计全绿；现在只剩本批提交。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-149 sandbox bootstrap 失败 degraded

`EDGE-149` 已把 sandbox 根路径真实替换成普通文件，验证 `Bootstrap` 失败时进入 degraded、
`IsReady=false` 且保留可解释错误；移除文件障碍后 `RetryBootstrap` 恢复 ready、重建目录并清空
错误。真实 HTTP governance 场景同时锁住 `:retry-bootstrap` 的 200 + `{ok}` 产品契约；故障
注入留在 service 层，避免 harness 启动器先替测试恢复故障。

正式证据=`testend/rig/formal-evidence/EDGE-149-sandbox-bootstrap-degraded-retry-20260825.md`。五级严格为
`L1=measure:edge149-sandbox-bootstrap-degraded-retry`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；
本格没有独立 Computer Use 五通道 session、时序测量、视觉成品或 discoverability 证据，不越级把
filesystem/HTTP/retry 证据冒充产品层证据。formal journal=`3231`（2300 baseline + 931 live），
`gen_coverage.py --check`=`848 rows / 646 carried judgments / 0 tombstones`，`anchors=10/10`，
`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按失败/恢复双路径及 na 边界复核 ack）。
批次六十二当前=`45/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-150`。P12 的
400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-148 沙箱运行时首用直装

`EDGE-148` 已在全新 `t.TempDir()` sandbox 中真实走上游直装链：UV、Node、Python 均从零下载
钉死资产，完成发布 checksum 校验、staging 解压/原子换、二进制定位和真实 `--version` 执行；
每个 runtime 再次 Install 也正确幂等短路，没有命中开发机已有 runtime。一次使用自然语言而非
COVERAGE 精确键的写账命令被 sequence gate 拒绝，未污染任何错误行，改用正式键后才登记。

正式证据=`testend/rig/formal-evidence/EDGE-148-sandbox-first-use-direct-install-20260825.md`。五级严格为
`L1=measure:edge148-sandbox-first-use-direct-install`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格
没有独立 Computer Use 五通道 session、时序测量、视觉成品或 discoverability 证据，不越级把
真实上游 sandbox e2e 冒充产品层证据。formal journal=`3226`（2300 baseline + 926 live），
`gen_coverage.py --check`=`848 rows / 645 carried judgments / 0 tombstones`，`anchors=10/10`，
`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按 fresh-runtime 证据及 na 边界复核 ack）。
批次六十二当前=`40/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-149`。P12 的
400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-147 handler 同实例并发调用串扰

`EDGE-147` 已用 focused fan `-race` 与真实 HTTP 并发场景收口：两个带不同 tag 的调用共享同一
resident `instanceId`，RPC method 按 stdio mutex 串行，但上层 stderr sink 窗口按设计可以重叠。
两条 call detail 都保留自己的 `start/end` 行，窗口重叠产生的额外行不被伪装成严格隔离；真实
日志确认迟到尾行在 30ms grace 内保留。窗口外丢弃、detach 幂等与并发 fan-out 也由 focused
回归锁住。

正式证据=`testend/rig/formal-evidence/EDGE-147-handler-concurrent-stderr-windows-20260825.md`。五级严格为
`L1=measure:edge147-handler-concurrent-stderr-windows`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；
本格没有独立 Computer Use 五通道 session、时序测量、视觉成品或 discoverability 证据，不越级把
fan/HTTP/call-log 证据冒充产品层证据。formal journal=`3221`（2300 baseline + 921 live），
`gen_coverage.py --check`=`848 rows / 644 carried judgments / 0 tombstones`，`anchors=10/10`，
`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按窗口重叠语义及 na 边界复核 ack）。
批次六十二当前=`35/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-148`。P12 的
400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-146 handler 产物目录 chdir 恢复

`EDGE-146` 已用真实生成的 Python `DriverScript` 做驻留进程回归：第一次带 `out` 的调用抛出
异常后，测试实际删除该次产物目录；同一进程随后在新的 `out-second` 目录成功执行下一次调用，
最后无 `out` 调用回到 driver 启动目录且 `ANSELM_OUT` 为空。真实 HTTP 产物场景同时证明两次
`:call` 各自产生并读取独立附件 receipt。异常、删除目录、后续调用和环境清理均有断言，锁住
`finally` 恢复 cwd 的产品安全合同。

正式证据=`testend/rig/formal-evidence/EDGE-146-handler-chdir-restore-20260825.md`。五级严格为
`L1=measure:edge146-handler-chdir-restore`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格没有
独立 Computer Use 五通道 session、时序测量、视觉成品或 discoverability 证据，不越级把
driver/HTTP/附件证据冒充产品层证据。formal journal=`3216`（2300 baseline + 916 live），
`gen_coverage.py --check`=`848 rows / 643 carried judgments / 0 tombstones`，`anchors=10/10`，
`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按异常后续调用覆盖及 na 边界复核 ack）。
批次六十二当前=`30/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-147`。P12 的
400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-145 handler 纯 meta edit 不重启

`EDGE-145` 已用 focused service 和真实 `HandlerResidentSemantics` 黑盒收口：PATCH 改名与全
`set_meta` edit 改描述都只更新 Handler 行，不增加 spawn、不铸新 version；真实计数器从 2
继续到 3、4，证明 resident 内存态未被无关 meta 修改抹掉，GET 仍只有一个版本且名称/描述已落盘。

正式证据=`testend/rig/formal-evidence/EDGE-145-handler-meta-edit-no-restart-20260825.md`。五级严格为
`L1=measure:edge145-handler-meta-edit-no-restart`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格没有
独立 Computer Use 五通道 session、时序测量、视觉成品或 discoverability 证据，不越级把
HTTP/version/resident 证据冒充产品层证据。formal journal=`3211`（2300 baseline + 911 live），
`gen_coverage.py --check`=`848 rows / 642 carried judgments / 0 tombstones`，`anchors=10/10`，
`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按两类 meta 路径及 na 边界复核 ack）。
批次六十二当前=`25/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-146`。P12 的
400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-144 handler 空 ops edit 抹内存态

`EDGE-144` 已用 focused service 与真实 HTTP/notification/resident 证据收口：空 ops edit 返回
原 active v1、不铸新版本，重建环境并重启 resident，成功发出 `handler.env_rebuilt`；真实计数器
下一次调用从 1 重新开始，证明内存态已抹除。失败环境的 focused 回归同时证明只 provision 一次、
停止旧 resident 且不发假成功通知。

正式证据=`testend/rig/formal-evidence/EDGE-144-handler-empty-ops-rebuild-20260825.md`。五级严格为
`L1=measure:edge144-handler-empty-ops-rebuild`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格没有
独立 Computer Use 五通道 session、时序测量、视觉成品或 discoverability 证据，不越级把
HTTP/通知/版本/resident 证据冒充产品层证据。formal journal=`3206`（2300 baseline + 906 live），
`gen_coverage.py --check`=`848 rows / 641 carried judgments / 0 tombstones`，`anchors=10/10`，
`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按成功/失败双路径及 na 边界复核 ack）。
批次六十二当前=`20/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-145`。P12 的
400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-143 handler 注入 secret 掩码三面

`EDGE-143` 首轮真实 HTTP 观察抓到真实缺陷：method 同时 `print(self.token)` 和将 token 放进
traceback 时，backend journal 的 `handler.stderr` 仍记录明文 secret。验收停下修复：
`captureStderr` 现在接收 spawn 时解析出的 `secretVals`，在写 zap journal 和 stderr fan 两个
入口前统一掩码。修复后二次 focused observer 与真实 HTTP 均通过：即时错误、调用审计
`errorMessage`、detail `logs` 和 backend `handler.stderr` 均无明文且保留 `********`；列表接口
刻意省略 logs，未被错误当成缺失证据。

正式证据=`testend/rig/formal-evidence/EDGE-143-handler-secret-masked-three-surfaces-20260825.md`。
五级严格为 `L1=measure:edge143-handler-secret-masked-three-surfaces`、`L2=na`、`L3=na`、
`L4=na`、`L5=na`；本格没有独立 Computer Use 五通道 session、时序测量、视觉成品或
discoverability 证据，不越级把安全/HTTP/日志证据冒充产品层证据。formal journal=`3201`
（2300 baseline + 901 live），`gen_coverage.py --check`=`848 rows / 640 carried judgments / 0 tombstones`，
`anchors=10/10`，`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按首轮真实
缺陷、修复后重跑及 na 边界复核 ack）。批次六十二当前=`15/50`，未到 50 格不跑统一长门禁、不提交；
下一原子前线=`EDGE-144`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-142 handler traceback 不被剥

`EDGE-142` 已用 focused 错误面回归和真实 HTTP 黑盒收口：`errorspkg.Surface` 保留
`HANDLER_CLIENT_CALL_FAILED`/`INIT_FAILED` 分类的同时，继续浮出 Python cause 与 traceback；真实
Handler 方法抛出 `ValueError('bad amount')` 后，即时 HTTP 502 响应、`/calls` 列表和
`/handler-calls/{id}` 详情均保留 `ValueError: bad amount` 与 `Traceback`，没有退化成不透明的
`call failed`。

正式证据=`testend/rig/formal-evidence/EDGE-142-handler-traceback-surfaces-20260825.md`。五级严格为
`L1=measure:edge142-handler-traceback-surfaces`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格没有
独立 Computer Use 五通道 session、时序测量、视觉成品或 discoverability 证据，不越级把
错误面/HTTP/审计证据冒充产品层证据。formal journal=`3196`（2300 baseline + 896 live），
`gen_coverage.py --check`=`848 rows / 639 carried judgments / 0 tombstones`，`anchors=10/10`，
`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按四个反向失败面及 na 边界复核 ack）。
批次六十二当前=`10/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-143`。P12 的
400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-141 handler generator 终值两写法

`EDGE-141` 已用三层真实证据收口：新增 focused `-race` 回归把 `AssembleClass` 与生产
`DriverScript` 写入临时目录并启动真实 `python3`，经 stdio 行 JSON 协议验证 `yield` 终值和
`return` 产生的 `StopIteration.value` 都成为最终 `return`；既有包内生成测试与真实 HTTP
`TestContractEntities_HandlerResidentSemantics` 再次通过，真实创建 Handler 后分别调用
`yield_final`/`return_final` 均为 200 且返回正确值。

正式证据=`testend/rig/formal-evidence/EDGE-141-handler-generator-finals-20260825.md`。五级严格为
`L1=measure:edge141-handler-generator-finals`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格没有
独立 Computer Use 五通道 session、时序测量、视觉成品或 discoverability 证据，不越级把
backend/driver 证据冒充产品层证据。formal journal=`3191`（2300 baseline + 891 live），
`gen_coverage.py --check`=`848 rows / 638 carried judgments / 0 tombstones`，`anchors=10/10`，
`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按五格共享证据包及 na 边界复核 ack）。
批次六十二当前=`5/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线=`EDGE-142`。P12 的
400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-140 handler ctx 取消 = 管道脏

handler RPC cancellation 已通过真实 stdio pipe 与 app manager `-race`：取消正在等待的 `Init` 后 client 标记 crashed，后续 Init 立即拒绝 `ErrCrashed`；app 下一次 Call 回收旧 resident 并重新 spawn，证明不复用状态未知的脏管道。当前 testend 没有可控的真实 HTTP handler 断连台架，未伪造该证据。

正式证据=`testend/rig/formal-evidence/EDGE-140-handler-cancel-dirties-pipe-20260825.md`。五级严格为
`L1=measure:edge140-handler-cancel-dirties-pipe`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；stdio/app 证据不替代独立 Computer Use、测量、视觉和 discoverability 证据。
formal journal=`3186`（2300 baseline + 886 live），`gen_coverage.py --check`=`848 rows / 637 carried judgments / 0 tombstones`，`anchors=10/10`，`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按本格证据边界复核 ack）。
批次六十一已达到=`50/50`；统一门禁证据=`testend/rig/formal-evidence/batch-61-unified-gate-20260825.md`，根验证、完整 testend、rig 自测、backend verify、覆盖/锚点/警报、格式和残留进程审计全绿；代码、测试、证据和 COVERAGE 已提交=`91fcbacb`。下一原子前线=`EDGE-141`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-139 handler config 不完整

handler 必填配置门已通过 focused `-race` 与真实 HTTP：未配必填 init arg 时 runner spawn 为 0，返回 `HANDLER_CONFIG_INCOMPLETE`，仍写入一条 failed call 审计；真实 Merge Patch 删除 `b` 后 `missingConfig=[b]`，补回配置才恢复调用，收台无 sandbox 残留。

正式证据=`testend/rig/formal-evidence/EDGE-139-handler-config-incomplete-20260825.md`。五级严格为
`L1=measure:edge139-handler-config-incomplete`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；配置/HTTP/spawn/审计证据不替代独立 Computer Use、测量、视觉和 discoverability 证据。
formal journal=`3181`（2300 baseline + 881 live），`gen_coverage.py --check`=`848 rows / 636 carried judgments / 0 tombstones`，`anchors=10/10`，`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按本格证据边界复核 ack）。
批次六十一当前=`45/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-140`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-138 handler 孤儿 config key

handler active schema 过滤已通过 focused `-race` 与真实 HTTP：focused 证明只把当前 schema 声明的参数传入结果且不改写持久 config；真实路径配置 v1 的 token、edit 删除 schema 后 v2 正常 spawn、revert v1 后原 token 恢复，未出现 `__init__` TypeError，收台无 sandbox 残留。

正式证据=`testend/rig/formal-evidence/EDGE-138-handler-orphan-config-filter-20260825.md`。五级严格为
`L1=measure:edge138-handler-orphan-config-filter`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；schema/HTTP/spawn 证据不替代独立 Computer Use、测量、视觉和 discoverability 证据。
formal journal=`3176`（2300 baseline + 876 live），`gen_coverage.py --check`=`848 rows / 635 carried judgments / 0 tombstones`，`anchors=10/10`，`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按本格证据边界复核 ack）。
批次六十一当前=`40/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-139`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-137 handler spawn 单飞

handler 冷启动并发已通过 manager `-race` 与真实 HTTP：5 个并发调用在第一次 spawn 人为阻塞期间只启动一次，释放后全部取得同一 resident；真实调用台账 5 行的 `instanceId` 去重后为 1，未重复付 env/process/`__init__`。

正式证据=`testend/rig/formal-evidence/EDGE-137-handler-spawn-singleflight-20260825.md`。五级严格为
`L1=measure:edge137-handler-spawn-singleflight`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；并发/HTTP/台账证据不替代独立 Computer Use、测量、视觉和 discoverability 证据。
formal journal=`3171`（2300 baseline + 871 live），`gen_coverage.py --check`=`848 rows / 634 carried judgments / 0 tombstones`，`anchors=10/10`，`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按本格证据边界复核 ack）。
批次六十一当前=`35/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-138`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-136 无 uploader 时的产物声明

未接 uploader 的 test/REST-only 装配已通过 focused `-race`：`$media` 声明原样透传、notes 为空，传入的 output 目录在调用前不存在且调用后仍不存在；没有隐式建目录、附件或失败副作用。该格刻意没有可伪造的真实 product HTTP uploader 证据。

正式证据=`testend/rig/formal-evidence/EDGE-136-function-artifact-no-uploader-20260825.md`。五级严格为
`L1=measure:edge136-function-artifact-no-uploader`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；未接线装配证据不替代独立 Computer Use、测量、视觉和 discoverability 证据。
formal journal=`3166`（2300 baseline + 866 live），`gen_coverage.py --check`=`848 rows / 633 carried judgments / 0 tombstones`，`anchors=10/10`，`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按本格证据边界复核 ack）。
批次六十一当前=`30/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-137`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-135 产物四道闸逐件失败

function 媒体产物逐件失败已通过 focused `-race` 与真实 HTTP：同一次运行中的正常 PNG 成功落附件；40 MiB 超限文件与 shell 伪装 PNG 各自被拒绝，声明原样保留，logs 各有解释，普通结果字段保持成功，收台无 sandbox 残留。

正式证据=`testend/rig/formal-evidence/EDGE-135-function-artifact-per-item-failures-20260825.md`。五级严格为
`L1=measure:edge135-function-artifact-per-item-failures`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；逐件安全/HTTP 证据不替代独立 Computer Use、测量、视觉和 discoverability 证据。
formal journal=`3161`（2300 baseline + 861 live），`gen_coverage.py --check`=`848 rows / 632 carried judgments / 0 tombstones`，`anchors=10/10`，`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按本格证据边界复核 ack）。
批次六十一当前=`25/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-136`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-134 产物路径逃逸

function 媒体产物越界声明已通过 focused `-race` 与真实 HTTP：`../outside.png` 在 containment 检查处 fail-closed，focused 路径使用真实可读的目录外 PNG 并证明 uploader 零调用；真实 function 运行成功但保留原 `$media` 声明、没有 `attachmentId`，logs 明确说明拒绝原因，收台无 sandbox 残留。

正式证据=`testend/rig/formal-evidence/EDGE-134-function-artifact-path-escape-20260825.md`。五级严格为
`L1=measure:edge134-function-artifact-path-escape`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；安全/HTTP 证据不替代独立 Computer Use、测量、视觉和 discoverability 证据。
formal journal=`3156`（2300 baseline + 856 live），`gen_coverage.py --check`=`848 rows / 631 carried judgments / 0 tombstones`，`anchors=10/10`，`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按本格证据边界复核 ack）。
批次六十一当前=`20/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-135`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-133 function 媒体产物声明

function 媒体声明已通过 focused `-race` 与真实 HTTP：函数在每次 sandbox run 中写入 `ANSELM_OUT/chart.png` 并返回 `$media`，结果的 `chart` 原键就地变为可下载 MediaRef receipt，`source=function_artifact`，同级普通字段保留，两个不同运行得到不同附件 ID 且下载字节逐字匹配。

正式证据=`testend/rig/formal-evidence/EDGE-133-function-media-artifact-20260825.md`。五级严格为
`L1=measure:edge133-function-media-artifact`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；真实 sandbox/附件证据不替代独立 Computer Use、测量、视觉和 discoverability 证据。
formal journal=`3151`（2300 baseline + 851 live），`gen_coverage.py --check`=`848 rows / 630 carried judgments / 0 tombstones`，`anchors=10/10`，`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按本格证据边界复核 ack）。
批次六十一当前=`15/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-134`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-132 function 超时清洗

function wall-clock timeout 已通过 focused `-race` 与真实 HTTP：把 `functionRunSec` 设为 1，运行无限循环 function，实际返回 `504 FUNCTION_RUN_TIMEOUT`；执行历史唯一行是 `timeout`，错误明确写 wall-clock 限制且不泄漏 sandbox spawn 误导，收台时 sandbox handles 为 0。

正式证据=`testend/rig/formal-evidence/EDGE-132-function-timeout-cleanup-20260825.md`。五级严格为
`L1=measure:edge132-function-timeout-cleanup`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；真实 HTTP/durable/收台证据不替代独立 Computer Use、测量、视觉和 discoverability 证据。
formal journal=`3146`（2300 baseline + 846 live），`gen_coverage.py --check`=`848 rows / 629 carried judgments / 0 tombstones`，`anchors=10/10`，`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按本格证据边界复核 ack）。
批次六十一当前=`10/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-133`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-131 revert 到很老版本后再 trim

版本指针与 cap 的边界已通过两层证据：focused store regression 直接把 active pointer 设为最老 v1 后 trim，证明 v1 保留、v2 被裁且只回收 v2 env；真实 HTTP 路径建 v1→v50、revert v1、再 edit v51，证明新 edit 按产品契约成为 active，版本集合收敛到 cap=50，不误删新的 active v51。

正式证据=`testend/rig/formal-evidence/EDGE-131-revert-old-version-trim-20260825.md`。五级严格为
`L1=measure:edge131-revert-old-version-trim`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；版本/HTTP/store 证据不替代独立 Computer Use、测量、视觉和 discoverability 证据。
formal journal=`3141`（2300 baseline + 841 live），`gen_coverage.py --check`=`848 rows / 628 carried judgments / 0 tombstones`，`anchors=10/10`，`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按本格证据边界复核 ack）。
批次六十一当前=`5/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-132`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 批次六十收口重述：EDGE-130 已提交

#### 2026-08-25 当前前线重述：EDGE-130 版本 cap 50 trim 回收 venv

版本 cap 与 sandbox 回收已通过 focused `-race` 和真实 51 次 edit 场景：最老非 active 版本被 trim，关联 venv 经 `DestroyEnv` 回收，active version 保留；真实 `/versions` 与 `/sandbox/envs` 对账成立，收台无 sandbox 残留句柄。

正式证据=`testend/rig/formal-evidence/EDGE-130-version-cap-trim-reclaims-env-20260825.md`。五级严格为
`L1=measure:edge130-version-cap-trim-reclaims-env`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；真实 HTTP/数据库/sandbox 对账不替代独立 Computer Use、测量、视觉和 discoverability 证据。
formal journal=`3136`（2300 baseline + 836 live），`gen_coverage.py --check`=`848 rows / 627 carried judgments / 0 tombstones`，`anchors=10/10`，`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按本格证据边界复核 ack）。
批次六十已达到=`50/50`；统一门禁证据=`testend/rig/formal-evidence/batch-60-unified-gate-20260825.md`，根验证、完整 testend、rig 自测、backend verify、覆盖/锚点/警报、格式和残留进程审计全绿，已提交=`759c17c8`。批次六十一已从 `0/50` 开始，当前下一原子前线为 `EDGE-132`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-129 env 被 GC 后重试一次

真实 function 生命周期已通过：sandbox GC 回收当前版本环境后，下一次 `:run` 触发 `ErrEnvNotFound` 分支，系统重建同一 active version 的 env 并透明重试一次，最终仍返回 `200` 成功；没有要求用户手动编辑，也没有铸造新版本。

正式证据=`testend/rig/formal-evidence/EDGE-129-env-gc-retry-once-20260825.md`。五级严格为
`L1=measure:edge129-env-gc-retry-once`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；真实 HTTP/sandbox GC/成功回执不替代独立 Computer Use、测量、视觉和 discoverability 证据。
formal journal=`3131`（2300 baseline + 831 live），`gen_coverage.py --check`=`848 rows / 626 carried judgments / 0 tombstones`，`anchors=10/10`，`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按本格证据边界复核 ack）。
批次六十当前=`45/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-130`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-128 空 ops edit 重建 env

空 ops edit 的成功与失败边界已通过应用回归和真实 function HTTP 生命周期：失败环境重建失败时 active version 仍为 `failed`，不发 `function.env_rebuilt` 假成功通知；正常环境空 ops 返回原来的 `version=1`，发一条重建通知，版本列表仍只有一行。该操作重建 active env，不铸造新版本。

正式证据=`testend/rig/formal-evidence/EDGE-128-empty-ops-rebuild-env-20260825.md`。五级严格为
`L1=measure:edge128-empty-ops-rebuild-env`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；应用/HTTP/通知/版本真相不替代独立 Computer Use、测量、视觉和 discoverability 证据。
formal journal=`3126`（2300 baseline + 826 live），`gen_coverage.py --check`=`848 rows / 625 carried judgments / 0 tombstones`，`anchors=10/10`，`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按本格证据边界复核 ack）。
批次六十当前=`40/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-129`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-127 env failed 仍创建成功

真实 function HTTP 生命周期已通过：用不存在依赖创建 function 仍返回 `201`，实体 active version 可读且明确为 `envStatus=failed`、`envError` 非空；随后运行才返回 `422 FUNCTION_ENV_NOT_READY`。创建、失败状态可见和运行时门控被清楚分开，没有把实体创建失败或运行时缺包混成不透明错误。

正式证据=`testend/rig/formal-evidence/EDGE-127-env-failed-create-visible-20260825.md`。五级严格为
`L1=measure:edge127-env-failed-create-visible`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；真实 HTTP/状态/错误证据不替代独立 Computer Use、测量、视觉和 discoverability 证据。
formal journal=`3121`（2300 baseline + 821 live），`gen_coverage.py --check`=`848 rows / 624 carried judgments / 0 tombstones`，`anchors=10/10`，`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按本格证据边界复核 ack）。
批次六十当前=`35/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-128`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-126 未配 utility 模型时的 envfix

未配置 utility model 的 envfix 降级已通过 focused `-race` 与真实 function HTTP 生命周期：sandbox 首次安装失败后只尝试一次，`OK=false`，失败 stderr/原因保留在 History；真实 function 仍可创建为 `envStatus=failed`，运行时明确返回 `FUNCTION_ENV_NOT_READY`，不伪造可运行环境，也不把缺失模型变成裸 Go error。

正式证据=`testend/rig/formal-evidence/EDGE-126-envfix-no-utility-20260825.md`。五级严格为
`L1=measure:edge126-envfix-no-utility`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；真实 HTTP/状态/错误证据不替代独立 Computer Use、测量、视觉和 discoverability 证据。
formal journal=`3116`（2300 baseline + 816 live），`gen_coverage.py --check`=`848 rows / 623 carried judgments / 0 tombstones`，`anchors=10/10`，`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按本格证据边界复核 ack）。
批次六十当前=`30/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-127`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-125 envfix 拒绝丢包修复

envfix 的防假就绪护栏已通过 focused `-race` 回归：首次安装失败后，mock utility LLM 返回比用户原始声明更短的空依赖列表；系统拒绝该建议，不发生第二次安装，结果保持 `OK=false`，`FinalDeps` 保留用户声明，真实安装错误仍可达。生产实现比较原始 `req.Deps` 长度，避免把失败推迟成运行时缺包错误。

正式证据=`testend/rig/formal-evidence/EDGE-125-envfix-reject-dep-drop-20260825.md`。五级严格为
`L1=measure:edge125-envfix-reject-dep-drop`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；当前没有可控真实 utility model 丢包建议的产品会话，也没有独立 Computer Use、测量、视觉和 discoverability 证据，不越级使用 focused 回归。
formal journal=`3111`（2300 baseline + 811 live），`gen_coverage.py --check`=`848 rows / 622 carried judgments / 0 tombstones`，`anchors=10/10`，`alarms.py check` clean（`gap-too-fast` 与 `discovery-collapse` 已按本格证据边界复核 ack）。
批次六十当前=`25/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-126`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-124 envfix 自愈循环

envfix 失败→修复→重试状态机已通过 focused `-race` 回归：首次安装失败后 utility 修正依赖，第二次用完整修正依赖成功，历史为 `[fail, ok]`；真实 function 生命周期也证明坏依赖创建可见、运行时返回 `FUNCTION_ENV_NOT_READY`。当前 testend 未配置 utility model，repair-unavailable 会诚实停止，未伪造绿 env。

正式证据=`testend/rig/formal-evidence/EDGE-124-envfix-repair-loop-20260825.md`。五级严格为
`L1=measure:edge124-envfix-repair-loop`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；没有 utility repair 的真实 Computer Use、测量、视觉和 discoverability 证据，不越级使用 focused 回归。
formal journal=`3106`（2300 baseline + 806 live），`gen_coverage.py --check`=`848 rows / 621 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean（机械警报已按复核记录 ack）。
批次六十当前=`20/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-125`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-123 暂停时 `nextFireAt` 缺席

暂停 cron 的投影已通过应用与真实 HTTP 双重验证：`paused=true`、`listening=false`，JSON 完全省略 `nextFireAt`；硬重启跨 cron 边界仍保持该诚实投影且无 run，恢复后下一次真实 cron run 成功。

正式证据=`testend/rig/formal-evidence/EDGE-123-paused-next-fire-absent-20260825.md`。五级严格为
`L1=measure:edge123-paused-next-fire-absent`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；HTTP 投影证据不替代独立 Computer Use、测量、视觉和 discoverability 证据。
formal journal=`3101`（2300 baseline + 801 live），`gen_coverage.py --check`=`848 rows / 620 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean（机械警报已按复核记录 ack）。
批次六十当前=`15/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-124`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-122 fsnotify 秒桶去重

新增并通过 fsnotify 秒桶不变量回归：同一 UTC 秒内同 path+operation 共享 dedup key，下一秒或不同 path/operation 生成新 key；真实 fsnotify HTTP 场景同时证明过滤后的 create 才产生唯一 activation/firing/run，modify 与不匹配事件不新增 run。

正式证据=`testend/rig/formal-evidence/EDGE-122-fsnotify-second-dedup-20260825.md`。五级严格为
`L1=measure:edge122-fsnotify-second-dedup`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；应用与 HTTP 证据不替代独立 Computer Use、测量、视觉和 discoverability 证据。
formal journal=`3096`（2300 baseline + 796 live），`gen_coverage.py --check`=`848 rows / 619 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean（机械警报已按复核记录 ack）。
批次六十当前=`10/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-123`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-121 webhook 分钟桶去重

真实 webhook 重试语义已通过：同一分钟相同 raw body 的两次 HTTP 请求均接受但折叠为一条 firing/run；不同 body 产生第二条独立 firing/run，未被错误去重。

正式证据=`testend/rig/formal-evidence/EDGE-121-webhook-minute-dedup-20260825.md`。五级严格为
`L1=measure:edge121-webhook-minute-dedup`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；真实 HTTP 只证明去重语义，不替代独立 Computer Use、测量、视觉和 discoverability 证据。
formal journal=`3091`（2300 baseline + 791 live），`gen_coverage.py --check`=`848 rows / 618 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean（机械警报已按复核记录 ack）。
批次六十当前=`5/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-122`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-120 webhook HMAC 不匹配

webhook 鉴权拒绝语义已通过真实 contract：HMAC 正签名返回 `202`，错误签名/错误 header 返回 `401` 纯文本，不进入 workflow；明文 secret 的缺失/错误同样 `401`。实现使用 `http.Error`，不误套 N1 JSON envelope。

正式证据=`testend/rig/formal-evidence/EDGE-120-webhook-hmac-mismatch-20260825.md`。五级严格为
`L1=measure:edge120-webhook-hmac-mismatch`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；真实 HTTP 只证明鉴权语义，不替代独立 Computer Use、测量、视觉和 discoverability 证据。
formal journal=`3086`（2300 baseline + 786 live），`gen_coverage.py --check`=`848 rows / 617 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean（机械警报已按复核记录 ack）。
批次五十九已达到=`50/50`；统一长门禁已通过，证据=`testend/rig/formal-evidence/batch-59-unified-gate-20260825.md`，已提交 `49baf1c9`。批次六十从 `0/50` 开始，下一前线=`EDGE-121`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-119 webhook 路径改后旧路径

真实 contract 已证明 webhook Edit 改 `config.path` 后旧路径立即 `404`、新路径 `202`，前后两次事件各完成一个 run；catch-all registry 没有旧路由残留。

正式证据=`testend/rig/formal-evidence/EDGE-119-webhook-old-path-404-20260825.md`。五级严格为
`L1=measure:edge119-webhook-old-path-404`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；真实 HTTP 只证明路由真相，不替代独立 Computer Use、测量、视觉和 discoverability 证据。
formal journal=`3081`（2300 baseline + 781 live），`gen_coverage.py --check`=`848 rows / 616 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean（机械警报已按复核记录 ack）。
批次五十九当时=`45/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-120`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-118 暂停期间的 Edit 何时生效

配置时序已收口：暂停 → Edit 不热更新 source，`:resume` 按当前配置重新注册；应用层回归和真实 sensor HTTP 路径共同证明暂停窗口不产生 run，恢复后使用编辑后的目标成功触发。

正式证据=`testend/rig/formal-evidence/EDGE-118-edit-config-takes-effect-on-resume-20260825.md`。五级严格为
`L1=measure:edge118-edit-config-takes-effect-on-resume`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；真实 HTTP 只证明时序语义，不替代独立 Computer Use、测量、视觉和 discoverability 证据。
formal journal=`3076`（2300 baseline + 776 live），`gen_coverage.py --check`=`848 rows / 615 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean（机械警报已按复核记录 ack）。
批次五十九当前=`40/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-119`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-117 `Edit` 与 `:pause` 并发/暂停期配置生效

暂停期间编辑不热更 source、恢复时采用最新配置的语义已通过：应用层 `-race` 回归覆盖暂停编辑窗口；真实 sensor HTTP 场景覆盖暂停、硬重启、暂停期修改目标、恢复后重新注册并使用新目标，暂停窗口没有 activation/run。

正式证据=`testend/rig/formal-evidence/EDGE-117-edit-while-paused-defers-20260825.md`。五级严格为
`L1=measure:edge117-edit-while-paused-defers`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；真实 HTTP 只证明产品语义，不替代独立 Computer Use、测量、视觉和 discoverability 证据。
formal journal=`3071`（2300 baseline + 771 live），`gen_coverage.py --check`=`848 rows / 614 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean（机械警报已按复核记录 ack）。
批次五十九当前=`35/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-118`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-116 `resume` 的 Register 失败回滚

source 拒绝重新注册时的失败态已收口：精确回归证明首次 `Resume` 显式报错、持久行回滚为 paused、竞态报告不产生 firing；source 恢复后再次 `Resume` 成功恢复 listening 并产生唯一 firing。仓内没有可稳定制造同等 source 注册失败的真实 UI/网关产品路径，因此不伪造更高等级证据。

正式证据=`testend/rig/formal-evidence/EDGE-116-resume-register-rollback-20260825.md`。五级严格为
`L1=measure:edge116-resume-register-rollback`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；fake source 只证明应用回滚不变量，不能越级替代真实台架证据。
formal journal=`3066`（2300 baseline + 766 live），`gen_coverage.py --check`=`848 rows / 613 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean（机械警报已按复核记录 ack）。
批次五十九当前=`30/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-117`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-115 暂停时 `:fire` 大声拒

暂停状态的手动 fire 已在应用源头和真实 HTTP 产品路径双重收口：app regression 证明暂停后 source 已注销，`onReport` 不产生 activation/firing，`FireManual` 返回 `ErrPaused`；真实 App/HTTP 场景证明 `POST /api/v1/triggers/<id>:fire` 返回 `422 TRIGGER_PAUSED`，硬重启跨 cron 边界仍无 run/activation，resume 后下一次真实 cron fire 成功。

正式证据=`testend/rig/formal-evidence/EDGE-115-paused-fire-rejected-20260825.md`。五级严格为
`L1=measure:edge115-paused-fire-rejected`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；本格没有独立 Computer Use 逐帧、时延采集、视觉美观或 discoverability 证据，不将 L1 证据越级使用。
formal journal=`3061`（2300 baseline + 761 live），`gen_coverage.py --check`=`848 rows / 612 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean（gap-too-fast 与 discovery-collapse 已按复核记录 ack）。
批次五十九当前=`25/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-116`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-114 trigger 暂停在源头注销

新增并通过四源 pause 护栏：cron、webhook、fsnotify、sensor 的 app regression 均断言 source `Unregister` 恰好一次；真实 fsnotify/sensor 场景完成 pause → hard restart → no new firing → resume → source recovery，源头没有漏闸。

正式证据=`testend/rig/formal-evidence/EDGE-114-pause-unregisters-source-20260825.md`。五级严格为
`L1=measure:edge114-pause-unregisters-source`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；虽有真实 source 生命周期路径，但没有独立 Computer Use 逐帧、时延采集、视觉美观或 discoverability session。
formal journal=`3056`（2300 baseline + 756 live），`gen_coverage.py --check`=`848 rows / 611 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十九当前=`20/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-115`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-113 sensor 电平触发风暴

新增并通过 level-triggered regression：连续三轮 sustained-true probe 均产生 fired activity；真实 HTTP 场景也完成 function → sensor poll → workflow run，并在 activation 中保留 probe return value。该边界明确由 workflow concurrency policy 治理风暴，不由 sensor 静默改成 edge-trigger。

正式证据=`testend/rig/formal-evidence/EDGE-113-sensor-level-trigger-storm-20260825.md`。五级严格为
`L1=measure:edge113-sensor-level-trigger-storm`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；虽有真实 HTTP 产品路径，但没有独立 Computer Use 逐帧、时延采集、视觉美观或 discoverability session。
formal journal=`3051`（2300 baseline + 751 live），`gen_coverage.py --check`=`848 rows / 610 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十九当前=`15/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-114`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-112 shed 孤儿 firing

真实 scheduler regression 通过：pending firing 对应的 workflow 被删除后，首次 drain 将其终结为 `shed`；第二次 drain 不再重试、不重复记错、不创建 flowrun，pending 收件箱清空。

正式证据=`testend/rig/formal-evidence/EDGE-112-shed-orphan-firing-20260825.md`。五级严格为
`L1=measure:edge112-shed-orphan-firing`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是 scheduler 孤儿 firing 终态契约，没有独立 Computer Use 逐帧、时延采集、视觉美观或 discoverability session。
formal journal=`3046`（2300 baseline + 746 live），`gen_coverage.py --check`=`848 rows / 609 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十九当前=`10/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-113`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-111 AppendFiring 撞键返已存在行

真实 trigger service regression 通过：真实 fire 撞上已被 misfire sweep 记为 `missed` 的 dedup key 时，原行被救回为唯一 pending run，missed 查询移除该行，activation 计数为 1，且 firing 的 `activation_id` 血缘闭合。

正式证据=`testend/rig/formal-evidence/EDGE-111-append-firing-requeues-missed-20260825.md`。五级严格为
`L1=measure:edge111-append-firing-requeues-missed`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是 trigger dedup/requeue 数据真相契约，没有独立 Computer Use 逐帧、时延采集、视觉美观或 discoverability session。
formal journal=`3041`（2300 baseline + 741 live），`gen_coverage.py --check`=`848 rows / 608 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十九当前=`5/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-112`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-110 睡醒伪 fire 吸附/丢弃

真实 cron infra regression 通过：准时回调与 90 秒迟到回调均吸附到合法小时刻度，50 分钟后的睡醒 stale callback 超出容差被拒绝，不会隐式补跑。

正式证据=`testend/rig/formal-evidence/EDGE-110-wake-artifact-snap-or-drop-20260825.md`。五级严格为
`L1=measure:edge110-wake-artifact-snap-or-drop`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是 cron 回调归属契约，没有独立 Computer Use 逐帧、时延采集、视觉美观或 discoverability session。
formal journal=`3036`（2300 baseline + 736 live），`gen_coverage.py --check`=`848 rows / 607 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十八已达到=`50/50`；统一长门禁已通过，证据=`testend/rig/formal-evidence/batch-58-unified-gate-20260825.md`，已提交 `64bc55fd`。下一前线=`EDGE-111`，批次五十九从 `0/50` 开始。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-109 misfire 台账双封顶

真实 trigger service regression 通过：weekly 稀疏日程全年约 52 条全部精确保留，daily 日程只保留 30 天窗口内约 30 条，minutely 日程恰好封顶 200 条且全部在窗口内；水位推进后第二次 sweep 无新增。

正式证据=`testend/rig/formal-evidence/EDGE-109-misfire-double-cap-20260825.md`。五级严格为
`L1=measure:edge109-misfire-double-cap`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是 trigger backfill 上限契约，没有独立 Computer Use 逐帧、时延采集、视觉美观或 discoverability session。
formal journal=`3031`（2300 baseline + 731 live），`gen_coverage.py --check`=`848 rows / 606 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十八当前=`45/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-110`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-108 catchup_one 崩溃窗不重跑

真实 trigger service regression 通过：模拟 fan-out 已提交而 watermark 未推进的崩溃窗，重查相同缺口时返回 `n=0`，activation 数不变，pending catch-up 仍只有一个；系统按“真正已记账”而不是“窗口仍有刻度”决定是否补跑。

正式证据=`testend/rig/formal-evidence/EDGE-108-catchup-one-crash-window-20260825.md`。五级严格为
`L1=measure:edge108-catchup-one-crash-window`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是 trigger 崩溃窗账本契约，没有独立 Computer Use 逐帧、时延采集、视觉美观或 discoverability session。
formal journal=`3026`（2300 baseline + 726 live），`gen_coverage.py --check`=`848 rows / 605 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十八当前=`40/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-109`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-107 catchup_one 补一个

真实 trigger service regression 通过：`misfirePolicy=catchup_one` 跨过多个 cron 刻度后只产生一个 runnable catch-up；该刻度不再留在 missed，较早刻度保持 missed，二次 sweep 不产生第二个 catch-up。

正式证据=`testend/rig/formal-evidence/EDGE-107-catchup-one-exactly-once-20260825.md`。五级严格为
`L1=measure:edge107-catchup-one-exactly-once`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是 trigger misfire 策略契约，没有独立 Computer Use 逐帧、时延采集、视觉美观或 discoverability session。
formal journal=`3021`（2300 baseline + 721 live），`gen_coverage.py --check`=`848 rows / 604 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十八当前=`35/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-108`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-106 暂停期间的错过不算 misfire

真实 trigger service regression 通过：cron trigger 暂停期间的 sweep 返回 `n=0` 且不生成 missed 行；`:resume` 静默闭合暂停窗口，后续 sweep 仍返回 `n=0` 且不复活暂停期间的刻度。用户主动暂停不会被伪报成 misfire。

正式证据=`testend/rig/formal-evidence/EDGE-106-pause-not-misfire-20260825.md`。五级严格为
`L1=measure:edge106-pause-not-misfire`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是 trigger 账本语义，没有独立 Computer Use 逐帧、时延采集、视觉美观或 discoverability session。
formal journal=`3016`（2300 baseline + 716 live），`gen_coverage.py --check`=`848 rows / 603 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十八当前=`30/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-107`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-105 AttachReplay 零值纪元

真实 trigger service regression 通过：同一 cron trigger 上，boot `AttachReplay` 的 `wf_old` 被正确记入停机缺口，运行中实时 `Attach` 的 `wf_new` 不被追溯收费；listener 共用、引用集和 workflow 归属均正确。

正式证据=`testend/rig/formal-evidence/EDGE-105-attach-replay-zero-epoch-20260825.md`。五级严格为
`L1=measure:edge105-attach-replay-zero-epoch`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是 boot replay 与实时挂载的 misfire 归属契约，没有独立 Computer Use 逐帧、时延采集、视觉或 discoverability session。
formal journal=`3011`（2300 baseline + 711 live），`gen_coverage.py --check`=`848 rows / 602 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十八当前=`25/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-106`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-104 hotSince 下界

真实 trigger service regression 通过：AttachReplay 后将 trigger 做旧到约 90 秒前，重启 entry 的 `hotSince` 下界压过 live-listener 容差，misfire sweep 立即生成 missed 行且不进 pending；重启后面板不会因等待两分钟而虚假空白。

正式证据=`testend/rig/formal-evidence/EDGE-104-hot-since-lower-bound-20260825.md`。五级严格为
`L1=measure:edge104-hot-since-lower-bound`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是重启 hotSince 下界与 misfire watermark 契约，没有独立 Computer Use 逐帧、时延采集、视觉或 discoverability session。
formal journal=`3006`（2300 baseline + 706 live），`gen_coverage.py --check`=`848 rows / 601 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十八当前=`20/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-105`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-103 窗口上界留容差尾带

真实 trigger service regression 通过：`now - MisfireTolerance` 之后仍可能迟到的刻度不被本趟 sweep 记成 `missed`，避免提前占掉 dedup key；尾带之前的 gap 正常记账，watermark 停在窗口末端交给下一趟 sweep。

正式证据=`testend/rig/formal-evidence/EDGE-103-misfire-tolerance-upper-bound-20260825.md`。五级严格为
`L1=measure:edge103-misfire-tolerance-upper-bound`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是 trigger 窗口上界与 dedup-key 保护契约，没有独立 Computer Use 逐帧、时延采集、视觉或 discoverability session。
formal journal=`3001`（2300 baseline + 701 live），`gen_coverage.py --check`=`848 rows / 600 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十八当前=`15/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-104`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-102 睡眠期 misfire（进程仍活）

真实 `Service.SweepMisfires` regression 通过：用 listener 注册纪元回拨精确模拟“进程仍活但睡过墙钟”，尾带之前的刻度记为 missed，仍可能迟到送达的 `MisfireTolerance` 尾带不被偷占，watermark 停在尾带之前。实际等待一小时不在开发机重复，证据明确标注时间状态替身边界。

正式证据=`testend/rig/formal-evidence/EDGE-102-live-misfire-tolerance-band-20260825.md`。五级严格为
`L1=measure:edge102-live-misfire-tolerance-band`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是 trigger 尾带与 watermark 契约，没有独立 Computer Use 逐帧、时延采集、视觉或 discoverability session。
formal journal=`2996`（2300 baseline + 696 live），`gen_coverage.py --check`=`848 rows / 599 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十八当前=`10/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-103`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-101 misfire 记账不补跑

真实 HTTP 场景对 sidecar 执行 `SIGKILL`，跨过一分钟 cron 刻度后重启，boot 记账 `missed=1`；firing 查询、workspace 汇总、时间窗口和 flowrun-stats 均通过。missed 行没有 flowrun、不进入 pending，重复 sweep 不重复记账；trigger focused `-race` 同时通过幂等、重启不等容差带和活进程尾带。free-tier port-1 与 search shutdown warning 是隔离 harness 预期噪声，不是场景失败。

正式证据=`testend/rig/formal-evidence/EDGE-101-misfire-missed-accounting-20260825.md`。五级严格为
`L1=measure:edge101-misfire-missed-accounting`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是 trigger 台账与重启契约，没有独立 Computer Use 逐帧、时延采集、视觉或 discoverability session。
formal journal=`2991`（2300 baseline + 691 live），`gen_coverage.py --check`=`848 rows / 598 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十八当前=`5/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-102`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-100 LLM 工具 flowrun 节点封顶

新增 2001-row scale regression 与真实 25 轮 loop HTTP 分页均通过：LLM 工具投影严格保留不超过 80 行，保留全部 failure/parked 与最近 completed 尾巴，`nodeSummary` 保留真实总数；REST 仍能分页取回全部 52 行且每个 `(node, iteration)` 唯一，执行审计 join 完整。testend 收台 search health warning 是取消上下文噪声，不是场景失败。

正式证据=`testend/rig/formal-evidence/EDGE-100-flowrun-node-cap-20260825.md`。五级严格为
`L1=measure:edge100-flowrun-node-cap`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是 LLM 上下文安全投影与 REST 数据真相契约，没有独立 Computer Use 逐帧、时延采集、视觉或 discoverability session。
formal journal=`2986`（2300 baseline + 686 live），`gen_coverage.py --check`=`848 rows / 597 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十七已达到=`50/50`；统一长门禁已通过，证据=`testend/rig/formal-evidence/batch-57-unified-gate-20260825.md`，已提交 `d52047b4`；下一前线=`EDGE-101`，批次五十八从 `0/50` 开始。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-099 flowruns 两种分页互斥

handler `-race` 单测与真实 HTTP offset-pagination scenario 均通过：`cursor` 与 `offset` 同时出现时先返回 `422 FLOWRUN_LIST_CURSOR_OFFSET_CONFLICT`；单独的畸形 `offset` 仍返回参数错误；offset 分页、cursor 分页以及负值边界均保持契约。testend free-tier port-1 warning 是隔离 harness 预期关闭端口，不是场景失败。

正式证据=`testend/rig/formal-evidence/EDGE-099-flowruns-cursor-offset-conflict-20260825.md`。五级严格为
`L1=measure:edge099-flowruns-cursor-offset-conflict`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是 API 分页互斥契约，没有独立 Computer Use 逐帧、时延采集、视觉或 discoverability session。
formal journal=`2981`（2300 baseline + 681 live），`gen_coverage.py --check`=`848 rows / 596 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十七当前=`40/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-100`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-098 activity 排队段负值

Flutter `66` 项 scheduler timing/run tests、后端 activity union/join/keyset `-race` 与真实 HTTP activity scenario 通过：`readyAt > startedAt` 时 queue 段钳为零，缺真相戳时诚实缺席，真实双 agent activity 的 queue stamp 与执行窗口一致。

正式证据=`testend/rig/formal-evidence/EDGE-098-activity-queue-negative-clamp-20260825.md`。五级严格为
`L1=measure:edge098-activity-queue-negative-clamp`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；虽有 deterministic timing 证据，但没有独立 Computer Use 逐帧、时延采集、视觉或 discoverability session。
formal journal=`2976`（2300 baseline + 676 live），`gen_coverage.py --check`=`848 rows / 595 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十七当前=`35/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-099`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-097 matrix 多迭代最坏处置

#### 2026-08-25 当前前线重述：EDGE-097 matrix 多迭代最坏处置

真实 store `-race` 三个 rank/iteration regression 与 HTTP matrix scenario 通过：failed 永远压过后续 completed，parked 压过 completed，cancelled 保持中性而不误报绿/红；多轮矩阵不会把历史失败洗成成功。收台时 search health warning 是 testend 取消噪声。

正式证据=`testend/rig/formal-evidence/EDGE-097-flowrun-matrix-worst-iteration-20260825.md`。五级严格为
`L1=measure:edge097-flowrun-matrix-worst-iteration`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是 scheduler projection 不变量，没有独立 Computer Use 逐帧、时延、视觉或 discoverability session。
formal journal=`2971`（2300 baseline + 671 live），`gen_coverage.py --check`=`848 rows / 594 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十七当前=`30/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-098`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-096 flowrun-matrix 未知 id

#### 2026-08-25 当前前线重述：EDGE-096 flowrun-matrix 未知 id

真实 store `-race`、app guard 与 HTTP scenario 通过：异 workspace/不存在 id 静默缺席，混合请求只返回当前 workspace 已知列，全未知返回 `cols=[]/rows=[]/cells=[]`；空参数、上限、去重和裸 ctx 隔离边界均通过。testend search shutdown warning 是 harness 收台噪声。

正式证据=`testend/rig/formal-evidence/EDGE-096-flowrun-matrix-unknown-id-20260825.md`。五级严格为
`L1=measure:edge096-flowrun-matrix-unknown-id`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是 scheduler projection 边界，没有独立 Computer Use 逐帧、时延、视觉或 discoverability session。
formal journal=`2966`（2300 baseline + 666 live），`gen_coverage.py --check`=`848 rows / 593 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十七当前=`25/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-097`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-095 flowrun-stats 倒挂窗

#### 2026-08-25 当前前线重述：EDGE-095 flowrun-stats 倒挂窗

真实 store `-race` 与 HTTP scenario 通过：`until <= since` 时窗口 totals/successRate/avgElapsedMs 为空而非错误，recent/lastRunAt 保留；正常上界、未来 since、超限和坏参数契约也保持。testend 的 port-1 free-tier warning 是隔离 harness 预期，不是场景失败。

正式证据=`testend/rig/formal-evidence/EDGE-095-flowrun-stats-inverted-window-20260825.md`。五级严格为
`L1=measure:edge095-flowrun-stats-inverted-window`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是 scheduler 统计边界，没有独立 Computer Use 逐帧、时延、视觉或 discoverability session。
formal journal=`2961`（2300 baseline + 661 live），`gen_coverage.py --check`=`848 rows / 592 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十七当前=`20/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-096`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-094 mode=0 老库升级

#### 2026-08-25 当前前线重述：EDGE-094 mode=0 老库升级

真实落盘 SQLite `-race` focused 通过：mode=0 旧库 Compact 后回收死空间、`migrated=true`、存活行完整；同一旧 DSN 重开仍为 `INCREMENTAL`；第二次 Compact `migrated=false`；已是 INCREMENTAL 的 Compact 与 app storage 映射同组通过。

正式证据=`testend/rig/formal-evidence/EDGE-094-mode0-compact-migration-20260825.md`。五级严格为
`L1=measure:edge094-mode0-compact-migration`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是 infra/db 迁移不变量，没有独立 Computer Use 逐帧、时延、视觉或 discoverability session。
formal journal=`2956`（2300 baseline + 656 live），`gen_coverage.py --check`=`848 rows / 591 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十七当前=`15/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-095`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-093 手动 VACUUM 压缩失败

#### 2026-08-25 当前前线重述：EDGE-093 手动 VACUUM 压缩失败

storage app focused `-race` 通过：只读 SQLite 确定性模拟 VACUUM 文件写入拒绝，`Compact` 映射为 `STORAGE_COMPACT_FAILED`，数据库文件大小与 probe 行数均不变；成功 Compact 路径同组通过。真实 ENOSPC 不在开发机上制造，证据明确标注为安全的写失败替身。

正式证据=`testend/rig/formal-evidence/EDGE-093-storage-compact-failure-20260825.md`。五级严格为
`L1=measure:edge093-storage-compact-failure`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是 storage failure contract，没有独立 Computer Use 逐帧、时延、视觉或 discoverability session。
formal journal=`2951`（2300 baseline + 651 live），`gen_coverage.py --check`=`848 rows / 590 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十七当前=`10/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-094`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-092 磁盘回收闸；批次五十七开始

真实落盘 SQLite focused `-race` 通过：大于比例门（49.3MB、3000 行存活）时 DELETE 后文件先不缩、`ReclaimFreePages` 后缩小；约 5% routine churn 低于比例与 128MiB 两道门时回收为 0 且文件不动；Stat 与 app storage 映射一并通过。没有生产逻辑改动。

正式证据=`testend/rig/formal-evidence/EDGE-092-disk-reclamation-gate-20260825.md`。五级严格为
`L1=measure:edge092-disk-reclamation-gate`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是 infra/db 磁盘治理不变量，没有独立 Computer Use 逐帧、时延、视觉或 discoverability session。
formal journal=`2946`（2300 baseline + 646 live），`gen_coverage.py --check`=`848 rows / 589 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十七当前=`5/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`EDGE-093`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 已提交批次五十六：EDGE-082..EDGE-091

#### 2026-08-25 当前前线重述：EDGE-091 保留清理后的孤儿深链；批次五十六收满

前端 scheduler 77 项 focused Flutter 测试通过：run 所属 workflow 被删除/清理后，run 深链仍可达；host 404、钉版图缺失和不可解析 id 都诚实渲成墓碑/句子，不白屏、不伪造当前图。

正式证据=`testend/rig/formal-evidence/EDGE-091-retention-orphan-deep-link-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-091-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge091-retention-orphan-deep-link`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；有 deterministic frontend fixture/UI 证据，但没有独立 Computer Use 逐帧、时延、视觉或 discoverability session。
formal journal=`2941`（2300 baseline + 641 live），`gen_coverage.py --check`=`848 rows / 588 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十六已达到=`50/50`；统一长门禁已通过，证据=`testend/rig/formal-evidence/batch-56-unified-gate-20260825.md`，已提交 `b93d228c`；下一前线=`EDGE-092`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-090 run 历史保留清理

Boot wiring 与 store retention focused 测试通过：30d 线清理 100d old completed run，fresh 与 900d old running 存活；0 线不清 ancient completed；cascade、边界、batch、workspace isolation 均通过。

正式证据=`testend/rig/formal-evidence/EDGE-090-run-retention-purge-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-090-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge090-run-retention-purge`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是 storage governance，没有独立 formal rig 逐帧、时延、视觉或 discoverability capture。
formal journal=`2936`（2300 baseline + 636 live），`gen_coverage.py --check`=`848 rows / 587 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十六当前=`45/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-091`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-089 draining 最后一个 run 结算

真实 HTTP workflow 场景确认：`:deactivate` 对在途 approval run 先进入 draining、不杀 run；人工决策使 run completed 后，workflow 才收口 inactive。

正式证据=`testend/rig/formal-evidence/EDGE-089-draining-last-run-settles-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-089-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge089-draining-last-run-settles`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；有黑盒生命周期证据，但没有独立 formal rig 逐帧、时延、视觉或 discoverability capture。
formal journal=`2931`（2300 baseline + 631 live），`gen_coverage.py --check`=`848 rows / 586 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十六当前=`40/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-090`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-088 per-run 单飞 + redrive

同一 run 并发收到多个 advance 时最多一个驱动者；中途信号折叠为一次尾部 redrive，不重复执行副作用节点，也不丢推进信号。scheduler `-race` focused 护栏通过，三次 advance 下 `fn_a` 恰执行一次。

正式证据=`testend/rig/formal-evidence/EDGE-088-per-run-single-flight-redrive-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-088-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge088-per-run-single-flight-redrive`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是 scheduler concurrency invariant，没有独立 formal rig 逐帧、时延、视觉或 discoverability capture。
formal journal=`2926`（2300 baseline + 626 live），`gen_coverage.py --check`=`848 rows / 585 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十六当前=`35/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-089`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-087 sendJob 撞已关队列

feeder 在 StopPool 关闭队列后迟到发送时，`sendJob` recover 关闭 channel panic、清理 dedup 槽，进程不崩；后续 Recover 可重新入队。scheduler `-race` focused 护栏通过。

正式证据=`testend/rig/formal-evidence/EDGE-087-send-job-closed-queue-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-087-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge087-send-job-closed-queue`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是 shutdown queue race，没有独立 formal rig 逐帧、时延、视觉或 discoverability capture。
formal journal=`2921`（2300 baseline + 621 live），`gen_coverage.py --check`=`848 rows / 584 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十六当前=`30/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-088`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-086 advClosing 关停不跑缓冲 run

关停设置 `advClosing` 后，StopPool 排空队列只跳过缓冲 run，不在不可取消上下文中执行；run 保持 running，等下次 boot Recover。scheduler `-race` focused 护栏通过。

正式证据=`testend/rig/formal-evidence/EDGE-086-adv-closing-skips-buffered-run-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-086-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge086-adv-closing-skips-buffered-run`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是 shutdown scheduler 边界，没有独立 formal rig 逐帧、时延、视觉或 discoverability capture。
formal journal=`2916`（2300 baseline + 616 live），`gen_coverage.py --check`=`848 rows / 583 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十六当前=`25/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-087`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-085 pin 闭包冻结在途 run

真实 HTTP workflow 场景确认：run 起跑时钉住 function/control 版本；之后编辑引用实体，原 run replay/继续仍使用旧版本，新 run 才采用 active 新版本。function pin 与 control parked pin 场景均通过；只登记已有产品护栏，不改运行逻辑。

正式证据=`testend/rig/formal-evidence/EDGE-085-pin-closure-inflight-run-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-085-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge085-pin-closure-inflight-run`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；有黑盒后端证据，但没有独立 formal rig 逐帧、时延、视觉或 discoverability capture。
formal journal=`2911`（2300 baseline + 611 live），`gen_coverage.py --check`=`848 rows / 582 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十六当前=`20/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-086`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-084 菱形 join 未守 has()

新增回归测试确认：capability-check 按结构允许汇合节点读取任一祖先，但运行时未选分支绑定空 map；不使用 `has()` 读取缺失字段时，run 大声失败并保留 `no such key` 上下文，绝不编造值或静默跳过。只增加测试护栏，不改变产品逻辑。

正式证据=`testend/rig/formal-evidence/EDGE-084-diamond-join-missing-key-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-084-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge084-diamond-join-missing-key`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是作者责任运行时边界，没有独立 formal rig 五通道、逐帧时延、视觉或 discoverability session。
formal journal=`2906`（2300 baseline + 606 live），`gen_coverage.py --check`=`848 rows / 581 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十六当前=`15/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-085`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-083 MaxIterations 栅栏

永真 CEL 回边最多落 `iteration 0..1000` 共 1001 条循环体行；下一回边被拒绝，run 失败，错误明确写出 `MaxIterations (1000)`。
focused scheduler `-race` 回归通过，未改运行逻辑。

正式证据=`testend/rig/formal-evidence/EDGE-083-max-iterations-fence-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-083-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge083-max-iterations-fence`、`L2=na`、`L3=na`、`L4=na`、`L5=na`；这是 scheduler fence，没有独立 formal rig 五通道、逐帧时延、视觉或 discoverability session。
formal journal=`2901`（2300 baseline + 601 live），`gen_coverage.py --check`=`848 rows / 580 carried judgments / 0 tombstones`，anchors=`10/10`，`alarms.py check` clean。
批次五十六当前=`10/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-084`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-082 replay 与保留清理竞速

保留清理在 `flowruns` 父表删除处重新检查终态；`:replay` 通过 `WHERE id=? AND status='failed'` 抢到逆转后，清理不能删除该 run。
反向的 stale replay 返回 `ErrNotReplayable`，不复活新终态。生产 SQLite 是单连接，未引入测试专用生产 hook；真实 store 回归、race focused
测试均通过。

正式证据=`testend/rig/formal-evidence/EDGE-082-replay-retention-race-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-082-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge082-replay-retention-race`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：这是存储竞态，没有独立 formal rig 五通道、逐帧时延、
视觉或 discoverability session，不作虚假升级。formal journal=`2896`（2300 baseline + 596 live），
`gen_coverage.py --check`=`848 rows / 579 carried judgments / 0 tombstones`，anchors 保持=`10/10`，统计警报复审后 `alarms.py check` clean。
批次五十六当前=`5/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-083`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-072 approval 显式零时长

`timeout:"0s"` 与 `"0ms"` 均在创建前被拒绝为 HTTP 422 `APPROVAL_INVALID_TIMEOUT`；非法 duration 和非空 timeout 缺少
`timeoutBehavior` 同样拒绝，`""` 仍保留为永不超时。领域、应用层和黑盒契约场景均通过，未放宽公开契约。

正式证据=`testend/rig/formal-evidence/EDGE-072-approval-explicit-zero-duration-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-072-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge072-approval-explicit-zero-duration`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：没有独立 formal rig 五通道、逐帧时延、
视觉或 discoverability session，不作虚假升级。formal journal=`2846`（2300 baseline + 546 live），
`gen_coverage.py --check`=`848 rows / 569 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报复审后
`alarms.py check` clean。批次五十五当前=`5/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-073`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-081 并发 :replay 守卫；批次五十五收满

同一 failed run 的两次 replay 只能有一个赢得 `WHERE status='failed'` 逆转守卫；赢家进入新终态后，持旧 failed 读的输家返回
`FLOWRUN_NOT_REPLAYABLE`，不复活新终态，`replay_count` 恰为 1。普通、`-race` 和完整 flowrun store 包通过。

正式证据=`testend/rig/formal-evidence/EDGE-081-replay-concurrent-guard-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-081-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge081-replay-concurrent-guard`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：没有独立 formal rig 五通道、逐帧时延、
视觉或 discoverability session，不作虚假升级。formal journal=`2891`（2300 baseline + 591 live），
`gen_coverage.py --check`=`848 rows / 578 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报复审后
`alarms.py check` clean。批次五十五已达到=`50/50`；统一长门禁已通过，证据=`testend/rig/formal-evidence/batch-55-unified-gate-20260825.md`，待本批提交，不推进下一前线。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-080 :replay 只收 failed

cancelled 是终局状态，`:replay` 只接受 failed；对 cancelled run 返回 `FLOWRUN_NOT_REPLAYABLE`，不清节点、不重开 header、不铸造新执行。
普通、`-race` 和黑盒取消/replay 路径通过。

正式证据=`testend/rig/formal-evidence/EDGE-080-replay-only-failed-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-080-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge080-replay-only-failed`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：没有独立 formal rig 五通道、逐帧时延、
视觉或 discoverability session，不作虚假升级。formal journal=`2886`（2300 baseline + 586 live），
`gen_coverage.py --check`=`848 rows / 577 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报复审后
`alarms.py check` clean。批次五十五当前=`45/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-081`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-079 恢复后排队戳是新起点

恢复重走未落行节点时，`ready_at` 不伪装成原 run 创建时间，而以恢复 walk 时刻为新排队起点；普通和 `-race` timing 回归通过。

正式证据=`testend/rig/formal-evidence/EDGE-079-recovery-ready-at-new-origin-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-079-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge079-recovery-ready-at-new-origin`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：没有独立 formal rig 五通道、逐帧时延、
视觉或 discoverability session，不作虚假升级。formal journal=`2881`（2300 baseline + 581 live），
`gen_coverage.py --check`=`848 rows / 576 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报复审后
`alarms.py check` clean。批次五十五当前=`40/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-080`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-078 崩溃恢复 Recover

boot Recover 对每个 durable running run 入队而非内联阻塞；已完成节点记忆化跳过，崩溃时未落行的节点按 at-least-once 重跑，慢 run 不阻塞其它恢复。
普通和 `-race` scheduler 回归通过。

正式证据=`testend/rig/formal-evidence/EDGE-078-crash-recovery-rewalk-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-078-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge078-crash-recovery-rewalk`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：没有独立 formal rig 五通道、逐帧时延、
视觉或 discoverability session，不作虚假升级。formal journal=`2876`（2300 baseline + 576 live），
`gen_coverage.py --check`=`848 rows / 575 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报复审后
`alarms.py check` clean。批次五十五当前=`35/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-079`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-077 被打断的在飞节点不落行

取消正在 provider 调用中的 agent 后，只让 run 落 `cancelled`；被打断节点不写 `flowrun_nodes`、不误报 `failed`，调度器仍能接受下一次运行。
普通、`-race` 和黑盒 stalled-agent 路径通过。

正式证据=`testend/rig/formal-evidence/EDGE-077-cancel-interrupted-node-no-row-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-077-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge077-cancel-interrupted-node-no-row`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：没有独立 formal rig 五通道、逐帧时延、
视觉或 discoverability session，不作虚假升级。formal journal=`2871`（2300 baseline + 571 live），
`gen_coverage.py --check`=`848 rows / 574 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报复审后
`alarms.py check` clean。批次五十五当前=`30/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-078`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-076 收割闸与永久停滞子图

first-wins 输家不执行 `CancelParkedNodes`：自然 failed 且可 replay 的 run 保留 parked approval，避免节点被错误写成 `cancelled` 后形成
无法清理的混合子图。普通和 `-race` scheduler 回归通过。

正式证据=`testend/rig/formal-evidence/EDGE-076-cancel-loser-must-not-sweep-parked-subgraph-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-076-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge076-cancel-loser-must-not-sweep-parked-subgraph`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：没有独立 formal rig 五通道、逐帧时延、
视觉或 discoverability session，不作虚假升级。formal journal=`2866`（2300 baseline + 566 live），
`gen_coverage.py --check`=`848 rows / 573 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报复审后
`alarms.py check` clean。批次五十五当前=`25/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-077`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-075 取消赢家收割 parked 审批

取消 running 且 parked 的 run 时，只有赢得 durable header guard 的调用才执行 `CancelParkedNodes`；节点落 `cancelled`、inbox 清空，
不伪造 `failed`。普通、`-race` 和黑盒 HTTP 取消路径通过。

正式证据=`testend/rig/formal-evidence/EDGE-075-cancel-winner-sweeps-parked-approval-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-075-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge075-cancel-winner-sweeps-parked-approval`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：没有独立 formal rig 五通道、逐帧时延、
视觉或 discoverability session，不作虚假升级。formal journal=`2861`（2300 baseline + 561 live），
`gen_coverage.py --check`=`848 rows / 572 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报复审后
`alarms.py check` clean。批次五十五当前=`20/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-076`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-074 run 取消竞态输家

确定性复现取消与自然终态同瞬竞态：自然终态先赢头守卫后，`:cancel` 返回 `FLOWRUN_NOT_CANCELLABLE`，保留自然 failed 头，
不发第二条 `run_terminal`，也不误收割可重放失败 run 的 parked approval。普通、`-race` 与黑盒取消路径通过。

正式证据=`testend/rig/formal-evidence/EDGE-074-flowrun-cancel-natural-terminal-loser-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-074-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge074-flowrun-cancel-natural-terminal-loser`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：没有独立 formal rig 五通道、逐帧时延、
视觉或 discoverability session，不作虚假升级。formal journal=`2856`（2300 baseline + 556 live），
`gen_coverage.py --check`=`848 rows / 571 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报复审后
`alarms.py check` clean。批次五十五当前=`15/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-075`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-073 approval 版本 resolve 失败

钉死的 approval 版本无法解析时，收件箱仍保留该 parked 行及 flowrun/workflow 身份，只省略派生的 `deadline`；不丢行、不伪造零时限，
仍可继续人工决策。focused 普通和 `-race` scheduler 测试通过。

正式证据=`testend/rig/formal-evidence/EDGE-073-approval-version-resolve-failure-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-073-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge073-approval-version-resolve-failure`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：没有独立 formal rig 五通道、逐帧时延、
视觉或 discoverability session，不作虚假升级。formal journal=`2851`（2300 baseline + 551 live），
`gen_coverage.py --check`=`848 rows / 570 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报复审后
`alarms.py check` clean。批次五十五当前=`10/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-074`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-071 approval 三种超时行为；批次五十四收满

timeout sweep 的三种配置均已锁定：`reject` 将 approval 决为 no 并裁掉 publish，`approve` 决为 yes 并执行 publish 一次，
`fail` 将 approval node 与 run 都落为 failed。focused 普通、focused `-race` 和完整 scheduler 包全部通过。

正式证据=`testend/rig/formal-evidence/EDGE-071-approval-timeout-behaviors-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-071-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge071-approval-timeout-behaviors`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：没有独立 formal rig 五通道、逐帧时延、
视觉或 discoverability session，不作虚假升级。formal journal=`2841`（2300 baseline + 541 live），
`gen_coverage.py --check`=`848 rows / 568 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报复审后
`alarms.py check` clean。批次五十四已达到=`50/50`；统一长门禁已通过，证据=`testend/rig/formal-evidence/batch-54-unified-gate-20260825.md`，待本批提交，不推进下一前线。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-070 approval 人工 vs 超时 first-wins

人工 YES 与已到期 timeout sweep 并发争夺同一个 parked approval 时，durable 条件更新只允许一个 winner；输家得到干净的
`ErrNodeNotParked`，run 只结算一次，下游分支与记录的 decision 一致，之后重复决策继续被拒。focused 普通、focused `-race` 和完整
scheduler 包全部通过。

正式证据=`testend/rig/formal-evidence/EDGE-070-approval-human-timeout-first-wins-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-070-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge070-approval-human-timeout-first-wins`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：没有独立 formal rig 五通道、逐帧时延、
视觉或 discoverability session，不作虚假升级。formal journal=`2836`（2300 baseline + 536 live），
`gen_coverage.py --check`=`848 rows / 567 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报复审后
`alarms.py check` clean。当前批次=`45/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-071`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-069 ClaimFiring 事务崩溃回滚

故障注入让 `ClaimFiring` 在 pending→claimed 后、提交前写入 partial `flowrun_id`，再从 callback 返回错误；事务回滚两次写入，
firing 恢复为可重试的 `pending` 且 flowrun 关联为空，盘上不存在 claimed-but-no-run 半成品。focused 普通、focused `-race` 和完整
trigger store 包全部通过。

正式证据=`testend/rig/formal-evidence/EDGE-069-claim-firing-rollback-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-069-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge069-claim-firing-rollback`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：没有独立 formal rig 五通道、逐帧时延、视觉或
discoverability session，不作虚假升级。formal journal=`2831`（2300 baseline + 531 live），
`gen_coverage.py --check`=`848 rows / 566 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报复审后
`alarms.py check` clean。当前批次=`40/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-070`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-068 两阶段 drain 背靠背触发

同一批次两个同 workflow firing 在 phase-1 全部先 claim/seed、phase-2 再 advance；四种非 allow_all 策略分别得到正确耐久处置：
serial 留第二条 pending，skip 留中性 skipped，replace 一条 cancelled 加一条成功 successor，buffer_one supersede 旧条且只跑最新条。
普通、`-race` 与完整 scheduler 包全部通过。

正式证据=`testend/rig/formal-evidence/EDGE-068-two-phase-drain-same-batch-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-068-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge068-two-phase-drain-same-batch`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：没有独立 formal rig 五通道、逐帧时延、
视觉或 discoverability session，不作虚假升级。formal journal=`2826`（2300 baseline + 526 live），
`gen_coverage.py --check`=`848 rows / 565 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报复审后
`alarms.py check` clean。当前批次=`35/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-069`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-067 手动 :trigger 绕过 overlap

HTTP `:trigger` 与 chat `trigger_workflow` 共用手动 `StartRun` 咽喉，不进入 real-firing overlap policy。即使 workflow 策略为
`replace` 或 `buffer_one`，两个并发手动 run 也会同时进入慢 action，释放后各自完成；真实 firing inbox 才应用 overlap。
focused 普通、focused `-race`、`trigger_workflow` 契约测试和完整 scheduler 包全部通过。

正式证据=`testend/rig/formal-evidence/EDGE-067-manual-trigger-bypasses-overlap-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-067-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge067-manual-trigger-bypasses-overlap`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：没有独立 formal rig 五通道、逐帧时延、
视觉或 discoverability session，不作虚假升级。formal journal=`2821`（2300 baseline + 521 live），
`gen_coverage.py --check`=`848 rows / 564 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报复审后
`alarms.py check` clean。当前批次=`30/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-068`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-066 overlap allow_all 并发

一次高频 inbox 批次灌入 8 条 `allow_all` firing 时，8 个独立 run 全部 seed；结构性的 Advance pool 上限为
`advanceWorkers=4`，前四个慢 action 占满时第五个不会进入，释放后 8 个 run 全部完成且每个 action 只 dispatch 一次。
focused 普通、focused `-race`、allow_all/pool 回归和完整 scheduler 包全部通过。首轮没有进入慢 action 是测试夹具把 gate 键写成
`slow` 而图解析出的输入字段是 `flag`，已修正后重跑，生产池上限未被放宽。

正式证据=`testend/rig/formal-evidence/EDGE-066-overlap-allow-all-pool-cap-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-066-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge066-overlap-allow-all-pool-cap`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：没有独立 formal rig 五通道、逐帧时延、
视觉或 discoverability session，不作虚假升级。formal journal=`2816`（2300 baseline + 516 live），
`gen_coverage.py --check`=`848 rows / 563 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报复审后
`alarms.py check` clean。当前批次=`25/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-067`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-065 overlap replace 抢占

已有 workflow run 在途时，新的 `replace` firing 先以受保护的终态转换取消旧 run，再消费 firing、创建并执行唯一
successor；旧 run 保留为中性 `cancelled` 审计行，successor 完成且 action 恰执行一次。同批替换回归仍保持一取消一成功。
focused 普通、focused `-race` 与完整 scheduler 包全部通过。首轮诊断发现的是测试 firing 缺少图所需的 `start.orderId`，已补齐
夹具并保留严格成功断言，生产 replace 路径未被放宽。

正式证据=`testend/rig/formal-evidence/EDGE-065-overlap-replace-preempts-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-065-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge065-overlap-replace-preempts`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：没有独立 formal rig 五通道、逐帧时延、
视觉或 discoverability session，不作虚假升级。formal journal=`2811`（2300 baseline + 511 live），
`gen_coverage.py --check`=`848 rows / 562 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报复审后
`alarms.py check` clean。当前批次=`20/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-066`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-064 overlap buffer_one 收敛

在途 run 期间连续三个真实 firing 进入 `buffer_one` workflow 时，旧两个落为 `superseded`，只保留最新一个
`pending`；在途 run 结束前不 dispatch，下一次 drain 才执行最新 firing，successor/action 各一个。focused 普通/race、
`SupersedeAllButNewestPending` store 测试和完整 scheduler 包全部通过。

正式证据=`testend/rig/formal-evidence/EDGE-064-overlap-buffer-one-converges-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-064-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge064-overlap-buffer-one-converges`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：没有独立 formal rig 五通道、
逐帧时延、视觉或 discoverability session，不作虚假升级。formal journal=`2806`（2300 baseline + 506 live），
`gen_coverage.py --check`=`848 rows / 561 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立复审
ack 后 `alarms.py check` clean。当前批次=`15/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-065`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-063 overlap skip 丢弃

真实触发进入 `skip` workflow 时，如果已有 run 在途，新 firing 不保持 pending，也不创建 successor 或 dispatch action；
它留下明确的中性 `skipped` firing 审计行。该语义与 `serial` 的排队行为分离，避免把“没有执行”误报成失败或静默丢失。
focused 普通/race 与完整 scheduler 包全部通过。

正式证据=`testend/rig/formal-evidence/EDGE-063-overlap-skip-neutral-disposition-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-063-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge063-overlap-skip-neutral-disposition`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：没有独立 formal rig
五通道、逐帧时延、视觉或 discoverability session，不作虚假升级。formal journal=`2801`（2300 baseline + 501 live），
`gen_coverage.py --check`=`848 rows / 560 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立复审
ack 后 `alarms.py check` clean。当前批次=`10/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-064`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-062 overlap serial 推迟

真实触发进入 `serial` workflow 时，如果已有 run 在途，第二个 firing 保留在 durable pending inbox，不并发建 run；
前一个 run 结算后，下一次 drain 才消费它，并且只产生一个 successor/action。该语义与 `skip` 明确分开，手动
`trigger_workflow` 不绕进 overlap policy。新增的“下一 tick 真执行”回归与原 skip 对照测试、focused race、完整 scheduler
包全部通过。

正式证据=`testend/rig/formal-evidence/EDGE-062-overlap-serial-defers-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-062-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge062-overlap-serial-defers`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：没有独立 formal rig 五通道、
逐帧时延、视觉或 discoverability session，不作虚假升级。formal journal=`2796`（2300 baseline + 496 live），
`gen_coverage.py --check`=`848 rows / 559 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立复审
ack 后 `alarms.py check` clean。当前批次=`5/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-063`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-061 transcriptResync 不可与 lifecycleResync 互顶

messages 流与 notifications 流的 410 语义保持严格分离：`lifecycleResync()` 只负责生命周期投影，
`transcriptResync()` 只负责 messages 活层、人在环交互、rundown、touchpoint 和 activity dots。对话列表
作为同时拥有两类状态的 rail 同时订阅两者；transcript controller 只订 messages。新增反向回归证明 notifications
resync 到达时 live transcript 保持不动，随后 messages resync 才从 durable head 收口；对话流、人在环、列表、
transcript、touchpoint 和 jump 相关测试共 `104 passed`。

正式证据=`testend/rig/formal-evidence/EDGE-061-transcript-resync-boundary-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-061-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge061-transcript-resync-boundary`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：没有独立 formal rig
五通道、逐帧时延、视觉或 discoverability session，不作虚假升级。formal journal=`2791`（2300 baseline + 491 live），
`gen_coverage.py --check`=`848 rows / 558 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立复审
ack 后 `alarms.py check` clean。批次五十三已达到=`50/50`，统一长门禁已通过并提交；完整证据=
`testend/rig/formal-evidence/batch-53-unified-gate-20260825.md`。下一前线=`EDGE-062`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-060 lifecycleResync 六处配对

notifications 流的 410 缺口现在由六类生命周期消费者各自回答：chat rail、对话头、实体列表、实体详情、
Library 文档树和 Skill 列表均订阅同一 `lifecycleResync()`；文档树与 Skill 复用 400ms 去抖，列表/详情/头部
走 provider 重取。源码守卫会拒绝未来只订 `lifecycleSignals()` 不订同流 resync 的消费者。定向 Flutter 守卫、
对话 rail 410 行为、对话头、实体列表/详情和 Library 测试共 `115 passed`。

正式证据=`testend/rig/formal-evidence/EDGE-060-lifecycle-resync-six-pairing-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-060-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge060-lifecycle-resync-six-pairing`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：没有独立 formal rig
五通道、逐帧时延、视觉或 discoverability session，不作虚假升级。formal journal=`2786`（2300 baseline + 486 live），
`gen_coverage.py --check`=`848 rows / 557 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立复审
ack 后 `alarms.py check` clean。当前批次=`45/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-061`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-059 ephemeral delta 丢弃不背压

真实 stream Bus 测试对一个只连接不读取的订阅者发布 100,000 个 ephemeral delta；洪峰在 2 秒守卫内完成，
满 channel 时 delta 被丢弃而不是反压生产者。随后发布 durable frame 仍得到 seq 1，证明 ephemeral 不占 durable
序列、不进 replay ring。普通、focused `-race` 与完整 stream 包全绿，无 stop-and-fix。

正式证据=`testend/rig/formal-evidence/EDGE-059-ephemeral-delta-drop-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-059-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge059-ephemeral-delta-drop`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App 五通道、
帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2781`（2300 baseline + 481 live），
`gen_coverage.py --check`=`848 rows / 556 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`40/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-060`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-058 durable buffer 满断开卡死订阅者

真实 stream Bus 测试建立一个只连接不读取的订阅者，灌入 `bufSize + subscriberHeadroom + 10` 个 durable frame。
发布方在 3 秒守卫内完成，满载订阅者被断开，没有长期持有 workspace fan-out mutex；取消路径仍幂等。普通、focused
`-race` 与完整 stream 包全绿，无 stop-and-fix。

正式证据=`testend/rig/formal-evidence/EDGE-058-durable-buffer-wedged-subscriber-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-058-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge058-durable-buffer-wedged-subscriber`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2776`（2300 baseline + 476 live），
`gen_coverage.py --check`=`848 rows / 555 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`35/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-059`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-057 续传游标三来源

真实 stream handler 测试覆盖所有 cursor 来源与优先级：合法 `Last-Event-ID` header 优先于 `fromSeq` query，
header 缺失时使用 query，缺失或非法值归零为 `0`（仅实时、不 replay）；同一 handler 也把环外 cursor 映射为
HTTP 410。普通、focused `-race` 与完整 handlers 包全绿，无 stop-and-fix。

正式证据=`testend/rig/formal-evidence/EDGE-057-sse-cursor-sources-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-057-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge057-sse-cursor-sources`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App 五通道、帧时延、
视觉或导航证据；各 na 理由已落盘。formal journal=`2771`（2300 baseline + 471 live），
`gen_coverage.py --check`=`848 rows / 554 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`30/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-058`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-056 SSE 410 SEQ_TOO_OLD 重放

backend Bus 单测在小 replay ring 中证明旧 cursor 返回 `ErrSeqTooOld`；真实 HTTP/SSE 场景灌满生产环后，
使用已淘汰 cursor 重连得到 `410 Gone + SEQ_TOO_OLD`，transport 没有静默从未知位置继续。L1 通过；没有独立
formal rig 五通道 session，因此 L2-L5 严格记 `na`，不把 targeted harness 结果冒充完整观察链。普通、focused
`-race`、完整 stream 包与 targeted e2e 全绿，无 stop-and-fix。

正式证据=`testend/rig/formal-evidence/EDGE-056-sse-seq-too-old-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-056-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge056-sse-seq-too-old`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App 五通道、
帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2766`（2300 baseline + 466 live），
`gen_coverage.py --check`=`848 rows / 553 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`25/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-057`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-055 最近 2 条 message 的 durable 底线

真实 context-manager 入口收到恰好两条、且都远超触发估算的 durable message。持久化 compaction 遵守最近
两条逐字底线：不写 summary、不归档、不落 compaction anchor、不 demote，两个 block 都保持 hot；独立的
continuation-checkpoint 投影测试同时通过，证明 loop 仍可在内存 prompt 层收缩而不削弱 durable 底线。普通、focused
`-race` 与完整 contextmgr 包全绿，无 stop-and-fix。

正式证据=`testend/rig/formal-evidence/EDGE-055-recent-two-durable-floor-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-055-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge055-recent-two-durable-floor`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2761`（2300 baseline + 461 live），
`gen_coverage.py --check`=`848 rows / 552 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`20/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-056`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-054 附件跨压缩水位

真实 `MaybeCompact` 路径收到一个携带原生附件引用的旧 user 回合；因原生媒体不适用文本 bytes/token
估算，该回合被强制跨过压缩水位。summary 输入保留 opaque attachment ID，旧 block 归档，后续 agent 获得
诚实的 `read_attachment` 重读路线，而不是编造媒体细节或无限重放原生内容。普通、focused `-race` 与完整
contextmgr 包全绿，无 stop-and-fix。

正式证据=`testend/rig/formal-evidence/EDGE-054-attachment-across-compaction-watermark-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-054-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge054-attachment-across-compaction-watermark`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2756`（2300 baseline + 456 live），
`gen_coverage.py --check`=`848 rows / 551 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`15/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-055`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-053 demote 只动 tool_result

真实 context-manager demotion 收到一个混合长回合：同一 assistant message 含解释文本与 16 个 tool-result，
更早 user message 含大段粘贴。demote 只按新旧给 tool-result 分配 hot/warm/cold；user 粘贴与 assistant 解释
逐字不变、仍为 hot，且没有进入 context-role update。普通、focused `-race` 与完整 contextmgr 包全绿，无 stop-and-fix。

正式证据=`testend/rig/formal-evidence/EDGE-053-demote-only-tool-results-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-053-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge053-demote-only-tool-results`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2751`（2300 baseline + 451 live），
`gen_coverage.py --check`=`848 rows / 550 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`10/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-054`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-052 压缩读过滤被取代回合

真实 `MaybeCompact` 入口收到一条旧 assistant（`superseded_by` 指向当前 assistant）与当前版本。
当前版本进入最老非保护压缩窗口；utility summary prompt 含当前回答、不含旧回答，水位推进到当前 block。
这证明压缩读与 LLM 使用同一现行版本投影，旧 retry 回答不会经 summary 回流到后续 prompt。普通、focused
`-race` 与完整 contextmgr 包全绿，无 stop-and-fix。

正式证据=`testend/rig/formal-evidence/EDGE-052-compaction-filters-superseded-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-052-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge052-compaction-filters-superseded`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2746`（2300 baseline + 446 live），
`gen_coverage.py --check`=`848 rows / 549 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`5/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-053`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-051 压缩水位幂等键

contextmgr 测试模拟进程在 `SetSummary` 已持久化新 summary/watermark、但 archive 标记与 compaction
锚尚未写入时崩溃。恢复后的新 service 以 watermark 为真相，跳过已覆盖 block，不再调用第二次摘要，
也不重复 archive/anchor；fixture 中仍为 hot 的旧 block 证明幂等性不依赖 backstop 已完成。普通、focused
`-race` 与完整 contextmgr 包全绿，无 stop-and-fix。

正式证据=`testend/rig/formal-evidence/EDGE-051-compaction-watermark-idempotency-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-051-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge051-compaction-watermark-idempotency`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2741`（2300 baseline + 441 live），
`gen_coverage.py --check`=`848 rows / 548 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。统一长门禁证据=`testend/rig/formal-evidence/batch-52-unified-gate-20260825.md`：
根 `make verify`、完整 `backend testend=327.911s`、rig=`51/51`、docs、清册、锚点、警报、格式、diff 与进程收台审计
全部通过。当前批次=`50/50`，门禁已通过并提交=`8ed36a5e`；下一前线=`EDGE-052`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-050 fork 血缘源被删

真实 SQLite conversation service 先创建 source，再建立带切点血缘的 fork，随后软删除 source。
source GET 诚实返回 `ErrNotFound`；fork 仍可读，`ForkedFromConversationID` 与 `ForkedFromMessageID` 两列
保留历史 source/message ID，列表只显示存活 fork。没有外键级联，也没有为了美化而改写历史指针。
普通、focused `-race` 与完整 conversation 包全绿，无 stop-and-fix。

正式证据=`testend/rig/formal-evidence/EDGE-050-fork-source-deleted-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-050-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge050-fork-source-deleted`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2736`（2300 baseline + 436 live），
`gen_coverage.py --check`=`848 rows / 547 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`45/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-051`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-049 fork parent_block_id 跨消息 remap

真实 messages store fixture 在一个 assistant message 的 tool-call block 下，跨下一条 message
构造 subagent 子树；其 block 级 `parent_block_id` 与 message 级 `attrs.parentBlockId` 都指向源 block。
fork 预铸全部新 block ID 后再写入，两个父指针都 remap 到 fork 自己的 tool-call，block seq 连续重排，
源树不变且没有指针逃出 fork 的 block ID 闭包。普通、focused `-race` 与完整 chat 包全绿，无 stop-and-fix。

正式证据=`testend/rig/formal-evidence/EDGE-049-fork-parent-block-remap-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-049-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge049-fork-parent-block-remap`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2731`（2300 baseline + 431 live），
`gen_coverage.py --check`=`848 rows / 546 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`40/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-050`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-048 fork 版本指针 remap

真实 SQLite fork fixture 构造一条已重试线程：旧 assistant 的 `superseded_by` 指向新 assistant，
新 assistant 的 `attrs.retryOf` 指回旧 assistant。完整 fork 将两个指针都重映射到 fork 自己的 message ID，
且 fork 的 LLM 投影只保留当前答案；切在旧版本时，窗口外取代者被切掉，旧行的 `superseded_by` 清零，
窗口外目标的 `retryOf` 丢弃，没有源线程悬空引用。普通与 focused `-race` 全绿，无 stop-and-fix。

正式证据=`testend/rig/formal-evidence/EDGE-048-fork-version-pointer-remap-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-048-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge048-fork-version-pointer-remap`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2726`（2300 baseline + 426 live），
`gen_coverage.py --check`=`848 rows / 545 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`35/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-049`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-047 fork 切在水位之前不带 summary

真实 fork fixture/store 在 summary watermark 覆盖范围之前切分；fork 同时丢弃 summary 与 `summaryCoversUpToSeq`，LLM 只看到自身前缀，不收到描述不存在历史的摘要。普通、focused `-race` 与完整 chat 包全绿，无 stop-and-fix。

正式证据=`testend/rig/formal-evidence/EDGE-047-fork-summary-drop-before-watermark-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-047-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge047-fork-summary-drop-before-watermark`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2721`（2300 baseline + 421 live），
`gen_coverage.py --check`=`848 rows / 544 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`30/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-048`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-046 fork summary 水位重定基

真实 messages store/fork service 在摘要水位之后切分已压缩线程；fork 携带摘要，并把 `summaryCoversUpToSeq` 重定基到 fork 自己的 block 序列，LLM 投影准确隐藏摘要已覆盖的块，不继承源线程坐标。普通、focused `-race` 与完整 chat 包全绿，无 stop-and-fix。

正式证据=`testend/rig/formal-evidence/EDGE-046-fork-summary-rebase-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-046-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge046-fork-summary-rebase`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2716`（2300 baseline + 416 live），
`gen_coverage.py --check`=`848 rows / 543 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`25/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-047`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-045 retry 的 modelOverride 逐回合

真实 chat service 的 recording resolver 记录三次生成：首轮普通消息使用线程默认，retry 使用显式 per-turn model override，下一轮普通消息再次使用线程默认；retry 行记录真实 override model id，conversation head 未被改写。普通、focused `-race` 与完整 chat 包全绿，无 stop-and-fix。

正式证据=`testend/rig/formal-evidence/EDGE-045-retry-model-override-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-045-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge045-retry-model-override`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2711`（2300 baseline + 411 live），
`gen_coverage.py --check`=`848 rows / 542 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`20/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-046`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-044 retry 非终态尾巴

内存与耐久两道 retry 闸均已验证：阻塞 provider 让 conversation queue 正在生成时，retry 立即返回 `STREAM_IN_PROGRESS`；真实 messages store
构造 crash-shaped `streaming` assistant 尾巴时，retry 同样从耐久状态拒绝。两路径都不追加 user/assistant，原线程保持不变。普通、focused `-race`
与完整 chat 包全绿，无 stop-and-fix。

正式证据=`testend/rig/formal-evidence/EDGE-044-retry-nonterminal-tail-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-044-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge044-retry-nonterminal-tail`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2706`（2300 baseline + 406 live），
`gen_coverage.py --check`=`848 rows / 541 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`15/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-045`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-043 retry 写序中断留重复问句

真实 messages store 在编辑重发「新 user 已提交、旧 `superseded_by` 指针写入失败」的窗口注入故障；retry 返回写入错误，但耐久历史仍保留原 user、原回答和编辑后 user，LLM 视图同时保留两种问句与旧回答，符合可见重复/后续自我修正而非静默丢交流。普通、focused `-race` 与完整 chat 包全绿，无 stop-and-fix。

正式证据=`testend/rig/formal-evidence/EDGE-043-retry-write-order-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-043-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge043-retry-write-order`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2701`（2300 baseline + 401 live），
`gen_coverage.py --check`=`848 rows / 540 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`10/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-044`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-042 retry 尾巴是无回答的 user 行

真实 chat service + messages store 构造进程在 assistant 行铸出前崩溃的 user-only 尾巴，运行 boot `SweepOrphans` 后执行空 payload retry；retry
自然入既有 queue 产出缺失回答，不写第二条 user，不伪造 `retryOf`，耐久线程恰为一个 user + 一个 recovered assistant，LLM 视图同时保留问题和恢复答案。
普通、focused `-race` 与完整 chat 包全绿，无 stop-and-fix。

正式证据=`testend/rig/formal-evidence/EDGE-042-retry-bare-user-tail-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-042-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge042-retry-bare-user-tail`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2696`（2300 baseline + 396 live），
`gen_coverage.py --check`=`848 rows / 539 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`5/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-043`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-041 retryOf 在 close 快照里

retry assistant 的 `message_stop` close 快照经真实 JSON payload 带有 `retryOf` 指针；只凭 close 快照即可让晚连客户端或 410 replay 后的客户端重建
版本链，普通回合的 close 则不带该指针。对应 open-frame companion、普通和 `go test -race` focused 全绿，无实现 stop-and-fix。

正式证据=`testend/rig/formal-evidence/EDGE-041-retry-close-snapshot-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-041-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge041-retry-close-snapshot`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2691`（2300 baseline + 391 live），
`gen_coverage.py --check`=`848 rows / 538 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。批次统一长门禁记录=`testend/rig/formal-evidence/batch-51-unified-gate-20260825.md`，根 `make verify`、完整
backend `testend=274.381s`、rig=`51/51`、docs、清册、锚点、警报、格式、diff 和进程收台审计全绿。当前批次=`50/50`，门禁已通过，待提交；下一前线暂不推进。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-040 superseded 指针只挡 LLM 视图

真实 chat service + 真实 messages store 完成首轮、空 payload retry 和一条后续普通回合。旧 assistant 行仍可由普通 newest-first
分页经 older cursor 找回，`around=<oldId>` 仍以旧行作目标并保留当前版本，窗口的 `newerCursor` 经 `dir=newer` 继续到更晚回合；只有
`LoadThreadForLLM` 隐去被取代正文。普通、focused `-race` 与完整 chat 包全绿。测试首稿错误假设两行记录也应有 newer cursor，触发后停下修正为增加
真实后续回合后再测，不把不存在的游标当契约。

正式证据=`testend/rig/formal-evidence/EDGE-040-superseded-reads-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-040-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge040-superseded-reads`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2686`（2300 baseline + 386 live），
`gen_coverage.py --check`=`848 rows / 537 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`45/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-041`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-039 `:retry` 编辑重发分支

非空 retry payload 同时 supersede 原 user 与 assistant，落一条编辑后的 user（保留原附件 id），生成替代回答；耐久历史保留所有版本，
LLM 投影只读编辑后的回合，且刻意不继承旧 @ mention snapshot。普通与 `go test -race` focused 全绿，没有 stop-and-fix 代码缺陷。

正式证据=`testend/rig/formal-evidence/EDGE-039-retry-edit-resend-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-039-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge039-retry-edit-resend`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2681`（2300 baseline + 381 live），
`gen_coverage.py --check`=`848 rows / 536 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`40/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-040`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-038 `:retry` 重生成分支

空 `RetryInput` 的重生成分支只 supersede 末 assistant，旧回答和 blocks 仍从 durable store 可读，不写第二条 user 问题，新回答走既有
conversation queue，LLM 视图只见现行版本。普通与 `go test -race` focused 全绿，没有 stop-and-fix 代码缺陷。

正式证据=`testend/rig/formal-evidence/EDGE-038-retry-regenerate-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-038-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge038-retry-regenerate`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2676`（2300 baseline + 376 live），
`gen_coverage.py --check`=`848 rows / 535 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`35/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-039`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-037 归档对话发消息自动解档

新增 chat service 回归覆盖归档线程发消息的两个路径：`Send` 先尝试 `Unarchive`，解档成功后照常生成；解档返回错误时按软失败处理，
消息仍落盘并完成 assistant 终态、发出 close。普通与 `go test -race` focused 全绿，没有 stop-and-fix 代码缺陷。

正式证据=`testend/rig/formal-evidence/EDGE-037-archived-send-unarchive-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-037-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge037-archived-send-unarchive`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2671`（2300 baseline + 371 live），
`gen_coverage.py --check`=`848 rows / 534 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`30/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-038`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-036 只发生过一轮的对话标题丢失

本条发现并修复真实产品缺口：原实现 `SetAutoTitle` 首次失败就返回，一条只发生一轮的对话可能永久显示 `New chat`。现在保留已经
生成的标题，在 detached lifecycle 中做一次有界重试，每次使用新的持久化预算；测试构造第一次失败、第二次成功，确认复用同一标题且
没有第二次模型生成。完整 `go test ./internal/app/chat` 与 `go test -race ./internal/app/chat` 全绿，没有遗留 stop-and-fix。

正式证据=`testend/rig/formal-evidence/EDGE-036-autotitle-single-turn-retry-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-036-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge036-autotitle-single-turn-retry`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2666`（2300 baseline + 366 live），
`gen_coverage.py --check`=`848 rows / 533 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`25/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-037`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-035 自动标题双预算

现有回归将慢标题生成预算缩短，并让 provider 每次调用都无视取消、吃完整个生成预算；标题已经生成后，仍通过从 detached
lifecycle context 新取的五秒持久化预算写入，而不是继承已经耗尽的生成 context。普通与 `go test -race` focused 全绿，没有 stop-and-fix
代码缺陷。

正式证据=`testend/rig/formal-evidence/EDGE-035-autotitle-dual-budget-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-035-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge035-autotitle-dual-budget`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2661`（2300 baseline + 361 live），
`gen_coverage.py --check`=`848 rows / 532 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`20/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-036`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-034 硬崩溃孤儿回合清扫

以硬崩溃后的真实数据形状播种 `pending` 与 `streaming` assistant 行，并在其中一条挂载 streaming block；boot 对账入口
`SweepOrphans` 逐 workspace 执行后，两种 message 都变为 `cancelled/StopReasonCancelled`，streaming block 同步变为 cancelled，
另一 workspace 的同形状孤儿保持不变。普通与 `go test -race` focused 全绿，没有 stop-and-fix 代码缺陷。

正式证据=`testend/rig/formal-evidence/EDGE-034-sweep-orphans-workspace-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-034-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge034-sweep-orphans-workspace`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2656`（2300 baseline + 356 live），
`gen_coverage.py --check`=`848 rows / 531 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`15/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-035`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-033 关页不留 streaming 孤儿

新增真实 chat service 取消回归：provider 已进入流式后调用 conversation cancel，等待 durable `message_stop`，从 store 读回 assistant
必须是 `cancelled/StopReasonCancelled`，且队列不再报告 active generation。`WriteFinalize` 在 detached workspace/conversation context
上执行，客户端离开不会把 streaming 行遗留在盘上。普通与 `go test -race` focused 全绿，没有 stop-and-fix 代码缺陷。

正式证据=`testend/rig/formal-evidence/EDGE-033-cancel-stream-finalize-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-033-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge033-cancel-stream-finalize`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2651`（2300 baseline + 351 live），
`gen_coverage.py --check`=`848 rows / 530 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`10/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-034`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-032 convQueue 5 分钟自毁后重建

生产队列仍以五分钟为空闲拆卸策略；本轮通过未导出测试 seam 将该策略缩短，仅为确定性验证：首个回合完成后等待队列从 registry
消失，再次 Send 必须创建新队列并落 `message_stop`。拆卸和投递继续共用 `q.mu`，不会把任务投进无人消费的死 channel。测试先发现两处
收尾 timer reset 写死生产常量，已修为复用当前队列采用的 timeout；生产默认行为不变。普通与 `go test -race ./internal/app/chat`
全绿，没有遗留 stop-and-fix。

正式证据=`testend/rig/formal-evidence/EDGE-032-convqueue-idle-recreate-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-032-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge032-convqueue-idle-recreate`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2646`（2300 baseline + 346 live），
`gen_coverage.py --check`=`848 rows / 529 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。当前批次=`5/50`，未满 50 格不跑统一长门禁、不提交。下一前线=`EDGE-033`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-031 回合收尾期单槽缓冲

assistant 可见收尾后，慢速同步 compaction 仍在进行；此时 running 已释放，后续一条 Send 允许进入单槽，
但不会在 compaction 完成前启动，释放后才继续执行，从而兼顾用户响应与 summary/history 写入不竞态。
新增 blocking compactor 与 provider entry 双屏障回归，普通与 `go test -race` 全绿，没有 stop-and-fix 代码缺陷。

正式证据=`testend/rig/formal-evidence/EDGE-031-compaction-single-slot-buffer-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-031-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge031-compaction-single-slot-buffer`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2641`（2300 baseline + 341 live），
`gen_coverage.py --check`=`848 rows / 528 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。批次五十=`50/50`；统一长门禁证据=`testend/rig/formal-evidence/batch-50-unified-gate-20260825.md`：
`make verify`、完整 `make -C backend testend`（266.081s）、rig 51 tests、脚本/格式/清册/锚点/警报和进程审计全绿；
本批随后提交。下一前线=`EDGE-032`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-030 生成中再 Send

当第一条 assistant turn 已真实进入 provider stream 后，同一对话的下一条 Send 立即返回
`STREAM_IN_PROGRESS`，不背着用户排到 active turn 后面。将原先“多次尝试直到最终拒绝”的宽松回归改成
entry barrier 后精确发送一条并断言立即拒绝；普通与 `go test -race` 全绿，没有 stop-and-fix 代码缺陷。

正式证据=`testend/rig/formal-evidence/EDGE-030-send-while-generating-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-030-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge030-send-while-generating`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App 五通道、
帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2636`（2300 baseline + 336 live），
`gen_coverage.py --check`=`848 rows / 527 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。批次五十=`45/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-031`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-029 重复 resolve interaction

真实 chat interaction 首次 resolve 完成后，再次对同一 conversation/toolCallId resolve 会返回稳定的
`NO_PENDING_INTERACTION`，不会重放答案、重新打开交互或发生第二次状态转移；broker 层 unknown/already-resolved
也保持安全 no-op。新增 chat service 重复决议回归，普通与 `go test -race` 全绿，没有 stop-and-fix 代码缺陷。

正式证据=`testend/rig/formal-evidence/EDGE-029-duplicate-resolve-interaction-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-029-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge029-duplicate-resolve-interaction`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2631`（2300 baseline + 331 live），
`gen_coverage.py --check`=`848 rows / 526 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。批次五十=`40/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-030`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-028 interaction 枚举外 action

resolve interaction 收到拼错的 `aprove` 等枚举外 action 时，在查 conversation 或 pending tool call 之前
直接返回稳定的 `INTERACTION_INVALID_ACTION`，并在结构化 details 中暴露完整合法集合
`approve / approve_always / deny / accept / decline`；不会把用户本想批准的危险调用静默解释为 deny。
新增 chat service 回归验证 wire code 与五项 `validActions`，普通与 `go test -race` 全绿，没有 stop-and-fix
代码缺陷。

正式证据=`testend/rig/formal-evidence/EDGE-028-invalid-interaction-action-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-028-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge028-invalid-interaction-action`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2626`（2300 baseline + 326 live），
`gen_coverage.py --check`=`848 rows / 525 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。批次五十=`35/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-029`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-027 ask_user 无交互用户

在 workflow/agent 等无 humanloop broker 的非交互 context 中，`ask_user` 立即返回稳定的
`ASK_NO_INTERACTIVE_USER` unavailable sentinel，不永久等待不存在的用户，也不伪造回答，让模型可以得到
明确结果后自行改道。新增 ask tool focused/race 回归，普通与 race 全绿，没有 stop-and-fix 代码缺陷。

正式证据=`testend/rig/formal-evidence/EDGE-027-ask-no-interactive-user-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-027-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge027-ask-no-interactive-user`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App 五通道、
帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2621`（2300 baseline + 321 live），
`gen_coverage.py --check`=`848 rows / 524 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。批次五十=`30/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-028`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-026 allowed-tools 变更重置信任门

installed skill 更新时，`allowed-tools` 集合改变会将信任门重置，旧授权不会带到新的 requested grant；若
只改正文/description 而 allowed-tools 不变，已有用户授权继续有效；local drift 在非 force 更新时仍先拒绝。
现有 skill update 回归普通与 `go test -race` 全绿，没有 stop-and-fix 代码缺陷。

正式证据=`testend/rig/formal-evidence/EDGE-026-skill-allowed-tools-reset-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-026-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge026-skill-allowed-tools-reset`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App 五通道、
帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2616`（2300 baseline + 316 live），
`gen_coverage.py --check`=`848 rows / 523 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。批次五十=`25/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-027`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-025 skill 信任门未批时预授权为空

installed skill 的 `allowed-tools` 是用户尚未批准的 requested grant，不是安装即生效的权限。未执行
`:approve-tools` 时，激活仍注入正文、记录 active skill 名称，但 agent state 的预授权集为空，危险工具仍
走逐次人闸；显式批准后才安装预授权。现有 skill trust gate 与 loop gate 回归普通/race 全绿，没有
stop-and-fix 代码缺陷。

正式证据=`testend/rig/formal-evidence/EDGE-025-skill-trust-gate-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-025-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge025-skill-trust-gate`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App 五通道、
帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2611`（2300 baseline + 311 live），
`gen_coverage.py --check`=`848 rows / 522 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。批次五十=`20/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-026`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-024 驻地只闸写不闸读

驻地是 zoom、不是 jail：挂载 conversation work directory 后，Read 与 Grep 读取驻地外绝对路径仍直接执行，
不弹 humanloop，不把用户的观察范围错误收窄。扩展现有 workdir gate 回归同时覆盖两个非写工具，普通与
`go test -race` 全绿，没有 stop-and-fix 代码缺陷。

正式证据=`testend/rig/formal-evidence/EDGE-024-read-outside-workdir-no-gate-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-024-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge024-read-outside-workdir-no-gate`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2606`（2300 baseline + 306 live），
`gen_coverage.py --check`=`848 rows / 521 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。批次五十=`15/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-025`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-023 越界判定路径解不开

首轮复核发现真实缺口：驻地下 `Write` args 畸形或缺 `file_path` 时，旧实现会因无法判定越界而让 safe
自报静默通过；且畸形 `json.RawMessage` 会让批准 prompt 序列化失败。stop-and-fix 增加“目标不可判定”
独立状态：先走普通 danger 闸、不错误标成 `outsideWorkDir`；合法参数保持结构化，非法 JSON 以原始字符串
显示；批准后真实 Write validator 返回 `file_path is required`，不产生成功副作用。新增 focused/race 回归，
全绿。

正式证据=`testend/rig/formal-evidence/EDGE-023-undeterminable-workdir-target-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-023-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge023-undeterminable-workdir-target`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App
五通道、帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2601`（2300 baseline + 301 live），
`gen_coverage.py --check`=`848 rows / 520 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。批次五十=`10/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-024`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-022 驻地越界写人闸

挂载 conversation work directory 后，`Write` 即使自报 `danger=safe`，只要目标路径解析后位于驻地之外，
就必须经过 humanloop；提示载荷明确带 `outsideWorkDir:true`，拒绝时工具不执行。`approve_always` 与 active
skill `allowed-tools` 预授权都不能绕过这一事实闸；驻地内的 safe write 仍不额外设闸。现有 workdir gate
测试族普通与 `go test -race` 全绿，没有 stop-and-fix 代码缺陷。

正式证据=`testend/rig/formal-evidence/EDGE-022-outside-workdir-gate-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-022-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge022-outside-workdir-gate`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App 五通道、
帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2596`（2300 baseline + 296 live），
`gen_coverage.py --check`=`848 rows / 519 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。批次五十=`5/50`，未满 50 格不跑统一长门禁、不提交；下一前线=`EDGE-023`。
P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-021 白名单随对话删除清除

`chat.Service.ForgetConversation` 是 conversation-delete cascade 的实际生命周期钩子：它清掉被删除对话的
全部 `approve_always` 授权，同时保留其他存活对话的授权。新增 chat hook 回归，并与 humanloop broker 的
prefix 清理测试一起通过普通与 `go test -race`；没有发现需 stop-and-fix 的实现缺陷。

正式证据=`testend/rig/formal-evidence/EDGE-021-forget-conversation-grants-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-021-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge021-forget-clears-grants`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App 五通道、
帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2591`（2300 baseline + 291 live），
`gen_coverage.py --check`=`848 rows / 518 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。批次四十九=`50/50`，统一长门禁证据=`testend/rig/formal-evidence/batch-49-unified-gate-20260825.md`：
`make verify`、完整 `make -C backend testend`（270.240s）、rig 51 tests、脚本/格式/清册/锚点/警报和进程审计全绿；
本批随后提交。下一前线=`EDGE-022`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-020 approve_always 会话白名单

`approve_always` 只写入 broker 的 `(conversationID, tool)` 授权键：第一次危险调用仍经过 interaction，同一
会话再次调用同一工具不再弹闸，但换工具或换会话都必须建立自己的批准；越界驻地写的事实闸仍不可豁免。
新增 loop gate 回归实际走过三条路径并通过 race：同键一次批准后直通、换工具重新询问、换会话重新询问，
没有 stop-and-fix 代码缺陷。

正式证据=`testend/rig/formal-evidence/EDGE-020-approve-always-scope-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-020-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge020-approve-always-scope`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App 五通道、
帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2586`（2300 baseline + 286 live），
`gen_coverage.py --check`=`848 rows / 517 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。批次四十九=`45/50`，未满 50 格不跑统一长门禁、不提交；sequence gate
下一前线=`EDGE-021`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-019 危险工具人闸阻塞

`dispatchWithGate` 在执行前验证输入并计算有效 danger；dangerous 调用在 broker interaction 未得到明确
approve/approve_always 前阻塞，工具不发生副作用。interaction 由 surface 暴露，deny 或非法 action 不执行；
静态 `DangerFloorer` 仍可将模型自报 safe 的真实不可逆/花费操作抬回 dangerous。新增时序回归先等待
interaction、确认工具未执行，再 approve 后确认执行；相关 loop/race 全绿，没有 stop-and-fix 代码缺陷。

正式证据=`testend/rig/formal-evidence/EDGE-019-danger-gate-blocking-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-019-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge019-danger-gate-blocking`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App 五通道、
帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2581`（2300 baseline + 281 live），
`gen_coverage.py --check`=`848 rows / 516 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。批次四十九=`40/50`，未满 50 格不跑统一长门禁、不提交；sequence gate
下一前线=`EDGE-020`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-018 sanitizer 孤儿 tool_call 补 stub

发送 provider request 前，`SanitizeMessages` 维护 assistant `tool_calls` 与 tool messages 的配对：已完成的
tool result 原样保留；取消或缺失的 call 按原始顺序补带 interrupted marker 的 stub；没有对应 assistant 的
stray tool result 丢弃。新增多调用批次回归锁住“一个完成、一个取消、后续 user 消息继续存在”，并通过相关
provider 回归与 `go test -race`，没有 stop-and-fix 代码缺陷。

正式证据=`testend/rig/formal-evidence/EDGE-018-sanitizer-orphan-tool-call-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-018-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge018-sanitizer-orphan-tool-call`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App 五通道、
帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2576`（2300 baseline + 276 live），
`gen_coverage.py --check`=`848 rows / 515 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。批次四十九=`35/50`，未满 50 格不跑统一长门禁、不提交；sequence gate
下一前线=`EDGE-019`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-017 DeepSeek 全文本 parts 坍缩

DeepSeek-compatible wire 在 user message 没有媒体幸存时，将全部文本 parts 按 `\n\n` 顺序拼成 JSON string
`content`；有媒体时仍保留原生 parts array。这样附件在无 vision 模型上降级成文本占位后，冻结历史每次
重放仍走 text-only wire，不会因 array-form content 反复 400。新增回归直接解析实际 request body，断言 content
类型、顺序和精确分隔符；普通测试与 `go test -race` 全绿，没有 stop-and-fix 代码缺陷。

正式证据=`testend/rig/formal-evidence/EDGE-017-deepseek-text-parts-collapse-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-017-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge017-deepseek-text-parts-collapse`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App 五通道、
帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2571`（2300 baseline + 271 live），
`gen_coverage.py --check`=`848 rows / 514 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。批次四十九=`30/50`，未满 50 格不跑统一长门禁、不提交；sequence gate
下一前线=`EDGE-018`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-016 生成族产地过滤

MediaRef collector 不再读取 `source` 做 producer veto；`generate_image` 的 receipt 与 function/MCP artifact
一样进入 MediaExpander，并按 producing tool call 分组。生成工具结果仍只携带 receipt，字节由附件消费咽喉
按模型能力和信封决定。该行为遵循 ADR 0020，避免模型看不到刚生成的媒体而重复生成。现有 loop/mediaref
回归覆盖生成来源、同轮原生媒体和调用归属，普通测试与 `go test -race` 全绿，没有 stop-and-fix 代码缺陷。

正式证据=`testend/rig/formal-evidence/EDGE-016-generation-no-producer-veto-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-016-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge016-generation-no-producer-veto`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App 五通道、
帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2566`（2300 baseline + 266 live），
`gen_coverage.py --check`=`848 rows / 513 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。批次四十九=`25/50`，未满 50 格不跑统一长门禁、不提交；sequence gate
下一前线=`EDGE-017`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-015 MCP 非纯 JSON 结果里的 receipt

MCP 媒体工具结果可能是 `[image: image/png]` 占位文本加换行后的 JSON receipt，不能以“整段先解析成 JSON”
作为媒体入口。loop 对非 JSON 结果保留文本，再由 `mediaref.Collect` 解析嵌入对象；只接受合法
`attachmentId=att_<16hex>`，并按 producing tool call 分组。新增回归使用真实混合形状，既有 collector 回归
继续锁住散文/代码块 receipt、伪造 id、去重和封顶；普通测试与 `go test -race` 全绿，没有 stop-and-fix
代码缺陷。

正式证据=`testend/rig/formal-evidence/EDGE-015-mcp-embedded-receipt-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-015-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge015-mcp-embedded-receipt`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App 五通道、
帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2561`（2300 baseline + 261 live），
`gen_coverage.py --check`=`848 rows / 512 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。批次四十九=`20/50`，未满 50 格不跑统一长门禁、不提交；sequence gate
下一前线=`EDGE-016`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-014 MediaExpander 当轮回喂

loop 对 tool result 中的 MediaRef 按 producing tool call 分组，经可选 `MediaExpander` 只追加到下一次
provider request 的原生 content parts；首次请求不带媒体，生成图与 function/MCP 产物共用同一消费咽喉。
无 expander 或模型不支持模态时保留文本 receipt，诚实降级。临时 user 消息不进入 `allBlocks`，不会写入
`WriteFinalize`。新增回归锁住首次/后续 request、产地归属、无媒体不展开和 finalized blocks 隔离；普通测试与
`go test -race` 全绿，没有 stop-and-fix 代码缺陷。

正式证据=`testend/rig/formal-evidence/EDGE-014-media-expander-same-turn-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-014-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge014-media-expander-same-turn`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App 五通道、
帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2556`（2300 baseline + 256 live），
`gen_coverage.py --check`=`848 rows / 511 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。批次四十九=`15/50`，未满 50 格不跑统一长门禁、不提交；sequence gate
下一前线=`EDGE-015`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-013 ObjectMap 字符串化对象参数

静态追踪确认 `run_function.args` 使用公共 `tool.ObjectMap`：原生 JSON object 与一个解码后仍为 object
的 JSON 字符串进入同一张参数 map；数组、数字、普通非 JSON 字符串和字符串化数组明确拒绝，不猜错值。
该边界同时复用于同类 handler/agent object 参数，避免逐工具漂移。新增公共回归覆盖成功的两种编码和四种
错误形状，普通测试与 `go test -race` 全绿；没有 stop-and-fix 代码缺陷。

正式证据=`testend/rig/formal-evidence/EDGE-013-objectmap-stringified-object-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-013-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge013-objectmap-stringified-object`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App 五通道、
帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2551`（2300 baseline + 251 live），
`gen_coverage.py --check`=`848 rows / 510 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。批次四十九=`10/50`，未满 50 格不跑统一长门禁、不提交；sequence gate
下一前线=`EDGE-014`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-012 danger 非枚举值 fail-open

标准字段剥离器对缺失或未知的 `danger`（如 `none`、`nuclear`）回落 `safe`，避免模型协议扩展值意外
打开人闸；但工具声明的静态危险 floor 仍不可绕过，会把非法或 safe 自报抬回真实 `dangerous`。既有
实现符合这条边界，focused tool/loop 回归与 `go test -race` 全绿，没有 stop-and-fix 代码缺陷。

正式证据=`testend/rig/formal-evidence/EDGE-012-invalid-danger-fail-open-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-012-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge012-danger-fail-open`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App 五通道、
帧时延、视觉或导航证据；各 na 理由已落盘。formal journal=`2546`（2300 baseline + 246 live），
`gen_coverage.py --check`=`848 rows / 509 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。新批次四十九=`5/50`，未满 50 格不跑统一长门禁、不提交；sequence gate
下一前线=`EDGE-013`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-011 execution_group 并发与下标拍平

现有 loop 已为每个工具调用预分配下标槽，同一 `execution_group` 由 goroutine 并发执行，完成后按原调用序
拍平。原测试只验证了顺序，没有锁住“真的并发”；已补屏障回归，要求两个同组工具都启动后才释放，并用
Go race detector 验证无竞态。代码行为无须 stop-and-fix，测试把等待时间回归风险固定下来。

正式证据=`testend/rig/formal-evidence/EDGE-011-execution-group-parallel-order-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-011-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge011-parallel-index-order`、`L2=na`、`L3=na`、`L4=na`、`L5=na`：不冒充真实 App 帧、
视觉时延或可发现性旅程；各 na 理由已落盘。formal journal=`2541`（2300 baseline + 241 live），
`gen_coverage.py --check`=`848 rows / 508 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报独立
复审 ack 后 `alarms.py check` clean。批次四十八已达到 `51/50`，统一长门禁现在解锁；P12 的 400+ Journey
继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-010 tool_result 256 KiB 最终硬封顶

静态审阅发现旧实现把截断提示追加在 256 KiB 原文之后，失败工具的错误文本也可能把最终结果再次撑出
上限；这会同时放大持久化、SSE 和当前 prompt。已停止推进并修复：成功结果保留头部并在合法 UTF-8
字符边界截断，失败结果保留输出头部、错误尾部和收窄提示，三者总长度严格不超过
`limits.Tools.ToolResultCapKB`（默认 256 KiB）。后端 loop 回归覆盖成功与“部分输出+错误”两条路径，
前端工具卡已有超长 prose bounded excerpt、截断提示和原始长度回归；loop 全包、工具卡全测、analyzer 全绿。

正式证据=`testend/rig/formal-evidence/EDGE-010-tool-result-cap-investigation-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-010-ledger-alarm-reaudit-20260825.md`。五级严格为
`L1=measure:edge010-tool-result-cap`、`L2=na`、`L3=na`、`L4=E1`、`L5=na`：本条不冒充制造超大结果的
真实五通道 session，L3 也不是时延/动效判据；na 理由已落盘。formal journal=`2536`（2300 baseline +
236 live），`gen_coverage.py --check`=`848 rows / 507 carried judgments / 0 tombstones`，anchors=`10/10`，
统计警报独立复审 ack 后 `alarms.py check` clean。批次四十八由 `41→46/50`，未满 50 格不跑统一长门禁、
不提交；正式 sequence gate 下一前线=`EDGE-011`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-009 Chat 回合总墙钟语义止损修复

产品复核发现 ChatTurnSec 总墙钟虽然能解除 stalled turn，却被共享 loop 归类为普通 `cancelled`；用户
无法知道是系统为保持响应而主动截断，也没有明确下一步。已停止推进并修复：chat 在 context 中标记自身
墙钟，loop 只将 chat-owned `DeadlineExceeded` 落成 `error/CHAT_TURN_TIMEOUT`，用户主动 Cancel 和
其它宿主保持原有 cancelled 语义；终态消息给出发送后续消息或简化任务的可行动提示。错误码表、loop/chat
契约文档同步更新，Flutter transcript 映射本地化提示并隐藏内部码/detail，focused widget 与 chat/loop/
agent/subagent/reqctx focused suites、analyzer 全绿。

正式证据=`testend/rig/formal-evidence/EDGE-009-chat-turn-wall-clock-stop-fix-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-009-ledger-alarm-reaudit-20260825.md`。五级严格为 `L1=E1`、`L2=na`、
`L3=na`、`L4=E1`、`L5=na`：没有等待数分钟的真实五通道 stall session，不冒充现场时序；各 na 理由和
实际终态/视觉证据已落盘。formal journal=`2531`（2300 baseline + 231 live），`gen_coverage.py --check`=
`848 rows / 506 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报经独立复审 ack 后 `alarms.py
check` clean。批次四十八由 `36→41/50`，未满 50 格不跑统一长门禁、不提交；正式 sequence gate 下一前线=
`EDGE-010`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-008 MaxSteps 终态错误用户体验止损修复

产品复核发现 `MAX_STEPS_REACHED` 虽然由 loop 正确写成非成功终态，Chat transcript 的通用分支仍会在
“达到步数上限”后拼接 durable error code 和内部英文 detail；用户看到了实现诊断，却没有得到下一步。
已停止推进并修复：中英文文案明确说明回复因步骤上限暂停，并告诉用户发送后续消息或简化任务继续；
`MAX_STEPS_REACHED` 加入 transcript 的内部码屏蔽映射，focused widget regression 覆盖本条及前两条 loop
终态，断言可行动文案存在且 raw code/detail 不出现；`make -C frontend analyze` 和 Go loop focused suite 全绿。

正式证据=`testend/rig/formal-evidence/EDGE-008-max-steps-ux-stop-fix-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-008-ledger-alarm-reaudit-20260825.md`。本条五级严格为 `L1=E1`、
`L2=na`、`L3=na`、`L4=E1`、`L5=na`：没有稳定真实网关入口制造人为 MaxSteps 上限，不冒充五通道流式时序；
各 na 理由和 L4 实际 transcript 证据已落盘。formal journal=`2526`（2300 baseline + 226 live），
`gen_coverage.py --check`=`848 rows / 505 carried judgments / 0 tombstones`，anchors=`10/10`，统计警报
经独立复审 ack 后 `alarms.py check` clean。批次四十八由 `31→36/50`，未满 50 格不跑统一长门禁、不提交；
正式 sequence gate 下一前线=`EDGE-009`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-007 loop 终态错误用户体验止损修复

产品复核发现 `TOOL_ERROR_STORM` 与 `CONTEXT_INPUT_TOO_LARGE` 虽然由后端正确落成终态，Chat transcript
仍会把 durable error code 和内部 detail 直接拼进主文案；这不符合 CODEX E1 的“解释发生了什么、告诉用户
下一步、隐藏内部实现码”要求。已停止推进并修复：英文/中文文案均改为本地化、可行动提示，分别说明工具连续
失败已暂停并建议检查输入重试，以及内容超出单次处理范围并建议拆分最新附件或内容后重试；新增 focused
widget regression 断言用户文案存在且原始错误码/detail 不出现，`make -C frontend analyze` 全绿。

正式证据=`testend/rig/formal-evidence/EDGE-007-loop-terminal-error-ux-stop-fix-20260825.md`；EDGE-005 的
旧 L4 `na` 已用 `judge.py --revalidate --law E1` 对这次真实产品表面重验为 pass，历史边界与新证据均保留。
EDGE-007 五级严格为 `L1=E1`、`L2=na`、`L3=na`、`L4=E1`、`L5=na`：没有伪造真实五通道 storm session，L4
只基于真实 transcript widget 与 analyzer/regression 证据，逐项理由已落盘。formal journal=`2521`
（2300 baseline + 221 live），`gen_coverage.py --check`=`848 rows / 504 carried judgments / 0 tombstones`，
anchors=`10/10`；统计警报经独立复审 ack 后 `alarms.py check` clean。批次四十八由 `26→31/50`，未满
50 格不跑统一长门禁、不提交；正式 sequence gate 下一前线=`EDGE-008`。P12 的 400+ Journey 继续按用户
裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-006 DeepSeek active tool chain 完整切分

新增回归 `TestDeterministicCheckpointKeepsDeepSeekReasoningToolGroupIntact`，构造旧 group 与活动中的
DeepSeek-like group，执行保留一组的 deterministic emergency checkpoint，断言输出是一个 marker 加一组
完整活动协议：`reasoning_content`、`reasoningSignature`、assistant tool call 的 name/arguments/id 与
对应 `tool_result` 全部保留，切点不落在 assistant/tool group 中间。DeepSeek provider 现有 build/request/
parse/round-trip focused tests 同批通过。

正式调查证据=`testend/rig/formal-evidence/EDGE-006-deepseek-tool-chain-investigation-20260825.md`，账本
警报复审=`testend/rig/formal-evidence/EDGE-006-ledger-alarm-reaudit-20260825.md`。这是模型线缆 prompt 投影
的兼容性不变量，不产生 UI、DB、SSE 或真实网关表面，五级严格为 `L1=measure:deepseek-active-tool-group`、
`L2–L5=na`，理由已逐项落盘。formal journal=`2516`（2300 baseline + 216 live），
`gen_coverage.py --check`=`848 rows / 503 carried judgments / 0 tombstones`，anchors=`10/10`，三条统计
警报经复审 ack 后 `alarms.py check` clean。批次四十八由 `21→26/50`，未满 50 格不跑统一长门禁、不提交；
正式 sequence gate 下一前线=`EDGE-007`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-005 CONTEXT_INPUT_TOO_LARGE 诚实终态

新增回归 `TestRun_ContextOverflowStillTooLargeUsesActionableTerminalCode`，构造“原采样收到
`context_length` 拒绝 → checkpoint 生成成功 → 同一步重试仍收到 `context_length` → 第二个有界恢复周期
结束”的真实 loop 边界。测试锁定实际四次 provider/checkpoint 调用，而不是假设三次；最终 result 和
`WriteFinalize` 都是 `error`，错误码精确为 `CONTEXT_INPUT_TOO_LARGE`，错误提示同时包含不可拆输入的
状态解释和 `split` 下一步，不泄漏成裸 `LLM_STREAM_ERROR`，也不伪装成成功。

loop 与 LLM provider focused regression 全部通过。正式调查证据=
`testend/rig/formal-evidence/EDGE-005-context-too-large-investigation-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-005-ledger-alarm-reaudit-20260825.md`。真实 provider-error 视觉面由
EDGE-001 覆盖，EDGE-002 的 managed 504 仍保留为红边界；本条强制重复 rejection 来自 harness、无独立
UI/视觉/用户入口；EDGE-007 随后发现并修复 transcript 直接泄漏本条 durable code 的问题，故以
`judge.py --revalidate --law E1` 将 L4 从历史 `na` 重验为 `pass`，当前五级为 `L1=E1`、`L2=na`、
`L3=na`、`L4=E1`、`L5=na`，新旧证据均保留。formal journal=`2516`（2300 baseline + 216 live），
`gen_coverage.py --check`=`848 rows / 503 carried judgments / 0 tombstones`，anchors=`10/10`，三条统计
警报经独立复审 ack 后 `alarms.py check` clean。批次四十八仍由 `16→21/50` 表示该格首次入账，重验不
重复计数；正式 sequence gate 下一前线=`EDGE-006`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-004 权威 context_length 透明恢复

现有生产 loop 回归精确覆盖 provider 在尚未产出任何 assistant block 时返回结构化
`context_length` 拒绝：loop 先做隔离的 semantic checkpoint，清理 prompt 视图后重试同一个逻辑采样步，
恢复成功对用户透明，且不泄漏中间 provider error。`TestRun_ProviderContextOverflowCompactsAndRetriesSameStep`
断言了零 block 拒绝、checkpoint 请求不带 tools、重试 prompt 变小且含 continuation checkpoint、总调用数
恰为三次、最终 completed；`TestChat_CompactionWatermark` 与 `TestPromptR6_PostCompactionView` 通过真实
HTTP/SSE 服务，补证 learned overflow budget、durable summary/watermark、压缩后模型视图和最近完整协议组。

loop/contextcheckpoint/contextmgr 定向 Go tests 与上述 testend scenarios 均通过。正式调查证据=
`testend/rig/formal-evidence/EDGE-004-context-overflow-recovery-investigation-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-004-ledger-alarm-reaudit-20260825.md`。真实 managed gateway 在 EDGE-002
观察到的 504 发生在本分支之前，仍保留为红边界，没有被复用。由于本条强制 rejection 来自确定性 harness，
且恢复没有独立 UI、视觉或用户入口，五级严格为 `L1=H3`、`L2–L5=na`，理由已逐项写入证据。formal
journal=`2505`（2300 baseline + 205 live），`gen_coverage.py --check`=`848 rows / 501 carried judgments /
0 tombstones`，anchors=`10/10`，三条统计警报经独立复审 ack 后 `alarms.py check` clean。批次四十八由
`11→16/50`，未满 50 格不跑统一长门禁、不提交；正式 sequence gate 下一前线=`EDGE-005`。P12 的 400+
Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-003 语义压缩双失败后的确定性有损 checkpoint

这是 loop 内部的故障注入边界，不是可由真实网关稳定制造的用户旅程：测试让 Host 提供的
utility compactor 返回错误，再让主模型 checkpoint 请求返回不可重试的 `invalid_request`；同一
逻辑采样步随后必须落到 deterministic emergency checkpoint 并继续完成。新增回归
`TestRun_ContextOverflowFallsBackToDeterministicCheckpointWhenSemanticCompactorsFail`，固定三次
`Stream` 顺序为“原请求 `context_length` 拒绝 → 主模型 checkpoint 拒绝 → 同步骤重试成功”，证明
utility 只调用一次、无无界重试、最终 `completed` 且不向用户泄漏中间错误；重试 prompt 明确含
`context_checkpoint kind="deterministic-emergency"`、`Re-fetch durable tool results`，并保留最新完整
assistant/tool group 的 `new_call` 协议。

loop、contextcheckpoint、contextmgr 定向 Go tests 全部通过。正式调查证据=
`testend/rig/formal-evidence/EDGE-003-deterministic-checkpoint-investigation-20260825.md`，账本警报复审=
`testend/rig/formal-evidence/EDGE-003-ledger-alarm-reaudit-20260825.md`。由于该 checkpoint 只是发送给
模型的内存 prompt 投影，不产生 UI、DB、SSE 或真实网关表面，五级裁决严格记为 `L1=H3`，`L2–L5=na`
并逐项写明理由；没有借用 EDGE-002 的真实 session 冒充本分支的五通道证据。formal journal=`2500`
（2300 baseline + 200 live），`gen_coverage.py --check`=`848 rows / 500 carried judgments / 0 tombstones`，
anchors=`10/10`，两条统计警报经独立复审 ack 后 `alarms.py check` clean。批次四十八由 `6→11/50`，未满
50 格不跑统一长门禁、不提交；正式 sequence gate 下一前线=`EDGE-004`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-002 continuation checkpoint 语义压缩

真实 Flutter App 通过实体选择器选中临时 Function `edge002_checkpoint_chunk`，连续四次真实
调用把大 tool_result 回喂到同一对话；messages/entities/notifications 三路独立 SSE witness
记录了四组配对的 `run_function` 与 `tool_result` durable 帧，App 活动侧显示 `执行 ×4`，没有
孤儿 tool_call。第五次追加请求的 LLM body 达 `1,116,940` bytes，受管网关在 loop 进入 semantic
checkpoint 前返回 plain `error code: 504`；backend 对应 `predicted_input=371722`、
`history_bytes=1051004`、`compaction_mode=""`、无 `cleared_tool_bytes`，该真实边界保留为红证据，
没有冒充压缩成功。App 显示已修复的中英文可行动文案，不泄漏 `LLM_PROVIDER_ERROR` 或上游异常串。

同一生产 loop/context-manager 的黑盒路径补齐核心证明：`TestChat_CompactionWatermark` 与
`TestChatFork_SummaryTwoBranches` 通过，证明结构化 continuation checkpoint 保留最新完整工具组、
不制造悬空 provider 协议、正确持久化 summary/watermark，并只在合法 fork 边界携带摘要；loop、
contextmgr、contextcheckpoint 定向 Go tests 也通过。故五级裁决只在证据明确分层后写入，不将网关
504 改写为绿。

五通道 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-115619`，录屏=`798.073333s`，
backend=`933` 行、SSE=`604` 行、LLM=`40` 行和 frontend=`831` 行 journal 均已封存；`rig-down.sh` 后无残留进程。frontend 中重复的 Flutter `accessibility_bridge` AXTree
行是 Computer Use 快速 AX snapshot churn，和此前已接受的录制 session 同类，未被静默删除，独立
写入证据。临时 Function 已真实 DELETE=204。正式证据=`sessions/20260825-115619/evidence/EDGE-002-five-channel.md`，
账本复审=`testend/rig/formal-evidence/EDGE-002-ledger-reaudit-20260825.md`；五级由 `judge.py`
写入 `G1/F2/A5/C4/G2`，formal journal=`2495`（2300 baseline + 195 live），`gen_coverage.py --check`=
`848 rows / 499 carried judgments / 0 tombstones`，anchors=`10/10`，警报复审 ack 后
`alarms.py check` clean。批次四十八由 `1→6/50`，未满 50 格不跑统一长门禁、不提交；正式 sequence
gate 下一前线=`EDGE-003`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：EDGE-001 上下文水位 80% 的 tool_result marker 机制

真实 Flutter macOS App 在受管 Anselm 网关上建立一次临时 `edge001_context_chunk` function，连续生成
大 tool_result，观察到后端在预测输入约 65.6% 且已越过 80% 编辑触发条件的时序点，实际清掉旧 tool
group 两次(`528723`、`524292` bytes)。独立 LLM tap 的四个真实 chat body 含 7/7/9/9 个 prompt-only
omission marker；最新三组和 reasoning/tool-call 协议仍按完整 group 留在 prompt，durable REST 历史
中 marker 出现 0 次且完整 fixture marker 保留。临时 function 已经真实删除，两个测试对话均收口。

首轮真实画面又抓到一个必须停线修的产品问题：上游 504 的主时间线直接显示
`Something went wrong · LLM_PROVIDER_ERROR · llm: provider error (504)`，违反 E1 的三要素和裸码禁令。
修复前画面作为红证据保留；前端现在对 `LLM_PROVIDER_ERROR` 走中英文用户文案，说明模型服务未完成回复、
允许再次尝试、请求过大时拆分发送，并不把网关码/异常串放在主视觉。新增 focused widget 回归，结果
`32/32` 通过。修复后未虚构新的真实 504 画面，因此该 session 的 504 仍标红，marker 机制本身才入绿。

五通道 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-113116`，录屏=`935.448333s`；
backend=`1147` 行，SSE=`1408` 行，LLM=`104` 行，frontend 无 Flutter/Dart/布局/Unhandled 红线，三个 SSE
流真实接入，受管网关 challenge/install/models 与 chat wire 经过 llmtap。正式证据与修复边界=`sessions/20260825-113116/evidence/EDGE-001-five-channel.md`，
统计警报复审=`testend/rig/formal-evidence/EDGE-001-ledger-alarm-reaudit-20260825.md`；五级由 `judge.py`
写入 `G1/F2/A5/C4/G2`，COVERAGE=`848 rows / 498 carried judgments / 0 tombstones`，anchors=`10/10`，
`alarms.py check` 在复审 ack 后 clean。批次四十八由 `0→1/50`，未满 50 格不跑统一长门禁、不提交；
下一正式前线=`EDGE-002`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-114 完成，stage/generic 通用舞台与 poll 终态收口

静态反查确认 `_GenericStage` 是第 13 座共同 host，不是额外工具族：未被 12 个 bespoke body 接管的 stage route 共享诚实丝带、kind 量身体、live/settling/failed 状态和结果摘要；`search_tools`、conversation、attachment 等无 stage route 的面保持诚实缺席，不凭空造舞台。`trigger_workflow` 是 poll 生命周期，202 回执不谢幕，必须等对应 `flowrunId` 的 durable `run_terminal`。

真实 App 先走工具目录检查，再用实体提及选择器精确选择 disposable `surf114_poll`，只调用一次 `trigger_workflow`，真实 flowrun=`fr_b71eebde4adf9919`，后端 8.12 秒后 completed，节点 2、边 1；右岛从通用 workflow 图和运行卷转为 settled touchpoint 摘要。直接输入带下划线 ID 的两次失败保留为 Computer Use 输入桥负边界，不计绿格；产品入口提及路径成功且 wire 保留精确 ID。fixture 收台前全部删除，列表不再出现 `surf114_`。

五通道 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-105440`，录屏=`699.328333s / 2784x1808 / 60fps`，结果帧=`sessions/20260825-105440/evidence/frames/surf114-generic-settled.png`；messages durable=`66..74` 单调，entities workflow=`run_started → run tick → run_terminal` 且 `flowrunId` 一致，backend/frontend 无应用级红线，LLM wire 正向调用 HTTP 全`200`，rig-check/rig-down 通过并无残留。frontend AX 固定格式观察器噪声已由 `evidence/frontend-ax-review.md` 精确审阅，不以 grep 静默。

新增真实时序回归：`tool_result open → run_terminal → tool_result close`，focused Flutter 通过；五级由 `judge.py` 写入 `E2/F2/B2/C4/G1`。formal journal=`2485`（2300 baseline + 185 live），`gen_coverage.py --check`=`848 rows / 497 carried judgments / 0 tombstones`，anchors=`10/10`；`gap-too-fast`/`discovery-collapse` 按 `SURF-114-ledger-alarm-reaudit-20260825.md` 独立复审并串行 ack，最终 `alarms.py check` clean。批次四十七=`50/50` 后统一长门禁已通过并提交 `467e12e7`：根 `make verify`、完整 `make -C backend testend`=`312.506s`、rig=`50/50`、格式/覆盖/锚点/警报/进程审计全绿；完整记录=`testend/rig/formal-evidence/batch-47-gate-20260825.md`。正式 sequence gate 下一原子前线=`EDGE-001 上下文水位 80% 触发 tool_result 换 marker`，批次四十八从 `0/50` 开始。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-113 完成，stage/mcp 接线现场与类型化工具货架闭环

静态反查确认 MCP 舞台只把 install/reconnect/create 的类型化结果投影成接线现场和工具货架：服务器名取自接线参数，环境键遮罩，落定工具只信 `resultObj['tools']` 中的 `name`，最多展示 12 个并明确总数；安装是危险动作，必须经过一次性人闸，重连是安全动作。这样既不把任意执行参数冒充发现工具，也不把 secret 或内部连接细节泄漏到产品面。

真实 App 在受管网关上先搜索并安装 marketplace `microsoftdocs/mcp`，一次性 `允许` 后只执行一次安装；舞台显示“已允许”“已连接”“3 工具”和三个真实工具 chip：`microsoft_docs_search`、`microsoft_code_sample_search`、`microsoft_docs_fetch`。随后对已安装实例 `mcp` 只执行一次 reconnect，舞台显示“已重连 MCP mcp · 3 工具”、连接时间和同一组三个工具，助手同时解释 marketplace 名称与本地实例名的差异；无重复安装、卸载或重试。

五通道 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-104412`，录屏=`202.041667s / 2784x1808 / 60fps`，抽帧=`sessions/20260825-104412/evidence/frames/surf113-mcp-125.png`、`surf113-mcp-175.png`；messages durable=`1..44`、notifications=`16..19` 单调无 gap，entities 状态 `disconnected→connecting→ready` 完成两次，LLM 观测响应全`200`，backend 无 panic/FATAL/应用红线，frontend 无 Flutter/Dart/布局/Unhandled 红线，App/backend/ssetap/llmtap/recorder 收台无残留。调查=`testend/rig/formal-evidence/SURF-113-stage-mcp-investigation-20260825.md`，L2=`sessions/20260825-104412/evidence/SURF-113-stage-mcp-five-channel.md`。

专项 Flutter=`30` 项、Go MCP app/tool/infra 三组全绿；五级由 `judge.py` 写入 `E2/F2/B2/C4/G1`。formal journal=`2480`（2300 baseline + 180 live），`gen_coverage.py --check`=`848 rows / 496 carried judgments / 0 tombstones`，anchors=`10/10`。本轮 `gap-too-fast`/`discovery-collapse` 按 `SURF-113-ledger-alarm-reaudit-20260825.md` 独立复审并串行 ack，未改阈值/算法/CODEX/锚点/gate，最终 `alarms.py check` clean。批次四十七由 `40→45/50`，未到第 50 格不跑统一长门禁、不提交；下一正式前线=`SURF-114 stage/generic`。P12 的 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-112 完成，stage/memory 记忆笺与用户图钉边界闭环

静态反查确认 Memory 舞台是只读记忆笺：slug 笺角、正文 live tail/settled 全文和落定结果条；舞台不渲染 pin/unpin，图钉只走用户 REST 面。`write_memory` 只接受 `name/description/content`，AI 写入不携带 pinned；更新已有记忆必须保留既有 `Pinned` 与 `Source`，否则会静默破坏用户策展和 system-prompt 投影。

真实 App 在受管网关上只调用一次 `read_memory` 读取 `handoff-note`，活动舞台显示 slug、来源、标题/摘要和完整正文；随后只激活一次 `write_memory` 并只写入一次 `release-rule` 更新，没有 retry、重复 mutation 或其它记忆动作。更新后的舞台显示新正文；REST 真相证明 description 不变、`pinned=true` 仍在、`source=user` 仍在。再经 REST 对 `handoff-note` 执行 pin/unpin，各返回 200，SSE 只发 frame-only `memory.updated`，没有 `inbox` 伪审计行。

五通道 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-103249`，录屏=`257.440000s / 2696x1720 / 60fps`，抽帧=`sessions/20260825-103249/evidence/frames/surf112-memory-read.png`、`surf112-memory-write-170.png`；messages durable=`1..36`、notifications=`16..22` 单调无 gap，backend 无 WARN/ERROR/panic/fatal，frontend 无 Flutter/Dart/Unhandled 红线（仅已知 IMK 平台噪声），LLM 请求响应全`200`，App/backend/ssetap/llmtap/recorder 收台无残留。调查=`testend/rig/formal-evidence/SURF-112-stage-memory-investigation-20260825.md`，L2=`sessions/20260825-103249/evidence/SURF-112-stage-memory-five-channel.md`。

五级由 `judge.py` 写入 `E2/F2/B2/C4/G1`；formal journal=`2475`（2300 baseline + 175 live），`gen_coverage.py --check`=`848 rows / 495 carried judgments / 0 tombstones`，anchors=`10/10`。本轮 `gap-too-fast`/`discovery-collapse` 按 `SURF-112-ledger-alarm-reaudit-20260825.md` 独立复审并串行 ack，未改阈值/算法/CODEX/锚点/gate，最终 `alarms.py check` clean。批次四十七由 `35→40/50`，未到第 50 格不跑统一长门禁、不提交；下一正式前线=`SURF-113 stage/MCP`。P12 的 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-111 完成，stage/skill 正文、占位符与安装信任门闭环

静态反查确认 Skill 舞台将 SKILL.md 分成 metadata header 与真实 Markdown prose；`allowedTools` 在 installed skill 的信任门未批时只能显示为请求，必须显示“信任门未批,确认仍逐次”，批准后才显示琥珀“免危险确认(预授权)”。`activate_skill` 的 `$1`、`$ARGUMENTS`、`${CLAUDE_SKILL_DIR}`、`${CLAUDE_SESSION_ID}` 及带捆绑文件的目录锚点语义均已冻结。

真实 App 创建 `surf111runbook`，Computer Use 首次输入因桥接器吞掉 `$`/下划线而保留为仪器负事实；随后以本地 REST 真相面修正精确 body、参数 `target` 并补入 `references/notes.md`，App 再用 `get_skill` 读取，主内容与右侧 stage 均显示完整 Markdown 和 literal markers。真实 App 激活传入 `daily`、`review`，最终正文与 stage 同时显示 `$1→daily`、`$ARGUMENTS→daily review`、真实 references 路径和 session ID，无实体副作用。

同一 session 另以本地 tarball 构造 `surf111-installed`：`inspect-source`/`install` 成功，REST 证明 `source=installed`、`toolsApproved=false`；App 读取后的 stage 显示“已请求预授权·信任门未批,确认仍逐次”，工具 chip 中性。执行 `approve-tools` 后新 App 回合重新读取，stage 才显示“激活后免危险确认(预授权)”和琥珀工具 chip。

五通道 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-101708`，录屏=`531.340000s / 2784x1808`，正向帧=`sessions/20260825-101708/evidence/frames/surf111-400s.png`；messages=`1..75`、notifications=`16..28` 连续唯一，backend 无 WARN/ERROR/panic/fatal，frontend 仅已知 IMK 平台噪声，managed wire 观测响应全`200`，`rig-down` 无残留。调查=`testend/rig/formal-evidence/SURF-111-stage-skill-investigation-20260825.md`，L2=`sessions/20260825-101708/evidence/SURF-111-stage-skill-five-channel.md`。

五级由 `judge.py` 写入 `E2/F2/B2/C4/G1`；formal journal=`2470`（2300 baseline + 170 live），`gen_coverage.py --check`=`848 rows / 494 carried judgments / 0 tombstones`，anchors=`10/10`。两条统计警报按 `SURF-111-ledger-alarm-reaudit-20260825.md` 独立复审并串行 ack，阈值/算法/CODEX/锚点/gate 未改，最终 `alarms.py check` clean。批次四十七由 `30→35/50`，未到第 50 格不跑统一长门禁、不提交；下一正式前线=`SURF-112 stage/memory`。P12 的 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-110 完成，stage/agent 四槽创建与局部编辑闭环

静态反查确认 Agent 舞台同时消费 `prompt`、`tools`、`knowledge`、`modelOverride` 四槽；live 阶段未触槽回显旧真相，settled 阶段四槽回全墨，prompt 使用有界视口；`create_agent` 的 knowledge 是文档 ID 数组、tools 是 `{ref}` 数组、modelOverride 必须同时有 `apiKeyId` 与 `modelId`，`edit_agent` 是局部合并。

真实 App 先保留两个错误参数路径：knowledge 字符串化被后端拒绝，随后缺少 modelOverride.apiKeyId 也被拒绝，均显示“草稿未保存 · 尚未创建实体”且没有副作用；一次停止重复推理产生的 context-canceled finalize WARN 也原样保留。修正后只创建 `surf110-planner` v1，并挂载 `fn_a62ac98dd28924cd`、`doc_cb76412ca8fc8183` 和 `{apiKeyId:'aki_fa6cda7c029fecb7',modelId:'anselm-auto'}`；随后只改 prompt 生成 v2，其余挂载、模型、标签、描述全部保持不变。

五通道 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-100206`，workspace=`ws_54e12e38cccbb4b2`，录屏=`572.313333s / 2784x1808`，settled 截图=`sessions/20260825-100206/evidence/SURF-110-stage-agent-settled.png`；REST active v2、SSE close、主内容和右侧舞台一致；durable seq 为 messages=`1..77`、entities=`7..10`、notifications=`16..19`，均连续唯一；backend 仅三条已知负路径 WARN，无 panic/fatal；frontend 无 Flutter/Dart/布局/Unhandled 红线，仅已知 IMK 平台噪声；LLM managed wire 观测响应全 `200`；`rig-down` 封口无残留。调查=`testend/rig/formal-evidence/SURF-110-stage-agent-investigation-20260825.md`，L2=`sessions/20260825-100206/evidence/SURF-110-stage-agent-five-channel.md`。

五级由 `judge.py` 写入 `E2/F2/B2/C4/G1`；formal journal=`2465`（2300 baseline + 165 live），`gen_coverage.py --check`=`848 rows / 493 carried judgments / 0 tombstones`，anchors=`10/10`。`gap-too-fast`/`discovery-collapse` 按 `SURF-110-ledger-alarm-reaudit-20260825.md` 独立复审并串行 ack，阈值/算法/CODEX/锚点/gate 未改，最终 `alarms.py check` clean。批次四十七由 `25→30/50`，未到第 50 格不跑统一长门禁、不提交；下一正式前线=`SURF-111 stage/skill`。P12 的 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-109 完成，stage/handler 生命周期与 RFC-7396 编辑闭环

静态反查确认 Handler 舞台的真实输入契约：`set_init_args_schema` 使用 `args`，`set_init`/`set_shutdown` 使用 `initBody`/`shutdownBody`，`add_method` 使用嵌套 `method`，而 `update_method` 必须使用 `{name, patch}` 的 RFC-7396 形状；timeout 以毫秒存储、以秒钟词展示，sensitive init arg 只显示掩码。focused Flutter=`12/12`，对应 Go handler/tool 测试通过。

真实 App 先保留模型错误使用 `set_method`、非法 Handler 名称和嵌套 `method` 编辑形状的失败路径；后端错误、SSE error close 和 UI 红色失败卡均未吞掉。模型依照工具错误自纠后，以正确 `name:"send" + patch` 创建 `surf109_notifier` v1，再编辑为 v2；最终 Handler 包含 `init`、`send`、`shutdown`、`apikey ••••`、`region`，`send` 的时限由 `30s` 变为 `45s`，代码返回 status 由 `sent` 变为 `updated`，其他输入输出和生命周期内容保持不变。点击最新实体查看后右侧舞台跟随 v2，旧 v1 作为历史保留。

五通道 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-095228`，workspace=`ws_40865e568cbd7b05`，录屏=`334.810000s / 2784x1808 / 60fps`，截图=`sessions/20260825-095228/evidence/SURF-109-stage-handler-settled.png`；REST active version 2、`timeout=45000`、body 含 `status:'updated'`、env ready/runtime running，与 SSE close、entities `handler.edited`、LLM arguments 和 UI 一致；backend 仅三条刻意失败路径 WARN，无 panic/fatal；frontend 仅已知 IMK 平台噪声，无 Flutter/Dart/布局/Unhandled 红线；真实 managed gateway completion 全 `200`；`rig-down` 封口无残留。调查=`testend/rig/formal-evidence/SURF-109-stage-handler-investigation-20260825.md`，L2=`sessions/20260825-095228/evidence/SURF-109-stage-handler-five-channel.md`。

五级由 `judge.py` 写入 `E2/F2/B2/C4/G1`；formal journal=`2460`（2300 baseline + 160 live），`gen_coverage.py --check`=`848 rows / 492 carried judgments / 0 tombstones`，anchors=`10/10`。`gap-too-fast`/`discovery-collapse` 按 `SURF-109-ledger-alarm-reaudit-20260825.md` 独立复审并串行 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check` clean。批次四十七由 `20→25/50`，未到第 50 格不跑统一长门禁、不提交；下一正式前线=`SURF-110 stage/agent`。P12 的 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-108 完成，stage/subagent 一席一卡与真实终端活窗闭环

静态反查确认 `SubagentStageBody` 只消费本行 `StageScene`，任务名由真实 schema `{subagent_type,prompt}` 的 `prompt` 首行唯一派生；execution phase 才是 live 真相，ReAct 尾最多 6 行，当前工具 progress 的内联终端最多 10 行，结算同时读取 nested message close 与 reload lifted fields。既有 focused Flutter stage/stage-panel/subagent tests 与 Go subagent/tool tests 均通过。

真实 App 先保留一个故意的负向边界：输入桥丢失 `_` 后模型实际调用 `Explore`，只读白名单诚实拒绝 Bash；随后用保留下划线的输入重跑 `general-purpose`，真实子代理调用 Bash 输出三行 `SURF108 terminal probe 1/2/3`，退出码 0，并在侧幕/对话正文显示单卡、ReAct 尾、终端输出和绿色结算。第三次短请求再次输出 `SURF108 LIVE 1/2/3`，用于确认结算前后的流转。负向结果不计绿，但不删除。

五通道 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-093437`，workspace=`ws_ef0727b1f151cce9`，录屏=`842.563333s / 2784x1808`，截图=`sessions/20260825-093437/evidence/SURF-108-stage-subagent-settled.png`；AX live 显示“正在派子代理… general-purpose”和“实时聆听中 · 落定以真相为准”，settling 会变为“正在落定”，settled 侧幕展开后显示 Bash、输出和退出码。SSE journal 记录 `Subagent`、`subagent:true`、Bash、progress、tool_result 和 ordered output；LLM wire 真正经过 `https://api.anselm.website` 且 completion 全`200`；backend 无 panic/fatal，只有故意失败路径的两条 Grep fallback WARN；frontend 仅已知 IMK 平台噪声，无 Flutter/Dart/布局/Unhandled 红线；`rig-down` 完整封口、无残留。调查=`testend/rig/formal-evidence/SURF-108-stage-subagent-investigation-20260825.md`，L2=`sessions/20260825-093437/evidence/SURF-108-stage-subagent-five-channel.md`。

五级由 `judge.py` 写入 `E2/F2/B2/C4/G1`；formal journal=`2455`（2300 baseline + 155 live），`gen_coverage.py --check`=`848 rows / 491 carried judgments / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast`/`discovery-collapse` 按 `SURF-108-ledger-alarm-reaudit-20260825.md` 独立复审并串行 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check` clean。批次四十七由 `15→20/50`，未到第 50 格不跑统一长门禁、不提交；下一正式前线=`SURF-109`。P12 的 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-107 完成，stage/trigger 四脸与 nextFireAt 真相闭环

首轮真实读取 `SURF107-cron` 时发现产品级数据真相缺陷：后端通用 ISO 时间脱敏器把用户明确要求的 `nextFireAt` 也替换成了“相应时间”，导致 REST/LLM wire 有精确值而 App 最终答案不可用。该轮停止计绿；stop-and-fix 在 `backend/internal/app/loop/redact.go` 增加字段级窄保护，覆盖 `nextFireAt`/“下次触发时间”的 direct field、翻译后的 Markdown table row 与跨 streaming chunk，普通 `createdAt`/`updatedAt` 继续脱敏。新增 redaction focused tests，后端 `Test(Redact|TextRedactor)` 全绿；前端 trigger focused=`21/21`。

修复后 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-092425`，使用新 backend、真实 App、真实 managed gateway、Computer Use、独立三路 SSE witness、LLM tap 和连续录屏，只读重跑 `SURF107-cron`。App/AX 显示 `下次触发时间 | 2026-08-26 09:00:00 (UTC+8)`，同一答案的 `最后更新`仍为“相应时间”；REST `listening=true`、`paused=false`、`refCount=1`、相同 `nextFireAt`；SSE message close 与 LLM wire 均含完整值。四脸构建的 cron/webhook/fsnotify/sensor 配置和 listener 事实取自前置 session=`20260825-090642`，不把修复前画面冒充修复后证据。嵌套 sensor target、畸形 ID 和 Computer Use 输入桥残缺请求均保留为负向事实，不计绿。

五通道：修复后录屏=`336.175000s / 2784x1808`，截图=`sessions/20260825-092425/evidence/SURF-107-fixed-next-fire.png`；backend 无 WARN/ERROR/panic/fatal；ssetap 三流真实连接，messages durable=`1..21`、notifications=`1..2` 单调唯一、entities 无本路径业务 durable 帧；LLM managed proof/install/models 与 chat completion 全`200`；frontend 仅已知 IMK 平台噪声，无 Flutter/Dart/布局/Unhandled 红线；`rig-down` 收台无残留。调查=`testend/rig/formal-evidence/SURF-107-stage-trigger-investigation-20260825.md`，L2=`sessions/20260825-092425/evidence/SURF-107-stage-trigger-five-channel.md`。

五级由 `judge.py` 写入 `E2/F2/B2/C4/G1`；formal journal=`2450`（2300 baseline + 150 live），`gen_coverage.py --check`=`848 rows / 490 carried judgments / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast`/`discovery-collapse` 按 `testend/rig/formal-evidence/SURF-107-ledger-alarm-reaudit-20260825.md` 独立复审并串行 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check` clean。批次四十七当前=`15/50`，未到第 50 格不跑统一长门禁、不提交；下一正式前线=`SURF-108 stage/subagent`。P12 的 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-106 完成，stage/approval 审批预览五级闭环

静态反查发现托管模型会把 `allowReason` 与 `timeout` 作为字符串发送，timeout 以秒数表达；原审批 stage 只认原生布尔值和原始 timeout 字符串，备注能力和人话时长可能静默消失。stop-and-fix 增加共享 scalar 解析 seam：live stage 与 settled preview 都兼容原生/字符串化值，整秒统一转为 `m/h/d/w`，零值显示为 `0s` 而不伪装成 `0w`；补 `"true"`、`"7200"`、`2h`、备注 chip 与零值回归。focused Flutter=`22/22`。

正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-085143`。首轮 AX 输入桥残缺请求和旧对话 edit 路径均保留但排除；干净新对话中真实 managed gateway 只调用一次 `create_approval`，创建 `SURF106-approval-clean` v1。Computer Use 展开 Activity 逐帧确认审批人视角模板、`amount`/`vendor` 琥珀插值、`2h`、`2h 后自动拒绝`、`可填备注`、批准/拒绝动作，未见 clipping/overlap/reflow/非用户跳变。REST active v1 与 UI/助手正文一致。

五通道：screen=`362.563333s`；backend PID=`6955`，仅观测器缺 workspace 探针产生一条 `401`，无应用级 WARN/ERROR/panic/fatal；SSE messages=`1..53`、notifications=`1..7`、entities=`1..2` 各自单调唯一；LLM managed proof/install/models 与 9 次 chat completion 全 `200`，最终 tool call 的 `allowReason="true"`、`timeout="7200"` 可重取；frontend 仅已知 IMK 平台噪声，无 Flutter/Dart/布局/Unhandled 红线；`rig-check`/`rig-down` 通过且无残留。调查=`testend/rig/formal-evidence/SURF-106-stage-approval-investigation-20260825.md`，L2=`sessions/20260825-085143/evidence/SURF-106-stage-approval-five-channel.md`。

五级由 `judge.py` 写入 `E2/F2/B2/C4/G1`；formal journal=`2445`（2300 baseline + 145 live），`gen_coverage.py --check`=`848 rows / 489 carried judgments / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast`/`discovery-collapse` 按 `testend/rig/formal-evidence/SURF-106-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check` clean。批次四十七当前=`10/50`，未到第 50 格不跑统一长门禁、不提交；下一正式前线=`SURF-107 stage/trigger`。P12 的 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-25 历史重述：SURF-105 完成，stage/control 决策梯五级闭环

静态反查发现 control stage 只读 `PartialJsonSession.arrayItemsAt(['branches'])`，无法消费真实 managed gateway 已产生的闭合 JSON 字符串数组；这会让实时决策梯空白。stop-and-fix 增加 `controlBranchItems`：原生数组优先，闭合合法 JSON 数组字符串窄兼容，部分/畸形字符串保持诚实空集，并按 session 缓存；补 stringified branches、`port`、`when`、`emit` 与 catch-all 回归。focused Flutter=`20/20`。

session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-083508` 使用真实 App、managed gateway、Computer Use、三路 SSE witness、LLM tap 和连续录屏。台架曾因 AX `set_value` 与可视编辑器不同步产生残缺输入；模型先澄清，后端在 mutation 前拒绝坏 `inputs`，没有实体副作用。随后真实成功创建 `SURF105` v1，活动岛与助手正文一致；展开成功 stage 逐帧确认 `hot`、`normal`、`otherwise` 三段顺序、连续高度、独立“否则”徽记和明确“透传”幽灵，REST active v1 与画面对账一致。该观察器输入负路径保留在调查记录，不冒充产品红或绿。

五通道：录屏封口总时长=`540.676667s`（含 App rebind 后的新 segment）；backend PID=`5237`、health 通过，仅故意坏 inputs 的 validation WARN；SSE messages=`1..33`、notifications=`1..3`、entities=`1..2` 各自单调唯一；LLM managed proof/install/models 与业务 completion 全 `200`；frontend 仅正常 Dart VM/已知 IMK 平台噪声，无 Flutter/Dart/布局/Unhandled 红线；`rig-check`/`rig-down` 通过且无残留。调查=`testend/rig/formal-evidence/SURF-105-stage-control-investigation-20260825.md`，L2=`sessions/20260825-083508/evidence/SURF-105-stage-control-five-channel.md`。

五级由 `judge.py` 写入 `E2/F2/B2/C4/G1`；formal journal=`2440`（2300 baseline + 140 live），`gen_coverage.py --check`=`848 rows / 488 carried judgments / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast`/`discovery-collapse` 按 `testend/rig/formal-evidence/SURF-105-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check` clean。批次四十七当时=`5/50`，下一前线已由上方 SURF-106 整体重述接管。P12 的 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-104 完成，stage/workflow 工作流图生长五级闭环

首轮真实 managed gateway 返回字符串化 `ops` 时，后端已正确写入 v2，但前端只读原生数组，错误把真实 `+1 节点 · +1 边` 显示为“仅改元数据(图未变)”。该产品红事实保留在 `testend/rig/formal-evidence/SURF-104-stage-workflow-investigation-20260825.md`，不计绿。stop-and-fix 增加统一 `workflowOpsFromArgs` seam：原生数组优先，闭合合法 JSON 数组字符串窄兼容，未闭合/畸形字符串继续不生成假图；focused Flutter=`41/41`。

修复后 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-080352` 用真实 App、managed gateway、Computer Use、三路 SSE witness、LLM tap 和录屏重跑；真实模型再次发送字符串化 `ops`，App 活动卡显示 `+1 节点 · +1 边`，打开活动侧幕并展开 `surf104_graph` 后真实画布显示 `节点 2 · 边 1`、`start/触发 → run/动作`。后端 v2、触点、摘要、画布一致，无重复 mutation。

五通道：screen=`243.491667s`；backend 无 WARN/ERROR/panic/fatal/unknown；SSE 三流均连接，messages durable=`1..15`、notifications=`16..19` 单调唯一无 gap，entities 连接无业务帧；LLM proof/install/models 与 4 次 chat completion 全 `200`；frontend 仅正常 Dart VM 与已知 IMK 平台噪声，无 Flutter/Dart/布局/Unhandled 红线；`rig-check`/`rig-down` 通过且无残留。L2 证据=`sessions/20260825-080352/evidence/SURF-104-stage-workflow-five-channel.md`。

五级由 `judge.py` 写入 `E2/F2/B2/C4/G1`；formal journal=`2435`（2300 baseline + 135 live），`gen_coverage.py --check`=`848 rows / 487 carried judgments / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast`/`discovery-collapse` 已按 `testend/rig/formal-evidence/SURF-104-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check` clean。批次四十六=`50/50` 已通过统一长门禁并提交 `4baec1b7`，完整记录=`testend/rig/formal-evidence/batch-46-gate-20260825.md`；formal sequence 下一前线=`SURF-105 stage/control`，批次四十七=`0/50`。P12 的 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-103 完成，stage/document 文档编辑舞台五级闭环

静态反查确认文档舞台以按编辑 block 冻结的 baseline 做公共前缀增量快进：分叉前为 muted known truth，分叉后才着新墨；书脊只扫描新增段界；metadata-only 不假造空散文幕；失败保留整篇残稿；落定用 UTF-8 字节数显示真实全量替换徽；`[[id]]` 缺名时显示原 id 不阻塞。focused Flutter=`26/26`。

真实 App 以全新数据目录、真实 managed gateway、Computer Use、三路 SSE witness、LLM tap 和录屏验证两条文档编辑路径。第一条是故意矛盾 probe：要求保留未知正文却禁止读取，模型先读、第一次编辑漏段、第二次修正，最终正确但右侧真实显示 `编辑 ×2`，该负事实完整保留；第二条给出完整目标正文并禁止其它工具，真实 App 单次 `edit_document` 落定，正文、文档名和右侧舞台一致，无重复卡片、跳变、溢出或布局红线。前者不作为绿证据，后者才是正向产品路径。

五通道封口：session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-075245`，screen=`119.876667s`；backend=`249` 行无 WARN/ERROR/panic/fatal/exception；frontend=`4` 行仅已知 IMK 平台噪声，无 Flutter/Dart/布局/Unhandled 红线；SSE=`420` 行，messages durable=`1..48`、notifications=`16..22`、entities=`7..8` 单调唯一无 gap；LLM=`28` 行，managed proof/install/models 与 12 次 chat completion 全 `200`；`rig-check`/`rig-down` 通过且无残留。调查=`testend/rig/formal-evidence/SURF-103-stage-document-investigation-20260825.md`，L2=`sessions/20260825-075245/evidence/SURF-103-stage-document-five-channel.md`。

五级由 `judge.py` 写入 `E2/F2/B2/C4/G1`；formal journal=`2430`（2300 baseline + 130 live），`gen_coverage.py --check`=`848 rows / 486 carried judgments / 0 tombstones`，anchors=`10/10`。本格写账触发的 `gap-too-fast`/`discovery-collapse` 已按 `testend/rig/formal-evidence/SURF-103-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check` clean。批次四十六当前=`45/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`SURF-104 stage/workflow`。P12 的 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-102 完成，stage/function 函数编辑舞台五级闭环

静态反查确认函数编辑舞台按 `functionBaselineProvider` 冻结编辑前真相：live 先显示旧真相地层，再以中性空心点呈现已听写 OpTicker，`AnCodeEditor(live:true)` 在同一代码壳内增长；settle 只解除贴底并以冻结 before/落地 after 的逐行 diff 显示真实 `+n/−m`，失败态不会给操作成功色。`functionBaselineProvider` keep-alive 与真相失效分离，focused Flutter 阶段套件 `40/40` 全过，覆盖窄帧地层、OpTicker、live editor、同壳 settle、真实 diff 和对齐规则。

真实 App 使用全新数据目录、真实 managed gateway、Computer Use、三路 SSE witness、LLM tap 和连续录屏。短编辑场次把临时函数从 v4 改到 v5，单一 `set_code` 成功，App 与活动侧幕均显示落定代码；另一场真实观察到 `正在修改函数…`、`edit_function 进行中`、`实时聆听中 · 落定以真相为准`，随后打开落定代码舞台，未见 composer 跳变、横向溢出或布局红线。Computer Use 对窄中间帧的采样由 focused 测试补足，不把静态测试冒充真实 App。

本轮同时保留一个重要负事实：长代码 probe 中上游模型先发了错误形状的 `edit_function`，随后才发出正确调用；backend 记录对应 WARN，重新进入场次后 UI 如实显示红色失败尝试与成功结果。该事实没有被吞掉，也没有擅自改 UI 去掩盖；它归入后续模型工具遵循/重试呈现边界，不作为本格的成功证据。

五通道封口：session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-073701`；screen 真实录制并正常收台；backend=`883` 行，三条 WARN 均已归因，无 panic/fatal/未解释错误；frontend 仅已知 macOS `IMKCFRunLoopWakeUpReliable`，无 Flutter/Dart/布局/Unhandled 红线；SSE=`1211` 行，messages durable=`1..162`、notifications=`16..43`、entities=`7..28` 均单调唯一无 gap；LLM wire 全 HTTP `200`；`rig-check`/`rig-down` 通过且无残留。调查=`testend/rig/formal-evidence/SURF-102-stage-function-investigation-20260825.md`，L2=`sessions/20260825-073701/evidence/SURF-102-stage-function-five-channel.md`。

五级由 `judge.py` 写入 `E2/F2/B2/C4/G1`；formal journal=`2425`（2300 baseline + 125 live），`gen_coverage.py --check`=`848 rows / 485 carried judgments / 0 tombstones`，anchors=`10/10`。本格写账触发的 `gap-too-fast`/`discovery-collapse` 已按 `testend/rig/formal-evidence/SURF-102-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check` clean。批次四十六当前=`40/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`SURF-103 stage/document`。P12 的 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-101 完成，i18n/markdown 图片占位与长 URL 稳定性闭环

静态反查确认 `markdown.imageNotLoaded` 在英文 locale 为 `image not loaded`、中文 locale 为 `图片未加载`，生成 slang 与源文件一致；`AnMarkdown` 的 `ImageMd` 统一进入 `_imagePlaceholder`，不创建 `NetworkImage` 或其它隐式网络取图，用户可见文案、图片图标和 URL 走单行 ellipsis 芯片。新增双语精确回归，既有 markdown widget test 锁定零 `Image` widget 与惰性占位，focused Flutter=`32/32`。

真实 App 以全新数据目录完成 onboarding，并通过真实 backend、managed gateway、Computer Use、独立三路 SSE witness、LLM tap 和连续录屏验证短 URL 与 298 字符长 URL。Computer Use 直接输入 markdown 的首条尝试因输入桥损坏 `![...]`、冒号和斜杠，明确排除为 harness 输入层事实；随后用真实 REST 仅写入精确 durable markdown，再由真实 App 打开并渲染。最终 AX 与画面均显示 `图片未加载`；长 URL 在单行占位芯片内省略，不发生溢出、遮挡、历史内容重排或持续跳变，连续帧联系表已复核。证据=`sessions/20260825-072409/evidence/SURF-101-i18n-markdown-five-channel.md`，调查=`testend/rig/formal-evidence/SURF-101-i18n-markdown-investigation-20260825.md`。

五通道封口：screen=`225.711667s`；backend=`347` 行无应用 WARN/ERROR/panic/fatal/exception；frontend=`5` 行仅原样披露已知 macOS `IMKCFRunLoopWakeUpReliable` 平台输入法日志，无 Flutter/Dart/布局/Unhandled 红线；SSE=`170` 行，三流各连接一次，messages durable=`1..24`、notifications durable=`1..4` 单调无 gap，entities 无业务 durable 帧；llmtap=`22` 行，带状态记录全部 HTTP `200`。`rig-check`/`rig-down` 均通过且无残留进程。

五级由 `judge.py` 写入 `E2/F2/B2/C4/G1`；formal journal=`2420`（2300 baseline + 120 live），`gen_coverage.py --check`=`848 rows / 484 carried judgments / 0 tombstones`，anchors=`10/10`。本格写账触发的 `gap-too-fast`/`discovery-collapse` 已按 `testend/rig/formal-evidence/SURF-101-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check` clean。批次四十六当前=`35/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`SURF-102 stage/function`。P12 的 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-25 历史收口：SURF-100 完成，i18n/appName 产品名与 onboarding wordmark 闭环

静态反查确认产品名 `appName` 在英文和中文 locale 均为 `Anselm`，窗口标题、workspace onboarding、launch-at-login、系统通知和窗口控制无障碍语义均从生成 locale 读取；onboarding 的 `toUpperCase()` 是明确的品牌排版选择。新增 locale 回归断言中英文均精确等于 `Anselm`，focused Flutter=`12/12`。

真实 App 以全新数据目录启动并完成 onboarding。Computer Use 实际观察到右上角 wordmark 为 `ANSELM`，图形标记与字标同一水平带内，无截断、重叠或异常跳位；输入 `SURF-100 品牌检查` 创建 workspace 后真实回到中文 Chat，品牌没有被翻译或漂移，工作区名作为独立用户值显示在左下角。onboarding 终帧=`sessions/20260825-071353/evidence/frames/SURF-100-app-name-onboarding.png`，Chat 终帧=`sessions/20260825-071353/evidence/frames/SURF-100-app-name-final.png`，正式证据=`sessions/20260825-071353/evidence/SURF-100-i18n-app-name-five-channel.md`，调查=`testend/rig/formal-evidence/SURF-100-i18n-app-name-investigation-20260825.md`。

五通道封口：screen=`75.223333s`；backend=`136` 行无应用红线；frontend=`4` 行无 Flutter/Dart/布局/Unhandled 红线，唯一 error 是证据中原样披露的 macOS `IMKCFRunLoopWakeUpReliable` 平台输入法日志；SSE=`8` 行，notifications/entities/messages 三流各连接一次，本格只验证启动与 onboarding，未创建业务实体，因此没有 durable business frame，不虚构 seq；llmtap=`10` 行，managed proof/install/models 全成功。`rig-check`/`rig-down` 通过且无残留进程。

五级由 `judge.py` 写入 `E2/F2/B2/C4/G1`；formal journal=`2415`（2300 baseline + 115 live），`gen_coverage.py --check`=`848 rows / 483 carried judgments / 0 tombstones`，anchors=`10/10`。本格写账触发的 `gap-too-fast`/`discovery-collapse` 已按 `testend/rig/formal-evidence/SURF-100-ledger-alarm-reaudit-20260825.md` 独立复核并 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check` clean。该条为历史收口；批次四十六随后推进至=`35/50`，下一前线=`SURF-102`。P12 的 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-25 历史收口：SURF-099 完成，i18n/tree JSON 树真实截断与无障碍闭环

静态反查确认 `AnJsonTree` 的 invalid JSON、循环引用、more-items 三个用户可见键及 Scheduler/Chat 的真实调用点。首轮资源审查发现中文无障碍标签使用半角逗号 `JSON 树,$count 项`，停止后修为自然中文 `JSON 树，$count 项`，重新生成 slang 产物并新增英文/中文、invalid/circular/more-items 精确回归；`an_json_tree_test.dart` 与 `locale_boot_test.dart` 全部通过。

真实 App 用临时 Function 返回 2100 项列表，构造真实 Workflow `surf099_tree_workflow`，两次 Flowrun 均完成；Computer Use 走调度 → workflow → 运行 → 打开 → `tree` 节点。Scheduler 右岛真实读到 `JSON 树，1 项`（顶层真实只有 `text` 一个键），连续滚动到末端显示 `1993..1998` 后的 `… 101 项已省略`；2100 输入、2000 节点上限、1999 个可见标量与 101 个省略项严格对齐，树没有静默丢项、展开后无空白折线、末端文案无裁切/重叠/跳变。最终帧=`sessions/20260825-065746/evidence/frames/SURF-099-i18n-tree-final.png`，正式证据=`sessions/20260825-065746/evidence/SURF-099-i18n-tree-five-channel.md`，调查=`testend/rig/formal-evidence/SURF-099-i18n-tree-investigation-20260825.md`。

五通道封口：screen=`451.910000s`；backend=`670` 行无应用 WARN/ERROR/panic/fatal/exception；SSE=`348` 行，notifications/messages/entities 三流真实连接，durable 区间分别为 `16..26`、`1..76`、`7..24`；frontend=`4` 行，仅正常启动/Dart VM 与一条已披露的 macOS `IMKCFRunLoopWakeUpReliable` 平台输入法日志，无 Flutter/Dart/RenderFlex/RenderBox/Unhandled/Exception 红线；llmtap=`43` 行，managed proof/install/models/chat completion 全 HTTP `200`。`rig-check`/`rig-down` 通过且无残留进程。

五级由 `judge.py` 串行写入 `E2/F2/B2/C4/G1`；formal journal=`2410`（2300 baseline + 110 live），`gen_coverage.py --check`=`848 rows / 482 carried judgments / 0 tombstones`，anchors=`10/10`。本格写账后的 `gap-too-fast`/`discovery-collapse` 已按 `testend/rig/formal-evidence/SURF-099-ledger-alarm-reaudit-20260825.md` 独立复核并 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check` clean。该条为历史收口；批次四十六随后推进到=`30/50`，下一前线=`SURF-101`。P12 的 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-25 历史收口：SURF-098 完成，i18n/status 五态日志词 stop-and-fix 闭环

首轮真实日志观察发现产品缺陷：聚合头已经显示本地化的 `2 完成 / 1 失败`，但明细行仍直接拼接 backend raw status，显示 `manual · failed`。停止后在 `log_list_provider.dart` 增加统一 `_statusWord`，function/handler/agent/workflow 四类用户可见日志主行均经 `AnStatus.fromRaw` 映射到 `t.status.*`；detail rows 保留 raw status 作为诊断 chrome，不让机器事实丢失。新增中英文 provider 回归断言，focused Flutter suite 全绿。

修复后真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-064736`、workspace=`ws_4c8a6c08c07f6523`，Computer Use 走过 Entities → `surf041_terminal_function` → 日志；最终画面明确显示 `2 完成 / 1 失败`，三行分别为 `manual · 完成`、`manual · 失败`、`manual · 完成`，颜色、行高、排序和右侧最近执行条稳定，无 raw 英文泄漏。录屏帧=`sessions/20260825-064736/evidence/frames/SURF-098-i18n-status-final.png`。

五通道封口：screen=`71.558333s`；backend=`207` 行无应用 WARN/ERROR/panic/fatal/exception；SSE=`192` 行，notifications/messages/entities 三流真实连接并记录成功/失败 durable close；frontend=`3` 行，仅正常启动/Dart VM/平台输出，无 Flutter/Dart/RenderFlex/RenderBox/Unhandled 红线；llmtap=`13` 行，managed proof/install/models 全 `200`，本格不虚构 chat completion。`rig-check`/`rig-down` 通过且无残留。SSE 原样保留专门 fixture 的 `entry.body.count` 缺失 `body` workflow 红事实，该失败不被本格 i18n 绿证据掩盖，也不归因于状态词修复。正式证据=`sessions/20260825-064736/evidence/SURF-098-i18n-status-five-channel.md`，调查=`testend/rig/formal-evidence/SURF-098-i18n-status-investigation-20260825.md`。

五格已由 `judge.py` 串行写入 `G1/F1/B2/C4/G1`；formal journal=`2405`（2300 baseline + 105 live），`gen_coverage.py --check`=`848 rows / 481 carried judgments / 0 tombstones`，anchors=`10/10`。`gap-too-fast`/`discovery-collapse` 按 `testend/rig/formal-evidence/SURF-098-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check` clean。该条为历史收口；批次四十六随后推进到=`30/50`，下一前线=`SURF-101`。P12 的 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-25 历史收口：SURF-097 完成，i18n/graph 工作流图节点词闭环

静态反查确认 `NodeKind` 六项均走生成的双语资源，真实 workflow editor、inspector 和 graph canvas 调用点无英文旁路。真实 App 走过 Entities → `surf041_terminal_workflow` → 图编辑器：添加节点菜单逐项显示 `触发/动作/智能体/分支/审批`；选择 `entry` 的检查器显示 `触发`，选择 `inspect` 的检查器显示 `动作`；开放枚举的 `未知` 由双语 focused test 覆盖，不伪造不可添加的 UI 操作。

focused Flutter=`14/14` 通过。绿色真实 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-062648`，录屏=`270.311667s`，帧=`evidence/frames/SURF-097-graph-menu.png`、`evidence/frames/SURF-097-graph-final.png`；Computer Use 未保存、未改图，画布卡片、连线、检查器无 clipping/overlap/reflow/非用户跳变。

五通道封口：backend D1=`85363`、`375` 行且无应用级 WARN/ERROR/panic/fatal/exception；SSE 三流真实连接并原样记录 fixture 执行失败；frontend=`3` 行，仅正常启动输出；llmtap challenge/install/models/chat completion 均 `200`；`rig-check`/`rig-down` 通过且无残留。`seed_surf041.py` 的真实执行因 `entry.body.*` 与当前触发 payload 形状不匹配而失败，SSE 原样记录 `no such key: body`；这是后续执行契约格的红事实，不被本格图编辑器 i18n 绿证据掩盖。正式证据=`sessions/20260825-062648/evidence/SURF-097-i18n-graph-five-channel.md`，调查=`testend/rig/formal-evidence/SURF-097-i18n-graph-investigation-20260825.md`。

五格已由 `judge.py` 串行写入 `G1/F1/B2/C4/G1`；formal journal=`2400`（2300 baseline + 100 live），`gen_coverage.py --check`=`848 rows / 480 carried judgments / 0 tombstones`，anchors=`10/10`。`gap-too-fast`/`discovery-collapse` 按 `testend/rig/formal-evidence/SURF-097-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check` clean。该条为历史收口；当前批次=`20/50`，下一前线=`SURF-099`。P12 的 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-25 历史收口：SURF-096 完成，i18n/startup 启动门控与重试恢复闭环

`SURF-096 i18n/startup` 首轮真实 App-first 红测发现启动崩溃页把 `BackendState.error` 的 raw backend URL/英文内部错误直接作为第三行显示；该轮停止并排除，不计绿。stop-and-fix 从产品启动门移除 raw `detail`，诊断仍留在 frontend journal/backend journal；双语 startup 六键精确回归与启动门测试共 `12/12` 通过。

修复后第一轮 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-061312` 使用 `RIG_SEED=0`、真实 macOS App、App-first、后端延迟 `25s`：Computer Use 观察到启动页只显示 `本地引擎无法连接/后端没有启动…/重试`，点击真实重试后恢复到 `创建工作区`，稳定帧无 clipping/overlap/reflow/非用户跳变。为满足 L2 的 SSE 硬门禁，第二轮 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-061754` 预置 workspace 重跑；同样的崩溃页修复后真实重试进入实体总览壳。

五通道封口：第一轮 screen=`73.485000s / 2784x1808`、backend=`61` 行、frontend=`3` 行、SSE 无 workspace 业务帧、llmtap=`1` 条 ready；第二轮 screen=`86.055000s / 2784x1808`、backend=`84` 行无应用红线、SSE 对 `ws_f953e7540cc060ca` 的 notifications/entities/messages 三流真实连接并 clean EOF、frontend=`3` 行无 Flutter/Dart/布局/Unhandled 红线、llmtap=`10` 行 managed wiring 正常但本路径无 completion。未把无 workspace 场景写成 SSE 通过，也未伪造 LLM completion。`rig-check`/`rig-down` 两轮通过且无残留进程；正式证据=`sessions/20260825-061312/evidence/SURF-096-i18n-startup-five-level.md`，L2 五通道补证=`sessions/20260825-061754/evidence/SURF-096-i18n-startup-five-channel.md`，调查=`testend/rig/formal-evidence/SURF-096-i18n-startup-investigation-20260825.md`。

五格已由 `judge.py` 串行写入 `G1/F1/B2/C4/G1`；formal journal=`2395`（2300 baseline + 95 live），`gen_coverage.py --check`=`848 rows / 479 carried judgments / 0 tombstones`，anchors=`10/10`。`gap-too-fast`/`discovery-collapse` 按 `testend/rig/formal-evidence/SURF-096-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check` clean。该条为历史收口；当前批次=`20/50`，下一前线=`SURF-099`。P12 的 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-095 完成，i18n/diff 差异查看动作语言闭环

`SURF-095 i18n/diff` 首轮静态审查确认七个差异动作键均已接入 `AnVersionDiff` 与版本手风琴，但发现中文资源把内部术语 `diff` 直出为用户文案，`只显变更`偏电报化，`展开全部($n 行)`也不符合中文排版。stop-and-fix 将其修为 `展开差异`、`收起差异`、`仅显示变更`、`展开全部（$n 行）`，同步生成 slang 产物，并新增双语精确回归。

聚焦 Flutter 共 `43` 项通过，覆盖 locale、差异渲染、版本手风琴、折叠/整份切换、菜单二入口、长文本和虚拟化。真实中文 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-060117` 通过 REST 构造 v2 后，Computer Use 实际打开 v1 更多操作并验证 `收起差异/展开全部（3 行）/设为活跃版本`，点击整份后再验证 `收起差异/仅显示变更/设为活跃版本`；差异卡、红删绿增行、菜单宽度与行高均无 clipping/overlap/reflow/非用户跳变。最终帧=`sessions/20260825-060117/evidence/frames/SURF-095-final.png`，正式证据=`sessions/20260825-060117/evidence/SURF-095-i18n-diff-five-level.md`，调查=`testend/rig/formal-evidence/SURF-095-i18n-diff-investigation-20260825.md`。

五通道封口：screen=`139.673333s / 2784x1808 / H.264`，backend=`249` 行且 D1/health 通过、无应用红线，SSE=`14` 行且 notifications durable=`16..18`、entities=`7..8` 连续，frontend=`19` 行无 Dart/Flutter/布局/Unhandled 应用红线，llmtap=`10` 行真实 `https://api.anselm.website` challenge/install/models 全 `200`。固定 AXTree bridge 签名已由 session `evidence/frontend-ax-review.md` 明确复核为 Computer Use 观察器噪声，未知签名仍 fail-closed；本确定性实体路径无 Chat completion 需求，不伪造 completion 或 messages durable 业务帧。`rig-check`/`rig-down` 全绿且无残留进程。

五格已由 `judge.py` 串行写入 `G1/F1/B2/C4/G1`；formal journal=`2390`（2300 baseline + 90 live），`gen_coverage.py --check`=`848 rows / 478 carried judgments / 0 tombstones`，anchors=`10/10`。`gap-too-fast`/`discovery-collapse` 按 `testend/rig/formal-evidence/SURF-095-i18n-diff-investigation-20260825.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check` clean。批次四十六当前=`5/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`SURF-096 i18n/startup`。P12 的 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-25 历史快照：SURF-095 开始，i18n/diff 差异查看动作语言

批次四十五已完成并提交 `f0a4aa11`：`SURF-085` 至 `SURF-094` 共 50/50 个单格均完成五级裁决；统一 `make verify`、完整 backend `testend=300.030s`、rig 自测 `50/50`、coverage、anchors、alarms、gofmt、diff 和监听进程审计全绿。提交前发现并修正覆盖清册漏登记和中文 onboarding 测试断言漂移，均已纳入该提交；working 与正式 gate 证据见 `testend/rig/formal-evidence/batch-45-gate-20260825.md`。

批次四十六从 `SURF-095 i18n/diff` 开始，当前 `0/50`。下一格静态目标为差异查看面中的 `新增/删除/折叠/显示全部/只显变更` 七个双语动作键；先做资源/调用点/守卫反查，再以真实 App + 五通道完成五级判定。P12 的 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-094 完成，i18n/action 通用动作词闭环

`SURF-094 i18n/action` 已完成真实 App 五级 `G1/F1/B2/C4/G1`。静态反查确认 `编辑/取消/保存/复制/展开/收起/自动换行/删除` 八个动作键在中英文资源中均有精确值，应用调用均走生成 locale；新增完整双语断言，focused locale suite=`6/6`，targeted analysis 通过。

绿色 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-052544`：实体 `sync_inventory` 详情真实显示 `复制/自动换行`，文库更多操作真实显示 `展开全部/收起全部`，MCP 手动添加表单真实显示 `添加/取消`；`编辑/保存/删除` 的生成调用点与既有实体/编辑器/确认框测试逐一核对，无英文旁路。终帧=`sessions/20260825-052544/evidence/SURF-094-final.png`，可见动作菜单间距、对齐、层级和中文文案均稳定，无 clipping/overlap/非用户跳变。

五通道封口：screen=`166.140000s / 2784x1808 / H.264 / 60fps`；backend=`260` 行，SSE=`8` 行，frontend=`17` 行，llmtap=`10` 行。D1/health/三流连接/managed wiring/窗口录制均通过，后端与 LLM 无应用红线；frontend 明确保留 Computer Use 驱动快速 AX 树切换时 Flutter `accessibility_bridge.cc` 的桥接消息，AX 后续读取和画面均正常，不将该仪器/框架边界隐去。此只读动作路径无需 Chat completion，未伪造 durable 业务帧或 completion。正式证据=`sessions/20260825-052544/evidence/SURF-094-i18n-action-five-level.md`，调查=`testend/rig/formal-evidence/SURF-094-i18n-action-investigation-20260825.md`。

五格已由 `judge.py` 串行写入 `G1/F1/B2/C4/G1`；formal journal=`2385`（2300 baseline + 85 live），`gen_coverage.py --check`=`848 rows / 477 carried judgments / 0 tombstones`，anchors=`10/10`。`gap-too-fast`/`discovery-collapse` 按 `testend/rig/formal-evidence/SURF-094-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate。统一长门禁已通过，完整记录=`testend/rig/formal-evidence/batch-45-gate-20260825.md`：`make verify`、backend `testend=300.030s`、rig=`50/50`、`gofmt`/coverage/anchors/alarms/diff/process audit 全绿；下一前线由提交后决定。P12 的 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-093 完成，i18n/coldStart 首启与语言轴闭环

`SURF-093 i18n/coldStart` 已完成真实 App 五级 `G1/F1/B2/C4/G1`。首轮 `RIG_SEED=0` 冷启动真实走查发现：onboarding 第一帧和创建中提示已是中文，但释放到空白 Chat 后仍泄漏 `What should we dig into?`、`Auto`、`Mention an entity`、`Attach files`；红 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-051818` 不入账。stop-and-fix 补齐 `coldStart` 全组文案与这四个同屏 Chat 键，重新生成 slang，新增完整冷启动 11 键和 Chat 4 键精确回归，focused suite=`11/11`。

修复后绿色 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-052124`：空 workspace 首帧真实显示 `工作 №001`、中文艺术家/馆藏署名、中文作品名、`创建工作区`、`工作区名称`；输入后 AX 显示创建动作，创建中显示 `正在准备工作区…`；进入 Chat 后真实 AX 与画面一致显示 `自动`、`想从哪里开始？`、`提及实体`、`添加附件`、`语音输入`、`想聊点什么？`。共享 onboarding→Chat 过渡无卡死、跳变、clipping 或 overlap。名称冲突由 API 错误映射与 focused `workspace_create_control_test.dart` 覆盖，本次不伪造重复创建 mutation。

五通道封口：screen=`46.655000s / 2784x1808 / H.264 / 60fps`；backend=`108` 行，SSE=`8` 行，frontend=`4` 行，llmtap=`10` 行。三流 SSE clean connect/EOF；本路径没有发送 Chat 消息，故没有伪造业务 durable frame 或 completion；managed gateway 只记录 readiness/接线。frontend 仅正常 Dart VM 与已审阅 IMK 宿主噪声，无 Flutter/Dart/布局/Unhandled 红线。终帧=`sessions/20260825-052124/evidence/SURF-093-final.png`，正式证据=`sessions/20260825-052124/evidence/SURF-093-i18n-coldStart-five-level.md`，调查=`testend/rig/formal-evidence/SURF-093-i18n-coldStart-investigation-20260825.md`。

五格已由 `judge.py` 串行写入 `G1/F1/B2/C4/G1`；formal journal=`2380`（2300 baseline + 80 live），`gen_coverage.py --check`=`848 rows / 476 carried judgments / 0 tombstones`，anchors=`10/10`。写账后 `gap-too-fast`/`discovery-collapse` 由 `testend/rig/formal-evidence/SURF-093-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，红场语言缺陷仍保留、未被统计警报掩盖，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check` clean。当前批次=`45/50`，未到 50 格不跑统一长门禁、不提交；下一前线为 `SURF-094`。P12 的 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-092 完成，i18n/ref 引用类型与真实执行闭环

`SURF-092 i18n/ref` 已完成真实 App 五级 `G1/F1/B2/C4/G1`。静态反查确认 `AnRefPill` 的 11 个类型分支全部经过 `entityKindWord`；新增双语完整集合回归，英文/中文各 11 个 ref 词齐全，focused locale/ref suite=`12/12`。真实 App 走过实体、文库、MCP 设置和 Chat mention picker；选择 `sync_inventory` 后插入引用，发送最小问题，模型识别为函数引用并执行一次，返回 `synced=42`，消息区和 Activity 侧幕均显示同一成功结果。

真实 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-051028`：screen=`102.840000s / 2784x1808 / H.264 / 60fps`；backend=`228` 行，SSE=`76` 行，frontend=`4` 行，llmtap=`19` 行。三流 SSE 观察到 durable message open/tool close/message close 与 notification signal，seq 单调、delta 保持 `seq=0`；managed gateway proof/install/models/chat 穿过 tap，前端仅正常 VM 与已审阅 IMK 宿主噪声，无 Flutter/Dart/布局/Unhandled 红线。终帧=`sessions/20260825-051028/evidence/SURF-092-final.png`，正式证据=`sessions/20260825-051028/evidence/SURF-092-i18n-ref-five-level.md`，调查=`testend/rig/formal-evidence/SURF-092-i18n-ref-investigation-20260825.md`。

视觉边界如实记录：用户可见引用 chip 采用函数 glyph + `sync_inventory` 的紧凑表达，不重复显示 `函数`；类型词在语义/annotation 路径中保留，并由 11-kind 双语回归锁定。五格已由 `judge.py` 串行写入 `G1/F1/B2/C4/G1`；formal journal=`2375`（2300 baseline + 75 live），`gen_coverage.py --check`=`848 rows / 475 carried judgments / 0 tombstones`，anchors=`10/10`。`gap-too-fast`/`discovery-collapse` 由 `testend/rig/formal-evidence/SURF-092-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，最终 `alarms.py check` clean。当前批次=`40/50`，未到 50 格不跑统一长门禁、不提交；下一前线为 `SURF-093`。P12 的 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-091 完成，i18n/shell 壳层状态与原生可达性闭环

`SURF-091 i18n/shell` 已完成真实 App 五级 `G1/F1/B2/C4/G1`。首轮真实 AX 树发现顶部四海洋中三个折叠图标槽是无名原生按钮；截图看起来正常，但键盘/屏幕阅读器用户无法发现它们。stop-and-fix 为 `an_ocean_switcher.dart` 的每个槽补 `semanticLabel: it.label` 与 `semanticFocusable: true`，新增 `an_ocean_switcher_test.dart`，修复后 focused suite=`35/35`。

最终 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-050144`：真实 AX 暴露 `对话/实体/调度/文库`，逐一切换成功；设置入口、workspace 快捷菜单中的 `新建工作区/工作区设置`、通知托盘独立接管左岛、`收起侧栏/展开侧栏` 收展均可达且状态闭合。`comingSoonTitle/comingSoonHint` 仍由 `_OceanPlaceholder/_RailPlaceholder` 保留，但当前 `OceanKind` 五值全部 built，产品中不存在可点击的未建海洋；该不可达不变量已在证据中明确记录，没有伪造点击。

五通道封口：screen=`112.400000s / 2784x1808 / H.264 / 60fps`；backend=`198` 行，SSE=`4` 行，frontend=`4` 行，llmtap=`10` 行。D1、health、三流连接、受管 key tap wiring、窗口录制均通过；frontend 仅正常 Dart VM 行，无 Flutter/Dart/布局/Unhandled 红线。最终帧=`sessions/20260825-050144/evidence/SURF-091-final.png`，正式证据=`sessions/20260825-050144/evidence/SURF-091-i18n-shell-five-level.md`，调查=`testend/rig/formal-evidence/SURF-091-i18n-shell-investigation-20260825.md`。

五格已由 `judge.py` 串行写入 `G1/F1/B2/C4/G1`；formal journal=`2370`（2300 baseline + 70 live），`gen_coverage.py --check`=`848 rows / 474 carried judgments / 0 tombstones`，anchors=`10/10`。写账后 `gap-too-fast`/`discovery-collapse` 由 `testend/rig/formal-evidence/SURF-091-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check` clean。当前批次=`35/50`，未到 50 格不跑统一长门禁、不提交；下一前线为 `SURF-092 i18n/ref`。P12 的 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-090 完成，i18n/attach 附件状态与 AX 可达性闭环

`SURF-090 i18n/attach` 已完成真实 App 五级 `G1/F1/B2/C4/G1`。首轮真实附件走查发现：附件 chip 和失败重试动作虽然视觉上存在，但没有进入原生 AX 树；这不是观察器漏报，而是实际产品可发现性缺陷。stop-and-fix 为 `an_attachment_chip.dart` 增加带文件名和状态的根语义，为 `AnInteractive` 增加可选语义标签/可聚焦能力，并在 `an_composer.dart` 建立附件 strip/Stack 的显式语义边界；focused Flutter=`36/36`，视觉布局不变。

最终 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-044311`：真实 AX 树可读 `surf090-broken.png, 正在准备媒体…`、`取消媒体准备`、失败态 `surf090-broken.png, 媒体准备失败` 和 `重试媒体准备`；无效 PNG 的失败/重试路径真实执行，后端日志中的 decode WARN 是故意构造的负路径证据，不是应用崩溃。有效 JPEG 真实经受管网关上传、视觉调用和 Chat 完成，最终回答与附件目的相符。取消按钮已可通过 AX 定位，但无效文件约 1 秒内完成，立即点击与 worker 完成发生竞态，本 session 未捕获 `preparation/cancel` 请求；该边界已在正式证据中如实标注，后端 `media_preparation_test.go` 覆盖取消端点，未将其冒充为端到端成功。

五通道封口：screen=`363.483333s / 2784x1808 / H.264 / 60fps`；backend=`491` 行，SSE=`76` 行，frontend=`4` 行，llmtap=`43` 行。受管网关 proof challenge/install/media upload/complete/chat 均为预期 `200/201`；SSE 三流真实连接，delta 保持 `seq=0`，durable close/notification 序列单调且无 gap；frontend 仅正常 VM/IMK 行，无 Flutter/Dart/布局/Unhandled 红线。最终帧只含 Anselm，证据=`sessions/20260825-044311/evidence/SURF-090-i18n-attach-five-level.md`，调查=`testend/rig/formal-evidence/SURF-090-i18n-attach-investigation-20260825.md`。

五格已由 `judge.py` 串行写入 `G1/F1/B2/C4/G1`；formal journal=`2365`（2300 baseline + 65 live），`gen_coverage.py --check`=`848 rows / 473 carried judgments / 0 tombstones`，anchors=`10/10`。写账后 `gap-too-fast`/`discovery-collapse` 由 `testend/rig/formal-evidence/SURF-090-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check` clean。当前批次=`30/50`，未到 50 格不跑统一长门禁、不提交；下一前线为 `SURF-091 i18n/shell`。P12 的 400+ Journey 仍按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-088 完成，i18n/feedback 失败反馈闭环

#### 2026-08-25 当前前线重述：SURF-089 i18n/a11y 修复后五级入账，批次四十五 25/50

`SURF-089 i18n/a11y` 已完成真实 App 五级 `G1/F1/B2/C4/G1`。首轮真实 AX 检查发现 inline editor 只暴露匿名 `text field (settable)`；第一次原生桥实验又因多余的 `setAccessibilityElement(true)` 把角色变成 `unknown`，两次红场均保留为不计绿证据。最终修复只给 Flutter 内部原生 `FlutterTextField` 设置 `accessibilityLabel`，不改变其角色、输入协议或视觉布局。

绿色 session=`sessions/20260825-040519`：真实 AX 树进入编辑后显示 `text field (settable) 描述`，输入后显示 `Description: 描述, Value: Native AX`，取消后清除原生标签并回到 `添加简介…`；`更多操作`、关系图 `缩小/放大/适应画布`、字段专属铅笔和编辑态播报均保持正常。正式证据=`sessions/20260825-040519/evidence/SURF-089-i18n-a11y-five-level.md`，首轮调查=`testend/rig/formal-evidence/SURF-089-i18n-a11y-investigation-20260825.md`。

五格已由 `judge.py` 串行写入 `G1/F1/B2/C4/G1`，COVERAGE=`848 rows / 472 carried judgments / 0 tombstones`，`gen_coverage.py --check` clean；写账后触发的 `gap-too-fast`/`discovery-collapse` 已由 `testend/rig/formal-evidence/SURF-089-ledger-alarm-reaudit-20260825.md` 独立复审并 ack，`alarms.py check` 最终 clean。未到 50 格不跑统一长门禁、不提交。下一前线为 `SURF-090 i18n/attach`；P12 的 400+ Journey 仍按用户裁定推迟二期。

`SURF-088 i18n/feedback` 已完成真实 App 五级 `G1/F1/B2/C4/G1`。首轮真实 Function 路径发现 seed 的 `greet` 有必填 `name` 参数却没有输入声明，点击运行落出 Python `TypeError`；红 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-025554` 不入账。修复 `backend/cmd/seed/main.go` 补齐 `name: string` 输入并重建后，第二轮又发现失败详情的本地化摘要虽正确，但流式 traceback 仍泄漏进主输出终端；红 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-030052` 继续排除。修复 `entity_format.dart` 与 `run_terminal.dart`，将 traceback 从主输出移入可展开的 `技术详情`，并以 focused entity format=`3/3`、既有 run terminal=`8/8` 回归锁定。

最终绿色 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-030446` 使用全新数据，真实中文 App 走通：seed `greet` 显示 `name: string · 要问候的名字` 并成功运行；临时失败 Function 在真实详情页运行后，主界面显示 `执行失败，请检查输入后重试。`，主输出不再显示 traceback，展开 `技术详情` 可读完整异常、收起后恢复紧凑失败态；代码 Copy 显示 `已复制`。临时 fixture 通过 REST `DELETE 204` 清理，App 重新读取后回到两个 seed Function 基线，无残留选中项。

五通道封口：screen=`2696x1720 / 224.743333s / H.264 / 60fps`；backend=`330` 行无应用 WARN/ERROR/panic/fatal/未处理异常；SSE=`25` 行，messages/notifications/entities 三流真实连接并 clean EOF，实体成功/失败运行均有 durable open/close，gap=`0`；frontend 仅正常启动/Dart VM service，无 Flutter/Dart/RenderFlex/RenderBox/Unhandled 红线；llmtap 真实 gateway proof challenge/install/models 全 `200`；SQLite `integrity_check=ok`、foreign-key check 为空，执行表为 `1 ok + 1 deliberate failed`，失败 fixture 保留诚实 tombstone 而不在 live list 出现。正式证据=`sessions/20260825-030446/evidence/SURF-088-i18n-feedback-five-level.md`，独立警报复核=`testend/rig/formal-evidence/SURF-088-ledger-alarm-reaudit-20260825.md`。

五格串行写账后 formal journal=`2355`（2300 baseline + 55 live），`gen_coverage.py --check`=`848 rows / 471 carried judgments / 0 tombstones`；anchors=`10/10`。`gap-too-fast` 与 `discovery-collapse` 按独立复核证据 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check` clean。当前批次=`20/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`SURF-089 i18n/a11y`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-087 完成，i18n/run 运行卷宗闭环

`SURF-087 i18n/run` 已完成真实 App 五级 `G1/F1/B2/C4/G1`。真实中文 Scheduler 路径覆盖总览 KPI、完成/失败/运行中 run、失败节点图与节点台账、入口 payload、钉版引用、重放确认及取消。首轮发现失败 fallback 泄漏英文 `Execution failed.`，红场不入账；修复 scheduler run model 的错误投影、三处 UI fallback、双语 i18n key，并以 focused Flutter `65/65` 作为回归证据。修复后重跑又发现重放标题为 `重放这个 run?`，再次停下修为 `重放这次运行？`，同步批量重放和不可重放文案，重新生成产物，并在真实 modal 复验中文标题、说明和按钮。

绿色 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-024808`，最终录屏=`2784x1808 / 45.240s`，最终帧=`sessions/20260825-024808/frames-surf087-final.png`。五通道封口：backend=`115` 行、frontend=`3` 行均无应用红线；SSE=`16` 行，三流真实连接/EOF；llmtap=`1` 条 readiness；SQLite `integrity_check=ok`、foreign-key check 为空，flowruns=`5 completed / 6 failed / 2 running`，flowrun_nodes=`30`。本路径夹具在 witness 前播种、最终 UI 为只读走查，因此没有伪造业务 durable 帧或 LLM completion。最终视觉复核无 clipping/overlap/非用户跳变，失败态显示 `执行失败。`。正式证据=`sessions/20260825-024808/evidence/SURF-087-i18n-run-five-level.md`，独立警报复核=`testend/rig/formal-evidence/SURF-087-ledger-alarm-reaudit-20260825.md`。

五格串行写账后 formal journal=`2350`（2300 baseline + 50 live），`gen_coverage.py --check`=`848 rows / 470 carried judgments / 0 tombstones`；anchors=`10/10`。`gap-too-fast` 与 `discovery-collapse` 均按独立复审证据 ack，最终 `alarms.py check` clean；未改阈值、算法、法典、锚点或 gate。当前批次=`15/50`，未到 50 格不跑统一长门禁、不提交；下一前线=`SURF-088 i18n/feedback`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-086 完成，i18n/notifications 通知托盘闭环

`SURF-086 i18n/notifications` 已完成真实 App 五级 `G1/F1/B2/C4/G1`。全新 workspace/session=`ws_e67fcaccb6f5b77b` / `sessions/20260825-022809` 中，中文通知托盘真实走通 `通知` 入口、`今天` 分组与 9 条通知、单条深链即标已读、`仅显示未读`、组头 `全部已读`/`全部未读`、`deploy` 搜索命中、分组收展和 hover `标为已读`；未读 badge、列表、已读灰化和最终画面一致，无 clipping/overlap/非用户跳变。

五通道封口：screen=`2784x1808 / 281.475s`，最终帧=`sessions/20260825-022809/frames-surf086-final.png`；backend=`380` 行无应用 WARN/ERROR/panic/fatal/exception；SSE=`8` 行，messages/entities/notifications 三流真实连接并正常 EOF，本路径夹具在 witness 接管前已播种，不伪造业务 durable 帧；frontend=`45` 行只含已审阅的 AXTree tooling churn、IMK/CapsLock 宿主行和正常启动，无 Dart/Flutter/布局/Unhandled 红线；llmtap=`10` 行 readiness/managed gateway，无本路径 completion；REST unread-count=`9`、列表=`9`，SQLite `integrity_check=ok`、foreign-key check 为空。AX 复核=`sessions/20260825-022809/evidence/frontend-ax-review.md`，正式证据=`sessions/20260825-022809/evidence/SURF-086-i18n-notifications-five-level.md`，告警复核=`testend/rig/formal-evidence/SURF-086-ledger-alarm-reaudit-20260825.md`。

五级写账后正式 journal=`2345` 条（2300 baseline + 45 live），`gen_coverage.py --check`=`848 rows / 469 carried judgments / 0 tombstones`；`gap-too-fast` 已按独立复审证据 ack，未改阈值、算法、法典、锚点或 gate；`alarms.py check`=`clean (45 live judgments; 2300 baseline excluded)`。当前批次=`10/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `SURF-087 i18n/run`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-085 完成，i18n/library 文库、Skill 与真实 Chat 查询闭环

`SURF-085 i18n/library` 已完成真实 App 五级 `G1/F1/B2/C4/G1`。首轮真实场景发现中文 Chat composer 仍显示英文 `Ask anything…`；红 session=`sessions/20260825-021142` 不入账。stop-and-fix 将 `zh_CN.i18n.json` 的 `chat.placeholder` 改为自然中文 `想聊点什么？`，重新生成 slang 产物，并在 `locale_boot_test.dart` 锁定中英文两套值；focused locale=`3/3`。

修复后全新绿场=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-021948`，真实 App 走过 Library rail 的五篇文档、Skill rail 的三项 Skill、SURF-050 文档检查器的正文/大纲/属性/反向链接/展开全部，以及 surf051-inspector 的四文件/两绑定表单；所有可见中文文案、层级、间距、右岛内容均无 clipping/overlap/非用户跳变。回到 Chat 后 composer 确认显示 `想聊点什么？`；真实受管网关查询 `List the documents and skills in the current library and give me the count for each.` 走 `list_documents`，活动卡显示 `已列文档 · 5 个`，最终中文表格准确列出文档 `5`、技能 `3` 及其名称。

五通道封口：screen=`2784x1808 / 148.115s`，最终帧=`sessions/20260825-021948/frames-surf085-final.png`；backend=`281` 行无应用 WARN/ERROR/panic/fatal/exception；SSE=`132` 行，messages durable 末序 `14`、notifications `27`、entities `10` 单调，delta 保持 `seq=0`；frontend=`4` 行仅正常启动/VM 与已知 macOS IMK host noise，无 Flutter/Dart/RenderFlex/RenderBox/Unhandled/Exception；llmtap=`19` 行，真实 gateway challenge/install/models/chat 全 200，最终响应线缆含两行完整答案；SQLite `integrity_check=ok`、foreign-key check 为空。正式证据=`sessions/20260825-021948/evidence/SURF-085-i18n-library-five-level.md`，告警复核=`testend/rig/formal-evidence/SURF-085-ledger-alarm-reaudit-20260825.md`。

五级写账后正式 journal=`2340` 条（2300 baseline + 40 live），`gen_coverage.py --check`=`848 rows / 468 carried judgments / 0 tombstones`；`gap-too-fast` 按红绿 session、独立五通道复审和 stop-and-fix 回归确认是同批串行写账信号并 ack，未改阈值、算法、法典、锚点或 gate；`alarms.py check`=`clean (40 live judgments; 2300 baseline excluded)`。当前批次=`5/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `SURF-086 i18n/notifications`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-084 完成，i18n/scheduler 失败投影与审批/重放闭环

`SURF-084 i18n/scheduler` 已完成真实 App 五级 `G1/F1/B2/C4/G1`。首轮真实 scheduler 走查发现失败 run 的速览卡把 Python `Traceback`、本地路径、节点 ID 和运行时包装原文直接展示给用户；红 session=`sessions/20260825-014625` 不入账。该信息可留在后端/SSE 诊断证据中，但不应成为用户理解失败原因的前置负担。

stop-and-fix 收紧 `frontend/lib/features/scheduler/ui/scheduler_run_model.dart` 的用户投影：traceback 只保留最终异常原因，移除本地路径、Python 栈帧、function/node 技术包装，并补 `scheduler_run_model_test.dart`；focused Flutter=`26/26`。绿色 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-014850` 使用修复后重新构建的 App，失败速览与完整 run 卷宗均只显示 `SURF-029 deliberate failure 1`，同时保留失败状态、钉版 v1、节点台账、甘特、入口 payload 和因果图。

同一绿色 session 真实走通 scheduler 总览 KPI（在跑/等你/24h 失败/下次调度空态）、approval `通过`、失败 run 的 Graph/Open/full detail、失败节点 `重放` 确认（重跑 1 个失败节点、复用 1 个已完成结果）与重放后的失败状态；最终画面层级清楚，无 clipping/overlap/非用户跳变或未解释英文 scheduler chrome。五通道 `rig-check`/`rig-down` 全绿；screen=`2784x1808 / 188.261667s`，backend=`318` 行无 WARN/ERROR/panic/fatal，SSE=`57` 行含 run start、node success/failure、approval resolve、run terminal 与 replay failure，frontend=`3` 行仅正常启动/VM，llmtap challenge/install/models 全 200。正式证据=`sessions/20260825-014850/evidence/SURF-084-i18n-scheduler-five-level.md`，告警复核=`testend/rig/formal-evidence/SURF-084-ledger-alarm-reaudit-20260825.md`。

五级写账完成后正式 journal=`2335` 条（2300 baseline + 35 live），`gen_coverage.py --check`=`848 rows / 467 carried judgments / 0 tombstones`，本批次=`50/50`。`gap-too-fast` 按红绿 session、原始五通道证据和回归测试独立复审并 ack，未改阈值、算法、法典、锚点或 gate；统一长门禁已通过（`make verify`、`make -C backend testend`=`314.193s`、rig=`50/50`、gofmt/compile/diff/process audit 全绿），本批已提交 `0177b9cf`。下一原子前线为 `SURF-085 i18n/library`；P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-083 完成，i18n/entities 全实体面与空输出日志闭环

`SURF-083 i18n/entities` 已完成真实 App 五级 `G1/F1/B2/C4/G1`。首轮真实实体详情走查发现一个产品真相问题：函数先打开日志页显示空态，再从同一挂载详情页运行一个没有 stdout/stderr 的函数，右侧执行终端更新了，但日志页直到离开并重新进入才出现记录。红 session=`sessions/20260825-012354` 不入账。

stop-and-fix 修复共享 `entitystream.Writer.Close`：启用的空输出执行现在也必须发 durable `open → close`，同时保留重复收尾幂等；补 backend `TestWriter_CloseWithoutWritesEmitsTerminal` 与 Flutter `function logs refresh after a durable empty-run close` 回归。绿色 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-013336`，真实 App 在同一函数详情页先打开空日志、再运行后立即显示 `1 完成 / 0 失败` 与 `manual · ok`，SSE 同一 block id 观测到 `open`/`close completed`，修复不是只在 provider 层伪刷新。

同一绿色 session 还真实覆盖实体总览五计数牌、8 实体/5 关系图、函数概览/版本/日志/运行、处理器常驻调用与日志、智能体挂载/提示词/真实网关唤起、工作流版本/串行治理/手动 run、控制分支与版本、审批模板与规则、暂停/冷/热触发器的配置/活动/派发，以及各自成功/空态/终态。五通道 `rig-check`/`rig-down` 全绿；backend=`448` 行且无 WARN/ERROR/panic/fatal，SSE=`103` 行含实体与 workflow durable 终态，frontend 仅正常 Flutter VM/启动行，llmtap challenge/install/models/chat 全 200；终帧抽检只含 Anselm，未发现新的产品视觉缺陷。正式证据=`sessions/20260825-013336/evidence/SURF-083-i18n-entities-five-level.md`，告警复核=`testend/rig/formal-evidence/SURF-083-ledger-alarm-reaudit-20260825.md`。

五级写账触发的 `gap-too-fast` 已独立重读红绿 session、五通道原始证据和 stop-and-fix 回归后 ack，未改阈值、算法、法典、锚点或 gate。正式 journal=`2330` 条（2300 baseline + 30 live），`gen_coverage.py --check`=`848 rows / 466 carried judgments / 0 tombstones`，当前批次=`45/50`；未到 50 格不跑统一长门禁、不提交。下一原子前线由 formal sequence gate 决定；P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-082 完成，i18n/settings 三段目录与 13 面板闭环

`SURF-082 i18n/settings` 已完成真实 App 五级 `G1/F1/B2/C4/G1`。首轮真实设置走查发现中文
Models & keys 的场景行仍泄漏原始英文 `Agent`；红 session=`sessions/20260825-010946` 不入账。
修复 `frontend/lib/i18n/zh_CN.i18n.json` 的 `scenarioAgent`、`referenceAgent`、
`referenceAgentOverride` 为 `智能体`、`智能体默认模型`、`智能体覆盖`，重新生成 slang 产物并补双语
locale 回归；修复后真实 App 逐一走过通用、通知、对话、模型与密钥、MCP 服务器、记忆、沙箱、工作区、
存储与日志、高级限额、网络、快捷键、关于共 13 个面板，三段目录与动态空态均保持中文产品语义。

设置搜索在真实 App 切换 English 后通过真实键盘输入验证：`model` 命中 `Models & keys`，`proxy` 命中
`Network` 及 `HTTP proxy`/`HTTPS proxy`/`Bypass` 项；中文分组与 hint 命中由纯函数/widget 门禁覆盖。
Computer Use 的 paste 只改可见文本、不派发 Flutter `onChanged`，已确认是观察器输入限制，不计产品缺陷。
正式证据=`sessions/20260825-011352/evidence/SURF-082-i18n-settings-five-level.md`，告警复核=
`testend/rig/formal-evidence/SURF-082-ledger-alarm-reaudit-20260825.md`；绿色 session 五通道
`rig-check`/`rig-down` 全绿，录屏终帧只含 Anselm，frontend 仅已知 IMK host noise。

五级写账触发的 `gap-too-fast` 已独立复审并 ack，未改阈值、算法、法典、锚点或 gate。正式 journal=`2325`
条（2300 baseline + 25 live），`gen_coverage.py --check`=`848 rows / 465 carried judgments / 0 tombstones`，
focused locale=`3/3`、settings search=`all passed`，当前批次=`40/50`；未到 50 格不跑统一长门禁、不提交。
该格完成时下一原子前线为 `SURF-083 i18n/entities`；其后 SURF-083 已在上方整体重述并将批次推进到 `45/50`。P12 的 400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-080 完成，detail-push 十二 kind 闭环

#### 2026-08-25 当前前线重述：SURF-081 完成，i18n/chat 双语思考标签 stop-and-fix

`SURF-081 i18n/chat` 已完成真实 App 五级 `G1/F1/B2/C4/G1`。首轮中文 Chat 真实观察发现回答上方
`thought` 与流式态 `thinking` 是未翻译的 UI 文案；红 session 不入账。修复
`frontend/lib/i18n/zh_CN.i18n.json` 为 `思考`/`思考中`，重新生成 slang 产物，并补双语回归；修复后
真实 App 重新构建，English/简体中文均走过 Chat rail、composer、历史回答、流式思考态、turn actions，
真实回答 `acceptance-ping`/`live-ping` 均收口。正式证据=`sessions/20260825-010531/evidence/SURF-081-i18n-chat-five-level.md`，
红 session=`sessions/20260825-005929` 明确排除；最终帧只含 Anselm，frontend 仅已知 IMK host noise。

五级写账触发的 `gap-too-fast` 已由 `testend/rig/formal-evidence/SURF-081-ledger-alarm-reaudit-20260825.md`
独立复审并 ack，未改阈值、算法、法典、锚点或 gate。正式 journal=`2320` 条（2300 baseline + 20 live），
`gen_coverage.py --check`=`848 rows / 464 carried judgments / 0 tombstones`，focused locale=`3/3`，
当前批次=`35/50`；未到 50 格不跑统一长门禁、不提交。下一原子前线仍由 formal sequence gate 决定；P12 的
400+ Journey 继续按用户裁定推迟二期。

`SURF-080 settings/detail-push` 已完成真实 App 五级 `G1/F1/B2/C4/G1`。源代码声明的 12 个 kind
全部真实到达：`addKey/editKey/sandboxInstall/mcpServer/mcpAdd/mcpImport/mcpMarket/mcpInstall/
addMemory/memory/addWorkspace/workspace`；空 MCP roster 的 15 秒 registry 超时后正常落到内置 `102`
条快照，没有把 Loading 误判成产品 defect。为了覆盖只有实体存在时才可达的面，构造并删除了本地
memory、custom key、失败 stdio MCP 和非当前 workspace 夹具；最终 REST 真相为一 workspace、一个受管
Anselm key、零 MCP、零 memory。正式证据=`sessions/20260825-004915/evidence/SURF-080-settings-detail-push-five-level.md`，
补充 detail session=`sessions/20260825-002854`；窗口级录屏抽帧确认只含 Anselm。

本格 stop-and-fix 修复了台架本身的 stale recorder：App 重启后即使几何不变，只要 macOS window ID
变化也必须切新录制段；`rig-rebind-app.sh`、回归测试和 `testend/rig/README.md` 已同步。修复后的真实
rebind=`760→769` 同几何并通过五通道 `rig-check`；旧 window-ID 段不计证据。静态台架回归=`37/37`，
backend/frontend 无应用红线，SSE 三流与 llmtap managed bootstrap 均正常。正式 journal=`2315` 条
（2300 baseline + 15 live），`gen_coverage.py --check`=`848 rows / 463 carried judgments / 0 tombstones`，
当前批次=`30/50`；未到 50 格不跑统一长门禁、不提交。下一原子前线仍由 formal sequence gate 决定；P12 的
400+ Journey 继续按用户裁定推迟二期。

#### 2026-08-25 当前前线重述：SURF-079 完成，台架改为窗口级录制

**账本 gate 已按用户裁定恢复历史基线**：完整 runtime journal 不可恢复，但用户明确裁定“不回头全部重验，继续走”；`rebuild_ledger.py --write --acknowledge-history` 将当前 `COVERAGE` 的 `2300` 个 carried 单格写入正式 `RIG_HOME`，逐条标记 `source=coverage-baseline`，并保存 `ledger-baseline.json`。基线不进入实时漂移曲线，后续真实 `judge.py` 裁决才进入；`judge.py` 硬校验 baseline 单格集合仍是当前清册子集。连续性审计见 [`testend/rig/formal-evidence/ledger-continuity-audit-20260825.md`](../../../testend/rig/formal-evidence/ledger-continuity-audit-20260825.md)。

`SURF-078 settings/panel-shortcuts` 已正式写账 `G1/F1/B2/C4/G1`：用户手动把第一行改为 `⌘J`，离开设置后仍持久化；第二行尝试 `⌘J` 显示冲突且不覆盖；Escape 取消录制；Reset all 恢复默认值；回到 Chat 后 `⌘J` 真实收起再展开左侧岛。session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260824-233028`，证据=`sessions/20260824-233028/evidence/SURF-078-settings-panel-shortcuts-formal.md`；五通道封口、应用红线 clean，`COVERAGE` 在该格后为 `848 rows / 461 carried judgments / 0 tombstones`。

`SURF-079 settings/panel-about` 已在**修正后的窗口级录制台架**完成正式五级 `G1/F1/B2/C4/G1`。真实 App 走通 About 版本区、`Checking…` 加载态、GitHub Releases 无 published release 时的诚实 `Couldn't check...` 结果、Engine version、字体与 MiSans/SIL 许可致谢、诊断复制和 `Copied` 反馈；clipboard 实值为 `Anselm 0.1.0 · engine dev · macos Version 26.5.2 (Build 25F84)`。没有发现产品或视觉 defect。

正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-001953`，证据=`sessions/20260825-001953/evidence/SURF-079-settings-panel-about-five-level.md`；窗口录屏 `screencapture -l 643`，`2784x1808 / H.264 / 49.323333s`，封口抽帧确认只含 Anselm。旧矩形录屏 session=`20260825-000908` 发现终帧被 Codex 宿主污染，已明确拒绝、不入账；`rig-up`、`rig-rebind-app`、`rig-check` 已统一改为按 window ID 捕获，未知遮挡仍硬失败，规则与理由同步在 `testend/rig/README.md`。五通道为 backend 无应用红线、SSE 三流连接并 clean EOF、frontend 无 Flutter/Dart/布局红线、llmtap challenge/install/models 全 200；本设置路径无业务 durable frame 或模型 completion，均未虚构。

该格写账触发 `gap-too-fast`，复审证据=`testend/rig/formal-evidence/SURF-079-ledger-alarm-reaudit-20260825.md`：五级是同一真实 session 的集中序列化，不是无证据橡皮章；未改阈值、算法、法典、锚点或 gate，已 ack，`alarms.py check`=`10 live judgments / 2300 baseline judgments excluded` clean。当前正式 journal=`2310` 条，`gen_coverage.py --check`=`848 rows / 462 carried judgments / 0 tombstones`；当前批次=`20/50`，下一原子前线为 `SURF-080`，未到 50 格不跑统一长门禁、不提交。P12 的 400+ Journey 继续按用户裁定推迟二期。

`SURF-075 settings/panel-storage` 已完成真实 App + managed gateway 五级验收。真实覆盖 Storage & logs 的数据目录、磁盘/数据库/附件统计、诊断复制、Run 历史保留、数据库压缩、Reset local preferences，以及用户明确确认后的不可逆 Factory reset。用户在真实危险区输入 `Anselm` 并点击 `Erase everything & relaunch`；旧 App/sidecar 优雅停止，replacement App 回到 `Create a workspace` onboarding，旧 workspace 没有幽灵残留。

正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260820-121523`，data root=`/Users/sunweilin/Library/Containers/website.anselm.app/Data/.anselm-surf075-formal-r4`，workspace=`ws_1741cdc98bf0b39c`，旧 App/sidecar=`57551/57583`，replacement App/sidecar=`57682/57684`，replacement port=`58408`。录屏原段=`322.903333s`，重启后段=`17.951667s`，合并=`340.870000s / 2560x1584 / H.264 / 60fps`；正式证据=`sessions/20260820-121523/evidence/SURF-075-settings-panel-storage-five-level.md`，警报复审=`sessions/20260820-121523/evidence/SURF-075-ledger-alarm-reaudit.md`。

五通道封口：backend=`119` 行，无 panic/fatal/WARN/ERROR/traceback；ssetap=`966` 行，messages/entities/notifications 各真实连接，未记录 gap，确定性 reset 路径无耐久业务帧；frontend=`227` 行，无 Unhandled/FlutterError/RenderFlex/Dart/应用 panic 红线；llmtap=`10` 行，managed challenge/install/models 全 `200`，本路径无 completion 不虚构。数据 root 与 `anselm.db` 在 reset 后被真实移除，新 App 显示 onboarding；`rig-check`/`rig-down`、录屏 ffprobe 和进程收台通过。重启后窗口 Y 坐标产生 1px 变化，conductor 封存旧段并以新 crop 启动第二段，未使用 stale crop。

`SURF-075` 五级 `G1/F1/B2/C4/G1` 已串行写入，formal ledger=`2320→2325 judgments`，COVERAGE=`848 rows / 457→458 judged / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast`/`discovery-collapse` 已按独立 session、外部 backend 红尝试、App-owned rebind、五通道原始 journal 和 10/10 anchor calibration 逐条复审并 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2325 judgments)`。批次四十三达到 `50/50`；统一长门禁已通过：root `make verify` 的 frontend/backend/docs/demo 全绿，Flutter 四组=`5376 tests`，完整 `make -C backend testend`=`288.411s`，rig=`44/44`，changed-Go `gofmt`/diff/process audit 全绿。提交前只剩最终 staged diff 审计；下一原子前线为 `SURF-076`。P12 400+ Journey 按用户裁定推迟二期。

`SURF-076 settings/panel-limits` 已完成五级 `G1/F1/B2/C4/G1`：真实 App 中打开 Advanced limits，确认机器级范围、17 个 schema 字段和五组滚动布局，真实修改与非法回滚均可由用户目的驱动完成；PATCH/GET、Reset 结果与 backend/REST 真相一致，编辑、滚动、错误回滚和确认收口没有观察到非用户触发的内容跳变；scope badge、group hierarchy、row descriptions、units、range copy、modified-row reset affordance 和 destructive confirmation 的视觉层级清楚且一致，新用户从 Settings 侧栏可自行找到入口。正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260820-133336`，证据=`sessions/20260820-133336/evidence/SURF-076-settings-panel-limits-five-level.md`；五通道已封口，anchors=`10/10`，alarms=`clean`。formal ledger=`2325→2330 judgments`，COVERAGE=`848 rows / 459 judged / 0 tombstones`，批次四十四=`5/50`。L5 后统计警报按原阈值打开，已独立重审并 ack，未改阈值/算法/法典；下一格为 `SURF-077`。

`SURF-077 settings/panel-network` 已完成五级 `G1/F1/B2/C4/G1`：真实 App 从 Settings 侧栏进入 Network，看到 machine scope、三字段、Save 和重启注记；空值直连与填写/清空两条用户目的均可达；两次整体 PATCH、返回值、离开重进的持久化状态和最终 `{}` 均与 backend/REST 真相一致；字段编辑、离开重进、保存提示和清空收口没有观察到非用户触发的内容跳变；scope badge、purpose hint、label-above rhythm、mono inputs、restart warning callout 和 primary Save hierarchy 清楚克制，新用户不读文档也能找到入口并理解重启后生效。正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260820-134625`，证据=`sessions/20260820-134625/evidence/SURF-077-settings-panel-network-five-level.md`；五通道已封口，formal ledger=`2330→2335 judgments`，COVERAGE=`848 rows / 460 judged / 0 tombstones`，批次四十四=`10/50`。L5 后统计警报按原阈值打开，已独立重审并 ack，未改阈值/算法/法典；下一格为 `SURF-078`。

`SURF-078 settings/panel-shortcuts` 已完成一次真实 App 五通道走查，但**尚未裁决、不得写绿账**。Settings → Shortcuts 入口、六条全局命令、逐键帽静息态、录制态、无修饰键拒绝、Escape 取消和 Reset all 均真实可见；backend=`450` 行、SSE=`9` 行、frontend=`3` 行、llmtap=`10` 行，录屏=`376.895000s / 2560x1584 / H.264 / 60fps`，无 backend/frontend 红线。正式证据=`sessions/20260820-135637/evidence/SURF-078-settings-panel-shortcuts-blocked.md`。当前阻塞是 Computer Use `sky.press_key` 在 macOS 上未向 Flutter 注入 `meta/control` 状态：`super+9`、`meta+9`、`cmd+9`、`command+9`、`ctrl+9` 和 `super+shift+9` 均被 App 正确识别为无修饰键，因此不能诚实验证成功改绑、冲突拒绝、持久化、单项 Reset 及改绑后全局快捷键。仓内 S6 widget/binding tests=`8/8`，但不替代真实 App 证据；不直接改偏好、不伪造通过。正式 ledger/COVERAGE 保持 `2335 / 848 rows·460 judged / 0 tombstones`，批次四十四仍=`10/50`；下一动作是恢复可注入 macOS Command 的真实键盘通道后原地续跑 `SURF-078`，未到 50 格不跑统一长门禁、不提交。P12 400+ Journey 按用户裁定推迟二期。

SURF-075 的出厂重置因本轮重新验证再次触发 stop-and-fix，但不新增判决：外接 backend 的 `child=null`、App sandbox 拒绝 `/private/tmp`、以及直接 exec 同 bundle 不留 replacement 均被分流为台架/编排前置失败。修复为 App-owned + 默认容器数据根 `.anselm`，并恢复 `app_relaunch.dart` 的 `open -n <bundle>` LaunchServices 重启语义。最终 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260820-132029` 中，旧 App/sidecar=`76065/76097` graceful stop，数据根消失，replacement=`76191/76193` 回到 `Create a workspace`；`rig-rebind-app.sh` 与 `rig-check.sh` 五通道全绿。该复核已被上方当前前线整体重述覆盖；不要把旧的 `2325 / 848·458 / 50/50` 当成当前状态。

#### 历史快照: SURF-073 settings/panel-sandbox

`SURF-073 settings/panel-sandbox` 已完成真实 App + managed gateway 五级验收。真实覆盖健康门健康态与 degraded 失败/Retry 恢复、机器级磁盘字节、Python 3.13 安装与删除、被环境引用的 Python 3.12 删除保护、未引用运行时删除取消/确认、Functions/Handlers/MCP/Skills/Conversations 五 owner tab、环境删除取消/确认和 GC 两步确认。真实键盘输入非法 dotnet 版本立即得到可执行版本提示；一次 `set_value` 只改变可见字段未触发 Flutter `onChanged` 的仪器观察被排除并清理，不算产品缺陷。

正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260820-001124`，data=`/private/tmp/anselm-data-surf073-20260820-r1`，workspace=`ws_a8955c11bf9eccd4`，录屏=`572.355000s / 2560x1584 / H.264 / 60fps`；正式证据=`sessions/20260820-001124/evidence/SURF-073-settings-panel-sandbox-five-level.md`，警报复审=`sessions/20260820-001124/evidence/SURF-073-ledger-alarm-reaudit.md`。

五通道封口：backend=`726` 行，唯一 WARN 是故意将 sandbox 路径替换为文件以验证 degraded health gate，随后 Retry 恢复；真实 endpoint 证据含 runtime install `201`、runtime-in-use `409`、runtime delete `204`、env delete `204`、GC `200`、bootstrap failure/retry `200`、invalid version `422`，无 panic/fatal/exception/traceback。ssetap=`11` 行，三流独立连接并捕获 direct delete/GC 的 `sandbox.env_deleted` durable 帧；frontend=`4` 行仅正常启动/VM/已知 macOS CapsLock host noise；llmtap=`10` 行，managed challenge/install/models 全 `200`，本确定性设置路径无 completion；`rig-check`/`rig-down` 通过并封存进程。focused Flutter=`47/47`。`judge.py` 串行写入 `G1/F1/B2/C4/G1`，formal ledger=`2310→2315 judgments`，COVERAGE=`848 rows / 455→456 judged / 0 tombstones`，anchors=`10/10`。`gap-too-fast`/`discovery-collapse` 按 SURF-073 独立复审逐条 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2315 judgments)`。下一原子前线为 `SURF-074 settings/panel-workspaces`，本批已完成 `40/50`，未到 50 格不跑统一长门禁、不提交。P12 400+ Journey 按用户裁定推迟二期。

#### 历史快照: SURF-072 settings/panel-memory

`SURF-072 settings/panel-memory` 已完成真实 App + managed backend 五级验收。真实覆盖 Memory 空态/名册、All/Pinned 投影、搜索命中与无匹配、新建 slug 失败与合法值恢复、创建并置顶、编辑锁名、内容保存、未保存面包屑离开保护、删除取消和最终物理删除。首轮真实走查发现两个必须 stop-and-fix 的产品问题：合法 slug 输入后旧错误残留；详情有未保存修改时面包屑直接绕过保护。首轮不入账；代码修复后重新构建真实 App，合法输入即时清错，面包屑与 Escape 统一走 detail pop guard，`Keep editing` 留在详情，`Discard` 才离开，并新增 shell 回归测试。

修复后验证 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-235804`，删除收口 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260820-000144`，data=`/private/tmp/anselm-data-surf072-20260819-r1`，workspace=`ws_be9766a8964b8449`，录屏=`121.830000s + 84.088333s`；正式证据=`sessions/20260820-000144/evidence/SURF-072-settings-panel-memory-five-level.md`，警报复审=`sessions/20260820-000144/evidence/SURF-072-ledger-alarm-reaudit.md`。修复前红 session=`sessions/20260819-234423` 仅作反例证据，不计绿。

五通道封口：修复验证 backend=`186` 行、删除收口 backend=`139` 行，无应用 panic/fatal/exception/traceback/布局溢出红线；唯一 `400` 是故意缺少必填描述/内容的预期校验拒绝，补齐后真实 `200`。ssetap 两轮独立连接 messages/entities/notifications，捕获 `memory.created` 与 `memory.deleted` durable notification；frontend=`4/3` 行仅正常启动/VM 与已知 macOS IMK host noise；llmtap wiring 通过，本确定性 Memory 路径无模型 completion，不虚构调用。`rig-check`/`rig-down` 两轮通过并封存进程。focused Flutter=`68/68`。`judge.py` 串行写入 `G1/F1/B2/C4/G1`，formal ledger=`2305→2310 judgments`，COVERAGE=`848 rows / 454→455 judged / 0 tombstones`，anchors=`10/10`。`gap-too-fast`/`discovery-collapse` 由 SURF-072 独立复审后逐条 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2310 judgments)`。下一原子前线为 `SURF-073 settings/panel-sandbox`，本批已完成 `35/50`，未到 50 格不跑统一长门禁、不提交。P12 400+ Journey 按用户裁定推迟二期。

#### 历史快照: SURF-071 settings/panel-mcp

`SURF-071 settings/panel-mcp` 已完成真实 App + managed gateway 五级验收。空态市场真实显示 `0-100 of 102 items`，搜索 `context7` 收敛到单卡并可打开包含 runtime、必填环境变量和 Install/Cancel 的计划页；没有提交外部 API key。手动表单真实切换 stdio、sse、streamable-http，提交本地不存在命令后列表与详情均诚实显示 `failed` 和具体 sandbox 错误；Tools、Call history、stderr 三个审计标签分别显示 `No tools`、`No calls yet`、`No output yet`，Reconnect 和 soft-delete 入口保持可达。

同一真实 App 中有效 `mcpServers` JSON 导入得到 `Imported 1 · skipped 0`，重复同名导入得到 `Imported 0 · skipped 1`；删除确认明确写出 `soft delete`，确认后回到空态市场，列表无残留。第一次中文输入法标点导致的非法 JSON 被记录为 Computer Use 输入限制，切换英文输入法后同一路径成功，不把仪器伪故障升级为产品缺陷；没有产品级 stop-and-fix 缺陷。

session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-232740`，data=`/private/tmp/anselm-data-surf071-20260819-r1`，workspace=`ws_470266a26e97918d`，录屏=`564.475000s`；正式证据=`sessions/20260819-232740/evidence/SURF-071-settings-panel-mcp-five-level.md`，警报复审=`sessions/20260819-232740/evidence/SURF-071-ledger-alarm-reaudit.md`。

五通道封口：backend=`660` 行无 WARN/ERROR/panic/FATAL；ssetap 发现并连接 messages/entities/notifications，捕获两次实体 connecting→failed、两次 `mcp.installed` 和两次 `mcp.removed`，durable notification seq=`1..4`；frontend=`5` 行仅正常启动/VM/CapsLock 与已知 macOS IMK host noise；llmtap=`13` 行，managed challenge/install/models/quota 全 `200`，没有提交外部凭证；`rig-check` 在 App 运行期间五通道 physically observing，`rig-down` 封存录屏并清空进程组。focused Flutter=`47/47`。`judge.py` 串行写入 `G1/F1/B2/C4/G1`，formal ledger=`2300→2305 judgments`，COVERAGE=`848 rows / 453→454 judged / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast`/`discovery-collapse` 已由 SURF-071 独立重审并串行 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2305 judgments)`。下一原子前线为 `SURF-072 settings/panel-memory`，本批已完成 `30/50`，未到 50 格不跑统一长门禁、不提交。P12 400+ Journey 按用户裁定推迟二期。

#### 历史快照: SURF-069 settings/panel-models-keys

`SURF-069 settings/panel-models-keys` 已完成真实 App + managed gateway 五级验收。全新工作区 onboarding 后进入 Settings → Models & keys，真实覆盖受管免费档卡、克隆音色空库存、受管密钥行、六类场景默认模型和 Search keys 空态。免费档显示 `Anselm Free · Auto multimodal`、`0 / 1B` 和 reset 时间；音色空态明确要求助手从音频附件登记，并显示 `2 of 2 slots free`，没有把永久库存位写成会自动恢复的日配额。Dialogue、Utility、Agent、Image generation、Speech synthesis、Video generation 六个 Change 入口逐一真实展开并关闭，生成场景的 `Anselm Free (gateway managed)` 与对话场景的 `Anselm Auto / Gateway-managed` 边界清楚；Refresh quota 与 Refresh model list 后面板回到稳定状态，未产生配置漂移。没有产品级 stop-and-fix 缺陷。

session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-224143`，data=`/private/tmp/anselm-data-surf069-20260819-r1`，workspace=`ws_b3a9e6654c009416`，录屏=`518.718333s / 2560x1584 / H.264 / 60fps`。关键帧=`SURF-069-models-keys-top.jpeg`、`SURF-069-models-keys-scenarios.jpeg`，正式证据=`sessions/20260819-224143/evidence/SURF-069-settings-panel-models-keys-five-level.md`，警报复审=`testend/rig/formal-evidence/SURF-069-ledger-alarm-reaudit.md`。

五通道封口：backend=`593` 行无 WARN/ERROR/panic/FATAL；ssetap=`8` 行，workspace 创建后自动发现并连接三流，设置纯读路径无业务 durable 帧，停机正常断开；frontend=`4` 行仅正常启动/VM/已知 macOS IMK host noise；llmtap=`16` 行，managed proof/install/models/quota wire 全部经过 tap 且响应 `200`；`rig-check`/`rig-down`、focused Flutter=`55/55`、coverage、diff、进程审计通过。`judge.py` 串行写入 `G1/F1/B2/C4/G1`，formal ledger=`2290→2295 judgments`，COVERAGE=`848 rows / 451→452 judged / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast`/`discovery-collapse` 已由 `SURF-069-ledger-alarm-reaudit.md` 独立重审并串行 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2295 judgments)`。下一原子前线由 formal sequence gate 决定，本批已完成 `20/50`，未到 50 格不跑统一长门禁、不提交。P12 400+ Journey 按用户裁定推迟二期。

#### 历史快照: SURF-068 settings/panel-chat

`SURF-068 settings/panel-chat` 已完成真实 App + managed gateway 五级验收。全新工作区 onboarding 后进入 Settings → Chat，真实完成右岛自动登台 `Never → First per chat`、发送键切换到 `⌘Enter sends`、Web fetch `Local fetch → Jina proxy → Local fetch`，并从默认对话模型行真实跳转到 Models & keys 后返回。真实聊天经 managed gateway 得到 `OK.`；第二个真实回合触发 `Glob`，右岛/Transcript 显示可解释工具活动，用户点击 Stop 后显示 `Interrupted`，后端与 SSE 同步为 cancelled，发送区恢复可用。没有把 Computer Use 不支持的组合键名误判成产品缺陷，也没有把按产品定义不属于 stage-worthy 集合的 `Glob` 不自动登台误记为缺陷。相邻观察是模型把“当前工作目录”解释为 `~`，递归 glob 等待约 53 秒后被主动停止，已保留为后续工具意图/workdir 引导审计项，不计入 Chat 设置行的绿格。

session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-221915`，data=`/private/tmp/anselm-data-surf068-20260819-r1`，workspace=`ws_02acc0a8ce4f704e`，录屏=`963.813333s / 2560x1584 / H.264 / 60fps`。录屏覆盖 Chat 设置初态/切换、Models & keys 跳转、真实 `OK.` 聊天、Glob 活动和取消收尾；正式证据=`sessions/20260819-221915/evidence/SURF-068-settings-panel-chat-five-level.md`，警报复审=`testend/rig/formal-evidence/SURF-068-ledger-alarm-reaudit.md`。

五通道封口：backend=`1063` 行无 WARN/ERROR/panic/FATAL；ssetap=`79` 行，三流真实连接，聊天和 Glob 的 open/close/tool_result/取消帧均被独立 witness 记录；frontend=`5` 行仅正常启动/VM/已知 macOS IMK 与 CapsLock host noise；llmtap=`25` 行，managed proof/chat wire 全部经过 tap 且响应 `200`；`rig-check`/`rig-down`、SQLite 最终 `web_fetch_mode=local`、focused Flutter=`97/97`、coverage、anchors、diff、进程审计通过。`judge.py` 串行写入 `G1/F1/B2/C4/G1`，formal ledger=`2285→2290 judgments`，COVERAGE=`848 rows / 450→451 judged / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast`/`discovery-collapse` 已由 `SURF-068-ledger-alarm-reaudit.md` 独立重审并串行 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2290 judgments)`。下一原子前线由 formal sequence gate 决定，本批已完成 `15/50`，未到 50 格不跑统一长门禁、不提交。P12 400+ Journey 按用户裁定推迟二期。

#### 历史快照: SURF-067 settings/panel-notifications

`SURF-067 settings/panel-notifications` 已完成真实 App + managed gateway 五级验收。全新工作区 onboarding 后进入 Settings → Notifications，真实走过 `All → Needs you → Silent`、系统/应用内通知和失败/审批/需关注三类胶囊登记的 off/on 往返，并恢复默认。通过真实 approval workflow 验证设置不是静态表单：默认 `Needs you + approvals on` 弹出可操作的 `Awaiting approval` 胶囊；关闭审批登记后新 pending 事件不弹顶带但仍保留 inbox 真相；切换 `All` 后绕过分类登记再次弹出；点击真实 `Approve` 后显示 `Approved` 并沿同一线收口，flowrun 进入 completed。没有产品级 stop-and-fix 缺陷。

session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-220500`，data=`/private/tmp/anselm-data-surf067-20260819-r1`，workspace=`ws_b987f930f7df592c`，录屏=`622.090000s / 2560x1584 / H.264 / 60fps`。关键帧与正式证据=`sessions/20260819-220500/evidence/SURF-067-settings-panel-notifications-five-level.md`，警报复审=`testend/rig/formal-evidence/SURF-067-ledger-alarm-reaudit.md`。五级=`G1/F1/B2/C4/G1`，formal ledger=`2280→2285 judgments`，COVERAGE=`848 rows / 449→450 judged / 0 tombstones`，anchors=`10/10`，alarms=`clean`。P12 400+ Journey 按用户裁定推迟二期。

#### 历史快照: SURF-066 settings/panel-general

`SURF-066 settings/panel-general` 已完成真实 App + managed gateway 五级验收。全新工作区 onboarding 后进入 Settings → General，真实覆盖主题 `Dark → System → Light`、缩放 `0.8× → 1.1×` 与当前屏幕不可容纳档 `1.25×/1.5×` 的禁用点击、界面/内容/代码三条字体轴、语言 `English → 简体中文 → System` 双写、记住窗口、开机自启和自动检查更新。所有改动最终恢复默认；没有产品级 stop-and-fix 缺陷。当前屏幕的高档缩放由 `WindowZoom.maxFactor()` 计算并以禁用视觉和 disabled semantics 呈现，点击不会假装应用。

session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-214739`，data=`/private/tmp/anselm-data-surf066-20260819-r1`，workspace=`ws_60c1fd52053065b7`，录屏=`673.656667s / 2560x1584 / H.264 / 60fps`。关键帧=`SURF-066-theme-dark.png`、`SURF-066-theme-system.png`、`SURF-066-zoom-min.png`、`SURF-066-zoom-max.png`、`SURF-066-font-menu-selection.png`、`SURF-066-content-font-serif.png`、`SURF-066-code-font-fira.png`、`SURF-066-language-english.png`、`SURF-066-language-chinese.png`、`SURF-066-window-startup-visible.png`、`SURF-066-defaults-before-switches.png`，正式证据=`sessions/20260819-214739/evidence/SURF-066-settings-panel-general-five-level.md`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-066-ledger-alarm-reaudit.md`。

五通道封口：backend=`744` 行无应用红线；ssetap 三流真实连接并正常 EOF 收束，本路径无业务耐久帧不虚构；frontend=`4` 行仅正常启动/VM/已知 macOS IMK host warning；llmtap=`10` 行，managed proof/install/models 全 `200`，设置路径无 completion；`rig-check`/`rig-down`、SQLite 最终 `language=en`、focused Flutter=`38/38 + 12/12`、coverage check、diff check、进程审计通过。`judge.py` 串行写入 `G1/F1/B2/C4/G1`，formal ledger=`2275→2280 judgments`，COVERAGE=`848 rows / 448→449 judged / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast`/`discovery-collapse` 已由独立证据重审并串行 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2280 judgments)`。下一原子前线为 `SURF-067 settings/panel-notifications`，本批已完成 `5/50`，未到 50 格不跑统一长门禁、不提交。P12 400+ Journey 按用户裁定推迟二期。

#### 历史快照: SURF-065 settings/rail-search

`SURF-065 settings/rail-search` 已完成真实 App + managed gateway 五级验收。全新工作区 onboarding 后进入 Settings，真实验证空查询三段目录、`zzzz` 无匹配安静空态、真实退格清空后目录恢复，以及 `zoom` 跨面板结果：General/UI zoom、Storage & logs/Reset local preferences、Shortcuts/Zoom in/Zoom out/Reset zoom。面板头点击只跳面板，具体项点击滚动到目标并在浮层头带下等高洗亮；没有幽灵结果、旧目录残留或产品级 stop-and-fix 缺陷。输入全部使用真实键盘事件，没有用 `set_value` 代替 Flutter 回调。

session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-212554`，data=`/private/tmp/anselm-data-surf065-20260819-r1`，workspace=`ws_53a147068c051721`，录屏=`127.786667s / 2560x1584 / H.264 / 60fps`。五通道封口：backend=`176` 行无应用红线；ssetap 三流真实连接、本路径无聊天/实体业务耐久帧不虚构；frontend=`5` 行仅正常启动/VM/已知 IMK host warning；llmtap managed proof/install/models=`200`，设置路径无 completion；rig-check/rig-down、settings focused=`42/42`、Dart analyze、coverage check、进程审计通过。证据=`sessions/20260819-212554/evidence/SURF-065-settings-rail-search-five-level.md`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-065-ledger-alarm-reaudit.md`。

五级=`G1/F1/B2/C4/G1`，formal ledger=`2270→2275 judgments`，COVERAGE=`848 rows / 447→448 judged / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast`/`discovery-collapse` 经独立重审并串行 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2275 judgments)`。批次四十二已达 `50/50`；统一长门禁已通过：anchors `10/10`、rig Python `42/42`、`make verify` 四门全绿、`make -C backend testend` 全量黑盒 `283.748s` 通过、gofmt/diff/process-listener audit 全绿。下一原子前线为 `SURF-066 settings/panel-general`，本批工作树审计后提交。P12 400+ Journey 按用户裁定推迟二期。

`SURF-064 settings/rail-system` 已完成真实 App + managed gateway 五级验收。全新工作区 onboarding 后进入 Settings，System 段真实打开 Storage & logs、Advanced limits、Network、Shortcuts、About。Storage 显示 sidecar 返回的真实数据目录、磁盘/数据库/附件 reclaimable 数值、90 days retention、Compact、Reset local preferences 与明确 factory reset 危险区；Limits 显示机器级说明、schema 驱动的 agent/context/timeout 分组、当前值、范围与 default；Network 显示 HTTP/HTTPS/no-proxy、Save 和 engine restart 提示；Shortcuts 显示六个全局键位与 Reset；About 显示 app/engine 版本、更新失败的人话原因、字体许可，点击 Copy diagnostics 后出现 `Copied` 回执。没有执行不可逆 factory reset，本格没有产品级 stop-and-fix 缺陷。

session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-212039`，数据=`/private/tmp/anselm-data-surf064-20260819-r1`，workspace=`ws_b34dfc17c20ccd09`，录屏=`116.973333s / 2560x1584 / H.264 / 60fps`。关键帧=`SURF-064-storage.png`、`SURF-064-limits.png`、`SURF-064-network.png`、`SURF-064-shortcuts.png`、`SURF-064-about.png`，正式证据=`sessions/20260819-212039/evidence/SURF-064-settings-rail-system-five-level.md`。

五通道封口：`rig-check` 在 App 运行期间证明五通道物理归属；backend=`171` 行无应用 panic/fatal/exception/stack trace/RenderFlex/RenderBox；ssetap 三流连接，本路径无聊天/实体耐久业务帧不虚构；frontend=`4` 行仅正常启动/VM 与已知 macOS IMK host warning，无 Flutter/Dart/assertion/overflow 红线；llmtap=`10` 行，managed proof/install/models 全 `200`，系统设置路径不触发 LLM 不伪造 completion；rig-down 录屏正常收束，进程审计无残留。系统 focused suite=`26/26`、Dart analyze、coverage check、git diff check 通过。

`judge.py` 串行写入 `G1/F1/B2/C4/G1`，formal ledger=`2265→2270 judgments`，COVERAGE=`848 / 446→447 / 0`，anchors=`10/10`。写账触发的 `gap-too-fast`/`discovery-collapse` 经 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-064-ledger-alarm-reaudit.md` 独立复审并串行 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2270 judgments)`。批次四十二由 `40→45/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `SURF-065 settings/rail-search`。P12 400+ Journey 按用户裁定推迟二期。

`SURF-063 settings/rail-resources` 已完成真实 App + managed gateway 五级验收。全新工作区 onboarding 后进入 Settings，Resources 段真实包含 Models & keys、MCP servers、Memory、Sandbox、Workspaces。Models & keys 显示 managed `Anselm Free · Auto multimodal`、配额、cloned voices settled-empty、managed key、六个 scenario defaults 与 Search keys empty state；MCP 首次进入真实显示 loading rows，随后落为 `0-100 of 102 items` marketplace，并保留 `Add manually` / `Import mcp.json`；Memory 与 Sandbox 分别显示诚实空态，Workspaces 显示当前 workspace、蓝点、`Current` 与 `New workspace`。没有把 loading、settled-empty、managed identity 或旧 workspace 内容混为一谈，本格没有产品级 stop-and-fix 缺陷。

session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-211359`，数据=`/private/tmp/anselm-data-surf063-20260819-r1`，workspace=`ws_627041276bc74cad`，录屏=`133.883333s / 2560x1584 / H.264 / 60fps`。关键帧=`SURF-063-models-keys.png`、`SURF-063-mcp-market.png`、`SURF-063-memory-empty.png`、`SURF-063-sandbox-empty.png`、`SURF-063-workspaces.png`，正式证据=`sessions/20260819-211359/evidence/SURF-063-settings-rail-resources-five-level.md`。

五通道封口：`rig-check` 在 App 运行期间证明五通道物理归属；backend=`196` 行无应用 panic/fatal/exception/stack trace/RenderFlex/RenderBox；ssetap 三流连接，本路径无聊天/实体耐久业务帧不虚构；frontend=`4` 行仅正常启动/VM 与已知 macOS IMK host warning，无 Flutter/Dart/assertion/overflow 红线；llmtap=`13` 行，managed proof/install/models 全 `200`，资源路径不触发 LLM 不伪造 completion；rig-down 录屏正常收束，进程审计无残留。资源 focused suite=`77/77`、Dart analyze、coverage check、git diff check 通过。

`judge.py` 串行写入 `G1/F1/B2/C4/G1`，formal ledger=`2260→2265 judgments`，COVERAGE=`848 / 445→446 / 0`，anchors=`10/10`。写账触发的 `gap-too-fast`/`discovery-collapse` 经 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-063-ledger-alarm-reaudit.md` 独立复审并串行 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2265 judgments)`。批次四十二由 `35→40/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `SURF-064 settings/rail-system`。P12 400+ Journey 按用户裁定推迟二期。

`SURF-062 settings/rail-prefs` 已完成真实 App + managed gateway 五级验收。全新工作区 onboarding 后进入 Settings，左岛真实展示 `Preferences` 下的 `General`、`Notifications`、`Chat` 三面板；三面分别覆盖外观/缩放/字体/语言/启动、通知级别与 OS/in-app/capsule 开关、sidestage/send key/web fetch 与 Models & keys 入口。真实键盘输入 `theme` 后结果态显示 `General → Theme`，点击后跨面板定位、搜索清空、目标行滚到浮层头带下并一次性洗亮；输入 `login` 后 `Launch at login` 长页定位同样成立。启动项开关真实从 off→on→off，AX 状态、画面和默认恢复动作一致，没有留下偏好污染；本格没有产品级 stop-and-fix 缺陷。

session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-210545`，数据=`/private/tmp/anselm-data-surf062-20260819-r1`，workspace=`ws_54a9a9eaa18dc054`，录屏=`257.628333s / 2560x1584 / H.264 / 60fps`。关键帧=`SURF-062-rail.png`、`SURF-062-general.png`、`SURF-062-notifications.png`、`SURF-062-chat.png`、`SURF-062-search-theme.png`、`SURF-062-search-login.png`，正式证据=`sessions/20260819-210545/evidence/SURF-062-settings-rail-prefs-five-level.md`。

五通道封口：`rig-check` 在 App 运行期间证明五通道物理归属；backend=`297` 行无应用 panic/fatal/exception/stack trace；ssetap 三流均已连接，本路径无实体/聊天耐久业务帧不虚构；frontend=`5` 行仅正常启动/VM 与已知 macOS IMK host warning，无 Flutter/Dart/RenderFlex/RenderBox/Unhandled 红线；llmtap=`10` 行，managed proof/install/models 全 `200`，设置路径不触发 LLM 不伪造 completion；rig-down 录屏正常收束，进程审计无残留。设置 catalog/search/shell focused suite=`42/42`、Dart analyze、coverage check、git diff check 通过。

`judge.py` 串行写入 `G1/F1/B2/C4/G1`，formal ledger=`2255→2260 judgments`，COVERAGE=`848 / 444→445 / 0`，anchors=`10/10`。写账触发的 `gap-too-fast`/`discovery-collapse` 经 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-062-ledger-alarm-reaudit.md` 独立复审并串行 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2260 judgments)`。批次四十二由 `30→35/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `SURF-063 settings/rail-resources`。P12 400+ Journey 按用户裁定推迟二期。

`SURF-061 scheduler/run-inspector-node` 已完成真实 App + managed gateway 五级验收。真实构造的 loop workflow 产生同一 `work` 节点的 3 个 durable iterations；右岛检查器显示 `#0/#1/#2`，切换后输出与执行日志坐标逐轮变化。失败节点路径同时展示全文 traceback、无结果诚实态、执行日志状态和 `Replay the failed nodes` 原地动作；本格没有产品级 stop-and-fix 缺陷。

绿 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-205412`，数据=`/private/tmp/anselm-data-surf061-20260819-r1`，workspace=`ws_7a9b6f127158cb3c`，目标 run=`fr_2d4323570cff2460`，录屏=`333.648333s / 2560x1584 / H.264 / 60fps`。真实 App 的旗舰显示 `work ×3`、`route ×3`、`7 nodes · Completed 7`；选择 `work` 后右岛检查器可发现并切换 `#0/#1/#2`，`index=0/1/2` 与对应 execution ID 均真实变化。另一真实失败 run 的检查器显示完整 Error、`This node recorded no result.`、Execution log 和 Replay CTA。关键截图=`SURF-061-run-dossier-loop.png`、`SURF-061-inspector-iteration-0.png`、`SURF-061-inspector-iteration-1.png`、`SURF-061-inspector-failed-node.png`，正式证据=`sessions/20260819-205412/evidence/SURF-061-run-inspector-node-five-level.md`。

构造阶段第一次使用整数 CEL literal，后端诚实暴露 double/integer 类型不匹配；这是 fixture recipe 错误，不是产品 defect。该失败事实保留在 backend/SSE journal，随后通过公开 control `:edit` 改为 double literal 后从新版本运行，未改生产代码、不隐藏失败。

五通道封口：backend=`578` 行无应用 panic/fatal/exception/stack trace；ssetap=`152` 行，entities durable=`7..58`、notifications durable=`16..57` 单调，目标 run 的每轮 `seq=0` node frame 与最终 `run_terminal(completed)` 均被独立 witness 记录；frontend=`4` 行，仅正常启动、Dart VM 与已知 macOS IMK host warning，无 Flutter/Dart/RenderFlex/RenderBox/Unhandled 红线；llmtap 仅记录真实 managed proof/install/models，均=`200`，确定性 Scheduler 路径不伪造 completion。SQLite 7 行节点对账与 integrity check 通过，收台后无残留进程。

`judge.py` 串行写入 `G1/F1/B2/C4/G1`，formal ledger=`2250→2255 judgments`，COVERAGE=`848 / 443→444 / 0`，anchors=`10/10`。写账触发的 `gap-too-fast`/`discovery-collapse` 已由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-061-ledger-alarm-reaudit.md` 独立复审并串行 ack，未改阈值、算法、法典、锚点或 gate；最终 `alarms.py check`=`clean (2255 judgments)`。批次四十二由 `25→30/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `SURF-062 settings/rail-prefs`。P12 400+ Journey 按用户裁定推迟二期。

`SURF-060 scheduler/run-inspector-dossier` 已完成 stop-and-fix 后的真实 App + managed gateway 五级验收。红跑发现失败运行的右岛 dossier 没有展示本次运行实际收到的入口 payload；后端真实数据确认 payload 持久化在 trigger 节点 result 中。修复前保留红证据，不计绿；修复后在 dossier 的 Error 之前增加 `Entry payload` JSON 区段，从 durable trigger node result 展示完整入口数据，并补 focused Flutter regression 与 Scheduler 文档。

绿 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-204650`，红 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-204243`，数据=`/private/tmp/anselm-data-surf060-20260819-r3`，workspace=`ws_0204dbcd6673da77`，绿录屏=`206.026667s / 2560x1584 / H.264 / 60fps`。真实 App 从 Scheduler → Inactive → `surf052_failed` → failed run → `Open` 进入右岛，最终同时看见状态、pinned version、replay history、`Entry payload`（`body.index=5`、`body.mode=fail`）、Error 全文、Pinned refs 与 AI triage；点击 AI triage 后真实 Chat 回合完成，明确解释 deliberate failure 的完整因果链。截图=`SURF-060-green-dossier-entry-payload.png`、`SURF-060-green-triage-chat.png`，正式证据=`sessions/20260819-204650/evidence/SURF-060-run-inspector-dossier-five-level.md`，红证据=`sessions/20260819-204243/evidence/SURF-060-red-dossier-missing-payload.png`。

五通道封口：backend=`366` 行无 panic/fatal/exception/stack trace 红线；ssetap=`270` 行，messages durable=`1..22`、notifications durable=`1..12` 单调，真实回合包含 delta 与 completed close；frontend=`3` 行，仅正常 Dart VM service，无 Flutter/Dart/Unhandled 红线；llmtap proof challenge=`200`，三次 chat completion 响应均=`200`，request/response body 均封存；录屏已由 rig-down 正常收束，App/backend/ssetap/llmtap/recorder 无残留进程。`rig-check` 报告 five channels physically observing。

focused `scheduler_run_test.dart`=`39/39`、Dart analyze、rig-check/rig-down、ffprobe/process leak audit 通过。`judge.py` 串行写入 `G1/F1/B2/C4/G1`，formal ledger=`2245→2250 judgments`，COVERAGE=`848 / 442→443 / 0`，anchors=`10/10`。写账触发的 `gap-too-fast`/`discovery-collapse` 已由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-060-ledger-alarm-reaudit.md` 独立复审并串行 ack，未改阈值、算法、法典、锚点或 gate；最终 `alarms.py check`=`clean (2250 judgments)`。批次四十二由 `20→25/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线由 formal sequence gate 决定。P12 400+ Journey 按用户裁定推迟二期。

`SURF-059 scheduler/rail-inactive` 已完成 stop-and-fix 后的真实 App + managed gateway 五级验收。红跑用真实 API 停用带 5 次失败历史的 `surf052_failed`；展开 `Inactive 2` 后发现该历史行仍显示红色 live dot，违反「灰不占状态点位」。修复 `schedulerRailModel`：inactive 行只保留历史时间，不再生成 live status dot；同步新增 model regression 和 Scheduler feature 文档。

绿 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-203404`，红 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-203033`，数据=`/private/tmp/anselm-data-surf059-20260819-r1`，workspace=`ws_64f76fe1fdf9aa85`，绿录屏=`209.260000s / 2560x1584 / H.264 / 60fps`。真实 App 展开 Inactive 后显示 `surf052_failed 5m ago` 与 `surf052_inactive —`，无红色 live dot；Display options 关闭 `Show inactive` 后区块消失，再开启后 `Inactive 2` 与两行恢复一致。截图=`SURF-059-inactive-expanded-green.png`、`SURF-059-inactive-restored-green.png`、`SURF-059-final-green.png`，正式证据=`sessions/20260819-203404/evidence/SURF-059-rail-inactive-five-level.md`，红证据与警报复审分别为 `SURF-059-red-inactive-collapsed.png`/`SURF-059-red-inactive-red-dot.png` 和 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-059-ledger-alarm-reaudit.md`。

五通道封口：backend=`324` 行，无 `WARN|ERROR|panic|FATAL` 应用红线；ssetap 三流真实连接并记录 settle 阶段 workflow lifecycle durable frames，messages 本路径无聊天业务 frame 不虚构；frontend=`3` 行，仅 Dart VM 启动，无 Flutter/Dart/RenderFlex/RenderBox/assertion/Unhandled/Exception 红线；llmtap 真实 ready，本确定性 Scheduler 路径无 completion 不伪造；rig-down 后无 Anselm/llama/ssetap/llmtap/screenrecord 进程残留。focused provider=`13/13`、model=`15/15`、Dart analyze 无问题，rig-check/rig-down/ffprobe/process leak audit 通过。

五格=`G1/F1/B2/C4/G1`；`judge.py` 串行写入后 formal ledger=`2240→2245 judgments`，COVERAGE=`848 rows / 441→442 judged rows / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已以独立复审证据串行 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2245 judgments)`。批次四十二由 `15→20/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `SURF-060 scheduler/run-inspector-dossier`。P12 的 400+ Journey 继续按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-058 scheduler/rail-never-ran` 已完成真实 App + managed gateway 的五级验收。全新工作区真实 onboarding 后，公共 API 构造一条从未运行的 active workflow、带真实 run 历史的 active workflows 和一条 inactive workflow；Scheduler rail 首次显示 `Never ran 1`，子行保持初始折叠，`Inactive 1` 独立沉底。Computer Use 点击展开后只出现唯一真实 `surf052_never_ran` 行，计数仍为 1。随后真实启动 `fr_da9efc70f9a08841`，后端返回 completed 且 trigger/action 节点均完成；App 收到 durable 更新后，`Never ran` 段和计数消失，该 workflow 进入无头主段并按最近活动排序，inactive 段不受污染。没有重复行、空的墓碑段或 stale 折叠状态。

正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-201947`，数据=`/private/tmp/anselm-data-surf058-20260819-r1`，workspace=`ws_625a6279a8161d46`，录屏=`346.326667s / 2560x1584 / H.264 / 60fps`。五通道封口：backend=`572` 行，无 `WARN|ERROR|panic|FATAL` 应用红线；ssetap 三流真实连接，entities durable=`1..44`、notifications durable=`1..33` 单调无 gap，messages 本路径无聊天所以无 durable 行，不虚构；frontend 只有 App/VM 启动与已知 macOS IMK host 噪声，无 Flutter/Dart/RenderFlex/RenderBox/assertion/Unhandled/Exception 红线；llmtap managed challenge/install/models 均 HTTP 200，本确定性 Scheduler 路径无 completion，不伪造 LLM 证据。初始、展开、迁移画面分别封存为 `SURF-058-initial-collapsed.png`、`SURF-058-expanded.png`、`SURF-058-promoted-to-main.png`，正式证据=`sessions/20260819-201947/evidence/SURF-058-rail-never-ran-five-level.md`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-058-ledger-alarm-reaudit.md`。

五格=`G1/F1/B2/C4/G1`；anchors=`10/10`；`judge.py` 串行写入后 formal ledger=`2235→2240 judgments`，COVERAGE=`848 rows / 440→441 judged rows / 0 tombstones`；写账触发的 `gap-too-fast` 与 `discovery-collapse` 已针对本 session 独立复审并串行 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2240 judgments)`。focused Scheduler provider=`13/13`、model=`14/14`，rig-check/rig-down/ffprobe/process leak audit 通过；批次四十二由 `10→15/50`，未到 50 格不跑统一长门禁、不提交。下一原子前线由 `COVERAGE.md` formal sequence gate 决定；P12 的 400+ Journey 继续按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-057 scheduler/rail-main` 已完成 stop-and-fix 后的正式五级验收。首轮真实 App 通过真实 `:pause` 将两个 cron trigger 置为 `paused:true/listening:false`，REST 与独立 SSE 都确认 `nextFireAt` 缺席，rail 却仍显示 `in 3h`；这是产品级 stale data 缺陷，红帧与根因均已封存。修复在 `SchedulerRailController` 增加窄订阅：只对 `entities/trigger` 的 `status` signal 触发已有 300ms 去抖重取，activation/firing telemetry 不触发整 rail 重取；同步补 provider 正负回归和 Scheduler feature 文档。

修复后的真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-200757`，红 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-200109`，数据=`/private/tmp/anselm-data-surf057-20260819-r1`，workspace=`ws_751c44f801a46d07`，绿录屏=`200.778333s / 2560x1584 / H.264 / 60fps`。绿场景中暂停 trigger 正确回落为上次运行，恢复后回到 `in 3h`；真实完成 run `fr_10cf32bafb1a5505` 后活动排序稳定为运行中→healthy→failed；Display options 关闭 Show next fire 后 healthy 回落 `1m ago`，恢复默认后重新显示 `in 3h`；Name 排序与 Recent activity 排序均真实切换，Never ran/Inactive 始终折叠沉底。五通道封口：绿 backend 无应用 WARN/ERROR/panic/FATAL/Unhandled/RenderFlex/RenderBox/Exception，ssetap 三流连接并观察 trigger status、workflow run、approval 和 settle 信号，frontend 只有 Dart VM 行、无 Flutter/Dart/RenderFlex/RenderBox/assertion/Unhandled/Exception 红线，llmtap journal 非空且本确定性 Scheduler 路径诚实不虚构 completion。红证据=`sessions/20260819-200109/evidence/SURF-057-red-stale-trigger-meta.md`，绿证据=`sessions/20260819-200757/evidence/SURF-057-rail-main-five-level.md`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-057-ledger-alarm-reaudit.md`。

五格=`G1/F1/B2/C4/G1`；anchors=`10/10`；`judge.py` 串行写入后 formal ledger=`2230→2235 judgments`，COVERAGE=`848 rows / 439→440 judged rows / 0 tombstones`；写账触发的 `gap-too-fast` 与 `discovery-collapse` 已针对红绿两 session 独立复审并串行 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2235 judgments)`，`gen_coverage.py --check`=`clean (848 rows, 440 carried judgments, 0 tombstones)`。focused Scheduler provider=`13/13`、model=`14/14`，`make -C docs verify`、rig Python=`42/42`、Python compile、Shell syntax、ffprobe、process leak audit、`git diff --check` 均通过；批次四十二由 `5→10/50`，未到 50 格不跑统一长门禁、不提交。下一原子前线由 `COVERAGE.md` formal sequence gate 决定；P12 的 400+ Journey 继续按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-056 scheduler/rail-overview-row` 已完成正式五级验收。真实 App 在 Scheduler rail 先验证无数据时固定首行 `Overview`；再经公共 API 构造真实 parked approval，画面同时出现 Overview 的琥珀等待点与右缘 `1`、中心 `Waiting 1`、右上审批卡和 `Waiting on you` 行。真实点击 `Approve` 后先显示明确回执，随后 durable refetch 收敛为 Overview 无等待徽标、中心 `Waiting 0` 和 `No approvals waiting on you.`。点击真实工作流行进入 workflow page，再点击新鲜 AX 树中的 Overview，返回 `/scheduler` 且选中态与中心详情均无残留；第二次 parked run 再次把计数从 0 拉回 1，证明正反状态闭环来自同一 inbox 真相源。

正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-194527`，数据=`/private/tmp/anselm-data-surf056-20260819-r1`，workspace=`ws_83b4627329714f23`，录屏=`593.678333s / 2560x1584 / H.264 / 60fps`。五通道封口：`rig-check` 在收台前五通道全绿，backend journal `705` 行无应用 WARN/ERROR/panic/FATAL/Unhandled/RenderFlex/RenderBox/Exception，REST parked approval 与 UI 逐字段对账并在 settle 后收口；ssetap `113` 行，notifications/entities/messages 三流均连接，记录 `workflow.approval_pending`、run start、function close、parked/completed node 和 durable seq，`seq=0` delta 未推进游标；frontend journal 只有 Dart VM 与已知 macOS IMK host 噪声，无 Flutter/Dart/RenderFlex/RenderBox/assertion/Unhandled/Exception 红线；llmtap managed challenge/install/models 全 `200`，本路径为确定性 Scheduler，不虚构 completion。稳定帧=`sessions/20260819-194527/evidence/SURF-056-overview-zero.png`、`SURF-056-overview-waiting-1.png`、`SURF-056-workflow-selected.png`、`SURF-056-overview-return.png`；正式证据=`sessions/20260819-194527/evidence/SURF-056-overview-five-level.md`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-056-ledger-alarm-reaudit.md`。

五格=`G1/F1/B2/C4/G1`；anchors=`10/10`；`judge.py` 串行写入后 formal ledger=`2225→2230 judgments`，COVERAGE=`848 rows / 438→439 judged rows / 0 tombstones`；写账触发的 `gap-too-fast` 与 `discovery-collapse` 已以独立重审证据串行 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2230 judgments)`，`gen_coverage.py --check`=`clean (848 rows, 439 carried judgments, 0 tombstones)`。SURF-056 focused Flutter Scheduler=`57/57`，`rig-check`、`rig-down`、ffprobe 和 process leak audit 通过；批次四十二由 `0→5/50`，未到 50 格不跑统一长门禁、不提交。下一原子前线由 `COVERAGE.md` formal sequence gate 决定；P12 的 400+ Journey 继续按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-055 scheduler/run-relay` 已完成正式五级验收。真实 App 从 Scheduler workflow home 打开真实 run terminal，点击生产路径 `Open run page →` 进入 id-only `/scheduler/runs/:frId` relay；relay 正确解析宿主 workflow 并交棒 `/scheduler/w/{workflowId}/runs/{flowrunId}` 旗舰，不留下实现中转页或空白终点。最终画面保留 `Done`、pinned version、2 节点完成图、Timeline、Run dossier、pinned function/trigger refs；故意的 dead-id 负路径返回 `FLOWRUN_NOT_FOUND`，并由 route regression 锁定为可解释句子而非空白页。Computer Use 驱动早先无法可靠合成 rail 搜索 Return 的诊断已保留，但不冒充产品绿；本轮正式正路径由真实 production run-terminal relay 完成。

正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-191759`，数据=`/private/tmp/anselm-data-surf055-20260819-r1`，workspace=`ws_b0ddf3d9093275fc`，workflow=`wf_83b293643efa4b62`，primary run=`fr_4cc81cf274f208f2`，录屏=`262.258333s / 2560x1584 / H.264 / 60fps`。五通道封口：backend journal 最终 `408` 行、无未解释应用红线，REST run completed 且 pinned refs、entry payload、relay action result 全对账；ssetap `15` 行并观察 `seq=1 run_started → seq=2 function open → seq=0 delta → seq=3 function close → seq=4 run_terminal`，ephemeral delta 不推进 durable cursor；frontend journal 无 Flutter/Dart/RenderFlex/RenderBox/Unhandled/Exception/assertion 红线，仅已知 macOS IMK host 噪声；llmtap readiness 保留，确定性 scheduler 路径没有 completion，诚实不虚构。正式证据=`sessions/20260819-191759/evidence/SURF-055-run-relay-five-channel.md`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-055-ledger-alarm-reaudit.md`。

五格=`G1/F1/B2/C4/G1`；anchors=`10/10`；`judge.py` 串行写入后 formal ledger=`2220→2225 judgments`，COVERAGE=`848 rows / 437→438 judged rows / 0 tombstones`；写账触发的 `gap-too-fast` 与 `discovery-collapse` 已以独立重审证据串行 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2225 judgments)`，`gen_coverage.py --check`=`clean (848 rows, 438 carried judgments, 0 tombstones)`。统一长门禁亦已完成：anchors 10/10、rig Python 42/42、focused Scheduler 80/80、`make verify` 全绿、`make -C backend testend` 全量黑盒通过、shell/py_compile/diff/process leak audits 全通过。批次四十一由 `49→50/50` 正式收口并可提交；下一原子前线由 `COVERAGE.md` formal sequence gate 决定。P12 的 400+ Journey 继续按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-054 scheduler/run-flagship` 已完成 stop-and-fix 后的正式五级验收。首轮真实 App 发现横向钉版图在右岛打开时被压成不可读的细线；第二轮确认台架复用了旧 Flutter bundle，不能把旧画面当修复结果；两轮红现场均保留。修复增加只读 `reflowPinned` 展示开关，Run 旗舰在窄主轨按纵向重排同一张钉版图，默认图模型与编辑器仍尊重作者坐标。第三轮用新构建 App、真实受管网关和 Computer Use 重跑，完整图、节点标签和连线在右岛打开时均可读。

正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-185802`，数据=`/private/tmp/anselm-data-surf054-20260819-r3`，workspace=`ws_c170fe14c137fee5`，workflow=`wf_40a2b65d4d430fbc`，completed target=`fr_f66380fb2e86dc6d`，failed comparison=`fr_f464c9dc989c810c`。真实 App 逐帧完成 onboarding→Scheduler→workflow→run URL；卷宗头显示 `Done / 661ms / v1 pinned`，图、甘特、台账均有 5 节点事实。点击 graph `stage_validate` 后右岛、图、甘特、台账同选且输出为 `mode=ok, step=validate, value=order-054`；再从台账点击 `stage_transform`，同一选区切换且执行日志跟随，URL 选区契约由 focused route test 锁定。

五通道封口：`screen.mov`=`231.118333s`，窗口遮挡门和 recorder lifecycle 通过；backend PID=`81279` 在 `:9081` 归属正确，无应用 WARN/ERROR/panic；REST completed run 5 节点全 completed，activity 4 条按 intake→publish 为 `206/150/149/150ms`；ssetap=`47` 行，失败对照 run 的 `stage_validate` 真实 `run_terminal` 与 notification/attention 失败信号可见；frontend 无 Flutter/Dart/overflow/assertion 红线，仅保留已知 macOS `IMKCFRunLoopWakeUpReliable` host 噪声；llmtap challenge/install/models 全 `200`，该确定性 Scheduler 路径无 completion，诚实不虚构。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-185802/evidence/SURF-054-run-flagship-green.md`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-054-ledger-alarm-reaudit.md`。

五格=`G1/F1/B2/C4/G1`；anchors=`10/10`；`judge.py` 串行写入后 formal ledger=`2215→2220 judgments`，COVERAGE=`848 rows / 436→437 judged rows / 0 tombstones`；`gap-too-fast` 与 `discovery-collapse` 按同一 sealed session、红绿 stop-and-fix、失败对照路径和未变 anchors 独立复审并串行 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2220 judgments)`，`gen_coverage.py --check` clean。批次四十一由 `48→49/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线由形式序列决定。P12 的 400+ Journey 继续按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-038 entities/rail-control` 已在全新数据目录和真实 managed gateway 上完成正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-020352`，workspace=`ws_52e3d3d1863100ee`。真实 App + Computer Use 覆盖 Control rail 计数、搜索/清空、折叠/展开、三项选择、无匹配态、Overview、详情与 Versions；最终详情的两类输入、三条有序分支、CEL、emit 与 default/passthrough 稳定，无产品 defect。

`SURF-039 entities/rail-approval` 首轮红 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-022010` 暴露真实产品缺陷：搜索 `refund` 后 rail 只剩 `surf039_refund_gate`，中心却仍显示被排除的 `surf039_note_gate`，查询、列表和详情不一致。按 stop-and-fix 修复 `entity_rail.dart`：防抖查询明确排除当前选择时回到 Overview，命中时保留详情，清空时保持选择；新增 route-backed widget regression。全新数据目录的绿色 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-022641` 完成 Approval 三种规则形态、真实搜索排除、空结果、清空、详情、Versions、折叠/展开与最终稳定帧，未再出现 stale detail。

SURF-039 五通道封口：`screen.mov`=`214.663333s / 2560x1584 / H.264 / 60fps`，最终帧=`sessions/20260819-022641/final-frame.png`；backend `369` 行无 WARN/ERROR/panic/fatal，frontend 无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception 红线；ssetap 独立连接 notifications/messages/entities 三流，播种对应 durable notifications `16..18` 严格递增无 gap；llmtap managed proof/install/models 全 `200`；SQLite `PRAGMA integrity_check=ok`，三条 Approval/version rows 与 UI 逐字段一致。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-022641/evidence/SURF-039-entities-rail-approval-five-channel-green.md`；五格按 `G1/F1/B2/C4/G1` 写入。警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-039-ledger-alarm-reaudit.md`，两轮 `gap-too-fast`/`discovery-collapse` 均由红绿 session、五通道原始 journal、修复回归和 anchors `10/10` 独立复审并 ack，最终 `alarms.py check`=`clean (2145 judgments)`。

`SURF-040 entities/rail-trigger` 在全新数据目录 `/private/tmp/anselm-data-surf040-20260819-r1` 和 workspace=`ws_fbb258b6f3edf39a` 完成正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-024530`。fixture `testend/rig/seed_surf040.py` 通过公共 API 幂等构造 cron/webhook/fsnotify/sensor 四种 Trigger：hot cron 连接 active workflow，webhook 与 sensor 为 cold，fsnotify 保持 paused；真实 App + Computer Use 逐帧覆盖四类头部 source badge、Listening/Idle/Paused 与蓝点、Fire CTA 可用/禁用、配置和 payload 详情、Overview、搜索 `hot`/`cold`/`zzzz`、清空以及最终稳定 hot detail。真实点击 Fire 产生 activation=`tra_bc6fe650e5ee155e`、dispatch 与 flowrun=`fr_db91b4fc0799d77a`；UI 的 Dispatch 诚实显示 `run started`，REST/SQLite 继续对账到最终 `completed`，没有把中间回执误判为终态。未发现产品或视觉 defect，不需要 stop-and-fix。

`SURF-040` 五通道封口：录屏 `286.338333s / 2560x1584 / H.264 / 60fps`，最终帧=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-024530/final-frame.png`；backend journal 无 WARN/ERROR/panic/fatal/exception，frontend journal 仅正常启动、Dart VM 与已知 macOS 输入法宿主噪声，无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception/NoSuchMethodError 红线；ssetap 独立连接 notifications/messages/entities 三流，notifications durable=`16..24`、entities durable=`7,8,9,10` 严格有序并观察 `run_started→run_terminal(completed)`，messages 本路径无 durable frame（无 chat turn，诚实记为不适用）；llmtap managed proof challenge/install/models 全 `200`，本路径无 completion，不伪造 LLM 证据；SQLite `PRAGMA integrity_check=ok`，Trigger/Workflow/Activation/Firing/Flowrun 与 UI 逐字段对账。rig-check、rig-down、ffprobe 和前端红线扫描均通过。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-024530/evidence/SURF-040-entities-rail-trigger-five-channel-green.md`。

`SURF-041 entities/run-terminal` 在全新数据目录 `/private/tmp/anselm-data-surf041-20260819-r1`、workspace=`ws_61fa03f0cc98ae73`、正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-031703` 完成。真实 App + Computer Use 逐帧覆盖 Handler source/Call、Agent Invoke、Workflow Webhook `body` 映射、Function action、Recent 与 Scheduler pinned run dossier。首轮发现 Handler Code 卡漏掉 MethodSpec 的 `label` 参数；stop-and-fix 更新 `entity_format.dart` 的 source formatter，新增 `entity_format_test.dart`，修复后二进制复跑显示 `def inspect(self, label):`，真实键入 `ui-correct` 贯穿 UI/API/SQLite。Fixture 同时修正为真实 `entry.body.label/count`，旧失败 flowrun 历史保留，最终 `fr_d521c9d0e7525126` 为 v4/completed。

`SURF-041` 五通道封口：录屏=`665.585000s / 2560x1584 / H.264 / 60fps`；backend/frontend 无未解释应用红线；ssetap 三流真实连接，entities durable=`1..12`、notifications durable=`1`、messages 本路径无 durable chat frame，seq=`0` delta 未推进游标；llmtap 记录受管 gateway proof/bootstrap 与真实 Agent completion，Function/Handler/Workflow 未虚构 LLM 调用；SQLite `integrity_check=ok`，Handler/Agent/Workflow/flowrun 与 UI 对账。`rig-check`、`rig-down`、focused Flutter test、fixture compile、ffprobe 通过。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-031703/evidence/SURF-041-entities-run-terminal-five-channel.md`；警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-041-ledger-alarm-reaudit.md`，`gap-too-fast`/`discovery-collapse` 已按原阈值串行 ack，最终 `alarms.py check`=`clean (2155 judgments)`。

`SURF-042 entities/workflow-editor-inspector` 在重新构建的真实 App、managed gateway、Computer Use 和五通道台架上完成正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-040751`，workspace=`ws_2998f557f8cc1e2b`，workflow=`wf_9d05754c871a12c5`。真实画面逐帧覆盖 graph editor 初始空 inspector、Action 的 Function/Handler/MCP 引用族、Handler target/method、input mapping、Retry、Max attempts、Save/Discard、右岛关闭/重开与完整 8 节点/8 边画布。

本格首轮停线发现 MCP 无 server 时目标下拉打开为空白浮层；这不是可接受的空态。修复 `AnDropdown`：无选项且未声明说明时不可打开，声明 `emptyLabel` 时显示标准行高/内距的不可选解释；`NodeRefPicker` 为 MCP server/tool、Handler method 和通用 target 接入双语空态文案，并补组件与 picker regression。重建 App 后真实 MCP 空态显示 `No MCP servers configured yet`，无空白菜单；`set_value` 只改语义文本而未触发工作图脏态，也被真实键盘复验识别为无效路径，最终真实输入形成 `Unsaved changes`，Save 后显示 `New version saved`，Max attempts=`5`。源码回归 focused Flutter=`31/31`，dart format 通过。

五通道封口：录屏=`236.961667s / 2560x1584 / H.264 / 60fps`，成功帧=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-040751/evidence/SURF-042-retry-saved.jpeg`，MCP 空态帧=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-040751/evidence/SURF-042-mcp-empty-state.jpeg`；backend journal 真实记录 `POST /api/v1/workflows/wf_9d05754c871a12c5:edit status 200`，REST active version=`wfv_76f014eeabf70d23`/v3 且 `functionAction.retry.maxAttempts=5`，capability-check=`structurallyValid=true,resolved=true`；ssetap 三流真实连接并收到 notifications durable `workflow.edited` version 3；frontend/backend 红线为空；llmtap ready journal 存在但本路径无 LLM 调用，不虚构 completion。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-040751/evidence/SURF-042-entities-workflow-editor-inspector-five-channel.md`；五格按 `G1/F1/B2/C4/E4` 写入。写账触发的 `gap-too-fast`/`discovery-collapse` 由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-042-ledger-alarm-reaudit.md` 独立复审并串行 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2160 judgments)`。

`SURF-043 entities/graph-entity-card` 在全新数据目录 `/private/tmp/anselm-data-surf043-20260819-r1`、workspace=`ws_ebf2131f32f3925d`、正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-042026` 完成。fixture `testend/rig/seed_surf043.py` 通过公共 API 创建带描述/v1 的 Function，并让 Agent 与 deactivated Workflow 真实引用它；关系图因此返回 8 节点/5 边，Function 有两条 incoming `equip` 边。真实 App + Computer Use 逐帧验证 Overview graph preview → full graph explore → Function 右岛实体卡：kind 字形、完整名称、`v1`、描述、`REFERENCED BY` 两个 hydrated relation pills 和 `Open in detail` 均可见；点击 Workflow pill 后右岛正确切换为 Workflow 的 `EQUIPS` 卡，再回到 Function 并打开真实 Function detail，名称/版本/描述/code/interface/env ready 与卡片一致。没有 stale inspector、空白卡、白闪、裁切、重排或未解释跳变，不需要 stop-and-fix。

`SURF-043` 五通道封口：录屏=`167.395000s / 2560x1584 / H.264 / 60fps`；backend 无应用 WARN/ERROR/panic/fatal，REST `relgraph`/Function detail/workflow capability-check 与 UI 逐字段对账，`structurallyValid=true,resolved=true`；ssetap 三流真实连接，notifications durable=`16..21`（function/agent/trigger/workflow created 与 env 状态），entities durable=`7,8`（build open/close，中间 delta=`seq=0`），messages 本路径无 chat turn、无 durable frame，诚实不伪造；frontend 只有正常 App/平台/VM journal，无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception 红线；llmtap managed proof/install/models 全 `200`，本路径为 deterministic read path、无 completion 不虚构。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-042026/evidence/SURF-043-entities-graph-entity-card-five-channel.md`；五格按 `G1/F1/B2/C4/G1` 写入。写账触发的两条统计警报由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-043-ledger-alarm-reaudit.md` 独立复审，anchors=`10/10` 重校，串行 ack 后最终 `alarms.py check`=`clean (2165 judgments)`。

`SURF-044 library/draft` 在全新数据目录 `/private/tmp/anselm-data-surf044-20260819-r1`、workspace=`ws_867b0cc89d411afc`、正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-043243` 完成。真实 App + managed gateway + Computer Use 先在 Library 无选区落地四个空态引导，点击正文只聚焦不创建；真实键入 `SURF-044 draft body` 只产生一次 `POST /api/v1/documents`，草稿先认领 `doc_ba3237feabbeeb4b` 再导航，树刷新后唯一 `Untitled` 行被选中，右岛显示 `/Untitled`、`17 chars`、`19 B`；随后真实键入 `!` 仍落在原编辑器末尾，正文没有重挂或丢失，右岛更新为 `18 chars`、`20 B`。无 stop-and-fix defect。

`SURF-044` 五通道封口：`screen.mov`=`378.571667s / 2560x1584 / H.264 / 60fps`，Computer Use 空态/认领/终帧分别保留在同 session 的 `evidence/SURF-044-draft-empty.jpg`、`SURF-044-adopted.jpg`、`SURF-044-final.jpg`，并抽取 `SURF-044-video-final.jpg`；backend 无 WARN/ERROR/panic/FATAL/exception 红线，REST/SQLite `PRAGMA integrity_check=ok` 与 UI 逐字段一致；ssetap 三流真实连接，notifications durable=`16..17` 对应 `document.created`/`document.updated`，messages/entities 本路径没有 chat/entity mutation 故无 durable frame，诚实不伪造；frontend 仅正常 App/平台/VM journal，无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception；llmtap managed proof/install/models 六个状态观察全 `200`，本路径无 completion 不虚构。`measure diff` 的 adopted→final 归一帧 `changedFrac=0.00099`、变化盒只落在预期编辑/属性区域。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-043243/evidence/SURF-044-library-draft-five-channel.md`，五格按 `G1/F1/B2/C4/G1` 写入；警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-044-ledger-alarm-reaudit.md`，anchors=`10/10`，串行 ack 后最终 `alarms.py check`=`clean (2170 judgments)`。

`SURF-045 library/document` 在全新数据目录 `/private/tmp/anselm-data-surf045-20260819-r2`、workspace=`ws_be21c75959fb9fd0`、正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-045509` 完成。真实 App + managed gateway + Computer Use 逐帧覆盖 Library 文档树、长文档头部/正文/Outline 同滚页、Outline 跳转、连续滚动到底和末尾边界；初轮点击 `5. Review` 后标题落入固定 shell scrim，只有约一行可见，判为产品级遮挡缺陷，立即停线。

stop-and-fix 修改 `frontend/lib/features/library/ui/an_document_editor.dart`：Outline 跳转目标现在统一扣除固定 shell head band 与呼吸间距，新增 `headingScrollTarget` 回归测试，`library_test.dart` focused suite=`56/56`。重新构建真实 App 后，`5. Review` 标题稳定落在 scrim 下方且完整可读，继续小幅滚动后 active outline 正确跟随；滚到底无白缝，最后一项受 max extent 约束但正文完整可达，无新的跳变、裁切、重叠或焦点问题。fixture=`testend/rig/seed_surf045.py` 仅经公共 API 幂等构造 18 个标题、3083 字符长文档。

`SURF-045` 五通道封口：`screen.mov`=`102.518333s / 2560x1584 / H.264 / 60fps`，原始帧与修复后帧保留在 `sessions/20260819-045509/evidence/`，`measure diff` 两段变化盒均落在预期滚动内容区域；backend 无 WARN/ERROR/panic/FATAL/exception 红线，REST/SQLite 文档字段与 UI 对账且 `PRAGMA integrity_check=ok`；ssetap 三流真实连接，notifications durable=`16` 对应 `document.created`，messages/entities 本路径无对应 mutation 故无 durable frame，诚实不伪造；frontend 仅正常启动/平台/VM journal，无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception；llmtap managed proof/install/models 状态全 `200`，本路径无 completion 不虚构。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-045509/evidence/SURF-045-library-document-five-channel.md`，五格按 `G1/F1/B2/C4/G1` 写入；警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-045-ledger-alarm-reaudit.md`，anchors=`10/10`，两条统计警报串行 ack 后最终 `alarms.py check`=`clean (2175 judgments)`。

`SURF-054`、`SURF-055` 已加入五格绿；EP-230–EP-251、EP-220 及既有绿色项保持五格绿；EP-252–EP-257 debug-only 五格为 L1–L3 绿、L4/L5 按边界记 `na`，其余已列 SURF 面（含 SURF-003、SURF-028–SURF-055）均完成五级裁决。批次三十六、三十七、三十八、三十九、四十已完成统一门禁并由 `c9e7679c` 收口提交；批次四十一已 `50/50`，正式 ledger=`2225 judgments`，COVERAGE=`848 rows / 438 judged rows / 0 tombstones`，anchors=`10/10`，alarms=`clean`，统一长门禁已通过，待本批次提交；下一前线继续按 `COVERAGE.md` 的 formal sequence gate 推进。P12 的 400+ Journey 继续按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-053 scheduler/workflow-home` 在全新数据目录 `/private/tmp/anselm-data-surf053-20260819-r7`、workspace=`ws_7189416b4484a96e`、workflow=`wf_2ec6213e355a3288`、正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-182815` 完成。fixture 通过公共 API 构造 cron、webhook、paused 三个真实 trigger entry，以及 completed/failed/running 历史；真实 Flutter macOS App + managed gateway + Computer Use 覆盖 onboarding、Scheduler、workflow 首页、三入口 `Run now` 选择器、Webhook 手动运行、成功终态和 Cancel chooser。首轮真实多入口运行曾只显示 `invalid or ambiguous trigger entry node`，用户目的无法完成；红 session 保留，stop-and-fix 贯通后端 `entryNode`、HTTP `:trigger` 和前端 `_RunEntryPicker`/双语文案，重建 App 后 Webhook 路径真实完成，目标 flowrun=`fr_c851c8fc46870084`。

五通道封口：录屏=`319.870000s / 2560x1584 / H.264 / 60fps`，抽样帧保留 onboarding、Chat 空态、workflow 页面和 settle 终帧；外部窗口遮挡门通过，Computer Use 光标按仪器规则豁免；backend journal 无应用 WARN/ERROR/panic/fatal/exception，SQLite `integrity_check=ok`、foreign-key check 为空，REST/SQLite/UI 对账为 6 runs（`completed=3/failed=2/cancelled=1`）和 11 nodes；ssetap 三流真实连接，entities durable=`1..24`、notifications durable=`1..15` 唯一递增，目标帧闭合 `run_started→hook_work completed→run_terminal(completed)`，messages 本路径无业务 durable frame 不虚构；frontend 无 Flutter/Dart/RenderFlex/RenderBox/Unhandled/Exception 应用红线，唯一 `IMKCFRunLoopWakeUpReliable` 为 macOS 输入法平台通知并原样保留；llmtap managed proof/install/models 有状态请求全 `200`，本确定性 workflow 路径无 completion 不伪造。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-182815/evidence/SURF-053-scheduler-workflow-home-five-channel.md`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-053-ledger-alarm-reaudit.md`。

五格=`G1/F1/B2/C4/G1`；`judge.py` 在锚点重新校准通过后串行写入，formal ledger=`2210→2215 judgments`，COVERAGE=`848 rows / 435→436 judged rows / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast`/`discovery-collapse` 已按封存 session、红绿 stop-and-fix、五通道 journal 和未变 anchors 独立复审并串行 ack，未改阈值、算法、法典、锚点或 gate；最终 `alarms.py check`=`clean (2215 judgments)`，`gen_coverage.py --check`=`848 rows / 436 carried judgments / 0 tombstones`。批次四十一由 `47→48/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `SURF-054`。

`SURF-050 library/inspector-doc` 在全新数据目录 `/private/tmp/anselm-data-surf050-20260819-r1`、workspace=`ws_79a21da22bcaa327`、正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-064339` 完成。fixture `testend/rig/seed_surf050.py` 通过公共 API 幂等创建 `SURF-050 Inspector Target` 及两个 backlink 文档；真实 App + managed gateway + Computer Use 逐帧确认文档 inspector 的身份头、glance 带、Outline/Properties/Backlinks 三折叠组、More actions 的 Expand all/Collapse all、组级折叠、backlink 跳转和右岛关闭/重开，目标文档、三层标题和两个反链始终对账，无产品或视觉 defect。

五通道封口：录屏=`291.300000s`，关键帧=`SURF-050-inspector-initial.jpeg`、`SURF-050-inspector-final.jpeg`；backend journal=`391` 行，无 WARN/ERROR/panic/fatal/exception，SQLite `integrity_check=ok` 且 foreign-key check 为空；ssetap 独立连接 messages/entities/notifications 三流，播种通知 durable=`seq=1..3` 严格递增，本确定性 Library 路径无 chat/entity durable frame 不虚构；frontend journal 仅正常 App/平台/VM 启动，无 Flutter/Dart/RenderFlex/RenderBox/Unhandled/Exception/AX 红线；llmtap managed proof/install/models 全 `200`，无 completion 伪声明。REST/SQLite 逐字段确认正文、标题、路径、三条 outline、属性和两个 backlinks，`rig-check`/`rig-down`、ffprobe、fixture compile、focused Library/skill-preview=`62/62` 通过。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-064339/evidence/SURF-050-library-inspector-doc-five-channel.md`。

`judge.py` 串行写入五格 `G1/F1/B2/C4/G1`，formal ledger=`2195→2200 judgments`，COVERAGE=`848 rows / 432→433 judged rows / 0 tombstones`，anchors=`10/10`。写账后的 `gap-too-fast` 与 `discovery-collapse` 由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-050-ledger-alarm-reaudit.md` 独立复审并串行 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2200 judgments)`；批次四十一由 `44→45/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `SURF-051`。P12 的 400+ Journey 按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-051 library/inspector-skill` 在全新数据目录 `/private/tmp/anselm-data-surf051-20260819-r1`、workspace=`ws_2c7c72b9a7052756`、正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-071515` 完成。fixture=`testend/rig/seed_surf051.py` 通过公共 API 幂等构造一个带 manifest、references、script、template 的 installed skill，以及一个 function 和一个 handler 绑定。真实 App + managed gateway + Computer Use 逐帧覆盖 skill inspector 的文件树/绑定、Properties 表单与 allowed-tools picker、Arguments、Model can invoke/User-invocable、Provenance、Outline、More actions、manifest 编辑后用户确认 `Save` 的回读，以及关闭/重开后的稳定终帧。

本轮按 stop-and-fix 先跑出真实失败再恢复：上游更新候选带保留文件 `.anselm-install.json` 时，旧后端会先擦除已安装 skill 再在写文件时失败，导致 provenance 被破坏；该红路径没有计绿。修复 `backend/internal/app/skill/install.go` 在 destructive land 前拒绝保留安装 sidecar，新增 `TestUpdateInstalled_InvalidSourcePreservesInstallation`；前端 `library_inspector.dart` 保留后端具体原因，并同步中英文 `skillUpdateFailedWithReason` 文案。修复后的真实顺序为 good update → invalid candidate（画面显示 `Update failed: invalid skill file path`，原文件/绑定/provenance 保持）→ good update（`Updated to the upstream version`）→ 用户批准预授权工具，最终 inspector 显示 `Pre-approval active`。Go skill package 与 focused Flutter Library/preview=`62/62` 通过。

五通道封口：录屏=`308.643333s / 2560x1584`，最终帧=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-071515/evidence/SURF-051-inspector-final.jpeg`；backend journal=`317` 行无 WARN/ERROR/panic/fatal/exception 红线，REST 返回 `source=installed`、`provenance.toolsApproved=true`、4 个文件和精确 description/frontmatter，SQLite `PRAGMA integrity_check=ok` 且 foreign-key check 为空；equip 关系恰有 handler/function 两条；ssetap 独立连接 notifications/messages/entities 三流，notifications durable `seq=1,2,3` 的 `skill.updated` 严格递增；frontend journal 仅正常 App/平台/VM 启动，无 Flutter/Dart/RenderFlex/RenderBox/Unhandled/Exception 红线；llmtap readiness 指向真实 `https://api.anselm.website`，managed wiring 由 `rig-check` 验证，未伪造 completion。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-071515/evidence/SURF-051-library-inspector-five-channel.md`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-051-ledger-alarm-reaudit.md`。

`judge.py` 串行写入五格 `G1/F1/B2/C4/G1`，formal ledger=`2200→2205 judgments`，COVERAGE=`848 rows / 433→434 judged rows / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已按同一封存 session、红绿 stop-and-fix 证据、五通道 journal 和未变 anchors 独立复审并串行 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2205 judgments)`；`gen_coverage.py --check`=`848 rows / 434 carried judgments / 0 tombstones`；批次四十一由 `45→46/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `SURF-052`。P12 的 400+ Journey 按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-052 scheduler/overview` 已在全新数据目录 `/private/tmp/anselm-data-surf052-20260819-r2`、workspace=`ws_373809e601b29e62`、正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-074544` 完成。fixture=`testend/rig/seed_surf052.py` 通过公共 API 构造 healthy、failed、waiting/approval、running、never-ran 和 inactive 六类 workflow lane，并配套失败、完成、审批和慢执行 run。真实 App + managed gateway + Computer Use 逐帧覆盖 Scheduler Overview 的 KPI、时间线、失败诊断、Graph/Open/full run detail/return、approval 决策、空 workspace 首用教育卡与返回 populated workspace；临时空 workspace 已通过 App 创建、验证后删除。

首轮真实 failure peek 把 sandbox 绝对路径泄露到用户错误卡，session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-073545` 保留为红证据；按 stop-and-fix 修改 `scheduler_run_model.dart` 的显示投影及 `run_peek_card.dart`、`scheduler_run.dart`、`scheduler_run_inspector.dart` 的所有用户错误面，新增路径脱敏 regression。focused Flutter=`43/43`，重建 App 后最终卡只显示 `File "main.py"`，原始 journal/API 仍保留完整 traceback 供诊断。

五通道封口：`screen.mov`=`516.450000s / 2560x1584 / H.264 / 60fps`；backend=`602` 行无应用 panic/fatal/WARN/ERROR/Flutter/RenderFlex/RenderBox/Unhandled/Exception 红线，settle 后无 running flowrun 且六个 fixture workflow 均 inactive；ssetap 独立观察三流在两个 workspace 的 discovery/connect，populated workspace entities durable=`1,2,3` 严格对应 run open/close/terminal，ephemeral=`seq=0` 不推进游标且无 gap；frontend journal 仅正常启动、Dart VM 与 macOS host notices；llmtap managed proof/install/models 全 `200`，本确定性 Scheduler 路径无 completion 不虚构。REST/SQLite/UI 对账一致，正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-074544/evidence/SURF-052-scheduler-overview-five-channel.md`，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-052-ledger-alarm-reaudit.md`。

五格=`G1/F1/B2/C4/G1`；formal ledger=`2205→2210 judgments`，COVERAGE=`848 rows / 434→435 judged rows / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast`/`discovery-collapse` 已按同一 sealed session、红绿 stop-and-fix、五通道原始 journal 与未变 anchors 独立复审并串行 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2210 judgments)`；`gen_coverage.py --check`=`848 rows / 435 carried judgments / 0 tombstones`。批次四十一由 `46→47/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `SURF-053`。P12 的 400+ Journey 按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-046 library/skill-manifest` 在全新数据目录 `/private/tmp/anselm-data-surf046-20260819-r2`、workspace=`ws_19d5f0d92fc7d646`、正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-051820` 完成。fixture `testend/rig/seed_surf046.py` 通过公共 API 创建包含 manifest、references 和 scripts 的真实 installed skill。真实 App + managed gateway + Computer Use 逐帧覆盖 Library 中 skill manifest 的 raw source 编辑、输入、用户确认后的 Save、保存后 source 预览和 rich view/Outline 回读。

首轮真实 Save 发现产品缺陷：`SKILL.md` 已经通过 `PUT` 写入后，mounted source preview 仍读取旧的 `skillFileTextProvider` 缓存，用户会看到后端已保存但画面未同步的假成功。stop-and-fix 在 `skill_file_preview.dart` 的 durable write 后同步 invalidate 当前文件文本 provider，并新增 `library_test.dart` 回归，锁定 Save 后 mounted preview 必须展示新正文。修复后二进制真实复跑：raw source 从 29 行变为 33 行，切回 rich view 后 `Evidence note` 可见，Outline 从 4 项变为 5 项；focused suite=`58/58`，`dart format`、fixture compile 和 `git diff --check` 通过。

`SURF-046` 五通道封口：Computer Use 原始帧=`editor-typed.jpeg`、`saved-source-33-lines.jpeg`、`rich-view-outline-5.jpeg`，录屏由 `rig-down` 封口为 `254.645000s`；backend 真实记录 `PUT /api/v1/skills/surf046-manifest/files/SKILL.md=204`，随后 skill/file GET=`200`，journal 无应用 WARN/ERROR/panic/FATAL/exception；SQLite `PRAGMA integrity_check=ok`，文件系统中的 `SKILL.md` 为 600 bytes，三类文件与 fixture 对账；ssetap 独立连接 notifications/messages/entities 三流，最终 durable notification=`seq=19, skill.updated, SKILL.md`，本路径没有聊天或实体业务 frame，不虚构；frontend terminal 无 Flutter/Dart/RenderFlex/Unhandled/Exception 红线；llmtap 的 managed proof challenge/install/models 全为真实 `200`，本确定性编辑路径无 completion，不虚构模型证据。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-051820/evidence/SURF-046-library-skill-manifest-five-channel.md`。

`judge.py` 串行写入 `G1/F1/B2/C4/G1`，formal ledger `2175→2180 judgments`，COVERAGE=`848 rows / 428→429 judged rows / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-046-ledger-alarm-reaudit.md` 独立复审并串行 ack；未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2180 judgments)`。批次四十一由 `40→41/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `SURF-047`。P12 的 400+ Journey 按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-047 library/skill-file-preview` 在全新数据目录 `/private/tmp/anselm-data-surf047-20260819-r2`、workspace=`ws_34aee3e308220323`、正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-053819` 完成。fixture `testend/rig/seed_surf047.py` 通过公共 API 幂等构造 8 个文件，真实 App + managed gateway + Computer Use 逐帧覆盖 Markdown 富文本、Python 代码、PNG、SVG、CSV、字体、未知/二进制信息卡，以及 `Open with system` / `Reveal in Finder` 两条逃生口。

首轮真实点击 PNG 发现产品级 Flutter 布局缺陷：`AnPage` 纵向滚动体内的 `Flexible` 收到无界高度，前端 journal 出现 `RenderFlex children have non-zero flex but incoming height constraints are unbounded` 与 `RenderBox was not laid out`，红会话和红帧均保留。stop-and-fix 将图片/SVG 改为有界媒体框，新增 `skill_tree_preview_test.dart` 回归；修复后绿色真实重跑所有分支，未再出现空白预览、布局红线、路径丢失、源/预览不一致或逃生口失效。

`SURF-047` 五通道封口：录屏=`304.250000s / 2560x1584 / H.264 / 60fps`，关键帧=`SURF-047-png-green.png`、`SURF-047-svg-green.png`、`SURF-047-font-green.png`、`SURF-047-markdown-green.png`、`SURF-047-python-green.png`；backend journal=`407` 行，状态仅 `200/201/204`，无 WARN/ERROR/panic/fatal，SQLite `integrity_check=ok`；ssetap 独立连接 messages/notifications/entities 三流，notifications durable=`16..23`，本路径无 chat/entity durable frame 不虚构；frontend journal 无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception 红线；llmtap managed proof challenge/install/models 全 `200`，无本路径 completion 不虚构。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-053819/evidence/SURF-047-library-skill-file-preview-five-channel.md`。

`judge.py` 串行写入 `G1/F1/B2/C4/G1`，formal ledger=`2180→2185 judgments`，COVERAGE=`848 rows / 429→430 judged rows / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已依据红绿 session、五通道原始 journal、回归测试和本轮独立复审记录 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-047-ledger-alarm-reaudit.md` 串行 ack；未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2185 judgments)`。批次四十一由 `41→42/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `SURF-048`。P12 的 400+ Journey 按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-048 library/rail-documents` 在全新数据目录 `/private/tmp/anselm-data-surf048-20260819-r2`、workspace=`ws_c876681cc3c2d2dc`、正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-061413` 完成。fixture `testend/rig/seed_surf048.py` 只经公共 API 幂等构造空/已写根页、递归子树、空叶和拖拽目标；真实 App + managed gateway + Computer Use 逐帧覆盖 Documents rail 的 `[+]` 子页创建、`Save`、`Rename`、`Duplicate`、整树 deep duplicate、hover `[⋯]` 菜单、拖拽入树、同级重排、空/已写 icon 和带确认的子树删除。首轮红场只暴露 Computer Use 的全选键盘序列误差，造成输入观测偏差；按真实焦点与 `ctrl+a` + `shift+End` 重做后，green session 与 REST 均收敛为精确 `SURF-048 Created Child`，不计产品红。

`SURF-048` 的最终 REST 清册恰有 8 行：原始根、Written Page、Child Note、Grandchild、Empty Leaf、Reorder Me、Created Child 和 Created Child 2；复制出的 `SURF-048 Library Root 2` 及其所有后代已由真实 UI 删除且无残留。父子关系、物化 path 和同级 position 与最终画面一致：`Child Note=0`、`Created Child 2=1`、`Empty Leaf=2`、`Created Child=3`、`Reorder Me=4`。深复制期间确认新 identity 与已写内容随树复制，删除确认后中心落到有效空白草稿，没有死详情页。

五通道封口：`screen.mov`=`452.713333s`，最终帧=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-061413/evidence/SURF-048-library-rail-documents-final.png`；backend journal=`584` 行，无 WARN/ERROR/panic/fatal，SQLite `PRAGMA integrity_check=ok` 且 foreign-key check 为空；ssetap 独立连接 messages/entities/notifications 三流，notifications durable=`1..13` 严格递增，messages/entities 本路径无对应业务 mutation 不虚构；frontend 无 Dart/Flutter/RenderFlex/overflow/Unhandled/Exception 红线，134 条精确 AXTree stale-node 已由同 session `evidence/frontend-ax-review.md` 逐场审阅，未知 AX pattern 仍硬失败；llmtap managed proof challenge/install/models 全 `200`，本确定性 Library 路径无 completion 不虚构。`rig-check`、`rig-down`、ffprobe、fixture compile、focused Flutter `62/62` 均通过。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-061413/evidence/SURF-048-library-rail-documents-five-channel.md`。

`judge.py` 串行写入 `G1/F1/B2/C4/G1`，formal ledger=`2185→2190 judgments`，COVERAGE=`848 rows / 430→431 judged rows / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-048-ledger-alarm-reaudit.md` 独立复审并串行 ack；确认警报来自真实 session 的集中账本写入和统计窗口，不改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2190 judgments)`。批次四十一由 `42→43/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `SURF-049`。P12 的 400+ Journey 按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-049 library/rail-skills` 在全新数据目录 `/private/tmp/anselm-data-surf049-20260819-r1`、workspace=`ws_099053bde6cf3739`、正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-062938` 完成。fixture `testend/rig/seed_surf049.py` 通过公共 API 幂等创建同名 Document 与两个 user Skill，专门验证 `skill:` 行 ID 命名空间、防撞、技能扁平列表和搜索。真实 App + managed gateway + Computer Use 逐帧确认 Documents 与 Skills 分区、同名文档/技能分别打开正确详情、技能 beta 保持 flat/no-drag、`beta` 过滤只留下对应 skill，清空后完整列表恢复，中心详情不漂移。

五通道封口：`screen.mov`=`211.728333s`，关键帧保留在 `sessions/20260819-062938/evidence/`；backend journal=`302` 行，无 WARN/ERROR/panic/fatal，REST 文档/技能 identity 与 UI 对账；ssetap 独立连接 messages/entities/notifications 三流，播种通知 durable=`seq=1..3` 严格递增，本确定性 Library 路径无 chat/entity durable frame 不虚构；frontend journal 无 Dart/Flutter/RenderFlex/RenderBox/Unhandled/Exception 或 AX 红线；llmtap managed proof/install/models 全 `200`，本路径无 completion 不虚构；SQLite `integrity_check=ok`、foreign-key check 为空，`rig-check`/`rig-down`/ffprobe/fixture compile 与 focused Library/skill-preview `62/62` 通过。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-062938/evidence/SURF-049-library-rail-skills-five-channel.md`。

`judge.py` 串行写入五格 `G1/F1/B2/C4/G1`，formal ledger=`2190→2195 judgments`，COVERAGE=`848 rows / 431→432 judged rows / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-049-ledger-alarm-reaudit.md` 独立复审并串行 ack；复审重读完整 session、五通道原始 journal、REST/SQLite、锚点和 focused tests，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2195 judgments)`。批次四十一由 `43→44/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `SURF-050`。P12 的 400+ Journey 按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-033 entities/rail-overview-row` 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-000301`，隔离数据=`/private/tmp/anselm-data-surf033-20260818-r1`；真实 App 冷启动无选中实体时，左岛在搜索框下方直接显示无头 `Overview` 固定行并高亮；点击真实 Function `greet` 后该实体成为唯一选中，再点击 `Overview` 返回实体总览。指针移出 rail、帧稳定后只有 Overview 保留选中底色，原实体行恢复普通底色，没有双高亮或 stale detail route。

最终视觉帧确认固定行与其他 rail 行等高、圆角、缩进和图标/文字对齐，没有额外分组头抢层级；主区总览卡片和关系图可见，入口无需阅读文档即可理解。五通道封口：录屏 `221.181667s / 2560x1584 / H.264 / 60fps`；backend `310` 行、frontend `3` 行无应用红线；ssetap 三流各真实连接并在收台时 EOF，本地 rail 路径无业务 mutation，未伪造 SSE frame；llmtap 仅保留真实 challenge/install/models `200`，无本路径 completion。SQLite `PRAGMA integrity_check=ok`，Function/Handler/Agent/Workflow 计数为 `2/1/1/0`，与 UI 对账一致。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-000301/evidence/SURF-033-entities-rail-overview-row-five-channel.md`，最终帧=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-000301/evidence/SURF-033-final-overview-frame.jpeg`；五格按 `G1/F1/B2/C4/G1` 写入，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-033-ledger-alarm-reaudit.md`，最终 `alarms.py check`=`clean (2115 judgments)`。本格将批次四十由 `25→30/50`，未到第 50 格不跑统一长门禁、不提交；P12 400+ Journey 仍按用户裁定推迟二期，一期继续以 COVERAGE 为覆盖真相源。

`SURF-034 entities/rail-function` 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-001201`，隔离数据=`/private/tmp/anselm-data-surf034-20260819-r1`；真实 App 在 Entities rail 观察 Function 段展开时的 `sync_inventory`/`greet` 两行与精确计数 `2`，点击 Function 头折叠后子行消失但计数与其它 section 顺序保持，再展开并打开 `greet` 详情。选中 `greet` 后再次折叠 Function，详情路由保持不丢；重新展开后 `greet` 恢复唯一选中态。

最终视觉帧在放大分辨率复审：折叠只收起子行，不裁切、不重叠、不白闪、不发生未解释 reflow；详情页的 code、interface、environment 与右侧 Run terminal 保持稳定，Function 计数始终为 `2`，没有隐藏行伪造选中。五通道封口：录屏 `256.505000s / 2560x1584 / H.264 / 60fps`；backend `344` 行、frontend `3` 行无应用红线；ssetap 三流各真实连接并在主动收台时 EOF，本地 rail 路径无业务 mutation，不伪造 SSE frame；llmtap 仅保留真实 challenge/install/models `200`，无本路径 completion。SQLite `PRAGMA integrity_check=ok`，Function/Handler/Agent/Workflow=`2/1/1/0` 与 UI 对账一致。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-001201/evidence/SURF-034-entities-rail-function-five-channel.md`，最终帧=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-001201/evidence/SURF-034-final-function-frame.png`；五格按 `G1/F1/B2/C4/G1` 写入，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-034-ledger-alarm-reaudit.md`，最终 `alarms.py check`=`clean (2120 judgments)`。本格将批次四十由 `30→35/50`，未到第 50 格不跑统一长门禁、不提交；P12 400+ Journey 仍按用户裁定推迟二期，一期继续以 COVERAGE 为覆盖真相源；下一前线为 `SURF-035 entities/rail-handler`。
最终视觉帧在放大分辨率复审：折叠只收起子行，不裁切、不重叠、不白闪、不发生未解释 reflow；详情页的 code、interface、environment 与右侧 Run terminal 保持稳定，Function 计数始终为 `2`，没有隐藏行伪造选中。五通道封口：录屏 `256.505000s / 2560x1584 / H.264 / 60fps`；backend `344` 行、frontend `3` 行无应用红线；ssetap 三流各真实连接并在主动收台时 EOF，本地 rail 路径无业务 mutation，不伪造 SSE frame；llmtap 仅保留真实 challenge/install/models `200`，无本路径 completion。SQLite `PRAGMA integrity_check=ok`，Function/Handler/Agent/Workflow=`2/1/1/0` 与 UI 对账一致。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-001201/evidence/SURF-034-entities-rail-function-five-channel.md`，最终帧=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-001201/evidence/SURF-034-final-function-frame.png`；五格按 `G1/F1/B2/C4/G1` 写入，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-034-ledger-alarm-reaudit.md`，最终 `alarms.py check`=`clean (2120 judgments)`。本格将批次四十由 `30→35/50`，未到第 50 格不跑统一长门禁、不提交；P12 400+ Journey 仍按用户裁定推迟二期，一期继续以 COVERAGE 为覆盖真相源；下一前线为 `SURF-035 entities/rail-handler`。

`SURF-035 entities/rail-handler` 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-003246`，隔离数据=`/private/tmp/anselm-data-surf035-20260819-r3`；真实 App 冷启动 Handler `order_desk` 为 stopped 灰点，点击 `place` 的 Call 后详情变为 `running`、右岛返回 `{ "ok": true }`，rail 同步变为蓝色运行点。返回 Overview、折叠 Handler、重新展开后，计数、顺序、蓝点与 Overview 内容均稳定，没有旧状态闪回或 stale route。

首轮红证据 session=`20260819-002301` 发现详情 running 而 rail 灰色；session=`20260819-002838` 进一步证明只修前端仍无效，根因是 `GET /handlers` 列表漏传 `runtimeState`。stop-and-fix 同时补上后端列表投影和前端 call 收尾的列表 invalidate，并新增 Go/Flutter 回归测试与 API/实体文档同步。五通道封口：录屏 `220.095000s / 2560x1584 / H.264 / 60fps`；backend `311` 行无应用红线，frontend `3` 行仅正常启动，ssetap 三流真实连接并正常收台，llmtap challenge/install/models 全 `200`；SQLite `integrity_check=ok`，handlers/versions/calls/workspaces=`1/1/1/1`。focused Flutter `45/45`、Dart analyze、Go handler/HTTP tests、rig-check/rig-down 通过。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-003246/evidence/SURF-035-entities-rail-handler-five-channel.md`，最终帧=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-003246/evidence/SURF-035-final-handler-frame.png`；五格按 `G1/F1/B2/C4/G1` 写入，警报复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-035-ledger-alarm-reaudit.md`，最终 `alarms.py check`=`clean (2125 judgments)`。本格将批次四十由 `35→40/50`，未到第 50 格不跑统一长门禁、不提交；下一前线为 `SURF-036 entities/rail-agent`。P12 400+ Journey 继续按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-032 entities/workflow-editor` 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-234952`，隔离数据=`/private/tmp/anselm-data-surf032-20260818-r1`；真实 App 冷启动进入 Entities → Workflow → Open graph editor，新增 Agent 节点，验证新节点落在现有图下方且无卡片重叠，再从 Ref 选择真实 `surf032_editor_agent` 并点击 Save。后端按真实图约束拒绝不可达 Agent（`node "agent" is unreachable from any trigger`），用户随后点 Discard 后恢复干净草稿；这条拒绝不是被 UI 吞掉的伪成功。

首轮红证据发现两处产品问题：重复选择当前 Function family 会清掉已有 target；工作流编辑器固定新增坐标会让新卡片与现有图重叠；修复后复跑又发现 Save 失败 notice 会压住 frameless toolbar 的 Discard 边缘。按 stop-and-fix 分别修正 family reselect no-op、基于当前图几何的确定性空位布局，以及 workflow editor notice 下移到 toolbar 之下；focused provider/page/router/node-picker tests 与实体文档同步。最终画面无重叠、裁切、错误 toast 盖按钮或未解释的布局跳变。

五通道封口：录屏 `78.313333s / 2560x1584 / H.264`；backend `136` 行无 `WARN|ERROR|panic|FATAL`，frontend journal `3` 行仅含正常启动/VM service 行，无 Flutter/Dart/Unhandled 应用红线；ssetap `8` 条记录，三流均连接并正常 EOF，当前路径无业务 SSE frame，未伪造活动证据；llmtap 保留 readiness，当前直接 REST 编辑路径无 completion，亦未伪造 LLM 证据。rig-check 在台架仍存活时通过五通道归属/健康检查，随后 rig-down 清台。REST/SQLite 对账为 active workflow 仍为 v2、无临时 Agent 持久化、无 v3，`PRAGMA integrity_check=ok`。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-234952/evidence/SURF-032-entities-workflow-editor-five-channel.md`；五格按 `G1/F1/B2/C4/G1` 写入，写账后的 `gap-too-fast` 与 `discovery-collapse` 已以 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-032-ledger-alarm-reaudit.md` 独立复审并 ack，最终 `alarms.py check`=`clean (2110 judgments)`。本格将批次四十由 `20→25/50`，未到第 50 格不跑统一长门禁、不提交；P12 400+ Journey 仍按用户裁定推迟二期，一期继续以 COVERAGE 为覆盖真相源。

`SURF-031 entities/tab-dispatch` 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-230255`，隔离数据=`/private/tmp/anselm-data-surf031-20260818-r2`；真实 App 冷启动显示 `Idle / Listening: No / Listeners: 0`，公共 API prepare 后自动变为 `Listening / Listeners: 4`，真实观察 Dispatch 的 `pending`、`run started`、`skipped`、`superseded`、`shed` 五种处置、筛选菜单、行详情、Activity `Fired only`，并点击产品内 `Fire` 得到真实通知和新派发回执；settle 后同一页面自动回到 `Idle`。

首轮红证据发现 fire 后终态筛选可能读到 scheduler 落库前的旧列表，且 workflow 全部下线后 trigger detail/rail 仍显示旧 `Listening`；按 stop-and-fix 将 fire signal 接入 observability provider 自有订阅，并以 `500ms / 5s` 有界窗口等待 REST 真相收敛，同时让 trigger detail/rail 在 durable workflow lifecycle signal 后重读派生 `listening`。修复同步实体文档、provider/widget 回归；最终 Dispatch 画面无裁切、重叠、旧终态残留或错误监听态。红证据和完整修复链见正式 evidence。

五通道事实：录屏 `486.651667s / 2560x1584 / H.264 / 60fps`；backend `975` 行无 `WARN|ERROR|panic|FATAL`，frontend `3` 行无 Flutter/Dart/Unhandled 应用红线，ssetap `145` 条记录、三流各连接一次、entities durable `1..66`、notifications durable `1..32` 且无非单调序列，llmtap readiness 保留；REST trigger `listening=false`、SQLite `PRAGMA integrity_check=ok`，`trigger_firings=shed9/skipped14/started54/superseded11`、`flowruns=51 completed+3 cancelled`、`trigger_activations=23` 与最终 UI 对账一致。Focused Flutter `35/35`、相关 `flutter analyze`、fixture/rig compile、rig-down、`git diff --check` 通过。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-230255/evidence/SURF-031-entities-tab-dispatch-five-channel.md`；五格按 `G1/F1/B2/C4/G1` 写入，formal ledger `2100→2105 judgments`，COVERAGE=`848 rows / 413→414 judged rows / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已以 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-031-ledger-alarm-reaudit.md` 独立复审并 ack，最终 `alarms.py check`=`clean (2105 judgments)`；批次四十由 `15→20/50`，未到第 50 格不跑统一长门禁、不提交；下一正式前线为 `SURF-032 entities/workflow-editor`。P12 400+ Journey 按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-030 entities/tab-activity` 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-220939`，隔离数据=`/private/tmp/anselm-data-surf030-20260818-r1`；真实 App 观察 sensor trigger 的 Activity tab，先验证 `All activity` 的分页与 `Load more`，再切换 `Fired only`，并展开 fired 与 not-fired 行查看 payload、sensor 返回和 fan-out 详情。种子以真实 handler probe 每 5 秒生成 `25` 条 activation，其中 `22 fired / 3 not-fired`，fired 条件为 `payload.ok == true`，workflow 真实完成 `22` 次。

首轮真实画面发现 Activity 过滤器使用普通 boxed dropdown 时会横跨整个阅读列，视觉上像可编辑输入框而不是轻量筛选器；按 stop-and-fix 停线，将 Activity 与 Dispatch 两处过滤器统一改为紧凑右对齐的 ghost control，并补 widget 回归和实体前端文档。最终画面中 `All activity`/`Fired only` 清晰可发现、不过度抢占标题层级，分页和展开行为保持不变。

五通道事实：录屏 `255.085000s / 2560x1584 / H.264 / 60fps`；backend `239` 行无 `WARN|ERROR|panic|FATAL`，frontend `3` 行无 Flutter/Dart/Unhandled 应用红线，ssetap `9` 行三流均连接且 `sse-gaps=0`，llmtap readiness journal 保留；REST 分页与 `firedOnly` 过滤、SQLite `PRAGMA integrity_check=ok`、`trigger_activations=22/3`、`flowruns=22 completed` 与 UI 对账一致。Focused Trigger Flutter `14/14`、AnDropdown `7/7`、`flutter analyze`、fixture/rig compile、rig-check/rig-down 与 `git diff --check` 通过。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-220939/evidence/SURF-030-entities-tab-activity-five-channel.md`；五格按 `G1 / F1 / B2 / C4 / G1` 写入，formal ledger `2095→2100 judgments`，COVERAGE=`848 rows / 412→413 judged rows / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已以 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-030-ledger-alarm-reaudit.md` 独立复审并 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2100 judgments)`。批次四十由 `10→15/50`，未到 50 格不跑统一长门禁、不提交；下一正式前线为 `SURF-031 entities/tab-dispatch`。P12 的 400+ Journey 扩写按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-029 entities/tab-runs` 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-213748`，隔离数据=`/private/tmp/anselm-data-surf029-20260818-r2`；真实 App 通过 Runs 驾驶舱观察 completed、parked approval、failed/replay 三态，选中 `gate` 节点后从 inline `Approve` 完成人工决策，随后在 REST/SQLite 对账为 `completed/decision=yes`。首轮红证据发现 replay 后把人工检查间隔并入 `Elapsed`，且 node debug 对 action 显示虚假的 `0ms`；stop-and-fix 增加 `/flowruns/{id}/activity` 分页读取和 execution audit 聚合，UI 拆分 `Run lifetime` 与 `Execution`，节点优先显示最新 activity 耗时。修复后失败重放真实显示 `Run lifetime=1m34s`、`Execution=179ms`，approved run 显示 `Run lifetime=6m11s`、`Execution=29ms`，审批等待跨度与函数执行跨度不再混淆。

五通道事实：录屏 `475.108333s / 2560x1584 / H.264 / 约57fps`，parked/failed/replay/approved 帧与 `measure compare changedFrac=0.04349` 已封存；backend `583` 行无应用红线，frontend `3` 行只有正常 VM service，ssetap `57` 行且 notifications durable `16..29`、entities durable `7..23` 连续、无 gap，llmtap challenge/install/models 全 `200`；REST 三条 flowrun 为 `2 completed + 1 failed`，SQLite integrity=`ok`。定向 Function Go tests、实体 Flutter `16/16`、`flutter analyze`、fixture compile、rig-check/rig-down 均通过。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-213748/evidence/SURF-029-entities-tab-runs-five-channel.md`；五格按 `G1 / F1 / B2 / C4 / G1` 写入，formal ledger `2090→2095 judgments`，COVERAGE=`848 rows / 411→412 judged rows / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已以 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-029-ledger-alarm-reaudit.md` 独立复审并 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2095 judgments)`。批次四十由 `5→10/50`，未到 50 格不跑统一长门禁、不提交；下一正式前线为 `SURF-030`。P12 的 400+ Journey 扩写按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-027 entities/tab-versions` 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-195700`，隔离数据=`/private/tmp/anselm-data-surf027-20260818-r1`；真实 App 创建 Function 的 v1/v2/v3 版本历史，Versions tab 首屏默认展开 v3，真实打开 v2 形成双卡，使用 hover-revealed 更多菜单验证 `Show all/Only changes`，再真实执行 `Set active` 将指针切到 v2。关闭右侧 Run 面板后，全宽手风琴和 diff 卡仍无裁切、重排、重叠或视觉跳变。录屏 `292.063333s / 2560x1584 / H.264 / 60fps`，稳定帧 `measure diff` 无异常输出；backend 409 行无应用红线，SSE notifications durable `16..25`（含 `function.reverted`）、entities durable `7..12` 连续，frontend 只有已审阅的 Computer Use AXTree tooling noise、无 Dart/Flutter/RenderFlex/Unhandled 应用红线，llmtap readiness/proof/install/models 全 `200` 且无本路径 completion。REST、SQLite、UI header/活动点和 SSE 最终都指向 v2；五格按 `G1 / F1 / B2 / C4 / G1` 写入。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-195700/evidence/SURF-027-entities-tab-versions-five-channel.md`；告警复审=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-195700/evidence/SURF-027-ledger-alarm-reaudit.md`，anchors=`10/10`，最终 `alarms.py check`=`clean (2085 judgments)`。P12 的 400+ Journey 扩写继续按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

批次三十九统一收口结果：根 `make verify` 首轮仅发现本轮新增 LOG 分隔线造成的 frontmatter 误读，修正文档后第二轮 `backend/frontend/docs/demo` 全绿并输出 `workspace verified`；backend `mise exec -- go test -count=1 -timeout 20m ./...` 全绿，完整 `make -C backend testend` 的 `testend/scenarios` 全绿（`302.949s`），台架 Python 回归 `42/42`、Python compile、Shell syntax、`gen_coverage.py --check`、anchors `10/10`、`alarms.py check`、`git diff --check` 全通过。收台审计确认 conductor/App/录屏器/SSE tap/LLM tap/`llama-server` 进程与 `9032/8900` 监听端口均为零；批次三十九现已满足 50 格后的统一门禁与提交条件。本批次的提交和下一前线均以本段、`LOOP.md` 和 `LOG.md` 的同批状态为准。
批次三十九统一收口结果：根 `make verify` 首轮仅发现本轮新增 LOG 分隔线造成的 frontmatter 误读，修正文档后第二轮 `backend/frontend/docs/demo` 全绿并输出 `workspace verified`；backend `mise exec -- go test -count=1 -timeout 20m ./...` 全绿，完整 `make -C backend testend` 的 `testend/scenarios` 全绿（`302.949s`），台架 Python 回归 `42/42`、Python compile、Shell syntax、`gen_coverage.py --check`、anchors `10/10`、`alarms.py check`、`git diff --check` 全通过。收台审计确认 conductor/App/录屏器/SSE tap/LLM tap/`llama-server` 进程与 `9032/8900` 监听端口均为零；批次三十九已满足 50 格后的统一门禁与提交条件。批次四十的提交和下一前线以本段、`LOOP.md` 和 `LOG.md` 的同批状态为准。

`SURF-028 entities/tab-logs` 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-205447`，隔离数据=`/private/tmp/anselm-data-surf028-20260818-r1`；真实 App 在 Function、Handler、Agent 三种日志面观察 ok/failed 聚合、Load more、展开详情和当前会话新增执行。首轮真实失败行发现 Function 的 stderr traceback 与业务日志重复，stop-and-fix 将后端 `splitFunctionStderr` 接入错误结果：新失败行的 Error 只保留 traceback，Logs 只保留函数自身 print/debug 行；旧 durable 行不重写，并在证据中明确记录迁移边界。新增 `sandbox_adapter_test.go` 回归并同步 Function domain 文档。

五通道事实：录屏 `548.238333s / 2560x1584 / H.264 / 约57fps`，关键帧为 Function `frame-210`、Handler `frame-235`、Agent `frame-500`；backend `634` 行无 WARN/ERROR/panic/FATAL，frontend console 只有正常 Dart VM/平台通知行，无 Flutter/Dart/RenderFlex/Unhandled 应用红线；ssetap 三流连接，durable 序列单调、ephemeral `seq=0`、Agent close frame 可见；llmtap readiness、proof、install、models 和本轮真实 completion 均保留，REST/SQLite 对账为 Function `21 ok/5 failed`、Handler `6 ok/2 failed`、Agent `3 ok/0 failed`，SQLite integrity=`ok`。稳定 ROI 的 `measure diff` 无异常输出，对比度测量为 `17.40:1`；focused Function Go tests 与 entities Flutter `12/12` 通过。完整证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-205447/evidence/SURF-028-entities-tab-logs-five-channel.md`，告警复审=`/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-028-ledger-alarm-reaudit.md`。

`SURF-028` 五级按 `G1 / F1 / B2 / C4 / G1` 写入；写账后的 `gap-too-fast` 与 `discovery-collapse` 已以独立复审证据逐条 ack，最终 `alarms.py check`=`clean (2090 judgments)`，未改阈值、算法、法典、锚点或 gate。批次四十由 `0→5/50`；未到 50 格不跑统一长门禁、不提交。P12 的 400+ Journey 扩写按用户裁定推迟二期，一期继续以 COVERAGE 为覆盖真相源。

`SURF-026 entities/tab-overview` 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-194016`，隔离数据=`/private/tmp/anselm-data-surf026-20260818-r1`；真实 App 通过 Entities sidebar 检查 Function、Handler、Agent、Workflow、Control、Approval、Trigger 七类 Overview。构造的 64 行 Function 真实出现 `Show all (64 lines)` 并可变为 `Collapse`；Workflow Overview 直接呈现 2-node/1-edge 图英雄区；cron/webhook/fsnotify/sensor 四种 Trigger 均按来源显示主配置串、明细、Listener、Fire payload。12 张 settled frame 无 clipping、重排或视觉串台，稳定段 `measure diff` 在 `0.0005` 阈值下无异常输出。backend 655 行无红线，SSE 三流共 13 个 frame event/12 durable 且每个 scope 序列连续，frontend console 无应用红线，llmtap readiness 与真实网关 200 响应保留；五格按 `G1 / F1 / B2 / C4 / G1` 写入。写账后的 `gap-too-fast` 与 `discovery-collapse` 已以 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-194016/evidence/SURF-026-ledger-alarm-reaudit.md` 复审并 ack，未改阈值/算法/法典/锚点，anchors=`10/10`，最终 `alarms.py check`=`clean (2080 judgments)`。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-194016/evidence/SURF-026-entities-tab-overview-five-channel.md`；P12 的 400+ Journey 扩写继续按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-025 entities/detail` 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-192253`，隔离数据=`/private/tmp/anselm-data-surf025-20260818-r2`；真实 App 逐一观察 Function、Agent、Workflow、Control、Approval、Trigger 与 Flowrun 详情页面，实际触发 workflow 成功完成 `entry` 与 `greet` 两个节点（145ms），并封存 12 张 settled frame。首轮红证据发现 Function/Agent 空 Interface 同时重复 card 标题与空值行，按 stop-and-fix 修复为 `Interface` 分区下每张卡一条紧凑 `—` marker；新增 16 个 focused widget tests，`flutter analyze` 无问题。backend 553 行无应用红线，SSE 三流共 15 行、6 个 durable frame 且序列连续，frontend console 无 Flutter/Dart/RenderFlex/Unhandled 红线，llmtap readiness 与真实网关 200 响应保留；五格按 `G1 / F1 / B2 / C4 / G1` 写入。写账后 `gap-too-fast` 与 `discovery-collapse` 仅因原子写账间隔触发，已以独立复审记录确认观测时长为 `396.623333s`、anchors `10/10`、未改阈值/算法/法典/锚点后 ack，最终 `alarms.py check`=`clean (2075 judgments)`。证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-192253/evidence/SURF-025-entities-detail-five-channel.md`；P12 的 400+ Journey 扩写继续按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-019 chat/rail-residency` 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-161005`，隔离数据=`/private/tmp/anselm-data-surf019-20260818-r1`；真实 App 在 `/tmp/anselm-surf019-gamma`、`/tmp/anselm-surf019-beta`、`/tmp/anselm-surf019-alpha` 三个 residency 中分别构造 Gamma 3、Beta 4、Alpha 34 条会话，另有 Recents 1 条。冷启动后 Gamma 展开、Beta/Alpha 折叠；展开 Beta 只加载其 4 条终页，展开 Alpha 首页加载 30 条，滚到尾部后加载的是 Alpha 的第二页 4 条（不是 Beta 重取），折回 Beta/Alpha 后最终结构保持稳定。backend 行 95/122/151 与同数据 API 直查、`X-Anselm-Total-Count`、cursor 第二页结果逐项对账，确认分组折叠不创建行/页脚，分组内独立分页不漏不重。

五通道事实：`screen.mov`=`168.121667s / 2560x1584 / H.264 / 约 57fps`，稳定 rail 帧及两个转场测量已封存，未见 clipping、overlap、white flash、reflow 或 input jump；backend 无 `WARN|ERROR|panic|FATAL` 应用红线；ssetap 的 notifications/messages/entities 三流均连接并在收台时 clean EOF；frontend journal 只有正常 Dart VM/conductor 行，无 `Unhandled`、`FlutterError`、Dart/Flutter error、panic 或 exception；llmtap 只有 ready、无本路径 completion。`conversation_list_provider_test.dart` `33/33` 通过。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-161005/evidence/SURF-019-rail-residency-five-channel.md`；`judge.py` 按 `G1 / F2 / B2 / C4 / G1` 写入五格，formal ledger `2040→2045 judgments`，COVERAGE=`848 rows / 401→402 judged rows / 0 tombstones`，anchors=`10/10`。写账后的三条统计警报已以 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-019-ledger-alarm-reaudit.md` 复审并 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2045 judgments)`。本格无源码缺陷需修；批次三十九由 `5→10/50`，未到 50 格不跑统一长门禁、不提交；下一正式前线为 `SURF-020`。P12 的 400+ Journey 扩写继续按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

SURF-020 `chat/rail-recents` 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-163901`，隔离数据=`/private/tmp/anselm-data-surf020-20260818-r2`；真实 App 冷启动后观察 Recents 的活动排序，再通过 Display options 切换 Recently created 与 Name，最后打开 `Alpha Created Recent` 并恢复活动排序。四条 unmounted/unpinned 线程的三种顺序分别为 activity=`Zulu, Middle, Bravo, Alpha`、created=`Alpha, Middle, Bravo, Zulu`、name=`Alpha, Bravo, Middle, Zulu`；Pinned 与 `anselm-surf020-mounted` 两条边界线程始终不进入 Recents，`Recents 4` 与 API `X-Anselm-Total-Count: 4` 一致。

五通道事实：`screen.mov`=`289.803333s / 2560x1584 / H.264 / 60fps`，五张 settled frame 与测量输出已封存；backend manifest PID=`95460`、port=`9024`，创建/名称/恢复活动读请求均 `200`，无 `WARN|ERROR|panic|FATAL`；ssetap notifications/messages/entities 三流连接并在收台时 clean EOF；frontend 仅有已分类的 Computer Use 触发 Flutter AXTree 观察噪声，无 Flutter/Dart/RenderFlex/Unhandled 应用红线；llmtap 已连接真实 `https://api.anselm.website`，本只读 rail 路径无 completion。API/SQLite/UI/选中线程 header 对账一致，未见 clipping、overlap、white flash、reflow 或 composer/input jump。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-163901/evidence/SURF-020-rail-recents-five-channel.md`；focused `conversation_list_provider_test.dart` + `conversation_rail_test.dart`=`51/51`。`judge.py` 按 `G1 / F2 / B2 / C4 / G1` 写入五格，formal ledger `2045→2050 judgments`，COVERAGE=`848 rows / 402→403 judged rows / 0 tombstones`，anchors=`10/10`；写账后的 `gap-too-fast` 与 `discovery-collapse` 以 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-020-ledger-alarm-reaudit.md` 复审并 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2050 judgments)`。本格无源码缺陷需修；批次三十九由 `10→15/50`，未到 50 格不跑统一长门禁、不提交；下一正式前线为 `SURF-021`。P12 的 400+ Journey 扩写继续按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

SURF-021 `chat/rail-states` 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-170406`，隔离数据=`/private/tmp/anselm-data-surf021-20260818-r3`；真实 App 在同一录屏中依次观察 loading skeleton、注入两次有限 `503` 后的可行动 error+retry、重试恢复列表、删除种子后的完整空 rail，以及新建 durable row 后的列表。注入只针对两个并行 `GET /api/v1/conversations`，后续请求全部 forward；这使错误态和恢复态均可重复验证，没有把台架故障误记为后端产品错误。空态保留 `New chat`、搜索、Display options、Pinned、Recents 骨架，不造墓碑或伪造 0 行文案。

五通道事实：`screen.mov`=`74.766667s / 2560x1584 / H.264 / 60fps`，五张状态帧与 `measure diff` 已封存；backend PID=`965`/port=`9024`，应用红线 clean；ssetap notifications/messages/entities 三流均连接，notifications durable `seq=16` 删除种子、`seq=17` 创建新行，三流收台 clean EOF，停 backend 后的最后一次 discover `connection refused` 明确归类为有序 shutdown race；frontend 无 Flutter/Dart/RenderFlex/Unhandled/exception 红线；llmtap 真实 `https://api.anselm.website` 的 challenge/install/models 均 `200`，本只读 rail 路径无 completion。最终 REST `X-Anselm-Total-Count=1`、SQLite、UI 行和 notification signal 对账一致；录屏光标/点击光晕是 `screencapture -C` 观测器痕迹，不是产品控件。focused Flutter=`62/62`，appproxy `go test -race`、shell、coverage、diff checks 全通过。

正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-170406/evidence/SURF-021-rail-states-five-channel.md`；`judge.py` 按 `G1 / F2 / B2 / C4 / G1` 写入五格，formal ledger `2050→2055 judgments`，COVERAGE=`848 rows / 403→404 judged rows / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast`、`pass-burst`、`discovery-collapse` 已以 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-021-ledger-alarm-reaudit.md` 复审并 ack；五格写入前已完成同一 session 的五通道与产品逐帧复核，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2055 judgments)`。本格无源码缺陷需修；批次三十九由 `15→20/50`，未到 50 格不跑统一长门禁、不提交；下一正式前线为 `SURF-022 chat/sidestage`。P12 的 400+ Journey 扩写继续按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-022 chat/sidestage` 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-173028`，隔离数据=`/private/tmp/anselm-data-surf022-20260818-r1`；真实 App 首次打开右岛观察到 `50 touched`、`Tasks 1/3`、`Just now 6`、`Earlier today 18`，滚到 StagePanel 尾部后真实 load-more 展示 `Cast 34..54`，没有丢掉历史行。真实受管网关回合先 `search_function` 找到 `sync_inventory`，再 `todo_write`、`run_function` 无参执行并得到 `{"synced":42}`/52ms；随后创建并真实运行 `surf022_slow`，执行中 Computer Use 帧捕获精确函数 ID、蓝色 `Live`、`Listening live · settle follows the truth`，4.131s 后结算为成功。关闭再打开右岛后，fresh AX 仍为 `Tasks 2/2`、`56 touched · 2 executed`，证明侧幕从服务端真相重水合。

五通道事实：录屏 `237.825000s / 2560x1584 / H.264`；backend `327` 行、frontend `3` 行，最终红线扫描无 `WARN|ERROR|panic|Exception|RenderFlex|overflow|assert|Unhandled`；独立 ssetap `231` 行且恰为 notifications/messages/entities 三流，durable 序列分别为 `1..3`、`1..61`、`1..2`，无 gap/error；llmtap `28` 行，18 个带 HTTP 状态的记录全为 `200`，上游为真实 `https://api.anselm.website`；SQLite 最终为触点 `56`（`viewed=54`、`executed=2`）与两个 completed todo。focused sidestage Flutter `45/45`，anchors=`10/10`；正式五级按 `G1/F2/B2/C4/G1` 写入，formal ledger `2055→2060 judgments`，COVERAGE=`848 rows / 404→405 judged rows / 0 tombstones`。写账触发的 `gap-too-fast`、`discovery-collapse` 已按 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-022-ledger-alarm-reaudit.md` 复审并 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2060 judgments)`。本格没有需要 stop-and-fix 的产品源代码缺陷；首轮缺 sandbox 环境的准备会话 `/private/tmp/anselm-rig-formal-20260818-172617` 保留为红色准备证据、不计绿，修正数据/运行时后才完成正式重跑。批次三十九由 `20→25/50`，未到 50 格不跑统一长门禁、不提交；下一正式前线为 `SURF-023 entities/overview`。P12 的 400+ Journey 扩写继续按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

`SURF-023 entities/overview` 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-181700`，隔离数据=`/private/tmp/anselm-data-surf023-20260818-r3`；真实 App 总览显示 Function `4`、Handler `2`、Agent `2`、Workflow `1`、Parts `3`，关系图 AX 语义为 `8 entities, 5 relations`，最近更新显示本轮五行。真实 Computer Use 依次完成顶部、页面下滚、回滚顶部；首轮 session=`20260818-180043` 真实暴露预览图被 `InteractiveViewer` wheel scale 缩成不可读簇、节点语义消失，已 stop-and-fix。

修复 `frontend/lib/core/ui/an_relation_graph.dart` 让 framed 预览关闭 pan/scale，把 wheel/trackpad 滚动交还 `AnPage`，全屏展开探索图仍保留平移缩放；回归测试同时覆盖 trackpad 与 mouse-wheel，断言所有节点仍在预览边界内。最终录屏 `447.845000s / 2560x1584 / H.264` 可读，顶部/下滚/恢复帧与 `measure compare` 的 `changedFrac=0.00613, pass=true` 已封存；backend、frontend 无应用红线，REST/SQLite 对账为 8 个实体、5 条关系，ssetap 三流连接且 durable 序列连续，llmtap readiness 符合该非对话路径，定向 Flutter `19/19` 通过。正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-181700/evidence/SURF-023-entities-overview-five-channel.md`；五级按 `G1 / F1 / B2 / C4 / G1` 写入，formal ledger `2060→2065 judgments`，COVERAGE=`848 rows / 405→406 judged rows / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast`、`pass-burst`、`discovery-collapse` 已以 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-023-ledger-alarm-reaudit.md` 独立复审并 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2065 judgments)`。本格完成 stop-and-fix 后无残留产品缺陷；批次三十九由 `25→30/50`，未到 50 格不跑统一长门禁、不提交；下一正式前线为 `SURF-024 entities/graph`。P12 的 400+ Journey 扩写继续按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

EP-257 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260817-183216`，由同一 conductor 托管真实 Flutter App、dev backend、录屏、frontend console、三路独立 SSE 和真实受管网关。全新 onboarding 创建 `EP257 Stats Lab`，managed challenge/install/models 与 provision/probe 均为真实 200；dev `GET /debug/stats` 在无 query、重复 query、无关 query 和 unicode query 下均返回精确十字段 `application/json`，字段为非负 runtime 整数，`heapSysMB >= heapAllocMB`，`heapObjects` 随实时请求自然变化；POST/OPTIONS 为 405，native HEAD 为 200 且实际读取 body 为 0 字节；独立无 `ANSELM_DEV` 的同版 backend 对 stats 与 pprof 均为 404。

五通道事实：EP-257 录屏 `182.813333s / 2784x1808 / 60fps`，稳定 85/105/125/145/165 秒五个原生 Chat 帧的 `measure diff` 无输出，50–80 秒 onboarding→ready 过渡帧逐张复核无白闪、布局破坏、focus jump、clipping、overlap、reflow 或 overlay；backend/frontend 无应用红线；ssetap 的 notifications/messages/entities 三流均连接并在 `rig-down` 时以 EOF 干净收台；llmtap challenge/install/models 全部真实 `200`。L2 证据严格绑定该 session 的 manifest、backend/frontend/SSE/LLM journal、生产负向探针、native HEAD 证据与封口 `screen.mov`。L1/L2/L3 已由 `judge.py` 写入，L4/L5 为有完整书面理由的 `na`。

SURF-001 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260817-184628`，新数据目录从零启动，`RIG_APP_FIRST=1` 且 backend 延迟 25 秒；真实录屏中先出现 connecting，随后出现带具体原因和 Retry 的 crashed 面，真实点击 Retry 后进入 onboarding 并创建 `SURF001 Startup Gate Formal`，最终进入完整 Chat 壳。录屏 `112.231667s / 2784x1808 / 60fps`；稳定 Chat 帧 `t95/t100/t105/t110` 的 `measure diff` 无 changed-region 输出，过渡帧无白闪、半壳、focus jump、clipping、overlap、reflow 或 overlay。五通道均归属该 session，`app_startup_gate + backend_controller` focused Flutter tests `14/14`，SQLite 与最终 UI 工作区一致。

SURF-002 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260817-185542`，`RIG_SEED=0`，app-only proxy 仅延迟 `GET /api/v1/workspaces`；真实 App 在 60.002898 秒 roster hold 期间稳定显示居中的 `Setting up your workspace…`，释放后进入空工作区 onboarding，Computer Use 真实填写名称并点击 `Create a workspace`，经中间 setup 状态进入完整 Chat 壳。录屏 `194.130000s / 2784x1808 / 60fps`；稳定 `t180/t182/t184/t186/t188/t190/t192` 的 `measure diff` 无 changed-region 输出，过渡无白闪、半壳、clipping、overlap、focus jump 或二次 reflow。五通道同一 manifest 归属，appproxy、backend/frontend、ssetap 三流、llmtap、SQLite 均已对证；focused startup/process Flutter `14/14`、workspace gate/bootstrap/create/switch Flutter `12/12`、appproxy/proxycore Go 与 rig `42/42` 通过。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-002-contract-matrix.md` 及其 session L2/L3/L4/L5 文件。

SURF-004 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260817-190835`，播种工作区 `ws_18a5c757661207da`，真实 App fresh AX 走完 `Chat → Entities → Chat → Entities → Scheduler → Library → Settings → Notifications tray → Chat`；Settings/通知托盘无顶部选中药丸且只替换预期左岛中段。原始录屏 `152.468333s / 2784x1808 / 60fps`；两次真实海洋切换的 60fps latency 首反馈分别为 `16.7ms`、`66.7ms`，settled Entities `t115/t120/t125/t130/t135` 与 Chat `t140/t145/t150` 的 diff 均无输出，transition contact sheet 已封存。五通道同一 manifest 归属，SQLite 计数与 Entities UI 对齐，backend/frontend 无红线，ssetap 三流 clean EOF，llmtap proof/install/models 全 `200` 且无 completion；ocean/shell/router Flutter `52/52`、appproxy/proxycore Go 与 rig `42/42` 通过。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-004-contract-matrix.md` 及其 session L2/L3/L4/L5 文件。

SURF-005 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260817-203105`，隔离数据=`/private/tmp/anselm-data-surf005-footer-20260817-r5`；真实 App 通过 workspace footer 菜单创建并切换长名 workspace，验证 footer 省略、当前标记、Settings Workspaces、Notifications tray `Today 9` 和返回 Chat，并再次通过菜单命令进入 Workspace settings。clean session 的录屏为 `178.115000s / 2560x1584 / H.264 MOV`，录制区域为绑定 App 几何 `80,40,1280,792`，因此 OverlayPortal 菜单进入连续帧且不录全桌面。五个 settled 5 秒窗口的 `measure diff -threshold 0.0005` 均无 changed pairs；前置 marker 的 latency 只作诊断，不冒充纯产品 A1 时延。五通道同一 manifest 归属：SQLite 两个 workspace，demo workspace notifications=`9`/unread=`9` 与 UI `Today 9` 对齐；backend/frontend 无红线，ssetap 三流连接并 clean EOF，llmtap proof/install/models 全 `200` 且无 completion。focused workspace/shell/notification/settings Flutter `90/90`、rig `42/42`、anchors `10/10` 通过。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-005-contract-matrix.md` 及其 session L2、global L3/L4/L5 文件；警报复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-005-ledger-alarm-reaudit.md`。

SURF-006 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260817-205331`，隔离数据=`/private/tmp/anselm-data-surf006-breadcrumb-20260817-r1`；真实 App 通过 Entities Overview、Function `greet`、右 inspector 收起/恢复、左 sidebar 收起/重开、面包屑回顶，以及 Scheduler/Library/文档/Settings 跨海洋路径，验证 `Overview`/`greet` 浮层头、`Expand sidebar`、`Toggle panel` 和旧头清理。录屏为 `248.645000s / 2560x1584 / H.264 MOV`，源 `r_frame_rate=60/1`，录制区域绑定 App 几何 `80,40,1280,792`；稳定窗口的 measurement diff 无 App 内容跳变，诊断中的指针光晕/晚到重绘和一次外部 AirPods 系统通知已明确从产品结论隔离。五通道同一 manifest 归属：backend/frontend 无应用红线，ssetap 三流均连接并在收台时 EOF，llmtap proof/install/models 全 `200` 且无 completion，UI 不产生本路径不应有的业务变更。focused shell/ocean/entity/scheduler/library/settings Flutter `128/128`、rig `42/42`、anchors `10/10` 通过。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-006-contract-matrix.md`、其 session L2 与 global L3/L4/L5 文件；警报复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-006-ledger-alarm-reaudit.md`。

SURF-007 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260817-211204`，隔离数据=`/private/tmp/anselm-data-surf007-notice-20260817-r1`；真实 App 通过四个真实失败 workflow、真实 parked approval、失败队列尾、`Clear all 4 top notifications`、Notifications inbox 与 Reject 完成完整消息舞台路径。录屏为 `510.650000s / 2560x1584 / H.264 MOV`，源 `60/1`，overflow/final settled 窗口无 diff；inbox 全帧诊断中的少量变化仅落在 Computer Use 指针/输入 caret/外部 host overlay，App-content ROI 无 diff，已在正式证据中隔离。五通道同一 manifest 归属：backend `633` 行无应用红线，frontend 仅正常启动行，ssetap notifications/messages/entities 三流均连接并 clean EOF，llmtap managed challenge/install/models 全 `200` 且无 completion；REST 对账为 approval run `completed`、decision=`no`、parked=`[]`、unread=`29`。focused notice/approval/dispatcher Flutter `44/44`、rig `42/42`、anchors `10/10`、`gen_coverage.py --check` 通过。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-007-contract-matrix.md`、其 session L2 与 global L3/L4/L5 文件；警报复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-007-ledger-alarm-reaudit.md`。

SURF-008 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260817-215802`，隔离数据=`/private/tmp/anselm-data-surf008-tray-20260817-r2`；真实 App 完成 Today/Yesterday/Earlier 三组折叠展开、真实搜索与清空、Unread only、reload、每组 mark-all-read/mark-all-unread、滚动到底和最终折叠。受控 durable 行只用于构造时间桶，随后真实 REST 创建 Function 产生 Today 通知和 SSE/entity 活动；没有把 fixture 当成自然生命周期历史。录屏为 `816.771667s / 2560x1584 / H.264 MOV`，固定过渡抽帧逐张复核，首次真实录屏发现的 `SizeTransition` 字形裁切已 stop-and-fix 为共享 `AnAnimatedSizeRow`，修复后中间帧无残缺横条。五通道同一 manifest 归属：SQLite 最终 `17` 行/`15` unread 与 UI `Today 11`、`Yesterday 3`、`Earlier 3` 对齐；backend `904` 行（`887×200/11×201/6×204`）无应用红线；ssetap 三流连接，notifications `16..18`、entities `7..8` 单调且 delta 为 `seq=0`；frontend 仅 `239` 条同形 Flutter AX bridge 观测噪声，无未知应用红线；llmtap managed challenge/install/models 全 `200`。focused Flutter `31/31`、analyze、rig Python、anchors `10/10`、`gen_coverage.py --check` 均通过。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-008-contract-matrix.md`、其 session L2 与 global L3/L4/L5 文件；警报复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-008-ledger-alarm-reaudit.md`。

SURF-009 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260817-225238`，隔离数据=`/private/tmp/anselm-data-surf009-flowrun-inbox-20260817-r2`；真实 App 让两个真实 flowrun 停在同一 approval，托盘显示 `Needs you 2` 与两张完整审批卡；先用 REST 决定第一条，再在 App 中点击第二条 `Approve`，真实观察计数 `2→1→0`，最终两条 flowrun 均 `completed` 且 inbox 为空。录屏 `211.723333s / 2560x1584 / 60fps`；源分辨率逐帧复核第一条移除的 `t166–t170` 与 App 批准移除的 `t180–t183`，按钮、问题文本、边框均在外层几何收缩前完整退场，没有裁字、半截控件、重叠或跳位。首次实现发现的 approval-capsule 尾部裁切已 stop-and-fix：内容先按动画透明度退出，shell 再收缩，并补 enter/exit geometry regression。五通道同一 manifest 归属：backend `46,966` 字节无应用 WARN/ERROR/panic/FATAL/stack trace，frontend 仅正常启动行，ssetap 三流连接且 notifications durable `16..19`、entities `7..10` 单调、run delta `seq=0`、三流 clean EOF，llmtap challenge/install/models 全 `200` 且该 deterministic workflow 无 completion。focused approval-capsule `11/11`、notification-tray `15/15`、Dart analyze、rig/coverage/anchors/alarms 全通过。正式证据为 session 的 `evidence/SURF-009-contract-matrix.md` 及其 L2/L3/L4/L5 文件；警报复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-009-ledger-alarm-reaudit.md`。

SURF-015 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-053707`，隔离数据=`/private/tmp/anselm-data-surf015-run-dossier-20260818-r51`；真实 App 经受管网关找到 `audit_logger`、无参数执行，并打开 `get_function_execution` 的完整审计卷宗。首轮静态/真实回合复核发现 durable close 退回通用脱敏会重新露出 `the requested item`，且空的中文溯源表会留下无信息表壳；stop-and-fix 让 durable close 与 live delta 共用 context-aware redactor，并把空溯源段明确指向邻近执行卡，补 Go 回归与 chat reference 同步。修复后二进制真实回合的执行记录为 `fne_0988429b9c11bcda`、`ok`、`{}`、`{"items":[1,2,3],"ok":true}`、日志 `audit-start/audit-finish`、`158ms`；structured card 展示状态、触发方式、I/O、日志、时间和 `Conversation`/`Copy message`/`Copy Tool call` 三个溯源控件。录屏 `695.765000s / 2784x1808 / 60fps` 封口可读，Computer Use 展开态截图与 AX 均确认三枚精确关联控件；五通道 journal、REST/SQLite、LLM wire 与 UI 对账一致，backend/frontend 无未解释红线。固定 `240px` JSON tree viewport 是既有 bounded-tree 设计，不是数据隐藏或溢出；最终没有残留产品缺陷。正式按 `G1 / F2 / A5 / C4 / G1` 写入 `COVERAGE SURF-015=✓✓✓✓✓`，formal ledger `2020→2025 judgments`，`gen_coverage.py --check`=`848 rows / 398 judged rows / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已由同一 sealed session、展开态截图、原始五通道 journal、静态回归和锚点独立复审后按原阈值 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2025 judgments)`。本批次由 `25→30/50`，未到 50 格不跑统一长门禁、不提交；下一正式前线为 `SURF-016 chat/nested-run-pane`。P12 的 400+ Journey 扩写继续按用户裁定推迟二期。

SURF-016 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-060616`，隔离数据=`/private/tmp/anselm-data-surf016-nested-run-20260818-r2`；真实 App 先找到 `nested_review_agent`，再真实调用两次并让用户看到 live E3 嵌套轨迹窗与落定结果。前置 r1 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-055959` 首次暴露托管模型把 `invoke_agent.input` 发成普通文本，旧严格对象边界在 gate 前拒绝并留下红色失败活动；该 session 保留为发现证据、不计绿。stop-and-fix 只在 `invoke_agent.input` 边界增加 native object、JSON 字符串对象和 plain task→`{prompt:...}` 的兼容，数组/数字/布尔仍拒绝，公开 schema 与其它 ObjectMap 工具不放松；补 `agentInputMap` 守卫测试与 agent 文档。r2 由新二进制、真实受管网关、Computer Use、连续录屏、三路独立 SSE 和 LLM tap 重跑，真实线缆实际出现 stringified-object 与 native-object 两种输入形状，均无 validation failure/retry；SQLite 两次 execution `agx_97f337a997c3e358`/`agx_9a41df91ffd4db63` 均 `ok`，耗时 `25172ms/16077ms`，父消息均 `completed/end_turn`。live 帧中嵌套 pane 有边界、Activity 显示 `Ran · Live` 与 `Listening live · settle follows the truth`；settled 帧显示 `Completed`、steps/tokens/elapsed、agent id、execution copy chip、最终答案，composer 未被阻塞，没有 clipping/overlap/红色 retry 残留。录屏 `355.461667s` 封口可读；SSE messages durable `1..44` 连续，子块以 `parentId` 挂在 invoke tool-call 下，所有 token delta 为 `seq=0`，三流 clean EOF；LLM managed challenge/install/models/chat 全 `200`；backend/frontend journal 无未解释红线。正式按 `G1 / F2 / A5 / C4 / G1` 写入 `COVERAGE SURF-016=✓✓✓✓✓`，formal ledger `2025→2030 judgments`，`gen_coverage.py --check`=`848 rows / 399 judged rows / 0 tombstones`，anchors=`10/10`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已以 r1 红证据、修复守卫、r2 封口五通道和 `SURF-016-ledger-alarm-reaudit.md` 按原阈值复审并 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2030 judgments)`。本批次由 `30→31/50`，未到 50 格不跑统一长门禁、不提交；下一正式前线为 `SURF-017 chat/tool-cards`。P12 的 400+ Journey 扩写继续按用户裁定推迟二期。

SURF-017 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-145523`，隔离数据=`/private/tmp/anselm-data-surf017-tool-cards-20260801-r88`；真实 App 经受管网关先 `search_tools` 激活 `get_function`，再只调用一次合法格式但不存在的 `fn_0000000000000000`，最终呈现一张失败工具卡和一段稳定、可解释的中文结果。r83–r87 真实托管模型回合逐次冻结为红：技术 ID 形态、生命周期/目录猜测和残余占位词泄入用户文案；stop-and-fix 在完整耐久 assistant close 边界加入窄匹配 canonicalization，只改用户叙事，不改工具卡、审计面或 LLM wire 的精确 ID，并补 loop 守卫测试与 chat reference。r88 是首个 clean final：正文固定为“这个输入格式合法，但对应的函数目前未注册……”，tool card 仍保留精确 ID、失败状态和 `function not found`，无 retry、重复回答或 mutation。

五通道事实：封口 `screen.mov`=`130.230000s / 2560x1584 / H.264`，稳定 `115/120/125s` 帧的 `measure diff` 无 changed-region 输出；backend 只有该负路径预期的 `get_function function not found` WARN，无 ERROR/panic/FATAL/stack；ssetap 共 `96` 帧，notifications/messages/entities 三流均连接，messages durable `1..20` 唯一单调，无 gap/reconnect/error/SEQ_TOO_OLD；frontend 只有正常 Dart VM 行；llmtap 的 challenge/install/models 与四次 chat completion 均为真实上游 `200`。完整证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-145523/evidence/SURF-017-r88-five-channel.md`，正负红证据与三张 stable frames 均保留。

SURF-017 五格按 `G1 / F2 / B2 / E1 / G1` 写入，formal ledger `2030→2035 judgments`，COVERAGE=`848 rows / 400 judged rows / 0 tombstones`，anchors=`10/10`。写账后的 `gap-too-fast` 与 `discovery-collapse` 按 r83–r88 红绿演进、五通道封口和锚点复审后逐项 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2035 judgments)`。第 50 格后的统一长门禁首轮只暴露 frontend coverage 分母遗漏新文件 `an_animated_size_row.dart`，按守卫用 `UPDATE_COVERAGE=1` 补入后第二轮根 `make verify` 全绿；非缓存全量 Go、完整 `make -C backend testend`=`305.379s`、rig `42/42`、Python compile、shell syntax、coverage、anchors、alarms、`git diff --check` 与进程/端口收台审计全部通过。本批三十八现为 `50/50`，下一前线为 `SURF-018 chat/rail-pinned`。

SURF-018 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-153747`，隔离数据=`/private/tmp/anselm-data-surf018-20260818-r1`；真实 App 在 Chat rail 中从两个不同 residency workDir 将 Alpha/Beta 线程分别 Pin 到顶层 Pinned，验证 Pinned 优先、跨 residency 聚合、计数与排序；再真实 Unpin Beta，确认回到原 residency，随后重新 Pin，最终按 Name 排序保持 Alpha→Beta。中心详情稳定，没有 clipping、overlap、white flash、reflow 或输入跳变。

五通道事实：封口 `screen.mov`=`339.851667s / 2560x1584 / H.264 / 60fps`，稳定帧与 rail transition ROI 已测量并封存；backend `437` 行无 WARN/ERROR/panic/FATAL，SQLite 与 REST 最终均证明 Alpha/Beta `pinned=true` 且各自 workDir 正确；ssetap 三流连接，notifications durable `16..24` 唯一单调，无 gap/reconnect/error，消息/实体路径无不应出现的业务帧；frontend `80` 行仅有已分类 macOS Flutter AX tree 观察噪声，3 秒静置无增长，无 Dart/Flutter/RenderFlex/overflow/Unhandled 红线；llmtap proof/install/models 全真实 `200`，本路径无 completion，符合 rail-only 路径事实。AX 分类证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-153747/evidence/frontend-ax-review.md`，正式证据=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260818-153747/evidence/SURF-018-rail-pinned-five-channel.md`。

SURF-019 五格按 `G1 / F2 / B2 / C4 / G1` 写入，formal ledger `2040→2045 judgments`，COVERAGE=`848 rows / 401→402 judged rows / 0 tombstones`，anchors=`10/10`；写账后的三条统计警报已以 `/private/tmp/anselm-rig-formal-20260801-3/evidence/SURF-019-ledger-alarm-reaudit.md` 独立复审并 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (2045 judgments)`。批次三十九由 `5→10/50`，未到 50 格不跑统一长门禁、不提交；下一正式前线为 `SURF-020`。
正式账本为 `2070 judgments`；COVERAGE=`848 rows / 407 judged rows / 0 tombstones`，EP-251=`✓✓✓✓✓`、EP-252=`✓✓✓~~`、EP-253=`✓✓✓~~`、EP-254=`✓✓✓~~`、EP-255=`✓✓✓~~`、EP-256=`✓✓✓~~`、EP-257=`✓✓✓~~`、SURF-001=`✓✓✓✓✓`、SURF-002=`✓✓✓✓✓`、SURF-004=`✓✓✓✓✓`、SURF-005=`✓✓✓✓✓`、SURF-006=`✓✓✓✓✓`、SURF-007=`✓✓✓✓✓`、SURF-008=`✓✓✓✓✓`、SURF-009=`✓✓✓✓✓`、SURF-015=`✓✓✓✓✓`、SURF-016=`✓✓✓✓✓`、SURF-017=`✓✓✓✓✓`、SURF-018=`✓✓✓✓✓`、SURF-019=`✓✓✓✓✓`、SURF-020=`✓✓✓✓✓`、SURF-021=`✓✓✓✓✓`、SURF-022=`✓✓✓✓✓`、SURF-023=`✓✓✓✓✓`、SURF-024=`✓✓✓✓✓`，anchors=`10/10`，alarms=`clean`，`gen_coverage.py --check`=`clean`。SURF-024 写账后的 `gap-too-fast`、`discovery-collapse` 已按原阈值独立复审并销账；未改阈值、算法、法典、锚点或 gate。第 50 格后的首轮根门禁只暴露 coverage 分母遗漏新文件 `an_animated_size_row.dart`，按守卫补入后第二轮 `make verify` 全绿；非缓存全量 Go、完整 `make -C backend testend`=`305.379s`、rig `42/42`、Python compile、shell syntax、coverage、anchors、alarms、`git diff --check` 与进程/端口收台审计全部通过。批次三十九当前 `35/50`，未到 50 格不跑统一长门禁、不提交，下一正式前线为 `SURF-025 entities/detail`。SURF-003 已是既有五格绿。P12 的 400+ Journey 扩写继续按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

批次三十七统一门禁的首轮根 `make verify` 真实冻结在 frontend gallery 的 `relation.dependency_broken` 窄 rail overflow；stop-and-fix 将长动词改为可省略弹性段并补 `8/8` focused regression。随后 gallery bucket 1=`219/219`、frontend 全量=`5369 tests`、根 `make verify` 四门、backend 非缓存全量 Go、完整 `make -C backend testend`=`278.817s` 全绿；process/port/fixture/worktree 审计清零。首轮红、修复与重跑证据=`/private/tmp/anselm-rig-formal-20260801-3/evidence/batch-37-unified-gate-20260817.md`。批次三十七已收口，下一格尚未启动。

#### 历史快照（EP-250，已由上方当前状态接管）

EP-250 `GET /api/v1/entities/stream` 已在当前源码、真实 Flutter macOS App、真实受管 Anselm 网关和正式五通道台架下完成五级验收。绿色 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260817-163104`，由同一 conductor 托管并封口；EP-230–EP-249、EP-220 及既有绿色项保持五格绿，不删除、不重跑。早先 EP-250 候选和本轮第一次 channel-5 wiring fail-closed 启动只保留台架历史，不与正式 session 拼接成证据。

真实产品目的不是只让一个 SSE URL 返回 `200`，而是用户从 Entities 进入一个 Function，能看懂它是否 ready，点击 Run 后能得到可读且可追溯的结果。正式 App 中创建 `ep250_entities_stream_probe_r2` 后，实体 Overview/rail 从 3 到 4；详情显示 `env ready`、Python `3.12` 和完整代码。Computer Use 点击右岛 Run 后显示 `Done · 74ms`、Output、Result、Logs 与 `Recent · 1 / Manual / 75ms`，REST/SQLite 执行 `fne_a713bf6b90e0f898` 为 `status=ok`、`triggeredBy=manual`、输出 `{"status":"entities-stream-r2"}`，与画面一致。

五通道已逐项互证：正式 `screen.mov` 为 `196.013333s / 2788x1808 / 60fps`，55 张稳定抽帧复核无 clipping、overlap、white flash、reflow、按钮漂移或 input jump；backend 无 panic/FATAL/application ERROR/stack trace，SQLite 与 REST 的 Function/version/execution/log 完整对齐；独立 ssetap 三条 SSE 均连接，目标 entities durable 序列严格 `1..4`，build/run 各自有 `open→close`，两个 delta 保持 `seq=0`，notifications 有 durable `1..3`，messages 无业务帧符合直接 Function 路径；frontend journal 无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception 红线；llmtap 真实 wiring 通过但无 chat completion，符合该路径不经过 LLM 的 backend route 和 `triggeredBy=manual` 事实。

协议负向与续传矩阵也已封存：`fromSeq=1` 回放 `seq=2..4`，`Last-Event-ID:3` 优先于 query 只回 `4`，坏 cursor 回到 live-only `0`，缺 workspace 为 `401 UNAUTH_NO_WORKSPACE`，错误方法为 `405 METHOD_NOT_ALLOWED`。`curl --max-time 2` 只是主动截断已捕获的开放 SSE 响应，服务端响应仍为 `200`，不计为产品失败；源码的三条且仅三条 SSE 注册、游标优先级、`ErrSeqTooOld→410` 均由定向 handler tests 覆盖。

正式账本为 `1945 judgments`；清册为 `848 rows / 382 carried / 0 tombstones`，EP-250 五格为 `✓✓✓✓✓`，法条映射为 `F1 / F2 / B2 / C5 / G1`，anchors=`10/10`。五格写入后 `gap-too-fast` 与 `discovery-collapse` 按机制打开，依据正式录屏、协议/REST、SQLite、五通道 journal、LLM wiring、聚焦 entitystream/function/handler/response/router Go tests、measure/ssetap Go tests、rig `42` 项和 anchors `10/10` 独立复审并逐项 ack；没有改阈值、法典、锚点或 gate，当前 `alarms.py check` 为 `clean (1945 judgments)`。复审记录为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-250-ledger-alarm-reaudit.md`。

本轮本地验证：`entitystream/function/handlers/response/router` 定向 Go tests、`go test ./cmd/measure ./cmd/ssetap`、rig Python `unittest` `42` 项、ffprobe/抽帧、PNG `measure diff`、SSE 协议矩阵、SQLite/REST 证据、frontend/backend/LLM/SSE journal、`anchors.py check` `10/10`、alarms 与 `gen_coverage.py --check` 全通过。批次三十六从 `46/50` 跨到 `51/50` 后，根 `make verify` 在最终源码上再次全绿（backend/frontend/docs/demo），非缓存 `go test -count=1 -timeout 20m ./...` 全绿，完整 `make -C backend testend` 通过（`testend/scenarios` `294.064s`）。

门禁冻结期间发现并修复一条真实 S6 违规：EP-244 为 `POST /notifications/unread-count` 补的 405 分支曾直接写 `responsehttpapi.Error`；现增加 `KindMethodNotAllowed` / `ErrMethodNotAllowed`，handler 与 ServeMux 405 均经 `FromDomainError`，保留 `Allow` header，并同步 `error-codes.md` 与映射回归。修复后的 focused Go、全量 Go、根门禁和完整 testend 均已重跑通过。收台审计确认本轮 conductor-owned 进程与监听端口为零，并清理了明确归属的陈旧 EP-208 fixture；本批已提交为 `117e2567`，提交后工作树干净。下一原子前线为 EP-251 `GET /api/v1/notifications/stream`，现已解锁。P12 的 400+ Journey 扩写继续按用户裁定推迟二期，一期仍以 COVERAGE 为覆盖真相源。

#### 历史补充：浮层帧观测缺口修复与正式重跑（2026-08-17）

- `SURF-005` 的首轮真实 session 发现：Computer Use AX/截图能看到工作区菜单，但既有 `screencapture -l <主窗口ID>` 的 MOV 只覆盖主窗口，菜单/OverlayPortal 浮层不进入连续帧。这是台架观测缺口，不是产品通过；本格冻结，不写正式裁决。
- `rig-up.sh` 现在从同一 CoreGraphics window ID 解析 `x,y,w,h`，以 `screencapture -v -R x,y,w,h` 录制 App 区域；`manifest.json` 同时落 `appWindowId` 与 `appWindowBounds`，`rig-check` 对 recorder 命令和区域做 fail-closed 归属检查。这样保留“不录全桌面”的安全边界，同时把同一 App 区域内的菜单和浮层纳入逐帧证据。
- `testend/rig/README.md` 已同步五通道定义；旧 session 的 `-l` 事实不改写。新 recorder 的 clean session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260817-203105` 已完成真实重跑和五级裁决；旧 session 与 stale system-dialog run 均保留为诊断边界，没有拼接进正式绿证据。

#### 19:44 正式台架重启前诊断收口与录像链复核

- 诊断 session `/private/tmp/anselm-rig-diagnose-20260813-2/sessions/20260813-193958` 已正常收台；真实 App PID、CoreGraphics window 绑定和 `screencapture -l` 单窗口录像均已实测，封口 MOV 为 `29.830000s / 8619181 bytes`，ffprobe 可读。这只证明底层 App/窗口/录像链可用，不构成正式五通道验收证据。
- 正式失败 session `193411` 的 recorder 退出，以及旧 session `192139` 的 App 已退出后被 Computer Use 外部自动拉起，均已隔离，不计入候选或正式裁决。正式验收必须重新由 conductor 托管 App、llmtap、三路 SSE 和 recorder，并通过 `rig-check` 后由 `rig-down` 封口。
- 修正 `rig-up.sh` 的诊断分支：`RIG_RECORD=0` 刻意跳过 Screen Recording TCC 探测时必须成功返回，不能被 `set -e` 误判为权限失败；`test_screen_recording.py` 已补回归，rig 全量为 `37/37`。formal ledger/COVERAGE/anchors/alarms 仍为 `1790 / 848 rows / 351 carried / 0 tombstones / clean`，批次三十四 `27/50`，未调用 `judge.py`、未执行 EP-220 删除。

#### 19:08 Screen Recording 权限 fail-fast 机制固化

- 真实环境已验证 `rig-up.sh` 在权限恢复后正常启动并捕获窗口；本轮补充了拒绝路径回归：模拟系统拒绝 `screencapture` 时，conductor 在任何 server、observer、Flutter build、App 启动前退出，不产生半启动 session、二进制或 manifest。
- `python3 -m unittest discover -s testend/rig -p 'test_*.py'`=`37/37`，`bash -n`、Python compile、`git diff --check` 通过；`testend/rig/README.md` 已同步 fail-fast 契约。
- 这是台架机制修复，不写 `judge.py`，不修改 formal ledger/COVERAGE/anchors/alarms；EP-220 当前对象 action-time 永久删除序列门继续关闭。

#### 18:56 EP-213 UI Delete Positive 已删除终态幂等复核（r7）

- 本轮在独立 fixture `/private/tmp/anselm-data-ep213-ui-positive-20260811-r3` 重新启动真实 Flutter App、窗口录制、backend、frontend journal、三路独立 SSE witness 和 managed `llmtap :8793`。新 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-185408`；`rig-check` 五通道通过，`rig-down` 正常封口，录屏 `61.050000s`。
- fresh App 的 `Settings → Models & keys` 只显示受管 `Anselm Free`，没有活动的 `EP-213 UI Delete Positive` 行；同名 API-key 记录均是既有 tombstone，未通过 REST、SQLite、终端或其他旁路恢复对象。画面同时显示 `Cloned voices: No cloned voices yet` 与 `2 of 2 slots free`。因此本轮不存在可安全执行的新删除按钮，没有发出新的 mutation。
- backend 只记录 `GET /api/v1/voices`，llmtap 没有删除 wire，SSE 没有伪造 deletion frame，frontend journal 无应用级 Flutter/Dart/RenderFlex/overflow/Unhandled 红线。候选证据为 `sessions/20260813-185408/evidence/EP-213-ui-delete-positive-idempotent-r7.md`；这是既有删除结果的真实幂等终态复核，不是新的五级裁决。
- 正式状态不变：ledger `1790`，`gen_coverage.py --check`=`848 rows / 351 carried / 0 tombstones`，`alarms.py check`=`clean (1790)`，批次三十四 `27/50`。不调用 `judge.py`，不推进批次，不提前运行统一长门禁或提交；EP-220 当前对象的 action-time 永久删除序列门仍关闭。

#### 19:04 EP-220 当前对象确认边界 r10（仍未执行不可逆动作）

- 在独立 fixture `/private/tmp/anselm-data-ep220-delete-20260813-r4` 重新启动真实 App 和完整五通道台架，session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-190019`。fresh AX/frame 精确显示 `EP220 Delete Trial`、`1 of 2 slots free`、完整费用不退还/释放库存位警告和 `Delete permanently` 按钮；输入框保持为空。
- `rig-check` 在确认层通过，`rig-down` 正常封口，录屏 `245.165000s`。backend 只有 `GET /api/v1/voices`，managed llmtap 没有 voice-delete wire，SSE 没有删除业务帧，frontend 无应用级红线。候选证据为 `sessions/20260813-190019/evidence/EP-220-voice-delete-confirmation-boundary-r10.md`。
- 当前对象的 action-time 永久删除确认仍未收到，故没有输入对象名、没有点击最终按钮、不写 EP-220 正式五格；sidecar/API Serve 定向删除契约和前端回归测试通过，但静态/候选证据不能替代真实 mutation。

#### 17:51 EP-220 r8 确认边界与 EP-221 候选独立复核

- EP-220 当前对象仍为 `EP220 Delete Trial`。真实 App 已打开确认层，确认文案、精确对象名、费用不退还/释放库存位说明和 `Cancel` 均正确；错误输入 `EP220 Delete TriaI` 不放行 `Delete permanently`，取消后实体仍在、库存仍为 `1 of 2 slots free`。候选证据为 `sessions/20260813-173949/evidence/EP-220-voice-delete-candidate-r8-confirmation-boundary.md`，确认帧为 `ep220-delete-confirmation.png`。
- 本次五通道台架已在收台前通过 `rig-check`，录屏封口为 `457.238333s / 2784x1808 / 60fps`；backend 仅出现 `GET /api/v1/voices`，llmtap 没有 `voices:delete`，SSE 没有伪造 deletion frame，frontend 无应用级红线。当前对象的永久删除仍未执行，不能写 EP-220 正式裁决。
- EP-221 的 `available=true` session `20260813-103321` 与 `available=false` 隔离 session `20260813-104154` 已重新读取：两段录屏均可解析，正态 action row 显示 `Read aloud`，缺席态无空按钮；REST/backend、SQLite 作用域、三路 SSE、frontend journal、managed tap 事实一致。两段候选仍受 EP-220 序列门约束，不调用 `judge.py`，不改 `COVERAGE`。
- 正式状态不变：ledger `1790`，`gen_coverage.py --check`=`848 rows / 351 carried / 0 tombstones`，`alarms.py check`=`clean (1790)`，anchors/COVERAGE 未修改，批次三十四 `27/50`。EP-213 的历史行动时确认不转移给 EP-220。

#### 18:23 动态正式前线门 stop-and-fix 与 EP-220 台架准备

- 审计发现只声明 EP-220→EP-221 的静态依赖仍会留下 EP-222 及更后行的越序口；已将 `testend/rig/ledger-sequence.json` 收紧为仓内 `first_unsettled` 策略。`judge.py` 在锁内按 COVERAGE 实际行序找到第一条含 `·/✗` 的行，只允许该行写新裁决；五格 settled 后自动推进，任意后行、坏 ledger 行、非法策略版本/模式和外部 `RIG_SEQUENCE` 均 fail-closed。
- 回归 `testend/rig` 全量 `36/36`，其中 `test_judge.py 7/7`、`test_scope.py 16/16`；正式账本的 EP-221、EP-222 越序探针均被拒绝，COVERAGE 与 `judgments.jsonl` 哈希未改变；`gen_coverage.py --check`=`848/351/0`，formal alarms=`clean (1790)`，docs verify 和 diff check 通过。
- EP-220 当前对象仍是 `EP220 Delete Trial`（workspace `ws_f27e55d84cee9c45`、voice `vce_7d4d4e1496ccda91`）。数据库确认目标仍是活动行；下一步仅准备新鲜真实 App 确认层，最终不可逆按钮必须在 fresh frame 核对精确对象后取得动作时确认，当前未执行删除。

#### 18:02 账本顺序门 stop-and-fix

- 审计发现 `judge.py` 原先执行法条/证据/五通道/锚点/警报校验，但没有执行 working 记录反复声明的正式前线顺序；因此存在“EP-220 尚未收口却可手工给 EP-221 写 pass”的机制缺口。该问题已冻结账本写入并修复。
- `testend/rig/ledger-sequence.json` 现在是仓内版本控制的 `first_unsettled` 策略，不接受 `RIG_SEQUENCE` 替换。`judge.py` 在 ledger lock 内读取当前 COVERAGE，按真实行序只允许第一条含 `·` 或 `✗` 的行继续落裁决；该行五格均为 `✓/~` 后自动推进，任何后行均 fail-closed 拒绝。策略版本/模式非法或清册无可解析行也拒绝；重复同一已记录裁决仍先按幂等重放。
- 回归验证：`testend/rig` 全量 `36/36`（其中 `test_judge.py` `7/7`、`test_scope.py` `16/16`）；已证明 EP-222 不能越过 EP-220、EP-221 两道动态前线，坏 ledger 行、外部 `RIG_SEQUENCE` 和非法策略版本均 fail-closed。对 formal ledger 的真实 EP-221 L1 写入尝试返回 `formal sequence gate`，`COVERAGE.md` 与 `judgments.jsonl` 哈希均未改变。

#### 17:36 基础设施健康复核（不替代 EP-220 正向五级裁决）

- 本仓 `make verify` 已重新通过：backend、frontend、docs、demo 全绿；frontend 全量为 `5361` tests，前端 formatter、slang、build_runner、analyze 均无错误。`make -C backend testend` 独立黑盒场景全绿，`testend/scenarios` 用时 `288.500s`。
- 隔壁 `/Users/sunweilin/Developer/Anselm-API-Serve` 工作树干净，`main` 当前为 `2879a1d9b010104ffab073bf1b48c0fbfd59c5e3`；`make verify` 全绿（含 `go test -race ./...`、integration e2e、golangci-lint、docs lint）。该 commit 的 CI `31590465992` 和 production deploy `31590711567` 均为 success，生产 `/v1/install/challenge` 已返回 `200`。
- voice delete 静态交叉审计与两仓文档一致：sidecar 先调用网关 `POST /v1/voices:delete`，网关对精确 provider 缺失码幂等成功，成功后才删本地行；普通 400/404/5xx 保留本地指针。该健康复核没有发出当前对象的删除请求，因此不能填充 EP-220 五格。
- `gen_coverage.py --check`=`848 rows / 351 carried / 0 tombstones`，`alarms.py check`=`clean (1790)`，`git diff --check` 通过。正式账本、COVERAGE、anchors 和 alarms 不变；EP-220 仍等待当前对象动作时确认。

#### 最新补充：EP-220 voice enrollment、Settings 权威刷新修复与删除边界 r7（2026-08-13 17:10）

真实 App 在 workspace=`ws_f27e55d84cee9c45`、真实受管网关和独立数据目录
`/private/tmp/anselm-data-ep220-delete-20260813-r4` 中完成音频生成、受管 cloned voice 登记和当前对象删除边界复验。登记 session 为
`sessions/20260813-163316`，修复后 Settings/边界 session 为 `sessions/20260813-165157`，完整候选证据为
`sessions/20260813-165157/evidence/EP-220-voice-delete-candidate-r7-settings-refresh-and-boundary.md`；最终录屏
`2784x1808 / 60fps / 592.660000s`，稳定帧为 `sessions/20260813-165157/evidence/frames/ep220-final.png`。

第一轮真实登记通过 `generate_speech` 产生 `att_f496350b17df4b9a`，用户在真实危险交互中批准一次
`enroll_voice`；llmtap 只记录一次上游 `POST /v1/voices`=`200`，SSE durable result 与 SQLite/REST 一致地生成
`vce_7d4d4e1496ccda91 / EP220 Delete Trial / remaining=1`。同一 assistant 批次随后出现的完全重复模型调用被应用层明确
`Duplicate tool call suppressed`，没有第二次上游 mutation 或第二次 approval。

首轮回到已常驻的 Settings 海洋时，真实 backend `GET /api/v1/voices` 已返回该条库存，但 UI 仍显示登记前的空态；按
stop-and-fix 停线。修复 `frontend/lib/features/settings/ui/settings_ocean.dart` 在进入 Models & keys 或离开后重新进入 Settings
时失效 `voicesProvider`，并在 `frontend/test/features/settings/settings_shell_test.dart` 增加跨 Chat 重新进入的权威库存回归。
`docs/references/frontend/features/settings.md` 同步声明该常驻海洋边界。修复后的 focused Settings suite `19/19` 通过。

第二轮用新 binary、同一数据目录和真实五通道台架复验：Settings 正确显示 `EP220 Delete Trial` 与 `1 of 2 slots free`；hover
后 Delete affordance 可发现，确认层完整展示对象名、永久移除/费用不退还/释放库存位警告、Cancel 和 Delete permanently。
输入错误名称 `wrong name` 后最终按钮不放行，取消后目标行和库存仍保持不变。fresh AX/frame、backend、SSE、frontend console、llmtap
和 SQLite 均没有产生任何 voice-delete mutation；最终不可逆删除尚未执行，EP-220 序列门继续关闭。

本轮是候选观察，不调用 `judge.py`，不修改 formal ledger/COVERAGE/anchors/alarms；正式账本 `1790`，清册
`848/351/0 tombstones`，alarms clean，批次三十四 `27/50`。下一步只在当前对象 `EP220 Delete Trial` 获得 action-time 明确确认后，
执行真实 upstream delete → local delete → REST/SQLite/SSE/UI 收敛和重启复核；不得用 EP-213 的历史授权或终端/REST 绕过 UI。

#### 最新补充：SURF-008 shell/notification-tray 真实 App 候选复验（2026-08-13 15:31）

`SURF-008 shell/notification-tray` 在真实 Flutter macOS App、真实受管网关和隔离数据目录中完成通知托盘的真实行点击深链、搜索命中、无匹配空结果、Unread only 和 Today 分组折叠/展开路径。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-150645`，完整候选证据为
`sessions/20260813-150645/evidence/SURF-008-notification-tray-real-app-candidate-r1.md`；录屏 `2784x1808 / 60fps / 1380.481667s` 可读，最终帧已封存。

真实 App 从 Today 28 条通知进入托盘；隔离数据只用一次 REST `mark-read` 制造可辨识读状态，随后真实通知行点击进入精确 Workflow 详情，观察期间托盘与 REST 未读数一致为 27。真实输入搜索 `SURF007 failure queue 2` 得到 5 条匹配行、Today 计数为 5；重新打开托盘后输入 `zzzz-not-found`，稳定帧只保留搜索栏，分组和通知行消失，中心工作流详情不受影响。Today 组头真实折叠后只剩 `Today 28`，展开后恢复行；Unread only 真实切换并按加载状态重新计算组计数。

期间发现 Computer Use `set_value`/AX 语义树与 Flutter 真实编辑事件、截图采集帧可能短暂不同步；重开托盘并用真实键盘路径复核后稳定通过，已分类为工具观测时序，不修改产品代码。settled frame 未见 clipping、overlap、stale center、white flash、reflow、overlay 或 input jump。

五通道事实：backend 无应用级 WARN/ERROR/panic/FATAL；ssetap 两 workspace 三流连接并 clean EOF；frontend 无 Dart/Flutter/RenderFlex/overflow/Unhandled/unknown AX 红线；llmtap 真实 gateway readiness/proof/quota 均 `200`、无虚构 completion；录屏由 `rig-down` 正常封口，所有 conductor-owned 进程停止。`notification_tray_test.dart` 与 notification feed/provider/signal/fixture/unread/row focused suite 共 `50/50` 通过，`rig-check`、`gen_coverage.py --check`、`alarms.py check`、`git diff --check` 通过。

本轮不调用 `judge.py`，不修改 formal ledger/COVERAGE/anchors/alarms；正式账本 `1790`，清册 `848/351/0 tombstones`，alarms clean，批次三十四仍 `27/50`。SURF-008 不是正式五级绿格，EP-220 当前对象 action-time 永久删除序列门继续关闭。

#### 最新补充：SURF-007 shell/notice-band 真实 App 候选复验（2026-08-13 14:59）

`SURF-007 shell/notice-band` 在真实 Flutter macOS App、真实受管网关和独立数据目录中完成真实 workflow failure、approval capsule、队列尾巴、溢出和清场路径。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-144241`，完整候选证据为
`sessions/20260813-144241/evidence/SURF-007-notice-band-real-app-candidate-r1.md`；录屏 `2788x1808 / 60fps / 727.596667s` 可读。

真实 Function 失败经真实 `POST /api/v1/flowruns` 产生 `workflow.run_failed`，App 显示居中的失败胶囊；真实 `trigger → approval` 图停在 parked 状态，App 显示不自动消失的审批块、问题、`Approve` 和 `Reject`。fresh AX 每次动作后均重新读取；拒绝后两个临时 approval run 最终均为 `completed`，节点结果为 `decision=no`，没有留下 parked 项。

审批保持 parked 期间制造真实失败队列，AX 暴露 `Clear all 4 top notifications`；录屏抽帧显示审批卡居中、右缘两颗队列提示点和 `+1` 溢出。点击清场后，顶带展示副本按反向动画收回，但 REST parked 审批和 Notifications 事实未丢；重新打开 Notifications 可见 `Needs you 1`、同一问题和可用决策按钮。该路径验证“清展示、不改事实”的设计边界，本轮未发现需要 stop-and-fix 的产品缺陷。

五通道事实：backend `842` 行无应用级 WARN/ERROR/panic/FATAL；SSE notifications 含 `12` 条 `workflow.run_failed` 和 `2` 条 `workflow.approval_pending`，entities 含 `14` 条 workflow `run_terminal`，两 workspace 三流均 clean EOF；frontend 仅正常启动行，无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception 红线；llmtap 保持真实网关接线，仅 readiness/probe、无虚构 completion。`rig-check` 和 `rig-down` 通过，录屏与关键帧均已封存。

验证：`make -C docs verify`、`gen_coverage.py --check`、`alarms.py check`、`git diff --check` 已通过；聚焦 notice/approval/dispatcher Flutter 回归随本轮同步执行。候选不调用 `judge.py`，不修改 formal ledger/COVERAGE/anchors/alarms。正式账本 `1790`，清册 `848/351/0 tombstones`，alarms clean，批次三十四仍 `27/50`；SURF-007 不是正式五级绿格，EP-220 当前对象 action-time 永久删除序列门继续关闭。

#### 最新补充：SURF-006 shell/ocean-breadcrumb-head 真实 App 候选复验（2026-08-13 14:31）

`SURF-006 shell/ocean-breadcrumb-head` 在真实 Flutter macOS App 上完成 Settings 长页的标题折叠、紧凑浮层头出现和点击回顶候选复验。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-141915`，完整证据为
`sessions/20260813-141915/evidence/SURF-006-ocean-breadcrumb-real-app-candidate-r1.md`；录屏 `2788x1808 / 60fps / 539.996667s` 可读，稳定视觉帧封存于 `evidence/frames/`。

Computer Use 每次动作后 fresh AX：顶部态无紧凑标题；Models & keys 长页小步滚动到大标题离开正文视口后，浮层头出现为可点击的 `Models & keys`；点击后页面回到顶部并恢复大标题。一次大步滚动未出现浮层头仅作为过渡/settling 探索，不定性为缺陷；受控小步重跑稳定复现预期。视觉复核未见 clipping、overlap、stale title、white flash、reflow、overlay 或 input jump，无需 stop-and-fix。

五通道事实：backend 无应用级 WARN/ERROR/panic/FATAL；ssetap 两 workspace 三流均连接并 clean EOF；frontend 仅正常 macOS/Flutter 启动行，无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception 应用红线；llmtap proof challenge/quota 均 200、无 completion 符合只读 Settings 路径事实。`rig-down` 已停止 conductor-owned 进程并封口录屏。

验证：`ocean_breadcrumb_test.dart`、`shell_chrome_test.dart`、`settings_shell_test.dart` 全部通过；本轮不调用 `judge.py`，不修改 formal ledger/COVERAGE/anchors/alarms。正式账本 `1790`，清册 `848/351/0 tombstones`，alarms clean，批次三十四仍 `27/50`。SURF-006 目前是候选观察，不是正式五级绿格；EP-220 当前对象的 action-time 永久删除序列门继续关闭。

#### 最新补充：EP-220 当前对象确认层 r6 安全取消收台（2026-08-13 14:18）

`EP220 Delete Trial` 的真实 App 确认层重新打开并显示完整对象、永久移除/费用不退还/释放库存位说明、Cancel 与 Delete permanently；空输入没有执行删除。本轮按 action-time 不可逆动作边界未输入对象名、未点击最终按钮，只点击 Cancel，目标行和 `1 of 2 slots free` 保持不变。EP-213 `UI Delete Positive` 的历史确认不转移。

有效 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-140938`，完整证据为
`sessions/20260813-140938/evidence/EP-220-voice-delete-confirm-r6-awaiting-action.md`。录屏 `2784x1808 / 60fps / 244.693333s` 可读，backend 无 voice DELETE，llmtap 无 voice-delete 上游请求，SSE 两 workspace 三流连接并 clean EOF，frontend 无应用级红线，conductor-owned 进程均已停止。

这是候选边界，不调用 `judge.py`，不修改 formal ledger/COVERAGE/anchors/alarms；正式账本 `1790`，清册 `848/351/0 tombstones`，alarms clean，批次三十四 `27/50`。EP-220 序列门继续关闭。

#### 最新补充：SURF-005 shell/sidebar-footer 真实 App 候选复验与 stop-and-fix（2026-08-13 14:03）

`SURF-005 shell/sidebar-footer` 在真实 Flutter macOS App 上完成 workspace 快捷菜单、Settings 格、Notifications 格/红点和通知托盘接管候选复验。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-140149`，完整证据为
`sessions/20260813-140149/evidence/SURF-005-sidebar-footer-real-app-candidate-r2.md`；录屏 `2784x1808 / 60fps / 44.393333s`，抽帧 `frames/workspaces.png`。

首次真实点击 `Workspace settings` 时，菜单收起但中心仍为 `Models & keys`。菜单文案承诺进入工作区设置，回调却只选择 Settings ocean；这是实际产品缺陷，已停止继续观察。修复 `frontend/lib/app/app_shell.dart` 让命令选择 `SettingsPanel.workspaces`、清除 pushed detail、再进入 Settings；`frontend/test/app/workspace_switcher_test.dart` 增加「打开 Workspaces 且 detail 为空」守卫。修复后二次真实 App fresh AX 明确出现 `Settings / Workspaces`、`New workspace` 和当前工作区行，旧 Models & keys 消失。

Notifications 格开关也在同一会话中真实验证：打开时托盘只接管左岛中段、Settings 中心保持不变；再次点击关闭后恢复 Settings rail。工作区菜单、底栏三分区、红点和 settled layout 均无 stale menu、重复壳、白闪、clipping、overlap、reflow、overlay 或 input jump。

五通道事实：rig-check 五通道物理归属全绿；backend 无应用级 WARN/ERROR/panic/FATAL；ssetap 三流连接并 clean EOF、只读 shell 路径无业务帧；frontend 无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception 应用红线；llmtap 真实网关 proof challenge/quota 均 200、无 completion 符合路径事实。修复后 `workspace_switcher_test.dart` `2/2`、SURF-005 focused Flutter suite `93/93`、`git diff --check` 通过，rig-down 已收台且封口录屏。

本轮仍是候选观察，不调用 `judge.py`，不修改 formal ledger/COVERAGE/anchors/alarms；账本 `1790`，清册 `848/351/0 tombstones`，alarms clean，批次三十四 `27/50`。EP-220 action-time 永久删除确认仍未获得，正式五级裁决按序列门后置。

#### 最新补充：SURF-004 shell/ocean-switcher 真实 App 候选复验（2026-08-13 13:51）

`SURF-004 shell/ocean-switcher` 在真实 Flutter macOS App 上完成四海洋、Settings 无选中、通知托盘接管和返回 Chat 的候选复验。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-134257`，完整证据为
`sessions/20260813-134257/evidence/SURF-004-ocean-switcher-real-app-candidate-r1.md`。

Computer Use 每次操作后 fresh AX 观察到 `Entities → Chat → Entities → Scheduler → Library → Settings → Notifications tray → Chat`。
Chat、Entities、Scheduler、Library 的 rail/center 内容与目的相符；Scheduler 空态提供 `Open Entities` 与 `Open the conversation`；Settings
和通知托盘时四个顶部海洋均收成图标且没有顶部药丸，通知托盘只接管左侧中段，返回 Chat 后托盘关闭。未观察到 stale center/rail、重复壳、
白闪、clipping、overlap、reflow、overlay 或 input jump。

源码实现与观察一致：`app_shell.dart` 在 Settings/托盘路径传 `-1`，`an_ocean_switcher.dart` 使用单共享药丸、固定较宽 resting layout、
token 几何和单一 `AnMotion.mid` forward controller。本轮没有发现需要 stop-and-fix 的产品缺陷。录屏 `2784x1808 / 60fps / 132.210000s`
经 ffprobe 可读，contact sheet 与抽帧已封存；粗粒度抽帧/scene detector 未可靠隔离 sub-240ms 动画中间帧，因此本轮只证明交互及 settled
geometry，不宣称逐帧动画曲线或 transition latency 的数字证据，该 follow-up 已在证据中明确标记。

五通道复核：backend 无应用级 WARN/ERROR/panic/FATAL；ssetap 三流连接并 clean EOF、无该只读路径预期外业务帧；llmtap 仅 readiness、
proof challenge/quota、无 completion；frontend 无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception 红线，唯一
`IMKCFRunLoopWakeUpReliable` 已分类为 macOS input-host 噪声。台架收台时 conductor-owned App/backend/taps/recorder 均已停止。

验证通过：ocean/shell/router focused Flutter `51/51`、`go test ./cmd/appproxy ./harness/proxycore`、scope/channel-5 Python `24/24`、
`make -C docs verify`、`gen_coverage.py --check` 和 `alarms.py check`。本轮仍是候选观察，不调用 `judge.py`，不改 formal
ledger/COVERAGE/anchors/alarms；正式账本 `1790`，清册 `848/351/0 tombstones`，alarms clean，批次三十四 `27/50`。EP-220 当前对象
action-time 永久删除确认仍未获得，SURF-004 不能越过序列门写正式五级裁决。

#### 最新补充：SURF-002 shell/workspace-gate 真实延迟名册候选复验（2026-08-13 13:42）

`SURF-002 shell/workspace-gate` 在真实 Flutter App 上完成冷启动工作区名册延迟路径候选复验。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-132649`，完整证据为
`sessions/20260813-132649/evidence/SURF-002-workspace-gate-real-app-candidate-r1.md`。

App 通过 conductor 直接启动真实 macOS binary，代理只延迟 `GET /api/v1/workspaces`；首个目标请求
`05:27:16.175969Z→05:28:16.178388Z`，实测 `60.002419s`，后端仍由 `:8927` 直接持有，App 走 `:8790` 代理，
其余请求透明转发。Computer Use/frame 在起始、20 秒、释放前真实看到居中的 `Setting up your workspace...`，
无 shell、旧 workspace、半成品 onboarding 或重复 Router；释放后进入完整 Entities Overview。

测量器给出等待段 `changedFrac=0.00010`（编码噪声级），释放转场 `changedFrac=0.79082`、box=`(112,77)-(2672,1660)`，
ready 稳定帧之间无超过阈值变化；录屏 `2784x1808 / 60fps / 168.611667s` 可读，无白闪、clipping、overlap、reflow、
overlay 或 input jump。backend/frontend 无应用级红线，ssetap 三路连接且无该路径预期外业务帧，llmtap 仅 ready 无 completion。

本轮候选已完成五通道核对、`14/14` workspace 聚焦 Flutter、appproxy/proxycore Go、scope/channel-5 Python `24/24`、
`make -C docs verify`、`gen_coverage.py --check` 和 `alarms.py check`；不调用 `judge.py`，不改 formal ledger/COVERAGE/
anchors/alarms。正式账本 `1790`，清册 `848/351/0 tombstones`，alarms clean，批次三十四 `27/50`。SURF-002 仍是候选，
EP-220 当前对象 action-time 永久删除确认仍未获得。

#### 最新补充：SURF-001 shell/startup-gate 真实三态候选复验（2026-08-13 13:02）

`SURF-001 shell/startup-gate` 完成真实 App 的 starting、crashed、Retry、ready 三态候选复验。第一场 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-124951`，第二场 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-125132`，完整证据为
`sessions/20260813-125132/evidence/SURF-001-startup-gate-real-app-candidate-r1.md`。

8 秒延迟场真实看到全画布居中的 `Connecting to the local engine…`，backend ready 后进入完整 Entities Overview；25 秒延迟场
超过前端健康等待预算，真实 AX 和画面落入 `Can't reach the local engine` 错误态，提供清晰原因和 `Retry`，点击后恢复完整
Entities Overview。崩溃帧和 Retry 后稳定帧为 `evidence/frames/surf001-crashed.png` 与
`evidence/frames/surf001-ready.png`，后者已纠正为 Retry 后帧；两场 MOV 均由 `rig-down` 封口且 ffprobe 可读，owned
processes 已清零。无白屏、重复壳、reflow、overlay 或 input jump。

backend 无应用级 WARN/ERROR/panic/FATAL，frontend 无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception 红线，仅已知
macOS foreground host 噪声；三路 SSE 均连接且无启动路径业务帧；llmtap 仅 ready、无 completion。`app_startup_gate_test.dart`
与 `backend_controller_test.dart` 共 `14/14`，台架 Python 测试 `24/24`，`make -C docs verify`、`gen_coverage.py --check`
与 `alarms.py check` 均通过。本轮不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；账本仍 `1790`，清册仍
`848/351/0 tombstones`，alarms clean，批次三十四仍 `27/50`。SURF-001 仍是候选观察；EP-220 当前对象的 action-time
永久删除确认仍未获得。

#### 最新补充：EP-257 dev-only debug stats 真实台架候选复验（2026-08-13 12:40）

EP-257 `GET /debug/stats` 已完成真实 dev backend、真实 Flutter App、窗口录制、backend/frontend journal、三路独立 SSE witness 与受管 llmtap 候选观察。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-123812`，完整证据为
`sessions/20260813-123812/evidence/EP-257-debug-stats-real-app-candidate-r1.md`。

五次连续读取均返回完整 10 字段 JSON；所有字段为非负整数，`gomaxprocs=8`、`numCPU=8` 为正，`heapSysMB=19 >= heapAllocMB=12`，`heapObjects` 随实时请求自然变化。任意 query string 不改变 schema 或语义，响应只含 runtime 指标；POST `405`。独立无 `ANSELM_DEV` backend 对相同路径严格 `404`，健康检查 `200` 后优雅退出。

真实 App fresh AX/frame 始终为可读 Entities Overview，无 clipping、overlap、reflow、overlay 或 input jump；backend 无应用级 WARN/ERROR/panic/FATAL，frontend 无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception 红线；三路 SSE 保持连接且无业务帧符合只读 debug 路径，llmtap 仅 startup ready、无 completion。录屏封口 `52.981667s`，owned processes 已清零。本轮仍为候选，不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；正式账本仍 `1790`，清册仍 `848/351/0 tombstones`，alarms clean，批次三十四仍 `27/50`。EP-220 当前对象的 action-time 永久删除确认仍未获得。

#### 最新补充：EP-256 dev-only pprof trace 真实台架候选复验（2026-08-13 12:36）

EP-256 `GET /debug/pprof/trace` 已完成真实 dev backend、真实 Flutter App、窗口录制、backend/frontend journal、三路独立 SSE witness 与受管 llmtap 候选观察。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-123331`，完整证据为
`sessions/20260813-123331/evidence/EP-256-pprof-trace-real-app-candidate-r1.md`。

显式 `seconds=1` 返回 `200 application/octet-stream`、`24,405 bytes`，首字节为 `go 1.25 trace`；保存原件经 `go tool trace -pprof=sched` 生成 gzip profile，再由 `go tool pprof -top` 解析出 `489.98us` 调度延迟样本和真实 backend/sqlite/pprof 栈。`seconds=0.25` 非空；`seconds=0/-1/非法` 均按 Go 标准库回落 1 秒并返回非空 trace；POST `405`。独立无 `ANSELM_DEV` backend 对相同路径严格 `404`。

真实 App fresh AX/frame 始终为可读 Entities Overview，无 clipping、overlap、reflow、overlay 或 input jump；backend 无应用级 WARN/ERROR/panic/FATAL，frontend 无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception 红线；三路 SSE 保持连接且无业务帧符合只读 debug 路径，llmtap 仅 startup ready、无 completion。录屏封口 `95.851667s`，owned processes 已清零。本轮仍为候选，不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；正式账本仍 `1790`，清册仍 `848/351/0 tombstones`，alarms clean，批次三十四仍 `27/50`。EP-220 当前对象的 action-time 永久删除确认仍未获得。

#### 最新补充：EP-255 dev-only pprof symbol 真实台架候选复验（2026-08-13 12:31）

EP-255 `GET /debug/pprof/symbol` 已完成真实 dev backend、真实 Flutter App、窗口录制、backend/frontend journal、三路独立 SSE witness 与受管 llmtap 候选观察。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-122653`，完整证据为
`sessions/20260813-122653/evidence/EP-255-pprof-symbol-real-app-candidate-r1.md`。

dev GET 对空 query、未知地址、零地址和混合非法地址均返回 `200 text/plain` 的 `num_symbols: 1`；从同一进程刚采集的 CPU profile 取 live PC `0x102e4a7ec`，查询成功返回 `runtime.(*mspan).heapBitsSmallForAddr`，证明真实正向符号解析。POST 返回 `405`，HEAD 返回 `200` 头部响应；独立无 `ANSELM_DEV` backend 对相同路径严格 `404`，健康检查 `200` 后优雅退出。

真实 App fresh AX/frame 始终为可读 Entities Overview，无 clipping、overlap、reflow、overlay 或 input jump；backend 无应用级 WARN/ERROR/panic/FATAL，frontend 无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception 红线，仅已知 foreground host 噪声；三路 SSE 保持连接且无业务帧符合只读 debug 路径，llmtap 仅 startup ready、无 completion 符合不经过 LLM。录屏封口 `159.461667s`，owned processes 已清零。本轮仍为候选，不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；正式账本仍 `1790`，清册仍 `848/351/0 tombstones`，alarms clean，批次三十四仍 `27/50`。EP-220 当前对象的 action-time 永久删除确认仍未获得。

#### 最新补充：EP-254 dev-only CPU profile 真实台架候选复验（2026-08-13 12:30）

EP-254 `GET /debug/pprof/profile` 已完成真实 dev backend、真实 Flutter App、窗口录制、backend/frontend journal、三路独立 SSE witness 与真实受管 llmtap 候选观察。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-121944`，完整证据为
`sessions/20260813-121944/evidence/EP-254-pprof-profile-real-app-candidate-r1.md`。

显式 `seconds=3` 采样在有界本地请求负载期间返回可解析 gzip pprof；`go tool pprof` 成功解析 `3.03s`、`66` nodes、`50ms` samples，并看到实际 backend/sqlite/logger 栈；POST `405`。Go 标准 pprof 的 `seconds<=0` 回落默认 30 秒已真实观察，台架将显式正 duration 与 client timeout 作为调用约束。独立无 `ANSELM_DEV` backend 对 profile 严格 `404`。

真实 App 在采样期间保持稳定，三路 SSE 全连接但无业务帧符合本地 debug 路径；backend/frontend 应用级红线均为 0，llmtap 无 completion。录屏封口 `179.023333s`，owned processes 已清零。本轮仍为候选，不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；正式账本仍 `1790`，清册仍 `848 rows / 351 carried judgments / 0 tombstones`，alarms clean，批次三十四仍 `27/50`。EP-220 当前对象的 action-time 永久删除确认仍未获得。

#### 最新补充：EP-253 dev-only pprof cmdline 真实台架候选复验（2026-08-13 12:22）

EP-253 `GET /debug/pprof/cmdline` 已完成真实 dev backend、真实 Flutter App、窗口录制、backend/frontend journal、三路独立 SSE witness 与受管 llmtap 候选观察。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-121610`，完整证据为
`sessions/20260813-121610/evidence/EP-253-pprof-cmdline-real-app-candidate-r1.md`。

dev GET 返回 `200 text/plain`、52 bytes，body 仅为当前 server 可执行文件路径，未泄露 gateway/proof 环境值；POST 返回 `405`。独立无 `ANSELM_DEV` 的 production backend 对相同路径严格返回 `404`，bootstrap `TestRegisterDebug_DevOnly` 定向通过。

真实 App 在读取后保持稳定，三路 SSE 全连接但无业务帧符合本地 debug 路径；backend/frontend 应用级红线均为 0，llmtap 无 completion 符合不经过 LLM。录屏封口 `56.331667s`，owned processes 已清零。本轮仍为候选，不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；账本仍 `1790`，清册仍 `848/351/0`，alarms clean，批次三十四仍 `27/50`。EP-220 当前对象的 action-time 永久删除确认仍未获得。

#### 最新补充：EP-252 dev-only pprof Index 真实台架候选复验（2026-08-13 12:16）

EP-252 `GET /debug/pprof/` 已完成真实 dev backend、真实 Flutter App、窗口录制、backend/frontend journal、三路独立 SSE witness 与真实受管 llmtap 候选观察。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-121053`，完整证据为
`sessions/20260813-121053/evidence/EP-252-pprof-index-real-app-candidate-r1.md`。

`ANSELM_DEV=1` 下 `/debug/pprof/` 返回 `200 text/html`，标准 Go index 列出 `allocs/block/cmdline/goroutine/heap/mutex/profile/symbol/threadcreate/trace`；named profiles、带引号的 `goroutine?debug=2`、`profile?seconds=1`、`trace?seconds=1` 均真实 `200`。相邻 `/debug/stats` 返回完整可解析 runtime JSON。独立无 `ANSELM_DEV` 的 standalone backend 中 `/debug/stats` 与 `/debug/pprof/` 均严格 `404`，bootstrap `TestRegisterDebug_DevOnly` 定向通过。

真实 App 在 profile/trace 请求期间保持稳定，三路 SSE 全连接但无业务帧符合本地 debug 路径；backend/frontend 无应用级 WARN/ERROR/panic/FATAL、Flutter/Dart/RenderFlex/overflow/Unhandled/Exception 红线，llmtap 无 completion 符合不经过 LLM。录屏封口 `147.978333s`，owned processes 已清零。一次未加引号的 zsh URL glob 错误已在证据中明确归类为探针错误，不冒充产品缺陷。

本轮仍为候选，不调用 `judge.py`，不改 formal ledger、COVERAGE、anchors 或 alarms；正式账本仍 `1790`，清册仍 `848 rows / 351 carried judgments / 0 tombstones`，alarms clean，批次三十四仍 `27/50`。EP-220 当前对象 `EP220 Delete Trial` 的 action-time 永久删除确认仍未获得，EP-252 不能越过顺序门写正式五级裁决。

#### 最新补充：EP-251 notifications SSE 真实 App 候选复验（2026-08-13 12:06）

EP-251 `GET /api/v1/notifications/stream` 已完成完整 runtime 隔离副本上的真实 App、Computer Use、窗口录制、backend/frontend journal、三路独立 SSE witness 与真实受管 llmtap 候选观察。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-120142`，完整证据为
`sessions/20260813-120142/evidence/EP-251-notifications-stream-real-app-candidate-r1.md`。

真实 App 在通知托盘先显示 `Today 9`，REST `unread-count=9`。正式创建隔离 Function
`ep251_notifications_stream_probe` 后，Entities rail 从 2 个 Function 自动刷新到 3 个；Notifications tray 实时显示
`function.created` 与终态 `environment ready`，总行数为 `Today 11`，REST unread 同步为 `11`。点击 Function-created 行后，中心深链至精确 Function 详情（`v1 / env ready / Python 3.12`），backend 记录 `:mark-read=204`，REST unread 回到 `10`，SQLite 同一通知行 `read_at` 非空。总行数与未读数分开表达，长函数名在 rail 内安全省略，无裁切、重排或布局跳变。

独立 notifications witness 记录 durable `seq=1 function.created → seq=2 sandbox.env_status_changed/installing → seq=3 sandbox.env_status_changed/ready`，序列单调；installing 没有 `inbox` 且不落通知行，function.created/ready 与 REST/SQLite 对齐。三流均已连接，entities 有相关 build 帧，messages 无业务帧符合 direct Function 路径；backend/frontend 应用级红线均为 0，llmtap 无 completion 符合该路径不经过 LLM。录屏已封口 `230.041667s`，owned processes 已清零。

本轮仍为候选，不调用 `judge.py`，不改 formal ledger、COVERAGE、anchors 或 alarms；正式账本仍 `1790`，清册仍 `848 rows / 351 carried judgments / 0 tombstones`，alarms clean，批次三十四仍 `27/50`。EP-220 当前对象 `EP220 Delete Trial` 的 action-time 永久删除确认仍未获得，EP-251 不能越过顺序门写正式五级裁决。

#### 最新补充：EP-250 entities SSE 真实 App 与 Function 调试台候选复验（2026-08-13 11:55）

EP-250 `GET /api/v1/entities/stream` 在隔离 session
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-114944` 完成真实 App、Computer Use、
窗口录制、backend/frontend journal、三路独立 SSE witness 和真实受管 llmtap。有效 backend=`:8914`、
llmtap=`:8810 → https://api.anselm.website`；录屏封口 `208.976667s / 2784x1808 / 60fps`。

首个复制 EP-249 数据的 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-114232` 暴露
台架夹具红：sandbox runtime 只剩悬挂绝对链接，新建 Function 真实显示 `env failed`；另一次旧 `8810`/新
`8812` tap 配置不一致由 channel-5 preflight 在 App 启动前 fail-closed。两者均未当作产品证据。有效重跑
改用含真实 Python Mach-O runtime 的完整基线，并复用数据库原有的空闲 `8810` tap 端口。

真实 App 通过正式创建接口在隔离 workspace 建立 `ep250_entities_stream_probe`，实体 rail 自动从 2 个
Function 刷新为 3 个，Overview 计数同步；选择新实体后详情显示 `v1`、`env ready`、Python 3.12 和完整代码。
Computer Use 点击右岛 `Run` 后，终态显示 `Done · 122ms`、Output、Result、Logs 和 Recent `Manual`；结果为
`{"status":"entities-stream"}`，日志与 Output 均为 `EP-250 entity run observed`。最终原尺寸画面无
clipping、overlap、reflow、右岛遮挡、按钮漂移或输入跳变。

独立 entities witness 记录创建阶段 `build open(seq=1) → delta(seq=0) → close(seq=2)`，运行阶段
`run open(seq=3) → delta(seq=0) → close(seq=4)`；durable `1..4` 单调，两个 delta 没有推进 durable 游标。
notifications 另有 `function.created` 和环境 `installing → ready` durable `1..3`；messages 无业务帧符合
直接 Function 调试台不创建 Chat 回合。REST 与 SQLite 同时确认执行 `fne_809a4ee53163ceca`、
`status=ok`、`triggeredBy=manual`、`output.status=entities-stream`、`elapsedMs=124` 和日志原文。

五通道业务事实为：backend Function 创建/运行与收台路径正常；entities durable `1..4` 连续、delta 为 `seq=0`；
frontend 应用红线 0，仅有已知 macOS IMK/foreground 宿主噪声；直接 Function 路径不经过 LLM，llmtap 无
chat completion 请求与 `triggeredBy=manual` 事实一致。完整候选证据为
`sessions/20260813-114944/evidence/EP-250-entities-stream-real-app-candidate-r1.md`。

本轮不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；正式账本仍 `1790`，清册仍
`848 rows / 351 carried / 0 tombstones`，alarms clean，批次三十四仍 `27/50`。EP-220 当前对象
`EP220 Delete Trial` 的 action-time 永久删除确认仍未释放序列门；EP-250 只形成候选观察。

#### 最新补充：EP-249 messages SSE 真实 App 与续传协议候选复验（2026-08-13 11:36）

EP-249 `GET /api/v1/messages/stream` 在隔离 session
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-113400` 完成真实 App、Computer Use、
窗口录制、backend/frontend journal、三路独立 SSE witness 和真实受管 llmtap。有效 backend=`:8912`、
llmtap=`:8812 → https://api.anselm.website`；录屏封口 `174.295000s / 2784x1808 / 60fps`。首个临时 tap
端口与复制数据目录的旧 managed baseUrl 不一致，channel-5 preflight 在 App 启动前拒绝；随后用持久化正确
端口重启，未将无效 session 当作产品证据。

真实 App composer 发送 `Reply with exactly EP-249 stream smoke passed.`，立即出现新会话和 `thinking`，
composer 保持原位；终态精确显示 `EP-249 stream smoke passed.`，Copy/Fork/Retry/Read aloud 操作区完整，
无 clipping、overlap、reflow、按钮漂移或输入跳变。messages witness 记录 durable `seq=1..8`，包含 user
open/close、assistant open、reasoning open/close、text open/close 和 assistant message close；ephemeral
delta 没有被当作 durable 状态。entities/notifications 三流均独立连接，未把无实体业务帧写成证据。

只读协议复核确认 `fromSeq=1` 回放 `2..8`；同时给 `Last-Event-ID:7` 与 `fromSeq=1` 时 header 优先、只回放
`8`；非法游标是 live-only；缺 workspace 明确返回 `401 UNAUTH_NO_WORKSPACE`。REST 与 SQLite 同时确认一条
completed user、一条 `completed/end_turn` assistant，assistant 的 reasoning/text blocks 与 SSE close 一致。
一次只读 SQLite 探针误用不存在的 `messages.content` 列，未产生写操作，随后按真实 schema 完成核对。

五通道业务事实为：backend 路径 `200/202/204`，负态 `401` 符合契约；frontend 应用红线为 0；真实 llmtap
challenge 与四次 chat completion 均 `200`。完整候选证据为
`sessions/20260813-113400/evidence/EP-249-messages-stream-real-app-candidate-r1.md`。

本轮不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；正式账本仍 `1790`，清册仍
`848 rows / 351 carried / 0 tombstones`，alarms clean，批次三十四仍 `27/50`。EP-220 当前对象
`EP220 Delete Trial` 的 action-time 永久删除确认仍未释放序列门；EP-249 只形成候选观察。

#### 历史候选：EP-248 triage 输出质量 stop-and-fix 后真实 App 五通道复验（2026-08-13 11:26；已由 2026-08-17 正式直通 session 取代）

EP-248 `POST /api/v1/executions/{id}:triage` 完成真实 stop-and-fix 链。首轮真实 App session
`20260813-110224` 暴露前端 `postForId` 省略 body 时 handler 严格 JSON 解码返 `400`；修复为 body 可省略或
传可选 `{note}`，补 handler 测试与 API 文档。session `20260813-111042` 进一步暴露旧 managed install
被网关 `INVALID_INSTALL` 拒绝，以及 quota provider 默认自动 retry 把 Repair CTA 遮成 loading；已修复
provider 的 retry 策略，保留显式 Repair 作为恢复动作，并补 Settings 测试。session `20260813-111625`
在真实 repair 后又发现模型输出含“a requested function_missing + 孤立反引号”：opaque id 被截断且 Markdown 不平衡，
因此该轮仍不计绿。

修复后二进制在 session
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-112345` 由 conductor 托管真实 Flutter
App、Computer Use、窗口录制、backend/frontend journal、三路独立 SSE witness 和受管
`llmtap :8812 → https://api.anselm.website`。fresh AX 打开 `Please diagnose this execution` 后，
第一次点击 Retry 菜单容器没有发请求；重新定位到嵌套 Retry 按钮后真实回合启动并完成。最终回答完整保留
`EP-248 Triage Failure Probe`、`boom` 和 `fn_ep248_missing`，根因、失败证据、结论与下一步均自然可读；
最终 Markdown code spans 成对，没有截断 id、孤立反引号、clipping、overlap、reflow 或 composer 跳变。

五通道已封口：录屏 `161.148333s / 2784x1808 / 60fps`；messages durable `1..31` 无观察到的 gap；
backend 业务状态只有 `200/202/204`，隔离 fixture 的 lexical fallback 与残留 handler env 仅为已解释
`INFO`；frontend 应用级红线为 0；真实 llmtap chat completion 响应均为 `200`。完整候选证据为
`sessions/20260813-112345/evidence/EP-248-triage-real-app-candidate-r3.md`。

本轮当时不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；它仍是修复后候选观察，不能替代正式 endpoint 证据。该候选保留用于说明 stop-and-fix 历史，正式 EP-248 五格以
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260817-160404` 为唯一 L2 session。

#### 最新补充：EP-221 availability 正负态真实 App 五通道候选复核（2026-08-13 10:44）

EP-221 已在两个隔离台架中完成正负两端观察。可用态 session
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-103321` 使用真实受管
`llmtap :8805 → https://api.anselm.website`；REST `GET /api/v1/read-aloud/availability` 返回
`{"data":{"available":true}}`，真实 App 在已有完成回答的 action row 显示 `Read aloud`。fresh AX/frame
同时确认 `Copy`、`Fork from here`、`Retry` 与 `Read aloud` 均完整可见，没有 clipping、overlap、reflow、
按钮漂移或输入区跳变。本轮不点击朗读，EP-222 的 TTS 不在本格重复计数。

缺席态 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-104154` 使用完全隔离的
`/private/tmp/anselm-data-ep221-no-speech-20260813-r2` 和关闭上游
`llmtap :8807 → http://127.0.0.1:9`。active API key 为 `0`，free-tier provision 失败只记录
`device-proof challenge returned HTTP 502` 的 warning；REST 仍以 HTTP `200` 返回
`{"data":{"available":false}}`。真实 App 的已有回答 action row 只保留 `Copy`、`Fork from here`、
`Retry`，`Read aloud` 完整隐藏，没有空按钮、错误页或 Flutter 应用红线。这个负态证明能力诚实缺席，
不是产品缺陷；测试副本之外没有数据被改动。

两次 session 均由 conductor 托管真实 App、窗口录制、backend/frontend journal、三路独立 SSE witness 和
LLM tap；`rig-check`/`rig-down` 均通过，录屏分别为 `308.056667s` 与 `62.926667s`，frontend 应用级红线为
0。完整候选证据分别是
`sessions/20260813-103321/evidence/EP-221-read-aloud-availability-available-candidate-r1.md` 和
`sessions/20260813-104154/evidence/EP-221-read-aloud-availability-absent-candidate-r1.md`。

本轮不调用 `judge.py`，不修改 formal ledger、COVERAGE、ANCHORS 或 alarms；正式账本仍为 `1790`，清册仍为
`848 rows / 351 carried / 0 tombstones`，alarms clean，批次三十四仍为 `27/50`。EP-220 当前对象
`EP220 Delete Trial` 的 action-time 永久删除确认仍未释放序列门，EP-221 正式五级裁决继续按序后置。

#### 最新补充：EP-213 UI Delete Positive 已授权对象的真实幂等终态复核 r6（2026-08-13 10:28）

用户明确确认的精确对象为 `EP-213 UI Delete Positive`；既有正式 mutation 已完成删除。本轮使用独立 fixture
`/private/tmp/anselm-data-ep213-ui-positive-20260811-r3` 重新启动真实 App、Computer Use、窗口录制、backend/frontend journal、三路独立
SSE witness 和真实受管 `llmtap :8793 → https://api.anselm.website`。fresh AX/frame 显示 `No cloned voices yet` 与 `2 of 2 slots free`；
SQLite 交叉核对两个同名 mock 行均有非空 `deleted_at`，目标不在活动列表，因此没有重造对象、没有再次发出 `DELETE`。

backend 只有 `GET /api/v1/api-keys` 与 `GET /api/v1/voices` 读取，LLM wire 只有 ready/proof/quota，三路 SSE 均连接，frontend 无应用级红线，
录屏 `43.213333s` 已封口且 conductor 进程已清零。完整证据为
`sessions/20260813-102639/evidence/EP-213-ui-delete-idempotent-final-r6.md`。这是已完成删除的幂等终态复核，不是新的正式五级裁决；不重复修改
formal ledger/COVERAGE/anchors/alarms，正式 mutation 仍以 `sessions/20260813-083330/evidence/EP-213-ui-delete-authorized-rerun.md` 为准。


#### 最新补充：EP-220 当前对象确认层 r5（2026-08-13 10:06）

真实 App 在 `EP-220 Voice Delete R2` workspace 中重新显示 `EP220 Delete Trial`、`Delete` affordance 和 `1 of 2 slots free`。
fresh AX/frame 打开确认层后完整显示永久移除对象、费用不退还、释放一个库存位、精确输入提示
`Type “EP220 Delete Trial” to confirm` 以及 `Cancel/Delete permanently`；空输入时最终按钮未放行。

本轮未收到该精确对象的 action-time 永久删除确认，因此没有输入名称、没有点击最终按钮，仅点击 Cancel；目标行和库存余量保持不变。
五通道 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-100250`，backend 只有 voices 列表读取、LLM wire
只有 proof/quota、SSE 已连接、frontend 无应用级红线。SQLite 按实际 schema 核对：`voices` 没有 `deleted_at`，目标行仍存在；该域
是上游先行成功后本地硬删除，不套用 API key tombstone 语义。完整候选证据为
`sessions/20260813-100250/evidence/EP-220-voice-delete-confirm-r5-awaiting-action.md`。

本轮不调用 `judge.py`，不修改 formal ledger/COVERAGE/anchors/alarms；账本仍 `1790`，清册仍 `848 rows / 351 carried / 0 tombstones`，
alarms clean，批次三十四仍 `27/50`。EP-220 仍等待当前对象 action-time 永久删除确认；EP-213 历史授权不转移。

#### 最新补充：EP-213 UI Delete Positive 幂等删除核验（2026-08-13 09:58）

用户本轮确认的精确对象为 `EP-213 UI Delete Positive`。独立 EP-213 fixture
`/private/tmp/anselm-data-ep213-ui-positive-20260811-r3` 通过真实 App、Computer Use、窗口录制、backend/frontend journal、
三路独立 SSE witness 和真实受管 `llmtap :8793` 重新核对；fresh AX/frame 与 SQLite 均确认两个 EP-213 workspace 的同名
目标已有 `deleted_at`，当前活动列表只剩受管 `Anselm Free`。本轮没有恢复 tombstone、没有再次发出 DELETE；backend 仅有
`GET /api/v1/api-keys`，LLM wire 仅有 proof/quota，`rig-check` 与 `rig-down` 均通过，frontend 无应用级红线。

本轮是已完成真实删除的幂等收口，不是新的正式五级裁决，不重复修改 formal ledger/COVERAGE/anchors/alarms；完整边界证据为
`sessions/20260813-095524/evidence/EP-213-ui-delete-idempotent-reaudit.md`，正式 mutation 仍以既有授权 session
`sessions/20260813-083330/evidence/EP-213-ui-delete-authorized-rerun.md` 及 post-delete 重启复核为准。

#### 最新补充：EP-221–EP-224 朗读缓存缺陷 stop-and-fix 后真实五通道复验（2026-08-13 09:46）

上一轮真实朗读候选在 SQLite 交叉核对时发现：`speech_cache.last_used_at` 对历史零值行和新写入
行都落成 Go 零时间 `0001-01-01 00:00:00+00:00`。这不是观察噪声，而是会让 LRU 把刚合成的产物
误判为最久未使用，故按规则先停线，不沿用上一轮候选为绿。

修复分两层：`SpeechCacheStore.Put` 写入前显式盖 `LastUsedAt=time.Now().UTC()`；bootstrap 在
schema migration 后幂等调用 `RepairLegacyRecency`，把历史零值回填为同一行 `created_at`，不覆盖
已经有真实命中时间的行。新增存储测试覆盖新行时间戳和回填幂等性；`app/readaloud`、
`infra/store/attachment`、`bootstrap` 定向 Go 测试通过，`make -C docs verify` 与 `git diff --check`
通过；数据库和 attachment domain 文档已同步。

修复后二进制使用真实旧数据目录重新起 App：session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-093429`，
backend=`:8899`，llmtap=`:8805 → https://api.anselm.website`。启动后旧库 4 条 cache 全部为非零近期性，
其中 3 条旧零值精确回填到自身 `created_at`，已有真实命中时间保持不变；新行
`spc_32a5e1394eedcd67` 非零且与创建时间相同。真实 App 新建会话发送唯一文本并得到精确回复；
未命中朗读的 `Preparing read-aloud… → Read aloud` 在同一按钮槽位收敛，第二次同文本命中未重复
上游 TTS，画面无内容跳变或输入区跳变。

五通道证据：窗口录制 `173.830000s`；backend journal 无 WARN/ERROR/panic/fatal；三路独立 SSE
witness 均连接，目标 workspace messages durable seq=`1..8`、notifications seq=`1..2` 无缺口；
Flutter runner、真实 App window 和 frontend journal 均在台架内，前端只有已知 macOS launcher 的
`Failed to foreground app; open returned 1`，无 Dart/Flutter/RenderFlex/overflow/Unhandled/Exception
红线；两次 read-aloud REST 动作均完成，只有一次未命中动作穿过 llmtap 发出 `/v1/audio/speech`，HTTP 为 200；缓存命中
没有新增上游 TTS 请求。
`rig-check` 动作前/收台前通过，`rig-down` 正常，证据：
`sessions/20260813-093429/evidence/EP-221-224-readaloud-capabilities-repair-r1.md`。

本轮仍是修复后真实观察候选，不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；正式
账本仍 `1790`，清册仍 `848 rows / 351 carried / 0 tombstones`，alarms clean，批次三十四仍 `27/50`。
EP-220 当前对象删除未执行；EP-221–EP-224 待 EP-220 序列门释放后逐格入账。

#### 最新补充：EP-221–EP-224 朗读/能力目录真实五通道候选复验（2026-08-13 09:24）

新 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-091608` 在正确持久化受管接线 `llmtap :8805` 下完成真实
App 观察。EP-221 availability 返回 `{available:true}`；EP-223 能力目录为唯一 `anselm-auto` 且真实 UI 显示受管 Free tier；
EP-224 返回并展示 canonical 六槽 `dialogue → utility → agent → image → speech → video`。Settings 的 quota、managed key、
`EP220 Delete Trial` 和 `1 of 2 slots free` 同步可见，无省略号、裁剪、重排或错误红线。

EP-222 同时验证缓存和首次合成：缓存文本的动作位由 `Read aloud → Stop → Read aloud` 收敛且不重复上游；新回复
`Read aloud uncached probe 0918.` 的朗读动作先显示同槽位 `Preparing read-aloud…`，再回到 settled `Read aloud`。llmtap
记录两次 chat completion 200、一次 `/v1/audio/speech` 200，响应 280364 bytes；SQLite 新增 speech-cache 行和
`read-aloud.wav` attachment，缓存路径没有第二次 TTS 请求。四张稳定帧、录像和五通道全文证据见
`sessions/20260813-091608/evidence/EP-221-224-readaloud-capabilities-candidate.md`。

本轮只形成候选观察，不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；账本仍 `1790`，清册仍
`848 rows / 351 carried / 0 tombstones`，alarms clean，批次三十四仍 `27/50`。EP-220 `EP220 Delete Trial` 未执行删除，
EP-213 的历史授权不转移。

#### 最新补充：EP-220 r4 正确接线后的真实确认层复核（2026-08-13 09:00）

复用夹具的持久化受管 key 实际指向 `127.0.0.1:8805`。首个诊断 session 使用 `8796`，`rig-check` 正确拒绝 channel-5 wiring，
并已收台，不计产品证据。随后用真实持久化 `8805` 启动完整台架，`rig-check` 五通道通过；llmtap 的 proof challenge/quota
均为 `200`，App quota 稳定显示 `8 / 1B`。

真实 App 在 workspace=`EP-220 Voice Delete R2` 中重新发现当前对象 `EP220 Delete Trial`，打开确认层后，原尺寸画面完整显示
永久删除对象、费用不会退还、只释放一个库存位和 `Type “EP220 Delete Trial” to confirm`；没有点击最终
`Delete permanently`，没有发出上游或本地 DELETE。SQLite 目标行仍存在，backend 无 voice DELETE，frontend 无应用级运行时红线，
录屏 `291.678333s` 可读，`rig-down` 已正常收台。稳定帧和完整候选证据分别为
`sessions/20260813-085330/evidence/frames/ep220-confirm-r4-awaiting-action.png` 与
`sessions/20260813-085330/evidence/EP-220-voice-delete-confirm-r4-awaiting-action.md`。

本轮只证明正确接线、当前对象识别和不可逆边界呈现，不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/alarms；正式账本仍
`1790`，清册仍 `848 rows / 351 carried / 0 tombstones`，alarms clean，批次三十四仍 `27/50`。EP-220 仍等待当前对象的
action-time 永久删除确认；EP-213 的历史授权不转移。收到确认后才继续真实 `upstream 204 → local 204 → UI/inventory settled`、
重启复核和五级裁决。

#### 最新补充：通道五启动前接线门 stop-and-fix（2026-08-13 09:12）

上一轮真实运行证明了 `rig-check` 能在 App 已启动后识别旧数据目录的错误 `llmtap` 指针，但这仍会先浪费一轮 Flutter
和录屏。现已把同一判定前移到 `rig-up.sh` 的 backend 健康/播种之后、ssetap/Flutter/录制器之前：逐 workspace 读取
managed key，已有 key 必须精确指向本轮 `http://127.0.0.1:<LLMTAP_PORT>`；无 workspace 或无 managed key 才是
onboarding pending。API 失败、坏响应、managed key 缺 `baseUrl`、错误端口和 `8805`/`88050` 这类前缀碰撞全部拒绝启动。
判定集中在 `testend/rig/channel5_wiring.py`，启动前置检查与 `rig-check.sh` 共用，新增 8 个边界单测锁定该契约。

本地验证为 `bash -n testend/rig/rig-up.sh testend/rig/rig-check.sh`、`python3 -m unittest
testend.rig.test_channel5_wiring testend.rig.test_scope -v`（24 tests passed）、`git diff --check`；台架手册已同步。
本次不启动真实 App、不调用 `judge.py`，formal ledger 仍 `1790`，COVERAGE 仍 `848/351/0`，alarms clean，批次三十四仍
`27/50`。这是防止无效录制的仪器修复，不是产品格子的正式裁决。

#### 最新补充：EP-243–EP-247/EP-251 通知中心 r12 真实五通道观察（2026-08-13 08:40）

有效 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-082016`，数据目录为
`/private/tmp/anselm-data-notifications-20260813-r12`，workspace=`ws_eca2a3332fae9b5a`。真实 App 完成 onboarding，
经受管网关创建两个 Function，再打开通知铃托盘。单条点击 beta 创建通知后，通知被标记已读并导航到 Function 详情；
`Display options → Unread only` 将 4 行过滤为 3 行；Today 组可折叠/展开；hover 组头显出 `More actions`，菜单提供
`Mark all read / Mark all unread`。执行 Today 组的 `Mark all read` 后，审计行仍保留，UI、REST 和 SQLite 均收敛到
`unread=0`。未发现视觉跳变、裁剪、重排、按钮漂移或输入异常。

五通道已封口：录屏 `653.243333s / 2784x1808 / 60fps`，稳定帧为
`sessions/20260813-082016/evidence/frames/ep243-notifications-all-read-r12.png`；backend 无应用级 panic/FATAL/WARN/ERROR；
独立 ssetap 的 messages/entities/notifications durable 序列分别为 `1..40`、`1..8`、`1..8`，无 durable gap；llmtap
记录 18 个 HTTP 200 响应，包含 bootstrap 和两次 Function 创建；frontend 无 Flutter/Dart/RenderFlex/overflow/Unhandled/
Exception 应用红线，已知 stale AX-node 仅按本 session `frontend-ax-review.md` 审阅；SQLite 四条通知的 `read_at` 与 REST
未读计数一致。`rig-check` 前后通过，`rig-down` 正常封口且 owned processes 清零。

完整候选证据为 `sessions/20260813-082016/evidence/EP-243-247-251-notification-center-r12.md`。本轮不调用 `judge.py`，
不改 formal ledger/COVERAGE/anchors/警报阈值；正式账本仍 `1790`，清册仍 `848 rows / 351 carried / 0 tombstones`，formal
alarms clean。批次三十四由 `26/50` 推进为 `27/50`；EP-220 当前对象仍未获得 action-time 永久删除确认，不能沿用 EP-213
历史确认。

#### 最新补充：EP-213 精确对象授权删除闭环（2026-08-13 08:40）

用户本轮明确确认删除 `EP-213 UI Delete Positive`。在真实 App 中先从 `EP-213 Delete` 切到正确的
`EP-213 UI Delete` workspace，再由新鲜 AX/frame 核对目标名称和永久性文案完全匹配，随后点击最终 `Delete`。UI 立即
只剩其他三行；后端记录目标 `DELETE .../aki_b67e840525785925=204`，重复删除返回 `404 API_KEY_NOT_FOUND`；SQLite 保留
tombstone 身份和 `deleted_at`，同时清空密文及 probe 材料；重启后列表仍无幽灵目标。

第一次动作 session 因复用夹具时持久化 managed key 仍指向 `8788`、而新 tap 在 `8794`，被 `rig-check` 正确拒绝通道五
接线，未把不完整仪器证据冒充全绿。随后以持久化 `8788` 重启同一夹具，`rig-check` 全通道通过并完成 post-delete 复核；
证据为 `sessions/20260813-083330/evidence/EP-213-ui-delete-authorized-rerun.md` 与
`sessions/20260813-083905/evidence/frames/ep213-after-delete-settled.png`。这是已完成 EP-213 绿格的授权清理闭环，不
重复写 formal ledger、不推进批次，也不把授权外推给 EP-220。

#### 最新补充：EP-223 r11 文案修复后真实五通道复验（2026-08-13 08:16）

EP-223 r10 的真实画面曾发现受管 `Anselm Auto` 的长二级文案在固定单行轨道中被省略号截断；已直接收紧为英文
`Gateway-managed`、中文「网关托管」，同步 i18n 源、slang 生成物、设置参考与可见性测试。r11 使用全新数据目录和
真实 App 完成 onboarding，Computer Use 打开 Models & keys → Dialogue → Change；AX 树和原尺寸画面均显示完整的
`Anselm Auto` 与 `Gateway-managed`，没有 ellipsis、reflow、clipping、按钮漂移或输入跳变。真实经 Anselm Auto
网关发送 `Reply with exactly: EP-223 R11 smoke passed.`，得到精确回复 `EP-223 R11 smoke passed.`。

有效 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-080900`，数据目录为
`/private/tmp/anselm-data-ep223-capabilities-20260813-r11`，workspace=`ws_b43de815beec0b16`；录屏
`286.278333s / 2784x1808 / 60fps`，证据帧为 `evidence/frames/ep223-dialogue-picker-r11.png` 与
`evidence/frames/ep223-chat-r11.png`。五通道事实一致：backend 健康且无应用级 panic/WARN/ERROR；llmtap
challenge/install/models/quota 与两次 chat completion 全为 200；messages durable seq=`1..8`、notifications
seq=`1..2` 单调，entities 三流已连接且本轮无实体 durable mutation；SQLite 保存 workspace、conversation、用户消息和
completed assistant（provider=`anselm`、model=`anselm-auto`、outputTokens=`47`）；frontend 仅正常 runner/DevTools
和已知 macOS IMK 宿主噪声，无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception 应用红线。`rig-check` 前后通过，
`rig-down` 正常封口，owned processes 已清零。

本轮是修复后真实观察候选，不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/警报阈值；正式账本仍 `1790`，
清册仍 `848 rows / 351 carried / 0 tombstones`，formal alarms clean。批次三十四由 `25/50` 推进为 `26/50`；EP-220
当前对象 `EP220 Delete Trial` 仍未获得 action-time 永久删除确认，EP-213 的历史确认不外推。序列门释放后才按 CODEX
逐格复审并入账。

#### 最新补充：Anselm Auto 二级文案 stop-and-fix 与 EP-213 安全收口（2026-08-13 08:05）

本轮 stop-and-fix 由 EP-223 r10 的真实画面触发：Dialogue 的受管 `Anselm Auto` 行原先使用
`Gateway-managed routing and reasoning`，在固定单行 meta 轨道中被省略号截断。它不是 Flutter overflow，
但用户看到的是不完整的产品模式身份，故按 craft bar 冻结并修复。现在英文短标签为 `Gateway-managed`，中文为
「网关托管」；设置参考、slang 生成物和 `s2_models_keys_test.dart` 已同步，定向 22/22 通过。正式账本仍不写入，
待新二进制 EP-223 r11 真实五通道复验后按 EP-220→EP-221 序列入账。

EP-213 本轮使用活动夹具到达真实确认层，AX/frame 精确显示 `This deletes “EP-213 UI Delete Positive” permanently.`；
只点击 `Cancel`，未输入名称、未点击最终 `Delete`，backend 无目标 DELETE，SQLite 目标仍为活动行且密文仍在。
该 session 已由 `rig-down` 正常封口；不把确认层观察冒充删除成功，也不把历史授权外推到其他对象。

#### 最新补充：EP-223 `GET /api/v1/model-capabilities` r10 真实五通道候选复验（2026-08-13 07:38）

有效 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-072852`，数据目录为
`/private/tmp/anselm-data-ep223-capabilities-20260813-r10`，workspace=`ws_fef1b753c43faaa7`，由 conductor
托管真实 Flutter App、Computer Use、窗口录制、backend/frontend journal、三路独立 SSE witness 和真实受管
`llmtap`。全新数据目录完成 onboarding 创建 `EP-223 Capability R10` workspace，进入 Chat 后真实打开
Settings → Models & keys，刷新模型目录，打开 Dialogue 的 Change 和聊天头部 Auto 菜单，再发送
`Reply with exactly EP-223 R10 smoke.`；真实回答为 `EP-223 R10 smoke`。`rig-check` 动作前/收台前通过，
`rig-down` 正常收台，录屏 `368.158333s / 2784x1808 / 60fps` 可读，owned 进程归零。

设置页真实显示 `Anselm Free · Auto multimodal`、配额、受管 key、六个场景默认槽位和 `Refresh model list`；
刷新后没有把失败吞成空目录。Dialogue 选择器和聊天头部 Auto 菜单都只展示真实可用的 `Auto` 与
`anselm-auto · Anselm Free`，没有虚假模型或不可用旋钮。真实用户对话完成后，user bubble、assistant 文本、
动作行和 composer 稳定对齐，无 clipping、overlap、reflow、按钮漂移或输入跳变。抽帧证据为
`sessions/20260813-072852/evidence/frames/ep223-settings-r10.png`、`ep223-chat-r10.png`、
`ep223-model-menu-r10.png`。

五通道事实一致：REST `GET /api/v1/model-capabilities=200` 唯一能力项为受管
`anselm/anselm-auto`，`vision=true`、`video=true`、`tools=true`、`knobs=null`，原始响应为
`sessions/20260813-072852/evidence/model-capabilities-rest.json`；backend 同 endpoint 为 200 且无应用级
WARN/ERROR/panic/FATAL。SSE messages durable seq=`1..8`，notifications=`1..2`，entities 已连接但本轮无实体
mutation，seq=0 delta 未进入 durable 游标，三流无 gap/乱序。真实 llmtap challenge/install/models/quota 和两次
chat completion（真实回答、auto-title）均为 200。frontend journal 只有正常 runner、已知 macOS 前台/IMK 宿主
噪声，应用级 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception marker 为 0。

完整候选证据为 `sessions/20260813-072852/evidence/EP-223-model-capabilities-r10-current-candidate.md`。
本轮不调用 `judge.py`，不修改 formal ledger/COVERAGE/anchors/警报阈值；账本仍 `1790`，清册仍
`848 rows / 351 carried / 0 tombstones`，formal alarms clean，批次三十四仍 `25/50`。EP-220 当前对象
`EP220 Delete Trial` 的 action-time 永久删除确认仍未完成，不能沿用已删除 EP-213 的历史确认；EP-220→EP-221
序列门释放后才按 CODEX 法条逐格复审并入账。

#### 最新补充：EP-220 当前对象非破坏性边界复验 r3（2026-08-13 07:24）

EP-220 当前对象仍是 `EP220 Delete Trial`，不是已授权并已删除的 `EP-213 UI Delete Positive`。真实 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-072031`，data=`/private/tmp/anselm-data-ep220-voice-delete-20260812-r2`，由 conductor 托管真实 Flutter App、Computer Use、窗口录制、backend/frontend journal、三路独立 SSE witness 和真实受管 `llmtap`；`rig-check` 在操作前、确认层打开后、取消后均通过，`rig-down` 正常收台，录屏 `138.095000s`、`2784x1808`，无 owned 进程残留。

Models & keys 的 Cloned voices 真实显示 `EP220 Delete Trial`、`1 of 2 slots free` 和可发现的 `Delete`。打开危险确认层后，完整显示永久移除对象、费用不退还、仅释放一个库存位，输入提示为 `Type "EP220 Delete Trial" to confirm`；空输入时 `Delete permanently` 保持禁用。随后点击 `Cancel`，危险区收起，目标行与库存余量保持不变。原尺寸确认层帧已固化为 `sessions/20260813-072031/evidence/frames/ep220-confirm-r3.png`，未见长名称截断、裁剪、按钮漂移或 reflow。

五通道对证：backend 相关请求只有 `GET /api/v1/voices=200`，无 `DELETE /api/v1/voices/{id}`；llmtap 没有 voice-delete 上游 wire；两个 workspace 的三路 SSE 建立连接且无实体 durable 变更；frontend journal 仅 19 行正常 runner/已知 IMK 宿主噪声，应用级 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception marker 为 0；REST/SQLite 目标音色仍归原 workspace，未产生 tombstone，库存仍 `1 of 2 slots free`。

完整边界证据为 `sessions/20260813-072031/evidence/EP-220-voice-delete-boundary-r3.md`。本轮只证明“当前对象可发现、危险文案完整、空输入不放行、取消不变”，不调用 `judge.py`，不修改 formal ledger/COVERAGE；EP-220 的正式五级仍需当前对象的明确 action-time 永久删除确认，随后才能验证真实 `upstream 204 → local 204 → UI/inventory settled`。

#### 最新补充：EP-222 Read Aloud r9 真实五通道候选复验（2026-08-13 07:13）

修复后二进制由 conductor 托管真实 Flutter App、Computer Use 窗口录制、backend journal、frontend console、三路独立 SSE witness 和真实受管 `llmtap` 完成 EP-222 r9；session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-070347`，data=`/private/tmp/anselm-data-ep222-readaloud-20260813-r9`，workspace=`ws_dee542a1628a82f3`，conversation=`cv_331c44605a891767`。`rig-check` 在动作前后均通过，`rig-down` 正常收台，录制时长 `211.478333s`，原尺寸 `2784x1808`、`60fps`；无 owned 进程残留。

真实用户目的为“让刚生成的回答朗读，并在再次播放时命中缓存”。点击回答动作行的 `Read aloud` 后，Computer Use AX 立即读到 `Preparing read-aloud…`，像素帧 `sessions/20260813-070347/evidence/frames/ep222-r9-preparing.png` 显示固定槽位 spinner；等待合成期间没有动作行跳变、文本重排、裁剪或按钮漂移。合成后同一槽位变为 `Stop`，停止后回到 `Read aloud`；再次点击同一回答进入播放态，但没有重新请求上游合成。稳定态帧为 `ep222-r9-90s.png`、`ep222-r9-105s.png`、`ep222-r9-195s.png`，播放态帧为 `ep222-r9-playing.png`。

五通道事实一致：backend 的 `POST /api/v1/read-aloud:read` 恰两次，第一次 `200/13976ms`、第二次 `200/0ms`；llmtap 只有一次 `/v1/audio/speech`，响应 `200`、音频 `1286444` bytes。第二次 REST 返回 `cached:true` 并复用 `att_17a72cd4d778b1ae`；SQLite 只有一条对应 `speech_cache` 行和一条未删除的 `read-aloud.wav` attachment，`last_used_at` 随第二次读取更新。messages SSE durable seq=`[1..8]`，notifications=`[1,2]`，entities 已连接但本轮无实体 durable 帧，三流无 gap/乱序。frontend journal 共 18 行，应用级 Flutter/Dart/RenderFlex/overflow/unhandled/panic/FATAL marker scan 为 0，仅有正常 runner、macOS IMK 宿主噪声和收台行。

完整候选证据为 `sessions/20260813-070347/evidence/EP-222-read-aloud-r9-current-candidate.md`。`go test ./internal/app/readaloud ./internal/infra/store/attachment ./internal/transport/httpapi/handlers -count=1` 已通过。r9 只形成修复后真实观察候选，不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/警报阈值；账本仍 `1790`，清册仍 `848 rows / 351 carried / 0 tombstones`，`alarms.py check` clean，批次三十四仍 `25/50`。EP-220 `EP220 Delete Trial` 的动作时对象确认仍未完成，不能套用已删除 EP-213 `UI Delete Positive` 的历史确认；EP-220→EP-221→EP-222 序列释放后，才按证据逐格入账。

#### 历史补充：EP-243/EP-244/EP-251 修复后 r8 真实五通道候选复验（2026-08-13 06:57）

修复后二进制由 conductor 托管真实 Flutter App、Computer Use 窗口录制、backend journal、frontend console、三路独立 SSE witness 和真实受管 `llmtap` 完成 r8；session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-064314`，data=`/private/tmp/anselm-data-ep243-env-copy-fix-20260813-r8`。`rig-check` 在动作前后均通过，`rig-down` 正常收台，录制时长 `634.308333s`；r6 的通知真相红线、r7 的台架启动红线均保留为历史证据，不被覆盖。

本轮 stop-and-fix 直接收紧了产品引导而没有改动作契约：`edit_handler`/`edit_function` 的工具描述、`restart_handler` 的边界描述，以及 AI iterate steer 现在明确规定“保持定义不变、只重建失败环境”必须调用匹配的 `edit_*` 且 `ops: []`；`restart_handler` 只重置 ready 环境中的 resident，不负责安装或重建。Go 定向测试、AISpawn/Handler 回归和相关领域工具文档已同步，`gofmt` 与 `git diff --check` 通过。

真实 Handler 路径中，实体菜单的 `Edit with AI` 可发现；首轮 AI 先读取定义并询问具体变化，第二轮自然语言“只重建失败环境、代码/依赖/config 完全不变”后，LLM wire 只调用 `edit_handler`，载荷为 `ops:"[]"`（字符串化数组由解码器接受），没有调用 `restart_handler`。SSE/后端终端出现单一、三次有界失败环境尝试，没有 `handler.env_rebuilt` 成功通知；REST/SQLite 最终保持同一 v1、`envStatus=failed`、`runtimeState=stopped`、`configState=ready`，App 画面给出可读失败摘要、依赖提示和三次尝试结果，而不是伪造成功。

真实 Function 路径同样只调用 `edit_function` 的 `ops: []`，不铸新版本；LLM wire、SSE、REST/SQLite 和最终 App 回复均说明代码、依赖、config 未改变，仅重试环境安装，失败终态保持可见。两条路径都没有成功环境可供运行，这一轮验证的是“失败仍诚实、重试动作正确、定义不被破坏”，不是把失败环境判成产品成功。

Computer Use 逐帧复核了实体状态、失败摘要、Activity 触点和 AI 回复；frontend console 共 `1,256` 行，其中 `1,238` 行是已知 macOS accessibility bridge stale-node 形态，未知 AXTree 形态为 `0`，最后一次交互后静置 5 秒无增长；没有 Dart/Flutter/RenderFlex/overflow/unhandled/panic。一次早期仪器点击误触 Handler 的 `Call method` 后立即取消，只产生一条失败 ping 调用且没有实体变更，已保留在 session 真相中，不作为产品路径结果。

r8 只恢复为 EP-243/EP-244/EP-251 的“修复后真实观察候选”，不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/警报阈值；账本仍 `1790`，清册仍 `848 rows / 351 carried / 0 tombstones`，`alarms.py check` clean，批次三十四仍 `25/50`。当前正式前线继续是 EP-220 `EP220 Delete Trial`，必须对当前对象在动作时重新确认，不能套用已删除的 EP-213 `UI Delete Positive` 授权；EP-220→EP-221 序列门释放后，才可按证据逐格入账。

#### 历史补充：EP-243/EP-244/EP-251 失败重建误发成功通知，冻结等待 r7（2026-08-13 06:17）

前置真实 session `/private/tmp/anselm-rig-formal-20260813-042809` 已证明 Function/Handler 的耐久终态和状态投影修复有效，但逐帧 review 发现红线：主 Callout 直接展示 `sandboxapp.EnsureEnv`、GitHub runtime URL 和 `context canceled: runtime install failed`。该红证据为 `sessions/20260813-042809/evidence/EP-243-244-251-handler-env-raw-error-red.md`，不计绿。

红线停修期间，Function/Handler 共用的 `EnvironmentFailure` 现按取消/运行时/依赖/通用失败分类；主面只给本地化摘要和 `Edit with AI` 下一步，原始异常仅在用户主动打开 `Technical details` 后显示，并以 4000 字符硬上限保护布局。Handler 生命周期另修正为空 ops/代码编辑的重复安装：一次动作只允许一个有界 build；新环境失败时先停止旧 resident，不能继续执行第二套 spawn/install，也不能让旧类继续服务。对应 Go/Flutter 回归和领域文档已同步。

中间 r4 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-052238` 真实证明原 Handler 空 ops 会产生多个完整环境安装/重建周期，形成产品红证据 `EP-243-244-251-handler-duplicate-rebuild-red.md`。r5 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-053930` 又发现受管 utility 返回“解释文字 + fenced JSON”时旧 `parseDeps` 不消费修复建议，红证据为 `EP-243-244-251-envfix-fenced-response-red.md`。两条红证据均保留，不得用后续绿候选覆盖。

r6 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-054714` 用新 binary、真实 App、Computer Use、窗口录制、backend/frontend journal、三路独立 SSE witness、真实受管 llmtap 完成复验，workspace=`ws_6308c23c55c7caed`。Function 一次空 `:edit` 最终 `envStatus=failed`；Handler 一次空 `:edit` 最终 `envStatus=failed`、`runtimeState=stopped`、`configState=ready`，动作约 16.6s。可是 Handler 的 notifications SSE 同时出现 `handler.env_rebuilt`，与最终 failed 终态矛盾；该 session 及候选证据因此正式降级为红/被 supersede，不得用于任何绿裁决。其余 entities build block、SQLite、backend 与 LLM 证据仍保留用于定位。

Computer Use 逐帧/AX 复核了 Function 与 Handler 的独立状态 chips、失败摘要、依赖提示和 `Technical details` 收起/展开；这些视觉观察仍有效，但因通知真相矛盾，整轮不能判绿。`screen.mov` 已封口为 `168.361667s / 2784x1808`，稳定 Computer Use 截图临时文件在会话结束后已清理，工作记录只引用当时的 AX/截图观察和保留的过程录像，不伪造持久 PNG。

已直接修复 Function/Handler 空 ops 路径：只有 `ensureEnv` 返回 ready 才发 `function.env_rebuilt` / `handler.env_rebuilt`；失败只保留 `failed` 状态、环境状态信号和构建终端，不发成功通知。新增成功/失败通知回归测试，并同步事件/领域文档与 EDGE 清册；定向 Go 测试已通过。下一步是用修复后二进制真实起 App 重跑 r7，确认通知 SSE、REST/SQLite、实体终端、前端画面和 LLM 线缆一致后，才恢复候选状态。正式账本仍 `1790`，清册仍 `848 rows / 351 carried / 0 tombstones`，`alarms.py check` clean，批次三十四仍 `25/50`；EP-220/EP-221 序列门仍在前，不运行统一长门禁、不提交。

#### 最新补充：EP-234–EP-242 系统、网络、保留与存储真实观察完成（2026-08-13 03:18）

有效 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-030420`，由 conductor 托管真实 Flutter App、Computer Use、窗口录屏、backend/frontend journal、三路独立 SSE witness 和真实受管 llmtap；workspace=`ws_e1b28e8f091e830c`，数据目录=`/private/tmp/anselm-data-ep234-242-system-storage-20260813`。录屏封口 `744.840000s / 2784x1808 / 60fps`，`rig-check` 前后通过，`rig-down` 已收台且 owned processes/listeners 归零。完整证据为 `sessions/20260813-030420/evidence/EP-234-242-system-storage-real.md`，稳定帧为 `evidence/frames/storage-final.jpg` 与 `about-final.jpg`。

真实 App 完成 Storage & logs、Network、About 路径：数据目录、sandbox `0 B`、retention `90 days`、数据库 `784.0 KB / 0 B reclaimable`、attachments `0 B / 0 B reclaimable` 均可见；About 显示 App `0.1.0`、Engine `dev`，原尺寸抽帧无 clipping、overlap、reflow 或按钮漂浮。Network 通过真实表单写入临时 `example.test`，再用真实键盘逐字符清空并保存；最终 frame、REST 和配置文件均为 direct mode：`network={}`。中途发现 Computer Use 的 `set_value("")` 让 AX 与截图不一致，已冻结并改走可观测键盘路径，不把仪器假状态算产品绿。

Retention 真实 dropdown 往返 `90 → 30 → 90`，两次均有 `Retention updated`，最终 UI/REST/`settings.json` 都为 `90`，且 `limits/network/retention` 三段完整保留；隔离 workspace 无 flowrun，临时 30 天没有删除任何 run。EP-242 真实点击 Compact database 返回 `200 {"reclaimedBytes":0,"migrated":false}`，复读 storage-stat 仍为 `dbBytes=802816, deadBytes=0`；SQLite `page_count=196, freelist_count=0, auto_vacuum=2`，无隐藏清理或数据变化。未带 workspace 的直接探针返回 `401 UNAUTH_NO_WORKSPACE`，带正确 workspace header 后授权读面均为 `200`。

五通道无应用级红线：backend 无 WARN/ERROR/panic/FATAL，frontend 只有已知 macOS IMK host 噪声，SSE 三流均连接，llmtap challenge/install/models/quota 全 `200`。静态 Storage/Network/About/fixture Flutter `32/32`、backend bootstrap/settings/storage/db/http handlers 定向套件、`git diff --check` 通过；`alarms.py check`=`clean (1790)`，`gen_coverage.py --check`=`848 rows / 351 carried / 0 tombstones`。

本轮只完成真实观察，不调用 `judge.py`，不改 formal ledger/COVERAGE/anchors/警报阈值；正式账本仍 `1790`，清册仍 `848/351/0`，批次三十四仍 `25/50`。EP-234–EP-242 的五级裁决必须等 EP-220→EP-221 序列门释放后按证据逐格写入；下一动作是准备 EP-220 当前对象的 action-time 确认，不得把 EP-213 的历史授权身份外推到它。

#### 最新补充：EP-226/227 关系邻域与全图真实路径修复后完成观察（2026-08-13 02:47）

首个冷启动关系 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-023718` 发现 query 语义红线：`depth=foo`/`1.5` 存在时被静默当成默认深度并返回 `200`，错误会伪装成空邻域。该 session 明确不计绿；已冻结当前切片，HTTP handler 现区分 query 缺席与存在：缺席默认 `2`，出现时必须为一个十进制整数，空/重复/浮点/文字返回 `400 INVALID_REQUEST` 并携带 `param=depth`、`got`、`want`，范围外继续由 domain 返回 `400 REL_DEPTH_LIMIT`。新增 `relation_test.go`，并同步 `api.md` 与 `relation.md`。

修复后二进制有效 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-024157` 真实 REST 证据：无 `depth`、`1`、`2`、`3` 均正常；`0`/`4` 为 `REL_DEPTH_LIMIT`；`foo`/`1.5`/空为带 details 的 `INVALID_REQUEST`；`relgraph` 为 `4 nodes / 2 hydrated edges`。真实 App 逐帧完成 Entities Overview -> 全页 Explore -> 选中 `greet` -> 右岛 `REFERENCED BY deploy-helper` -> 关系 pill 跳 Skill -> `EQUIPS greet` -> provenance -> 隐藏/恢复 Document -> Fit。隐藏端点时节点、标签和相连边一起消失，恢复后完整图回归，未发现新的产品红线。稳定帧与全文证据保存在 session `evidence/`，全文为 `EP-226-227-relations-observed-fixed.md`。

五通道封口：录屏 `243.980000s / 2784x1808 / 60fps` 可读；rig-check 前后五项通过，rig-down 正常收台；backend 无应用级 WARN/ERROR/panic/FATAL，frontend 仅正常 Flutter runner/DevTools 行，无应用级 Flutter/Dart/RenderFlex/Unhandled/Exception 红线；ssetap 三流接通；llmtap challenge/install/models 全 `200`。relation handler/app/domain 与关系图/总览/widget 定向测试通过，`gen_coverage.py --check`=`848/351/0`，formal alarms=`clean (1790)`，`git diff --check` 通过。

EP-226/227 按 EP-220/EP-221 序列门暂不调用 `judge.py`、不改 formal ledger/COVERAGE；账本仍 `1790`、清册 `848/351/0`、警报 clean、批次三十四仍 `25/50`。这两格是“观察修复完成、正式五格待序入账”，不能提前宣称绿。

#### 最新补充：EP-228/229 catalog 与工具目录真实路径（2026-08-13 02:30）

真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-021557` 使用最新二进制、真实 Flutter App、
真实受管 gateway、Computer Use、窗口录制、backend/frontend journal、三路独立 SSE witness 和 llmtap；workspace 为
`ws_7967db8bc0eb0880`，数据目录为 `/private/tmp/anselm-data-ep228-229-20260813-r3`。本轮真实用户目的为“创建一个本地
skill，并确认它能进入目录与工具授权面”。最终 ASCII 输入一次成功调用 `create_skill`，没有 search/activate/edit 或 retry；
App 显示成功卡和完整 name/description/body，Library rail 与详情页显示 `catalog-lab-skill-r3`，REST `GET
/api/v1/skills/catalog-lab-skill-r3=200` 返回完整持久字段。

EP-228 的 `GET /api/v1/catalog=200` 同时返回人类可读 summary 与 `coverage.skill=[catalog-lab-skill-r3]`；EP-229 的
`GET /api/v1/tools=200` 返回 117 个有界 descriptor。Computer Use 从 Skill properties 打开真实 `Add a tool` 弹窗，
看到 Builtin 分组、工具名和可读 summary；稳定帧封存在 session evidence 的 `ep228-skill-detail.png` 与
`ep229-tool-picker.png`。这不是静态目录猜测，而是前端真实消费 `/tools` 的 Library picker 路径。

本轮前置首试因 Computer Use 输入层破坏中文/引号和下划线，形成缺 description/不存在 skill 的失败路径；backend 两条 WARN
被完整保留，UI 保持 `Draft unsaved` 真相，不计产品绿。stop-and-fix 直接加强 `criticalRulesSection` 与 `CreateSkill.Description()`
的 create/new/write/make 意图消歧，并补 chat/skill contract tests 与 Skill 文档；修复后 ASCII 复跑成功。picker 搜索未判绿，
因为 `type_text` 丢下划线、`set_value` 未触发 Flutter `onChanged`，这是观察器输入限制，不冒充产品缺陷；picker suite `7/7`
通过，完整目录加载与视觉可读性已观察。

五通道封口：`rig-check` 在 live session 全绿；`rig-down` 正常收台，录屏 `758.688333s / 2784x1808 / 60fps` 可读；
messages durable `1..37`、entities `1..2`、notifications `1..3` 单调无 gap；llmtap 的 proof/install/models/chat responses
均为 `200`；frontend 只有已知 macOS launcher/IMK 噪声，无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception 红线。
完整证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-021557/evidence/EP-228-229-catalog-tools-observed-fixed.md`。

EP-228/229 真实观察完成，但按 EP-220/EP-221 序列门不调用 `judge.py`、不写 formal ledger、不改 COVERAGE 五格；正式账本仍
`1790`，清册仍 `848/351/0`，alarms clean，批次三十四仍 `25/50`。本轮修复代码与文档已在工作树，待正式序列解除后按五级
裁决入账；不把 observed-fixed 误写成 formal green。

#### 最新补充：EP-230–233 限额真实 App 路径与 stop-and-fix（2026-08-13 01:56）

首轮限额真实 session `20260813-013937` 暴露产品级重复写入：用户按一次回车，backend 收到两次相同
`PATCH /api/v1/limits`，原因是 `_LimitRow` 同时把 `onSubmitted` 与自定义 `onEditingComplete` 绑定到
`_commit()`。前线停下修复为保留 `onSubmitted`、恢复 Flutter 默认 `editingComplete` 行为，点按移出仍显式提交；fixture
增加 PATCH 计数，`s5_storage_limits_test.dart` 要求一次 done 只有一次 PATCH。定向 Flutter suite `12/12`、focused
`flutter analyze` 全绿。

修复后二进制新起隔离 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-015207`，数据目录
`/private/tmp/anselm-data-ep230-limits-20260813-fixed`，真实 workspace `ws_285571c968951ab2`。Computer Use
完成 onboarding → Settings → Advanced limits，逐帧观察机器级说明、Reset all、五组和全部 18 个 schema 字段；顶部修改态
`agent.maxSteps=32` 与尾部恢复态均无 clipping、overlap、reflow、输入跳变或隐藏 CTA。真实回车路径最终只产生一条
`PATCH /api/v1/limits=200` 和一条权威 GET；Reset all 确认框显示 `Reset every limit to its default?`，确认后以一条
`POST /api/v1/limits:reset=200` 和权威 GET 收敛回默认 `25` 等值。

五通道已封口：backend `290` 行无应用级 WARN/ERROR/panic/FATAL，frontend `20` 行无 Dart/Flutter/RenderFlex/overflow/
Unhandled/Exception 产品红线（仅已知 IMK/runner host 噪声）；ssetap 独立接通 `notifications/messages/entities` 三流并
正常收台；llmtap 的 proof challenge/install/models 全 `200`，设置只读/配置路径没有虚构 completion；`rig-check` 全五通道
通过，录屏 `216.715000s / 2784x1808 / 60fps` 可读。证据为
`sessions/20260813-015207/evidence/EP-230-233-limits-real.md`，稳定帧为该 session 的 `limits-top-fixed.jpg` 与
`limits-tail-fixed.jpg`。

这轮真实观察覆盖 EP-230 `GET /limits`、EP-231 `GET /limits/schema`、EP-232 `PATCH /limits` 和 EP-233 `POST
/limits:reset`，但按 EP-220/EP-221 序列门不调用 `judge.py`、不写 formal ledger、不改 COVERAGE 五格；正式账本仍 `1790`，
清册仍 `848/351/0`，alarms clean，批次三十四仍 `25/50`。首次可选 seed 卡住的 session
`20260813-013331` 只保留为台架启动边界，不计产品绿证。

#### 最新补充：EP-224 场景枚举真实 App 五通道路径（2026-08-13 01:25）

静态契约已经在前置 stop-and-fix 中收紧为六项 canonical 顺序：`dialogue`、`utility`、`agent`、`image`、`speech`、`video`。本轮新起隔离数据目录
`/private/tmp/anselm-data-ep224-scenarios-20260813`，由 conductor 托管真实 Flutter App、窗口录制、backend/frontend journal、三路独立 SSE witness 和 llmtap；真实 workspace 为
`ws_961ef30cec854cc2`。Computer Use 在 Settings → Models & keys 的 Scenario default models 区逐帧看到六行完整人话说明与六个 Change 入口：Dialogue、Utility、Agent、Image generation、Speech synthesis、Video generation；滚动到尾部后最后两行与 Search keys 区仍完整可读，无截断、重叠、溢出或跳变。稳定终帧为
`sessions/20260813-011852/ep224-final-scenarios.png`。

同一 live sidecar 的 REST 交叉核对：有 workspace 和无 workspace 的 `GET /api/v1/scenarios` 均为 `200`，body 为恰六项 canonical 数组；错误方法 `POST` 为标准 `405 METHOD_NOT_ALLOWED` 并保留 `Allow: GET, HEAD`。backend journal `220` 行无 WARN/ERROR/panic/FATAL，frontend `18` 行仅有已知 macOS launcher 的 `Failed to foreground app; open returned 1`，无 Dart/Flutter/RenderFlex/overflow/Unhandled/Exception 红线；ssetap 已连接该 workspace 的 messages/entities/notifications 三流，llmtap `13` 行的 proof/install/models/quota 响应全 `200`，该 GET-only 切片没有虚构 chat completion。录屏 `135.281667s / 2784x1808 / 60fps` 可读，收台后证据保留。

本轮还修正 `models_keys_panel.dart` 中落后的“三行”注释为“六行”，并由抽取清册生成器同步 `COVERAGE.md` 的 EP-224 六槽描述。EP-224 真实产品证据已完成，但按 EP-220/EP-221 序列门仍不调用 `judge.py`、不写 formal ledger、不改变 `COVERAGE` 五格 verdict；正式账本 `1790`、清册 `848/351/0`、alarms clean、批次三十四 `25/50` 均保持不变。完整证据为 `sessions/20260813-011852/evidence/EP-224-scenarios-real.md`。

#### 最新补充：EP-225 关系图真实五通道路径与 stop-and-fix（2026-08-13 01:03）

静态审计确认实体总览消费 `/api/v1/relgraph`，全页探索支持节点选中、右岛关系分组、关联节点飞行、provenance 开关、Fit/zoom、图例过滤和详情入口；后端 `/relations`、`/relations/neighborhood`、`/relgraph` 的响应结构与黑盒覆盖一致。

首轮真实观察 session `20260813-004244` 发现两个产品/台架问题：涟漪透明度连同标签一起施加，稀疏图的远端实体名被压到不可舒服阅读；图例隐藏节点时残边仍留在画布。修复已停在原地完成：透明度现在只包节点点与边，标签保留既有 ink 层级；`CustomPainter` 将隐藏 kind 与边集合纳入重绘签名，隐藏端点时边同步过滤，并新增 15 项关系图 widget 回归（包括点/边计数和标签可读性）。中间热重载又暴露旧 painter 实例字段未初始化的 Flutter 异常；该失败日志与录像保留，不计绿，字段已改为 nullable 并用冷重启复验。

全新数据目录冷启动的有效 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-005927`，录屏 `115.818333s / 2784x1808` 可读。Computer Use 真实完成 Entities → Overview → relationship graph → 选中 `greet` → 点击 `Skill: deploy-helper` 关系 pill → provenance → Fit to view → 返回总览 → 打开 `greet` 详情；隐藏 Document 后 AX 树与画面均只剩 Skill/Function 且无残边，恢复后完整图返回。REST 实证：relations 2 条、skill 过滤 1 条、function neighborhood 1 条、relgraph 4 节点/2 边；五通道 rig-check 前后通过，frontend 无 Flutter/Dart/RenderFlex/Unhandled 红线，backend 无 WARN/ERROR/panic/FATAL，llmtap 6 个响应全 200，三路 SSE 均连接。正式证据为 `sessions/20260813-005927/evidence/EP-225-relations-real.md`；上一轮失败证据为 `sessions/20260813-004244`，两者边界已明确。

该路径尚未调用 `judge.py`，不写 formal ledger/COVERAGE，不推进批次；正式账本仍 `1790`，清册 `848/351/0`，alarms clean，批次三十四仍 `25/50`。原因是 EP-220/EP-221 序列门仍未收口；EP-225 作为真实产品证据已完成，下一步继续按序处理前线，不把未入账误写成五级绿格。

#### 最新补充：EP-224 场景枚举六槽门禁补强（2026-08-13 00:41）

静态审计发现 `GET /api/v1/scenarios` 原黑盒门禁只断言 `dialogue/utility/agent` 三项，而 domain/handler 当前真实返回六项；
已将测试收紧为恰好六项及 canonical 顺序 `dialogue, utility, agent, image, speech, video`，并修正 handler 注释与 API 文档。
`gofmt`、`git diff --check`、后端 handler/domain 单测及真实黑盒 `TestPlatform_ModelConfig` 通过。此为契约门禁补强，尚未进行
真实 App 五通道验证，未调用 `judge.py`，formal ledger `1790`、`COVERAGE 848/351/0`、alarms clean、批次三十四 `25/50` 不变。

#### 最新补充：EP-223 last-good 组件守卫与语音 fail-closed 回归（2026-08-13 00:37）

EP-223 的能力目录三态实现已再收紧：`ModelPickerPanel` 自身只在 `caps` 为空时渲染 loading/error；已有目录即使收到
刷新标记仍保持 key/model 可操作，last-good 保护不依赖某一个父级调用方。语音输入 provider 也用 pending/error 状态锁住
fail-closed：没有成功读到匹配的受管 `anselm-auto` 能力行时，录音入口不可用。新增 4 条相关 widget/provider 回归，串行
完整相关串行套件 `83/83`、`flutter analyze`、Dart format、`git diff --check` 通过。该静态补强仍按序等待 EP-220/EP-221，未调用
`judge.py`，不改 formal ledger `1790`、`COVERAGE 848/351/0`、alarms 或批次三十四 `25/50`。

#### 最新补充：EP-223 模型能力目录三态修复与真实台架（2026-08-13 00:30）

静态审计 `GET /api/v1/model-capabilities` 时发现设置、聊天头部和重试菜单都用 `.value ?? []` 吞掉了
能力目录的 loading/error 语义：网络或后端故障会被用户看成“没有模型/需要添加 key”，且没有恢复动作。前线冻结后，
共享消费契约改为三态：只有成功返回空数组才进入无模型引导；已有旧目录时继续展示 last-good；没有旧目录时设置面板
显示加载/失败的人话与单一刷新入口，聊天菜单保留 Auto、当前回合重试和模型能力刷新入口。语音输入仍按能力未知时
fail-closed，不把未证实的能力伪装成可用。

本次补丁同步了英文/中文 slang，并新增设置“加载不等于空”“失败可恢复”和聊天菜单失败态回归；串行相关回归
`73/73`、`flutter analyze`、Dart format 均通过。真实 App 第一轮 session
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-001238` 完成 onboarding、Models & keys、刷新模型目录、
Chat、真实受管网关聊天和 retry 菜单；第二轮有效 session
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260813-002350` 复用同一 workspace 验证能力/默认一致性及
`Anselm Auto · Gateway-managed routing and reasoning` 边界。两轮五通道均由 conductor 托管，错误端口 session
`20260813-002140` 被 `rig-check` 正确排除。真实证据分别为两个 session 的 `evidence/EP-223-*` 文件。

真实观察到 `/model-capabilities=200`、受管 `/models` 仅声明 `anselm-auto` 且能力胶囊包含文本、多模态、生图、语音、视频与
`image_to_video=true`；聊天 wire 200，messages durable seq `1..8` 单调，前端无应用级红线，SQLite workspace/default/message
真相一致。受管路由不提供 native knobs，未虚构外部选择器。该产品证据尚未写 formal ledger/COVERAGE：正式序列仍由 EP-220/EP-221
占住，账本 `1790`、清册 `848/351/0`、警报 clean，批次三十四保持 `25/50`；下一步按顺序补序入账，不提前改格。

#### 最新补充：EP-213 已授权对象删除闭环与确认原语代际守卫（2026-08-12 23:45）

用户明确授权的对象是 `EP-213 UI Delete Positive`。在独立 EP-213 夹具中只读确认活动对象
`aki_dd5b33196ff2df48` 后，真实 Flutter App 的确认卡 AX/frame 精确显示对象名和永久删除文案；点击最终 `Delete` 后，
backend 记录 `DELETE /api/v1/api-keys/aki_dd5b33196ff2df48=204`，目标行从 Model keys 消失，managed `Anselm Free`
与 scenario defaults 保留。SQLite tombstone 保留审计身份，但 `key_encrypted`、masked key、base URL、format、test
状态/错误/回执/时间全部清空。完整证据为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-234156/evidence/EP-213-ui-delete-authorized-closure.md`，
录屏为 `71.518333s / 2784x1808 / 60fps`。

第一次删除后健康检查因旧夹具持久化 `:8793` 而临时 tap 运行在 `:8806` 被台架正确拒绝；未把该轮算作产品证据。随后以
`RIG_LLMTAP_PORT=8793` 对齐持久化地址，完整 App、backend、三路 SSE、frontend console、llmtap 和录屏均由 conductor
托管，`rig-check` 通过并正常 `rig-down`。该对象已有 EP-213 正式五级绿账，本次是授权清理补充，不重复写 formal ledger、
不改 COVERAGE；当前 EP-220 `EP220 Delete Trial` 仍为唯一前线，formal ledger `1790`、批次三十四 `25/50` 不变。

静态 stop-and-fix 另发现 `AnTypeToConfirm` 在复用同一 Flutter `State` 且 `expected` 变化时会保留旧精确输入，可能让旧对象
解锁新对象。公共原语现于 `didUpdateWidget` 清空草稿并重新上锁，新增
`frontend/test/core/ui/an_type_to_confirm_test.dart`，并将 E6 同步进设计系统与 CODEX。EP-220 的最终对象未执行，EP-213
授权不外推。

#### 最新状态（2026-08-12 23:06 session）

当前唯一前线仍为 EP-220 `DELETE /api/v1/voices/{id}`。当前真实对象 `EP220 Delete Trial` 尚未执行最终不可逆删除；此前
用户 action-time 确认的是另一个对象 `EP-213 UI Delete Positive`，不能外推到当前对象。未取得当前对象的 action-time 确认前，
不得点击最终 `Delete permanently`，不得用 REST、SQLite 或终端绕过 UI。因此 EP-220 仍不写正式绿格，批次三十四保持 `25/50`。

最新正确 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-230602`，绑定数据目录
`/private/tmp/anselm-data-ep220-voice-delete-20260812-r2`。真实 Flutter App、真实受管 gateway、Computer Use、窗口录制、
backend/frontend journal、三路独立 SSE witness 和 llmtap 均由 conductor 托管，收台前 `rig-check` 通过且 `rig-down` 正常封口；
录屏 `225.245000s / 2784x1808 / 60fps` 可读。Computer Use 打开原 workspace 的精确删除确认框但未输入、未点最终删除；切到真实
创建的第二 workspace 后显示空库存与 `2 of 2 slots free`，旧确认和旧音色均不穿透；切回原 workspace 后目标行与
`1 of 2 slots free` 恢复，旧确认没有复活。只读 SQLite 仍只有原 workspace 的目标音色行，第二 workspace 为后续隔离复验保留。

本轮修复和机制锁定：库存 provider 以 active workspace 换代；切换时只清 `_confirming`，不把真实在途 `_deleting` 伪装成结束；
在途 DELETE 与随后 GET 都 pin 发起 workspace，旧操作只能在同一 workspace 代际更新 UI。对应 API client/voice card 回归、focused
analyze、Dart format、docs verify、`git diff --check` 均通过。五通道封口为 backend `311` 行、frontend `18` 行、SSE `16` 行、
llmtap `13` 行：无应用级后端/前端红线，两个 workspace 各自接通 `messages/entities/notifications`，真实 proof challenge/quota
为 `200`，没有 voice-delete 请求。完整证据为
`sessions/20260812-230602/evidence/EP-220-voice-workspace-confirmation-isolation-fixed.md`。

最新边界 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-232215` 已正常收台，录屏
`265.713333s` 可读。Computer Use 在真实确认框输入近似名称 `EP220 Delete Tria`，删除没有放行，随后点击 `Cancel`；
危险区收起，`EP220 Delete Trial` 与 `1 of 2 slots free` 保持不变。backend `299` 行只有库存 `GET=200`、没有 voice
DELETE；frontend `18` 行无应用级红线；SSE `8` 行完成两个 workspace 三流接线；llmtap `7` 行无删除 wire。证据为
`sessions/20260812-232215/evidence/EP-220-voice-delete-boundary-cancelled.md`。这只证明错误名称拒绝和取消边界，不能填充
EP-220 五级账本；当前对象最终删除仍等待明确 action-time 确认。

以下 EP-220 过程段落保留为本轮之前的 stop-and-fix 历史，不覆盖上述最新状态：

当前唯一前线仍是 EP-220 `DELETE /api/v1/voices/{id}`。删除路径的后端、API Serve、前端 inline danger zone、精确名称确认、取消、失败保留和回归测试已经完成静态审计；真实受管 enrollment 也已成功。但当前真实对象 `EP220 Delete Trial` 仍被保留，最终不可逆删除没有执行：此前用户在 action-time 明确确认的是 EP-213 `UI Delete Positive`，该对象已按授权删除；这条确认不自动改写当前 EP-220 的对象身份。未取得当前对象的 action-time 确认前，不得点击最终 `Delete permanently`，不得用 REST/SQLite/终端绕过 UI。EP-220 因而不能写入任何正式绿格，批次计数保持 `25/50`。

本轮又把验收台架的作用域门收紧为 fail-closed：`rig-up.sh`、`rig-check.sh`、`rig-down.sh` 与
`testend/rig/judge.py`、`alarms.py`、`anchors.py` 都必须在进程启动前取得显式的绝对 `RIG_HOME`，缺失、相对路径
和 `~` 路径都会拒绝运行，不能静默写入代理的个人默认账本；`--help` 仍保持只读可用。该门已由
`test_scope.py` 的 16 项入口作用域回归与全套 23 项 rig 单测覆盖，并以正式
`RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 复跑通过；这只修正仪器归属，不改变产品数据、当前音色对象、
正式裁决、警报阈值、法典或锚点。

EP-220 前置真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-175045` 已由完整五通道台架托管并正常收台，录屏 `431.853333s / 2784x1808` 可读。Computer Use 已观察到 Delete 的 hover 可发现性、精确名称确认、Cancel 不变和错名输入不放行；backend 没有 voice DELETE，REST/SQLite 仍保留同一行，llmtap 没有 voice-delete 请求。非破坏性证据为该 session 的 `evidence/EP-220-voice-delete-non-destructive.md`，状态明确为 partial，不构成正式绿账。

该前置 session 的逐帧复核又发现一条真实 craft 缺陷：行级危险区沿用了 `AnInput` 的 `inputMin=180` fallback，长对象名的确认提示被截成 `Type “EP220 Delete T…`，用户无法完整核对要输入的对象。前线冻结后让公共 `AnTypeToConfirm` 的确认字段使用 `block:true` 填满危险卡可用宽度，补 `voices_card_test.dart` 的长名几何回归和设置规范；修复后二次 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-193159` 由最新源码重新启动，Computer Use 逐帧确认完整提示 `Type “EP220 Delete Trial” to confirm`、费用/库存说明、按钮层级和卡片边界均稳定，无截断或 reflow。随后填入精确名称再点击 `Cancel`，危险区安全收起、对象与 `1 of 2 slots free` 库存均保留；`testend/cmd/measure contrast` 对 `#B3261E`/`#FFEBEE` 测得 `5.72:1`，满足 CODEX `D1`。旧 session 已正常封口为 `4038.698333s`，新 session 仍在等待当前对象的最终动作确认；该红修复及非破坏性复验均不构成任何正式绿格。

为锁住不可逆边界，Anselm 新增 `backend/internal/app/voice/voice_test.go`，覆盖上游优先、上游失败保留本地行、缺行不消费上游三条回归；并新增 `backend/internal/infra/llm/voiceclone_test.go`，用真实 HTTP 夹具锁住 sidecar 到网关的 `POST /voices:delete`、install header、`voiceId` body、无 body 的 `204` 成功和 `502 → VOICE_CLONE_FAILED.details.upstream` 失败契约；`backend/internal/transport/httpapi/handlers/voice_test.go` 再用真实 `http.ServeMux` 锁住 sidecar `DELETE /api/v1/voices/{id}` 的空 body `204`、上游失败 `503` envelope 和本地指针保留。Anselm 语音传输、voice/app/store/handler 定向测试和隔壁 `Anselm-API-Serve` 的 voice app/store/handler/router 定向测试均通过；这只是静态/传输层补强，不替代当前对象的真实删除闭环。完成当前对象的 action-time 授权后，才继续真实 `upstream 204 → local 204 → UI/inventory settled` 闭环；EP-221 仍按顺序后置，不提前写账。

API Serve 的分布式删除收敛也已完成并部署：`Anselm-API-Serve` commit `2879a1d9b010104ffab073bf1b48c0fbfd59c5e3` 已推送到 `main`；仅当 `voice-enrollment/delete_voice` 返回 HTTP 400 且 provider code 精确属于 `InvalidParameter.ResourceNotExist` 或 `BadRequest.VoiceNotFound` 时，网关把“上游已不存在”转换为幂等成功，普通 400/404/5xx 仍保留本地行并继续报错。API Serve `make verify`、CI `31590465992`、production deploy `31590711567` 均成功，生产 `/v1/install/challenge` 返回 `200`。这解决了“上游已删、本地重试无法收敛”的重试缺陷，但不构成 EP-220 当前对象的真实 UI 删除证据，EP-220 仍为 `·····`，批次仍为 `25/50`。

本轮跨仓非破坏性复核进一步确认这条幂等语义确实闭合：桌面端只负责本地 `DELETE /api/v1/voices/{id}` 与网关适配，不直接猜 provider 缺失码；API Serve 在网关边界将两个精确缺失码收敛为成功，之后才删除网关自己的 install 行。普通 `400`、`404`、`5xx` 仍保持本地指针并报错，因此不存在“桌面认为失败、网关已删”后无法重试的语义分叉。Anselm backend voice/app、LLM、store、handler 定向测试，API Serve voice app/upstream/store/handler/router 定向测试以及 `voices_card_test.dart` `10/10` 均通过。该审计不触发当前对象删除，也不提前写正式五格；Computer Use 全量 AX 仍确认 `EP220 Delete Trial` 在列表、危险区停在最终按钮前，正式台架保持五通道在线、`alarms clean (1790)`、`gen_coverage 848/351/0`、anchors `10/10`，批次三十四仍为 `25/50`。

随后在常驻 Settings 海洋上做 workspace 代际审计：`VoicesController` 原先只依赖动态读取 workspace id 的 repository，切换 workspace 时 provider 本身不失效，旧音色行会在新 `GET /voices` 未落定期间穿透。该问题由回归探针真实击中；stop-and-fix 让库存 provider 显式 `watch(activeWorkspaceProvider)`，切换立即进入新代际 loading，旧行不再可见，读取完成后才展示新 workspace 的行。新增两个 workspace、延迟第二次读取和“旧行消失→新行出现”三态回归；`voices_card_test.dart` 由 `10/10` 增至 `11/11`，focused `flutter analyze` 无问题。设置契约同步要求 active workspace 是库存代际边界；这次尚未触碰 EP-220 删除对象，也不写正式五级裁决。

随后用包含该修复的新 binary 做真实 App 非破坏性复验：Computer Use 在原 workspace 创建 `EP220 Workspace Switch`，真实切换后打开 Models & keys，画面显示 `No cloned voices yet`、`2 of 2 slots free`，旧 workspace 的 `EP220 Delete Trial` 没有穿透；切回原 workspace 后，`EP220 Delete Trial` 与 `1 of 2 slots free` 恢复。session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-222936` 的五通道均由 conductor 归属，backend `269` 行、SSE 两个 workspace 三流均连接、frontend 无应用级红线、LLM bootstrap/quota 全部 `200`；只读 SQLite 对证音色行仍仅属于 `ws_4389dec386259764`。中间 pending frame 由两 workspace delayed-read widget regression 覆盖，真实 session 不伪造网络延迟。证据为 `.../evidence/EP-220-voice-workspace-generation-fixed.md`；这仍是 stop-and-fix 前置证据，不写正式五级裁决，EP-220 当前对象仍等待 action-time 确认，批次保持 `25/50`。

该回归又延伸到破坏性 UI 意图：常驻 Settings 海洋在“打开音色确认框 → 切 workspace → 切回”后会复活旧确认框，且旧 workspace 的异步删除完成可能继续触碰当前 UI。先用红色 widget probe 击中“切回仍有 `AnTypeToConfirm`”，再在 `VoicesCard` 增加 workspace 监听与操作代际：切换时只清 `_confirming`，不把真实在途删除伪装成已结束；操作保持单飞直到原请求结算，旧操作的 DELETE 与随后 `GET /voices` 都固定发起时 workspace header，完成后只在仍属当前代际时更新状态/通知，不能在新 workspace 发通知或回写库存；补充“确认意图清除”和“在途删除不刷新新 workspace”回归，待新 binary 逐帧复验。该修复不触碰 `EP220 Delete Trial`，不写正式绿格，批次仍为 `25/50`。

EP-221 `GET /api/v1/read-aloud/availability` 已完成修复后的真实台架验证，但按顺序暂不写正式五格。首轮真实路径发现冷启动 `WorkspaceBootstrap` 在免费档开通前预取到 `available=false`，provider keep-alive 后把旧 false 留到整场会话，导致真实语音路由已播种而助手动作行仍没有 `Read aloud`。stop-and-fix 在 `_prepareManagedDefault()` 的 `finally` 中失效 `readAloudAvailableProvider`，并加入“开通前 false → 开通 → 至少再次探测且最终 true”的 Flutter 回归。

EP-221 绿观察 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-173436`，全新空数据目录由 Computer Use 真实创建 workspace、真实受管网关开通并完成一条聊天。backend 时序证明第一次 availability 在 provision 前、第二次在 provision 后；最终 assistant action row 逐帧和 AX 均出现 `Read aloud`。录屏 `325.773333s` 可读，三路 SSE 均连接且 messages durable `1..8`、notifications `1..2` 单调，backend/frontend 无应用红线，llmtap 的 managed bootstrap 与 chat 响应全为 `200`。正式证据为该 session 的 `evidence/EP-221-read-aloud-availability-fixed.md`，但 EP-220 尚未按序收口，故 EP-221 的 COVERAGE 仍保持 `·····`，不伪造 formal ledger judgments。

EP-221 的代码/测试/契约同步已完成：`workspace_bootstrap.dart`、`workspace_bootstrap_test.dart`、`docs/references/frontend/features/chat.md`；定向 Flutter 测试 `3/3`、定向 `flutter analyze`、`go test ./internal/infra/llm -count=1`、`make -C docs verify` 和 `git diff --check` 均通过。当前没有统一长门禁、没有提交；完成 EP-220 后才按序为 EP-220、EP-221 分别补五级裁决，并继续把批次推进到 `50/50`。

本轮 EP-220 非破坏性定向复核继续通过：Anselm voice/app/LLM/handler race tests、前端 `voices_card_test.dart` `9/9`、API Serve voice/upstream/handler/router race tests 均通过；最新 session `193159` 的五通道 `rig-check`、`gen_coverage.py --check`=`848/351/0`、`alarms.py check`=`clean (1790)`、docs verify 与 `git diff --check` 均通过。backend 只见正常 workspace refresh，frontend 只有已知 IMK host 噪声，llmtap 没有 voice/delete 记录。这些是回归/健康证据，不构成正式绿格；当前对象最终删除仍待 action-time 确认，批次继续为 `25/50`。

随后对 EP-220 删除后的失败恢复语义做了 stop-and-fix：发现 DELETE 已成功而紧随的 `GET /voices` 重读失败时，旧实现会继续展示旧音色行并使用“上游登记保留、可重试”文案，下一次重试实际上可能撞上已不存在的上游对象。现在 `VoicesController` 以 `VoiceDeleteCommittedRefreshException` 进入专用错误态，隐藏旧行、明确删除已提交/库存待刷新，只提供 Retry；重读成功后再恢复服务端权威库存算术。新增 fixture 钩子和 `voices_card_test.dart` 回归覆盖失败后 Retry 收敛，定向测试 `10/10`，focused analyze 与 slang 通过。该修复尚未触发真实 EP-220 删除，正式五格仍为空，批次保持 `25/50`。

随后静态审计下一原子 EP-222 `POST /api/v1/read-aloud:read`，发现陈旧 `speech_cache` 行会占住唯一 `cache_key`：附件被独立清理后，朗读虽能返回新音频，但缓存无法回写，用户以后每次朗读都会重新合成并付出上游成本。stop-and-fix 已增加幂等 `SpeechCacheRepository.Delete`；`readaloud.lookup` 只在附件明确 `ATTACHMENT_NOT_FOUND` 时先清除陈旧映射，普通存储错误原样保留映射。新增 app/store 回归覆盖陈旧映射修复、workspace 隔离、重复删除幂等和普通存储错误保留；普通与 `-race` 聚焦 Go 测试均通过，数据库/附件域/Chat 契约已同步。EP-222 仍未写正式五格，EP-220 仍按顺序停在当前对象最终动作前，批次保持 `25/50`。

EP-222 的新 binary 真实五通道证据已经封口。正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-210502` 由 conductor 托管真实 Flutter App、真实受管 gateway、Computer Use、窗口录制、backend/frontend journal、三路独立 SSE witness 和 llmtap；`rig-check` 通过并正常收台，录屏 `704.231667s / 2784x1808 / 60fps` 可读。完整证据为 `sessions/20260812-210502/evidence/EP-222-read-aloud-preparation-cache-green.md`。

真实回答落定后点击 `Read aloud`，动作槽立即显示 `Preparing read-aloud…` 与统一 spinner，固定原尺寸/中心、不推挤邻项；等待中入口禁用，完成后为 `Stop`，播放结束恢复 `Read aloud`。backend 只有一次 UI read（`200 / 2833ms`），llmtap 只有一次 speech 请求（`200 / 249644 bytes`），SSE 三流接通、durable seq 单调无 gap，frontend 无应用级 Flutter/Dart/RenderFlex/Unhandled/overflow 红线。相同精确文本的 REST 重读返回同一附件、`cached:true`、`0ms`，SQLite 的 cache 映射与附件行一致；带句号的独立 probe 是不同 cache key，已排除在零成本结论之外。

`chat_transcript_test.dart 31/31`、focused analyze、Dart format、slang、read-aloud app/store 普通与 `-race` 测试均通过。证据已完整，但正式五级裁决仍必须等待 EP-220 序列门释放；COVERAGE 的 EP-222 五格不提前涂绿，EP-220 仍未执行当前对象最终删除，批次三十四保持 `25/50`，不运行统一长门禁、不提交。

以下为上一格已正式闭合的 EP-219 快照，保留作完整审计事实，不再作为当前前线。

EP-219 `GET /api/v1/voices` 已完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、窗口录屏、backend journal、三路独立 SSE witness、frontend console 和 llmtap 的五级验收。产品目的不是只列出音色行，而是让用户看懂**持久库存**：当前有哪些克隆音色、还剩多少永久槽位；空库存是已落定的状态，不能因为没有行就把 `remaining/capacity` 藏掉，也不能把库存说成会随时间恢复的日配额。

首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-153640` 发现一个产品缺陷：真实 `GET /api/v1/voices` 返回 `{items:[],capacity:2,remaining:2}`，但 Settings → Models & keys 的 Cloned voices 空态只显示“暂无音色”和登记说明，用户看不到 `2 of 2 slots free`，库存边界不可发现。stop-and-fix 让 settled-empty 与 populated state 共用同一份本地化库存算术，并同步更新设置页规范与 widget 回归；没有改变后端契约，也没有用客户端自行计算替代权威重读。

正式绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-154141` 从修复后二进制重新启动，复用真实 workspace `ws_75579fdcb9648a9a` 与受管 install。Computer Use 逐帧确认空态说明与 `2 of 2 slots free` 在同一张卡内稳定呈现，间距、层级、边界和下方 Model keys 没有溢出或跳变；点击 Refresh 后仍从权威读取收敛到同一结果。REST 正向为 `200 {capacity:2,items:[],remaining:2}`；缺 workspace 为 `401 UNAUTH_NO_WORKSPACE`，错误方法为 `405 METHOD_NOT_ALLOWED`，错误没有被伪装成空库存；SQLite 对证 workspace 存在且 voices 表为空。

五通道已封口：正式 `screen.mov` 为 `137.630000s / 2784x1808` 且 `ffprobe` 可读；`backend.log` 无 panic/FATAL/application ERROR；`frontend.log` 无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception 应用红线；ssetap 独立接通 `notifications`、`entities`、`messages` 三流；llmtap 的 challenge/install/models/quota 观察到的 6 个响应全为 `200`，没有请求绕过 tap。完整绿证据为 `sessions/20260812-154141/evidence/EP-219-voices-green.md`，首轮红证据保留在 `sessions/20260812-153640`，独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-219-voices-ledger-reaudit.md`。

正式按 `G1 / F2 / A4 / C4 / G2` 写入 `COVERAGE EP-219=✓✓✓✓✓`；anchors=`10/10`，formal ledger `1785→1790 judgments`，`gen_coverage.py --check`=`848/351/0`，写账触发的 `gap-too-fast` 与 `discovery-collapse` 已基于首轮缺陷、修复后二次 session、最终录像、五通道 journal、REST/SQLite 和定向回归独立复审并 ack，最终 `alarms.py check`=`clean (1790)`。修复回归为 Flutter 设置相关 28 项、后端 voice/handler/store/generate 定向测试、`make -C docs verify` 和 `git diff --check`；未到批次门槛不运行统一长门禁、不提交。批次三十四由 `20→25/50`，下一原子前线为 EP-220 `DELETE /api/v1/voices/{id}`。

EP-218 `GET /api/v1/speech/asr` 已完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、窗口录屏、backend journal、三路独立 SSE witness、frontend console 和 llmtap 的五级验收。产品目的不是让 WebSocket 握手成功，而是让用户从空 composer 发现麦克风，录音时看到实时转写，停止后得到仍可编辑的最终文字，并由用户明确决定是否发送；连接失败、权限不足、超时和重试不能留下死录音态或偷偷发送内容。

首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-144612` 暴露了验收代理自身的 duplex 缺陷：上游 ASR 已返回 `101 Switching Protocols`，但透明代理把 101 的双向 body 包成只读 response witness，`ReverseProxy` 因 `non-writable body` 拒绝升级。该 session 保留为仪器红证，不计产品绿。stop-and-fix 让 `testend/harness/proxycore` 对 101 保留可写双向 body，仅对普通有限 HTTP response 做 body witness，并增加 protocol-upgrade regression。

修复后又由真实部署 wire 发现跨仓协议缺口：网关发送累积实时事件 `conversation.item.input_audio_transcription.text`（`stash` 为累计快照），而前端原来只识别 `.delta`，所以真实 partial 不可见。前端现在兼容 `.text` 与 `.delta`，`.completed` 仍落最终 transcript；同步 `api.md` 和 Flutter regression。该缺陷在真实产品路径中修复，不以本地 fixture 的 `.delta` 测试冒充完成。

正式绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-150935` 使用全新数据目录和新的修复后二进制。真实受管 bootstrap 的 challenge/install/models 全为 `200`，三次 `/v1/speech/asr` 均为 `101`，没有请求绕过 llmtap。Computer Use 在真实窗口中观察到录音条从 `Recording 00:07` 到 `Recording 00:38` 稳定存在，红点、波形、停止按钮和中文实时 partial 同时可见；点击停止后收口为普通 composer，最终文字仍在可编辑文本框内并出现发送箭头，没有自动发送、死 spinner 或视口跳变。一次过短声学样本没有产生可靠文字，因同步/样本长度不足不计入绿判定，也没有造成产品状态卡死；一次后续发送是操作员明确点击造成，不是停止录音副作用。

五通道已封口：正式 `screen.mov` 为 `783.353333s` 且 `ffprobe` 可读；`backend.log` 无 panic/FATAL/应用级 ERROR；`frontend.log` 无 Flutter/Dart/RenderFlex/overflow/Unhandled/Exception 应用红线，仅已知 macOS IMK host 噪声；ssetap 独立接通 `notifications`、`entities`、`messages` 三流并正常收台；llmtap 记录真实 managed bootstrap、ASR `101` 和 Chat wire。完整绿证据为 `sessions/20260812-150935/evidence/EP-218-speech-input-green.md`，独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-218-speech-input-ledger-reaudit.md`。

正式按 `G1 / F2 / A5 / C4 / G2` 写入 `COVERAGE EP-218=✓✓✓✓✓`；anchors=`10/10`，formal ledger `1780→1785 judgments`，`gen_coverage.py --check`=`848/350/0`，写账触发的 `gap-too-fast` 与 `discovery-collapse` 已由独立复审按原阈值串行 ack，最终 `alarms.py check`=`clean (1785)`。修复回归 `go test ./harness/proxycore ./cmd/llmtap`、`go test ./harness/...` 和 speech provider Flutter tests 均通过，`git diff --check` 通过。批次三十四由 `15→20/50`，未到批次门槛不运行统一长门禁、不提交；下一原子前线为 EP-219 `GET /api/v1/voices`。

EP-217 `POST /api/v1/freetier:provision` 已完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、窗口录屏、backend journal、三路独立 SSE witness、frontend console 和 llmtap 的五级验收。产品目的不是让一个按钮“返回 200”，而是让用户在受管免费档异常时有一条安全、可发现、幂等的恢复路径：不丢对话和设置，不制造第二个 managed identity，网关恢复后回到真实配额面。

EP-217 保留两条互补的真实路径。幂等 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-141212` 对同一 workspace 连续 POST 两次，均为 `200 {"provisioned":true}`；SQLite 只有一条非删除 managed 行，llmtap 只有一次 `/v1/install`，后续只做 models 健康探测。修复后正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-142457` 在真实 App 的 `Settings → Models & keys` 中先观察到健康配额面，再故意停止 session-owned llmtap；点击 Refresh 暴露真实 `502 LLM_PROVIDER_ERROR`，旧绿色 quota meter 被清掉，画面给出人话解释和 `Repair free tier`。点击 Repair 后出现 `Provisioning…`，恢复代理后重新得到 `0 / 1B · resets 2026-09-01 00:00`，managed 行、六个 defaults 和设置均保持不变。

首轮坏天气暴露并冻结了两个产品缺陷：quota 传输/解码失败被错误映射为通用 `500`，前端还保留旧的绿色配额。stop-and-fix 将非取消/超时的 quota 上游错误映射到既有 `LLM_PROVIDER_ERROR`/`502` 契约，前端把失败写成 `AsyncError` 并显示 Repair 面；补充了 Go transport、malformed URL、freetier/response 和 Flutter stale-meter/Repair 回归测试，随后用新的真实 session 重跑到 `502 → Repair → provision 200 → quota 200`。

五通道复核已封口：修复后 backend 无应用级 WARN/ERROR/panic/FATAL，frontend 无 Flutter/Dart/RenderFlex/overflow/Unhandled 红线（仅已知 macOS IMK host 噪声），ssetap 接通 `notifications`、`entities`、`messages` 三流，llmtap 记录真实 proof/quota/recovery wire 且无请求绕过 tap；封口 `screen.mov` 可读，为 `250.746667s`。Computer Use 从最终录像抽取并复看 `EP-217-repair-error.jpg` 与 `EP-217-repair-recovered.jpg`，错误面文字和 CTA 可读，恢复面稳定且不显示伪造零值。正式证据为上述两个 session 内的 `EP-217-provision-idempotent.md`、`EP-217-provision-repair-green.md`，独立账本复核为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-217-provision-ledger-reaudit.md`。

正式按 `G1 / F1 / A4 / C4 / G2` 写入 `COVERAGE EP-217=✓✓✓✓✓`；锚点因超过 4 小时被 gate 正确拒绝后，使用同一 `anchor-answers-final.json` 重新校准，未改锚点集、答案、阈值、算法、法典或 gate。formal ledger `1770→1780 judgments`（其中第一轮未导出 `RIG_HOME` 的五条记录只保留在默认个人审计账本，不属于 formal authority），`gen_coverage.py --check`=`848/349/0`，最终 `alarms.py check`=`clean (1780)`。该段现为 EP-218 之前的历史状态；当前前线与批次数字以上方 EP-218 整体重述为准。

EP-216 `GET /api/v1/freetier/quota` 已完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、窗口录屏、backend journal、三路独立 SSE witness、frontend console 和 llmtap 的五级验收。产品目的不是只得到一个 quota JSON，而是让用户在 `Settings → Models & keys → Free tier` 中看见真实受管网关的本月配额；尚无受管行时必须诚实显示启用入口和可重试的失败状态，不能伪造 `0`。

主正式 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-135155`，workspace=`ws_16f91208451a5a15`，全新数据目录完成 onboarding 后经真实 `https://api.anselm.website` 完成 `challenge → install → models → quota`；录屏封口为 `181.195000s`。Computer Use 逐帧确认已开通面显示 `Anselm Free · Auto multimodal`、配额条、`0 / 1B · resets 2026-09-01 00:00`、Refresh、锁定 managed 行和六个 `anselm-auto · Anselm Free` 场景默认；手动 Refresh 再次走真实 `/v1/quota`，画面仍与权威值一致，无裁切、死 loading、重复行或布局跳变。

负向补充 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-135604`，网关指向关闭回环端口以构造真实无受管行面，不触碰生产 install 或配额。REST 返回 `404 FREETIER_NOT_PROVISIONED`，SQLite 无 `api_keys` 行；Settings 显示匿名指纹说明和 `Enable free tier`，点击后进入等待态，失败后回到可重试 CTA 并显示 `Provisioning incomplete (offline or gateway unreachable) — retry later`，没有伪造配额条。该 session 只证明 404/启用负向面，L2 正式真相仍绑定主真实网关 session。

五通道已封口：主 session 的 backend 无应用 WARN/ERROR/panic/FATAL，frontend 无 Flutter/Dart/RenderFlex/overflow/Unhandled 红线，仅已知 macOS IMK host 噪声；ssetap 独立连接 `notifications`、`entities`、`messages` 三流；llmtap 记录真实 quota `200`。负向 session 的三条 `free-tier provision skipped: install failed` WARN 是预期的离线 best-effort 分类，已在负向证据中说明，不是未解释故障。主 REST 返回 `{limit:1000000000,used:0,remaining:1000000000,resetAt:"2026-09-01T00:00:00+08:00",available:true}`，SQLite 对证 managed 行、`test_status=ok`、`last_tested_at` 和非空加密列。

正式按 `G1 / F1 / A4 / C4 / G2` 写入 `COVERAGE EP-216=✓✓✓✓✓`；formal ledger `1770→1775 judgments`，anchors=`10/10`，`gen_coverage.py --check`=`848/348/0`。五级写账触发的 `gap-too-fast` 与 `discovery-collapse` 已由独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-216-quota-ledger-reaudit.md` 按原阈值串行 ack，未修改阈值、算法、法典、锚点或 gate。该历史段当时把批次三十四由 `5→10/50`；当前前线已由上方 EP-217 整体重述接管。

EP-215 `GET /api/v1/providers` 已完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、窗口录屏、backend journal、三路独立 SSE witness、frontend console 和 llmtap 的五级验收。产品目的不是只得到一个 provider JSON，而是让用户在 `Settings → Models & keys → Add key` 中能够浏览全量 provider、按 display name/provider id 搜索、看懂模型数量与 `Untested` 状态，并把 managed Anselm 与手动 BYOK 新增路径清楚分开。

正式 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260812-131710`，workspace=`ws_c8056a935eaaed3b`；全新数据目录先完成 onboarding，再真实进入 Models & keys。Computer Use 逐帧验证了双列 provider market、`together` 精确单卡搜索、无匹配 `No provider matches that` 空状态、Azure required Base URL form，以及关闭 Add key 后回到稳定的 managed settings。搜索 `anselm` 不出现在手动 market 是产品边界而非缺失：managed `Anselm Free` 在 Models & keys 的受管区域单独展示；本轮没有输入或传输任何用户 credential。

五通道已封口：`rig-check`/`rig-down` 通过且 owned processes/listeners 归零；`screen.mov` 可读，为 `1292.316667s / 2784x1808 / 60fps`；backend 无 panic/FATAL/application WARN/ERROR；frontend 无 Flutter/Dart/RenderFlex/overflow/Unhandled 红线，仅已知 macOS IMK host 噪声；ssetap 独立连接 `notifications`、`entities`、`messages` 三流；llmtap 对真实 `https://api.anselm.website` 的 challenge/install/models/quota 均为 `200`，本项是 settings/catalog 只读路径，没有伪造 chat completion。

REST 与 production-mode 对证：dev formal session 的 no-workspace/workspace `GET /providers` 均为 `200`、191 条、按 name 排序、无重复，`anselm.managed=true`；`mock` 只在 `ANSELM_DEV` fixture 中出现。独立未设置 `ANSELM_DEV` 的 production-mode server 返回 `200`、180 条、排序稳定、无重复、`anselm.managed=true` 且 `mock=[]`。完整证据为 `sessions/20260812-131710/evidence/EP-215-providers-green.md`，production 原始响应和摘要同目录，账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-215-providers-ledger-reaudit.md`。

正式按 `G1 / F1 / A4 / C4 / G2` 写入 `COVERAGE EP-215=✓✓✓✓✓`；formal ledger `1765→1770 judgments`，anchors=`10/10`，`gen_coverage.py --check`=`848/347/0`，最终 `alarms.py check`=`clean (1770)`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已按独立复审串行 ack，未修改阈值、算法、法典、锚点或 gate。本格没有产品代码 stop-and-fix；Computer Use 的文本选择异常确认是仪器输入限制，不计产品红线。

**前置状态（已由上方 EP-216 整体重述接管）：** 清册 EP-186 至 EP-215 均已完成；EP-216 已完成并推进批次三十四至 `10/50`。该旧段保留 EP-215 的完整证据事实，不再作为当前前线；本批尚未达到 50 格，统一长门禁和提交仍按协议后置。

EP-213 `DELETE /api/v1/api-keys/{id}` 已完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、窗口录屏、backend journal、三路独立 SSE witness、frontend console 和 llmtap 的五级验收。用户对精确对象 `EP-213 UI Delete Positive` 给出授权后，最终点击前重新读取确认框，AX/frame 同时核对对象名、永久删除文案 `This deletes “EP-213 UI Delete Positive” permanently.` 与 `Cancel/Delete` 按钮；真实点击后 UI 稳定只剩受管 `Anselm Free`。历史 `daily-rule` fixture 没有被借用。

正式 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-154423`，workspace=`ws_3c0e81066bb031d7`，key=`aki_3d1ee884e96c91d5`。backend 记录目标 DELETE=`204`，立即 list 只剩 managed，重复 DELETE=`404 API_KEY_NOT_FOUND`；SQLite unscoped tombstone 保留 id/workspace/display name/provider/`deleted_at`，但 `key_encrypted`、masked value、Base URL、API 方言、probe 状态/错误/回执/时间戳全部为空。UI final settled frame、REST、SQLite 和 backend journal 共同证明“删掉的是当前对象”而不是只删 fixture。

五通道已封口：`rig-check`/`rig-down` 通过，owned processes/listeners 收台，`screen.mov` 可读；backend 无 panic/FATAL/application WARN/ERROR；frontend 无 Flutter/Dart/RenderFlex/overflow/Unhandled 红线，仅已知 macOS IMK host 噪声；三路 SSE 均连接，API-key 设置按 REST reread 契约不产生 lifecycle durable frame，未虚构丢帧；llmtap 记录真实 managed bootstrap，fixture provider 为 mock，未虚构 completion。视觉同分辨率测量确认确认态到最终列表收敛并随后稳定；因录像没有可信 click-frame 对齐，L3 保守用 `A4`，不冒充 `A1`。完整证据为 `EP-213-apikey-delete-final-green.md`、`EP-213-visual-measurement.md` 与 `EP-213-delete-final-settled.jpeg`。

正式按 `G1 / F1 / A4 / C4 / G2` 写入 `COVERAGE EP-213=✓✓✓✓✓`；formal ledger `1760→1765 judgments`，anchors=`10/10`，`gen_coverage.py --check`=`848/346/0`，最终 `alarms.py check`=`clean (1765)`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已以独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-213-apikey-delete-ledger-reaudit.md` ack，未修改阈值、算法、法典、锚点或 gate。

收账时发现台架自身的并发丢写：五个并发 `judge.py` 进程均把裁决写入 journal，但清册曾丢掉 EP-213 L1。该台架红线已 stop-and-fix：`judge.py` 现在以 `RIG_HOME/judge.lock` 串行保护去重、清册更新和 journal 追加，并能在半步崩溃后按已有 journal 重放修复清册；`python3 -m unittest testend/rig/test_judge.py -v` 的幂等/并发回归通过，EP-213 L1 已由脚本 replay 恢复，未手工涂绿。操作规则已同步到 `testend/rig/README.md`。

**前置批次收口（已归档）：** 清册 EP-186 至 EP-214（含 EP-213）均已完成；批次三十一已在 EP-194 关闭并提交，批次三十二已在 EP-204 关闭并提交 `e83e0fc6`，批次三十三已由 EP-213 关闭为 `50/50`。EP-213 的红场、stop-and-fix、真实 UI 正负路径、REST/SQLite 矩阵、五通道 session、视觉测量、账本修复和独立警报复审均保留；统一长门禁、完整 testend、账本/清册/锚点/警报、本批 Go 定向回归和工作树边界审计均已通过，本批提交为 `4d304b3c`。当前状态已由上方 EP-218 整体重述接管，下一前线为 EP-219。

全量前端门禁曾因 `referenceSearch` 误命中 placeholder guard 冻结；已将该 API-key 引用标签加入判定层的明确 non-placeholder 集合，未改文案规则。修复后 `make -C frontend verify` 的 `gen + analyze + 4 groups`、`5328 tests` 全通过。

### 历史状态快照（2026-08-11，EP-214 收口前的 EP-213 前置状态）

**历史前线（已被上方整体重述取代）：** 清册 EP-186、EP-187、EP-188、EP-189、EP-190、EP-191、EP-192、EP-193、EP-194、EP-195、EP-196、EP-197、EP-198、EP-199、EP-200、EP-201、EP-202、EP-203、EP-204、EP-205、EP-206、EP-207、EP-208、EP-209、EP-210、EP-211、EP-212 与 EP-214 均已完成；当时 EP-213 仍未完成，不能因相邻 probe 证据代替删除确认。该段保留当时 EP-214 probe、EP-213 RenderFlex stop-and-fix、静态安全审计与未授权最终 Delete 的完整历史事实；恢复执行不再以此段的前线或账本数字为准。

EP-214 `POST /api/v1/api-keys/{id}:test` 验证的不是一个返回 `200` 的探针，而是用户在 `Settings → Models & keys` 点击 Test 后，能看见可理解的成功状态，且 probe 结果真实写入持久层而不泄漏 secret。真实 App 对 `EP-213 Dialogue Ref` 点击 Test，列表稳定回到绿色 `OK`；没有错误 banner、死 spinner、重复行或布局跳变。

真实五通道 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-142038`，同一 conductor 托管真实 Flutter App、Computer Use、真实受管 `https://api.anselm.website`、三路独立 ssetap、backend/frontend journals、llmtap 和封口录屏；录屏 `398.760000s / 2784x1808 / 60fps`，follow-up clean settled frame 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-142920/evidence/EP-214-clean-settled.png`。backend 记录精确 `POST ...:test=200` 与 `ok=true`，SQLite 对证 `test_status=ok`、`last_tested_at` 和 `updated_at` 同步推进；frontend 无应用级 Dart/Flutter/RenderFlex/Unhandled/Exception 红线。三路 SSE 均连接，但当前 API-key 设置契约是 REST reread、没有 API-key lifecycle durable frame；LLM tap 只记录真实 managed proof/quota bootstrap，fixture provider 为 mock，故不虚构 completion。

EP-214 正式按 `measure:apikey-test-purpose / F1 / A4 / C4 / G2` 写入 `COVERAGE EP-214=✓✓✓✓✓`；完整证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-142038/evidence/EP-214-key-test-green.md`，干净视觉证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-142920/evidence/EP-214-clean-frame.md`，独立警报复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-214-ledger-alarm-reaudit.md`。formal ledger `1755→1760 judgments`，`gen_coverage.py --check`=`848/345/0`，anchors=`10/10`，最终 `alarms.py check`=`clean (1760)`；批次三十三由 `40→45/50`，未到 50 格不跑统一长门禁、不提交。EP-213 删除正向/引用阻断/managed 不可删的静态与 REST 矩阵仍保留，但由于当前用户确认并非当前 UI 对象，真实 UI 最终 Delete 未点击，EP-213 继续作为下一原子前线。

EP-212 `PATCH /api/v1/api-keys/{id}` 验证的不是一个能返回 `200` 的修改接口，而是用户能否安全地维护 BYOK：改名、改可选 Base URL、轮换 secret、清空旧 Base URL，并能从探测状态理解结果；secret 留空时必须保留旧值，受管 Anselm 行必须明确锁定且不可修改。

首轮真实 App 红场 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-131319` 证明了一个真实产品缺陷：编辑表单把空 Base URL 映射成省略字段，后端因此保留旧 URL，用户点击保存却无法清除它。该场冻结、不计绿。stop-and-fix 将编辑路径改为显式发送 `baseUrl: ''`，保留新增路径的 null 省略语义，并补充设置仓库契约注释与 Flutter S-3 回归；`s2_models_keys_test.dart` 19 tests、相关 Go/testend/Flutter 定向测试均通过。

固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-132645` 由同一 conductor 托管真实 Flutter App、Computer Use、录屏、backend/frontend journals、三路独立 SSE witness、llmtap 和真实受管 `https://api.anselm.website`；录屏 `145.063333s / 2788x1812 / 60fps`，`rig-check` 通过，`rig-down` 后 owned processes/listeners 归零。Computer Use 在真实编辑表单中看到 populated Base URL，清空且未触碰 secret 字段，点击 `Save & test` 后回到列表；最终画面显示清空后的行、managed lock、绿色探测状态，无 stale URL、重复行、死 spinner、错误面或布局跳变。

五通道和数据真相闭合：backend 记录 PATCH→list→`:test`→list，坏 OpenAI endpoint 的 probe failure 返回 `200` 但 durable `testStatus=error`，不回滚 mutation；显式 `baseUrl:""` 在 SQLite 为 `base_url=''`，empty PATCH 不刷新 `updatedAt`，managed/cross-workspace/whitespace/unknown-field 分别得到 `API_KEY_IMMUTABLE`、`API_KEY_NOT_FOUND`、`API_KEY_VALUE_REQUIRED`、`INVALID_REQUEST`，加密列无 plaintext leak。SSE 三流为两个 workspace 全部连接且无 gap；API key 当前无登记生命周期帧，设置页按 REST reread 收敛；frontend 无 Dart/Flutter/RenderFlex/Unhandled 红线，仅已知 IMK host 噪声；LLM tap 观察到真实 managed proof/quota `200`，本 endpoint slice 没有 completion，未虚构。

正式按 `G1 / F1 / A4 / C4 / G2` 写入 `COVERAGE EP-212=✓✓✓✓✓`，证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-132645/evidence/EP-212-apikey-patch-green.md`，红证据为同 formal home 下 `sessions/20260811-131319/evidence/EP-212-apikey-patch-red-baseurl-clear.md`，独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-212-apikey-patch-ledger-reaudit.md`。写账后的 `gap-too-fast` 与 `discovery-collapse` 已按原阈值复审并 ack，`alarms.py check`=`clean (1755)`；未到 50 格不跑统一长门禁、不提交。

EP-211 `GET /api/v1/api-keys` 验证的不是一个能返回 `200` 的读取接口，而是用户在 `Settings → Models & keys` 能否看到当前 workspace 的真实 key 清单，且切换 workspace 后不会残留上一 workspace 的凭证。Alpha 真实画面同时显示 `Anselm Free` 与 `EP-210 Mock Key`，Beta 只显示 managed 行，再切回 Alpha 后 mock 行恢复；所有值均脱敏，状态点可读。

正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-130114` 的窗口录屏为 `267.125000s / 2784x1808`，由同一 conductor 托管真实 Flutter App、Computer Use、backend/frontend journals、三路独立 SSE witness、llmtap 和真实受管 `https://api.anselm.website`；`rig-check` 和 `rig-down` 均通过，owned processes/listeners 归零。backend 记录 Alpha/Beta activation 与列表读取、分页/过滤/空结果/坏 cursor/非法 limit/缺失 workspace 的正负矩阵，无应用 WARN/ERROR/panic/FATAL；frontend 无 Dart/Flutter/RenderFlex/Unhandled/runtime 红线；Alpha/Beta 各自六条 SSE 连接成功；managed proof/quota 为真实 `200`。当前事件登记没有 api-key 生命周期帧，REST 重读是设置页契约，不把无帧误判为丢事件；SQLite 对证 Alpha managed+mock、Beta managed、加密列和 masked projection。

本格后端激活/列表耗时为 `0–1ms`，但保存抽帧没有精确 click frame，因此不虚报 A1；L3 以 A4 证明没有超过一秒、无需进度态。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-130114/evidence/EP-211-apikey-list-green.md`，独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-211-apikey-list-ledger-reaudit.md`。正式按 `measure:apikey-list-purpose / F1 / A4 / C4 / G1` 写入 `COVERAGE EP-211=✓✓✓✓✓`；formal ledger `1745→1750 judgments`，`gen_coverage.py --check`=`848/343/0`，最终 `alarms.py check`=`clean (1750)`。五级写账触发的 `gap-too-fast`、`pass-burst` 与 `discovery-collapse` 已独立复审并 ack，未修改阈值/算法/法典/锚点/gate。本批由 `30→35/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-212 `PATCH /api/v1/api-keys/{id}`。

EP-210 `POST /api/v1/api-keys` 验证的不是一个能返回 `201` 的创建接口，而是新用户能否从真实 App 的 `Settings → Models & keys → Add key` 找到 provider、提交凭证、看到真实探测结果，并确认 managed 与 BYOK 分开、凭证只以脱敏投影出现且 workspace 不串线。Computer Use 搜索 `mock` 后只显示 `Mock (dev)`，保存并自动 probe 后列表出现 managed 与 mock 两行绿状态；非法 provider、空 key 各得到明确 400 且不增加数据库行，Beta 列表不含 Alpha 的 mock key。

正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-124305` 的窗口录屏为 `376.210000s / 2784x1808`，同一 conductor 托管 App、录屏、backend/frontend journals、三路独立 SSE witness、llmtap 和真实受管 `https://api.anselm.website`；`rig-check` 和 `rig-down` 均通过，owned processes/listeners 归零。backend 无应用 WARN/ERROR/panic/FATAL，frontend 只有已知 IMK/launcher 噪声；Alpha/Beta 各自六条 SSE 连接成功；managed challenge/install/models/quota 全为 `200`。API key 生命周期没有 `entities`/`notifications` 帧符合当前事件登记，设置页依 REST 重读收敛，未把无帧误判为丢事件。SQLite 对证了加密 key、masked projection 和 workspace 隔离。

本格的测量边界也被明确记录：backend `create 201 → probe 200 → final list 200` 的真实关键路径为 `95ms`，录像抽帧足以检查无死 spinner、重复行、stale form 和错误面，但没有精确 click frame，因此没有虚报 CODEX A1；L3 按 A4 判定为操作未超过一秒、不需要进度态。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-210-apikey-create-green.md`，测量注记为 `EP-210-apikey-create-measurement.md`，独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-210-apikey-create-ledger-reaudit.md`。正式按 `measure:apikey-create-purpose / F1 / A4 / C4 / G1` 写入 `COVERAGE EP-210=✓✓✓✓✓`；formal ledger `1740→1745 judgments`，anchors=`10/10`，`gen_coverage.py --check`=`848/342/0`，最终 `alarms.py check`=`clean (1745)`。本批由 `25→30/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-211 `GET /api/v1/api-keys`。

EP-209 `POST /api/v1/workspaces/{id}:activate` 验证的不是一个能返回 `200` 的 bookkeeping endpoint，而是用户切换工作区后，当前 subject、`lastUsedAt`、对话隔离和回切恢复是否共同成立。首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-120306` 在加载带朗读入口的 transcript 时记录了真实 `_ReadAloudSlot` build-phase Riverpod 红线，正式冻结、不计绿。修复将 workspace-bound media/read-aloud provider 的首次 dirty refresh 移出 widget build，并让 key mutation/free-tier provision 正确失效 availability；provider-settle guard、workspace hot-switch/bootstrap、settings key invalidation 和 chat transcript 回归均通过。

固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-122342` 使用全新数据目录、真实 Flutter App、Computer Use、真实受管 `https://api.anselm.website`、三路独立 SSE witness、backend/frontend journals、LLM tap 和连续窗口录屏。真实创建 Alpha 与 Beta，Beta→Alpha 后发送 `Reply with exactly ALPHA-CONTEXT-209-FIXED and nothing else.`，模型只返回 `ALPHA-CONTEXT-209-FIXED`；Alpha→Beta 的页面没有 Alpha recent/transcript，Beta→Alpha 再打开 Recents 后原对话正确恢复，没有重复 user bubble。backend journal 记录两 workspace activation `200` 与切换后的 `lastUsedAt`，SQLite、REST、SSE close 快照和 UI 一致。

五通道封口：录屏 `391.225000s / 2784x1808 / 60fps`，`rig-check` 在创建、切换、真实对话前后均通过，`rig-down` 后 owned processes 全部收台；backend 无应用 WARN/ERROR/panic/FATAL，frontend 只有已知 IMK host 噪声，无旧 Riverpod 红线；ssetap 为两个 workspace 各接通 messages/entities/notifications，Alpha messages durable `1..8`、notifications `1..2` 单调唯一，Beta 无 Alpha durable 帧；llmtap 的 managed challenge/install/models 与两次 chat completion 均为 `200`。封存抽帧为 `sessions/20260811-122342/evidence/frames/238-beta.png`、`312-alpha-stream.png`、`382-alpha-history.png`。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-209-workspace-activate-fixed-green.md`，独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-209-workspace-activate-ledger-reaudit.md`；按 `measure:workspace-activate-purpose / F2 / A1 / C4 / G1` 写入 `COVERAGE EP-209=✓✓✓✓✓`，本批由 `20→25/50`，未满 50 格不跑统一长门禁、不提交。

EP-208 `DELETE /api/v1/workspaces/{id}/default-search` 验证的不是一个能返回 `200` 的删除接口，而是用户是否能在 Models & keys 找到默认 search key、清空后看到诚实的 `Not set`、重复清空不制造假变化、保留仍可用的 search key，并在 Chat 使用 WebSearch 时得到可行动的未配置引导。静态审计先冻结旧路径：`SetDefaultSearch(..., "")` 无条件更新 `updatedAt`；修复返回相同 workspace 状态，重复 DELETE 不再写行，补 `TestSetDefaultSearch_NoOpDoesNotRefreshUpdatedAt`、platform `ClearPathOwnerAndIdempotency` 和 API 文档。

最终真实绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-075026` 使用 workspace `ws_3af53835ac2258f1`、测试 key `EP-208 Search Visual` 和真实受管上游 `https://api.anselm.website`。Computer Use 在 Settings → Models & keys 真实看到已选择值，点击 Clear 后看到 `Not set`，再次 Clear 仍 `Not set` 且 key 行保留；回 Chat 让真实模型使用 WebSearch 后得到明确的 no-backend guidance。第一场 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-073906` 因目标行未进入截图视口被严格排除，不冒充绿证据；两场均保留。

五通道封口：最终录屏 `340.696667s / 2784x1808 / 60fps`；backend/frontend/SSE/LLM journal 分别 `450/19/182/25` 行，backend 无 panic/FATAL/application error，frontend 只有已知 IMK host 噪声；三路 SSE 均连接，llmtap 的 challenge/install/models/quota 与四次真实 completion 全 `200`。截图 before/after `changedFrac=0.00493`，操作前稳定帧 `f0093` 到首个变化帧 `f0094` 为 `16.7ms`，重复清空稳定 pair 在 `0.0005` 阈值下无 diff。正式按 `measure:default-search-clear-purpose / F2 / A1 / C4 / G1` 写入 `COVERAGE EP-208=✓✓✓✓✓`，独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-208-ledger-reaudit.md`；批次三十三由 `15→20/50`，未到 50 格不跑统一长门禁、不提交。

EP-207 `PUT /api/v1/workspaces/{id}/default-search` 验证的不是一个能返回 `200` 的写接口，而是用户是否能在 Models & keys 选择真实 search key、实际完成 WebSearch、清除默认并得到诚实的未配置引导，同时 API 永远不接受跨 workspace 或悬挂 key。首轮红 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-070832` 证明旧二进制接受 source-owned key 和 `aki_missing_ep207` 并落成 200；红证据已封存。修复让 `SetDefaultSearch` 先解析 path workspace，再把 key existence checker 重置到 path owner，避免陈旧 header 改变引用边界；补 app 单测、platform 黑盒矩阵和 API 文档。

修复后真实绿 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-071305`，数据目录为 `/private/tmp/anselm-data-ep207-default-search-fixed-20260811`。Computer Use 真实走 Settings → Models & keys → picker → `EP207 Search Probe`，回 Chat 使用 WebSearch 得到确定性标题 `EP207 Search Result` 与 URL `https://example.com/ep207`，再回设置 Clear 回显 `Not set`；清除后再次搜索显示明确、可行动的 no-backend guidance。跨 workspace key 与 missing key 均为 `404 API_KEY_NOT_FOUND`，unknown target 为 `404 WORKSPACE_NOT_FOUND`；target-owned Serper probe 为 `{ok:true, latencyMs:1}`，SQLite 清除后 default 为空但 key 仍为 `test_status=ok`，source workspace 未污染。

录屏封口为 `309.938333s / 2784x1808 / 60fps`；选择首个可见反馈 `16.7ms`、清除 `50.0ms`，稳定选择/清除帧在 `0.0005` 阈值下无 diff，contrast=`16.83:1/5.07:1/4.70:1`。backend 无应用 WARN/ERROR/panic/fatal/exception，frontend 仅既有 macOS foreground/IMK 平台噪声，SSE witness 为两 workspace 的 notifications/messages/entities 三流接线并记录真实 durable message，llmtap 记录真实受管 challenge/install/models/quota 与十二次 completion `200`。串行定向 Flutter 测试 `18/18`、Go app/handler/scenario、analyze、coverage、alarms、diff check 通过；此前与 analyze 并发导致的 Flutter 临时目录异常不计作测试结果，单独重跑通过。正式按 `measure:default-search-purpose / F2 / A1 / C4 / G1` 写入 `COVERAGE EP-207=✓✓✓✓✓`，独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-207-ledger-reaudit.md`；未满 50 格，不跑统一长门禁、不提交；下一原子前线为 EP-208。

EP-206 `DELETE /api/v1/workspaces/{id}/default-models/{scenario}` 验证的不是一个能返回 `200` 的删除接口，而是用户是否真的能从 Models & keys 移除不再需要的场景默认，同时不损坏受管 key、不越 workspace 边界，也不把聊天入口清到无法启动。首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-062950` 中 Utility → Change 只有 `Anselm Auto` 没有 Clear；修复后 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-063528`，Computer Use 看到 utility 的 Clear，点击后回显 `Not set`，dialogue 展开只显示 Auto 且无 Clear。修复同时补了 managed 与空能力目录的 Flutter 守卫测试，黑盒测试覆盖 path-owner、六场景、重复清除、非法 scenario 与未知 target。

真实后端矩阵在同一 session live backend 上写入 target 的六个默认，再使用 source workspace header 清 target path，六次 DELETE 全部 `200`，重复 dialogue 清除仍 `200`，`wizard` 返回 `MODEL_SCENARIO_INVALID`，未知 workspace 返回 `WORKSPACE_NOT_FOUND`，target REST/SQLite 六槽全部为 null 而 key 行仍在。录屏为 `204.325000s / 2784x1808 / 60fps`；右侧 scenario ROI 的真实状态变化 `changedFrac=0.05168` 且包围盒为 `(1048,1333)-(1790,1644)`，清除后稳定帧无超过阈值变化，primary/secondary contrast=`16.67:1/5.33:1`。backend 无应用 panic，frontend 仅有既有 macOS debug/IMK 噪声，SSE tap 三流均连接且不虚构 settings durable event，llmtap challenge/install/models/quota 全真实 `200`。正式按 `measure:default-model-clear-purpose / F2 / A1 / C4 / G1` 写入 `COVERAGE EP-206=✓✓✓✓✓`；证据为 session `evidence/EP-206-final-green.md`，独立重审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-206-ledger-reaudit.md`。未满 50 格，不跑统一长门禁、不提交；下一原子前线为 EP-207。

EP-205 `PUT /api/v1/workspaces/{id}/default-models/{scenario}` 验证的不是一个能返回 200 的设置接口，而是用户能否在 Models & keys 中把六个真实模型场景绑定到正确 workspace，并读懂受管免费档的可用量。首轮红 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-053125` 的最终画面保留裸 `1000000000` 和 `2026-09-01T00:00:00+08:00`；修复新增共享 `fmtCompactCount`、双 locale raw-value 断言，并让 SetDefault 先按路径 workspace 做 key/options 校验。真实负向矩阵证明目标 path + 错 header key 得 `404 API_KEY_NOT_FOUND` 且不污染 target，unknown target 先得 `404 WORKSPACE_NOT_FOUND`，source 保持不变。

真实绿 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-060054`，数据目录为 `/private/tmp/anselm-data-ep205-quota-fix-20260811`；Settings → Models & keys 的英文画面为 `0 / 1B · resets 2026-09-01 00:00`，中文为 `0 / 10亿 · 2026-09-01 00:00 重置`，六个 scenario 均显示 `anselm-auto · Anselm Free`。录屏 `154.625000s / 2784x1808 / 60fps`；app-valid 稳定段 43 帧无超阈值 diff，保守 action→首个可见反馈 `33.3ms`，primary/secondary contrast=`16.83:1/5.07:1`。backend/frontend 无应用红线，SSE 三流接线且不虚构 settings durable frame，llmtap challenge/install/models/quota 全真实 `200` 且不虚构 completion。正式按 `measure:default-model-purpose / F2 / A1 / C4 / G1` 写入 `COVERAGE EP-205=✓✓✓✓✓`，formal ledger `1715→1720 judgments`；写账触发的 `gap-too-fast` 与 `discovery-collapse` 已由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-205-ledger-reaudit.md` 独立复核并 ack，未改阈值/算法/法典/锚点/gate。批次三十三由 `0→5/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-206。

EP-204 `GET /api/v1/workspaces/{id}/stats` 验证的不是一个返回计数的隐藏接口，而是用户在删除 workspace 前能否看到即将消失的真实内容，并在磁盘盘点不可及时完成时得到诚实的未知状态。静态审计确认 path id 显式定界、live row 统计按 workspace 且排除软删除、running/generating 交集来自服务端状态，CAS 只扫描目标 workspace，500ms context 超时保留 `blobBytes=-1`，不会把未知伪装成零。

真实五通道 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-044429`，数据目录为 `/private/tmp/anselm-data-ep204-workspace-stats-20260811`；真实 App 创建带 conversation、document 和 29-byte attachment 的 `EP204 Workspace Stats Lab`，再创建并切换到 `EP204 Workspace Other`，从 Settings → Workspaces 打开非当前 workspace 的编辑/删除确认面。UI 真实显示 `1 conversations · 0 entities · 1 documents · 29 B of attachments.`，加载期间先显示 `Taking inventory…`，当前 workspace 不显示删除危险区。REST/SQLite/CAS 交叉证明内容 workspace 为 `1/1/29`、空 workspace 全零、未知 id 为 `404 WORKSPACE_NOT_FOUND`，冲突 header 不改变 path 主体；200,000 个隔离空文件把生产 walk 推到真实 500ms，接口仍 200、`blobBytes=-1`，清理后恢复 29。

录屏封口为 `304.740000s / 2784x1808 / 60fps`；30fps action→loading 和 loading→ready 的首个可见反馈均为 `33.3ms`，全分辨率转场 diff 与 1fps contact sheet 已复核，无黑帧、死 loading、裁切、文字跳变、残留 dialog 或未解释 reflow。backend 无应用 panic/FATAL/WARN/ERROR，frontend 仅已知 IMK 平台噪声，ssetap 三流均接线且无 gap，llmtap 的真实 managed bootstrap 状态保留；该确定性 stats slice 不虚构 LLM completion。定向 Go、Flutter 和 rig tests 通过；正式按 `G1 / F2 / A1 / C4 / G2` 写入 `COVERAGE EP-204=✓✓✓✓✓`，警报由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-204-ledger-reaudit.md` 独立复核并 ack，未修改阈值、算法、法典、锚点或 gate。批次三十二统一长门禁已通过并提交 `e83e0fc6`，下一原子前线为 EP-205。

EP-203 `DELETE /api/v1/workspaces/{id}` 验证的不是一个返回 `204` 的删除接口，而是用户能否在 Settings → Workspaces 中看清将被删除的实际内容、避免误删，并在确认后让 UI、REST、SQLite 生命周期、三路 SSE 与后端清理共同收敛；最后一个 workspace 必须始终保留。静态审计确认 handler → service → store 的删除链路、真实 stats 盘点、精确名称确认、当前/最后一个 workspace 的 UI affordance 门控和 `CANNOT_DELETE_LAST_WORKSPACE` 保护均符合契约，未发现需要 stop-and-fix 的产品代码缺陷。

真实五通道 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-042252`，数据目录为 `/private/tmp/anselm-data-ep203-workspace-delete-20260811`；fixture 为 Alpha `ws_c2c0b5ec6ce86f6c`、Beta `ws_7602c406a380b4d8`、Gamma `ws_9ca729321b5ccb16`。Beta 真实建有一条 conversation 和一篇 document，Settings 删除确认显示 `1 conversations · 0 entities · 1 documents · 0 B of attachments.`；错误名称点击不执行，真实焦点+键盘输入精确名称后删除 Beta，再删除非当前 Alpha，最终 roster 只剩当前 Gamma，Gamma 没有删除 affordance。

REST 矩阵覆盖 Beta/Alpha `204`、删除后 list 收敛、详情与 stats `404 WORKSPACE_NOT_FOUND`、最后 Gamma `422 CANNOT_DELETE_LAST_WORKSPACE` 且 Gamma 仍可读；backend journal 对应 `04:29:39.420`、`04:30:51.966`、`04:31:06.566`。backend 无 panic/FATAL/WARN/ERROR 应用红线，frontend 只有已知 macOS IMK 平台噪声，llmtap 的 14 个状态均为真实 `200`，ssetap 记录三 workspace 的 messages/entities/notifications 接线及 Beta 的真实 `document.created`、`conversation.created` durable 帧，无 gap 或伪造业务帧。

封口录屏为 `493.813333s / 2784x1808 / 60fps`；删除动作到首个可见反馈 Beta=`16.7ms`、Alpha=`16.7ms`，准确帧与测量证据保存在 session `evidence/frames/` 及 `EP-203-final-green.md`，未见黑帧、死 loading、裁切、文字跳变、残留 dialog 或未解释 reflow。定向 Go workspace/store/handler、Flutter Settings/workspace、rig 单测全部通过；正式按 `G1 / F2 / A1 / C4 / G1` 写入 `COVERAGE EP-203=✓✓✓✓✓`，formal ledger `1705→1710 judgments`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-203-ledger-reaudit.md` 独立复核并 ack，未修改阈值、算法、法典、锚点或 gate；批次三十二由 `40→45/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-204。AX `set_value` 不触发 Flutter `onChanged` 的仪器限制已记录为台架 caveat，不是产品缺陷。

EP-202 `PATCH /api/v1/workspaces/{id}` 验证的不是一个能返回 `200` 的更新接口，而是用户能否在 Settings → Workspaces 中把工作区改成自己认得出的名字和颜色，并在 Chat 中用清楚的解释切换网页获取策略。真实 App 从空 onboarding 创建 Alpha；通过真实点击、焦点、键盘输入、颜色点击和 Save 完成 rename/color，左下角 shell 与 GET 都回声为 `EP202 Patch Alpha Renamed` / `#E2A93B`。Chat 的 Jina proxy 与 Local fetch 两次都由真实 UI 点击产生 PATCH，GET 分别回读 `jina` 与 `local`，最终恢复为 local。

静态审计确认 workspace handler 的严格 JSON 解码、partial Update、name/language/webFetchMode 校验和显式 id 路由均符合契约，未发现需要 stop-and-fix 的代码缺陷。真实 Beta 的 avatar-only、language-only、webFetchMode-only、name-only PATCH 均保留未改字段；非法 language、非法 webFetchMode、空 name、unknown field、尾随 JSON 和 unknown id 分别得到准确错误，负向 probe 后业务字段未污染。第一版未知 id probe 与绕过 Flutter `onChanged` 的 AX `set_value` 试探只留在仪器记录中，不计入绿证据。

固定五通道 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-040349`，数据目录为 `/private/tmp/anselm-data-ep202-workspace-patch-20260811`；conductor 在线期间 `rig-check` 的 D1、health、SSE、llmtap、Flutter、console、recorder 全部通过。窗口录屏最终为 `558.061667s / 2788x1808 / 60fps`；独立 ssetap 为 Alpha/Beta 各连接 messages/entities/notifications，llmtap 真实跨 `https://api.anselm.website` 记录 challenge/install/models `200`，backend 无应用级 WARN/ERROR/panic/FATAL，frontend 只有已知 macOS IMK 平台噪声。录屏逐帧未发现黑帧、死 loading、裁切、文字跳变、未解释 reflow 或控件错位。

60fps 测量工具对控件 ROI 得到颜色 `50.0ms`、Jina `33.3ms`、Local `50.0ms` 首个可见反馈，均满足 A1；颜色圆点等尺寸、选中 ring、segmented inset 和说明文案对齐满足 C4。定向 Go workspace/store/handler 测试通过，相关 Flutter Settings/workspace 测试 `33` 项通过，rig 单测 `6` 项通过。正式按 `G1 / F2 / A1 / C4 / G1` 写入 `COVERAGE EP-202=✓✓✓✓✓`；写账触发的 `gap-too-fast` 与 `discovery-collapse` 已由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-202-ledger-reaudit.md` 独立复核并 ack，未修改阈值、算法、法典、锚点或 gate。批次三十二由 `35→40/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-203。

EP-201 `GET /api/v1/workspaces/{id}` 验证的不是一个能返回 `200` 的隐藏读取接口，而是用户在真实 App 中从空 onboarding 创建 workspace 后，Settings → Workspaces 能否显示同一份完整、稳定、可解释的对象；API caller 对未知、删除后 id 和错误 workspace header 也必须得到准确语义。首轮静态审计确认 handler → service → store 的显式 id 链路和 `WORKSPACE_NOT_FOUND` 翻译正确，未发现需要 stop-and-fix 的代码缺陷。

主五通道 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-034512`，真实 App 创建 `EP201 GET Alpha` 并打开 Workspaces roster；REST 矩阵另建隔离 Beta，覆盖 Alpha/Beta `200`、未知 id `404 WORKSPACE_NOT_FOUND`、无关 workspace header 仍 `200`、删除 Beta 后同样 `404` 和最终 roster 只留 Alpha。Beta 的立即删除会取消其异步受管开通，backend 唯一 DEBUG `context canceled` 已在证据中明确归类为 fixture lifecycle cancellation，不伪装成零日志。补充短重放 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-035449` 由 conductor 从空库创建 `EP201 GET Replay`，记录了真实 Settings 点击到 Workspaces 的帧级转场。

EP-201 的逐帧分流也已完成：主录像中疑似全黑的 `frame-0096`、`frame-0098` 直接打开均为正常 Settings → Chat；原始 60fps `95.5–98.5s` 全部 `YAVG=190.546`。补充录像中物理动作前最后稳定帧 `frame-0264` 到首个完整 Workspaces 帧 `frame-0265` 经 `measure latency` 为 `16.7ms`、`changedFrac=0.04142`，满足 A1。正式按 `G1 / F2 / A1 / C4 / G1` 写入 `COVERAGE EP-201=✓✓✓✓✓`；写账触发的 `gap-too-fast` 与 `discovery-collapse` 由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-201-ledger-reaudit.md` 独立复核并 ack，未改阈值、算法、法典、锚点或 gate。静态 Go/Flutter/rig 回归均通过。

EP-200 `POST /api/v1/workspaces` 验证的不是单独一个 `201`，而是空库用户能否在真实 App 中创建 workspace，并在受管免费档准备期间得到即时、明确、不会误操作的反馈，随后进入可用 Chat；API caller 还必须得到同一套严格输入契约和最终 machine roster。首轮红探针把两个 JSON 值拼在一个 body 中，接口错误地创建第一个 workspace 并返回 `201`；前线冻结，`decodeJSON` 与 `decodeJSONOptional` 现在在首值后检查 EOF，第二个值或垃圾尾巴统一返回 `400 INVALID_REQUEST`。创建控件同时修复 `_saving` 时 setup 文案透明的反馈缺陷，等待期间显示 `Setting up your workspace…`、输入只读、按钮禁用。

固定版五通道 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-032721`，真实 App 从空 onboarding 开始，Computer Use 创建 `EP200 UI Loading`；AX 树和录屏都看到即时 setup 状态，另一路 REST 创建 `EP200 API Loading` 并确认受管开通和六个 `anselm-auto` 默认场景最终落盘。固定版矩阵覆盖合法创建、尾随 JSON、空名称、非法语言、未知字段、65-rune 名称和列表收敛；原始红证据与固定版证据均在 session `evidence/` 内。backend 无 panic/FATAL/ERROR/WARN，三 workspace 流接线最终收敛到 messages/entities/notifications，llmtap 的 challenge/install/models 为真实 `200`，frontend 无 Dart/Flutter/RenderFlex/Unhandled/overflow 红线。录屏为 `121.798333s / 2784x1808 / 60fps`，对比度 `14.68:1`，动作到首反馈 `16.7ms`，稳定 Chat ROI 无超过阈值的异常帧差；完整 formal re-audit 为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-200-ledger-reaudit.md`。

正式按 `G1 / F2 / A1 / C4 / G1` 写入 `COVERAGE EP-200=✓✓✓✓✓`；formal ledger `1690→1695 judgments`，anchors=`10/10`，`gen_coverage.py --check`=`848 rows / 332 carried judgments / 0 tombstones`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已依据独立 re-audit、原始红证据、固定版五通道 session、负向矩阵、测量和静态验证逐项 ack，没有放宽阈值、修改算法、补写法典或改变锚点；最终 `alarms.py check`=`clean (1695)`。批次三十二由 `25→30/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-201。

EP-199 `GET /api/v1/workspaces` 验证的不是一个能返回 workspace 数组的列表接口，而是用户在首次启动、创建多个 workspace、切换上下文和打开 Settings roster 时，是否始终看到同一份有序、可解释、不会因同一时间戳而漂移的机器级名册。空库必须先呈现 onboarding；真实创建后，footer switcher、Settings roster、当前 workspace 标记和服务端列表必须收敛；删除确认表面在本格走查，但完整 UI 删除后的收口属于 EP-203，不能被本格的隔离 API fixture 删除冒充。

静态 stop-and-fix 发现 store 只按 `created_at ASC` 排序；多个 workspace 在同一时间戳下可能使冷启动 onboarding 初始对象和 roster 顺序不稳定。现在契约固定为 `created_at ASC, id ASC`，新增相同时间戳 tie-break 回归，API 与 support-services 文档同步说明这是机器级、有界、不分页的完整名册。

真实五通道 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-025525`，由 conductor 托管真实 Flutter macOS App、Computer Use、真实受管 `https://api.anselm.website`、三路独立 ssetap、backend/frontend journals、llmtap 和封口录屏 `320.688333s / 2784x1808`。全新数据目录先真实观察空 onboarding，再在 App 内创建 `EP199 Workspace Alpha`、`EP199 Workspace Beta`、`EP199 Workspace Gamma`，通过 footer switcher 在三者间切换，并在 Settings → Workspaces 观察完整 roster、创建顺序和当前标记；随后打开 Beta 的删除确认表面。为避免把不可逆 fixture 操作误算成产品删除验收，最终 Beta 删除由 session 内直接 REST probe 隔离完成，REST 列表收敛为 Alpha/Gamma，已删除对象返回 `404 WORKSPACE_NOT_FOUND`；EP-203 仍需重新用真实 UI Confirm 完成删除闭环。

五通道真相：backend 无 WARN/ERROR/panic/FATAL，frontend 无 Dart/Flutter/RenderFlex/Unhandled/Exception/runtime 红线，SSE witness 为三个 workspace 各自连接 messages/entities/notifications 且本 GET-only slice 没有虚构业务帧，llmtap 的 challenge/install/models 均真实 `200` 且没有伪造 completion。`rig-check` 在创建、切换和收台前通过 D1 attribution、backend health、三流接入、llmtap、Flutter runner、console 与 recorder 检查；录屏 1fps 逐帧抽取 321 帧，onboarding、Chat、switcher、roster、delete confirmation 无裁切、死 loading、文字跳变或未解释 reflow。原始创建 60fps 片段以 `measure latency` 得首个可见反馈 `16.7ms`，深色文字对纯白背景对比度 `14.68:1`；稳定 ROI diff 无异常。完整证据为 session 内 `evidence/EP-199-final-green.md`，formal re-audit 为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-199-ledger-reaudit.md`。

正式按 `measure:workspace-roster-purpose / G1 / A1 / C4 / G1` 写入 `COVERAGE EP-199=✓✓✓✓✓`；formal ledger `1685→1690 judgments`，anchors=`10/10`，`gen_coverage.py --check`=`848 rows / 331 carried judgments / 0 tombstones`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已逐项重新读取原始 session、数据库、LLM body、SSE、测量和静态验证后 ack，没有放宽阈值、修改算法、补写法典或改变锚点；最终 `alarms.py check`=`clean (1690)`。批次三十二由 `20→25/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-200。

EP-198 `PATCH /api/v1/search/settings` 验证的不是一个能返回 `200` 的写接口，而是机器级搜索设置能否在用户意图、存储原子性、跨 workspace 作用域和语义降级之间保持同一真相。首轮静态 stop-and-fix 发现两个真实缺陷：多字段 PATCH 逐键写入可能半更新；设置变更只 invalidate/kick 当前 workspace。现在批量设置在单 SQL 事务内提交，后写失败会整体回滚；Service 记录所有已进入搜索索引的 workspace，embedder/model/参数变化扇出到全部 workspace。真实五通道 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-024018`，录屏 `239.978333s / 2784x1808`；19 项 REST 证据覆盖未知字段、非法值、畸形 JSON、空 no-op、部分 PATCH、死端口 lexical fallback、跨 workspace、文档搜索和恢复 ready。SSE 两 workspace 各自三流连接且只出现真实 document.created durable frame；backend/frontend 无应用红线；llmtap 的 managed bootstrap 全部真实 200；Settings 主内容稳定 ROI 测得 `changedFrac=0`。正式按 `measure:search-settings-patch-purpose / F2 / A1 / C4 / na` 写入 `COVERAGE EP-198=✓✓✓✓~`，ledger `1680→1685`；警报已由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-198-search-settings-patch-ledger-reaudit.md` 独立复核并 ack，未改任何阈值或法典。下一原子前线为 EP-199。

EP-197 `GET /api/v1/search/settings` 验证的不是一个能返回 `200` 的设置读取接口，而是产品对“这台机器的搜索引擎到底是什么状态”必须诚实：设置存储是 machine-level，所有 workspace 读到同一份；新 Ollama 适配器在没有任何成功上游响应前必须是 `absent`，实际失败后才变为带错误详情的 `error`，绝不能把“对象已构造”伪装成 `ready`。同一批静态 stop-and-fix 同步补齐 engine 状态锁、失败/成功转移、focused unit/race 回归和 search domain 文档。

真实五通道 session 为 `/private/tmp/anselm-rig-ep197-search-settings-20260811/sessions/20260811-021913`，workspace=`ws_01e6bcd51f451d54` 与通过真实 sidecar 建立的 `ws_7f859ea0512d2549`，由 conductor 托管真实 Flutter macOS App、Computer Use、真实受管 `https://api.anselm.website`、三路独立 ssetap、backend/frontend journals、llmtap 和封口录屏；录屏 `401.060000s / 2784x1808 / 60fps`。真实 onboarding 创建 `EP197 Search Settings Lab`，随后打开 Settings 全面检查 panel rail、Settings 搜索和 Models & keys；未把隐藏 API 误报为用户设置入口。

REST 真相：初始两个 workspace 均为 `builtin / engine.absent / embeddinggemma-300m-qat-q8_0`；非法 PATCH 返回 `400 SEARCH_EMBEDDER_INVALID`；切 `off` 后另一 workspace 立即看到 `off`；切到不可达 `http://127.0.0.1:9` 后首次 GET 保持 `absent`，真实创建文档并 kick reindex 触发一次失败嵌入，随后 GET 为 `error` 并带 connection-refused；同一搜索仍返回文档 lexical hit；空 Ollama 参数与 builtin PATCH 最终恢复有效默认。backend journal 无未解释应用级红线，唯一 degraded 日志是预期的 provider-unavailable lexical fallback。

五通道对证：SSE witness 为两个 workspace 各自连接 `messages/entities/notifications`，本 settings slice 只记录真实 `document.created` durable notification，没有虚构 settings lifecycle frame；LLM tap 记录真实 gateway challenge/install/models/quota bootstrap，确定性 API 路径不虚构 chat completion；frontend 只有已知 macOS runner `Failed to foreground app; open returned 1` 与 IMK 平台噪声，没有 Dart/Flutter/RenderFlex/Unhandled/runtime 红线；最终 onboarding 与 Models & keys 帧无裁切、死 loading、错位或未解释 reflow。正式按 `measure:search-settings-purpose / F2 / A1 / C4 / na` 写入 `COVERAGE EP-197=✓✓✓✓~`；formal ledger `1675→1680 judgments`，`gen_coverage.py --check`=`848 rows / 329 carried judgments / 0 tombstones`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-197-search-settings-ledger-reaudit.md` 独立复核并 ack，未改阈值/算法/法典/锚点/gate；最终 `alarms.py check`=`clean (1680)`。

EP-196 `POST /api/v1/search:reindex` 验证的不是一个能返回 `204` 的维护接口，而是索引重建是否对用户的搜索目的保持透明：不能先 purge 造成空结果，不能让一个 workspace 的维护阻塞另一个 workspace，也不能让重复动作静默排队或并发写坏索引。首轮静态核对确认实现是 per-workspace single-flight、force-reconcile 就地覆盖词法索引、向量失效后后台重嵌；补齐过时的 `202` 注释为真实 `204` fire-and-forget 语义，并同步 testend/bootstrap 注释和搜索文档。

真实五通道 session 为 `/private/tmp/anselm-rig-ep196-reindex-20260811/sessions/20260811-015322`，workspace=`EP196 Reindex Lab` 与 `EP196 Parallel Lab`，由 conductor 托管真实 Flutter macOS App、Computer Use、真实受管 `https://api.anselm.website`、三路独立 ssetap、backend/frontend journals、llmtap 和封口录屏；录屏 `335.445000s / 2784x1808`。主 workspace 建立 180 篇带 `EP196-REINDEX-TOKEN` 的文档，搜索基线与重建期间均为 `total=181`；同 workspace burst 得到 `204×6` 与 `409×114`，第二 workspace 同时得到 `204`，24 次并发搜索全部 `200` 且保持一个命中。

真实 Chat 通过 Computer Use 发送 `Use the document search tool to search for EP196-REINDEX-TOKEN. Do not guess. Tell me how many matching documents it found and give me the exact name of the first result.`；LLM wire 真实调用 `search_documents`，tool card 显示 `10 of 181`，助手准确回答 `181` 和 `EP196 Reindex Document 180`。backend 无 WARN/ERROR/panic/FATAL；frontend 无 Dart/Flutter/RenderFlex/Unhandled/Exception 红线，只有已知 macOS IMK 噪声；两个 workspace 各自三流连接，primary messages durable `1..14`、notifications `1..183` 均无 gap，gateway challenge/install/models/chat 全部真实 `200`。

逐帧与测量：30fps 抽帧以 submit action=`219` 为基线，`measure latency` 首个可见反馈为 frame=`220`、`33.3ms`、changedFrac=`0.01506`；稳定 transcript ROI 的 `f000400→f000401` 没有超过 rig 阈值的 diff。稳定 Chat 画面中的用户问题、搜索 tool capsule、grounded 回答、workspace rail 和 composer 均无裁切、重排、死 spinner 或未解释跳变。该 endpoint 是内部 fire-and-forget 动作，没有独立 UI、导航入口或可轮询产物，因此 L5 按事实记 `na`，不把隐藏 API 伪装成可发现产品入口。

正式按 `measure:search-reindex-purpose / F2 / A1 / C4 / na` 写入 `COVERAGE EP-196=✓✓✓✓~`；formal ledger `1670→1675 judgments`，anchors=`10/10`，`gen_coverage.py --check`=`848 rows / 328 carried judgments / 0 tombstones`。五级写账触发的 `gap-too-fast` 与 `discovery-collapse` 已写入 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-196-reindex-ledger-alarm-reaudit.md`，逐项重新读取原始 session、数据库、LLM body、SSE、测量和静态验证后 ack；没有放宽阈值、修改算法、补写法条或改变锚点。批次三十二由 `5→10/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-197。

EP-195 `GET /api/v1/search` 验证的不是一个能返回 `200` 的查询接口，而是用户能否在真实产品中找到正确的知识、明确控制搜索边界，并在模型协助时获得与数据库和线缆一致的答案。首轮静态审计发现 malformed RFC3339、倒置时间窗和非布尔 `includeArchived` 会静默改变查询意图；已改为显式 `422`（含 `param/got/want` 或归一化边界详情），有效偏移统一 UTC 且保持 inclusive，补充传输层、领域层和真实 testend 回归。同步更新 `docs/references/backend/api.md`、`docs/references/backend/domains/search.md`、`docs/references/backend/error-codes.md`。

真实五通道 session 为 `/private/tmp/anselm-rig-ep195-search-20260811/sessions/20260811-013347`，workspace=`ws_44cc272d2644236b`，由 conductor 托管真实 Flutter macOS App、Computer Use、真实受管 `https://api.anselm.website`、三路独立 ssetap、backend/frontend journals、llmtap 和封口录屏；录屏 `235.940000s / 2784x1808`，manifest 绑定 D1 backend、tap、Flutter runner 和 recorder lifecycle。真实建立三篇文档和一条 archived conversation：omni query `total=4` 且 cursor 续页无重复；`types=document + tags=search-proof + inclusive window + includeArchived=false + limit=1` 两页只得到 Alpha/Beta；改过滤器复用旧 cursor 返回 `400 SEARCH_CURSOR_INVALID`；false/true 归档过滤分别返回 3/4；malformed after、非法 bool 和倒置 window 分别返回明确 `422`；exact-name query 将 Alpha 排首并返回 `<mark>`。

真实 Chat 通过 Computer Use 从 Composer 发送 `Search my documents for EP195-RANK-TOKEN. Do not guess or use the conversation title. Use the document search tool, then tell me the exact matching document names and the relevant snippet for each result.`；UI 出现 `Searched document "EP195-RANK-TOKEN" · 3 found`，稳定表格精确列出 `EP195 Search Beta`、`EP195 Search Alpha`、`EP195 Search Gamma` 及各自 snippet，并明确 `3 total matches`。LLM wire 实际发出 `search_documents({"query":"EP195-RANK-TOKEN"})`，tool result 含同三条 ID/name/snippet/total，未以 conversation title 猜测。

五通道真相：backend 无应用级 WARN/ERROR/panic/FATAL；frontend 无 Dart/Flutter/RenderFlex/Unhandled/Exception/runtime 红线，只有已知 macOS launcher/IMK 噪声；notifications、entities、messages 三流均连接，notifications durable seq=`1..7`、messages durable seq=`1..14` 单调，seq=`0` 仅是 delta，message stream 含真实 reasoning/tool_call/tool_result/text/close；gateway challenge/install/models 与最终 completion 均 `200`，LLM context 无错误。逐帧 30fps 抽取以 `f000375` 为保守 send action，`measure latency` 首反馈 `f000376`=`33.3ms`、全局 changedFrac=`0.00495`，Composer ROI changedFrac=`0.06062`，均有 changed box；稳定 Chat 帧和标题结束帧无黑屏、死 spinner、表格溢出、reflow 或文字跳变。标题中间的 `Se` 是仓内已立法的一次性 typewriter，SQLite 最终标题完整、标题槽预留完整宽度，late frames 收敛为稳定 full head title 与正常 sidebar ellipsis；该中间态已审美复核，不作为缺陷隐藏。

正式按 `measure:search-purpose / F2 / A1 / C4 / G1` 写入 `COVERAGE EP-195=✓✓✓✓✓`；formal ledger `1665→1670 judgments`，anchors=`10/10`，`gen_coverage.py --check`=`848 rows / 327 carried judgments / 0 tombstones`。五级写账触发的 `gap-too-fast` 与 `discovery-collapse` 已写入 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-195-search-ledger-alarm-reaudit.md`，逐项重新读取原始 session、数据库、LLM body、SSE、测量和静态验证后 ack；没有放宽阈值、修改算法、补写法条或改变锚点。正式 `anchors.py check`=`10/10`、`alarms.py check`=`clean (1670)`；EP-195 session/evidence/formal ledger 保留，隔离数据目录已按授权移入 Trash；本段记录当时批次三十二由 `0→5/50`，随后进入 EP-196。

EP-194 `POST /api/v1/memories/{name}/unpin` 验证的不是一个返回 `200` 的反向按钮，而是用户能否把一条不应继续影响每轮对话的记忆从常驻策展中移出，同时保留它、看得见它、能重新置顶，并让下一次对话只知道它的索引而不偷偷得到全文正文。

真实五通道 session 为 `/private/tmp/anselm-rig-ep194-memory-unpin-20260811/sessions/20260811-005136`，workspace=`ws_40dce7f8769118eb`，由 conductor 托管真实 Flutter macOS App、Computer Use、真实受管 `https://api.anselm.website`、三路独立 ssetap、backend/frontend journals、llmtap 和封口录屏；录屏 `229.195000s / 2784x1808 / 60fps`。真实建立初始 pinned 的 `unpin-guide` 和未置顶的 `quiet-note`，在 Settings → Resources → Memory 中点击真实 Unpin；同一行立即变为 Pin，Pinned 过滤显示稳定的 `No matching memories`。随后真实 Chat 发送 `List only the memory names currently visible in your memory index. Do not read any memory.`，助手只列出 `quiet-note` 与 `unpin-guide`，没有调用 `read_memory`。

五通道真相：Unpin 与重复 Unpin 均返回 `200 pinned:false`；后续 GET 仍保留完整记忆，pinned-only 列表为空，文件 frontmatter 为 `pinned: false`，description/body 未丢失。notifications durable seq=`1..3` 记录两次 create 和一次真实 `memory.updated`，重复 mutation 没有第二条更新通知；messages durable seq=`1..8` 单调，seq=`0` 只用于流式 delta；三流均连接并在收台时 clean EOF。llmtap 真实记录 proof challenge/install/models/chat/auto-title 全部 `200`，chat request 含名称索引但没有完整 unpin-guide 正文，最终 wire/可见回答均未伪造读取。backend 无应用 WARN/ERROR/panic/FATAL；frontend 无 Dart/Flutter/RenderFlex/Unhandled/Exception，唯一 IMK launcher 噪声按既有规则分类。

逐帧与测量：30fps 固定抽帧中 Unpin action=`1279`→pin 图标反馈 frame=`1282`，`100.0ms`、changedFrac=`0.01233`、box=`(534,292)-(547,307)`；Pinned filter action=`1493`→稳定空态 frame=`1495`，`66.7ms`、changedFrac=`0.03848`、box=`(528,200)-(1187,329)`；Chat submit action=`565`→首个可见反馈 frame=`567`，`66.7ms`、changedFrac=`0.00296`、box=`(597,328)-(1176,404)`。原始 60fps 黑帧复核的十二帧均为 `YAVG=189.839/YMIN=16/YMAX=235` 的正常白色 Chat 空态，没有产品黑屏、残留 spinner、列表 reflow、文字跳变或错位。完整证据为 session 内 `evidence/EP-194-final-green.md`，账本复核为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-194-ledger-alarm-reaudit.md`。

正式按 `measure:memory-unpin-purpose / F2 / A1 / C4 / G2` 写入 `COVERAGE EP-194=✓✓✓✓✓`；formal ledger `1660→1665 judgments`，anchors=`10/10`，`gen_coverage.py --check`=`848 rows / 326 carried judgments / 0 tombstones`。本次五级写账按机制触发 `gap-too-fast`、`pass-burst`、`discovery-collapse`；复核重新读取原始录屏、五通道 journals、LLM body、测量输出、前端/后端日志和 CODEX 法条，确认这些是批量写账与清洁路径的统计信号，不修改阈值、算法、法典、锚点或 gate，已逐条 ack，最终 `alarms.py check`=`clean (1665)`。隔离数据目录已按用户授权移入 Trash，session、录屏、journals、formal ledger、evidence 与测量目录保留。批次三十一达到 50/50 后，root make verify、完整 make -C backend testend（284.530s）、Memory 定向 Go/Flutter 回归、rig 自测、docs/coverage/anchors/alarms/diff、端口/进程和 fixture 审计均已通过；下一动作是工作树审计和提交。

EP-193 `POST /api/v1/memories/{name}/pin` 验证的不是一个能返回 `204` 的按钮，而是用户能否在真实 Settings → Resources → Memory 中可靠地改变一条记忆的长期策展状态，并立刻理解结果：Pin 后条目进入 Pinned 过滤，Unpin 后过滤器诚实为空，重新 Pin 后回到 Pinned；随后真实对话必须能通过 pinned memory 达成用户目的，而不是只在列表里改变一个图标。首轮静态审计发现旧 `_MemoryRow` 直接 await pin Future，没有单飞锁存，也没有 pin 专属异常处理；失败可能成为未处理 Flutter exception，快速连点还可能发出相互竞争的 mutation。该问题按 stop-and-fix 冻结，不能带病进入真实验收。

修复落在 stateful、`ValueKey(m.name)` 绑定的 row：pin 入口使用 `_pinBusy` 单飞，进行中显示共享 `AnSpinner` 与 action-specific AX label，只禁用 pin 入口和该行导航；失败写入 notice center 的本地化 `pinFailed`，保留权威旧状态；fixture 增加 gate、错误注入和调用计数，补 failure/no-exception 与 duplicate-click/single-flight 回归。同步 en/zh i18n 和 `docs/references/frontend/features/settings.md`，没有把错误吞成成功或把整页误置 loading。

真实五通道 session 为 `/private/tmp/anselm-rig-ep193-memory-pin-fix-20260811/sessions/20260811-003318`，workspace=`ws_f810cbeb47756bcc`，由 conductor 托管真实 Flutter macOS App、Computer Use、真实受管 `https://api.anselm.website`、三路独立 ssetap、backend/frontend journals、llmtap 和封口录屏；录屏 `181.463333s / 2784x1808 / 60fps`，recorder lifecycle 有 recorder PID 与 UTC 起点。真实建立 `pin-guide` 与 `quiet-note`，初始均未置顶；在 Memory UI 中 Pin `pin-guide`，Pinned 只显示它；Unpin 后显示 `No matching memories`；All 后再次 Pin。回到 Chat 发送 `What is the exact phrase in the pinned memory and nothing else`，最终可见回答为精确文本 `Pin this only when it should ride every conversation.`，用户目的而非仅接口动作成立。

五通道真相：backend journal 记录三次真实 pin mutation（首次 pin、unpin、repin）及 roster GET 均为 `200`，无应用 WARN/ERROR/panic/FATAL；最终 REST all 为 `pin-guide pinned=true`、`quiet-note pinned=false`，`pinned=true` 过滤只含 `pin-guide`，文件 `pin-guide.md` frontmatter 为 `pinned: true`。notifications durable seq=`1..7` 单调，含两次 memory.created、三次 memory.updated、conversation.created 和 auto-title；messages 流记录真实 user、`read_memory` tool call/result、assistant close，entities/messages 三流均物理连接且没有虚构业务帧。llmtap 真实记录 gateway challenge/install/models 与 3 次 completion 全部 `200`，其中对话线缆带有 pinned 内容并要求 `read_memory(name="pin-guide")`；frontend console 无 Dart/Flutter/RenderFlex/Unhandled/Exception/runtime 红线，保留的 `Failed to foreground app; open returned 1` 仍按既有规则归类为 VM 启动前 launcher 噪声。

逐帧与测量：30fps 固定抽帧的首次 Pin 图标反馈为 `33.3ms`、Pinned 过滤为 `66.7ms`、Unpin 空态为 `66.7ms`、All 为 `33.3ms`、repin 图标为 `66.7ms`；Chat 首个可见反馈为 `433.3ms`，均有相邻帧 diff 与 changed box 证据，没有黑帧、残留 spinner、列表错位、整行高度漂移或文字跳变。正式证据为 session 内 `evidence/EP-193-final-green.md`，账本警报复核为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-193-ledger-alarm-reaudit.md`；证据明确保留 measurement 对齐和平台噪声分类，不把未观察的 hover 或不存在的 completion 写成事实。

正式按 `measure:memory-pin-purpose / F2 / A1 / C4 / G2` 写入 `COVERAGE EP-193=✓✓✓✓✓`；formal ledger `1655→1660 judgments`，anchors=`10/10`，`gen_coverage.py --check`=`848 rows / 325 carried judgments / 0 tombstones`。本次写账再次触发 `gap-too-fast` 与 `discovery-collapse`，均已基于独立 re-audit、原始录屏、五通道 journals、静态测试和锚点逐条 ack；未修改阈值、算法、法典、锚点或 gate，最终正式 `alarms.py check`=`clean (1660 judgments)`。EP-193 隔离数据目录已按授权移入 Trash；session、录屏、journals、formal ledger、evidence 与测量复核目录保留。批次未满 50 格，不跑统一长门禁、不提交；下一原子前线为 EP-194。

EP-192 `DELETE /api/v1/memories/{name}` 验证的不是一个能返回 `204` 的删除接口，而是用户能否在真实 Settings → Resources → Memory 里安全完成一次不可逆操作：先看到物理删除和不可恢复的明确警告，Cancel 回到同一状态且不发 DELETE，Confirm 后名册和空态真实收敛；如果另一个客户端先删除当前打开的 memory，当前编辑页必须停止伪装成可写真相，回到已确认的 roster，并告诉用户名册已刷新。重复删除、非法 name 和最终 REST/file state 也必须分别诚实返回 `404`、`400` 和空结果。

真实五通道 session 为 `/private/tmp/anselm-rig-ep192-memory-20260810/sessions/20260810-154348`，workspace=`ws_b525c35db275343e`，由 conductor 托管真实 Flutter macOS App、Computer Use、真实受管 `https://api.anselm.website`、三路独立 ssetap、backend/frontend journals、llmtap 和封口录屏；录屏 `29509.911667s / 2788x1808 / 60fps`，recorder lifecycle 有 PID 绑定的 UTC 微秒起点。真实 Memory editor 创建 `daily-rule` 与 `keep-me`，先打开 `daily-rule` 删除确认并 Cancel，确认两行仍在且没有 DELETE；再打开 `keep-me`，由第二客户端真实 DELETE，App 回到 roster 并显示 `Memory removed — the roster was refreshed`；最后在用户明确授权后从真实 UI Confirm 删除 `daily-rule`，Settled empty state 显示 `Add your first memory` 与 `New memory` 入口。

本轮 stop-and-fix 将前端 Memory detail 接到 settled roster 的权威存在性：加载中或读取失败不误驱逐，只有名册确认对象消失才在 post-frame 返回列表并渲染可理解的 removed 状态；同步新增 en/zh 文案、`_MemoryGone` 空态、Settings reference 文档和外部删除 widget regression。静态 `go test` memory/store/HTTP handler/middleware/response/router、`TestContractKnowledge_MemorySurface`、Memory/lifecycle Flutter tests（11 项）、`flutter analyze`、measure tests、`make -C docs verify` 和 `git diff --check` 全部通过。

五通道真相：backend journal 记录两次真实 UI/外部 DELETE=`204`，最终 GET memories=`[]`，重复删除=`404 MEMORY_NOT_FOUND`，非法 uppercase name=`400 MEMORY_INVALID_NAME`，产品 session 无 WARN/ERROR/panic/fatal；notifications durable seq=`1..4` 单调，依次为两次 create、外部 delete、UI delete，entities/messages 三流物理连接但没有虚构业务帧；llmtap 真实记录受管 gateway challenge/install/models 全部 `200`，本格是 settings-only path，没有 chat completion，故诚实记录为空；frontend console 无 Dart/Flutter/RenderFlex/Unhandled/Exception/runtime 红线，唯一 `Failed to foreground app; open returned 1` 仍按既有规则归类为 VM 启动前 launcher 噪声。

逐帧与测量：外部删除 notice 的第一可见反馈为 `16.7ms`，UI Confirm 采用保守 `actionFrame=344`，第一可见反馈 `83.3ms`，`changedFrac=0.00770`，changed box=`(675,392)-(2395,991)`；取消对话框保持居中可读，确认后只收敛主内容到空态，没有黑帧、文字跳变、残留 dialog、死 spinner 或布局 reflow。正式证据为 session 内 `EP-192-final-green.md`，五级账本复核为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-192-ledger-alarm-reaudit.md`；两份证据已修正并保留可复算的 frame/latency 对应关系。

正式按 `measure:memory-delete-purpose / F2 / A1 / C4 / G2` 写入 `COVERAGE EP-192=✓✓✓✓✓`；formal ledger `1650→1655 judgments`，anchors=`10/10`，`gen_coverage.py --check`=`848 rows / 324 carried judgments / 0 tombstones`。写账触发的 `gap-too-fast`（同一已封存 session 的五级批量写入）与 `discovery-collapse`（没有为干净路径伪造 fail）均已基于原始录屏、五通道 journal、测量输出、静态测试和锚点逐条独立复核并 ack；未修改阈值、算法、法典、锚点或 gate，最终正式 `RIG_HOME` 下 `alarms.py check`=`clean (1655 judgments)`。EP-192 数据目录已按授权移入 Trash，formal ledger、session、录屏、journals、evidence 与测量复核目录保留。

EP-191 `PUT /api/v1/memories/{name}` 验证的不是一个能返回 `200` 的写接口，而是用户能否建立一条可长期复用的 memory，并在外部或其他界面更新它时继续相信当前页面：名称保持稳定、描述和多行正文完整、置顶/source 策展不被覆盖，UI、REST、文件 store 和 notifications durable frame 必须共同收敛；非法 name、缺字段、错误 source、未知字段和 frontmatter 注入尝试必须诚实失败或保留原策展状态。

真实 R3 五通道 session 为 `/private/tmp/anselm-rig-ep191-memory-20260810-r3/sessions/20260810-151539`，workspace=`ws_44809c9a07c035aa`，由 conductor 托管真实 Flutter macOS App、Computer Use、真实受管 `https://api.anselm.website`、三路独立 ssetap、backend/frontend journals、llmtap 和封口录屏；录屏 `336.938333s / 2784x1808 / 60fps`，`recording-lifecycle.json` 为 recorder PID 绑定的 UTC 微秒起止证据。真实 Memory editor 创建 `daily-rule-r3`，外部 PUT 更新描述后，页面不导航、不刷新即显示 `Updated in R3 externally`；随后创建/更新/删除 `r3-curated`，恶意多行描述中的 `pinned:`/`source:` 不能覆盖 `pinned=true, source=user`，最终 roster 与删除后的 REST 结果一致。

静态 stop-and-fix 先修正了多行 description 可能注入 frontmatter 元数据的后端缺陷：scalar 解析与 quoted rendering 现在保证用户描述不能写入 `pinned`/`source` 控制字段，补充 round-trip regression；前端 memory provider 不再因 durable signal 直接重建成 loading gap，而是权威 list 后原地 reconcile，并用 generation 丢弃过期响应；同步 API、Memory settings 文档和 i18n。`go test` 的 memory/store/HTTP handler/middleware/response/router 定向包、`TestContractKnowledge_MemorySurface`、Memory/lifecycle Flutter tests（10 项）和 `flutter analyze` 全部通过。

五通道真相：backend journal 记录真实 PUT/GET/DELETE，响应与文件 store 一致且无应用 WARN/ERROR/panic/fatal；notifications durable seq=`1..5` 单调，分别对应两次 create、两次 update 和一次 delete，entities/messages 三流物理连接但没有凭空捏造业务帧；llmtap 真实记录受管 gateway challenge/install/models 全部 `200`，本格没有 chat completion，故不伪造模型调用；frontend console 无 Dart/Flutter/RenderFlex/Unhandled/Exception/runtime 红线，唯一 `Failed to foreground app; open returned 1` 仍是已知 VM 启动前 macOS launcher 噪声。

逐帧与测量：原始 source frame `source_007→source_008` 是唯一变化，`measure diff`=`changedFrac 0.00058`、changed box=`(1114,540)-(1396,563)`，严格只落在记忆描述行；PTS=`264.113333→264.130000`，相邻稳定帧给出的保守可见反馈上界=`16.7ms`，满足 CODEX A1 的 `≤100ms`，没有整面重排、黑帧、死 spinner 或布局跳变。R2 的秒级 `startedAt` 只作为被拒绝的测量教训保留，R3 使用新增 lifecycle 微秒证据；正式证据为 session 内 `EP-191-r3-final-green.md`，账本警报复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-191-ledger-alarm-reaudit.md`。

正式按 `measure:memory-upsert-purpose / F2 / A1 / C4 / G2` 写入 `COVERAGE EP-191=✓✓✓✓✓`；formal ledger `1645→1650 judgments`，anchors=`10/10`。写账触发的 `gap-too-fast`、`discovery-collapse` 已依据独立 re-audit 逐条 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (1650 judgments)`，`gen_coverage.py --check`=`848 rows / 323 carried judgments / 0 tombstones`。EP-191 base、R2、R3 三个隔离数据目录已按用户授权移入 Trash，formal ledger、session、录屏、journals、evidence 与测量复核目录保留。

EP-190 `GET /api/v1/memories/{name}` 验证的不是一个能返回 `200` 的单读接口，而是用户从真实 App 的 Settings → Resources → Memory 名册进入一条记忆后，能否看见完整的名称、描述和多语言多行正文，理解这是当前选中条目，并且服务端对不存在名、非法名和真实文件内容保持诚实。UI 详情页从已加载的权威名册 hydrate，单读 REST endpoint 另行直接验证；不把 UI 的 roster hydrate 冒充为一次隐藏的 `GET /memories/{name}`。

真实五通道 session 为 `/private/tmp/anselm-rig-ep190-memory-20260810/sessions/20260810-135706`，workspace=`ws_0d164dea5b031f88`，由 conductor 托管真实 Flutter macOS App、Computer Use、真实受管 `https://api.anselm.website`、三路独立 ssetap、backend/frontend journals、llmtap 和封口录屏；录屏 `120.555000s / 2784x1808 / 60fps`。真实路径建立 `deep-dive` 与 `quiet-note` 两条 memory，UI 名册展示两条，进入 `deep-dive` 后详情页稳定显示锁定 Name、Description 和完整中英文多行 Content；同一 session 的真实 REST `GET /memories/deep-dive`=`200`，未知 `ghost-note`=`404 MEMORY_NOT_FOUND`，非法 `Upper-Case`=`400 MEMORY_INVALID_NAME`。

静态审计确认后端 memory store 按 name 校验、读取对应 `<name>.md` 并返回文件 mtime，既有 `TestContractKnowledge_MemorySurface` 已覆盖 round trip、unknown、invalid、traversal、pin/unpin 和严格字段；前端详情诚实保留“从权威 roster hydrate、没有单独 repository getMemory 方法”的实现边界。定向 scenario、memory/store/handler Go tests 全部通过，`git diff --check` 干净。

五通道真相：SQLite/file store 中仅有预期的 `deep-dive.md` 与 `quiet-note.md`，正文包含标题、中文句子、列表和末行，REST 返回完整对象；notifications durable seq=`1..2` 单调，对应两条 memory created，纯 GET 没有 durable side effect，entities/messages 物理连接但没有虚构事件；llmtap 的 challenge/install/models 全为真实 `200`，本格不触发 completion，故不伪造模型调用；backend 无应用 WARN/ERROR/panic/fatal，frontend 无 Dart/Flutter/layout/runtime 红线，唯一 foreground launcher 行按既有规则归类为 VM 前 macOS 噪声。

逐帧与测量：名册到详情的稳定帧无裁切、字段丢失、重复行、残留 spinner、错位或跳变；原始录屏 30fps 固定解码，详情切换 `actionFrame=78` 后 `feedbackFrame=80`，可见反馈 `66.7ms`，稳定帧比较 `changedFrac=0`，满足 CODEX A1 的 `≤100ms`；transition changed box=`(1048,259)-(2393,950)`。正式按 `measure:memory-detail-purpose / F2 / A1 / C4 / G2` 写入 `COVERAGE EP-190=✓✓✓✓✓`；证据为 session 内 `EP-190-final-green.md`、`EP-190-api-db-sse.txt`、`EP-190-latency.txt`、`EP-190-frontend-terminal-review.md`，账本警报复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-190-ledger-alarm-reaudit.md`。

正式 ledger `1640→1645 judgments`，anchors=`10/10`；写账触发的 `gap-too-fast`、`discovery-collapse` 已依据独立 re-audit 逐条 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (1645 judgments)`，`gen_coverage.py --check`=`848 rows / 322 carried judgments / 0 tombstones`。EP-190 数据目录已按用户授权移入 Trash，formal ledger、session、录屏、journals、evidence 与测量复核目录保留。

EP-189 `GET /api/v1/memories` 验证的不是一个能返回 `200` 的列表接口，而是用户能否在真实 App 的 Settings → Resources → Memory 中看懂当前记忆名册，并可靠地区分加载、失败和真正的空列表；All/Pinned/Search 过滤应服务于用户意图，置顶/取消置顶必须让 UI、文件真相、REST 和通知流共同收敛。

真实五通道 session 为 `/private/tmp/anselm-rig-ep189-memory-20260810/sessions/20260810-133324`，workspace=`ws_5e398fa82e5059d9`，由 conductor 托管真实 Flutter macOS App、Computer Use、真实受管 `https://api.anselm.website`、三路独立 ssetap、backend/frontend journals、llmtap 和封口录屏；录屏 `268.238333s / 2784x1808 / 60fps`。真实路径建立 12 条 memory、3 条 pinned，在 UI 中观察 All=12、Pinned=3、Search=`workflow-goal`，随后真实 unpin→pin，最终 REST `pinned=true`。

本格首轮静态审计发现 Memory roster 用 `.value ?? []` 把 loading/error 伪装成空态，违反“错误不能冒充暂无数据”的产品语义；stop-and-fix 已改为 `AnLastGood` + active workspace reset key，补 skeleton、localized error、Retry 和 settled empty 分流，增加 8 项 settings widget 回归，并同步 `docs/references/frontend/features/settings.md`。定向 memory/store/handler Go tests 与 Flutter tests、`flutter analyze` 均通过。

五通道真相：文件型 memory store 真实存在 12 个预期 `.md` 文件，API all/pinned/unpinned 分别返回 12/3/9 且按 name 排序；notifications durable seq=`1..17` 单调，对应 12 created、3 次初始 pin、1 次 unpin、1 次最终 pin；entities/messages 物理连接但本只读名册路径没有 durable frame，未虚构事件；llmtap 的 challenge/install/models 全为真实 `200`，该 endpoint 不触发 completion，故不伪造模型调用；backend 无应用 WARN/ERROR/panic/fatal，frontend 无 Dart/Flutter/layout/runtime 红线，唯一 foreground launcher 行按既有规则归类为 VM 前 macOS 噪声。

逐帧与测量：All、Pinned、Search、pin transition 稳定帧均无裁切、重复行、残留 spinner、错位或跳变；30fps 固定解码测得名册反馈 `66.7ms`，Pinned/Search 反馈 `33.3ms`，均满足 CODEX A1 的 `≤100ms`。正式按 `measure:memory-roster-purpose / F2 / A1 / C4 / G2` 写入 `COVERAGE EP-189=✓✓✓✓✓`；证据为 session 内 `EP-189-final-green.md`、`EP-189-api-db-sse.txt`、`EP-189-latency.txt`、`EP-189-frontend-terminal-review.md`，账本警报复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-189-ledger-alarm-reaudit.md`。

正式 ledger `1635→1640 judgments`，anchors=`10/10`；写账触发的 `gap-too-fast`、`discovery-collapse` 已依据独立 re-audit 逐条 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (1640 judgments)`，`gen_coverage.py --check`=`848 rows / 321 carried judgments / 0 tombstones`。EP-189 数据目录按已授权删除，正式 ledger、session、录屏、journals 和 evidence 保留。

本批前置格的收口记录如下，当前判断以上 EP-190 整体重述为准。

EP-188 `DELETE /api/v1/attachments/{id}` 验证的不是一个孤立的 `204`，而是用户在真实 Composer 中移除一张已准备好的、尚未发送的图片后，画面、数据库、REST 和附件生命周期是否共同收敛。Computer Use 在真实 Flutter macOS App 中选取真实图片 `/private/tmp/ep186-cancel-slow3.jpg`，等待 `att_0e0b2e21ebf1104f` 进入 ready，再点击缩略图右上角的可见关闭触点；缩略图立即消失，Composer 只完成既有 empty-state 形变，没有 stale chip、死 spinner 或空白占位。

真实五通道 session 为 `/private/tmp/anselm-rig-ep188-rerun-20260810/sessions/20260810-130805`，workspace=`ws_a874dbf4461dcf47`，录屏由 `rig-down` 封口为 `359.475000s / 2784x1808 / 60fps`。backend journal 记录 upload `201`（`13:13:24.395 +0800`）、ready metadata `200`（`13:13:46.550 +0800`）和 DELETE `204`（`13:14:13.178 +0800`, `1ms`）；SQLite 对同一行留下 `deleted_at=2026-08-10 05:14:13.178006+00:00`。收台后用同一数据做 REST 复核，metadata、content 和重复 DELETE 均诚实返回 `404 ATTACHMENT_NOT_FOUND`，原始回执在 session evidence 中保留。

SSE witness 独立连接了 `notifications`、`entities`、`messages` 三条流并正常 EOF 收台；这是 attachment-only draft deletion，产品没有 lifecycle SSE 事件，故 durable frame 数为 0，不能虚构 SSE 消息。llmtap 真实记录受管网关 challenge/install/models 全部 `200`，本格不触发 chat completion，也不把空调用冒充模型证据。frontend terminal 没有 Dart/Flutter/RenderFlex/overflow/Unhandled/runtime 红线，唯一 `Failed to foreground app; open returned 1` 被保留并分类为 Flutter VM 启动前的已知 macOS launcher 噪声；backend 无应用 WARN/ERROR/panic/fatal/exception。

逐帧证据：`remove-frames-3325/0044.png` 仍有完整 ready thumbnail 与关闭触点，`0045.png` 为第一张移除后的变化帧。`measure latency` 输出 `feedbackFrame=44, latencyMs=16.7, changedFrac=0.00872, box=(1082,676)-(2366,940)`，满足 A1；后续约 340ms 是既有 Composer 形变收口，不是删除反馈延迟。L4 复核了 shared thumbnail/Composer/AnButton 几何、inset close control、无裁切和无高度跳变；L5 记录了可见触点、AX `Remove`、`AnButton.iconOnly -> AnInteractive` 的统一 tooltip/hover/focus 合同。证据明确说明没有单独保存 hover screenshot，不把未观察到的 hover 写成已观察事实。

正式按 `measure:attachment-delete-purpose / F2 / A1 / C4 / G2` 写入 `COVERAGE EP-188=✓✓✓✓✓`；formal ledger `1630→1635 judgments`，anchors=`10/10`。账本写入后的 `gap-too-fast` 与 `discovery-collapse` 依据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-188-ledger-alarm-reaudit.md` 独立重读原始五通道 journal、录屏、逐帧测量、数据库/REST 负向证据、frontend/LLM 状态和 anchors 后逐条 ack，未修改阈值、算法、法典、锚点或 gate；最终 `alarms.py check`=`clean (1635 judgments)`，`gen_coverage.py --check`=`848 rows / 320 carried judgments / 0 tombstones`。

EP-186 `POST /api/v1/attachments/{id}/preparation/cancel` 与 EP-187 `POST /api/v1/attachments/{id}/preparation/retry` 不是只看 `200` 的后台接口，而是 Composer 中用户面对大型图片 preparation 时能否保有控制感：等待必须有明确状态和可操作的 `Cancel media preparation`，取消后必须显示 `Media prep cancelled` 与 `Retry media preparation`，重试后回到准备态并最终交付真实图片 thumbnail。取消、重试、ready、失败和重复边界必须由 REST、SQLite、UI 和 SSE/日志共同解释，不能只因为请求成功就把产品判绿。

真实 App 首轮发现了红：旧实现只在约 8 秒内做 10 次 `800ms` 轮询，真实 backend preparation 需要约 17–22 秒；后端已经 `ready` 后，Composer 仍会永久停在 `Preparing media...`，这直接破坏用户目的。stop-and-fix 已将轮询改为持续追到服务端 terminal state：前 10 次每 `800ms`，之后每 `2s` 自适应退避；暂时的 metadata GET 失败不再永久终止轮询；进入长等待窗口时显示 `Still preparing media...`，取消/重试/释放时清理计数与定时器。对应增加长等待 widget 测试、取消/重试可见按钮断言、i18n 和 chat reference 文档；后端 media/handler 测试、Flutter 定向测试和 analyze 全绿。

真实五通道台架 session 为 `/private/tmp/anselm-rig-ep186-pollfix-20260810/sessions/20260810-123430`，使用真实 Flutter macOS App、Computer Use、真实受管网关、独立 messages/entities/notifications ssetap、backend journal、frontend terminal 和 llmtap。`att_948b33fc2427f981` 的真实 `38.7MB` 图片经历 upload `201`、可见 cancel、cancel `200`、可见 cancelled、retry `200`、重新进入 preparation；`att_94e6ee9c8250da4e` 的独立源图在前 10 次快速 GET 后继续以约 2 秒间隔轮询，直到 `12:40:59.572` 的 `ready`，不是靠 fixture 或手工改库冒充。录屏已由 `rig-down` 封口：`425.251667s / 2784x1808 / 60fps`，有效反馈帧保存在 session evidence 的 `cancelled.jpg`、`retrying.jpg`、`long-wait.jpg`、`ready.jpg`；逐帧确认取消文案、长等待文案、取消/重试控件和最终 thumbnail 均无死 spinner、裁切、跳变或 stale preparation label。

五通道交叉核验：backend journal 保留 upload、cancel、retry、连续 metadata poll 和最终 ready 的真实时序；SQLite/REST 最终 attachment 状态一致；三路 ssetap 均正常连接（该 attachment-only slice 没有聊天 durable frame，不能虚构 SSE 消息）；llmtap 没有模型调用，因为取消/重试 preparation 本身不应触发 LLM，`event=ready` 的空调用事实已记录；frontend log 只有已知 runner 的 `Failed to foreground app; open returned 1`，没有 DartError、FlutterError、RenderFlex、Unhandled 或 stack trace；backend journal 无 WARN/ERROR/panic/fatal/exception。L5 的 discovery 由真实可见 cancel/retry label 与稳定按钮承担。

正式按 `measure:attachment-preparation-purpose / F2 / A4 / C4 / G2` 分别写入 `COVERAGE EP-186=✓✓✓✓✓` 与 `EP-187=✓✓✓✓✓`；formal ledger `1620→1630 judgments`，anchors=`10/10`。账本写入后的 `gap-too-fast`、`pass-burst`、`discovery-collapse` 均依据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-186-187-ledger-alarm-reaudit.md` 独立重读原始五通道 journal、录屏、修复前红证据、测试和法典后逐条 ack，未修改阈值、算法、法典、锚点或 gate；最终 `alarms.py check`=`clean (1630 judgments)`，`gen_coverage.py --check`=`848 rows / 319 carried judgments / 0 tombstones`。

EP-186/187/188/189/190/191 的红证据、修复代码、定向测试、封口录屏与 formal re-audit 均保留；本批次当前 **35/50**，仍不跑统一长门禁、不提交，下一原子前线为 EP-192。P12 旅程 400+ 继续按用户裁定推迟二期，一期仍以 COVERAGE 矩阵为覆盖真相。

### 5.2 历史状态快照（EP-184，批次三十 50/50，统一门禁已关闭）

**历史前线（2026-08-10，清册 EP-184 已完成，批次三十由 45→50/50；本格完成音频短期 loopback 播放租约的真实用户闭环、五通道交叉核验、逐帧与时延复核、正式账本和统计警报复核；批次统一长门禁、完整 testend、专项回归、工作树审计均已通过；当时下一原子前线为 EP-185）。**
EP-184 `POST /api/v1/attachments/{id}/playback-lease` 验证的不是“能吐一个 URL”的内部端点，而是用户录音发送后能否继续完成真实产品目的：原生播放器不能携带 bearer header，因此服务端必须为**音频附件**签发受 workspace 约束、短期、opaque 的 loopback lease；Composer/transcript 的音频卡必须立即给出 `Loading audio...`，随后可 Play、Pause、Resume、显示时长和进度，并在自然结束后回到 Play。非音频、无 workspace、未知/过期 lease、软删附件均必须大声失败，不能把租约变成跨 workspace 的内容凭证。

静态 stop-and-verify 通过 attachment handler playback-lease tests、前端 audio-player/user-turn tests（20 项）和真实 black-box contract；矩阵覆盖 audio-only `415`、missing-workspace `401`、lease `200`、bearerless Range `206`、unknown token `404`、soft-delete 后旧 lease `404`。本格没有新增产品代码修复：前线复核确认现有 `busy` 状态与 `Loading audio...` 文案在 lease 请求前先进入 UI，避免用户等待时看到不可解释的静默或「不可播放」误导。

真实 App session 为 `/private/tmp/anselm-rig-ep184-20260810/sessions/20260810-102935`：全新 workspace `EP184 Audio Lease` 中，Computer Use 打开 Composer 的 `Record audio attachment`，真实录音至 `Recording audio attachment 00:07`，停止后生成 `M4A · 224.7 KB` chip，发送到真实受管 `https://api.anselm.website`，模型准确回 `EP184 audio ready.`；之后点击真实 `Play audio`，native player 走 lease + 两次 Range `206`，画面进入 `Pause audio`、`0:15` 和蓝色进度，暂停/恢复/自然结束均正确。录屏 `355.428333s / 2784x1808 / 60fps` 已由 rig-down 封口并可 ffprobe 读取。

五通道与真相：backend journal 实际记录 upload `201`、metadata `200`、lease `200/159 bytes`、playback `206/2 bytes` 与 `206/230059 bytes`；ssetap 独立连接 messages/entities/notifications，messages durable seq=`1..9` 单调，user close 携 `att_9e8cb7921746eba4`，touchpoint 为 `attached`，assistant close 为精确完成答复；llmtap 的 challenge/install/models/chat 全 `200`，真实媒体 chat body `63639` bytes 且无 base64，播放不虚构 LLM 或 entity mutation；frontend 仅有已经独立审阅的 Flutter AXTree bridge tooling churn，无 Dart/Flutter/layout/runtime 红线，收台监听归零。

逐帧与测量：蓝色 accent 对白对比度=`4.70:1`；播放卡的 progress region=`141x4`，play control=`56x56`，连续片段无跳变、裁切或不等高。原先以 backend lease 时间戳作为 action 的 `116.7ms/200ms` 读数被拒绝，因为本地 busy state 先于 HTTP 请求出现；以最后 ready 帧 `f0073` 到第一帧 `Loading audio...` 的真实可见边界测量，`measure latency`=`16.7ms`，changed box=`(1366,292)-(1732,336)`，满足 CODEX A1。证据为 session 内 `EP-184-final-green.md`、`EP-184-api-db-sse.txt`、`EP-184-llm-summary.txt`、`EP-184-frontend-terminal-review.md`、`EP-184-latency.txt` 和反馈帧条。

正式按 `measure:attachment-playback-purpose / F2 / A1 / C4 / G2` 写入 `COVERAGE EP-184=✓✓✓✓✓`；formal ledger `1610→1615 judgments`，anchors=`10/10`，`alarms.py check`=`clean (1615 judgments)`。写账触发的 `gap-too-fast`、`discovery-collapse` 已依据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-184-playback-lease-ledger-reaudit.md` 独立重读五通道原始 journal、录屏、静态测试、法条和锚点后逐条 ack，未改阈值、算法、法典、锚点或 gate；`gen_coverage.py --check`=`848 rows / 316 carried judgments / 0 tombstones`。

批次三十现已 **50/50**；根 `make verify`、完整 `make -C backend testend`、本批专项回归、anchors、alarms、coverage、gofmt、diff 和进程审计均已通过，批次门禁已关闭，下一动作是提交。EP-184 evidence、batch gate record 与 formal re-audit 保留，`/private/tmp/anselm-data-ep184-20260810` 已按授权移入 Trash。P12 旅程 400+ 继续按用户裁定推迟二期，一期仍以 COVERAGE 矩阵为覆盖真相。

### 5.2 历史状态快照（EP-183，批次三十 45/50）

**历史前线（2026-08-10，清册 EP-183 已完成，批次三十由 40→45/50；本格完成附件原始内容的真实字节、MIME、Range/条件请求和安全文件名契约，修复 stop-and-fix、真实 App 内容读取复核、五通道交叉核验、逐帧与时延复核、正式账本和统计警报复核；当时按用户裁定未满 50 格，不跑批次统一长门禁、完整 testend 或提交；下一原子前线当时为 EP-184）。**
EP-183 `GET /api/v1/attachments/{id}/content` 验证的不是一个“能返回文件”的内部端点，而是用户上传后预览、原生媒体 provider 读取、Range/seek 和缓存重验证时，服务端是否仍交付**原始且可解释的内容**：字节必须完整，MIME 必须保真，Unicode 与控制字符文件名不能破坏 header，软删后内容必须停止服务。该端点没有独立的 UI click target，discoverability 由 EP-181 的 Composer 附件入口承担，不能把 API-only 行伪装成有自己的 G2。

静态审计发现 `Content` 与 bearerless `PlaybackContent` 手工拼接 `Content-Disposition`，只移除引号，不能可靠处理 CR/LF、反斜杠、Unicode 等用户文件名。stop-and-fix 统一改为标准 MIME serializer；新增 handler 回归锁住完整字节、MIME、安全 Unicode+控制字符文件名、`Range` 206、`If-Modified-Since` 304；black-box contract 进一步锁住真实 upload 后的 200/206/304/416、软删后的 404 和标准库的可解释 invalid-range 文案，避免把标准 `ServeContent` 边界误判成产品错误。

真实 App 证据复用 `/private/tmp/anselm-rig-ep181-20260810/sessions/20260810-094431`：真实 Flutter macOS App、Computer Use、真实受管 `https://api.anselm.website` gateway、三路独立 ssetap、llmtap、backend/frontend journals 和 `2784x1808 / 60fps / 231.580s` 封口录屏中，实际发生过附件 content `200/1,111,731 bytes`，同一内容被 media provider 用于真实缩略图和多模态回合；不是用 upload 回执替代 content GET。黑盒 content contract 与既有 audio playback lease 回归均通过，前端 media provider/URI tests 通过。

五通道与数据真相：SQLite attachment 行、CAS blob、API metadata、content 字节和消息 attachment id 一致；ssetap 独立连接 messages/entities/notifications，messages durable seq 单调，attachment user close 与 content 读取属于同一真实回合；llmtap 记录相对 media lease、无 base64/绝对 host；backend 无应用 WARN/ERROR/panic/FATAL，frontend 除已知 launcher `Failed to foreground app; open returned 1` 外无 Dart/Flutter/RenderFlex/overflow/Unhandled/lost-device 红线。删除后的 REST/数据库状态和 content 404 共同证明软删没有继续泄露媒体。

逐帧与测量：有效 session 中附件缩略图、user card、composer action slot 和 assistant 排版稳定，连续解码 final window 无 diff 超过 `0.0005`，contrast=`8.86:1`；30fps action→visible feedback=`33.3ms`，黑盒 content GET 后端耗时=`0–3ms`。随机 seek 产生的 H.264 partial-frame 重建伪影按连续解码规则排除，不冒充产品抖动。L5 诚实记 `na`：原始内容 transport endpoint 无独立导航、菜单或键盘入口，发现性属于 EP-181 Composer，不虚造入口。

正式按 `measure:attachment-content-purpose / F2 / A1 / C4 / na` 写入 `COVERAGE EP-183=✓✓✓✓~`；formal ledger `1605→1610 judgments`，anchors=`10/10`。写账触发的 `gap-too-fast`、`discovery-collapse` 均按 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-183-content-ledger-reaudit.md` 独立重读原始五通道 journal、录屏、测试、法条和锚点后逐条复审并 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (1610 judgments)`；`gen_coverage.py --check`=`848 rows / 315 carried judgments / 0 tombstones`。

定向 `mise exec -- go test -count=1 ./internal/transport/httpapi/handlers ./internal/app/attachment`、平台 `TestContractDocsAtt_ContentRangeAndConditional` 与 `TestContractDocsAtt_AudioPlaybackLease`、frontend media tests、`gofmt`、anchors、alarms、coverage 和 `git diff --check` 均通过；真实台架已收台，监听归零。EP-183 evidence 与 formal re-audit 保留在 session/formal RIG，批次三十当前 **45/50**，还未到 50 格，不跑统一长门禁、不提交；下一原子前线为 EP-184。P12 旅程 400+ 继续按用户裁定推迟二期，一期仍以 COVERAGE 矩阵为覆盖真相。

### 5.2 历史状态快照（EP-182，批次三十 40/50）

**历史前线（2026-08-10，清册 EP-182 已完成，批次三十由 35→40/50；本格完成附件 metadata GET 的静态契约补强、真实 App 已发生的 metadata 读取复核、五通道交叉核验、逐帧与时延复核、正式账本和统计警报复核；当时按用户裁定未满 50 格，不跑批次统一长门禁、完整 testend 或提交；下一原子前线当时为 EP-183）。**
EP-182 `GET /api/v1/attachments/{id}` 验证的不是一个“返回一行 JSON”的内部读取，而是附件在真实产品生命周期中能否被稳定重建：上传回执之后、持久消息重放时、媒体 preparation 轮询期间，用户看到的 filename、MIME、kind、大小和 id 必须仍是后端真实行；图片 preparation 必须呈现真实状态，media worker 暂不可用时不能把附件 metadata 一并隐藏。

静态审计确认 handler 通过 workspace-scoped attachment service 取行，再由统一 response 投影附加 preparation sidecar；新增 handler 测试锁住 ready image 的 target、dimensions、MIME、size、updatedAt 全量投影，以及 preparation 失败时 HTTP `200` 仍保留 metadata、sidecar 明确为 `unavailable/MEDIA_PREPARATION_UNAVAILABLE`。独立 testend attachment REST 矩阵现在每次 upload 后真实 GET metadata，并逐字段比对 id、sha256、filename、mimeType、sizeBytes、kind；非图片必须诚实返回 `not_required/not_required`。软删后的 `404 ATTACHMENT_NOT_FOUND` 边界继续由同一黑盒矩阵锁住。

有效真实 session 复用 `/private/tmp/anselm-rig-ep181-20260810/sessions/20260810-094431`，因为该真实 Flutter App 生命周期实际发生了三次 `GET /api/v1/attachments/att_de36c7c54c9af7a7`，backend journal 分别记录 `200`（418、464、464 bytes），随后 content 读取为 `200/1,111,731 bytes`；不是把 upload 的响应冒充 GET 证据。该 session 使用真实 Flutter macOS App、Computer Use、真实受管 `https://api.anselm.website` gateway、三路独立 ssetap、llmtap、backend/frontend journals 和 `2784x1808 / 60fps / 231.580s` 封口录屏；EP-181 的有效附件缩略图、持久 user card、流式态和稳定完成态均由 GET metadata 支撑，未出现 stale filename、missing card 或 preparation 跳变。

五通道与数据真相：SQLite attachment 行、CAS blob、消息 attachment id 和 API metadata 彼此一致；ssetap 独立连接 messages/entities/notifications，messages durable `seq=1..9` 单调且 user close 携 attachment id；llmtap 记录同一附件进入真实受管多模态请求的相对 media lease、无 base64/绝对 host；backend 无应用 WARN/ERROR/panic/FATAL，frontend 除已知 launcher `Failed to foreground app; open returned 1` 外无 Dart/Flutter/RenderFlex/overflow/Unhandled/lost-device 红线。

逐帧与测量：附件缩略图、remove 控件、user card、composer action slot、assistant 行宽/间距/图标均稳定；连续解码 final window 无 diff 超过 `0.0005`，contrast=`8.86:1`；30fps action→visible feedback=`33.3ms`，backend metadata GET=`0–1ms`。随机 seek 产生的 H.264 partial-frame 重建伪影已按连续解码规则排除。L5 对该 API-only row 诚实记 `na`：它没有独立 click target 或导航入口，discoverability 归属于 EP-181 的 Composer 附件入口，不虚造 endpoint 自身的 G2。

正式按 `measure:attachment-user-purpose / F2 / A1 / C4 / na` 写入 `COVERAGE EP-182=✓✓✓✓~`；formal ledger `1600→1605 judgments`，anchors=`10/10`。五级写账后每次按机制打开的 `gap-too-fast`、`discovery-collapse` 均以 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-182-get-attachment-ledger-reaudit.md` 独立重读原始五通道 journal、录屏、测试、法条和锚点后逐条 ack，未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (1605 judgments)`；`gen_coverage.py --check`=`848 rows / 314 carried judgments / 0 tombstones`。

定向 `mise exec -- go test -count=1 ./internal/transport/httpapi/handlers ./internal/app/attachment ./internal/app/media`、平台 `TestContractDocsAtt_AttachmentRestAndCASDedup` 与 `TestContractDocsAtt_MalformedMultipartIsBadUpload`、handler `gofmt`、anchors、alarms、coverage 和 `git diff --check` 均通过；真实台架已收台，监听归零，EP-182 未新增专用数据目录。session、录屏、五路 journal、EP-182 evidence 和 formal re-audit 保留；批次三十当前 **40/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-183。P12 旅程 400+ 继续按用户裁定推迟二期，一期仍以 COVERAGE 矩阵为覆盖真相。

### 5.2 历史状态快照（EP-181，批次三十 35/50）

**历史前线（2026-08-10，清册 EP-181 已完成，批次三十由 30→35/50；本格完成真实附件上传、真实受管多模态回合、静态缺陷修复、定向测试、五通道交叉核验、连续录屏逐帧复核、正式账本和统计警报复核；当时按用户裁定未满 50 格，不跑批次统一长门禁、完整 testend 或提交；下一原子前线当时为 EP-182）。**
EP-181 `POST /api/v1/attachments` 验证的不是一个“上传返回 201”的后台动作，而是用户在真实 Composer 中点附件入口、选择本机图片、看到可理解的缩略图、输入任务并发送后，模型真的看见这张图、答案真的达成目的，且附件、消息、SSE 和后端状态共同持久化。

静态审计发现 upload handler 把损坏 multipart、非 multipart 和超大请求全部误报成 `ATTACHMENT_TOO_LARGE`，并且大 multipart 的临时文件没有明确清理。stop-and-fix 已改为只有 MaxBytesError 返回 `ATTACHMENT_TOO_LARGE`，其余格式错误返回 `ATTACHMENT_BAD_UPLOAD`，请求结束调用 `MultipartForm.RemoveAll`；新增 handler round-trip、malformed boundary、33 MiB 临时文件清理测试、black-box contract 和 attachment reference 同步。

有效真实 session `/private/tmp/anselm-rig-ep181-20260810/sessions/20260810-094431` 使用真实 Flutter macOS App、Computer Use、真实受管 `https://api.anselm.website` gateway、独立三路 ssetap、llmtap、backend/frontend journals 和 `2784x1808 / 60fps / 231.580s` 封口录屏。App 真实走过 paperclip → macOS file picker → `Preparing media...` → 图片缩略图 → 输入 prompt → 发送 → assistant 完成态；最终回答描述了画面中的人物、地图、地球仪、北极熊皮、模型船和日期。此前 `093951` session 因 stale Computer Use index 误关窗口，明确作为无效操作会话排除，不进入任何裁决。

五通道与数据真相：backend 的本地 `POST /api/v1/attachments`=`201`、metadata/content=`200`，content=`1,111,731` bytes；SQLite attachment 行、CAS blob、消息附件引用和三个 completed message block 一致，source JPEG 与远端 PUT body SHA-256 相同；ssetap 独立连接 notifications/messages/entities，messages durable `seq=1..9` 单调，user close 携 attachment id，touchpoint 和 auto-title 信号均落在正确流；llmtap 记录 proof challenge、media init、1,111,731-byte PUT、complete=`201`、multimodal chat=`200`，chat body 使用相对 media lease，不含 base64；backend 无应用 WARN/ERROR/panic/FATAL，frontend 只有已知 launcher `Failed to foreground app; open returned 1`，无 Dart/Flutter/RenderFlex/overflow/Unhandled/lost-device 红线。

逐帧判断：附件缩略图在 composer 内边界清楚，remove 控件可理解；发送后 user card 保留图文关系；生成中 stop 替换 send 且 composer 不跳位；完成后 microphone affordance 恢复，assistant 行宽、间距和操作图标稳定。连续解码的最终窗口无 diff 超过 `0.0005`；随机 seek 到 H.264 非关键帧产生的局部文字重建伪影已用连续解码和实时 Computer Use 帧排除，不能冒充产品 bug。`measure latency` 在 30fps 下 upload action→thumbnail feedback=`33.3ms`、send action→首个可见 feedback=`33.3ms`；`measure contrast`=`8.86:1`。证据为 session 内 `evidence/EP-181-final-green.md`、`EP-181-api-db-sse.txt`、`EP-181-llm-summary.txt`、`EP-181-frontend-terminal-review.md`、`EP-181-latency.txt`、四张稳定帧和封口录屏。

正式按 `measure:attachment-user-purpose / F2 / A1 / C4 / G2` 写入 `COVERAGE EP-181=✓✓✓✓✓`；formal ledger `1595→1600 judgments`，anchors=`10/10`。写账后的 `gap-too-fast`、`discovery-collapse` 均按 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-181-ledger-alarm-reaudit.md` 独立复审并逐次 ack，确认原始五通道 journal、SQLite/API 真相、真实视觉帧、连续解码测量、malformed/oversize/cleanup 负向边界和无效会话排除齐全；未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (1600 judgments)`。`gen_coverage.py --check`=`848 rows / 313 carried judgments / 0 tombstones`。

定向 `mise exec -- go test -count=1 ./internal/transport/httpapi/handlers ./internal/app/attachment`、平台 attachment contracts、handler `gofmt`、measure contrast/diff、anchors、alarms、coverage 和 `git diff --check` 均通过；EP-181 真实 App、backend、ssetap、llmtap、recorder 均已收台，监听归零。专用 `/private/tmp/anselm-data-ep181-20260810` 在证据封存和账本落定后按授权清理，正式 session、录屏、五路 journal、证据和 formal ledger 保留。批次三十当前 **35/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-182。P12 旅程 400+ 继续按用户裁定推迟二期，一期仍以 COVERAGE 矩阵为覆盖真相。

### 5.2 历史状态快照（EP-180，批次三十 30/50）

**历史前线（2026-08-10，清册 EP-180 已完成，批次三十由 25→30/50；EP-180 的静态审计、零部分删除修复、定向单测与平台 contract、真实 App/受管网关、逐帧复核、五通道交叉核验、逐次警报复核和台架收台均已通过；L5 对 API-only endpoint 诚实记 `na`，没有伪造前端入口；当时按用户裁定未满 50 格，不跑批次统一长门禁、完整 testend 或提交；下一原子前线为 EP-181）。**
EP-180 `POST /api/v1/conversations/{id}/sandbox-envs:reset-all` 验证的不是一个“返回 removed”的后台动作，而是用户需要一次清理某个 conversation 的全部 scratch environments 时，所有 idle runtime 都被删除、任何 resident/running environment 都在**任何删除发生前**阻止整批操作、重复执行幂等，并且另一个 workspace 即使知道 conversation ID 也不能读写。产品结果必须与 Settings → Sandbox → Conversations 的真实 roster、REST、SQLite、SSE deletion signals、LLM wire 和后端日志共同收敛。

静态审计发现原实现逐 env 删除：若排序靠前的 idle sibling 已经删除，后面的 running env 才报 `SANDBOX_ENV_IN_USE`，用户会得到失败响应但状态已经被部分改变。这是不可接受的产品/数据真相裂缝。修复新增 `DestroyOwners`：按稳定 owner 顺序取得所有锁，先完整预检所有 env，发现任一 `RunningPID > 0` 立即返回 `ErrEnvInUse` 且零 mutation，只有全量通过后才逐项销毁；handler 改为一次调用 batch service。新增 sandbox unit test 锁住“idle 在前、running 在后也不能部分删除”，平台 contract 同时覆盖 owned 全量删除、重复幂等、foreign 隔离和 partial-delete guard。

真实 session `/private/tmp/anselm-rig-ep180-20260810/sessions/20260810-091401` 使用真实 Flutter macOS App、Computer Use、真实受管 `https://api.anselm.website` gateway、独立三路 ssetap、llmtap、backend/frontend journals 和 `2784x1808 / 60fps / 451.906667s` 封口录屏。App 完成 onboarding 后经真实 gateway 聊天，精确显示 `EP180 gateway regression OK.`；因为当前产品没有可由用户直接制造 conversation scratch env 的 producer，本格的 reset-all 业务行使用**受控 SQLite fixture**物化两条 owned env，明确不把 fixture 当成产品入口。真实 API reset-all 返回 `removed=2`，随后 Settings 重新取数显示空态；再以 idle-first/running-second fixture 验证真实 endpoint 返回 `409 SANDBOX_ENV_IN_USE` 且两行都保留，清除运行 PID 后再次 reset-all 才返回 `removed=2` 并进入空态。

五通道与数据真相：owned list=`200` 两行，reset-all=`200 {removed:2}`，刷新 list=`200` 空数组，重复 reset-all=`200 {removed:0}`；resident guard=`409 SANDBOX_ENV_IN_USE`，SQLite 与 follow-up list 均确认两行未被部分删除；foreign workspace 的 list/reset-all 均为 `404 CONVERSATION_NOT_FOUND`，临时 workspace 已删除。ssetap 独立连接三条流，messages durable `seq=1..8` 单调，notifications durable `seq=2..6` 单调，其中四条为精确的 `sandbox.env_deleted`，ephemeral message delta 仍是 `seq=0`，没有被误当作耐久事实；llmtap 记录真实 gateway proof/install/models/chat 全 `200`；backend journal 与 REST/SQLite/SSE/UI 一致；frontend journal 除已知 launcher `Failed to foreground app; open returned 1` 外无 Flutter/Dart/RenderFlex/overflow/Unhandled/lost-device 红线。

逐帧判断：Settings roster 中两行均显示可读 conversation title、绿色健康点和 `0 deps · 0 B`，运行行明确显示 `running`，没有 `cv_*`/`se_*` opaque ID、残留删除项或不必要的 spinner；完成删除后画面进入稳定、可读的 `No environments` 空态。绿色状态点在 native frame 中各为 `13x13` 的连通区域，文本对比度实测 `8.86:1`；action→可见 projection feedback 两段测量均为 `100ms`，按 A1 的边界证据记录，不虚报为更快；稳定性窗口测量 changed fraction=`0.00682`。证据为 session 内 `evidence/EP-180-final-green.md`、`EP-180-api-db-sse.txt`、`EP-180-llm-summary.txt`、`EP-180-frontend-terminal-review.md`、`EP-180-latency.txt`、`EP-180-chat.png`、`EP-180-settings-rows.png`、`EP-180-settings-final.png` 和对应封口录屏。该具体 reset-all endpoint 没有独立 frontend client、click target 或 shortcut，故 L5 诚实记 `na`，Settings roster 只承担已连接产品面的 L4。

正式按 `G1 / F2 / A1 / C4 / na` 写入 `COVERAGE EP-180=✓✓✓✓~`；formal ledger `1590→1595 judgments`，anchors=`10/10`。每次写账后故意触发的 `gap-too-fast`、`discovery-collapse` 均按 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-180-ledger-alarm-reaudit.md` 独立复审并逐次 ack，确认五通道原始 journal、foreign negative path、全量删除、重复幂等、resident zero-mutation guard、API-only 边界和真实画面齐全；未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (1595 judgments)`。`gen_coverage.py --check`=`848 rows / 312 carried judgments / 0 tombstones`。

定向 `mise exec -- go test -count=1 ./internal/app/sandbox ./internal/transport/httpapi/handlers ./internal/infra/store/sandbox`、平台 `TestContractPlatform_SandboxGovernanceEdges`、`gofmt`、anchors、alarms、coverage 和 `git diff --check` 均通过；EP-180 真实 App、backend、ssetap、llmtap、recorder 均已收台，监听归零。专用 `/private/tmp/anselm-data-ep180-20260810` 在证据封存后按授权清理，正式 session、录屏、五路 journal、红绿证据和 formal ledger 保留，不把临时数据带进仓库。批次三十当前 **30/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-181。P12 旅程 400+ 继续按用户裁定推迟二期，一期仍以 COVERAGE 矩阵为覆盖真相。

### 5.2 历史状态快照（EP-154，批次二十八 35/50）

**历史前线（2026-08-09，清册 EP-154 已完成，批次二十八当时 35/50；按用户裁定未到 50 格，不跑批次统一长门禁、完整 testend 或提交）。**
EP-154 `POST /api/v1/conversations/{id}/messages` 已完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、窗口录屏、backend journal、三路独立 SSE witness、frontend console 和 llmtap 的五级验收。产品目的不是只得到一个 `202`，而是让用户在真实 Composer 中只附一张图也能完成一个完整回合：user 行先落库并回声，assistant 流式行打开并闭合，模型真实看见图片并返回可读答案；随后同一真实对话显式命中 `inspect_media`，在代理图超过受管网关 3 MiB 解码预算时诚实回退原图，不把上游 400 暴露给用户。

最终 session 为 `/private/tmp/anselm-rig-ep154-20260809/sessions/20260809-195358`，`screen.mov` 已由 rig-down 封口可读（`2784x1808 / 60fps / 432.191667s`），稳定终帧为 `accepted-frame.png`。Computer Use 真实走过附件菜单、macOS 文件选择器、`Preparing media...`、原图缩略图、发送、助手完成态以及第二轮 `inspect_media` 工具调用；最终 UI 有完整结构化表格、历史背景、操作行和可用 Composer，没有红色工具失败、死 spinner、重复错误、布局跳变或隐藏 CTA。

本场首个真实附件 session 曾抓到一条真实红线，保留在 `/private/tmp/anselm-rig-ep154-20260809/sessions/20260809-194419`：1,111,731-byte JPEG 的 model-default PNG proxy 为 5,238,623 bytes，网关返回 `BAD_REQUEST media exceeds the per-request decoded size limit`。stop-and-fix 将预算依据改为最终 staging bytes；受管图片 proxy 超预算但原图可交付时回退原图，`inspect_media` 同样使用该规则，proxy 与原图都不可交付时返回结构化 budget-degraded 说明而不是发出必败请求。定向 `internal/app/attachment`、`internal/app/tool/attachment`、`internal/bootstrap` Go tests 已通过。

五通道正式证据为 session 内 `evidence/EP-154-final-green.md`，SSE 汇总、DB 真相、LLM wire、前端终端复核和清理回执分别为 `EP-154-sse-summary.txt`、`EP-154-db-final.txt`、`EP-154-llm-summary.txt`、`EP-154-frontend-terminal-review.md` 与 `EP-154-fixture-cleanup.md`。三路 SSE 均物理连接；messages durable `seq=1..24` 单调，完整记录 attachment-only user echo、assistant close、`inspect_media` tool_call/tool_result 和最终 `message close`；notifications 观测到 conversation 创建与自动标题，entities 连接正常。SQLite 中四条 message 和九条 block 全为 `completed`，无 pending/streaming/error/cancelled 残留；工具结果含 `width=2560,height=1970` 与“proxy 超预算、改检原图”note。

backend journal 无应用 WARN/ERROR/panic/FATAL；frontend 只有已知 runner 启动器 `Failed to foreground app; open returned 1`，随后 Flutter resident 正常且无 Dart/Flutter/RenderFlex/overflow/Unhandled/lost-device 红线，启动器噪声被单独归类并保留。llmtap 的 challenge/install/models、两次图片 staging、primary chat、nested vision 和外层收尾均为 HTTP `200/201`，无 4xx/5xx 或 `BAD_REQUEST`。发送动作到首个可见反馈的 `testend/cmd/measure latency` 为 `100.0ms`，满足 CODEX A1；稳定终帧人工复核通过产品视觉标准。收台后 Flutter、后端、ssetap、llmtap、recorder、llama runtime 和监听均归零。

本场账本写入前 anchors=`10/10`，`alarms.py check`=`clean (1460 judgments)`；五级裁决 `G1/F2/A1/C4/G2` 已写入，中央账本由 `1460→1465 judgments`，`COVERAGE EP-154=✓✓✓✓✓`。写账后按机制打开 `gap-too-fast` 与 `discovery-collapse`；独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-154-messages-ledger-reaudit.md`，确认红线、修复链、五通道原始 journal、视觉测量和最终帧齐全后逐条 ack，未修改阈值、算法、法典、锚点或账本规则；最终 `alarms.py check`=`clean (1465 judgments)`。P12 旅程 400+ 继续按用户裁定推迟二期，一期仍以 COVERAGE 矩阵为覆盖真相。
当时下一原子前线为 EP-155 `GET /api/v1/conversations/{id}/messages`；批次二十八由 **30→35/50**，未到 50 格不跑统一门禁、不提交。

### 5.2 历史状态快照（EP-153，批次二十八 30/50）

**历史前线（2026-08-09，清册 EP-153 已完成，批次二十八当时 30/50；按用户裁定未到 50 格，不跑批次统一长门禁、完整 testend 或提交）。**
EP-153 `POST /api/v1/conversations/{id}/workdir:add-worktree` 已完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、窗口录屏、backend journal、三路独立 SSE witness、frontend console 和 llmtap 的五级验收。产品目的不是只执行一次 `git worktree add`，而是让用户在当前对话中发现并理解“平行工作树”这一能力，看到它会创建在仓库旁、绑定 `wt/<name>` 分支、把对话迁移到新的真实工作目录；冲突、非法名称和复用既有分支时都给出可行动结果，而不是接管或污染用户已有目录。

EP-153 真实 session 为 `/private/tmp/anselm-rig-ep153-20260809/sessions/20260809-190946`，`screen.mov` 已由 rig-down 封口可读（`2784x1808 / 60fps / 512.488333s`）。Computer Use 在真实 App 中打开 workdir 菜单，先看到当前 `Branch main`、`No uncommitted changes`、本地分支和既有 worktree；初始菜单较长，真实滚动后 Git 操作区和 `Open a worktree…` 可见，随后打开对话框。对话框明确说明平行 checkout、`wt/<name>` 命名、对话会迁移以及不会自动 commit/push；真实输入 `session` 并确认后，App、REST projection、外部 Git 和当前对话 residency 一致变为 `/private/tmp/ep153-repo.ZkdbHn-session` / `wt/session`。第二次用同一真实菜单和 REST 创建 `reopen`，成功复用预先存在但未被 checkout 的 `wt/reopen` 分支，App 刷新为 `/private/tmp/ep153-repo.ZkdbHn-reopen`；Worktrees 区正确列出其他工作树且不把当前项重复列入。两次 Composer 均经真实受管 gateway 精确返回 `EP153-ACK`、`EP153-REOPEN-ACK`。

REST/SQLite/fixture 交叉证据固定在该 session evidence：首次创建返回 200，路径为仓库旁的平面 sibling，branch=`wt/session`、`dirty=false`，外部 `git worktree list` 与 UI projection 一致；`taken` 冲突返回 409 `CONVERSATION_WORKTREE_EXISTS` 并给出具体阻挡路径 `/private/tmp/ep153-repo.ZkdbHn-taken`，碰撞目录 `SENTINEL.txt` 的 SHA-256 前后保持 `70e85898d13a5318b2a0c59dad361eb2d9cd5be94208b5b16a3e1c21cc31c4cb`。`../escape`、`/absolute`、`nested/deep`、`..`、`-b` 均返回 422 `CONVERSATION_INVALID_WORKTREE_NAME`；复用 `reopen` 返回 200 并新建 sibling worktree，不接管碰撞目录、不改变 main HEAD。第二次 residency 变化在已有 transcript 后落下恰好一个 `kind=workdir` marker；第一次空线程迁移不伪造 marker。最终 REST 与 SQLite 都保留七条消息块、marker、当前 workdir 和两次精确回复。

五通道正式证据为 `/private/tmp/anselm-rig-ep153-20260809/sessions/20260809-190946/evidence/EP-153-final-green.md`，SSE 汇总、DB 真相、前端统计、AX/终端复核和清理回执分别为同 session 的 `evidence/EP-153-sse-summary.txt`、`evidence/EP-153-db-final.txt`、`evidence/EP-153-frontend-stats.txt`、`evidence/frontend-terminal-review.md` 与 `evidence/EP-153-fixture-cleanup.md`。三路 SSE 均物理连接，messages 共 29 条记录、16 条 durable、max seq=`16`，notifications 共 6 条记录、4 条 durable、max seq=`4`，entities 已连接且本旅程无 durable entity event；llmtap proof/install/models/chat 全部 HTTP 200。backend journal 无应用 WARN/ERROR/panic/FATAL；frontend 只有启动器 `Failed to foreground app; open returned 1` 一行，随后 Flutter resident 正常、无 Dart/Flutter/RenderFlex/overflow/Unhandled/lost-device/panic/fatal，独立终端复核在 8 秒 idle 内零增长；该启动器噪声被单独归类，没有从证据中静默删除。收台后 Flutter、后端、ssetap、llmtap、recorder 和 8902/8903 监听均归零。

本场账本写入前，统计检查按机制打开 `gap-too-fast` 与 `discovery-collapse`；独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-153-conversations-add-worktree-ledger-reaudit.md`，anchors=`10/10` 后逐条 ack，写入前 `alarms.py check`=`clean (1455 judgments)`。五级裁决 `G1/F2/A1/C4/G2` 已写入，中央账本由 `1455→1460 judgments`，`COVERAGE EP-153=✓✓✓✓✓`。写账后统计警报按新 evidenceThrough 再次打开，第二次独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-153-post-judgment-alarm-reaudit.md`，anchors 仍为 `10/10`，逐条 ack 后最终 `alarms.py check`=`clean (1460 judgments)`；没有手改阈值、算法、法典、锚点或账本规则。定向 Go conversation/gitinfo/httpapi handler tests、Flutter workdir menu tests（23 项）、`gen_coverage --check`（848 rows / 285 carried / 0 tombstones）、`git diff --check`、`make -C docs verify` 已通过。所有 EP-153 临时 fixture 与隔离数据已在证据封存和裁决后按用户授权通过 `/usr/bin/trash` 移入 Trash，session 证据保留。P12 旅程 400+ 继续按用户裁定推迟二期，一期仍以 COVERAGE 矩阵为覆盖真相。
下一原子前线为 EP-154 `POST /api/v1/conversations/{id}/messages`；批次二十八由 **25→30/50**，未到 50 格不跑统一门禁、不提交。

### 5.2 历史状态快照（EP-146，批次二十七 45/50）

**历史前线（2026-08-09，清册 EP-146 已完成，批次二十七当时 45/50；未到 50 格，不跑统一长门禁、不提交）。**
EP-146 `DELETE /api/v1/conversations/{id}` 已完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、窗口录屏、backend journal、三路独立 SSE witness、
frontend console 和 llmtap 的五级验收。产品目的不是只返回一个 `204`，而是让用户能明确删除当前对话，删除后从 rail 和所有详情入口消失；其消息审计仍按 D1 保留，关系与触点不留下幽灵边，生成中的回合被安全取消，删除后应用仍能继续工作。

正式 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-160637`，由 conductor 归属 backend、SSE tap、LLM tap、Flutter runner 和录屏，`screen.mov` 已封口可读（`2784x1808 / 60fps / 678.315s`）。真实 App 从 More actions 打开确认对话框，确认后目标 `EP146 DELETE target` 立即从 rail 消失并回到可用空 composer；同一测试通过受管 gateway 发送带 function mention 和附件的消息，真实回复精确为 `EP146-ACK`。REST/SQLite 交叉证明删除头为 `deleted_at` 软删，GET/list/messages 均为 `404/不出现`，消息与 blocks 仍保留，relations 与 conversation_touchpoints 均清零；附件和 function fixture 不被错误级联删除。

关系路径又用真实 fork 验证：源对话到 fork 的 `create` relation 在删除 fork 后双向查询均为空，fork 头软删而消息审计仍在。随后真实受管长回合 `EP146 in-flight delete` 在 `isGenerating=true` 时从 App 删除，assistant 终态为 `cancelled`，取消后的部分 durable 文本不丢失；删除后新建 `EP146 post-delete health` 并得到精确 `EP146-POST-OK`，证明取消没有毒化 conversation queue 或后端。重复删除、missing id、跨 workspace、普通/生成中状态和删除后详情入口均纳入矩阵。

五通道证据包括非空 `manifest.json`、`backend.log`、`sse.jsonl`、`frontend.log`、`llm.jsonl` 和上述已封口录屏；三路 SSE durable 序列均连续，notifications 观测到 `conversation.deleted`，messages 观测到取消回合的 assistant block/message close；llmtap 的 challenge、install、models、两次 chat completion 均为 `200`，真实请求体和上游响应均留存。backend/frontend 没有 panic、FATAL、未处理 Flutter/Dart/RenderFlex/overflow 红线；取消瞬间唯一的 `incremental block persistence failed: context canceled` 已逐行复核为可选增量写入与删除取消竞态，detached finalizer 随后成功完整落盘，故保留为可解释的预期取消噪声，不隐藏也不改阈值。启动包装器的已知 `Failed to foreground app; open returned 1` 仍单独分类。

正式绿证据为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-160637/evidence/EP-146-final-green.md`，独立账本复审为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-146-conversations-delete-ledger-reaudit.md`；裁决 `G1/F2/A1/C4/G2` 已写入，账本由 `1420→1425 judgments`，
`COVERAGE EP-146=✓✓✓✓✓`，anchors `10/10`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已按独立复审逐项 ack，原阈值、算法、法典和锚点未变，最终 `alarms.py check`=`clean (1425 judgments on record)`。

定向 conversation/chat/store/relation/touchpoint/httpapi 验证、`python3 testend/rig/gen_coverage.py --check`（848 rows / 278 carried judgments / 0 tombstones）、`make -C docs verify`、
`git diff --check` 均通过。EP-146 临时数据目录按用户授权通过 `/usr/bin/trash` 移入 Trash，formal session、录屏、journals、红绿证据和账本保留；P12 旅程 400+ 仍按用户裁定推迟二期，一期以 COVERAGE 矩阵为覆盖真相。批次二十七由 **40→45/50**；未到 50 格不跑统一长门禁、不提交。
下一原子前线为 EP-147。

### 5.2 历史状态快照（EP-142，批次二十七 25/50）

EP-142 `POST /api/v1/conversations` 的五级验收、REST 边界、真实 App 创建/首条消息/自动标题、五通道证据、fixture Trash、账本 `1400→1405` 和警报复审已在
`LOG.md` 及其 session evidence 中封存；本快照保留其当时前线，当前推进以本节 EP-144 整体重述为准。

### 5.2 历史状态快照（EP-141，批次二十七 20/50）

**历史前线（2026-08-09，清册 EP-141 已完成，批次二十七当时 20/50；未到 50 格，不跑统一长门禁、不提交）。**
EP-141 `POST /api/v1/documents/{id}:iterate` 已按完整产品目的完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、窗口录屏、backend journal、
三路独立 SSE witness、frontend console 和 llmtap 的五级验收。产品目的不是只返回一个 `202`，而是让用户能从 Library 文档行的 More actions 找到 `Edit with AI`，
进入带当前文档 mention 的持久 Chat 对话，用自然语言提出精确修改，并看到真实文档被修改；标题、description、tags、Promise heading 和子页必须保持不变，
空请求、坏输入、目标不存在和缺 workspace 必须给出真实错误且不产生幽灵 conversation。

EP-141 的独立 REST/SQLite/SSE 矩阵固定在 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-131242` 的
`evidence/EP-141-rest-boundary-matrix.jsonl`：有效请求真实返回 `202` 并创建 conversation，模型随后真实调用 `read_document` 和 `edit_document`；空/空白请求为
`400 EMPTY_ITERATE_REQUEST`，请求类型/坏 JSON 为 `400 INVALID_REQUEST`，缺文档为 `404 DOCUMENT_NOT_FOUND`，缺 workspace 为 `401 UNAUTH_NO_WORKSPACE`，所有负向
均无幽灵文档或 conversation 行。REST 有效编辑只改变目标正文首句，子页、description 和 tags 与 SQLite/REST 真相一致。

首轮产品走查发现后端 endpoint 已存在，但 Library 行菜单没有 affordance，用户无法发现能力；stop-and-fix 增加 `LibraryRepository.iterateDocument` 的 live 请求、
fixture 同语义、行级 `Edit with AI` 菜单、中文/英文文案、精确 Dio wire test、真实 widget journey test 和 Library reference 文档。真实 App 通过
Library → More actions → Edit with AI 进入 Chat，自动种下 `Help me edit “Product Brief UI” with AI.`；随后提出具体句子修改，模型只编辑目标 id，
Activity 显示 `1 touched / Edited`，回到 Library 后正文、标题、description、tags、Promise heading、Path、size 和 outline 均正确。菜单终帧含 Rename、Duplicate、
Edit with AI、Delete；中途 `Untitled` 是返回 Library 后尚未选择文档的正常空选区，不是数据丢失，之后两帧稳定终态逐像素一致。

最终真实 App session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-131242` 的 backend D1 为 `:8742`/PID `48325`，ssetap PID `48339`，
llmtap `:8788`/PID `48301`，Flutter runner `48341`，窗口 recorder `48961`；rig-down 后进程组和监听端口归零。录像封口为 H.264 `2784x1808 / 60fps /
409.856667s`，messages/entities/notifications 三流均连接；backend 无应用 `WARN/ERROR/panic/FATAL`，frontend 无 Dart/Flutter/Unhandled/RenderFlex/overflow 红线。
Flutter runner 的一次 `Failed to foreground app; open returned 1` 发生在启动阶段，随后 App 正常 resident，已作为 runner 提示而非产品错误记录。llmtap wire 确认真实
gateway readiness、文档 mention、精确编辑请求、工具调用和最终确认一致。

封口证据为 session 内 `evidence/EP-141-document-iterate-final-green.md`，临时 fixture 清理回执为同 session 的 `evidence/EP-141-fixture-cleanup.md`，
独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-141-document-iterate-ledger-reaudit.md`；临时数据已按用户授权移入 macOS Trash，
正式 session、录像、journal、矩阵和证据均保留。最终稳定画面 `395→405` 经 `measure compare` 为 `changedFrac=0, pass=true`。

正式账本由 `1395→1400 judgments`，五级法条为 `G1/F2/A1/C4/G2`，`COVERAGE EP-141=✓✓✓✓✓`；anchors `10/10`。写账后 `gap-too-fast` 与
`discovery-collapse` 按原阈值打开，独立复审确认真实 409 秒录像、五通道 journal、正负向 REST 矩阵、stop-and-fix 证据、视觉测量和定向测试齐全后 ack，未修改
阈值、算法、法典或锚点；最终 `alarms.py check`=`clean (1400 judgments on record)`，`gen_coverage.py --check`=`848 rows / 273 carried / 0 tombstones`。
P12 旅程 400+ 扩写仍按用户裁定推迟二期，一期以 COVERAGE 矩阵为覆盖真相。

定向 Flutter Library/repository `57` tests、backend `aispawn/document/httpapi` 选择性回归、testend document iterate contract、`git diff --check`、
`anchors.py check`、`alarms.py check` 和 `gen_coverage.py --check` 均通过。批次二十七由 **15→20/50**；未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-142
`POST /api/v1/conversations`。

### 5.2 历史状态快照（EP-140，批次二十七 15/50）

**历史前线（2026-08-09，清册 EP-140 已完成，批次二十七当时 15/50；未到 50 格，不跑统一长门禁、不提交）。**
EP-140 `POST /api/v1/documents/{id}:duplicate` 已按完整产品目的完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、窗口录屏、backend journal、
三路独立 SSE witness、frontend console 和 llmtap 的五级验收。产品目的不是只返回一个 `201`，而是让用户能从 Library 的行级 More actions 找到 Duplicate，
得到一棵拥有新 ID、正确父子关系和路径的完整副本，保留正文/描述/标签/wikilink 出边，并在复制后立即打开新根，不用猜副本去了哪里；空 body/`parentId:null`
按源同级放置并自动根名去重，显式 `parentId` 放到指定父级，坏输入、缺源、缺父和缺 workspace 必须给出真实错误且不产生幽灵成功。

EP-140 的独立 REST/SQLite/SSE 矩阵固定在 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-124218`：覆盖根级同级复制、显式父级、空 body、
`{parentId:null}`、嵌套源、显式后代父级，以及 missing source/parent、空父、坏 JSON、unknown field、缺/错 workspace；成功响应均为 `201`，负向为预期的
`404/422/400/401`。结构证据确认每个节点都是新 ID，`parentId/path/position` 正确重映射，正文、description、tags 和深层孙节点完整保留；关系证据确认
复制出的 wikilink 出边使用新 relation ID。接口真实边界也写明：逐节点写入，不宣称跨整棵子树原子。

为避免测试环境撒谎，fixture repository 的 duplicate 从浅复制改为与 live service 同语义的 BFS 深拷贝：新 ID、根名去重、目标父级、路径、位置和全部 metadata
均覆盖；backend tests 增加显式父级、metadata、子孙和 wikilink relation 回归。API 与 Library reference 同步记录 `201`、空父语义、深拷贝字段和非原子边界。
这轮没有发现 live backend duplicate 的产品源代码红；真正修复的是测试 fixture 与线上契约不一致这一测试基础设施缺陷。

最终真实 App session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-124808` 从干净 fixture 起步。Computer Use 通过 More actions → Duplicate 创建
`Duplicate Source 2`，新根自动打开；再进入 `Child One` 和 `Grandchild`，逐页确认 body、description、tags、breadcrumb、Path、size、modified 和层级均正确。
侧栏树即时出现完整复制子树，画面无路径滞后、裁剪、光标跳变或未解释布局红线；notifications 只收到该 UI duplicate 的一个 durable
`document.created`（seq=1）。

最终五通道 session 的 backend D1 为 `:8895`/PID `44395`，ssetap PID `44412`，llmtap `:8795`/PID `44369`，Flutter runner `44414`，窗口 recorder `44811`；
rig-down 后录像封口为 H.264 `2784x1808 / 60fps / 458.446667s`，监听端口和进程均归零。messages/entities/notifications 三流均连接，backend 无
`WARN/ERROR/panic/FATAL`，frontend 无 `Unhandled exception/FlutterError/Lost connection/RenderFlex/overflow`；确定性 duplicate 不虚构 LLM completion，gateway
challenge/install/models 的真实 wire 证据保留在 setup session `.../124107`。

封口证据为 session 内 `evidence/EP-140-document-duplicate-final-green.md`，fixture 清理回执为同 session 的 `evidence/EP-140-fixture-cleanup.md`，独立账本复审为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-140-document-duplicate-ledger-reaudit.md`；临时数据已按用户授权提交 macOS Trash，正式 session、录像、journal、
矩阵和证据均保留。

正式账本由 `1390→1395 judgments`，五级法条为 `G1/F2/A1/C4/G2`，`COVERAGE EP-140=✓✓✓✓✓`；anchors `10/10`。写账后 `gap-too-fast` 与
`discovery-collapse` 按原阈值打开，独立复审确认最终 458 秒录像、五通道 journal、负向 REST 矩阵和逐页 Computer Use 证据齐全后 ack，未修改阈值、算法、法典
或锚点；最终 `alarms.py check`=`clean (1395 judgments on record)`，`gen_coverage.py --check`=`848 rows / 272 carried / 0 tombstones`。P12 旅程 400+
扩写仍按用户裁定推迟二期，一期以 COVERAGE 矩阵为覆盖真相。

定向 backend document/handler/store Go tests、Library + live-metrics Flutter `60` tests、fixture `dart format`、`gofmt`、`make -C docs verify`、
`gen_coverage.py --check` 和 `git diff --check` 均通过。批次二十七当前由 **10→15/50**；未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-141
`POST /api/v1/documents/{id}:iterate`。

### 5.2 历史状态快照（EP-139，批次二十七 10/50）

**历史前线（2026-08-09，清册 EP-139 已完成，批次二十七当时 10/50；未到 50 格，不跑统一长门禁、不提交）。**
EP-139 `POST /api/v1/documents/{id}:move` 已按完整产品目的完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、窗口录屏、backend journal、
三路独立 SSE witness、frontend console 和 llmtap 的五级验收。产品目的不是只返回一个 `200`，而是让用户能在 Library 里把文档移到根级或嵌套父级、
在同级上下缘重排、保留整棵后代子树，并且不重新选择页面就能从树、面包屑、正文和右岛 Path/Modified 看懂最终位置；非法位置、自落、成环和越界必须在
mutation 前拒绝，重复同槽移动必须是真 no-op。

首轮真实红 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-115232` 发现负数/过大 position 被静默接受并发布移动，红证据
`evidence/EP-139-document-move-red-negative-position.md` 永久保留、不计绿。stop-and-fix 增加 `DOCUMENT_INVALID_POSITION`，将显式位置收紧为目标同级
插入下标 `0..N`（含末位），校验在任何写入/发布前完成；随后又补出同父同解析位置的 no-op 守卫，保持 `updatedAt`、顺序和 SSE 不变。后端补充 invalid/no-op
单测，Document domain/API/error/events/endpoints 文档同步。

固定版本又在真实拖拽中抓到右岛 Path 比树和面包屑落后一拍；修复后 Inspector 从最新 tree row 取结构元数据、正文 provider 继续冻结保光标，并补 Library widget
regression。五通道重跑进一步抓到 Inspector `Modified` 把编辑器首次载入的 live seed 时间当成持久修改时间；修复为 seed 只提供字数/大小，真实编辑才可乐观提供本地时间，
且后端较晚持久时间优先；补 `documentInspectorUpdatedAt` 守卫和文档说明。这个问题也已在最终真实画面中确认不再出现。

最终 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-122441` 使用新 binary 从既有 EP-139 树开始。Computer Use 真实操作：选中
`Source Section`，拖到 `EP139 Beta` 根级，再拖回 `Destination Section`；两次均同时看到侧栏层级、面包屑、正文、右岛 Path 一致，最终 Path 为
`/EP139 Beta/Destination Section/Source Section`，`Deep Context` 仍挂在其下，正文 `## Source`、tags 和 description 未变，Modified 与持久时间显示为
`12:26`。另以 REST 重跑显式 `position:0` 与省略 position 的 append no-op，`updatedAt`、path、position 和通知数均不变。

独立 REST/SQLite/SSE 矩阵覆盖根↔嵌套、显式 0、inclusive end position、同父重排、nil parent、nil position append、后代 path/content/tags 保留，以及负数/越界/
浮点/布尔/数组/字符串 position、自落、成环、missing parent/document、坏 JSON、缺/错 workspace、unknown action。最终 SQLite/REST 同真：
`doc_1942443aabe8b4eb.parent_id=doc_b16767da037811f4`、`position=0`、path 为最终深路径。

最终 session 的 backend D1 为 `:8894`/PID `38988`，ssetap PID `39015`，llmtap `:8829`/PID `38951`，Flutter runner PID `39023`，窗口 recorder PID `39524`；
`rig-check` 在操作前、操作中、收台前均五通道全绿，rig-down 后进程组和监听端口归零。录屏 `176.760000s / 2784x1808 / 60fps`；SSE 三流均连接，
notifications durable 只有真实两条 `document.moved` 且 seq `[1,2]` 单调；backend 250 行无应用 WARN/ERROR/panic/FATAL，frontend 18 行无 Flutter/Dart/overflow/
Unhandled 红线；llmtap 记录 readiness，确定性 move 不虚构 completion。封口证据为 session 内 `evidence/EP-139-document-move-final-green.md`，独立账本复审为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-139-document-move-ledger-reaudit.md`，稳定画面抽帧也保留在 session evidence。

正式账本由 `1385→1390 judgments`，五级法条为 `G1/F2/A5/C4/G2`，`COVERAGE EP-139=✓✓✓✓✓`；anchors `10/10`。写账后 `gap-too-fast` 与
`discovery-collapse` 均按原阈值真实打开，独立复审确认红证据、修复链、五通道原始 journal 和最终帧齐全后 ack，未修改阈值、算法、法典或锚点；最终
`alarms.py check`=`clean (1390 judgments on record)`，`gen_coverage.py --check`=`848 rows / 271 carried / 0 tombstones`。P12 旅程 400+ 扩写仍按用户裁定
推迟二期，一期以 COVERAGE 矩阵为覆盖真相。

定向 backend document/handler/store Go tests、Library + live-metrics Flutter `59` tests、`gofmt`、`make -C docs verify` 和 `git diff --check` 均通过。
批次二十七当前由 **5→10/50**；未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-140 `POST /api/v1/documents/{id}:duplicate`。

### 5.2 历史状态快照（EP-138，批次二十七 5/50）

**历史前线（2026-08-09，清册 EP-138 已完成，批次二十七当时 5/50；未到 50 格，不跑统一长门禁、不提交）。**
EP-138 `DELETE /api/v1/documents/{id}` 已完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、窗口录屏、backend journal、
三路独立 SSE witness、frontend console 和 LLM wire 的五级验收。产品目的不是只得到一个 `204`，而是让用户能从 Library 找到删除入口、理解级联后果、
先取消不产生副作用，确认后整棵子树消失；另一个视图删除打开页或祖先时，当前编辑器不能继续伪装成可写，必须回到干净草稿并明确说出页面已删除。

固定 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-112205` 从真实 onboarding 起步。首轮构造树覆盖根、子、双孙、兄弟和 link
关系；真实 App 打开根页，More actions 显示 Rename/Duplicate/Delete，确认框显示 `Delete this page?` 及
`“EP138 Delete Root” and everything nested inside it will be removed.`；先点 Cancel，选中页、正文、树和 inspector 均保持不变，再确认 Delete，
页面从 rail 消失、右侧详情卸载、中心回到 `Untitled` 空白草稿。此路径没有产品源代码红，不把确认框或 204 单独冒充完整通过。

独立 REST/SQLite/SSE 矩阵确认 DELETE 的真实语义：根、子、双孙、兄弟全部 `GET=404 DOCUMENT_NOT_FOUND`，重复删除和未知 id 均 `404`；软删主行
保留 tombstone，子树共享删除时刻，live relation count 为 `0`；删除后用相同名字重新创建得到新的 `201`。跨 workspace 目标文档在其自身 workspace
读为 `200`，从当前 workspace 删除为 `404`，没有跨隔离删写。打开子页后外部删除祖先，经过权威 tree resync 触发 `This page was deleted`，14 个 120ms
采样从第 2 帧开始观察到提示，随后回到空白草稿；这不是静默跳转。

正式绿证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-112205/evidence/EP-138-document-delete-final-green.md`，
AXTree 独立复核为同 session 的 `evidence/frontend-ax-review.md`，统计警报独立复核为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-138-document-delete-ledger-reaudit.md`，清理回执为同 session 的
`evidence/EP-138-fixture-cleanup.md`。原始 fixture 构造时有两次 shell JSON 传参错误，均只产生 `422`、无幽灵写入，按台架问题分类，没有伪造产品红。

五通道收台：backend D1 归属到 `:8892`（PID `28732`），无应用 WARN/ERROR/panic/fatal/exception；ssetap 独立连接
messages/entities/notifications，三流均有连接记录，notifications durable seq `1..18` 单调且包含 created/deleted 与
`relation.dependency_broken`；channel 5 真实 upstream 为 `https://api.anselm.website`，challenge/install/models 全 HTTP `200`，本确定性 DELETE
不虚构 completion；Flutter console 无 Dart/Flutter/RenderFlex/overflow/unhandled/concurrent-modification/lost-device 红线。日志中的固定格式
macOS Flutter AXTree stale-node 行只在 `frontend-ax-review.md` 中按既有 tooling 规则复核，最后静置 3 秒不再增长；未知 AX 形状仍 fail-closed。
窗口录屏已封口为 H.264 `1025.690000s`，进程组归零。

正式账本由 `1380→1385 judgments`，五级法条为 `G1/F2/A5/C4/G2`，`COVERAGE EP-138=✓✓✓✓✓`；anchors `10/10`，两条统计警报按原阈值触发后
独立复审并 ack，最终 `alarms.py check` 为 `clean (1385 judgments on record)`；阈值、算法、法典和锚点均未改。`gen_coverage.py --check` 为
`848 rows / 270 carried / 0 tombstones`。`check_journeys.py` 仍按 P12 裁定报告一期路线未认领清册行；400+ 路线扩写是二期工作，一期主循环以
COVERAGE 矩阵为覆盖真相，不以此阻塞。

EP-138 无产品源代码修复，仅执行 backend/frontend/database/REST/SSE/Computer Use 五级验收。正式批次二十七从 **0→5/50**，未到 50 格不跑统一长门禁、
不提交；下一原子前线为 EP-139 `POST /api/v1/documents/{id}:move`。

### 历史状态快照（EP-125，批次二十五 40/50）

EP-125 `GET /api/v1/mcp-servers/{name}/stderr` 已完成真实 stdio MCP bounded-tail 验收：300 条长噪声不撑爆详情页，终帧显示
`show 4269 earlier lines` 与最新 marker，REST `data.size=262144` 命中 256 KiB 上限，unknown server 为 `404`。固定绿 session
为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-061239`，录屏 `375.708333s / 2784x1808 / 60fps`，正式账本
`1315→1320`，证据与清理回执均保留；当前前线以 EP-126 整体重述为准。

### 历史状态快照（EP-119，批次二十五 10/50）

**当前前线（2026-08-09，清册 EP-119 已完成，批次二十五 10/50）。**
EP-119 `DELETE /api/v1/skills/{name}/files/{path...}` 已完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、
窗口录屏、backend journal、三路独立 SSE witness、frontend console 和 LLM wire 的五级验收。产品目的不是只得到一个
`204`，而是用户在 Library 删除附属文件后，确认语义、文件树、当前预览、后端真相和 SSE 事件全部收口；嵌套路径可删，
`SKILL.md` 清单受保护，重复删除和跨客户端竞态必须给出可理解的下一步。

首轮真实 App 竞态路径冻结为红：REST 先删除 `references/keep.md` 后，App 仍显示旧预览和幽灵文件行；用户再点击删除收到
`404 SKILL_FILE_NOT_FOUND`，旧 UI 只显示泛化的 `Action failed`，没有刷新也没有离开失效预览。stop-and-fix 在
`_SkillFilesGroup._deleteFile` 为所有 API 失败刷新文件树；对 `SKILL_FILE_NOT_FOUND` 回到 skill 概览并显示“文件已被删除、
列表已刷新”，其他失败显示带路径的重试文案。新增错误常量、中英文文案和 stale-delete widget 回归后，用最终 binary
重跑正负路径。

固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-043659` 完成真实 onboarding、受管免费档
provision、附属文件和嵌套文件删除、取消确认、`SKILL.md` manifest 保护、重复删除及外部先删竞态。最终真实列表只有
`SKILL.md`（164 bytes）和 `scripts/run.py`（39 bytes）；终帧 `evidence/EP-119-final.png` 显示 skill 概览、`2 files`、
无幽灵行，完整审计证据为该 session 下的 `evidence/EP-119-skill-file-delete-final-green.md`。

五通道收台：录屏 `364.575000s`；backend D1 归属到 `:8864`，创建 `201`、两次 App 删除 `204`、manifest 保护 `400`、
竞态/重复删除 `404`、最终列表 `200`，无应用 panic/FATAL/ERROR/WARN；SSE 三流均连接，notifications durable seq `1..8`
单调并覆盖 create、seed、两个 App delete 和竞态 delete；frontend 无 Dart/FlutterError/RenderFlex/overflow/Unhandled/
lost-device 红线，AX 观察确认框、失效提示和最终文件树一致。managed gateway challenge/install/models 全 `200`，本格是
确定性文件路径，不伪造模型 completion。

正式账本由 `1285→1290 judgments`，五级法条为 `G1/F2/A1/C4/G2`，anchors `10/10`，`COVERAGE EP-119=✓✓✓✓✓`；独立
账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-119-skill-file-delete-ledger-reaudit.md`。集中写账打开的
`gap-too-fast` 与 `discovery-collapse` 已按原阈值独立复审并 ack，最终 `alarms.py check`=`clean (1290 judgments on record)`，
未改阈值、算法、法典或锚点。临时数据目录按用户授权以 `trash` 清理，记录在
`sessions/20260809-043659/evidence/EP-119-fixture-cleanup.md`；正式 session、录屏、journals 和账本保留。

批次二十五由 **0→10/50**。本批未满 50 格，不跑统一长门禁、不提交；下一原子前线为 EP-120
`GET /api/v1/mcp-servers`。

### 历史状态快照（EP-116，批次二十四 45/50）

EP-116 `GET /api/v1/skills/{name}/files` 已完成真实 Flutter App、真实受管 gateway、Computer Use 和五通道验收。真实
Library 显示 `Files 3`、`SKILL.md`、`references/live.md`、`references/seed.md`，公开响应不泄漏 provenance sidecar；未知
skill 为 `404`，缺 workspace 为 `401`，删除专用 skill 后 `204→404` 且 App 诚实回到 `Untitled`。固定绿 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-022720`，正式账本 `1270→1275 judgments`，`COVERAGE EP-116`
`✓✓✓✓✓`，独立复审后 alarms clean。批次当时 **45/50**；当前前线以 EP-117 整体重述为准。

### 历史状态快照（EP-115，批次二十四 40/50）

**历史前线（2026-08-09，清册 EP-115 已完成，批次二十四 40/50）。**
EP-115 `POST /api/v1/skills:install` 已完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、窗口录屏、
backend journal、三路独立 SSE witness、frontend console 和 LLM wire 的五级验收。产品目的不是返回一个 `200`，而是
用户从 source 预览后只安装新的合法 skill，Library、正文、文件树、provenance、信任门与后端实际写入保持同一真相；
已有 skill 的 no-force 重放不覆盖，force 才能完整替换。

固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-021859` 中，真实 App 从预览选择
`ep115-new`，已有 `ep115-existing` 显示 installed 且不可选，`broken-one` 显示解析失败且不可选；安装后 rail 出现
新 skill，中心显示正文、2 个文件、allowed-tools、provenance 和 `Pre-approval pending`。REST 进一步证明 no-force
existing 为明确 `skipped`、force 返回 `installed` 并把 existing 切到 v2 正文和 replacement 文件；坏候选和新 skill 重放
均只 skip。删除专用实体后 REST `204→404`，App 收到 durable delete 并清掉当前选中详情，回到 `Untitled`。

五通道收台：录屏 `246.440000s / 2784x1808 / 60fps`；backend 无 panic/fatal/error，三条 expected skip WARN 已逐项解释；
SSE durable seq `16..20` 单调，只有 setup create、App create、force update 和 cleanup deletes；frontend 无 Dart/Flutter/
RenderFlex/Unhandled/overflow 红线；managed gateway challenge/install/models 全 `200`。正式账本由 `1265→1270 judgments`，
五级法条为 `G1/F2/A5/C4/G2`，anchors `10/10`，`COVERAGE EP-115=✓✓✓✓✓`，`gen_coverage.py --check`=`848 rows / 247 carried / 0 tombstones`。
集中写账警报已按独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-115-skill-install-ledger-reaudit.md`
ack，最终 `alarms.py check`=`clean (1270 judgments on record)`；未改阈值、算法、法典或锚点。

source fixture/runtime 已按用户授权删除；formal session、录屏、backend/frontend/SSE/LLM journals、截图、REST 回执和证据
均保留。该格使批次二十四达到 **40/50**；当前前线以 EP-116 整体重述为准。

### 历史状态快照（EP-114，批次二十四 35/50）

**历史前线（2026-08-09，清册 EP-114 已完成，批次二十四 35/50）。**
EP-114 `POST /api/v1/skills:inspect-source` 已完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、
窗口录屏、backend journal、三路独立 SSE witness、frontend console 和 LLM wire 的五级验收。产品目的不是返回一个
`200`，而是用户在安装前能看见所有候选、失败原因、已有 skill、allowed-tools 与实际选择状态；已有 skill 不能被画成
可执行的重复安装，inspect 也不能悄悄写入工作区。

首轮真实 EP-114 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-015806` 冻结为红：已有
`commit-helper` 在 UI 中带 `installed` 标记却被默认选中，后端 no-force install 实际只会返回 `skipped`，用户选择与
实际动作不一致。stop-and-fix 将默认选择收窄为 `installable && !alreadyExists`，已有项仍可见但开关禁用，并增加
“已在库中”明确文案与 widget 回归测试。

固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-020745` 使用真实 source fixture 重跑：
`bad name`、`broken-front` 的失败原因可读且不可选；`commit-helper` 显示 installed、关闭且不可选；新的
`valid-preview` 默认选中，`Read/Grep/run_function` 在安装动作前可见。取消新候选后 `Install selected` 变为禁用，
再选回恢复可用；点击 Cancel 后 skill 列表仍只有两个 seeded skill，未产生写入或生命周期帧。正式证据为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-114-skill-inspect-final-green.md`，首轮红证据保留。

五通道收台：录屏 `182.816667s / 2784x1808`；backend inspect 为 `200` 且无应用红线；SSE 三流均连接，本只读路径
无伪造业务帧；frontend 无 Dart/Flutter/RenderFlex/Unhandled/overflow 红线，仅已审计的 macOS foreground 启动噪声；LLM
bootstrap challenge/install/models 全 `200`。正式账本由 `1260→1265 judgments`，五级法条为 `G1/F2/A5/C4/G2`，anchors
`10/10`，`COVERAGE EP-114=✓✓✓✓✓`，`gen_coverage.py --check`=`848 rows / 246 carried / 0 tombstones`。
集中写账打开的 `gap-too-fast`/`discovery-collapse` 已按独立复审
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-114-skill-inspect-ledger-reaudit.md` ack，最终
`alarms.py check`=`clean (1265 judgments on record)`；未改阈值、算法、法典或锚点。

source fixture/runtime 已按用户授权删除；formal session、录屏、backend/frontend/SSE/LLM journals、截图、红绿证据和
账本均保留。批次二十四当前 **35/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-115
`POST /api/v1/skills:install`。

### 历史状态快照（EP-113，批次二十四 30/50）

**当前前线（2026-08-09，清册 EP-113 已完成，批次二十四 30/50）。**
EP-113 `POST /api/v1/skills/{name}:approve-tools` 已完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、
窗口录屏、backend journal、三路独立 SSE witness、frontend console 和 LLM wire 的五级验收。产品目的不是返回一个
`200`，而是第三方 Skill 的 allowed-tools 信任门必须由用户明确打开，首次授权只产生一次真实生命周期更新；重复点击、
网络重试或直接重放公开 API 都必须幂等，不伪造第二次 `skill.updated`，同时来源、文件树、正文、provenance 和 App
投影保持同一真相。

首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-013940` 冻结为红：App 首次授权后
正确产生 `seq=17 skill.updated`，但重复调用同一公开 API 虽然 REST 状态没有变化，SSE 又产生了 `seq=18 skill.updated`。
这是数据/产品生命周期假信号，停止推进。修复 `backend/internal/app/skill/install.go`：`toolsApproved` 已为 `true` 时
只读当前实体，不写 provenance、不刷新 `updatedAt`、不发通知；新增 `TestApproveTools_IsIdempotentAfterApproval`，并
保留安装/更新单事件回归和后端 Skill 文档契约。

固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-014829` 重新从真实 source fixture 安装
`trust-gate`，App 待授权帧显示 3 files、文件树、`Read`/`Grep` 和 `Pre-approval pending`；点击后变为
`Pre-approval active`、`Provenance 0`，重复静态帧稳定。首次 App 授权只产生 `seq=17 skill.updated`；随后直接重放
公开 API 返回 `200`，`updatedAt` 和 `toolsApproved` 前后完全一致，SSE 没有第二个更新事件。未知 Skill 和用户本地
Skill 均按 `422 SKILL_NOT_INSTALLED` 失败，不能越过信任门。最终录屏 `189.115000s / 2784x1808`，正式绿证据为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-113-skill-approve-final-green.md`，红证据和独立账本复审均保留。

定向验证：`mise exec -- go test ./internal/app/skill`、`mise exec -- go test -race ./internal/app/skill`、
`git diff --check` 全部通过；anchors `10/10`，正式账本由 `1255→1260 judgments`，五级法条为 `G1/F2/A5/C4/G2`，
`gen_coverage.py --check`=`848 rows / 245 carried / 0 tombstones`，EP-113=`✓✓✓✓✓`。两条集中写账警报的独立
复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-113-skill-approve-ledger-reaudit.md`，已按原阈值
ack，最终 `alarms.py check`=`clean (1260 judgments on record)`，未改阈值、算法、法典或锚点。

本轮 source fixture/runtime 已按用户授权删除；formal session、录屏、backend/frontend/SSE/LLM journals、红绿证据和
账本均保留。批次二十四当前 **30/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-114
`POST /api/v1/skills:inspect-source`。

### 5.2 历史状态快照（EP-112，批次二十四 25/50）

**历史前线（2026-08-09，清册 EP-112 已完成，批次二十四 25/50）。**
EP-112 `POST /api/v1/skills/{name}:update` 已完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、
窗口录屏、backend journal、三路独立 SSE witness、frontend console 和 LLM wire 的五级验收。产品目的不是收到
一个 `200`，而是上游 skill 更新后，中心正文、文件树、描述、provenance、allowed-tools 信任状态、通知和失败保护
必须是同一代真相；本地改动非 force 时要阻断并明确说明，force 更新也不能静默丢掉未改变的信任配置。

首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-011139` 冻结为红：后端 metadata、
文件树和 provenance 已到 v2，但中心 native editor 仍显示 v1 正文和已删除的 guide，且通知重复发出
`skill.created` + `skill.updated`。这是真实数据代际矛盾，不计绿。stop-and-fix 重置实际正文变化时的内部
native editor generation，同时保留页面滚动/大纲壳并阻断旧实例延迟保存反写；安装/更新落地改为一次操作只发
一个正确的 lifecycle event，并补 Go/Flutter 回归和 frontend library 文档。

固定 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-012412` 重新从 v1 走到 v2：App 的
中心正文、描述与右侧文件树一起切到 v2，3 文件收敛为 2 文件，`Read` pre-approval 保持；本地编辑
`scripts/check.py` 后非 force 路径返回 `SKILL_LOCALLY_MODIFIED` 并指出文件，App 显示明确的 Force update 闸，
确认后恢复 v2 且不重置 `Read`。录屏 `405.186667s / 2784x1808`，证据含 v1/v2、漂移确认框和 force 后终帧。
五通道分别证明 UI 代际一致、update/读取 HTTP 200、SSE 只有对应 `skill.updated`、Flutter console 无运行时红线、
真实 managed gateway bootstrap 全 200；正式绿证据为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-112-skill-update-final-green.md`，首轮红证据仍保留。

定向验证：`mise exec -- go test ./internal/app/skill`、`mise exec -- go test -race ./internal/app/skill`、
`cd frontend && mise exec -- flutter test test/features/library/library_test.dart`、`make -C docs verify`、
`git diff --check` 全部通过；统一长门禁和提交按批次协议刻意未执行。正式账本由 `1250→1255 judgments`，五级法条
为 `G1/F2/A5/C4/G2`；anchors `10/10`，`alarms.py check`=`clean (1255 judgments on record)`，
`gen_coverage.py --check`=`848 rows / 244 carried / 0 tombstones`，EP-112=`✓✓✓✓✓`。两条集中写账警报的独立
复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-112-skill-update-ledger-reaudit.md`，未改阈值、
算法、法典或锚点。

本轮本地 source fixture 和运行时数据已按用户授权删除；formal session、录像、backend/frontend/SSE/LLM journals、
红绿证据和账本均保留。当时批次二十四为 **25/50**，未到 50 格不跑统一长门禁、不提交；随后前线进入
EP-113 `POST /api/v1/skills/{name}:approve-tools`。

### 5.2 历史状态快照（EP-111，批次二十四 20/50）

**当前前线（2026-08-09，清册 EP-111 已完成，批次二十四 20/50）。**
EP-111 `POST /api/v1/skills/{name}:activate` 已完成真实 Flutter App、真实受管 Anselm gateway、
Computer Use、窗口录屏、backend journal、三路独立 SSE witness、frontend console 和 LLM wire 的五级验收。
用户目的不是收到一个工具卡，而是激活 skill 后，精确参数能到达正确的 skill/fork 边界，歧义不扩搜，
读取范围不越界，父回合不会在隔离 fork 返回后继续执行工具，最终结果仍能被用户理解并继续操作。

最终主 session `/private/tmp/anselm-rig-ep111-skill-activate-20260808/sessions/20260809-005230` 使用正确
的持久化 tap wiring (`8877`)；`rig-check` 五通道全绿。Computer Use 输入
`["the ep111-fork skill file"]` 后，实时画面显示一张 `Activated skill ep111-fork` 卡和一份明确的中文
歧义说明：没有绝对路径、没有挂载工作目录，不能定位目标，且没有扩大搜索范围；loading、终态和静态保持期间
没有可见布局、文字或输入跳变。录屏 `156.808333s / 2784x1808 / 60fps`，三流连接到同一 workspace，
messages durable seq `1..41` 单调，managed proof/chat HTTP 成功，frontend 无 Flutter/Dart 应用红线。

实现层已将 fork Explore 约束从提示语提升为确定性边界：无 workdir 时只允许 Skill 参数给出的精确绝对
`Read`，有 workdir 时所有 `Read/LS/Glob/Grep` 都必须在挂载根内；越界返回真实 tool error，不再以成功文本
诱导模型重试。fork 成功后以 run-local `TurnControl` 移除父回合全部工具 schema，跳过 AutoActivator；若模型
仍发 tool call，loop 不查找、不执行，写入 `toolsDisabled` tool result 并以 `TURN_TOOLS_DISABLED` 终止。
未知 fork agent 在 create/replace 阶段早拒 `422 SKILL_FORK_AGENT_TYPE_INVALID`，旧坏清单仍在 active-skill
预授权前 fail-closed；失败 fork 不污染 active skill。精确绝对路径的正向 session
`/private/tmp/anselm-rig-ep111-skill-activate-20260808/sessions/20260809-003714` 证明一次 `Read` 后直接
进入父回合文本收尾；对抗 session `004327` 证明空工具集下的晚发 `get_skill` 被硬拦。

旧 prompt-only 红证据与旧 tap 接线失败均保留在盘上；它们分别证明“只靠提示不够”和“台架自检必须阻断错误
数据”。`004327` 的 ReplayKit 动态录屏曾出现短暂重影，但实时 Computer Use 画面和新正确接线的
`005230` 录屏未复现，已诚实登记为观测器待加完整性 guard，不用它冒充产品绿证据。正式账本由 `1245→1250`
条裁决，五级法条为 `G1/F2/A5/C4/G2`；anchors `10/10`，formal alarms clean，COVERAGE 为
`848 rows / 247 carried / 0 tombstones`。按批次协议，批次二十四仍 **20/50**，未到 50 格不跑统一长门禁、
不提交；下一原子前线为 COVERAGE 的下一行。
EP-111 临时 fixture 已按用户授权清理：`ep111-inline` 与 `ep111-fork` 均
`DELETE=204→GET=404`，列表只剩 seeded skills，filesystem 目录和 relations 均为零；清理证据为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-111-fixture-cleanup.md`。本轮还修复了 formal
`anchor-check.json` 指向已删除答卷的问题：恢复冻结答案表并重新校准 10/10，未改锚点集、法条或阈值。

### 5.2 历史状态快照（EP-110，批次二十四 15/50）

**当前前线（2026-08-08，清册 EP-110 已完成，批次二十四 15/50）。**
EP-110 `DELETE /api/v1/skills/{name}` 已按“用户删除 skill 后，整棵文件树、绑定关系、Library 选中态、REST、SSE 和 workspace 隔离必须同时收口，结果必须可理解且可继续排错”的产品目的完成真实 App、真实受管 Anselm gateway、Computer Use 和五通道验收。

真实路径构造 `ep110-delete-tree`：`SKILL.md` 加 `references/notes.md`、`scripts/check.py` 共 3 个文件，并绑定 seeded `greet` function。Library 中真实打开后，中心显示正文，右岛显示 `3 files · 1 bindings`、文件树、`Bindings greet` 和完整 Properties；从行尾 actions 打开删除确认，看到 `Delete this skill?` 与明确的不可逆对象说明，按用户授权确认后，rail 移除 fixture，中心回到空的 `Untitled`，没有残留详情或属性。

删除后的数据真相逐层核对：skill GET 与 files GET 均为 `404 SKILL_NOT_FOUND`，列表只剩 `commit-helper` 与 `deploy-helper`，文件系统整目录消失，`skill → function` 的 `equip` relation 为空。负向矩阵覆盖缺 workspace=`401 UNAUTH_NO_WORKSPACE`、非法名=`400 SKILL_INVALID_NAME`、未知/重复目标=`404 SKILL_NOT_FOUND` 和跨 workspace=`404 SKILL_NOT_FOUND`；不是只验证一次 `204`。

最终 session `/private/tmp/anselm-rig-ep110-skill-delete-20260808/sessions/20260808-231300` 录屏 `217.530000s` 可读；三路 SSE 均连接，notifications durable seq `16..19` 单调并包含 `skill.created`、两次捆绑文件更新和 `skill.deleted`；backend/frontend 无应用红线。主 workspace 的真实 Anselm gateway challenge/install/models 均经 `llmtap :8876` 返回 `200`。隔离 workspace 创建后立即删除导致的 install cancellation 被记录为预期生命周期取消，不计为网关成功或失败。完整证据为 `/private/tmp/anselm-rig-ep110-skill-delete-20260808/sessions/20260808-231300/evidence/EP-110-final-green.md`，正式副本和独立告警复审分别为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-110-skill-delete-final-green.md` 与 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-110-approval-ledger-reaudit.md`。

本格无新的产品源代码变更；EP-109 的 free-tier workspace-delete race 修复仍由 Go targeted/race tests 覆盖。定向验证：`mise exec -- go test ./internal/app/skill ./internal/app/relation ./internal/transport/httpapi/handlers`、`mise exec -- go test -race ./internal/app/freetier`、`flutter test test/features/library/deleted_page_eviction_test.dart test/features/library/library_test.dart test/features/library/skill_tree_preview_test.dart`（57 tests）全部通过；`gofmt`、`git diff --check` 通过。正式 `judge.py` 按 `G1/F2/A5/C4/G2` 将账本 `1240→1245 judgments` 写入五格，EP-110=`✓✓✓✓✓`；anchors `10/10`，正式 `gap-too-fast`/`discovery-collapse` 经独立证据复审后 ack，`alarms.py check`=`clean (1245 judgments on record)`，未改阈值、算法、法典或锚点；`gen_coverage.py --check`=`848 rows / 242 carried / 0 tombstones`。一次无 `RIG_HOME` 前缀的默认账本误路由已明确排除，正式账本只认显式 formal 根。

批次二十四当前 **15/50**；未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-111 `POST /api/v1/skills/{name}:activate`。

### 5.2 历史状态快照（EP-107，批次二十三 50/50）

**当前前线（2026-08-08，清册 EP-107 已完成，批次二十三 50/50）。**
EP-107 `POST /api/v1/skills` 已按“用户用自然语言在真实 Chat 中创建一个可用 skill；HTTP、工具 schema、持久化、SSE、Library 和删除后的 UI 真相必须一致；每个可见结果都要可理解、可继续使用”的产品目的完成真实 App、真实受管 Anselm gateway、Computer Use 和五通道验收。

本格严格执行 stop-and-fix。首轮真实 Chat 发现 `create_skill` schema 遗漏 `userInvocable`：用户明确要求 `true`，工具无法发出该字段，REST frontmatter 也确认缺失。修复 `backend/internal/app/tool/skill/crud.go` 的严格 bool 解码、映射和 schema/description，补 `crud_test.go` 并同步 skill domain 文档。修复后的真实 Chat 回归在 session `/private/tmp/anselm-rig-ep107-skill-create-rerun-20260808/sessions/20260808-215429` 创建 `ep107-chat-notes-v2`，REST/LLM wire/UI 均确认 `userInvocable:true`、`disableModelInvocation:true`、`allowedTools:["Read"]`，Library Properties 显示 `Model can invoke Off` 与 `User-invocable On`。

回归继续发现第二个真实产品红：从 REST/agent 路径删除当前选中的 skill 后，Library rail 已消失，但中心详情仍展示已删除正文和属性。修复 `frontend/lib/features/library/ui/library_ocean.dart` 的“曾见过且已消失”选中态驱逐逻辑，补中英文文案、生成字符串和 `deleted_page_eviction_test.dart`。最终真实 session `/private/tmp/anselm-rig-ep107-skill-create-rerun2-20260808/sessions/20260808-215933` 创建并选中 `ep107-delete-live2` 后执行 DELETE `204`；约 350ms 后真实 App rail 移除、中心回到 `Untitled`、显示 `This skill was deleted`，不存在残留正文/Properties。随后 GET 为 `404 SKILL_NOT_FOUND`，workspace 中 `ep107-*` 计数为 `0`，notifications durable seq `19` 为 `skill.deleted`。

五通道封口：最终 `rig-check.sh` 五通道全绿，`rig-down.sh` 正常收台并以 ffprobe 封片 `259.116667s`；backend/frontend/llmtap/ssetap 无 panic、FATAL、未解释 WARN/ERROR、Flutter/Dart/RenderFlex/Unhandled 红线；三路 SSE 均连接，删除 durable signal 可见；LLM tap 真实指向 `https://api.anselm.website`，Chat 回归完成真实 challenge/install/models 和 chat completions。最终证据为 session `evidence/EP-107-skill-create-final-green.md`，红证据为 formal `EP-107-user-invocable-red.md`，删除残留红绿因果链也保留在同一最终证据。

本地验证：`mise exec -- go test ./internal/app/tool/skill -count=1` 通过；`mise exec -- flutter test test/features/library/deleted_page_eviction_test.dart test/features/library/library_test.dart` 通过（51 tests）；`gen_coverage.py --check` 为 `848 rows / 239 carried / 0 tombstones`；anchors `10/10`。正式账本使用 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3`，按 `G1/F2/A5/C4/G2` 从 `1225→1230 judgments` 写入五级裁决，EP-107=`✓✓✓✓✓`；独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-107-skill-create-ledger-reaudit.md`。集中写账打开的 `gap-too-fast`/`discovery-collapse` 已由独立红绿证据、五通道、anchors 复核后 ack，未改阈值、算法、法典或锚点，最终 `alarms.py check`=`clean (1230 judgments on record)`。

批次二十三已达到 **50/50**。下一动作不是启动 EP-108，而是按协议执行一次统一长门禁：封存本批、完整 `make verify`、完整 `go test ./...`、已修场景回归、工作树审计和提交；只有长门禁全绿并提交后，下一 loop 才把 EP-108 `GET /api/v1/skills/{name}` 设为前线。

### 5.2 历史状态快照（EP-102，批次二十三 25/50）

**历史前线（2026-08-08，清册 EP-102 已完成，批次二十三 25/50）。**
EP-102 `POST /api/v1/approvals/{id}:revert` 已完成真实 App、真实受管 Anselm gateway、Computer Use 和五通道验收。首轮点击版本动作暴露真实 Flutter `Concurrent modification during iteration`；stop-and-fix 将 selection region focus handoff 延后一个 frame 并加脱离守卫，补 6/6 回归测试。固定 session `/private/tmp/anselm-rig-ep102-approval-revert-fixed-20260808/sessions/20260808-202631` 重跑 v2→v1、外部 REST resync 和 UI 再回退，Overview/Versions/Activity/REST/SQLite/SSE 一致，未知 `999→404`、字符串版本 `"1"→400`。录屏 `304.298333s`，五通道无应用红线，cleanup `204→404` 且列表为空；正式账本 `1200→1205`，anchors `10/10`，独立复审和 alarms clean，清册 `848/234/0`。完整红绿证据与修复记录保留在上述 session；本状态只作历史追溯，当前前线以 EP-103 为准。

**历史前线（2026-08-08，清册 EP-101 已完成，批次二十三 20/50）。**
EP-101 `POST /api/v1/approvals/{id}:edit` 已按“完整替换而非部分 patch”的产品目的完成真实 App、真实受管
Anselm gateway、Computer Use 和五通道验收。用户目标是从 Approval 的 `Edit with AI` 入口新增
`refundReason:string`、精确替换模板，同时保留未改变的 `allowReason=true`、`timeout=4h` 和
`timeoutBehavior=reject`；最终必须一次完整工具调用成功，不能让用户看到校验失败后再 retry。

首轮真实 session `/private/tmp/anselm-rig-ep101-approval-edit-20260808/sessions/20260808-193907`
冻结为产品红：模型遗漏未改变的 `allowReason`，后端正确拒绝不完整 snapshot，App 出现红色工具结果、
`No approval preview · previous version remains active` 和 retry 后成功的混合旅程。红证据永久保留，
不计绿。stop-and-fix 没有放宽后端契约，而是强化 `edit_approval` 的 description/schema：模型必须先读
当前 Approval，再复制所有 required fields，包括未改变的布尔值；补齐工具契约测试并同步
`docs/references/backend/domains/approval.md`。

固定真实 session `/private/tmp/anselm-rig-ep101-approval-edit-fixed-20260808/sessions/20260808-195118`
在同一台架上重跑：最终一次 `edit_approval` 产生 v3，输入为 `customer:string`、`amount:number`、
`refundReason:string`，模板精确为
`Please review {{ input.customer }}'s refund request for {{ input.amount }}. Reason: {{ input.refundReason }}. Approve?`
，并保留 `allowReason=true`、`4h`、`reject`。终帧显示完整用户请求、单张成功工具卡、齐全字段表、
一致的助手总结和 `EP101 Refund Review Edited ×2` 活动计数；没有红卡、裁切、loading 残留、视口跳变
或重复 mutation。Computer Use 的中文 `type_text` 会丢失部分中文字符，故最终精确意图用 ASCII 等价
请求在正常 composer 中重走；中文输入层的限制没有被伪装成产品通过。

五通道封口：录屏已由 `rig-down.sh` 封片为 `213M / 797.218333s`；backend journal 无
`WARN|ERROR|panic|fatal`，frontend journal 无 `error|exception|assert|stack trace|unhandled`；
独立 ssetap 记录最终 messages durable close `seq=56/59/63/64`、notifications `seq=20 approval.edited`
且无错误帧；REST active v3、SSE close 快照、LLM wire 完整参数和 UI 字段逐项一致。最终证据为
`/private/tmp/anselm-rig-ep101-approval-edit-fixed-20260808/sessions/20260808-195118/evidence/EP-101-approval-edit-final-green.md`，
红证据与清理证据同目录/首轮 session 保留。用户已授权的临时 Approval 清理完成：DELETE `204`，随后
GET `404 APPROVAL_NOT_FOUND`，列表为空，SSE 只记录一条 `approval.deleted`。

正式账本已用 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 按 `G1/F2/A5/C4/G2` 从
`1195→1200 judgments` 写入五级裁决；锚点 `10/10`，正式独立复审为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-101-approval-edit-ledger-reaudit.md`，
`alarms.py check`=`clean (1200 judgments on record)`，`gen_coverage.py --check`=`848 rows / 233 carried / 0 tombstones`。
曾有一份未带正式 `RIG_HOME` 的默认账本副本，按错路由审计保留，工作记录与 COVERAGE 只认 formal ledger。
本格代码修复的定向 Go tests、gofmt 和 `git diff --check` 已通过；批次二十三当前 **20/50**，未到
50 格不跑统一长门禁、不提交。下一原子前线为 EP-102 `POST /api/v1/approvals/{id}:revert`。

### 5.2 历史状态快照（EP-100，批次二十三 15/50）

**当前前线（2026-08-08，清册 EP-100 已完成，批次二十三 15/50）。**
EP-100 `DELETE /api/v1/approvals/{id}` 已按完整产品目的完成真实 App、真实受管 Anselm gateway、Computer Use 和五通道验收。用户目的不是“收到一个 204”，而是从活动目录移除 Approval、清理关系边、保留不可变版本审计，并让受影响 workflow 保持可见、可定位、可修复，且 workspace 隔离和重复删除边界诚实。

固定真实 session `/private/tmp/anselm-rig-ep100-approval-delete-20260808/sessions/20260808-192034` 使用主 workspace
`ws_63cd621a13771254`，Approval `apf_28ec4b33b61dd4ed` 已有 v1/v2/v3，workflow `wf_e221c04926eff830` 通过一条 approval 节点引用它。真实 App 打开 Approval 详情、More actions、删除确认框并在用户已授权删除验收夹具后确认；Approval 从 rail/Parts 消失，选中详情回到 Overview，关系图删除 Approval 边但保留 workflow/trigger，Notifications 明确显示删除和 `1 reference dangling`，workflow graph/editor 保留原始 dangling ref 而不静默重绑。

REST 矩阵覆盖主删除 `204`、删除后单读 `404 APPROVAL_NOT_FOUND`、列表消失、三条 immutable versions 与 v1 历史仍可读、workflow 图仍在、capability check 的明确 missing-ref 问题、关系图清边、重复/未知删除 `404`、缺 workspace `401`、cross-owner `404` 和删除后同名新建 `201`。SQLite 证明软删主行带 `deleted_at`、三条版本保留且没有指向已删 Approval 的关系行；`resolved=true` 的含义按契约是 resolver 已接线并完成尝试，runnable 仍由 `problems` 判定。

Computer Use 逐帧检查确认删除确认文案、rail/Parts 收敛、通知详情、workflow Overview 和 graph inspector 没有裁切、重叠、loading 残留、错误重绑或输入/视口跳变。没有发现需要 stop-and-fix 的产品或代码红；删除确认的“从 active catalog 移除且不可恢复”与 soft-delete/version-history 契约一致。

五通道对证：录屏封片 `494.890000s`；backend journal 652 行无应用 WARN/ERROR/panic/FATAL；frontend journal 18 行只有已知 launcher `Failed to foreground app; open returned 1`，无 Dart/Flutter/RenderFlex/Unhandled/runtime error；独立 ssetap 的 messages/entities/notifications 三流均连接，主 notifications durable seq `16..24` 单调并包含 `approval.deleted` 与聚合 `relation.dependency_broken`；LLM tap 真实接线到 `https://api.anselm.website`，challenge/install/models 全部 HTTP 200。rig-check 操作前后全绿，rig-down 正常收台。

用户已授权并完成独立 fixture cleanup：cleanup session `/private/tmp/anselm-rig-ep100-cleanup-20260808/sessions/20260808-192941` 删除依赖 workflow、trigger 和 auxiliary workspace，DELETE 全部 `204`、精确 GET 全部 `404`；主 workspace、seeded graph 和 EP-100 证据/journal/录像保留。清理证据为 `EP-100-fixture-cleanup.md`，最终绿证据为 `EP-100-approval-delete-final-green.md`。

独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-100-approval-delete-ledger-reaudit.md`。
`judge.py` 按 `G1/F2/A5/C4/G2` 将正式账本 `1190→1195 judgments`，`COVERAGE EP-100=✓✓✓✓✓`，anchors=10/10；集中写账打开的 `gap-too-fast`/`discovery-collapse` 已由红绿证据、真实录屏、五通道、REST/SQLite 负向矩阵和 cleanup 独立复审后 ack，没有修改阈值、算法、法典或锚点。正式 `alarms.py check`=`clean (1195)`，`gen_coverage.py --check`=`848 rows / 232 carried / 0 tombstones`。

本格无产品源代码变更；已完成 anchors check、alarms check、coverage check 和 `git diff --check`。pytest 不在当前 Python 环境中安装，未把缺失工具伪报为通过；相关既有 Go 回归此前已通过。批次二十三当前 **15/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-101 `POST /api/v1/approvals/{id}:edit`。

### 5.2 历史状态快照（EP-098，批次二十三 5/50）

EP-098 `GET /api/v1/approvals/{id}` 首轮发现悬空 `active_version_id` 会被旧二进制伪装成缺少 `activeVersion`；stop-and-fix 已将 Approval/Control/Function/Handler/Agent/Workflow 六个同类单读服务统一为 fail-closed。真实固定 session `/private/tmp/anselm-rig-ep098-approval-get-fixed-20260808/sessions/20260808-185307` 完成正常、空/悬空 pointer、未知 ID、缺 workspace、cross-workspace 和 UI Overview/Versions 验收，录屏 `292.263333s`，backend/frontend/SSE/LLM 五通道无未解释红线。正式账本 `1180→1185`、anchors `10/10`、清册 `848/230/0`；cleanup 已按授权完成。代码、测试和契约证据随本批次继续保留。

### 5.2 历史状态快照（EP-097，批次二十二 50/50）

EP-097 的完整五通道收口、统一长门禁和提交记录保留如下；当前恢复不得把批次计数回退到二十二。

### 5.2 历史状态快照（EP-096，批次二十二 45/50）

**当前前线（2026-08-08，清册 EP-096 已完成，批次二十二 45/50）。**
EP-096 `POST /api/v1/approvals` 已按完整产品目的完成真实 App、真实受管 Anselm gateway、Computer Use 和五通道验收。
用户目的不是“API 返回 201”，而是用户用自然语言描述一个带输入类型、理由、超时和超时处置的审批表单后，产品必须一次创建正确，
并在对话、Activity 和审批预览中给出一致、可理解、可继续使用的结果。

首轮真实 App 冻结出产品红：受管模型把 `2h` 编码成精确整数秒字符串 `"7200"`。旧工具边界先返回
`invalid timeout duration or missing/invalid timeoutBehavior`，随后模型重试并成功创建；因此同一屏同时出现失败工具行、
`Draft unsaved · nothing was created` 和成功创建卡片。这不是可接受的“模型自我修正”，因为用户无法判断是否有重复或半成品。
红证据永久保留于
`/private/tmp/anselm-rig-ep096-approval-create-20260808/sessions/20260808-175421/evidence/EP-096-approval-create-red.md`。

前线冻结后 stop-and-fix：在 approval tool 解码边界增加精确整数秒字符串/整数兼容归一化（`7200`→`2h`），但公开
HTTP/domain duration 契约仍严格拒绝零、负数、无单位小数、坏 JSON 和错误形状；补 tool create execution、正负解码与
domain/handler 守卫测试，并同步 approval domain 文档。定向 Go tests 全部通过：
`go test ./internal/app/tool/approval ./internal/app/approval ./internal/domain/approval ./internal/transport/httpapi/handlers`。

最终真实 session `/private/tmp/anselm-rig-ep096-approval-create-20260808/sessions/20260808-180647` 使用 workspace
`ws_14972f564f66a37d`，由同一 conductor 托管真实 Flutter App、Computer Use、`28438` 窗口 `132.026667s` 录像、
backend/frontend journals、三路独立 SSE witness、真实 gateway 和 LLM tap。用户实际输入要求创建
`ep096-refund-review-fixed`，声明 `amount:number`、`customer:string`，允许 reason，`2h` 后 reject。
最终画面正文明确创建成功，工具卡为 `Created approval … · v1`，Activity 只有一条 Created，展开的审批预览完整显示
prompt、两项输入类型、`2h`、`auto-rejects after 2h`、`note allowed` 及 Approve/Reject；无失败行、Draft unsaved、
矛盾文案、裁切、重叠、loading 残留或输入跳变。

五通道对证：backend journal 无 WARN/ERROR/panic/tool execute failed；frontend console 只有已知 launcher
`Failed to foreground app; open returned 1`，无 Dart/Flutter/RenderFlex/Unhandled runtime error；SSE durable frame 记录
唯一 `create_approval` open/close、`approval.created` 和 touchpoint，durable seq 单调；LLM journal 全部 upstream response
为 200，真实工具参数仍为 `"timeout":"7200"`，证明修复覆盖真实托管形状而非手写请求。最终 HTTP 与 SQLite 同时证明
`apf_c07e5096237e71db` 的 active `v1` 为 `timeout=2h`、`timeout_behavior=reject`、inputs 为 amount/customer，
`7200` 未泄漏到持久层、HTTP 或 UI。正式绿证据为
`/private/tmp/anselm-rig-ep096-approval-create-20260808/sessions/20260808-180647/evidence/EP-096-approval-create-final-green.md`。

用户已授权并完成本轮 fixture cleanup：临时 sidecar session
`/private/tmp/anselm-rig-ep096-cleanup-20260808/sessions/20260808-181438` 通过 API 删除三条审批和三条验收对话，
六次 DELETE 均 `204`，随后六个 exact GET 均 `404`，审批列表不再出现 `ep096-*`。SQLite 三条审批主行保留非空
`deleted_at`，三条 v1 immutable version rows 保留 `2h/reject`；红绿证据、LLM/SSE/backend/frontend journals 与录像均未删。
清理证据为
`/private/tmp/anselm-rig-ep096-approval-create-20260808/sessions/20260808-180647/evidence/EP-096-fixture-cleanup.md`。

独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-096-approval-create-ledger-reaudit.md`。
`judge.py` 按 `G1/F2/A5/C4/G2` 将正式账本 `1170→1175 judgments`，`COVERAGE EP-096=✓✓✓✓✓`，anchors=10/10；集中写账
打开的 `gap-too-fast`/`discovery-collapse` 已依据红证据、修复测试、第二次真实 session、负向边界和五通道复审后 ack，
没有修改阈值、算法、法典或锚点。正确 formal home 下 `alarms.py check`=`clean (1175)`，`gen_coverage.py --check`=
`848 rows / 228 carried / 0 tombstones`。

批次二十二当前 **45/50**，尚未达到 50 格，因此不运行统一长门禁、不提交。EP-089/EP-090/EP-091/EP-092/EP-093/EP-094/
EP-095/EP-096 的代码、测试、契约文档、红绿证据、清理记录和 COVERAGE ledger 留在当前工作树，随批次二十二第 50 格
统一提交。下一原子前线为 EP-097 `GET /api/v1/approvals`。

### 5.2 历史状态快照（EP-092，批次二十二 25/50）

EP-092 `POST /api/v1/controls/{id}:revert` 已按完整产品目的完成真实 App、受管 gateway、Computer Use 和五通道
验收：只移动 Control active pointer 到 v1，保留 name/description、不铸造新版本且保留 v2 历史。真实模型只调用一次
`revert_control`；最终画面显示 v1 的 score input、ordered routes 和两侧 emit，无裁切、重叠或 loading 残留。
固定 session `/private/tmp/anselm-rig-ep092-control-revert-20260808/sessions/20260808-162625`，录屏
`474.791667s / 2784x1808 / 60fps`；HTTP 矩阵覆盖 v2/v1 成功回退及 zero/unknown 版本 404，SQLite/REST/UI/SSE
一致，cleanup 后 App 收敛到 `0 entities, 0 relations`。账本 `1150→1155`，COVERAGE 五级全绿，anchors=10/10，
`alarms.py check`=`clean (1155)`，清册 `848/224/0`；错误 shell quoting 只作为无副作用 harness 证据保留。

### 5.2 历史状态快照（EP-091，批次二十二 20/50）

**历史前线（2026-08-08，清册 EP-091 已完成，批次二十二 20/50）。**
EP-091 `POST /api/v1/controls/{id}:edit` 已按完整产品目的完成验收：用户在真实 App 中表达「只改变
Control 的一个路由条件」时，未提及的输入声明、port、emit 和 catch-all 都保留；托管模型的等值 JSON
数组编码可以正常执行；显式清空仍有明确语义；坏输入在 mutation 前大声失败。最终真实画面显示 active v5、
`score:number`、approve `input.score >= 0.96`、review default 和两侧 `emit: decision`。

首轮真实 AI 编辑发现两层产品红并冻结前线。第一层是托管模型把 `inputs`/`branches` 作为精确 JSON 数组
字符串传入，旧工具边界按原生数组解码并失败；第二层更严重：旧 `edit_control` 把省略的可选 `inputs` 当成
空值，模型只想把阈值从 `0.90` 调到 `0.95`，却生成了 `inputs:null` 的 v3，破坏了原有 `score` 输入声明。
这不是可接受的重试噪声，而是局部编辑造成的数据丢失。红证据永久保留于
`/private/tmp/anselm-rig-ep091-control-edit-20260808/sessions/20260808-160105/evidence/EP-091-control-edit-red-inputs-erased.md`。

stop-and-fix 同时修复 AI、领域服务和 HTTP 边界：`decodeControlInputs` 接受原生数组与精确 JSON 数组字符串，
仍拒绝 malformed/object/non-array；`edit_control` 以字段 presence 区分「省略=保留 active declaration」与
「显式 []=清空」；HTTP `:edit` 遵守同一语义，并在坏输入时先返回 `INVALID_REQUEST`，不做部分 mutation。服务层
增加 `PreserveInputsIfOmitted` 保护，补充 stringified、malformed、service-level 与 tool-level 回归测试；
Control API/domain 文档同步说明契约。

固定 session `/private/tmp/anselm-rig-ep091-control-edit-20260808/sessions/20260808-161138` 由同一 conductor
托管真实 Flutter App、Computer Use、窗口录制、backend/frontend journal、三路独立 SSE witness、managed gateway
和 LLM tap；录屏 `388.893333s / 2784x1808`。先将旧红状态恢复到 v2，真实 App 的 Edit with AI 创建 v4，真实
LLM wire `00006_v1_chat_completions.bin` 证实托管模型传入 stringified inputs，v4 保留 score 声明并把阈值改为
0.95。随后 HTTP 省略 inputs 创建 v5，仍保留 score 声明；HTTP `inputs:"not json"` 返回 400 且 GET 证明 v5
未被污染。最终 Computer Use 逐帧确认 v5 详情无裁切、重叠、跳变或残留 loading。

REST/SQLite/SSE/UI/LLM 对证：`control-v4.json` 与 `http/omit-inputs.json` 均含 `score:number`；malformed HTTP
证据为 `http/malformed-inputs.json`。三路 SSE 均连接，messages durable seq `1..35`、notifications durable
seq `1..5` 严格单调，entities 完成连接；backend 494 行无 WARN/ERROR/FATAL/panic/tool execute failed，frontend
18 行无 Flutter/Dart/RenderFlex/Unhandled 红线；challenge 与 5 次真实 chat completion 全 HTTP 200。`rig-check.sh`
收台前确认 backend/ssetap/llmtap/Flutter runner/recorder 均归属本 session，`rig-down.sh` 后无残留进程。

正式绿证据为
`/private/tmp/anselm-rig-ep091-control-edit-20260808/sessions/20260808-161138/evidence/EP-091-control-edit-final-green.md`；
独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-091-control-edit-ledger-reaudit.md`。
`judge.py` 按 `G1/F2/A5/C4/G2` 将正式账本 `1145→1150 judgments`，`COVERAGE EP-091=✓✓✓✓✓`，anchors=10/10。
集中写账触发的 `gap-too-fast`/`discovery-collapse` 已按独立复审记录 ack，未改阈值、算法、法典或锚点；
`alarms.py check`=`clean (1150)`，`gen_coverage.py --check`=`848 rows / 223 carried / 0 tombstones`。

批次二十二当前 **20/50**，尚未达到 50 格，因此不运行统一长门禁、不提交。EP-089/EP-090/EP-091 的代码、测试、
契约文档、红绿证据、工作记录和 COVERAGE ledger 留在当前工作树，随批次二十二第 50 格统一提交。下一原子前线为
EP-092 `POST /api/v1/controls/{id}:revert`。

### 5.2 历史状态快照（EP-090，批次二十二 15/50）

**历史前线（2026-08-08，清册 EP-090 已完成，批次二十二 15/50）。**
EP-090 `DELETE /api/v1/controls/{id}` 已按完整产品目的完成验收：用户删除 Control 后，真实 App 的
Entities rail、Parts 计数和关系图都收敛到 REST/数据库事实；被删实体消失，仍存活的 workflow 保留，历史版本
保留，悬空引用由 capability-check 明确显示，重复删除和未知 ID 给出可解释 404。固定切片同时删除同类
Approval 以验证关系依赖通知的对称语义；Approval 自身的 coverage 单格仍由 EP-100 管理，不在本格重复计数。

首轮真实 session 发现产品红：Control/Approval DELETE、关系查询和 REST `/relgraph` 已正确更新，但 Overview
的关系图只在挂载时读取一次；等待约 `2.5s` 后仍显示 `8 entities, 6 relations`，保留已删除实体的 ghost nodes。
前线冻结。修复将 `EntityRepository` 增加 workspace-wide durable `relationSignals()`，不把 relation 变化错误
裁剪成七种 rail `EntityKind`；Live 实现只消费 durable notification，ephemeral frame 不触发耐久快照刷新。
`relGraphProvider` 同时监听 relation pulse 与 lifecycle resync，并以 `300ms` 合并删除及聚合依赖通知，避免中间
拓扑闪现和重复请求。Fixture、provider 和三项专门测试同步；Flutter 定向 15 项全通过。

红证据永久保留于
`/private/tmp/anselm-rig-ep090-control-delete-20260808/sessions/20260808-152528/evidence/EP-090-control-delete-red.md`。
固定 session `/private/tmp/anselm-rig-ep090-control-delete-fixed-20260808/sessions/20260808-153741` 由同一
conductor 托管真实 Flutter App、Computer Use、窗口录制、backend/frontend journal、三路独立 SSE witness、
managed gateway 和 LLM tap；录屏 `98.700000s / 2784x1808 / 60fps`。新 fixture 创建后真实 App 从 `6/4`
收敛到 `14 entities, 10 relations`；连续删除后从 REST 的 `12/8` 收敛到相同的 `12 entities, 8 relations`，
两类 rail 行消失、Parts 回到 0，剩余 workflow/trigger/function 节点保留。

REST/SQLite/SSE/UI 对证：Control/Approval delete 均 `204`，exact GET 与重复 DELETE 均 `404`；Control/Approval
版本历史仍保留；relations 清除被删实体 equip 边；capability-check 返回 `structurallyValid:true,
resolved:true` 并列出悬空 control/approval 引用。notifications durable seq `1..8` 严格连续，依次包含两类
created、workflow created、两类 deleted 及各自 `relation.dependency_broken`；backend 195 行无 panic/FATAL/ERROR
或未解释 WARN，frontend 18 行无 Flutter runtime 红线，固定 session 三流各连接且 rig-check/rig-down 干净收台。
本确定性 REST/UI 切片没有伪造 LLM completion，llmtap 只记录真实 ready/wiring；challenge/install/models 仍由台架
真实接线验证。

正式绿证据为
`/private/tmp/anselm-rig-ep090-control-delete-fixed-20260808/sessions/20260808-153741/evidence/EP-090-control-delete-final-green.md`，
首轮红证据同目录见上；独立账本复审为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-090-control-delete-ledger-reaudit.md`。
`judge.py` 按 `G1/F2/A5/C4/G2` 将正式账本 `1140→1145 judgments`，`COVERAGE EP-090=✓✓✓✓✓`，anchors=10/10。
集中写账触发的 `gap-too-fast`/`discovery-collapse` 已依据独立复审记录 ack，未改阈值、算法、法典或锚点；
`alarms.py check`=`clean (1145)`，`gen_coverage.py --check`=`848 rows / 222 carried / 0 tombstones`。

批次二十二当时 **15/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-091。

### 5.2 历史状态快照（EP-089，批次二十二 10/50）
EP-089 `PATCH /api/v1/controls/{id}` 已按完整产品目的完成验收：真实用户修改 Control metadata 后，
列表和详情准确反映 name/description；metadata patch 不铸造新版本；空 patch 或等值 patch 可安全重试，
不会刷新时间戳、写盘或制造生命周期事件。真实 App 详情逐帧显示 `EP089 Control Patched`、description、
opaque ID、v1、更新时间、两个 input 和两个 ordered routing branch。

首轮真实 session 发现产品红：空 `PATCH {}` 返回 200 但仍产生 `control.updated` durable notification，并因 ORM
Save 总刷新而改变 `updatedAt`。按 stop-and-fix 冻结并修复 Control UpdateMeta；同类 Approval 一并修复。现在
两者均在实际字段发生变化时才 Save/publish，空 patch/等值 patch 直接返回当前实体；API/domain 文档与 app
层 recording-notifier 回归测试已同步。红证据永久保留于
`/private/tmp/anselm-rig-ep089-control-patch-20260808/sessions/20260808-150028/evidence/EP-089-control-patch-red.md`。

固定 session `/private/tmp/anselm-rig-ep089-control-patch-fixed-20260808/sessions/20260808-151021` 由同一
conductor 托管真实 Flutter App、Computer Use、窗口录制、backend/frontend journal、三路独立 SSE witness、
managed gateway 和 LLM tap；录屏 `401.523333s / 2784x1808 / 60fps`。Control 与 Approval 的实际 patch、空
patch、等值 patch、错误边界、删除 cleanup 均已走通。notifications durable seq `1..6` 严格为两类实体的
created/实际 updated/deleted；no-op 没有幽灵帧。删除后真实 App Overview 的 Control/Approval rail 无残留、Parts
为 0、关系图为 0 entities/0 relations，空态引导完整。

REST/SQLite/SSE/UI/LLM 对证：Control no-op 的 `updatedAt` 为
`2026-08-08T07:15:17.41525Z` 前后一致，Approval no-op 的 `updatedAt` 为
`2026-08-08T07:15:17.640948Z` 前后一致；实际变化各只发一条 updated。空名/未知字段/未知 id/缺 workspace
header 均按预期返回 422/400/404/401；DELETE=204 后 exact GET=404、live lists=0、workspace 保留。backend
511 行无应用 WARN/ERROR/panic/FATAL，frontend 19 行无 Flutter runtime 红线，managed challenge/install/models
全 200，三路 SSE 连接且无 gap，rig-check/rig-down 干净收台。

正式证据为
`/private/tmp/anselm-rig-ep089-control-patch-fixed-20260808/sessions/20260808-151021/evidence/EP-089-control-patch-final-green.md`，
独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-089-control-patch-ledger-reaudit.md`；
`judge.py` 按 `G1/F2/A5/C4/G2` 将正式账本 `1135→1140 judgments`，`COVERAGE EP-089=✓✓✓✓✓`，anchors=10/10。
两条集中写账警报经独立重读红绿 session、REST、SSE、backend/frontend/LLM、UI 和单元测试后 ack，未改阈值、
算法、法典或锚点；`alarms.py check`=`clean (1140)`，`gen_coverage.py --check`=`848 rows / 221 carried / 0 tombstones`。

批次二十二当前 **10/50**，尚未达到 50 格，因此不运行统一长门禁、不提交。EP-089 的代码、测试、契约文档、红绿
证据、工作记录和 COVERAGE ledger 留在当前工作树，随批次二十二第 50 格统一提交。下一原子前线为 EP-090。

### 5.2 历史状态快照（EP-086，批次二十一 45/50）

**历史前线（2026-08-08 13:35，清册 EP-086 已完成，批次二十一 45/50）。**
EP-086 `POST /api/v1/controls` 已按完整产品目的完成验收：用户可以创建带有输入 schema、条件分支、
all-else 默认分支和 emit 映射的 Control，并在实体详情中读懂版本、输入类型、路由条件和输出；非法
输入在落库前明确拒绝，重复名称保持冲突语义，删除后列表、详情、关系和 UI 都诚实收敛。

首轮真实 session `/private/tmp/anselm-rig-ep086-control-20260808/sessions/20260808-132051` 发现
unknown input type `money` 被错误接受并渲染，冻结为产品红；stop-and-fix 增加 schema 输入校验和
`CONTROL_INVALID_INPUTS`，create/edit 均在持久化前拒绝未知类型、重复字段名等错误，并补 domain/app
回归。修复后 fresh session `/private/tmp/anselm-rig-ep086-control-20260808-fixed/sessions/20260808-132726`
重跑通过：空名、空分支、缺 catchall、非法 CEL、未知类型、重复字段名均为可解释 422；合法 control
为 201，重复名称为 409。修复证据和首轮红证据均永久保留。

最终 session 由同一 conductor 托管真实 Flutter App、Computer Use、录屏、frontend/backend journal、
三路独立 SSE witness、managed gateway 和 LLM tap；录屏 `166.691667s`，rig-check/rig-down 通过并
干净收台。notifications/entities/messages 三流均连接，control.created/deleted durable frame 与
REST/SQLite 对齐；challenge/install/models 全 200；backend/frontend 无未解释应用红线。实体详情逐帧
显示 `amount: number`、`region: string`、三条路由分支、默认分支和 emit keys，清理后回到空 Overview。
所有临时 control 均 DELETE=204 → GET=404，workspace GET=200；SQLite 保留 tombstone、v1 版本和通知，
relations=0，不误删 seeded 数据。

正式证据为 `/private/tmp/anselm-rig-ep086-control-20260808-fixed/sessions/20260808-132726/evidence/EP-086-control-real-session.md`，
独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-086-control-ledger-reaudit.md`。
anchors=10/10；`judge.py` 按 `G1/F2/A5/C4/G2` 将正式账本 `1120→1125 judgments`，
`COVERAGE EP-086=✓✓✓✓✓`。集中写账警报以复审证据 ack，阈值、算法、法典和锚点未改，
`alarms.py check`=`clean (1125)`；`gen_coverage.py --check`=`848 rows / 218 carried / 0 tombstones`。

批次二十一当时累计 **45/50**，尚未达到 50 格，因此不运行统一长门禁、不提交。EP-086 的
`CONTROL_INVALID_INPUTS` 代码、测试、API/domain 文档、五通道证据和 COVERAGE ledger 随批次二十一第 50 格
统一提交；下一原子前线为 EP-087 `GET /api/v1/controls`。

### 5.2 历史状态快照（EP-085，批次二十一 40/50）

**当前前线（2026-08-08，清册 EP-085 已完成，批次二十一 40/50）。**
EP-085 ANY /api/v1/webhooks/{triggerId}/{path...} 已按完整产品目的完成验收：外部系统可以在不带
Anselm bearer/workspace header 的情况下访问 catch-all webhook，按 HMAC 或 plain secret 正确认证，
让绑定 workflow 真实执行；用户能从 Trigger 详情发现挂载 URL 和认证载体，在同一详情页看到
Last fired、Activity 与 Dispatch 的真实回声；改 path 后旧地址立即 404、新地址立即 202，详情页
同步展示新 URL。重复网络请求保留 Activation 审计但不重复建 Firing/run，满足可追溯与幂等两端。

本轮使用 fresh data directory 和真实 onboarding 建立 workspace，创建并激活 HMAC webhook pipeline、
plain-secret webhook pipeline 以及真实 Python Function action。真实 Computer Use 矩阵覆盖 wrong method、
bad/missing/wrong auth、valid JSON、同 body retry、不同 JSON、纯文本 body、header/query secret、
path edit 前后；UI 逐步核对了 URL/Copy、签名算法和自定义 header、Listening、Last fired、Activity、
Dispatch，以及 plain-secret 的 X-Webhook-Secret header or ?token= query 引导。首轮真实路径发现
外部 fire 后打开的 Overview 仍显示 Last fired: never，stop-and-fix 为 fire signal 触发 REST truth
refresh 并失效 observability projection；第二轮又发现 plain-secret 详情缺少认证载体说明，补上双语
引导且不渲染 secret，最终 session 重跑通过。两处红证据和修复后绿证据均保留，未把仪器错误或正确
的 dedup 语义误报为产品红。

正式 session 为 /private/tmp/anselm-rig-ep085-webhook-20260808-final/sessions/20260808-125703，
证据为其 evidence/EP-085-webhook-real-session.md，独立账本复审为
/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-085-webhook-ledger-reaudit.md；同一 conductor
托管真实 Flutter App、窗口录制、backend/frontend journal、三路独立 SSE witness、managed gateway
wiring 和 LLM tap。录屏 539.071667s；rig-check、rig-down 通过且进程/监听器全部收台。SSE
独立 witness 连接 notifications/entities/messages，durable seq 分别 1..10、1..12 无 gap；
backend/frontend 无未解释应用红线；challenge/install/models 全 HTTP 200，确定性 webhook slice
没有伪造 LLM completion。SQLite 对证 HMAC 为 5 Activation / 4 Firing / 4 completed Flowrun，
duplicate dedup group 为 0，plain-secret 为 2 Activation / 1 Firing。全部 fixture 均
DELETE=204 → GET=404，三类 live 列表为空，workspace 保持 GET=200；录屏、journal、数据库和
抽帧证据全部保留。

anchors=10/10；judge.py 按 G1/F2/A5/C4/G2 将正式账本 1115→1120 judgments，
COVERAGE EP-085=✓✓✓✓✓。集中写账打开的 gap-too-fast 与 discovery-collapse 已以独立
复审证据逐项 ack，阈值、算法、法典和锚点未改，alarms.py check=clean (1120)。清册重生检查
保持 848 rows / 217 carried / 0 tombstones。

批次二十一当前累计 **40/50**，尚未达到 50 格，因此不运行统一长门禁、不提交。EP-085 的 trigger
detail fire-refresh、plain-secret discoverability、实体契约/i18n/文档和 COVERAGE ledger 均留在当前
工作树，随批次二十一第 50 格统一提交。下一原子前线为 EP-086 POST /api/v1/controls。

### 5.2 历史状态快照（EP-084，批次二十一 35/50）

**历史前线（2026-08-08 12:38，清册 EP-084 已完成，批次二十一 35/50）。**
EP-084 `GET /api/v1/trigger-schedule` 已按完整产品目的完成验收：用户在真实 Scheduler Overview
可以看到未来 cron 时间线，知道下一次自动化属于哪个 workflow，区分正常、暂停、无人引用和没有可预测
下一次触发的来源，理解时间线被封顶时发生了什么，并从已有运行的时间格进入正确的 run/operations
表面。真实 API、SQLite、SSE、Flutter 画面和五通道终端日志对同一批调度事实给出一致结论。

本轮真实 App 使用 fresh data directory，先通过真实 onboarding 建立 workspace，再通过当前 LLM tap
连通 managed Anselm gateway。夹具包含每分钟 dense cron、每小时 sparse cron、paused cron、无 workflow
的 unreferenced cron 和 webhook。真实 dense cron 连续产生 9 条 `fire → run_started → run →
run_terminal(completed)` 链；Overview 的 25 小时矩阵显示成功格，点格进入 workflow run/operations
表面；hover card 显示小时内的时间、来源、耗时，并对隐藏的两条成功记录给出 `2 more all succeeded`。
paused lane 保留在原位并显示 `Paused`，没有伪造 `nextFireAt`；webhook 和无人引用 cron 没有伪造未来点；
`More is scheduled inside this window than the track can show.` 独立说明未来截断。清理后 durable delete
通知驱动 App 收敛到 `No automation yet`，无幽灵泳道。

本轮没有发现需要 stop-and-fix 的产品缺陷：真实视觉帧没有裁切改变语义、重叠、死 spinner、错误未来预测、
不解释的跳变或机器 ID 泄露；长名称使用有界省略，AX tree 保留完整标签，时间/状态在未来句和 hover card
中保持最高优先级。EP-084 的 setup-only 红 session 因复用数据库残留旧 gateway wiring，被 `rig-check`
正确拒绝并单独保留，不计产品红；随后用 fresh data 重跑，不把仪器问题伪装成产品结论。

正式证据为 `/private/tmp/anselm-rig-ep084-schedule-20260808-retry/sessions/20260808-122252/evidence/EP-084-schedule-real-session.md`，
独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-084-trigger-schedule-ledger-reaudit.md`；
同一 conductor 托管真实 Flutter App、Computer Use、窗口录像、backend/frontend journal、三路独立 SSE
witness、managed gateway wiring 和 LLM tap。封口录屏 `667.105000s`，`rig-check`、`rig-down` 通过且 owned
process/listener 全部收台；视觉帧保留 Overview、hover card 和清理后的空状态。

五通道对证：SSE witness 共 73 条 JSONL，entities 44 条、durable seq `1..20`，notifications 29 条、
durable seq `1..27`；backend 无 panic/WARN/ERROR/FATAL 应用红线，frontend 无 Dart/FlutterError/RenderFlex/
Unhandled/lost-device/assertion 红线，LLM challenge/install/models 全 200。唯一 frontend 输出是已知
Flutter runner `Failed to foreground app; open returned 1`，随后 App 正常构建并全程可观测；确定性 workflow
正确没有伪造 completion。10 个临时 fixture 均 `DELETE=204` 后 `GET=404`，workspace 仍 `200`，session、
journal 和录屏全部保留。

定向黑盒 `TestTriggerSchedule_(Timeline|TruncatesHonestly)` 通过，Scheduler KPI/Overview Flutter 回归
共 65 项通过。anchors=`10/10`；`judge.py` 按 `G1/F2/A5/C4/G2` 将账本 `1110→1115 judgments`，
`COVERAGE EP-084=✓✓✓✓✓`；集中写账触发的 `gap-too-fast` 与 `discovery-collapse` 已用独立复审证据逐项
ack，阈值、算法、法典和锚点未改，`alarms.py check`=`clean (1115)`。清册为
`gen_coverage.py --check`=`848 rows / 216 carried / 0 tombstones`。

批次二十一当时累计 **35/50**，尚未达到 50 格，因此不运行统一长门禁、不提交。EP-079/EP-081 修复、
activation 修复、EP-083 workflow 名称修复、EP-084 本轮文档和 COVERAGE ledger 均留在当前工作树，随
批次二十一第 50 格统一提交。当时下一原子前线为 EP-085 ANY /api/v1/webhooks/{triggerId}/{path...}。

### 5.2 历史状态快照（EP-077，批次二十 47/50）

**当前前线（2026-08-08 07:56，清册 EP-077 已完成，批次二十 47/50）。**
`POST /api/v1/triggers/{id}:pause` 已按完整产品目的完成验收：用户从真实 Entities rail 的
More actions 选择 Pause 后，Trigger 在原详情页进入 `Paused`，源头 listener 注销但 workflow
引用保留；Fire 保留空间位置但 inert，直接 REST `:fire` 以 `422 TRIGGER_PAUSED` 大声拒绝。用户
随后从同一处 Resume，listener 按当前 config 重新注册，详情回到 `Listening`，恢复后的 sensor
source 真实产生 activation→firing→flowrun 并完成。暂停开关、运行投影和 SSE 状态帧没有分叉。

最终 session `/private/tmp/anselm-rig-ep077-pause-20260808/sessions/20260808-074937` 由同一
conductor 托管真实 Flutter App、Computer Use、窗口录像、backend journal、三路独立 SSE witness、
真实 managed gateway wiring 和 LLM tap；运行中 `rig-check` 五通道通过，`rig-down` 后 owned
process/listener 全部收台，录屏 `207.725000s / 2784x1808 / 60fps`。关键帧为
`evidence/trigger-paused-final.png` 与 `evidence/trigger-resumed-final.png`。

REST/SQLite/SSE/UI 对证：暂停读模型为 `paused=true/listening=false/refCount=1`；暂停期间
`:fire=422 TRIGGER_PAUSED`，activation/firing/flowrun 数保持不变。Resume 后读模型为
`paused=false/listening=true/refCount=1`，sensor 新建 activation=`tra_217e69d5737b4a0c`、
firing=`trf_e1ce88be0f712109`、flowrun=`fr_6aeac3da976cacbb`，flowrun REST/SQLite=`completed`。
SSE 三流均连接；entities 记录同一 trigger scope 的 `status {paused:true}` 与
`status {paused:false}`，随后同一 workflow 的 `fire`、`run_started(seq=3)`、
`run_terminal(completed,seq=4)`，durable 序列单调，ephemeral 帧没有被冒充耐久状态。

frontend/backend/LLM 行数为 `32/254/1`；backend 无 panic/FATAL/WARN/ERROR，frontend 无
Flutter/Dart/RenderFlex/Unhandled/assertion 红线，AXTree 报错已由同 session 的
`evidence/frontend-ax-review.md` 复核为 Computer Use 观察器噪声；deterministic workflow 的
LLM tap 只有 ready，不冒充 completion。三次 shell/台架问题（`path` 覆盖 PATH、zsh 未给
`$ID:resume` 加花括号、首次 rig-check 缺 AX review）均已正确重跑并记录为仪器问题，不计产品红。

正式红/绿/独立复审证据分别为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-077-trigger-pause-red.md`、
`EP-077-trigger-pause-green.md`、`EP-077-trigger-pause-ledger-reaudit.md`。anchors `10/10`；
`judge.py` 按 `G1/F2/A5/C4/G2` 将账本 `1070→1075 judgments`，`COVERAGE EP-077=✓✓✓✓✓`；
集中写账触发的 `gap-too-fast` 与 `discovery-collapse` 已按独立复审 ack，阈值、算法、法典和
锚点未改，`alarms.py check`=`clean (1075)`，`gen_coverage.py --check`=`848 rows / 209 carried / 0 tombstones`。
定向 Go/Flutter/Dart analyze、录像封口、收台和 `git diff --check` 通过。

批次二十当前 **47/50**；未到第 50 格不跑统一长门禁、不提交。下一原子前线为 EP-078
`POST /api/v1/triggers/{id}:resume`。

### 5.2 历史状态快照（EP-076，批次二十 42/50）

**历史前线（2026-08-08 07:44，清册 EP-076 已完成，批次二十 42/50）。**
`POST /api/v1/triggers/{id}:fire` 已按完整产品目的完成验收：用户在真实 Trigger 详情点击 Fire 后，
立即得到动作反馈；Dispatch 允许短暂显示 durable `pending`，但在同一页面通过有界 REST 重读自动收敛到
真实的 `started` disposition 和 flowrun；Activation、Firing、Flowrun、SSE 和 SQLite 的 ID/状态链
可以互相追溯。暂停时详情徽标显示 `Paused`，Fire 保留空间位置但 inert，并明确提示先 Resume；后端
`TRIGGER_PAUSED` 仍是最终防线。

首轮真实 session `/private/tmp/anselm-rig-ep076-fire-20260808/sessions/20260808-071716` 冻结了三条
真实红：暂停态曾显示 `Idle` 且 Fire 仍可点；手动 fire 的 `{manual:true}` 被错误 fixture graph
送进需要 `start.name` 的 action，run `fr_9e3ae7722a140bef` 诚实失败；Dispatch 首次读到 `pending`
后不再重读，workflow 已 terminal 但 UI 留在旧状态。红证据与录屏永久保留，不计绿。

stop-and-fix 直接修复了暂停态 header、i18n 和 trigger widget regression；将 disposable workflow
改成无参数 `sync_inventory` action，使手动 fire 的 payload 与 graph 契约相容；`FiringListNotifier`
在当前页仍有 pending 时每 500ms 重读同一 REST 页并按 id 替换行，进入终态立即停止，瞬时失败保持
last-known-good 后按 pending 条件重试；fixture 支持行级更新，新增 pending→started widget regression。
同步 frontend entities 文档和本过程证据。

最终 session `/private/tmp/anselm-rig-ep076-fire-20260808/sessions/20260808-073336` 由同一 conductor
托管真实 Flutter App、Computer Use、窗口录像、backend journal、三路独立 SSE witness、真实 managed
gateway wiring 和 LLM tap；运行中 `rig-check` 五通道通过，`rig-down` 后 owned process/listener
全部收台，录屏 `434.098333s`。关键帧为 `dispatch-after-fire.png`、`dispatch-settled.png`、
`trigger-paused-final.png`、`trigger-resumed-final.png`。

REST/SQLite/SSE/UI 对证：主路径 `:fire=202`，activation=`tra_1d399eb2587378fc`，
`fired=true/firingCount=1/payload={manual:true}`；firing=`trf_789d0baf6b1f6162` 为
`started` 且关联 flowrun=`fr_957497ee81dcfba7`；flowrun REST/SQLite terminal=`completed`，
capability-check=`200 {structurallyValid:true,resolved:true}`。SSE 三流均连接，entities durable
seq `1..10` 单调无重无倒退，主 Fire 为 ephemeral frame，随后同一 flowrun 收到
`run_started(seq=3)` 与 `run_terminal(completed,seq=4)`；deterministic graph 的 LLM tap 只有
ready，不冒充 completion。

暂停负向同一 session 真实得到 `paused=true/listening=false`，Computer Use 画面为 `Paused` + inert
Fire，直接 `:fire=422 TRIGGER_PAUSED` 且无新增 activation/firing/flowrun；随后用正确的
`${endpoint}:resume` 恢复为 `paused=false/listening=true`。一次不带花括号的 zsh endpoint 拼接
404 被单独记录为仪器错误，不计产品红。

backend journal `524` 行、frontend `18` 行、SSE `32` 行、LLM `1` 行；修正版无应用级
WARN/ERROR/panic/FATAL 或 Flutter/Dart/RenderFlex/Unhandled/assertion 红线，唯一平台噪声为已知
Flutter runner `Failed to foreground app; open returned 1`。定向 Dart analyze、12 项 trigger widget
tests、trigger/handler/store Go tests 和 `git diff --check` 通过。

正式红/绿/独立复审证据分别为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-076-trigger-fire-red.md`、
`EP-076-trigger-fire-green.md`、`EP-076-trigger-fire-ledger-reaudit.md`。锚点 `10/10`；`judge.py`
按 `G1/F2/A5/C4/G2` 将账本 `1065→1070 judgments`，`COVERAGE EP-076=✓✓✓✓✓`；集中写账触发的
`gap-too-fast` 与 `discovery-collapse` 已按独立复审 ack，阈值、算法、法典和锚点未改，
`alarms.py check`=`clean (1070)`，`gen_coverage.py --check`=`848 rows / 208 carried / 0 tombstones`。

批次二十当前 **42/50**；未到第 50 格不跑统一长门禁、不提交。下一原子前线为 EP-077
`POST /api/v1/triggers/{id}:pause`。

### 5.2 历史状态快照（EP-075，批次二十 41/50）

**当前前线（2026-08-08 07:10，清册 EP-075 已完成，批次二十 41/50）。**
`DELETE /api/v1/triggers/{id}` 已按完整产品目的完成验收：用户从真实 Entities rail 删除一个正在监听且被
workflow 使用的 trigger 时，确认框先说明会停止 listener、哪些 workflow 会悬空以及后续需要修复；确认后
实体从 rail/detail/关系图收敛，后端 soft-delete、关系清边、审计保留和 durable notification 均与 UI 一致。

首轮真实红 session `/private/tmp/anselm-rig-ep075-delete-20260808/sessions/20260808-065336` 抓到 generic
`Delete this entity?` 只说移出 active catalog，没有解释 `Listening: Yes / Listeners: 1` 或
`ep072fix-listening-workflow` 的依赖后果；红帧永久保留，未计绿。stop-and-fix 在 `EntityRail` 删除确认前
fresh 读取已有 `GET /api/v1/relgraph`，列出入向 `equip/link` 使用者，listener 热时给出停止监听文案，
关系读取失败则 fail-closed；同步中英文 i18n、30 项 widget regression、实体文档。审计同时修正
`docs/references/backend/events.md` 中与当前 durable trigger lifecycle notification 矛盾的旧句。

最终 session `/private/tmp/anselm-rig-ep075-delete-20260808/sessions/20260808-070205` 由同一 conductor
托管真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、
真实 managed gateway wiring 和 LLM tap，录屏 `308.340000s / 2784x1808 / 60fps`。真实画面先打开
`ep072fix-sensor-4-repaired` detail，看到 `Listening: Yes / Listeners: 1`，再在 Delete 确认框中看到
`ep072fix-listening-workflow`、停止 listener 和 repair 后果；点击已授权 Delete 后回到 Overview，Trigger
rail `24→23`、Parts `24→23`、关系图 `10→8`，通知托盘显示 trigger deleted 与 dangling dependency 两条记录。
绿帧为 `ep075-delete-confirm-green.png`、`ep075-after-delete-green.png`、`ep075-notifications-green.png`。

REST/SQLite/SSE 对证：DELETE=`204`，后续 trigger GET=`404 TRIGGER_NOT_FOUND`，trigger list=`23` 且 deleted id
缺席；relgraph=`8` 条边且 deleted id 缺席；SQLite 保留 tombstone `deleted_at`、5 条 activation、5 条 firing，
删除后新增 activation/firing 均为 0；引用 workflow 仍保留但 capability-check 诚实返回
`structurallyValid=true,resolved=true` 与缺失 trigger problem。独立 ssetap 三流均连接，entities durable `1..2`、
notifications `1..2` 单调，关键帧为 `trigger.deleted` 与 `relation.dependency_broken`；LLM tap 有 ready 回执，
本确定性删除路径没有伪造模型 completion。

五通道封口：backend 无应用 WARN/ERROR/panic/FATAL；frontend 仅 2 条固定 Flutter macOS AXTree observer churn，
已在 session `frontend-ax-review.md` 标记 `tooling-ax-tree/reviewed`，静置 10 秒不增长且没有 Dart/FlutterError/
RenderFlex/overflow/Unhandled/lost-device；rig-check 在动态操作后通过，rig-down 后 owned process groups 归零。
锚点 `10/10`；`judge.py` 以 `G1/F2/A5/C4/G2` 写入五格，账本 `1060→1065 judgments`，`COVERAGE EP-075=✓✓✓✓✓`。
集中写账触发的 `gap-too-fast` 与 `discovery-collapse` 已依据独立复审、红绿证据、五通道 journal 和锚点 ack；
阈值、算法、法典和锚点未改，`alarms.py check`=`clean (1065)`；`gen_coverage.py --check`=`848 rows / 207 carried / 0 tombstones`。
定向 Dart analyze、实体 rail 30 项 Flutter 测试、trigger/relation/http handler Go 测试和 `git diff --check` 通过。

批次二十当前 **41/50**；未到第 50 格不跑统一长门禁、不提交。下一原子前线为 EP-076
`POST /api/v1/triggers/{id}:fire`。

### 5.2 历史状态快照（EP-070，批次二十 20/50）

EP-070 `POST /api/v1/flowruns/{id}/approvals/{node}:decide` 已完成真实 App、受管 gateway、
Computer Use 和五通道验收。用户能从 Scheduler Overview 或顶部 approval capsule 理解真实
生产审批、填写理由、批准/拒绝，并看到 inbox、运行计数、下游节点和 run history 收敛；非法
decision、未知字段、重复决策和并发 first-wins 均有诚实边界，拒绝不会执行 publish。

正式 session `/private/tmp/anselm-rig-ep070-approval-decision-20260808/sessions/20260808-043003`
录屏 `788.638333s / 2784x1808 / 60fps`，五通道完整且 `rig-check`/`rig-down` 通过。修正版
webhook fixture capability-check 为 `structurallyValid=true, resolved=true`，旧 test-only
`trg_manual` 仅保留 setup 红证据；旧错误 fixture 已按授权软删除，修正版 fixture 未删除。
四条正负/竞态路径、REST/SQLite/UI/SSE/LLM 交叉证据、逐帧产品检查和五级 `G1/F2/A5/C4/G2`
裁决均已封存于现有 EP-070 evidence；账本 `1035→1040`，`COVERAGE EP-070=✓✓✓✓✓`，
anchors `10/10`，`alarms.py check`=`clean (1040)`。批次二十当时 20/50，下一前线为 EP-071。

### 5.2 历史状态快照（EP-069，批次二十 15/50）

**历史快照（2026-08-08 04:26，清册 EP-069 已完成，批次二十 15/50）。** `GET /api/v1/flowrun-matrix` 已按完整产品目的完成验收：Scheduler 的矩阵真实呈现同一 workflow 的 completed、failed、running/awaiting-approval 和 sparse/not-reached 四种语义；用户点击红格可进入精确失败 dossier，点击等待列可进入 Gantt/approval 视图，Failed/Waiting/All 筛选与矩阵列保持一致。Computer Use 逐帧检查没有裁切、溢出、跳变、死 spinner 或不符合直觉的 CTA。

正式固定 session `/private/tmp/anselm-rig-ep069-flowrun-matrix-fixed-20260808/sessions/20260808-041832` 由 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、LLM tap 和真实 managed gateway wiring；录屏 `293.975000s`，最终 journal 为 backend/frontend/SSE/LLM=`402/18/18/1`，`rig-check` 五通道通过，`rig-down` 后 owned process groups 与监听端口均归零。矩阵 REST/SQLite 对证覆盖 newest-first 顺序、known/ghost 混合、all-ghost 空结果、重复 ID 去重、blank-only `400 INVALID_REQUEST`、51-ID `422 FLOWRUN_MATRIX_TOO_MANY_IDS`，running 行省略 elapsed、终态行展示 elapsed；SQLite 的 run/node rows 与 UI 每个状态一致。

首轮真实清理发现一个真实产品缺陷：REST 已空且 notifications 流已收到 durable `workflow.deleted` 后，scheduler rail 仍保留已删 workflow。前线冻结并 stop-and-fix：`scheduler_rail_provider` 增加 durable workflow lifecycle notification 订阅和 300ms refetch debounce，补回归测试；固定 session 清理后真实 UI 收敛到 `No automation yet`，没有 stale row。夹具签名错误则被保留为后端可解释的 setup failure evidence，不误判为产品红。两轮 fixture 均按授权精确清理，live entities 为空、tombstone/version/run/node 审计保留、seeded entities 未动。

正式证据 `/private/tmp/anselm-rig-ep069-flowrun-matrix-fixed-20260808/sessions/20260808-041832/evidence/EP-069-flowrun-matrix-real-session.md`，独立 ledger 复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-069-flowrun-matrix-ledger-reaudit.md`。`judge.py` 按 `G1/F2/A5/C4/G2` 写入五格，账本 `1030→1035 judgments`，COVERAGE `EP-069=✓✓✓✓✓`，anchors `10/10`；集中写账触发的 `gap-too-fast` 与 `discovery-collapse` 已按独立复审证据 ack，`alarms.py check`=`clean (1035)`，阈值、算法、法典和锚点未改。scheduler matrix/home、rail provider 定向 Flutter 测试，scheduler/store Go 测试和 `TestFlowrunMatrix_Grid` 均通过。

批次二十当前 **15/50**，未到第 50 格不跑统一长门禁、不提交；下一原子前线为 EP-070 `POST /api/v1/flowruns/{id}/approvals/{node}:decide`。

### 5.2 历史状态快照（EP-068，批次二十 10/50）

**当前前线（2026-08-08 04:02，清册 EP-068 已完成，批次二十 10/50）。** `GET /api/v1/flowrun-stats` 已按完整产品目的完成验收：Scheduler 从同一统计投影与同一 schedule lane 诚实呈现运行、失败、审批等待、错过刻度和 workflow 健康。真实用户看到 `Running 1`、`Waiting 1`、`Failed · 24h 2`、`Next fire in <1m`；真实 cron 停机跨刻度重启后继续看到 `Missed · 24h 2`，lane 的无障碍描述同步为 `2 missed`，没有把 missed 伪装成 run 或静默吞掉。

正式 session `/private/tmp/anselm-rig-ep068-flowrun-stats-fixed-20260808/sessions/20260808-035335` 由 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、LLM tap 和受管 gateway wiring；录屏 `214.181667s / 2784x1808 / 60fps`，窗口 `26612`。真实路径覆盖：健康审批与连续失败 workflow → Scheduler Overview → 创建真实 minutely cron → 停机跨 `03:52` 刻度 → 同一数据目录重启 → Overview missed KPI/lane → workflow 详情的 cron runs、矩阵、成功率、平均耗时 → parked approval 收口。

REST 边界全部真实取证：主批查 totals `running=1/completedSince=5/failedSince=2/parkedNodes=1/missed=0`，byWorkflow 保留请求顺序与 ghost zero row；future/倒挂窗只清空窗内 landed aggregates，不抹掉 live running/parked 或 consecutive failures；`recentN=99` clamp，重复/空 ID 去重；51 个 ID 为 `422 FLOWRUN_STATS_TOO_MANY_IDS`；坏 since/until 为 `FLOWRUN_STATS_INVALID_SINCE`/`FLOWRUN_STATS_INVALID_UNTIL`。重启后的最终统计为 `completedSince=6/missed=2`，两条 missed firing 均无 `flowrunId` 且日期落在真实停机刻度。

REST/SQLite/SSE/UI 对证一致：SQLite `trigger_firings` 保留 `2 missed + 3 started`，四条 EP-068 手工 run 的 approval/health/failure 状态与 8 个 node rows 一致；删除后的六个 fixture 行保留 `deleted_at` tombstone。entities durable seq 观察到 cron `run_started/run_terminal` 和 approval terminal，notifications durable `1..6` 观察到 cleanup；messages、entities、notifications 三流均连接。backend/frontend/SSE/LLM=`356/18/29/1`，应用级 panic/FATAL/WARN/ERROR、Flutter/Dart/RenderFlex/Unhandled/assertion 均为零；deterministic graph 无 LLM 节点，tap 只有 readiness 而无 completion 是正确边界。

正式证据 `/private/tmp/anselm-rig-ep068-flowrun-stats-fixed-20260808/sessions/20260808-035335/evidence/EP-068-flowrun-stats-real-session.md`，ledger 复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-068-flowrun-stats-ledger-reaudit.md`。`judge.py` 按 `G1/F2/A5/C4/G2` 写入五格，账本 `1025→1030 judgments`，COVERAGE `EP-068=✓✓✓✓✓`，anchors `10/10`；集中写账按原机制打开两条统计警报，已用独立复审证据 ack，最终 `alarms.py check`=`clean (1030)`，阈值、算法、法典和锚点均未调整。scheduler unit、`TestFlowrunStats_BatchProjection`、`TestTrigger_MisfireMissedAccounting` 均通过。

按用户删除授权，先将 parked run `fr_ff847dc5b94e0737` 决策为 `completed/decision=no`，再对 3 workflow、1 approval、1 trigger、1 function 执行精确 DELETE `204×6`、随后 GET `404×6`；搜索列表为空，tombstone、version、run/node/firing 审计保留，seeded entities 未动。批次二十当前 **10/50**，未到第 50 格不跑统一长门禁、不提交；下一原子前线为 EP-069 `GET /api/v1/flowrun-matrix`。

### 5.2 历史状态快照（EP-067，批次二十 5/50）

**历史前线（2026-08-08 03:42，清册 EP-067 已完成，批次二十 5/50）。** `GET /api/v1/flowrun-inbox` 已按完整产品目的完成验收：真实用户在 Scheduler 和通知托盘都能找到停在 approval 的 run，看到流程名、`Awaiting approval`、节点名、渲染问题、明确倒计时和 Approve/Reject；批准、带理由拒绝、非法请求和终态重复决策都各自给出诚实结果，决策后收件箱和 Scheduler 空态立即收敛，没有孤立的 `human`、死卡或无限 spinner。

正式 session `/private/tmp/anselm-rig-ep067-flowrun-inbox-20260808/sessions/20260808-033401` 由同一 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、LLM tap 和受管 gateway wiring；录屏 `205.191667s / 2784x1808 / 60fps`，窗口 `26563`。真实 UI 路径覆盖 `Scheduler Overview → Waiting on you → Approve`、通知按钮 → `Needs you` → `+ Reason` → Reject，以及最后的 `No approvals waiting on you.` / `Nothing is running right now.` 空态。初始旧 session 曾发现 approval capsule 的真实 `RenderFlex overflowed by 18 pixels`，已 stop-and-fix 为异步问题高度测量 + 内容溢出保护；生成代码、静态分析和回归测试均通过，最终 session 前端日志没有该红线。

REST/SQLite/SSE 对证一致：`fr_30b3f4d1e090ee0d` 经真实 App Approve 后为 `completed`、human result=`decision=yes`；`fr_68dae31075077ccd` 经通知托盘带理由 Reject 后为 `completed`、human result=`decision=no` 且 reason=`需要业务方再确认`；`fr_86ea343f844bfb69` 的非法 `maybe` 返回 `422 FLOWRUN_INVALID_DECISION`、未知字段返回 `400 INVALID_REQUEST`，parked 行在两次拒绝后仍留在 inbox，随后正常拒绝并收口；重复决策返回 `422`。最终 `GET /api/v1/flowrun-inbox` 为 `{parked:[]}`，三条 run 各只有一个 `run_terminal(completed)`。

SSE witness 三流均真实连接：entities durable seq `1..6` 连续，notifications durable seq `1..3` 连续，parked/decision 行按契约为 ephemeral `seq=0`；messages 流在本 deterministic workflow 中没有业务帧，但连接已被 witness 记录。backend `330` 行、frontend `17` 行、SSE `19` 行、LLM `1` 行；backend 无 panic/FATAL/WARN/ERROR，frontend 无 Flutter/Dart/RenderFlex/Unhandled/assertion 红线。LLM tap 已在线并承接 `https://api.anselm.website`；本 graph 没有 LLM 节点，故 `ready` 后无 completion 请求是正确边界，不把 tap 就绪冒充模型产出。

正式证据 `/private/tmp/anselm-rig-ep067-flowrun-inbox-20260808/sessions/20260808-033401/evidence/EP-067-flowrun-inbox-real-session.md`，ledger 复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-067-flowrun-inbox-ledger-reaudit.md`。`judge.py` 按 `G1/F2/A5/C4/G2` 写入五格，账本 `1020→1025 judgments`，COVERAGE `EP-067=✓✓✓✓✓`，anchors `10/10`；集中写账按原机制打开 `gap-too-fast` 与 `discovery-collapse`，已用独立复审证据 ack，最终 `alarms.py check`=`clean (1025)`，阈值、算法、法典和锚点均未调整。

按用户删除授权，workflow `wf_079bd3e516258373` 与 approval `apf_415cdf697e7fee9a` 精确 DELETE `204×2`、随后 GET `404×2`、搜索列表为空；tombstone、workflow version、三条 flowrun/node 审计保留，fixture relations=0，seeded entities 未动。前端 targeted tests `81` 项全绿，`flutter analyze` 无问题，`git diff --check` 和 `gen_coverage.py --check`=`848 rows / 199 carried / 0 tombstones` 通过。批次二十当前 **5/50**，未到第 50 格不跑统一长门禁、不提交；下一原子前线为 EP-068 `GET /api/v1/flowrun-stats`。

### 5.2 历史状态快照（EP-065，批次十九 45/50）

**历史前线（2026-08-08 02:20，清册 EP-065 已完成，批次十九 45/50）。** `POST /api/v1/flowruns/{id}:replay` 已按完整产品目的完成验收：真实用户可以在 Scheduler 打开失败 run，先看到失败节点、完整 traceback 和明确的“重跑 1 个失败节点、复用 2 个已完成结果”确认，再在同一个 run dossier 里看到 `Replay #1`、四个节点全部完成、finish 输出和 Overview 的 `Failed · 24h 0`；已完成 run 再次 replay 则明确返回 `FLOWRUN_NOT_REPLAYABLE`，不会制造第二次执行。

正式 session `/private/tmp/anselm-rig-ep065-flowrun-replay-fixed-20260808/sessions/20260808-021122` 使用真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、LLM tap 和受管 Anselm gateway；录屏 `147.960000s / 2784x1808 / 60fps`。正式 fixture 使用真实 webhook `trg_4fc6464cb69089fe`，graph 为 `webhook → function → flaky handler → finish function`；capability-check 返回 `structurallyValid=true`、`resolved=true`、无 problems/warnings。早先使用测试专用 `trg_manual` 的探索 session 因 capability-check 明确显示悬空引用，已排除，不计入绿裁决。

REST/SQLite/产品数据事实一致：UI run `fr_d2f77da1dbc075a0` 首次为 failed（start/stable completed、flaky failed、finish 未运行），确认后同 run `Replay #1`、四节点 completed；独立 REST run `fr_6d2e339a29ced1fe` 的 `POST /flowruns` 为 `201`，`POST /flowruns/{id}:replay` 为 `202`，结果 `flaky.n=2`、`finish.final=2`，第二次 replay 为 `422 FLOWRUN_NOT_REPLAYABLE`。每个 run 的审计均只有 stable 一次成功、finish 一次成功、handler 一次失败加一次成功，completed nodes 被复用而非重跑；原始失败 JSON 可由 `json.loads` 解析且无控制字符。

五通道已封存：backend journal `296` 行、frontend journal `18` 行、SSE journal `48` 行、LLM journal `10` 行；notifications durable seq `16..32`、entities durable seq `7..18` 单调，失败 terminal、replay 活动、成功 terminal 和 workflow attention 事件均已观察。真实 gateway challenge/install/models 全部 HTTP 200；backend 无 panic/FATAL/WARN/ERROR，frontend 无 Flutter/Dart/RenderFlex/Unhandled 应用红线。Computer Use 逐帧检查失败 dossier、确认框、成功 finish inspector 和最终 Overview，未发现裁切、旧失败 CTA、重复活动、无解释 spinner、布局跳变或视觉缺陷；本格无需产品源代码修复。

正式证据为 `/private/tmp/anselm-rig-ep065-flowrun-replay-fixed-20260808/sessions/20260808-021122/evidence/EP-065-flowrun-replay-final-green.md`，API probe 为同目录 `EP-065-flowrun-replay-api-probes.md`，cleanup 为 `/private/tmp/anselm-rig-ep065-cleanup-fixed-20260808/sessions/20260808-021437/evidence/EP-065-flowrun-replay-cleanup.md`。按 `G1/F2/A5/C4/G2` 写入五格，账本 `1010→1015 judgments`，COVERAGE `EP-065=✓✓✓✓✓`，anchors `10/10`，两条批量写账警报经 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-065-flowrun-replay-ledger-reaudit.md` 独立复审并 ack，`alarms.py check` clean(1015)，清册 `848 rows / 197 carried / 0 tombstones`。阈值、三曲线算法和锚点均未调整。

按用户删除授权，独立无 App/no-LLM cleanup 已对 workflow、webhook trigger、handler 和两个 function 精确执行 DELETE `204×5`、后续 GET `404×5`；五条 tombstone、immutable version history、两条 replayed flowrun 及节点/执行审计保留，fixture relations=0，seeded entities 未动。批次十九当时 **45/50**；EP-066 已接续完成并达到 50/50，统一长门禁转由当前前线执行，下一原子前线为 EP-067 `GET /api/v1/flowrun-inbox`。

### 5.2 历史状态快照（EP-064，批次十九 40/50）

**当前前线（2026-08-08 01:53，清册 EP-064 已完成，批次十九 40/50）。** `GET /api/v1/flowruns/{id}/activity` 已按完整产品目的完成验收：真实用户可以在 Scheduler 打开一个完成的 run，看到从 function、handler、agent 到 MCP 的完整 Gantt 活动链，逐节点查看真实 output、排队/执行时长和 execution log；API 以四张执行审计表的真实数据聚合成稳定的 keyset 活动页，空 run、坏游标、非法 limit、幽灵 run 都有诚实边界，不把空结果伪装成错误或把错误伪装成空页。

本格最终真实 session `/private/tmp/anselm-rig-ep064-flowrun-activity-20260808b/sessions/20260808-014240` 使用新 binary、独立数据目录、真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、真实 Anselm gateway LLM tap。录屏封口 `475.320000s / 2784x1808`，绑定 Anselm window id `26407`；真实 App 路径为 `Scheduler → ep064-flowrun-activity-four-kinds → completed run → Gantt → agent/MCP Inspector`。画面显示 `Done`、`9.8s`、`queued 0ms`、`ran 9.7s`、`v3 · pinned version`、`5 nodes · Completed 5`，Gantt 中 agent 的真实长执行条与其余短活动按时间比例呈现，节点 output 和 execution log ID 均可达。

REST/SQLite/产品数据事实一致：真实 run `fr_c322e8cac2176f65` 的 activity 按开始时间升序返回四行：`function/fne_a501a1ac92d4c1ec/29ms`、`handler/hcl_ab1653e281c4ac88/0ms`、`agent/agx_2de12b89655ef061/9707ms`、`mcp/mcl_bcb44fd8172592d5/3ms`，每行 `readyAt ≤ startedAt` 且 `status=ok`。`limit=2` 两页无重复、无缺口；trigger-only run `fr_5e645bb73e54d5fa` 返回 `data=[]`；malformed cursor、`limit=0`、unknown run 分别为 `MALFORMED_CURSOR`、`INVALID_REQUEST`、`FLOWRUN_NOT_FOUND`。SQLite 对证同一 run 有 `5` 个 node、四张执行表各 `1` 行；API probe 在 session evidence 的 `EP-064-flowrun-activity-api-probes.json`。

五通道已封存：backend journal `623` 行、frontend journal `17` 行、SSE journal `118` 行、LLM journal `16` 行；entities durable seq 到 `14`、notifications durable seq 到 `22`，run 的 agent/MCP node signal 与 `run_terminal(completed)` 均被观察到且各 stream 单独单调。真实 gateway challenge/install/models 和 `/v1/chat/completions` 全部 HTTP 200，LLM body/response 分别为 `519/26302` bytes；frontend/backend 无 Flutter、Dart、RenderFlex、Unhandled、panic、WARN/ERROR 应用红线。`rig-check.sh` 收台前五通道通过，`rig-down.sh` 后 owned process groups 归零，录屏可读。

本格没有产品源代码修复；第一次 cleanup 命令因 zsh 变量错误只请求了 `/api/v1/` 并全部 404，没有状态改变，随后逐条绝对 URL 重跑成功，属于验收仪器错误，不计产品红。正式证据为 `/private/tmp/anselm-rig-ep064-flowrun-activity-20260808b/sessions/20260808-014240/evidence/EP-064-flowrun-activity-real-session.md`，清理证据为 `/private/tmp/anselm-rig-ep064-cleanup-20260808/sessions/20260808-015120/evidence/EP-064-flowrun-activity-cleanup.md`。

正式绿证据按 `G1/F2/A5/C4/G2` 写入五格，账本 `1005→1010 judgments`，COVERAGE `EP-064=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` 在 gap-too-fast 与 discovery-collapse 独立复核 ack 后为 clean(1010)，清册 `848 rows / 196 carried / 0 tombstones`。两条警报只记录连续写账与本格完整复核，不修改 25 秒阈值、通过速率、发现率算法。

按用户删除授权，独立无 App/no-LLM cleanup `/private/tmp/anselm-rig-ep064-cleanup-20260808/sessions/20260808-015120` 已精确删除本格两个 workflow、trigger、MCP server：DELETE `204×4`，exact GET `404×4`；真实 run、5 条节点和四张执行审计行仍保留，seeded function/handler/agent 未动，deleted tombstone 与 fixture relations=0 已由 SQLite 核对。批次十九当前 **40/50**，未到 50 不跑统一长门禁、不提交；下一原子前线为 EP-065 `POST /api/v1/flowruns/{id}:replay`。

### 5.2 历史状态快照（EP-063，批次十九 35/50）

**当前前线（2026-08-08 01:37，清册 EP-063 已完成，批次十九 35/50）。** `GET /api/v1/flowruns/{id}` 已按完整产品目的完成验收：用户可以从 Scheduler 找到一个真实完成的 run，看到稳定的 run 头、`26 nodes · Completed 26`、分页节点列表，展开剩余节点并打开单节点 Inspector 查看 output 和 execution log；REST 的有界 `{flowrun,nodes,nextCursor}`、同 run keyset continuation、错误语义和 workspace 隔离均与产品画面一致，没有把无界节点历史一次性倾倒到首屏。

本格最终真实 session `/private/tmp/anselm-rig-ep063-flowrun-get-20260808/sessions/20260808-012500` 使用新 binary、独立数据目录、真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、真实 Anselm gateway LLM tap。录屏封口 `438.676667s / 2784x1808`，绑定 Anselm window id `26377`，终帧为 `evidence/EP-063-final-frame.png`。真实 App 路径为 `Scheduler → ep063-flowrun-node-pagination → completed run → Show remaining 14 → node25`；画面显示 Manual、Done、pinned version、26/26 completed，node25 Inspector 显示 output `{"ok":true}` 与 Completed execution log。

REST/SQLite/产品数据事实一致：fixture workflow `wf_75f1ef981c05df4b` 生成 run `fr_4174d512cfc9b9ea`，用 `limit=10` 得到 `10+10+6` 三页，节点顺序 `node25..node16`、`node15..node06`、`node05..node01,start`，26 个唯一节点全部 completed，三页 header 都指向同一 run。负向矩阵覆盖 unknown run、malformed cursor、`limit=0`、`limit=51` clamp 和有效 run 的 cross-workspace lookup，分别得到 `FLOWRUN_NOT_FOUND`、`MALFORMED_CURSOR`、`INVALID_REQUEST`、有界 200 和隔离 404；API 原始结果在 session evidence 的 `EP-063-flowrun-get-api-probes.json`，分页原始页和汇总在 rig 根目录。

五通道已封存：backend journal `590` 行、frontend journal `18` 行、SSE journal `124` 行、LLM journal `16` 行；entities durable seq `7..60` 连续单调 54 个，notifications durable seq `16..19` 连续单调 4 个，前端/backend 无未解释应用红线，受管网关 challenge/install/models 全部 HTTP 200。SSE 序列按 stream 独立核对，不把不同 stream 的同数值 seq 误判为重复；本格是 deterministic function workflow，不伪造 chat completion。`rig-check.sh` 收台前五通道通过，`rig-down.sh` 后进程组归零，录屏可读。

本格没有产品源代码修复；首轮 shell 清理循环只因变量名拼写错误在发出 DELETE 前退出，随后显式 URL 重跑并取得正确结果，属于验收仪器命令错误，不计产品红。最终证据为 `/private/tmp/anselm-rig-ep063-flowrun-get-20260808/sessions/20260808-012500/evidence/EP-063-flowrun-get-real-session.md`，API probe 为同目录 `EP-063-flowrun-get-api-probes.json`，独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-063-flowrun-get-ledger-reaudit.md`。

正式绿证据按 `G1/F2/A5/C4/G2` 写入五格，账本 `1000→1005 judgments`，COVERAGE `EP-063=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` 在 gap-too-fast 独立复审 ack 后为 clean(1005)，清册 `848 rows / 195 carried / 0 tombstones`。复审确认五次写账是同一封口证据的机械登记，不修改 25 秒阈值、通过速率、发现率算法。

按用户删除授权，独立无 App/no-LLM cleanup `/private/tmp/anselm-rig-ep063-cleanup-20260808/sessions/20260808-013308` 已精确删除本格 workflow、function 和隔离验证 workspace：DELETE `204×3`，exact GET `404×3`，主 workspace GET `200`；SQLite 保留 1 条 flowrun、26 条 node、25 条 function execution、各 1 条版本和三条 tombstone，fixture relations=0。清理证据为同 cleanup session 的 `evidence/EP-063-flowrun-get-cleanup.md`。批次十九当前 **35/50**，未到 50 不跑统一长门禁、不提交；下一原子前线为 EP-064 `GET /api/v1/flowruns/{id}/activity`。

### 5.2 历史状态快照（EP-062，批次十九 30/50）

**历史前线（2026-08-08 01:22，清册 EP-062 已完成，批次十九 30/50）。** `POST /api/v1/flowruns` 已按完整产品目的完成验收：用户可以从 Workflow debugger 触发一次手动 run，明确看到 Done、节点完成数、耗时和输出，再通过 `Open run →` 进入 Scheduler durable run inspector；API 侧支持单 trigger 自动选择、多 trigger 显式 `entryNode`，非法入口、未知 workflow、未知字段和 malformed JSON 都 fail-loud，不会静默跑错图或伪造成功。

本格最终真实 session `/private/tmp/anselm-rig-ep062-flowrun-start-20260808/sessions/20260808-005702` 使用新 binary、独立数据目录、真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、真实 Anselm gateway LLM tap。录屏封口 `1293.626667s`，绑定 Anselm window id `26340`，终帧为 `evidence/EP-062-final-frame.png`。真实 App 路径为 `Entities → ep062-manual-run → workflow debugger → Trigger → Open run → Scheduler inspector`；最终画面显示 `Manual · 01:12`、`Done`、`107ms · queued 0ms · ran 102ms · v2 · pinned version`，graph 为 `start → echo`，节点为 `Completed 2`，右侧输出为 `accepted: true / source: ui`。

REST/SQLite/产品数据事实一致：单 trigger 正向 run `fr_0f741423bace74b4` 完成并回显 `api-single-fixed`；multi trigger 显式选择 `t2` 的 `fr_764f18dec3c769b1` 只执行 `t2 → b` 并回显 `api-t2-fixed`；真实 UI run `fr_8e32ab2d25642afb` 完成且 pin 到 workflow v2/function v3；同语义 workflow debugger API probe `fr_d7ea4365f1097af6` 也完成。负向矩阵覆盖无 `entryNode` 的多入口、ghost 入口、action 入口、未知字段、缺失/未知 workflow、malformed JSON，分别得到 `FLOWRUN_INVALID_ENTRY`、`INVALID_REQUEST` 或 `WORKFLOW_NOT_FOUND`；完整输入和结果在 `EP-062-flowrun-start-api-probes.json`。

五通道已封存：backend journal `1582` 行、frontend journal `20` 行、SSE journal `87` 行、LLM journal `10` 行；SSE 当前 session `55` 个 durable frame，真实 UI run 的 entities seq `37/39/40` 分别对应 `run_started/function close/run_terminal(completed)`，ephemeral node frame 保持 seq `0`。frontend 无 Flutter/Dart/RenderFlex/overflow/lost-device/unhandled application red line，backend 无 panic/FATAL/ERROR/WARN；受管网关 challenge/install/models 均 HTTP 200，本 workflow 为 function-only，未伪造 chat completion。`rig-check.sh` 收台前五通道通过，`rig-down.sh` 后 owned process groups 归零，录屏经 ffprobe 可读。

本格保留并明确排除两类非产品红观察：最初 shell 写入的 function v1 含字面量 `\\n`，造成 SyntaxError，已用真实 function edit 修复并由 v2/v3 成功 run 证明；Computer Use 对自定义 `AnCodeEditor` 的 `set_value` 只改变 AX 层、未触发 Flutter `onInput`，随后用 Example/empty payload 真实走通 UI，不把工具限制伪报成产品 bug。本格没有产品源代码修复，证据文件、API JSON、UI AX 树和 SQLite 交叉检查均已保存。

正式绿证据为 `/private/tmp/anselm-rig-ep062-flowrun-start-20260808/sessions/20260808-005702/evidence/EP-062-flowrun-start-real-session.md`，API 证据为同目录 `EP-062-flowrun-start-api-probes.json`，最终帧为 `EP-062-final-frame.png`；账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-062-flowrun-start-ledger-reaudit.md`。按 `G1/F2/A5/C4/G2` 写入五格，正式账本 `995→1000 judgments`，COVERAGE `EP-062=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(1000)，清册 `848 rows / 194 carried / 0 tombstones`。集中写账触发的 `gap-too-fast` 已由独立复审销账，25 秒阈值、通过速率和发现率算法未改。

按用户删除授权，独立无 App/no-LLM cleanup `/private/tmp/anselm-rig-ep062-cleanup-20260808/sessions/20260808-011934` 已精确删除本格 2 workflow、1 function：DELETE `204×3`，后续 exact GET `404×3`，live workflow list 为空，seeded `greet`、`sync_inventory` 未动；SQLite 保留 2 个 workflow tombstone、1 个 function tombstone、3 个 workflow versions、8 个 flowruns、8 个 function executions，fixture relations=0。清理证据为同 cleanup session 的 `evidence/EP-062-flowrun-start-cleanup.md`。批次十九当时 **30/50**，未到 50 格未跑统一长门禁、不提交；EP-063 已在上方完成。

### 5.2 历史状态快照（EP-061，批次十九 25/50）

**历史前线（2026-08-08 00:54，清册 EP-061 已完成，批次十九 25/50）。** `GET /api/v1/flowruns` 已按完整产品目的完成验收：用户既可以在 Workflow detail 的 Runs cockpit 以 keyset 继续加载历史，也可以在 Scheduler 以 offset 页码浏览完整工作区历史；两种分页共享同一过滤语义，cursor 与 offset 同时出现、非法 offset/status/origin/RFC3339 时间、未知 workflow/trigger 组合都明确失败或诚实返回空集，不会静默切页或伪造状态。

本格最终真实 session `/private/tmp/anselm-rig-ep061-flowruns-20260808/sessions/20260808-003250` 使用新 binary、独立数据目录、真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、真实 Anselm gateway LLM tap。录屏封口 `630.583333s / 2784x1808 / 60fps`，终帧为同目录 `evidence/EP-061-final-frame.jpg`。真实 App 路径覆盖 `Entities → ep061-list-workflow → Runs` 的 keyset `20→28`、`Scheduler → ep061-list-workflow` 的 offset `29` 行和第 1/2/3 页、Manual/Webhook 来源筛选、失败 workflow 的 traceback/Replay/AI triage inspector，以及 approval workflow 的 Waiting/Running/Cancelled 状态、approval inspector 和 Cancel run。

REST/SQLite/产品数据事实一致：主列表 workflow 真实产生 `29` 条完成历史（28 manual + 1 webhook）；工作区验收 fixture 的最终历史为 `34` 条，其中 `30 completed / 2 failed / 2 cancelled`，来源为 `31 manual / 3 webhook`。API 探针验证 cursor 与 offset 页无重叠且顺序均为 `(startedAt,id) DESC`，offset 与 cursor 内容一致；`startedAfter`/`startedBefore` 和 completed 时间窗符合左闭右开；failed/running/cancelled/completed 桶、未知复合筛选及所有非法输入均与 handler/store 契约一致。Scheduler 过滤后的页数和空态可解释，失败详情的完整 traceback 在右侧 dossier 可读；approval CTA 在 inspector 下方可达，没有截断、死 loading、状态错配或视觉跳变。

五通道已封存：backend journal `915` 行、frontend journal `17` 行、SSE journal `111` 行（`107` 个 stream frame）、LLM journal `10` 行。notifications durable seq `16..37`、entities durable seq `7..77` 均严格单调；messages stream 已连接且 deterministic workflow 不虚构 durable mutation。frontend 无 Flutter/Dart/RenderFlex/overflow/lost-device/unhandled application red line，backend 无 panic/FATAL/ERROR/WARN；受管网关 challenge/install/models 均 HTTP 200，本格没有 LLM node，故不伪造 completion。`rig-check.sh` 收台前五通道通过，`rig-down.sh` 后 owned process groups 归零。

正式绿证据为 `/private/tmp/anselm-rig-ep061-flowruns-20260808/sessions/20260808-003250/evidence/EP-061-flowruns-real-session.md`，API 证据为同目录 `EP-061-flowruns-api-probes.json`，SSE 汇总为 `EP-061-sse-summary.json`；账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-061-flowruns-ledger-reaudit.md`。按 `G1/F2/A5/C4/G2` 写入五格，正式账本 `990→995 judgments`，COVERAGE `EP-061=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(995)，清册 `848 rows / 193 carried / 0 tombstones`。集中写账触发的 `gap-too-fast` 已由独立复审销账，25 秒阈值、通过速率和发现率算法未改；本格没有产品源代码修复，针对性 Go/Flutter 测试、diff check 和 coverage check 均通过。

按用户删除授权，独立无 App cleanup `/private/tmp/anselm-rig-ep061-cleanup-20260808/sessions/20260808-004956` 已精确删除本格 5 workflow、5 trigger、1 approval、1 deliberate-failure function：全部 DELETE `204`，后续精确 GET `404`，`ep061-` live lists 为空；approval 的 parked fixture 先经 `:kill` 收束，避免残留 draining。SQLite 真相为 workflow tombstones `5`、trigger tombstones `5`、approval/function tombstone 各 `1`、fixture relations `0`，但保留 `34` flowruns、`8` workflow versions、`4` trigger firings；seeded `greet`、`sync_inventory` 和 `演示工作台` 未动。清理证据为同 cleanup session 的 `evidence/EP-061-flowruns-cleanup.md`。批次十九当前 **25/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-062。

### 5.2 历史状态快照（EP-060，批次十九 20/50）

**当前前线（2026-08-08 00:27，清册 EP-060 已完成，批次十九 20/50）。** `GET /api/v1/workflows/{id}/versions/{version}` 已按完整产品目的完成验收：用户可以从 Entities 找到 workflow、进入 Versions tab 看见可读的版本图；REST 的数字版本号和 opaque 版本 ID 都只返回路径 `{id}` 所属 workflow 的 immutable graph，跨父 ID、未知数字、0、负数和未知 opaque ID 都统一给出明确的 `WORKFLOW_VERSION_NOT_FOUND`，不会把另一 workflow 的图渲染到当前上下文。

本格首轮真实 session `/private/tmp/anselm-rig-ep060-workflow-version-20260808/sessions/20260808-001344` 复现并冻结了真实产品红线：workflow A 的 `wfv_9ae3d6a00dc235c5` 经 workflow B 的 URL 仍返回 `200`，响应 `workflowId` 却是 A；数字版本边界当时已正确 404。红证据 `/private/tmp/anselm-rig-ep060-workflow-version-20260808/sessions/20260808-001344/evidence/EP-060-workflow-version-red.md` 永久保留，不计绿。stop-and-fix 新增 `GetVersionForWorkflow(workflowID,versionID)` 父级查询：store 用 `workflow_id + id`，app 保持 `graphParsed` 解码，HTTP opaque 分支不再调用执行器所用的全局 pinned `GetVersion`；同步补 store/app/handler 回归和 workflow/API 文档。既有 scheduler 全局 pinned 读取未改变。

修复后的最终真实 session `/private/tmp/anselm-rig-ep060-workflow-version-fixed-20260808/sessions/20260808-001940` 使用新 binary、独立数据目录、真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、真实 Anselm gateway LLM tap。真实 App 路径为 `Entities → Workflow → ep060-fixed-workflow-a → Versions`：header 显示 `v2 / inactive / serial`，Versions 首行自动展开，显示 `v1 → v2`、真实 change reason、`+0 -0` 和完整 trigger graph JSON；v1 仍可见，最终帧没有代码裁切、重叠、死 loading、错误 workflow 名或右岛遮挡。录屏封口 `106.916667s / 2784x1808 / 60fps`，最终帧为同目录 `evidence/EP-060-final-frame.jpg`。

REST/SQLite 事实一致：A `/versions/2` 与 A `/versions/wfv_3312be856281502c` 均 `200`、`workflowId=A`、含 `graphParsed`；B 读取 A opaque ID、B `/versions/2`、A `/versions/0`、`-1`、`999`、`unknown` 均为 `404 WORKFLOW_VERSION_NOT_FOUND`。backend 无 panic/FATAL/ERROR/WARN 或未解释应用错误；frontend 无 `Unhandled exception`、`FlutterError`、RenderFlex/overflow、lost-device 或 Dart error；SSE 三流连接，notifications durable `16,17,18` 严格单调，read-only Versions 路径没有伪造 message/entity durable mutation；LLM tap 的真实 challenge/install/models 均 `200`，本格不虚构 chat completion。`rig-check` 收台前五通道全绿，`rig-down` 后 owned process groups 归零。

独立 cleanup `/private/tmp/anselm-rig-ep060-cleanup-20260808/sessions/20260808-002310` 已按用户授权软删两 workflow 与两 trigger：DELETE `204×4`，后续四个 GET `404`，live workflow/trigger lists 为空；SQLite 保留两条 workflow `deleted_at`、3 条 immutable `workflow_versions`、两条 trigger tombstone，fixture relations=0，seeded `演示对话` 仍唯一对话，cleanup 收台无残留。正式绿证据为 `/private/tmp/anselm-rig-ep060-workflow-version-fixed-20260808/sessions/20260808-001940/evidence/EP-060-workflow-version-final-green.md`，独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-060-workflow-version-ledger-reaudit.md`。五级裁决由 `judge.py` 按 `G1/F2/A5/C4/G2` 写入，正式账本 `985→990 judgments`，COVERAGE `EP-060=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(990)，清册 `848 rows / 192 carried / 0 tombstones`。集中写账触发的 `gap-too-fast` 已依据独立复审 ack，25 秒阈值、通过速率与发现率算法未改。批次十九当前 **20/50**，未到第 50 格不跑统一长门禁、不提交；下一原子前线为 EP-061 `GET /api/v1/flowruns`。

### 5.2 历史状态快照（EP-059，批次十九 15/50）

**历史前线（2026-08-08 00:07，清册 EP-059 已完成，批次十九 15/50）。** `GET /api/v1/workflows/{id}/versions` 已按完整产品目的完成验收：真实用户从 Entities 找到 workflow，打开详情的 Versions tab，在 20 条边界看到明确的 `Load more`，加载后得到完整 v22 到 v1 历史；首个版本自动展开、差异可读、分页追加不重复，完成后不留下死的 Load more 控件。

EP-059 专用真实台架 `/private/tmp/anselm-rig-ep059-workflow-versions-20260808/sessions/20260807-235745` 使用独立数据目录和端口，由同一 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、真实 Anselm gateway LLM tap。fixture workflow `wf_e6a23f5c4c1e6ad0` 由 trigger `trg_dc40065b733c5085` 驱动，创建后通过 21 次真实 `:edit` 形成 v1..v22；版本页首屏显示 v22..v3，点击 `Load more` 后补齐 v2、v1。最终录像封口 `251.178333s / 2784x1808 / 60fps`，尾帧回看显示 v15..v1，右侧 workflow 面板稳定，无红卡、截断或死控件。

REST/SQLite/UI 事实一致：REST `limit=20` 第一页严格为 `22..3`，`hasMore=true` 且返回 opaque cursor；用该 cursor 的第二页严格为 `2..1`，`hasMore=false`；按数字 `22` 和 opaque version ID 单读都指向 v22。`limit=0` 返回 `400 INVALID_REQUEST`，坏 cursor 返回 `400 MALFORMED_CURSOR`；SQLite 保留全部 22 个 `workflow_versions` 行。构造 fixture 时曾因 zsh 将未加括号的 `$WF:edit` 解释成参数展开而得到错误路由，已改为 URL 编码冒号；这是台架脚本插值失误，不是产品路径，未计作产品红证据。

五通道事实一致：backend 无 panic/FATAL/未解释应用错误；frontend 只有正常 `Dart VM Service` 启动行，无 `Unhandled exception`、`FlutterError`、RenderFlex/overflow/lost-device；SSE 三流均连接，notifications durable `16..37` 严格单调无 gap，messages/entities 在本只读旅程中没有新增 durable 帧；LLM tap 记录真实 challenge/install/models 握手，本格不虚构 chat completion。`rig-check` 收台前五通道全绿，`rig-down` 后 owned process groups 归零，`screen.mov` 经 ffprobe 可读。

正式绿证据 `/private/tmp/anselm-rig-ep059-workflow-versions-20260808/sessions/20260807-235745/evidence/EP-059-workflow-versions-final-green.md`，最终帧同目录 `EP-059-final-frame.jpg`；账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-059-ledger-alarm-reaudit.md`。五级裁决由 `judge.py` 按 `G1/F2/A5/C4/G2` 写入，正式账本 `980→985 judgments`，COVERAGE `EP-059=✓✓✓✓✓`，清册检查为 `848 rows / 191 carried / 0 tombstones`。集中写账打开的 `gap-too-fast` 已由独立录屏、五通道、REST/SQLite、SSE 与最终帧复审后 ack；25 秒阈值、通过速率和发现率算法均未改，`alarms.py check` clean(985)，anchors `10/10`。

按用户删除授权，独立无 App cleanup `/private/tmp/anselm-rig-ep059-cleanup-20260808/sessions/20260808-000634` 已将本格 workflow、trigger 软删：DELETE `204×2`，后续 GET `404×2`，live workflow/trigger 列表为空；SQLite 主行保留 `deleted_at`，22 个版本行保留，fixture relations=0，seeded `演示对话` 未动，收台无残留。批次十九当前 **15/50**，未到第 50 格不跑统一长门禁、不提交；下一原子前线为 EP-060。

### 5.2 历史状态快照（EP-058，批次十九 10/50）

**历史前线（2026-08-07 23:52，清册 EP-058 已完成，批次十九 10/50）。** `POST /api/v1/workflows/{id}:iterate` 已按完整产品目的完成验收：真实用户从 Workflow 行选择 `Edit with AI` 后进入持久 AI 编辑对话，能用自然语言要求修改图，AI 会读取被提及的 workflow、trigger、relations 和 agent，再产生一笔可核对的新 workflow version；空请求和不存在目标都给出明确错误，不创建幽灵 conversation。

EP-058 首轮真实 session `/private/tmp/anselm-rig-ep058-workflow-iterate-20260807/sessions/20260807-230750` 暴露 hosted model 的 `get_trigger`/workflow ops 形状问题和可见失败活动；fixed2 `/private/tmp/anselm-rig-ep058-workflow-iterate-fixed2-20260807/sessions/20260807-232114` 又暴露重复 trigger 调用与原始错误重复展示；fixed3 `/private/tmp/anselm-rig-ep058-workflow-iterate-fixed3-20260807/sessions/20260807-233252` 证明即使 mention 带唯一 trigger ID，模型仍可能首轮发空参 `get_trigger`。三条红链全部保留，不计绿。stop-and-fix 只加入已观测 alias 的窄兼容、唯一证据 trigger ID 修复、canonical `op`/hosted `type` 归一化，以及成功 activity 清理同目标旧失败 stage projection； durable transcript 仍保留真实失败事实，失败实体读取不再重复渲染原始错误。

最终真实 session `/private/tmp/anselm-rig-ep058-workflow-iterate-fixed4-20260807/sessions/20260807-233816` 由同一 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、真实 Anselm gateway LLM tap。第一次交互输入没有真正进入 answer 槽，产生 `Empty answer`，该观察被保留且不计绿；随后以明确英文意图重新提交，模型只完成一次真实 `edit_workflow`：workflow `wf_3180aae05499c1f9` 从 v1 变为 v2，图为 `entry(trg_0dee30ab43f0ecfa) → summarize(agent ag_87bc026f0b6d1c7c)`。App 最终显示 `Edited`、v2 和三条成功 Activity，没有红卡、retry 或重复 mutation；录屏封口 `571.585000s / 2784x1808 / 60fps`。

五通道事实一致：backend 无 panic/FATAL/ERROR/未解释应用告警；frontend 无 Dart/Flutter/RenderFlex/overflow/Unhandled 红线，只有已知 macOS IMK runner 环境行；SSE 三流全连接，durable `messages 1..94`、`entities 7..8`、`notifications 16..19` 单调无 gap，ephemeral delta 保持 `seq=0`；LLM wire 真实 chat responses 全 200，最后一笔 body 与 UI/REST 图完全一致。REST 对证 v2 graph、built-in conversation 和 inactive 状态；负向 whitespace 返回 `400 EMPTY_ITERATE_REQUEST`，missing workflow 返回 `404 WORKFLOW_NOT_FOUND`，两者前后 conversation 数不变。

本格 targeted Go tests、相关 Flutter tests、`flutter analyze`、`git diff --check` 全绿；`rig-check` 收台前五通道全绿。五级裁决已由 `judge.py` 按 `G1/F2/A5/C4/G2` 写入，正式账本 `975→980 judgments`，COVERAGE `EP-058=✓✓✓✓✓`，清册检查为 `848 rows / 190 carried / 0 tombstones`。集中写账打开的 `gap-too-fast` 已以独立复审证据 ack，25 秒阈值与三曲线算法未改，`alarms.py check` clean(980)，anchors 重新校准为 `10/10`。

证据：最终绿证据 `/private/tmp/anselm-rig-ep058-workflow-iterate-fixed4-20260807/sessions/20260807-233816/evidence/EP-058-workflow-iterate-final-green.md`，账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-058-ledger-alarm-reaudit.md`。按用户删除授权，独立无 App cleanup `/private/tmp/anselm-rig-ep058-cleanup-20260807/sessions/20260807-235013` 已将本格 conversation、workflow、trigger 软删：DELETE `204×3`，后续 GET `404×3`，live workflow/trigger 列表为空，SQLite 保留 2 个 workflow version、4 条 message、42 个 block，fixture relations=0，seeded `演示对话` 未动，收台无残留。批次十九当前 **10/50**，未到第 50 格不跑统一长门禁、不提交；下一原子前线为 EP-059 `GET /api/v1/workflows/{id}/versions`。

### 5.2 历史状态快照（EP-056，批次十八 50/50）

**历史前线（2026-08-07，清册 EP-056 已完成，批次十八 50/50）。** `POST /api/v1/workflows/{id}:revert` 已按完整产品目的完成验收：用户在 Workflow 的 Versions 页面能看懂版本差异、明确选择历史版本并看到 active 指针切换；回退不删除版本历史、不制造新版本，非法版本号必须给出明确错误。

最终真实 session `/private/tmp/anselm-rig-ep056-workflow-revert-20260807/sessions/20260807-214211` 由同一 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三条独立 SSE witness、LLM tap 和受管网关。真实 UI 从 v3 依次打开 More actions → Set active，先切到 v2、再切到 v1；每次 header、绿色 active marker 和版本历史立即一致，v3 的 diff 仍可读，未出现跳变、遮挡、截断或把历史版本从界面抹掉。最终录屏 `338.140000s / 2784x1808 / 60fps`，关键帧为 `EP-056-final-v2-active.jpg` 与 `EP-056-final-v1-active.jpg`。

REST/SQLite/SSE 交叉一致：两次真实 UI revert 均返回 `200`；version `999` 与 `0` 均返回 `404 WORKFLOW_VERSION_NOT_FOUND`；最终 active version 为 `wfv_1da2f4946f7dee62`（v1），v1/v2/v3 三行版本历史完整保留，未产生 v4。notifications durable seq `16..20` 单调记录 workflow created/edited/reverted，三流连接和收台无 gap；LLM tap 记录真实 challenge/install/models readiness，不为确定性 revert 伪造模型 completion。

五通道封口：backend journal `459` 行无 panic/FATAL/WARN/ERROR；frontend journal `76` 行仅有已审阅的固定 AXTree tooling pattern，没有 Dart/FlutterError/RenderFlex/overflow/Unhandled/lost-device 运行期红线；ssetap 的 `messages/entities/notifications` 三流均连接并正常 EOF；窗口录制可由 ffprobe 读取，`rig-check` 通过，`rig-down` 后 owned process groups 归零。正式绿证据为 `/private/tmp/anselm-rig-ep056-workflow-revert-20260807/sessions/20260807-214211/evidence/EP-056-workflow-revert-final-green.md`，ledger/alarm 独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-056-workflow-revert-ledger-alarm-reaudit.md`；正式账本 `965→970` 按 `G1/F2/A1/C4/G2` 写入五格绿，anchors `10/10`，`alarms.py check` clean(970)，`gen_coverage.py --check` 为 `848 rows / 188 carried / 0 tombstones`，阈值和算法未改。

统一批次门禁已在 50/50 后一次完成：`make verify` 的 backend/frontend/docs/demo 全绿；backend `mise exec -- go test -count=1 -timeout 20m ./...` 全绿；本批修复涉及的前端定向回归 `79` 项与 `flutter analyze` 全绿；独立黑盒 `make -C backend testend` 全绿（`testend/scenarios 298.841s`）。证据与源码均通过 `git diff --check`、gofmt/仓库格式门禁，未放宽任何警报或裁决阈值。

证据封存后按用户授权用独立无 App cleanup session `/private/tmp/anselm-rig-ep056-cleanup-20260807/sessions/20260807-220655` 删除专用 workflow/trigger：workflow 首次 DELETE `204`、幂等重试 `404`，trigger DELETE `204`，后续对象 GET 均 `404`；SQLite 保留 workflow 的 3 个版本，软删除主行、执行/节点历史保留，fixture relations 为 0，cleanup backend 无红线，收台后无残留进程。批次十八由 **45/50→50/50**；该批收口后的下一原子前线为 EP-057，现已在批次十九第 5 格完成。

### 5.2 历史状态快照（EP-055，批次十八 45/50）

EP-055 `POST /api/v1/workflows/{id}:edit` 首轮暴露旧 viewport 未 fit 和全屏编辑器缺少错误 notice host 两个产品问题；stop-and-fix 后，pristine viewport 会在结构变更后 fit，用户主动变换的 viewport 保持，全屏 graph/editor 路由可见结构化 `WORKFLOW_INVALID_GRAPH`。最终真实 session `/private/tmp/anselm-rig-ep055-workflow-edit-20260807/sessions/20260807-212105` 完成合法保存与 invalid graph 反馈，REST/SQLite/SSE、前端运行期和清理证据均已封存；账本 `955→960` 红、`960→965` 绿，COVERAGE `EP-055=✓✓✓✓✓`，cleanup `/private/tmp/anselm-rig-ep055-cleanup-20260807/sessions/20260807-213318` 无残留。

### 5.2 历史状态快照（EP-050，批次十八 20/50）

**历史前线（2026-08-07，清册 EP-050 已完成，批次十八 20/50）。** `POST /api/v1/workflows/{id}:trigger` 已按完整产品目的完成验收：真实用户从 Scheduler workflow 详情页发现 `Run now`，点击后获得即时执行反馈，能在 Matrix、Runs 和旗舰详情继续追踪同一 run；手动执行不改变 workflow 的 `Inactive` 生命周期，也不伪装成触发器真实 fire。空 body 与带 payload 的手动执行都能收口，错误 payload 被明确拒绝且不会制造幽灵 run。

正式 session `/private/tmp/anselm-rig-ep050-workflow-trigger-20260807/sessions/20260807-180921` 由 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三条独立 SSE witness、LLM tap 和受管网关。真实 App 从 Scheduler Overview 进入 `ep050-manual-run`，页面可见 `Inactive`、`Run now`、最近 7 天统计、Matrix、Runs 与 Triggers；点击 `Run now` 后 toast 显示 `Run started · fr_e87daec34cb74b0a`，统计变为 `Success 100%`，出现绿色 `Manual · 18:12`。第二次合法 payload 执行后 UI 实时出现第二条绿色 `Manual · 18:15`，打开运行详情显示 `Done`、`Completed`、`0ms`、v1 pinned version、一个 completed trigger 节点；最终帧无截断、重叠、空白错误态或遮挡关键操作。

后端/数据真相交叉一致：两次成功请求均为 `202`，flowrun 分别为 `fr_e87daec34cb74b0a` 与 `fr_58e12b1ffac09e2e`；两条 flowrun 均 `status=completed`、`origin=manual`、pin 到 `wfv_fa4de7baee6d78fe`。第二次 `start` trigger 节点结果在 REST 与 SQLite 均原样保留 `{"count":2,"message":"EP050 payload","nested":{"ok":true}}`。触发器仍显示 `never fired`，workflow 仍 inactive。错误请求 `{"payload":"not-an-object"}` 返回 `400 INVALID_REQUEST`，随后列表仍恰有两条 run。

五通道已经封口：录屏 `427.206667s / 2784x1808 / 60fps`；backend `549` 行无应用 panic/WARN/ERROR；SSE `notifications/entities/messages` 三流均连接，entities durable seq `1..4` 严格记录两次 `run_started→run_terminal(completed)`，收台以 EOF 正常断开；frontend `17` 行没有 Dart、FlutterError、RenderFlex、overflow、Unhandled、lost-device 或运行期应用红线，唯一的启动阶段 Flutter runner `Failed to foreground app; open returned 1` 已在 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-050-frontend-runtime-review.md` 独立归因并保留；LLM tap 只有 readiness，因为本路径是确定性 trigger 节点，不虚构模型 completion。

正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-050-workflow-trigger-final-green.md`，独立警报复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-050-ledger-alarm-reaudit.md`，最终 UI 帧为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-050-workflow-trigger-final-frame.png`；anchors 重新校验 `10/10` 后按 `G1/F2/A5/C4/G2` 写入 `COVERAGE.md` 为 `✓✓✓✓✓`，正式账本 **910→915 judgments**。五格写入触发的 `gap-too-fast`/`discovery-collapse` 已逐项复审并 ack，25 秒间隔阈值、5% discovery floor 与算法均未修改，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 182 carried / 0 tombstones`。

EP-050 没有源代码修复；真实 session 在交互前 `rig-check` 通过，`rig-down` 后 Flutter/backend/ssetap/llmtap/recorder 进程组归零。批次十八当前 **20/50**；按既定规则未到 50 格不运行统一长门禁、不提交。下一原子前线为 `EP-051 POST /api/v1/workflows/{id}:stage`，本批累计到 50 格后再统一收台、跑完整门禁、审计并提交。

### 5.2 历史状态快照（EP-048，批次十八 10/50）

**当前前线（2026-08-07，清册 EP-048 已完成，批次十八 10/50）。** `PATCH /api/v1/workflows/{id}` 已按完整产品目的完成验收：
真实用户从 Workflow 详情的 Run governance 卡直接编辑并发策略，不需要绕到 API；下拉内五种策略均有完整可读的运行语义，选择后通过既有 meta PATCH 收口，
不创建新版本，失败路径仍由统一错误提示和后端重读负责。wire 值与人类文案明确分离：`buffer_one` 在界面显示为 `Keep latest`，而不是把机器枚举直接丢给用户。

首轮真实 session `/private/tmp/anselm-rig-ep048-workflow-patch-20260807/sessions/20260807-171935` 冻结为红：详情治理卡只有静态 `Concurrency: serial`，
AX 树没有按钮/下拉，用户只能用直接 PATCH 验证后端能力；红证据与录屏永久保留。第一修复 session
`/private/tmp/anselm-rig-ep048-workflow-patch-fix-20260807/sessions/20260807-172937` 已能真实选择策略，但视觉复核发现菜单提示在实际宽度下被省略号截断，仍不计绿。
stop-and-fix 将五条解释压缩到完整可读的短句，并同步中英文 i18n、生成字符串、fixture widget regression 与实体 feature 文档。

最终 session `/private/tmp/anselm-rig-ep048-workflow-patch-fix-20260807/sessions/20260807-173308` 由 conductor 托管真实 Flutter App、Computer Use、窗口录制、
frontend console、backend journal、三条独立 SSE witness、LLM tap 和受管网关。真实 App 从 `Entities → Workflow → ep048-workflow-patch` 进入详情，
打开治理卡下拉后完整显示 `Serial / Queue each trigger`、`Skip while running / Drop while running`、`Keep latest / Keep newest pending`、
`Replace current / Cancel current run`、`Run in parallel / Overlap runs`；选择 `Keep latest` 后详情稳定回显该策略，`v1`、图、生命周期、告警和右侧运行面板均无跳变、
裁切、重叠或错误红面。

真实后端记录 `PATCH /api/v1/workflows/wf_a51ce934d1b4c9e1` 为 `200`，随后详情 GET 为 `200`；SSE notifications 收到 durable `workflow.updated` 帧，
seq 单调。SQLite 独立证明最终 wire 值为 `buffer_one`、`active_version_id=wfv_9520bac4b77eae9c` 且版本数仍为 `1`；并发策略改变没有版本 bump。
未知实体负边界与初始直接 PATCH 探针均保留在 session evidence，不将后端能力误当作产品入口证据。

五通道已经封口：最终录屏由 `rig-down` 封存，`backend.log`、`sse.jsonl`、`frontend.log`、`llm.jsonl` 与 manifest 齐全；启动时 `rig-check` 证明五通道物理归属，
收台后 Flutter/backend/ssetap/llmtap/recorder 进程组全部归零。backend 无应用 `panic/FATAL/ERROR/WARN`，frontend 无 Dart/Flutter/RenderFlex/overflow/Unhandled 红线；
启动器的已知 foreground 返回值已单独解释，不冒充 Flutter 错误。此项不触发模型调用，LLM tap 只记录 ready，不伪造 completion 证据。

正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-048-workflow-patch-final-green.md`，红证据为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-048-red-no-concurrency-affordance.md`，独立警报复审为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-048-ledger-alarm-reaudit.md`；anchors 重新校验 `10/10` 后按 `G1/F2/A1/C4/G2` 写入 `COVERAGE.md` 为 `✓✓✓✓✓`，
正式账本 **900→905 judgments**。五格写入触发的 `gap-too-fast`/`discovery-collapse` 已依红绿分离、完整录屏、五通道 journals、REST/SQLite 和 targeted regression 独立复审并 ack；
25 秒间隔阈值、5% discovery floor 与算法均未修改，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 180 carried / 0 tombstones`。

本格变更已通过 `make gen`、`mise exec -- flutter test test/features/entities/ui/detail/workflow_overview_test.dart`（11 tests）、目标文件 `flutter analyze`、
`go test ./internal/app/workflow ./internal/transport/httpapi/handlers` 与 `git diff --check`。批次十八当前 **10/50**；按既定规则未到 50 格不运行统一长门禁、不提交。
下一原子前线为 `EP-049 DELETE /api/v1/workflows/{id}`，本批累计到 50 格后再统一收台、跑完整门禁、审计并提交。

### 5.2 历史状态快照（EP-045，批次十七 45/50）

**当前前线（2026-08-07，清册 EP-045 已完成，批次十七 45/50）。** `POST /api/v1/workflows` 已按完整产品目的完成验收：
用户在真实 Chat 中提出“复用既有 trigger 创建工作流”的意图后，模型先找到正确 trigger，再以一次 mutation 创建 v1；
workflow 只有一个 trigger 节点、保持 inactive、元数据完整，UI、REST、SQLite、SSE 与受管网关 wire 一致，且不留下失败卡或 retry。

本格首轮红 session `/private/tmp/anselm-rig-ep045-workflow-create-20260807/sessions/20260807-152351` 暴露两类台架/产品问题：
Computer Use `type_text` 丢失下划线和部分标点，导致原始输入不能作为绿证据；模型随后把 `nodeId/triggerId` 发成不受支持的
扁平形状并自修。该输入保真问题与产品红证据永久保留，不计绿。

输入修正后第二个红 session `/private/tmp/anselm-rig-ep045-workflow-create-20260807/sessions/20260807-153602` 证明产品契约仍有
缺口：模型发出精确的 `nodes`/`edges` 图快照而不是 op 数组，后端正确拒绝，模型重试成功，但真实 UI 留下了
`create_workflow Failed` 与 `Draft unsaved · nothing was created` 红卡。该 session 也永久保留，不计绿。

stop-and-fix 增加了两层受限兼容并同步契约：`add_node` 只接受不冲突的
`nodeId → node.id`、`triggerId → node.ref`（仅 `kind=trigger`）；执行边界另接受顶层同时含 `nodes` 与 `edges` 数组的精确
图快照，将已观察的 `type/triggerId` 确定性映射为 `kind/ref` 并展开为 `add_node`，边展开为 `add_edge`。未知键、缺数组、
规范/别名冲突、非 trigger 使用 `triggerId` 和任意其它对象仍 fail-closed。`create_workflow` schema 改为明确描述规范嵌套
node/edge 形状；补 decoder、Execute、冲突拒绝和字符串化快照回归测试，并同步 workflow domain 与 tools 清册。

最终真实绿 session `/private/tmp/anselm-rig-ep045-workflow-create-20260807/sessions/20260807-154617` 由 conductor 托管真实 Flutter App、
Computer Use、窗口录制、frontend console、backend journal、三条独立 SSE witness、LLM tap 和真实受管网关完成。AX 在提交前确认
完整用户消息；模型执行一次 trigger search 和一次 `create_workflow`，没有 `tool execute failed`、没有 retry。稳定态 UI 只显示
`Created`：结果表有 `Name`、`Description`、`Tags`、复用的 `Trigger`、`Inactive (deactivated)` 和 `Version 1`，Activity 只有一条
成功触点，无红卡、裁切、重叠或空 draft。

后端最终事实：workflow `wf_64daa9eefc827154`、version `wfv_78be24cae05bd43f`/v1、`active=false`、`lifecycleState=inactive`；
graph 唯一节点为 `{id:"start",kind:"trigger",ref:"trg_f3b9a6e64e4a68e9}`，edges 为空；trigger `trg_f3b9a6e64e4a68e9`
只出现一次。五通道封口：screen `111.591667s / 2784x1808 / 60fps`；backend 无应用 WARN/ERROR/panic；messages/entities/notifications
三流均连接并有对应 tool/build/`workflow.created`/touchpoint；frontend 无 Dart/Flutter/RenderFlex/Unhandled/overflow 应用红线，仅保留
已知 macOS IMK host 噪声；LLM wire 的 proof/chat 请求均经 `https://api.anselm.website`，`rig-check` 通过、`rig-down` 封口且进程归零。

正式证据 `/private/tmp/anselm-rig-ep045-workflow-create-20260807/sessions/20260807-154617/evidence/EP-045-workflow-create-final-green.md`，
红证据为同目录的 `EP-045-workflow-create-red.md` 与 `EP-045-workflow-create-red-graph-snapshot.md`；独立复审
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-045-workflow-create-ledger-reaudit.md`。anchors `10/10` 后按 `G1/F2/A1/C4/G2`
写入 `COVERAGE.md` 为 `✓✓✓✓✓`，正式账本 **885→890 judgments**；两条统计警报按独立复审 ack，阈值与算法未修改，
`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 177 carried / 0 tombstones`。

批次十七当前 **45/50**；未到 50 格，不运行统一长门禁、不提交。下一原子前线为
`EP-046 GET /api/v1/workflows`。

### 5.2 历史状态快照（EP-043，批次十七 35/50）

**历史前线（2026-08-07，清册 EP-043 已完成，批次十七 35/50）。** `GET /api/v1/agents/{id}/executions`
已按完整产品目的完成验收：用户能在 Agent Logs 里看到完整执行历史、聚合计数和可展开的输入/输出/provider/model；
从 REST 或其它表面新增的真实执行会在已打开的 Logs 中自动出现，不能要求用户手动刷新，也不能让 Logs 与右侧运行台互相矛盾。

EP-043 首个真实负路径 session `/private/tmp/anselm-rig-ep043-agent-executions-20260807/sessions/20260807-143107`
发现未知父 Agent 被错误返回为 `200` 空历史；修复后 session `/private/tmp/anselm-rig-ep043-agent-executions-20260807/sessions/20260807-143520`
又捕到真实产品红线：外部新增 18 次执行后右侧运行台已显示 `21 total runs`，但已打开的 Logs 仍停在 `3 Done / 0 Failed`。
两套红证据永久保留，不计入绿判。

本格立即 stop-and-fix：Agent `SearchExecutions` 先校验父实体，未知父返回 `404 AGENT_NOT_FOUND`；`LogListNotifier` 订阅可执行
实体 scope 的 durable `FrameClose`，只把帧当作重取提示，按当前已加载窗口重读 REST 台账与 aggregates，保留仍在窗口内的展开行，
瞬时失败保留最近可信快照，并避开与 keyset load-more 的游标竞态。同步补 app/store/provider 回归测试及 API/domain/frontend 文档。

修复后的真实绿 session `/private/tmp/anselm-rig-ep043-agent-executions-20260807/sessions/20260807-144741` 验证：初始 UI 同屏
为 `21 Done / 0 Failed` 与 `21 total runs`；从 REST 真实执行输入 `number=42` 后，不点击刷新，Logs 自动变为 `22 Done`，右岛同步
变为 `22 total runs · last ok 3.6s`，最新行置顶并展开显示真实 execution ID、输入 `42`、输出 `1764`、provider `anselm`、model
`anselm-auto` 和 `Use this input`。REST 分页为 `20+2`、无重叠、aggregates `22/22/0`；`status=failed` 为空但聚合诚实，
非法 status 为 `422 AGENT_EXECUTION_INVALID_STATUS`，未知父为 `404 AGENT_NOT_FOUND`。

五通道封口：录屏 `183.773333s / 2784x1808 / 60fps`；backend `254` 行无应用 WARN/ERROR/panic/fatal 或 4xx/5xx；独立 SSE witness
三流均连接，Agent scope 真实收到 `open → seq=0 delta → durable close`；frontend `18` 行无 Dart/Flutter/RenderFlex/Unhandled/
overflow 应用红线，仅保留 raw journal 中已知的 macOS Flutter launcher foreground 噪声；LLM tap 真实绑定 `https://api.anselm.website`，
proof/chat 均 HTTP 200。`rig-check` 五通道通过，`rig-down` 封口、录屏可读且进程归零。

正式证据 `/private/tmp/anselm-rig-ep043-agent-executions-20260807/sessions/20260807-144741/evidence/EP-043-agent-executions-final-green.md`，
独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-043-agent-executions-ledger-reaudit.md`；anchors `10/10` 后按
`G1/F2/A1/C4/G2` 写入 `COVERAGE.md` 为 `✓✓✓✓✓`，正式账本 `875→880 judgments`。`gap-too-fast`/`discovery-collapse` 已依据红绿分离、
五通道 journal、REST/SQLite 与独立复审逐条 ack，阈值与算法未修改；`alarms.py check` clean，`gen_coverage.py --check` 为
`848 rows / 175 carried / 0 tombstones`。

批次十七当前 **35/50**；未到 50 格，不运行统一长门禁、不提交。下一原子前线为
`EP-044 GET /api/v1/agent-executions/{id}`。

### 5.2 历史状态快照（EP-042，批次十七 30/50）

**当前前线（2026-08-07，清册 EP-042 已完成，批次十七 30/50）。** `GET /api/v1/agents/{id}/versions/{version}`
已按完整产品目的完成验收：用户从真实 Agent 的 Versions 面板读取数字版本或 opaque `agv_` 版本 ID 时，
只能看到该 Agent 自己的版本；跨父版本和不存在的父 Agent 都必须明确拒绝，不能把另一 Agent 的代码伪装成当前版本。

EP-042 首个真实负路径 session `/private/tmp/anselm-rig-ep042-agent-version-detail-20260807/sessions/20260807-141645`
发现了真实数据边界缺陷：opaque 版本 ID 走了全局查找，错误地让另一 Agent 的 v4 以及未知父 Agent 返回 `200`。
本格立即 stop-and-fix：Agent domain/repository 增加 parent-scoped opaque lookup，app 层先校验父 Agent，数字和 opaque
路径统一使用父级边界；补 store/app 回归测试，并同步 API/domain 文档。红 session 永久保留，不计入绿判。

修复后的真实 session `/private/tmp/anselm-rig-ep042-agent-version-detail-20260807/sessions/20260807-142043` 验证：
自有数字 v4、opaque v4、自有数字 v1 均为 `200`；跨父数字/opaque v4 均为 `404 AGENT_VERSION_NOT_FOUND`；未知父
数字/opaque 均为 `404 AGENT_NOT_FOUND`；自有未知数字/opaque 均为 `404 AGENT_VERSION_NOT_FOUND`。SQLite 对证 active v4、
版本严格为 `[4,3,2,1]`。Computer Use 逐帧看到 v4→v3、v3→v2 diff，v1 的完整 prompt 与 earliest version，画面无裁切、
重叠、stale row、loading 残留或错误归属。

五通道封口：录屏 `129.010000s / 2784x1808 / 60fps`；backend `196` 行无 panic/fatal/error/warn 红线；独立 SSE witness
三流均连接并正常断开，本只读 GET 无 durable mutation frame；frontend `18` 行无 Dart/Flutter/RenderFlex/Unhandled/
overflow/失联红线；LLM tap 真实绑定 `https://api.anselm.website`，本确定性只读路径只有 ready、没有虚构 completion。
`rig-check` 五通道通过，`rig-down` 后进程归零，红绿 session、日志和关键帧均保留。

正式证据 `/private/tmp/anselm-rig-ep042-agent-version-detail-20260807/sessions/20260807-142043/evidence/EP-042-agent-version-detail-final-green.md`，
独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-042-agent-version-detail-ledger-reaudit.md`；anchors `10/10` 后按
`G1/F2/A1/C4/G2` 写入 `COVERAGE.md` 为 `✓✓✓✓✓`，正式账本 `870→875 judgments`。集中写账触发的
`gap-too-fast`/`discovery-collapse` 已依据红绿分离、五通道日志、REST/SQLite 交叉证据逐条 ack，阈值与算法未修改，
`alarms.py check` clean；`gen_coverage.py --check` 为 `848 rows / 174 carried judgments / 0 tombstones`。

批次十七当前 **30/50**；未到 50 格，不运行统一长门禁、不提交。下一原子前线为
`EP-043 GET /api/v1/agents/{id}/executions`。

### 5.2 历史状态快照（EP-041，批次十七 25/50）

**历史前线（2026-08-07，清册 EP-041 已完成，批次十七 25/50）。** `GET /api/v1/agents/{id}/versions`
已按完整产品目的完成验收：用户从真实 Agent 详情进入 `Versions`，能辨认 active v4、按新到旧阅读
v3/v2/v1，展开可读的 v3→v4 与 v2→v3 diff，并把 v1 明确识别为 earliest version；分页、数字版本号、
opaque `agv_` 版本号与不存在边界均返回诚实结果，不把不存在的 Agent 伪装成空历史。

EP-041 首个正确接线的 session `/private/tmp/anselm-rig-ep041-agent-versions-fixed-20260807/sessions/20260807-140230`
发现真实契约缺陷：未知父 Agent 的版本列表返回 `200 {data:[],hasMore:false}`，会把“实体不存在”误导成“实体存在但没有历史”。
本格立即 stop-and-fix：`agentapp.Service.ListVersions` 先 workspace-scoped 查 Agent 主实体，再进入版本分页；补充已知/未知父实体回归测试，
并同步 API/domain 文档。前一条接线错误的 `8806` session `/private/tmp/anselm-rig-ep041-agent-versions-20260807/sessions/20260807-140126`
和上述缺陷红 session 均保留，未混入绿证据；新 binary 在 `/private/tmp/anselm-rig-ep041-agent-versions-fixed-20260807/sessions/20260807-140622`
重新跑完整路径。

正路径 REST 真实返回分页 `[4,3] hasMore=true`、游标页 `[2,1] hasMore=false`，数字/opaque v4 均 200；数字 999、未知 opaque 版本均为
`404 AGENT_VERSION_NOT_FOUND`，未知父 Agent 为修复后的 `404 AGENT_NOT_FOUND`。SQLite 同时确认 active pointer 为 v4、版本严格为 `[4,3,2,1]`，无 v5
或 mutation。Computer Use 逐帧复核 Versions：v4/v3 diff、v1 earliest version 与完整 prompt 均可读，右岛稳定，无裁切、重复、stale row、
loading 残留或错误卡。

五通道封口：绿 session 录屏 `256.180000s / 2784x1808 / 60fps`；backend `320` 行无 panic/fatal/error/warn 红线；独立 SSE witness 三流均连接、
正常断开且本只读 GET 不产生伪造 durable mutation frame；frontend `18` 行无 Dart/Flutter/RenderFlex/Unhandled/overflow/失联红线；LLM tap 真实绑定
`https://api.anselm.website`，本确定性只读路径没有虚构 completion。`rig-check` 五通道全部通过，`rig-down` 后进程归零，绿/红 session、日志和关键帧均保留。

正式证据 `/private/tmp/anselm-rig-ep041-agent-versions-fixed-20260807/sessions/20260807-140622/evidence/EP-041-agent-versions-final-green.md`，
独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-041-agent-versions-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入
`COVERAGE.md` 为 `✓✓✓✓✓`，正式账本 `865→870 judgments`。集中写账触发的 `gap-too-fast`/`discovery-collapse` 已用独立复审、红绿分离和五通道日志
ack，阈值与算法未修改，`alarms.py check` clean；`gen_coverage.py --check` 为 `848 rows / 173 carried judgments / 0 tombstones`。

批次十七当前 **25/50**；未到 50 格，不运行统一长门禁、不提交。下一原子前线为
`EP-042 GET /api/v1/agents/{id}/versions/{version}`。

### 5.2 历史状态快照（EP-039，批次十七 20/50）

**历史前线（2026-08-07，清册 EP-039 已完成，批次十七 20/50）。** `POST /api/v1/agents/{id}:iterate`
已按完整产品目的完成验收：用户从 Agent 行菜单进入 `Edit with AI` 后得到可识别的新对话；seed 会话自动
命名并读取当前 Agent 配置，用户的后续要求只产生一次规范 `edit_agent` mutation，新版本立即 active，
Versions 显示可读 diff，修改后的 Agent 立即可执行，不产生重复 mutation、retry 或幻影会话。

真实 session `/private/tmp/anselm-rig-ep039-agent-iterate-20260807/sessions/20260807-134539` 由同一
conductor 托管真实 App、Computer Use、窗口录像、backend、三路独立 SSE witness、frontend console 和
受管网关 tap。真实对话 `cv_3438427f7e802314` 从 `Edit with AI` 开始，标题为
`Help me edit “EP036 Invoice Agent” with AI`；助手先展示 v3 的 name/description/prompt/mount/inputs/
outputs/knowledge，再按用户要求只新增 EP039 receipt 句子，铸造 v4
`agv_1890517a41cdc11b`，并在 UI 中显示 unchanged-fields 表和 `1 touched`。Versions 显示 `v3 → v4`
红绿 diff，v1/v2/v3 历史仍可读；随后真实 invoke 使用同一 Function mount 得到结构化
`{"receipt":"EP039","total":0}`。

负路径空请求只发一次，返回 `400 EMPTY_ITERATE_REQUEST`；未知 Agent 只发一次，返回 `404 AGENT_NOT_FOUND`。
两条负路径前后 conversation 数都为 1，Agent 版本严格为 `[4,3,2,1]`，没有 v5、retry、部分写入或幻影
会话。五通道封口：录屏 `301.048333s / 2784x1808 / 60fps`，三张关键帧保存在 session evidence；backend
`422` 行无 panic/fatal/error/warn 红线；SSE 三流连接且 notifications durable `1..3`、messages `1..35`、
entities `1..10` 连续无 gap；frontend `20` 行无 Dart/Flutter/RenderFlex/Unhandled/overflow/失联红线，
仅有已审计的 macOS launcher/IMK 平台噪声；LLM tap 真实连到 `https://api.anselm.website`，8 次真实
completion 响应均为 HTTP 200；REST、SQLite、UI、SSE 和 wire 对 v4、对话标题和最新 execution
`agx_c7ec1079661121` 一致，`rig-check`/`rig-down` 均封口且无残留。

正式证据 `/private/tmp/anselm-rig-ep039-agent-iterate-20260807/sessions/20260807-134539/evidence/EP-039-agent-iterate-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-039-agent-iterate-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入 `COVERAGE.md` 为 `✓✓✓✓✓`，正式账本 `860→865 judgments`。集中写账触发的 `gap-too-fast`/`discovery-collapse` 已依据独立复审和五通道证据 ack，阈值与算法未修改，`alarms.py check` clean；`gen_coverage.py --check` 为 `848 rows / 172 carried judgments / 0 tombstones`。

清册机械核对显示 `EP-040 GET /api/v1/agents/{id}/mount-health` 已在 2026-08-06 完成正式五级裁决，
账本已有 `G1/F2/A1/C4/G2`、COVERAGE 为 `✓✓✓✓✓`，其证据与独立复核均存在；本轮不重复写账或重跑。
批次十七当前 **20/50**；未到 50 格，不运行统一长门禁、不提交。下一原子前线为
`EP-041 GET /api/v1/agents/{id}/versions`。

### 5.2 历史状态快照（EP-038，批次十七 15/50）

**历史前线（2026-08-07，清册 EP-038 已完成，批次十七 15/50）。** `POST /api/v1/agents/{id}:edit`
已按完整产品目的完成验收：用户对 Agent 提交一次全量 Config snapshot 后，新版本立即成为 active，原有
Function mount、inputs、outputs 和其它配置不会静默丢失；真实 App 收到 lifecycle signal 后能重取详情，
Versions 能展示 `v2 → v3` 的红绿 diff、active 标记和历史，右岛清掉旧版本瞬态 Trace/Result 但保留 Recent。

真实 session `/private/tmp/anselm-rig-ep038-agent-edit-20260807/sessions/20260807-133427` 由同一
conductor 托管真实 App、Computer Use、窗口录像、backend、三路独立 SSE witness、frontend console 和
受管网关 tap。正确的全量请求只铸造 v3 `agv_76bde4aaf3c188ea`，prompt 含明确的 EP038 marker，mount、
inputs/outputs 和 `changeReason` 均保留；UI Overview 显示 `All mounts healthy`，Versions 显示 `+1 -1`
和 `v2 → v3`，v2/v1 历史仍可读。唯一的 `/agents/dit` 404 是台架 shell 插值错误，发生在有效 mutation
之前且没有产生版本变更，已在正式证据中明确排除，不冒充产品路径。

负路径对含未知字段 `wat` 的请求只发一次，返回仓内统一的 `400 INVALID_REQUEST`；之后 REST、SQLite、
Versions 和 active pointer 均仍是 v3，版本严格为 `[3,2,1]`，没有 v4、retry 或部分写入。五通道封口：
录屏 `150.373333s / 2784x1808 / 60fps`，三张关键帧保存在 session evidence；backend `231` 行无
panic/fatal/error/warn；SSE 三流连接且 notifications 仅有正路径 durable `seq=1 agent.edited`，无 gap
和负路径 mutation；frontend `18` 行无 Dart/Flutter/RenderFlex/Unhandled/overflow/失联红线；LLM tap
真实连到 `https://api.anselm.website`，本确定性 REST 格不需要 completion，未虚构模型证据；REST、SQLite、
UI、SSE 和 wire 对版本结果一致，`rig-check`/`rig-down` 均封口且无残留。

正式证据 `/private/tmp/anselm-rig-ep038-agent-edit-20260807/sessions/20260807-133427/evidence/EP-038-agent-edit-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-038-agent-edit-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入 `COVERAGE.md` 为 `✓✓✓✓✓`，正式账本 `855→860 judgments`。集中写账触发的 `gap-too-fast`/`discovery-collapse` 已由独立复审 ack，阈值与算法未修改，`alarms.py check` clean；`gen_coverage.py --check` 为 `848 rows / 171 carried judgments / 0 tombstones`。

批次十七历史位置 **15/50**；下一原子前线已由 EP-039 接续。

### 5.2 历史状态快照（EP-037，批次十七 10/50）

**历史前线（2026-08-07，清册 EP-037 已完成，批次十七 10/50）。** `POST /api/v1/agents/{id}:revert`
已按完整产品目的完成验收：用户可以在真实 Agent 详情的 Versions 中辨认 v1/v2、看到 diff 和 active
标记，切换 active 指针；切换后不把旧版本的 Trace/Result 冒充为新版本产出，同时保留 Recent 审计历史。

真实 session `/private/tmp/anselm-rig-ep037-agent-revert-20260807/sessions/20260807-132025` 先通过
REST 构造带明确 v2 diff 的 fixture，再由 Computer Use 在真实 App 中完成 v2→v1；随后在 v2 active 下用
受管网关执行 `subtotal=100,tax=10` 得到 `total=110`，再在结果可见时切回 v1。最终画面显示 v1 active、
v2 历史仍在、Recent 保留最新 9.9s 运行，但右岛没有旧 v2 Trace/Result 残留。故障边界用真实 HTTP
`version=999` 只调用一次，返回 `404 AGENT_VERSION_NOT_FOUND`，active v1 不变且没有 v3/重试。

五通道封口：录屏 `427.071667s / 2784x1808 / 60fps`，关键帧保存于 session evidence；backend `546`
行无 panic/fatal/error/warn；SSE 三流全连接，notifications durable `1..4`、本次 entities `1..10` 单调无 gap，
seq=0 delta 仍为 ephemeral；LLM tap 连接真实 `https://api.anselm.website`，proof/chat 状态均为 200；
SQLite、REST、UI、SSE 和 wire 对 `total=110` 与最终 active v1 一致。frontend 仅有固定格式的 AXTree
旧节点观察器噪声，session-scoped `frontend-ax-review.md` 记录了三秒静置不增长和无 Dart/Flutter/
RenderFlex/Unhandled/overflow 红线；未知格式仍保持 fail-closed。`rig-check` 复核通过，`rig-down` 封口且无残留。

正式证据 `/private/tmp/anselm-rig-ep037-agent-revert-20260807/sessions/20260807-132025/evidence/EP-037-agent-revert-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-037-agent-revert-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入 `COVERAGE.md` 为 `✓✓✓✓✓`，正式账本 `850→855 judgments`。集中写账触发的 `gap-too-fast`/`discovery-collapse` 已由独立复审 ack，阈值未放宽，`alarms.py check` clean；`gen_coverage.py --check` 为 `848 rows / 170 carried judgments / 0 tombstones`。

批次十七历史位置 **10/50**；下一原子前线已由 EP-038 接续。

### 5.2 历史状态快照（EP-036，批次十七 5/50）

**历史前线（2026-08-07，清册 EP-036 已完成，批次十七 5/50）。** `POST /api/v1/agents/{id}:invoke`
已按完整产品目的完成验收：用户从真实 Agent 详情进入 Invoke，立即看到取消/等待反馈，运行结束后
看到 mounted Function 的工具 trace 与最终 JSON；当另一入口在旧结果仍可见时落下一笔新执行，右岛
会切换到新的 observed run，Recent、trace、Result 不会把旧结果和新执行混在一起。

首轮真实 session 暴露了产品缺陷：外部调用的 trace 已进入右岛，但旧本地结果卡与 Recent 计数仍留在
面板中。stop-and-fix 在 `run_terminal_controller.dart` 增加 durable close 后的账本重取，并在 settled
面板观察到新的顶层 run 时重置旧树、从执行账本收口终态；同步补齐 controller 回归测试和实体面板
文档。最终 session `/private/tmp/anselm-rig-ep036-agent-invoke-20260807/sessions/20260807-131105`
用真实 Flutter App、Computer Use、窗口录像、backend、三路独立 SSE witness、frontend console 和
受管网关 LLM tap 重跑：UI 示例 `0+0` 先完成；随后 REST `400+60` 返回 `total=460`，右岛只呈现
新执行的 `total=460`，Recent 计数从 8 到 9。

五通道封口：录屏 `177.275000s / 2784x1808 / 60fps`，四个关键帧保存在 session evidence；backend
`240` 行无 panic/fatal/error/warn；frontend `17` 行无 Flutter/Dart/RenderFlex/Unhandled 红线；SSE
三流全连接，entities 最终观察运行 durable seq `11..20` 单调无 gap；LLM tap 的 `400/60` 请求和
`460` 流式响应均为 HTTP 200；SQLite 最新执行 `agx_faf49cf4a927835b` 为 `ok / 460 / 8432ms`。
UI、REST、SQLite、SSE、LLM wire 五处真值一致，录像经 `ffprobe` 可读，rig-down 后无残留进程。

正式证据 `/private/tmp/anselm-rig-ep036-agent-invoke-20260807/sessions/20260807-131105/evidence/EP-036-agent-invoke-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-036-agent-invoke-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入 `COVERAGE.md` 为 `✓✓✓✓✓`，正式账本 `845→850 judgments`。集中写账触发的 `gap-too-fast`/`discovery-collapse` 已复审并 ack，阈值未放宽，`alarms.py check` clean；`gen_coverage.py --check` 为 `848 rows / 169 carried judgments / 0 tombstones`。

批次十七当前 **5/50**；未到 50 格，不运行统一长门禁、不提交。下一原子前线为 `EP-037 POST /api/v1/agents/{id}:revert`；本格明确未覆盖“另一个本地运行仍在飞时并发外部调用”，该边界留给后续 edge 路径，不冒充本格已验证。

### 5.2 历史状态快照（EP-035，批次十六 50/50，统一门禁已通过）

**当前前线（2026-08-07，清册 EP-035 已完成，批次十六 50/50）。** `DELETE /api/v1/agents/{id}` 已按完整产品目的完成验收：真实用户从 Agent 详情的 More actions 进入删除，看到明确的不可逆确认，确认后 Agent 从 active catalog 消失，详情选区回到可用 Overview，关系清空，版本审计仍可读；重复删除不重复清边或发事件。上一格清册 EP-040 的临时错号已保留在历史记录，本段严格使用 `COVERAGE.md` 的机械编号。

真实 session `/private/tmp/anselm-rig-ep035-agent-delete-20260807/sessions/20260807-114742` 由同一 conductor 托管真实 Flutter App、Computer Use、窗口录屏、backend、三路独立 SSE witness、frontend console 与受管网关 LLM tap。删除前 `EP034 Meta Edited` 有一条真实 equip 关系，用户确认后 DELETE 返回 204；画面最终回到 Overview，Agent count=46，目标行消失，右侧没有旧详情或空白选中态，关系图为 `0 entities, 0 relations`。此前 Cancel-only preflight 与错误 llmtap 归属的失败尝试均保留在各自 session，不混入绿证据。

逐帧复核保留了一个真实中间状态：右岛首次挂载的标准 `AnCountUp` 在约 0.5 秒内从 0 揭示到 46，期间 rail 的权威徽标已是 46；这不是 DB 计数跳变，最终卡片、REST 和 SQLite 均为 46。该段按 CODEX B1/B3 作为新内容首次出现的有界动效审查，抽帧与判定写在 session evidence，没有只留终帧。

五通道封口：录屏 `325.161667s / 2784x1808 / 60fps`；backend `411` 行无 panic/FATAL/WARN/ERROR，含 relation purge 与 DELETE=204；SSE 三流全连接，notifications durable seq 1 为 `agent.deleted`，messages/entities 本确定性删除路径无 mutation frame，不虚构事件且无 gap/error；frontend `26` 行仅有两条已复核的标准数字节点 AXTree bridge 观测器噪声，未知 AXTree 形状和 Dart/Flutter/RenderFlex/overflow/Unhandled/失联仍硬失败；LLM tap 记录真实受管网关 ready，本格不需要 completion 不虚构模型证据。`rig-check.sh` 操作前通过，`rig-down.sh` 封口录屏且无残留。

正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-035-agent-delete-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-035-agent-delete-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入 `COVERAGE.md` 为 `✓✓✓✓✓`，正式账本 **840→845 judgments**。集中写账触发的 `gap-too-fast`/`discovery-collapse` 已由独立复审 ack，阈值与算法未放宽，`alarms.py check` clean；`gen_coverage.py --check` 为 `848 rows / 168 carried judgments / 0 tombstones`。

批次十六现已 **50/50**，统一收台已完成并通过：根目录 `make verify` 全绿（含 backend 完整 `go test ./...`、frontend、docs、demo），完整 testend `mise exec -- go test -count=1 -timeout 20m ./...` 全绿，`make -C backend testend` 全绿；Agent/实体后端专项与 Flutter 实体专项全绿，`gofmt`、`git diff --check`、`gen_coverage.py --check`、`alarms.py check` 全绿，验收台架进程组归零。工作树审计无未解释文件，已按 WRK-093/P15 将本批次代码、测试与工作记录一并固化；下一原子前线为 `EP-036`，不把门禁结果降级成“仅专项通过”。

### 5.2 历史状态快照（EP-032，批次十六 30/50）

**当前前线（2026-08-06，EP-032 已完成，批次十六 30/50）。** `GET /api/v1/agents` 已按完整产品目的完成验收：真实 App 首屏 Agent rail 与 Overview 都显示精确总数 45，真实逐字输入 `alpha` 显示 2，五次真实 Backspace 恢复 45，滚动加载 20/20/5 三页后计数仍为 45，45 个名称无重复。首轮真实 App session `/private/tmp/anselm-rig-ep032-agent-list-input-20260806/sessions/20260806-162636` 抓到真实产品缺陷：UI 把已加载行数 40 当成总数，翻页后跳成 45，冻结为红并保留；不是分页可接受副作用。

stop-and-fix 不改变 N4 JSON body，后端七类实体列表增加 `X-Anselm-Total-Count` 精确过滤总数响应头；前端 `Page.total`、EntityListState、rail badge 和 Overview cards 消费该元数据。代码级复审又补上 durable created/deleted/edited lifecycle 的总数刷新，避免实时增删改后徽标落后于 DB；fixture、ApiClient、实体列表、Overview、rail 和 signal 回归均已补齐。中间 session `/private/tmp/anselm-rig-ep032-agent-list-count-fixed-20260806/sessions/20260806-164204` 因复用数据里的受管 key 仍指向旧 `8805` 而新 tap 为 `8807`，被 D1/channel-5 门禁拒绝报绿，不混入最终证据；最终 session `/private/tmp/anselm-rig-ep032-agent-list-count-fixed-20260806/sessions/20260806-165306` 换用既有 key 端口并由最新 binary 重跑通过。

五通道封口：录屏 `72.431667s / 2784x1808 / 60fps`，终帧 `/private/tmp/anselm-rig-ep032-agent-list-count-fixed-20260806/sessions/20260806-165306/evidence/ep032-final-frame.png`；backend `162` 行、frontend `19` 行、SSE `8` 行、LLM witness `1` 行，应用级 panic/fatal/error/warn/Flutter/Dart/RenderFlex/Unhandled 红线均为零；三路 SSE 全连接并正常 EOF 收台，channel 5 经受管网关 tap，LLM completion 对只读列表不需要且未虚构。REST header 为 `45/2/1/0`，body 无 `total`；SQLite live Agent 为 `45`，REST/SQLite/UI/SSE/wire 与收台进程清零互证。正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-032-agent-list-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-032-agent-list-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入五级裁决，正式账本 **820→825 judgments**，COVERAGE `EP-032=✓✓✓✓✓`，两条统计警报按独立复审 ack，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 164 carried judgments / 0 tombstones`。批次十六当前 **25→30 / 50**；未满 50 格，不运行统一长门禁、不提交，下一原子前线为 `EP-033 GET /api/v1/agents/{id}`。

### 5.2 历史状态快照（EP-031，批次十六 25/50）

**当前前线（2026-08-06，EP-031 已完成，批次十六 25/50）。** `POST /api/v1/agents` 已按完整产品目的完成验收：用户从真实 Chat 创建 Agent 后，能得到一个 identity、完整 Config 快照和 v1，名称、描述、tags、prompt 在 UI、REST、SQLite、SSE 与 LLM wire 上一致。首轮真实 App session `/private/tmp/anselm-rig-ep031-agent-create-20260806/sessions/20260806-154305` 抓到真实产品缺陷：托管模型把 `tags` 发成精确 JSON 数组字符串，旧执行边界按 `[]string` 解码失败，App 显示 `Create agent failed` 与 `Draft unsaved · nothing was created`，冻结为红并保留；中间修复 session `/private/tmp/anselm-rig-ep031-agent-create-fixed-20260806/sessions/20260806-155712` 又抓到流式脱敏残留句尾 `)`，继续冻结，不计绿。

stop-and-fix 在 `create_agent` 执行边界加入窄兼容：接受原生 `[]string` 和精确 JSON 数组字符串，拒绝逗号 prose、非字符串数组和非数组值；同时让 `id`/`identifier` 括号的流式分片保持完整，最终整段移除。补 hosted-model shape、非法 tags、完整流式 chunk 边界回归测试与工具说明。最终真实 session `/private/tmp/anselm-rig-ep031-agent-create-final-20260806/sessions/20260806-160242` 由新 binary、真实 App、Computer Use、录屏、frontend console、backend journal、三路独立 SSE witness、LLM tap 和受管网关重跑：首次 create 成功，只产生 `ag_e093c9019b049a4e` 的 v1，最终文案为 `Agent created successfully: EP031 Planner with tags [acceptance, planner].`；模型追加的一次安全 `get_agent` 读取无副作用、无重复 create，明确保留在证据中。

五通道封口：录屏 `157.588333s / 2784x1808 / 60fps`，终帧为 `/private/tmp/anselm-rig-ep031-agent-create-final-20260806/sessions/20260806-160242/evidence/ep031-final-frame.png`；backend `255` 行无应用级 panic/fatal/error/warn；三路 SSE 均连接、无 error，messages durable `1..22`、notifications `1..5` 单调，entities 本切片无 mutation frame 不虚构事件；frontend 无 Flutter/Dart/RenderFlex/Unhandled 应用红线，仅 macOS foreground/IMK 宿主噪声；LLM challenge/install/models/chat completion 全 `200`。REST `201/200/400/401/401/204`、SQLite、UI、SSE 与 wire 互证，收台无残留。正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-031-agent-create-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-031-agent-create-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入五级裁决，正式账本 **815→820 judgments**，COVERAGE `EP-031=✓✓✓✓✓`，两条统计警报按独立复审 ack，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 163 carried judgments / 0 tombstones`。批次十六当前 **20→25 / 50**；未满 50 格，不运行统一长门禁、不提交，下一原子前线为 `EP-032 GET /api/v1/agents`。

### 5.2 历史状态快照（EP-030，批次十六 20/50）

EP-030 的完整红绿证据、五级裁决和批次状态保留如下：`GET /api/v1/handler-calls/{id}` 首轮真实 App 抓到前端未请求或呈现后端已有的 `logs`，stop-and-fix 增加详情懒加载与 UI 展示；最终失败行显示 logs/traceback、成功行显示 logs/output。正式证据、独立复审、五通道日志和 `810→815` 账本记录仍以 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-030-handler-call-final-green.md` 与 `EP-030-handler-call-ledger-reaudit.md` 为准；以上 EP-031 状态为当前恢复真相。

### 5.2 历史状态快照（EP-029，批次十六 15/50）

EP-029 的完整红绿证据、五级裁决和批次状态保留如下：`GET /api/v1/handlers/{id}/calls` 首轮固定版真实 session 抓到未知 Handler 的 `data.calls=null`，stop-and-fix 在共享 `response.Paged` 边界递归规范化嵌套 nil slice；修复后分页、筛选、aggregates、空列表和 Handler Logs 路径均通过。正式证据、独立复审、五通道日志和 `805→810` 账本记录仍以 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-029-handler-calls-final-green.md` 与 `EP-029-handler-calls-ledger-reaudit.md` 为准；以上 EP-030 状态为当前恢复真相。

### 5.2 历史状态快照（EP-028，批次十六 10/50）

EP-028 的完整红绿证据、五级裁决和批次状态保留如下：`DELETE /api/v1/handlers/{id}/config` 修复前真实 session `/private/tmp/anselm-rig-ep028-handler-config-20260806/sessions/20260806-143909` 抓到重复通知；修复 changed 保护后在 `/private/tmp/anselm-rig-ep028-handler-config-20260806/sessions/20260806-144550` 重跑，最终清 config、停 resident、清空后调用 422、未知 Handler 404、重复 DELETE 204/no-op。正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-028-handler-config-clear-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-028-handler-config-clear-ledger-reaudit.md`；账本 `800→805 judgments`，COVERAGE `EP-028=✓✓✓✓✓`，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 160 carried judgments / 0 tombstones`。批次十六由 `5→10/50`，下一原子当时为 EP-029。

### 5.2 历史状态快照（EP-027，批次十六 5/50）

**状态修订。** EP-027 `PUT /api/v1/handlers/{id}/config` 已完成 JSON Merge Patch、实例重启、敏感键保留、可选键删除/默认值回落和真实 Chat `update_handler_config` 产品路径。固定 session `/private/tmp/anselm-rig-ep027-handler-config-20260806/sessions/20260806-142114` 录屏 `583.983333s / 2784x1808`；backend `598` 行无应用红线，三流 durable `messages 1..66 / entities 7..8 / notifications 16..30` 单调，严格 Chat 只出现 update 工具；REST/SQLite/UI/secret scan 一致。正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-027-handler-config-update-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-027-handler-config-update-ledger-reaudit.md`；anchors `10/10` 后账本 **795→800 judgments**，COVERAGE `EP-027=✓✓✓✓✓`，alarms clean，gen coverage 为 `848 rows / 159 carried judgments / 0 tombstones`。早期 `...dball` 台架 URL 错误和探索性 Chat 越界调用均保留并排除，严格重跑通过；批次十六由 **0→5 / 50**，下一原子为 EP-028。

### 5.2 历史状态快照（EP-026，批次十五 50/50）

**当前前线（2026-08-06，EP-026 已完成，批次十五 50/50）。** `GET /api/v1/handlers/{id}/config` 已按真实配置、未配置、敏感值掩码和未知 Handler 四条边界完成验收。真实 session `/private/tmp/anselm-rig-ep026-handler-config-20260806/sessions/20260806-134441` 由 conductor 托管新 binary、真实 Flutter App、Computer Use、录屏、frontend console、backend journal、三路独立 SSE witness、LLM tap 与受管网关：已配置 Handler 返回 `200`、`configState=ready`、`api_key=********`、region/retries 原值；未配置 Handler 返回 `config=null`、`configState=unconfigured`、`missingConfig=[api_key]`；未知 ID 返回 `404 HANDLER_NOT_FOUND`。App 逐帧显示 configured 的 ready/masked schema 与 unconfigured 的 stopped/missing api_key 状态，无 secret 泄漏、裁切、重叠或视觉跳变。首个配置 PUT 探针因测试命令漏写显式 `-X PUT` 得到 `405`，确认是台架构造错误；补正后产品 PUT 为 `204`，不计产品红，也不降低门禁标准。

五通道封口：录屏 `245.513333s`、`2784x1808`；backend journal 356 行且无 panic/WARN/ERROR，messages/entities/notifications 三流均连接并分别记录预期 durable 帧，LLM challenge/install/models 全 `200`（该确定性 GET 路径没有 completion，不冒充模型证据），frontend journal 无 Flutter/Dart/RenderFlex/Unhandled 应用红线；REST、SQLite、UI、SSE 和敏感值扫描一致，收台无残留。正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-026-handler-config-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-026-handler-config-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入五级裁决，正式账本 **790→795 judgments**，COVERAGE `EP-026=✓✓✓✓✓`，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 158 carried judgments / 0 tombstones`。批次十五由 **45→50 / 50**；统一长门禁已通过：anchors/alarms clean、根目录 `make verify` 全绿、`make -C backend testend` `305.314s` 全绿、`testend` 全包 `359.770s` 全绿、Handler 后端专项与实体详情 Flutter `7/7` 通过、gofmt/diff clean，testend 进程组归零；批次已提交 `6ffc44bb`，下一原子前线为 `EP-027 PUT /api/v1/handlers/{id}/config`。

### 5.2 历史状态快照（EP-025，批次十五 45/50）

以下保留 EP-025 当时的完整状态重述；当前执行以前述 EP-026 状态、LOG 最新条目和 COVERAGE 当前行作为真相。

**当前前线（2026-08-06，EP-025 已完成，批次十五 45/50）。** `GET /api/v1/handlers/{id}/versions/{version}` 首轮真实 App 路径冻结为红：A Handler 接受了 B Handler 的 opaque `hdv_...` 版本 ID 并返回 B 的代码，跨父数据泄漏且用户会被错误版本误导。stop-and-fix 增加 parent-scoped repository lookup，数字版本与 opaque 版本详情继续保持同一父 Handler 边界，并补 store/app/transport/black-box 回归与 Handler domain 文档。固定 session `/private/tmp/anselm-rig-ep025-handler-version-get-fixed-20260806/sessions/20260806-133348` 使用新 binary、真实 App、Computer Use、受管网关和五通道台架重跑：A 数字 v1 与自有 opaque ID 均 200，A 读取 B opaque ID、未知数字和未知 opaque 均为 404 `HANDLER_VERSION_NOT_FOUND`，B 自有 opaque ID 仍 200；Versions 画面显示正确 owner 的 `v1 · stopped`、`ready`、active 标识、真实 source/change reason 和完整代码，无错归属、裁切或视觉跳变。首轮红 session `/private/tmp/anselm-rig-ep025-handler-version-get-20260806/sessions/20260806-132936` 永久保留，固定录屏 186.876667s/30MB；backend 无 WARN/ERROR/panic，三路 SSE durable seq 单调，frontend 无 Flutter/Dart/RenderFlex/Unhandled 应用红线，受管网关 bootstrap 全 200。正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-025-handler-version-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-025-handler-version-ledger-reaudit.md`；anchors 10/10 后按 G1/F2/A1/C4/G2 写入五级裁决，正式账本 785→790 judgments，COVERAGE EP-025=✓✓✓✓✓，alarms.py check clean，gen_coverage.py --check 为 848 rows / 157 carried judgments / 0 tombstones。批次十五由 40→45 / 50；未满 50 格不跑统一长门禁、不提交，下一原子前线为 EP-026 GET /api/v1/handlers/{id}/config。

### 5.2 历史状态快照（EP-024，批次十五 40/50）

以下段落仅保留 EP-024 的当时状态，当前恢复以前一段 EP-025 整体重述、LOG 最新条目和 COVERAGE 当前行作为真相。

**历史前线（2026-08-06，EP-024 已完成，批次十五 40/50）。** `GET /api/v1/handlers/{id}/versions` 已在真实 App、受管 Anselm 网关、Computer Use 和五通道台架下完成 22 个真实 Handler 版本的分页、续页、展开和滚动检查。首屏显示 v22→v3 共 20 条，`Load more` 只追加 v2、v1 一次并在终页消失；active v22、最新 diff 与 v1 `earliest version` 均正确，最早版本代码卡可完整滚入视口，无裁切、重叠或异常跳变。REST cursor 续页为 20+2 且无重叠，`limit=0/abc` 为 400 `INVALID_REQUEST`，坏 cursor 为 400 `MALFORMED_CURSOR`；未知父实体按现有集合读取语义返回空集合，单实体读取仍走 not-found。SQLite 证明唯一 fixture 有 22 个 distinct versions、1..22、active=v22、全部环境 ready。真实 session `/private/tmp/anselm-rig-ep024-handler-versions-20260806/sessions/20260806-131758` 录屏 398.341667s/90MB；三路 SSE 全连接且 durable seq 单调，backend 无 WARN/ERROR/panic，frontend 仅已知 macOS 调试宿主噪声、无 Flutter/Dart/RenderFlex/Unhandled 红线，受管网关 challenge/install/models 全 200。正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-024-handler-versions-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-024-handler-versions-ledger-reaudit.md`；anchors 10/10 后按 G1/F2/A1/C4/G2 写入五级裁决，正式账本 780→785 judgments，COVERAGE EP-024=✓✓✓✓✓，alarms.py check clean，gen_coverage.py --check 为 848 rows / 156 carried judgments / 0 tombstones。批次十五由 35→40 / 50；未满 50 格不跑统一长门禁、不提交，下一原子前线为 EP-025。

### 5.2 历史状态快照（EP-023，批次十五 35/50）

以下段落仅保留 EP-023 的当时状态，当前恢复以前一段 EP-024 整体重述、LOG 最新条目和 COVERAGE 当前行作为真相。

**当前前线（2026-08-06，EP-023 已完成，批次十五 35/50）。** POST /api/v1/handlers/{id}:iterate 已在真实 App、受管 Anselm 网关、Computer Use 和五通道台架下完成 Handler actions → Edit with AI → ask-user → AI edit → v2 完整产品旅程。首轮真实路径暴露 legacy set_methods 被归一为既有 status 的 add_method，后端真实拒绝 method "status" already exists；红 session /private/tmp/anselm-rig-ep023-handler-iterate-20260806/sessions/20260806-124805 与证据永久保留。stop-and-fix 让 edit normalization 读取 active method 名称：既有方法转 update_method，新方法才转 add_method，并强化 edit_handler 描述、补 TestNormalizeHandlerOpsForEdit_SplitsLegacyMethodListByActiveNames。固定 session /private/tmp/anselm-rig-ep023-handler-iterate-fixed-20260806/sessions/20260806-130116 重新由 conductor 托管真实 App、窗口录制、frontend console、backend journal、三路独立 SSE witness 和 LLM tap；最终模型仅发一个 canonical update_method，App 显示 Updated handler · v2、最终说明和 Activity 1 touched，SQLite/REST active 指针为 v2，消息块保留 inspection/ask-user/edit/result 全链。录屏 400.173333s，三路 durable frame 单调且 close 快照与数据库一致，受管网关 challenge/install/models 与 chat completions 全 200，固定路径没有应用级 WARN/ERROR/panic 或 Flutter/Dart/RenderFlex/Unhandled 红线；已知 macOS runner/IMK host 噪声按 fail-closed 规则单独隔离。正式证据 /private/tmp/anselm-rig-formal-20260801-3/evidence/EP-023-handler-iterate-final-green.md，session 细节与红证据分别在固定/首轮 session evidence，独立账本复审 /private/tmp/anselm-rig-formal-20260801-3/evidence/EP-023-handler-iterate-ledger-reaudit.md；五级裁决 G1/F2/A1/C4/G2 使正式账本 775→780 judgments，anchors 10/10，gap-too-fast/discovery-collapse 按原阈值独立复审并 ack，alarms.py check clean，gen_coverage.py --check 为 848 rows / 155 carried judgments / 0 tombstones。批次十五由 30→35 / 50；未满 50 格不跑统一长门禁、不提交，下一原子前线为 EP-024。

### 5.2 历史状态快照（EP-022，批次十五 30/50）

以下段落仅保留 EP-022 的当时状态，当前恢复以前一段 EP-023 整体重述、LOG 最新条目和 COVERAGE 当前行作为真相。

**当前前线（2026-08-06，EP-022 已完成，批次十五 30/50）。** `POST /api/v1/handlers/{id}:edit` 已在真实 App、受管 Anselm 网关、Computer Use 和五通道台架下完成成功与非法 method 编辑路径。真实 Handler `hd_f3d9a96f278672d0` 从 v1 `hdv_98ffb76322048024` 开始，首个真实 Call 让 App 从 `v1 · stopped` 正确刷新为 `v1 · running`；随后 HTTP `:edit` 用 canonical `update_method` 铸造 v2 `hdv_6ff081d3ae49ebf6`，环境 ready 并重启 resident。App 同步显示 `v2 · running`、`ready`、新代码，旧 v1 结果被清掉而 durable Recent 保留；随后真实 Call 返回 `{"edited":true,"revision":"v2"}`，Recent 增至 2。非法 `does_not_exist` 编辑返回 `422 HANDLER_OP_INVALID` 并给出具体 method 缺失原因，版本列表仍只有 v1/v2、active v2、无 v3/调用副作用。最终 session `/private/tmp/anselm-rig-ep022-handler-edit-20260806/sessions/20260806-123828` 录屏 `191.498333s / 2784x1808 / 60fps`；REST/SQLite 对证两次调用钉住不同 resident instance，SSE 三流全连接且 durable seq 无 gap，受管网关 challenge/install/models 全 200，backend/frontend 无未解释应用红线，收台无 conductor 残留。Flutter 启动器唯一 `Failed to foreground app; open returned 1` 已在证据中按“App 随后 resident 且 Computer Use 全部成功”的仪器噪声单独复核，未知错误仍按 fail-closed。正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-022-handler-edit-final-green.md`，session 细节证据 `.../evidence/EP-022-handler-edit-green.md`，账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-022-handler-edit-ledger-reaudit.md`；五级裁决 `G1/F2/A1/C4/G2` 使正式账本 **770→775 judgments**，anchors `10/10`，两条统计警报按原阈值独立复审并 ack，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 154 carried judgments / 0 tombstones`。批次十五由 **25→30 / 50**；未满 50 格不跑统一长门禁、不提交，下一原子前线为 `EP-023`。

**历史快照（EP-021，批次十五 25/50）。** `POST /api/v1/handlers/{id}:revert` 已完成版本回退成功与非法版本失败路径；首轮真实回退暴露 v1 标题下残留 v2 结果的产品真相红线，stop-and-fix 后 active version 变化会清掉瞬时结果并保留 durable Recent。最终 session `/private/tmp/anselm-rig-ep021-handler-revert-fixed-20260806/sessions/20260806-122413` 显示 v1 running/ready、旧结果消失，随后 v1 Call 成功；REST/SQLite、SSE、录屏、五通道和 10/10 controller tests 已在前一条状态日志中交叉证明，账本为 770，警报 clean。该段仅供追溯，当前恢复以前述 EP-022 状态为准。

**历史快照（EP-020，批次十五 20/50）。** `POST /api/v1/handlers/{id}:restart` 已在最终新构建的真实 App、受管 Anselm 网关、Computer Use 和五通道台架下完成成功与失败两条产品路径。首轮成功路径暴露真实产品缺陷：第一次 Handler `:call` 成功并已惰性拉起 resident instance，REST/SQLite 已是 `runtimeState=running`，但实体详情仍停在 `v1 · stopped`；stop-and-fix 在 Handler call 收尾后重新读取 server-owned detail，避免 UI 留在过期运行态。最终 session `/private/tmp/anselm-rig-ep020-handler-restart-fixed-20260806/sessions/20260806-120431` 真实显示首次 Call 后 `v1 · running`、`ready`、`Done`，Restart instance 原地完成且不铸新版本，第二次 Call 的 Recent 由 1 增至 2；REST/SQLite 证明两次调用均成功、同一 active version `hdv_b075d14eefb8e00f`、两次 resident instance ID 分别为 `hdi_51fd8207eeaa0161` 与 `hdi_da984cee7bc1fdf`。负路径用真实未配置必填 `token` 的 Handler 执行 Restart，UI 明确显示 `Handler “ep020_restart_blocked” restart failed · View`，后端返回 `422 HANDLER_CONFIG_INCOMPLETE`，没有伪造实例或调用审计。录屏 `200.308333s / 2784x1808 / 60fps`；SSE notifications durable `handler.restarted ok:true` 为 seq 16，失败为 seq 20..22，连接与收台无 gap；backend/frontend/LLM tap 五通道均归属于同一 manifest，受管网关 challenge/install/models 全 HTTP 200，frontend 的 AXTree bridge churn 已独立标注为 macOS Flutter 调试仪器噪声且未发现 Dart/Flutter/Unhandled/overflow 红线，收台无残留进程。正式证据为 `/private/tmp/anselm-rig-ep020-handler-restart-fixed-20260806/sessions/20260806-120431/evidence/EP-020-handler-restart-green.md`，账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-020-handler-restart-ledger-reaudit.md`；定向 controller 测试 `9/9`、目标 `flutter analyze` 通过，正式账本 **760→765 judgments**，两条统计警报按原阈值独立复审并 ack，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 152 carried judgments / 0 tombstones`。批次十五由 **15→20 / 50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-021`。

**当前前线（2026-08-06，EP-019 已完成，批次十五 15/50）。** `POST /api/v1/handlers/{id}:call` 已在新构建的真实 App、受管 Anselm 网关、Computer Use 和五通道台架上完成成功/失败两条真实路径：成功右岛显示 `Done`、handler stdout、结构化结果和最近调用；失败显示 `Failed`、`HANDLER_CLIENT_CALL_FAILED`、用户 stdout，并将后端 `details.error` 与 Python traceback 以真实换行展示。首轮失败路径发现右岛丢弃结构化 details，第二轮又发现 JSON 转义让 traceback 难读；两次均 stop-and-fix 后用最终 binary 重跑，最终录屏 `/private/tmp/anselm-rig-ep019-handler-call-final-20260806/sessions/20260806-114857/screen.mov` 为 `176.410000s / 2784x1808 / 60fps`。REST/SQLite 证明同一 resident instance、v1 不升版、`1 ok/1 failed` 调用审计、logs/error/traceback 全部落真；SSE entities `open/delta/close` 与 backend 200/502 对齐，LLM challenge/install/models 全 200，frontend/backend 无未解释应用红线，收台无残留进程。正式证据为 `EP-019-green.md`，账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-019-handler-call-ledger-reaudit.md`；正式账本 **760 judgments**，anchors `10/10`，两条警报按原阈值独立复审并 ack，`alarms.py check` clean。批次十五由 **10→15 / 50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-020 POST /api/v1/handlers/{id}:restart`。以下 EP-018 之前的状态段仅作历史快照，以上整体重述为准。

**当前前线（2026-08-06，批次十五进行中）。** 第九批 `TOOL-081..090`、第十批 `TOOL-091..100`、第十一批 `TOOL-101..110` 和第十二批 `TOOL-111..120` 均已完成 **50 / 50** 并提交；`TOOL-121 generate_video`、`TOOL-122 edit_image`、`TOOL-123 animate_image`、`TOOL-124 enroll_voice`、`EP-001 POST /api/v1/functions`、`EP-002 GET /api/v1/functions`、`EP-003 GET /api/v1/functions/{id}`、`EP-004 PATCH /api/v1/functions/{id}`、`EP-005 DELETE /api/v1/functions/{id}`、`EP-006 POST /api/v1/functions/{id}:run`、`EP-007 POST /api/v1/functions/{id}:revert`、`EP-008 POST /api/v1/functions/{id}:edit`、`EP-009 POST /api/v1/functions/{id}:iterate`、`EP-010 GET /api/v1/functions/{id}/versions`、`EP-011 GET /api/v1/functions/{id}/versions/{version}`、`EP-012 GET /api/v1/functions/{id}/executions`、`EP-013 GET /api/v1/function-executions/{id}`、`EP-014 POST /api/v1/handlers`、`EP-015 GET /api/v1/handlers`、`EP-016 GET /api/v1/handlers/{id}`、`EP-017 PATCH /api/v1/handlers/{id}` 与 `EP-018 DELETE /api/v1/handlers/{id}` 均已完成 `G1/F2/A5/C4/G2`，COVERAGE 当前这些 EP 行均为 `✓✓✓✓✓`。正式账本 `/private/tmp/anselm-rig-formal-20260801-3` 为 **755 judgments**，anchors `10/10`；EP-018 的真实删除 session 验证了取消不变、确认文案、详情回 Overview、204→404、版本历史保留、env 回收和 `sandbox.env_deleted`→`handler.deleted` 的五通道一致性；EP-018 写账触发的两条统计警报按原阈值以独立复审记录 ack，`alarms.py check` clean。批次十三和批次十四均已完成 **50 / 50** 并通过此前的统一长门禁、完整 testend、警报复核和工作树审计；批次十五当前 **10 / 50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-019 POST /api/v1/handlers/{id}:call`。默认 `~/.anselm-rig` 中历史错路由记录只作审计，不作为本战役水位。

`EP-016 GET /api/v1/handlers/{id}` 的真实 App session `/private/tmp/anselm-rig-ep016-handler-get-20260806/sessions/20260806-100548` 验证了 Handler 详情的完整用户目的：Computer Use 画面同时显示名称、v1、stopped、unconfigured、description、activeVersion、Python 3.12、必填 sensitive `api_key`、默认 `region`、`ping` 方法和 source；REST/SQLite 交叉证明 active version、configState、runtimeState、missingConfig、schema 和未知 ID 404 一致。封口录像 `292.240000s / 2784x1808 / 60fps`、稳定截图、messages/entities/notifications 三路 SSE（durable entities `7..8`、notifications `16..20`，无 gap）、backend journal、frontend console、LLM tap 均来自同一 manifest；清理 DELETE=204 后 GET=404，SQLite 仅保留软删 handler/version 审计且 env 已回收。正式证据为 `evidence/EP-016-green.md`，独立警报复审为 `evidence/EP-016-alarm-reaudit.md`；五级裁决已将账本 **735→740 judgments**，批次十四由 **45→50 / 50**。

`EP-017 PATCH /api/v1/handlers/{id}` 的首轮真实 App 画面冻结为红：Handler Overview 只有只读 description，完全没有 tags 入口，用户无法完成“维护 Handler 元数据”的目的。stop-and-fix 将 Handler 元数据接入与 Function/Workflow 一致的 `AnKv` 编辑面：description 支持空值起编辑，tags 支持 Add/remove；PATCH 成功或失败后都重读 canonical detail，`HANDLER_INVALID_NAME` 映射为具体本地化错误。首轮绿 session `/private/tmp/anselm-rig-ep017-handler-patch-20260806/sessions/20260806-105636` 证明了该 surface，但随后同类复查发现 description/tags 保存失败仍错误复用“名称保存失败”文案；stop-and-fix 已补齐 `metaSaveFailed` 双语文案，并同步 Function/Workflow 的同类 catch/invalidate 路径。新 binary 的最终真实 Computer Use session `/private/tmp/anselm-rig-ep017-handler-patch-20260806/sessions/20260806-111449` 从空 description/tags 开始真实键盘输入并 Enter 提交，Escape 收束 tag editor；最终画面显示 `rechecked metadata`、`recheck-tag`、`v1 · running`、`ready`，无跳变、错误卡或假重启。REST/SQLite 证明最终 meta、单一 `hdv_...` v1、resident `bump` 可继续执行；负路径保留非法名称 400 `HANDLER_INVALID_NAME` 与未知 ID 404。新录屏 `159.730000s / 2784x1808 / 60fps`；三路 SSE 已连接，notifications durable `1..3` 单调无 gap，frontend 无未解释 Flutter 红线，llmtap 通过受管网关线缆；最终证据为 `sessions/20260806-111449/evidence/EP-017-recheck-green.md`，独立警报复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-017-recheck-ledger-reaudit.md`。五级裁决已将账本 **745→750 judgments**，批次十五仍为 **5 / 50**；未满 50 格不跑统一长门禁、不提交，下一原子前线为 `EP-018 DELETE /api/v1/handlers/{id}`。

`EP-007 POST /api/v1/functions/{id}:revert` 的真实产品 session `/private/tmp/anselm-rig-ep007-functions-20260806/sessions/20260806-060152` 完成 v2→v1 回退：Computer Use 在 Versions 面板的 `Set active` 菜单执行真实回退，UI 保留 v1/v2 历史、顶部 active 状态和右侧运行结果均切到 v1；REST 带参数执行返回 `rest-v1`/`version=v1`，非法 v99 返回 `FUNCTION_VERSION_NOT_FOUND` 且 active pointer 不变。SQLite 的 active/version/execution/notification 真相与 notifications 的 `function.reverted` durable 帧一致；三路 SSE、backend、frontend console、LLM tap 和录屏均由同一 manifest 归属。清理 session 真实 DELETE=204、GET=404、live list 为空，SQLite soft-delete 与 `function.deleted` 也对齐。Computer Use `set_value` 绕过编辑器回调、坐标输入造成的中间非法 JSON 被明确排除在绿证据外并记入仪器限制；未发现产品代码红线。正式证据为 `evidence/EP-007-function-revert.md`，警报复审为 `evidence/EP-007-ledger-alarm-reaudit.md`。

`EP-008 POST /api/v1/functions/{id}:edit` 的真实 App session `/private/tmp/anselm-rig-ep008-functions-20260806-fixed3/sessions/20260806-064400` 完成按名称定位已有 Function、只改返回版本标记 v1→v2、保留 value、只调用一次 `edit_function` 的用户目的；最终 UI 只有一张 `Updated function · v2` 活动卡，环境为 ready，助手正文无 opaque Version ID 或 `the requested item`/`the referenced item` 占位，也没有错误卡。五通道证据齐全：录屏 `174.058333s / 2784x1808 / 60fps`；messages/entities/notifications durable seq 分别 `1..42`、`1..8`、`1..9` 单调；LLM tap 20 个响应全 HTTP 200；backend/frontend 无未解释应用红线；REST/SQLite 证明恰有 v1/v2 两个版本、active 为 v2、v1 未变、执行数为 0。空 ops 返回 200 且只重建 env、不铸 v3；畸形 `ops` 在修复后返回 422 `FUNCTION_OP_INVALID` 并在 mutation 前保持真相不变。首轮真实 App 的 Version ID 占位泄漏与 fixed2 的畸形 ops 500 红证据均保留，分别修复了跨 chunk 脱敏和 `ParseOps` 结构化错误映射，补测试与领域文档后以 fixed3 新 binary 重跑。正式证据为 `evidence/EP-008-green.md`，警报复审为 `evidence/EP-008-ledger-alarm-reaudit.md`；Function 与内置 conversation 已真实 DELETE=204 清理。该格已完成五级裁决，下一格为 `EP-009`。

`EP-009 POST /api/v1/functions/{id}:iterate` 的真实 App session `/private/tmp/anselm-rig-ep009-functions-20260806-fixed3/sessions/20260806-070454` 先保留了 generic opening/title 的红证据，再在 fixed3 新 binary 上完成 stop-and-fix 后重跑：Entities rail 选中真实 Function，`Edit with AI` 发出包含 Function 名称的非空请求，chat rail/header 均显示可识别标题，助手读取同一个 Function 并进入可继续编辑的 composer；没有 retry、第二个 conversation 或隐藏 mutation。修复将前端固定请求改为带实体名的本地化文案，后端同时拒绝空白请求并补 whitespace regression；REST/SQLite 证明 mention snapshot、touchpoint、tool call/result 和 conversation title 一致，未知 Function、空/空白请求和 malformed JSON 均在建会话前拒绝。
五通道证据齐全：录屏 `408.985000s / 2784x1808 / 60fps`；messages/entities/notifications durable seq 分别 `1..18`、`1..2`、`1..8` 单调，ephemeral delta 为 seq `0`；LLM tap 12 个响应全 HTTP 200；backend 无 panic/FATAL/WARN/ERROR，frontend 无 Dart/Flutter/runtime 红线。唯一重复的精确 `accessibility_bridge.cc` AXTree 旧节点提示由 session-scoped `evidence/frontend-ax-review.md` 明示为 Computer Use tooling noise，未知 AX 格式仍硬失败；清理已验证 Function 与 conversation DELETE=204、GET=404。正式证据为 `evidence/EP-009-green.md`，账本复审为 `evidence/EP-009-ledger-alarm-reaudit.md`；五级裁决已将正式账本由 **700→705 judgments**，COVERAGE `EP-009=✓✓✓✓✓`，批次十四由 **10→15 / 50**，下一原子前线为 `EP-010 GET /api/v1/functions/{id}/versions`。

`EP-010 GET /api/v1/functions/{id}/versions` 的真实 App session `/private/tmp/anselm-rig-ep010-functions-20260806/sessions/20260806-072203` 构造 21 个真实版本，验证 Versions 页面首屏 20 条 `v21→v2`、cursor 续页唯一返回 v1、active 标识、真实 change reason、代码 diff 和最早版本展开。Computer Use 逐帧确认 v21 默认展开显示 `v20 → v21`、`+1 −1`，加载更多后 v1 显示 `v1 · earliest version` 与完整代码；没有裁切、错位或不可解释状态跳变。REST 首页/续页与 UI 完全一致，`limit=0/abc` 返回 `INVALID_REQUEST`，坏 cursor 返回 `MALFORMED_CURSOR`；删除后主实体 404、列表移除，版本历史按 API 审计约定保留。
五通道证据为 `evidence/EP-010-green.md`、三张稳定截图和封口 `screen.mov`：录像 `456.258333s / 2784x1808 / 60fps`；messages/entities/notifications 三流各连接，entities durable `1..42`、notifications durable `1..85` 单调，entities delta 保持 seq `0`；backend 无 panic/FATAL/WARN/ERROR，frontend 无 Flutter/Dart/Unhandled/连接错误；llmtap 真实记录 proof challenge、install、models 全 HTTP 200，本旅程没有模型调用，未将 recorder ready 冒充 completion。正式账本由 **705→710 judgments**，`EP-010=✓✓✓✓✓`；独立警报复审为 `evidence/EP-010-ledger-alarm-reaudit.md`，anchors `10/10`，`alarms.py check` clean。批次十四由 **15→20 / 50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-011 GET /api/v1/functions/{id}/versions/{version}`。

`EP-011 GET /api/v1/functions/{id}/versions/{version}` 首轮真实 App session `/private/tmp/anselm-rig-ep011-functions-20260806/sessions/20260806-073520` 发现并冻结跨父 opaque version ID 泄漏：A 读取 B 的版本 ID 错误返回 B；代码审查同时发现显式版本执行也缺少 function parent 约束。stop-and-fix 增加 parent-scoped repository lookup，并让 opaque 版本详情和 `:run` 共用该边界；补 store/app/transport/black-box 回归与 API/domain 文档。fixed session `/private/tmp/anselm-rig-ep011-functions-20260806-fixed/sessions/20260806-074225` 用新 workspace 和 A/B fixture 重跑：真实 Flutter Versions 页面显示 v2 active、真实 change reason、`+1 −1` diff，v1 可展开并显示 `earliest version` 与完整旧代码；无错归属、截断或视觉跳变。
五通道交叉核验：A 的 v1/v2 数字版本、自有 v2 opaque ID、B 自有 opaque ID 均 200；A 读取 B opaque ID 与未知 ID 均为 404 `FUNCTION_VERSION_NOT_FOUND`；A 显式 v1 run 返回 owner A。清理 DELETE A/B=204，随后 GET=404；SQLite 保留 2 条 soft-deleted function、3 条版本和 1 条执行审计。录屏 `284.375s / 2784x1808 / 60fps`，messages/entities/notifications 各连接一次，entities durable `1..6`、notifications `1..14` 单调且 delta=0；backend/frontend 无未解释应用红线；llmtap proof/install/models 全 HTTP 200，本 deterministic 路径没有 completion，未把 ready 冒充模型调用。正式证据为 `evidence/EP-011-green.md`，账本复审为 `evidence/EP-011-ledger-alarm-reaudit.md`；正式账本 **710→715 judgments**，批次十四由 **20→25 / 50**，下一原子前线为 `EP-012 GET /api/v1/functions/{id}/executions`。

`EP-012 GET /api/v1/functions/{id}/executions` 的首轮真实 App session `/private/tmp/anselm-rig-ep012-functions-20260806/sessions/20260806-075245` 冻结为红：真实 Function 产生 22 条执行（18 success、4 failed），REST aggregates 已是 `18/4`，但 Overview 只显示最近 5 条推导出的 `5 today`，而 Logs 行把 UTC 时间直接显示给本地用户，分别造成总量错误和时间跳变。stop-and-fix 将执行聚合补成 `totalCount` 并贯通 function/handler/agent/mcp store、domain、API contract 和前端 snapshot；时间格式统一转本地时区；同步双语文案、生成物、回归测试与 API/domain 文档。
修复后的真实 App session `/private/tmp/anselm-rig-ep012-functions-20260806-fixed/sessions/20260806-080821` 重跑同一产品目的：Overview 显示 `22 total runs`，Logs 显示 `18 Done`/`4 Failed` 与本地 `2026-08-06 08:10`，失败行展开后可见 execution ID、触发方式、版本、输入、错误、耗时和本地时间，Load more 后 22 行全部可达，无错误卡、重复活动或视觉跳变。五通道封口为 `screen.mov` `258.726667s / 2784x1808 / 60fps`、SSE 三流已连接且 durable seq 单调（entities `1..46`，notifications `1..5`，messages 本路径无 durable 消息）、llmtap 10 条 bootstrap/proof/install/models 记录、backend/frontend 无 panic/FATAL/WARN/ERROR/Flutter/Dart/Unhandled 红线；SQLite 保留 22 条执行审计，Function DELETE=204 后 GET=404，live function 为零。正式证据为 `evidence/EP-012-green.md`，警报复审为 `evidence/EP-012-ledger-alarm-reaudit.md`；正式账本 **715→720 judgments**，批次十四由 **25→30 / 50**。列表接口按契约不带每条 execution 的 `logs`，当前 UI 尚未调用单次详情接口补取该字段；这是 EP-013 的明确前线，不把“聚合与分页已正确”冒充为“单次详情已完成”。下一原子前线为 `EP-013 GET /api/v1/function-executions/{id}`。
修复后的真实 App session `/private/tmp/anselm-rig-ep012-functions-20260806-fixed/sessions/20260806-080821` 重跑同一产品目的：Overview 显示 `22 total runs`，Logs 显示 `18 Done`/`4 Failed` 与本地 `2026-08-06 08:10`，失败行展开后可见 execution ID、触发方式、版本、输入、错误、耗时和本地时间，Load more 后 22 行全部可达，无错误卡、重复活动或视觉跳变。五通道封口为 `screen.mov` `258.726667s / 2784x1808 / 60fps`、SSE 三流已连接且 durable seq 单调（entities `1..46`，notifications `1..5`，messages 本路径无 durable 消息）、llmtap 10 条 bootstrap/proof/install/models 记录、backend/frontend 无 panic/FATAL/WARN/ERROR/Flutter/Dart/Unhandled 红线；SQLite 保留 22 条执行审计，Function DELETE=204 后 GET=404，live function 为零。正式证据为 `evidence/EP-012-green.md`，警报复审为 `evidence/EP-012-ledger-alarm-reaudit.md`；正式账本 **715→720 judgments**，批次十四由 **25→30 / 50**。列表接口按契约不带每条 execution 的 `logs`，前端详情懒加载路径留给下一格。

`EP-013 GET /api/v1/function-executions/{id}` 的真实 App session `/private/tmp/anselm-rig-ep013-functions-20260806/sessions/20260806-082436` 完成单执行详情闭环：列表真实返回 2 条与 `1 ok/1 failed` aggregates 且不带 logs；展开 Function 的 Logs 行后，前端调用单详情 GET，成功执行显示 input/output/logs/elapsed/time，失败执行显示 traceback 与 logs；未知 execution ID 返回 404 `FUNCTION_EXECUTION_NOT_FOUND`。这是对 EP-012 明确边界的 stop-and-fix：轻列表不膨胀，详情不再空白或假成功。五通道封口为 `screen.mov` `346.728333s / 2784x1808`，SSE 三流连接并记录 run/error/delete 帧，llmtap proof/install/models 全 200，frontend 无 Flutter/Dart/Unhandled/AXTree 红线，backend 无 panic/FATAL；两个临时 Function DELETE=204 后 live list 为空，SQLite `live_functions=0/deleted_functions=2/execution_rows=2`。正式证据为 `evidence/EP-013-green.md`，账本复审为 `evidence/EP-013-ledger-alarm-reaudit.md`；正式账本 **720→725 judgments**，批次十四由 **30→35 / 50**。下一原子前线为 `EP-014 POST /api/v1/handlers`。

`EP-014 POST /api/v1/handlers` 的真实 App session `/private/tmp/anselm-rig-ep014-handlers-20260806-compat9/sessions/20260806-093450` 先经历多轮红证据：托管模型返回的 legacy Handler op 形状并非单一 canonical 协议，必须在后端做有限、可审计的兼容翻译，不能把 Function 的 `set_code` 语义误当 Handler 成功。compat8 绿路径又暴露一个产品视觉红线：助手正文脱敏后把不可用的 ID 表格行替换为空行，Flutter 表格因此隐藏了真正的 `ping` 方法；stop-and-fix 改为物理移除该行，并补 durable close 与流式路径回归，compat9 新 binary 才重新判绿。
最终 Computer Use 画面明确显示 `Handler ep014compat 已创建完成`、名称、Python 3.12、`ping` 无输入且返回 `{pong: true}`、Init 参数无、版本 v1；没有 opaque ID、空表格断行、retry 或错误卡。真实 REST/SQLite 交叉核验为 create `201`、GET 的 env/config ready 且 runtime stopped、未知字段 `400 INVALID_REQUEST`、真实 `:call` 返回 `pong=true`、calls 聚合 `1 ok/0 failed`，清理 DELETE `204` 后 live GET `404`；版本、env 和调用审计按约保留。五通道封口录屏 `189.793333s` 可读，SSE 三流 durable seq 单调且无 gap，llmtap 全 HTTP 200，backend/frontend 无未解释应用红线。正式证据为 `evidence/EP-014-green.md`，警报复审为 `evidence/EP-014-alarm-reaudit.md`；正式账本 **725→730 judgments**，批次十四由 **35→40 / 50**，`anchors 10/10` 与 `alarms.py check clean` 均已复核。未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-015 GET /api/v1/handlers`。

`EP-015 GET /api/v1/handlers` 的主真实 App session `/private/tmp/anselm-rig-ep015-handlers-20260806/sessions/20260806-094604` 构造 44 个真实 Handler 加 seed 行，验证 Entities rail 的 `20+20+5` cursor 续页、最终 45 行、顺序无重漏和 `order_desk` 边界；Computer Use 真实输入 `ep015-handler-3` 得到 10 条 `39→30`，独立空输入 session `/private/tmp/anselm-rig-ep015-handlers-20260806/sessions/20260806-095453` 真实输入 `ep015-no-such-handler` 显示明确的 `No entities match your search.`，没有把空态伪装成加载失败。REST 同时验证 `20+20+5`、search、empty、`limit=0` 的 `400 INVALID_REQUEST`；清理 DELETE 44 个临时行均为 204、搜索为空、已删 GET=404。SQLite 最终 `handlers_total=45/live=1/ep015_deleted=44`，44 个版本保留，临时 env 已回收。五通道证据包括三流独立连接、主 session entities `7..94` / notifications `16..147` 无 gap、LLM bootstrap 全 200、backend/frontend 无未解释应用红线和三份 ffprobe 可读录屏；`set_value` 造成的隐藏输入串接被单独归类为 Computer Use 仪器限制，不进入绿判。正式证据为 `evidence/EP-015-green.md`，空态补证为 `evidence/EP-015-empty-search.md`，警报复审为 `evidence/EP-015-alarm-reaudit.md`；正式账本 **730→735 judgments**，批次十四由 **40→45 / 50**。未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-016 GET /api/v1/handlers/{id}`。

邻仓 `/Users/sunweilin/Developer/Anselm-API-Serve` 的 I2V 修复提交 `0d06f6e58615fec2fd04e3c15d16aea2edaf4aef` 已经生产 CI/CD 成功部署：CI `31029509745`、deploy `31029785594` 均全绿，公网 `healthz` 返回 `200 {"status":"ok"}`，未带设备证明的 `/v1/models` 返回预期 `401 DEVICE_PROOF_REQUIRED`。部署只证明服务可用，不替代产品验收；真实受管网关随后明示 I2V 能力，才启动本次 App 轮次。

`EP-004 PATCH /api/v1/functions/{id}` 在真实 App 中完成无效名称拒绝、有效名称保存、刷新后 canonical truth 与 fixture 恢复。旧实现把后端 `400 FUNCTION_INVALID_NAME` 静默当成成功并退出编辑态；stop-and-fix 让 inline editor 只在异步 PATCH 成功后退出，失败保留 draft、保持编辑态，并用完整可读的本地化规则提示 `Lowercase; a-z 0-9 - _; 1–64.`。真实 session `/private/tmp/anselm-rig-ep004-functions-20260806/sessions/20260806-044310` 记录了 UI 红/绿/恢复路径：无效 PATCH `400`、有效 PATCH `200`、恢复 PATCH `200`；notifications durable seq `1..2` 与侧栏/详情最终名称一致。独立台架校准 session `/private/tmp/anselm-rig-ep004-functions-20260806/sessions/20260806-044956` 由同一 conductor 启动真实 backend、三路 SSE witness、Flutter runner 与 LLM tap，`llm.jsonl` 的 `event=ready` 真实证明 recorder 已在线并绑定 `https://api.anselm.website`；该 deterministic journey 没有模型调用，因此不伪造 request/response。五级正式证据为 `sessions/20260806-044956/evidence/ep-004-functions-patch-formal.md`，账本警报复审为 `ep-004-ledger-reaudit.md`。
`EP-005 DELETE /api/v1/functions/{id}` 在真实 App 中先发现并修复确认文案红线：旧文案只说实体会被移除，没有说明不可撤销；修复为双语 active-catalog removal + irreversible consequence，并由真实绿 session `/private/tmp/anselm-rig-ep005-functions-20260806/sessions/20260806-050031` 重跑。Computer Use 通过实体 rail 的 More actions 打开确认框并只确认一次；录屏 `209.958333s / 2784x1808 / 60fps`，固定确认帧与删除后 Overview 帧已封存。后端 DELETE `204`，REST 回读 `404 FUNCTION_NOT_FOUND`、搜索为空、live list 44 条不含目标；SQLite 保留 `deleted_at` 与 v1 审计，环境、执行记录和关系边清除。notifications durable seq `1..2` 严格为 `sandbox.env_deleted` → `function.deleted`，三路 SSE 已连接，backend 无应用 WARN/ERROR/panic/FATAL；frontend 仅两条静态、5 秒不增长的已知 macOS AXTree 观察器噪声，无 Flutter/Dart/RenderFlex/Unhandled 红线；deterministic 删除路径的 LLM tap 只记录真实 upstream recorder `ready`，不冒充模型调用。正式证据为 `evidence/EP-005-formal-acceptance.md`，警报复审为 `evidence/ep-005-ledger-alarm-reaudit.md`。第一次未 export `RIG_HOME` 的五格误写默认账本已保留审计并清警，正式账本只用显式根重放；下一原子前线为 `EP-006`。
`EP-005 DELETE /api/v1/functions/{id}` 在真实 App 中先发现并修复确认文案红线：旧文案只说实体会被移除，没有说明不可撤销；修复为双语 active-catalog removal + irreversible consequence，并由真实绿 session `/private/tmp/anselm-rig-ep005-functions-20260806/sessions/20260806-050031` 重跑。Computer Use 通过实体 rail 的 More actions 打开确认框并只确认一次；录屏 `209.958333s / 2784x1808 / 60fps`，固定确认帧与删除后 Overview 帧已封存。后端 DELETE `204`，REST 回读 `404 FUNCTION_NOT_FOUND`、搜索为空、live list 44 条不含目标；SQLite 保留 `deleted_at` 与 v1 审计，环境、执行记录和关系边清除。notifications durable seq `1..2` 严格为 `sandbox.env_deleted` → `function.deleted`，三路 SSE 已连接，backend 无应用 WARN/ERROR/panic/FATAL；frontend 仅两条静态、5 秒不增长的已知 macOS AXTree 观察器噪声，无 Flutter/Dart/RenderFlex/Unhandled 红线；deterministic 删除路径的 LLM tap 只记录真实 upstream recorder `ready`，不冒充模型调用。正式证据为 `evidence/EP-005-formal-acceptance.md`，警报复审为 `evidence/ep-005-ledger-alarm-reaudit.md`。第一次未 export `RIG_HOME` 的五格误写默认账本已保留审计并清警，正式账本只用显式根重放。

`EP-006 POST /api/v1/functions/{id}:run` 的真实 App session `/private/tmp/anselm-rig-ep006-functions-20260806/sessions/20260806-053154` 完成合法 JSON 正向执行和非法 JSON 负向路径。正向通过 Example → Run 两次真实执行，UI 显示 `Done`、`73ms` 和 `{count:0, kind:"args", value:""}`；REST、SQLite 与后端日志均为同一 active version 的两条 `ok/manual` 执行。负向由可见编辑器输入 `A` 触发，画面显示 `Payload must be valid JSON.`、Run 置灰，点击不增加 Recent 执行数。528.990000s 录屏、三路 SSE 连接、frontend console、LLM tap、REST/SQLite 和 backend journal 均已封存；ready env 的同步 Function run 不发布实体/消息帧，SSE journal 的零帧是预期且无断连。临时 Function 随后由真实 API `DELETE=204` 清理，GET `404`、搜索为空。正式证据为 `evidence/EP-006-real-app.md`，警报复审为 `evidence/EP-006-ledger-alarm-reaudit.md`；五级裁决已写入 COVERAGE，中央账本 `685→690`，正式警报最终 clean；该格已在批次十三收口。

`EP-002 GET /api/v1/functions` 的最终五通道 session 为 `/private/tmp/anselm-rig-ep002-functions-20260806/sessions/20260806-034541`。在真实 App 和真实受管网关上构造 45 个真实 Function fixture，逐页验证 `20+20+5`、cursor continuation、filtered search、非法 limit 和上限 limit；Entities rail 真实加载 20→40→45 条，匹配查询显示结果。前置观察发现 no-match 搜索会变成没有解释的空白 rail，stop-and-fix 增加本地化 `No entities match your search.`，保留普通空 workspace 的完整结构；定向 frontend tests `41/41`、`make -C frontend gen`、Dart format 与 diff check 通过。最终会话还完成一次真实网关 chat，回复 `pagination witness ready.`；录屏 `151.576667s`，backend 无未解释应用错误，三路 SSE durable seq 单调，frontend console 无 Flutter/Dart/RenderFlex/Unhandled 红线，LLM tap 完成响应全为 HTTP 200。完整证据为 `sessions/20260806-034541/evidence/ep-002-functions-green.md`，账本复审为 `sessions/20260806-034541/evidence/ep-002-ledger-reaudit.md`。

EP-002 的产品修复落在 `frontend/lib/core/ui/an_sidebar_list.dart`、`frontend/lib/features/entities/ui/entity_rail.dart`、双语 i18n、定向测试和 `docs/references/frontend/features/entities.md`；这是同一覆盖格内的 stop-and-fix，不额外虚增 COVERAGE 数量。EP-003 没有发现需要施工的产品或代码红线；其成功/404 raw response、详情终帧和五通道 journal 已封存于 `/private/tmp/anselm-rig-ep003-functions-20260806/sessions/20260806-035647/evidence/`，复审证据为 `ep-003-ledger-reaudit.md`。以下 `TOOL-123` 及其后的旧段落均为历史过程快照；恢复执行只以上述整体重述、`LOOP.md`、`LOG.md` 最新条目和 COVERAGE 当前行作为真相。

`TOOL-123` 的真实 App 用户路径在 session `/private/tmp/anselm-rig-tool123-live-20260806/sessions/20260806-020305` 完整通过：生成蓝色帆船静态图 → 用户批准危险 `animate_image` → 网关提交/轮询/媒体上传 → 保存 5 秒 MP4 → 展开、播放到 `0:05 / 0:05`、重播、全屏、退出全屏。源附件 `att_88a52e72d00ccc1f` 与视频附件 `att_5863a6340ae60b18` 的 receipt、SQLite、UI 和 LLM 线缆一致；首帧独立测量 `changedFrac=0.1009`，`measure compare` 通过，构图保持帆船左侧与右侧开阔水面。

本次五通道证据为 `sessions/20260806-020305/evidence/tool-123-animate-image-formal-20260806.md`：647.886667 秒可读窗口录屏；backend 无未解释 WARN/ERROR；三路 SSE 均连接，messages durable `1..38`、notifications `1..2` 分流单调，ephemeral delta 保持 seq `0`；LLM tap 记录 I2V `202`、轮询 `200`、媒体上传 `201`、最终对话 `200`；frontend 无 Flutter/Dart/AXTree/RenderFlex/Unhandled/Exception 红线。上一 session `/private/tmp/anselm-rig-tool123-live-20260806/sessions/20260806-015946` 的 AXTree 红证据保留，不被改判绿；修复后的 loading/error/retry 状态由 34 项媒体定向测试和 `flutter analyze` 锁定。

五级写账触发的 `gap-too-fast` 与 `discovery-collapse` 已以独立复审文件 `sessions/20260806-020305/evidence/tool-123-ledger-alarm-reaudit.md` 逐项复核并 ack；警报阈值未放宽，其含义是账本批写和“单格全绿不代表全产品全绿”。此前一次未 export `RIG_HOME` 的 L1 误写到默认旧账本，已保留原始审计、销账并切回正式账本重放；默认旧账本不作为本战役水位。该段为上一格收口，下一轮从 `EP-001 POST /api/v1/functions` 继续，50 格统一长门禁仍后置。

`TOOL-124 enroll_voice` 的真实 App 用户路径在 session `/private/tmp/anselm-rig-tool124-live-20260806/sessions/20260806-022721` 完整通过：生成短参考音频 → 解释持久音色身份与有限库存 → 危险 `enroll_voice` 人闸批准 → 真实网关登记 → 使用登记音色再次生成语音 → Settings 读取音色库存并确认 1/2 槽位 → 用本地音色行 ID 删除 → GET 库存回到空集/2 个可用槽。参考音频 `att_353b3737368b9dbf` 的 WAV 为 157484 bytes、3.280000s，复用音频 `att_e06c667a3db58ac3` 为 169004 bytes、3.520000s；网关音色句柄 `vce_23b241a4e1789dd687ab954eef2dc39d` 与本地行 `vce_b905053ec7c7c2eb` 的创建、使用和删除边界均有证据。五通道正式证据为 `sessions/20260806-022721/evidence/tool-124-enroll-voice-formal-20260806.md`：587.738333 秒可读窗口录屏，messages durable `1..52`、notifications `1..2` 单调，entities 流已连接，ephemeral delta 保持 seq `0`；LLM tap 记录两次 speech `200`、voice create `200`、媒体上传 `200/201`、删除 `204`，backend/frontend 无未解释 runtime 红线。Computer Use 输入层对中文字符的丢失被保留为仪器限制而非产品红线；英文主路径正常完成。

TOOL-124 首轮还暴露了 Settings 将音色 GET 失败伪装成“没有音色”的真相问题；stop-and-fix 改为明确错误状态与 `Retry`，补 `voices_card_test.dart` 6/6、fixture failure hook、双语文案与 settings 文档规则，`flutter analyze` 与定向媒体/设置回归通过。五级写账触发的 `gap-too-fast` 与 `discovery-collapse` 已以独立复审文件 `sessions/20260806-022721/evidence/tool-124-ledger-alarm-reaudit.md` 串行 ack，阈值未放宽，最终 `alarms.py check` 为 clean(655)。

`EP-001 POST /api/v1/functions` 的前置真实 App 会话连续发现三条产品/契约红线并逐条停修：托管模型把外层 `ops` 发成 JSON 字符串、把 `set_inputs/set_outputs` 发成不兼容的嵌套字段形状，以及成功正文把 ID 行渲染成 `the requested item` 占位符。三份红证据分别保留在 `/private/tmp/anselm-rig-ep001-live-20260806/sessions/20260806-024539/evidence/ep-001-formal-red-stringified-ops-retry.md`、`/private/tmp/anselm-rig-ep001-green-20260806/sessions/20260806-025504/evidence/ep-001-formal-red-placeholder-id-table.md` 和 `/private/tmp/anselm-rig-ep001-green2-20260806/sessions/20260806-030108/evidence/ep-001-formal-red-nested-schema-retry.md`；均未计绿。

stop-and-fix 在 `create_function/edit_function` 执行边界增加窄兼容：只还原合法 JSON 数组字符串、无歧义字段 map 和完整覆盖 properties 的 JSON-Schema；公开 schema 仍保持 canonical flat array，CSV/prose/歧义/不完整 required 继续拒绝。同步工具描述、function domain/API 文档和 Go 回归。另修复 opaque ID 在 `Field | Value` 表格中变成坏占位的问题：精确 ID 只在相邻可展开、可复制的 `Created function · v1` 工具卡出现，用户正文不再留下假值。

正式绿 session `/private/tmp/anselm-rig-ep001-green3-20260806/sessions/20260806-030648` 由同一 manifest 托管真实 App、Flutter console、录屏、backend、三路 SSE witness 和 LLM tap：只调用一次 `create_function`，SQLite 只有一个函数/v1，环境 `ready`，持久化 tool call 已规范化，SSE 三流 durable seq 单调，LLM/HTTP 全 200，录屏 `337.441667s`，收台无残留进程。前端除已知 macOS 输入法 mach-port 系统噪声外无 Flutter/Dart/RenderFlex/Unhandled 红线；正式证据为 `sessions/20260806-030648/evidence/ep-001-formal-green-provider-shapes.md`，警报复审为 `sessions/20260806-030648/evidence/ep-001-ledger-alarm-reaudit.md`。五级裁决已写入 COVERAGE，批次十三由 **20 / 50** 推进至 **25 / 50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-002 GET /api/v1/functions`。

随后代码审查发现一个必须在进入下一格前清除的审计问题：通用 provider 参数归一化被错误记成 `get_flowrun` 专属原因，且 `edit_function` 对畸形 `ops` 的校验拖到了执行阶段。stop-and-fix 已补上通用审计原因、edit 写前校验与回归测试；最终代码 session `/private/tmp/anselm-rig-ep001-auditfix-20260806/sessions/20260806-032244` 重新走真实 App、真实受管网关和五通道，provider wire 的外层 `ops` 为字符串，SQLite/SSE 已规范化为四项 native ops，`argumentRepair` 为 `provider arguments normalized by tool boundary`，函数 `ready`，真实执行 `100 °C → 212 °F`，录屏 `200.358333s` 可读，三流 durable seq 单调，LLM 全 200，backend/frontend 无未解释应用红线。最终证据为 `evidence/ep-001-audit-fix-green.md`，账本复审为 `evidence/ep-001-auditfix-ledger-reaudit.md`；五级重验证使正式账本 **660→665 judgments**，不增加覆盖格，警报最终 clean。

`TOOL-122` 的五格均使用正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-050103` 及证据 `evidence/TOOL-122.md`：真实 App 完成一次生图→改图，来源与改后附件分离，改图结果保留原构图并将红色圆形精确改为蓝色；用户目的达成，五通道数据一致，交互过程无几何跳变，图像卡的比例、来源关系和事实展示达到可发布标准，新用户能发现并完成路径，无第二次生成、无 retry。两条统计警报已用独立复审证据 `evidence/tool-122-ledger-alarm-reaudit.md` 串行 ack，最终 `alarms.py check` 为 clean。

`TOOL-119 generate_image` 首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-024832` 暴露助手正文把媒体回执行脱敏成 `**Attachment ID:** the requested item`；随后 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-025906` 与 `20260805-030147` 又捕获流式 SSE 中间帧泄露 `Attachment ID` 标签和反引号半截。stop-and-fix 将媒体语义标签行从通用脱敏中窄化处理，并让流式 redactor 跨 provider chunk 暂存整行；Go 回归覆盖实际 `att_…` 值边界，真实正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-031323` 已证明 user-facing SSE delta/close 无 `Attachment ID`、`attachmentId`、`att_` 或坏占位。

同一前线的产品复核又发现 `generate_image` 工具卡丢弃 receipt 的 `width/height`，导致 landscape/portrait 在附件行返回前先占方形版面。stop-and-fix 将 filename、mime、sizeBytes、width/height、source 全量作为 `AnMediaRef` 提示传入统一媒体卡，新增 delayed-meta widget guard；真实 landscape 路径最终显示真实 `1344×768` 图像、文件名和大小，composer 正常收口。正式证据为 `sessions/20260805-031323/evidence/TOOL-119.md`，警报复审为 `tool-119-ledger-alarm-reaudit.md`；anchors `10/10`，五级 `G1/F2/A5/C4/G2` 已落账，最终 `alarms.py check` 为 `clean (630 judgments)`。本格使批次十二推进到 **45 / 50**；未到 50 格前不跑统一长门禁、不提交。

`TOOL-120 generate_speech` 首次真实复验前冻结两条产品红线：生成语音收据的 filename/sizeBytes/durationMs 被前端丢弃，附件行在途时没有保留已知事实；元数据失败直接显示裸 `att_`，在途通用文件骨架落地后还会跳成音频卡。stop-and-fix 补齐收据解析和音频卡状态：收据先供稳定文件名、大小、精确时长，附件行到达后覆盖；在途保持音频几何与 loading 文案；失败显示可重试人话，播放失败/离线/缺失分别走统一状态。正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-032851` 真实完成 onboarding、一次受管 `/audio/speech`、展开音频卡、播放 lease、Range 播放与自然收尾；画面显示 `generated-20260804-193020.wav · WAV · 123.8 KB · 0:03`，播放中为 Pause、结束后回到可重播 Play。录屏 `180.128333s`；messages durable `1..14`、notifications `1..2` 单调；SQLite 附件 `audio/wav`、`126764` bytes，blob 为 24kHz mono PCM WAV；LLM wire 一次 speech request/response、一次 `generate_speech` tool call，backend/frontend 无未解释红线。正式证据为 `sessions/20260805-032851/evidence/TOOL-120.md`，警报复审为 `tool-120-ledger-alarm-reaudit.md`；anchors `10/10`，五级 `G1/F2/A5/C4/G2` 已落账，最终 `alarms.py check` 为 `clean (635 judgments)`。本格使批次十二达到 **50 / 50**；统一长门禁、完整 testend、工作树审计均已通过，已提交 `91cdd51c`，下一原子前线为 `TOOL-121 generate_video`，尚未开始。

`TOOL-121 generate_video` 首次正式路径完成真实 onboarding、受管网关、Computer Use、窗口录屏、三路独立 SSE witness、LLM tap、backend/frontend journal 和隔离清理。首轮 landscape 成功后，产品复核发现前端丢弃 receipt 的 filename/sizeBytes，且视频在附件行迟到时默认 16:9，portrait/square 可能发生首帧几何跳变；前线冻结并补齐 `AnMediaRef` 的 filename/size/aspect hints、portrait/square/landscape 占位比例、native controller 实际几何覆盖和 delayed-meta widget guard。定向 Flutter 21 项、analyze、Go generate/llm tests 和 diff check 通过。

`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-040847` 用新 binary 真实重跑 portrait：danger card 在批准前阻断；批准后只调用一次视频生成，UI 显示 `Generating video…`、经过 `running…` 和 `generated in 1m43s, downloading…`，最终保存 `generated-20260804-201201.mp4 · video/mp4 · 4.6 MB · 5s`。实际 blob 为 H.264/AAC `720×1280`、`5.038005s`、`4825115` bytes；播放自然结束后 AX 显示 `0:05 / 0:05`、`Replay`、`Fullscreen`，画面为真实灯塔帧。messages durable `1..16`、notifications `1..2` 无 gap，entities 已连接；LLM 为一次 `POST /videos/generations` 202、十次成功轮询和后续 chat completions，无 retry/第二次生成；backend/frontend 无未解释红线，录屏 `378.828333s`。用户确认后 cleanup DELETE=204、GET=404、列表为空，唯一 workspace 与正式 session 保留。正式证据 `sessions/20260805-040847/evidence/TOOL-121.md`，警报复审 `tool-121-ledger-alarm-reaudit.md`；anchors `10/10`，五级 `G1/F2/A5/C4/G2` 已落账，中央账本 `635→640 judgments`，最终 `alarms.py check` 为 `clean (640 judgments)`。批次十三推进到 **5 / 50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `TOOL-122 edit_image`。

`TOOL-113 list_conversations` 首轮正式复验 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-220707` 冻结为红：raw provider 与 durable close 的三条 RFC3339 时间正确，但中间 SSE 曾把 `Alpha planning` 的 `lastMessageAt` 改成 `the recorded time`；同时发现普通词尾 `ge` 被 partial `get_flowrun` matcher 误判。红 session 保留、不计绿。stop-and-fix 收紧 token-boundary，并让带 `lastMessageAt` 的表格在无换行尾行、空目标列和孤立 `|` 行期间整体暂存；补真实 provider wire chunk regression，并同步 chat domain 法条。

修复后二次正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-221418` 使用新 binary、真实 macOS App、真实受管 gateway、Computer Use 和五通道台架：真实对话只调用三次 `list_conversations`，逐 cursor 取回 Gamma/Alpha/Beta 三页；中间 text delta 与 durable close 均无占位，最终 UI 表格逐字显示三条 `lastMessageAt`，稳定态 AX/截图无裁切、重叠或布局红线。`screen.mov` 已封口 `162.765s / 2784x1808 / 60fps`；messages durable `1..20` 单调；backend/frontend 无未解释红线；LLM wire 全 200。正式证据为 `evidence/TOOL-113.md`，复审为 `evidence/tool-113-ledger-alarm-reaudit.md`；锚点 `10/10`，`judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE 行为 `✓✓✓✓✓`，`alarms.py check` 为 `clean (600 judgments)`。

`TOOL-114 manage_conversation` 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-222259` 以真实 App 完成 rename、pin、unpin、archive、当前对话自动 unarchive、显式 unarchive 六条产品路径；空标题负路径只调用一次，服务端返回 `rename requires a non-empty title`，标题不变、没有 fallback 或 retry。稳定 Computer Use 画面和录屏中的失败卡完整可读，通知顺序与 UI/工具结果一致；`screen.mov` 封口 `411.743333s / 2784x1808 / 60fps`，messages durable `1..96`、notifications `1..6` 单调，三路 SSE 均连接，LLM chat responses 全 200，frontend 无运行时红线，backend 只有预期业务校验 WARN。正式证据为 `evidence/TOOL-114.md`，复审为 `evidence/tool-114-ledger-alarm-reaudit.md`；锚点 `10/10`，`judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE 行为 `✓✓✓✓✓`，最终 `alarms.py check` 为 `clean (605 judgments)`。以下均为历史快照；批次未到 50 格，不跑统一长门禁、不提交。

`TOOL-115 search_blocks` 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-232754` 使用新 binary、真实 macOS App、真实受管 gateway、Computer Use、217.091667s 窗口录屏、backend/frontend journal、三路独立 SSE witness 和 LLM tap。正向全 kind 检索一次返回 9 条真实 block；指定 handler 筛选一次返回 3 条；无匹配一次返回可行动建议；空 query 一次显示明确校验失败且无 retry/mutation。首轮真实复验发现摘要泄漏 opaque ref、跨 SSE chunk 占位符闪现和 hosted model 字符串化 `kinds`/`limit`；stop-and-fix 增加换行前缓冲、search_blocks 摘要归一化和严格兼容解码，并强化“不先做 unfiltered preliminary call”的工具契约。修复后二次复验中工具卡保留精确 ref，助手表格不泄露机器标识，UI、SQLite、tool result、SSE 和 LLM wire 一致；frontend 无运行时红线，backend 只有预期空 query WARN，LLM chat responses 全 200。正式证据为 `evidence/TOOL-115.md`，警报复审为 `evidence/tool-115-ledger-alarm-reaudit.md`；锚点 `10/10`，`judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE 行为 `✓✓✓✓✓`，最终 `alarms.py check` 为 `clean (610 judgments)`。以下均为历史快照；批次未到 50 格，不跑统一长门禁、不提交。

`TOOL-116 get_relations` 首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-014547` 冻结为红：关系表的 `起点 (from)` 端点名称后泄露 `(fromId: deploy-helper)`，中间 SSE delta 也曾露出裸关系占位符；该 session 不计绿。stop-and-fix 让关系表按 `起点/终点/端点名称` 识别端点列，只展示 kind 与人名；机器字段、关系 ID、时间戳和裸占位符在 delta 与 durable close 都先暂存并完整脱敏，精确 ref 只留在相邻 tool card、tool result 和 LLM 审计线缆；新增真实 hosted-model 形态回归测试并同步 chat domain 法条。修复后二次正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-015059` 使用新 binary、真实 App、真实受管 gateway、Computer Use 和五通道台架，真实请求只调用一次 `get_relations`，最终画面显示 `技能 deploy-helper → 函数 greet` 与 `精确 ref 见关系卡`；assistant-only SSE delta/reasoning/close 禁词扫描为空，`rig-check.sh` 五观察器通过后由 `rig-down.sh` 封口，frontend/backend 无 runtime 红线，LLM 状态全 200。正式证据为 `evidence/TOOL-116.md`，警报复审为 `evidence/tool-116-ledger-alarm-reaudit.md`；锚点 `10/10`，`judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE 行为 `✓✓✓✓✓`，最终 `alarms.py check` 为 `clean (615 judgments)`。以下均为历史快照；批次未到 50 格，不跑统一长门禁、不提交。

`TOOL-117 WebFetch` 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-020051` 使用新 binary、真实 macOS App、真实受管 gateway、Computer Use、三路独立 SSE witness、LLM tap、backend/frontend journal 和窗口录屏。正向 RFC 9110 local fetch 从 `Fetching...` 收口为 486 字 grounded 摘要；`example.com` 在 local 模式诚实显示 `JS page` 与 127 字 shell 降级，在 Chat 设置切换 `Jina proxy` 后同页真实返回 133 字正文并准确回答 `Example Domain`。loopback 请求被明确拒绝，无网络副作用。录屏 `336.700000s / 2784x1808 / 60fps`，SQLite 最终 `web_fetch_mode=jina`，messages durable `1..62`、notifications `1..2` 单调，四条 WebFetch tool-result close、LLM 28 个 HTTP response 全 200，backend/frontend 无未解释 runtime 红线；正式证据为 `evidence/TOOL-117.md`，警报复审为 `evidence/tool-117-ledger-alarm-reaudit.md`。锚点 `10/10`，`judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE 行为 `✓✓✓✓✓`，最终 `alarms.py check` 为 `clean (620 judgments)`。以下均为历史快照；批次未到 50 格，不跑统一长门禁、不提交。
`TOOL-117 WebFetch` 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-020051` 使用新 binary、真实 macOS App、真实受管 gateway、Computer Use、三路独立 SSE witness、LLM tap、backend/frontend journal 和窗口录屏。正向 RFC 9110 local fetch 从 `Fetching...` 收口为 486 字 grounded 摘要；`example.com` 在 local 模式诚实显示 `JS page` 与 127 字 shell 降级，在 Chat 设置切换 `Jina proxy` 后同页真实返回 133 字正文并准确回答 `Example Domain`。loopback 请求被明确拒绝，无网络副作用。录屏 `336.700000s / 2784x1808 / 60fps`，SQLite 最终 `web_fetch_mode=jina`，messages durable `1..62`、notifications `1..2` 单调，四条 WebFetch tool-result close、LLM 28 个 HTTP response 全 200，backend/frontend 无未解释 runtime 红线；正式证据为 `evidence/TOOL-117.md`，警报复审为 `tool-117-ledger-alarm-reaudit.md`。锚点 `10/10`，`judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE 行为 `✓✓✓✓✓`，最终 `alarms.py check` 为 `clean (620 judgments)`。以下均为历史快照；批次未到 50 格，不跑统一长门禁、不提交。

`TOOL-118 WebSearch` 首轮正向真实 App 路径冻结为红：托管模型把公开 schema 的 `limit` 发成字符串，后端正确拒绝后出现可见 validation failure 和 retry；stop-and-fix 将 schema 收紧为 integer，同时在执行边界接受原生整数与精确十进制字符串，浮点/任意字符串/数组/布尔继续拒绝，并补 Go 回归。修复后的正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-023835` 以新 binary、真实 App、真实受管 gateway、Computer Use、三路 SSE witness、LLM tap 和窗口录屏完成成功与 401 失败两条路径；成功只调用一次 WebSearch，返回 Alpha/Beta 两条有序结果、`2+ hits` 与 `truncated:true`，失败只调用一次且显示 provider 401，无 retry。抽帧又发现助手复述的长错误代码块横向裁切；stop-and-fix 让 Markdown 围栏代码默认 `wrap:true`，并钉住只读宽度基准，补 40 项 Flutter 回归。最终失败帧 `frames/frame-195.jpg` 已完整折成两行，`authentication failed` 与 JSON 全可读；正向 settled 帧为 `frames/frame-135.jpg`。五通道：screen.mov `244.275000s / 2784x1808 / 60fps`，messages durable `1..40`、notifications `1..4` 单调且 0 gap，LLM body 对两条路径均恰一条 WebSearch、backend 仅预期 401 WARN、frontend 无异常；证据 `evidence/TOOL-118.md`，警报复审 `evidence/tool-118-ledger-alarm-reaudit.md`，anchors `10/10`，五级 `G1/F2/A5/C4/G2` 已落账，最终 `alarms.py check` 为 `clean (625 judgments)`。以下均为历史快照；批次未到 50 格，不跑统一长门禁、不提交。

**历史快照（2026-08-04，TOOL-113 之前）。** 第九批 `TOOL-081..090` 已完成 **50 / 50** 并提交 `32b33499`；第十批 `TOOL-091..100` 已完成 **50 / 50** 并提交 `553fa150`；第十一批 `TOOL-101..110` 已完成 **50 / 50**，统一长门禁、`make verify`、锚点校准和警报复核均通过，已提交 `de146b72`。当时正式账本为 **595 judgments**，本批为 **10 / 50**，下一原子前线为 `TOOL-113 list_conversations`。该段仅供追溯，当前前线以上方整体重述为准。

`TOOL-112 search_conversations` 首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-205354` 冻结为红：新 workspace 的后台免费档 hook 与首条 Chat 消息发生竞态，UI 出现 `LLM_RESOLVE_ERROR · no model configured for scenario`；该 session 保留、不计绿。stop-and-fix 增加同 workspace provisioning single-flight，并让桌面 onboarding 在释放 Chat 前调用既有 `POST /freetier:provision` 做前台就绪检查；同时把 FTS snippet 窗口从 16 token 收紧证据不足的缺陷修为有界 64 token，并加精确连字符查询回归。

修复后二次正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-210040` 从空数据目录启动真实 macOS App、真实受管 gateway、Computer Use 和五通道台架：workspace 创建后前台 provision 等到受管 key/default model 可见，Chat 首发无模型错误；源对话写入 `ORBITAL-112-FIX4` 并改名 `Launch plan notes`，新对话真实调用 `search_conversations` 返回 1 个 message hit。展开卡片逐帧可见完整高亮、`matchedChunks=2`、可复制 `messageId` 芯片；点击命中行深跳到目标 assistant message，画面与 SQLite/REST 一致。`rig-check.sh`、`rig-down.sh` 均通过；`backend.log`/`frontend.log` 无未解释 runtime 红线，`sse.jsonl` 三流连接且 durable close 序列一致，`llm.jsonl` 含真实受管 wire 与完整 tool result。正式证据为 `evidence/TOOL-112.md`；锚点 `10/10`，`judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE 行为 `✓✓✓✓✓`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已按红 session、修复后二次绿 session、五通道证据和校准结果书面 ack，最终 `alarms.py check` 为 `clean (595 judgments)`。本批未到 50 格，不跑统一长门禁、不提交。

`TOOL-109 run_skill_script` 正式绿 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-184737`，录屏已封口。首轮重跑确认 lazy 目录行已经暴露 `run_skill_script(name, script; optional: args, stdin, timeoutSec)`，并明确 `name` 是 skill slug、`script` 是相对路径；真实正向路径只产生一次成功调用，参数、stdin、沙箱 stdout 与最终 `OK` 一致。缺失脚本和 `.sh` 扩展名两条负向路径各只产生一次失败调用，无 retry；后端 WARN 是预期业务失败，非未处理异常。五通道 `rig-check` 全绿，frontend 无 Flutter/AX/Unhandled 红线，SSE 与 LLM wire 均证明三条对话各只有一个 `run_skill_script` 调用。正式证据为 `evidence/TOOL-109.md`，警报重审为 `evidence/tool-109-ledger-alarm-reaudit.md`；`judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE 行为 `✓✓✓✓✓`，锚点 10/10，`alarms.py check` 为 `clean (580 judgments)`。下方内容均为历史快照；恢复执行时以上述整体重述、`LOG.md` 最新条目和 COVERAGE 当前行作为唯一前线。第十一批未到 50 格前不跑统一长门禁、不提交。

`TOOL-110 Subagent` 正式绿 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-190256`，录屏已封口。真实正向路径只调用一次 `Subagent(Explore)`，子运行读取真实 `CLAUDE.md` 并返回首个标题，UI 只出现一次 `Spawned subagent · Explore`，嵌套轨迹归在父卡下；非法 `subagent_type=Nope` 路径只产生一次校验错误，UI 改为 `Subagent validation failed · not started`，明确没有启动子代理，不显示 `get_subagent_trace` 回放提示。前置红线是失败卡误称“已派子代理”并虚构轨迹，已修复 `failedVerb`、未启动体文案、错误重复回答和中英文 i18n，并补 widget regression；修复后正负路径重跑通过。SSE 正向恰有 1 个 `subagent:true` 子消息、负向为 0；backend 只有预期校验 WARN，frontend Flutter/AX/Unhandled 红线为 0，LLM wire 全 200，`rig-check` 五通道全绿。正式证据为 `evidence/TOOL-110.md`，警报重审为 `evidence/tool-110-ledger-alarm-reaudit.md`；`judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE 行为 `✓✓✓✓✓`，锚点 10/10，`alarms.py check` 为 `clean (585 judgments)`。本批已到 50 / 50，完成长门禁和提交后才进入 `TOOL-111`。
`TOOL-110 Subagent` 正式绿 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-190256`，录屏已封口。真实正向路径只调用一次 `Subagent(Explore)`，子运行读取真实 `CLAUDE.md` 并返回首个标题，UI 只出现一次 `Spawned subagent · Explore`，嵌套轨迹归在父卡下；非法 `subagent_type=Nope` 路径只产生一次校验错误，UI 改为 `Subagent validation failed · not started`，明确没有启动子代理，不显示 `get_subagent_trace` 回放提示。前置红线是失败卡误称“已派子代理”并虚构轨迹，已修复 `failedVerb`、未启动体文案、错误重复回答和中英文 i18n，并补 widget regression；修复后正负路径重跑通过。SSE 正向恰有 1 个 `subagent:true` 子消息、负向为 0；backend 只有预期校验 WARN，frontend Flutter/AX/Unhandled 红线为 0，LLM wire 全 200，`rig-check` 五通道全绿。正式证据为 `evidence/TOOL-110.md`，警报重审为 `evidence/tool-110-ledger-alarm-reaudit.md`；`judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE 行为 `✓✓✓✓✓`，锚点 10/10，`alarms.py check` 为 `clean (585 judgments)`。随后完整 `make testend` 发现并冻结了一个旧验收剧本问题：`install_mcp_server` 的 danger gate 未被场景处理，导致回合正确停在 `streaming`；场景已改为逐次断言并批准两道人闸，定向场景与完整 testend 均通过，MCP 领域文档同步说明该安全边界。本批完成长门禁、最终验证、审计并提交 `de146b72`，下一原子前线为 `TOOL-111 get_subagent_trace`。

上段为当前事实；下方内容均为历史快照。恢复执行时以上述整体重述、`LOG.md` 最新条目和 COVERAGE 当前行作为唯一前线。

`TOOL-108 delete_skill` 正式绿 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-180135`，录屏 `564.176667s`。真实 App 先验证模型自报 `danger=safe` 被静态危险下限挡住，再验证不存在目标经过 HumanLoop Deny 后终局且不重试，最后在用户明确确认后 Allow 删除 fixture；UI 只有一次危险闸、一次 `Deleted` activity 和成功反馈。目标目录已消失，列表不再出现目标，单项 REST 返回 `SKILL_NOT_FOUND`；SSE 有一次 `skill.deleted`、一次 `deleted` touchpoint 和一次成功 tool_result，LLM wire 只有一次 mutation，backend/frontend/录屏一致。`rig-check` 五通道全绿，台架已收台；正式证据为 `evidence/tool-108-formal-180135-green.md`，警报重审为 `evidence/tool-108-ledger-alarm-reaudit.md`。`judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE 行为 `✓✓✓✓✓`，`alarms.py check` 为 `clean (575 judgments)`。下方内容均为历史快照；恢复执行时以上述整体重述、`LOG.md` 最新条目和 COVERAGE 当前行作为唯一前线。第十一批未到 50 格前不跑统一长门禁、不提交。

`TOOL-107 edit_skill` 的正式绿 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-175428`，录屏 `130.763333s`。成功路径真实读取 `deploy-helper` 后只做一次完整覆盖，UI/Activity 只有一条 `Edited`，正文与完整元数据可见，文件真相已核对；失败路径真实编辑不存在的 `missing-skill-107`，只出现一张 `Failed`，错误原文为 `skill not found`，右侧明确显示 `Draft unsaved · truth is still the last version`，没有创建残留。SSE、LLM wire、backend journal、SQLite/文件系统和画面一致，`rig-check` 五通道全绿；frontend 只有已知 foreground 诊断，无 Flutter exception。

本格先后冻结四条红线且全部排除出账本：Computer Use 换行误提交；`AnInteractive` 布局阶段同步 `setState`；托管模型把 `disableModelInvocation:false` 字符串化导致合法 edit 首次失败并重试；缺失 skill 的终局错误重复执行导致两张红卡。stop-and-fix 已分别完成 post-frame hover flush 与回归测试、`decodeSkillBool` 精确字符串兼容、`EditSkill.HaltOnRepeat` 终局抑制，并同步 backend/frontend 领域文档。红证据保留在 `173117`、`173358`、`174614`、`175039` 四个 session 的 `evidence/` 下。

`judge.py` 已以 `G1/F2/A5/C4/G2` 写入 `TOOL-107` 五格，COVERAGE 行为 `✓✓✓✓✓`；锚点 10/10 校准通过，写账触发的 `gap-too-fast` 与 `discovery-collapse` 已依据四条红证据、正式绿 session、五通道日志、回归测试和 `evidence/tool-107-ledger-alarm-reaudit.md` 复审并 ack，当前 `alarms.py check` 为 `clean (570 judgments)`。下方内容均为历史快照；恢复执行时以上述整体重述、`LOG.md` 最新条目和 COVERAGE 当前行作为唯一前线。第十一批未到 50 格前不跑统一长门禁、不提交。

`TOOL-104 activate_skill` 首轮红 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-164045` 暴露托管模型把公开 schema 的 `arguments: array<string>` 编成 JSON 数组字符串：后端正确拒绝了旧形状，真实 App 出现失败卡，模型随后重复用原生数组重试；红证据保留，不计绿。stop-and-fix 增加窄兼容层，只接受原生字符串数组或**精确 JSON 数组编码字符串**，普通字符串、数字、对象、混合数组和非法编码继续拒绝；同步单测与 skill 领域文档。

正式绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-164732` 使用新 binary、真实 Flutter App、真实受管 gateway、Computer Use 和五通道台架重跑。LLM wire 实际仍发字符串化数组，但只执行一次；App 只有一张成功 `Activated skill activation-104` 卡，`$1`/`$ARGUMENTS` 正确替换为 `design`/`design review`，没有失败重试卡；SSE、SQLite、backend/frontend journal 与画面一致，后端无 WARN/ERROR，录屏 `198.910000s / 2784x1808 / 60fps`。正式证据 `evidence/tool-104-formal-164732-green.md`。

`TOOL-103 get_mcp_call` 首轮红 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-163003` 暴露托管模型连续把 opaque `callId` 从真实记录的 `...bfa41` 抄成 `...bba41`：后端正确返回 `mcp call not found`，App 正确渲染红色失败卷宗，没有伪造成功；红证据 `evidence/tool-103-red-opaque-id-copy.md` 保留，不计绿。正式绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-163620` 使用真实 Context7 历史记录，按原样读取单条成功调用：App 卡片显示 `Completed · 2.0s`、工具 chip 和完整卷宗，SQLite 为 `status=ok / triggered_by=chat / elapsed_ms=1990`，SSE 含 exact argument 与 tool-result close，LLM wire 未改写，backend 无 WARN/ERROR，Flutter runner 无 Dart/Unhandled 红线。录屏 `72.616667s / 2784x1808 / 60fps`，正式证据 `evidence/tool-103-formal-163620-green.md`。

`TOOL-102 search_mcp_calls` 首轮真实红 session `20260804-160132` 冻结了托管模型把 `limit` 发成字符串时的可见失败卡与自动重复查询；stop-and-fix 让执行层接受原生整数与精确十进制字符串，浮点、数组、布尔、对象和非整数文本继续拒绝，并把 schema 描述与现有 handler/activation 先例同步。正式绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-161720` 从 fresh onboarding 和真实 Context7 安装开始：两次真实 `resolve-library-id`（合法 Flutter 查询与空业务参数）、一次有界 `search_mcp_calls(limit=1)`、一次 `nextCursor` 翻页；App 卡片、SQLite、SSE、LLM wire、backend/frontend journal 一致，翻页从 `hasMore=true` 正确收口为 `false`，无失败重试卡。业务文本 `Library name is required` 的 MCP `IsError=false` 仍诚实记录为 `status=ok`，没有由产品猜测擅自重分类。五通道 `rig-check` 收台前全绿；正式证据 `evidence/tool-102-formal-161720-green.md`，警报复审 `tool-102-ledger-alarm-reaudit.md`。

`judge.py` 已以 `G1/F2/A5/C4/G2` 写入 `TOOL-104` 五格，COVERAGE 行为 `✓✓✓✓✓`；锚点继续有效，五格写入触发的 `gap-too-fast` 与 `discovery-collapse` 已依据真实参数形状红案、正式绿 session、五通道原始日志、SQLite/LLM 线材、录屏和复审说明 ack，`alarms.py check` 为 `clean (555 judgments)`。下方第十批及更早段落是历史快照；恢复执行时以上述整体重述、`LOG.md` 最新条目和 COVERAGE 当前行作为唯一前线。

`TOOL-105 get_skill` 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-165430` 完成 existing 与 missing 两条真实路径。existing 只调用一次 `get_skill(deploy-helper)`，结构化 card 显示 skill identity、description/context/source、allowed-tools chips 和完整 Markdown body；展开 `raw result` 后可核对未过滤的 opaque allowed-tool、workspace dir、ISO `updatedAt`、完整 frontmatter/body。助手 prose 的机器值脱敏是全局安全法条，不放开；missing `missing-skill-105` 只产生一张红失败 card 和一个预期 backend execute-failed WARN，无 retry/activate/create/edit。录屏 `276.158333s / 2784x1808 / 60fps`，五通道证据 `evidence/tool-105-formal-165430-green.md`。

`judge.py` 已以 `G1/F2/A5/C4/G2` 写入 `TOOL-105` 五格，COVERAGE 行为 `✓✓✓✓✓`；`gap-too-fast`、`pass-burst` 与 `discovery-collapse` 已依据真实负路径、raw-result 展开和五通道复审说明 ack，`alarms.py check` 为 `clean (560 judgments)`。下方第十批及更早段落是历史快照；恢复执行时以上述整体重述、`LOG.md` 最新条目和 COVERAGE 当前行作为唯一前线。

`TOOL-106 create_skill` 的前置真实 session `20260804-170849` 捕获托管模型把 `allowedTools`/`arguments` 编成 JSON 数组字符串，旧执行层拒绝后模型重复调用；`20260804-171251` 又暴露可选元数据被模型省略；`20260804-171503` 暴露冲突时 Activity rail 错把成功动词与 failed 并列。三份红证据均保留且不计绿。stop-and-fix 增加共享的精确数组字符串兼容解码与完整工具描述，并让中心卡/侧幕失败态都只使用明确失败语义；Go/Flutter 定向守卫测试和领域文档同步。

正式绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-171941` 使用新 binary、真实 Flutter App、真实受管 gateway、Computer Use、三路独立 SSE witness、LLM tap、backend/frontend journal 和 `333.665000s` 录屏。成功路径只创建一次 `release-notes-106e`，卡片逐字段展示完整元数据与正文，Activity 只有一条 `Created`；重名路径只调用一次，中心显示 `Create skill failed` 与真实 `skill name already exists`，侧幕只显示 `Failed` 和 `Draft unsaved · nothing was created`，没有 retry、第二条 mutation 或矛盾成功卡。五通道、SSE/SQLite/LLM wire/UI 一致；backend 仅有预期重名 WARN，Flutter 无异常红线。正式证据 `evidence/tool-106-formal-171941-green.md`。

`judge.py` 已以 `G1/F2/A5/C4/G2` 写入 `TOOL-106` 五格，COVERAGE 行为 `✓✓✓✓✓`；锚点因超过 4 小时被 gate 拒绝后已重新完成 10/10 校准，五格写入后的 `gap-too-fast` 与 `discovery-collapse` 已依据正负路径、三份红证据、五通道 session 和锚点复审并 ack，复审说明为 `evidence/tool-106-ledger-alarm-reaudit.md`，当前 `alarms.py check` 为 `clean (565 judgments)`。下方第十批及更早段落是历史快照；恢复执行时以上述整体重述、`LOG.md` 最新条目和 COVERAGE 当前行作为唯一前线。

TOOL-101 经过三次真实红冻结后才接受第四次绿：`152538` 暴露 prose 只有无信息量的 `the recorded time` 且结构化 MCP 卡缺 `connectedAt`；`153910` 暴露 label/value 形状未被第一版规则覆盖；`154256` 暴露 Markdown `**Connected at:**` 跨 provider chunk 后仍泄漏 vague placeholder。三份红证据均保留，均未写账；stop-and-fix 保留 raw ISO 脱敏边界，新增 label/value、Markdown 表格和跨 chunk 语义处理，结构化卡显示本地化连接时间，并让 Unix long-lived cleanup 在外部进程组竞态时幂等回退到 direct child。

正式绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-155203` 从 fresh onboarding、真实 Context7 安装和用户 Allow 开始；外部终止 MCP 进程组后成功完成一次 reconnect，第二次 reconnect 不重复执行，未知名称只生成一张明确失败卡且不重试。最终 App 卡片显示 `connected`、2 个 tool chips 和 `Connected at · 2026-08-04 15:54`，正文明确指向 MCP status card。五通道封口：window recording `203.746667s`；SSE messages durable `1..37`、notifications `1..6` 单调，entities 捕获 `disconnected → connecting → ready`；LLM tap 观察到的 upstream responses 全 HTTP 200；backend 仅有预期 unknown-server WARN，无 panic/FATAL/cleanup 权限警告；frontend 无 Flutter/Dart/RenderFlex/Unhandled 红线；`rig-check` 收台前五通道均通过。证据为 `evidence/tool-101-formal-155203-green.md`，账本复审为 `tool-101-ledger-alarm-reaudit.md`。

`judge.py` 已以 `G1/F2/A5/C4/G2` 写入 `TOOL-101` 五格，COVERAGE 行为 `✓✓✓✓✓`；锚点 10/10 已重校，五格写入触发的 `gap-too-fast` 与 `discovery-collapse` 已依据三份红证据、正式绿 session、五通道原始日志、修复回归和复审文件 ack，`alarms.py check` 为 `clean (540 judgments)`。下方第十批及更早段落是历史快照；恢复执行时以上述整体重述、`LOG.md` 最新条目和 COVERAGE 当前行作为唯一前线。

`TOOL-098` formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-100552` 使用全新数据目录、真实 Flutter App、真实受管 gateway、Computer Use、三路独立 SSE witness、LLM tap、backend/frontend journal 和 `385.805000s / 2784x1808 / 60fps` 录屏完成三条路径：`query="database query"` 返回 4 个 installable server；不可命中 query 返回 0，并在 UI 给出扩大 query/单词/无 query/能力描述四类恢复建议；无 query 返回 96 个 installable server，卡片显示 `first 30 of 96`，点击后进入有界 JSON tree，不静默丢剩余目录。query 结果的真实卡片逐 server 显示 full name、description、runtime 和 required-env 数量，模型正文补充精确 env 名称与 required/optional 状态。

修复后 formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-104247` 用新 binary 重跑同一无 env 路径：`tool_call danger:"dangerous" → interaction → resolved(Deny) → tool_result`，没有安装执行或半安装行；UI 的危险闸文案与 canonical summary 完整，Deny 后助手准确说明 env 未知、没有伪造 `ENTRA_CLIENT_ID`。录屏 `88.993333s / 2784x1808 / 60fps`，五通道和 `rig-check` 全绿；证据 `evidence/tool-099-formal-104247-red-deny-gate.md` 只证明恢复后的负路径，不计 `TOOL-099` 绿格。

`TOOL-099` success formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-142537` 的 action-time `Allow` 确实完成了真实 `context7` 安装，修复后的卡片显示 `Allowed · connected · 2 tools`，并完成一次动态工具发现与 `resolve-library-id` 调用；但 cleanup 中 `uninstall_mcp_server` 在没有 interaction 的情况下执行，错误名称后模型又重试一次。屏幕录制 `297.000000s / 2784x1808 / 60fps`、五通道 journals、SSE `messages 1..58`、MCP row/tool list 与后端日志均保留，红证据 `evidence/tool-099-formal-143238-red-uninstall-no-gate-retry.md`；台架已收台。卸载 floor/alias stop-and-fix 已完成，下一步必须从新 binary 重跑一次受 gate 保护的 uninstall，确认失败名不重试、Allow/Deny 语义正确、最终 UI 不出现矛盾卡片，随后才能写 TOOL-099 五级判决。

Computer Use 逐帧复核没有发现裁剪、死链、表头错位或不可行动空态；五通道一致：SSE 三流连接，messages durable `1..48`、notifications `1..6` 单调唯一；LLM wire 三个 chat body 各只有一次 marketplace call（另有预期 lazy `search_tools`），所有 HTTP 200；backend/frontend redline 扫描为空，`rig-check` 五观察器全绿。一次 30 秒 Computer Use 观察器超时已重置 kernel 并重新取得最终 AX/画面，记录为仪器事件而非产品红。正式证据为 `evidence/tool-098-formal-100552-green.md`，前端生态回归 `24/24` 通过。

五级 `G1/F2/A5/C4/G2` 已写入 COVERAGE，`TOOL-098` 行为 `✓✓✓✓✓`；中央账本由 520 增至 **525 judgments**。五格写账触发的 `gap-too-fast` 与 `discovery-collapse` 已以 anchors `10/10`、三条正负/边界路径、正式录屏、五通道 raw journal 和 `evidence/tool-098-ledger-alarm-reaudit.md` 完成重审并 ack，正式 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 alarms.py check` 为 `clean (525 judgments)`。验收 conversations 已真实 DELETE=204、列表为空；正式 evidence/journal/录像保留，`gen_coverage.py` 重建仍为 **848 rows × 5 = 4240 cells**。

`TOOL-097` 首轮 formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-094444` 冻结为红：后端和 LLM wire 已返回完整模型配置，但真实 App 的 durable tool card 只有模型数量和名称 chip，key 健康、脱敏值、端点、默认 key 关联及能力边界不可检查；红证据 `evidence/tool-097-formal-094444-red-thin-card.md` 保留、不计绿。stop-and-fix 只改前端 projection boundary：`modelConfigBody` 增加默认角色/模型与安全 key display name、API key 的 provider/masked/status、端点、bounded available-model capability table 和 native option chips；绝不渲染 `apiKeyId` 或密文，并同步中英文 i18n 与 widget privacy regression。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-095429` 使用修复后二进制、真实 onboarding workspace、真实 Flutter App、真实受管 gateway、Computer Use、三路独立 SSE witness、LLM tap、backend/frontend journal 和最终 `173.423333s / 2784x1808 / 60fps` 录屏重跑。最终展开卡片直接显示六个默认角色的 `anselm-auto · Anselm Free`、key `Anselm Free / anselm / ins_ab0...82c6 / ok`、endpoint、model `anselm-auto / anselm / 1M / 16.4k / image · video` 和 native option；没有 raw JSON、`apiKeyId`、布局剪裁或未解释跳变。SSE 三流各连接一次，messages durable `1..14`、notifications `1..2`，只有一次 tool call/result；LLM wire、REST、SQLite、UI 一致，backend/frontend 红线为空，`rig-check` 五观察器全绿。

五级 `G1/F2/A5/C4/G2` 已写入 COVERAGE，`TOOL-097` 行为 `✓✓✓✓✓`；中央账本由 515 增至 **520 judgments**。五格写账触发的 `gap-too-fast` 与 `discovery-collapse` 已以 anchors `10/10`、红证据、修复测试、正式绿 session 和 `evidence/tool-097-ledger-alarm-reaudit.md` 完成重审并 ack，正式 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 alarms.py check` 为 `clean (520 judgments)`。验收 conversation 已真实 DELETE=204、列表为空，正式 journals/录像/evidence 保留；`gen_coverage.py` 重建为 **848 rows × 5 = 4240 cells**。

`TOOL-096` 首轮 formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-195946` 冻结为红：真实 App 要求一次 `forget_memory` 删除已存在 memory，SSE 的 tool call 为 `danger:"cautious"`，没有 `Dangerous · Awaiting your approval`，随后直接产生 `Forgot memory …` 并真实删除。红证据为 `evidence/tool-096-formal-195946-red-missing-danger-floor.md`，不计绿。stop-and-fix 为 `ForgetMemory.MinimumDanger() = DangerDangerous`、准确 canonical gate summary、破坏性工具总测试、loop gate summary 测试、memory 领域文档与工具清册同步。

修复后的 deny formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-200420` 使用真实 Flutter App、真实受管 gateway、Computer Use、三路 SSE witness、LLM tap、backend/frontend journal 和 `214.911667s / 2784x1808 / 60fps` 窗口录屏，证明 existing-memory 与 missing-memory 两条路径都停在准确 approval，Deny 无副作用。随后正式 green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-093819` 在用户 action-time 授权后完成 Allow：画面先显示不可逆/无恢复 approval，批准后显示 `Forgot`；REST memory list 为空、目标 GET=404。第二个新对话再次批准同一调用后显示中性 `Already gone`，工具返回 `not found (already gone?)`，没有第二条 `memory.deleted` 通知。绿证据为 `evidence/tool-096-formal-093819-green.md`，账本复审为 `tool-096-ledger-alarm-reaudit.md`。

五通道交叉证据已封存：`rig-check` 在录制期间通过全部五个物理观察器，录屏 `114.498333s / 2784x1808 / 60fps`；SSE 两个 conversation 各只有一次 `forget_memory`，每次均为 `tool_call → interaction → resolved → tool_result`，真实删除只产生一次 `memory.deleted`，durable messages 到 seq 28；LLM wire、REST、UI 和 backend journal 一致；frontend/backend 红线扫描无 panic/fatal/error/warn/exception/Flutter runtime marker。anchors `10/10`，五级 `G1/F2/A5/C4/G2` 已写入 COVERAGE，行状态为 `✓✓✓✓✓`。五格写账触发的 `gap-too-fast` 与 `discovery-collapse` 已依据红证据、修复链、正式 session 和复审记录 ack；正式 `export RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3; alarms.py check` 为 `clean (515 judgments)`。真实验收 conversation 已 DELETE=204、列表为空，memory 已 404；正式 evidence/journal/审计行保留。`gen_coverage.py` 重建仍为 **848 rows**。

`TOOL-095 write_memory` formal green session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-194919` 使用全新数据目录、真实 Flutter App、真实受管 gateway、Computer Use 逐帧观察、三路独立 SSE witness、LLM tap、backend/frontend journal；录屏 `211.295000s / 2784x1808 / 60fps`。三条路径均通过：一次 exact create 落为 `source=ai,pinned=false`；一次更新真实用户置顶记忆，description/body 改变但 `source=user,pinned=true` 保留；一次非法 slug 原样送达后权威拒绝、不归一化、不创建。UI 成功卡可展开显示 AI/source、description、正文，失败卡明确红色 `Not saved` 与 slug 规则，无 raw JSON、重复 mutation 或布局溢出。

五通道交叉证据完整：SSE 三流已连接，messages durable `1..42`、notifications `1..9` 连续；create `write_memory seq 7 → result seq 9`、update `seq 21 → 23`、invalid `seq 35 → 37`，每条路径只调用一次；LLM wire `24` 个状态条目全为 200，pinned system projection 在更新前后分别携带 V1/V2 且 source=user；backend/frontend journal 无 panic/fatal/error/warn/exception/Flutter runtime 红线。正式证据为 `sessions/20260803-194919/evidence/tool-095-formal-194919-green.md`。

五级裁决 `TOOL-095=G1/F2/A5/C4/G2` 已写入 COVERAGE，`TOOL-095` 行为 `✓✓✓✓✓`。五格写账后按机制触发的 `gap-too-fast`、`pass-burst` 与 `discovery-collapse` 已依据正式 session、逐格复审记录 `tool-095-ledger-alarm-reaudit.md`、anchors 10/10 和五通道原始 journal ack；正式 `export RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3; alarms.py check` 为 `clean (510 judgments)`。正式 fixture 的三条 conversation 与两个 memory 已通过真实 API `DELETE=204`、列表为空清理；唯一 workspace 因最后 workspace 不可删除约束保留，正式证据和审计行不删除。

`TOOL-088 edit_document` 首轮至第七轮真实观察冻结七条红：reasoning placeholder 泄漏；tags 被发成 JSON 字符串后失败；同一用户意图被拆成两次 edit；重复 search 进入失败循环；hosted provider 对 tags 做双重编码；失败 search 后没有稳健恢复；以及 provider 将 `search_documents` 发成 filesystem-shaped `path/pattern` 参数。七份红证据均保留、不计绿。

stop-and-fix 修复 loop 的 per-Run tool ledger（成功 safe call 只抑制重复、不结束回合；失败 safe call 可重试；危险/越界调用仍按保护规则停回合），增加 `search_documents` 的窄兼容层（仅把 provider 的非空 `path/pattern` 当文档库 query，绝不读 filesystem；空形状返回有界文档页），增加 `edit_document.tags` 对一层 JSON 编码数组的精确兼容解码，并收紧 prompt/schema 为单一 canonical edit、完整 search 后逐字使用 opaque `doc_` ID。同步 loop/document/chat 测试、领域/API 文档与工具抽取清册；定向 Go tests、docs verify 和 diff check 通过。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-155506` 使用新二进制、真实 Flutter App、真实受管 gateway、真实 onboarding、Computer Use、140.740000s 窗口录屏、backend/frontend journals、三路独立 SSE witness 和 LLM tap 重跑。用户目的真实完成：root `/Release Atlas Final` 被完整编辑，description/body/tags 与意图一致，child 自动继承新路径；wire 只有一次成功 `search_documents`、一次成功 `edit_document`、一次成功 child search，无 retry/失败活动/重复 mutation。SQLite/REST、tool result、UI 与五通道交叉一致；messages durable `1..27`、notifications `1..5` 连续，LLM 响应全 200，backend/frontend 错误扫描 clean。正式证据为 `evidence/tool-088-formal-155506-green-edit-document.md`，五级 `G1/F2/A5/C4/G2` 已落账。

`TOOL-089 move_document` 首轮 formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-162904` 冻结为红：真实 App 在 true-cycle 拒绝后把同一 document/parent pair 重复发起，且 UI 将 terminal duplicate 渲染成误导性的第二张 `Not run` 卡。红证据保留、不计绿。stop-and-fix 增加不改变 S18 五方法接口的 `RepeatTerminaler` 可选终态标记；per-Run ledger 区分安全失败可重试、保护调用停回合和 terminal cycle rejection；前端只隐藏 terminal duplicate 噪声但保留 durable/SSE/audit 证据。同步 move 工具描述/schema、后端/前端领域文档、工具抽取清册、本地 Go/Flutter 回归测试和中英文案。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-164319` 使用修复后二进制、真实 onboarding、真实 Flutter App、真实受管 gateway、Computer Use、546.920000s 封口录屏、backend/frontend journals、三路独立 SSE witness 和 LLM tap 重跑。正向路径一次将 `Source Section` 移入 destination position 0，一次移回 root position 2 并只读 destination 一次；负向路径一次将其移入自身 descendant，后端 terminal reject、无 mutation，UI 只显示一张清楚的红色 `Move rejected`。SQLite 的 seq `3/4`、`9/10`、`12/13`、`18/19`、最终 parent/position/path 与 UI/tool result/wire 一致；SSE 452 frames、61 durable、无 gap，LLM 全 200，backend/frontend 无未解释红线。正式证据为 `evidence/tool-089-formal-164319-green.md`，账本复审为 `tool-089-ledger-alarm-reaudit.md`；五级 `G1/F2/A5/C4/G2` 已落账。

`TOOL-090 delete_document` 首轮 formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-170003` 冻结为红：真实 App 的后端 not-found 软失败与最终 prose 都正确，但工具卡仍显示 `Deleted document doc_missing_delete_090`，并保留成功软删注记。修复为 completed payload 的 not-found 重分类：失败动词、琥珀原始证据、自动展开且不显示成功注记；同步前端回归、Document/Chat 文档和工具清册。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-170748` 使用新二进制、真实 onboarding、真实 Flutter App、真实受管 gateway、Computer Use、234.611667s 封口录屏和五通道台架重跑。正向一次 exact search + 一次 delete，root/child/deep 三行同一 tombstone 时间、Standalone 活文档不受影响；负向一次 fabricated missing ID 无 mutation，工具卡显示 `Delete document failed` 和原始 not-found warning；Library 只投影 Standalone。SQLite/REST/UI/tool result/LLM wire 一致；SSE 298 frames、messages durable `1..36`、notifications `1..7` 单调、无 gap，LLM 全 200，backend/frontend 无未解释红线。正式证据为 `evidence/tool-090-formal-170748-green.md`，红证据为 `tool-090-formal-170003-red-not-found.md`，账本复审为 `tool-090-ledger-alarm-reaudit.md`；五级 `G1/F2/A5/C4/G2` 已落账，警报复审后 `clean (485 judgments)`。

统一长门禁首轮由 `testend/scenarios/TestContractDocsAtt_DocumentChildrenDuplicateMove` 捕获旧断言：测试仍要求 `/documents?parentId` 一次返回 55 个子节点，而现行实现与 `api.md` 已是默认 50、opaque cursor 分页；未修改生产语义，修正 testend 为 50+5 续页、无重复、顺序和非法 cursor 断言，并补 `/documents/tree` 整树投影断言。定向回归及随后完整 `mise exec -- go test ./...`（testend，`scenarios 319.089s`）、根目录 `make verify`（backend/frontend/docs/demo）、backend `go test ./...`、锚点 10/10、警报和 `git diff --check` 全部通过。第九批已到 **50 / 50**，统一长门禁已绿，当前工作树审计并提交；下一原子前线为 `TOOL-091 list_attachments`。

`TOOL-081 search_activations` 首轮正式观察冻结三条真实红：模型把 `firingCount` 解释成 trigger 历史累计值；把 `payload.manual=true` 误说成 sensor CEL 阈值通过；修复后 hosted model 以字符串发送 `firedOnly`/`limit`，后端类型拒绝并在 App 留下失败活动与 retry。三份红证据分别保留于 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-112217/evidence/tool-081-formal-112217-red-firingcount-semantics.txt`、`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-112933/evidence/tool-081-formal-112933-red-manual-threshold-causality.txt`、`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-113423/evidence/tool-081-formal-113423-red-hosted-scalar-retry.txt`，均不计绿。

stop-and-fix 在 `activations.go` 增加逐行 `firingCount`/`payload.manual` 语义、严格的 exact bool/decimal scalar string 兼容解码；错误形状仍拒绝。同步 trigger 工具测试、API/domain 文档和抽取清册，`go test ./internal/app/tool/trigger ./internal/app/loop` 与 `git diff --check` 通过。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-113825` 使用新二进制、真实 Flutter App、真实受管 gateway、Computer Use、314.906667s 窗口录屏、backend/frontend journal、三路独立 SSE witness 和 LLM tap 重跑。最终 UI 清楚说明 per-activation fan-out、manual bypass 与 false CEL probe；最终请求序列只有 `search_triggers → search_activations`，无失败请求/retry，五路证据一致，LLM chat/proof 响应全 200，SSE durable seq 单调无重复，backend/frontend 无未解释红线。一次 Computer Use wrapper 超时被单独归类为观察器仪器事件，重启 kernel 后重新取得最终帧，不计产品红。五级 `G1/F2/A5/C4/G2` 已落账。

fixture 收口使用独立本地 API 清理 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-114620`：workflow、trigger、function 和 4 条 acceptance conversation 均 DELETE=204，随后 GET=404、列表为空；SQLite 保留软删审计行及 57 条 activation/1 条 firing。台架进程全部收台，无残留。

`TOOL-083 search_firings` 首轮 formal-138 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-115803` 冻结为红：hosted model 把 `limit` 发成字符串，后端拒绝，App 留下失败活动与 retry。formal-139 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-120111` 在 decoder 修复后又暴露模型把 `pattern` 发给 firing inbox，缺失必填 opaque `triggerId`，再次留下失败活动与 retry；两份红证据均保留不计绿。stop-and-fix 增加 exact decimal `limit` 窄兼容，并在 description/schema/validation 明确必须逐字复制 `triggerId`、先 `search_triggers` 再查询，拒绝 name/pattern/placeholder；同步测试、API 文档与抽取清册。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-120402` 使用新二进制真实复验：三条有效查询均成功，结果为 no-status 1、started 1、skipped 0；空集被解释为合法 no-match。最终 screen.mov `141.861667s`，SSE messages durable `1..39`、notifications `1..2` 单调唯一，LLM 全 200，backend/frontend 无未解释红线；同批重复只读调用由 loop 幂等抑制，无重复 repository 访问。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-120402/evidence/tool-083-formal-120402-green.txt`，五级已落账；三条统计警报经红绿证据重审并 ack，复审说明为 `tool-083-ledger-alarm-reaudit.txt`；TOOL-084 已接续完成，下一前线为 `TOOL-085`。

`TOOL-084 search_documents` 先后冻结四条真实红：filesystem `path/pattern` 形状误投到文档搜索；显式分页返回 cursor 但 schema 没有 cursor；assistant 在同一 tool-call 消息中先流出用户可见答案，导致重复 Page 3；混合搜索的 semantic-only recall 引入无关文档。formal 红证据保留于 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-121222/`、`121822/`、`122316/`、`123034/`、`123622/` 的 `evidence/` 下，均不计绿。

stop-and-fix 收紧 `search_documents` 的文档库语义、`query/limit/cursor` 契约和首调用即携带显式 limit 的规则；补充结果 metadata hydration、精确 cursor 续页、tool-call 消息不得带用户答案的 loop 提示，并让文档关键词搜索显式走 lexical-only，保留 RAG/omni 的 hybrid 行为。同步 Go 测试、chat prompt 测试、文档和工具抽取清册；`go test ./internal/app/chat ./internal/app/tool/document ./internal/app/search`、`make -C docs verify`、`git diff --check` 均通过。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-124129` 使用新二进制、真实 Flutter App、真实受管 gateway、Computer Use、连续录屏和五通道台架完成：首调用即 `limit=1`，后续两页使用精确 cursor `eyJoIjoiY2UxNGM5MjM4NzRkIiwibyI6MX0` 与 `eyJoIjoiY2UxNGM5MjM4NzRkIiwibyI6Mn0`，总计 3 条目标文档，无 `Noisy Field Notes` 语义误命中；最终 UI 只有一份答案、无失败卡/retry/重复 Page 3。录屏 `187.523333s`，SSE durable seq `1..48` 连续，LLM wire 与 REST/SQLite 交叉一致，backend/frontend 无未解释错误；fixture 清理为 DELETE=204、GET=404、列表为空。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-124129/evidence/tool-084-formal-124129-green-search-documents.txt`，账本复审为 `tool-084-ledger-alarm-reaudit.txt`，五级 `G1/F2/A5/C4/G2` 已落账。

`TOOL-085 list_documents` 首轮正式空目录路径在 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-130911` 冻结为红：根列表成功后，真实受管网关在旧共享传输的 60 秒响应头预算内没有返回下一步响应，UI 最终显示 `LLM_STREAM_ERROR`，用户拿不到已知的空结果。红证据 `evidence/tool-085-formal-130911-red-empty-folder-header-timeout.md` 保留且不计绿。

stop-and-fix 将共享 LLM 建连响应头预算从 60 秒提高到 120 秒，仅覆盖受管网关冷路由/上游唤醒；`ChatTurnSec`、流式 idle 和 `LLMStreamMaxSec` 保持原边界。补充 `TestNewHTTPClient_SeparatesSetupAndStreamingBudgets`、Chat domain 预算说明，并通过 `go test ./internal/infra/llm`、`git diff --check` 和 docs verify。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-132312` 重新走真实 onboarding、工作区夹具、Flutter App、受管 gateway、Computer Use、窗口录屏、backend/frontend journal、三路独立 SSE witness 和 LLM tap。HTTP 夹具证明 Large Collection 的 120 个直接子节点按 `40/40/40` 三页、游标和 `0..119` 顺序完整返回；真实 App 强制 `limit=40` 后执行根列表与三页 cursor，最终 UI 明示 `complete: true`、`hasMore: false`、总数 120、首尾位置 0/119；独立空目录路径显示 `Listed document · empty`，助手回答 zero documents，无失败卡/retry。LLM wire 与 REST 逐字一致，所有响应 200；SSE 三流均连接，两个 conversation 的 durable seq 分别连续 `1..36`、`37..54`；backend/frontend 错误扫描 clean，录屏 `418.840000s` 可读。正式证据为 `evidence/tool-085-formal-132312-green-list-documents.md`，统计复审为 `tool-085-ledger-alarm-reaudit.md`，五级 `G1/F2/A5/C4/G2` 已落账。

`TOOL-086 read_document` 的首轮真实文档阅读冻结两条产品红：formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-133944` 中前端把 query-required 的空参数误呈为 `Listed document · failed`，且 hosted model 把 filesystem 的 `path/pattern` 形状投给 `search_documents`；formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-134623` 中模型把文档名称/路径误当作 `read_document.id`，产生一次可见 not-found，再搜索重试。两份红证据分别保留于 `evidence/tool-086-formal-133944-red-search-card-and-model-shape.md` 与 `evidence/tool-086-formal-134623-red-opaque-id-guidance.md`，均不计绿。

stop-and-fix 将 `search_documents` 固定为 query-required search channel，空 query 不再伪装成 list；前端补 `entity_search_verb_test.dart`，并同步 Chat 文档。随后将 `read_document` 的 description/schema 明确收紧为必须逐字复制 `search_documents`/`list_documents` 返回的 opaque `doc_` ID，禁止名称或路径，补 Go contract test 与 document domain 文档；`gofmt`、`go test ./internal/app/tool/document`、Flutter entity-search 定向测试和 `git diff --check` 通过。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-135027` 使用新二进制、真实 Flutter App、真实受管 gateway、Computer Use、连续录屏、backend/frontend journal、三路独立 SSE witness 和 LLM tap 重跑。真实线缆严格为 `search_documents(query)` → `search_tools` → `read_document(id=doc_0628e58b2f3d8c1d)`，没有路径误读、失败卡或 retry；最终画面完整展示文档 path、description、tags、全部标题、中文注记和最终句，视觉布局清楚。REST/SQLite 与 tool result 逐字一致，messages durable seq `1..27` 连续，三流均连接，LLM 响应全 200，backend/frontend 错误扫描 clean；仅保留已知稳定的 Computer Use AXTree observer noise，不计产品红。录屏封口 `159.260000s / 2784x1808 / 60fps`，正式证据为 `evidence/tool-086-formal-135027-green-read-document.md`，账本复审为 `tool-086-ledger-alarm-reaudit.md`，五级 `G1/F2/A5/C4/G2` 已落账。

独立 cleanup session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-135432` 通过本地 API 删除本轮 root/child document 与 acceptance conversation，DELETE 均为 204，随后 GET 均为 404，documents/conversations 列表为空；cleanup 台架已收台，正式 green session 与两份 red session 原样保留。

本次 `gap-too-fast` 与 `discovery-collapse` 不是删除或静默放行：五格脚本动作完成后均依据红 session、绿 session、五通道和夹具事实复审并 ack，红证据仍在盘上；`alarms.py check` 最终 clean。第九批推进到 **30 / 50**，下一前线 `TOOL-087 create_document`，未到第 50 格不跑统一长门禁、不提交。

`TOOL-087 create_document` 的 formal-140938、142906、143806、144710 先后冻结为红：分别发现 placeholder ID 进入用户表格、首次 create 漏掉必填 name、先造空根再删除/编辑且同名子文档重复 mutation、以及用户明确提供的 description/tags 被模型静默漏传。四份红证据均保留、不计绿。stop-and-fix 先修 system prompt 与 loop redactor，再把 create_document 的 LLM schema 收紧为每次必传 name/description/content/tags；未提供后三者必须显式传空字符串/空数组，用户值必须同一 canonical call 原样带上；补 Go loop/chat/document 回归、工具抽取清册与 document domain 文档。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-145421` 使用新二进制、全新数据目录、真实 Flutter App、真实受管 gateway、Computer Use、窗口录屏、backend/frontend journal、三路 SSE witness 和 LLM tap 重跑。真实用户目的完成：root `/Release Atlas` 与 child `/Release Atlas/Ship Checklist` 正确写入，root description 为 `A durable release brief`、tags 为 `release/acceptance/notes`，child description 为 `Release gates to run`，child `parentId` 精确指向 root；最终 UI 只显示两项 Created、无 retry/delete/edit/duplicate/failure，路径和嵌套关系清楚。SSE messages/entities/notifications durable 分别为 `1..26`、`1..4`、`1..4` 连续唯一；LLM wire 两次实际 create 均带齐必填字段且全 HTTP 200；REST/SQLite、tool result、UI 一致，backend/frontend 红线扫描 clean，录屏 `282.973333s`。正式证据为 `evidence/tool-087-formal-145421-green-create-document.md`。

台架已收台，所有五通道 journals 与 screen.mov 保留。锚点校准后，`judge.py` 以最终证据写入 `TOOL-087=G1/F2/A5/C4/G2` 五格，中央账本由 465 增至 **470 judgments**；`gap-too-fast` 与 `discovery-collapse` 因批量裁决节奏开启，已按锚点重校、四份真实红证据、最终绿证据和五通道复审后 ack，`alarms.py check` 最终为 `clean (470 judgments)`。第九批推进到 **35 / 50**，下一前线 `TOOL-088 edit_document`，未到 50 格不跑统一长门禁、不提交。

`TOOL-079 delete_trigger` 首轮正式观察先冻结为红：真实 Computer Use 打开并关闭模型 Popover 后，前端 console 出现 105 行 `Failed to update ui::AXTree, error: 149 will not be in the tree and is not the new root`，画面虽未立即破碎，但 macOS 可访问性树已退化，不能把它归类为“无害日志”。stop-and-fix 在 `frontend/lib/core/ui/an_popover.dart` 为常驻 `OverlayPortal` 增加稳定的 `Semantics(container:true, explicitChildNodes:true)` 外边界，补 `an_menu_test.dart` 回归，并同步 chat feature/testend 文档；`flutter test` 14/14、`frontend/make verify` 5174 项、`docs/make verify`、相关 Go 测试和 `git diff --check` 全部通过。

负向 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-073913` 证明真实危险 gate 的 Deny 不执行 mutation：trigger 主行仍在、没有 deleted touchpoint，UI 明确显示拒绝。正向 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-101120` 使用修复后二进制、真实 Flutter App、真实受管 gateway、Computer Use 和连续录屏完成 Allow：gate 文案具体说明主行不可恢复、listener 停止、关系影响与历史保留；UI 只出现一次 `delete_trigger` 和一次 Allow，最终显示 `Deleted trigger ... · deleted`。SQLite/REST 证明主行以 `deleted_at` 保留审计、正常读取不可见、activation/firing 为 0、created/deleted 两条 touchpoint 成对存在；LLM wire 恰有一次 canonical delete call，SSE durable messages `1..13` 连续，backend/frontend 无未解释运行时红线，录屏封口为 `838.035000s / 2784x1808 / 60fps`。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-101120/evidence/tool-079-formal-green-delete-trigger.txt`；五级 `G1/F2/A5/C4/G2` 已落账，当前中央账本为 425 judgments。

`TOOL-080 fire_trigger` 首轮真实暂停负向冻结为红：助手把暂停清除动作错误指向 `edit_trigger`，而该工具不能恢复 paused 状态；红证据保留在 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-103209/evidence/tool-080-red-paused-wrong-resume-guidance.txt`，不计绿。stop-and-fix 在 `FireTrigger` 工具描述、trigger 领域文档和抽取清册中明确 `TRIGGER_PAUSED`、`edit_trigger` 不可 resume、正确路径为 Resume control 或 `POST /api/v1/triggers/{id}:resume`，并补工具描述守卫测试；`go test -count=1 ./internal/app/tool/trigger ./internal/app/loop` 通过。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-104036` 使用新二进制、真实 Flutter App、真实受管 gateway、Computer Use、窗口录像、backend/frontend journal、三路独立 SSE witness 和 LLM tap 重跑：active trigger 的正向请求只调用一次 `fire_trigger`，得到 activation `tra_77b6353d19b9ba70`、固定 payload `{manual:true}`、一个 workflow fan-out 和 flowrun `fr_1dfce2fbff3f084b`；暂停负向只调用一次并展示真实错误与正确 Resume/:resume 指引，无 retry、无 `trigger_workflow`、无新 mutation。SQLite/REST 交叉证明恰有一个 activation、一个 firing 和一个 completed flowrun，负向没有第二组行。screen.mov `223.748333s / 2784x1808 / 60fps`，SSE 三流连接/断开无 gap/error，messages durable 至 54、entities 至 2、notifications 至 4，LLM tap 所有响应 200，backend 只有预期 paused WARN，frontend 无 Flutter/Dart/RenderFlex/Unhandled 红线。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-104036/evidence/tool-080-formal-green-fire-trigger.txt`；fixture 随后通过真实 DELETE=204 清理，GET=404，审计行保留。五级 `G1/F2/A5/C4/G2` 已落账，中央账本由 425 增至 430 judgments。

**第八批统一收口（2026-08-03 11:12）。** 根 `make verify` 的 backend/frontend/docs/demo 四子门禁全部通过；显式 `mise exec -- go test ./...` 全部通过；`git diff --check` 和 `alarms.py check` clean。第一次完整 `make testend` 暴露 `TestContractChat_TouchpointSelfReportAndNameBorrow` 在 120 秒内未 terminal：原因是本批把 `delete_function` 提升为不可绕过 dangerous floor，而旧黑盒用例没有批准两道人闸。没有放宽产品安全标准；修复 testend 用例按真实交互依次 resolve 两个 delete gate，定向场景 6.456s 通过，第二次完整 testend `310.401s` 通过。收台后无 `anselm-testend`/`llama-server` 残留进程；本批只剩工作树审计与选择性提交。

`TOOL-077` 的 formal-132 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-062539` 首轮真实 webhook 路径冻结为红：助手正文将 `/api/v1/webhooks/{triggerId}/{path}` 中的 opaque trigger id 脱敏成不可用的 `the requested item`，用户无法复制可工作的 endpoint。formal-133 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-063222` 的 sensor 路径又暴露 hosted model 把 `config.output` 发成对象 map，后端连续拒绝两次后才成功，失败重试污染了用户回合。formal-134 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-063932` 的 fsnotify 路径冻结为红：模型第一次把 `config` 发成字符串，后端正确拒绝，但 Flutter trigger 专用卡直接把字符串强转为 Map，真实 App 出现 `Something went wrong`，`frontend.log` 连续记录 `type 'String' is not a subtype of type 'Map<dynamic, dynamic>?'`。三份红证据均保留且不计绿。

stop-and-fix 分三处完成：`backend/internal/app/loop/redact.go` 让 webhook endpoint 整行保留可用性语义，同时不把机器 id 放进助手正文；`backend/internal/app/tool/trigger/build.go` 将自然语言 sensor output map 稳定规范化为 CEL object literal，并补 Go 守卫测试和 trigger 领域文档；`frontend/lib/features/chat/ui/tool_card_trigger.dart` 对坏 `config`/`events` 形状做安全降级，失败卡继续显示后端真实错误且不回显敏感参数，并补 Flutter widget 回归。`go test ./internal/app/loop`、`go test ./internal/app/tool/trigger`、trigger 定向 Flutter test、Dart analyze 与 `git diff --check` 均通过。

绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-064904` 使用新二进制、真实 onboarding、真实受管 gateway、Computer Use、窗口录像、backend/frontend journal、三路 SSE witness 和 LLM tap 完成四种 source kind：sensor `acceptance_077_sensor_final`（真实搜索 function 后创建，5s、`payload.total > 10000`、输出 total/healthy）；cron `*/5 * * * *`（next fire 可见）；webhook `acceptance-077-hook-final`（精确可复制 POST endpoint 只在工具卡出现）；fsnotify（绝对路径、create+modify、`*.json`）。所有创建均一次成功，工具卡展开字段与产品目的相符，没有 `Something went wrong` 或 Flutter runtime 红线。

五通道交叉核对：screen.mov `297.055000s`；`rig-check` 运行中确认五通道归属和在线；SSE 共 778 帧，messages durable 尾段 `102..116` 单调，entities/notifications 生命周期帧完整；backend 无 WARN/ERROR/panic/FATAL/tool failure，REST 与 SQLite 交叉证明四条 trigger 的 config、outputs、`paused=false`、`listening=false`；frontend 无 FlutterError/未处理异常/渲染错误；LLM bodies 全部经过透明 tap，四条自然语言路径和 sensor 搜索→创建链完整。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-064904/evidence/tool-077-formal-135-green-four-trigger-kinds.txt`。五级 `G1/F2/A5/C4/G2` 已写入 COVERAGE，`gap-too-fast` 因五格批量写账被复审并 ack，最终 `alarms.py check` clean。

`TOOL-078 edit_trigger` 的 formal-136 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-065903` 首轮真实 App 冻结为红：托管模型把 `create_trigger.config` 发成 JSON 字符串，后端拒绝并留下失败活动卡，随后 retry 才创建成功；这不是可接受的“模型自己修好了”，因为用户已经看见错误历史。前线冻结后在 `backend/internal/app/tool/trigger/build.go` 增加 create/edit 对称的严格对象解码：原生 object 与精确 JSON 编码 object string 均接受，数组、标量、普通文本、坏 JSON 均拒绝；edit 同时复用 sensor output map→CEL 稳定归一化。补充 trigger Go 回归测试、工具描述、领域文档和清册同步。

formal-137 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-070531` 使用新二进制、真实 onboarding、真实受管 gateway、Computer Use、窗口录像、backend/frontend journal、三路 SSE witness 和 LLM tap 重跑：先创建 `acceptance_078_cron`（`*/10 * * * *`），再一次 edit 改名、描述和表达式到 `*/15`，最后真实验证兼容说明路径并更新到 `*/20`。最终 SQLite 只有一条 trigger，`acceptance_078_cron_renamed`、`Edit acceptance trigger`、`{"expression":"*/20 * * * *"}`、`paused=0` 完整一致；画面只有成功 Created/Edited 活动，没有失败卡、retry 或 Settling 残留，工具卡、活动岛和助手正文一致。模型最后一次虽在 reasoning 中声称要发字符串，LLM wire 仍实际发 native object，这是 schema 约束下的模型编码观察，不冒充字符串路径成功；formal-136 的真实红证据和新 decoder 单测仍保留。

五通道交叉核对：screen.mov `222.758333s` 且 ffprobe 可读；`rig-check` 在运行中确认五通道归属；SSE 共 432 帧，notifications durable `1..2`、messages durable `1..59` 单调唯一，三流均有 `tap=connect`；backend 无 WARN/ERROR/panic/FATAL，health/最终 REST GET 全 200；frontend 无 FlutterError/DartError/RenderFlex/Unhandled/SEVERE/Exception/Lost connection；LLM tap 36 条 journal、10 个 request body、24 个有状态响应全 200。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-070531/evidence/tool-078-formal-137-green-edit-trigger.txt`。五级 `G1/F2/A5/C4/G2` 已写入 COVERAGE，批量写账触发的 `gap-too-fast` 已以本 session 完整复核说明 ack，最终 `alarms.py check` clean。

formal-130 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-060503` 首轮真实 Flutter App + 受管网关 + Computer Use 暴露产品红点：`get_trigger` 成功后，助手正文把真实 `trg_...` 内部 ID 复述给用户。红证据 `tool-076-formal-130-red-trigger-id-leak.txt` 保留且未计绿。根因是 `backend/internal/app/loop/redact.go` 的 opaque ID 前缀族只覆盖历史 `tr_`，没有覆盖当前 trigger 的 `trg_`。

stop-and-fix 在所有实体 ID 相关的直接/流式 redaction 族加入 `trg`，并补 `redact_test.go` 的直接路径与 provider chunk 拆分回归；`docs/references/backend/domains/chat.md` 同步当前前缀契约。`mise exec -- go test -count=1 ./internal/app/loop` 通过，rig-up 重新编译新二进制后才重跑，未复用红 binary。

绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-061313` 使用真实 onboarding 创建 `TOOL-076 Trigger Observatory Fixed`，真实受管 gateway、Computer Use、窗口录屏、backend/frontend journal、三路 SSE witness 和 LLM tap 全部接线。fixture 为无监听 cron（`refCount=0/listening=false`）和 active workflow 监听的 webhook（配置路径 `acceptance-076-fixed`、`refCount=1/listening=true`）。三条真实 App 路径均只调用一次 `get_trigger`：live webhook 正确显示 webhook/path/paused=false/refCount=1/listener=true；pause 后正确显示 paused=true/refCount=1/listener=false；全零不存在 ID 路径诚实显示 not found 且不 retry。三条助手正文均不含 `trg_`，精确值只保留在相邻 tool card/审计线缆。

五通道交叉核对：录屏封口 `361.345000s`；messages durable `1..44`、notifications `1..8` 连续无 gap；entities 已连接；LLM challenge/install/models 与 6 个 chat completion 响应全 HTTP 200，业务 tool call 恰为 3 次 `get_trigger`；backend 无 panic/FATAL/未解释错误，唯一 WARN 是刻意不存在 ID 的 `trigger not found`；frontend 无 `Unhandled exception`、`FlutterError`、`Lost connection` 或断言红线，启动器既有 `open returned 1` 已单独标注；assistant durable close 扫描无 `trg_`/其它实体 ID 泄露。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-061313/evidence/tool-076-formal-131-green-trigger-get.txt`，五级 `G1/F2/A5/C4/G2` 已落账；本次 gap-too-fast/discovery-collapse 因同一真实证据包逐级写账而开启，均带复核说明 ack，最终 `alarms.py check` 为 clean。

（TOOL-074 的完整当前记录见 `LOG.md`；本节上方已整体重述最新前线。）

（旧批次状态，当前值以上方整体重述为准。）

| 交付物 | 当前真相 |
|---|---|
| 五通道 conductor | ✅ `rig-{up,check,down}.sh` 亲自托管 App、Flutter console、录像、后端、动态全 workspace SSE tap、LLM tap；D1 端口归属、受管 baseURL 接线、进程身份、journal 与三流连接持续自检。任一通道禁用时不得报验收绿 |
| 帧与 Computer Use | ✅ 屏幕权限、真实交互、MOV 封口、ffmpeg/ffprobe 全通；Computer Use 负责操作与现场截图，连续录像由 conductor 落盘 |
| SSE witness | ✅ `cmd/ssetap` 支持固定 workspace 与动态全 workspace；durable cursor 逐流续传，每帧带 workspace/stream/接收时戳 |
| LLM witness | ✅ `cmd/llmtap` 请求体与响应体逐调用留底；透明核同时保 SSE flush 与 WebSocket upgrade；device-proof 仍签真实受众，不放宽证明消费边界 |
| 测量脚本箱 | ✅ `cmd/measure` 提供 diff/regions/contrast/latency/compare；diff 与 latency 支持 ROI，compare 对源图与视频首帧先做确定性栅格归一并以 `changedFrac` 硬拒大幅构图漂移；合成已知几何守卫绿 |
| CODEX | ✅ [WRK-088](CODEX.md) 八域 33 条法，裁决只能援引法条或测量值，法不够先立法 |
| COVERAGE | ✅ [WRK-089](COVERAGE.md) 已对齐新 main：工具 124 / 端点 257 / 面 114 / 边 353，共 **848 行 × 5 级 = 4240 格**；它是一期覆盖真相源 |
| JOURNEYS | ✅ [WRK-090](JOURNEYS.md) 现有 47 条只作一期路线；400+ 与逐行认领按用户 P12 推迟二期，不阻塞一期按 COVERAGE 驻停清扫 |
| 账本 gate | ✅ `judge.py` 校验证据文件、CODEX 法条、L2 六件五通道证据、三流连接、可读 MOV、开放警报和四小时锚点凭证；任一缺失物理拒收 pass |
| 锚点自校 | ✅ [WRK-091](ANCHORS.md) 冻结 10 个正反锚点；无答案答卷通过才签发绑定题集哈希的四小时凭证，题集变化或凭证过期自动锁 gate |
| 统计警报 | ✅ `alarms.py` 监控裁决过快、速率暴冲、发现率塌方；ack 必须写复审结论，且在出现新裁决前不会拿同一批历史原地复活；新证据到达后重新评估 |
| 操作手册 | ✅ `testend/rig/README.md` 自足描述起、检、停、校准、测量、裁决和警报，任何 agent 无需旧对话即可使用 |
| 产品主循环 | ✅ 已从第一条未裁决格启动；前置真实切片持续覆盖 onboarding、chat、composer、toc、log drawer、Read、Write、Edit、LS、Glob、Grep、Bash、BashOutput、KillShell、ask_user、todo_write、todo_read 以及 function 全生命周期。所有产品语义、错误态、数据真相和视觉问题均按 stop-and-fix 冻结、修复并真实重跑；当前已完成 control、approval、workflow search/get/create/edit/revert/delete、capability-check、trigger/stage/activate/deactivate/kill、flowrun 查询/重放、approval inbox/decision、`search_triggers`、`get_trigger`、`create_trigger` 四种 source kind、`edit_trigger`、`delete_trigger`、`fire_trigger`、`search_activations`、`get_activation`、`search_firings`、`search_documents`、`list_documents`、`read_document`、`create_document`、`edit_document`、`move_document`、`delete_document`、`list_attachments`、`read_attachment` 与 `inspect_media`。TOOL-069 至 TOOL-098 的已知产品缺陷均有红证据、修复、守卫测试和真实复验；当前中央账本 **525 judgments**，锚点有效、警报 clean；第十批 **40 / 50**，原子前线 `TOOL-099 install_mcp_server` 仍未绿，静态 floor 修复后的 Deny formal 已封存，未到 50 格不跑统一长门禁、不提交。 |

**当前执行状态（2026-08-02 00:08）。** `TOOL-050 revert_control` 正式 session 为 `/private/tmp/anselm-rig-formal-110/sessions/20260802-000259`。formal-109 首轮红证据确认 hosted model 首次发送 `version:"1"`，后端拒绝并在 App 留下失败 activity，随后模型 retry 成功；前线冻结后在 control 工具边界增加 exact decimal integer string 解码，公开 schema 仍保持 integer，浮点/布尔/数组/坏字符串继续拒绝，补 control 测试、工具描述和领域文档，定向 Go 测试通过。formal-110 正向真实只执行一次 `revert_control`，wire 的 stringified version 被接受，active pointer 从 v2 移到 v1 `ctlv_c05fb8b13fd7b636`，UI 只有一张成功 `Reverted control … · ↩ v1` activity，正文明确 v2 仍在 history；负向只执行一次 version 999，返回 `control logic version not found`，UI 只有一张失败卡且明确 active v1 unchanged，无 retry/新版本。screen.mov `147.631667s / 2784x1808 / 60fps`，SSE messages `1..29`、notifications `1..7` 连续，entities 已连接，LLM chat completion 全 200，backend 只有刻意负路径 WARN，frontend 无 runtime 红线；fixture/conversation DELETE=204 后 GET=404，台架已收台。五级 `G1/F2/A5/C4/G2` 已落账，中央 300 judgments，锚点有效，警报最终 clean；第六批 4 / 50，未到 50 格不跑统一长门禁、不提交，下一前线 `TOOL-051`。

**当前执行状态（2026-08-01 23:51）。** `TOOL-049 edit_control` 正式 session 为 `/private/tmp/anselm-rig-formal-108/sessions/20260801-234249`。formal-107 红证据确认同一用户意图被执行成缺 reason 的 v2 与带 reason 的 v3；前线冻结后将非空 `changeReason` 设为 AI schema 必填，并在 mutation 之前以 `CONTROL_CHANGE_REASON_REQUIRED` 拒绝缺失或空白值，补 control 测试与 error-code/领域文档，定向 `go test ./internal/app/tool/control ./internal/app/loop` 通过。formal-108 正向真实只执行一次 `edit_control`，wire 的 stringified branches 使用正确 `port`，reason 为 `acceptance TOOL-049 final fix`，后端创建 v2 `ctlv_34cbcddfc2f6d22a`，UI 只有一个成功 activity 和完整三分支表；负向只执行一次缺 reason 调用，后端返回 `input validation failed: changeReason is required`，UI 显示失败原因和 `Draft unsaved · truth is still the last version`，无 retry，REST active version 仍为 v2、没有 v3。screen.mov `189.023333s / 2784x1808 / 60fps`，SSE messages `1..29`、entities `7..8`、notifications `16..21` 连续，LLM chat completion 全 200，backend 只有刻意负路径 WARN，frontend 无 Flutter runtime 红线；fixture 与 conversation DELETE=204 后 GET=404，台架已收台。五级 `G1/F2/A5/C4/G2` 已落账，中央 295 judgments，锚点有效，警报最终 clean；第六批 3 / 50，未到 50 格不跑统一长门禁、不提交，下一前线 `TOOL-050`。

**当前执行状态（2026-08-01 23:30）。** `TOOL-048 create_control` 正式 session 为 `/private/tmp/anselm-rig-formal-106/sessions/20260801-232207`。formal-104 的托管模型字符串化 branches 和 formal-105 的 `name`/重复调用问题均先冻结为红并保留证据；修复后定向 `go test ./internal/app/tool/control ./internal/app/loop` 通过。formal-106 真实 App 正向只创建一个 `acceptance_control_fixture_106`，LLM wire 中 `branches` 是 JSON 字符串但 branch 使用正确 `port`，backend decoder 接受后返回 `ctl_a385d713822f5367`、active version `ctlv_fe1349dcbb94cd67`，UI 展示完整有序 `pass/review` 表且无红行；负向同一会话只尝试重复名称一次，返回 `control logic name already exists`，UI 明确显示未创建与错误解释，无 retry。录屏、五通道 journal、正负终帧和证据文件 `evidence/tool-048-formal-106-green.txt` 已封存；screen.mov `230.008333s / 2784x1808 / 60fps`，messages `1..29`、entities `7..8`、notifications `16..20` 连续，LLM chat completion request/response 全 200，backend 仅刻意负向 WARN，frontend 无运行时红线；fixture 与 conversation DELETE=204 后 GET=404，台架已收台。五级 `G1/F2/A5/C4/G2` 已落账，中央 290 judgments，锚点有效，警报最终 clean；第六批已从 1 / 50 推进为 2 / 50，未到 50 格不跑统一长门禁、不提交，下一前线 `TOOL-049`。

**当前执行状态（2026-08-01 18:16）。** `TOOL-036 search_agent` 已在正式 session `/private/tmp/anselm-rig-formal-20260801-78/sessions/20260801-181026` 完成正向名称命中、空 query 列全库和 identifier-shaped no-match 三条真实 App 路径；五通道证据、三张终帧和 fixture/对话清理事实均保留。该格尚未裁决，因为修复触及共享搜索语义原语，`search_function`、`search_handler` 等旧绿格必须先复验。Goal API 仍为 `blocked` 且不提供恢复操作；不创建重复 Goal、不谎报完成，盘上 `LOOP.md` 仍为 `active`，当前批次 **15 / 50**，下一动作是同类搜索复验。

**当前执行状态（2026-08-01 18:30）。** `TOOL-036 search_agent` 已完成五级裁决 `G1/F2/A5/C4/G2`；共享 `ContentSearch` 影响的 `TOOL-014 search_function`、`TOOL-024 search_handler` 已由 formal session 79 对命中、空 query、identifier no-match 六条路径复验并恢复五级绿。formal-78/79 的五通道、录屏和终帧保留，三条统计警报复审并 ack 后为 `clean (230 judgments)`。本批新完成单格为 **16 / 50**（旧格复验不重复计数），未到 50 格不跑统一长门禁、不提交，下一前线为 `TOOL-037 get_agent`；Goal API 仍为不可恢复的 `blocked`，盘上 `LOOP.md` 保持 `active`，不创建重复 Goal、不谎报完成。

**当前执行状态（2026-08-01 18:40）。** `TOOL-037 get_agent` 已完成五级裁决 `G1/F2/A5/C4/G2`；formal-80 的严格正向最终字段表完整，负向不存在 ID 单次失败且无 retry，前置 setup 400、Bash 污染和中途未完成截图均不进入绿证据。五通道、视觉终帧、fixture/对话清理回执保留，警报复审并 ack 后为 `clean (235 judgments)`。本批新完成单格为 **17 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线为 `TOOL-038 create_agent`；Goal API 仍为不可恢复的 `blocked`，盘上 `LOOP.md` 保持 `active`，不创建重复 Goal、不谎报完成。

**当前执行状态（2026-08-01 19:10）。** `TOOL-038 create_agent` 已完成五级裁决 `G1/F2/A5/C4/G2`。formal-81 暴露首发 scoped SSE 竞态导致重复 user bubble，已修复普通 send 的 REST head reconcile，并通过 Flutter 37 项定向测试；formal-82 暴露显式 agent description 被托管模型漏发，已收紧工具契约、schema 描述、后端守卫测试和 agent 文档。formal-83 修复后正向 exact metadata 贯穿 LLM wire、entities、REST 和 UI，负向重复名只执行一次并显示可解释失败，无 retry/副作用；formal-84 无 Computer Use 基线确认 frontend 无 Flutter/Dart/RenderFlex/Unhandled 红线，formal-83 动态 AXTree 行归类为观察器噪声。五通道、录屏、终帧、fixture/对话 DELETE→GET 404 和 SQLite `deleted_at` 均保留，警报复审并 ack 后 `clean (240 judgments)`。本批新完成单格为 **18 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线为 `TOOL-039 edit_agent`；Goal API 旧实例仍为不可恢复的 `blocked`，盘上 `LOOP.md` 保持 `active`，不创建重复 Goal。

**当前执行状态（2026-08-01 19:22）。** `TOOL-039 edit_agent` 已完成五级裁决 `G1/F2/A5/C4/G2`。前置冻结并修正 `get_agent` stale description、agent service 注释与领域文档，明确 LLM `edit_agent` partial merge、HTTP `:edit` full snapshot；定向 Go 测试与 docs verify 通过。formal-85 真实 onboarding + managed gateway + Computer Use 正向只改 agent prompt，UI 显示 v1→v2、version ID 和 preserved-fields 说明，REST activeVersion、mount-health `allHealthy=true`、skill/document/function relation 与 SQLite 只有 v1/v2 一致；负向不存在 ID 只执行一次，显示 `agent not found` 与 `Draft unsaved · truth is still the last version`，无 retry。LLM body 的历史 tool_calls 已经逐 body 复核为上下文回放，不是重复执行；backend 仅预期 not-found WARN。五通道录屏 `290.713333s`，LLM 7/9 全 200，SSE durable `messages 1..36`、`entities 1..4`、`notifications 1..15` 无 gap；frontend 除 Computer Use 诱发 AXTree bridge 噪声外无 Flutter/Dart/RenderFlex/Unhandled/Exception，formal-84 无 CU 基线已完成对照。所有 fixture 和 conversation DELETE=204→GET=404，进程已收台，警报复审并 ack 后 `clean (245 judgments)`。本批新完成单格为 **19 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线 `TOOL-040 revert_agent`；Goal API 旧实例仍为不可恢复的 `blocked`，盘上 `LOOP.md` 保持 `active`，不创建重复 Goal。

**Day 0 已完成。** 主循环配置为从 COVERAGE 第一条未裁决格开始，遵守“台架先绿 → 锚点解锁 → 旅程走线
**当前状态：** 第九批 `TOOL-081..090` 已完成 50/50、统一长门禁全绿并提交 `32b33499`；下一前线为 `TOOL-091 list_attachments`。
→ 到站清完整列 → 发现即冻结前线并修复 → 同类横扫 → judge 落账”的固定节拍；当前已完成
`EDGE-325`、`EDGE-326`、`SURF-003`、`SURF-010`、`SURF-011`、`SURF-012`、`SURF-013`、`SURF-014`、`TOOL-001`、`TOOL-002`、`TOOL-003`、`TOOL-004`、`TOOL-005`、`TOOL-006`、`TOOL-007`、`TOOL-008`、`TOOL-009`、`TOOL-010`、`TOOL-011`、`TOOL-012`、`TOOL-013`、`TOOL-014`、`TOOL-015`、`TOOL-016`、`TOOL-017`、`TOOL-018`、`TOOL-019`、`TOOL-020`、`TOOL-021`、`TOOL-022`、`TOOL-023`、`TOOL-024`、`TOOL-025`、`TOOL-026`、`TOOL-027`、`TOOL-028`、`TOOL-029`、`TOOL-030`、`TOOL-031`、`TOOL-032`、`TOOL-033`、`TOOL-034`、`TOOL-035`、`TOOL-036`、`TOOL-037`、`TOOL-038`、`TOOL-039`、`TOOL-040`、`TOOL-041`、`TOOL-042` 的五级裁决。首批 50/50 与第二批 50/50 均完成统一 `alarms.py check`、完整 testend、修复场景回归、工作树审计并提交；第三批已完成 **50 / 50**，`TOOL-022 search_function_executions` 已由真实 App + 五通道证据收尾，警报复审后 clean(150 judgments)，统一长门禁和最终审计均已通过并提交 `eb1ee050`；第四批已完成 **50 / 50**，`TOOL-023` 至 `TOOL-032` 均已过五级裁决，最新警报复审后 clean(200 judgments)，统一长门禁、完整 testend、修复场景回归、锚点/警报/进程/fixture/diff 审计均已通过；第五批当前 **30 / 50**，`TOOL-033` 至 `TOOL-042` 均已由正式五通道 session 收尾，最新警报复审后中央账本 clean(260 judgments)，formal-81/82、TOOL-039、TOOL-040、TOOL-041 和 TOOL-042 前置产品/契约问题均已修复并留存红证据，未到 50 格不运行统一长门禁，下一前线为 `TOOL-043`。

**当前执行状态（2026-08-01 21:13）。** `TOOL-043 invoke_agent` 的 formal-93 首轮红证据已保留：不存在 agent ID 的执行失败被右侧 Activity 错穿成实体编辑专用的 `Draft unsaved · truth is still the last version`，故冻结前线而未计绿。修复新增 `AnHonesty.failedRun`，按 create/edit/run 三类分流失败真相，补双语文案、W4 守卫测试和 frontend 文档；定向 `stages_w4_test.dart` 13/13 全绿。formal-94 以新二进制、真实 onboarding、真实受管网关和 Computer Use 完成正向 `search_agent → invoke_agent` 与负向不存在 ID 单次 invoke：正向结构化结果为 answer=4、confidence=1，负向只显示 `agent not found`，无 executionId、无 retry、无其它写操作；Activity 显示 `Run failed · inspect the error below`，不再出现 draft/version 误导。session `/private/tmp/anselm-rig-formal-94/sessions/20260801-210343` 的 screen.mov 为 `236.766667s / 2784x1808 / 60fps`；messages/entities/notifications durable 分别 `1..39`、`1..4`、`1..3`，LLM 20/20 状态响应全 200，backend 只有刻意负路径 WARN，frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception 红线；REST、SQLite、UI、SSE 和 LLM wire 交叉一致。agent、conversation 均 DELETE=204→GET=404，成功 execution 保留，台架已收台无残留进程。五级裁决 `TOOL-043=G1/F2/A5/C4/G2` 已落账，锚点 10/10 通过，警报复审并 ack 后中央账本 clean(265 judgments)。Goal 与盘上 loop 均为 active；第五批 **35 / 50**，下一原子前线为 `TOOL-044 search_agent_executions`。

**当前执行状态（2026-08-01 21:40）。** `TOOL-044 search_agent_executions` 的 formal-95 首轮红证据已保留：Computer Use 输入污染导致越界生命周期操作；clean retry 又暴露列表携带完整 `transcript`、模型改写 opaque cursor 导致分页重叠。前线冻结后，列表裁剪 transcript，工具 description/schema 强化 cursor byte-for-byte 原样续传，补 store/tool 回归测试并同步 agent/API/extract 文档。formal-96 以新二进制真实重跑正向 2+1 无重叠分页与负向 `status=failed` 空结果，五通道、REST、SQLite、UI、SSE、LLM wire、backend/frontend journal 一致；录屏 `414.928333s / 2784x1808 / 60fps`，SSE durable `notifications 1..5`、`entities 1..12`、`messages 1..49` 连续，LLM 28 个状态响应全 200，fixture agent/conversation DELETE=204，台架已收台。五级裁决 `TOOL-044=G1/F2/A5/C4/G2` 已落账，锚点 10/10 通过，警报复审并 ack 后中央 clean(270 judgments)。Goal 与盘上 `LOOP.md` 均为 `active`；第五批 **40 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线为 `TOOL-045 get_agent_execution`。

**当前执行状态（2026-08-01 21:56）。** `TOOL-045 get_agent_execution` 的 formal-97 以新二进制、真实 onboarding、真实受管网关和 Computer Use 完成正向单条 detail 与负向不存在 ID。正向真实返回并在 App 报告完整顶层审计字段、input/output 和两条 transcript（reasoning→text）；对照 raw REST/LLM wire 后确认 off-chat loop block 的空 id/message/seq/status/零值时间是既定语义，前端 hydration 会为缺 id 生成稳定 `hblk_*`，不是字段被吞。负向只调用一次并显示 `agent execution not found`，无 retry/其它工具/写操作。screen.mov `286.645000s / 2784x1808 / 60fps`，SSE durable `notifications 1..3`、`entities 1..4`、`messages 1..28` 连续，LLM 18 个状态响应全 200，backend 仅预期 not-found WARN，frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception 红线；fixture agent/conversation DELETE=204，台架已收台。五级裁决 `TOOL-045=G1/F2/A5/C4/G2` 已落账，锚点 10/10 通过，警报复审并 ack 后中央 clean(275 judgments)。Goal 与盘上 `LOOP.md` 均为 `active`；第五批 **45 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线为 `TOOL-046 search_control`。

## 当前前线整体重述（2026-08-27 · EDGE-333 真实设置复验）

上一轮 `EDGE-345` 的真实 App 复验发现两个产品问题：用户要求用上传音频登记音色时，模型先调用
`inspect_media` 并被“当前不能转录”卡住；在已有历史成功结果的对话里，模型还曾把新请求直接回答成“已经完成”，
没有验证本次动作。两处都已冻结、修复并补测试：`prompt.go` 增加音频“登记/克隆=文件操作、直接走
`enroll_voice`；转录/理解才走 `inspect_media`”的分流，以及“新变更不能凭历史成功冒充本次完成”的真相规则；
`enroll.go` 的工具描述与 `stream-llm.md` 同步加强同一契约。

修复后的真实 App session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-203732`：全新对话重新上传 WAV 后，用户只说
“Please register this uploaded audio as a voice named acceptance-voice”，LLM wire 只选择一次 `enroll_voice`，
没有 `inspect_media`；App 显示 `dangerous` 确认，五通道 `rig-check` 前后通过，录屏 `189.416667s / 2784x1808 /
60fps`，messages durable `1..23`、notifications durable `1..2`，backend/frontend journal 无未解释应用红线。
测试随后点击“拒绝”，没有新增不可逆的受管音色。正式证据为
`testend/rig/formal-evidence/EDGE-345-voice-intent-routing-fix-20260827.md`，会话证据在该 session 的 `evidence/`
目录；上一轮红证据与已有真实合成成功证据均保留。

同一修复还在含有历史成功记录的旧对话中复验：用户再次要求登记同名音色时，模型重新发起 `enroll_voice` 并
等待确认，没有凭历史结果报本次完成；拒绝后显示“操作已取消”。session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-204342`，证据为
`testend/rig/formal-evidence/EDGE-345-history-truth-fix-20260827.md`。

随后完成下一条安全、可逆的 `EDGE-333` 真实 App 复验。session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-204754`，真实 App 在「存储与日志」面板中显示
服务端自持的 `90 天` 默认值；Computer Use 实际完成 `90 天 → 30 天 → 90 天`，每次均即时回显，恢复后出现
「保留策略已更新」。backend journal 记录初始 GET 以及两次 `PATCH 200 + GET 200`，最终 REST 为
`runRetentionDays=90`；SQLite `PRAGMA integrity_check=ok`，数据目录没有客户端 `settings.json`。录屏
`239.690000s / 2784x1808 / 60fps`，`rig-check` 前后和 `rig-down` 均通过，frontend 无 Flutter/Dart/RenderFlex/
Unhandled/Exception 应用红线，三路 SSE 和 llmtap wiring 健康。正式证据为
`testend/rig/formal-evidence/EDGE-333-retention-real-app-20260827.md`，会话证据在该 session 的 `evidence/`
目录；警报复审记录为 `testend/rig/formal-evidence/EDGE-333-ledger-alarm-reaudit.md`。

本次只把 `EDGE-333` 的 `L2/F1` 真实真相层写绿，清册状态由 `✓~~~~` 变为 `✓✓~~~`；没有把同一设置截图
冒充时延、美学或新用户发现性证据。账本先因锚点超过 4 小时拒绝写入，重新完成 10/10 锚点校准后才入账；
写入触发的 `gap-too-fast` 与 `discovery-collapse` 已按独立 session 证据逐条复审并 ack，未改阈值、算法、法典
或锚点，`alarms.py check` 最终为 `clean (1953 live judgments; 2300 baseline judgments excluded)`。
当前 formal journal 为 `4253`（2300 baseline + 1953 live），`gen_coverage.py --check` 为
`848 rows / 848 carried judgments / 0 tombstones`；新批次为 `2/50`，未满 50 不运行统一长门禁、不提交。
`COVERAGE` 没有 `·/✗` 未决格只代表机械账本没有空白，不代表全产品验收完成；后续继续逐项复验适用的
`✓~~~~` 行。P12 的 400+ JOURNEYS 仍按用户裁定推迟二期。

在 `EDGE-333` 之后顺序复验 `EDGE-334 testend Kill9 崩溃半场`：真实 harness 的
`TestContractChat_CrashSweepOrphans`、`TestWorkflow_CrashRecovery`、
`TestAttachmentPreparation_CrashRequeuesInterruptedWork`、`TestP4bRail_GeneratingNoResidueAfterCrash` 四项
均通过，总耗时约 `64.046s`；实际观察到 orphan sweep、workflow recovery、附件 interrupted work requeue 和
generating 无残留。正式证据为 `testend/rig/formal-evidence/EDGE-334-kill9-crash-half-20260827.md`。
该条已有 `L1/F5` 判决，本次只是基础设施复验，L2-L5 仍没有真实 App 证据，未新增账本单元；当前批次仍为
`2/50`，不提前运行统一长门禁、不提交。

随后复验 `EDGE-335 testend 进程组泄漏自检`：完整 `make testend` 通过，
`testend/scenarios` 用时 `292.290s`；测试期间的 backend、sandbox、`llama-server` 并发进程全部由 harness
收容，结束后独立进程审计无 `testend-bin`、`anselm-server`、`llama-server` 残留，也无遗留 pid 文件。正式
证据为 `testend/rig/formal-evidence/EDGE-335-process-group-leak-check-20260827.md`。该条已有 `L1/F3`，
本次是基础设施复验，L2-L5 仍不具备真实 App 产品证据，不新增账本单元；批次仍为 `2/50`。

在这两条基础设施复验后发现 `EDGE-336 testend 超时/被杀由下一轮收` 只有实现和历史全量运行证据，缺少针对
PID 活性的专门回归锁。已补 `testend/harness/scratch_test.go` 的
`TestReapStaleScratchUsesPIDLiveness`，真实通过 `go test ./harness`：死亡 PID 目录会被回收，非数字目录和
当前进程目录保留；没有触碰其他进程。该改动同步写回既有证据
`testend/rig/formal-evidence/EDGE-336-testend-dead-round-reaping-20260826.md`，不新增账本单元，批次仍为
`2/50`。

同一轮还补强 `EDGE-337 testend 缓存剥 pid` 的回归锁：`TestPrunePIDFilesKeepsRuntimeFilesOnly` 与活性回收
测试共同通过 `go test ./harness -count=1`，确认共享 runtime cache 会删除 `*.pid` 运行态记录、保留普通
runtime 文件，避免未来 OS PID 复用造成误杀。结果同步到
`testend/rig/formal-evidence/EDGE-337-cache-pid-stripping-20260826.md`；该条已有 `L1/F3`，L2-L5 仍不适用
于没有 App 产品场景的 testend 基础设施路径，不新增账本单元，批次仍为 `2/50`。

回到产品面复验 `EDGE-341 未验证供应商诚实徽标`：真实 App 在 Models & keys → Add key 展示供应商目录
`0-100 of 213 items`，卡片同时呈现供应商名、模型数量和 `未验证` 徽标；打开 `302.AI` 表单检查后取消，
没有输入、上传或保存凭证。源码确认徽标带 `unverifiedHint` tooltip，明确说明条目来自 models.dev 且尚未由
Anselm 试过。session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-210515`，录屏
`139.223333s`，五通道 `rig-check` 前后通过，backend/frontend/SSE/llmtap 无应用红线，进程已收台；正式
证据为 `testend/rig/formal-evidence/EDGE-341-unverified-provider-real-app-20260827.md`。因本轮没有独立
hover/tooltip 观测，也不是全新 onboarding，不把它冒充 L4/L5 新判决；既有 `L1:E4` 保持，批次仍为 `2/50`。

## 当前前线整体重述（2026-08-29 · EDGE-317 真实 App L2 收口）

`EDGE-317 选区跨块缝隙` 已完成真实产品路径验收。正式 clean session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-235053`，隔离 workspace 为
`ws_89eb5841c48ec008`，fixture document 为 `doc_763d224956e3eecd`。真实 Flutter App 从 Library
打开三段文档，离开到另一类资源后重新打开，再以真实焦点和 `Shift+Down` 跨越三个块进行选区；最终画面
显示等高、连续的蓝色选区，块间 padding 没有白缝，末行随真实文本宽度收束，工具条稳定出现。

首轮真实观察确实发现独立选区 overlay 在块间显示白缝，已冻结为红并保留证据；stop-and-fix 延后选区层在
persistent frame callback 中的重建并合并拖动更新，同时将 selection 色在独立 overlay surface 上预混为
可见的表面色。修复后二进制重新走离开/重开和跨块选区，截图与像素采样均确认桥接生效；focused selection
与 presenter tests 全部通过。正式证据为
`testend/rig/formal-evidence/EDGE-317-selection-block-gaps-real-app-20260828.md`，红绿帧和五通道
journal 保留在该 session 的 `evidence/`。

五通道封口：录屏=`424.336667s`；`rig-check` 五通道通过，backend/frontend 无应用级红线；SSE witness
三流均连接并记录预期 `notifications seq=16`，LLM witness 的 managed proof/install/models 全 `200`，
本确定性 Library 路径没有 completion，不虚构；文档 GET `200` 的正文、路径、大小与 UI/夹具逐字一致，
`rig-down` 无残留。`judge.py` 以 `C1` 写入 `L2 ✓`，清册由 `✓~~~~` 提升为 `✓✓~~~`，L3-L5 仍为
`na`；anchors=`10/10`。写账打开的 `discovery-collapse` 已以独立复审记录
`testend/rig/formal-evidence/EDGE-317-ledger-alarm-reaudit-20260829.md` 复核并 ack，最终
`alarms.py check`=`clean (1999 live judgments; 2300 baseline judgments excluded)`。

当前批次由 `37/50` 推进至 `38/50`，未满 50 格不跑统一长门禁、不提交；下一原子继续从尚未具备正式
L2 的 `~` 格选择。P12 的 400+ Journey 扩写仍按用户裁定推迟二期，一期以 COVERAGE 为覆盖真相源。

## 当前前线整体重述（2026-08-29 · EDGE-319 大纲下标不变式真实 App L2 收口）

`EDGE-319 大纲下标不变式` 已完成真实产品路径验收。正式 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-002006`，真实 App 夹具混合正文 h1-h6、围栏内
`#`/`##`、引用内 `#` 和深层标题后的 h3。右侧 Outline 显示恰好 8 项，与编辑器 `headingNodeIds` 的文档序
一致；围栏/引用伪标题没有混入，h4-h6 保留且没有造成后续下标漂移，8 个目录入口逐个点击完成。

五通道 session 已由 `rig-check`/`rig-down` 封口，backend/frontend 无应用红线，SSE 三流 durable seq 单调，LLM
challenge/install/models 全为 `200`，REST 夹具与画面一致。正式证据为
`testend/rig/formal-evidence/EDGE-319-outline-heading-invariant-real-app-20260829.md`，`judge.py` 以 `F1`
写入 `L2 ✓`，清册由 `✓~~~~` 提升为 `✓✓~~~`，L3-L5 保持 `na`；anchors=`10/10`。写账打开的
`discovery-collapse` 已以独立复审记录 `testend/rig/formal-evidence/EDGE-319-ledger-alarm-reaudit-20260829.md`
复核并 ack，最终 `alarms.py check`=`clean (2001 live judgments; 2300 baseline judgments excluded)`。
当前批次由 `39/50` 推进至 `40/50`，未满 50 格不跑统一长门禁、不提交；下一原子继续从尚未具备正式 L2 的 `~`
格选择。P12 的 400+ Journey 扩写仍按用户裁定推迟二期。

## 上一前线整体重述（2026-08-29 · EDGE-318 原子块双/三击真实 App L2 收口）

`EDGE-318 原子块双/三击` 已完成真实产品路径验收。正式 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-000303`，真实 App 夹具包含正文、可编辑 Dart
代码块、可编辑表格、水平分隔线和后续正文。代码块与表格内部双击保持自然的内嵌编辑行为；对原子块执行双击/三击后拖动，分隔线退格探针未误删相邻正文，未形成上游 word/paragraph 手势毒态，编辑器持续可操作。

这次证据刻意不把“整块蓝色高亮”冒充为已证明：代码/表格的内部命中区由编辑器接管，分隔线组件 selection 色为透明；本格 L2 只证明手势安全性和恢复性，不替 L3-L5 的视觉、动效、美学与发现性判定。五通道 session 已由 `rig-check`/`rig-down` 封口，backend/frontend 无应用红线，SSE 三流与 LLM challenge/install/models 均有同 session 记录，夹具最终 REST 内容恢复为原始 `312 B`。

正式证据为 `testend/rig/formal-evidence/EDGE-318-atomic-block-tap-guard-real-app-20260829.md`，`judge.py` 以 `A5` 写入 `L2 ✓`，清册由 `✓~~~~` 提升为 `✓✓~~~`，L3-L5 保持 `na`；anchors=`10/10`。写账打开的 `discovery-collapse` 已以独立复审记录 `testend/rig/formal-evidence/EDGE-318-ledger-alarm-reaudit-20260829.md` 复核并 ack，最终 `alarms.py check`=`clean (2000 live judgments; 2300 baseline judgments excluded)`。当前批次由 `38/50` 推进至 `39/50`，未满 50 格不跑统一长门禁、不提交；下一原子继续从尚未具备正式 L2 的 `~` 格选择。P12 的 400+ Journey 扩写仍按用户裁定推迟二期。

## §6 施工中代拍台账(依据注明,用户可随时翻案)

| # | 代拍决策 | 依据 | 状态 |
|---|---|---|---|
| D1 | 台架自检增加「journal 归属验证」:服务端口持有者 PID == stdout 捕获对象 PID | §5.1 试用轮当场事故 | ✅ 立法,Day 0 实现 |
| D2 | 台架代码住 `testend/`:SSE tap 等 Go 观察者进 `testend/cmd/`(它本就是零 backend import、打纯 HTTP/SSE 的黑盒家),编排脚本进 `testend/rig/` | 复用既有模块与 harness 纪律,不为战役开新顶层目录 | ✅ Day 0 实现 |

## §7 施工序与完成判据

```
[前提] ✅ 另一团队后端大改已并入 main(0731),两仓已对齐
→ ✅ Day 0:五通道台架 + 清册 + 法典 + gate + 锚点 + 警报 + 操作手册全通
→ 主循环:旅程走线 × 驻停清扫,昼夜连轴(专机 24h,P9);
   交互扫面与门禁/testend/回归/数据预构造穿插
→ 收口:全量回归 sweep + 门禁全绿 + 本页收口重述 + landed-into + 归档
```

**完成判据 = 清册干涸(面矩阵全绿 + 旅程账全 ✅),一周 = 预算(N7)。**

## §8 风险与诚实台账

- **体量**:乘法格子万级;可行性押在三压缩器(N4)与测量脚本化上。头两天立法密集、进度看着慢,
  是曲线正常形状非失速。
- **真模型非确定性**:同一旅程两跑行为可异;判据锚在线缆证据与产品兜底(N8),区分「产品 bug」
  与「模型行为」,后者修引导面。
- **一周可能溢出**:长尾(错误码全类、全部难触发路径)可能出预算;诚实溢出在账上(N7)。
- **修复引入回归**:一周长跑里后面的修复可能踩坏前面的——守卫 + 夜间回归重放压舱(§4.6);
  被修复触碰的已绿格子重开重验(§2)。
- **环境依赖**:专机的 OS 权限(录屏/辅助功能)、网关无配额窗口期(P8)是外部前提,失效即前线冻结、
  记档等恢复。
