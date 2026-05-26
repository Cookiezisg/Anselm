// Steiger FSD linter config — 阶段1:只有 src/shared 已完成 FSD 化。
// 其余目录(components/store/api/sse/hooks/panes 等)是迁移期扁平结构,
// 阶段2-5 逐步搬迁;在此之前临时 ignore 以避免无意义噪音。
// steiger 全绿是阶段5的终态目标,不是阶段1的要求。

import fsd from "@feature-sliced/steiger-plugin";

export default [
  ...fsd.configs.recommended,
  {
    // 忽略尚未迁移到 FSD 的扁平目录
    ignores: [
      "src/api/**",
      "src/sse/**",
      "src/store/**",
      "src/hooks/**",
      "src/motion/**",
      "src/i18n/**",
      "src/bridge/**",
      "src/components/**",
      "src/panes/**",
      "src/App.jsx",
      "src/main.jsx",
      // app 层阶段4a骨架;组件未迁入 pages,insignificant-slice 会触发;阶段5移除
      "src/app/**",
    ],
  },
  {
    // insignificant-slice: 阶段2迁移期间暂时无引用;
    // 调用点仍在 shared-tmp(api/config.js re-export),steiger 无法跨层追踪。
    // 阶段5调用点全量迁移后移除此豁免。
    //
    // inconsistent-naming: model-config 连字符是刻意的——与后端 API 路径
    // /model-configs 保持一致,不是命名失误。阶段5整体迁移时重新评估。
    files: ["src/entities/**"],
    rules: {
      "fsd/insignificant-slice": "off",
      "fsd/inconsistent-naming": "off",
    },
  },
  {
    // features 阶段3:slice 只含 model 段,steiger insignificant-slice 会触发;
    // 调用点仍在 panes(feature-tmp),阶段4迁入 pages/widgets 后移除此豁免。
    files: ["src/features/**"],
    rules: { "fsd/insignificant-slice": "off" },
  },
  {
    // widgets 阶段4b:每个 widget slice 是独立组件,文件直接平铺在 slice 根目录
    // (无 ui/model 子段);steiger no-segmentless-slices 会触发;
    // 阶段5整体迁移后重新评估是否引入分段。
    files: ["src/widgets/**"],
    rules: { "fsd/no-segmentless-slices": "off" },
  },
];
