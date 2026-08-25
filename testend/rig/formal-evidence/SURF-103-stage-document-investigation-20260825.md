# SURF-103 · stage/document · 正式调查记录

## 受验对象

`SURF-103 stage/document`：文档编辑舞台是否呈现书脊、公共前缀快进、metadata-only 的诚实
降级和 `[[id]]` 内联胶囊，并在落定后显示真实正文与全量替换尺寸，而不是伪造一块空白散文幕。

## 静态与 focused test

- `DocumentStageBody` 用按编辑 block 冻结的 `documentBaselineProvider` 做公共前缀增量比较；
  分叉前是 muted known truth，分叉后才是新墨，书脊只扫描新增段界。
- 没有打开 `content` 键的 metadata-only edit 不生成空 prose curtain；失败态保留整篇可滚动
  残稿；落定以 `utf8` 字节数计算真实 `全量替换 aKB→bKB`，避免 CJK 的 UTF-16 长度假差。
- `[[id]]` 通过 stage mention names seam 解析，缺名显示原 id 而不是阻塞舞台。
- focused command：
  `cd frontend && mise exec -- flutter test test/features/chat/ui/stages_w2_test.dart test/features/chat/state/stage_director_provider_test.dart test/features/chat/ui/stage_alignment_test.dart test/app/entity_mention_source_test.dart`
  通过，`+26`，无失败。

## 真实 App 路径

formal session：
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-075245`

在全新数据目录、真实 Flutter macOS App、真实 Anselm managed gateway、Computer Use、连续
录屏、独立 SSE witness 和 LLM tap 下，构造两个真实文档编辑场次：

1. **负向矛盾 probe**：用户要求“保留未知前两段”同时禁止 `read_document`。模型合理地先读文档，
   随后第一次 `edit_document` 漏掉一段，再第二次调用修正。最终正文正确，但活动侧幕明确显示
   `编辑 ×2`；这条作为模型/测试约束负事实保留，不能被最终正确抹掉。
2. **干净正向 probe**：用户给出完整目标正文并明确禁止其它工具。真实 App 显示单一
   `已更新文档`，活动侧幕只显示一次 `surf103_clean_doc 编辑`；打开侧幕舞台后，文档名、正文
   `# 原始笔记 / 稳定前缀段落。 / 保留的第二段。 / 新增的第三段。` 均稳定，无重复编辑卡片、
   composer 跳变、横向溢出或布局红线。

## 五通道事实

- Screen：真实窗口录制 `119.876667s`，由 `rig-down.sh` 正常封口；Computer Use 观察了干净
  场次的正文和右侧文档舞台。
- Backend：`backend.log` 249 行，无 WARN/ERROR/panic/fatal/exception；负向矛盾 probe 的
  两次 safe edit 不是后端错误，最终文档 GET 与目标正文一致。
- SSE：`sse.jsonl` 420 行；messages durable `1..48`、notifications `16..22`、entities
  `7..8`，均单调、唯一、无 gap；`seq=0` delta 未计入 durable。
- LLM wire：managed proof challenge/install/models 与 12 次 chat completion 全部 HTTP 200。
- Frontend：4 行日志仅有正常 Dart VM 启动和已知 macOS IMK 平台噪声，无 Flutter/Dart、
  RenderBox/RenderFlex、Unhandled 或 SEVERE 红线。
- `rig-check.sh`、`rig-down.sh` 通过；D1 attribution、health、三流、LLM tap、App 窗口和
  录制均由台架检查，收台后无残留进程。

## 产品裁决

干净正向编辑路径通过：用户目标真实达成，单次编辑、正文、文档舞台和 activity 事实一致。
矛盾 probe 不作为产品 defect：它故意要求模型在不知道正文时既不读又必须保留，模型先读并在
发现遗漏后修正是可解释行为；不过 `编辑 ×2` 已封存为负事实，后续模型工具遵循/多步修正旅程
必须单独检验，不能用最终正文正确掩盖中间状态。
