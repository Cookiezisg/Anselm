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

## 2026-08-01 10:45 · 第三批 TOOL-022 search_function_executions 收尾与 50/50 边界

- 首轮真实会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-103528` 不用于判绿：分页查询中托管模型把 `limit` 发成 JSON 字符串，严格执行边界返回 bad-args；模型随后用数字重试并完成路径，但该真实误用按 H2 视为产品/工具契约反证，前线冻结。
- 直接修复 `backend/internal/app/tool/function/run.go`：`search_function_executions` 公开 schema 继续声明 integer，边界接受精确整数字符串以兼容真实托管模型，同时拒绝数组、小数和非数字字符串；描述和参数说明写清“优先 JSON integer、字符串仅作精确整数兼容”。`function_test.go` 增加描述、接受字符串和拒绝非整数测试；`gofmt` 与 function/tool targeted tests 通过。
- 固定会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-103839` 由同一 conductor 托管真实 Flutter App、受管网关、Computer Use、连续录像、三路 SSE witness、Flutter console 与 LLM tap。真实覆盖：分页两页与 cursor 原样续接；`status=failed` 聚合和行；`versionId` 精确筛选；不存在 function 的干净 `No records` 空态；非法 `status=running` 的允许值错误态。证据图为 `evidence/search-executions-paging.png`、`search-executions-version-filter.png`、`search-executions-empty.png`、`search-executions-invalid-status.png`，完整摘要为 `evidence/tool-022-search-function-executions-session-summary.txt`。
- 五通道收台：screen.mov H.264 `2880x1800 / 420.495000s` 且 ffprobe 可读；backend 只有刻意 invalid-status WARN，无 panic/fatal/未解释 ERROR；frontend 只有已知 macOS IMK/foreground 噪声；LLM 15 个 chat-completion 状态响应全 200，修复后无 limit 解码 retry；messages durable `1..81`、notifications `1..8` 单调，entities 保持连接，sse journal 无 gap；rig-check 在收台前通过，收台无幸存进程。
- 裁决：`judge.py` 五格独立落账 `TOOL-022 search_function_executions`：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。每次裁决后的 `gap-too-fast` 与 `discovery-collapse` 均用本次红/固定会话、录屏、五通道 journal 与截图复审并 ack，最终 `alarms.py check` 为 `clean (150 judgments)`。
- 第三批从 **45 / 50** 达到 **50 / 50**。按 P15 现在进入统一收台后的 `alarms.py check`、完整 `make verify`、完整 `go test ./...`、已修场景回归、完整 testend、工作树审计和提交；门禁完成前不进入 `TOOL-023`，不提交。

## 2026-08-01 11:09 · 第三批统一长门禁收口

- `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/alarms.py check`：`clean (150 judgments on record)`；10 个锚点重新校准通过，四小时 judge 凭证有效。
- `make verify` 全绿：backend、frontend 四组 Flutter 测试、docs、demo 均通过；随后 `mise exec -C backend -- go test ./...` 全包通过。
- `make -C backend testend` 的完整黑盒 scenarios 通过（`280.955s`）；`cd testend && mise exec -- go test -count=1 -timeout 30m ./...` 全模块通过（scenarios `325.407s`，并覆盖 cmd/measure、cmd/ssetap、fixtures、golden、harness、proxycore）；已修 webhook 崩溃恢复专项通过（`11.167s`）。
- 收尾审计通过：docs lint 只有既有的 21 个非同名 DTO mirror 跳过提示；`git diff --check` 通过；testend 残留进程、`:8742`、`:8788` listener 均为空；`test_judge` 与 rig 脚本语法检查通过。
- 第三批统一长门禁已完成，当前只剩工作树最终审计和一次性提交；下一前线仍冻结在 `TOOL-023`，不在本批次记录中提前推进。

## 2026-08-01 11:15 · 第三批提交与第四批前线固定

- 最终工作树审计通过后，第三批以 `eb1ee050 test(acceptance): close third 50-cell gate` 一次提交；提交后 `git status --short` 为空，`:8742`、`:8788` 无 listener，testend 无残留进程。
- 第四批计数重置为 **0 / 50**，不重判已绿单格；下一前线从 COVERAGE 第一条未裁决项 `TOOL-023 get_function_execution` 开始。

## 2026-08-01 10:04 · 第三批 TOOL-020 update_function_meta 真实工具切片与 stop-and-fix

- 首轮真实会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-094939` 不用于判绿：正向路径中 Computer Use `type_text` 吞掉字面下划线，模型写出连字符而非用户要求的精确名称；负向路径中模型先把 `tags` 数组错序列化为字符串，收到后端拒绝后才重试。两项都是真实产品/AI 引导反证，前线冻结。
- 直接修复 `backend/internal/app/tool/function/lifecycle.go`：`update_function_meta` 的描述和参数 schema 增加完整 JSON 对象示例，明确 `tags` 必须是字符串数组，禁止逗号字符串；`function_test.go` 增加描述契约测试。另修复 `testend/rig/rig-up.sh`，每个 session 初始化 `evidence/` 目录，并同步 `testend/rig/README.md`，避免首次截图转换把证据目录写成普通文件。
- 修复后二进制会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-095616` 由真实 App、受管网关、Computer Use、Flutter console、连续录像、三路 SSE witness 与 LLM tap 托管。正向 fixture `fn_d197bf1543a1e7f4` 的 meta 精确更新为 `acceptance_meta_visual_retry_v3`、`Meta update patched schema fixture`、`[acceptance, meta, visual]`；`update_function_meta` 恰一次，v1、active version、代码、env 与 restart 均未改变。SQLite 与 HTTP 一致。
- 负向只传 name 给不存在的 `fn_0000000000000000`，工具激活后调用恰一次；UI 显示干净 `function not found`，无 function/version/sandbox 副作用。证据图为 `evidence/update-function-meta-fixed-hit.png` 与 `evidence/update-function-meta-fixed-failed.png`，完整摘要为 `evidence/tool-020-update-function-meta-session-summary.txt`。
- 五通道：screen.mov H.264 `2880x1800 / 268.930000s`；backend 只有一条刻意 not-found WARN，无 panic/fatal/ERROR；frontend 仅已知 macOS IMK/foreground 噪声；LLM 24 个响应全 200，修复 session 无 serialization retry；messages/notifications durable `1..73`、`1..5` 单调，entities 已连接；rig-check 在收台前通过，anchors 校准通过。
- 裁决：`judge.py` 五格独立落账 `TOOL-020 update_function_meta`：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。每次裁决后的 `gap-too-fast` 与 `discovery-collapse` 均以本次正负画面、录屏、五通道 journal、SQLite/HTTP 结果复审并 ack，最终 `alarms.py check` 为 `clean (140 judgments)`。
- 第三批从 **35 / 50** 推进至 **40 / 50**；下一前线为 `TOOL-021`。未到 50 格不跑统一长门禁、不提交；本批代码、测试、COVERAGE、LOOP 与本日志留在工作树，待第三批边界统一收口。

## 2026-08-01 10:26 · 第三批 TOOL-021 run_function 真实工具切片与 stop-and-fix

