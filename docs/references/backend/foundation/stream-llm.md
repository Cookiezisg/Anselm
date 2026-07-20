---
id: DOC-032
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-21
review-due: 2026-10-19
audience: [human, ai]
---

# stream + llm —— SSE 总线与 LLM 端口

## stream（domain 协议 + infra Bus）

**domain/stream 是传输协议**（与 messages 的内容模型刻意分离）：`Frame` 四型 open/delta/close/signal；`Scope{Kind, ID}` 实体锚定；**durable/ephemeral 双轨**（E2）——durable 帧（open/close/非 ephemeral signal）分 seq 入 replay 环，ephemeral 帧（delta/tick）seq=0 实时扇出、不入环、订阅者满则丢（token 级 delta 永不撑爆窗口/卡生产者）。close 带快照供 replay。

**infra/stream 是进程内 Bus**：一个类型实例化三次（messages/entities/notifications，E1）；per-workspace seq + replay 环；重连从续传游标重放（`Last-Event-ID` 头优先、否则 `?fromSeq` 查询参，缺/坏 → 0 仅实时），环已淘汰 → `SEQ_TOO_OLD`（410 Gone，前端全量重拉）。v1 按 workspace 全量推、前端自滤（E1 约定）。

## llm（provider 端口）

`Client` 单方法 `Stream(ctx, Request) iter.Seq[StreamEvent]`——全部 provider（anthropic/openai/google/deepseek/qwen/zhipu/moonshot/doubao/openrouter/ollama/custom/anselm）适配到同一事件流（text/reasoning delta、tool start/delta、finish 带 token 计数）。要点：
- **sanitizer**：发送前守 `assistant.tool_calls ↔ tool` 配对——孤儿 tool_call 合成 stub 回复（LLM 看见被打断、严格 provider 不 400）。被取消的回合重续就靠它。
- **deepseek 全文本 parts 坍缩**：user 回合的 `Parts` 中无 image/video/audio 存活时（如附件被模型能力或媒体额度降级成文本占位）以 `\n\n` join **坍缩回字符串 `content`**——纯文本端点拒收数组形 `content`，且冻结附件逐回合重放，数组形会让该对话每一回合永远 400。任一原生媒体仍走 OpenAI-compatible 数组多模态形。
- **factory**：按 provider+key 构造 Client，返回 `(Client, 解析后 baseURL, error)`；`DescribeModels` 各 provider 自描述模型目录（model 域消费）。
- **anselm（内置免费档）**：`anselm.go` embed `deepseekProvider` 复用 OpenAI-compatible streaming/tools/reasoning wire，仅覆盖 `Name`/`DefaultBaseURL`（`AnselmBaseURL` = `https://api.anselm.website/v1`）/`DescribeModels`。公开模型仅 `anselm-auto`：保守 `256K/32K` 上下文外壳、原生图片+MP4 视频、每回合最多 8 个/3MiB 解码媒体、当前 audio=false、无 knobs（网关拥有 reasoning，不给死 UI）。`install.go` 的 `InstallClient` 领 `gwk_` token（`POST {base}/install`，发哈希后机器指纹、绝不发裸序列号）。网关 402 / 流内 `BUDGET_EXHAUSTED` → `ErrQuotaExhausted`（自有 Code、非重试、绝不标 token 失效）。零配置受管接入（provisioning + 默认 wiring）由 apikey/model 域承载。
- **mock**：`fake_llm` 脚本队列（T6——默认测试 0 token）。
- 码 `LLM_*` 6 + `MOCK_QUEUE_EMPTY` → [error-codes.md](../error-codes.md)。

**`app/modelclient` 是唯一的 model→client 解析链**：`Resolve(ctx, scenario, override, picker, keys, factory) → (Client, 预填 Request{ModelID/Key/BaseURL/Options}, provider)`。chat loop 之外的全部 LLM 消费方走它——bootstrap 四 resolver 核、search 精度链 sifter、envfix 依赖自愈、WebFetch 摘要器。**禁止手抄该链**：factory 第二返回值是解析后的 baseURL，若误接进 `Request.ModelID`，线缆 model 字段就变成 base url、静默杀死该 LLM 功能——故所有非 chat-loop 消费方一律走此函数，不各自拼解析。
