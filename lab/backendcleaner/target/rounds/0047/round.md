# Round 0047 — workflow 静态图实体模块（波次 4 第一块：编排者落地）

> 波次 4 编排核心的第一块。前置（ctl/apf 回炉 + 全实体 I/O 统一 + doc 20 校准）已在本轮稍早完成并 push（contract-changes #27/#28）；本条专记 workflow 静态实体的新建。

## 目标

建 `wf_`/`wfv_` 静态编排图实体——doc 20 的「编排者」：节点按 id 引用其它实体（trg_/fn_·hd_·mcp_/ag_/ctl_/apf_）、边画控制骨架、图以 JSON 存于版本行。**只 STORE + VALIDATE + PIN，不执行**（执行=flowrun+scheduler 后续波次，import 同一批纯 helper 走 pin 版本）。镜像 function 范式套图。

## 心智模型收敛（建之前的 study）

用户要求「先扣模型」，过了几个尖角：

- **承重墙**：一个节点要用的每个数据，必然是它某祖先节点的 result 字段（外加 `ctx.runId`）——无工作流变量、无合并 payload、无环境态。**边永不搬数据**，下游按名引用祖先（model B / node-addressable）。
- **control 输出**：定为 **per-port**——删掉先前为「对称」给 ctl/apf 加的 `Outputs` 字段（control 的输出已被各 `Branch.Emit` 的 keys 完整描述、approval 恒为 `{decision,reason}` 常量；单存 outputs 冗余且并集丢 per-port 精度）。**Inputs 全留**（每个实体都要被 `:run`/`:invoke` 表单 + 节点接线调用，需入参清单）。→ R0047② 收尾 commit。
- **循环可见性**：祖先 = 含回边的有向可达；`BackEdges()` 做成 domain 纯函数，校验与未来解释器共用。
- **agent input**：是结构化 JSON 喂 LLM（非模板插值）——承认它比 function 松一档。
- doc 20 据此**校准到落地现实**（FieldSpec→schema.Field、InputSchema→Inputs、Branch.Port 保留、ctl/apf 无 Outputs、agent JSON、mcp FromJSONSchema）。

## 落地

- **domain/workflow**：`Workflow`/`Version`/`Graph`/`Node{ID,Kind,Ref,Input,Retry}`/`Edge{From,FromPort,To}`/`RetryConfig`；`ValidateGraph`（形状 + 良构 + ≥1 trigger + 可达 + 环=control/approval 发出的可归约回边 + 端口形状）；**`BackEdges` 独立纯函数**（解释器复用）；`ParseOps`/`ApplyOps`（7 ops，update=RFC7396 顶层 merge、delete_node 级联删边、不改 base）；8 errorsdomain（`WORKFLOW_NOT_FOUND`/`NAME_DUPLICATE`/`VERSION_NOT_FOUND`/`NO_ACTIVE_VERSION`/`INVALID_GRAPH`/`INVALID_OPS`/`REF_NOT_FOUND`/`INVALID_LIFECYCLE`）。
- **store**：orm 两表——`workflows`（软删 + partial-UNIQUE name + CHECK lifecycle_state/concurrency）+ `workflow_versions`（UNIQUE(workflow_id,version) + 硬 trim 护 active）。
- **app**：Service（Create/Edit〔ops〕/Revert/UpdateMeta/SetLifecycle/SetNeedsAttention/Get/List/Search/Delete/Get(Active)Version/ListVersions/**CapabilityCheck**/**BuildPinClosure**）+ **`RefResolver`/`RefInfo` 端口**（nil 容忍→结构-only；测试注 fake；真接 M7）+ **`WorkflowReader`** DIP（给未来 scheduler）+ catalog/relation 适配器。create/edit 管线 = ApplyOps → ValidateGraph → **compileGraphCEL**。
- **tool**：7 Lazy（create/edit/revert/delete/get/search/capability_check_workflow；**无** trigger/执行类）。
- **handler**：REST（CRUD + `:edit`/`:revert`/`:activate`/`:deactivate`/`:capability-check` + versions；**无** `:trigger`/执行历史）。
- **relation**：workflow 是第 **12** 类 EntityKind（`wf_` 早预登记）；图 node.Refs 产 `workflow → {trg_,fn_/hd_/mcp_,ag_,ctl_,apf_}` 引用边。

## 关键修复：model B 承重墙差点没接住

subagent 首版用 `pkg/cel.Compile`（固定 env：payload/ctx/input）编译节点 Input——**`reviewer.score` 这种 node-id 寻址被拒**，正是 model B 的反面。修：`pkg/cel` 加 **`ScopedEnv`/`NewScopedEnv(roots)`**（根=调用方给的名字 + ctx，各 DynType），`compileGraphCEL` 改用「图全 node ids」作根。副产：引用非 node id 的名字编译失败=白送「引用存在节点」校验（更严的「只可祖先」lint 仍是 deferred TODO）。测试随之从 `payload.v` 改 `t.v` 等 node-id 接线 + 加 `ScopedEnv` 单测 + 「ref 非节点→拒」单测。

## 延后

- **执行**：durable 解释器 + scheduler + flowrun/journal（后续波次）——本模块只 pin 不跑。
- **祖先-only CEL lint**：需 `cel.ReferencedRoots`（CEL AST 抽标识符），pkg/cel 暂未暴露；现状=引用必须是「存在节点」，运行时解释器兜「非祖先」。
- **M7 中央装配**：`WorkflowTools`→Toolset、handler.Register、catalog source、relation namer/syncer、store.Schema→migrate、`SetResolver` 注真。

## 验证

`go build ./...` / `go vet ./...` / `gofmt -l internal/` / `go test ./...` 全绿（exit 0）。domain/store/app/tool 四包全离线测（含 ValidateGraph 表驱动、BackEdges、ApplyOps 级联、CapabilityCheck fake resolver、BuildPinClosure agent depth-2、lifecycle 转换、ScopedEnv）。

## 契约

`domains/workflow.md` 整篇重写（DOC-128，纠正旧 pending/gorm/tool·case 节点的 stale 设计）+ database §4.7 两表 + §3.2 图引擎 typescript 修正 + S15 登记 wf_/wfv_（注 fr_/fre_/apv_ 未建）+ §3.1 ScopedEnv 一行 + api §2.3 重写 + error-codes §2.7 八码 + contract-changes #29。

> commit：ctl/apf Outputs 收尾 `6ca84e07` · doc 20 校准 `8b94fed4` · workflow 模块 + cel ScopedEnv `c882190b` · 契约+lab（本条）。
