---
id: WRK-076
type: working
status: active
owner: @weilin
created: 2026-07-22
reviewed: 2026-07-22
review-due: 2026-10-20
audience: [human, ai]
---

# B1「文件即真相」— 后端规范（拍板稿）

> 战役总纲见 [README.md](README.md)。本篇 = B1 的精确契约 + 实现分解 + 回归清单。调研三源（后端读码 / yaml.Node 最佳实践 / Agent Skills 规范）已交叉对抗验证，版本前提全部成立：Go 1.25（`os.Root` 需 1.24+）、`go.yaml.in/yaml/v3 v3.0.4` 已在依赖（全仓唯一使用点即 skill frontmatter）。

## 0. 一句话

把 skill 的真相源从「API 参数组装」翻转为「磁盘目录原文」：frontmatter 未知键/键序在编辑循环中不丢，SKILL.md 与附属文件可按原文读写，全部路径过第二套穿越守卫。

## 1. 设计决策（已定；异议在拍板时提出）

### D1 双表示拆分（保真的架构解）

`Frontmatter` typed struct（yaml+json 双 tag）**保留**——catalog/searchsource/relations/tool 四处具名字段访问 + 前端 freezed 解码全靠它。保真不改 domain 契约，而是 **infra 层实现细节**：

- `parseFrontmatter` 同时产出 typed struct（视图）与 `*yaml.Node`（原文树，**不出 infra 层**——domain 严禁 import yaml，原则 #3）。
- 结构化 `Save(ctx, name, fm, body)` 签名不变，实现改为**保真读-改-写**：读现有 SKILL.md → parse 成 Node → 只把 SaveInput 涉及的键写进 Node（成对遍历 `Content`、原地改 value 节点、新键 append、**重复键遍历到底全改**）→ `Marshal(doc)` 落盘。新建（无现有文件）时直接 Marshal typed struct。
- 编码器 `SetIndent(2)` 钉住缩进（yaml v3 默认 4 会重排原文）。
- 已知残余（yaml.Node 非逐字节保真，官方明示）：首次结构化编辑会归一化一次原文（空行丢失、注释位置可能漂移、折叠标量 `>` 有 issue #337 空行累积——frontmatter 场景建议值用 `|` 或单行），之后幂等稳定。**读永不写回**，原文 PUT 逐字节忠实（用户给什么写什么），故漂移面仅限「右岛表单编辑装来的 skill」这一条窄路径——可接受，规范注明。

### D2 typed 字段全集补齐规范核心

`Frontmatter` 新增三字段（yaml/json 双 tag，omitempty）：

```go
License       string            `yaml:"license,omitempty"       json:"license,omitempty"`
Compatibility string            `yaml:"compatibility,omitempty" json:"compatibility,omitempty"`
Metadata      map[string]string `yaml:"metadata,omitempty"      json:"metadata,omitempty"`
```

至此 typed 视图覆盖规范核心 6 + CC 扩展 8 + Anselm `source`；其余未知键靠 D1 保真。HTTP 结构化投影不暴露未知键（要看全貌走 files 面读原文）。

### D3 name 双正则（守卫从宽、创建从严）

- **守卫正则**（`IsValidName`，Get/Delete/files 等一切路径入口）：`^[a-z0-9][a-z0-9_-]{0,63}$`——较现状放宽首字符允许数字（对齐规范）、保留 `_`（存量兼容），字符集仍无 `/` 无 `.`，穿越守卫力度不变。
- **创建正则**（`IsSpecName`，Create/结构化新建）：`^[a-z0-9]+(-[a-z0-9]+)*$` 且 ≤64——规范 ASCII 保守版（无 `_`、无连续/首尾连字符）。刻意不采参考实现的 Unicode 放宽（跨平台文件系统一致性 + 路径安全优先）。
- 效果：存量 `_` 名 skill 照常读/改/删；新建从严对齐规范；GitHub 装来的规范名（含数字开头如 `3d-print`）可落地。

### D4 allowed-tools 两态解析

读取兼容 `[a, b]`（列表）与 `"a b"`（规范的空格分隔字符串）两态 → typed 视图统一 `[]string`；被编辑时写回归一为 YAML 列表（未被编辑则 Node 原样）。

### D5 SKILL.md 大小写回退

读取按参考实现：`SKILL.md` 优先，缺失回退 `skill.md`；平台写入恒 `SKILL.md`。

### D6 统一 files 面（SKILL.md 也是文件）

不设单独 raw 端点；SKILL.md 经 files 面读写，仅多一道特判校验（见 §2）。删除 SKILL.md 拒绝（毁 skill 走 `DELETE /skills/{name}`）。

### D7 第二套穿越守卫（相对路径）

