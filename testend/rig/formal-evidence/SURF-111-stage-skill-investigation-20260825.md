# SURF-111 stage/skill investigation

## Scope

验收 Skill 舞台的完整产品闭环：创建 skill、读取 SKILL.md 元数据与 Markdown 正文、展示 allowed-tools 与参数占位符、安装来源的信任门未批/已批差异，以及真实 `activate_skill` 的 `$1`、`$ARGUMENTS`、`${CLAUDE_SKILL_DIR}`、`${CLAUDE_SESSION_ID}` 展开。

## Static contract

- `SkillStageBody` 将 SKILL.md 分成 metadata header 与真实 Markdown prose；live 使用 prose tail，settled 使用全文排版和有界折叠。
- API/user-created skill 的 allowed-tools 可直接显示为生效预授权；installed skill 的 allowed-tools 在 `toolsApproved=false` 时只能显示为中性请求，必须显示“信任门未批,确认仍逐次”，批准后才显示琥珀“激活后免危险确认(预授权)”。
- `activate_skill` 支持 `$1..$n`、命名参数、`$ARGUMENTS`、`${CLAUDE_SKILL_DIR}` 与 `${CLAUDE_SESSION_ID}`；带捆绑文件而正文没有目录占位符时才补目录前导，本次正文已有显式目录占位符。

## Real run

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-101708`
- workspace: `ws_b3580596c9dfb602`
- recording: `screen.mov`, finalized `531.340000s`, `2784x1808`
- created skill: `surf111runbook` (inline, human-only, Read + edit_document)
- installed probe: `surf111-installed`, source `http://127.0.0.1:8991/surf111-source2.tar.gz`

### Positive paths

1. 真实 App 创建 `surf111runbook`，结果卡与右侧 stage 显示 inline、仅人可唤、Read/edit_document、参数槽和正文；Computer Use 输入桥丢失 `$`/下划线的初始 body 被识别为仪器边界，不冒充精确内容。
2. 通过本地 REST 真相面修正同一已创建 skill 的精确 body，并补入 `references/notes.md`。App 随后用真实 `get_skill` 读取，主内容和 stage 均显示完整 Markdown、literal placeholder markers、参数 `target` 和人类触发语义。
3. 真实 App 通过 `activate_skill` 传入 `daily`、`review`。最终画面与右侧 stage 显示：`$1 → daily`、`$ARGUMENTS → daily review`、真实 skill directory `/private/tmp/anselm-data-surf111-20260825-r1/workspaces/.../skills/surf111runbook/references`、真实 conversation/session ID；未创建或编辑实体。
4. 本地 tarball 先经 `inspect-source`，再安装 `surf111-installed`。REST readback 证明 `source=installed`、`allowedTools=[Read,edit_document]`、`provenance.toolsApproved=false`。App 读取后舞台明确显示“已请求预授权·信任门未批,确认仍逐次”，工具 chip 为中性。
5. 通过 `approve-tools` 将该 installed skill 的 provenance 改为 `toolsApproved=true`；App 新回合重新读取后，舞台才显示“激活后免危险确认(预授权)”与琥珀工具 chip。信任门前后视觉语义没有提前泄漏。

## Product verdict

用户可以看懂 skill 能做什么、接受什么参数、是否仅人工触发，以及 allowed-tools 是否已经获得信任授权；激活后的占位符和目录锚点都展开为真实值。未批安装不会被包装成已授权，批准后才改变视觉语义。该格可进入五级账本。
