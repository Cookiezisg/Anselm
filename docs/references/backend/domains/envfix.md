---
id: DOC-304
type: reference
status: active
owner: @weilin
created: 2026-06-06
reviewed: 2026-06-06
review-due: 2026-09-01
audience: [human, ai]
---
# envfix — sandbox env 物化 + LLM 自愈构建（共享）

> **核心地位**：把一组 `(runtime, deps)` 物化成一个 ready 的 sandbox env；装失败时让 **utility 小模型**看 stderr 改依赖列表并重试——一个自愈构建循环，被所有持有 sandbox env 的实体共用（**function · handler · 未来的轮询触发源**）。

---

## 1. 为什么独立成包

function（M3.1）、handler（M3.2）、轮询触发源都要「装 venv，装不上让 AI 改依赖重试」。这是 3 个真实消费者——抽 `app/envfix` 共享，不在各实体里重抄（复用优先、不造轮子）。

它跨 sandbox（装）+ model/apikey/llm（改），是典型 **app 层编排**，故落 `app/envfix`（非 pkg——pkg 不依赖业务 app/infra）。

---

## 2. 物理布局

```
backend/internal/app/envfix/envfix.go  # Provisioner + Request/Result/Attempt/Sink + Provision 循环
backend/internal/app/envfix/fix.go     # suggestDeps（LLM 改依赖）+ prompt + 解析
```

依赖全以接口/工厂注入：`SandboxPort`(EnsureEnv，DIP——sandboxapp.Service 结构化满足) · `model.ModelPicker` · `apikey.KeyProvider` · `llm.Factory`。

---

## 3. Provision 循环

```
① EnsureEnv(deps) 装一次 → Sink.OnAttempt
② ready → 返回 {OK, FinalDeps=deps}
③ failed + 还有名额 → Sink.OnFixing → utility LLM 看 stderr+当前 deps 给修正 deps
   （链：model.Resolve(utility) → ResolveCredentialsByID → factory.Build → llm.Generate + jsonrepair）
④ 用新 deps 再装 → 循环，至 MaxAttempts（默认 3）
⑤ 终态返回 Result{OK, FinalDeps, AttemptsUsed, History}
```

- **从不返 Go error**：基础设施失败 / 未配 utility 模型只是以 `OK=false` + 最后 stderr 结束循环；调用方上呈给锻造 LLM 自行改代码。
- **FinalDeps 回写**：成功的（可能被 LLM 修正过的）deps 由调用方写回版本行——比「每次重试产生新版本」干净。
- **stream-agnostic**：进度经调用方提供的 `Sink`(OnAttempt/OnFixing) 暴露；本包**绝不 import stream/eventlog**。tool 层实现 Sink 把尝试推到 SSE 流（live 推流 M5.2 接缝）；HTTP 调用方传 nil 静默跑。

---

## 4. prompt 约束

utility 模型被约束为：**只改依赖列表**（typo / 版本冲突 / 缺约束）、**绝不碰代码**、返 JSON only `{"deps":[...]}`。无法判断时返原 deps 不变。

---

## 5. 现状与跨域接线

| 接线 | 当下 | 实接 |
|---|---|---|
| function 消费 | ✅ M3.1（Service.ensureEnv 调 Provision，create/edit/run 共用） | — |
| handler 消费 | 机制就位 | M3.2 |
| 轮询触发源消费 | 机制就位 | 那一轮 |
| Sink live 推流（每尝试推 messages 流） | tool 用累积 Sink 折进结果 | chat host M5.2（tool-progress 流缝） |
| boot 注入（sandboxapp.Service + picker + keys + factory） | — | M7 |

---

## 6. 测试矩阵（全离线）

fake `SandboxPort`（脚本化失败/成功）+ mock LLM（provider=mock 短路）：一次成功 / 修复成功（FinalDeps 回写值）/ 3 次耗尽 / 无 utility 模型降级 / Sink 回调时序 / nil Sink 容忍。

---

## 7. 决策快照

- **抽共享包而非各实体重抄**：3 真实消费者（function/handler/trigger），rule-of-three 已满足。
- **app 层非 pkg**：跨 sandbox+model+llm 编排，pkg 不依赖业务。
- **Sink 而非内嵌推流**：包保持纯粹、可测；谁调谁推（推流逻辑留 tool 层）。
- **FinalDeps 回写、版本号不变**：env-fix 修正的是「能装上的实际 deps」，属于「让这个版本真正可用」的收尾，不算篡改历史。
- **链对齐新地基**：删 `Thinking`/`llmclient`/`llmparse` 残留，旋钮走 `ModelRef.Options`，JSON 兜底用 `jsonrepair`。
