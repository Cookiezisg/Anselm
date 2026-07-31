---
id: WRK-086-LOG
type: working
status: active
owner: @weilin
created: 2026-07-31
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
landed-into:
---

# WRK-086 · 文档治理日志

> 仅追加已确认事实。猜测、计划和未复现问题留在 [`CHARTER.md`](CHARTER.md) 的批次/frontier，不写入本日志。

## 2026-07-31 · PREP-000 · Goal 启动基线

- 起点 commit：`43a7b17ee90b5227d4490657ede5bc6871b4642a`（`docs: record post-focus backend regression gate`）。
- tracked Markdown：161；`docs/` Markdown：150。
- `docs/` 分布：archive 56、references 44、working 26、decisions 20、root 2、how-to 1、concepts 1。
- 初始 `make -C docs verify` 在治理草稿产生前通过，带 1 条 warning：12 对 anchored DTO 完成镜像检查，21 个 anchor 因无同名 Go struct 跳过。此 warning 尚未裁决为缺陷。
- 已确认结构问题：
  - `docs/working/backend-evolution/archived/` 含 7 篇仍声明 `type: working / status: active` 的历史材料。
  - 当前受治理树可见重复 ID：`WRK-026` 与 `WRK-070`；另有 archive 与 working 重复，现有门禁不查唯一性。
  - `working/frontend/` 有 12 篇，其中多篇正文已明确写“全落/归档”，仍保持 active。
  - `docs/references/frontend/architecture.md` 仍称“重建中”；`concepts/architecture.md` 仍称右岛/人在环/工具卡在建。
  - 当前代码有 chat/entities/library/notifications/scheduler/settings 六个 feature，但缺完整 Chat、Scheduler current reference。
  - `frontend/README.md` 仍称 feature 是 future，和物理目录冲突。
  - `working/frontend/README.md` 同时承担协作规范、进展、路线与历史索引，且把已完成工作继续作为活入口。
  - 平台已落事实与未实施、具时效性的发行研究混在 `working/platform-foundation/`。
- Goal 启动前有 5 份未提交前端治理草稿，已在 CHARTER §8 隔离；必须在 G1 重新核对，不能计为完成证据。

## 2026-07-31 · G0-001 · 结构门禁与单一 archive

- `backend/cmd/docs` 新增低误报结构门禁：`DOC-NNN` / `WRK-NNN[-SLUG]` 语法、受治理区 ID 唯一、三个 frontmatter 日期格式、canonical 目录/type 对齐、`status: archived` 位置、working 必备 `landed-into`、working 私有 `archive|archived|legacy|old` 子树禁令。
- 新增 `main_test.go` 五组 fixture，分别校准合法树、重复 ID、type/status 错位、私有墓地/缺字段、非法 ID/日期；`go test ./cmd/docs` 与 `go vet ./cmd/docs` 通过。
- 新门禁首次对真实仓库打出 25 个错误：17 篇 working 缺 `landed-into`、7 篇旧 iteration 位于 `working/backend-evolution/archived/`、2 组重复 ID（重叠计数）。逐项修复后 `make -C docs verify` 恢复通过。
- 旧 iteration 七篇材料迁入唯一墓地 `docs/archive/backend-evolution-v1/`，保留历史 frontmatter 并标 `status: archived` / `landed-into`；current HISTORY、README 与 testend R23 链接已改到新路径。
- GOVERNANCE §3/§4/§5/§11 与 CLAUDE 文档门禁摘要同步到实际实现；同时纠正 GOVERNANCE 旧文中“ADR git 历史已机械校验”的不实陈述——该项仍靠人工清单。
- 当前唯一 warning 仍是 DTO 镜像覆盖统计（12 checked / 21 skipped），留待 G1/G5 依据类名投影语义逐项裁决。

## 2026-07-31 · G1-001 · 前端入口、缺失事实源与施工面退役

