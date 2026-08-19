# SURF-063 · settings/rail-resources

## 判定

`pass`。本项验证资源目录段的五个真实面板（Models & keys、MCP servers、Memory、Sandbox、Workspaces）是否可发现、能落到诚实的 loading/empty/settled 状态，并且受管资源与当前 workspace 的显示不互相污染。没有发现需要 stop-and-fix 的产品缺陷。

## 真实 App 路径

- Session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-211359`
- Data: `/private/tmp/anselm-data-surf063-20260819-r1`
- Workspace: `ws_627041276bc74cad` (`Acceptance SURF-063`)
- 全新 workspace onboarding 后进入 Settings，Resources 目录段真实包含 Models & keys、MCP servers、Memory、Sandbox、Workspaces。
- Models & keys：managed `Anselm Free · Auto multimodal`、配额显示、cloned voices 的 settled-empty 与 `2 of 2 slots free`、managed key、六个 scenario default model 行、Search keys 的 empty state 均可见；没有把 key secret 渲染到画面。
- MCP servers：首次进入先显示 loading rows；随后落为真实 marketplace 名册，AX 显示 `0-100 of 102 items`，同时保留 `Add manually` 与 `Import mcp.json` 两个入口。空的已安装 server 名册没有被伪装成错误。
- Memory：显示 `New memory` 与“Add your first memory”空态，未显示旧 workspace 内容。
- Sandbox：显示 `Disk usage 0 B`、Runtimes 的 `Install`、`No runtimes yet`、五类 owner environment tabs、`No environments` 与 `Reclaim all now`；空磁盘是合法 settled-empty，不是请求失败。
- Workspaces：显示当前真实 workspace、蓝色状态点、`Current` 标记与 `New workspace` 入口；目录/面板切换无重叠、截断或横向跳变。

关键帧：

- `evidence/SURF-063-models-keys.png`
- `evidence/SURF-063-mcp-market.png`
- `evidence/SURF-063-memory-empty.png`
- `evidence/SURF-063-sandbox-empty.png`
- `evidence/SURF-063-workspaces.png`

## 五通道证据

1. **Frame**：`screen.mov` 由 conductor 正常收束，最终时长 `133.883333s`；关键资源面板帧已封存。
2. **Backend**：`backend.log`=`196` 行；无 panic / fatal / exception / stack trace / RenderFlex / RenderBox 应用红线。
3. **SSE**：`sse.jsonl`=`4` 行；三条流在 rig-check 中真实连接，本项没有聊天/实体耐久 mutation，不伪造业务帧。
4. **Frontend terminal**：`frontend.log`=`4` 行；仅正常 App 启动、Flutter VM 与一个已知 macOS 输入法宿主噪声，无 Flutter / Dart / assertion / overflow / unhandled 红线。
5. **LLM wire**：`llm.jsonl`=`13` 行，managed proof challenge / install / models 真实返回 `200`；资源目录路径没有模型 completion，不伪造 completion 证据。

`rig-check` 在 App 运行期间证明五通道归属：backend PID=`7873` 持有 `:9081`，ssetap PID=`7900`，llmtap PID=`7846`，App PID=`8374`，recorder PID=`8416`。rig-down 后无 App/backend/tap/recorder 残留。

## 本地验证

- `mise exec -- flutter test test/features/settings/settings_catalog_gate_test.dart test/features/settings/settings_search_test.dart test/features/settings/settings_shell_test.dart`：此前本批共同设置 gate `42/42` 通过。
- 资源面相关 focused Flutter tests 与 `dart analyze`：通过。
- `python3 testend/rig/gen_coverage.py --check`：通过，848 rows，无 tombstone。
- `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/alarms.py check`：clean。
- `git diff --check`：通过。

## 法条

- `G1`：五个资源面板均从 Settings Resources 目录直接可发现，空态仍提供下一步入口。
- `F1`：managed key、MCP marketplace、memory、sandbox 与 workspace 画面均与同 session backend/SSE/REST 观察一致。
- `B2`：loading → settled、空态和面板切换保持稳定，没有把资源列表压成不可读的窄条或造成布局跳变。
- `C4`：配额、managed 身份、音色槽位、空资源与重试/安装入口使用可行动的人话，不把内部 ID 或 secret 暴露给用户。
