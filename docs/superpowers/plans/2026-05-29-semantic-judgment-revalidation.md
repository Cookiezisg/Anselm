# Workflow-Revamp LLM-Facing 设计验证 & 规格化 — 计划 (v5,完整重写)

> 本文件从头重写。统领整个"验证 + 规格化"工作。先讲**目的与最终产物**,再讲**怎么做**。

---

## §0 目的与最终产物

### 0.1 目的(为什么做这件事)

Forgify 的 workflow-revamp 是 ~20+ 天的大工程(详 `11-integration-chains.md`)。**决定产品最终能不能 work 的,不是后端架构,而是"发给大模型的每一句话"**——tool 描述 / system prompt / catalog / lazy 分组 / 教学 / schema。本研究在**真正动土之前**,用**真实模型 + 真实场景**严格验证这些"话"能不能让默认模型(DeepSeek V4-flash)**可靠地把用户意图变成正确、能跑的产物,且 token 经济**。

产出二选一:
1. **有依据的信心** + **可直接抄的完整规格** → 团队照着建,建出来就能用;
2. **早期发现的硬问题**(某些描述/schema/甚至模型撑不住)→ **动土前**改设计,而非生产里痛苦发现。

**核心纪律:假信心比没信心更坏。** 结构对 ≠ 语义对。因此每个产物必须**过 Claude 审语义 + code 真执行 + 真 ReAct**,不靠程序性结构检查蒙混。

### 0.2 最终产物(★ 真正的交付物)

**一份非常完整、细节到每个 LLM-facing 东西长什么样子的设计文档** —— `14-llm-facing-design-spec.md`(规格)+ `13-validation-report.md`(验证证据)。结构见 §8。

> 验收标准:Forgify 工程师拿着这份设计文档,**不需要再猜任何 prompt/描述/schema**,每一个 LLM-facing artifact 都有「最终文本 + 为什么 + 实测语义正确率 + token + 贴哪个文件」。

---

## §1 系统理解基准(post-revamp Forgify —— eval 必须测这个,不是我想象的)

读完 `00-12` 全部设计文档后锁定。**搭"真实 prompt"和判语义都照此。**

### 1.1 范式 —— message-queue + actor(不是 DAG;同类 = LangGraph)
节点 = actor(接消息→处理→emit),边 = 持久化 SQLite queue。触发 = emit 首条消息进入口 queue。消息 `{id, queueName, flowrunId, ctx(只读元信息), payload(业务数据)}`。**case 回边 = 复制消息进上游 queue → 节点反复激活**(有环图)。retry / replay / 回边 = 同一机制(复制消息进 queue)。单进程、同步消费、parentId 因果链、消息永不删。

### 1.2 Quadrinity —— 4 类 forge 实体(全有版本 + pending/accept + 锻造工具)
- **function** 纯函数(fn_/fnv_/fne_);kind=normal|polling(version 级);polling 签名 `poll(last_cursor)→{events,next_cursor}`
- **handler** stateful class(hd_/hdv_/hcl_);**bare-names body 契约**(方法/init 参数裸名,非 dict 访问)
- **agent** LLM ReAct 配置(ag_/agv_/agx_):prompt(整段不拆)/ skill(0-1)/ knowledge(多文档直注无 RAG)/ **tools(只 fn/hd/mcp,不含 ag —— agent 不能调 agent)** / outputSchema(enum|json_schema|free_text)/ model
- **workflow** 编排(wf_/wfv_/fr_)
- mcp 是 marketplace 装,不算 forge。**agent 是 callable**(`ag_xxx`)→ workflow **tool 节点**能调 agent(boss 调 worker;但 agent 自己的 tools 不能挂 ag)

