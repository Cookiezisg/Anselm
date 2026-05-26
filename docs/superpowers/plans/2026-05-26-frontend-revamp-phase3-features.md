# 前端 Revamp 阶段 3:features 层(抽用例) 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: 用 superpowers:subagent-driven-development 逐 task 执行。步骤用 `- [ ]` 勾选。

**Goal:** 把散在组件 `onClick`/`onSubmit`/`useEffect` 里的**业务编排**(~435 行:组装/校验/调 mutation/错误处理/toast/资源自愈/invalidate)抽进 **8 个 `features/<x>/model` 的用例 hook**,组件**原位瘦身**(只调一个意图级 hook + 渲染)。**行为/UI 零改动**(vitest 全绿 + 组件交互/渲染完全一致即证)。

**Architecture:** features 是 FSD 第 3 层(对位后端 `app/service`),**只能 import `entities` + `shared`**。本阶段每 slice **只建 `model/`(用例 hook)+ `index.ts`**;**组件本身不迁移**(留 `panes/`/`components/`/`overlays/` 原位,只瘦身调 hook)——组件迁进 `pages/`/`widgets/`/`features/ui` 是**阶段 4**。铁律(= 后端 S6):组件 `onClick` 里不准有业务决策,只调 feature hook 拿意图级 API(`{submit, canSubmit, isStreaming}` 之类)。

**Tech Stack:** TypeScript、TanStack Query、zustand、react-i18next、vitest、steiger、eslint-plugin-boundaries。

---

## 通用纪律(每个 task 都遵守)

- **独占 main 工作树**,直接在 `main` 开发,**严禁开新分支**(多 session 共享工作树)。
- **精确 git add**:只 add 本 task 产物。**严禁 `git add -A`/`git add .`**——工作树长期有其它在途文件 + `frontend/tests/manual/probe-*.mjs` 探针 + `backend/lintprompts`、`backend/server`(audit 残留),**绝不能带上**。commit 前 `git status` 核对。
- **绝不碰** `backend/` 任何文件。
- commit message **中文**、**无任何 AI attribution**。commit 后 **`git push`**。撞 `index.lock`:`ps aux | grep "[g]it"` + 看时间戳,确认孤儿锁才 `rm -f`,**绝不盲删**。
- 命令在 `frontend/` 内跑(除非注明仓库根)。

## 通用抽取 SOP(每个 feature 通用,样板见 Task 3.1)

> 只有 Task 3.1 写出完整代码作模板,其余 task 引用本 SOP + 给「现状(文件:行号)/ hook API / 抽取点」。

1. **建 `features/<x>/model/use<X>Flow.ts`**(或语义命名,如 `useAccountManager`):把组件里的**业务编排**逐段搬进来——组装 body / 校验 / 调 entity mutation / 错误处理 / **toast(随编排进 hook)** / 资源级自愈 / `invalidateQueries`。hook 返回**意图级 API**(动作函数 + 派生状态,如 `{ submit, canSubmit, isStreaming }`),**不暴露 mutation 内部**。从 `@entities/<x>` import entity hooks、从 `@shared/*` import `apiFetch`/`pushToast`(若 toast 来自 `store/ui`,见下方债务说明)。
2. **逻辑逐字保留、行为不变**:抽取 = **移动 + 封装**,不是重写。每个分支、每条 toast、每个自愈、每次 invalidate 的**触发条件和效果完全不变**。只是从组件搬进 hook。**不新增防御**(后端必给的字段不加 fallback)、**不改文案**、**不改交互时序**(防抖间隔/流式状态等逐字)。
3. **建 `features/<x>/index.ts`** public API barrel:re-export 该 feature 对外 hook(+ 必要类型)。组件只 import 这个 barrel。
4. **组件原位瘦身**:组件**留原位**(不迁目录),删掉抽走的编排代码,改成 `const { submit, ... } = useXxxFlow(...)`,`onClick={submit}`。组件只剩**渲染 + 本地 UI state(展开/草稿/hover)+ 事件绑定**。**JSX 渲染输出和交互行为必须 1:1 不变**。
5. **边界债**:① feature hook 读 `store/ui`(`pushToast`/`setActiveConv` 等客户端状态)——`store/ui` 尚未分层(阶段4 拆进 `app/model`),这是 feature→store 越界,当场 inline `// eslint-disable-next-line boundaries/dependencies` + `// TODO(阶段4): ui store 拆进 app/model 后修正 import`。② feature hook 读 `store/settings`(activeUserId,如 switchTo)——同 entities,inline disable + `// TODO(阶段4): identity store`。逐条在报告列出。
6. **验证门**(全过):`npx tsc --noEmit`(0)/ `npx vitest run`(**基线不减**,组件测试验证行为不变)/ `npm run build` / `npx eslint src/features/<x> <改过的组件>`(除已知债豁免外 0 error)/ `npm run fsd`(steiger 干净)。复杂编排(onboarding/workflow-edit diff)**补针对性单测**覆盖关键分支。然后精确 commit + push。

