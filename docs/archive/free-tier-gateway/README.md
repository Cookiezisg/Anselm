---
id: WRK-030
type: working
status: active
owner: @weilin
created: 2026-06-19
reviewed: 2026-06-19
review-due: 2026-09-17
audience: [human, ai]
landed-into:
---

# Anselm Free-Tier Gateway —— 免费档模型网关设计蓝图（START HERE）

> **本文件是自包含、可搬运的独立项目蓝图**。它描述的网关是一个**独立于 Anselm 主仓库**的小服务（建议仓库名 `anselm-gateway`）；把这个文件夹整体拷进新仓库，它就是那个项目的 README + 设计文档，无需回看 Anselm 任何上下文即可实现。
>
> **范围聚焦**：本蓝图**只做网关 API**。官网、下载分发、网页分析、运营后台等**明确不做**（早期用 GitHub Releases + README 顶着即可）。仅「第 9 章 客户端集成」会落到 Anselm 主仓库。
>
> **本版（v2）已据一轮 5 视角对抗评审加固**——核心设计相对初稿有重大修正（预算预占、每日配额、install token 不回显、客户端走 `GET /quota`、内置档=合成 api_key 行）。详见 §17 变更记录。

---

## 0. TL;DR（一分钟读完）

- **要做的事**：作者自掏腰包，给所有用户一个**内置免费模型档**（DeepSeek），促进使用、增长 GitHub star。
- **已否决**：把 API key 加密打进客户端二进制——**客户端密钥在密码学上不可保密**（§4），且零成本控制。
- **正确做法**：一个**薄网关**，key 只存服务端；客户端调网关、不直连 DeepSeek。
- **部署位置**：**香港**（免备案 + 大陆/海外都可达）。代价：大陆免费档经香港 + 香港→DeepSeek 两跳跨 GFW，晚高峰会抖动（§2.3）。
- **双路径**：免费档走网关；用户可一键切「自有 key 直连」（不经网关、大陆直连、最快、不限额）。**自有 key 是首选叙事，免费档定位为「尝鲜」**（§15）。
- **钱包护栏（本版核心修正）**：**悲观预占 + 每日全局预算 + install 级每日 token 子配额 + 全局并发上限**。绝不用「事后累加」（在并发/崩溃下会被击穿）。最坏损失 = **当天**预算，次日恢复。

---

## 0.5 设计硬红线（不可妥协，违反即不达「成熟」）

> 这一节是评审加固后提炼的**红线清单**，实现时逐条对照。展开见对应章节。

1. **预算用「预占」不用「事后累加」**：进上游前，在一个事务里按「估算 prompt token + clamp 后 max_tokens」原子预扣全局/install 预算；流结束据实回补。崩溃只会**多扣**（偏保守、保钱包）。**产出前失败必须回滚全部三项预占（次数 + install 日 token + 全局日预算）——漏回滚 budget 会让被薅请求虚占当日预算、提前打成 402。** 估算器 `estimatePromptTokens` **必须保守 ≥ 真实分词**，否则三处护栏同时被侵蚀。（§7、§16 blocker）
2. **全局预算按「每日」不按「每月」**：被薅最坏只损失当天。（§7.4）
3. **`/v1/install` 绝不回显既有 install 的 token**：客户端持久化 token、重装即新 install；fingerprint 只作观测/风控信号，**不作配额合并键、不据它返回他人 token**。（§5.1、§8.2）
4. **请求体严格白名单**：只放行 `model`(改写)/`messages`/`stream`/`temperature`/`max_tokens`(clamp)；`n`>1、`logit_bias`、`stream_options`、`tools` 等一律剥离/拒绝。输入侧也限（prompt token 上限 + body ≤256KB）。（§5.2）
5. **DeepSeek key 永不出服务端**：不入任何日志/错误/metric/panic stack；上游错误**不透传**给客户端（归一化）。（§4.3、§11）
6. **网关面向公网任意来源**：base_url 打进开源二进制 = 任何人可调；客户端身份**不构成信任边界**，仅靠 `/install` 频控 + 预算封顶兜底。（§9.1）
7. **全局并发上限 + 上游账号级并发治理**：约束网关→单 DeepSeek 账号的总并发，留在账号上限下；上游 429 单独成类（可重试/排队，**不**直接 502、**不**误判为「产出前失败」回滚）。（§7.6、§14）
8. **配额/预算耗尽 ≠ key 失效**：Anselm 侧映射成专门错误码，**绝不触发 `MarkInvalidByID`**（否则合成 key 被置 error、内置模型从选择器消失）。（§9.5）

---

## 1. 背景与目标

### 1.1 目标
1. **零配置**新用户开箱即用一个免费模型档（无需自己注册 DeepSeek、填 key）。
2. 借「免费福利」拉动使用与 star 增长。
3. **有上限**的成本支出。

### 1.2 硬约束
- **免备案**（作者新加坡人、大陆无实体，ICP 备案成本过高，排除）。
- 大陆 + 海外都要能用。
- 最省钱、最省力、用标准范式，**成熟、bug-free**。

### 1.3 非目标
- 不做面向公众的多租户 SaaS。
- **不做官网/下载站/网页分析/运营后台**（用 GitHub Releases + README 顶）。
- v1 不做用户账号体系（GitHub 登录为可选演进，§8.5）。
- 网关只做「鉴权 + 计量 + 预算 + 透传」，不做 prompt 业务逻辑。

---

## 2. 核心决策与「不可能三角」

### 2.1 为什么必须有网关（而非嵌入 key）
见 §4。一句话：**任何能在用户机器上自动解密的 key，用户自己也能解出来**（开源仓库 + 二进制 + 本机抓自己出站流量 + 内存 dump）。嵌入方案还**零成本控制**，泄漏即无上限烧钱。

> 对照：Anselm 的 machine-fingerprint 加密器（`infra/crypto`）能成立，是因为它加密「用户自己的数据」、合法用户机器能重新派生指纹来解；它**解决不了**「对运行 app 的本人隐藏作者的 key」。

### 2.2 不可能三角
```
        大陆境内最优体验
           /        \
   免备案 ──────────── 不自己运维
```
三者只能取二。要大陆境内最优 → 放大陆 → 要备案（排除）。要免备案 → 放境外 → 大陆访问跨境。备案判定看「服务器是否在大陆 + 是否用域名对外服务」，**不看访问者是谁**——即使只有作者 app 访问也触发。→ **别放大陆**。

### 2.3 关键事实：DeepSeek 在大陆，跨境跳要正视
`api.deepseek.com` 在大陆（杭州）。**端到端 = 用户→香港 + 香港→DeepSeek + 回程**，后两跳都跨 GFW。