### 1.3 5 节点(14→5)
| 节点 | config | 要点 |
|---|---|---|
| trigger | `{kind, payloadSchema?, kind-specific}` | 5 kind:cron/fsnotify/webhook/polling/manual;emit 单条入口消息 |
| agent | `{agentRef: ag_xxx}` | thin wrapper,配置全在 entity;永远 active version 无 pin |
| tool | `{callable, args, retry?, onInfraCrash?, timeout?}` | callable=fn_/hd_.method/mcp:server/tool/ag_;args 支持 `{{payload.*}}`/`{{ctx.*}}` |
| case | `{expression: CEL, branches: {name:{to, emit?}}}` | 多路 switch + 回边 loop;**看牌发牌员非分析师**(只路由不计算);CEL 100ms/只读 payload·ctx/无副作用;emit 不写=透传,写=CEL 构造下游 payload(含 attempt+1) |
| approval | `{prompt(md必填), timeout?, timeoutBehavior, allowReason}` | yes/no 二元;payload 透传;reason 纯审计不进数据流 |

### 1.4 三条总纲
- **员工思维**:节点=员工,不 spawn subagent / 不调其他 workflow / skill 编排时配死 / 不挂平台黑盒(fs/shell/web/memory/ask)/ **agent 不调 agent**
- **能力源自 forge**:外部能力只从 forge 流出,无平台 escape hatch
- **永远 prod**:引用永远指 active version,无 @v3 pin;改/revert 引用方自动跟

### 1.5 Lifecycle + 错误
- `Workflow.active`(无 Deployment 抽象)+ `FlowRun.{triggerNodeId, isFromListener}`;isFromListener 决定 handler Owner(true→`{Kind:workflow}` 跨触发复用 / false→`{Kind:flowrun}` 独立)
- retry 内只记录;retry 用尽**必推 SSE 通知**(mechanism);**trigger 用尽特例→workflow 自动 inactive**;死信 `messages.status=dead_letter`,`:replay`
- **Mechanism vs Policy**:平台只给机制(通知/持久化/retry 编排),策略(retry 次数/timeout/错误分类)编排者拍,**平台永不猜默认值**

### 1.6 AI 工具 + UI
- **91 工具**(Quadrinity 锻造 43 / 生命周期 3 / 运行时观察 5 / 错误诊断 5 / 资产 mcp·skill·document·memory 18 / 主对话基础 17);lazy 11 组 + activate_tools;`:iterate`(forge 改)/ `:triage`(flowrun 诊断)
- UI:画布(看 + 运行时滴答)+ chat(改)双 pane;5 节点 palette;Active toggle;trigger ▶ 触发按钮

### 1.7 已修的 3 处文档不一致(按此权威版)
1. **永远 prod**:agentRef 无 @v3(已修 02)
2. **agent.tools = fn/hd/mcp**,不含 ag(agent 不调 agent;已修 09);但 workflow tool 节点可调 agent(boss 调 worker)
3. **全 msg-queue**:trigger/节点 = emit 消息进 queue,非"out 端口/event"(已修 01)

---

## §2 方法论 —— 真·端到端语义验证(非结构蒙混)

四个支柱:

| 支柱 | 含义 |
|---|---|
| **真实打包 prompt** | 不塞单个 tool 命令。用**完整组装的 system prompt**(identity / how_to_work / tool_conventions / catalog 渲染 / resident+lazy 工具集 / 每个 tool 的真实 Description+Parameters)。已上线老部分从代码 `chat/runner.go`+`app/tool/*` 抽真文本;新设计部分用设计文档构造"上线后的真 prompt"。 |
| **真 ReAct 多轮** | 不喂 canned 结果。完整 think→activate→call→result→continue 直到任务完成/卡死。 |
| **Claude 当执行环境** | 每个 episode 由一个 Claude subagent 驱动,**同时扮演后端 + 用户 + 裁判**(详 §5)。 |
| **语义裁决 + code 真执行** | 强模型(Claude)逐个审语义对错 + code 子进程实跑。**不靠程序性结构检查。** |

**两模型分离**:DeepSeek V4-flash = 被测的"Forgify chat 大脑";**Claude(subagent)= 真实环境 + 真执行 + 真裁判**。

---

