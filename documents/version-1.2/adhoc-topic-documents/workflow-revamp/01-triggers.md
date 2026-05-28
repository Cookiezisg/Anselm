# 01 — Triggers

脑爆结论笔记(2026-05-27)。

---

## 触发器全集 — 5 种

| Kind | 信号源 | push/pull |
|---|---|---|
| `cron` | 时钟 | push |
| `fsnotify` | 本地文件系统 | push |
| `webhook` | 外部 HTTP | push |
| `polling` | 用户写的判断逻辑 | **pull** |
| `manual` | 用户 / AI 显式调用 | push |

push / pull 维度穷举,无第 6 种。

---

## polling = 受约束的 function

polling trigger **本质是一个特殊签名的 function**,从既有 `forge` 系统流出。复用 forge 全套(版本 / pending / sandbox / iterate / 测试),不另造平行系统。

约束差:

| 维度 | 普通 function | polling function |
|---|---|---|
| 签名 | 用户自定义 | 固定:`def poll(lastCursor) -> {"events": [...], "nextCursor": ...}` |
| 执行 | workflow 节点按需调 | 系统按 interval 反复跑 |
| 错误 | 冒泡到节点 | 冒泡到 trigger 系统(系统决定重试 / 暂停 / 通知) |
| 资源 | 无约束 | 单次必须快(< 10s) |
| 副作用 | 无约束 | 应只读;有副作用要警示 |
| 状态 | 无状态 | cursor 由系统持久化 |
| 输出 | 返一个值 | 返事件列表,N 个 → N 个 flowrun |

输出必须是 **event-list + cursor**,不是 1/0 boolean——一次 polling 可能多事件、payload 跟触发耦合、cursor 必需。

---

## 对外契约统一

5 种内部实现不同,对外**都 emit event(s)** → 触发对应数量的 flowrun → event 喂给 trigger 节点 `out` 端口。

| Kind | 一次几个 event | event payload |
|---|---|---|
| cron | 1 | `{firedAt}` |
| fsnotify | 1 / 事件 | `{firedAt, path, eventKind}` |
| webhook | 1 / 请求 | `{firedAt, method, headers, body}` |
| polling | 0~N | function 自定义 |
| manual | 1 | 用户传 |

下游 workflow 不需要知道 trigger kind,只面对统一的 event。

---

## 差异化锚点

Forgify vs Zapier/n8n 的差别:**polling function 由 AI(forge)帮造**,而非平台预集成 / 用户手写。