- 逐项核对 `frontend/lib/app/router.dart`、`app_shell.dart`、六个 `features/*`、`core/*`、三平台宿主、`pubspec.yaml`、前端 Makefile 与测试目录；确认产品当前有 Chat、Entities、Library、Scheduler 四个业务海洋、Settings 设置海洋与 Notifications 跨壳能力。
- 新增 Chat、Scheduler 与平台层 current reference；重述前端 overview、architecture、Entities reference 与 `frontend/README.md`，修正旧文中的 `features/documents`、`/documents/*`、显式 `/chat` landing、旧海洋数量和“重建中/在建”描述。
- 路由事实已对齐：壳内 canonical 路由为 `/chat/:id`、`/library/:id`、`/library/skill/:name`、Scheduler 三级路由；`/scheduler/runs/:frId` 是 run-id 中继；Entities 关系图与 workflow 编辑器是两个壳外全屏页。
- 已完成的 12 篇前端施工材料全部填入 current 落点并迁入 `docs/archive/frontend-construction/`：Chat 主迭代、工具卡三册、Entities/Workflow、右岛两轮、Scheduler、sidestage 与旧 working hub。`docs/working/frontend/` 已物理消失。
- CLAUDE、INDEX、concept architecture 与 design-system 的 active 入口已改指 current reference，不再把已完成施工日志当当前协作入口。
- 代码核对发现 `frontend/lib/app/app_shell.dart` 仍有把已存在海洋称作“未建/即将推出”的源代码注释。它不改变运行时，但属于产品代码，按 CHARTER 的授权边界只登记、不在文档战役中修改。
- 验证：`make -C docs verify` 通过；`backend/` 下 `go test ./cmd/docs` 通过；active 文档中已无 `working/frontend`、旧 `/documents/*` 路由或“前端重建中”命中。DTO 镜像覆盖 warning 保持 12 checked / 21 skipped，未被隐藏。
- 本批只完成 G1 的入口、核心 current 面与归档；contract、design-system、Library、Notifications、Settings、Chat sidestage 的可读性与历史噪音仍需继续做 G1 对抗精炼，不能据此宣称 G1 完成。

## 2026-07-31 · G1-002 · 前端 current reference 全面精炼

- 重新按实际代码边界整体重述 contract、design-system、Library、Notifications、Settings 与 Chat sidestage；删除 current 文档里的施工批次、日期裁决流水、旧方案回顾、一次性测试数量和“全落/收官”陈述。
- contract 现在只维护 wire 投影地图、信封/分页、开放/封闭词表、消息版本语义和高风险三态；生成文件与完整类型清单由 `core/contract/` 自身承担，不在文档复制易漂移数量。
- design-system 现在只维护 token/原语/feature 的层级、选择表、三岛语法、焦点/a11y、流式/媒体纪律与验证入口；完整导出清单以 `core/ui/ui.dart` 为机械事实。
- 六个真实 feature 均有 current 入口：Chat、Entities、Library、Scheduler、Notifications、Settings；Chat 右岛因跨工具/运行/人在环复杂度保留独立 current reference。
- 高风险词扫描在 active 前端 reference 中只剩 Scheduler 对“占位冒充事实”的否定句，无施工状态命中；旧 `/documents/*`、`features/documents` 与 `working/frontend` 引用为零。
- 复核所有文档声明的测试目录/文件；修正重写时误换的 DOC ID（Library 保持 DOC-052、Chat sidestage 保持 DOC-051）与不存在的媒体测试目录。
- 验证：`make -C docs verify` 通过，`git diff --check` 通过；warning 仍为 12 个 DTO mirror pair checked / 21 个无同名 Go struct 的 anchor skipped。
- G1 完成。仍发现的 `app_shell.dart` 过时产品代码注释继续作为未授权代码 finding 保留，不影响 current 文档事实。

## 2026-07-31 · G2-001 · 已部署 API Serve 责任边界与易漂移复制收口

