---
id: WRK-005
type: working
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-11
review-due: 2026-09-11
expires: 2026-09-11
landed-into: ""
audience: [human, ai]
---

# round2-findings —— 二轮 Code Review（发版门禁，主模型亲审、零 agent）

> 用户要求：高标准、不开 agent、Fable 5 主模型亲审全项目，目标**可直接发版**。
> **第一维度（用户钦点最高优先）：产品角度是否正确、符合预期**——每个模块先立"产品上应该发生什么"（对照 architecture/domains 文档的产品语义 + 桌面单用户场景的常识预期），再对照实现，重点看边界场景下用户实际体验到的行为；代码再对也救不了产品语义错。其余维度（工程正确性/质量/架构/可维护）服务于它。
> 编号续用 CR-N（一轮止于 CR-12）。一条 = 维度 · 严重度（🔴 发版阻断 / 🟡 应修 / 🟢 小 / 📋 产品决策）· 验证过程 · 处置。

## 波次（按发版风险排序，全部亲读）

| 波 | 范围 | 状态 |
|---|---|---|
| W1 | 安全面：tool/shell·filesystem·search·web·mount·document、pathguard/fspath、fs/skill·memory·blob（路径穿越/命令注入/SSRF） | ← 进行中 |
| W2 | 传输层：28 handlers + middleware + response + router（N1-N5、输入校验、状态码） | ⬜ |
| W3 | orm + db + 全部 store（D1/D2、游标分页、SQL 构造、tx） | ⬜ |
| W4 | 引擎：scheduler + flowrun + workflow domain + trigger（D3、record-once、claim、timer、join） | ⬜ |
| W5 | llm ×18 + loop + stream + contextmgr（流终态、用量、E1-E3） | ⬜ |
| W6 | 其余 app 服务（crud/capability/envfix/catalog/subagent/aispawn/apikey+crypto…） | ⬜ |
| W7 | bootstrap ×12 + cmd（装配次序、停机次序、config） | ⬜ |
| W8 | pkg/* 小件（idgen/pagination/limits/jsonrepair/schema/cel/agentstate/reqctx/errors） | ⬜ |

## 发现

### W1 安全面 + 工具层（全部亲读：pathguard/fspath/shell/filesystem/search/web/mount/document/skill/memory/mcp/ask/subagent/toolset/function/agent/handler/workflow/trigger/control/approval 工具组 + infra/fs 三件 + loop tools/history，约 90 文件）

- **CR-13 🔴 已修** Bash foreground 孙进程持管道永久挂死：`cmd.Run()` 的 stdout/stderr 是 io.Writer → Go 开 os.Pipe + copy goroutine，Wait 等 copy 到 EOF。命令留下持有管道的孙进程（`npm run dev` 忘开后台被超时杀、脚本拉起 daemon 后正常退出）→ EOF 永不来 → **Run 永不返回**，对话队列整体卡死、cancel 无效（Cancel 只杀 sh）。修：① `WaitDelay=10s`（进程退出或 ctx 取消后强制关管道，Go 官方为此设计）② Unix `Setpgid` + 超时/取消/KillShell/Stop 全部组杀（`kill(-pgid)`，proc_unix/proc_windows 平台分流）。回归测试：`sleep 30 | sleep 30` timeout 200ms 须秒回（无修复阻塞 30s）。验证：shell 包测试 2s 全绿。
- **CR-14 🔴 已修** tool_result 无界：框架/loop 层无任何截断，结果整段落库 + 整段上 durable SSE open 帧 + 整段进**同回合**下一步 LLM 请求（warm 投影只裁后续回合）——一次不带 head_limit 的大树 content Grep（rg `cmd.Output()` 内存也无界）= LLM 400 + 巨型 DB 行 + 前端巨帧三连。修（强化地基）：① loop `capToolResult` 中央 256 KiB 硬顶（覆盖全部现/未来工具，含 MCP）② rg 路径 `cappedBuffer`（保头 256 KiB、丢弃计数、rg 跑完不杀——免断管舞步）③ stdlib 三模式输出循环加同值字节预算 + content 行模式 32 MB 文件守卫（与 multiline 同界；files/count 模式流式不受限）。
- **CR-15 🟡 已修** Glob 不跳噪音目录：与 Grep 的 noiseDirs 政策不一致——JS 项目 `**/*.js` 返回的 100 条几乎全是 node_modules（mtime 降序放大：刚装的包最新）。修：`hasNoiseSegment` 后置过滤（root 自身在噪音目录内不受限——显式意图）；测试断言 node_modules/.git 命中被排除。
- **📋 PD-4 留档**：WebFetch 默认把每个抓取 URL 发给第三方 r.jina.ai（带签名/token 的 URL 一并外发），直连仅为 fallback——local-first 隐私定位下这是产品决策（候选：A 默认直连+Jina 显式开启；B 现状+文档声明；C 配置项）。SSRF 守卫本身健全（全 DNS 答案检查、逐跳重检、1MB 封顶）。
- **🟢 wontfix/留档**：pathguard 不解析 symlink（本地单用户反足枪层、非安全边界，shell 本就可直读）；DNS rebinding TOCTOU（查后拨号，同阈值）；`invoke_agent` 硬编码 TriggeredByChat 而 `run_function` 有 triggerFromCtx（溯源标签不一致，W6 看 subagent 工具集后定）；grep stdlib `byteOffsetToLine` O(hits×size)（有 32MB 界，可接受）。
- **整体评价**：工具层质量高——5 方法契约一致、sentinel 共享（S20）、domain 错误全译 LLM 可行动话术、forge 镜像/进度流一致、fs 三件穿越守卫+原子写+隔离齐全、测试覆盖扎实。