files 的 `{path...}` 入口三重守卫，按序：① `filepath.IsLocal(rel)` 词法早拒（绝对路径 / `..` / Windows 保留名）→ 违者 `SKILL_FILE_PATH_INVALID`；② `filepath.Clean` 规范化后二次确认无 `..` 前缀；③ 一切实际 I/O 经 `os.OpenRoot(skillDir)` 句柄（symlink 逃逸 + TOCTOU 由内核挡）。testend 既有 `%2F` 编码穿越攻击矩阵（B-sk-1）延伸出 files 版。

### D8 护栏

SKILL.md 恒 32KB（`MaxBodyBytes` 不变，经 files PUT 同样生效）；附属文件单文件 **1MB**（新 `MaxFileBytes`，对齐 document 的 1MB 护栏），transport 层 `http.MaxBytesReader` 同值兜底。List 扫描只读 SKILL.md，附属文件不影响扫描成本。

### D9 事件

文件写/删复用 **`skill.updated`**，payload `{name, path}`（path 为新增可选字段）；不新增事件名（前端 `skill.` 前缀 refetch 机制零改动即覆盖）。SKILL.md 原文 PUT 同发 `skill.updated {name}`。

### D10 搜索索引范围

B1 仍只索引 SKILL.md（description + whenToUse 卡片 + body 分块）；references 等附属文件**不进索引**——记为已知取舍，B 系列后续可选扩展。

### D11 原文写路径不 TrimSpace

现 `Save` 的 `strings.TrimSpace(body)` 仅保留在结构化路径；原文 PUT 走新 `SaveRaw`，字节忠实落盘（仍 `.tmp + rename` 原子写）。

### D12 原文 PUT 的最小校验（从宽哲学）

经 files PUT 写 SKILL.md 时仅验：① ≤32KB；② frontmatter 围栏可解析（`---` 开头 + 闭合）；③ frontmatter 带 `name` 时必须 == 目录名（规范铁律）→ 违者 `SKILL_INVALID_FRONTMATTER` 带 reason。**不**要求 description（装来的 skill 可能缺省，catalog 已有 `(no description)` 兜底）；`bodyHasLeadingFrontmatter` 守卫**不适用**于原文路径（原文必然以 `---` 开头——先切围栏再论 body），仅保留在结构化路径。

### D13 发现目录不扩

不直读 `~/.claude/skills` / `.claude/skills`（workspace 物理隔离优先）；生态资产复用走 B4 的「导入/安装」（copy 进 workspace）。列 backlog。

## 2. 精确契约

### 端点（新增 3 条，挂 `SkillHandler.Register`）

| 端点 | 语义 | 响应 |
|---|---|---|
| `GET /api/v1/skills/{name}/files` | 递归列出该 skill 全部文件（含 SKILL.md） | `{data:[{path,size,updatedAt}]}`，有界集合不分页（N4 豁免①） |
| `GET /api/v1/skills/{name}/files/{path...}` | 读单文件原始字节 | 裸字节，`Content-Type` 按扩展名推断（缺省 `application/octet-stream`）+ `Content-Length` + `Content-Disposition: inline`（抄 attachment.Content 先例） |
| `PUT /api/v1/skills/{name}/files/{path...}` | 写单文件（原始字节体，`MaxBytesReader`；父目录自动 MkdirAll；path==SKILL.md 走 D12 校验） | `{data:{path,size,updatedAt}}` |
| `DELETE /api/v1/skills/{name}/files/{path...}` | 删单文件（path==SKILL.md 拒；删后空目录不清理） | 204 |

`{path...}` 尾随通配为全仓首例——实现时先以 httptest 实测 `PathValue("path")` 的多段解码行为与既有 `{nameAction}` 冒号派发、`envelopeMuxErrors` 405 改写的共存（读码已确认段数不同不冲突，仍须测试钉死）。

### 错误码（error-codes.md 新增 3 条）

| 码 | HTTP | 语义 |
|---|---|---|
| `SKILL_FILE_NOT_FOUND` | 404 | skill file not found |
| `SKILL_FILE_PATH_INVALID` | 400 | invalid skill file path（穿越/绝对路径/删 SKILL.md） |
| `SKILL_FILE_TOO_LARGE` | 422 | skill file exceeds size limit（对齐 `SKILL_BODY_TOO_LARGE` 的 422） |

### Repository 端口（domain，新增 5 方法）

```go
// 原有 List/Get/Save/Delete/Exists 不变（Save 实现改保真，签名不动）
SaveRaw(ctx context.Context, name string, raw []byte) error            // D11/D12
ListFiles(ctx context.Context, name string) ([]FileInfo, error)        // FileInfo{Path,Size,UpdatedAt}
ReadFile(ctx context.Context, name, rel string) ([]byte, error)
WriteFile(ctx context.Context, name, rel string, data []byte) error
DeleteFile(ctx context.Context, name, rel string) error
```

`FileInfo` 为 domain 新纯类型。mime 推断放 transport（`mime.TypeByExtension`），不进 domain。

### LLM 工具面

B1 **不加**新 LLM 工具（读附属文件走 B2 的 filesystem 工具可达；create/edit/get/delete/activate 五工具不变）。`get_skill` 结果自然多出 license/compatibility/metadata 字段。

