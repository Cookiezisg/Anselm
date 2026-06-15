# Foryx · Design Lab

交互形态 + 产品哲学的**发散场**。这里的 demo **不连后端**——只用来把「Foryx 做成什么样」
聊清楚。形态定稿后，统一在 `frontend/`（Flutter）落地。

> 设计理念见 [`PHILOSOPHY.md`](PHILOSOPHY.md)。Flutter 架构见
> [`../docs/decisions/0004-frontend-flutter-architecture.md`](../docs/decisions/0004-frontend-flutter-architecture.md)。

## 怎么看

纯静态 HTML，起个本地服务即可（直接 `open` 也行，但走服务器最稳）：

```bash
# 从仓库根
python3 -m http.server 4180 --directory design-lab
# 浏览器开 http://127.0.0.1:4180/
```

或直接 `open design-lab/index.html`（`index.html` 是 demo 索引）。

## Demos

| Demo | 看点 |
|---|---|
| `oceans/chat/chat.html` | **Chat 海洋（视觉参考 Claude Code 桌面端）**：外壳 + 侧栏 + Chat 海洋装在一起——圆角浮窗 · 海与岛同色靠海岸线分 · Notion 式三切换 · 工具调用块 · **信号交互**（AI 调工具时右岛实体卡从右滑入、流式编辑）。进页自动播放，点 ▷ 重播，可切明暗、收起/关闭右岛。 |
| `reference.html` | **设计参考**：精修形态沉淀——核心原则 + 配色 token + 实体卡两态（编辑中/已保存）+ 核心组件。供后面真实设计 / Flutter 落地直接参考。 |
| `onboarding/onboarding.html` | **首启向导**：外观（亮/暗/跟随系统，选了即时生效）+ 语言 → 大模型 / 联网搜索 API Key。 |

## 结构（模块化：多 AI 可并发打磨，见 [`CONTRIBUTING.md`](CONTRIBUTING.md)）

```
design-lab/
  index.html             # demo 索引
  PHILOSOPHY.md          # 产品哲学（形态事实源）
  CONTRIBUTING.md        # 并发协作约定（主人地图 + 共享契约）
  shared/                # 🔒 内核（只读消费）
    tokens.css           #   设计 token（颜色 明暗 / 圆角 / 间距 / 字体 / --ease-spring）
    shell.css            #   窗口框架 + 全站通用原语
    icons.js             #   图标集（APPEND-ONLY）
    shell.js             #   外壳：搭框、开三槽(#left/#sea/.body)、海洋挂载 API
    base.css·mock-data.js#   旧组件库 + 演示数据（onboarding/index 用，待各自收编）
  sidebar/               # 🧩 左侧栏模块（自挂载进 #left）
  onboarding/            # 🧩 Onboarding 模块（独立整页）
  oceans/                # 🌊 每个海洋一个文件夹（含很多设计块）
    chat/                #   Chat 海洋：chat.html · chat.css · chat.js · entity-card.js(右岛)
  reference.html         # 设计参考页
```

## 边界

- **不连后端、不进 `make docs` 门禁、不进 Flutter 工程**——纯草图。
- **一文件一主人 + 共享内核只读 + 海洋自包含**——多 AI 各 fork 一个模块、改不同文件、`main` 不冲突。规则见 [`CONTRIBUTING.md`](CONTRIBUTING.md)。
- 改 token / 框架 / 图标 = 改 `shared/`（内核负责人），全站受益。
- 这里聊定的形态，是 `frontend/` 落地的依据；不是产品代码本身。