| 网关位置 | 用户→网关 | 网关→DeepSeek | 备案 | 结论 |
|---|---|---|---|---|
| 海外（欧美） | 大陆跨境，差 | 又从海外回大陆，再跨一次 | 否 | 两次跨境，最差 |
| **香港** | 大陆跨境但优 | 跨境回大陆 | 否 | ✅ 免备案下最优 |
| 大陆境内 | 直达最优 | 境内最快 | **是** | 体验最佳但排除 |

> ⚠️ **诚实标注（评审纠正）**：
> - 「香港 30~80ms」**仅为「用户→香港、非高峰、优质 CN2 线路」单跳**，**不是端到端**。
> - **网关→DeepSeek 是跨 GFW 链路**：晚高峰（18:00–24:00 CST）有 5–15% 丢包、延迟尖峰 100–200ms+、路由漂移。这一跳承载全部免费档流量，是真实瓶颈。
> - 缓解：§10.1 选**带 CN2 GIA / 三网优化回程**的香港线路（普通 BGP 香港机晚高峰回大陆很差）；§7.6/§14 的上游超时按真实抖动设阈值 + 有限重试。

### 2.4 最终决策
1. **网关放香港**（免备案、大陆海外可达）。
2. **双路径**：免费档（作者 key 经网关）+ 自有 key 档（用户填自己的 key、直连、不经网关）。
3. **运行形态**：香港轻量服务器上**单文件 Go 二进制 + SQLite**（对大陆友好的 serverless 边缘节点没有好选择）。
4. **身份尽力而为，预算封顶兜底**。

> **排除项的准确理由（评审纠正）**：
> - **Cloudflare Workers**：`workers.dev` 子域大陆被 DNS 污染，但**自有域名的 Worker 大陆是可达的**。真正排除根因 = ① 无原生 SQLite/单写者串行化（状态层要换 D1/DO，与「单文件 Go+SQLite 最简」冲突）② 流式 SSE 长连接受 CPU/时长约束 ③ 仍需跨境回大陆打 DeepSeek。
> - **Vercel / Deno Deploy**：海外边缘，大陆可达性一般 + 同样跨境 + 无原生 SQLite。

---

## 3. 系统架构

### 3.1 拓扑
```
┌─────────────┐  localhost   ┌──────────────────┐
│ Flutter app │ ──HTTP/SSE──▶│ Anselm 后端 sidecar│
└─────────────┘              └───┬───────────┬───┘
                     免费档 │           │ 自有 key 档
                            ▼           ▼ 直连(不经网关)
              ┌──────────────────┐      │
              │ 香港网关          │      │
              │ Go + SQLite      │      │
              │ key/计量/预算/并发 │      │
              └────────┬─────────┘      │
        跨 GFW(晚高峰抖)│                │ 跨 GFW
                       ▼                ▼
              ┌──────────────────────────────┐
              │ DeepSeek (api.deepseek.com)   │ 大陆境内
              └──────────────────────────────┘
```

### 3.2 一次免费档请求的生命周期（预占模型）
1. 首启：Anselm 后端调 `POST /v1/install` 领 **install token**，加密持久化（机器级，§9.3）。
2. 发消息：`Authorization: Bearer <install-token>` 调 `POST /v1/chat/completions`。
3. 网关（**入口快照 `period` 月+日**，全程复用）：
   a. 校验 token（哈希查表）→ banned 则 403。
   b. 请求体白名单校验 + clamp（拒绝 `n>1` 等）。
   c. **在一个 `BEGIN IMMEDIATE` 事务里原子预占**：次数 `count+1`（<月配额）→ install 日 token 子配额（+est ≤ 上限）→ 全局**日**预算（+est ≤ 日上限）。任一失败回滚并返对应 429/402。
   d. 取全局并发信号量（约束网关→DeepSeek 总并发，留在账号上限下）；满则排队/429。
   e. 注入 key（redacting transport）转发上游。
4. **上游首字节到达后**才发 `200` + 响应头（含 `X-Quota-*`）→ 流式透传（响应头白名单）。
5. 流结束（`stream_options.include_usage` 取真实 usage）→ **据实回补**：`est − actual` 退还/补扣全局预算与 install 子配额。
6. 异常：上游**产出前**失败/429 → **回滚全部预占（count + install 日 token + 全局日预算，三者缺一不可）** → 返 502/504/429（不发 200、不发配额头）。🔴 **漏回滚全局日预算会让「大量产出前失败」请求永久虚占当日预算、把免费档提前打成 402**（评审 v3 修正）。
7. 客户端配额展示走 `GET /v1/quota`（§9.4），**不依赖响应头**。

---

## 4. 安全模型（威胁建模）

### 4.1 资产
- **A1** DeepSeek key（泄漏=无上限盗用）。
- **A2** 作者的钱（token + 出网流量）。
- **A3** 作者 DeepSeek 账号合规信誉（用户内容算作者账号行为，违规可致封号→全体免费档死）。

### 4.2 威胁与对策
| 威胁 | 对策 |
|---|---|
| **T1 客户端 key 提取** | key 永不下发，只存网关 |
| **T2 Sybil 刷量** | 软指纹 + `/install` 单 IP 频控（持久化，§7.5）；**真护栏=每日预算封顶** |
| **T3 转售/脚本滥用** | 速率 + 单请求 `max_tokens` clamp + **input token 上限** + install 日 token 子配额 + 模型白名单 |
| **T4 内容滥用** | **取舍写死**：零正文记录→网关侧不做内容审核，靠 DeepSeek 上游审核 + ToS（§4.4）；按 install 吊销 |
| **T5 配额竞态** | 原子条件更新 + `BEGIN IMMEDIATE` 事务（§7.3） |
| **T6 token 泄漏** | token 哈希存储（§8.1）+ 可吊销 + 预算限损 |
| **T7 伪造剩余次数** | 配额服务端权威，客户端展示仅参考 |
| **T8 请求体放大/字段注入** | 请求体严格白名单；拒绝 `n>1`/`logit_bias`/`stream_options`/`tools`；input token 上限（§5.2） |
| **T9 服务端 key 泄漏** | Authorization 永不入日志；全局 `recover` 不裸 dump 含 key 结构；502 不透传上游错误体/头（§4.3） |
| **T10 资源耗尽 DoS** | `MaxBytesReader`(256KB) + Server 超时 + 每 install 在飞连接上限 + 全局连接/并发上限（§5.3、§7.6） |
| **T11 上游账号并发耗尽** | 网关→单账号全局并发信号量；上游 429 单独成类、可重试/排队（§7.6、§14） |

