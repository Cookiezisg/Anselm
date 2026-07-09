---
id: DOC-033
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-14
review-due: 2026-09-14
audience: [human, ai]
---

# 平台小件 —— cel · crypto · db · transport · pkg 工具箱

> orm / reqctx / loop / stream + llm / sandbox / bootstrap / scheduler + flowrun 各有专篇（foundation/）；errors 机制见 [error-codes.md](../error-codes.md) + [ADR 0002](../../../decisions/0002-unified-error-type.md)。

## pkg/cel

裸 CEL 编译求值。宽容 `Compile` 一并声明 `payload`/`ctx`/`input`（RUNTIME 用、存储表达式已校验）；**`CompileFor(roots,expr)` 在恰好给定根集上编译（无自动 ctx）**——AUTHOR 期镜像各上下文真实活化、当场拒错命名空间：control when/emit + approval 模板只读 `input`、sensor condition/output 只读 `payload`（control/approval/trigger 的 create/edit 校验已切到它）。**env 无 now()/墙钟**——guard 重放确定（durable 引擎的前提之一）。`ScopedEnv`（scheduler 用）以图 node id 为根。模板模式 `{{ CEL }}`（approval 渲染，`CompileTemplateFor` 同受限）。

## infra/crypto

AES-GCM 整密文加解密（apikey 密文 / handler config / mcp config_enc 共用）+ 机器指纹派生密钥种子（`CRYPTO_*` 2 码）。本地单用户的"防瞄一眼"级别，非威胁模型级。

## infra/db

无业务知识的 SQLite 网关：`Open`（glebarez 纯 Go 驱动、WAL）+ `Migrate`（各 store 导出幂等 DDL、cmd/server 汇总、单事务按序应用——无 ALTER 机制，未上线期改 DDL = 本地库重建）。

## transport

`router.Chain` 中间件栈（请求方向，外层在前：Recover → RequestLogger → CORS → InjectLocale → IdentifyWorkspace → RequireWorkspace（豁免 workspaces/webhooks/health/providers/scenarios））+ 28 个资源 handler 注册到一个 mux + `response`（N1 Envelope + `errmap.statusForKind` 唯一 Kind→HTTP 表 + FromDomainError）。auth：`RequireWorkspace` 在边界以 401 `UNAUTH_NO_WORKSPACE` 拒（与内部 500 `MISSING_WORKSPACE_ID` 之分见 [reqctx.md](reqctx.md)#4）。

## pkg 工具箱（一行职责）

`agentstate`（**对话级**跨工具共享状态：discovered 工具/active skill/读写不变式——同一实例由 convQueue 建一次、re-seed 进每个回合，活到对话空闲拆除；写前必读的 `seenFiles` 是 **LRU 有界**，最久未标的淘汰，使跨数千文件的长重构不无界增长、近期工作集不变式不破）· `idgen`（`<prefix>_<16hex>`，S15）· `jsonrepair`（LLM 脏 JSON 尽力修复，strict 解析前置）· `limits`（用户可调上限单源——schema 即现实投影：每字段必有消费方；`app/settings` 启动读 `<dataDir>/settings.json`（`fileShape` 含 `limits` + `network` 两段）经 `SetProvider` 装源、PATCH /limits 热换（**PATCH 任一段绝不丢另一段**——`persist(limits, network)` 整体写）；`Default()` 是默认常量、`WithDefaults` 补零字段、`Schema()` 投影每字段元数据（default/min/max/unit/desc，bounds 镜像 `settings.validate()`、与结构 1:1 由反射测试守）供 UI 渲染范围免硬编）· **`app/settings` network 段**（工单⑩）：`Network{httpProxy?,httpsProxy?,noProxy?}` 出站代理,`GET/PATCH /network`（PATCH 整体替换）;`applyProxy` 在 boot 与 PATCH 时 `os.Setenv HTTP_PROXY/HTTPS_PROXY/NO_PROXY`（Go 默认 transport 的 `http.ProxyFromEnvironment` 读之）,完整生效须重启 sidecar（既有 client 缓存代理）;空字段 unset · `logtail`（头+尾限长日志收集器，io.Writer；fn/hd/mcp 执行链落 `logs` 列的共用预算 64KiB）· `pagination`（keyset 游标编解码）· `pathguard`（文件系统工具的 deny-list 安全层）· `schema`（Field 粗类型模型 + JSON Schema 双向转换）· `tokencount`（启发式 token 估算+可校准）· `wikilink`（`[[id]]` 引用抽取）· `fspath`（绝对路径/~ 展开守卫）。