## features 清单(8 个)+ 现状映射(行号来自调研,实现时以实际为准)

| # | feature | 来源组件(文件:行) | 抽进 hook | 编排步骤(逐字保留) | 优先级 |
|---|---|---|---|---|---|
| 3.1 | **send-message** | `panes/chat/ChatPane.jsx`:42-47,115-143 | `useSendMessageFlow(convId)` | 组装 body→useSendMessage→**error.code===CONVERSATION_NOT_FOUND 自愈**(setActiveConv(null)+invalidate)→toast;cancel | **样板** |
| 3.2 | **onboarding** | `components/overlays/Onboarding.jsx`(437行):85-166 | `useOnboardingFlow()` | ensureUser / pickProvider(清孤立 key)/ verify(多步校验:keyId 变化判断+fallback PROVIDER_DEFAULT_MODEL)/ handleNext(6步分发)/ finish(settings+invalidate+toast) | P1,最复杂 |
| 3.3 | **forge-iterate** | `components/.../AskAiTrigger.jsx`:26-57 + `api/forge.js` 的 `useIterateForge` 残壳 | `useForgeIterate()` | iterate mutation→**conversationId 取值(res.conversationId\|\|res.id)**→判空(警告 toast vs 跳转打开对话)→错误 toast。**把 2.8 留在 forge.js 的 `useIterateForge` 实现搬进本 feature** | P1,清 forge.js 残壳 |
| 3.4 | **forge-review** | `FunctionDetail.jsx`:39-50 / `HandlerDetail.jsx`:68-79 / `WorkflowDetail.jsx`:62-78 / `ForgeList.jsx`:134-143 | `useForgeReview(kind, id)` + `useForgeBatchDelete(kind)` | accept/reject/revert(调 useAcceptX/useRejectX/useRevertX + toast,3 个 detail 统一);ForgeList 批量删(confirm→逐个 mutate→clearSel) | P2 |
| 3.5 | **workflow-edit** | `panes/forge/WorkflowEditor.jsx`(667行):76-127,337-387 | `useWorkflowEdit(id)` | **2s 防抖 autosave**(markDirty→清 timer→**diffToOps 三向 diff**→nodeToSpec/edgeToSpec 映射→useEditWorkflow);capability-check | P2,diff 算法 |
| 3.6 | **settings** | `components/overlays/SettingsModal.jsx`:98-115 | `useAccountManager()` | switchTo(settings.set activeUserId+**全量 invalidate**+toast)/ addAccount(校验+createUser+switchTo+清输入) | P3 |
| 3.7 | **ask-user** | `components/overlays/AskUserModal.jsx`:81-95 | `useAskUserAnswer()` | 消费 `ui.pendingAsk`→校验(selected 非空)→POST `:resolve`→成功 toast+close / 错误 toast | P3 |
| 3.8 | **entity-link** | `components/shared/RelGraph.jsx`:54-84 + `EntityRelMeta.jsx`:33-68 | `useEntityDirectory()` + `useEntityNeighborhood(kind,id)` | RelGraph:8 entity query 并行→useMemo 聚合 nodes[]→normEdges(映射+dedupe);EntityRelMeta:neighborhood→guessKind(prefix)→dedupe+limit3。**只抽数据聚合,力导向算法/canvas 渲染留组件** | P3 |

