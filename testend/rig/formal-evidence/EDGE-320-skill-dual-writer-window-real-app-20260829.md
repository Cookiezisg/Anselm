# EDGE-320 · skill 双写者竞态 · 真实 App L2

## 场景

- 台架 session：`20260829-134830`
- 隔离数据目录：`/private/tmp/anselm-data-edge320-physical-20260829-r3`
- workspace：`ws_6f16fe1504cd83a4`
- 夹具：`edge320-race`
- 目的：在真实 Library 页面使用中心 body 编辑器与右侧 Properties 配置表单，确认两个 600ms 防抖写入者不会互相用旧快照覆盖。

## 操作与观察

1. 真实 App 打开 `edge320-race`，中心显示正文，右侧显示 `Arguments`。
2. 中心正文插入 `BODYCLEAN`，右侧 Arguments 提交 `cleanarg`，随后等待防抖写入完成。
3. REST 真相读取到 body 包含 `BODYCLEAN`，frontmatter arguments 为 `["cleanarg"]`。
4. 离开该 skill 进入 `commit-helper`，再返回 `edge320-race`。
5. 返回后真实 UI 同时显示正文 `BODYCLEAN` 与右侧 Argument `cleanarg`；没有出现一侧恢复旧值、空白或页面重挂。截图保存在 session `evidence/EDGE-320-reopened-skill.jpeg`。
6. 后端 journal 的两次完整 `PUT /api/v1/skills/edge320-race` 均为 HTTP 200（`13:50:44.593`、`13:50:44.993`）；随后 GET 在 `13:51:08.426` 返回同一 body/frontmatter。播种请求中的一次故意格式错误为 HTTP 400，未产生夹具或数据副作用，不属于产品路径。

## 判定

- L2 通过：两个写入者的改动均可从真实 UI 重进恢复，并与 REST body/frontmatter 逐字段一致。
- 这证明的是持久化保留和恢复，不宣称 Computer Use 的逐动作采样能证明数据库层面的纳秒级并发顺序。
- 已知取舍仍成立：两个独立的 read-modify-write 窗口由 600ms 防抖控制；若未来需要严格事务合并，应另立设计和验收项，不能由本格偷换结论。

## 五通道

- frames：真实 App 录屏约 `94.406667s`，收台前无遮挡，含返回后的关键帧截图。
- backend：session `backend.log`，PUT/GET 均成功且无应用级 WARN/ERROR。
- SSE：session `sse.jsonl`，三条 workspace 流由独立 ssetap 见证。
- frontend：session `frontend.log`，无 Flutter/Dart/RenderFlex/Unhandled 应用级红线；唯一 `IMKCFRunLoopWakeUpReliable` 为 macOS 输入法框架诊断信息。
- LLM：session `llm.jsonl` 与 request/response 文件，启动握手完整；本场景没有把模型自述当作产品真相。