- 首轮会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-100648` 暴露两项真实问题：不存在 ID 的提示因模型把零串写错而重复调用；显式版本被实际 wire 成 `"version":"2"`，后端严格 decoder 拒绝，模型随后省略版本重试。第二轮 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-101400` 在工具描述/schema 已明确 integer 后仍复现字符串化 `version`，同时 `args` 也被字符串化；两轮均只作红灯反证，不用于判绿。
- 前线冻结后修复 `backend/internal/app/tool/function/run.go`：公开 schema 仍声明 integer/object，执行边界接受与 attachment 工具一致的精确整数字符串和字符串化对象；数组、小数、非数字字符串仍拒绝。描述同步改为“优先数字，兼容精确整数字符串”，并补 `function_test.go` 的接受/拒绝形状测试。`gofmt` 与 `go test ./internal/app/function/... ./internal/app/tool/function/...` 通过。
- 固定会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-101832` 重新由同一 conductor 托管真实 App、受管网关、Computer Use、Flutter console、连续录像、三路 SSE witness 与 LLM tap。显式 v2 只发一次，wire 的字符串化 `args`/`version` 被边界正确解码，结果为 `MIXED CASE`，SQLite execution `fne_6f78754411a72538` 钉住 `fnv_e526b409693ea039`；不存在 `fn_deadbeefdeadbeef` 只发一次、干净返回 `function not found` 且无 execution；已有 echo function 缺 `text` 只发一次，`ok=false`、`failed`、TypeError 和 5 行日志真实呈现。
- 旧会话中一次 Computer Use 坐标误点到 Recents 而非 New chat，导致上下文污染；不用于绿证据。随后真正点击 `New chat`，重新获得独立的 not-found 与 execution-failed 终态画面，证据为 `evidence/run-function-explicit-v2.png`、`evidence/run-function-not-found-final.png`、`evidence/run-function-execution-failed-final.png`，完整摘要为 `evidence/tool-021-run-function-session-summary.txt`。
- 五通道：screen.mov H.264 `2880x1800 / 468.141667s`；backend 仅两条预期 not-found WARN，无 panic/error/fatal；frontend 仅已知 macOS IMK 噪声；LLM 15 个响应全 200，且 wire 留存了真实字符串化字段；messages/entities/notifications durable 分别 `1..75`、`1..4`、`1..6` 单调，三流持续连接；收台无幸存进程。
- 裁决：`judge.py` 五格独立落账 `TOOL-021 run_function`：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。每次裁决后的 `gap-too-fast` 与 `discovery-collapse` 均以本 session 的正负画面、录屏、五通道 journal、SQLite/LLM wire 复审并 ack，最终 `alarms.py check` 为 `clean (145 judgments)`。
- 第三批从 **40 / 50** 推进至 **45 / 50**；下一前线为 `TOOL-022 search_function_executions`。未到 50 格不跑统一长门禁、不提交；本批代码、测试、COVERAGE、LOOP 与本日志留在工作树，待第三批边界统一收口。

## 2026-08-01 09:42 · 第三批 TOOL-019 delete_function 真实工具切片与 stop-and-fix

- 首轮真实会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-092832` 发现工具描述与持久化设计不一致：产品报告声称删除了全部 function 版本，但代码/数据库的设计是软删主行、不可变版本历史 append-only 保留供审计。该会话作为反证保留，不用于判绿；前线冻结。
- 直接修复 `backend/internal/app/tool/function/lifecycle.go`：描述和返回结构明确 `function=soft_deleted`、`versions=retained_for_audit`、`sandbox=destroy_requested_best_effort`、`actions=not_found`；补 `function_test.go`，并同步 `docs/references/backend/api.md`。工具摘要与 COVERAGE 原始提取物同步为 retention truth。
- 修复后会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-093503` 由同一 conductor 托管真实 App、受管网关、Computer Use、Flutter console、连续录像、三路 SSE witness 与 LLM tap。正向 disposable function 为 `fn_cd3e4c341e12871a`，v1 `fnv_975a0bc158414e28`，sandbox `fnenv_8e9272035daf5708`；删除调用恰一次，UI 准确展示软删、版本审计保留、sandbox 回收、动作 not-found。SQLite 证明 deleted_at 已写、版本行仍在、sandbox 行和目录已清；HTTP 证明主实体 404、versions 仍 200 可审计。
- 负向新会话路径只请求不存在的 `fn_0000000000000000`，`delete_function` 激活后调用恰一次；UI 显示干净的 `function not found`，无实体、sandbox 或其它写操作副作用。证据图为 `evidence/delete-function-fixed-hit.png` 与 `evidence/delete-function-fixed-failed.png`，完整摘要为 `evidence/tool-019-delete-function-session-summary.txt`。
- 五通道：screen.mov H.264 `2880x1800 / 466.838333s`；backend 仅两条预期 WARN（fixture 的错误 ops 重试、刻意 not-found），无 panic/fatal/ERROR；frontend 仅已知 macOS IMK/foreground 噪声；LLM 22 个状态响应全 200；messages/entities/notifications durable `1..64`、`1..4`、`1..9` 单调；rig-check 在收台前通过。
- 裁决：`judge.py` 五格独立落账 `TOOL-019 delete_function`：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。每次裁决后的 `gap-too-fast` 与 `discovery-collapse` 均用本次正负画面、录屏、五通道 journal、SQLite/HTTP 结果复审并 ack，最终 `alarms.py check` 为 `clean (135 judgments)`。
- 第三批从 **30 / 50** 推进至 **35 / 50**；下一前线为 `TOOL-020 update_function_meta`。未到 50 格不跑统一长门禁、不提交；本批代码、测试、COVERAGE、LOOP 与本日志留在工作树，待第三批边界统一收口。

## 2026-08-01 09:25 · 第三批 TOOL-018 revert_function 真实工具切片与 stop-and-fix

- 正向真实会话从同一 `acceptance_create_visual_retry` 的 v2 回退到 v1。UI 展示 Previous v2、Target v1、Resulting v1、active version ID `fnv_16dc4e226e8e9007`、ready env 和恢复后的 echo code；v2 保留在 history，未产生 v3。
- 负向真实会话请求不存在的 v999。后端两次真实 `revert_function` 均明确返回 `function version not found`；模型随后调用只读 `get_function`，核验 active 仍为 v1、时间戳未变、无新版本且 active pointer 未修改。额外失败重试是模型工具编排事实，写入证据，不伪装成单次调用；它没有造成数据副作用。
- 五通道：会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-091433` 的 screen.mov H.264 `2880x1800 / 490.781667s`；backend 只有两条刻意 v999 失败 WARN，无 panic/fatal/ERROR；frontend 仅已知 macOS IMK/foreground 平台噪声；LLM 2 个 proof challenge 与 26 个 chat completion 状态全 200；messages durable `1..86`、notifications `1..5` 单调无 gap/regression，entities 保持连接。成功/失败原生画面证据为 `evidence/revert-function-hit.png` 与 `evidence/revert-function-failed.png`。
- SQLite 复核：`fn_d739a28d0bcdf21b` 的 active pointer 为 v1，history 恰有 v1/v2，无 v3；v1/v2 environment 均 ready。完整摘要为 `evidence/tool-018-revert-function-session-summary.txt`。
- 裁决：Go function service/tool 单测通过；`judge.py` 五格独立落账 `TOOL-018 revert_function`：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。五次统计警报均以本 session 的正负截图、录屏、五通道 journal 和 SQLite 结论复审并 ack，最终 `alarms.py check` 为 `clean (130 judgments)`。
- 第三批从 **25 / 50** 推进至 **30 / 50**；下一前线为 `TOOL-019 delete_function`。未到 50 格不跑统一长门禁、不提交；本批证据、COVERAGE、LOOP 与本日志留在工作树，待第三批边界统一收口。