## §3 覆盖范围 —— 100% 全集(逐个列名,不靠 "~N" 糊弄)

**铁律:LLM 能看到的每一个 tool、每一段 prompt、每一个 schema,全进覆盖。** 不只 workflow-revamp 那批——**资产管理**(mcp/skill/document/memory)和**主对话基础**(文件/shell/web/task/交互)**全部**纳入。两个理由:
1. 真实 chat 大脑每轮面对的是**完整 resident + activated 工具全集**(91 把),tool-selection 正确率必须在这个真实规模下测(M1:11% content-leak 在 40+ 工具时恶化)。只测 workflow 子集 = 假场景。
2. 用户要"每一个细节都考虑到"。

**全部深测 —— 没有"已上线免测"。** 产品没上线,DeepSeek V4-flash 在 91 工具全集里对每个描述的反应**全是未知数**,现在的描述都是"瞎写的初稿",必须个个验过、不行就重写。**深度不打折**,只是**验证模式**随产出类型不同:

| 模式 | 验什么 | 适用 |
|---|---|---|
| **CODE** | 子进程**真跑** + Claude 判逻辑对 | 产 Python:function/handler 的 create/edit |
| **ARTIFACT** | Claude 判结构是否**真实现意图** | 产结构:workflow/agent create-edit · case CEL · trigger payload · call args · ref · 注入字段 |
| **CONTENT** | Claude 判内容**对不对/达意** | 产内容:document/memory write · web-summary · auto-title · rerank · compaction · env-fix |
| **USAGE** | 在**真实多轮 ReAct**里判 5 件:① 全集里**选对**没 ② 参数(id/query/args)**构造对**没 ③ 结果**解读对**没 ④ 描述**够清晰**没 ⑤ token | 读/查/版本/生命周期/资产读/主对话基础(search/get/list/read/accept/revert/delete/activate/Read/Write/Bash/Web/Todo/Ask/Subagent…) |

> **USAGE 不是"过一眼"** —— 每把都跑多个真实 ReAct episode,5 件逐条判,描述"瞎写"的照样重写。所有模式都跑真 ReAct + Claude 语义判;CODE 模式额外 code 真执行。

### 3.1 全工具花名册(逐名,91 把,标验证模式)

**A. Forge Quadrinity(43)**

| 套 | 工具(逐名) | 模式 |
|---|---|---|
| Function(11) | **create_function · edit_function** → CODE;search_functions · get_function · get_function_versions · accept_pending_function · revert_function · delete_function · run_function · search_function_executions · get_function_execution → USAGE | CODE+USAGE |
| Handler(12) | **create_handler · edit_handler** → CODE;search_handlers · get_handler · get_handler_versions · accept_pending_handler · revert_handler · delete_handler · call_handler · update_handler_config · search_handler_calls · get_handler_call → USAGE | CODE+USAGE |
| Agent(11) | **create_agent · edit_agent** → ARTIFACT;search_agents · get_agent · get_agent_versions · accept_pending_agent · revert_agent · delete_agent · run_agent · search_agent_executions · get_agent_execution → USAGE | ARTIFACT+USAGE |
| Workflow(9) | **create_workflow · edit_workflow** → ARTIFACT;search_workflows · get_workflow · get_workflow_versions · accept_pending_workflow · revert_workflow · delete_workflow · capability_check_workflow → USAGE | ARTIFACT+USAGE |

**B. Workflow Lifecycle(3)** — trigger_workflow → ARTIFACT(payload 按 schema 构造);activate_workflow · deactivate_workflow → USAGE

**C. 运行时观察(5)** — search_flowruns · get_flowrun · get_flowrun_trace · get_flowrun_nodes · cancel_flowrun → 全 USAGE(诊断链走组 7)

**D. 错误诊断 + 修复(5)** — query_events · list_dead_letters · get_dead_letter · replay_message · clear_dead_letters → 全 USAGE(C+D 组合诊断链走组 7 端到端)

