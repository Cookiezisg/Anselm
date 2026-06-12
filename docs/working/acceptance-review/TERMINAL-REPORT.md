---
id: WRK-017
type: working
status: active
owner: @weilin
created: 2026-06-13
reviewed: 2026-06-13
review-due: 2026-09-13
expires: 2026-09-13
landed-into: ""
audience: [human, ai]
---

# 终报 —— 全产品真机验收 + 体验审查（2026-06-12～13）

> 草稿（W7 真模型结果跑完即定稿、W8 收口）。逐条细节见 [findings.md](findings.md)；裁决见 [DECISIONS-PENDING.md](DECISIONS-PENDING.md)；接手见 [HANDOFF.md](HANDOFF.md)。

## 1. 定位：第四种审查

前三种审查（实现正确性 / 设计自洽 / 闭环配对，见 git `product-review-r*`）都是**读码推演**。本轮**真开机、真打请求、真跑模型**——独立 Go module `testend/`（零 backend import）编译并拉起真 `cmd/server` 二进制，讲纯 HTTP/SSE；柱 A 全功能真机验收 + 柱 B 体验静态审读 + 柱 C 真模型金标旅程。

**核心命题被证实**：黑盒压力能抓到读码审查结构上抓不到的 bug。最硬的证据是 **9 个「设计完整、接线缺失」**——端口/store/工具/单测/文档全在，唯独 boot 漏接一条线，于是功能名义存在、物理失效；单测（注入 fake）绿、code review 见实现、doc 称其有，只有"真打那条路拿到错误结果"才暴露。

## 2. 方法与永久资产

| 资产 | 作用 | 命令 |
|---|---|---|
| `testend/` 黑盒套件 | 真二进制 + 纯 HTTP/SSE，函数名即验收台账行 | `make testend`（llmmock 零 token，分钟级） |
| `harness/llmmock.go` | OpenAI 兼容假模型，真走 provider HTTP 链、按 model id 独立队列、每请求捕获 PromptDump | （随 testend） |
| **PromptDump** | 「模型在线缆上真看到什么」= 体验审计事实源（柱 B）+ tool_result/usage 断言 | （随 testend） |
| `golden/` 金标套件 | 真模型端到端旅程（deepseek-v4-flash），EVALS 门控 | `make evals`（自动 source `.env`，烧钱手动跑） |

三柱共用同一 harness：柱 A 用 llmmock（零 token 跑全功能），柱 B 审 llmmock 抓到的 promptdump，柱 C 把 llmmock 换成真模型。

## 3. 发现总账（AC-1..AC-24）

24 条 finding，亲机复现 + 亲验定性。分级处置：

- **🔴 功能不可用/语义错（6）**：AC-4（常驻实例绑死请求 ctx）、AC-9（并发政策无设置口）、AC-10（ExtractMeta 零调用 set_meta no-op）、AC-11（nil-input 触发零参实体必崩）、AC-16（STREAM_IN_PROGRESS 名义存在物理失效）、AC-17（provider tool-call id 撞主键整回合丢失）、AC-18（压缩水位线只折叠 assistant）、AC-21（apikey 删除守卫 RefScanner 生产零注册）。**全部 fixed**。
- **🟠 介于（2）**：AC-13（mcp-calls 路由缺失）、AC-14（Status 与下载抢锁挂 52.7s）。fixed。
- **🟡 体验/一致性（8）**：AC-2/5/6/7/12/19/20/22/24——含护盾、竞态、校验漏洞、错误指路、热换、locale 权威等。多数 fixed，AC-20 观察。
- **🟢 轻症 / by-design 关闭（多条）**：AC-1/3/8/15/23 等。

> 注：🔴 计数含跨波的同族（AC-17/18 同属 W4），实修复独立条目以 findings.md 为准。

## 4. 贯穿 bug 模式图谱（最可迁移）

