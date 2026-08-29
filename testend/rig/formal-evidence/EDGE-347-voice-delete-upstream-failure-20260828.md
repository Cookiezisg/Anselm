# EDGE-347 音色删除上游失败保行

## 结论

`EDGE-347` 的 L2 真实产品验收通过。真实 Flutter App、真实
`https://api.anselm.website`、Computer Use、三路 SSE witness、LLM tap、后端
journal、前端日志和 SQLite 均已纳入同一台架 session。首轮故障先冻结并修复，
修复后才继续正向重试。

## 台架

- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-235829`
- data=`/private/tmp/anselm-data-edge347-fix2-20260827`
- screen recording=`418.725000s`
- workspace=`ws_a0c08e8dc49d9a60`
- local voice id=`vce_0d72f2bb4e897271`
- voice name=`edge347-delete-failure-fix`

## Stop-and-fix

测试 fixture 只改变了本地 voice 行的 `upstream_id` 为不存在的
`vce_missing_edge347_failure`，没有伪造网关响应。第一次从真实 App 删除时，LLM
wire 的 `POST /v1/voices:delete` 返回 `404`，后端
`DELETE /api/v1/voices/vce_0d72f2bb4e897271` 返回 `503`；SQLite 行仍在。

首轮暴露产品问题：失败说明只在短暂通知里出现，危险区没有持久说明，且旧中文
文案把 Markdown `**` 直接交给普通文本控件。修复为危险区和顶部都显示
“上游登记没能删掉，音色仍保留，可以重试。”，并增加 Flutter 回归断言；定向
Flutter 测试 13/13、`flutter analyze`（仅既有 info）、macOS debug build 均通过。

随后恢复原始上游句柄
`vce_0e09bab21961268f8570c382d02a6821`，重新启动标准台架并通过 Computer Use
在确认框中重新输入精确名称。错误的自动化输入曾造成重复文本并被按钮拒绝，已
关闭确认区、重新打开组件后以真实键盘输入一次，未绕过产品确认门。

## 修复后结果

- screen/AX：确认框中的名称精确为 `edge347-delete-failure-fix`；提交后最终
  显示“还没有克隆音色。让助手用一段音频附件登记一个。”和“还能留 2 个(共 2)”。
- LLM wire：`00005_v1_voices:delete` 的请求体为原始上游 id，响应 `204`；此前
  `00003_v1_voices:delete` 的不存在 id 响应 `404` 保留为红证据。
- backend journal：修复后
  `DELETE /api/v1/voices/vce_0d72f2bb4e897271` 为 `204`，随后
  `GET /api/v1/voices` 返回空列表；没有 panic、fatal 或未解释的 ERROR。
- SQLite：`select id,name,provider,upstream_id from voices` 返回空集。
- SSE：独立 witness 从启动到收台同时连接 `notifications`、`messages`、`entities`，
  没有连接缺失或断点；该操作没有产生需要伪造的 durable SSE 变更帧。
- frontend console/log：仅有 Flutter VM service 启动行，没有
  `RenderFlex`、`Unhandled`、`Exception`、`ERROR` 或 `fatal`。
- `rig-check`：五通道物理观测通过；`rig-down`：录屏正常收尾且无残留进程。

## 裁决边界

本证据只支持 L2 的“上游失败时本地保行、修复后可重试并最终删除”目的。没有把
一次具体删除流程扩展宣称为顺滑、视觉 craft 或可发现性证明，因此 L3、L4、L5
仍保持 `na`，分别待相应产品观察后再判。

法条：`F1`（数据真相由 SQLite、REST、UI、SSE/后台和 LLM wire 交叉核对）。
