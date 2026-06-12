---
id: WRK-009
type: working
status: active
owner: @weilin
created: 2026-06-12
reviewed: 2026-06-12
review-due: 2026-09-12
expires: 2026-09-12
landed-into: ""
audience: [human, ai]
---

# findings —— 全部发现（PR-N，每条先亲验再定性）

> 严重度：🔴 产品级断点 / 🟡 体验或一致性缺口 / 🟢 文档·可观测性轻症。处置：fixed / pending（DECISIONS-PENDING）/ wontfix（带理由）/ doc-fix。

## R1 配置与基础设施面

### 实锤·已修

- **PR-1 🔴 workflow Edit/Revert 换入口 trigger ref 不重绑活监听 → 旧绑定泄漏 + 新 trigger 无人听**（fixed）
  验证：`Activate` 按**当时** active 图解析 entry refs 挂监听（execution.go:82-90）；`Edit`/`Revert` 移 active 指针后零 binder 调用（crud.go）；`Deactivate` 按**当前**图解析去 detach（execution.go:102+）。后果：active workflow 改入口（trg_a→trg_b）后，trg_a 永远继续触发本 workflow、trg_b 无人听、deactivate 时 detach(trg_b) no-op → trg_a 引用计数永不归零（listener 永驻）。图编译校验「至少一个 trigger」（domain/workflow/graph.go:55）挡得住「删光」、挡不住「换 ref」。
  修复：`rebindIfListening`（diff 旧/新图 refs，detach 删除者 + attach 新增者；双图缺一跳过防 refcount 重复）接入 Edit 与 Revert（Revert 补「指针移动前快照旧图」）；`TestEditRevert_RebindLiveListener` 钉死（active 换 ref 重绑 ×2 方向 + inactive 不碰 binder）。已知限界：staged（AttachOnce）武装在 binder 内部、workflow 行不可见，staged 期间编辑保留旧一次性武装——试运行态可接受，注释明示。

- **PR-2 🟢 api.md workspace/sandbox 行与代码脱节**（doc-fix）
  验证：api.md 写 `GET /sandbox/status`，实际是 `GET /sandbox/bootstrap-status`；runtimes 三端点、`GET /sandbox/disk-usage`、`POST /sandbox:gc`、workspace 的 `default-models/{scenario}`、`default-search`、`:activate` 均未登记（handlers/sandbox.go:40-49、workspaces.go:32-47）。已重述该节。

### 实锤·待裁决（详见 DECISIONS-PENDING）

- **PR-3 🔴 `pkg/limits` 是未接线的空壳**（fixed——裁决 A：schema 重述为现实投影（删 9 个无消费方字段、并入 InvokeMaxTurns、新增 ToolResultCapKB/TriggerRatio）、Default 对齐接线前常量（行为零变化、测试钉死）；新 `app/settings` 读写 `<dataDir>/settings.json` + `GET/PATCH /api/v1/limits` 热换；9 处硬编码常量改读 `limits.Current()`：chat MaxSteps、agent InvokeMaxTurns、mcp 调用超时、bash 超时+输出 cap、read 页大小、loop tool_result cap、contextmgr 触发比、attachment 上限、webhook body 上限）
  验证：包自述「用户可调运行上限的唯一来源……启动装配经 SetProvider 换成 settings.json 支持的 getter」（limits.go:1-8）。实际：①全仓无任何 settings.json 加载器；②`SetProvider` 生产代码零调用（仅测试）；③全仓唯一消费方是 `infra/llm/provider.go:59` 读 `Timeout.LLMIdleSec`——其余全部字段（MaxSteps/Subagent*/bash·mcp 超时/工具体量/attachment 上限/workflow 轮数…）无人读，真实生效的是各模块**各自的硬编码常量**（如 `loop.maxToolResultBytes`、`mcp.defaultCallTimeout`、`shell.outputCapBytes`）。「用户可调」目前是虚构。