### 4.3 安全原则（写死）
- install token **不是强鉴权**，是「尽力而为领号凭证 + 可吊销句柄」。
- **每日全局预算硬封顶是最终、唯一可靠的钱包护栏**。
- 网关**不记录 prompt/completion 正文**，只记 `install_id / 用量 / 错误类别 / token 数`。
- **DeepSeek key 隔离**：(1) 用专门 **redacting transport**，outbound `Authorization` 永不进任何日志/错误/metric；(2) 全局 `recover()` panic handler 只记 request id + 错误类别，绝不裸 dump 含 key 的结构；(3) 上游错误**不透传**——`502` 返网关归一化错误，原始体/头只在脱敏后入服务端日志。
- **响应头白名单透传**：仅回 `Content-Type`、`X-Quota-*`、网关自有头；上游其它头（`Set-Cookie`/`Server`/账号侧信息）一律剥离。**CORS 默认拒绝**（网关被 localhost Go sidecar 调，无浏览器 CORS 需求）；**TLS 钉 1.2+** 现代套件。

### 4.4 A3 内容合规：取舍写死
- **决策**：保留「零正文记录」的隐私承诺 → 因此**网关侧不做内容审核**（事中无从拦截、事后无正文举证）→ A3 风险靠 **DeepSeek 自身上游审核 + ToS 接受**兜底。**删除任何「基本内容护栏」的承诺**（做不到，别误导）。
- **业务连续性预案**：A3 一旦触发（账号被封）= 全体免费档死。预案：(1) 配置支持**多 key / 备用 provider 热切换**（改环境变量重启即生效，key 不在客户端）；(2) 免费档可一键全局停（返 402），引导自有 key。

---

## 5. 网关 API 契约（OpenAI 兼容，自包含）

通用：鉴权头 `Authorization: Bearer <install-token>`（`/v1/install`、`/healthz` 除外）。错误统一 `{ "error": { "code": "...", "message": "..." } }`。

### 5.1 `POST /v1/install` — 领取 install token
- 无需鉴权。请求体：`{ "fingerprint": "<soft-fp>", "client": "anselm/<version>" }`
- 成功 `200`：`{ "token": "gwk_<32B-base64url>", "monthlyQuota": 5000, "resetAt": "...+08:00" }`
- 限频：单 IP 每小时上限（`INSTALL_PER_IP_HOUR`，**持久化到 SQLite**，不随重启归零）。超出 `429`。**IP 频控仅「减速」非安全边界**：IPv6 按 **/64 段聚合**限频（否则每用户海量地址形同虚设），大陆运营商 NAT 下又会误伤（万人共一出口 IP）——真护栏始终是每日预算封顶（§4.2 T2）。
- **🔴 不幂等回显既有 token（评审 critical 修正）**：fingerprint **不作幂等键、不据它返回任何既有 install 的 token**（否则「无鉴权 install + 知道 fp 即领走他人 token」= 凭证窃取）。每次 install **签发新 token + 新 install_id + 新配额池**；fingerprint 仅写入作风控观测信号。
- **重装/换机即新 install**（额度池重置），由**每日预算封顶**兜底刷量损失——与 §4.3 设计前提一致，也避免「指纹碰撞导致多用户共享配额池被互相薅空」（评审反向风险）。
- 并发 get-or-create 已不需要（不再去重），消除 check-then-insert 竞态。

### 5.2 `POST /v1/chat/completions` — 推理（核心）
- 请求体 OpenAI 兼容，但**严格白名单**：
  - 放行：`model`（被网关**强制改写/校验**为白名单内真实 DeepSeek model id）、`messages`、`stream`、`temperature`、`max_tokens`（**clamp 到 `MAX_TOKENS_CAP`**）。
  - **剥离/拒绝**：`n`（拒绝 >1，防 N 倍产出）、`logit_bias`（体积炸弹）、`stream_options`（网关自行设 `include_usage:true`）、`tools`/`function_call`、`response_format` 等一切其它字段。
  - **输入侧护栏**：`messages` 估算 prompt token 超 `INPUT_TOKEN_CAP` → 400；请求体字节 `MaxBytesReader(256KB)`。**🔴 估算用的 `estimatePromptTokens` 必须按选定 DeepSeek tokenizer 校准并保守高估（向上取整 + 安全系数，宁可误拒不可低估）——它同时是 input cap、预占 est、超顶界三处护栏的共同输入地基（§7.3、§13 单测断言、§16 blocker #6）。**
- 流式（`stream:true`）：网关自加 `stream_options:{include_usage:true}` 取末帧 usage；**上游首字节到达后**才发 `200`+响应头，逐帧透传至 `data: [DONE]`。
- 响应头（白名单）：`X-Quota-Limit` / `X-Quota-Used` / `X-Quota-Reset`（v1 客户端**不依赖**，见 §9.4）。
- 错误：

| 状态码 | code | 含义 | 客户端行为 |
|---|---|---|---|
| `401` | `INVALID_TOKEN` | token 缺失/无效 | **重新 install** |
| `403` | `ACCOUNT_BANNED` | install 被封 | **不重领**，提示用户 |
| `429` | `RATE_LIMITED` | 速率/日子限额 | 退避重试 |
| `429` | `QUOTA_EXHAUSTED` | 本月 5000 次用尽 | 提示切自有 key |
| `429` | `UPSTREAM_BUSY` | 上游账号并发满 | 短暂排队/重试 |
| `402` | `BUDGET_EXHAUSTED` | **当日**全局预算触顶 | 提示切自有 key（次日恢复） |
| `400` | `BAD_REQUEST` | 请求体非法/超 input cap | 不重试 |
| `502` | `UPSTREAM_ERROR` | DeepSeek 错误（归一化） | 重试有限次 |
| `504` | `UPSTREAM_TIMEOUT` | 上游超时/断流 | 重试有限次 |

> **封禁单列 403（评审修正）**：与 `401 INVALID_TOKEN` 区分，防客户端把封禁当 token 失效而**自动重领绕过 ban**。

### 5.3 `GET /v1/quota` — 查配额（客户端主路径）
- 鉴权。`200`：`{ "limit": 5000, "used": 137, "remaining": 4863, "resetAt": "...", "available": true }`（`available=false` 表示当日预算/账号态导致暂不可用）。
- **这是客户端展示配额的主路径**（§9.4 说明为何不用响应头）。
- ⚠️ `used` 含**在飞预占**（含 est 高估），是**保守上界**；请求流结束回补后收敛——客户端可能短时见 `used` 跳高再回落，属正常（服务端权威，§4.2 T7）。

### 5.4 `GET /healthz` — 存活探针
- 无需鉴权。`200 {"status":"ok"}`。