## 2026-08-01 09:12 · 第三批 TOOL-017 edit_function 真实工具切片与 stop-and-fix

- 正向真实会话编辑既有 `acceptance_create_visual_retry`：从 v1 变更描述与代码为 v2，输入/输出、Python 3.12、无依赖保持不变；产品卡片展示 Previous 1、New 2、Version ID `fnv_e526b409693ea039`、env ready，Activity 显示 Edited。
- 负向同一实体提交 `this is not valid Python`。后端在版本构建前返回 `function code invalid (reason=code must declare at least one top-level def)`；失败卡片保留 edit 专属 `Draft unsaved · truth is still the last version`，随后模型额外调用只读 `get_function` 核验 v2，SQLite 证明无 v3、active 指针和 v2 代码不变。该额外只读调用按实际证据记录，不包装成纯 edit 单工具路径。
- 五通道：会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-090605` 的 screen.mov H.264 `2880x1800 / 206.015000s`；backend 只有一条刻意非法代码 WARN，无 panic/fatal/ERROR；frontend 仅已知 IMK 平台噪声；LLM 20 个状态响应全 200；messages/entities/notifications durable seq 分别 `1..67`、`1..6`、`1..7`，各自唯一且单调。证据图为 `evidence/edit-function-hit.png` 与 `evidence/edit-function-failed.png`。
- 裁决：anchors 校准通过；`judge.py` 五格独立落账 `TOOL-017 edit_function`：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`；五次统计警报均以本 session 证据复审并 ack，最终 `alarms.py check` 为 `clean (125 judgments)`。完整证据摘要：`evidence/tool-017-edit-function-session-summary.txt`。
- 第三批从 **20 / 50** 推进至 **25 / 50**；下一前线为 `TOOL-018 revert_function`。未到 50 格不跑统一长门禁、不提交；本批代码、测试、COVERAGE 与本日志留在工作树，待第三批边界统一收口。

## 2026-08-01 09:01 · 第三批 TOOL-016 create_function 真实工具切片与 stop-and-fix

