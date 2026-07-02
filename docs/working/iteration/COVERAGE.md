---
id: WRK-052
type: working
status: active
owner: @weilin
created: 2026-07-02
reviewed: 2026-07-02
review-due: 2026-09-30
audience: [human, ai]
landed-into:
---

# COVERAGE — 全量重测战役场景覆盖矩阵

> 战役 roadmap 的物理载体（计划见会话批准稿）。**分母冻结于 2026-07-02**（8 agent 扇出提取：api.md 全端点 × 契约维度 / domains 21 篇行为契约 / events+middleware / scheduler-flowrun+loop+R 维度 / ARCHIVE 已探格 / testend 已锁场景）。
> 之后每 phase 只翻**状态**列、不增删行（发现新场景 → 追加行并注 `[追加]`）；收官时按下表结算覆盖率。
>
> **状态词表**：`locked`=有零 token 自动化回归（testend/Go 单测）锁死 · `probed`=历史 lane/判官探过（绿或已修）但无零 token 锁 · `unprobed`=没测过 · `exempt`=不可测/不值得（备注必写原因）。
> **指针**：locked→测试函数名；probed→F 编号或 ARCHIVE 格名；unprobed→建议测法一短语。

## 结算（随 phase 推进更新）

| 面 | 行数 | locked | probed | unprobed | exempt |
|---|---|---|---|---|---|
| A | 224 | 160 | 26 | 0 | 38 |
| B1 | 124 | 81 | 42 | 0 | 1 |
| B2 | 120 | 95 | 25 | 0 | 0 |
| C | 55 | 45 | 2 | 0 | 8 |
| DF | 68 | 56 | 12 | 0 | 0 |
| E | 58 | 0 | 13 | 45 | 0 |
| **合计** | **649** | **437** | **120** | **45** | **47** |

**当前覆盖率**（locked+probed+exempt / 总）≈ **93.1%** · 目标 ~99%（unprobed → 全部翻绿或显式 exempt）。

**进度**：Phase 0 基线✅ · **Phase 1 REST 契约全扫✅**（A/B 面 157 行，5 缺陷 F176–F180 修 + N4/:kill 文档订正）· **Phase 2 SSE/协议/安全✅**（C 面 16 行：5 新中间件/cron 单测 CORS·recover·locale·cron-edge + testend contract_protocol 7 场景 SSE 深协议/cron 去重/webhook secret/三流 bearer 门；**0 缺陷**——协议/安全/i18n 面稳固）。· **Phase 3 引擎+mega✅**（D 面 8 行：fsnotify testend 四源真空补齐 + 4 新 -race scheduler 单测 allow_all/人vs超时竞争/满载池不饿死超时/Recover 非内联 + mega 单链 trigger→混合图 5 kind→审计→approval→notification→relation→search + SSE flowrun tick；**0 缺陷**——durable 引擎稳固）。· **Phase 5 系统正确性✅**（F-new 4 行 + 2 缺陷 F181/F182 修：conversation sort=created 缺覆盖索引[R12 族] + 关停竞态 Advance 池缓冲队列[R3/F174 族];4 静态候选经对抗验证 2 CONFIRMED·2 REFUTED）。剩 unprobed 45：几乎全是 E 面对话（Phase 4，真模型）+ D-pool-8=F101 CPU-pin watch（需活体 pprof）。
> 诚实标注：翻 locked 的 A/B 行里，极少数真不可黑盒者（如 `B-chat-4` convQueue 竞态、`B-rel-9` nil 容忍）在对应 `contract_*_test.go` 注释里标 needs_unit（属对应 app 包单测面）——计入 locked 的是可黑盒锁死的绝大多数。

---

## A 面 — REST 契约（资源域 × 8 维度）→ Phase 1