### 5.5 HTTP server 加固（防 T10）
- `Server.ReadHeaderTimeout` / `ReadTimeout` / `IdleTimeout`（防 Slowloris）。**🔴 流式响应不能用全局 `WriteTimeout`（会截断长流），改用 `http.ResponseController.SetWriteDeadline` 在每次 flush 时滚动续期。**
- 全局最大连接数 / 每 install 在飞流式连接上限（SSE 每条占 goroutine+上游连接）。

---

## 6. 数据模型（SQLite，WAL）

> **连接池分离（评审修正）**：写用单连接池 `MaxOpenConns=1`（串行化单写者）；读（`GET /quota`、监控）用**独立只读连接池**（WAL 允许并发读）。**DB 写只在「请求开始预占」「请求结束回补」两个瞬时点发生，绝不在流式转发全程持有连接/事务。**

```sql
CREATE TABLE installs (
  id            TEXT PRIMARY KEY,            -- ins_<16hex>
  token_sha256  TEXT NOT NULL UNIQUE,        -- 🔴 存哈希,不存明文 token
  fingerprint   TEXT,                        -- 仅观测,无 UNIQUE,不作合并键
  client        TEXT,
  status        TEXT NOT NULL DEFAULT 'active', -- active | banned
  created_at    DATETIME NOT NULL,
  last_seen_at  DATETIME
);

-- 月度次数 + 日 token 子配额(period 既有 'YYYY-MM' 也有 'YYYY-MM-DD' 行)
CREATE TABLE usage (
  install_id    TEXT NOT NULL,
  period        TEXT NOT NULL,               -- 'YYYY-MM'(次数) / 'YYYY-MM-DD'(日 token 子配额)
  count         INTEGER NOT NULL DEFAULT 0,
  tokens        INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (install_id, period)
);

-- 全局预算: 🔴 按"日"(period='YYYY-MM-DD"), 预占+回补
CREATE TABLE budget (
  period        TEXT PRIMARY KEY,            -- 'YYYY-MM-DD'
  tokens_used   INTEGER NOT NULL DEFAULT 0,  -- 含预占
  requests      INTEGER NOT NULL DEFAULT 0
);

-- 必选: per-request ledger, 崩溃恢复对账(回补孤儿预占)
CREATE TABLE ledger (
  request_id    TEXT PRIMARY KEY,            -- req_<16hex>
  install_id    TEXT NOT NULL,
  period_day    TEXT NOT NULL,
  reserved      INTEGER NOT NULL,            -- 预占 token
  settled       INTEGER,                     -- 回补后实际; NULL=未结算
  created_at    DATETIME NOT NULL
);
-- 🔴 启动期 + 周期扫描器(评审 v3): 对 settled IS NULL 且 created_at 早于阈值(如 10min,远超单请求时长)
--    的孤儿行, 按 reserved 回补全局日预算(tokens_used -= reserved)并标记 settled。
--    否则崩溃留下的孤儿预占在当日内永不释放(只靠日翻页自然清), 当日预算被慢性虚占。
--    这是 §11 "ledger.settled IS NULL 堆积" 告警与 §13 "崩溃对账" 验收的落点。
```

---

## 7. 配额、计量与预算（评审重写的核心章）

### 7.1 周期、时区与 period 快照
- **时区**：全网关统一 `Asia/Shanghai`（`RESET_TZ`）。
- **🔴 tz database（评审修正）**：纯 Go 静态单文件二进制极易缺 IANA tz db → `time.LoadLocation` 报错。**必须 `import _ "time/tzdata"`（内嵌 tz db，符合单文件理念）+ 对 `LoadLocation` 错误 fail-fast（启动 panic，绝不静默 fallback UTC，否则所有边界静默偏移 8 小时）。**
- **🔴 period 入口快照（评审修正）**：请求入口一次性算出 `period_month`('YYYY-MM') 与 `period_day`('YYYY-MM-DD')，**贯穿预占/回补全程复用**，绝不在回补/回滚时重算（否则跨月零点并发会作用到不同 period 行、破坏守恒）。
- 月度次数惰性按 period 建行，无需定时任务。

### 7.2 计费语义（写死）
- 「算一次」边界 = **上游成功开始产出**（首字节到达）。产出前失败/429 → 回滚预占（不计次、不发 200）。产出后断流 → 保留计次（防故意断流刷量）。
- **次数(5000/月)是用户可见额度；真实成本护栏是 token**（input+output），见 §7.4/§7.5。两者并行，防「用满 prompt 的请求以极少次数吃爆全局预算」（评审 T3/经济 #6）。

### 7.3 配额原子性（事务，防竞态）
单个 `BEGIN IMMEDIATE` 事务内（正确性**不依赖** `MaxOpenConns=1`）：
```sql
BEGIN IMMEDIATE;
-- 次数
INSERT OR IGNORE INTO usage(install_id, period, count, tokens) VALUES (?, :month, 0, 0);
UPDATE usage SET count = count + 1
 WHERE install_id = ? AND period = :month AND count < :monthlyQuota;   -- RowsAffected==0 → QUOTA_EXHAUSTED
-- install 日 token 子配额(预占 est)
INSERT OR IGNORE INTO usage(install_id, period, count, tokens) VALUES (?, :day, 0, 0);
UPDATE usage SET tokens = tokens + :est
 WHERE install_id = ? AND period = :day AND tokens + :est <= :installDailyTokenCap; -- 0 → RATE_LIMITED
-- 全局日预算(预占 est)
INSERT OR IGNORE INTO budget(period, tokens_used, requests) VALUES (:day, 0, 0);
UPDATE budget SET tokens_used = tokens_used + :est, requests = requests + 1
 WHERE period = :day AND tokens_used + :est <= :globalDailyCap;       -- 0 → BUDGET_EXHAUSTED
-- 任一 RowsAffected==0 → ROLLBACK 并返对应错误; 全过 → COMMIT
COMMIT;
```
- `:est`（预占）= `estimatePromptTokens(messages) + clamp(max_tokens)`。**🔴 `estimatePromptTokens` 必须保守 ≥ 真实分词（§5.2）——这是预占/护栏正确性的前提；若低估，已 COMMIT 的预占偏低、并发期预算被低估占用、超顶界推导失真。**
- **回补**（流结束）：`UPDATE budget SET tokens_used = tokens_used - (:est - :actual)`（`actual<est` 退还；`actual>est` 补扣）；install 子配额同理；并 `UPDATE ledger SET settled=:actual WHERE request_id=?`（供孤儿对账，§6）。`actual` 取上游末帧 usage；**断流拿不到 usage 时按 `:est` 全额保留（宁高估，护栏偏保守）**。
- **回滚边界登记 FMEA**（评审 #3）：`count-1` 与「另一并发请求刚因 `count<limit` 失败被拒」之间存在「本可放行却被拒」的瞬时不公平——账目守恒但偶发「还有额度却被拒」，登记 §14、客户端可自动重试一次，**不声称「绝对公平」**。

