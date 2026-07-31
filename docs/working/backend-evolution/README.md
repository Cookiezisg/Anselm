---
id: WRK-026
type: working
status: active
owner: @weilin
created: 2026-06-18
reviewed: 2026-07-31
review-due: 2026-08-14
audience: [human, ai]
landed-into:
---

# Backend Evolution

Backend Evolution 是后端长期自我校正循环。它用真实用户路径发现静态测试看不见的
断裂，再把稳定结论沉淀为代码、回归测试和 current reference。

## 文件职责

| 文件 | 只承担 |
|---|---|
| [`CURRENT.md`](CURRENT.md) | 当前产品边界、优先面与运行准入 |
| [`FRONTIER.md`](FRONTIER.md) | 尚未闭合的下一批路径与 reprobe 触发器 |
| [`LOG.md`](LOG.md) | 只追加的已确认 finding、证据、守卫与提交 |
| [`HISTORY.md`](HISTORY.md) | 已收口战役和历史材料的短索引 |

完成证据不能堆回 FRONTIER，当前契约不能埋进 LOG，历史快照不能冒充现状。

## 循环

```text
REVIEW
→ EXPLORE
→ CONFIRM
→ GENERALIZE
→ FIX
→ VERIFY
→ LOG
→ COMMIT
→ REVIEW
```

1. **Review**：确认当前源、workspace、路由类别、上游条件和费用边界。
2. **Explore**：选择高频且证据缺口大的路径，观察真实 API、持久状态和媒体字节。
3. **Confirm**：换样本或同类实现复现，区分模型波动、外部窗口与确定性缺陷。
4. **Generalize**：定位共享咽喉和全部同类调用方。
5. **Fix**：做最小完整修复，不靠隐藏错误、删能力或放宽断言换绿。
6. **Verify**：重跑最小复现、受影响回归及必要的真实验收。
7. **Log/Commit**：确认后只向 LOG 追加证据，以一个原子提交落地。

## 证据规则

- 模型自然语言不是后端终态；以实体、Message Blocks、Execution、Flowrun、
  Attachment、Interaction、quota 或 wire recorder 裁决。
- Mock/单测证明确定性契约，不证明真实 provider、公开媒体 URL、费用和异步上游。
- 真实媒体必须同时验证引用、附件原件或派生字节、进入下游的 wire，以及调用次数。
- 费用型操作先确认 danger/approval 与最大调用数；不允许模型无界重调。
- 可以转成零 token 断言的结论进入普通回归；必须依赖真钱的结论留在显式
  `EVALS_*` acceptance。
- 失败或 skip 必须保留原始分类；上游 rate window 不能伪造成产品绿灯或产品缺陷。

## 产品边界

| 路径 | 职责 |
|---|---|
| managed-read/default | 默认对话、多模态输入、device proof 与受管能力投影 |
| byok-read | 用户选择的文本/图片/视频/音频/原生文档读取 |
| managed-write | 图像、语音、视频、音色等生成与资源操作 |
| hybrid | BYOK 模型理解/调度，受管 Anselm 执行生成 |

默认与 managed acceptance 走已部署 Anselm API，不索取本地 provider secret。
BYOK acceptance 只在用户明确提供测试 key 时启用，并验证的是用户选择的直连读路径。
历史直连生成测试缝只在 [`HISTORY.md`](HISTORY.md) 登记，不是当前产品入口。

## 停止边界

本循环没有“全部测完”。一次运行可以因用户要求、费用预算、部署不可用或外部窗口暂停，
但暂停前必须：

- 收敛正在编辑的改动；
- 记录已确认事实和未确认边界；
- 运行与改动相称的门禁；
- 留下干净、可继续的工作树。
