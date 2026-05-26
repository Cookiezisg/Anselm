// Steiger FSD linter config — 阶段4b 收口:迁移期扁平目录已删,正式6层已就位。
// 残余结构违规(entities 互相交叉引用、entities→features 反向依赖)是 Phase 5 架构工作。
// steiger 全绿是阶段5的终态目标。

import fsd from "@feature-sliced/steiger-plugin";

export default [
  ...fsd.configs.recommended,
  {
    // 测试文件允许跨层/跨 slice 导入(test harness 需要访问 internals)。
    // TODO(阶段5): 当正式 FSD 完全落地后考虑测试文件也遵循 public-api。
    ignores: [
      "src/**/*.test.js",
      "src/**/*.test.jsx",
      "src/**/*.test.ts",
      "src/**/*.test.tsx",
      // app 层阶段4a骨架;组件未迁入 pages,insignificant-slice 会触发;阶段5移除
      "src/app/**",
    ],
  },
  {
    // insignificant-slice: entities 层部分 slice 调用点仍在重构中,steiger 无法
    // 跨层追踪引用。阶段5全量迁移后移除此豁免。
    //
    // inconsistent-naming: model-config 连字符是刻意的——与后端 API 路径
    // /model-configs 保持一致,不是命名失误。阶段5整体迁移时重新评估。
    //
    // forbidden-imports (cross-slice & entities→features/pages):
    // RunDrawer.jsx 在 flowrun slice 内聚合 function/handler/workflow run 接口;
    // FunctionDetail/HandlerDetail/WorkflowDetail 用 forge-review feature;
    // DocEditor/FlowRunDetail/WorkflowDetail 用 pages 层组件(CapabilityCheckPanel
    // / ApprovalBanner / CodeBlockNode)。这些均需 Phase 5 拆层/上移。
    // TODO(阶段5): 拆 RunDrawer 为 widgets 层(可访问多 entity slice);
    //   将 forge-review 下移 entities 或提取为 shared hook;
    //   将页面独有组件移出 pages 到 shared/widgets。
    files: ["src/entities/**"],
    rules: {
      "fsd/insignificant-slice": "off",
      "fsd/inconsistent-naming": "off",
      "fsd/forbidden-imports": "off",
      // DocEditor→CodeBlockNode, FlowRunDetail→ApprovalBanner,
      // WorkflowDetail→CapabilityCheckPanel は全部 entities→pages 反向依赖;
      // pages 目前没有 index.ts barrel(页面组件通常不对外暴露),sidestep 只是
      // 跨层违规的副作用。TODO(阶段5): 拆出到 widgets/shared。
      "fsd/no-public-api-sidestep": "off",
    },
  },
  {
    // features 阶段4b:onboarding→settings cross-slice 依赖(ProviderGrid/
    // KeyVerifyField/ModelSelect 通过 settings/index.ts barrel 暴露,但 steiger
    // 仍报 cross-slice)。阶段5提取为 shared/widgets 组件。
    // TODO(阶段5): 把 onboarding 复用的 settings UI 组件上移到 widgets 或 shared。
    files: ["src/features/**"],
    rules: {
      "fsd/insignificant-slice": "off",
      "fsd/forbidden-imports": "off",
    },
  },
  {
    // widgets 阶段4b:每个 widget slice 是独立组件,文件直接平铺在 slice 根目录
    // (无 ui/model 子段);steiger no-segmentless-slices 会触发;
    // 阶段5整体迁移后重新评估是否引入分段。
    files: ["src/widgets/**"],
    rules: { "fsd/no-segmentless-slices": "off" },
  },
  {
    // shared 层 useEntityName.js 依赖 entities(解析实体名称);这是
    // 经过评估后允许的 shared→entities 反向依赖——useEntityName 是纯
    // display helper,上移 entities 或 widgets 是 Phase 5 工作。
    // TODO(阶段5): 将 useEntityName 移至 entities/shared 或 widgets 层。
    files: ["src/shared/**"],
    rules: {
      "fsd/forbidden-imports": "off",
    },
  },
  {
    // pages 层目前无 cross-layer 违规;no-public-api-sidestep 在迁移后期
    // 仍有一处(DocEditor 在 entities 层引用 pages 的 CodeBlockNode)。
    // 该违规已标记在 entities 规则里。pages 层本身保持干净。
    files: ["src/pages/**"],
    rules: {},
  },
];
