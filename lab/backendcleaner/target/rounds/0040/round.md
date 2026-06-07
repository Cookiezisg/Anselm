---
# Round 0040 — skill 重写（文件式指令载体，对齐 memory，砍 execution/search）

类型 / 目标：波次 3 M3.4。skill 从「LLM 搜索 + 执行审计 + 常驻轮询 + GORM」收敛为**纯文件式指令载体**。设计稿见同目录 `design.md`、调研见 `survey.md`（deep-research 104 agent / 22 源 / 19 confirmed）。

## 核心方针（一句话）
skill 是 **memory 的近亲**（文件式注入物）非 function 的近亲（执行实体）：纯文件、**零 DB 表、零 LLM 依赖、纯按需扫描**。

## 用户拍板
1. **对齐 function 的工具命名手感**（create/edit/delete/get/activate）但**砍 execution 审计 + search**（对 skill 是抽象错配 / 校验剧场）。
2. **纯按需扫描**（catalog source / HTTP List 触发时现扫，无缓存 / 轮询 / fingerprint）——砍 `polling.go`。
3. **无版本**（文件式，编辑即覆盖）。
4. allowed-tools = **预授权**（免危险确认）非限制白名单；存 `activeSkill`，消费留 ask 波次 6。
5. **AI 可创建**（create/edit/delete 工具，`source=ai` 区分）——Anthropic 官方软性愿景背书。
6. **disable-model-invocation 实装**（发现层过滤，不进 LLM 概览）。
7. 不加 `` !`cmd` `` shell 注入。

## 关键洞察（调研推翻我两个倾向）
- ① allowed-tools 权威语义 = **预授权**（非白名单限制）——与 Forgify「无中央门控、危险 LLM 逐次自报」(S18) 完美自洽。
- ② AI 自创 skill 有 Anthropic 软性愿景背书（'we hope to enable agents to create/edit/evaluate Skills'）。
- skill 本性归位 memory 那一类（文件式注入物）；SKILL.md 已是跨厂 open standard（agentskills.io）。

## 新增 / 重写
- **domain/skill**：Skill + Frontmatter（Anthropic 全字段镜像 + `source` 扩展）+ 6 errorsdomain + Repository + **SubagentRunner 端口**（自包含，不依赖未来 subagentapp 类型）。无 execution_log、无 `sk_` id（name 即身份）。
- **infra/fs/skill**：目录式 `SKILL.md` 文件 store（`go.yaml.in/yaml/v3` 解析、原子写 .tmp+rename、workspace 分桶、slug 防穿越、**纯按需扫描无状态**）。复用 memory R0025 范式。
- **app/skill**：Service（scan/activate[inline·fork]/mutate[create·replace·delete]）+ catalog source（filter disable-model-invocation）+ relation（equip 边从 allowed-tools 解析 + forged 边 + Namer name→name）。fork 经 SubagentRunner（nil 降级 ErrSubagentUnavailable）。
- **app/tool/skill**：5 工具（activate/get/create/edit/delete）。**无 search/execution 工具**。
- **transport**：skill handler（REST CRUD + `:activate`，List 不分页）。
- **agentstate**：+`activeSkill` 槽（`SetActiveSkill`/`ActiveSkill`/`IsToolPreApprovedBySkill`，RWMutex——单复合值不适用 sync.Map）。
- **go.mod**：`go.yaml.in/yaml/v3` indirect→direct。

## 砍掉的旧物
`search.go`（LLM rerank + model/apikey/llm/llmparse 依赖）+ `execution_log` + `skillexec` store（`ske_` 表）+ `search_skill_executions`/`get_skill_execution` 工具 + `polling.go`（常驻 1s 轮询）+ fingerprint/缓存 map + GORM。旧契约 DOC-122 腐烂（512KB body 实为 32KB / 扁平 *.md 实为目录式 / 假占位符 `$USER_ID` / 7 错误含虚构 `SKILL_RECURSION_DENIED`）整篇重写。旧 2275 行 → 新 ~1000 行。

## 与 function 3 处本质不对称
无版本/revert · 不可 @mention · 纯文件无 DB（无 execution 审计）。

## relation id 决策
skill 文件式无生成 id → **name(slug) 作 relation 节点 id**。R0021 预留的 `sk_` 前缀对文件式 skill 作废（skill 不被 wikilink 引用，KindForID 的 sk_ 无消费点）。

## 测试（全离线，无需 fake LLM）
store 6（roundtrip + frontmatter yaml / list 去 body+source 过滤 / delete+exists / workspace 隔离 / slug 拒+路径穿越拒 / 坏文件跳过）+ app 8（create 冲突 / fork 需 agent / replace not-found / inline 替换+activeSkill 预授权 / fork 无 runner 降级 / fork 有 runner 透传 / catalog 过滤 disable / relations equip 边只 fn_·hd_ / delete purge）+ agentstate 1（预授权替换语义）。

## 验证
`gofmt -l` 干净 · `go build ./...` 0 · `go vet ./...` 0 · `go test -race`（store/app/agentstate）全绿。

## 跨波次接线（deps-todo 登记）
- fork `SubagentRunner` 注入：subagent **波次 5**。
- allowed-tools 预授权消费（danger 确认免确认）：ask **波次 6**。
- `${CLAUDE_SKILL_DIR}` + L3 附加文件（references/scripts）：择机。
- boot 注入 `skillfs.New(~/.forgify)` + catalog `RegisterSource` + relation `Namer`/`SetRelationSyncer` + `SkillTools` 进 `Toolset.Lazy`：**M7**。
- user-invocable 前端 slash 入口：前端覆盖期。