## 不变量(行为/UI 不变 —— 阶段 3 绝不碰的东西)

- **组件渲染输出 + 交互 1:1 不变**:瘦身 = 删业务代码、调 hook;JSX 结构/className/事件绑定/本地 UI state 不动。Composer 的 @-menu/拖拽、WorkflowEditor 的 canvas 交互、各 detail 的渲染 —— 纯 UI 全留组件。
- **toast 文案/kind/触发条件不变**:toast 从组件搬进 feature hook,但每条的 title/desc/kind/触发点逐字保留。**不做 errorMap 集中表 / 全局 onError**(spec §7 那个更大的收口留阶段 4/5);本阶段只是把 toast 跟着编排搬家。
- **自愈分级**:**资源级**自愈(send-message 的 `CONVERSATION_NOT_FOUND`)抽进对应 feature hook;**身份级**自愈(activeUserId/SSE 401)**不碰**,留阶段 4 身份层。
- **enabled gate / invalidate / qk 不变**:沿用 entities 层(阶段2)的 hook;feature hook 里的 invalidate(如 switchTo 全量清、finish 全量清)逐字保留。
- **组件不迁目录**:本阶段组件留 `panes/`/`components/`/`overlays/` 原位,只瘦身;迁进 `pages/`/`widgets/`/`features/ui` 是阶段 4。
- **SSE / 身份 / God Store 不动**:`useEventLog`/`useForge`/`useNotifications`、identity、`store/ui` 的拆分都留阶段 4。

---

## Task 3.1:features/send-message(样板)+ 注册 features 边界

**Files:** Create `frontend/src/features/send-message/{model/useSendMessageFlow.ts, index.ts}`;Modify `frontend/src/panes/chat/ChatPane.jsx`(瘦身);Modify `frontend/eslint.config.js`(注册 features element)、`frontend/tsconfig.json`(确认 `@features/*` alias)。

### Step 1:读现状 + 工具
读 `frontend/src/panes/chat/ChatPane.jsx`(完整,重点 line 42-47 自愈 effect、115-143 onSend/onCancel——看组装 body、调哪个 entity hook(`useSendMessage`/`useCancelStream` from `@entities/conversation`)、error.code 判断、`setActiveConv`/`pushToast`/`invalidateQueries` 来源);`frontend/src/store/ui.js`(`pushToast`/`setActiveConv` 签名);`frontend/src/entities/conversation/index.ts`(可用 hook + 类型);`frontend/eslint.config.js`(boundaries elements 现状,有 `feature-tmp` 临时 element)+ `frontend/tsconfig.json`(alias)。

### Step 2:写 `features/send-message/model/useSendMessageFlow.ts`
把 ChatPane 的发送编排逐字搬进来 + 加类型。形态(**以 ChatPane 实际实现为准**):
```ts
import { useCallback } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { useSendMessage, useCancelStream } from "@entities/conversation";
import { qk } from "@shared/api";
// eslint-disable-next-line boundaries/dependencies
// TODO(阶段4): ui store 拆进 app/model 后修正 import
import { useUiStore } from "../../../store/ui";

export function useSendMessageFlow(convId: string) {
  const send = useSendMessage(convId);
  const cancel = useCancelStream(convId);
  const qc = useQueryClient();
  const setActiveConv = useUiStore((s) => s.setActiveConv);
  const pushToast = useUiStore((s) => s.pushToast);

  const submit = useCallback(async (text: string, attachments) => {
    // 组装 body → send.mutate → catch: error.code === "CONVERSATION_NOT_FOUND"
    //   → setActiveConv(null) + qc.invalidateQueries({queryKey: qk.conversations()})
    //   → 其它错误 toast。全部逐字对照 ChatPane onSend。
  }, [/* deps */]);

  const cancelStream = useCallback(() => { /* 对照 onCancel */ }, []);

  return { submit, cancelStream, isStreaming: send.isPending /* 或原状态 */ };
}
```
**严格对照 ChatPane onSend 的逻辑**(上面是骨架)。CONVERSATION_NOT_FOUND 自愈逐字。