- 首轮真实会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-084640` 发现 create 失败路径复用了 edit 的诚实丝带文案 `Draft unsaved · truth is still the last version`；新建不存在“上一版”，这是产品事实错误。该会话不用于判绿，前线冻结。
- 直接修复：`frontend/lib/core/ui/an_honesty_ribbon.dart` 新增 `AnHonesty.failedCreate` 及中英文 `ribbonFailedCreate`；`frontend/lib/features/chat/ui/stage_panel.dart` 仅对 `create_*` 使用“尚未创建实体”，`edit_*` 继续使用“上一版”；`stages_w4_test.dart` 增加 create/edit 对称 widget 回归。`dart run slang` 生成成功，`flutter test test/features/chat/ui/stages_w4_test.dart` 全部 12 项通过。
- 修复后真实会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-085503` 由同一 conductor 托管真实 App、受管网关、Computer Use、Flutter console、录像、三路 SSE witness 与 LLM tap。正向调用五个 ops 创建 `acceptance_create_visual_retry` (`fn_d739a28d0bcdf21b`, v1, env ready)，展开卡片显示真实两行 Python 代码，Activity 显示 `1 touched / Created`；负向只给一个 `set_meta`，后端返回 `function code invalid (reason=code is required)`，Activity 显示 Failed，create ribbon 显示 `Draft unsaved · nothing was created`。
- 数据与五通道：SQLite 只有成功 function/version，失败名无 `functions`/`function_versions` 行；screen.mov H.264 `2880x1800 / 188.273333s`，证据图为 `evidence/create-function-hit.png` 与 `evidence/create-function-failed.png`；backend 只有一条刻意触发的业务 WARN，无 panic/fatal/ERROR；frontend 仅已知 IMK 平台噪声；LLM 18 个状态响应全 200；messages/entities/notifications durable seq 分别 `1..51`、`1..6`、`1..7`，各自唯一且单调。
- 裁决：anchors 校准通过；`judge.py` 五格独立落账 `TOOL-016 create_function`：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`；五次统计警报均以本 session 证据复审并 ack，最终 `alarms.py check` 为 `clean (120 judgments)`。完整证据摘要：`evidence/tool-016-create-function-session-summary.txt`。
- 第三批从 **15 / 50** 推进至 **20 / 50**；下一前线为 `TOOL-017 edit_function`。未到 50 格不跑统一长门禁、不提交；本批代码、测试、COVERAGE 与本日志留在工作树，待第三批边界统一收口。

## 2026-08-01 08:44 · 第三批 TOOL-015 get_function 真实工具切片与 stop-and-fix

- 首轮会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-083052` 真实覆盖了正向完整活跃版本和不存在 ID。发现 not-found 工具卡的错误行显示 `get_function: functionapp.Get: function not found`，把内部 Go 调用路径暴露给用户；该会话和其截图全部标为反证，不用于判绿。
- 前线冻结后直接修复 `backend/internal/app/loop/tools.go`：ValidateInput 与 Execute 失败的 `errMsg` 统一走 `llmErrText`，保留操作日志的结构化信息但不把 Go wrapper 路径写进持久化 tool-result；新增 `TestExecuteTool_UserErrorMessageIsClean`，`mise exec -C backend -- go test ./internal/app/loop` 通过。
- 修复后会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-083704` 重新由 conductor 启动真实 App、受管网关、Flutter console、连续录像、三路 SSE witness 与 LLM tap。正向真实呈现代码、输入/输出、空依赖、Python 3.12、环境 ID、ready、同步时间和版本更新时间；负向真实调用 `fn_0000000000000000`，错误卡片只显示 `function not found`，且明确没有副作用。
- 五通道：`screen.mov` H.264 2880x1800、`189.096667s` 可读；backend 无 panic/fatal/ERROR，仅有一条预期的 not-found 业务 WARN；frontend 仅已知 `IMKCFRunLoopWakeUpReliable` 平台噪声；LLM 18 个状态响应全 200；SSE 三路各连接一次，messages durable `1..43`、notifications `1..4` 单调，entities 连接正常但本切片无 durable 事件。
- 证据：`evidence/get-function-hit.png`、`evidence/get-function-not-found.png`、`evidence/tool-015-get-function-session-summary.txt`。anchors 复核通过；`judge.py` 独立落账 `TOOL-015 get_function` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。统计警报均以复审结论 ack，最终 `alarms.py check` 为 `clean (115 judgments)`。
- 第三批从 **10 / 50** 推进至 **15 / 50**；下一前线为 `TOOL-016 create_function`。未到 50 格不跑统一长门禁、不提交；本批代码、测试、COVERAGE 与本日志留在工作树，待第三批边界统一收口。

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

## 2026-08-01 · 第二批 TOOL-003 Edit 真实工具切片

- 台架会话：`/tmp/anselm-rig-formal-20260801-14/sessions/20260801-044210`；真实 App、受管网关、Computer Use、屏幕录像、后端、三路 SSE tap 和 LLM tap 均由同一 conductor 托管。`rig-check` 起始与收台前均五通道全绿，收台录像 `screen.mov` 时长 `260.076667s` 且 ffprobe 可读，无残留进程。
- 构造数据：真实对话挂载 `/tmp/anselm-edit-fixture-14`，包含 `target.txt`、`other.txt` 和 `nested/child.txt`。成功路径由真实 composer 发起，LLM 线缆和 messages SSE 均证明执行顺序为 `Read(target.txt) → Edit(old=beta,new=BETA) → Read(target.txt)`；UI 显示 `Edited target.txt · 1 replaced`，最终代码块为 `alpha / BETA / gamma`。
- 负路径：同一对话要求替换不存在的 `delta`。真实模型先 `Read`，然后明确拒绝，不调用 `Edit`、`Write` 或其他变更工具；UI 展示原因和当前文件内容。磁盘核对确认三个夹具文件只有目标文件发生预期替换。
- 五通道收台：`llm.jsonl` 20 个 HTTP 响应全为 200，`sse.jsonl` messages durable seq 1..38 且包含两条路径的工具调用/结果，notifications seq 16、entities 流已连接；`backend.log` 无 WARN/ERROR/panic/FATAL；`frontend.log` 无 Flutter/Dart/AXTree/RenderFlex/Unhandled Exception；关键画面为 `evidence/edit-tool-final.jpeg` 与 `evidence/edit-tool-no-match.jpeg`，完整摘要为 `evidence/tool-003-edit-session-summary.txt`。
- `judge.py` 用正确批次 `RIG_HOME=/tmp/anselm-rig-formal-20260801-3`、已通过锚点校准的 `anchor-answers.json` 独立落账 `TOOL-003 Edit` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。批次从 `0 / 50` 推进到 **5 / 50**。
- 裁决后统计警报曾按机制打开 `gap-too-fast` 和 `discovery-collapse`；复审确认五格均在完整证据观看、收台和磁盘核对后才落账，且负路径真实发现了只读拒绝保护，遂分别写入复审 note 并 ack。最终 `alarms.py check` 为 `clean (55 judgments on record)`。注意：一次未导出的 `RIG_HOME` 曾误写默认账本，已完整隔离到 `~/.anselm-rig/misrouted-edit-20260801-0448.judgments.jsonl`，批次账本无污染。
- 当前前线：第二批 **5 / 50**；下一格为 `TOOL-004 LS`，未到第二批 50 格不跑统一长门禁、不提交。
- 台架机制 stop-and-fix：一次错误的未导出 `RIG_HOME` 重放暴露 `judge.py` 对相同裁决会重复追加 COVERAGE 证据指针的幂等缺口。已修复为相同 `(family,item,level,verdict,law,evidence)` 重跑 no-op，新增 `testend/rig/test_judge.py` 守卫并验证真实 TOOL-003 重放不增加 journal 行、不重复证据。此修复只影响裁判系统，不改变产品格计数；下一格仍为 `TOOL-004 LS`。

## 2026-08-01 · Goal/Loop 配置恢复

- 用户暂停后要求恢复 Goal 与 Loop；Codex 状态核对为唯一持久 Goal `active`，未创建副本，未启用并行 agent。
- 旧的 `TOOL-004 LS` 实时会话 `/tmp/anselm-rig-formal-20260801-16/sessions/20260801-045350` 已运行 `rig-check` 后收台；五通道在收台前均在线，录像时长 `331.833333s`，证据与 journals 保留，但该会话不写入 COVERAGE 裁决。
- 恢复点固定为第二批 `5 / 50`，下一前线仍为 `TOOL-004 LS`；50 格前不跑统一长门禁、不提交。后续每次唤醒先读本页、`README.md`、`LOOP.md` 和当前 git 状态，再检查是否存在 live rig，保持单一作者、单一台架、逐格 stop-and-fix。

## 2026-08-01 · 第二批 TOOL-004 LS 真实工具切片与 stop-and-fix

- 台架会话：`/tmp/anselm-rig-formal-20260801-17/sessions/20260801-050302`；当前前端代码在全新五通道台架中真实构建并启动，受管网关经 `llmtap` 接线，`ssetap` 动态接入三路 SSE，Computer Use 与连续屏幕录像由同一 conductor 托管；收台前 `rig-check` 五通道全绿，`screen.mov` 时长 `213.276667s` 且 ffprobe 可读。
- 构造数据：真实对话驻地 `/tmp/anselm-ls-fixture-17`，包含 `.hidden.txt`、`a.txt`、`b.txt`、空目录 `empty-dir`、`nested/deep.txt` 与 `nested/deeper/file.txt`。第一条真实请求只用 LS 列当前目录，正确返回 5 个直接条目；第二条请求按序只用 LS 查询 `nested`、缺失目录和文件 `a.txt`。
- 真实首轮发现的产品缺陷：LS 对 `Directory not found` 与 `Not a directory` 这种 completed tool_result 虽然正文是错误，折叠卡标题仍显示成功动词 `Listed`，造成红色事实旁的假成功语义。前线冻结，未把首轮当成通过。
- 修复：`lsResultFailed` 以 LS 成功 listing header 的结构契约判定失败；`_search` 支持失败动词/结果重分类；新增双语 `listFailed` 和 `tool_card_fs_search_test.dart` 的 parser/widget 守卫。修复后失败卡片自动展开原始错误正文并显示 `List failed … · failed`，正常卡片仍显示 `Listed … · 5 items`。
- 真实逐帧复验：成功画面确认目录优先、隐藏文件和空目录可见、`nested/deep.txt` 不越层；错误画面确认两个失败卡均不再显示 `Listed`，正文分别为缺失目录与提示使用 Read。证据为 `evidence/ls-success.jpeg`、`evidence/ls-errors.jpeg` 和完整录像；摘要为 `evidence/tool-004-ls-session-summary.txt`。
- 五通道收台：`backend.log` 无 WARN/ERROR/panic/FATAL；`frontend.log` 无 Flutter/Dart/AXTree/RenderFlex/Unhandled Exception，仅有已知 `IMKCFRunLoopWakeUpReliable` macOS 平台噪声；`llm.jsonl` 18 个 HTTP 响应全 200；`sse.jsonl` 三流均连接，messages durable seq `1..40` 单调，notifications durable seq `16`，entities 已连接；磁盘夹具只读且未改变。
- 录屏环境诚实标注：桌面级 `screen.mov` 中间捕获到其他进程的 Apple Music 权限弹窗，不属于 Anselm、未被操作，也未用于产品判断；Computer Use 取得的 Anselm 窗口截图没有被遮挡。该环境污染保留在摘要中，不伪装成产品绿证据。
- `judge.py` 用正确批次 `RIG_HOME=/tmp/anselm-rig-formal-20260801-3`、四小时锚点凭证和独立证据落账 `TOOL-004 LS` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`；批次从 `5 / 50` 推进到 **10 / 50**。裁决后 `gap-too-fast` 与 `discovery-collapse` 按机制打开，证据逐项复审并 ack，最终 `alarms.py check` 为 `clean (60 judgments on record)`。
- 当前前线：第二批 **10 / 50**；下一格为 `TOOL-005 Glob`，未到第二批 50 格不跑统一长门禁、不提交。


