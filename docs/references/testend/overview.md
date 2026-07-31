---
id: DOC-038
type: reference
status: active
owner: @weilin
created: 2026-06-12
reviewed: 2026-08-01
review-due: 2026-10-30
audience: [human, ai]
---

# testend 黑盒验收

`testend/` 是与 `backend/` 平级的独立 Go module。它编译并拉起真实
`cmd/server`，只通过 HTTP、SSE 与进程边界观察系统；禁止 import backend
内部包。包内测试回答“局部实现是否正确”，testend 回答“产品线缆与持久状态是否
真的走得通”。

## 入口

| 命令 | 范围 | 外部成本 |
|---|---|---|
| `make -C backend testend` | `testend/scenarios/`；真实 sidecar + llmmock / 本地假上游 | 无模型费用 |
| `make -C backend evals` | `testend/golden/`；默认经已部署 Anselm API 走 managed 金标 | 消耗受管额度 |
| `make -C backend qwen-evals` | 显式 Qwen 多模态与工具金标 | 消耗调用者 BYOK 额度 |

`make verify` 不包含 testend 或 evals。前者按契约改动显式运行，后两者必须由
调用者有意识地开启，不能作为普通门禁的隐式副作用。

## 场景类型

- **Contract / local**：真实 sidecar 搭配 llmmock、假 HTTP provider 或本地工具，
  验证 envelope、状态机、持久化、恢复、并发、失败语义与上游 wire。
- **Managed**：显式 `EVALS_MANAGED=1`，只经 device proof 调已部署 Anselm API；
  验受管开通、能力、quota、生成/读取与真实多模态链。
- **BYOK**：显式 `EVALS_BYOK=1` 并提供对应 provider key；必须走产品的 key
  创建、probe、能力投影和模型选择，managed fallback 不得代跑。
- **Hybrid**：同时显式开启 managed 与 BYOK；验证 BYOK planner 消费 managed
  capability 产物的接缝。

模型文案只能证明回合完成，不能证明 provider 实际收到某种媒体或参数。需要验证
wire 时使用透明 recorder、exact-byte 断言或 provider usage；无法观察的边界必须
在结果中诚实注明。

## Harness

| 组件 | 责任 |
|---|---|
| `harness/server.go` | 编译、拉起、健康等待、重启与隔离 data dir |
| `harness/client.go` | N1 envelope、workspace header、分页与最终一致性断言 |
| `harness/llmmock.go` | 剧本化 LLM、请求抓取及本地图像/语音假上游 |
| `harness/sse.go` | 三条 SSE 的订阅、续传与事件断言 |
| `harness/scratch.go`、`proc_*.go` | 临时根、进程组、信号处理、残留轮次回收 |

每个场景拥有独立端口、数据目录和进程组。正常结束先向 sidecar 发 `SIGTERM`，
再以进程组级 `SIGKILL` 兜底，并断言组内没有幸存者。故意 `Kill9` 的场景保留
硬崩溃语义；测试二进制被超时或强杀时，由下一轮按已死亡 pid 的 scratch 所有权
回收残留，不能按裸进程名扫描系统。

Sandbox 运行时缓存只保存可派生 runtime，不保存 pidfile 或业务状态。Darwin
优先使用 copy-on-write clone 预置，其他环境回落复制并显式记录；隔离语义不能
因缓存优化改变。

## 全产品验收台架

`testend/rig/` 是 WRK-087 的专机台架，不是普通自动化测试。`rig-up.sh` 亲自编译并托管真实
Flutter App、sidecar、屏幕录像、动态全 workspace SSE witness 与受管网关 wire witness；
`rig-check.sh` 持续证明五通道归属和接线；`rig-down.sh` 按顺序排空进程并封口 MOV。完整操作只认
[`testend/rig/README.md`](../../../testend/rig/README.md)，不能用手起 App、外来 sidecar 或缺失
任一 journal 的会话代替。

台架观察者仍遵守 testend 的黑盒边界：`cmd/ssetap` 只打 HTTP/SSE，`cmd/llmtap` 只代理上游线缆，
`cmd/measure` 只读截图/帧。受管录制代理通过 `ANSELM_PROOF_HOST` 继续把 device proof 绑定真实
受众；它只允许本机透明途经，不改变证明能在哪里消费。

## 多模态素材

固定素材合同见 [`testend/fixtures/README.md`](../../../testend/fixtures/README.md)。
仓库保存 manifest、生成器、语义断言与 SHA-256，不提交大二进制。真实媒体场景
可以通过 `EVALS_FIXTURE_DIR` 复用已经物化且 hash 匹配的目录。

## 纪律

1. 修改端点、error code、SSE 或持久状态时，按域前缀搜索并同步相关场景。
2. 默认场景不得依赖公网、真实 key 或随机模型行为。
3. 真实 eval 记录 provider、模型、开关、运行范围与可复验的物理证据。
4. key、device-proof 私钥、prompt 原文和 bearer 不得进入日志、fixture 或提交。
5. 进程组为空、临时目录可回收、无孤儿 durable 行，都是通过条件的一部分。
