# tooltuner — PRD

> 状态:草案 v0.2(开放式实验引擎版)。产品需求,不含技术架构(那是后续 spec)。
> 位置 `research/tooltuner/`。复用现有 `research/llm-experiments/` 的零件,**该目录完工后退役删除**(本工具取代它)。
> 操作者 = **Claude Code agent**(不是人敲 CLI)。

---

## 0. 一句话

**tooltuner 是一个持续、开放式的「tool-call 质量」优化引擎。** 由 Claude Code agent 操作:你有 token 就让 agent 调 skill 推几把,每一把 = 一次实验,只要 paired-lift 赢,就让一套工具集的**全部 LLM-facing 面**(工具描述 / schema / 系统 prompt / 教学守则 / 示例)更好一点——模型于是**选得更对、用得更对**。**没有终点,越转越好。**

---

## 1. 背景 & 学到的(直接决定本设计)

- R1-R4 已证明:**模型能力不是瓶颈,契约设计(描述 / schema / 指令)才是**;质量分两轴 —— **SELECTION(选对工具)+ USAGE(用对、结果正确)**。
- 但那是**一次性手动大工程**,且焊死在 Forgify 91 工具上。
- 两个关键教训:
  1. **分数不可靠**:绝对分 run-to-run 抖 ±15;低分常是**测量假象**(工具选择 35%→真相 91%、fp_poll 67% 其实对)。→ **不能贪心"修最低分",那是追噪声。**
  2. **优化无止境**:好工具可能更好,差工具可能本就没事。→ **没有"做完",只有持续。**

---

## 2. 谁用 & 怎么用

- **操作者 = Claude Code agent**:你的 session(`/loop` 可选用于无人值守一阵子;**不做调度 / 云端基础设施**)。
- 你的动作:想优化就**开 session 跟 agent 说一声**,推几把 → 走开。记忆持久,下次 / 换机器接着转。

---

## 3. 不是什么(纠正上一版的错)

- ❌ 不是人运行的 CLI / 框架 —— 是 **agent 当司机**,skill 指路不绑手。
- ❌ 不是"修最弱 → 收敛到做完"的燃尽 —— 是**开放式实验引擎**,无终点。
- ❌ **分数不是目标,paired-lift 才是** —— 95% 的工具 paired 赢一手,和 52%→64% 一样值。
- ❌ 不做 standalone / 开源 / GUI —— 全用 **Claude Code 原生积木**(Workflow / skill / memory 文件 / `/loop`)。

---

## 4. 四层(产品视角)

| 层 | 是什么 |
|---|---|
| **① 记忆** | git 里一个 target 文件夹:`surfaces`(**全部 LLM-facing 面**:工具描述 + schema + 系统 prompt + 教学守则 + 示例;改好即 port 回 Forgify 成品)+ `scores`(两轴历史)+ `backlog`(**活的研究日志**:假设 / 线索 / known-good)+ `changelog`(改动 before→after + lift + 留弃)+ `runs/`(raw trace,供"读 raw")+ `config` |
| **② 零件(确定性)** | `run_model`(批量 ReAct + 预算账本 + JSON 修复)、`score`(多数表决 / CI)、`ab`(paired-lift)、`gen`+`judge`(参数化 Workflow,要智能故为 Claude)。**= 现有代码泛化** |
| **③ skill `tooltuner`(皇冠)** | 把方法论灌进 agent:读 raw 验信号、只信 paired-lift、判官默认怀疑、改教学回归测副作用、G0-G10 已知坑、11 个测量假象、怎么用零件、何时停 |
| **④ 司机 = agent** | 每次自己挑实验、提改法、判够不够,靠 ①②③ 撑 |

---

## 5. 一次"推"长这样(开放版,不是修最低)

1. agent 调 skill → 读 `backlog` + `scores`
2. **挑一个实验**(从多信号,**不是排序取最低**):可疑低分(验真假)/ 有预感的高分(还能更好?)/ raw 里新冒的失败 / 把某个成功改法搬给兄弟工具 / 没试过的杠杆(few-shot…)/ 覆盖盲区
3. **第一步永远是读 raw 验信号**
4. 分叉:
   - 信号**真** → 提改法(改**任一面**:描述 / schema / 系统 prompt / 教学 / 加示例)→ `ab` paired-lift → **赢且不伤别处** → 写回对应 surface + 记 `changelog`
   - 信号**假**(其实没事)→ 标 **known-good** + 记原因 + 移出待办 ← **这也是一次成功的推**

> 改**全局面**(系统 prompt / 教学守则)会同时影响很多工具 → A/B 要**跨多工具回归**,不能只看动手那一个(可能帮了 A 伤了 B)。
5. 更新记忆 + 出报告。预算花完即停。

> 两种结果都算赢:① catalog 变好;② 学到"它没事"、不再空耗。贪心版只认 ①,会在 ② 上耗死。

---

## 6. 功能需求

- **F1** 持久 + 可重入(中断不丢,下次接着)
- **F2** 预算有界(花完即停;DeepSeek 402 即停)
- **F3** 两轴测量(gen → run_model → judge)
- **F4** **paired-lift 把关,只留有提升的,绝不退化**(改全局面 → 跨多工具回归)
- **F5** **开放式选题**(多信号挑实验,非"排序最低")
- **F6** **信号先验**(任何候选先读 raw,判出假象)
- **F7** **活的研究日志**(假设 / 试过 / known-good —— 自我延续 + 不重复踩坑)
- **F8** 配置即换靶(指向新工具集只写 config)
- **F9** 复用 Claude Code 原生积木

---

## 7. 成功标准

- 再入 = 一次 skill 调用,**零设置**
- 跨多轮,catalog 两轴 **paired 累积变好(不退化)**
- 单轮**便宜、有界、可中断**
- 能**无人值守**(`/loop`)持续转而**不跑偏**
- **假象能被识别归档**(不在没问题的工具上空耗)
- 产出 = 改好的 catalog,**可直接 port 回 Forgify 真实 `Description()` / `Parameters()`**

---

## 8. 范围 & 演进

- **第一个 target = Forgify 工具**(把现有 catalog 灌进去)。
- 复用 `research/llm-experiments/` 零件;**该目录退役删除**(本工具取代)。
- **做一次的清单**:记忆 schema + 3 Python 零件 + 2 Workflow + `tooltuner` skill。比"框架"代码少,耐用部分(skill + 记忆)正好留得住。

---

## 9. 已定(原开放问题)

- **优化对象 = 全部 LLM-facing 面**:工具描述 + schema + 系统 prompt + 教学守则 + 示例 + catalog 分组——凡是喂给模型、可调的文本契约都在内,**不只工具描述**。
- **持续 = 本地按需**:想优化就开 session 跟 agent 说一声;**不做调度 / 云端**(`/loop` 仅作可选的无人值守)。
- **单轮 vs 多轮 = agent 每个实验自选**(广扫单轮省钱,recon-then-act 多轮)。
- **默认**:被测模型 deepseek-v4-flash(可换);记忆保留 raw trace 以便回看。