## 2026-08-01 · 第二批 TOOL-005 Glob 真实工具切片与 stop-and-fix

- 台架会话：`/tmp/anselm-rig-formal-20260801-19/sessions/20260801-051557`；真实 App、受管网关、Computer Use、屏幕录像、后端、三路 SSE tap 和 LLM tap 均由同一 conductor 托管。收台后 `screen.mov` 时长 `171.003333s` 且 ffprobe 可读，三路 SSE 均真实连接。
- 构造数据：`/tmp/anselm-glob-fixture-18` 包含根级 `app.go`、`src/other.go`、`src/nested/deep.go`、非 Go 文本和标准噪声目录 `.git`、`node_modules`；真实对话要求递归 `**/*.go`，并检查空结果、`limit=2` 截断、缺失根和文件根边界。
- 首轮真实发现的产品缺陷：后端实现确实跳过标准噪声目录，但 Glob 的工具 description/schema 没有把这个用户可观察契约说清，模型无法确认 `.git` 与 `node_modules` 是否被主动排除。前线冻结，未将首轮当成通过。
- 修复：`backend/internal/app/tool/search/glob.go` 补齐递归噪声目录说明及显式根例外，`glob_test.go` 增加描述契约守卫；前端新增 `globResultFailed`，将非 JSON、缺失根和非目录等错误 payload 重分类为 `Glob failed` 并自动展开，补齐双语 i18n 与 widget 测试。
- 修复后真实逐帧复验：成功路径返回 3 个 Go 文件，模型明确复述递归噪声目录策略；`*.rs` 显示合法空结果；`limit=2` 显示 2 行且总数 3、截断语义清楚；缺失根和文件根均显示红色 `Glob failed "*.go" · failed` 与可读错误正文。关键画面：`evidence/glob-success.jpeg`、`evidence/glob-boundaries.jpeg`；完整摘要：`evidence/tool-005-glob-session-summary.txt`。
- 五通道收台：`backend.log` 无 WARN/ERROR/panic/FATAL；`frontend.log` 无 Flutter/Dart/AXTree/RenderFlex/Unhandled Exception，仅已知 macOS IMK 平台噪声；LLM journal 20 个 HTTP 响应全为 200；`sse.jsonl` 共 617 行，messages durable seq 单调、notifications/entities 均曾连接；录屏可读。桌面录像没有被用于掩盖或替代 Anselm 窗口证据。
- `judge.py` 在正确 `RIG_HOME=/tmp/anselm-rig-formal-20260801-3`、锚点凭证有效且警报先验干净的条件下，独立落账 `TOOL-005 Glob` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。第二批从 `10 / 50` 推进至 **15 / 50**；同一命令重放保持幂等 no-op。
- 裁决后 `alarms.py check` 按机制打开 `gap-too-fast` 与 `discovery-collapse`；复审确认本次真实包含负路径、首轮冻结和修复后重跑，逐项查看五通道证据后写入复核说明并 ack，最终为 `clean (65 judgments on record)`。
- 当前前线：第二批 **15 / 50**；下一格为 `TOOL-006 Grep`。未到第二批 50 格不跑统一长门禁、不提交。

## 2026-08-01 · 第二批 TOOL-006 Grep 真实工具切片与 stop-and-fix

- 最终台架会话：`/tmp/anselm-rig-formal-20260801-22/sessions/20260801-054044`；真实 App、受管网关、Computer Use、屏幕录像、后端、三路 SSE tap 和 LLM tap 均由同一 conductor 托管。收台前 `rig-check` 五通道全绿，`rig-down` 封口 `screen.mov` 时长 `269.225000s`，所有进程均正常结束。
- 构造数据：`/tmp/anselm-grep-fixture-20` 包含 README、Go、文本、多行匹配、`.git`、`node_modules`、空结果和可触发错误的路径。真实路径覆盖 `content`、`files_with_matches`、`count`、`multiline=true`、`head_limit=1` 截断、合法 no-match、非法正则 `[`、缺失根目录；递归结果不泄漏 `.git` 或 `node_modules`。
- 首轮真实发现并冻结：ripgrep 路径未显式排除 `node_modules`；content 模式把 context/path 物理行错误计入匹配数；缺失根和路径安全错误在 UI 中仍像成功搜索；非法正则触发 rg fallback WARN。未用首轮证据裁绿。
- 修复：`grep_rg.go` 显式排除六类噪声目录并在启动 rg 前预校验正则；`grep.go`/schema 补齐多行参数和噪声目录契约；`tool_card_fs_search.dart` 按模式计算语义 receipt、识别失败前缀并统一错误卡片；`tool_card_catalog.dart`、双语 i18n 与 widget 守卫同步更新。前两次台架中一次复杂提示误触发未知 `multiline` 工具，最终复验改用 Grep-only 明确指令并确认真实调用 `multiline=true`，最终 backend 无该告警。
- 修复后逐帧复验：content 显示 5 个语义匹配而非上下文物理行；files 模式显示 3 个文件；count 模式聚合每文件计数；多行模式命中 `src/multiline.txt`；截断显示 `1+ files` 并解释下限；空结果显示 `no matches`；非法正则和缺失根分别显示红色 `Search failed` 及原始错误正文。
- 五通道收台：`backend.log` 无 WARN/ERROR/panic/fatal；`frontend.log` 仅已知 macOS IMK/foreground 平台噪声，无 Dart/Flutter/AXTree/RenderFlex/Unhandled Exception；`llm.jsonl` 28 个 HTTP 响应全为 200；`sse.jsonl` 三流均连接，messages durable seq `1..70`、notifications durable seq `1..2` 连续，entities 已连接；证据摘要为 `evidence/tool-006-grep-session-summary.txt`，完整录屏已封存。
- `judge.py` 在锚点校准通过、警报先验干净的 `RIG_HOME=/tmp/anselm-rig-formal-20260801-3` 下独立落账 `TOOL-006 Grep` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。裁决后两条统计警报按机制打开；逐项复审真实负路径、冻结修复、五通道和证据后写入 ack，最终 `alarms.py check` 为 `clean (70 judgments on record)`。
- 第二批从 **15 / 50** 推进至 **20 / 50**；当前前线为下一未裁决格 `TOOL-007 Bash`。未到第二批 50 格不跑统一长门禁、不提交。完整证据清单与早期废弃台架说明见 `/tmp/anselm-rig-formal-20260801-22/sessions/20260801-054044/evidence/tool-006-grep-session-summary.txt`。

## 2026-08-01 · 第二批 TOOL-007 Bash 真实工具切片与 stop-and-fix

