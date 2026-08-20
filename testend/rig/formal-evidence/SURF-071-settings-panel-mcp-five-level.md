# SURF-071 · settings/panel-mcp

## 判定

`pass`。真实 macOS App 中完成 MCP 设置面的主要产品闭环：空态市场、市场搜索与安装计划、手动 stdio 失败配置、SSE/Streamable HTTP 表单切换、失败详情的 Tools/Call history/stderr 三个审计面、有效 `mcp.json` 导入、重复导入跳过、软删除确认与清理回归均可达且反馈诚实。没有发现需要 stop-and-fix 的功能、数据、视觉或可发现性缺陷。

本轮没有修改 MCP 产品代码。Computer Use 的中文输入法会把部分标点映射为全角符号，导致第一次粘贴尝试被正确拒绝为非法 JSON；切换到英文输入法后同一配置成功导入，因此该现象归类为台架输入方法，不记为产品缺陷。

## 真实 App 路径

- Clean session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-232740`
- Data: `/private/tmp/anselm-data-surf071-20260819-r1`
- Workspace: `ws_470266a26e97918d` (`Acceptance SURF-071`)
- App window: `53176`, recorder region `80,40,1280,792`

真实走查步骤：

1. 首次进入 MCP servers，观察加载骨架后收敛为空态市场；页面给出 `Install your first MCP server from the marketplace`，市场显示 `0-100 of 102 items`，双列卡片、描述和 prerequisite 标签布局稳定。
2. 用真实键盘在市场搜索框输入 `context7`，结果收敛为对应单卡；打开计划页，确认全名、stdio/node runtime、必填 `CONTEXT7_API_KEY`、secret 输入和 Install/Cancel 结构；未提交外部凭证，取消计划返回市场。
3. 打开 Add manually，分别切换 stdio、sse、streamable-http；stdio 显示 command/args/env，后两者显示 URL/headers，字段切换没有残留错误布局。
4. 提交本地不存在的 command，服务器立即落为 `failed`；列表显示 `1 servers · 1 failed` 和具体 `sandboxapp.Spawn ... env not found` 错误，而不是伪装成成功。
5. 打开失败服务器详情，确认 Reconnect/Delete、Last error，以及 Tools `0`、Call history、stderr 三个标签；分别进入后得到 `No tools`、`No calls yet`、`No output yet`，没有空白死区或错误崩溃。
6. 导入有效的 `mcpServers` JSON，收到 `Imported 1 · skipped 0`，新失败服务器出现在两列 roster；再次导入同名配置，收到 `Imported 0 · skipped 1`，没有重复行。
7. 打开删除确认，文案明确说明 `soft delete`；确认后行消失，页面回到空态市场，已删除服务器不再出现在 roster。
8. 每次 Computer Use 动作后均重新读取 accessibility tree，并用截图复核布局；没有依赖 stale element index 或上一轮进程内状态。

## 五通道证据

1. **Frame**：`screen.mov` 和 `recording-lifecycle.json` 覆盖空态市场、计划页、失败卡、详情三标签、导入成功/跳过、删除确认和删除后的空态回归；manifest 绑定同一 App PID `29801` 与窗口 `53176`。
2. **Backend**：clean session `backend.log` 共 `660` 行，无 WARN / ERROR / panic / FATAL；失败 spawn、导入、重复跳过和软删除均由真实 API 写入并返回。
3. **SSE**：独立 `ssetap` 发现并连接 `messages`、`notifications`、`entities` 三条流；捕获两次 MCP entity connecting→failed 状态帧、两次 `mcp.installed`、两次 `mcp.removed`，durable notification seq 为 `1..4`，未见幽灵删除或漏帧。
4. **Frontend terminal**：`frontend.log` 仅有 direct App/Flutter VM 启动信息、CapsLock 宿主行和已知 `IMKCFRunLoopWakeUpReliable` macOS IMK 噪声；无 Dart / Flutter / assertion / overflow / unhandled 红线。
5. **LLM wire**：`llm.jsonl` 记录真实 managed gateway challenge/install/models/quota 请求均为 `200`；本格没有不必要的模型调用或凭证提交，市场计划中的外部 API key 未发送。

`rig-check` 在 App 运行期间通过：backend listener 归属、ssetap、llmtap、App PID/窗口归属、录制区域和 recorder lifecycle 六项均通过。

## 本地验证

- `mise exec -- flutter test test/features/settings/s4_mcp_test.dart test/features/settings/mcp_calls_repository_test.dart test/features/settings/provider_market_test.dart test/features/settings/settings_shell_test.dart test/features/settings/settings_demo_fixture_test.dart`：通过，`47 tests`。
- `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 RIG_SESSION=/private/tmp/anselm-rig-formal-20260819-232740 bash testend/rig/rig-check.sh`：通过，五通道 physically observing。
- `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 RIG_SESSION=/private/tmp/anselm-rig-formal-20260819-232740 bash testend/rig/rig-down.sh`：通过，录制封存 `564.475s`。
- `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/alarms.py check`：本格前置状态 clean；五格写入后按机制重新检查并复核告警。

## 法条

- `F1`：列表状态、失败原因、导入计数、跳过计数和删除结果与后端实体/SSE 帧一致，没有用 UI 乐观状态替代事实。
- `F2`：MCP 状态变化由 entities stream，安装/删除由 notifications stream 见证；三流职责没有混用。
- `F3`：失败服务器保留可解释错误，工具/调用/stderr 空态各自说明“没有什么”，不把不可用服务渲成空白成功页。
- `B2`：加载骨架、市场、计划、失败卡和删除后空态均收敛到稳定布局，没有跳变、遮挡或 stale 状态残留。
- `C4`：市场双列卡片、失败卡红线、状态点、详情标签和确认对话框的层级、间距与圆角连续；没有发现不等高或不舒服的高亮/状态块。
- `G1`：空态直接给出市场入口，市场卡可打开计划，失败态给出 Reconnect，详情提供工具/调用/stderr 追查面，删除前明确 soft delete；用户不读文档也能完成下一步。
