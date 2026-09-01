# EDGE-281 skill 安装炸弹护栏：真实 App 现场记录

- 日期：2026-09-01
- 现场：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-111047`
- 结论：**不判绿，保留开放**
- 阻断：Computer Use 对 Flutter `AnInput` 的粘贴/AX set 不能可靠改变实际编辑器值；直接键入会丢失 ASCII 标点。没有把这类观察器输入限制冒充产品结果。

## 已验证

- 真实 macOS App 已启动并由录屏、frontend console、backend、三路 SSE witness 和 LLM
  recorder 同场归属；`rig-check.sh` 通过，`rig-down.sh` 已封存会话。
- App 的 Library → Skills → `Install skills from a source` 入口可达，安装前安全说明
  清楚说明联网取文件、落入 library 以及工具预授权含义。
- 本机测试源稳定返回超过 `100 MiB` 的响应；同一 session 中直接调用
  `POST /api/v1/skills:inspect-source` 返回 `422 SKILL_INSTALL_TOO_LARGE`，details 为
  `limit=archive bytes`、`max=104857600`；没有安装 Skill，也没有写入 library。
- 后端和前端 session journal 没有应用级 panic、Flutter exception、overflow 或未处理异常；
  所有 owned processes 已在收尾时停止。

## 未判定

- 没有把 L2-L5 写入账本。真实 App 没有通过可复现的用户输入抵达超限结果画面，因而不能
  证明用户可见错误反馈的顺滑、视觉 craft 或发现性。
- `set_value`/`paste` 后 AX 树可报告 URL，但截图仍显示旧值或占位符；`type_text` 后截图
  能显示文字，却会把 `:`、`.` 等 ASCII 标点丢掉。该差异记录为 Computer Use 输入桥问题，
  不是产品 bug 结论。

## 代码与回归

- `backend/internal/infra/skillfetch/skillfetch.go` 在 gzip 解析前执行压缩字节上限，超限
  明确返回 `SKILL_INSTALL_TOO_LARGE`，避免截断 gzip 被误报为 `SKILL_INSTALL_FETCH_FAILED`。
- `backend/internal/infra/skillfetch/skillfetch_test.go:TestReadArchive_CompressedByteLimit`
  与原有 symlink、条目数、解压累计上限测试均通过。
- `docs/references/backend/domains/skill.md` 已同步记录 `100 MiB / 200 MiB / 4096 / 1 MiB`
  四个阈值和错误语义。