### Step 3:`features/send-message/index.ts`
```ts
export { useSendMessageFlow } from "./model/useSendMessageFlow";
```

### Step 4:ChatPane 瘦身
ChatPane 删掉 onSend/onCancel 的业务体 + 自愈 effect(若自愈移进 hook),改成 `const { submit, cancelStream, isStreaming } = useSendMessageFlow(activeConv);`,onSend 调 `submit`。**JSX/Composer 渲染、本地草稿 state、流式 UI 全不变**。注意:若自愈 effect(line 42-47)依赖组件级 state,判断是移进 hook 还是留组件——目标是组件无业务决策,但**行为不变优先**(若移动有风险,保留 effect 但只让它调 hook 暴露的动作)。

### Step 5:注册 features 边界 + alias
- `eslint.config.js`:加 `{ type: "features", pattern: "src/features/*", capture: ["slice"] }`。规则:`features` 允许 import `entities`/`shared`;禁 `app`/`pages`/`widgets`(及未分层的反向);同层 features 默认禁。severity **`error`**(与 entities 同款,feature→store 债当场 inline disable)。验证规则能 fire。
- `tsconfig.json`:确认/补 `@features/*` → `./src/features/*`(vite/vitest 经 `vite-tsconfig-paths` 继承)。
- steiger:若 features slice 只有 model 段触发 `insignificant-slice`,在 `steiger.config.js` 给 `src/features/**` 加 `insignificant-slice: off`(同 entities 处理)。

### Step 6:验证 + commit
SOP step 6 五项 + ChatPane 相关 vitest 必须绿(发送/取消/自愈行为不变)。精确 `git add frontend/src/features/send-message frontend/src/panes/chat/ChatPane.jsx frontend/eslint.config.js frontend/tsconfig.json frontend/steiger.config.js`。commit `feat(frontend): features/send-message 用例抽取 + 注册 features 边界(阶段3样板)`。push。

---

## Task 3.2:features/onboarding(437 行,最复杂)

**Files:** Create `features/onboarding/{model/useOnboardingFlow.ts, index.ts}`;Modify `components/overlays/Onboarding.jsx`(瘦身)。

按 **SOP**。要点:
- `useOnboardingFlow()` 抽 Onboarding line 85-166 的全部编排:`ensureUser`(组装+createUser)、`pickProvider`(**最佳努力删孤立 key,不 await**)、`verify`(**多步校验**:keyId 变化判断→创/重用 key→testKey→组装 models,fallback `PROVIDER_DEFAULT_MODEL`)、`handleNext`(6 步:workspace/model/search/done 分发)、`finish`(settings.set + 全量 invalidate + toast)。
- hook 返回意图级:`{ step, next, back, verify, verifyState, finish, canProceed, ... }`(对照 Onboarding 实际状态机)。verify 的 5 个状态(verifying/verified/verifyError)逐字保留。
- 用到 `@entities/user`(useCreateUser)、`@entities/apikey`(useCreateApiKey/useTestApiKey/useDeleteApiKey)、`@entities/model-config`(useUpsertModelConfig/useProviders/useScenarios)、`store/settings`(set onboarded/activeUserId → inline disable + TODO阶段4)、`store/ui`(pushToast → inline disable + TODO阶段4)。
- Onboarding.jsx 瘦身:6 步向导的**渲染(各步 UI、进度、按钮)全留组件**,只把 ensure/verify/advance/finish 的业务体移进 hook,组件调 `next()`/`verify()`/`finish()`。
- **补针对性单测**:verify 多步校验(keyId 变化、fallback model)+ 6 步推进的关键分支。
- commit `feat(frontend): features/onboarding 用例抽取(阶段3)` + push。