**E. 资产 — MCP(5)** — call_mcp_tool → ARTIFACT(args 构造);search_mcp_tools · list_mcp_servers · install_mcp_from_registry · health_check_mcp → USAGE

**F. 资产 — Skill(3)** — search_skills · get_skill · activate_skill → 全 USAGE

**G. 资产 — Document(7)** — create_document · edit_document → CONTENT;search_documents · list_documents · read_document · move_document · delete_document → USAGE

**H. 资产 — Memory(3)** — write_memory → CONTENT;read_memory · forget_memory → USAGE

**I. 主对话基础 — 文件(5)** — Write · Edit → CONTENT(写对内容);Read · Glob · Grep → USAGE

**J. 主对话基础 — Shell(3)** — Bash · BashOutput · KillShell → 全 USAGE(Bash:命令对 + 输出解读对)

**K. 主对话基础 — Web(2)** — WebFetch · WebSearch → 全 USAGE

**L. 主对话基础 — Task(4)** — TodoCreate · TodoList · TodoGet · TodoUpdate → 全 USAGE

**M. 主对话基础 — 交互(2)** — AskUserQuestion(该问才问、问对) · Subagent → 全 USAGE

**N. Meta(1)** — activate_tools → USAGE(resident meta-tool;激活正确性是组 1 核心,本身永远 offer)

> 合计 43+3+5+5+5+3+7+3+5+3+2+4+2+1 = **91 把,全部深测**。逐名列全才准——"~84/~89" 是早期模糊计数,作废。

### 3.2 非工具 LLM-facing 表面(全部,全深测)

| 表面 | 模式 |
|---|---|
| Forge 教学 prompt + ops schema:create/edit × function(normal+polling)/handler/agent/workflow | 驱动 CODE/ARTIFACT |
| CEL case 表达式 | ARTIFACT |
| callable ref 形式(fn_/hd_.m/mcp:s/t/ag_) | ARTIFACT |
| 结构化参数:trigger payloadSchema · tool 节点 args(`{{payload.*}}`/`{{ctx.*}}`)· sql · mcp server·tool | ARTIFACT |
| 注入字段:summary · destructive · execution_group | ARTIFACT |
| 系统 prompt 段:identity · how_to_work · tools · tool_conventions | 整体行为 |
| section 顺序(关键规则殿后 G7)· chainPatternsSection(多步先 plan) | 整体行为 |
| lazy 11 组 + activate_tools 描述(激活对不对) | USAGE |
| error envelope 恢复(sentinel + next_step → 下一步自纠) | 整体行为 |
| Utility prompts:auto-title · rerank×4(fn/hd/skill/mcp)· compaction · env-fix · web-summary | CONTENT |
| subagent prompts:explorer · forger · verifier | 整体行为 |

### 3.3 端到端 ReAct 场景(最高保真,组合多表面)

完整 workflow 编排 · 多实体锻造链 · 诊断链(C+D)· 错误恢复 · 跨实体任务 · AI 错误诊断(notif 驱动)。

### 3.4 贯穿

token↔结果甜点 —— **每个 surface 都记 token**,在"达到语义正确"前提下找最省描述/prompt。

---

## §4 全覆盖语义评判 rubric(judge 照审,每个 surface 一条)

judge subagent 收 `{原始用户请求, 完整对话/产物, 该 surface 设计契约}`,逐条核。

### 组 1:意图 → 工具选择 / 激活
- **意图识别**:从(含含糊)话里正确判"对哪个实体做什么"
- **lazy 激活**:activate 对组(不激活无关、不漏)
- **catalog 理解**:从 asset 菜单选对实体
- **按需加载流程**:懂 search→(activate)→act;不调未激活/不存在;不瞎编 id
- **工具选择(全 91 把,逐套)**:每请求在**完整工具全集**里选对(hd_ 不走 fn_ 家族;capability_check 不被 get_workflow 替代;**资产/主对话基础工具不被 forge 工具误抢**,反之亦然)