## 3. 实现步骤

1. **domain**：`Frontmatter` +3 字段；`IsSpecName` + 守卫正则放宽；`FileInfo`；3 个新 sentinel；`MaxFileBytes`；Repository +5 方法。
2. **infra/fs/skill**：`parseFrontmatter` 改双产出（typed + Node）；`Save` 改保真读-改-写（Node 手术 + SetIndent(2)）；`SaveRaw`；files 五操作（`os.OpenRoot` 全程）；`skill.md` 回退；allowed-tools 两态解析。**单测新增**：未知键+键序往返逐字节断言、重复键全改、两态 allowed-tools、穿越矩阵（`../`、绝对、symlink 逃逸）、SKILL.md 特判。
3. **app/skill**：`SaveRawInput` 路径（校验 D12）+ files 透传方法 + 事件 payload 加 path；结构化 `validate()` 换 `IsSpecName`。
4. **transport**：3 条路由 + `{path...}` 实测；裸字节响应/请求（抄 attachment/limits 先例）。
5. **testend**：B-sk-1 矩阵更新（数字开头名转合法）；B-sk-2 补原文 PUT 语义分支；新增 files 契约场景（CRUD + 穿越攻击 + 保真往返 + 32KB/1MB 双护栏）；按 T5.1 `grep -rn '"skill\.' testend/` 全量过一遍。
6. **文档同提交**：api.md（skill 节 + N4 豁免①清单加 files）、error-codes.md（+3）、events.md（skill.updated payload path）、domains/skill.md（整体重述：目录即真相 + files 面 + 双正则 + 保真语义）、database.md（skill 节措辞核对）。

## 4. 破坏面与回归清单（来自读码调研，实现时逐条勾）

- ☐ `infra/fs/skill/skill_test.go` RoundTrip（typed 访问器在新 parse 下不变）
- ☐ `app/skill/skill_test.go` 全部（含 `RejectsBodyFrontmatter`——仅结构化路径）
- ☐ `app/agent/crud_skill_test.go`（Guide 错误面不变）+ `agent_test.go:330`（guide 进 system prompt）
- ☐ catalog_source / searchsource / relations / tool/skill 四处具名字段访问编译绿
- ☐ SSE-C build 镜像不受影响（结构化 create/edit 路径未动）
- ☐ testend `contract_knowledge_test.go` 三大组 + `chat_r3_test.go` 两场景
- ☐ 前端零改动可跑（JSON 投影只增不改；F1 前 files 面无人消费）

## 4.5 实现修正记录（建造中发现，2026-07-22——与拍板不冲突的工程级修正）

1. **D12 校验下沉 infra**：清单校验（尺寸/围栏/name==目录名）落在 `Store.SaveRaw` 而非 app 层——解析器在 infra，校验「字节是否合法清单」是存储格式关注点；app.ReplaceRaw 只管 Exists 前置 + 事件 + equip 边重同步。
2. **files PUT 响应 = 204**（原规范 `{data:{path,size,updatedAt}}`）：写后回显需再 stat，诚实成本高于价值；前端拿本地已知内容 + `skill.updated` 刷新列表。
3. **重复键语义**：yaml v3.0.4 在 Unmarshal 即拒重复 mapping key（**实测推翻调研「Node 不去重」断言**）→ 重复键文件天然是坏件（SaveRaw 拒收、Get 大声失败、List 跳过），patchKey 无需 dedup 分支（反校验剧场 #6）。
4. **大小写清退的平台 bug**：macOS APFS 默认大小写不敏感，盲删小写 `skill.md` 残件会删掉刚写的 `SKILL.md` 本身——清退经 `os.SameFile` 判别（首轮单测抓获）。
5. **mime 补充表**：系统 mime 表裸机缺 `.md`/`.py` 等——transport 内置 12 个 skill 高频扩展的小表，查不到再落系统表 → octet-stream。
6. **testend 连带**：IsSpecName 从严令 8 个场景文件的下划线 skill 夹具名全部改连字符（`triage-steps`/`deploy-guide`/`rel-skill` 等）；B-sk-1 矩阵数字开头由拒转收、新增下划线/连续/首尾连字符拒项；新增 `TestContractKnowledge_SkillFilesSurface`（B-sk-f1..f4：裸字节 CRUD / 穿越+逃逸审计 / 清单特判+保真 / 双护栏）+ harness `DoRaw`（裸字节双向）。

## 5. 拍板记录（2026-07-22，用户裁决，全数落定）

**Q1 name 双正则（D3）→ 采纳**：新建从严对齐规范（弃 `_`、允数字开头、禁连续/首尾 `-`）+ 守卫从宽保存量。testend 坏名矩阵中「数字开头」由拒转收。

**Q2 发现目录（D13）→ 采纳**：B1-B4 不直读 `~/.claude/skills` / `.claude/skills`，生态资产复用统一走 B4 安装/导入（copy 进 workspace）。
