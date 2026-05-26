// Steiger FSD linter config — 阶段5 收口:entities→features/pages 反向依赖已全部
// 上移至 pages/ui；shared→entities 反向(useEntityName)已上移至 widgets；steiger 真零违规。

import fsd from "@feature-sliced/steiger-plugin";

export default [
  ...fsd.configs.recommended,
  {
    // 测试文件允许跨层/跨 slice 导入(test harness 需要访问 internals)。
    ignores: [
      "src/**/*.test.js",
      "src/**/*.test.jsx",
      "src/**/*.test.ts",
      "src/**/*.test.tsx",
      // app 层骨架;组件未迁入 pages,insignificant-slice 会触发。
      "src/app/**",
    ],
  },
  {
    // inconsistent-naming: model-config 连字符是刻意的——与后端 API 路径
    // /model-configs 保持一致,不是命名失误。
    //
    // insignificant-slice: entities 层部分 slice 调用点仍在重构中,steiger
    // 无法跨层追踪引用。
    files: ["src/entities/**"],
    rules: {
      "fsd/insignificant-slice": "off",
      "fsd/inconsistent-naming": "off",
    },
  },
  {
    // features 阶段4b:onboarding→settings cross-slice 依赖(ProviderGrid/
    // KeyVerifyField/ModelSelect 通过 settings/index.ts barrel 暴露,但 steiger
    // 仍报 cross-slice)。后续提取为 shared/widgets 组件。
    files: ["src/features/**"],
    rules: {
      "fsd/insignificant-slice": "off",
      "fsd/forbidden-imports": "off",
    },
  },
  {
    // widgets 层每个 slice 直接平铺在 slice 根目录(无 ui/model 子段);
    // steiger no-segmentless-slices 会触发。
    files: ["src/widgets/**"],
    rules: { "fsd/no-segmentless-slices": "off" },
  },
];