### 7.4 全局预算：每日、预占、有界
- **🔴 按日不按月（评审 critical，product #1）**：`GLOBAL_DAILY_BUDGET = 月预算/30`，`period_day` 0 点重置。被薅最坏损失**当天**，次日自动恢复（避免「月初被薅光→全月 402 崩塌」）。
- **🔴 预占而非事后累加（评审 critical，security #1 / concurrency #1#2）**：预占在建连前已落库 → 崩溃只导致**多扣**（偏保守）。最坏超顶界 = `全局并发上限 N_global × (INPUT_TOKEN_CAP + MAX_TOKENS_CAP)`（**有界**，靠 §7.6 的 `N_global` 封死），文档写明此界。
- **🔴 全局日预算 vs install 子配额求和关系（评审 v3）**：`sum(活跃 install × INSTALL_DAILY_TOKEN_CAP)` 与 `GLOBAL_DAILY_BUDGET_TOKENS` **无内建约束关系**——活跃数一多，全局日预算会**先触顶**，大量 install 在自身子配额未尽时集体撞 402（先到先得，**而非 §15 想要的「人人享少量」**）。**退场的正确旋钮是动态收敛 `INSTALL_DAILY_TOKEN_CAP ≈ GLOBAL_DAILY_BUDGET / 活跃 install 数`**（而非只降次数 `MONTHLY_QUOTA`）。

### 7.5 速率与子限额
- 每 install：分钟级令牌桶（内存，**重启重置无害**——粒度小，且日级子限额与 `/install` 频控已持久化兜底，无需持久化）；**`/install` 频控 + 每日次数/token 子限额持久化到 SQLite**（不随重启归零，防「打崩重启刷新频控」组合拳）。

### 7.6 全局并发 + 上游账号级治理（评审 deployment #2 / T11）
- **全局在飞并发信号量 `N_global`**：约束「网关→DeepSeek」总并发，**留在 DeepSeek 账号级并发上限以下**（账号级、非 key 级，多 key 不放大；具体值列 §16 blocker 待核实）。
- 超 `N_global` → 短暂排队（有界等待）或 `429 UPSTREAM_BUSY`。
- 上游 `429` **单独成类**：可重试/排队，**不**映射成 `502`、**不**当「产出前失败」误回滚扣费（区别于真错误）。
- `N_global` 同时封住 §7.4 的预算超顶界。
- **🔴 容量校验（评审 v3）**：`N_GLOBAL_CONCURRENCY × 单流峰值带宽 ≤ 服务器固定带宽`，否则并发尖峰下流式吐字被带宽**静默限速**。选套餐与定 `N_global` 须联合算（§10.1、§16 容量规划 #7）。

---

## 8. 身份与防滥用

### 8.1 install token
- 不透明随机 token（`crypto/rand` 32B base64url，前缀 `gwk_`）。
- **🔴 哈希存储（评审修正）**：服务端只存 `SHA-256(token)`（高熵随机串无需加盐/慢哈希），明文 token **只在签发瞬间返回客户端、绝不持久化**。这样 DB/备份泄漏不暴露可用 token。前缀 `gwk_` 保留（利于 GitHub secret scanning）。

### 8.2 软指纹（仅观测）
- 客户端生成，**仅作风控观测信号**（异常聚集→人工核查），**不作配额合并键、不参与幂等**（§5.1）。
- 明知可伪造，不作安全边界。
- 与 Anselm `infra/crypto` 的**硬件指纹是两套不同对象**，命名上区分（soft fingerprint vs hardware fingerprint）。

### 8.3 封禁
- 异常用量 → `status='banned'` → 后续请求 `403 ACCOUNT_BANNED`（非 401，客户端不自动重领）。
- 封禁阈值/申诉/误封恢复列 §16（避免自动 ban 误伤正常重度用户）。

### 8.4 兜底
- 一切身份手段失效时，**每日全局预算封顶**保证损失有界（每日上界）。设计前提，非补丁。

### 8.5 可选演进：GitHub 登录
- Sybil 严重时升级为 GitHub OAuth：配额绑账号、天然挡 Sybil、契合涨 star。注意 GitHub 大陆被限速，作可选、非 v1 必选。

---

## 9. 客户端集成（落到 Anselm 主仓库 —— 评审重写）

> **评审结论：集成可行，但远非「几乎零改」。** 以下按**与现有架构吻合**的方式重写。

### 9.1 provider：复用现有，不新增名
- **🔴 不新增 `managed`/`anselm-free` provider 名（评审 critical）**：`infra/llm` 的 `lookupProvider` 对未注册 name **静默 fallback 到 openai**（会注入 openai 专有 knobs，与网关白名单打架）；且 `app/apikey/providers.go` 白名单不含新名，合成 key 建不出来。
- **v1 做法**：直接**复用现有 `deepseek` 或 `custom`（APIFormat openai）provider**，`base_url` 指向网关、`key` = install token。最省改、不踩 fallback。
- 若将来确需独立 provider：必须同时在 `buildProviderRegistry` 注册 + `app/apikey/providers.go` 白名单登记（含 TestMethod）+ 自包含实现 5 方法——这是单独工作项。

### 9.2 内置免费档 = 一条「受管 api_key 行」
- **🔴 现架构无「无 key 内置模型」概念（评审 critical）**：模型目录完全派生自已探测的 api_key（`app/model/capability.go` 的 `CapabilityService.List` 只对 `TestStatus==ok` 的 key 产出；`domain/model.ModelRef` 强制 `APIKeyID` 非空；`modelclient.Resolve` 必经 api_key 拿 Credentials）。
- **落地方式**：免费档 = 后端 boot 时在每个 workspace **自动维护一条受管 api_key 行**：`provider`=`deepseek`/`custom`，`base_url`=网关，`key`=install token，`test_status` 置 `ok`。
- **🔴 落地链必须闭环（评审 v3 high，否则照写即坏）**：`CapabilityService.List` 产出模型**不只看 `test_status==ok`，还要 `DescribeModels(provider, TestResponse)` 能解析出 model id**（deepseek/custom 把 `TestResponse` 当 OpenAI `/models` body 解，且 id 须命中 `deepseekSpecs` 前缀）。因此创建受管行时**必须同时植入一段合成 `TestResponse`**，形如 `{"data":[{"id":"<网关映射的真实 deepseek model id>"}]}`——否则得到「`test_status=ok` 但选择器里没有内置模型」的**死状态**。
- **🔴「不可编辑/不可删」需新增机制（评审 v3 medium）**：「不可删」可靠现有 `RefScanner`（受管 `ModelRef` 引用 → `Delete` 报 `ErrInUse`）兜住；但**「不可编辑」现 `apikey.Service.Update` 不咨询任何 scanner**，需新增（受管行加 `immutable` 标记列 + `Update` 前置拒绝，或前端只读 + 后端守卫双层）。
- 不引入新「内置模型」概念（那需 model/apikey 两域大改 + 单独 ADR）。

