# Brand icon assets — provenance & licenses

Two upstream icon sets, vendored as static SVGs (tinted to ink at render time by `AnBrandIcon`;
every missing brand falls back to a first-letter plate — no asset is ever required):

## lobe-icons (`@lobehub/icons-static-svg`) — MIT

LLM provider marks: `openai anthropic gemini deepseek openrouter qwen zhipu moonshot doubao ollama`.

MIT License — Copyright (c) 2023 LobeHub, LLC. Permission is hereby granted, free of charge, to any
person obtaining a copy of this software and associated documentation files (the "Software"), to
deal in the Software without restriction, including without limitation the rights to use, copy,
modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, subject to the
notice above being included in all copies or substantial portions of the Software. THE SOFTWARE IS
PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND. (Full text: https://github.com/lobehub/lobe-icons/blob/master/LICENSE)

## simple-icons — CC0 1.0 Universal (public domain dedication)

Service/marketplace brand marks (`github notion supabase sentry postgresql figma zapier todoist box
stripe vercel atlassian mongodb elastic huggingface intercom webflow wix stackoverflow postman
terraform googlechrome svelte nuxt mapbox miro pagerduty snyk upstash dynatrace jfrog pydantic
octopusdeploy codacy unity sap arm netdata sonatype githubcopilot neon brave`). No attribution
required (CC0); trademark caveat applies — the marks remain property of their respective owners and
are used solely to identify the corresponding service.

Local modifications (both sets): removed fixed `width/height="1em"` and inline `style` attributes
(flutter_svg sizes by viewBox); no path/geometry edits.
