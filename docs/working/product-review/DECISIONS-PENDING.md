---
id: WRK-010
type: working
status: active
owner: @weilin
created: 2026-06-12
reviewed: 2026-06-12
review-due: 2026-09-12
expires: 2026-09-12
landed-into: ""
audience: [human, ai]
---

# DECISIONS-PENDING —— 等用户裁决的产品级问题

## PD-A `pkg/limits` 空壳处置（源自 PR-3 🔴）

**现状**：包自述「用户可调上限单源 + settings.json」，实际无加载器、SetProvider 零调用、仅 LLMIdleSec 一个字段被消费；真实上限散落各模块硬编码常量。

**选项**：
- **A. 真做配置面**：`GET/PATCH /api/v1/limits`（或 settings 文件 + 热载）+ 把各模块硬编码常量全部改读 `limits.Current()`（loop 工具结果 cap、bash/mcp 超时、subagent 轮数、attachment 上限……约 10+ 处接线）。工作量中；价值=高级用户可调。
- **B. 砍包**：删除未消费字段，limits 只留 LLMIdleSec（或直接内联），各模块常量即事实。工作量小；诚实但放弃可调性。
- **C. 重述自述**：包保留为「未来配置面的预留 schema」，注释改为当前事实（无配置面、字段未接线）。零工作量；留技术债标记。

**建议**：A——桌面产品后期必有「高级设置」页，limits schema 已设计好，缺的只是接线；且「各模块常量」与「limits 默认值」存在两份事实漂移风险（mcpCallSec=180 与 defaultCallTimeout 是否一致没人守）。

## PD-B Ollama embedder 参数面（源自 PR-4 🟡）

**现状**：baseURL/model 硬编码默认值，PATCH /search/settings 只能切 embedder 种类。

**选项**：
- **A. 扩展 settings**：`PATCH /search/settings` 收 `{embedder, ollamaBaseUrl?, ollamaModel?}` 存 search_meta，切换/改参时重建 Ollama provider + 失效向量重嵌；GET 回显。工作量小（半天内）。
- **B. 维持默认**：文档声明「ollama 模式固定连本机默认端口 + embeddinggemma」。

**建议**：A——「可以接 Ollama」的卖点配一半等于没配（非默认端口/模型的用户直接卡死且无报错口）。

## PD-C 桌面 app 日志故事（源自 PR-5 🟡）

**现状**：zap 仅 stdout/stderr，级别二档（FORGIFY_DEV），无文件无轮转。

**选项**：
- **A. 文件落盘**：`<dataDir>/logs/forgify.log` + lumberjack 轮转 + 级别环境变量化；报障=发一个文件。
- **B. 等 Wails 集成**：桌面壳接管 stdout 重定向，后端不动。

**建议**：A 的最小版（文件 + 轮转，级别暂维持二档）——Wails 壳何时建未知，dogfooding 期就需要拿得出日志。

## PD-D 备份与跨机迁移（源自 PR-6 🟡）

**现状**：密钥绑机器指纹，拷库换机密文全废；无 export/import；无文档。

**选项**：
- **A. 导出口**：`POST /export`（打包 db+文件树，密文用用户口令重加密）+ `POST /import`。工作量大，正经功能。
- **B. 文档声明 + 最小逃生**：文档明示「迁移后需重填 api key/handler config/mcp config」（其余数据全保留——密文列只是这三类）；不做导出。
- **C. 密钥文件化**：密钥种子落 `<dataDir>/keyfile`（替代机器指纹），拷目录=完整迁移；牺牲「拷库即解」防护。

**建议**：B 先行（一段文档的事，损失面也就三类可重填的配置），A 进 roadmap；C 与 CR-20 的防拷库初衷冲突、不推荐。