### 9.3 install token 持久化
- **机器级单例**，存在**非 workspace 隔离**的机器级位置（不要塞进 D2 隔离表）。
- 多 workspace 下共享同一 install token（机器级）；受管 api_key 行可每 workspace 各建一条、但都引用同一 token。
- 用 `infra/crypto`（硬件指纹加密器）加密存。**指纹漂移兜底**：换硬件/重装致硬件指纹变 → 旧密文不可解 → 重新 `/install` 领新 token（额度池重置，由每日预算兜）。
- 注意 `app/settings` 当前 `settings.json` 是明文、且只存 limits 段 → install token **不要**塞明文 settings.json；落一个加密的机器级存储位（实现时明确）。

### 9.4 配额展示：走 `GET /v1/quota`，不用响应头
- **🔴 响应头主路径在现架构不成立（评审 critical）**：`Client.Stream → iter.Seq[StreamEvent]`，`StreamEvent` 不承载 HTTP 响应头；`provider.Stream` 拿到 `resp` 只把 `resp.Body` 交 `ParseStream`，`resp.Header` 从不上传。要透出响应头需跨 4 层协议改动（StreamEvent 加字段 + ParseStream emit + loop switch + messages SSE 新帧 + 前端 DTO），且与 E 系列「三流永不再加」冲突。
- **v1 方案 A（零协议改动）**：客户端用 `GET /v1/quota` —— 启动首屏拉一次 + 每次发消息后异步刷新。够用、不实时但简单。
- 方案 B（实时、未来）：正式在 `StreamEvent`/`EventFinish` 挂 quota 字段经 messages 流透出——列为演进项，**不进 v1**。

### 9.5 错误映射：配额耗尽 ≠ key 失效
- **现状真问题（评审 v3 核对后校准）**：网关 `401/402/429` 经 `transport.classifyHTTPError` 被压成通用 LLM sentinel（`ErrAuthFailed`/`ErrRateLimited`/…），**丢失细分**；尤其 **`402` 无 case → default → `ErrProviderError`（可重试）→ 被盲重试 3 次**（对预算耗尽盲重试是错的）。
- **MarkInvalidByID 是前瞻风险、非现状**：经核对 `MarkInvalidByID` **仅 web/search BYOK 路径调用，chat/agent LLM 路径今天不调用**——所以「内置模型从选择器消失」是**将来若给 LLM 路径加自动失活时**的规则（受管行须豁免），别去修一个当前不存在的触发点。
- **要求**：识别网关 `error.code`（`QUOTA_EXHAUSTED`/`BUDGET_EXHAUSTED`/`UPSTREAM_BUSY`）→ 映射成 Anselm 侧**专门的、非「key 失效」语义**错误码（新增 `error-codes.md`），且 **`402`/`429` 不进 `isRetryable` 盲重试**。
- **🔴 拦截点（评审 v3，文档须给落位）**：受管行走标准 `providerClient.Stream → doRequest → classifyHTTPError`，现架构**无「按 key 是否受管」的钩子**。落点二选一：在 `classifyHTTPError` 之外、或受管 `ModelRef` 解析后，**按 `base_url==网关` 判定 + 解析网关 `{error:{code}}` body** 做专门映射。仅 `INVALID_TOKEN` 才走「重领 token」；`ACCOUNT_BANNED` 不重领。

### 9.6 双路径 + 隐私（产品决策，非开放问题）
- 降级：`402`/`429 QUOTA_EXHAUSTED` → UI 明确提示「切自有 key（直连、大陆更快、不限额）」。
- **自有 key 是首选叙事**：首次配置即并列推荐自有 key（强调更快/不限额），免费档定位「尝鲜」（缓解 evaluator 担心的「分流不发生→免费档承载全量」）。
- **🔴 隐私冲突要定死（评审 high）**：Anselm 主打本地优先/隐私，免费档把 prompt 经作者服务器 + 过作者 DeepSeek 账号。**免费档默认关闭 + 首用走显式 modal 同意**（不止一行标注），文案直言「内容会经我们的代理与第三方模型，免费档不享本地隐私保证」。这是明确产品决策，写入而非轻描淡写。

### 9.7 契约同步清单（补全，遵守 CLAUDE.md 文档纪律）
改 Anselm 同提交同步：
- `references/backend/error-codes.md`：新增网关错误码的 Anselm wire code（且标注绝不触发 `MarkInvalidByID`）。
- `references/backend/database.md`：受管 api_key 行/ install token 存储若落表/列 + ID 前缀（S15）。
- `references/backend/domains/apikey.md`：受管 key「不可编辑/不可删」规则（「不可编辑」需**新增** `Update` 守卫/`immutable` 标记，非既有能力）+ RefScanner 识别 + **受管行须植入合成 `TestResponse` 才能被 `capability.List` 产出**。
- `references/backend/domains/model.md`：内置免费档语义。
- `references/backend/events.md` + messages 协议：**仅当**走方案 B 实时配额时（v1 不涉及）。
- 前端 `references/frontend/contract.md`：相关 DTO。

---

## 10. 部署（香港，免备案）

### 10.0 域名与子域规划（`anselm.host`）

域名 `anselm.host` 是整个 Anselm 项目的根;**网关只占一个子域,与未来其它子服务物理隔离**(信任域隔离——网关持 DeepSeek key,绝不与公开面同域):

| 子域 | 用途 | 状态 |
|---|---|---|
| **`api.anselm.host`** | **免费档模型网关(本项目)** | 现在做(A 记录已指向服务器) |
| `anselm.host` / `www.` | 官网/落地页 | 留 |
| `docs.anselm.host` | 文档站 | 留 |
| `status.anselm.host` | 状态页 | 留 |
| `admin.anselm.host` | 运营后台 | 留 |

网关部署:`GATEWAY_DOMAIN=api.anselm.host`;DNS A 记录 `api → 43.154.241.65`(已配)。其余子域将来各自独立部署、各自 HTTPS,互不影响本网关。