---

## Task 3.3:features/forge-iterate(+ 清 forge.js iterate 残壳)

**Files:** Create `features/forge-iterate/{model/useForgeIterate.ts, index.ts}`;Modify `components/.../AskAiTrigger.jsx`(瘦身);Modify `frontend/src/api/forge.js`(iterate 残壳 → 移走后转 shim 或删)。

按 **SOP**。要点:
- **把阶段 2 留在 `src/api/forge.js` 的 `useIterateForge` 实现搬进** `features/forge-iterate/model`(这是它的 FSD 归宿——跨实体用例)。定型 + 类型。
- `useForgeIterate()` 编排:对照 AskAiTrigger line 26-57——iterate mutation → **`conversationId 取值(res.conversationId || res.id)`** → 判空(无 → 警告 toast;有 → 打开对话 setActiveConv/openPane)→ 错误 toast。
- `forge.js` 的 `useIterateForge` 搬走后:forge.js 现在全是 re-export(function/handler/workflow)了——**iterate 也改成 `export { useIterateForge } from "@features/forge-iterate"` 或让 AskAiTrigger 直接 import features**(判断:若还有别处从 `api/forge` import iterate,留 re-export shim;否则直接改调用点)。forge.js 顶部 `TODO(阶段3)` 注释删除。
- **注意 boundaries**:`forge.js`(在 `src/api`)re-export `@features/forge-iterate` 会形成 api→features 的"反向"——但 api 是过渡 shim 层(非正式 FSD 层),且最终 forge.js 阶段5 删。若 eslint 对此报错,优先**改 AskAiTrigger 直接 import `@features/forge-iterate`**(组件→features 合法),forge.js 不再 re-export iterate。
- AskAiTrigger 瘦身:弹层/textarea/suggestion chips 纯 UI 留组件,调 `useForgeIterate().submit(prompt)`。
- commit `feat(frontend): features/forge-iterate 抽取 + 清 forge.js iterate 残壳(阶段3)` + push。

---

## Task 3.4:features/forge-review

**Files:** Create `features/forge-review/{model/useForgeReview.ts, index.ts}`;Modify `FunctionDetail.jsx`/`HandlerDetail.jsx`/`WorkflowDetail.jsx`/`ForgeList.jsx`(瘦身)。

按 **SOP**。要点:
- `useForgeReview(kind, id)`:统一三类(function/handler/workflow)的 accept/reject/revert 编排——按 kind 选对应 `@entities/<kind>` 的 useAcceptX/useRejectX/useRevertX(FunctionDetail:39-50、HandlerDetail:68-79、WorkflowDetail:62-78,目前嵌在 JSX onClick),调 mutation + toast。
- `useForgeBatchDelete(kind)`:ForgeList:134-143 批量删——confirm 确认 → 逐个 useDeleteX.mutate → clearSel + toast。
- 三个 detail + ForgeList 瘦身:把 onClick 里的业务体换成 hook 动作。**渲染不变**(accept/reject 按钮、版本展示)。
- commit `feat(frontend): features/forge-review 抽取(阶段3)` + push。

---

## Task 3.5:features/workflow-edit(diff/autosave)

**Files:** Create `features/workflow-edit/{model/useWorkflowEdit.ts, index.ts}`;Modify `panes/forge/WorkflowEditor.jsx`(瘦身)。