- 最终台架会话：`/tmp/anselm-rig-formal-20260801-23/sessions/20260801-055042`；真实 App、受管网关、Computer Use、屏幕录像、后端、三路 SSE tap 和 LLM tap 均由同一 conductor 托管。收台前 `rig-check` 五通道全绿，`rig-down` 封口 `screen.mov` 时长 `580.875000s`，所有台架进程均正常结束。
- 构造数据：`/tmp/anselm-bash-fixture-23` 中的 `fixture.txt` 与 `other.txt` 用于驻地验证。真实覆盖前台 stdout+stderr 合流与非零退出、危险命令审批拒绝、100ms 超时、后台启动与 BashOutput 轮询、KillShell 中途终止、原生目录选择器挂载驻地、驻地移失后的拒绝、不回落后端 cwd，以及 270000 字节输出封顶。
- 关键产品判断：大输出通过 `tool_result` 256KiB 总封顶后，Bash footer 可能被通用封顶截掉；UI 明确显示截断 marker，并把回执降为 `exit unknown` warn，而不是猜成功/失败。该状态诚实且可解释，提示用户收窄命令；不是缺陷，不改代码。
- 逐帧结果：前台卡片显示合并输出和 `exit 3`；危险命令先出现审批面，deny 后显示 Safety refusal 且没有执行；超时显示 `timed out after 100ms` 和 `exit -1`；后台显示可复制 `bsh_…`、轮询结果 `bg-start/bg-done` 与 exited code 0；KillShell 后 `should-not-appear` 未出现；驻地相对 `pwd`/`ls -1` 正确命中 fixture；驻地失效明确拒绝并不静默改跑 `/` 或 sidecar 目录。
- 五通道收台：`backend.log` 无 WARN/ERROR/panic/fatal；`frontend.log` 仅已知 macOS IMK/foreground 平台噪声，无 Dart/Flutter/AXTree/RenderFlex/Unhandled Exception；`llm.jsonl` 48 个 HTTP 响应全为 200；`sse.jsonl` 三流均连接，messages durable seq `1..138`、notifications durable seq `1..6` 连续，entities 已连接；证据 JPEG 覆盖前台、拒绝、超时、后台、终止、驻地、失效驻地和封顶。
- `judge.py` 在锚点校准通过、警报先验干净的 `RIG_HOME=/tmp/anselm-rig-formal-20260801-3` 下独立落账 `TOOL-007 Bash` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。裁决后两条统计警报按机制打开；复审真实负路径、封顶诚实语义、进程清理和五通道证据后写入 ack，最终 `alarms.py check` 为 `clean (75 judgments on record)`。
- 第二批从 **20 / 50** 推进至 **25 / 50**；当前前线为下一未裁决格 `TOOL-008 BashOutput`。未到第二批 50 格不跑统一长门禁、不提交。完整证据摘要见 `/tmp/anselm-rig-formal-20260801-23/sessions/20260801-055042/evidence/tool-007-bash-session-summary.txt`。

## 2026-08-01 · 第二批 TOOL-008 BashOutput 真实工具切片与 stop-and-fix

- 最终台架会话：`/tmp/anselm-rig-formal-20260801-24/sessions/20260801-060449`；真实 App、受管网关、Computer Use、屏幕录像、后端、三路 SSE tap 和 LLM tap 均由同一 conductor 托管。收台后 `screen.mov` 时长 `548.728333s`，五通道进程正常结束。
- 构造数据：沿用真实后台 shell `echo KEEPONE; echo DROPTWO; sleep 8; echo KEEPTHREE`，用 BashOutput 分别覆盖无过滤增量读取、`KEEP` regex 过滤、无新输出、最终 exited 状态；随后刻意请求不存在的 `bash_id` 和非法 regex，验证错误路径。
- 逐帧产品结果：正常卡片只展示本次新增输出，不重复已消费行；过滤卡片展示 `KEEPTHREE` 和 `exited (code 0)`；无新输出明确说明已消费完并保留最终状态。缺失 bash_id 显示 `session not found`、红色错误回执和原始错误；非法 regex 在工具输入校验层拒绝，显示红色 failed 行、`Error` 标签、完整 `missing closing ]` 原文和可展开 raw result。没有把错误伪装成空成功轮询。
- 五通道收台：`backend.log` 唯一 WARN 是这次刻意触发的非法 regex 输入校验拒绝，已与 UI、LLM wire 和证据摘要逐字互证；除此之外无 WARN/ERROR/panic/fatal。`frontend.log` 仅已知 macOS foreground/IMK 平台噪声，无 Dart/Flutter/AXTree/RenderFlex/Unhandled Exception；`llm.jsonl` 36 个 HTTP 响应全 200；`sse.jsonl` messages durable seq `1..90`、notifications `1..2` 单调，entities 持续连接。关键画面为 `evidence/bashoutput-missing.jpeg` 与 `evidence/bashoutput-invalid-regex.jpeg`，摘要为 `evidence/tool-008-bashoutput-session-summary.txt`。
- `judge.py` 在锚点校准通过、警报先验干净的 `RIG_HOME=/tmp/anselm-rig-formal-20260801-3` 下独立落账 `TOOL-008 BashOutput` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。五级证据分别指向摘要、录屏和两张真实画面；无代码缺陷需要 stop-and-fix。
- 裁决后 `gap-too-fast` 与 `discovery-collapse` 按机制打开；复审确认五级裁决是在完整录屏和五通道证据观看后落账，且负路径真实触发并清晰呈现，遂写入复审 note 并 ack；最终 `alarms.py check` 为 `clean (80 judgments on record)`。
- 第二批从 **25 / 50** 推进至 **30 / 50**；当前前线为下一未裁决格 `TOOL-009 KillShell`。未到第二批 50 格不跑统一长门禁、不提交。完整证据摘要见 `/tmp/anselm-rig-formal-20260801-24/sessions/20260801-060449/evidence/tool-008-bashoutput-session-summary.txt`。

## 2026-08-01 · 第二批 TOOL-009 KillShell 真实工具切片与 stop-and-fix

- 初始真实会话 `/tmp/anselm-rig-formal-20260801-25/sessions/20260801-061721` 先验证了后台启动、KillShell 终止和重复调用，但逐帧审查发现重复调用的主行显示 `Terminated … · session not found`，与后端幂等事实冲突；该会话不直接判绿。一次提示词中的分号还被 Computer Use 输入吞掉，形成了立即退出的 malformed `sleep 30 echo SHOULDNOTAPPEAR`，明确排除出终止成功证据。
- 前线冻结并修复共享产品语义：`tool_receipts.dart` 增加结果驱动的 `killShellTerminalVerb`；KillShell 三种正常 `err=nil` 结果分别显示 `Terminated`、`already finished`、`already stopped`，删去重复橙色 not-found 回执，精确 wire 结果仍保留在可展开 body。补齐英/中文 i18n 生成物、receipt/parser 测试和 widget 三态守卫；`flutter analyze` 无问题，相关测试全绿。
- 修复后新建真实会话：`/tmp/anselm-rig-formal-20260801-26/sessions/20260801-062334`。真实后台 `sleep 30` 立即经 KillShell 返回 `Killed background shell bsh_9f260ea1079737e9.`，UI 主行显示 `Terminated`；对已移除会话和 fabricated `bshghost` 的重复/未知调用显示 `already stopped`，原始 `Background shell process not found` 仍可读，且不再制造错误警告。证据为 `evidence/killshell-terminated.jpeg`、`evidence/killshell-already-stopped.jpeg`，完整摘要为 `evidence/tool-009-killshell-session-summary.txt`。
- 五通道收台：`screen.mov` 时长 `248.060000s`；`backend.log` 无 WARN/ERROR/panic/fatal；`frontend.log` 仅已知 macOS foreground/IMK 平台噪声，无 Dart/Flutter/AXTree/RenderFlex/Unhandled Exception；`llm.jsonl` 32 个 HTTP 响应全 200；`sse.jsonl` messages durable seq `1..76`、notifications `1..2` 单调，entities 持续连接。
- `judge.py` 在锚点校准通过、警报先验干净的 `RIG_HOME=/tmp/anselm-rig-formal-20260801-3` 下独立落账 `TOOL-009 KillShell` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。裁决后两条统计警报经逐帧、修复记录、目标测试和五通道证据复审后 ack；最终 `alarms.py check` 为 `clean (85 judgments on record)`。
- 第二批从 **30 / 50** 推进至 **35 / 50**；当前前线为下一未裁决格 `TOOL-010 ask_user`。未到第二批 50 格不跑统一长门禁、不提交。

