# Forgify · Design Lab

交互形态 + 产品哲学的**发散场**。这里的 demo **不连后端**——只用来把「Forgify 做成什么样」
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
| `demos/main-shell.html` | **主屏**：海与岛布局 · 四导航切换动效 · 聊天 · **信号交互**（AI 调工具时实体卡从右流式展开）。进页自动播放一段时间线，点 ▷ 重播，可切明暗 / 切导航 / 收起右岛。 |
| `demos/onboarding.html` | **首启向导**：外观（亮/暗/跟随系统，选了即时生效）+ 语言 → 大模型 / 联网搜索 API Key。 |

## 结构

```
design-lab/
  index.html          # demo 索引页
  PHILOSOPHY.md       # 产品哲学（形态事实源）
  shared/
    tokens.css        # 设计 token（颜色 明暗 / 圆角 / 间距 / 字体 / 动效）
    base.css          # 组件库（海与岛布局 · 聊天 · 实体卡 · 导航）
    mock-data.js      # 图标集 + 演示静态数据（绝不连后端）
  demos/
    main-shell.html   # 主屏 hero
    onboarding.html   # 首启向导
```

## 边界

- **不连后端、不进 `make docs` 门禁、不进 Flutter 工程**——纯草图。
- 改 token / 组件 = 改 `shared/`，全 demo 受益（视觉一致的锚点）。
- 这里聊定的形态，是 `frontend/` 落地的依据；不是产品代码本身。