按 **SOP**。要点:
- `useWorkflowEdit(id)`:对照 WorkflowEditor line 337-387(**2s 防抖 autosave**:markDirty→清前 timer→diffToOps→useEditWorkflow)+ 76-127(**diffToOps 三向 diff** add/update/delete、nodeToSpec/edgeToSpec 属性映射)。**防抖间隔(2s)、diff 算法、属性映射逐字保留**。capability-check(`useCapabilityCheck`)若在编辑流程里也抽入。
- hook 返回:`{ markDirty, isDirty, isSaving, runCapabilityCheck, ... }`。
- WorkflowEditor 瘦身:**canvas 拖拽/连线/缩放/Inspector 编辑等 UI 全留组件**(667 行大部分是 UI);只把 diff+autosave 业务移进 hook,组件在节点/边变化时调 `markDirty(graph)`。
- **补针对性单测**:diffToOps 的 add/update/delete 三向 + nodeToSpec/edgeToSpec 映射(这是核心算法,必须测)。
- commit `feat(frontend): features/workflow-edit 抽取(阶段3)` + push。

---

## Task 3.6:features/settings(账户管理)

**Files:** Create `features/settings/{model/useAccountManager.ts, index.ts}`;Modify `components/overlays/SettingsModal.jsx`(瘦身)。

按 **SOP**。要点:
- `useAccountManager()`:SettingsModal:98-115——`switchTo(userId)`(settings.set activeUserId + **全量 invalidateQueries** + toast;读 settings/qc → inline disable + TODO阶段4)、`addAccount(form)`(校验 + useCreateUser + switchTo + 清输入)。
- SettingsModal 瘦身:theme/lang/accent 等偏好开关的渲染留组件(它们直接 set settings,是 UI 偏好非业务编排,可留);只把 switchTo/addAccount 的多步业务移进 hook。
- commit `feat(frontend): features/settings 账户管理抽取(阶段3)` + push。

---

## Task 3.7:features/ask-user

**Files:** Create `features/ask-user/{model/useAskUserAnswer.ts, index.ts}`;Modify `components/overlays/AskUserModal.jsx`(瘦身)。

按 **SOP**。要点:
- `useAskUserAnswer()`:AskUserModal:81-95——消费 `ui.pendingAsk`(读 store/ui → inline disable + TODO阶段4)、submit(校验 selected 非空 → POST `:resolve` via `apiFetch` → 成功 toast + close / 错误 toast)。`:resolve` 是 ask 应答端点,用 `@shared/api` 的 apiFetch。
- AskUserModal 瘦身:选项渲染/输入 UI 留组件,调 `submit()`。isOpen 派生(askOpen || !!pending)逻辑保留。
- commit `feat(frontend): features/ask-user 抽取(阶段3)` + push。

---

## Task 3.8:features/entity-link(RelGraph/EntityRelMeta 数据聚合)

**Files:** Create `features/entity-link/{model/useEntityDirectory.ts, model/useEntityNeighborhood.ts, index.ts}`;Modify `components/shared/RelGraph.jsx` + `components/shared/EntityRelMeta.jsx`(瘦身)。

按 **SOP**。要点:
- `useEntityDirectory()`:RelGraph:54-84——**8 个 entity query 并行**(conversation/function/handler/workflow/flowrun/document/skill/... 的列表 hook from `@entities/*`)→ useMemo 聚合成 `nodes[]` + normEdges(字段映射+dedupe)。返回 `{ nodes, edges }`。
- `useEntityNeighborhood(kind, id)`:EntityRelMeta:33-68——`useNeighborhood` → guessKind(prefix) → dedupe + limit 3。
- RelGraph/EntityRelMeta 瘦身:**力导向算法(87-164)、canvas 渲染、SVG 全留组件**;只把数据聚合移进 hook,组件调 `const { nodes, edges } = useEntityDirectory()`。
- **注意**:RelGraph 组件本阶段**仍留 `components/shared/` 原位**(阶段 4 才迁 `widgets/entity-graph`);本 task 只抽它的数据聚合 hook。
- commit `feat(frontend): features/entity-link 数据聚合抽取(阶段3)` + push。

---

## Task 3.9:阶段 3 收口(features 边界验证 + 组件零业务核查 + 验证 + 文档)

**Files:** Modify `frontend/eslint.config.js`(若需)、`docs/superpowers/plans/2026-05-26-frontend-revamp-phase3-features.md`(勾选)。