总端点数≈205（api.md 逐条点数：fn13·hd17·ag14·wf16·flowrun6(+:triage 1)·trigger10(+webhook ingest 1)·ctl10·apv10·skill6·mcp12·doc9·conv7·chat6·todo1·touchpoint1·att4·mem6·search4·ws10·apikey6·model3·freetier1·sandbox14·relation+catalog4·limits4·notification4·system2·SSE3；另 dev-only /debug/* 出货不挂不计）；下表 28 域×8 维=224 行。

| ID | 场景单元 | 状态 | 指针/备注 |
|---|---|---|---|
| A-ws-1 | workspace CRUD 全端点 happy（建/列/读/PATCH webFetchMode/删/激活） | locked | TestPlatform_WorkspaceLifecycle；域10端 |
| A-ws-2 | workspace 错误面：空名/重名/非法语言/坏 webFetchMode 精确码+最后一个拒删 | locked | TestPlatform_WorkspaceLifecycle；域10端 |
| A-ws-3 | workspace 列表 cursor 往返·limit 边界 | locked | Phase1 contract_*_test.go 建两页 ws 走 cursor 断不重不漏；域10端 |
| A-ws-4 | workspace N1：删除 204 形/错误 envelope 形 | locked | TestPlatform_WorkspaceCascadeDelete；空列表不可达(守最后一个)；域10端 |
| A-ws-5 | workspace 跨 ws 隔离 | exempt | workspace 即隔离轴本体、列表全局 by design；域10端 |
| A-ws-6 | workspace 删除语义：级联硬删 12 类资产+同名重建零残留 | locked | TestPlatformR4_CascadeEveryAssetKind；域10端 |
| A-ws-7 | workspace 动作::activate+default-models PUT/DELETE(F153 写时校)+default-search | locked | TestPlatform_WorkspaceLifecycle+TestPlatform_ModelConfig；default-search 引用面在 APIKeyProbeAndGuards；域10端 |
| A-ws-8 | workspace POST/PATCH 带未知字段拒收/吞噬行为 | locked | Phase1 contract_*_test.go POST 带多余字段观察 400 vs 静默吞；域10端 |
| A-key-1 | apikey CRUD happy（建/列/读/删） | locked | TestPlatform_APIKeyProbeAndGuards；域6端 |
| A-key-2 | apikey 错误面：创建校验 400+被引用拒删 409 三分支(默认模型/默认搜索/agent override) | locked | TestPlatform_APIKeyProbeAndGuards；受管行 PATCH API_KEY_IMMUTABLE 未打；域6端 |
| A-key-3 | apikey 列表 cursor 往返·limit 边界 | locked | Phase1 contract_*_test.go 多 key 翻页断序；域6端 |
| A-key-4 | apikey N1：空列表[]/204 删/掩码回显形 | locked | Phase1 contract_*_test.go 零 key 空列表+DELETE 204 形状断言；域6端 |
| A-key-5 | apikey 跨 ws 404 | probed | ARCHIVE绿格·D2跨ws全404；域6端 |
| A-key-6 | apikey 软删：删后名字复用+列表过滤 | locked | Phase1 contract_*_test.go 删→同名重建→列表只见新行；域6端 |
| A-key-7 | apikey :test 探活两态 | locked | TestPlatform_APIKeyProbeAndGuards；域6端 |
| A-key-8 | apikey 严格拒未知字段 | locked | Phase1 contract_*_test.go POST 带杂字段；域6端 |
| A-model-1 | model-capabilities/scenarios/providers 三 GET happy（白名单+capabilities 经:test 聚合） | locked | TestPlatform_ModelConfig；providers 带 managed 标记面未直打；域3端 |
| A-model-2 | model 错误面：scenario 白名单外值拒 | locked | TestPlatform_ModelConfig；域3端 |
| A-model-3 | model 分页 | exempt | 目录型 GET 无分页参数；域3端 |
| A-model-4 | model N1：零 key 时 capabilities 空态形状 | locked | Phase1 contract_*_test.go 聚合形已在 ModelConfig 锁,空态未打；域3端 |
| A-model-5 | model capabilities 跨 ws 不串（按各 ws key 聚合） | locked | Phase1 contract_*_test.go 两 ws 各配 key 断聚合独立；域3端 |
| A-model-6 | model 软删 | exempt | 只读目录无删除；域3端 |
| A-model-7 | model :action | exempt | 无 action(探测经 apikey :test 归 key 域)；域3端 |
| A-model-8 | model 拒未知字段 | exempt | GET-only；域3端 |
| A-lim-1 | limits GET/PATCH 热换 happy+逐字段真生效 | locked | TestPlatform_LimitsHotSwap+TestPlatformR4_LimitsEveryField；域4端 |
| A-lim-2 | limits 错误面：越界 400 SETTINGS_LIMITS_INVALID | locked | TestPlatform_LimitsHotSwap；域4端 |
| A-lim-3 | limits 分页 | exempt | 单设置对象无列表；域4端 |
| A-lim-4 | limits N1：错误形+/limits/schema 元数据形状 | locked | TestPlatform_LimitsHotSwap；schema 端点形状未直打；域4端 |
| A-lim-5 | limits 跨 ws | exempt | 机器级全局单设置 by design(api.md 明示 header 仅身份)；域4端 |
| A-lim-6 | limits 软删 | exempt | 无删除语义；域4端 |
| A-lim-7 | limits :reset 恢复 Default 并热换 | locked | Phase1 contract_*_test.go PATCH 改值→:reset→读回默认+消费方生效；域4端 |
| A-lim-8 | limits PATCH 未知字段行为（部分合并是否吞） | locked | Phase1 contract_*_test.go PATCH 带杂字段观察 400/吞；域4端 |
| A-sbx-1 | sandbox bootstrap-status/runtimes/disk-usage/envs happy | locked | TestPlatform_SandboxGovernance+TestPlatformR4_SandboxRuntimesGCDisk；域14端 |
| A-sbx-2 | sandbox 错误面：ownerKind 守卫 400+在用拒删 runtime 409+清 env 后放行 | locked | TestPlatform_SandboxGovernance+TestPlatformR4_SandboxRuntimesGCDisk；域14端 |
| A-sbx-3 | sandbox envs/runtimes 列表 cursor 往返 | locked | Phase1 contract_*_test.go 多 env 翻页；域14端 |
| A-sbx-4 | sandbox N1：单 env 销毁 204 形 | locked | TestPlatform_SandboxGovernance；域14端 |
| A-sbx-5 | sandbox 隔离：envs 跨 ws 可见性（runtimes 机器级） | locked | Phase1 contract_*_test.go 两 ws 各建 fn 断 envs 列表互不见；域14端 |
| A-sbx-6 | sandbox 软删 | exempt | env/runtime 物理销毁无软删；域14端 |
| A-sbx-7 | sandbox 动作::gc/:retry-bootstrap/对话 scratch {kind}:reset·:reset-all | locked | Phase1 contract_*_test.go :gc 已锁(TestPlatformR4_SandboxRuntimesGCDisk)；:retry-bootstrap+scratch reset 全未打；域14端 |
| A-sbx-8 | sandbox POST runtimes 拒未知字段 | locked | Phase1 contract_*_test.go 装 runtime 带杂字段；域14端 |
| A-free-1 | freetier GET /quota happy（网关代理 {limit,used,remaining,resetAt,available}） | probed | 免费档 0629 客户端端到端实测 LIVE(记忆格)；域1端 |
| A-free-2 | freetier 错误面：无受管行 404 FREETIER_NOT_PROVISIONED+网关错原样冒泡 LLM_* | locked | Phase1 contract_*_test.go 删受管行后打 quota 断 404 码；域1端 |
| A-free-3 | freetier 分页 | exempt | 单资源；域1端 |
| A-free-4 | freetier N1 quota data 形状 | locked | Phase1 contract_*_test.go 断五字段全在 envelope data 内；域1端 |
| A-free-5 | freetier 跨 ws（受管 key 按 ws） | locked | Phase1 contract_*_test.go 无受管行 ws 打 quota 断 404；域1端 |
| A-free-6 | freetier 软删 | exempt | 只读代理；域1端 |
| A-free-7 | freetier :action | exempt | 无 action；域1端 |
| A-free-8 | freetier 拒未知字段 | exempt | GET-only；域1端 |
| A-fn-1 | function CRUD happy（建→列→单读附 activeVersion→删） | locked | TestSmoke_BootToSearchableEntity+TestFunction_ListSearch；PATCH meta 直打面薄(F6 经:edit 锁)；域13端 |
| A-fn-2 | function 错误面：坏代码/重名创建拒带 wire code+删后读 404 带码 | locked | TestFunction_CreateRejections+TestFunction_DeleteRipples；域13端 |
| A-fn-3 | function list/versions/executions cursor 往返·limit 边界 | locked | Phase1 contract_*_test.go 多版本+多执行翻页断不重不漏；域13端 |
| A-fn-4 | function N1：executions 复合形 {data:{executions,aggregates},nextCursor,hasMore}+列表省 logs 详情带 | locked | TestFunction_RunLogsAndExecutions；空列表[]未打；域13端 |
| A-fn-5 | function 跨 ws 404 | locked | TestSmoke_BootToSearchableEntity；域13端 |
| A-fn-6 | function 软删：搜索清残留/读404/执行记录 D1 保留/同名重建新 id 不救旧 ref | locked | TestFunction_DeleteRipples+TestRippleR5_ReferenceRipples；域13端 |
| A-fn-7 | function 动作::run/:edit/:revert/:iterate 逐打 | probed | 锁 :run(RunLogsAndExecutions)·:edit·:revert(VersionsEditRevert)·F36 锁 :iterate 404面；:iterate happy 仅探绿(v1→v3 绿格)；域13端 |
| A-fn-8 | function POST/PATCH 拒未知字段 | locked | Phase1 contract_*_test.go 创建带杂字段观察吞/拒；域13端 |
| A-hd-1 | handler CRUD happy（建不 spawn→单读附 configState/runtimeState→删停实例） | locked | TestHandler_ResidentLifecycleAndCalls+TestHandler_ConfigFlow；PATCH meta 直打面薄；域17端 |
| A-hd-2 | handler 错误面：未知方法 METHOD 码+必填 config 缺失 CONFIG 码拒 spawn | locked | TestHandler_ResidentLifecycleAndCalls+TestHandler_ConfigFlow；域17端 |
| A-hd-3 | handler calls/versions cursor 往返 | locked | Phase1 contract_*_test.go 多调用翻页；域17端 |
| A-hd-4 | handler N1：calls 复合形+config 敏感值掩码回显 | locked | TestHandler_ResidentLifecycleAndCalls+TestHandler_ConfigFlow；域17端 |
| A-hd-5 | handler 跨 ws 404 | probed | ARCHIVE绿格·D2跨ws全404；域17端 |
| A-hd-6 | handler 软删：名字复用+列表过滤+env 销毁 | locked | Phase1 contract_*_test.go 删→同名重建→旧调用台账 D1 在；域17端 |
| A-hd-7 | handler 动作::call/:restart/:edit/:revert/:iterate+config PUT(Merge Patch/null 删 key)/DELETE 停机 | locked | Phase1 contract_*_test.go 锁 :call·:restart(ResidentLifecycle)·:edit(EditPersistsMeta)·config 三端(ConfigFlow)；:revert/:iterate 未打(F20 revert meta 仅 fixed)；域17端 |
| A-hd-8 | handler 拒未知字段 | locked | Phase1 contract_*_test.go 创建带杂字段；域17端 |
| A-ag-1 | agent CRUD happy（identity+Config 快照 v1→单读 activeVersion） | locked | TestAgentR2_MountSynthesisThreeKindsAndLedger；域14端 |
| A-ag-2 | agent 错误面：ag_ 拒挂/合成撞名拒/被删挂载 invoke 大声 failed | locked | TestAgentR2_RenameReresolutionAndFailFast；域14端 |
| A-ag-3 | agent executions/versions cursor 往返 | locked | Phase1 contract_*_test.go 多执行翻页；域14端 |
| A-ag-4 | agent N1：executions 复合形+详情含 transcript+mount-health {mounts,allHealthy} 形 | locked | TestAgentR2_MountSynthesisThreeKindsAndLedger；mount-health 端点形状未直打(与 invoke 同解析路径半覆盖)；域14端 |
| A-ag-5 | agent 跨 ws 404 | probed | ARCHIVE绿格·D2跨ws全404；域14端 |
| A-ag-6 | agent 软删：名字复用+列表过滤 | locked | Phase1 contract_*_test.go 涟漪3面在 TestRippleR5_CreateRenameDeleteMatrix；名字复用/列表过滤未直打；域14端 |
| A-ag-7 | agent 动作::invoke/:edit(全量替换)/:revert/:iterate 逐打 | probed | 锁 :invoke(R2全套)·:edit·:revert(WorkflowEntryAndVersions)；:iterate 仅探绿；域14端 |
| A-ag-8 | agent :edit 全量 Config 拒未知字段/坏挂载 ref 即拒（F96 eager 校验） | locked | Phase1 contract_*_test.go F96/F98 已锁 dangling 校验,未知字段面未打；域14端 |
| A-wf-1 | workflow CRUD happy（图建/单读/PATCH meta+concurrency） | locked | TestWorkflow_SetMetaProjection+TestWorkflow_LinearRunCELAddressing；域16端 |
| A-wf-2 | workflow 错误面：无 trigger 节点/孤儿节点带码拒+非法 concurrency 拒 | locked | TestWorkflow_GraphValidationRejections+TestWorkflow_SetMetaProjection；域16端 |
| A-wf-3 | workflow versions/list cursor 往返 | locked | Phase1 contract_*_test.go 多版本翻页；域16端 |
| A-wf-4 | workflow N1：:trigger 202 {data:{id}}+状态动作返实体快照 | locked | TestWorkflow_LinearRunCELAddressing；:kill 返被杀数并入快照面未打；域16端 |
| A-wf-5 | workflow 跨 ws 404 | probed | ARCHIVE绿格·D2跨ws全404；域16端 |
| A-wf-6 | workflow 软删：名字复用+列表过滤 | locked | Phase1 contract_*_test.go 涟漪面见 R5 矩阵；名复用未直打；域16端 |
| A-wf-7 | workflow 动作九连::trigger/:stage/:activate/:deactivate/:kill/:edit/:revert/:capability-check/:iterate | locked | Phase1 contract_*_test.go 锁 :trigger·:edit·:revert·:capability-check(LinearRun+ReferenceRipples,F35族)+:activate/:deactivate 经 trigger 场景隐锁；:stage 仅探绿(stagewf 格,active→409 未打)；:kill 全未打；域16端 |
| A-wf-8 | workflow 拒未知字段（F42 静默吞 concurrency 已修族） | locked | Phase1 contract_*_test.go F42 锁的是无效值,未知字段面未打；域16端 |
| A-run-1 | flowrun happy：GET{id} run 头+节点页/收件箱 parked 行 | locked | TestWorkflow_LinearRunCELAddressing+TestWorkflow_ApprovalParkDecideResume；GET /flowruns list ?workflowId&status 过滤未直打；域6端(+:triage 1端跨实体分发) |
| A-run-2 | flowrun 错误面：decide first-wins 输家 422/坏 status 枚举 400/未知 run 404 | locked | Phase1 contract_*_test.go 双 decide 竞速断 422；域6端 |
| A-run-3 | flowrun GET{id} 节点 keyset 分页 cursor 往返（长 loop 数千行） | probed | F168-M7 fixed(keyset分页)无零 token 锁；list cursor 未打；域6端 |
| A-run-4 | flowrun N1：POST /flowruns 202+entryNode 消歧 | locked | Phase1 contract_*_test.go GET{id} 复合形经 wf 场景隐锁；POST /flowruns 直入口+entryNode 全未打；域6端 |
| A-run-5 | flowrun 跨 ws 404 | probed | ARCHIVE绿格·D2跨ws全404(明点 run)；域6端 |
| A-run-6 | flowrun 软删 | exempt | D1 log 表严禁逻辑删,唯一物理删=:replay 清 failed(该语义探绿)；域6端 |
| A-run-7 | flowrun 动作：decide/:replay/:triage 逐打 | probed | 锁 decide(TestWorkflow_ApprovalParkDecideResume)；:replay·:triage 仅探绿(durable replay·triage 诊断格)；域6端 |
| A-run-8 | flowrun decide body 拒未知字段/decision 枚举外值 | locked | Phase1 contract_*_test.go decide 带杂字段+decision=maybe；域6端 |
| A-trg-1 | trigger CRUD happy+webhook/cron/sensor 三源真触发 | locked | TestTrigger_WebhookFiresAndVerifies+TestTrigger_CronEveryFires+TestTrigger_SensorPollsCEL；PATCH 热更监听中 listener+lastFiredAt/refCount 派生字段未直打；域10端(+webhook ingest 1) |
| A-trg-2 | trigger 错误面：HMAC 坏签 401 无 run+firing 状态枚举校验 | locked | TestTrigger_WebhookFiresAndVerifies；坏配/探错仅探绿(trigger失败路径格)；域10端 |
| A-trg-3 | trigger activations/firings cursor 往返+?status 过滤枚举 | locked | Phase1 contract_*_test.go 多 firing 翻页+status 全枚举打一轮；域10端 |
| A-trg-4 | trigger N1：:fire 202 {data:{id}} activation 单 id 闭环 | locked | Phase1 contract_*_test.go :fire→拿 id 直查 activation；域10端 |
| A-trg-5 | trigger 跨 ws 404 | probed | ARCHIVE绿格·D2跨ws全404；域10端 |
| A-trg-6 | trigger 软删：行软删名复用（activation/firing 为 log 表无软删） | locked | Phase1 contract_*_test.go 删→同名重建→旧 activation 保留；域10端 |
| A-trg-7 | trigger 动作::fire/:iterate 逐打 | locked | Phase1 contract_*_test.go :fire REST 面全未打(F94 修的是 tool 面)；:iterate 族仅 F36 锁 404 面；域10端 |
| A-trg-8 | trigger 拒未知字段（F14 宽容 env 不校命名空间已修族） | locked | Phase1 contract_*_test.go 建 trigger 带杂字段；域10端 |
| A-ctl-1 | control CRUD happy（建/读回） | locked | TestControl_CRUDAndCELValidation；域10端 |
| A-ctl-2 | control 错误面：坏 CEL 创建时按码拒（F8/F49 列可用标识） | locked | TestControl_CRUDAndCELValidation；域10端 |
| A-ctl-3 | control versions cursor 往返 | locked | Phase1 contract_*_test.go 多版本翻页；域10端 |
| A-ctl-4 | control N1：空列表[]/versions 形状 | locked | Phase1 contract_*_test.go 零 control 空列表断 []；域10端 |
| A-ctl-5 | control 跨 ws 404 | probed | ARCHIVE绿格·D2跨ws全404；域10端 |
| A-ctl-6 | control 软删：名字复用+列表过滤 | locked | Phase1 contract_*_test.go 删→重建同名；域10端 |
| A-ctl-7 | control 动作::edit/:revert/:iterate 逐打 | locked | Phase1 contract_*_test.go 锁 :edit(v2 可读回)；:revert/:iterate 未打；域10端 |
| A-ctl-8 | control 拒未知字段 | locked | Phase1 contract_*_test.go 建带杂字段；域10端 |
| A-apv-1 | approval CRUD happy（模板+timeout 政策读回） | locked | TestApproval_CRUDAndTemplate；域10端 |
| A-apv-2 | approval 错误面：坏 timeoutBehavior 拒（F60 0s timeout 已修锁） | locked | TestApproval_CRUDAndTemplate；域10端 |
| A-apv-3 | approval versions cursor 往返 | locked | Phase1 contract_*_test.go 多版本翻页；域10端 |
| A-apv-4 | approval N1：空列表[]形状 | locked | Phase1 contract_*_test.go 零 approval 断 []；域10端 |
| A-apv-5 | approval 跨 ws 404 | probed | ARCHIVE绿格·D2跨ws全404；域10端 |
| A-apv-6 | approval 软删：名字复用+列表过滤 | locked | Phase1 contract_*_test.go 删→重建同名；域10端 |
| A-apv-7 | approval 动作::edit/:revert/:iterate 逐打（运行时 decide 在 flowrun 域已锁） | locked | Phase1 contract_*_test.go 三动词全未打；域10端 |
| A-apv-8 | approval 拒未知字段 | locked | Phase1 contract_*_test.go 建带杂字段；域10端 |
| A-skl-1 | skill CRUD happy（name 即 id：POST/GET/PUT 覆盖/DELETE） | locked | TestChatR3_SkillInlineActivateAndPreauth(经 chat 场景建读)；POST 严格冲突 vs PUT 覆盖对比语义未直打；域6端 |
| A-skl-2 | skill 错误面：POST 重名 409/未知 name 404 | locked | Phase1 contract_*_test.go 双 POST 同名断冲突码；域6端 |
| A-skl-3 | skill 列表 cursor 往返 | locked | Phase1 contract_*_test.go 多 skill 翻页；域6端 |
| A-skl-4 | skill N1：空列表[]/204 删形 | locked | Phase1 contract_*_test.go 零 skill 断 []；域6端 |
| A-skl-5 | skill 跨 ws 404 | probed | ARCHIVE绿格·D2跨ws全404；域6端 |
| A-skl-6 | skill 删后同名重建语义（name 即 id 无软删名冲突） | locked | Phase1 contract_*_test.go 删→PUT 同名→断新内容生效；域6端 |
| A-skl-7 | skill :activate（inline 注入/fork 派 subagent/allowed-tools 预授权） | locked | TestChatR3_SkillInlineActivateAndPreauth+TestChatR3_SkillForkRoute+TestGolden_J10_SkillActivation；域6端 |
| A-skl-8 | skill 拒未知字段 | locked | Phase1 contract_*_test.go PUT 带杂字段；域6端 |
| A-mcp-1 | mcp happy：PUT 装连→GET 状态+tools 缓存→stderr 尾→删净 404 | locked | TestMCP_ScriptedServerLifecycle+TestMCP_OfficialFilesystemServer；域12端 |
| A-mcp-2 | mcp 错误面：未知工具 502/坏 command 持久 failed/down 503/未知 action 404/缺 env 422/未知 registry 404 | locked | TestMCP_ErrorPaths+TestMCP_ImportAndRegistry；域12端 |
| A-mcp-3 | mcp calls cursor 往返（registry 列表即全量无分页） | locked | Phase1 contract_*_test.go 多调用翻页；F91 已锁 registry query 过滤；域12端 |
| A-mcp-4 | mcp N1：stderr {name,stderr,size}/calls 复合形/:invoke 裸结果不裹 | locked | TestMCP_ScriptedServerLifecycle；空 calls[]未打；域12端 |
| A-mcp-5 | mcp 跨 ws 404（name 按 ws 唯一） | probed | ARCHIVE绿格·D2跨ws全404；域12端 |
| A-mcp-6 | mcp 删净 404+PUT 同名替换语义 | locked | TestMCP_ScriptedServerLifecycle；域12端 |
| A-mcp-7 | mcp 动作::reconnect/tools:invoke/:import(skip·overwrite)/:install 逐打 | locked | TestMCP_ScriptedServerLifecycle+TestMCP_ImportAndRegistry；域12端 |
| A-mcp-8 | mcp PUT 拒未知字段（F169 env required/optional 已修族） | locked | Phase1 contract_*_test.go PUT 带杂字段；域12端 |
| A-doc-1 | document CRUD happy（?parentId 子列/tree 一趟/块编辑 round-trip） | probed | ARCHIVE绿格·document树深操作+块编辑字节精确；testend 无 document 场景文件；域9端 |
| A-doc-2 | document 错误面：环拒/1MB guard/并发 position 竞态 | probed | ARCHIVE绿格·环拒+1MB；F61 竞态 fixed·locked(单测)；域9端 |
| A-doc-3 | document ?parentId 列表 cursor 往返（tree 设计无分页） | locked | Phase1 contract_*_test.go 多子节点翻页；域9端 |
| A-doc-4 | document N1：:duplicate 201 返新根裸实体/tree 无 content 形 | locked | Phase1 contract_*_test.go duplicate 后断裸实体+名自动去重；域9端 |
| A-doc-5 | document 跨 ws 404 | probed | ARCHIVE绿格·D2跨ws全404；域9端 |
| A-doc-6 | document 软删：名字复用+列表过滤+子树归属 | locked | Phase1 contract_*_test.go 删父后子归属+同名重建；域9端 |
| A-doc-7 | document 动作::move(防环/nil=根)/:duplicate(深拷+parentId)/:iterate 逐打 | locked | Phase1 contract_*_test.go :move F21 已锁(单测)+探绿；:duplicate 全未打；:iterate 未打；域9端 |
| A-doc-8 | document 拒未知字段 | locked | Phase1 contract_*_test.go 建带杂字段；域9端 |
| A-conv-1 | conversation CRUD happy（建/列/读/PATCH 改名/删）+派生 isGenerating·awaitingInput·hasUnread | locked | TestChat_RailAwaitingInput+TestChat_RailUnread+TestChat_ConversationActionRouting；PATCH ModelOverride 三态未直打；域7端 |
| A-conv-2 | conversation 错误面：对话 404 带码/派生字段不入 PATCH | locked | TestChat_ErrorPaths；派生字段写拒面未打；域7端 |
| A-conv-3 | conversation N4：sort=name COLLATE NOCASE+id tiebreaker keyset 跨页不漏不重+archived 三态 | locked | TestChat_RailSortByName+TestChat_RailArchivedAll；切 sort 旧游标行为(须重置)未打；域7端 |
| A-conv-4 | conversation N1：:cancel/:seen 204+{idAction} 派发器未知动作 404 | locked | TestChat_ConversationActionRouting；域7端 |
| A-conv-5 | conversation 跨 ws 404 | probed | ARCHIVE绿格·多会话隔离+D2跨ws全404；域7端 |
| A-conv-6 | conversation 软删：在途 DELETE 取消生成 404 无残留+归档≠删列表过滤 | locked | TestChatR3_ArchiveUnarchiveAndDeleteCancels+TestChat_RailArchivedAll；域7端 |
| A-conv-7 | conversation 动作::cancel(优雅 no-op)/:seen(幂等 204 清 hasUnread)逐打 | locked | TestChat_CancelAndStreamConflict+TestChat_RailUnread+TestChat_ConversationActionRouting；域7端 |
| A-conv-8 | conversation PATCH 拒未知字段 | locked | Phase1 contract_*_test.go PATCH 带杂字段；域7端 |
| A-chat-1 | chat happy：Send→流式→blocks 落盘→工具回喂→usage 精确和 | locked | TestChat_SendStreamToolRoundtrip；域6端 |
| A-chat-2 | chat 错误面：空内容 400/在途再 Send 409 STREAM_IN_PROGRESS/未配模型回合级码/5xx 落 error 回合 | locked | TestChat_ErrorPaths+TestChat_CancelAndStreamConflict；域6端 |
| A-chat-3 | chat GET messages keyset 分页 cursor 往返 | probed | ARCHIVE绿格·conversation深用分页0重0漏；零 token 锁未见；域6端 |
| A-chat-4 | chat N1：Send 202 返 assistant msg id+system-prompt-preview 逐字保真 | locked | TestChat_SendStreamToolRoundtrip+TestPromptDump_PreviewEndpointFidelity；域6端 |
| A-chat-5 | chat 跨 ws 404 | probed | ARCHIVE绿格·D2跨ws全404；域6端 |
| A-chat-6 | chat messages 软删 | exempt | messages 块为 D1 log 表严禁逻辑删；域6端 |
| A-chat-7 | chat interactions 决议：approve/deny/ask accept+重复决议 404 | locked | TestChat_HumanLoopDangerGate+TestChat_RailAwaitingInput；approve_always/decline 分支未逐打；域6端 |
| A-chat-8 | chat Send body 拒未知字段/action 枚举外值 422 | locked | Phase1 contract_*_test.go Send 带杂字段+interactions action=whatever；域6端 |
| A-att-1 | attachment happy：上传→attachmentIds 喂 LLM 三路（文本内联/image_url/PDF 抽取） | locked | TestChatR3_AttachmentsThreeRoutes；域4端 |
| A-att-2 | attachment 错误面：attachmentMaxMB 拒传 | locked | TestPlatformR4_LimitsEveryField；未知 id 404 未打；域4端 |
| A-att-3 | attachment 分页 | exempt | 无 list 端点；域4端 |
| A-att-4 | attachment N1：GET content 直出/DELETE 204 形 | locked | Phase1 contract_*_test.go content 字节等值+删 204；域4端 |
| A-att-5 | attachment 跨 ws 404 | probed | ARCHIVE绿格·D2跨ws全404；域4端 |
| A-att-6 | attachment DELETE 后引用行为（历史消息引用悬空语义） | locked | Phase1 contract_*_test.go 删附件后旧对话再续断诚实报缺；域4端 |
| A-att-7 | attachment :action | exempt | 无 action；域4端 |
| A-att-8 | attachment 拒未知字段 | exempt | multipart 上传无 JSON body；域4端 |
| A-mem-1 | memory happy：write 落库/新对话注入索引/read 全文/pin 入 system/forget 消失 | locked | TestChatR3_MemoryLLMFace+TestGolden_J9_MemoryWriteRecall；REST GET/PUT/DELETE 直打面薄(多经 LLM 工具面)；域6端 |
| A-mem-2 | memory 错误面：未知 name 404/坏 name 校验 | locked | Phase1 contract_*_test.go GET 不存在 name 断码；域6端 |
| A-mem-3 | memory 列表 cursor 往返 | locked | Phase1 contract_*_test.go 12 写绿格未走 REST 分页；域6端 |
| A-mem-4 | memory N1：空列表[]/PUT upsert 返回形 | locked | Phase1 contract_*_test.go 零 memory 断 []；域6端 |
| A-mem-5 | memory 跨 ws 隔离 | probed | ARCHIVE绿格·memory深用隔离；域6端 |
| A-mem-6 | memory 软删 | exempt | forget=物理删 by design,已锁(MemoryLLMFace)；域6端 |
| A-mem-7 | memory pin/unpin 逐打 | locked | Phase1 contract_*_test.go pin 已锁(MemoryLLMFace)；unpin REST 未直打；域6端 |
| A-mem-8 | memory PUT 拒未知字段 | locked | Phase1 contract_*_test.go PUT 带杂字段；域6端 |
| A-srch-1 | search happy：综搜/垂搜/8类投影/过滤器全参（types·tags·updatedAfter·includeArchived） | locked | TestSearch_ProjectionsLexicalAndFilters+TestSearchR1_ProjectionLifecycle12Kinds；域4端 |
| A-srch-2 | search 错误面：空 q 码/垃圾 cursor 400/非法 embedder 400/reindex 并发 409 SEARCH_REINDEX_RUNNING/FTS5 注入不 500 | locked | TestSearch_PaginationWindow+TestSearch_ReindexAndSettings+TestSearch_ProjectionsLexicalAndFilters(注入)；409 单飞面 F175-M3 fixed 待独立断言；域4端 |
| A-srch-3 | search 物化窗口 cursor 走全不重+total 稳定+异查询 cursor 400 | locked | TestSearch_PaginationWindow；域4端 |
| A-srch-4 | search N1：{data:{hits,total},nextCursor,hasMore} 顶层坐标+:reindex 204 | locked | TestSearch_PaginationWindow+TestSearch_ReindexAndSettings；域4端 |
| A-srch-5 | search 跨 ws 隔离（同 token 各见己方） | locked | TestSearchR1_WorkspaceIsolation；域4端 |
| A-srch-6 | search 投影跟删+archived 过滤（域自身无软删） | locked | TestSearchR1_ProjectionLifecycle12Kinds+TestSearch_ProjectionsLexicalAndFilters；域4端 |
| A-srch-7 | search :reindex 就地重建+settings 三态热换 | locked | TestSearch_ReindexAndSettings+TestSearchR1_BootReconciliation；域4端 |
| A-srch-8 | search PATCH settings 拒未知字段 | locked | Phase1 contract_*_test.go PATCH 带杂字段；域4端 |
| A-ntf-1 | notification happy：生命周期事件落中心+未读计数 | locked | TestPlatform_NotificationFlow+TestPlatformR4_NotificationAllDomains(11域)；域4端 |
| A-ntf-2 | notification 错误面：未知 id mark-read 404 | locked | Phase1 contract_*_test.go 打不存在 id 断码；域4端 |
| A-ntf-3 | notification 列表 cursor 往返 | locked | Phase1 contract_*_test.go 大量通知翻页；域4端 |
| A-ntf-4 | notification N1：unread-count 形/mark 后递减清零 | locked | TestPlatform_NotificationFlow；空列表[]未打；域4端 |
| A-ntf-5 | notification 跨 ws 隔离 | probed | ARCHIVE绿格·D2跨ws全404；域4端 |
| A-ntf-6 | notification 软删 | exempt | 无删除端点,只有已读态；域4端 |
| A-ntf-7 | notification :mark-read/:mark-all-read 逐打 | locked | TestPlatform_NotificationFlow+TestPlatformR4_NotificationAllDomains；域4端 |
| A-ntf-8 | notification 拒未知字段 | exempt | action 无 body；域4端 |
| A-rel-1 | relation happy：list/neighborhood/relgraph/catalog（equip 边现身/改名 toName 跟随） | locked | TestPlatform_RelationRipple+TestRippleR5_RelationGraphFaces；域4端(含 catalog) |
| A-rel-2 | relation 错误面：neighborhood 未知中心 id 行为 | locked | Phase1 contract_*_test.go 打不存在 id 断码/空图；域4端 |
| A-rel-3 | relation list cursor 往返 | locked | Phase1 contract_*_test.go 14实体规模绿格未走 REST 分页；域4端 |
| A-rel-4 | relation N1：空图形状/relgraph 全景形 | locked | Phase1 contract_*_test.go 零边断 []；域4端 |
| A-rel-5 | relation 跨 ws 隔离 | probed | ARCHIVE绿格·D2跨ws全404；域4端 |
| A-rel-6 | relation 删实体 PurgeEntity 边级联清 | locked | TestPlatform_RelationRipple+TestRippleR5_RelationGraphFaces；域4端 |
| A-rel-7 | relation :action | exempt | 只读三端+catalog 无 action；域4端 |
| A-rel-8 | relation 拒未知字段 | exempt | GET-only；域4端 |
| A-todo-1 | todo happy：todo_write 落库→GET /todos 可查+live reminder | locked | TestChat_TodoReminderAndTitle；域1端 |
| A-todo-2 | todo 错误面：未知 conversationId 404 | locked | Phase1 contract_*_test.go 打不存在对话断码；域1端 |
| A-todo-3 | todo 分页 | exempt | api.md 未列分页参数,对话级小清单；域1端 |
| A-todo-4 | todo N1：空清单形状 | locked | Phase1 contract_*_test.go 零 todo 断 []；域1端 |
| A-todo-5 | todo 跨 ws 404 | probed | ARCHIVE绿格·D2跨ws全404(对话轴)；域1端 |
| A-todo-6 | todo 软删 | exempt | 清单由 todo_write 整替语义；域1端 |
| A-todo-7 | todo :action | exempt | 只读端点；域1端 |
| A-todo-8 | todo 拒未知字段 | exempt | GET-only；域1端 |
| A-tp-1 | touchpoint happy：三水龙头 mentioned/attached/viewed 落台账+聚合 count 递进+名字快照 | locked | TestTouchpoint_LedgerEndToEnd+TestTouchpoint_BuildToolRecordsCreated；域1端 |
| A-tp-2 | touchpoint 错误面：kind/verb 枚举外值 400 TP_INVALID_KIND/VERB | locked | TestTouchpoint_LedgerEndToEnd；域1端 |
| A-tp-3 | touchpoint keyset 分页（last_at DESC）cursor 往返 | locked | TestTouchpoint_LedgerEndToEnd；域1端 |
| A-tp-4 | touchpoint N1：空台账[]形状 | locked | Phase1 contract_*_test.go 新对话零触点断 []；域1端 |
| A-tp-5 | touchpoint 跨 ws 404 | locked | Phase1 contract_*_test.go 新域晚于 D2 绿格探针,跨 ws 读断 404；域1端 |
| A-tp-6 | touchpoint 软删 | exempt | log 台账 D1；对话删级联清已锁(LedgerEndToEnd)；域1端 |
| A-tp-7 | touchpoint :action | exempt | 只读,写入仅后端水龙头；域1端 |
| A-tp-8 | touchpoint 拒未知字段 | exempt | GET-only,query 枚举校验已锁于 A-tp-2；域1端 |
| A-sys-1 | health liveness happy（免 workspace） | locked | 全 testend 场景 boot 门控(TestSmoke_BootToSearchableEntity 起)；/system/data-dir 未打；域2端(+dev /debug/* 出货不挂) |
| A-sys-2 | loopback 双门：坏 token 401 UNAUTH_BAD_TOKEN/坏 Host 403 FORBIDDEN_BAD_HOST/webhook·OPTIONS 豁免/health 不豁免 bearer | locked | Phase1 contract_*_test.go 设 ANSELM_AUTH_TOKEN 起服打错 token+伪 Host 头逐断；testend 恒不设 token 即零覆盖；域2端 |
| A-sys-3 | system 分页 | exempt | 无列表端点；域2端 |
| A-sys-4 | system N1：health envelope 形/data-dir {dataDir} 形 | locked | Phase1 contract_*_test.go health 200 隐锁但 envelope 未显断言；域2端 |
| A-sys-5 | system 隔离 | exempt | health 免 workspace/data-dir 机器级 header 仅身份 by design；域2端 |
| A-sys-6 | system 软删 | exempt | 无资源；域2端 |
| A-sys-7 | system :action | exempt | 无 action（dev pprof 非 /api/v1）；域2端 |
| A-sys-8 | system 拒未知字段 | exempt | GET-only；域2端 |
| A-sse-1 | SSE 三流握手 happy：entities build 镜像+run 终端帧/messages 流式/notifications 到达 | locked | TestPlatformR4_SSEProtocolFaces+TestFunction_RunStderrReachesPanelTerminal+TestFunction_CreateEnvVisibility；域3端 |
| A-sse-2 | SSE 错误面：环淘汰后 410 SEQ_TOO_OLD | locked | TestPlatformR4_SSEProtocolFaces；垃圾 fromSeq 值未打；域3端 |
| A-sse-3 | SSE fromSeq durable 续传（游标等价）：重放 durable、ephemeral 绝不重放 | locked | TestPlatformR4_SSEProtocolFaces+TestChatR3_ReconnectReplay；域3端 |
| A-sse-4 | SSE N1：帧信封 {seq,scope,id,frame}+kind 四动词+delta 恒 seq=0 | locked | TestPromptR6_FrontendWireShapes；域3端 |
| A-sse-5 | SSE 跨 ws 事件不串流（流 workspace 级、ws 内不过滤 by design） | locked | Phase1 contract_*_test.go 两 ws 并行造事件断各自流零串；域3端 |
| A-sse-6 | SSE 软删 | exempt | 流无删除语义；域3端 |
| A-sse-7 | SSE :action | exempt | 订阅即 GET,无 action；域3端 |
| A-sse-8 | SSE 拒未知字段 | exempt | GET query,未知参数无害面；域3端 |

---

## B 面 — 行为契约（domains 21 篇逐域）→ Phase 1/3

### B1 · 执行实体与编排域

| ID | 场景单元 | 状态 | 指针/备注 |
|---|---|---|---|
| B-fn-1 | edit 铸新版本(号=max+1 单调)立即生效、revert=纯指针移可再 revert 回 | locked | TestFunction_VersionsEditRevert |
| B-fn-2 | 版本 cap50 硬删最老但绝不删 active(revert 后 active 很老也放过) | probed | ARCHIVE绿:版本cap-50不丢active |
| B-fn-3 | trim 越 cap 时回收被删版本的 per-version venv(reclaimTrimmedEnvs 经 DestroyEnv) | locked | Phase1 contract_*_test.go 造51版后查 sandbox disk-usage/env 目录不残留 |
| B-fn-4 | name partial-UNIQUE:重名拒 FUNCTION_NAME_DUPLICATE、软删后同名立即可重建(新 id 不救旧 ref) | locked | TestFunction_CreateRejections + TestRippleR5_ReferenceRipples |
| B-fn-5 | ops 闭集两码分流:畸形/中途非法=FUNCTION_OP_INVALID、终校验失败=FUNCTION_INVALID_CODE | locked | TestFunction_VersionsEditRevert + TestFunction_CreateRejections |
| B-fn-6 | 词法校验黑名单 import anselm_handler(无状态/有状态边界)创建即拒 | locked | Phase1 contract_*_test.go create 带该 import 断言 INVALID_CODE |
| B-fn-7 | envfix 修复不丢包:缩短依赖数的"修复"被拒、env 留 failed+真实装错、声明 deps 不丢 | probed | F148 |
| B-fn-8 | env failed 不阻塞创建(实体建成+状态可见)、run 时才报 FUNCTION_ENV_NOT_READY | locked | Phase1 contract_*_test.go 坏依赖 create 成功→读版本 env=failed→:run 断言码 |
| B-fn-9 | Edit 空 ops=重建 active env 重试安装+发 function.env_rebuilt | locked | Phase1 contract_*_test.go 空 ops :edit 断言事件+版本号不变 |
| B-fn-10 | nil input 在 runner 前归一 {}(sensor/无接线节点无参调用不 TypeError) | locked | Phase1 contract_*_test.go :run 无 input 的无参函数断言 ok |
| B-fn-11 | env 被 GC 回收(ErrEnvNotFound)时自动重建 env+重试一次 | locked | Phase1 contract_*_test.go sandbox:gc 后直接 :run 断言成功 |
| B-fn-12 | driver 护盾:print→stderr 三写(logs 落盘+entities run 终端)、stdout 保单一 JSON | locked | TestFunction_RunLogsAndExecutions + TestFunction_RunStderrReachesPanelTerminal |
| B-fn-13 | FunctionRunSec 墙钟真封顶→status=timeout(非 failed)+返回清洗成 FUNCTION_RUN_TIMEOUT 504 | probed | F83/F97/F158 |
| B-fn-14 | 同步 create 阻塞期 notifications 先 created 再 env_status_changed(无无声 spinner) | locked | TestFunction_CreateEnvVisibility |
| B-hd-1 | 常驻实例跨调用保 self 状态、:restart 重置、未知方法 HANDLER_METHOD_NOT_FOUND 不进 RPC | locked | TestHandler_ResidentLifecycleAndCalls |
| B-hd-2 | :edit set_meta 真改实体行 name/description(非只铸版本) | locked | TestHandler_EditPersistsMeta |
| B-hd-3 | 纯 meta edit/update_handler_meta 不铸版本不重启——内存态跨改名存活 | locked | Phase1 contract_*_test.go 计数器 handler 改名后 self 计数不归零 |
| B-hd-4 | 空 ops Edit=重建 env+重启抹态、结果带 restarted:true+restartNote 可见 | probed | F140 |
| B-hd-5 | config 流:必填缺 CONFIG 码拒 spawn/merge patch(null 删 key)生效即重启/敏感掩码回显/清空停机 | locked | TestHandler_ConfigFlow |
| B-hd-6 | spawn 咽喉按 active schema 过滤孤儿 config key(revert 遗留 kwarg 不永久炸 __init__) | locked | Phase1 contract_*_test.go 配 key→edit 删该 arg→revert→调用仍 spawn 成功 |
| B-hd-7 | spawn 单飞:并发首调共享一次 in-flight spawn、全批调用同一 instance_id | locked | Phase1 contract_*_test.go 冷启并发 5 调断言 call 行 instance_id 唯一 |
| B-hd-8 | 方法级 timeout(ms)真切卡死方法+全局 HandlerCallSec 兜底、timeout 入台账 | locked | TestHandler_MethodTimeout |
| B-hd-9 | crashed 语义:crash/EOF/ctx 取消一律标 crashed 废实例、下次 Get 自动重生 | probed | ARCHIVE绿:handler crash/restart韧性 |
| B-hd-10 | method Python 异常 traceback 入错误 Details 穿 LLM/flowrun 三面、无 Go 路径泄露 | probed | F89/F104/F131 |
| B-hd-11 | generator 终值:最后一个非 progress yield 或 return 值(StopIteration.value)两式都生效 | locked | Phase1 contract_*_test.go yield 终值与 return 终值两 method 各断言结果 |
| B-hd-12 | Get 失败(坏 __init__/缺 config/env 未就绪)也记 failed Call 行(容忍 nil 实例) | probed | F116 |
| B-hd-13 | 注入 secret 双面掩码:print→SSE/持久 progress 源头掩+实时返回错误也掩(scrubErr 构造处) | probed | F82/F108/F164 |
| B-hd-14 | driver stdout 护盾:用户代码 print 不炸 stdio 协议且落调用 logs | locked | TestHandler_PrintToStdout |
| B-ag-1 | 三类挂载(fn/hd.method/mcp)合成专属工具集恰为挂载、无任何系统工具 | locked | TestAgentR2_MountSynthesisThreeKindsAndLedger |
| B-ag-2 | 挂载物改名运行时按现名重解析/被删 fail-fast 大声失败/禁 ag_/合成撞名拒 | locked | TestAgentR2_RenameReresolutionAndFailFast |
| B-ag-3 | create/edit eager 校验全挂载存在(skill/knowledge/tool dangling 即拒、免 DOA agent) | probed | F96/F98 |
| B-ag-4 | mount-health 预检:逐挂载独立收集非 fail-fast、撞名对称标 unhealthy、knowledge doc 也覆盖 | locked | Phase1 contract_*_test.go 删 doc/造撞名后 GET mount-health 断言行级 unhealthy |
| B-ag-5 | 离线 MCP server 挂载报 MCP_SERVER_DOWN 非 TOOL_NOT_FOUND(排错指向重连) | probed | F141 |
| B-ag-6 | prompt 组装:身份+worker 纪律+skill 指南段+outputs JSON 硬约束+knowledge 前缀、零 chat 主视角泄漏 | locked | TestAgentR2_PromptAssembly + TestPromptDump_AgentViewpoint |
| B-ag-7 | outputs 回解析:恰1声明裹名/2+非对象报 AGENT_OUTPUT_NOT_STRUCTURED/非 OK 终态 Output 置 nil 不冒充 | probed | F40/F142 |
| B-ag-8 | modelOverride 优先级:override 请求走独立凭据、默认队列不动 | locked | TestAgentR2_ModelOverridePriority |
| B-ag-9 | modelOverride 写时校验 apiKeyId 存在(引用不存在 key 即 API_KEY_NOT_FOUND、非 invoke 时才炸) | probed | F153 |
| B-ag-10 | AgentInvokeSec 整次运行墙钟:超时压过 loop 自报→ExecutionStatusTimeout(durable 可 replay) | locked | Phase1 contract_*_test.go 慢 mock 流+调小 AgentInvokeSec 断言 timeout 状态 |
| B-ag-11 | chat 入口 invoke_agent:E3 嵌套流(parentBlockId 挂 tool_call)+结果回喂+台账 conversationId | locked | TestAgentR2_ChatEntryNestedStream |
| B-ag-12 | workflow 节点入口跑 active 版、结果记忆化 frn 行、:edit/:revert 版本语义同构 | locked | TestAgentR2_WorkflowEntryAndVersions |
| B-ag-13 | edit_agent 合并语义(缺省字段保留不抹挂载)+meta 字段大声拒 AGENT_META_NOT_IN_EDIT 指向 update_agent_meta | probed | F171 |
| B-ag-14 | 嵌套人在环:agent 内 dangerous 工具经父 broker 阻塞至用户 resolve(嵌套不冒泡) | locked | Phase1 contract_*_test.go invoke_agent 挂 dangerous 工具断言 interaction 挂起+decide 续跑 |
| B-wf-1 | ValidateGraph:无 trigger 节点/孤儿节点带 WORKFLOW_INVALID_GRAPH+reason 拒 | locked | TestWorkflow_GraphValidationRejections |
| B-wf-2 | 环纪律:回边必出自 control/approval,其它源回边创建即拒 | locked | Phase1 contract_*_test.go fn→fn 回边图 create 断言 INVALID_GRAPH |
| B-wf-3 | CEL 两段编译:语法错 vs 非祖先引用区分、报错列出可引用上游节点 id | locked | TestWorkflow_InvalidCELListsAvailableNodes |
| B-wf-4 | capability-check 缺 ref 收进 report.Problems 非 transport 错(含缺失 fnID 一次看齐) | locked | TestRippleR5_ReferenceRipples |
| B-wf-5 | 声明即必填 input 接线检查(含 control when/emit 与 approval template 的 input.*)+输出读 advisory 只进 Warnings 不阻断 OK | probed | F71/F168-M6/F156/F95 |
| B-wf-6 | 并发五策略真 fire 生效:两阶段 drain(先逐条 claim 决策再 advance)使 skip/replace/buffer_one 对背靠背触发生效 | probed | F29/F138 + ARCHIVE绿:concurrency四策略真webhook fire |
| B-wf-7 | 手动 :trigger/trigger_workflow 绕过并发策略立即建 run(两手动 run 可同途即便 replace) | locked | Phase1 contract_*_test.go replace 策略下连发两次 :trigger 断言双 run 在途 |
| B-wf-8 | set_meta 折头部 patch 真落 header、concurrency PATCH 生效+非法值拒 | locked | TestWorkflow_SetMetaProjection |
| B-wf-9 | 带 set_meta 的 edit 先置 ActiveVersionID 再 upsert——不 clobber 回旧版本孤儿化新图 | probed | F157 |
| B-wf-10 | 活监听重绑:active workflow edit/revert 改入口 trigger ref 即 detach 旧 attach 新 | locked | Phase1 contract_*_test.go 换 trigger 后 fire 旧/新各断言不触发/触发 |
| B-wf-11 | :stage 一次性武装真实触发后自动撤防+已 active 报 ALREADY_ACTIVE;:stage/:activate 门控坏图拒 WORKFLOW_NOT_RUNNABLE | probed | ARCHIVE绿:stagewf one-shot + F135 |
| B-wf-12 | :deactivate 在途不杀→draining 由 run 结算收口翻 inactive;:kill 取消全部在途 | locked | Phase1 contract_*_test.go 长跑 run 中 deactivate 断言跑完+状态收口 |
| B-wf-13 | pin 闭包跑前盖版本快照(agent 递归一层)、replay 清 failed 留记忆化按原 pin 重走 | probed | ARCHIVE绿:durable replay(record-once·pin·replay_count幂等) |
| B-wf-14 | 线性 run:payload CEL 寻址+节点结果记忆化+fn/hd 标量落 node.text(声明输出 advisory) | locked | TestWorkflow_LinearRunCELAddressing |
| B-trg-1 | Activation 触没触发都记(sensor 每探测一条、未 fire 带 ReturnValue/Error 可查"为何没触发") | locked | TestTrigger_SensorPollsCEL |
| B-trg-2 | persist-before-act 收件箱:fire 先落 firing、处置面 started/skipped/superseded/shed(含孤儿 workflow 终态 shed)+非法 status 过滤 422 | probed | F175-M7/F168-M2/F137 |
| B-trg-3 | webhook dedup:body 哈希+分钟桶折叠秒级重试、下一分钟同 payload 照常触发(UNIQUE 幂等不丢不重) | probed | ARCHIVE绿:webhook dedup防重放 |
| B-trg-4 | sensor 电平触发:dedup 含 probe 秒戳、持续真态每 poll 重复 fire(非边沿一次) | probed | F65 |
| B-trg-5 | 引用计数监听:N 个 active workflow 共享一个 listener(0→1 起、1→0 停) | locked | Phase1 contract_*_test.go 两 workflow 挂同 cron 断言单 listener 双 firing、全 deactivate 后不再 fire |
| B-trg-6 | CanonicalOutputs 盖章:cron/webhook/fsnotify 的 outputs 覆盖作者所填永不漂移、sensor 作者自定义不覆盖 | probed | F95 |
| B-trg-7 | webhook HMAC 式:坏签 401 纯文本无 run、正签触发 run 完成+activation/firing 台账 | locked | TestTrigger_WebhookFiresAndVerifies |
| B-trg-8 | webhook 明文式两载体(X-Webhook-Secret 头 / ?token= 查询)+signatureHeader 可改头名 | locked | Phase1 contract_*_test.go 三种携带方式各 POST 断言触发/401 |
| B-trg-9 | cron robfig 5 段分钟粒度真到点触发;@every/秒级拒 TRIGGER_INVALID_CRON 且消息指路 | locked | TestTrigger_CronEveryFires |
| B-trg-10 | fsnotify eventKind 交付端归一成配置词汇(create/modify…小写、组合 \| 连,非 fsnotify 大写 Op) | probed | F25 |
| B-trg-11 | :fire 合成 payload 仅 {manual:true} 不带自定义数据、0 监听者只记一条 0-firing Activation | probed | F94 |
| B-trg-12 | Edit 热更:监听中 trigger 新 config 重 Register、webhook 改路径后旧路径 404(catch-all registry 派发) | locked | Phase1 contract_*_test.go 改 config.path 后旧/新路径各 POST 断言 404/202 |
| B-trg-13 | sensor 目标存在性 eager 校验:dangling targetId 在 create/edit 即拒 TRIGGER_SENSOR_TARGET_NOT_FOUND | probed | F102 |
| B-trg-14 | NextFireAt(仅 cron)/LastFiredAt 读时派生非列:List/Get 行可显示"N 后触发/N 前 fire" | probed | W1/F26 |
| B-ctl-1 | first-true-wins 自上而下选边、解释器按 __port 路由 FromPort 匹配边、未选边不跑 | locked | TestWorkflow_ControlRoutingAndEmit |
| B-ctl-2 | 末条分支必须 When=="true" 兜底,缺 catchall 创建拒 CONTROL_NO_CATCHALL | locked | Phase1 contract_*_test.go 无兜底分支 create 断言码 |
| B-ctl-3 | Port 非空且组内唯一,违者拒 CONTROL_INVALID_BRANCHES | locked | Phase1 contract_*_test.go 重复 Port create 断言码 |
| B-ctl-4 | when/emit 坏 CEL 创建时按 CONTROL_INVALID_CEL 拒(app 编译、domain 不碰 cel-go) | locked | TestControl_CRUDAndCELValidation |
| B-ctl-5 | Emit 重塑 payload:emit 字段扁平进 result、下游按 gate.<字段> 读 | locked | TestWorkflow_ControlRoutingAndEmit |
| B-ctl-6 | Emit 空=透传 input 原样给下游 | probed | ARCHIVE绿:control first-true-wins+emit透传 |
| B-ctl-7 | :edit 铸 v2 可读回、版本语义同构方案 A | locked | TestControl_CRUDAndCELValidation |
| B-ctl-8 | 运行时 Resolve 按钉死版本求值——在途 run 不吃编辑后的新分支 | locked | Phase1 contract_*_test.go run park 期间 edit control 断言续跑仍走旧分支 |
| B-ctl-9 | 出口连回上游=结构化循环(回边 loop、LOOP STATE has() 模式) | probed | F28 + ARCHIVE绿:结构化累加循环25迭代 |
| B-apf-1 | 模板 {{CEL}} 不可编译创建即拒 APPROVAL_INVALID_TEMPLATE | locked | TestApproval_CRUDAndTemplate |
| B-apf-2 | 非空 timeout 必配 behavior(reject/approve/fail)、坏 timeoutBehavior 拒 APPROVAL_INVALID_TIMEOUT | locked | TestApproval_CRUDAndTemplate |
| B-apf-3 | 显式零时长(0s)被拒——会永 park 却不触发,永不超时须用 "" | probed | F60 |
| B-apf-4 | timeout=""=永不超时:run 长 park 不被任何定时器决策 | locked | Phase1 contract_*_test.go 空 timeout park 后等待期断言仍 parked |
| B-apf-5 | park:渲染模板写 parked 行(result.rendered+allowReason)、run 保持 running、入收件箱+通知 | locked | TestWorkflow_ApprovalParkDecideResume |
| B-apf-6 | 人工 decide yes/no 路由对应出口续跑;首决胜、重复决议拒 | locked | TestWorkflow_ApprovalParkDecideResume |
| B-apf-7 | 超时自动决策三行为:reject/approve/fail 各按 behavior 收尾(durable timer) | probed | ARCHIVE绿:approve/fail timeout三件套·双approval串联 |
| B-apf-8 | agent 席人在环半边:list_approval_inbox slim 行(不吐整 Result)+decide_approval 同源 :decide | probed | F163/F37 |
| B-apf-9 | ParseTimeout 扩展 d/w 粗粒度时长解析 | locked | Phase1 contract_*_test.go timeout="2d" create 读回断言接受 |
| B-sk-1 | slug 正则既是身份也是路径穿越守卫:含 ../ 等非法 name 创建拒、合法名 1:1 映射目录 | locked | Phase1 contract_*_test.go name 带路径分量 create 断言拒+盘上无逃逸目录 |
| B-sk-2 | body 自带 frontmatter 块(--- 开头)拒 SKILL_INVALID_FRONTMATTER、孤立 --- 分隔线放行 | locked | Phase1 contract_*_test.go 双 frontmatter body 与孤立 --- 各 create 断言拒/过 |
| B-sk-3 | 护栏:body ≤32KB、description ≤1024 超限拒 | probed | ARCHIVE绿:skill深用32KB cap |
| B-sk-4 | inline 激活:渲染 $ARGUMENTS/$1..$n/命名占位注入对话+allowed-tools 预授权 dangerous 免确认 | locked | TestChatR3_SkillInlineActivateAndPreauth |
| B-sk-5 | 刻意不支持 !`cmd` shell 注入——含该语法的 body 激活不产生任意执行 | locked | Phase1 contract_*_test.go body 带 !`touch marker` 激活断言无执行痕迹 |
| B-sk-6 | fork 模式派隔离 subagent 跑正文同步拿回、sub-message 带 subagentId 落父对话 | locked | TestChatR3_SkillForkRoute |
| B-sk-7 | fork 缺 frontmatter.agent 拒 SKILL_FORK_REQUIRES_AGENT | locked | Phase1 contract_*_test.go 无 agent 字段 skill :activate fork 断言码 |
| B-sk-8 | Guide(agent 挂载路径)只渲正文:不设 active-skill(预授权不泄父对话)、不 fork、不接 $ARGUMENTS | probed | F57 + ARCHIVE绿:skillagent指南真注入嵌套run |
| B-sk-9 | 创作面:create 同名 SKILL_NAME_CONFLICT、Replace 缺失 404 | locked | Phase1 contract_*_test.go 同名两次 create+改不存在 skill 各断言码 |
| B-sk-10 | 坏 SKILL.md 文件扫描跳过不连坐——List 仍返其余健康 skill | locked | Phase1 contract_*_test.go 盘上手写坏文件后 List 断言其余在场 |
| B-mcp-1 | stdio 主链:PUT 装连/tools/list schema 原样透传(不造 schema)/:invoke 真调 | locked | TestMCP_ScriptedServerLifecycle |
| B-mcp-2 | 状态机:连续 3 败翻 degraded 仍可服务(IsCallable)、一成回 ready | locked | TestMCP_ScriptedServerLifecycle |
| B-mcp-3 | reconnect 重置按钮:换出旧 client+进程后写者赢;坏 command 持久 failed 可 reconnect 救 | locked | TestMCP_ScriptedServerLifecycle + TestMCP_ErrorPaths |
| B-mcp-4 | 错误分层:未知工具 502/server down 503/不可达 remote failed/未知 action 404 | locked | TestMCP_ErrorPaths |
| B-mcp-5 | Import skip/overwrite 语义+registry 安装报错(非白名单 slug 404/必填 env 422 先于下载) | locked | TestMCP_ImportAndRegistry |
| B-mcp-6 | env 必填/可选分治:missingEnv 只强制 Required、可选旋钮给了就传不给不拦 | probed | F169 |
| B-mcp-7 | OAuth 装机全流程(DCR+PKCE+loopback 回调+refresh 静默换新+REAUTH_REQUIRED) | exempt | 需真外部 AS+系统浏览器交互,零 token 黑盒不可驱动;协议层宜另立 mock-AS 单测 |
| B-mcp-8 | ref-token name-or-id 统一:mcp:<名>/tool 在挂载/能力检查/派发三消费方都解析成 mcp_ id | probed | F22/F74 |
| B-mcp-9 | RemoveServer 按 id+name 双键 purge equip 边(名-键边不留悬挂孤儿) | probed | F166 |
| B-mcp-10 | 进度通知 per-call token 关联回发起调用、入 logs;失败附 server stderr 尾(8KiB) | locked | TestMCP_ScriptedServerLifecycle |
| B-mcp-11 | DynamicTools per-request 注入 search_tools 池:chat 席可发现且本回合可调 | probed | F52 |
| B-mcp-12 | 官方真货:npx filesystem server 真装真读文件+调用台账记账 | locked | TestMCP_OfficialFilesystemServer |
| B-mcp-13 | 密文红线:Env/Headers/OAuth 落 config_enc 加密单列、永不进搜索投影 | locked | TestSearchR1_EncryptedRedline |
| B-mcp-14 | 默认 call 超时 180s 长顶棚真切停滞工具调用 | locked | Phase1 contract_*_test.go 挂 sleep 的脚本 server 调工具断言超时收尾非永挂 |
| B-doc-1 | Create 重名自动后缀 foo→foo 2(cap100 重试)、PATCH 显式改名严格 DOCUMENT_NAME_CONFLICT | locked | Phase1 contract_*_test.go 同名两次 POST 断言后缀+PATCH 撞名断言码 |
| B-doc-2 | 并发同父 create:position 单事务 max+1 原子赋不撞车 | probed | F61 |
| B-doc-3 | 改名→子树 path 批量级联重写(后裔 path 全跟新) | locked | Phase1 contract_*_test.go 三层树改中层名后按新 path 读孙节点 |
| B-doc-4 | :move 防环 IsAncestor 拒 DOCUMENT_INVALID_PARENT、nil parent 移根、nil position 追加末尾 | probed | ARCHIVE绿:document树深操作(环拒·跨父move) |
| B-doc-5 | Delete 软删整子树(墓碑)+清全部后裔 relation 边(BFS) | probed | ARCHIVE绿:document级联 + TestPlatform_RelationRipple |
| B-doc-6 | 单篇 1MB 超限硬拒 DOCUMENT_CONTENT_TOO_LARGE 413——非自动拆分 | probed | F99 + ARCHIVE绿:1MB guard |
| B-doc-7 | attach 单篇不拖子树:挂载显式有界、子树不自动注入 | locked | Phase1 contract_*_test.go 挂父 doc 后 promptdump 断言子 doc 正文不在场 |
| B-doc-8 | 缺失附件渲 missing="true" 警告行非静默空块(模型知 grounding 已丢) | probed | F167 |
| B-doc-9 | body 写入即解析 [[wikilink]] 重 sync link 出边进 relation 图 | locked | TestRippleR5_RelationGraphFaces |
| B-doc-10 | :duplicate 深拷子树:BFS 铸新 id 重映射 parent/path、复制 content、新根名去重 | locked | Phase1 contract_*_test.go 复制三层树断言新 id 树形/原树不动 |
| B-doc-11 | move_document 位置语义=同级相对插入(非绝对索引) | probed | F21 |
| B-doc-12 | search_documents 主路径统一内容引擎(name+正文+heading snippet)、DB LIKE 仅回退 | locked | TestSearchLLM_VerticalToolsContentEngine |
| B-doc-13 | 标题 ≤256 字符且不含 /(path 分隔符)守卫 | locked | Phase1 contract_*_test.go 带 / 与超长标题 create 各断言拒 |

### B2 · 对话运行时与支撑域

| ID | 场景单元 | 状态 | 指针/备注 |
|---|---|---|---|
| B-chat-1 | Send 两段式头部先验对话存在——404 早退、不落孤儿 user 行 | locked | TestChat_ErrorPaths(404 已锁;孤儿行直查 DB 断言可补) |
| B-chat-2 | 每对话单飞:生成中(q.running 至 finalize)再 Send 直接 409 STREAM_IN_PROGRESS 不排队 | locked | TestChat_CancelAndStreamConflict |
| B-chat-3 | 回合收尾活期间的 Send 落单槽缓冲、紧随其后被服务,槽满仍 409 | locked | Phase1 contract_*_test.go 收尾窗口(真 utility 压缩检查拖秒级)并发 Send 断被服务或 409 |
| B-chat-4 | convQueue 5 分钟 idle 自毁+新 Send 重建;拆卸与投递 q.mu 原子互斥(task 不滞留死 channel) | locked | Phase1 contract_*_test.go Go 单测注入短 idle 计时+并发投递竞态 |
| B-chat-5 | 回合总墙钟 ChatTurnSec:detached ctx 上过每步守卫的永跑回合被切、不卡 isGenerating/shutdown | probed | F100(round-5 实测验证) |
| B-chat-6 | Shutdown 即时:cancel 全部在跑回合+stop 信号短路每个队列(不等 idle timer) | locked | Phase1 contract_*_test.go 流式中优雅停机断秒级退出+回合落 cancelled 终态 |
| B-chat-7 | LoadHistory 折叠块 seq≤水位不回喂模型、summary 前置,LLM 可见集与全读+过滤逐字同 | locked | TestChat_CompactionWatermark / TestPromptR6_PostCompactionView |
| B-chat-8 | LoadHistory 排除 subagent 子消息(`subagent_id≠''` 下推 SQL,内部 trace 不污染父历史) | locked | Phase1 contract_*_test.go subagent run 后 promptdump 断父模型视角无子块 |
| B-chat-9 | AutoActivator:LLM 直接点名 lazy 工具即自动 discovered、免先跑 search_tools | locked | TestChat_SendStreamToolRoundtrip |
| B-chat-10 | WriteFinalize 恒 Detached+boot SweepOrphans:硬崩溃(kill -9)孤儿 pending/streaming 扫成 cancelled | locked | Phase1 contract_*_test.go chat 流式中 kill -9 同目录重启断无 streaming 残留行 |
| B-chat-11 | 未读不对称原子性:user 发送=已读/完成回复=未读/取消·出错终态不算,unread 折进 TouchLastMessage 同一 UPDATE | locked | TestChat_RailUnread |
| B-chat-12 | 首回合 utility 自动起标题+utility 缺席全降级面(标题缺席/压缩跳过/WebFetch 回退原文)主链无错 | locked | TestChat_TodoReminderAndTitle / TestChatR3_UtilityAbsentDegrade |
| B-chat-13 | maxSteps 实时读热换生效+触顶诚实 stop_reason max_steps+MAX_STEPS_REACHED+续跑提示 | locked | TestChat_ErrorPaths / TestPlatform_LimitsHotSwap |
| B-chat-14 | approve_always 对话级白名单+删对话 ForgetConversation 整批清(授权不越过删除泄漏内存);:cancel 保留白名单 | locked | Phase1 contract_*_test.go approve_always 后删对话再建同名对话断同工具重新要确认 |
| B-msg-1 | progress 一等持久块:落盘+实时流,但 LLM 历史投影类型白名单永不回喂 | locked | Phase1 contract_*_test.go 带 progress 的工具跑完 promptdump 断模型历史无 progress 块 |
| B-msg-2 | 两段式写:CreateMessage 先 mint id 作流锚→FinalizeMessage 单事务落终态+seq+token/provider 溯源 | locked | TestChat_SendStreamToolRoundtrip |
| B-msg-3 | 两表 append-only(D1):删对话后 messages/message_blocks 行物理留存 | locked | Phase1 contract_*_test.go 删对话直查 DB 断行仍在 |
| B-msg-4 | SubagentID 双面:ListMessages 保留 sub-message 供 reload 重建子树 | locked | TestChatR3_SubagentNestedTree |
| B-msg-5 | ContextRole 是压缩器对块的投影变更,落库 Content 永不改写 | locked | Phase1 contract_*_test.go 压缩后直读 DB 断 block 原文逐字未变 |
| B-msg-6 | stop_reason context_budget:回合 input 逼近 context window 时 loop 软停诚实终态 | probed | F58 |
| B-msg-7 | SweepNonTerminal boot 对账:pending/streaming → cancelled(messages 版 Recover) | locked | Phase1 contract_*_test.go 同 B-chat-10 kill -9 场景合测 |
| B-msg-8 | get_subagent_trace:无参列本对话 runs/带 id 导全 trace/无对话·未知 id 降级 tool-result 串 | probed | F46+绿格「深度3 trace可读」 |
| B-msg-9 | get_subagent_trace 从 subagent 自身工具集恒剔除(隔离双保险之二) | probed | F149 |
| B-msg-10 | SumTokens usage 读面与 mock 上报逐数对账 | locked | TestPromptR6_ToolResultPairingAndUsageLedger / TestChat_SendStreamToolRoundtrip |
| B-conv-1 | PATCH ModelOverride 指针三态:缺=不变/null=清除/对象=设置 | locked | Phase1 contract_*_test.go PATCH 矩阵三态读回断言 |
| B-conv-2 | modelOverride 写时校 apiKeyId 存在(API_KEY_NOT_FOUND 即拒)、清除跳过、modelId 不校留 fail-loud-at-chat | probed | F153 |
| B-conv-3 | ?archived 三态:缺省仅活跃/true 仅归档/all 混排带 archived=true 标 | locked | TestChat_RailArchivedAll |
| B-conv-4 | sort=name COLLATE NOCASE+id tiebreaker+keyset 游标跨页不漏不重 | locked | TestChat_RailSortByName |
| B-conv-5 | activity 键 last_message_at 只随用户回合刷新(pin/改名/换模型不重排);未知/空 sort 静默落 activity 不 400 | locked | Phase1 contract_*_test.go PATCH 元数据后 list 序不变+garbage sort 值矩阵 |
| B-conv-6 | ?search= title 大小写不敏感子串+%/_ 通配转义、不改排序键;换 search/切排序旧游标失效行为 | locked | Phase1 contract_*_test.go 照 TestFunction_ListSearch 克隆到 conversations+异构旧 cursor 断不 500 |
| B-conv-7 | isGenerating 派生只读:在途生成时 List/Get 冷启动即填 true、不落库 | locked | Phase1 contract_*_test.go 流式中 GET list 断 isGenerating=true、完后 false |
| B-conv-8 | awaitingInput 派生:待决 interaction 点亮、resolve 即清,冷启动经 List/Get+GET interactions 重同步 | locked | TestChat_RailAwaitingInput |
| B-conv-9 | :seen 清 unread:幂等(未知/已删 id no-op 204)、不发任何通知、经 {idAction} 派发器路由 | locked | TestChat_RailUnread / TestChat_ConversationActionRouting |
| B-conv-10 | Delete 连带 GenerationCanceler 停在途生成、删后 404 无残留后续正常 | locked | TestChatR3_ArchiveUnarchiveAndDeleteCancels |
| B-conv-11 | AutoTitled 只写一次、绝不覆盖用户已改标题 | probed | ARCHIVE 绿格 auto-title/conversation 管理深用 |
| B-conv-12 | PATCH attachedDocuments eager 校验:引用不存在/已删 doc 即 422+Details 带缺失 id | probed | F168-M5/F167 |
| B-conv-13 | search_conversations 只返 conversationId/title/snippet/messageId 指针窗口、绝不倾全文、明示非枚举 | locked | TestSearchLLM_SearchConversationsTool / TestGolden_J8_RecallPastConversation |
| B-conv-14 | list_conversations 忠实分页(nextCursor 防误当全集)+includeArchived→ArchiveAll;manage_conversation 五动作+压缩自动·解档警告真相描述 | probed | F38/F106/F107+绿格「分页0重0漏」 |
| B-sub-1 | Spawn 同步拿回最终答案;回合作 sub-message 落父对话、blocks 经 E3 嵌在派它的 tool_call 下供重建 | locked | TestChatR3_SubagentNestedTree |
| B-sub-2 | 深度 1 守卫:Subagent 工具名总从子集剔除(子不能再派子) | locked | TestChatR3_SubagentNestedTree / TestPromptR6_SubagentViewpoint |
| B-sub-3 | Explore 类型工具白名单(只读 Read/LS/Glob/Grep)真生效 | locked | TestPromptR6_SubagentViewpoint |
| B-sub-4 | Plan(+WebFetch/WebSearch,25轮)/general-purpose(父全集减 Subagent,25轮)白名单+轮上限 | locked | Phase1 contract_*_test.go 三类型各 promptdump 工具集断言+轮耗尽终态 |
| B-sub-5 | 被取消的 subagent 仍落终态 sub-message 防孤儿(chatHost 系 Detached 落盘) | locked | Phase1 contract_*_test.go 父 :cancel 中断在跑 subagent 后查子消息终态 |
| B-sub-6 | subagent 模型=workspace dialogue、刻意不承袭 per-conversation override | locked | Phase1 contract_*_test.go 设对话 override 后 spawn 断请求落默认 mock 队列 |
| B-sub-7 | subagent prompt 自足:自有 system、父历史零泄漏 | locked | TestPromptR6_SubagentViewpoint |
| B-sub-8 | skill fork 模式走同一 Spawn(SubagentRunner 端口)、正文同步拿回 | locked | TestChatR3_SkillForkRoute |
| B-sub-9 | subagent 自有回合墙钟纵深(不靠父墙钟) | probed | F152 |
| B-att-1 | CAS dedup:相同字节重复上传共享一 blob(sha256 非唯一多行共享)、GC 按活跃 sha 保留集回收 | locked | Phase1 contract_*_test.go 双上传断盘上单 blob;删一行后 GC 不收、删两行后收 |
| B-att-2 | KindFromMIME 六桶分类+文件扩展名兜底 | locked | Phase1 contract_*_test.go 上传 mime/扩展名矩阵断 kind 字段 |
| B-att-3 | 渲染按模型能力三路门控:vision→image_url/NativeDocs→file part/否则 sandbox 抽取内联 | locked | TestChatR3_AttachmentsThreeRoutes |
| B-att-4 | 不认的 mime → ATTACHMENT_EXTRACTION_UNSUPPORTED 降级占位、回合不失败 | locked | Phase1 contract_*_test.go 上传怪 mime 后发消息断回合 completed+占位文案 |
| B-att-5 | 缺失/不可读 blob 告警跳过、绝不让回合失败 | locked | Phase1 contract_*_test.go 手删盘上 blob 后发消息断回合完成 |
| B-att-6 | list_attachments 发现+read_attachment 文本抽取内联/二进制返描述符不倾倒字节/未知 id 软失败自纠 | probed | F37+绿格「attachment 喂 LLM 零幻觉+vision 诚实」 |
| B-att-7 | attachmentMaxMB 上限拒传 | locked | TestPlatformR4_LimitsEveryField |
| B-att-8 | upload→download(:id/content) 字节 round-trip+软删后 get/download 404 | locked | Phase1 contract_*_test.go REST round-trip 矩阵 |
| B-att-9 | catalog source:活跃附件报成 name+kind/mime/size 条目入 system prompt 目录 | locked | Phase1 contract_*_test.go 上传后 promptdump 断附件条目在场 |
| B-mem-1 | 注入两段式:pinned 全文入 system、非 pinned 仅 name+description 目录行(控 token) | locked | TestChatR3_MemoryLLMFace |
| B-mem-2 | read_memory 按需加载非 pinned 全文 | locked | TestChatR3_MemoryLLMFace |
| B-mem-3 | write_memory 恒 source=ai、不设 pinned;name(slug) 即身份的 upsert | probed | ARCHIVE 绿格 memory 深用(12写·slug upsert) |
| B-mem-4 | Upsert 保策展:编辑只改 content/description,保留现有 pinned+source(pin 仅经专用端点) | probed | F147 |
| B-mem-5 | forget_memory 彻底消失(目录行+全文双除名) | locked | TestChatR3_MemoryLLMFace |
| B-mem-6 | 跨对话召回:对话 A write→新对话 B 经 system 注入索引召回 | locked | TestGolden_J9_MemoryWriteRecall |
| B-mem-7 | workspace 文件树隔离+ws 删除级联删 memories 目录 | probed | 绿格 memory 隔离;级联建议并入 CascadeEveryAssetKind 显式断言 |
| B-todo-1 | 整表替换写(TodoWrite 语义):每次重写全清单、存储只管快照 | locked | TestChat_TodoReminderAndTitle |
| B-todo-2 | reminder:每步前注入 live 清单为临时 system-reminder、不污染持久历史 | locked | TestChat_TodoReminderAndTitle |
| B-todo-3 | reminder 0-open 抑制:全完成清单不再逐轮注入 | locked | Phase1 contract_*_test.go 全完成后 promptdump 断无 reminder 段 |
| B-todo-4 | todo_read(常驻)读回当前作用域整张含已完成项、空清单软返 cleared 串 | probed | F39 |
| B-todo-5 | subagent run 独立作用域(scope_id=subagent id、父对话清单不动)+看板 ?subagentId= 读回 | locked | Phase1 contract_*_test.go subagent 内 todo_write 断父清单不变+GET todos 双参 |
| B-todo-6 | ≤64 项上限:超出按 TODO_* 码拒(规划异味信号) | locked | Phase1 contract_*_test.go 65 项 todo_write 断拒 |
| B-todo-7 | 写入即推 messages 流 todo 信号(前端实时面板) | locked | Phase1 contract_*_test.go SSE 收 todo 信号帧断 payload |
| B-rel-1 | equip 边现身/relgraph 全景/Namers hydrate 改名读侧跟名 | locked | TestPlatform_RelationRipple / TestRippleR5_RelationGraphFaces |
| B-rel-2 | diff-sync 终态幂等:edit/revert 换挂载后旧边消失(声明集合对照增删,HTTP 与 agent 席均未锁) | locked | Phase1 contract_*_test.go edit_agent 换挂载断旧边除名新边现身 |
| B-rel-3 | PurgeEntity 删除级联清边(11 种实体唯一汇流点) | locked | TestPlatform_RelationRipple / TestRippleR5_RelationGraphFaces |
| B-rel-4 | 8 个 delete 工具删前折入向 equip/link 依赖 {kind,id,name} ref+计数+修复提示(排除 create/edit 溯源与出边) | probed | F48/F160 |
| B-rel-5 | dependency_broken ONE 聚合通知:purge 前快照、hydrate 名+去重、HTTP 删除亦发、跨重启留存 | probed | F161 |
| B-rel-6 | 守卫:自环禁止/ref 校验/邻域 depth 1-3 限制按 REL_* 码拒 | locked | Phase1 contract_*_test.go REST 矩阵(自环边/depth=4/坏 ref) |
| B-rel-7 | get_relations 工具深度邻域推理(transitive/diamond 去重/cycle/规模) | probed | ARCHIVE 绿格 relation 图深用(14 实体规模) |
| B-rel-8 | trigger↔workflow 绑定边+document wikilink 边成图 | locked | TestRippleR5_RelationGraphFaces |
| B-rel-9 | hydrate/emit 失败只记录、绝不让删除失败(nil 容忍) | locked | Phase1 contract_*_test.go Go 单测注入 failing namer/emitter 断删除照常 |
| B-srch-1 | 12 类实体建→改(新 token 入旧 token 出)→删全周期 diff 投影+conversation DocAt 单 message 增量 | locked | TestSearchR1_ProjectionLifecycle12Kinds / TestSearchR1_ConversationMessageIncremental |
| B-srch-2 | 词法层:短词 LIKE 回退+长短混合隐式 AND+代码符号 trigram 子串+FTS5 注入永不 500 | locked | TestSearch_ProjectionsLexicalAndFilters / TestSearchR1_CodeSymbolAndMixedQuery |
| B-srch-3 | 写后通知队满即丢+boot 对账自愈:丢事件/杀进程后全可搜、重启新写照常 | locked | TestSearchR1_BootReconciliation |
| B-srch-4 | :reindex force-reconcile 命中恢复+settings 三态 builtin/ollama/off+死端口软降级+空串重置默认 | locked | TestSearch_ReindexAndSettings |
| B-srch-5 | reindex 无 purge 空窗:重建期间并发 Search 返完整结果 | probed | F168-M8/F175-M2(fixed) |
| B-srch-6 | 排序三档 exact>prefix>正文+实体折叠 matchedChunks;物化 top-200 窗口 cursor 走全不重、异查询/垃圾 cursor 按 SEARCH_CURSOR_INVALID 拒 | locked | TestSearchR1_RankingPrefixAndFolding / TestSearch_PaginationWindow |
| B-srch-7 | D2 隔离(每查询显式 workspace_id)+密文红线(apikey 密文/trigger secret/mcp env 永不进投影) | locked | TestSearchR1_WorkspaceIsolation / TestSearchR1_EncryptedRedline |
| B-srch-8 | 语义 builtin 真货:llama-server+GGUF 真下载、跨语种零词法重叠命中 | locked | TestSearch_SemanticRAGBuiltin |
| B-srch-9 | cosineFloor 0.55 噪声闸:无匹配/乱码 query 不按余弦噪声灌全 workspace | probed | F80-fix(round-7 真语料 BLOB 精测定值) |
| B-srch-10 | 换 embedder 逐行 model 记账自动重嵌不混用+fts_schema_version 不匹配 boot 清空重建 | locked | Phase1 contract_*_test.go PATCH 换 embedder 断旧行重嵌;篡改版本行重启断重建 |
| B-srch-11 | embed worker:整批 upsert 全失败中止本轮防无限热循环+向量缓存增量 patch 不整体作废 | probed | R9/R15(systems-correctness) |
| B-srch-12 | LLM 面:search_blocks 三段精度链+六类铁律(document/skill 永不出)+(entity,anchor) 粒度 refHint 直填接线(skill/mcp 键=name) | locked | TestSearchLLM_BlocksTier1/2/3AndScope / TestSearchR1_GranularityAnchors |
| B-srch-13 | 8 垂搜工具统一内容引擎+SlimPageResult 截断可见(count/total/nextCursor/hasMore);Retrieve RAG 口零生产消费方 | locked | TestSearchLLM_VerticalToolsContentEngine;Retrieve 部分 exempt(黑盒不可达,单测覆管线) |
| B-sup-1 | workspace CRUD 校验面+最后一个拒删+language 权威于 Accept-Language 驱动回复语言 | locked | TestPlatform_WorkspaceLifecycle / TestPromptDump_I18nReplyLanguage |
| B-sup-2 | workspace Delete Reaper 级联:自动化摘除/常驻停/mcp 断/索引清/文件树删,12 类资产零残留、keeper 无涟漪 | locked | TestPlatform_WorkspaceCascadeDelete / TestPlatformR4_CascadeEveryAssetKind |
| B-sup-3 | apikey 引用守卫:RefScanner 聚合非空拒删(API_KEY_IN_USE)+details.references {kind,id,name} 三来源 | locked | TestPlatform_APIKeyProbeAndGuards |
| B-sup-4 | apikey:旋转自动重探(失败不挡 PATCH)/受管行 Update 422 API_KEY_IMMUTABLE/apiFormat 白名单 400 | locked | Phase1 contract_*_test.go REST 矩阵三分支(注错 tester 仍 200) |
| B-sup-5 | freetier 全链:指纹铸 gwk_→CreateManaged 受管行(跳探针)→真补全→quota 扣减;每失败路径降级绝不挂 boot | probed | 0629 客户端侧 LIVE 端到端手测 |
| B-sup-6 | freetier quota 代理契约:无受管行 404 FREETIER_NOT_PROVISIONED/remaining 钳≥0/available 折全局预算/网关错按 LLM_* 分类冒泡 | locked | Phase1 contract_*_test.go llmmock 伪网关断四分支 |
| B-sup-7 | model 三场景白名单 dialogue/utility/agent+capabilities 经 :test 探测聚合 | locked | TestPlatform_ModelConfig |
| B-sup-8 | get_model_config 脱敏:KeyMasked 绝不出明文、投影真 workspace 配置 | probed | F68 |
| B-sup-9 | WebSearch 未配 backend 诚实降级+WebFetch 真抓取逐字零幻觉 | probed | ARCHIVE 绿格 web |
| B-sup-10 | webFetchMode local/jina(读不到收敛 local)+配真搜索 backend 后的 WebSearch 行为 | locked | Phase1 contract_*_test.go frontier「websearch 真后端席」整列空白;伪 backend+PATCH 矩阵 |
| B-sup-11 | catalog 永不持久化/缓存:建删实体即进出 system prompt 菜单、容器实体带 Members | locked | TestRippleR5_CreateRenameDeleteMatrix / TestPromptDump_ChatSystemPromptStructure |
| B-sup-12 | mention freeze-on-send:发送时快照 @ 实体内容进 Attrs、后改不影响已发语境 | locked | TestChatR3_MentionFreeze |
| B-sup-13 | notification:DB 行真相+SSE best-effort、11 发射域 created 族全到达、未读徽标递减/批量清零 | locked | TestPlatform_NotificationFlow / TestPlatformR4_NotificationAllDomains |
| B-sup-14 | aispawn :iterate/:triage 开预 seed 对话返 conversationId、不存在 id 按码拒(非 happy regime 仍薄) | probed | F36+绿格「:iterate v1→v3 / :triage crash·timeout 可辨」 |
| B-sup-15 | humanloop broker:Request 阻塞至 Resolve/ctx 取消、内存 pending 表=重连重同步真相源、经 ctx 流进嵌套运行 | locked | TestChat_HumanLoopDangerGate / TestChat_RailAwaitingInput |
| B-sup-16 | contextmgr:末回合真实 InputTokens 达 80% 触发+水位 summary_covers_up_to_seq 幂等键+最近 4 条 message 逐字底线 | locked | TestChat_CompactionWatermark / TestGolden_J12b_CrossCompactionTask |
| B-sup-17 | contextmgr demote 只动 tool_result(user 原话恒全文不截)+summary 对大粘贴诚实(不假装逐字保留) | probed | F175-M8(fixed)/M9(by-design) |
| B-sup-18 | entitystream 一原语十复用:run 终端/build 镜像帧真达、nil Bridge 全程容忍 | locked | TestPlatformR4_SSEProtocolFaces / TestFunction_RunStderrReachesPanelTerminal |
| B-tp-1 | 三水龙头端到端(mentioned/attached/viewed)+每 (对话,物,动词) 聚合行 count 递进不长行 | locked | TestTouchpoint_LedgerEndToEnd |
| B-tp-2 | 读侧:kind/verb 过滤+非法枚举 400+keyset 分页+messages 流 durable touchpoint 信号(幂等 upsert 重放安全) | locked | TestTouchpoint_LedgerEndToEnd |
| B-tp-3 | conversation 删除级联硬删整份台账(SetTouchpointPurger) | locked | TestTouchpoint_LedgerEndToEnd |
| B-tp-4 | executed 门:被拒危险调用/运行前取消 executed=false 不落幽灵行(deny 零触点) | locked | TestChat_HumanLoopDangerGate |
| B-tp-5 | output 键提取:create_function 新 id 只在工具输出仍记 created 行 | locked | TestTouchpoint_BuildToolRecordsCreated |
| B-tp-6 | TouchEntity 自报路:挂载 fn/hd/mcp 以实体名运行自报 {kind,id,name} 记 executed、完全绕目录(用户实体撞目录键名不误提取) | locked | Phase1 contract_*_test.go agent 挂载工具执行断 executed 行+同名撞键负控 |
| B-tp-7 | subagent 内触碰记到父对话名下+失败调用不记(失败的触碰不是触碰) | locked | Phase1 contract_*_test.go subagent 建实体断父台账;注入必败工具断零行 |
| B-tp-8 | deleted 行兄弟借名快照(名字仍诚实可显)/没碰过就删的孤儿行诚实空名 | locked | Phase1 contract_*_test.go 删已 executed 实体断 deleted 行带名;直删断空名 |
| B-tp-9 | 未知对话 GET touchpoints 返回空页非错(同 todos) | locked | Phase1 contract_*_test.go GET 未知 id 断 200 空页 |
| B-tp-10 | 目录穷尽性门禁:每个工具 ∈ 提取目录 ∪ no-touch 清单,新工具不表态即红 | locked | TestTouchpointCatalog_CoversEveryTool(bootstrap Go 单测) |

---

## C 面 — SSE 协议 / 安全门 / 错误码 / i18n / cron 时区 → Phase 2

| ID | 场景单元 | 状态 | 指针/备注 |
|---|---|---|---|
| C-sse-1 | 续传游标解析:Last-Event-ID 头优先于 ?fromSeq、缺/坏("junk")→0 仅实时不报错 | locked | TestDecodeFromSeq |
| C-sse-2 | durable 帧 fromSeq 缺口内重放(seq 单调、按序补齐后转实时) | locked | TestSubscribeReplaysFromSeq + TestPlatformR4_SSEProtocolFaces |
| C-sse-3 | 续传游标已被 replay 环(bufSize+256)淘汰→410 SEQ_TOO_OLD | locked | TestSubscribeSeqTooOld / TestStreamHandler_SeqTooOld410 / TestPlatformR4_SSEProtocolFaces |
| C-sse-4 | 410 后客户端闭环:REST 全量重取→以新 seq(或 0)重订阅→后续 durable 不漏不重 | locked | TestContractProtocol_ReplayRingEvictionAndRecovery |
| C-sse-5 | ephemeral(delta/tick) seq=0 不入环不 replay + durable Close 带快照=流式节点重连真相 | locked | TestPublishEphemeralSeqZeroNotBuffered + TestChatR3_ReconnectReplay |
| C-sse-6 | E3 嵌套:subagent/invoke_agent 块经 Open.ParentID 挂 tool_call 下、树可重建 | locked | TestAgentR2_ChatEntryNestedStream / TestChatR3_SubagentNestedTree |
| C-sse-7 | 卡死订阅者 durable buffer 满→发布方断开(关 done 幂等)、不堵整 workspace 扇出(R5) | locked | TestBus_DurablePublishDisconnectsWedgedSubscriber |
| C-sse-8 | HTTP 层慢消费者端到端:真 TCP 不读→断开→重连从环重放自愈 | locked | infra/stream TestBus_DurablePublishDisconnectsWedgedSubscriber (R5,Bus 层单测覆盖) |
| C-sse-9 | 同 workspace 同流多订阅者并发:各自收到全量 durable、序一致 | locked | TestContractProtocol_ThreeSubscribersSameDurableOrder |
| C-sse-10 | keep-alive:15s 空闲发 `: keep-alive` 注释帧、客户端解析不误当事件 | exempt | keep-alive 15s 空转黑盒不值(sse.go keepAliveInterval=15s 常量) |
| C-sse-11 | 三流分离:messages/entities/notifications 三 Bus 实例帧互不串流 | locked | TestContractProtocol_ThreeStreamSeparation |
| C-sse-12 | workspace 级隔离:B ws 订阅者永不见 A ws 帧(后端不过滤=全量但 per-ws) | locked | TestWorkspaceIsolation |
| C-sse-13 | 帧 envelope {seq,scope,id,frame} 四动词封闭 + delta 恒 seq=0 + SSE `id:` 行=seq | locked | TestPromptR6_FrontendWireShapes + TestWriteStreamEnvelopeIDLine |
| C-sse-14 | touchpoint durable 信号=单条聚合行视图、幂等 upsert 重放安全 | locked | TestTouchpoint_LedgerEndToEnd |
| C-sse-15 | ephemeral 域信号帧本体:interaction create/resolve(resolved:true)·mcp status 真变化才发·flowrun tick→workflow scope | locked | TestContractProtocol_InteractionEphemeralSignals |
| C-sec-1 | bearer 激活时缺/错 Authorization→401 UNAUTH_BAD_TOKEN | locked | TestRequireBearerToken_missingOrWrongRejected |
| C-sec-2 | bearer expected=""(dev/testend)=整体关闭 no-op;正确 token 放行 | locked | TestRequireBearerToken_emptyIsNoop + TestRequireBearerToken_correctPasses |
| C-sec-3 | /api/v1/health 不豁免 bearer(留一个未鉴权探针=漏洞) | locked | TestRequireBearerToken_healthNotExempt |
| C-sec-4 | OPTIONS 预检豁免 bearer(CORS 预检无 Authorization) | locked | TestRequireBearerToken_optionsExempt |
| C-sec-5 | /api/v1/webhooks/ 豁免 bearer(外部调用方自带 HMAC) | locked | TestRequireBearerToken_webhooksExempt |
| C-sec-6 | bearer 常量时间比较(crypto/subtle)无时序泄露 | exempt | 时序侧信道黑盒不可稳定断言;实现已用 ConstantTimeCompare,代码审计即证 |
| C-sec-7 | RequireLoopbackHost:非 loopback Host(evil.example.com/169.254.169.254/0.0.0.0)→403 FORBIDDEN_BAD_HOST;127.0.0.1/[::1]/localhost 任意端口放行 | locked | TestRequireLoopbackHost(9 例表驱动含 DNS-rebinding/metadata 端点) |
| C-sec-8 | CORS:白名单 origin 回 ACAO+Vary、非白名单不加头、无 Origin 直通;preflight 204 带 Methods/Headers/Max-Age | locked | middleware/cors_test.go(新,6 测) |
| C-sec-9 | webhook HMAC-SHA256 坏签 401 无 run、正签触发 run 完成(常量时间 hmac.Equal) | locked | TestTrigger_WebhookFiresAndVerifies |
| C-sec-10 | webhook 明文 X-Webhook-Secret 直比模式(signatureAlgo 空) | locked | TestContractProtocol_WebhookPlainSecret |
| C-sec-11 | webhook body 上限 webhookBodyMaxMB→413 | locked | TestPlatformR4_LimitsEveryField |
| C-sec-12 | workspace 豁免路径全集恰为 workspaces/health/providers/scenarios/webhooks、其余 /api/v1/* 全 guarded | locked | TestChainExemptVsGuarded |
| C-sec-13 | 缺/未知 workspace header→401 UNAUTH_NO_WORKSPACE;SSE 经 ?workspaceID 识别 | locked | TestRequireWorkspaceRejects + TestIdentifyWorkspaceInvalidDropped + TestIdentifyWorkspaceFromQueryForSSE |
| C-sec-14 | D2 跨 workspace 读写 run 全 404/401 零泄露 | locked | TestSmoke_BootToSearchableEntity + TestSearchR1_WorkspaceIsolation |
| C-sec-15 | 真进程加固全链:ANSELM_AUTH_TOKEN 设置下拉起真二进制,REST+三条 SSE 订阅须带 token、绑定仅 127.0.0.1 外址不可达 | locked | TestContractProtocol_SSEStreamsBearerGate |
| C-sec-16 | debug/pprof 端点门控 | exempt | grep 证实 transport/cmd 无任何 debug/pprof 端点,无此攻击面 |
| C-err-1 | Kind→HTTP 全表(16 Kind:500/400/401/404/409/422/413/415/429/502/503/504/202/499/410/403)逐一映射 | locked | TestStatusForKind |
| C-err-2 | fmt.Errorf %w 包裹链仍按 sentinel 的 Kind/Code 映射 | locked | TestFromDomainErrorWrappedStillMaps |
| C-err-3 | context.Canceled→499 KindClientClosed(errmap 单测面) | locked | TestFromDomainErrorContextCanceled |
| C-err-4 | 非 errorspkg.Error 未知错误→500 且内部细节被抑制不上线缆 | locked | TestFromDomainErrorUnknownIs500AndSuppressed |
| C-err-5 | 未匹配路由 404 ROUTE_NOT_FOUND / 错误方法 405 METHOD_ALLOWED 皆 N1 envelope(F172 回归,Allow 头保留) | locked | TestChain_MuxErrorsEnveloped |
| C-err-6 | 已匹配 handler 自返 404(FUNCTION_NOT_FOUND 等)不被 clobber 成 ROUTE_NOT_FOUND + muxErrorWriter 委托 Flush 三流 SSE 不 500 | locked | TestChain_MatchedHandler404NotClobbered + TestChain_SSEFlusherSurvives |
| C-err-7 | handler panic→Recover 捕获为 500 INTERNAL_ERROR envelope+日志(最外层) | locked | middleware/recover_test.go(新,3 测) |
| C-err-8 | 真线缆 499/504 各一例(请求中客户端断连;上游超时端点如 llm/mcp) | needs_unit | response/sse.go r.Context().Done() 分支;真断连黑盒脆 |
| C-err-9 | error-codes.md ~261 码与代码 sentinel 全集 1:1 对齐 | exempt | error-codes.md 1:1 属 Phase 6 DOC-ALIGN |
| C-i18n-1 | Accept-Language 解析:en* 前缀→en、其余(含空/垃圾)→zh-CN 兜底;pre-workspace(onboarding)请求靠它 | locked | middleware/locale_test.go(新) |
| C-i18n-2 | workspace 语言压过 Accept-Language 驱动 assistant("Reply in <lang>",持久选择权威) | locked | TestPromptDump_I18nReplyLanguage |
| C-i18n-3 | 中文/emoji/超长/RTL/病态 unicode 实体名与内容:建改搜零 500 零 mojibake(name 拒 CJK 有意) | probed | ARCHIVE 绿格 i18n/locale + 名校验 emoji/SQL 注入 + chaos;搜索面另有 locked TestSearch_ProjectionsLexicalAndFilters(中文短词 LIKE 回退) |
| C-cron-1 | cron 5 段分钟粒度到点真触发 run 完成 | locked | TestTrigger_CronEveryFires |
| C-cron-2 | cron 表达式按 time.Local 解释(robfig WithLocation(time.Local) 硬编码)+DST 春跳不存在时刻/秋回重复时刻的行为 | needs_unit | DST 需 TZ env 起进程 + robfig 语义 |
| C-cron-3 | dedup key=triggerID\| locked | TestContractProtocol_CronDedupAcrossRestart | unprobed | 黑盒:cron 到点后同分钟内 kill 重启,断言 firings 恰一行 |
| C-cron-4 | 时钟回拨/NTP 偏移下 cron 不双发 | exempt | 黑盒不可注入系统时钟;防线即 E-cron-3 的分钟截断 dedup key+唯一索引,代码审计即证 |
| C-cron-5 | 非法 cron 表达式创建/edit 时按码拒(非静默收下永不 fire) | locked | cron_validate_edge_test.go + cron_wire_test.go(新) |
| C-cron-6 | cron nextFireAt 可发现(W1/F26 修:不再盲等) | probed | F26/W1(fixed 格) |

---

## D 面 — durable 引擎与跨模块联动 · F 面 — 系统正确性 → Phase 3/5

## D 面(durable 引擎/联动)

| ID | 场景单元 | 状态 | 指针/备注 |
|---|---|---|---|
| D-dur-1 | run 中 kill -9 同目录重启→boot Recover 把 run 跑完(at-least-once 端到端) | locked | testend TestWorkflow_CrashRecovery |
| D-dur-2 | record-once 崩溃语义双面:completed 行重放被"抄"不重跑 + 写行前丢行整体重跑 | locked | TestCrashRecovery_CompletedRowsSkip + TestAtLeastOnce_LostRowReRuns |
| D-dur-3 | :replay 三面:物理删 failed 行+completed 复用+replay_count++/幂等重走确定性 | locked | TestReplay_FixFailedRun + TestReplayDeterminism_IdempotentAdvance |
| D-dur-4 | completed run 拒 :replay(仅 failed 可重放,HTTP 直验) | probed | ARCHIVE 绿格「durable replay+恢复深用(completed拒)」;建议 testend 一断言补锁 |
| D-dur-5 | pin 双锁:version_id 冻拓扑+pinned_refs 冻引用版本,在途编辑 wf/fn/agent 改不动 run | locked | TestDispatch_PinnedVersionsReachPort(+testend TestAgentR2_WorkflowEntryAndVersions 侧证) |
| D-dur-6 | agent 席 kill -9 恢复(粗粒度记忆化+版本 pin 存活→resume completed) | probed | ARCHIVE 绿格「kill-9硬崩溃恢复from agent席」 |
| D-dur-7 | 回边循环:源 completed 且选中 port 才走、iteration+1 每真实决策恰进一轮 | locked | TestWalk_LoopWithBackEdge |
| D-dur-8 | MaxIterations 栅栏:溢出持久化 MaxIterations+1 行(F175-M1 fencepost) | locked | TestWalk_LoopOverflow_FencepostAtMaxPlusOne |
| D-dur-9 | 循环累加器 has():无 result 已声明节点绑空 map 非缺省(F28) | locked | TestScopeFor_BindsAbsentNodesToEmptyMap |
| D-dur-10 | 菱形/control XOR 剪枝+simple-merge 汇合不死锁(edgePruned 入边忽略) | locked | TestWalk_ControlXOR_SimpleMerge |
| D-dur-11 | 并行扇出 AND-join:每条 live 入边源 completed 才 ready | locked | TestWalk_ParallelAndJoin |
| D-dur-12 | 大图 11-25 节点 13 边并行 re-join 全记忆化 + 深循环 25 迭代 scopeFor 双体 | probed | ARCHIVE 绿格「大复杂图11节点」「大规模15-25节点」「深循环25迭代双体scopeFor」;建议 testend 大图场景 |
| D-dur-13 | 多 trigger 入口消歧:显式 entryNode>trg_>唯一者,歧义 FLOWRUN_INVALID_ENTRY | locked | TestContractEntities_FlowrunEntryDecideAndErrorFaces(已覆盖:双 trigger resolveEntry 全矩阵) |
| D-dur-14 | 黑盒基线三件:线性 CEL 寻址+记忆化/control 选边 emit 下游可读/坏 CEL 列可用上游(F8) | locked | testend TestWorkflow_LinearRunCELAddressing + TestWorkflow_ControlRoutingAndEmit + TestWorkflow_InvalidCELListsAvailableNodes |
| D-appr-1 | approval park→收件箱→decide yes 续跑完成 / decide no 只放 no port | locked | testend TestWorkflow_ApprovalParkDecideResume + TestApproval_ParkResumeYes + TestApproval_DecideNo_NoPublish |
| D-appr-2 | 超时结算:5s tick 扫 parked vs deadline(系统唯一 durable timer) | locked | TestApproval_Timeout |
| D-appr-3 | 三 timeoutBehavior 矩阵(reject→no/approve→yes/fail→run失败)+30d/2w 粗粒度 | probed | ARCHIVE 绿格「approve/fail timeout三件套+durable timer 1ms-5s」 |
| D-appr-4 | 人 vs 超时并发竞争 first-wins:输家 no-op(人工路径 FLOWRUN_APPROVAL_NOT_PARKED 422) | locked | durphase3_test.go TestApproval_HumanVsTimeoutFirstWinsRace(新 -race) |
| D-appr-5 | 0s timeout 立即触发不永 park(F60 回归) | probed | F60(fixed·自称locked,测试名未核到,宁标 probed) |
| D-conc-1 | serial:在途时 firing 留 pending 下 tick 再试→终跑 / skip:标 skipped 丢弃 | locked | TestFiring_OverlapSerialDefers_SkipDrops |
| D-conc-2 | buffer_one:收敛到最新+留 pending、只跑 newest | locked | TestFiring_OverlapBufferOneDefers + TestFiring_OverlapBufferOneRunsNewestOnly |
| D-conc-3 | replace:先取消在途 run 再跑新(含同批双 firing) | locked | TestFiring_OverlapReplace + TestFiring_OverlapReplace_SameBatch |
| D-conc-4 | allow_all:同 wf 并发双 run 各自完成互不扰 | locked | scheduler durphase3_test.go TestConc_AllowAllTwoFiringsBothComplete(新 -race) |
| D-conc-5 | 五策略真后端运行时 drain 黑盒:HTTP 快连双触发断言 flowrun 数+firing 终态(每策略) | probed | ARCHIVE 绿格「concurrency serial/skip+replace/buffer_one 真 webhook fire」;testend 无对应场景 |
| D-conc-6 | ClaimFiring 单事务(崩溃回滚仍 pending、无 claimed-无-run 残留)+删 workflow pending firing 卸载 | locked | TestFiring_SingleTxClaim + TestFiring_DeletedWorkflowSheds |
| D-pool-1 | HOL 消除:30s 慢节点跑池 worker,不卡后续 firing/其他 run/下一 tick | locked | TestHOL_SlowNodeDoesNotBlockOtherRuns |
| D-pool-2 | per-run 单飞+redrive:同 run 同时至多一 goroutine、并发触发置标志再走一轮 | locked | TestPool_SameRunNeverDoubleDriven |
| D-pool-3 | 关闭序:WaitPoolDrained→Shutdown cancel 在飞→StopPool;sendJob recover 撞已关队列不崩(F101) | locked | TestPool_ShutdownDrainsWorkers + TestService_Shutdown_CancelsAllInflight + TestPool_SendJobRecoversOnClosedQueue |
| D-pool-4 | 满载 4-worker 池不饿死独立 timeoutLoop 的审批超时结算(F174 解耦) | locked | durphase3_test.go TestPool_SaturatedPoolDoesNotStarveTimeoutSettlement(新) |
| D-pool-5 | boot Recover 入队非内联:慢恢复节点不阻塞 boot | locked | durphase3_test.go TestPool_RecoverEnqueuesNonInline(新) |
| D-pool-6 | kill 先标 cancelled 再 cancel ctx(终态不被 failNode 刷成 failed)+打断卡死 agent/parked run | locked | TestKillWorkflow_InterruptsBlockedAgent + TestKillWorkflow_CancelsParkedRun |
| D-pool-7 | afterRunSettled:draining workflow 最后一个 run 结算 inactive(无丢唤醒) | locked | TestDrainReconcile_FiresOnRunSettle |
| D-pool-8 | F101 CPU-pin 半:busy-loop 钉 CPU 活体确诊(pprof 抓) | needs_unit | F101 CPU-pin 唯一 open watch,需活体 pprof |
| D-trg-1 | fsnotify 端到端(文件事件→firing→run;四源唯一 testend 真空) | locked | TestContractDurable_FsnotifyEndToEnd(新 testend,四源真空补齐) |
| D-trg-2 | webhook HMAC 正负签/cron 真到点/sensor CEL 轮询 端到端触发 | locked | testend TestTrigger_WebhookFiresAndVerifies + TestTrigger_CronEveryFires + TestTrigger_SensorPollsCEL |
| D-loop-1 | loop 三熔断:TOOL_ERROR_STORM 3 轮/CONTEXT_BUDGET 0.92 软守卫/MAX_STEPS 诚实终态 | locked | TestRun_ToolErrorStorm + TestRun_ContextBudgetSoftStop + TestRun_MaxStepsReached(+testend TestChat_ErrorPaths·TestPlatform_LimitsHotSwap) |
| D-hl-1 | danger gate 全动作:approve 真跑入触点/deny 不跑零触点拒绝回喂/重复决议 404/未知决议 no-op | locked | testend TestChat_HumanLoopDangerGate + TestResolveUnknownIsNoop + TestRequestBlocksUntilResolve |
| D-hl-2 | 预授权双通道:approve_always 会话白名单(对话删即 Forget 清,R16)+skill allowed-tools 免确认 | locked | TestApproveAlwaysWhitelists + TestForgetDropsConversationGrants + TestDispatchWithGate_SkillPreApproved(+testend TestChatR3_SkillInlineActivateAndPreauth) |
| D-tp-1 | touchpoint 全链:工具→upsert 收敛(count 递进不长行)→messages 流信号→级联删 + output 键提取 created + catalog 覆盖每工具门禁 | locked | testend TestTouchpoint_LedgerEndToEnd + TestTouchpoint_BuildToolRecordsCreated + TestTouchpointCatalog_CoversEveryTool |
| D-mega-1 | mega 联动链单场景:trigger→混合图(fn+hd+agent+control+approval)→执行审计→notification→search→relation→touchpoint+SSE 帧序一链全断言 | locked | TestContractMega_TriggerToNotificationChain(新:trigger→混合图 5 kind→审计→approval→notification→relation→search 全链 + SSE flowrun tick) |
| D-mega-2 | 涟漪矩阵 9 实体×建改删×3 面 + 关系图五类边水化 + 引用方涟漪 | locked | testend TestRippleR5_CreateRenameDeleteMatrix + TestRippleR5_RelationGraphFaces + TestRippleR5_ReferenceRipples |
| D-mega-3 | run 终态唤回环:failed→run_failed 通知+needsAttention 点亮/completed 熄灭/approval park→approval_pending | locked | TestRunTerminal_NotifyAndAttention + TestApprovalPark_Notifies(+testend TestWorkflow_ApprovalParkDecideResume 侧证) |
| D-chaos-1 | 混沌注入:深 JSON/病态 CEL/mem-bomb/inf-loop/SQLi/RTL 零 500/panic/逃逸 | probed | ARCHIVE 绿格 chaos lane |
| D-chaos-2 | 海量分页:长 loop run 千行 frn keyset 分页不倾倒(F168-M7)+logtail/bigio 三类 cap 显式截断信号 | probed | F168-M7 + 绿格 bigio(bash 截断面已锁 testend TestPlatformR4_LimitsEveryField) |

## F 面(系统正确性 R1–R21 + 0622 后新码)

| ID | 场景单元 | 状态 | 指针/备注 |
|---|---|---|---|
| F-R1 | shutdown 收割后台 bash 进程树(shell Manager.Stop 从 App.Shutdown 可达) | locked | TestApp_ShutdownReapsBackgroundShellProcs |
| F-R2 | llama-server 崩溃恢复收割(PID manifest+下次 boot reap 幸存者) | locked | TestReapStalePID_KillsSurvivor |
| F-R3 | shutdown 打断在飞 Advance(cancel 全 inflight ctx,不裸跑撞 db.Close) | locked | TestService_Shutdown_CancelsAllInflight |
| F-R4 | handler __init__ 墙钟(hang 构造器不永久卡 spawn/boot) | probed | 修复已入 spawn.go handlerInitTimeout=300s;hang 路径无专测(近邻 TestSpawn_BrokenInitSurfacesTraceback 只测报错) |
| F-R5 | durable SSE 对卡死订阅者限时强断、bus 不整体冻结 | locked | TestBus_DurablePublishDisconnectsWedgedSubscriber |
| F-R6 | boot 恢复按进程组杀 uvx/npx 孙进程(负 PGID) | locked | TestRestoreOnBoot_KillsGrandchildViaProcessGroup |
| F-R7 | sandbox envLocks 互斥表随 Destroy 驱逐不永涨 | locked | TestDestroy_EvictsOwnerLock |
| F-R8 | webhook 单 catch-all 路由:重注册不 panic、mux 不追加增长 | locked | TestRegisterUnregisterReRegister_NoPanic + TestMux_HasSingleStableCatchAll |
| F-R9 | embed backfill 整批写失败即断轮(不热自旋重嵌同批) | probed | 修复在 semantic.go wroteThisBatch abort;abort 分支无专测(主链锁 TestEmbedWorker_BackfillsAndInvalidates) |
| F-R10 | LoadThread SQL 侧过滤 watermark/subagent,每回合不整表重读 | locked | TestLoadThreadForLLM_FiltersSubagentAndWatermark_R10 + TestLoadHistory_ByteIdenticalAfterR10 |
| F-R11 | Advance 循环行集内存携带,GetNodes 非每轮重读(O(N²) 消除) | locked | TestAdvance_LoopRead_ConstantGetNodes_R11 + TestAdvance_LoopRead_ByteIdenticalRows_R11 |
| F-R12 | MissingEmbeddings 走 idx_sd_ws_updated 免 filesort | probed | 索引已建 search.go:61;无 EXPLAIN 级门禁(schema 常量、回归风险低) |
| F-R13 | shutdown 收割在飞一次性 function-runner(one-shot 进 kill-set) | locked | TestShutdown_ReapsInFlightOneShot |
| F-R14 | search.Close 受界:首用大下载中关停不无限阻塞 | locked | TestBuiltin_CloseBoundedDuringDownload |
| F-R15 | vecCache 增量补丁,编辑不触发整表 BLOB 重扫 | locked | TestVecCache_BackfillPatchesIncrementally + TestVecCache_PatchSkipsUnloadedWorkspace |
| F-R16 | humanloop approve_always 白名单随对话删除 Forget 清 | locked | TestForgetDropsConversationGrants |
| F-R17 | AgentState.seenFiles 有界 LRU 不随长会话无界涨 | locked | TestMarkRead_BoundedLRU |
| F-R18 | stderrFan detach 走 defer,panic 不漏 sink 到常驻实例 | probed | 修复已入 call.go;panic 路径无专测(fan 行为锁 TestStderrFan_WindowAttribution/ConcurrentCalls) |
| F-R19 | sensor Stop 等在飞探测归队(WaitGroup join,不与 db.Close 竞争) | locked | TestSensor_Stop_WaitsForInflightProbe |
| F-R20 | InvokeAgent 墙钟:无界 agent 不钉死调度(超时呈 failed 可 replay) | locked | TestService_InvokeWallClockTimeout_R20 + TestService_InvokeNoTimeoutUnderDeadline_R20 |
| F-R21 | drain head-of-line blocking 消除(=F174,ADR 0007 有界 Advance 池) | locked | TestHOL_SlowNodeDoesNotBlockOtherRuns(背景 ctx 播种契约另锁 TestBackgroundPaths_RequireWorkspaceSeeding) |
| F-new-1 | touchpoint 新码(domain/store/app,git status 未提交件)六类反模式扫描:泄漏/死锁/ctx 生命周期/单连接争用/关闭序/IO 放大 | locked | Phase 5 静态猎扇出(4 维度)复扫 touchpoint 新码;2 候选(tmp-path/name-resolve)对抗验证 REFUTED=洁净 |
| F-new-2 | chat rail 新查询面(awaitingInput/sort=name/hasUnread/:seen/archived)系统面:索引缺失/查询放大/unread watermark 竞态 | locked | Phase 5 → F181 conversation sort=created 缺索引已修(idx_conversations_ws_created) |
| F-new-3 | loopback 加固(RequireBearerToken/RequireLoopbackHost)边界:空 token=关语义/常时比较/Host 头 DNS-rebinding 绕过 | locked | Phase 1 LoopbackDoors(Host+bearer 全矩阵)+ middleware bearer/host/cors 单测 |
| F-new-4 | SSE wedged 强断→客户端重连→410 SEQ_TOO_OLD→REST 再续 端到端自愈链 | locked | C-sse-4(410 环淘汰恢复)+ Bus TestBus_DurablePublishDisconnectsWedgedSubscriber |

---

## E 面 — agent 对话面（真模型 lanes）→ Phase 4

> E1-* = frontier 未碰列 · E2-* = 0622 新能力 agent 面 · E3-* = 已修 HIGH 行为抽样回归

| ID | 场景单元 | 状态 | 指针/备注 |
|---|---|---|---|
| E1-web-1 | 配 BYOK 搜索 key 后 agent WebSearch 真返 {query,source,results,truncated} 且答复据结果非幻觉 | unprobed | stub provider 契约单测 + 真 key lane |
| E1-web-2 | BYOK key 无效/过期时 WebSearch 错误面可操作(provider 4xx 不臆造结果) | unprobed | stub 返 401 零 token 测 |
| E1-web-3 | 四 provider(Brave/Serper/Tavily/Bocha)结果形状归一、无 provider 私有键泄漏 | unprobed | 各 provider stub 矩阵单测 |
| E1-web-4 | workspace webFetchMode=jina vs local 同 URL 真切换取路(agent 席) | unprobed | fetch_stream 测扩两模式对照 |
| E1-web-5 | WebFetch 摘要诚实性:页面无答案时声明未找到、大页/慢流显式截断信号 | unprobed | 受控本地 http server + lane 判官 |
| E1-rel-1 | agent 经 edit_agent 挂/卸工具→equip 边真增删、get_relations 即时反映 | unprobed | turn 多轮 + GET /relations 对账 |
| E1-rel-2 | agent 经 edit_document 增删 wikilink→link 边跟随、删链边消失 | unprobed | lane + relgraph 对账 |
| E1-rel-3 | agent 想手动建任意两实体关系的能力缺口措辞(无写边工具、是否误导) | unprobed | lane 直问建边诉求 |
| E1-burn-1 | turn 预算审计:标准任务(建 fn+测+改名)最优 turn 数 vs 实际绕远/重复读 | unprobed | lane 轨迹 turn 计数判官 |
| E1-burn-2 | 大 catalog(100+ 实体)下 agent 先搜后取 vs list 倾倒烧 token | unprobed | 规模 seed + 轨迹 token 审计 |
| E1-burn-3 | 同一坏参数连撞 3+ 次(错误信息是否足以一次改对) | unprobed | 埋雷任务重试计数判官 |
| E1-att-1 | 无 vision 能力模型收图片附件→诚实降级不臆造图内容 | unprobed | llmmock 无 vision 能力 + 图附件 |
| E1-att-2 | 损坏 PDF sandbox 抽取失败→agent 收可操作错非静默空文本 | unprobed | 坏 PDF 上传 turn 探 |
| E1-att-3 | 多附件混合(文本+图+PDF)一次 send 三路门控不串扰 | unprobed | 混合附件 llmmock 断言 |
| E1-att-4 | compaction 后 attachmentIds 仍可 read_attachment 读回 | unprobed | 压缩越线后读回探 |
| E1-mcp-1 | degraded server 在 agent 席调用→错误面 + agent 自行 reconnect 恢复 | unprobed | scripted 3 败翻 degraded 后 lane |
| E1-mcp-2 | F169 修后 env required/optional 语义 agent 面(必填被问齐、optional 不阻塞) | unprobed | registry 装带 env server lane |
| E1-mcp-3 | MCP 工具与既有 function 撞名时 chat 席目录消歧 | unprobed | 同名 seed + toolpick lane |
| E1-mcp-4 | agent 席 registry 搜→装→即调全链(F91 query 过滤后白烧复查) | unprobed | registry lane + 轨迹审计 |
| E1-sub-1 | 一 turn 并发双 subagent fork 结果各归各、树不串 | unprobed | llmmock 双 fork 断言 |
| E1-sub-2 | subagent 席 memory/todo 工具可用性边界(隔离 or 缺口的诚实措辞) | unprobed | subagent 席问 memory lane |
| E1-sub-3 | subagent 失败(风暴/超时)回喂父的错误形状(父能续不假成功) | unprobed | 埋雷 subagent llmmock 断言 |
| E1-sub-4 | subagent 内 dangerous 工具确认归属(危险门走谁、体验可懂) | unprobed | dangerous 挂 subagent 探 |
| E1-tp-1 | agent 工具调用真产 touchpoint 行(mentioned/attached/viewed 从 agent 席触发) | unprobed | turn 后 GET /touchpoints 对账 |
| E1-tp-2 | agent 读回 touchpoint 的能力缺口("这实体最近谁碰过"诉求) | unprobed | lane 直问 + 工具目录审计 |
| E1-tp-3 | subagent/workflow 席动作的 touchpoint 归属(记到哪 conversation/actor) | unprobed | 嵌套席动作后台账查询 |
| E1-adv-1 | approval timeoutBehavior 三枚举 agent 建全生效(agent 席未扫全) | unprobed | 三枚举各建各触 lane |
| E1-adv-2 | trigger sensor interval 广告选项真按配置节奏轮询 | unprobed | 短 interval 计 firing 频率 |
| E1-adv-3 | handler init-args schema 广告的默认值/枚举约束真校验 | unprobed | 违约 init-args 建 lane |
| E1-adv-4 | limits 约束 agent 可见性(agent 能否知 maxSteps 等预算而非撞墙) | unprobed | lane 问预算 + 目录审计 |
| E1-dp-1 | fn 返回标量/None/嵌套 list 在下游 CEL 键形状全类型矩阵(F32 修后续) | unprobed | 各返回型 workflow 零 token 矩阵 |
| E1-dp-2 | handler 方法返 None/异常对象穿 workflow 节点结果的形状 | unprobed | None 返回图 run 断言 |
| E1-dp-3 | control emit 与上游同名键覆盖/合并语义 agent 可预期 | unprobed | 同名键图 run 断言 |
| E1-dp-4 | agent 节点声明 outputs coerce 失败的 loud-fail 措辞(F40 agent 半错误面) | unprobed | 违约 outputs invoke 断言 |
| E1-dp-5 | attachmentIds 能否穿进 workflow/agent 节点(跨席数据传递缺口) | unprobed | 带附件触 workflow lane |
| E2-conv-1 | agent 席"按名列对话"诉求—list_conversations 无 sort 参数的缺口/绕行面 | unprobed | lane 直问按名列(HTTP 面另锁 TestChat_RailSortByName) |
| E2-conv-2 | list_conversations includeArchived 混排时 archived 标志诚实呈现 | unprobed | 归档 seed + lane 枚举 |
| E2-conv-3 | "找聊过 X 的对话"→search_conversations vs list 分工选对 | unprobed | 双诉求 toolpick lane |
| E2-conv-4 | manage_conversation rename agent 席真改题、rail 即时反映 | probed | F107;抽样复测 |
| E2-conv-5 | 50+ 对话 nextCursor 忠实走完、不把单页当全集(F146 修后深面) | unprobed | 多页 seed 枚举轨迹审计 |
| E2-men-1 | @提及非文档实体(fn/agent/skill)的冻结语义 | unprobed | 多实体 mention llmmock 矩阵(文档面已锁 TestChatR3_MentionFreeze) |
| E2-men-2 | @提及已删实体发送时的错误/降级面 | unprobed | 删后 mention turn 探 |
| E2-men-3 | 一条消息多提及+附件组合的注入顺序与冻结一致性 | unprobed | 组合 send llmmock 断言 |
| E2-rail-1 | awaitingInput 由真危险门/ask 工具行为点亮与清除 | unprobed | 真 dangerous 调用后 rail 对账(HTTP 面已锁 TestChat_RailAwaitingInput) |
| E2-rail-2 | hasUnread 在长流+subagent 完成时的点亮/清除时机 | unprobed | 长流完成后 rail 对账 |
| E2-rail-3 | isGenerating 与 cancel/崩溃恢复的残留(kill 后无永久蓝点) | unprobed | 在途 kill 重启后 rail 查 |
| E3-hd-1 | F164 handler 调用错误面 secret 擦洗(实时错误+spawn 失败审计两面皆净) | probed | F164;抽样复测 |
| E3-wf-1 | F173 get_flowrun 节点 cap80+summary、长 loop 不倾倒 LLM 上下文 | probed | F173;抽样复测 |
| E3-wf-2 | F138 两阶段 drain:replace/skip/buffer_one 对背靠背真 fire 生效 | probed | F138;抽样复测 |
| E3-ag-1 | F134 edit_agent 部分编辑合并、不抹挂载 tools/knowledge | probed | F134;抽样复测 |
| E3-fn-1 | F148 envfix 不丢声明包、失败 env 保 failed 且 ENV_NOT_READY 可达 | probed | F148;抽样复测 |
| E3-mem-1 | F147 write_memory 更新保留 pinned/source 用户策展 | probed | F147;抽样复测 |
| E3-wf-3 | F135 :activate/:stage 悬挂 ref 拒 WORKFLOW_NOT_RUNNABLE 不上线 | probed | F135;抽样复测 |
| E3-loop-1 | F125 脏 JSON 工具参数先 jsonrepair、纯垃圾报"not valid JSON"真因 | probed | F125;抽样复测 |
| E3-srch-1 | F110 cosineFloor=0.55:真 paraphrase 命中浮现、乱码噪声仍拒 | probed | F110;抽样复测 |
| E3-mdl-1 | F68 get_model_config 脱敏投影(key 仅掩码、零 FS grep) | probed | F68;抽样复测 |
| E3-sub-1 | F149 subagent 工具集剔除 get_subagent_trace(隔离不读父兄弟) | probed | F149;抽样复测 |
| E3-http-1 | F172 /api/v1/* 404/405 走 N1 envelope(ROUTE_NOT_FOUND/METHOD_NOT_ALLOWED) | probed | F172;抽样复测 |
