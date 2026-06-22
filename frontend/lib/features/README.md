# features/ — the middle tier (3-tier feature-first, ADR 0004)

Each ocean / domain is one folder here. Features compose the UI kit (`core/ui`) and design
tokens (`core/design`) into a real screen, wire it to the backend contract (`core/contract`
+ `core/net`) and live streams (`core/sse`), and expose Riverpod providers for their state.

每个海洋/域一个文件夹。feature 用 `core/ui` 组件 + `core/design` token 搭出真界面,接后端契约
(`core/contract` + `core/net`)与实时流(`core/sse`),并用 Riverpod provider 暴露其状态。

## Per-feature layout 每片结构

```
features/<域>/
  data/      # repositories: typed calls over core/net (the only place that touches dio)
  state/     # Riverpod notifiers (AsyncNotifier paging + keepAlive stream subscriptions)
  ui/        # pages + widgets, composed ONLY from core/ui (never bespoke colors/metrics)
  model/     # OPTIONAL framework-free pure models that carry correctness
             #   (e.g. chat/model/block_tree_reducer.dart, workflow/model/graph_model.dart)
             #   — these must be unit-tested off-widget/off-socket.
```

## Rules 铁律

1. **Features never import each other.** Cross-feature coordination goes through a `core`
   provider or a navigation intent (go_router). 互不依赖;跨片走 core provider / 导航 intent。
2. **UI composes the kit only.** No raw `Color`/`px`/`TextStyle` — everything from
   `core/ui` + `core/design`. 只用套件 + token,禁内联。
3. **DB row is truth, stream is only for realtime** (ADR 0004): `seq>0` durable frames
   advance caches/cursors; ephemeral (delta/tick) only touch transient view state.
4. **Contract = backend projection.** DTOs live in `core/contract`, mirroring
   `docs/references/backend/*` field-for-field; change a backend field → change the DTO in
   the same commit (doc discipline extends to the Dart contract).
5. **Each feature ships a doc** in `docs/references/frontend/slices/<域>.md` and a journey
   test that proves data→state→ui end-to-end against the llmmock backend.

First feature: **entities** (the most regular — validates CRUD + entities SSE stream + the
three-island shell + the kit). 首个:entities。
