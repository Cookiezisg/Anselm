# 品牌图标来源与许可

`anselm-icon.svg` 与 `anselm-mark.svg` 是 Anselm 自有资产。其余 provider /
service 图标来自下面两套上游，并作为静态 SVG vendored；`AnBrandIcon` 渲染时着色，
未收录品牌回退为首字母牌，因此单个第三方资产不是运行必需。

## lobe-icons (`@lobehub/icons-static-svg`) — MIT

LLM provider 图标：`openai anthropic gemini deepseek openrouter qwen zhipu moonshot ollama`。

MIT License — Copyright (c) 2023 LobeHub, LLC. Permission is hereby granted, free of charge, to any
person obtaining a copy of this software and associated documentation files (the "Software"), to
deal in the Software without restriction, including without limitation the rights to use, copy,
modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, subject to the
notice above being included in all copies or substantial portions of the Software. THE SOFTWARE IS
PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND. (Full text: https://github.com/lobehub/lobe-icons/blob/master/LICENSE)

## simple-icons — CC0 1.0 Universal (public domain dedication)

Service / marketplace 图标（`github notion supabase sentry postgresql figma zapier todoist box
stripe vercel atlassian mongodb elastic huggingface intercom webflow wix stackoverflow postman
terraform googlechrome svelte nuxt mapbox miro pagerduty snyk upstash dynatrace jfrog pydantic
octopusdeploy codacy unity sap arm netdata sonatype githubcopilot neon brave`). No attribution
required（CC0）；商标仍归各自权利人所有，本项目只用它们识别对应服务。

本地修改：两套上游 SVG 均移除固定 `width/height="1em"` 和 inline `style`，
由 `flutter_svg` 按 `viewBox` 定尺寸；未修改 path / geometry。