- [ ] **Step 1: features 边界 + 债豁免清点**
`grep -rn "eslint-disable-next-line boundaries" frontend/src/features` 列出所有豁免,确认每处都有 `// TODO(阶段4)` 且确属 feature→store(ui/settings)债。`npx eslint src/features` 确认除豁免外 0 error。features 规则应为 `error`。
- [ ] **Step 2: 组件零业务决策抽查**
抽查 `ChatPane.jsx`/`Onboarding.jsx`/各 Detail/`AskUserModal.jsx`——确认 `onClick`/`onSubmit` 里**无业务决策**(只调 feature hook 动作),业务编排都在 `features/*/model`。残留的纯 UI(本地 state、渲染、canvas 交互)是合法的。报告抽查结果(对照 spec §16 验收"组件 onClick 零业务决策")。
- [ ] **Step 3: steiger + 全量验证**
`npm run fsd`(features 8 slice FSD 干净)。`npx tsc --noEmit`(0)+ `npx vitest run`(**基线不减**,所有组件行为测试 + 新增 feature hook 单测全绿)+ `npm run build`。仓库根 `make lint-frontend`(三段过)+ **`make dev` 冒烟**(端到端:发消息/onboarding/forge accept/iterate/workflow 编辑/切账户/ask 应答/关系图 —— 各 feature 交互正常,行为/UI 与重构前一致)。
- [ ] **Step 4: 文档勾选 + commit**
本 plan Task 3.1–3.9 勾 `[x]` + 末尾补阶段3完成说明(8 feature 抽取 + feature→store 豁免清单留阶段4 + forge.js iterate 残壳已清 + 组件原位瘦身、迁目录留阶段4)。**不动 PRD/CLAUDE.md**(留阶段5)。commit `chore(frontend): 阶段3 features 收口 — 边界验证 + 组件零业务核查(阶段3)` + push。

---

## Self-Review

**Spec 覆盖**(对照 spec §5 业务逻辑安置 / §7 横切收口 / §13 阶段3「把组件业务编排抽进 features/*/model,组件变薄」):
- ✅ 8 feature 覆盖 spec §11 features 层全部(send-message/forge-iterate/forge-review/workflow-edit/onboarding/settings/ask-user/entity-link)。
- ✅ 样板 useSendMessageFlow 即 spec §5 给的示范。
- ✅ 组件零业务决策(§16 验收)在 3.9 抽查。
- ✅ toast 随编排进 hook(§7「feature hook 决定文案」的第一步);集中 errorMap+全局 onError 明确留阶段4/5(避免本阶段过度收口)。
- ✅ 自愈分级:资源级(CONVERSATION_NOT_FOUND)进 feature;身份级留阶段4(§8)。
- ✅ forge.js iterate 残壳(阶段2 遗留)在 3.3 清掉。

**Placeholder 扫描**:Task 3.1 给完整骨架代码 + 抽取边界;3.2–3.8 给现状(文件:行号,来自调研)+ hook API 草案 + 抽取/保留边界——非占位,是「判断性重构的精确指引」。逐行编排代码不预先誊抄(易与实际漂移),由 implementer 对照组件实际逐字搬。

**类型一致性**:各 feature hook 返回意图级 API(`{submit, canSubmit, isStreaming}` 风格);用 `@entities/*` barrel 的 hook 和类型;`@features/*` alias 在 3.1 配。

**风险点(行为不变)**:阶段3 动组件,风险高于阶段2。缓解:① 每 task vitest 组件测试验证行为不变;② 复杂编排(onboarding verify / workflow diff)补针对性单测;③ 3.9 make dev 端到端冒烟;④ 抽取 = 移动+封装非重写,逐字保留每个分支/toast/自愈/invalidate;⑤ 组件不迁目录(减少一个变量,迁移留阶段4)。

**顺序依赖**:3.1 注册 features 边界(后续依赖);3.3 依赖阶段2 的 forge.js iterate 残壳(清它);3.9 收口依赖前 8 完成。subagent-driven 按序执行满足。