1. **设计完整、接线缺失（9×，本程序最高产）**：AC-9/10/13/21 + 产品审查期 limits 空壳 / todo_write / 唤回环 / 活监听重绑 / GetRegistryEntry。修法永远是"接上已有的件"。最阴变体：端口有定义、有单测（注入 fake）、有文档承诺，但 boot 从没注册真实现（AC-21）。
2. **契约名义存在、物理失效**：AC-16（STREAM_IN_PROGRESS 注释自身两句互斥）。
3. **provider 线缆习惯触雷**：AC-11（nil→null→f(**None)）、AC-17（call_1 每步复用撞 PK）。
4. **不变量只覆盖一半**：AC-18（水位线只投影 assistant、user 原文随行）。
5. **生命周期绑错 ctx**：AC-4（常驻实例绑死首个请求 ctx）。
6. **锁顺序把可见状态锁死**：AC-14。
7. **护盾缺失 / 跨管道竞态**：AC-5（print 污染 JSON-RPC）、AC-6（stderr 窗口）。
8. **校验漏洞**：AC-7（approval 孤值）、AC-19（EMPTY_CONTENT 不 trim）。
9. **运行时热换未贯通**：AC-22（maxSteps 构造时捕获，唯一不实时读的 limits 字段）。
10. **显式设置不驱动其该驱动者**：AC-24（workspace.language 不驱动回复语言）→ 用户裁决修复。

## 5. 各波结论

| 波 | 范围 | 结论 |
|---|---|---|
| W0 | 环境+座架 | harness/llmmock/promptdump 三件套落地；真二进制 smoke 绿 |
| W1 | 锻造域 | 4 雷修复（含只有真机能抓的 AC-4）；env 物化可见性钉死 |
| W2 | 编排域 | 3 🔴 修复 + **kill -9 崩溃恢复 PASS**（durable 终极考试）；四 trigger kind 全真跑 |
| W3 | 集成域 | MCP 真装真调（脚本+官方 npx）+ Search 全况含 **RAG 真下载真嵌入跨语言命中**；2 接线/锁 bug 修复 |
| W4 | 对话域 | **llmmock 进场即钓三 🔴**（读码审查抓不到，需真 provider/真落库/真重叠）；压缩水位线/人在环/在飞控制全验 |
| W5 | 平台域+涟漪 | AC-21（守卫接线于无）+ AC-22（热换）修复；workspace 级联删/apikey 三引用拒删/limits promptdump 验截断/relation 涟漪 |
| W6 | 体验静态柱B | promptdump 7 审读全绿（无安全剧场 / preview 无漂移 / S18 字段齐 / 视角隔离）；AC-24 locale 权威修复 |
| W7 | 金标真模型柱C | **deepseek-v4-flash 真驱动产品工具面，7/7 全绿首跑即过**：J1 bootstrap / J2 build+run function（旗舰）/ J3 build+call handler / J5 debug+edit / J7 search building blocks / J9 memory write+recall / J12 degraded。结果状态断言（实体建了、function 跑了、handler 调了、memory 召回了、搜到了）。**证明柱 A/B 的 llmmock 结论非假模型假象**。 |

## 6. 裁决台账

- **AC-PD-1**：function/handler 同步阻塞 env 物化 = by-design（可见性实测成立）。✅
- **AC-PD-2**：locale 权威 = workspace.language（用户裁决，已实现：WorkspaceResolver.Resolve + IdentifyWorkspace 覆盖）。✅

## 7. 永久资产 + 后续

- 验收套件 `make testend`（回归门禁候选）、金标 `make evals`、promptdump 审计、本套 working 文档（HANDOFF 可换 agent 接手）。
- 后续：前端重建对接已验证的后端契约；AC-20（apikey 未探测的静默降级）前端设置页提示；golden 旅程可按需扩到柱 C 计划 12 条（workflow-to-parked / MCP / skill 等过重项酌情）。