- 只读核对同级 `Anselm-API-Serve` 的 AGENTS、CLAUDE、INDEX/GOVERNANCE、中英文 README、deploy 文件树、公开 backend references、近期提交与当前工作树；该仓有用户正在收尾的未提交治理/实现改动，本战役未写入、未暂存、未提交其中任何文件。
- 主仓代码确认默认 managed base 由 `infra/llm/anselm.go` 持有，空配置直达生产 API，`ANSELM_GATEWAY_URL` 只作显式覆盖；`app/freetier`、`infra/deviceproof`、managed media/ASR/generation 客户端共同证明本地 sidecar 与部署服务已完整接缝。
- 主仓 backend-evolution 的真实 live 记录已在 2026-07-29 通过 managed provision/probe、`anselm-auto` 默认中文 chat 与终态，证明默认产品路径不要求本机 provider secret。
- 新增 `references/backend/managed-gateway.md`：本仓只登记 install/device-proof、managed 行、workspace 默认、附件/MediaRef、loopback API 与 BYOK 本地职责；API Serve 独占 provider secret、路由、费率/账本、部署/回滚/监控。明确默认路径不需要任何用户 provider key，`DASHSCOPE_API_KEY` / `ANSELM_DASHSCOPE_BASE` 不属于主仓启动配置。
- `foundation/stream-llm.md` 与 `domains/support-services.md` 整体重述，删除主仓对网关内部 provider 名单、模型数字、生成方言历史和配额实现的复制；managed/BYOK 只保留公开产品边界并链接新 reference。
- backend overview、concept architecture、INDEX 同步新边界；overview、database、error-codes 去掉易漂移的域/handler/provider/错误码手工总数。error registry 仍由 `cmd/docs/drift.go` 对具体 code 双向严格校验。
- `make -C docs verify` 通过；四索引漂移检测保持 error code 双向、event 双向/族、endpoint 资源词与 table 双向覆盖，warning 仍仅 DTO mirror 12 checked / 21 skipped。裸 shell `go test ./cmd/docs` 因系统 go1.26.2 与项目缓存/标准库 go1.25.11 混用失败；改用仓库锁定工具链 `mise exec -- go test ./cmd/docs`（go1.25.11）通过，确认是环境选择而非代码失败。
- G2 尚未完成：当前 backend reference 仍有大量 WRK/工单/批次历史标签，且 CLAUDE 当前快照复制了 API Serve 内部 provider 数字；后续批次必须继续整体重述，不能把本节视为 G2 完成。

## 2026-07-31 · G2-002 · 工程宪法恢复为稳定事实源

- 整体重述根 `CLAUDE.md`：保留项目定义、9 条设计原则、N/D/E/S/T 契约、前端守则和文档纪律，删除前后端施工流水、WRK 标签、provider/model/工具数量、一次性性能数字、真钱实验过程及 API Serve 内部实现复制。
- 当前能力改为短地图：系统架构、后端、前端、managed gateway、契约索引、working 与 archive 各指向唯一权威入口；多模态仍明确属于当前产品路径，具体机制由 backend/frontend reference 与 ADR 承担。
- 修正前端物理分层为 `lib/core → lib/features → lib/app`，删除不存在的 `shared/core`、`sse-gateway.md` 和强制多 agent 扇出流程；任务可按实际执行环境选择协作方式，不再由项目宪法硬编码代理编排。
- 同步重述 GOVERNANCE 的常驻执行层措辞、前端 canonical 文档地图与同步触发表；ADR 规则现在区分“不可改原决定正文”和“允许生命周期/前向元数据”，消除 §6 与收尾清单互相冲突。
- 验证：`make -C docs verify` 与 `git diff --check` 通过；warning 仍仅为 DTO mirror 12 checked / 21 skipped。
- G2 仍未完成：`concepts/architecture.md` 及 backend 四索引、domains、foundation 仍需逐篇清除建造史并复核当前代码。
