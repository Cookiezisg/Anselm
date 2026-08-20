# SURF-072 · settings/panel-memory

## 判定

`pass`。本格在真实 macOS App、保留真实 workspace 数据、受管后端和五通道台架上完成了记忆面板的完整用户闭环：空态引导、非法 slug、合法值恢复、创建并置顶、All/Pinned 投影、搜索命中与无匹配、置顶切换、编辑锁名、内容保存、未保存离开保护、删除取消和最终物理删除均可达。

首轮真实走查发现两个必须 stop-and-fix 的产品问题，首轮不计绿：合法名称输入后旧的 slug 错误仍残留；详情页有未保存修改时点击面包屑直接离开。修复后重新构建真实 App 并复测：输入变合法后错误即时消失，面包屑与 Escape 统一经过 detail pop guard，`Keep editing` 保留详情，`Discard` 才返回名册。修复没有降低任何既有门禁。

## 真实 App 路径

- 修复前观察 session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-234423`（只作为红证据，不入账）
- 修复后验证 session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-235804`
- 删除收口 session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260820-000144`
- Data：`/private/tmp/anselm-data-surf072-20260819-r1`
- Workspace：`ws_be9766a8964b8449`（`Acceptance SURF-072`）
- 修复后录屏：`121.830000s` + 删除收口 `84.088333s`

真实走查步骤：

1. 在已有数据中打开 Memory，确认 All/Pinned、搜索框、New memory、两条已存在用户记忆和 pin 语义。
2. 新建记忆先提交 `Bad Name!`，页面就地显示明确 slug 规则且不创建实体；将同一字段改为 `valid-after-error` 后，红色旧错误立即消失。
3. 补齐必填描述与内容并保存，列表出现 `valid-after-error`、`Validation recovery`、`user` 和日期；SSE 收到同名 `memory.created`。
4. 打开 `safety-rule`，确认编辑态名称灰化锁定、没有 create-only Pinned switch；修改内容并保存后重新打开，内容持久化且 pin 保持。
5. 在详情中制造 `DRAFT` 未保存变更，点击 Memory 面包屑：出现 `Discard unsaved changes?` 与 `The content has unsaved edits.`；点击 `Keep editing` 留在详情，再次离开点击 `Discard` 才回到名册。修复后截图显示遮罩、按钮层级和正文均完整，没有跳变或丢失。
6. 在名册中测试 Pinned 投影、unpin/repin、搜索命中 `safety` 和无匹配 `does-not-exist`；无匹配显示明确 `No matching memories`，而不是空白死区。
7. 删除收口 session 中对 `valid-after-error` 打开删除确认，先点击 Cancel 验证行保留；再次打开确认，文案明确说明物理删除和不可撤销，点击 Delete 后行消失。

## 五通道证据

1. **Frame**：两个修复后 session 的 `screen.mov` 覆盖合法值错误恢复、编辑保护、删除取消/确认/完成；`recording-lifecycle.json` 和 `manifest.json` 绑定各自真实 App PID 与窗口区域。删除收口录屏为 `84.088333s`。
2. **Backend**：修复验证 session `backend.log` 为 `186` 行，删除收口为 `139` 行；没有 panic、fatal、exception、traceback、RenderFlex、RenderBox 或 unhandled 红线。`valid-after-error` 的 `400` 是空描述/内容的预期后端校验拒绝，随后补齐后 `200` 成功；不是服务故障。
3. **SSE**：独立 ssetap 连接 `messages`、`notifications`、`entities` 三流；修复验证捕获 `memory.created` durable notification，删除收口捕获同名 `memory.deleted`，两次均在真实 UI 变更后出现；三流均在台架收台时正常 EOF 断开。
4. **Frontend terminal**：修复验证 session `frontend.log` 仅 direct App、Dart VM 和已知 macOS IMK host 行；删除收口仅 direct App 与 Dart VM 行；无 Flutter/Dart assertion、未处理异常或布局溢出。
5. **LLM wire**：两个修复后 session 的 `llm.jsonl` 均由 llmtap 常驻并记录 ready；本路径是确定性的 Memory REST/SSE 路径，不需要模型调用，故不虚构 completion。`rig-check` 仍确认 llmtap 真实归属、workspace managed wiring 和 gateway 通道可用。

`rig-check.sh` 在 App 运行时通过五通道物理归属；`rig-down.sh` 两次均成功封存录屏并清理进程组。

## 本地验证

- `mise exec -- flutter test test/features/settings/settings_shell_test.dart test/features/settings/s4_memory_test.dart`：通过，`19/19`，包含新增的 Memory breadcrumb 未保存保护回归。
- `mise exec -- flutter test test/features/settings/s4_memory_test.dart test/features/settings/demo_fixture_test.dart test/features/settings/settings_demo_fixture_test.dart test/features/settings/settings_shell_test.dart test/features/settings/settings_search_test.dart`：修复后聚焦套件通过（结果写入同批日志）。
- `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 bash testend/rig/rig-check.sh`：两个修复后 session 均通过。
- `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 bash testend/rig/rig-down.sh`：两个修复后 session 均通过。

## 法条

- `G1`：错误、保存、离开和删除下一步都可被用户发现；非法 slug 给出规则，未保存离开给出 Keep editing/Discard，删除前给出物理删除警告。
- `F1`：列表、编辑详情和 SSE `memory.created`/`memory.deleted` 与后端事实一致，没有用乐观 UI 冒充保存或删除。
- `B2`：加载、空态、无匹配、详情遮罩和删除确认均收敛为稳定布局；修复前发现的绕过保护已被回归测试锁住。
- `C4`：pin lead、列表行高、表单字段、确认对话框和遮罩层在录屏中保持等高、对齐、可读，没有发现视觉级 stop-and-fix 缺陷。
- `G1`：Memory 空态直接告诉用户“Add your first memory”，列表提供 All/Pinned/Search/New，行操作与详情入口不需读文档即可发现。
