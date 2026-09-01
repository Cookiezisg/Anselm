# EDGE-283 · skill 路径穿越：修复后真实 App 台架验收

- 日期：2026-09-01
- 现场：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-115436`
- 结论：词法和物理路径逃逸均被安全拒绝；没有在 skill 根目录外产生文件。

## 现场事实

- 真实 App、conductor-owned backend、三路 SSE witness、LLM tap、frontend console 和窗口录屏属于同一
  session；`rig-check.sh` 与 `rig-down.sh` 均通过，录屏已封口，owned processes 已收尸。
- 在隔离 workspace 的已安装 `commit-helper` skill 下，真实请求分别尝试相对穿越、编码 dot-segment、
  编码绝对路径、反斜杠路径和指向临时目录的 symlink 目录。
- 修复前，symlink 目录写入会因 `os.Root.MkdirAll` 的 `file exists` 返回未映射错误，错误落为
  `500 INTERNAL_ERROR`；该红事实保留在本轮现场 backend journal 中，没有写入账本。
- 修复后五类请求全部返回 `400 SKILL_FILE_PATH_INVALID`，统一错误 envelope 为
  `invalid skill file path`；临时哨兵目录文件数为 `0`。
- 本路径是 files API 的安全边界，不是一个可由普通用户在 App 中输入任意目标路径的独立产品操作面。

## 五通道核对

- 帧：真实 App 在同场正常启动并保持可用，窗口录屏完整封口；本隐藏安全请求不产生独立 UI 状态。
- 后端：五个真实拒绝请求均有 backend journal，修复版无 panic/fatal/应用级错误。
- SSE：同场 `entities`、`messages`、`notifications` 三流真实连接并留有 journal；拒绝动作没有伪造
  skill mutation。
- 前端：`frontend.log` 无 Dart/Flutter/RenderFlex/RenderBox/Unhandled 应用异常。
- LLM：`llm.jsonl` 由透明 tap 持有；本场为 files REST 安全边界，不虚构 chat completion。

## 修复与回归

- `backend/internal/infra/fs/skill/skill.go` 将 `MkdirAll` 报告的 `EEXIST`/`ENOTDIR` 物理路径边界
  归一为 `ErrFilePathInvalid`，避免安全拒绝泄漏为 500。
- `backend/internal/infra/fs/skill/filetruth_test.go` 新增目录 symlink 写入断言；skill fs 与 HTTP handler
  focused 回归通过。
- `docs/references/backend/domains/skill.md` 已同步：物理 symlink/非目录父路径统一返回
  `400 SKILL_FILE_PATH_INVALID`。

## 判定映射

- L2 `F2`：同场真实 App、后端、SSE、前端 console、LLM wire 和封口录屏均可追溯。
- L3-L5：明确适用性 `na`。路径穿越是隐藏 files API 的安全/数据边界，没有独立用户交互时延、视觉
  craft 或发现入口；相关 skill 文件编辑体验由其他 files/editor 旅程承载，不能为本请求虚构产品层结论。
