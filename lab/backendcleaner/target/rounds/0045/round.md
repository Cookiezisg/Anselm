# R0045 — control 逻辑实体（workflow 图模型重定型首落地）

> **背景**：本轮是一段长设计对话的产物。用户从「CEL 实体化」的纠结出发，逐步推导出 workflow 图模型的彻底重定型（[`18-graph-model-redesign.md`](../../../../docs/working/workflow-revamp/18-graph-model-redesign.md)，本轮同步起草）：**workflow = 纯编排的数据依赖图，5 节点（trigger / action / agent / control / approval）各引用一类实体，边 = payload 数据管道**。control 是该模型里**第一个落地的新实体**——把旧 `case` 节点内联的 CEL 路由逻辑（when/emit）物化成独立的「AI 工作实体」。

## 设计决策（用户逐条拍板）

1. **CEL 不实体化、control 节点的「逻辑坨」实体化**：节点 = 结构角色，实体 = 可锻造逻辑。
2. **强制每个 control 都是实体**（不搞 lambda/具名两形态）——为清晰心智，宁可 catalog 多一次性小实体。
3. **版本模型**（pin 必需）但去掉 function 的 sandbox/env/executions——最轻版本化。
4. **全量 branches、不用 ops**（branches 是原子整体，ops 无增量价值）。
5. **强制末条 `when:"true"` 兜底**（accept 挡「全 false 无路」死等）。
6. **无 run / 无 executions**（control 被 workflow 解释器求值，不独立执行）。
7. **relation 轻集成**（只作被引用方 + Namer，不产出边——when/emit 只读 payload）。
8. **不进 mention**（配置/逻辑实体，同 trigger）。
9. **独立孤儿生命周期**（删 workflow 不级联，同 function/agent）。
10. **数据流 = payload 隐式**（放弃显式端口；对齐 17 §5 作用域变量、不改 17）。

## 实现（domain → store → app → tool → handler）

- **domain/control**：`ControlLogic`(ctl_) + `Version`(ctlv_) + `Branch{port,when,emit}` + `ValidateBranches`（结构：非空 / port 非空且唯一 / 末条兜底）+ 8 `errorsdomain`。
- **infra/store/control**：orm 两表 + 手写 DDL（`control_logics` partial-UNIQUE name / `control_logic_versions` UNIQUE(control_id,version)）+ `MaxVersionNumber` + `TrimOldestVersions`（护 active）。
- **app/control**：Service（Create / Edit / Revert / UpdateMeta / Get / List / Search / Delete / **Resolve**）+ `validateBranches`（结构 domain + CEL `pkg/cel` 编译，domain 不 import cel-go）+ catalog source + relation（Namer + create/edit 边 + purge）+ notification。
- **app/tool/control**：6 Lazy 工具（create / edit / revert / search / get / delete_control，**无 run**）。
- **transport/handlers/control**：REST（CRUD + `:edit`/`:revert` + versions，**无 `:run`/pending**）。
- **relation/entitykind**：加第 **10** 类 EntityKind `control` + 前缀 `ctl_`。

## 测试（全离线 · 0 token）

- **domain**：`ValidateBranches` 表驱动（空 / port 空 / port 重复 / 末条非 true / 正常 / 单兜底 / 兜底带空格）。
- **store**：真 SQLite + ws ctx —— 往返 / branches+emit JSON 往返 / 重名冲突 / workspace 隔离 / 软删 + 重删 / 分页 / MaxVersion / **TrimProtectsActive** / SetActiveVersion / GetByIDs 保序。
- **app**：真 store —— Create(v1 active + emit 往返) / InvalidWhenCEL / InvalidEmitCEL / NoCatchAll / EmptyName / DuplicateName / Edit(指针前移 + v1 保留) / Revert / UpdateMeta(不 bump 版本) / Search(子串 + 空 query) / Delete(软删) / **Resolve(active + pinned 版本)**。
- **tool**：ControlTools 名字/数量 + ValidateInput 表驱动 + **RoundTrip**（真 app：create→get→edit→revert→search→delete 经 Execute）+ InvalidCEL `errors.Is` 冒泡。
- **relation**：`entitykind_test` 加 `ctl_` 用例 + 全集加 `control`。

## 契约文档（doc-sync，原则 #9）

- 新建 `domains/control.md`（DOC-305）。
- `database.md`：§1 全索引 + **§4.5 Control** 段 + 前缀列表/注释加 `ctl_`/`ctlv_`。
- `api.md`：**§2.6 Controls** 端点组。
- `error-codes.md`：**§2.6b** 8 个 `CONTROL_*`。
- `domains/relation.md`：§1.2 节点类型 **9 → 10**。
- `contract-changes.md` **#25**。

## 留 M7（总装配）

`cmd/server/main.go` 仍是最小骨架（波次 7 收口正式 DI）。control 同所有兄弟模块等总装配：`ControlTools` → `Toolset.Lazy`、`ControlHandler.Register`、catalog `RegisterSource`、relation `Namer['control']`、`controlstore.Schema` → `db.Migrate`、`SetRelationSyncer`。

## 验证

gofmt clean · `go build ./...` BUILD_OK · `go vet` VET_OK · test domain/store/app/tool/relation **ALL PASS**（纯新增 + relation 加一类，不破坏任何既有包）。

## 在波次 4 谱系里的位置

control 是 18 文档定下的 5 节点 × 5 实体里、**第一个独立落地的实体**。后续：approval 渲染实体（`apv_`）→ workflow domain 改造（node 引用实体、边 = payload）→ flowrun（journal）→ scheduler（durable interpreter，消费 `control.Resolve`）。本轮只做 control 实体本身，不碰 workflow/scheduler。