### 10.1 选型
- **香港轻量服务器**，1C2G。**🔴 选「固定带宽」套餐而非「按量流量包」**（评审 high）——LLM 流式代理 egress 可观，按量超出无封顶会产生未封顶账单；固定带宽天然封顶（限速不收费）。
- **🔴 选带 CN2 GIA / 三网优化回程的线路**（普通 BGP 香港机晚高峰回大陆很差）。
- 两条路权衡（评审）：**大陆系云**（腾讯/阿里香港，便宜、回大陆线路好，但需**实名 + 受 AUP**，「代理境内 API」类用途注意条款）vs **国际厂商**（Vultr/Linode 香港，合规更干净，但回大陆普通 BGP 晚高峰差）。
- 免备案；海外注册商域名（免大陆备案）。

### 10.2 运行形态
- 单文件 Go 二进制（纯 Go、无 CGO、`import _ "time/tzdata"`）。
- **Caddy** 自动 HTTPS（ACME）/ 或 Go `autocert`；TLS 钉 1.2+。
- `systemd` 开机自启 + 崩溃重启。SQLite 落本地盘。

### 10.3 配置（环境变量）
| 变量 | 说明 |
|---|---|
| `DEEPSEEK_API_KEY`（支持多 key 备用） | **唯一机密** |
| `DEEPSEEK_BASE_URL` | 默认 `https://api.deepseek.com` |
| `MODEL_ALLOWLIST` | 真实 model id（client 的 model 映射到此） |
| `MONTHLY_QUOTA` | 默认 5000（可随规模动态下调，§15） |
| `GLOBAL_DAILY_BUDGET_TOKENS` | **每日**全局预算（=月预算/30） |
| `INSTALL_DAILY_TOKEN_CAP` | 单 install 每日 token 子配额 |
| `MAX_TOKENS_CAP` / `INPUT_TOKEN_CAP` | 输出/输入 token 上限 |
| `N_GLOBAL_CONCURRENCY` | 全局在飞并发（≤ DeepSeek 账号级上限） |
| `RATE_PER_MIN` / `DAILY_SUBLIMIT` | 速率/日次数子限额 |
| `INSTALL_PER_IP_HOUR` | `/install` 单 IP 频控（持久化） |
| `RESET_TZ` | 默认 `Asia/Shanghai` |
| `LISTEN_ADDR` | 监听地址 |

### 10.4 部署步骤
1. 开香港轻量服务器（固定带宽 + CN2 线路），**开放 80 和 443**（🔴 评审：ACME HTTP-01 强制走 80，只开 443 会签证失败；或改 DNS-01 challenge 则可只开 443 但需配 DNS 凭据）。
2. 域名 A 记录指向公网 IP。
3. 上传二进制 + Caddyfile + systemd unit；填环境变量。
4. `systemctl enable --now anselm-gateway`，`curl https://域名/healthz` 验证。
5. 网关 URL 配进 Anselm 客户端构建。

---

## 11. 可观测性与运维

- **日志**（结构化，**不含 prompt 正文，不含 Authorization**）：`install_id`、端点、状态码、上游耗时、token 数、错误类别。
- **指标**：QPS、配额/预算耗尽率、`tokens_used` vs 日预算、**egress 流量 vs 带宽包**、上游错误率/429 率、p95、在飞并发。
- **告警**：当日预算 80%/100%；**流量包/带宽 80%**；上游错误/429 突增；磁盘将满；`ledger.settled IS NULL` 堆积（崩溃漏结算）。
- **key 轮换/切备用**：改环境变量重启，客户端无感。
- **备份**：litestream 持续复制（读 WAL、不抢写锁）。注意：**token 已哈希存储**，备份泄漏不暴露可用 token。
- **可用性**：单机无冗余 → 备「快速重建脚本 + 配置即代码」；DeepSeek 账号被封 → 切备用 key/provider。

---

## 12. 成本模型

- **固定**：香港固定带宽服务器（月租）+ 域名。
- **变量（两条，都要封顶）**：
  1. **DeepSeek token 费** = 实际 token × 单价 → 由 `GLOBAL_DAILY_BUDGET_TOKENS` 封顶。
  2. **🔴 服务器 egress 流量费**（评审：与 token 费同级、初稿漏掉）= 请求数 × 平均响应字节 × 单价 → **由「固定带宽」套餐天然封顶**（§10.1）。
- ⚠️ **必须先核实 DeepSeek 真实 model id + 单价**（§16 blocker），再据「作者每月愿承受的钱」反推 `GLOBAL_DAILY_BUDGET_TOKENS`。

---

## 13. 测试与质量保障（兑现 bug-free）

| 层 | 用例 |
|---|---|
| **单元** | 预占/回补守恒；估算口径（保守高估）；原子条件更新 `RowsAffected==0`；period 入口快照复用；tz fail-fast；请求体白名单 + `n>1` 拒绝；token 哈希校验；封禁 403 |
| **并发/竞态** | N goroutine 打同一 install：总扣次 == min(N, quota)，**绝不超卖**；预算预占在并发尖峰下不超 `N_global×(INPUT+MAX)`（`-race`） |
| **崩溃一致性** | 「已预占、上游产出中」杀进程 → 重启后预算**不少计**（偏多扣）；`ledger` 对账 |
| **集成** | OpenAI 兼容契约；流式透传 + `[DONE]`；`stream_options.include_usage` 取 usage；各错误码映射；响应头白名单（上游头被剥离） |
| **安全** | 伪造 token 401；`/install` 不回显他人 token（构造碰撞 fp 也拿不到）；超 input cap 400；key 不出现在任何日志/错误体；502 不透传上游体 |
| **混沌** | DeepSeek 超时/断流/5xx/429 → 回滚或归一化正确；上游 429 不误回滚、不变 502 |
| **端到端** | Anselm 真连：首启 install → 发消息 → `GET /quota` 更新 UI → 触顶降级提示 → 配额/预算耗尽**不**使内置模型从选择器消失 |
| **负载/DoS** | `MaxBytesReader` 拒超大 body；Slowloris 超时；在飞连接上限；OOM 不发生 |

> **M0 验收门禁**：`go test -race` 全绿 + 真香港实例端到端通 + **一次「故意刷爆当日预算」演练验证封顶 + 次日恢复**。

---

## 14. 失败模式与边界（FMEA）