## 2026-08-01 · 第二批 TOOL-010 ask_user 真实工具切片与产品收尾

- 最终台架会话：`/tmp/anselm-rig-formal-20260801-27/sessions/20260801-063212`；真实 Flutter App、受管 Anselm 网关、Computer Use、连续屏幕录像、后端、三路 SSE tap 和 LLM tap 均由同一 conductor 托管。收台前 `rig-check` 五通道全绿，`rig-down` 封口 `screen.mov` 时长 `256.490000s`，所有进程正常结束。
- 产品路径一：模型只调用一次 `ask_user` 并停在等待态，UI 展示清晰问题、`blue`/`green` 选项、文本框、`Don't answer` 与 `Send`；选择 `blue` 后状态诚实显示 Answered，模型只恢复一次并正常收尾。等待卡片层级、橙色等待边界、选项按钮和 composer 空闲状态逐帧检查，无视觉阻断问题。
- 产品路径二：模型只调用一次 `ask_user` 询问是否继续迁移，选择 `Don't answer` 后状态显示 Skipped，不伪造 yes/no 决策；模型只恢复一次，给出可重述或不继续的诚实后续并正常收尾。
- 没有发现需要 stop-and-fix 的产品或代码缺陷；截图 `evidence/askuser-pending.jpeg`、`evidence/askuser-answered.jpeg`、`evidence/askuser-skipped.jpeg` 与完整摘要 `evidence/tool-010-ask-user-session-summary.txt` 已封存。
- 五通道收台：`backend.log` 无 WARN/ERROR/panic/fatal；`frontend.log` 仅已知 macOS foreground/IMK 平台噪声，无 Dart/Flutter/AXTree/RenderFlex/Unhandled Exception；`llm.jsonl` 16 个 HTTP 响应全为 200；`sse.jsonl` messages durable seq `1..28`、notifications `1..2` 单调，entities 持续连接；LLM wire 可见 ask_user 调用与两个恢复回合。
- `judge.py` 在锚点校准通过、警报先验干净的 `RIG_HOME=/tmp/anselm-rig-formal-20260801-3` 下独立落账 `TOOL-010 ask_user` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。裁决后 `gap-too-fast` 与 `discovery-collapse` 按机制打开；复审确认完整录像、三张状态图、五通道 journal 和正/负路径均真实存在，写入复审 note 后 ack，最终 `alarms.py check` 为 `clean (90 judgments on record)`。
- 第二批从 **35 / 50** 推进至 **40 / 50**；当前前线为下一未裁决格 `TOOL-011 todo_write`。未到第二批 50 格不跑统一长门禁、不提交。

## 2026-08-01 · 第二批 TOOL-012 todo_read 与批次边界

- `TOOL-012 todo_read` 使用已收台的真实会话 `/tmp/anselm-rig-formal-20260801-28/sessions/20260801-064406` 作为独立覆盖项：前一条路径读回 1 个 completed + 2 个 pending，后一条路径在 3 个全部 completed 后读回完整清单；两次均明确禁止写操作，第二次没有生成旧的未完成任务提醒。
- `judge.py` 独立落账 `TOOL-012 todo_read` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。L1/L2 使用 `tool-012-todo-read-session-summary.txt`，L3 使用完整 `screen.mov`，L4/L5 使用 `todo-completed.jpeg`；没有把 `todo_write` 的判定理由当作本项证据。
- 本会话五通道收台：录屏 `176.260000s`；backend 无 WARN/ERROR/panic/fatal；frontend 仅已知 macOS foreground/IMK 平台噪声；LLM 26 个响应全 200；messages durable seq `1..64`、notifications `1..2` 单调，entities 已连接；证据摘要和截图已封存。
- 裁决后 `gap-too-fast`、`pass-burst`、`discovery-collapse` 三条统计警报按机制打开；逐项复审真实录像、负路径、五通道 journals 与锚点校准后 ack，最终 `alarms.py check` 为 `clean (100 judgments on record)`。
- 第二批从 **40 / 50** 达到 **50 / 50**；统一长门禁现在开始：`alarms.py check`、完整 `make verify`、完整 `go test ./...`、已修场景回归、testend、工作树审计和提交。门禁完成前不进入 `TOOL-013 search_tools`，不提交。

## 2026-08-01 07:17 · Goal/Loop 恢复

- 用户暂停后重新启用 Goal/Loop；Codex 盘上仍只有一个持久 `active` Goal，未创建副本，未启用并行 agent。
- 执行计划恢复为：第二批已完成 **50 / 50**，继续完成统一长门禁；门禁包含 `alarms.py check`、完整 `make verify`、完整 `go test ./...`、已修场景回归、完整 testend、工作树审计，全部通过后才一次性提交。
- 当前前线保持不变：门禁未全绿前不提交、不推进 `TOOL-013 search_tools`；本次恢复不改变任何产品判定或批次计数。

## 2026-08-01 07:48 · 第二批统一长门禁收口与 durable webhook ACK 修复

- 第二批已达到 **50 / 50**。按 `LOOP.md` 只在批次边界运行统一长门禁；没有把批次中的快速守卫测试冒充完整门禁。
- 首次执行 `make -C backend testend` 暴露真实失败：`TestTrigger_WebhookFiringSurvivesRestartBeforeDrain` 在 webhook 返回 `202` 后立即 `Kill9 → Restart`，durable firing 未能在 30 秒内出现。该失败稳定复现，证明不是 flaky test，也不是应该放宽的时序。
- 根因是产品/API 语义错误：`backend/internal/infra/trigger/webhook/webhook.go` 在 `go` 协程里调用 report，HTTP `202` 早于 Activation/Firing 持久化完成；硬崩溃可以丢掉用户已经收到“接受成功”的事件。
- stop-and-fix：`ReportFunc` 改为返回 `error`；`onReport`/`fanOut` 传播 AppendActivation、AppendFiring、RequeueMissedFiring 的真实错误；webhook 同步等待 durable audit/inbox 写入，成功才返回 `202`，失败返回 `503`；cron/fsnotify/sensor 的后台路径记录 report 错误。新增 `TestDispatch_DoesNotAcknowledgeBeforeReportReturns`，并同步 `docs/references/backend/api.md` 与 `docs/references/backend/domains/trigger.md` 的契约。
- 修复后专项回归：
  - `cd testend && mise exec -- go test -count=1 -timeout 10m -run '^TestTrigger_WebhookFiringSurvivesRestartBeforeDrain$' ./scenarios`：通过，约 `11.824s`。
  - `make -C backend testend`：通过，场景组约 `273.863s`。
  - `cd testend && mise exec -- go test -count=1 ./...`：通过，场景组约 `327.572s`。
  - `make verify`：backend、frontend、docs、demo 全部通过。