### 组 2:Forge 产物语义(核心)
- **create_workflow**:拓扑齐/边连对/case 分支 CEL+to 对/回边接对上游/callable ref 对/agentRef 对/无悬空死路/**整图真能实现业务流**
- **edit_workflow**:改动达成(插/删/重连/改 case)+ 引用现有 id 对 + 没误伤
- **create_agent**:prompt/skill/knowledge/tools/outputSchema/model 逐项符;**tools 只 fn/hd/mcp**;outputSchema kind 对
- **edit_agent**:ops 达成 + tools 合法
- **create_function**(normal+polling):kind 对;polling 有 interval;**code 真跑通**+ 逻辑对 + polling 返 `{events,next_cursor}` 且 **cursor 真推进**
- **edit_function**:改动达成(加方法走 update_code 也算对)
- **create_handler**:**code 真跑通**(实例化+init+调 method)+ **bare-names 真遵守** + 逻辑对 + schema 齐
- **edit_handler**:改动达成
- **trigger 节点 config**:kind 对 + payloadSchema 合理 + kind-specific 对
- **approval 节点 config**:prompt 含必要插值 + timeoutBehavior/allowReason 合理 + 分支接对
- **资产写工具产出**:create/edit_document(内容达意 + 路径对)· write_memory(记对事实)· call_mcp_tool(server/tool/args 对)· install_mcp_from_registry(选对 server)· activate_skill(激活对的 skill)
- **主对话基础工具(文件/shell/web/task/交互)**:产品没上线,**一样深测**——真 ReAct 里验选对 + 参数构造对 + 结果解读对 + 描述清晰 + token(USAGE 5 件);Write/Edit 额外判写对内容(CONTENT);描述"瞎写"的就改

### 组 3:子表达式 / 子结构
- **CEL**:条件语义(`>=` vs `>` vs `==` 精确)+ null-safety(has())+ 读对字段 + loop emit attempt+1 + 目标节点对
- **callable ref**:形式 + 内容跟请求一致
- **结构化参数**:每个参数值精确对应(sql/payload 字段/server·tool)
- **注入字段**:summary 切题;destructive 对危险操作判 true;execution_group 合理

### 组 4:系统 prompt 机器
- **系统 prompt 段**:完整组装下整体行为符预期(不越权、懂工具约定)
- **section 顺序**:关键守则被遵守(G7 殿后)
- **chainPatternsSection**:多步先 plan 再执行
- **lazy 分组**:11 组 + 组名 + activate 描述让激活对(V4 search-in-lazy)
- **error envelope 恢复**:收 sentinel+next_step 后下一步正确自纠

### 组 5:Utility(非 tool-call 输出)
- **auto-title**:切题 + 简短 + 无引号/markdown
- **rerank ×4**:valid JSON id 数组 + top-1 真最相关 + 无 prose
- **compaction**:保住关键决策/未决项 + 不超长
- **env-fix**:valid JSON `{deps}` + 包名对
- **web-summary**:准确 + 不超长 + 无幻觉

### 组 6:subagent 角色 prompt
- **explorer**:只调 search/get,绝不 create/edit/delete
- **forger**:正确建(create→accept)
- **verifier**:正确审/报告,不越权改

### 组 7:端到端 ReAct(最高保真)
- **完整 workflow 编排**:cron→拉邮件→agent 分类→case 路由→approval→reply→retry-loop 整条建对 + 可运行
- **多实体锻造链**:create_agent + N function + 接进 workflow + activate
- **诊断链**:query_events→trace→dead_letter→replay 正确定位 + 修
- **错误恢复**:中途调错/报错后自纠
- **跨实体任务**:"给客服 agent 加查订单能力" → forge function + edit_agent 挂上
- **AI 错误诊断**:收 trigger_exhausted/handler_crash 通知后正确诊断 + 提合理修

### 组 8:token↔结果平衡(贯穿)
- 每 surface 记 token;在"达到语义正确"前提下找最省描述/prompt(M4:不是越长越好)

**judge 裁决 schema**:`{surface, correct: bool, dimensions: {<各维>: bool}, why: str, fix_hint: str, tokens: int}`;组 7 额外 `steps`/`recovered`。

---

## §5 执行架构

### 5.1 一个 episode(Claude subagent 当后端+用户+裁判)
```
episode(一个真实用户任务):
  Claude subagent 循环:
    1. 调 DeepSeek(完整组装 prompt + 当前对话)→ 这轮 think/activate/tool_calls
    2. Claude 当【后端】真执行工具:
         code 类 → 子进程实跑,返真实结果/报错(§6)
         ops/edit → 真应用到图/实体,返成功或校验错(含 next_step)
         读类(search/get)→ 返真实合理数据(含 id)
         activate_tools → 真扩出该组工具进下一轮 offer
    3. Claude 当【用户】:需澄清时给真实用户口吻追问回复
    4. 回 DeepSeek 下一轮,直到任务完成/卡死/超步
    5. Claude 当【裁判】:语义审整条轨迹(意图/激活/每步结果/最终达成/token)→ schema 裁决
```

### 5.2 Workflow 工具编排(大规模并行)
```
phase Generate: 真实用户任务库 × N → 每个任务一个 episode(Claude subagent 驱动,内含 DeepSeek 多轮)
phase Judge:    每条轨迹 3 个 Claude judge 并行审(对抗式,默认怀疑)→ 多数表决(≥2 correct)
phase Cluster:  汇总真实语义率 + token 甜点 + 失败模式聚类(per surface)
phase Fix:      系统性失败 → fixer subagent 改描述/schema/prompt → 重跑该 surface episode → 回 Judge
loop 到各 surface 语义率收敛 / 失败稳定 / apikey 耗尽
```
- 单 judge 偏差用 3 票多数表决降;对抗 prompt 要求"主动找错"。
- 规模:全 surface × 真实任务库 × 多轮 × 3 judge ≈ 上千 subagent。预算无限放开。

### 5.3 真实用户任务库(不是命令)
明确("上线 wf_report")→ 含糊("那个每天发报告的流程让它自动跑")→ 复合("建邮件分类流程,发票要人工确认")→ 诊断("昨天报告没发,看看咋回事能修就修")→ 跨实体("给客服 agent 加查订单能力")。每个覆盖 §3 若干表面。

---

## §6 code 真执行(已锁:直接上执行)

每个 function/handler 生成的 code **实跑**:
1. 抽 code → 临时 `.py` → 子进程跑,喂测试输入。
2. **Mock 外部依赖**(`fetch_since`/slack client/gmail)用 stub 注入,测逻辑/cursor,不连真服务。
3. 三档:**runs-clean + 输出对** / **runtime-error**(给 traceback)/ **wrong-output**(实际 vs 预期)。
4. handler:实例化 class + init + 调 method,验 bare-names 真能跑;polling:跑 `poll(last_cursor)` 两次验 cursor 真推进、不重复。
5. 执行在 `/tmp` 隔离(避 Documents TCC)。真没法 mock 的外部依赖 → Claude 读判 + 标注。

---

## §7 运行与终止

- **跑到 DeepSeek apikey 余额耗尽(402)才停**(被测模型走 ¥200 池;Claude judge/执行走 Max 额度不计)。
- **预算下的优先级(91 把全深测,但 ¥200 有限)**:按风险排序——CODE/ARTIFACT 高风险锻造先吃深 reps,USAGE 读类后排;若 apikey 先耗尽,**报告里逐 surface 明记实际跑了多少 reps**。无声砍覆盖 = 假信心,禁止。DeepSeek 调用是唯一闸门,Claude 侧不限。
- 中途轮询迭代:judge 抓系统性失败 → 改描述/prompt → 重跑重判,真实率持续往上。
- 全程持久化(语料 + 裁决 + 迭代日志),可跨 session 续。

---

## §8 最终设计文档结构(★ 用户最关心的产物)

两份,cross-link:

### 8.1 `14-llm-facing-design-spec.md` —— 完整设计规格(主交付物)
> 每个 LLM-facing artifact 都「**最终文本 + 为什么 + 实测语义正确率 + token + 贴哪个文件**」。工程师照抄即可,零猜测。

```
§0  全局 LLM 设计原则(修正后的 master 发现,每条:规则+证据+为什么)
     thinking(别全局关,仅复杂长 ops 特殊处理)/ max_tokens / search-first /
     concise 教学 / ref 正则 / 类型 guard / recency(关键规则殿后)/ error-envelope
§1  完整系统 prompt 规格(整套组装的最终文本)
     identity / how_to_work / tool_conventions(summary/destructive/execution_group 解释)/
     catalog 渲染格式 / chainPatternsSection / 段顺序(关键规则殿后)
§2  Lazy 分组 + activate_tools 完整规格
     11 组逐组成员 / Resident 集 / activate_tools 描述全文 / search-in-lazy 决策
§3  全 91 工具规格(逐个,含资产管理 + 主对话基础,无一例外)
     每个:Description() 完整文本 + Parameters() 完整 schema + 何时用 + 类型 guard +
     example(复杂的)+ 实测语义正确率 + token + 残留失败模式 + 验证模式(CODE/ARTIFACT/CONTENT/USAGE)
     (全部 91 把无豁免:描述都是初稿,深测后不行就重写)
§4  Forge 实体锻造完整规格(深工具)
     create/edit × function/handler/agent/workflow:完整教学 prompt + ops schema +
     polling cursor 模板 / handler bare-names 模板 / 5-node workflow 模板 + 完整 example
§5  CEL / callable-ref / 注入字段 完整规格(教学全文 + 例 + 反例)
§6  错误信息 envelope 完整规格(sentinel + field/got/expected/next_step 格式 + 例)
§7  Utility prompts 完整规格(auto-title/rerank×4/compaction/env-fix/web-summary 最终 prompt 全文)
§8  subagent system prompts 完整规格(explorer/forger/verifier 全文)
§9  实施 roadmap(每个 artifact 贴哪个 .go 文件 + 改动量)
```

### 8.2 `13-validation-report.md` —— 验证证据(支撑)
```
§0  TL;DR + master 发现(修正版)
§1  方法论(真 ReAct + Claude 判 + code 真执行)
§2  每个 surface:结构率(标"上界")vs 语义率 + 逐轮迭代日志 + 失败 case
§3  端到端 episode 完整轨迹样本(成功 + 失败各几条,看真实行为)
§4  token 甜点分析(每 surface)
§5  code 可运行率(真执行结果)
§6  残留 + 给 revamp 设计的建议(若有)
§7  成本 ledger + 规模
```

---

## §9 已锁决策 + 确认清单

| # | 项 | 锁定 |
|---|---|---|
| A | **最终产物 = 完整细节设计文档**(每个 artifact 最终文本+证据),团队照抄零猜测 | ✅ |
| B | 真实**完整打包 prompt**(system 段+catalog+lazy+真 tool 描述),非单命令 | ✅ |
| C | 真 **ReAct 多轮**,Claude subagent 当后端+用户+裁判,**真执行**工具 | ✅ |
| D | **每个产物过 Claude 审语义**(对抗式 3 票),code **真执行**,非结构蒙混 | ✅ |
| E | 全覆盖 §4 rubric;**全 91 工具逐个(含资产 mcp/skill/doc/memory + 主对话基础 文件/shell/web/task/交互)** + 全非工具表面 | ✅ |
| F | DeepSeek 被测 / Claude 判+执行;Workflow 编排放开 subagent | ✅ |
| G | **跑到 apikey 烧完**,中途轮询迭代修 | ✅ |
| H | **工具定义本就不同**:agent.tools 只挂 fn/hd/mcp 当 agent 的 tool;workflow 是**节点**可配 agent。不对称正确,已定 | ✅ |

**请审核此 v5 plan。确认后我开 Workflow 铺真·端到端 eval,最终产出 §8 的完整设计文档。**
