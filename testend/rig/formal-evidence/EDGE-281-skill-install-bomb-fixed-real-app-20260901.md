# EDGE-281 · skill 安装炸弹护栏：真实 App 修复后验收

- 日期：2026-09-01
- 现场：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-112213`
- 结论：真实 App 的超大来源检查路径已达到本次五级判定标准；未执行安装。

## 现场事实

- `rig-up.sh` 启动并持有真实 macOS App、后端、三路 SSE witness、LLM tap 和窗口录制；
  `rig-check.sh` 五通道通过，`rig-down.sh` 封存录屏，owned processes 已收尸。
- Computer Use 依次打开 `Library → Skills → Install skills from a source`，来源框显示
  本场本机测试来源，然后点击 `Inspect source`。
- 来源为 `101 MiB` 的本地 fixture；真实后端日志记录同场
  `POST /api/v1/skills:inspect-source` 返回 `422`，耗时 `145ms`，响应大小 `158` bytes。
  该响应语义为 `SKILL_INSTALL_TOO_LARGE`，压缩来源上限为 `104857600` bytes。
- App 稳定帧见
  `sessions/20260901-112213/evidence/edge281-oversize-error.jpeg`：弹窗保留来源值，
  `Inspect source` 下方显示清晰红色错误文案 `the skill source exceeds the install size limits`；
  无空白、无布局溢出、无安装候选、无虚假成功 toast。
- 未点击 Install，没有 Skill 写入或删除；本机来源服务只提供 fixture 文件。

## 五通道核对

- 帧：录屏封口可读，稳定帧保存在同场 evidence 目录。
- 后端：`backend.log` 的同场 HTTP 记录为 `422`，无 panic/fatal/应用级异常。
- SSE：`sse.jsonl` 同场连接 `entities`、`messages`、`notifications` 三流；本动作未产生伪造
  的 Skill mutation。
- 前端：`frontend.log` 无 Dart/Flutter/RenderFlex/Unhandled 异常。
- LLM：`llm.jsonl` 同场由透明 tap 持有；该纯 REST 负向路径不需要虚构 chat completion。

## 代码与回归

- `backend/internal/infra/skillfetch/skillfetch.go` 在 gzip 解析前执行压缩字节上限，超限明确
  返回 `SKILL_INSTALL_TOO_LARGE`，避免截断 gzip 被误报为 fetch failure。
- `backend/internal/infra/skillfetch/skillfetch_test.go:TestReadArchive_CompressedByteLimit`
  与原有 symlink、条目数、解压累计上限测试通过。
- `frontend/test/features/library/library_test.dart` 验证台架预填只在显式构造参数下出现；普通
  `SkillInstallDialog()` 仍为空输入。台架用 `--dart-define` 传值，manifest 只记录配置布尔值，
  不记录来源地址。
- `docs/references/backend/domains/skill.md` 与 `testend/rig/README.md` 已同步阈值、错误语义和
  台架入口。

## 判定映射

- L2 `F2`：同场真实 UI、后端、SSE、前端 console、LLM wire 和封口录屏均可追溯。
- L3 `B2`：inspect 请求完成后 UI 在单一弹窗内收敛到错误态，不跳页、不重排、不持续 loading。
- L4 `C4`：错误态留在输入控件下方，红色层级清楚，来源值和操作上下文不丢失；稳定帧可复核。
- L5 `G1`：新用户可从 Skills 类型头的下载入口进入，Inspect 命名与错误文案直接说明下一步
  失败原因；不需要内部错误码知识。