- 台架控制面最终复核：`RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/anchors.py check /private/tmp/anselm-rig-formal-20260801-3/anchor-answers.json` 通过 10 个锚点；同一 RIG_HOME 的 `alarms.py check` 为 `clean (100 judgments on record)`。默认 `~/.anselm-rig` 的空 journal 是一次未选台架上下文的空壳，未被用作本批次证据，也没有把它冒充成 100 条裁决。
- `git diff --check` 通过；本记录与代码/契约同步，最终工作树审计通过后已提交 `906c9971`。下一前线为 `TOOL-013 search_tools`，不在本批次门禁记录中提前裁决。

## 2026-08-01 08:10 · 第三批 TOOL-013 search_tools 真实工具切片与 stop-and-fix

- 首轮真实台架会话：`/private/tmp/anselm-rig-formal-20260801-29/sessions/20260801-075126`。真实 App、受管
  Anselm gateway、Computer Use、屏幕录像、backend journal、三路独立 SSE tap、LLM wire tap 均在线。
  现场要求模型先用 `search_tools` 找到只读 function search，再激活并调用 `search_function`；后端真实回执是
  `loaded_tools[{name,purpose}]`，但前端只识别旧的 `tools[{description,parameters}]`，成功结果错误地显示原始
  JSON，未达到可读产品状态，前线冻结，未使用该会话裁绿。
- 同一首轮还发现 transcript 的 lazy builder 在 `childCount` 与 builder 回调之间共享可变 `t.pending`，流式
  reconciliation 清空列表后触发 `RangeError(length): Invalid value: Valid value range is empty: 0`
  （`chat_transcript.dart:438`）。这也是产品台架红线，未降级为“偶发平台噪声”。
- stop-and-fix：`tool_card_memory_web.dart` 增加 `loaded_tools` 与旧 fixture 的兼容解析，命中卡片改为可读的
  工具名称/用途/下一请求 schema 状态，不再倾倒原始 JSON；`chat_transcript.dart` 在每次 build 取不可变
  pending 快照，`chat_transcript_test.dart` 增加 reconciliation 竞态回归测试；对应 widget 测试与 `flutter analyze`
  均通过。
- 修复后二次全新真实会话：`/private/tmp/anselm-rig-formal-20260801-29/sessions/20260801-080221`。
  命中路径显示 `Searched tools "search function read-only" · 5 tools`，展开可读命中卡片并在下一模型请求中
  实际调用 `search_function`；无命中路径使用 `zzz_nonexistent_acceptance_capability_9c31`，显示清晰的
  `No match`，没有误调用其它工具。关键画面为 `evidence/search-tools-hit-card.png` 与
  `evidence/search-tools-no-match.png`，完整五通道摘要为 `evidence/tool-013-search-tools-session-summary.txt`。
- 五通道收台：`screen.mov` `155.068333s` 且可读；backend 无 WARN/ERROR/panic/fatal；frontend 无
  FlutterError、RenderFlex、DartError、AXTree 或 unhandled 错误，仅已知 macOS foreground/IMK 平台噪声；
  LLM 14 个响应全 HTTP 200。LLM wire 的 `00002` 仅提供 `search_tools`，`00003` 下一请求同时提供
  `search_function`，并真实完成命中与无命中两条调用链。SSE 共 243 条记录，messages durable seq `1..36`、
  notifications durable seq `1..2` 单调，entities 已连接。
- 正确台架 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 的锚点校准通过，先验警报 clean；随后
  `judge.py` 独立落账 `TOOL-013 search_tools` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。
  统计警报按机制打开 `gap-too-fast` 与 `discovery-collapse`；逐项重审完整录像、首轮红线与修复记录、命中/无命中
  截图、LLM/SSE/backend/frontend 五通道后写入复审 note 并 ack，最终 `alarms.py check` 为
  `clean (105 judgments on record)`。
- 第三批从 **0 / 50** 推进至 **5 / 50**；下一前线为 `TOOL-014 search_function`。未到第三批 50 格不跑统一
  长门禁、不提交；本批代码、测试、COVERAGE 与本日志留在工作树，待第三批边界统一收口。

## 2026-08-01 08:22 · 第三批 TOOL-014 search_function 真实工具切片

- 台架先查出一次旧数据目录的受管 key 仍指向上一轮 `:8815`，而本轮 llmtap 在 `:8788`；该 session 被
  `rig-check` 的 channel-5 wiring 物理拒收并收台，未用于产品裁决。随后使用全新数据目录和全新注册流程重启：
  `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-081207`，`rig-check` 五通道全绿。
- onboarding 创建真实 workspace `Acceptance Tool Search` 后，通过本地真实 API 构造最小 ready fixture
  `acceptance_search_probe`（`fn_d9eb9300387ec1c8`），描述和 tags 覆盖 acceptance/search/fixture。fixture
  只负责构造检索前置数据，所有验收判断仍通过真实 App 对话完成。
- 首轮 Computer Use 输入错误地把两个草稿拼成一条消息；该控制事故没有被掩盖，明确从验收证据中排除。它之后
  重新开干净对话，逐帧覆盖：`acceptance` 命中；空 query 列出全部 function；`FIXTURE` 大写 query 通过
  tag 的大小写不敏感匹配；`zzznonexistentacceptance9c31` 明确 no-match。命中卡片/表格显示真实 `fn_` id、
  name、description，no-match 显示 name/description/tags 均无匹配；整个操作保持只读。
- 五通道收台：`screen.mov` `506.090000s` 可读；backend 无 WARN/ERROR/panic/fatal；frontend 无 FlutterError、
  RenderFlex、DartError、AXTree 或 unhandled exception，仅已知 macOS foreground/IMK 平台噪声；LLM chat 48
  个响应全 HTTP 200，challenge/install/models 也全 200；messages durable seq `1..128`、entities `1..2`、
  notifications `1..15` 均单调；关键画面为 `evidence/search-function-hit.png` 和
  `evidence/search-function-no-match.png`，完整摘要为 `evidence/tool-014-search-function-session-summary.txt`。
- 正确台架锚点校准通过、警报先验 clean；`judge.py` 独立落账 `TOOL-014 search_function` 五格：L1 `G1`、
  L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。裁决后 `gap-too-fast` 与 `discovery-collapse` 打开，逐项复审
  506 秒录屏、负路径、首轮排除说明、两张截图和五通道 journal 后写入 note 并 ack，最终 `alarms.py check`
  为 `clean (110 judgments on record)`。
- 第三批从 **5 / 50** 推进至 **10 / 50**；下一前线为 `TOOL-015 get_function`。未到第三批 50 格不跑统一
  长门禁、不提交。