| 失败 | 影响 | 缓解 |
|---|---|---|
| DeepSeek 超时/断流 | 请求失败 | 产出前→回滚+502/504；产出后断流→保留计次、按 est 全额计费 |
| 上游账号并发满（429） | 误降级 | 单独 `UPSTREAM_BUSY`、排队/重试、不回滚不变 502；`N_global` 限流（§7.6） |
| 配额并发竞态 | 超卖 | `BEGIN IMMEDIATE` + 原子条件更新（§7.3） |
| 崩溃于「产出中」 | 预算少计 | 预占已落库→只多扣（保守）；`ledger` 对账 |
| 预算高并发超顶 | 超支 | 预占 + `N_global` → 有界 `N_global×(INPUT+MAX)` |
| 回滚瞬时「有额度却被拒」 | 偶发不公平 | 登记此边界；客户端可自动重试一次（不声称绝对公平） |
| 跨月/跨日零点并发 | period 错乱 | period 入口快照、全程复用 |
| tz db 缺失 | 边界偏 8h | `import _ "time/tzdata"` + fail-fast |
| token/DB 泄漏 | 盗号 | 哈希存储 + 可吊销 + 每日预算限损 |
| 重装刷额度 | Sybil | 不去重、每次新池；每日预算兜底 |
| 单机/账号故障 | 免费档全挂 | 快速重建 + 多 key/备用 provider 热切 |
| egress 超量 | 流量账单 | 固定带宽套餐天然封顶 |

---

## 15. 路线 / 里程碑 + 规模退场策略

- **M0 MVP**：`/install`（不回显 token）+ `/v1/chat/completions`（白名单 + 预占 + 流式透传 + 上游 usage）+ 每日全局预算封顶 + `GET /quota` + key 隔离 + DoS 加固。香港部署 + §13 门禁通过。
- **M1 加固**：上游并发治理、封禁、`ledger` 对账、混沌注入、备份、告警、多 key 热切。
- **M2 客户端**：受管 api_key 行 + 复用 deepseek/custom provider + `GET /quota` UI + 错误码映射（不触发 MarkInvalidByID）+ 隐私 modal + 自有 key 首选引导。
- **M3 演进（可选）**：GitHub 登录、实时配额（方案 B）、动态降配额。

**🔴 规模退场策略（评审 high，写入而非补丁）**：成本随机器数线性涨、预算固定 → 越成功越稀释。机制：
1. 监控「活跃 install × 人均额度」，逼近预算时**自动按比例下调 `MONTHLY_QUOTA`**（如 5000→1000），让更多人享少量，而非少数人吃满、其余全 402。
2. 规模超阈值时，免费档从「默认体验」转「试用引子」，主动引导自有 key。
3. 自有 key 为首选叙事，免费档不承担全量负载。

---

## 16. 开放问题（分两组）

### 🔴 上线前 blocker（必须先定死，否则埋雷）
1. **DeepSeek 真实 model id + 单价**——「DeepSeek V4 Flash」此确切 SKU 待核实（公开为 V3/V3.2/R1 系列）。决定 `MODEL_ALLOWLIST` + 成本/预算换算的全部地基。
2. **DeepSeek 账号级并发上限**——决定 `N_GLOBAL_CONCURRENCY`（账号级、非 key 级，多 key 不放大）。
3. **`GLOBAL_DAILY_BUDGET_TOKENS` 数值**——唯一钱包护栏，据 #1 单价 + 作者愿承受月额反推。
4. **隐私/ToS 决策**——免费档默认关闭 + 显式同意文案；作者个人账号承接全球用户内容的法律边界。
5. **月度重置时区**确认（本蓝图定 `Asia/Shanghai`）。
6. **`estimatePromptTokens` 估算器校准**——按选定 DeepSeek model 的 tokenizer 校准并保证**保守 ≥ 真实**（预占/护栏地基，§5.2/§7.3）。
7. **容量规划**——`N_GLOBAL_CONCURRENCY × 单流峰值带宽 ≤ 服务器固定带宽`（§7.6/§10.1），据此联合定套餐带宽与 `N_global`。

### 可演进（不阻塞 v1）
6. GitHub 登录（v1 可选）。
7. 实时配额方案 B。
8. 封禁阈值/申诉/误封恢复流程。

---

## 17. 变更记录（可追溯，体现成熟）

- **v3（2026-06-19，据收敛验证再加固）**：§3.2 步骤 6 补「产出前失败回滚含**全局日预算**」（原漏，会虚占当日预算）；写死 `estimatePromptTokens` **保守 ≥ 真实**契约（护栏地基，列 §16 blocker #6）；ledger **升必选** + 启动/周期**孤儿预占扫描器**（原「对账」措辞无回路）；§9.2 补**受管行落地链**（必须植入合成 `TestResponse` 才能被 `capability.List` 产出）+「不可编辑」需新增 `Update` 守卫；§9.5 **校准**（现状=错误压平 + 402 盲重试；`MarkInvalidByID` 是前瞻规则非现状）+ 给拦截点落位；§7.4 写明**全局日预算 vs install 子配额求和关系**、退场旋钮改 `INSTALL_DAILY_TOKEN_CAP` 动态收敛；§7.6/§10.1 加 `N_global × 单流带宽 ≤ 固定带宽` **容量校验**（§16 #7）；流式改 `ResponseController` 滚动写期限；IP 频控 IPv6 /64 聚合标注；`GET /quota` 的 `used` 标注含在飞预占。
- **v2（2026-06-19，据 5 视角对抗评审加固）**：预算「事后累加」→**悲观预占 + 每日全局配额**；新增 install 级每日 token 子配额 + 全局并发上限 + 上游账号级并发治理；`/install` **不再幂等回显 token**（消除无鉴权凭证窃取）；token **哈希存储**；请求体**严格白名单** + 输入侧护栏；服务端 **key 泄漏三重防护** + 响应头白名单 + CORS/TLS；**DoS 加固**（body 上限/超时/连接数）；**tz db 内嵌 + period 入口快照**；DB **读写连接池分离 + 写不跨流式全程**；客户端配额改走 **`GET /quota`**（响应头主路径在现架构不成立）；内置档落地为**受管 api_key 行**（复用 deepseek/custom provider，不新增名）；配额耗尽**绝不触发 MarkInvalidByID**；部署补 **egress 成本/固定带宽/CN2 线路/ACME 80 端口/Cloudflare 排除理由纠正**；产品补**规模退场策略 + 隐私默认关闭 + §16 blocker 分组**。**移除官网/下载/分析/运营面**（聚焦网关 API）。
- v1（2026-06-19，初稿）：见 git 历史。

---

## 18. 与 Anselm 主仓库的边界

| 内容 | 归属 |
|---|---|
| 网关服务（§3–§8、§10–§17） | **独立仓库 `anselm-gateway`**（本蓝图随之搬出） |
| 客户端集成（§9） | **Anselm 主仓库**，遵守其文档纪律 |
| 本蓝图 | 暂存 Anselm `docs/working/`；搬出后此处置 `archive/` 或填 `landed-into` 指向网关仓库 README |