- **PR-4 🟡 Ollama embedder 参数无配置面**（fixed——裁决 A：search_meta 补 `ollama_base_url`/`ollama_model` 两键、PATCH/GET 全接、工厂注入 + 参数变化重建适配器、域默认权威 `searchdomain.DefaultOllama*`；app/integration 双层测试）
  验证：`SetEmbeddingProviders(…, NewOllama("", ""))`（build_services.go:134）——baseURL 钉死 `127.0.0.1:11434`、model 钉死 `embeddinggemma`（engine.go NewOllama 默认分支）；`PATCH /search/settings` 只收 `embedder` 一个字段。用户切到 ollama 后无法指定地址/模型，GET 也看不到生效的 baseURL。

- **PR-5 🟡 桌面 app 日志故事缺失**（fixed——裁决 A 最小版：`<dataDir>/logs/forgify.log` 轮转 JSON（lumberjack 10MB×3×28d gzip）tee 在 stderr 控制台旁；文件 sink 测试）
  验证：zap 只出 stdout/stderr、级别仅由 `FORGIFY_DEV` 环境变量二档切换（infra/logger/zap.go:16-32、cmd/server/main.go:25）；无文件落盘/轮转/级别配置。Wails 桌面 app 用户报障无日志可交。

- **PR-6 🟡 备份/跨机迁移故事缺失**（doc-fix——裁决 B：`how-to/data-migration.md` 声明数据布局/备份/三类密文重填边界；export/import 进 roadmap）
  验证：落盘加密密钥从 `MachineFingerprint` 派生（build_data.go:155-168，CR-20 接通）——拷 `~/.forgify` 换机后 api key/handler config/mcp config 密文**全部不可解**；无任何 export/import 面；文档零说明。

### 轻症·已处置

- **PR-7 🟢 utility 模型未配时静默降级未声明**（doc-fix，随本轮文档批）
  验证：autotitle best-effort 吞错（chat/autotitle.go:29-36，无标题无提示）；contextmgr 压缩跳过；search_blocks 精选落第三档。行为本身合理（核心链路不依赖 utility），但「utility 的依赖清单 + 未配时各功能表现」无文档——用户无法把「没标题/没压缩」归因到「没配 utility 模型」。→ 已在 domains/chat.md 补一句（见提交）。
- **PR-8 🟢 env GC 无自动触发**（wontfix）
  验证：`POST /sandbox:gc` 手动口在、`Service.GC(olderThan)` 在（sandbox.go:214），无定时器。理由：本地单用户磁盘、disk-usage 可见、手动口已具备；自动 GC 引入「正在用的 env 被回收」风险大于收益（已有 ErrEnvNotFound 自愈兜底）。
- **PR-9 🟢 首启零 workspace 的 first-run 契约未文档化**（doc-fix）
  验证：bootstrap/cmd 无 workspace 播种；`forEachWorkspace` 对空集 no-op；删除守卫 `ErrCannotDeleteLast`（Count≤1 拒删）。首个 workspace 由前端 onboarding 创建——契约成立但没写下来。→ api.md workspace 行已带「守最后一个」，domains 留待前端对接预检（R5）一并补。

### 误报（agent 面扫报告，亲验驳回）

- ✗「agent 实体无 Edit 操作」——`agentapp.Edit` 在（crud.go:166），`edit_agent` 工具在（tool/agent/forge.go:107）。
- ✗「handler Edit 后活实例可能用旧代码（版本不一致）」——`Restart = Stop + Get`（manager.go:110-113），先停后起：失败时实例已不在，下次 Get 按新 active 版本 spawn；不存在 stale 实例路径。残余仅「spawn 失败留 stopped 态」且 RuntimeState 可查。
- ✗「sandbox 无清理口/env 不可见/无磁盘占用/无 boot 诊断」——十个端点俱全（handlers/sandbox.go:40-49：runtimes GET/POST/DELETE、envs GET×2/DELETE、disk-usage、bootstrap-status、:gc、:retry-bootstrap）。
- ✗「llama-server 关停缺失」——`search.Close()` 对实现 `ProviderCloser` 的 provider 调 Close（app/search/service.go:144-152），builtin 引擎杀子进程。
- ✗「mcp 改 config 不自动重连」——AddServer upsert 路径 `persistAndConnect` 自动连（install.go:98-110）。
- ✗「limits 经 settings.json limits.agent.maxSteps 可调」——把包注释当实现；见 PR-3。
