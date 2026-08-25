package loop

import (
	"regexp"
	"strings"
	"unicode"
	"unicode/utf8"
)

const (
	// User-facing prose must not expose opaque ids, but a literal redaction marker such as
	// "<opaque value omitted>" makes otherwise fluent sentences look like a broken template.
	// Use type-aware, context-neutral phrases instead; raw values remain in the adjacent tool card.
	//
	// 面向用户的 prose 不能泄露 opaque id，但字面「<opaque value omitted>」会让本来通顺的句子像坏模板。
	// 改用按类型的中性人话；精确值仍保留在相邻 tool card 中。
	opaqueEntityPlaceholder           = "the requested item"
	legacyEntityPlaceholder           = "the referenced item"
	opaqueTimestampPlaceholder        = "the recorded time"
	opaqueTimestampChinesePlaceholder = "相应时间"
	opaqueIntegerPlaceholder          = "the numeric value"
	opaqueHashPlaceholder             = "the recorded digest"
	opaqueEntityIDPatternSource       = `(?:ws|fn|fnv|fne|fnenv|hd|hdv|hcl|hdenv|hdi|ag|agv|agx|wf|wfv|ctl|ctlv|apf|apfv|trg|tra|trf|tr|cv|msg|blk|att|mdr|mpr|spc|tp|vce|aki|mrp|rel|noti|sr|se|mcp|mcl|doc|mem|todo|fr|frn|sk|act)_[A-Za-z0-9]+`
	opaqueChineseEntityLabelPattern   = `(?:工作流|函数|处理器|代理|触发器|对话|文档|技能|工作区|消息|附件|运行)`
	opaqueEnglishEntityLabelPattern   = `(?:workflow|function|handler|agent|trigger|conversation|document|skill|workspace|message|attachment|run|flowrun)`
)

const (
	// todo_read and todo_write are public tool names, not opaque todo entity ids. Keep them
	// out of the generic ID pass even when the model writes them in Markdown prose.
	// todo_read 与 todo_write 是公开工具名，不是 opaque todo 实体 ID；即使模型把它们写进
	// Markdown 正文，也不能被通用 ID 脱敏改成占位词。
	protectedTodoReadToolName  = "__ANSELM_PUBLIC_TOOL_TODO_READ__"
	protectedTodoWriteToolName = "__ANSELM_PUBLIC_TOOL_TODO_WRITE__"
)

var (
	// Entity ids are useful inside tool cards, but they are not useful prose. Keep the
	// prefixes explicit so ordinary snake_case words remain untouched.
	entityIDPattern = regexp.MustCompile(`\b` + opaqueEntityIDPatternSource + `\b`)
	// Models sometimes repeat an opaque target in parentheses after already naming it, e.g.
	// "workflow nightly (wf_...)". Removing that redundant parenthetical is more fluent than
	// leaving "(the referenced item)" in user-facing prose; standalone ids still use the placeholder.
	opaqueEntityParentheticalPattern = regexp.MustCompile("\\s*\\(\\s*`?" + opaqueEntityIDPatternSource + "`?\\s*\\)")
	// The inverse form is also common in reasoning: "<opaque id> (Human name)". Keep the
	// human name and drop the machine reference before the generic ID pass can create a marker.
	// reasoning 也常把机器值放前面：「<opaque id>（人类名称）」。先保留人名再删机器引用。
	opaqueEntityIDNameParentheticalPattern          = regexp.MustCompile(`[\x60"]?` + opaqueEntityIDPatternSource + `[\x60"]?[ \t]*[（(][ \t]*([^()\r\n]+?)[ \t]*[）)]`)
	opaqueEntityIDNameParentheticalPrefixPattern    = regexp.MustCompile(`[\x60"]?` + opaqueEntityIDPatternSource + `[\x60"]?[ \t]*[（(][ \t]*`)
	opaqueEntityPlaceholderNameParentheticalPattern = regexp.MustCompile(`[\x60"]?(?:` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `|` + regexp.QuoteMeta(legacyEntityPlaceholder) + `)[\x60"]?[ \t]*[（(][ \t]*([^()\r\n]+?)[ \t]*[）)]`)
	// A streamed parenthetical can be redacted in two passes (the id arrives after the opening
	// parenthesis). Remove the placeholder form too, so a chunk-boundary miss cannot leave
	// "name (the referenced item)" in the final prose.
	opaquePlaceholderParentheticalPattern      = regexp.MustCompile(`\s*[（(]\s*` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?" + `\s*[）)]`)
	localizedOpaqueTimestampPlaceholderPattern = regexp.MustCompile(`[ \t]*` + regexp.QuoteMeta(opaqueTimestampPlaceholder) + `[ \t]*`)
	// A model may label the same unavailable value inside a parenthetical, e.g.
	// "Agent created (id `the requested item`)". Remove the whole machine-value
	// parenthetical rather than exposing a phrase that looks like an id.
	// 模型也可能在括号内给不可用值加 id 标签。整段移除，不能把占位词伪装成 ID 留给用户。
	opaquePlaceholderIDParentheticalPattern = regexp.MustCompile(`(?i)\s*\(\s*(?:id|identifier)\s*[:：]?\s*` + "`?" + `(?:` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `|` + regexp.QuoteMeta(legacyEntityPlaceholder) + ")`?" + `\s*\)`)
	// A media summary may keep useful human detail beside the opaque attachment id, e.g.
	// "(red circle, `att_…`)". Once the id is redacted, remove only that list item rather than
	// exposing "(red circle, the requested item)" as a broken user-facing template.
	// 媒体摘要可能把人话描述与 opaque attachment id 放在同一括号里。脱敏后只删掉机器值这一项，
	// 保留「red circle」等有用语义，避免用户看到坏占位符。
	opaquePlaceholderParentheticalListPattern = regexp.MustCompile(`(?i)\([^()\r\n]*` + "`?" + `(?:` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `|` + regexp.QuoteMeta(legacyEntityPlaceholder) + `)` + "`?" + `[^()\r\n]*\)`)
	// A model may put the opaque id first and the human name in parentheses, e.g.
	// "Position 0: `doc_…` (Existing First)". Once the id is redacted, preserve the name
	// and remove the unavailable machine-value fragment instead of exposing a placeholder.
	opaquePositionPlaceholderNamePattern = regexp.MustCompile(`(?im)^([ \t]*[-*]?[ \t]*position[ \t]+[0-9]+[ \t]*:[ \t]*)` + "`?" + `(?:the requested item|the referenced item)` + "`?" + `[ \t]*\([ \t]*([^()\r\n]+?)\s*\)[ \t]*$`)
	// When a model puts an opaque id immediately after an already human-readable entity noun,
	// replacing it with a second noun makes broken prose ("the workflow the referenced item").
	// Drop only the placeholder in that narrow context; standalone ids still retain an honest
	// neutral replacement.
	//
	// 模型把 opaque id 紧跟在已有人话实体名后时，替换成第二个名词会形成坏句子（"the workflow the
	// referenced item"）。只在这个窄上下文移除 placeholder；独立 ID 仍保留诚实的中性替代。
	opaqueEntityNounPlaceholderPattern = regexp.MustCompile(`(?i)\b(the\s+)?(workflow|function|handler|agent|trigger|conversation|document|skill|workspace|message|flowrun|run|attachment)\s+` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `\b`)
	// The same streamed redaction can happen in Chinese prose, where the English noun rule
	// does not match. Remove a typed machine-value parenthetical entirely, or retain only the
	// human type when it appears outside parentheses; never leave the placeholder visible.
	// 中文 prose 也会出现同一类流式脱敏。英文名词规则匹配不到时，带类型的机器值括号整体移除；
	// 若不在括号内只保留人话类型，绝不把 placeholder 留在画面上。
	opaqueEntityTypedPlaceholderParentheticalPattern = regexp.MustCompile(`[（(][ \t]*(?:workflow|function|handler|agent|trigger|conversation|document|skill|workspace|message|flowrun|run|attachment|工作流|函数|处理器|代理|触发器|对话|文档|技能|工作区|消息|运行|附件)[ \t]+` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `[ \t]*[）)]`)
	opaqueEntityChineseNounPlaceholderPattern        = regexp.MustCompile(`(工作流|函数|处理器|代理|触发器|对话|文档|技能|工作区|消息|运行|附件)[ \t]+` + regexp.QuoteMeta(opaqueEntityPlaceholder))
	// Chinese assistant prose can introduce an opaque target as "文档 ID 为 <id>". The generic
	// entity pass must not leave "文档 ID 为 the requested item" behind; rewrite the whole assignment
	// to a natural confirmation while the exact value remains in the adjacent tool card.
	// 中文助手正文可能写成「文档 ID 为 <id>」。通用实体脱敏不能留下「文档 ID 为 the requested item」；
	// 整段改成自然确认，精确值仍留在相邻工具卡。
	opaqueChineseIDAssignmentPattern                     = regexp.MustCompile(`(?i)(` + opaqueChineseEntityLabelPattern + `)[ \t]*(?:的[ \t]*)?(?:ID|标识符?)[ \t]*(?:为|是|[:：=])[ \t]*` + "`?" + opaqueEntityIDPatternSource + "`?")
	opaqueChineseIDAssignmentPlaceholderPattern          = regexp.MustCompile(`(?i)(` + opaqueChineseEntityLabelPattern + `)[ \t]*(?:的[ \t]*)?(?:ID|标识符?)[ \t]*(?:为|是|[:：=])[ \t]*` + "`?(?:the requested item|the referenced item)`?")
	opaqueChineseDecoratedIDAssignmentPattern            = regexp.MustCompile(`(?i)(?:\*{1,3}|_{1,3})?(` + opaqueChineseEntityLabelPattern + `)[ \t]*(?:的[ \t]*)?(?:ID|标识符?)[ \t]*(?:\*{1,3}|_{1,3})?[ \t]*(?:为|是|[:：=])[ \t]*` + "`?" + opaqueEntityIDPatternSource + "`?")
	opaqueChineseDecoratedIDAssignmentPlaceholderPattern = regexp.MustCompile(`(?i)(?:\*{1,3}|_{1,3})?(` + opaqueChineseEntityLabelPattern + `)[ \t]*(?:的[ \t]*)?(?:ID|标识符?)[ \t]*(?:\*{1,3}|_{1,3})?[ \t]*(?:为|是|[:：=])[ \t]*` + "`?(?:the requested item|the referenced item)`?")
	opaqueChineseIDAssignmentPrefixPattern               = regexp.MustCompile(`(?i)(?:\*{1,3}|_{1,3})?(?:这个[ \t]*)?(` + opaqueChineseEntityLabelPattern + `)[ \t]*(?:的[ \t]*)?(?:ID|标识符?)[ \t]*(?:\*{1,3}|_{1,3})?[ \t]*(?:为|是|[:：=])[ \t]*` + "`?")
	// A common Chinese sentence is "我已经找到了这个文档的 ID：<id>". Retaining only the
	// noun makes that sentence fluent; the generic assignment rule below remains for "文档 ID 为".
	// 中文常见句式是「我已经找到了这个文档的 ID：<id>」。这里只保留「这个文档」，让整句自然；
	// 下方通用规则继续覆盖「文档 ID 为」句式。
	opaqueChineseLocatedIDAssignmentPattern            = regexp.MustCompile(`(?i)(这个)(` + opaqueChineseEntityLabelPattern + `)[ \t]*的[ \t]*(?:ID|标识符?)[ \t]*(?:为|是|[:：=])[ \t]*` + "`?" + opaqueEntityIDPatternSource + "`?")
	opaqueChineseLocatedIDAssignmentPlaceholderPattern = regexp.MustCompile(`(?i)(这个)(` + opaqueChineseEntityLabelPattern + `)[ \t]*的[ \t]*(?:ID|标识符?)[ \t]*(?:为|是|[:：=])[ \t]*` + "`?(?:the requested item|the referenced item)`?")
	// Models sometimes omit the noun and say only "找到了确切 ID：<id>". Replace the
	// machine-value assignment with "确切文档" rather than leaving a bare ID label or placeholder.
	// 模型有时省略实体名，只写「找到了确切 ID：<id>」。改成「确切文档」，不留下裸 ID 标签。
	opaqueChineseExactIDAssignmentPattern            = regexp.MustCompile(`(?i)((?:确切|准确))[ \t]*(?:的[ \t]*)?(?:ID|标识符?)[ \t]*(?:为|是|[:：=])[ \t\r\n]*[\x60"]?` + opaqueEntityIDPatternSource + `[\x60"]?`)
	opaqueChineseExactIDAssignmentPlaceholderPattern = regexp.MustCompile(`(?i)((?:确切|准确))[ \t]*(?:的[ \t]*)?(?:ID|标识符?)[ \t]*(?:为|是|[:：=])[ \t\r\n]*[\x60"]?(?:the requested item|the referenced item)[\x60"]?`)
	opaqueChineseExactIDAssignmentPrefixPattern      = regexp.MustCompile(`(?i)((?:确切|准确))[ \t]*(?:的[ \t]*)?(?:ID|标识符?)[ \t]*(?:为|是|[:：=])[ \t\r\n]*[\x60"]?`)
	// English reasoning uses the same assignment grammar, e.g. "I found the document ID: <id>".
	// Replace the machine-value clause with the already meaningful entity noun instead of exposing
	// the internal placeholder in the reasoning stream.
	// 英文 reasoning 也会写「I found the document ID: <id>」。只保留已有的人话实体名，不能把内部
	// placeholder 带进 reasoning 流。
	opaqueEnglishIDAssignmentPattern            = regexp.MustCompile(`(?i)(\bthe\s+(?:exact\s+)?` + opaqueEnglishEntityLabelPattern + `)[ \t]+ID[ \t]*(?:is|was|[:：=])[ \t]*[\x60"]?` + opaqueEntityIDPatternSource + `[\x60"]?`)
	opaqueEnglishIDAssignmentPlaceholderPattern = regexp.MustCompile(`(?i)(\bthe\s+(?:exact\s+)?` + opaqueEnglishEntityLabelPattern + `)[ \t]+ID[ \t]*(?:is|was|[:：=])[ \t]*[\x60"]?(?:the requested item|the referenced item)[\x60"]?`)
	opaqueEnglishIDAssignmentPrefixPattern      = regexp.MustCompile(`(?i)(\bthe\s+(?:exact\s+)?` + opaqueEnglishEntityLabelPattern + `)[ \t]+ID[ \t]*(?:is|was|[:：=])[ \t]*[\x60"]?`)
	// The compact English equivalent is "I found the exact ID: <id>". Retain the useful
	// noun while removing the unavailable machine value.
	// 英文紧凑句式「I found the exact ID: <id>」也只保留有用的实体名。
	opaqueEnglishExactIDAssignmentPattern            = regexp.MustCompile(`(?i)(\b(?:the\s+)?exact)[ \t]+ID[ \t]*(?:is|was|[:：=])[ \t\r\n]*[\x60"]?` + opaqueEntityIDPatternSource + `[\x60"]?`)
	opaqueEnglishExactIDAssignmentPlaceholderPattern = regexp.MustCompile(`(?i)(\b(?:the\s+)?exact)[ \t]+ID[ \t]*(?:is|was|[:：=])[ \t\r\n]*[\x60"]?(?:the requested item|the referenced item)[\x60"]?`)
	opaqueEnglishExactIDAssignmentPrefixPattern      = regexp.MustCompile(`(?i)(\b(?:the\s+)?exact)[ \t]+ID[ \t]*(?:is|was|[:：=])[ \t\r\n]*[\x60"]?`)
	// Reasoning can use a pronoun instead of the entity noun: "I found its ID: <id>". Since the
	// surrounding sentence identifies the document, retain that human referent and remove the ID.
	// reasoning 有时用代词写「I found its ID: <id>」；上下文已指明文档，保留人话指代并删掉 ID。
	opaqueEnglishItsIDAssignmentPattern            = regexp.MustCompile(`(?i)(\b(?:found|located|identified)[ \t]+)its[ \t]+ID[ \t]*(?:is|was|[:：=])[ \t\r\n]*[\x60"]?` + opaqueEntityIDPatternSource + `[\x60"]?`)
	opaqueEnglishItsIDAssignmentPlaceholderPattern = regexp.MustCompile(`(?i)(\b(?:found|located|identified)[ \t]+)its[ \t]+ID[ \t]*(?:is|was|[:：=])[ \t\r\n]*[\x60"]?(?:the requested item|the referenced item)[\x60"]?`)
	opaqueEnglishItsIDAssignmentPrefixPattern      = regexp.MustCompile(`(?i)(\b(?:found|located|identified)[ \t]+)its[ \t]+ID[ \t]*(?:is|was|[:：=])[ \t\r\n]*[\x60"]?`)
	// A model may echo tool arguments as JSON inside reasoning. Keep the field shape for
	// readability, but never put an opaque value or the internal placeholder in that text.
	// reasoning 里的伪 JSON 参数保留字段形状，但不能把 opaque 值或内部 placeholder 带出去。
	opaqueJSONIDFieldPattern            = regexp.MustCompile(`(?i)([\x60"]id[\x60"][ \t]*:[ \t]*[\x60"])(` + opaqueEntityIDPatternSource + `)([\x60"])`)
	opaqueJSONIDFieldPlaceholderPattern = regexp.MustCompile(`(?i)([\x60"]id[\x60"][ \t]*:[ \t]*[\x60"])(?:the requested item|the referenced item)([\x60"])`)
	opaqueJSONIDFieldPrefixPattern      = regexp.MustCompile(`(?i)[\x60"]id[\x60"][ \t]*:[ \t]*[\x60"]`)
	// Tool results often contain several machine ID fields, not only an exact "id" key.
	// Keep the JSON shape while replacing opaque IDs and timestamps in user-facing reasoning.
	// 工具结果常有 functionId/versionId/startedAt 等命名字段；保留 JSON 结构，清掉值形态的内部占位符。
	opaqueJSONNamedIDFieldPattern              = regexp.MustCompile(`(?i)([\x60"])((?:[A-Za-z][A-Za-z0-9]+)(?:id|identifier))([\x60"][ \t]*:[ \t]*[\x60"])(` + opaqueEntityIDPatternSource + `)([\x60"])`)
	opaqueJSONNamedIDFieldPlaceholderPattern   = regexp.MustCompile(`(?i)([\x60"])((?:[A-Za-z][A-Za-z0-9]+)(?:id|identifier))([\x60"][ \t]*:[ \t]*[\x60"])(?:the requested item|the referenced item)([\x60"])`)
	opaqueJSONNamedTimeFieldPlaceholderPattern = regexp.MustCompile(`(?i)([\x60"])((?:[A-Za-z][A-Za-z0-9]+)(?:at|time|timestamp))([\x60"][ \t]*:[ \t]*[\x60"])(?:the recorded time|相应时间)([\x60"])`)
	opaqueJSONNamedFieldPrefixPattern          = regexp.MustCompile(`(?i)[\x60"](?:[A-Za-z][A-Za-z0-9]+)(?:id|identifier|at|time|timestamp)[\x60"][ \t]*:[ \t]*[\x60"]`)
	// Standalone reasoning fields such as "- id: <id>" are machine plumbing, not useful prose.
	// Remove the whole field both before and after the generic ID pass so actual and placeholder
	// variants behave identically.
	// reasoning 中独立的「- id: <id>」是机器参数而不是人话；在通用 ID 脱敏前后都整行移除。
	opaqueIDFieldPattern            = regexp.MustCompile(`(?m)^[ \t]*[-*]?[ \t]*(?:id|identifier)[ \t]*:[ \t]*[\x60"]?` + opaqueEntityIDPatternSource + `[\x60"]?[ \t]*(?:\r?\n|$)`)
	opaqueIDFieldPlaceholderPattern = regexp.MustCompile(`(?m)^[ \t]*[-*]?[ \t]*(?:id|identifier)[ \t]*:[ \t]*[\x60"]?(?:the requested item|the referenced item)[\x60"]?[ \t]*(?:\r?\n|$)`)
	// Markdown emphasis can sit between the noun and the opaque target, e.g. "workflow **wf_…**".
	// Keep the emphasis attached to the meaningful noun by removing only the decoration around the
	// placeholder. The plain pattern above intentionally handles "**workflow wf_…**" so its outer
	// emphasis remains intact.
	opaqueEntityNounDecoratedPlaceholderPattern = regexp.MustCompile(
		`(?i)\b(the\s+)?(workflow|function|handler|agent|trigger|conversation|document|skill|workspace|message|flowrun|run|attachment)\s+(?:\*{1,3}|_{1,3}|` + "`" + `)\s*` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `\s*(?:\*{1,3}|_{1,3}|` + "`" + `)([[:space:][:punct:]]|$)`)
	opaqueEntityIDClausePrefixPattern = regexp.MustCompile(`(?i)(?:^|[ \t]+)(?:with|using|having)[ \t]+(?:the[ \t]+)?(?:id|identifier)[ \t]+[\x60"]?$`)
	// Keep the introducer one token earlier too. A provider can emit "with " and only put
	// "id <opaque value>" in the next delta; releasing the first fragment loses the context
	// needed to remove the whole machine-value clause.
	// 还要把引导语提前一个 token 暂存。provider 可能先发出「with 」，下一帧才发「id <opaque value>」；
	// 若先放出前半段，后续就失去删除整段机器值所需的上下文。
	opaqueEntityIDClauseOpenPrefixPattern = regexp.MustCompile(`(?i)(?:^|[ \t]+)(?:with|using|having)[ \t]+$`)
	// Preserve the grammar of sentences that introduce an opaque identifier, e.g.
	// "The ID `fr_…` does not exist". Replacing only the identifier would produce
	// "The ID the referenced item"; the adjacent tool card still contains the exact ID.
	opaqueIDSubjectPattern = regexp.MustCompile(`(?i)\bthe\s+id\s+` + "`?" + opaqueEntityIDPatternSource + "`?")
	// Keep the introducer pending when the provider splits immediately before the ID.
	opaqueIDSubjectPrefixPattern = regexp.MustCompile(`(?i)(?:\bthe\s+id\s+` + "`?" + `)$`)
	// Models also introduce a target as "The flowrun ID `fr_…`" or
	// "The flowrun with ID `fr_…`". Replace the
	// whole subject prefix so the result remains a complete noun phrase.
	opaqueTypedIDSubjectPattern       = regexp.MustCompile(`(?i)\b(the\s+)?(flow\s+run|flowrun|workflow|function|handler|agent|trigger|conversation|document|skill|workspace|message|run|attachment)\s+(?:with\s+)?id\s+` + "`?" + opaqueEntityIDPatternSource + "`?")
	opaqueTypedIDSubjectPrefixPattern = regexp.MustCompile(`(?i)(?:\bthe\s+)?(?:flow\s+run|flowrun|workflow|function|handler|agent|trigger|conversation|document|skill|workspace|message|run|attachment)\s+(?:with\s+)?id\s+` + "`?" + `$`)
	// Media reasoning often uses a possessive label instead of the generic "The ID …" form.
	// Replace the whole sentence fragment before the generic id pass so it cannot become
	// "The attachment ID is the requested item" after streaming redaction.
	// 媒体 reasoning 常用带类型的 label。先整体改写再走通用 ID 脱敏，避免流式后变成坏占位句。
	opaqueAttachmentIDAssignmentPattern       = regexp.MustCompile(`(?i)\b((?:the\s+)?(?:attachment|image|media))\s+id\s+(?:is|=|:)\s+` + "[\x60\"]?" + `(?:att_[A-Za-z0-9]+|` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `|` + regexp.QuoteMeta(legacyEntityPlaceholder) + `)` + "[\x60\"]?")
	opaqueAttachmentIDAssignmentPrefixPattern = regexp.MustCompile(`(?i)\b(?:the\s+)?(?:attachment|image|media)\s+id\s+(?:is|=|:)\s*`)
	// The model may compare the two media outputs by repeating their opaque ids. Keep the
	// comparison meaning without inventing a placeholder value in the user-facing stream.
	// 模型可能在比较两件媒体时重复 opaque id；保留「已就绪」事实，不伪造 placeholder 值。
	opaqueMediaAttachmentAssignmentPattern       = regexp.MustCompile(`(?i)\b((?:the\s+)?(?:original|edited|new|updated)\s+(?:attachment|one))\s+(?:is|was)\s+` + "[\x60\"]?" + `(?:att_[A-Za-z0-9]+|` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `|` + regexp.QuoteMeta(legacyEntityPlaceholder) + `)` + "[\x60\"]?")
	opaqueMediaAttachmentAssignmentPrefixPattern = regexp.MustCompile(`(?i)\b(?:the\s+)?(?:original|edited|new|updated)\s+(?:attachment|one)\s+(?:is|was)\s*`)
	flowRunSubjectPrefixPattern                  = regexp.MustCompile(`(?i)\b(?:the\s+)?flow\s+$`)
	opaqueReportForPattern                       = regexp.MustCompile(`(?i)\b(flow\s+run|flowrun|workflow|function|handler|agent|trigger|conversation|document|skill|workspace|message|run|attachment)\s+report\s+for\s+` + "`?" + opaqueEntityIDPatternSource + "`?")
	opaqueReportForPrefixPattern                 = regexp.MustCompile(`(?i)(?:\b(?:flow\s+run|flowrun|workflow|function|handler|agent|trigger|conversation|document|skill|workspace|message|run|attachment)\s+report\s+for\s+)$`)
	// A model may put the opaque run id in a Markdown table. Replacing only the cell with a generic
	// placeholder makes the table look like a broken template; retain the semantic row instead.
	//
	// 模型可能把 opaque run id 放进 Markdown 表格。只把单元格替换成通用 placeholder 会像坏模板；保留语义行。
	opaqueFlowrunIDTableRowPattern = regexp.MustCompile(`(?im)^[ \t]*\|[^\r\n|]*(?:flow\s*run|flowrun|run)[ \t]*id[^\r\n|]*\|[^\r\n|]*` + "`?" + `fr_[A-Za-z0-9]+` + "`?" + `[^\r\n|]*\|[ \t]*$`)
	opaqueReportDecoratedPattern   = regexp.MustCompile(`(?i)\b(flow\s+run|flowrun|workflow|function|handler|agent|trigger|conversation|document|skill|workspace|message|run|attachment)\s+report\s+for\s+(?:\*{1,3}|_{1,3}|` + "`" + `)*` + opaqueEntityIDPatternSource + `(?:\*{1,3}|_{1,3}|` + "`" + `)*`)
	// A webhook endpoint contains an opaque trigger id but is also an executable user-facing value.
	// Redacting only the id would leave a URL that looks copyable but cannot work.
	opaqueWebhookEndpointPattern            = regexp.MustCompile(`(?im)^[ \t]*(?:POST[ \t]+)?(?:https?://[^ \t/]+)?/api/v1/webhooks/` + "`?" + `trg_[A-Za-z0-9]+` + "`?" + `/[^\r\n \t]+[ \t]*$`)
	opaqueWebhookEndpointPlaceholderPattern = regexp.MustCompile(`(?im)^[ \t]*(?:POST[ \t]+)?(?:https?://[^ \t/]+)?/api/v1/webhooks/` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?" + `/[^\r\n \t]+[ \t]*$`)
	opaqueFlowrunReportTitlePattern         = regexp.MustCompile(`(?i)\b(flow\s*run|flowrun)\s+report\s*[:\x{2014}\-]\s*(?:\*{1,3}|_{1,3}|` + "`" + `)*fr_[A-Za-z0-9]+(?:\*{1,3}|_{1,3}|` + "`" + `)*`)
	opaqueFlowrunTitlePattern               = regexp.MustCompile(`(?i)\b(flow\s*run|flowrun)\s*:\s*(?:\*{1,3}|_{1,3}|` + "`" + `)*fr_[A-Za-z0-9]+(?:\*{1,3}|_{1,3}|` + "`" + `)*`)
	opaqueFlowrunAssignmentPattern          = regexp.MustCompile(`(?i)\bflowrunId\s*=\s*(?:\*{1,3}|_{1,3}|` + "`" + `)*fr_[A-Za-z0-9]+(?:\*{1,3}|_{1,3}|` + "`" + `)*`)
	opaqueVersionTableRowPattern            = regexp.MustCompile(`(?im)^[ \t]*\|[^\r\n|]*version[^\r\n|]*\|[^\r\n|]*wfv_[A-Za-z0-9]+[^\r\n|]*\|[ \t]*$`)
	opaquePinnedRefsTableRowPattern         = regexp.MustCompile(`(?im)^[ \t]*\|[^\r\n|]*pinned\s+refs[^\r\n|]*\|[^\r\n|]*(?:apf|apfv)_[A-Za-z0-9]+[^\r\n|]*\|[ \t]*$`)
	// Models may already have applied the neutral placeholder before the server-side redactor sees
	// the final text. Normalize those structured rows too, otherwise the placeholder leaks as prose.
	//
	// 模型可能在服务端 redactor 之前就先用了中性 placeholder；结构化行也要归一化，否则 placeholder 会漏到画面。
	opaqueFlowrunChineseWorkflowListPattern            = regexp.MustCompile(`(?m)^([ \t]*[-*][ \t]*)` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?" + `([ \t]*-[ \t]*)工作流[ \t]*` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?" + `([^\r\n]*)$`)
	opaqueFlowrunChineseStatusListPattern              = regexp.MustCompile(`(?m)^([ \t]*(?:[-*]|[0-9]+[.)])[ \t]*)` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?" + `([ \t]*-[^\r\n]*(?:running|failed|completed|状态)[^\r\n]*)$`)
	opaqueFlowrunStatusListPlaceholderPattern          = regexp.MustCompile(`(?im)^([ \t]*[-*][ \t]*(?:completed|failed|running|cancelled)[ \t]*:[ \t]*[0-9]+)[ \t]*\([ \t]*` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `(?:[ \t]*,[ \t]*` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `)*[ \t]*\)[ \t]*$`)
	opaqueFlowrunStatusLinePattern                     = regexp.MustCompile(`(?im)^([ \t]*[-*][ \t]*(?:completed|failed|running|cancelled)[ \t]*:[^\r\n]*)$`)
	opaqueFlowrunStatusPlaceholderRunPattern           = regexp.MustCompile(regexp.QuoteMeta(opaqueEntityPlaceholder) + `(?:[ \t]*,[ \t]*` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `)*[ \t]*(?:-[ \t]*)?`)
	opaqueFlowrunStatusEmptyDetailPattern              = regexp.MustCompile(`[ \t]*\([ \t]*\)[ \t]*$`)
	opaqueFlowrunReportTitlePlaceholderPattern         = regexp.MustCompile(`(?i)\b(flow\s*run|flowrun)\s+report\s*[:\x{2014}\-]\s*(?:\*{1,3}|_{1,3}|` + "`" + `)*` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `(?:\*{1,3}|_{1,3}|` + "`" + `)*`)
	opaqueFlowrunReportForPlaceholderPattern           = regexp.MustCompile(`(?i)\b(flow\s*run|flowrun)\s+report\s+for\s+(?:\*{1,3}|_{1,3}|` + "`" + `)*` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `(?:\*{1,3}|_{1,3}|` + "`" + `)*`)
	opaqueFlowrunTitlePlaceholderPattern               = regexp.MustCompile(`(?i)\b(flow\s*run|flowrun)\s*:\s*(?:\*{1,3}|_{1,3}|` + "`" + `)*` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `(?:\*{1,3}|_{1,3}|` + "`" + `)*`)
	opaqueFlowrunAssignmentPlaceholderPattern          = regexp.MustCompile(`(?i)\bflowrunId\s*=\s*(?:\*{1,3}|_{1,3}|` + "`" + `)*` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `(?:\*{1,3}|_{1,3}|` + "`" + `)*`)
	opaqueFlowrunIDPlaceholderTableRowPattern          = regexp.MustCompile(`(?im)^[ \t]*\|[^\r\n|]*(?:flow\s*run|flowrun|run)[ \t]*id[^\r\n|]*\|[^\r\n|]*(?:` + "`" + `)?` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `(?:` + "`" + `)?[^\r\n|]*\|[ \t]*$`)
	opaqueVersionPlaceholderTableRowPattern            = regexp.MustCompile(`(?im)^[ \t]*\|[^\r\n|]*version[^\r\n|]*\|[^\r\n|]*(?:` + "`" + `)?` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `(?:` + "`" + `)?[^\r\n|]*\|[ \t]*$`)
	opaqueRefPlaceholderTableRowPattern                = regexp.MustCompile(`(?im)^[ \t]*\|[^\r\n|]*\bref[^\r\n|]*\|[^\r\n|]*(?:` + "`" + `)?` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `(?:` + "`" + `)?[^\r\n|]*\|[ \t]*$`)
	opaqueNodeRecordPlaceholderTableRowPattern         = regexp.MustCompile(`(?im)^[ \t]*\|[^\r\n|]*node\s+record\s+id[^\r\n|]*\|[^\r\n|]*(?:` + "`" + `)?` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `(?:` + "`" + `)?[^\r\n|]*\|[ \t]*$`)
	opaquePinnedRefsPlaceholderTableRowPattern         = regexp.MustCompile(`(?im)^[ \t]*\|[ \t]*(?:` + "`" + `)?` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `(?:` + "`" + `)?[ \t]*\|[ \t]*(?:` + "`" + `)?` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `(?:` + "`" + `)?[ \t]*\|[ \t]*$`)
	opaquePinnedRefAnnotatedPlaceholderTableRowPattern = regexp.MustCompile(`(?im)^[ \t]*\|[ \t]*(?:` + "`" + `)?` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `(?:` + "`" + `)?[ \t]*\([^\r\n|]*\)[ \t]*\|[ \t]*(?:` + "`" + `)?` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `(?:` + "`" + `)?[ \t]*\|[ \t]*$`)
	opaquePinnedRefsHeadingPattern                     = regexp.MustCompile(`(?im)^[ \t]*\*{0,2}pinned\s+refs:?\*{0,2}[ \t]*$`)
	opaquePinnedRefsBulletPattern                      = regexp.MustCompile(`(?im)^[ \t]*-[^\r\n]*(?:approval form|pinned reference)[^\r\n]*` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `[^\r\n]*$`)
	opaquePinnedRefsPlaceholderBulletPattern           = regexp.MustCompile(`(?im)^[ \t]*-[^\r\n]*` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `[^\r\n]*(?:->|\x{2192})[^\r\n]*` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `[^\r\n]*$`)
	opaquePinnedRefsNaturalBulletPattern               = regexp.MustCompile(`(?im)^[ \t]*-[^\r\n]*(?:approval form|pinned reference)[^\r\n]*` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `[^\r\n]*(?:pinned to|version)[^\r\n]*` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `[^\r\n]*$`)
	opaquePinnedRefsNaturalSentencePattern             = regexp.MustCompile(`(?im)^[ \t]*(?:\*{0,2}pinned\s+refs:?\*{0,2}[ \t]*)?approval form[ \t]+` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?" + `[ \t]+pinned\s+to\s+version[ \t]+` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?" + `[.]?[ \t]*$`)
	opaqueFlowrunOverviewIDPlaceholderPattern          = regexp.MustCompile(`(?im)^[ \t]*-[ \t]*id:[ \t]+` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?" + `[ \t]*$`)
	opaqueFlowrunOverviewVersionPlaceholderPattern     = regexp.MustCompile(`(?im)^[ \t]*-[ \t]*version:[ \t]+` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?" + `[ \t]*$`)
	opaqueFlowrunSummaryTargetPattern                  = regexp.MustCompile(`(?im)^([ \t]*(?:flow\s*run|flowrun|run)[ \t]+summary)[ \t]+for[ \t]+(?:` + "`?" + opaqueEntityIDPatternSource + "`?" + `|` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `|` + regexp.QuoteMeta(legacyEntityPlaceholder) + `|the requested run|the supplied run(?: ID)?)[ \t]*:?[ \t]*$`)
	opaqueFlowrunSummaryForPrefixPattern               = regexp.MustCompile(`(?i)(?:\bflow\s*run|\bflowrun|\brun)[ \t]+summary[ \t]+for[ \t]+(?:the[ \t]+)?$`)
	opaquePinnedReferenceNaturalPattern                = regexp.MustCompile(`(?im)^[ \t]*pinned[ \t]+reference:[^\r\n]*(?:pinned[ \t]+ref|pinned[ \t]+to|version)[^\r\n]*(?:\bfnv|wfv|apfv|hdv)_[A-Za-z0-9]+[^\r\n]*$`)
	// A model can independently choose the neutral phrase, especially after a failed get_flowrun.
	// Rewrite that phrase in the flowrun-specific grammar so the final answer reads naturally.
	opaqueFlowrunTargetPlaceholderPattern  = regexp.MustCompile(`(?i)(\bget_flowrun\b` + "`?" + `\s+for\s+)` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?")
	opaqueFlowrunIDPlaceholderPattern      = regexp.MustCompile(`(?i)(?:\bwith\s+)?flowrunId\s+` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?")
	opaqueFlowrunMissingIDPattern          = regexp.MustCompile(`(?i)(\bthe\s+id\s+doesn['’]t\s+exist\s+[—-]\s+)` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?(\\s+appears)")
	opaqueFlowrunNoMatchPattern            = regexp.MustCompile(`(?i)(\bthere\s+is\s+no\s+workflow\s+run)\s+with\s+` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?")
	opaqueFlowrunRequestedIDRowPattern     = regexp.MustCompile(`(?im)^[ \t]*\|[^\r\n|]*(?:requested\s+id|flow\s*run\s*id)[^\r\n|]*\|[ \t]*` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?" + `[ \t]*\|[ \t]*$`)
	opaqueFlowrunIDFieldPlaceholderPattern = regexp.MustCompile(`(?im)^[ \t]*\*{0,2}flowrun\s+id\*{0,2}:\*{0,2}[ \t]+` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?" + `[ \t]*$`)
	// A placeholder must never survive in an ordinary labeled field either. Removing the whole
	// field is more honest than showing "ID: -" or inventing a value; the adjacent tool card remains
	// the exact-value surface.
	// 普通的带标签字段也不能留下 placeholder。整行移除比显示「ID: -」或编造值更诚实；精确值仍在相邻工具卡。
	opaquePlaceholderLabeledLinePattern = regexp.MustCompile(`(?im)^[ \t]*(?:[-*][ \t]+|[0-9]+[.)][ \t]+)?(?:\*{0,2}|_{0,2})?(?:id|identifier|path|label|name)(?:\*{0,2}|_{0,2})?[ \t]*:[ \t]*[\x60]?(?:the requested item|the referenced item)[\x60]?[ \t]*(?:\r?\n|$)`)
	// Models also commonly put the colon inside the Markdown emphasis, e.g. `**ID:** value`.
	// Treat that spelling as the same labeled machine field so the placeholder cannot survive the
	// stream or durable close path.
	// 模型也常把冒号放进 Markdown 加粗范围，例如 `**ID:** value`。两种写法都必须视为同一
	// 个带标签机器字段，不能让 placeholder 穿过流式或耐久 close。
	opaquePlaceholderBoldColonLabeledLinePattern = regexp.MustCompile(`(?im)^[ \t]*(?:[-*][ \t]+|[0-9]+[.)][ \t]+)?(?:\*{2}|__)(?:id|identifier|path|label|name):(?:\*{2}|__)[ \t]*[\x60]?(?:the requested item|the referenced item)[\x60]?[ \t]*(?:\r?\n|$)`)
	// A successful create_trigger result has an exact, copyable ID in its adjacent tool card. If the
	// model repeats that value in prose, the global opaque-ID rule must not leave the user with a
	// broken-looking "Trigger ID: the requested item" line; point to the card instead. This is
	// deliberately narrower than the generic ID rule and does not expose the ID in prose.
	// create_trigger 成功结果的精确 ID 在相邻工具卡中可复制。模型若在散文中重复该值，不能留下
	// 坏掉的「Trigger ID: the requested item」；明确指向卡片。此规则刻意收窄，不放开散文泄露。
	opaqueTriggerIDPlaceholderLinePattern = regexp.MustCompile(`(?im)^[ \t]*(?:[-*][ \t]+|[0-9]+[.)][ \t]+)?(?:\*{2}|__)?(?:trigger[ \t]+id|triggerid|触发器[ \t]*id|触发器标识)(?:\*{2}|__)?[ \t]*[:：][ \t]*(?:\*{2}|__)?[ \t]*[\x60]?(?:the requested item|the referenced item)[\x60]?[ \t]*\r?$`)
	// Version IDs are opaque too. Remove the whole field, including any model-added parenthetical,
	// instead of showing a value-shaped placeholder in assistant prose.
	// 版本 ID 同样是不透明机器值。整行连同模型附加的括号说明一起移除，不能渲染成像真实值的占位符。
	opaqueVersionIDPlaceholderLinePattern = regexp.MustCompile(`(?im)^[ \t]*(?:[-*][ \t]+|[0-9]+[.)][ \t]+)?(?:\*{0,2}|_{0,2})?version[ \t]+(?:id|identifier)(?:\*{0,2}|_{0,2})?[ \t]*:[ \t]*[\x60]?(?:the requested item|the referenced item)[\x60]?[^\r\n]*\r?$`)
	opaqueVersionIDActualLinePattern      = regexp.MustCompile(`(?im)^[ \t]*(?:[-*][ \t]+|[0-9]+[.)][ \t]+)?(?:\*{0,2}|_{0,2})?version[ \t]+(?:id|identifier)(?:\*{0,2}|_{0,2})?[ \t]*:[ \t]*[\x60"]?` + opaqueEntityIDPatternSource + `[\x60"]?[^\r\n]*(?:\r?\n|$)`)
	// 紧凑的中文执行卷宗会把机器字段写成「执行ID: …」「开始时间: …」。这些字段的精确值
	// 已经在相邻结构化卷宗卡中可复制；助手正文整行移除，不能把内部 placeholder 或伪时间留给用户。
	// 规则同时覆盖真实 opaque ID、旧 placeholder 和通用时间 placeholder。
	opaqueChineseAuditMachineFieldPattern             = regexp.MustCompile(`(?im)^[ \t]*(?:[-*•][ \t]+|[0-9]+[.)][ \t]+)?(?:\*{0,2}|_{0,2})?(?:(?:执行|版本|会话|消息|工具调用|节点|运行)[ \t]*(?:ID|标识符?)|(?:记录[ \t]*)?(?:开始|结束|创建|更新)[ \t]*时间)(?:\*{0,2}|_{0,2})?[ \t]*[:：][ \t]*[\x60"]?(?:(?:` + opaqueEntityIDPatternSource + `)|the requested item|the referenced item|the recorded time|相应时间)[\x60"]?[^\r\n]*(?:\r?\n|$)`)
	opaqueChineseAuditMachineFieldContinuationPattern = regexp.MustCompile(`(?im)^[ \t]*(?:[-*•][ \t]+|[0-9]+[.)][ \t]+)?(?:\*{0,2}|_{0,2})?(?:(?:执行|版本|会话|消息|工具调用|节点|运行)[ \t]*(?:ID|标识符?)|(?:记录[ \t]*)?(?:开始|结束|创建|更新)[ \t]*时间)(?:\*{0,2}|_{0,2})?[ \t]*[:：][ \t]*\r?\n[ \t]*[\x60"]?(?:(?:` + opaqueEntityIDPatternSource + `)|the requested item|the referenced item|the recorded time|相应时间)[\x60"]?[ \t]*(?:\r?\n|$)`)
	// The same fields can appear inline in Chinese reasoning, e.g. "我得到了执行 ID: …".
	// Keep the sentence useful while routing the exact value to the adjacent execution card.
	// 同一字段也可能以内嵌句式出现在中文 reasoning 中，例如「我得到了执行 ID: …」；保留事实，
	// 将精确值明确指向相邻执行卡，不能把中性 placeholder 留在用户面。
	opaqueChineseAuditInlineMachineFieldPattern         = regexp.MustCompile(`(?im)([\p{Han}][^\r\n]{0,48}?)(?:执行|版本|会话|消息|工具调用|节点|运行)[ \t]*(?:ID|标识符?)[ \t]*[:：=][ \t]*[\x60"]?(?:(?:` + opaqueEntityIDPatternSource + `)|the requested item|the referenced item|the recorded time|相应时间)[\x60"]?`)
	opaqueChineseBareExecutionIDPattern                 = regexp.MustCompile(`(?i)(执行[ \t]*(?:ID|标识符?))[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item)[\x60"]?`)
	opaqueChineseLocatedPlaceholderParentheticalPattern = regexp.MustCompile(`(?i)[（(][^（）()\r\n]*(?:找到|找到了|已定位)[^（）()\r\n]*(?:the requested item|the referenced item)[^（）()\r\n]*[）)]`)
	// A timing placeholder row is unambiguous even when its heading/table header arrived in a
	// previous provider chunk. Remove it without requiring the surrounding table context.
	// 「开始时间/结束时间 | 相应时间」本身已足够判定为伪字段；即使标题跨 provider chunk，也不能闪出。
	opaqueChineseDossierTimingPlaceholderRowPattern = regexp.MustCompile(`(?im)^[ \t]*\|[^\r\n|]*(?:开始时间|结束时间)[^\r\n|]*\|[^\r\n|]*相应时间[^\r\n|]*\|[ \t]*(?:\r?\n|$)`)
	opaqueChineseDossierFieldLinePattern            = regexp.MustCompile(`(?im)^([ \t]*[-*•]?[ \t]*)([*_]{1,3})?((?:函数[ \t]*版本|执行|函数|版本|会话|对话|消息|工具调用|节点|运行)[ \t]*(?:ID|标识符?))([*_]{1,3})?([：:][ \t]*)([^\r\n]*)$`)
	// Markdown also puts the colon inside the bold label: "**执行 ID:** value". This is a
	// separate shape from "**执行 ID**: value" and must be removed as one field before it can
	// reach either a live delta or the durable close snapshot.
	// Markdown 还会把冒号放进粗体标签：「**执行 ID:** 值」。它与「**执行 ID**: 值」是两种
	// 语法形态，必须整行移除，不能让字段或 placeholder 进入实时 delta/耐久快照。
	opaqueChineseAuditBoldColonMachineFieldPattern = regexp.MustCompile(`(?im)^[ \t]*(?:[-*•][ \t]+|[0-9]+[.)][ \t]+)?(?:\*{2}|__)(?:(?:执行|函数|版本|会话|消息|工具调用|节点|运行)[ \t]*(?:ID|标识符?)|(?:记录[ \t]*)?(?:开始|结束|创建|更新)[ \t]*时间)[:：](?:\*{2}|__)[ \t]*[\x60"]?(?:(?:` + opaqueEntityIDPatternSource + `)|the requested item|the referenced item|the recorded time|相应时间)[\x60"]?[^\r\n]*(?:\r?\n|$)`)
	// A model can use a bare Chinese "ID 为 …" after it has already named the entity.
	// Remove only the unavailable assignment while retaining the readable sentence.
	opaqueChineseBareIDAssignmentPattern            = regexp.MustCompile(`(?i)([\p{Han}][^。\r\n]{0,40}?[ \t]*)(?:ID|标识符)[ \t]*(?:为|是)[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item)[\x60"]?`)
	opaqueChineseBareIDAssignmentPrefixPattern      = regexp.MustCompile(`(?i)([\p{Han}][^。\r\n]{0,40}?[ \t]*)(?:ID|标识符)[ \t]*(?:为|是)[ \t]*[\x60"]?`)
	opaqueChineseBareIDPlaceholderAssignmentPattern = regexp.MustCompile(`(?i)([\p{Han}][^。\r\n]{0,40}?[ \t]*)(?:ID|标识符)[ \t]*(?:为|是)[ \t]*[\x60"]?(?:the requested item|the referenced item)[\x60"]?`)
	opaqueChineseGenericIDAssignmentPattern         = regexp.MustCompile(`(?i)\b(ID|标识符)[ \t]*(?:为|是)[ \t]*[\x60"]?(?:the requested item|the referenced item)[\x60"]?`)
	opaqueChineseGenericIDAssignmentPrefixPattern   = regexp.MustCompile(`(?i)\b(ID|标识符)[ \t]*(?:为|是)[ \t]*[\x60"]?`)
	opaqueChineseLocatedBareIDPattern               = regexp.MustCompile(`(?i)((?:找到|找到了|定位到|已定位)[^。\r\n]{0,80}?)(?:ID|标识符)[ \t]*(?:为|是|[:：=])[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item)[\x60"]?`)
	opaqueChineseLocatedBareIDPlaceholderPattern    = regexp.MustCompile(`(?i)((?:找到|找到了|定位到|已定位)[^。\r\n]{0,80}?)(?:ID|标识符)[ \t]*(?:为|是|[:：=])[ \t]*[\x60"]?(?:the requested item|the referenced item)[\x60"]?`)
	// Chinese failure explanations often refer to an opaque argument without an assignment verb,
	// e.g. "传入 ID `fn_…` 后". Keep the sentence readable by pointing at the structured card rather
	// than exposing either the real value or the internal placeholder.
	// 中文失败说明常在没有赋值动词时复述 opaque 参数，例如「传入 ID `fn_…` 后」。保留句意并指向结构化卡片，
	// 不让真实值或内部 placeholder 进入用户正文。
	opaqueChineseIDReferencePattern       = regexp.MustCompile(`(?i)(传入)(?:了)?[ \t]*(?:ID|标识符)[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item)[\x60"]?[ \t]*(?:后)?`)
	opaqueChineseIDReferencePrefixPattern = regexp.MustCompile(`(?i)(传入)(?:了)?[ \t]*(?:ID|标识符)[ \t]*[\x60"]?$`)
	// A model may qualify the entity before the field name: "传入了一个不存在的函数 ID <value>".
	// The Chinese qualifier is already meaningful; remove only the machine-field suffix instead of
	// letting the generic placeholder fallback turn it into "函数 ID 该目标".
	// 模型可能在字段名前加中文限定词：「传入了一个不存在的函数 ID <值>」。限定词本身有意义，
	// 只去掉机器字段后缀，不能让通用兜底把它变成「函数 ID 该目标」。
	opaqueChineseQualifiedIDReferencePattern = regexp.MustCompile(`(?i)(传入(?:了)?[ \t]*[\p{Han}][^，。\r\n]{0,40}?)[ \t]+(?:ID|标识符)[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item|该目标)[\x60"]?`)
	// Some answers move the placeholder before the label: "传入 <value> 这个 ID". Keep the
	// ordinary Chinese sentence and drop only the unavailable value.
	// 有些回答把 placeholder 放在字段名前：「传入 <值> 这个 ID」；保留普通中文句子，只去掉不可用值。
	opaqueChineseTargetBeforeIDPattern = regexp.MustCompile(`(?i)(传入(?:了)?)[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item|该目标)[\x60"]?[ \t]*(这个|该)[ \t]*(?:ID|标识符)`)
	// Another hosted-model spelling omits the "ID" label: "调用 get_function 并传入 <value> 后".
	// Removing only the value leaves a visible redaction artifact, so collapse the conjunction into
	// the natural completed action sentence.
	// 托管模型还可能省略「ID」写成「调用 get_function 并传入 <值> 后」；只删值会留下脱敏痕迹，
	// 因此把这个并列短语收敛成自然的已完成动作句。
	opaqueChineseConjoinedReferencePattern = regexp.MustCompile(`(?i)并[ \t]*传入(?:了)?[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item|该目标)[\x60"]?[ \t]*后`)
	// The same sentence may omit the conjunction: "调用 get_function 传入 <value> 后". Bind the
	// rewrite to the known tool name so ordinary Chinese prose using "传入" remains untouched.
	// 同一句也可能省略「并」：「调用 get_function 传入 <值> 后」。规则绑定已知工具名，避免误伤普通中文 prose。
	opaqueChineseToolReferencePattern      = regexp.MustCompile(`(?i)([\x60]?get_function[\x60]?)[ \t]*(?:并[ \t]*)?传入(?:了)?[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item|该目标)[\x60"]?[ \t]*后`)
	opaqueChineseToolReferenceStartPattern = regexp.MustCompile(`(?i)[\x60]?get_function[\x60]?[ \t]*(?:并[ \t]*)?传入(?:了)?[ \t]*[\x60"]?`)
	// The ID-labelled form needs the same tool-aware rewrite: "get_function 并传入 ID <value> 后"
	// must become a completed action sentence, not "get_function 并传入的目标...".
	// 带 ID 标签的形式也要按工具名整体改写：「get_function 并传入 ID <值> 后」不能留下
	// 「get_function 并传入的目标……」这种脱敏痕迹。
	opaqueChineseToolIDReferencePattern       = regexp.MustCompile(`(?i)([\x60]?get_function[\x60]?)[ \t]*(?:并[ \t]*)?传入(?:了)?[ \t]*(?:ID|标识符)[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item|该目标)[\x60"]?[ \t]*(?:后)?`)
	opaqueChineseToolIDReferencePrefixPattern = regexp.MustCompile(`(?i)([\x60]?get_function[\x60]?)[ \t]*(?:并[ \t]*)?传入(?:了)?[ \t]*(?:ID|标识符)[ \t]*[\x60"]?$`)
	opaqueChineseToolIDReferenceStartPattern  = regexp.MustCompile(`(?i)[\x60]?get_function[\x60]?[ \t]*(?:并[ \t]*)?传入(?:了)?[ \t]*(?:ID|标识符)[ \t]*[\x60"]?`)
	// A model may use an assignment-like tool phrase: "get_function 时传入的 ID 为 <value>".
	// Normalize the whole machine-field clause to a readable target reference.
	// 模型也可能写成「get_function 时传入的 ID 为 <值>」；整段收敛成可读的目标指代。
	opaqueChineseToolIDAssignmentPattern               = regexp.MustCompile(`(?i)([\x60]?get_function[\x60]?)[ \t]*时传入的[ \t]*(?:ID|标识符)[ \t]*(?:为|是|[:：=])[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item|该目标)[\x60"]?`)
	opaqueChineseToolIDAssignmentStartPattern          = regexp.MustCompile(`(?i)[\x60]?get_function[\x60]?[ \t]*时传入的[ \t]*(?:ID|标识符)[ \t]*(?:为|是|[:：=])[ \t]*[\x60"]?`)
	opaqueChineseToolIDAssignmentOpenPrefixPattern     = regexp.MustCompile(`(?i)[\x60]?get_function[\x60]?[ \t]*时传入(?:[ \t]*的)?[ \t]*$`)
	opaqueChineseToolIDTimeReferencePattern            = regexp.MustCompile(`(?i)([\x60]?get_function[\x60]?)[ \t]*时传入的[ \t]*(?:ID|标识符)[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item|该目标|这个输入)[\x60"]?`)
	opaqueChineseToolIDTimeReferenceStartPattern       = regexp.MustCompile(`(?i)[\x60]?get_function[\x60]?[ \t]*时传入的[ \t]*(?:ID|标识符)[ \t]*[\x60"]?`)
	opaqueChineseToolNameBeforeTimeTargetPattern       = regexp.MustCompile(`(?i)([\x60]?get_function[\x60]?)[ \t]*时传入的目标`)
	opaqueChineseTimeTargetBeforePredicatePattern      = regexp.MustCompile(`(?i)时传入的目标[ \t]+(在|不|已|未|并|但|且|，|。)`)
	opaqueChineseToolPlaceholderIDReferencePattern     = regexp.MustCompile(`(?i)([\x60]?get_function[\x60]?)[ \t]*(?:时[ \t]*)?传入了[ \t]*[\x60"]?(?:` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `|` + regexp.QuoteMeta(legacyEntityPlaceholder) + `|该目标)[\x60"]?[ \t]*(?:这个|该)?[ \t]*(?:ID|标识符)`)
	opaqueChineseToolValueBeforeIDPattern              = regexp.MustCompile(`(?i)([\x60]?get_function[\x60]?)[ \t]*(?:时[ \t]*)?传入了[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `|` + regexp.QuoteMeta(legacyEntityPlaceholder) + `|该目标)[\x60"]?[ \t]*(?:这个|该)?[ \t]*(?:ID|标识符)`)
	opaqueChineseToolValueBeforeIDStartPattern         = regexp.MustCompile(`(?i)[\x60]?get_function[\x60]?[ \t]*(?:时[ \t]*)?传入了[ \t]*`)
	opaqueChineseFunctionInputAfterMentionPattern      = regexp.MustCompile(`(?i)(?:并[ \t]*)?(?:时[ \t]*)?传入了[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `|` + regexp.QuoteMeta(legacyEntityPlaceholder) + `|该目标)[\x60"]?[ \t]*(?:这个|该)[ \t]*(?:ID|标识符)`)
	opaqueChineseFunctionInputAfterMentionStartPattern = regexp.MustCompile(`(?i)(?:并[ \t]*)?(?:时[ \t]*)?传入了[ \t]*[\x60"]?`)
	// A model may emit the public tool name in one delta and its value phrase in the next,
	// using the shorter "传入 <value>" form without an explicit ID label. This streaming-only
	// variant is gated by the preceding get_function mention and must not change whole-text
	// redaction semantics for ordinary prose.
	// 模型可能先发公开工具名、下一帧才发值短语，并省略显式 ID 标签。这个变体只用于前面已有
	// get_function 的流式保护，不能改变普通完整文本的既有语义。
	opaqueChineseFunctionReferenceAfterMentionPattern      = regexp.MustCompile(`(?i)(?:并[ \t]*)?(?:时[ \t]*)?传入(?:了)?[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `|` + regexp.QuoteMeta(legacyEntityPlaceholder) + `|该目标)[\x60"]?[ \t]*(?:(?:这个|该)[ \t]*(?:ID|标识符)|后)?`)
	opaqueChineseFunctionReferenceAfterMentionStartPattern = regexp.MustCompile(`(?i)(?:并[ \t]*)?(?:时[ \t]*)?传入(?:了)?[ \t]*[\x60"]?`)
	opaqueChineseToolQueryIDPattern                        = regexp.MustCompile(`(?i)([\x60]?get_function[\x60]?[ \t]*查询)[ \t]*(?:ID|标识符)[ \t]*(?:为|是|[:：=])[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item|该目标)[\x60"]?[ \t]*的函数`)
	opaqueChineseToolQueryIDStartPattern                   = regexp.MustCompile(`(?i)[\x60]?get_function[\x60]?[ \t]*查询[ \t]*(?:ID|标识符)[ \t]*(?:为|是|[:：=])[ \t]*[\x60"]?`)
	opaqueChineseNoMatchingFunctionIDPattern               = regexp.MustCompile(`(?i)(当前工作区中没有任何函数)[ \t]*(?:的[ \t]*)?(?:ID|标识符)[ \t]*(?:是|为|[:：=])[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item|该目标)[\x60"]?`)
	opaqueChineseNoMatchingFunctionIDStartPattern          = regexp.MustCompile(`(?i)当前工作区中没有任何函数[ \t]*(?:的[ \t]*)?(?:ID|标识符)[ \t]*(?:是|为|[:：=])[ \t]*[\x60"]?`)
	opaqueChineseActualFunctionIDPattern                   = regexp.MustCompile(`(?i)(获取(?:真实的|实际的|可用的))[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item|该目标)[\x60"]?[ \t]*(?:ID|标识符)[ \t]*(后)?`)
	opaqueChineseActualFunctionIDStartPattern              = regexp.MustCompile(`(?i)获取(?:真实的|实际的|可用的)[ \t]*[\x60"]?`)
	// A model can explain the same missing value generically as "这个 ID <value> 在系统中...".
	// Keep the generic ID fact while removing the unavailable value and its redaction artifact.
	// 模型也可能泛化成「这个 ID <值> 在系统中……」；保留 ID 事实，去掉不可用值和脱敏痕迹。
	opaqueChineseGenericMissingIDSentencePattern            = regexp.MustCompile(`(?i)((?:这个|该)[ \t]*(?:ID|标识符))[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item|该目标)[\x60"]?[ \t]*((?:在|于)[^。\r\n]{0,80}(?:不存在|找不到|未找到)[^。\r\n]*)`)
	opaqueChineseGenericMissingIDSentenceStartPattern       = regexp.MustCompile(`(?i)(?:这个|该)[ \t]*(?:ID|标识符)[ \t]*[\x60"]?`)
	opaqueChineseGenericMissingIDPlaceholderLocationPattern = regexp.MustCompile(`(?i)((?:这个|该)[ \t]*(?:ID|标识符))[ \t]*(?:` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `|` + regexp.QuoteMeta(legacyEntityPlaceholder) + `|该目标)[ \t]*(在[^。\r\n]{0,80}(?:不存在|找不到|未找到)[^。\r\n]*)`)
	opaqueChineseRawValueBeforeIDPattern                    = regexp.MustCompile(`(?i)[\x60"]?` + opaqueEntityIDPatternSource + `[\x60"]?[ \t]*(?:这个|该)[ \t]*(?:ID|标识符)[ \t]*`)
	opaqueChineseRawValueBeforeIDStartPattern               = regexp.MustCompile(`(?i)[\x60"]?` + opaqueEntityIDPatternSource)
	// A failure explanation may use the tool-bound phrase "with the exact ID <value>".
	// Keep the sentence natural without exposing either the raw ID or the internal placeholder.
	// 失败推理可能写成「with the exact ID <值>」；保留动作语义，不泄露真实 ID 或内部 placeholder。
	opaqueEnglishExactIDReferencePattern      = regexp.MustCompile(`(?i)(\bwith[ \t]+the[ \t]+exact)[ \t]+ID[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item)[\x60"]?`)
	opaqueEnglishExactIDReferenceStartPattern = regexp.MustCompile(`(?i)\bwith[ \t]+the[ \t]+exact[ \t]+ID[ \t]*[\x60"]?`)
	// The same reasoning grammar can say "with the nonexistent ID <value>". Once the
	// value is redacted, leaving the generic marker in that clause is still an implementation
	// leak; keep the fact while naming the public concept instead.
	// 同一类 reasoning 也会写「with the nonexistent ID <值>」；值被脱敏后不能留下通用 marker，
	// 保留事实但改成公开概念名。
	opaqueEnglishNonexistentIDReferencePattern           = regexp.MustCompile(`(?i)(\bwith[ \t]+the[ \t]+nonexistent)[ \t]+ID[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item)[\x60"]?`)
	opaqueEnglishNonexistentIDReferenceStartPattern      = regexp.MustCompile(`(?i)\bwith[ \t]+the[ \t]+nonexistent[ \t]+ID[ \t]*[\x60"]?`)
	opaqueEnglishNonexistentIDReferenceOpenPrefixPattern = regexp.MustCompile(`(?i)\bwith[ \t]+the(?:[ \t]+nonexistent(?:[ \t]+ID[ \t]*[\x60"]?)?)?[ \t]*$`)
	// A hosted model may then explain the placeholder itself as if it were a real value. Rewrite
	// this exact Chinese grammar into a truthful sentence before the fallback placeholder cleanup.
	// 托管模型有时还会把 placeholder 当成真实值解释。先改写这一固定中文句式，再走兜底清理。
	opaqueChineseMissingIDExplanationPattern = regexp.MustCompile(`(?i)[\x60"]?(?:the requested item|the referenced item)[\x60"]?[ \t]*是一个格式正确但实际并不存在的[ \t]*(?:ID|标识符)`)
	// A failure explanation may put the unavailable value between an entity label and its
	// predicate, e.g. "该函数 ID the requested item 在系统中并不存在". After the generic
	// placeholder pass that becomes "该函数 ID 该目标...", which is safe but reads like
	// redaction machinery. Remove the machine-field middle and keep a natural fact sentence.
	// 失败解释也可能把不可用值夹在实体名和谓语之间，例如「该函数 ID the requested item 在系统中并不存在」。
	// 通用 placeholder 兜底后虽会变成「该函数 ID 该目标……」，但仍像脱敏器在说话；去掉中间机器字段，保留自然事实。
	opaqueChineseMissingIDSentencePattern         = regexp.MustCompile(`(?i)(该(?:函数|工作流|处理器|代理|触发器|文档|技能|对话|消息|附件|运行))[ \t]*(?:ID|标识符)[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item|该目标)[\x60"]?[ \t]*((?:在|于)[^。\r\n]{0,80}(?:不存在|找不到|未找到)[^。\r\n]*)`)
	opaqueChineseAnyMissingIDSentencePattern      = regexp.MustCompile(`(?i)((?:该|这个)(?:函数|工作流|处理器|代理|触发器|文档|技能|对话|消息|附件|运行))[ \t]*(?:ID|标识符)[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item|该目标)[\x60"]?[ \t]*((?:在|于)[^。\r\n]{0,80}(?:不存在|找不到|未找到)[^。\r\n]*)`)
	opaqueChineseAnyMissingIDSentenceStartPattern = regexp.MustCompile(`(?i)(?:该|这个)(?:函数|工作流|处理器|代理|触发器|文档|技能|对话|消息|附件|运行)[ \t]*(?:ID|标识符)[ \t]*[\x60"]?`)
	// The model may omit the value entirely while retaining the machine label, e.g.
	// "该函数 ID 并不存在于系统中". The entity noun already carries the meaning.
	// 模型也可能省略值但保留机器标签：「该函数 ID 并不存在于系统中」；实体名已经足够表达事实。
	opaqueChineseMissingIDLabelPattern = regexp.MustCompile(`(?i)(该(?:函数|工作流|处理器|代理|触发器|文档|技能|对话|消息|附件|运行))[ \t]*(?:ID|标识符)[ \t]*((?:并不存在于|不存在于|并不存在|不存在|找不到|未找到)[^。\r\n]*)`)
	// Some hosted answers put the location phrase before the predicate, e.g. "该函数 ID 在系统中不存在".
	// Remove the machine-field label as well; the entity noun and location already carry the fact.
	// 托管模型有时把地点短语放在谓语前：「该函数 ID 在系统中不存在」；实体名和地点已足够表达事实，
	// 同样移除机器字段标签。
	opaqueChineseMissingIDLabelInSentencePattern       = regexp.MustCompile(`(?i)((?:该|这个)(?:函数|工作流|处理器|代理|触发器|文档|技能|对话|消息|附件|运行))[ \t]*(?:ID|标识符)[ \t]*(在[^。\r\n]{0,80}(?:不存在|找不到|未找到)[^。\r\n]*)`)
	opaqueChineseMissingIDParentheticalSentencePattern = regexp.MustCompile(`(?i)((?:该|这个)(?:函数|工作流|处理器|代理|触发器|文档|技能|对话|消息|附件|运行))[ \t]*(?:ID|标识符)[ \t]*[（(][ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `|` + regexp.QuoteMeta(legacyEntityPlaceholder) + `|该目标)?[\x60"]?[ \t]*[）)][ \t]*((?:在|于)[^。\r\n]{0,80}(?:不存在|找不到|未找到)[^。\r\n]*)`)
	opaqueChineseGenericMissingIDLocationPattern       = regexp.MustCompile(`(?i)((?:该|这个))[ \t]*(?:ID|标识符)[ \t]*(在[^。\r\n]{0,80}(?:不存在|找不到|未找到)[^。\r\n]*)`)
	// A missing-function explanation can omit the location preposition entirely: "这个 ID 并不
	// 存在于...". Treat the bare machine label as the already-known input, not as user-facing jargon.
	// 缺失函数说明有时直接写「这个 ID 并不存在于……」；把裸机器字段改成已知输入。
	opaqueChineseGenericMissingIDLabelPattern = regexp.MustCompile(`(?i)((?:该|这个))[ \t]*(?:ID|标识符)[ \t]*((?:并不存在于|不存在于|并不存在|不存在|找不到|未找到)[^。\r\n]*)`)
	// A value-explanation sentence can describe the placeholder as a fabricated identifier. Keep
	// the explanation but use a human label instead of exposing a value-shaped target.
	// 模型可能把 placeholder 解释成“虚构的标识符”；保留解释事实，但不用像值的 target。
	opaqueChineseFabricatedIDExplanationPattern        = regexp.MustCompile(`(?i)[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item|该目标)[\x60"]?[ \t]*(是一个[^。\r\n]{0,120}(?:虚构|标识符|ID)[^。\r\n]*)`)
	opaqueChineseMissingIDLabelPrefixPattern           = regexp.MustCompile(`(?i)(该(?:函数|工作流|处理器|代理|触发器|文档|技能|对话|消息|附件|运行))[ \t]*(?:ID|标识符)[ \t]*$`)
	opaqueChineseFabricatedIDExplanationPrefixPattern  = regexp.MustCompile(`(?i)[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item|该目标)[\x60"]?[ \t]*$`)
	opaqueChineseFabricatedIDExplanationContextPattern = regexp.MustCompile(`(?i)(?:该(?:函数|工作流|处理器|代理|触发器|文档|技能|对话|消息|附件|运行)[^。\r\n]{0,100}(?:不存在|找不到|未找到)[。！？][ \t]*)$`)
	opaqueChineseIDFormatParentheticalPattern          = regexp.MustCompile(`(?i)(格式(?:正确|合法))[（(]符合[ \t]*[\x60"]?[A-Za-z0-9]+_[\x60"]?[ \t]*前缀[^）)]*(?:ID|标识符)[^）)]*[）)]`)
	opaqueChineseIDPrefixFormatPattern                 = regexp.MustCompile(`(?i)格式为[ \t]*[\x60"]?[A-Za-z0-9]+_[\x60"]?[ \t]*开头`)
	opaqueChineseIDFormatPrefixPattern                 = regexp.MustCompile(`(?i)(格式为)[ \t]*[\x60"]?[A-Za-z0-9]+_[\x60"]?[ \t]*(?:前缀|prefix)`)
	opaqueChineseIDFormatPrefixStartPattern            = regexp.MustCompile(`(?i)格式为[ \t]*[\x60"]?`)
	// Do not expose a provider's concrete prefix example in prose, including the common
	// "格式上符合 <prefix> 前缀加十六进制字符的结构" spelling.
	// prose 不能暴露 provider 的具体前缀示例，包括常见的「格式上符合 <前缀> 前缀加十六进制字符的结构」。
	opaqueChineseIDFormatStructurePattern                 = regexp.MustCompile(`(?i)(?:格式上符合|符合)[ \t]*[\x60"]?[A-Za-z0-9]+_[\x60"]?[ \t]*前缀[ \t]*(?:加|\+)[ \t]*(?:[0-9]+[ \t]*位[ \t]*)?十六进制字符[ \t]*的[ \t]*(?:ID[ \t]*)?(?:结构|规范)`)
	opaqueChineseIDFormatStructureStartPattern            = regexp.MustCompile(`(?i)(?:格式上符合|符合)[ \t]*[\x60"]?`)
	opaqueChineseIDPrefixParentheticalPattern             = regexp.MustCompile(`(?i)([（(])以[ \t]*[\x60"]?[A-Za-z0-9]+_[\x60"]?[ \t]*开头([）)])`)
	opaqueChineseIDPrefixPhrasePattern                    = regexp.MustCompile(`(?i)以[ \t]*[\x60"]?[A-Za-z0-9]+_[\x60"]?[ \t]*开头`)
	opaqueChineseDanglingIDExplanationPattern             = regexp.MustCompile(`(?i)(而)?[ \t]*该[ \t]*ID[ \t]*是一个`)
	opaqueChineseFunctionIDRequirementPattern             = regexp.MustCompile(`(?i)(要求传入一个真实(?:已注册)?的函数)[ \t]*(?:ID|标识符)`)
	opaqueChineseFunctionIDDirectoryRequirementPattern    = regexp.MustCompile(`(?i)(要求传入一个(?:实际存在于目录中的|实际存在于目录中|真实(?:已注册)?的)函数)[ \t]*(?:ID|标识符)`)
	opaqueChineseFunctionIDBroadRequirementPattern        = regexp.MustCompile(`(?i)(要求传入(?:的是)?一个[^。\r\n]{0,60}?函数)[ \t]*(?:ID|标识符)`)
	opaqueChineseFunctionIDNaturalRequirementPattern      = regexp.MustCompile(`(?i)((?:需要|要求|必须)[ \t]*(?:传入|提供|使用)[^。\r\n]{0,80}?函数)[ \t]*(?:ID|标识符)`)
	opaqueChineseFunctionIDNaturalRequirementStartPattern = regexp.MustCompile(`(?i)(?:需要|要求|必须)[ \t]*(?:传入|提供|使用)[^。\r\n]{0,80}?函数[ \t]*$`)
	// A model may leave the machine label bare after the value has already been removed, e.g.
	// “这个函数 ID 不存在”. Keep the sentence natural without exposing the field name.
	// 值已被移除后，模型仍可能留下「这个函数 ID 不存在」；把裸机器字段改成人话。
	opaqueChineseBareFunctionIDLabelPattern        = regexp.MustCompile(`(?i)函数[ \t]+ID[ \t]*`)
	opaqueChineseInputIDLabelPattern               = regexp.MustCompile(`(?i)这个输入[ \t]+ID[ \t]*`)
	opaqueChineseValidInputPattern                 = regexp.MustCompile(`(?i)有效的[ \t]+这个输入`)
	opaqueChineseRealMarkerFollowPattern           = regexp.MustCompile(`(?i)拿到真实标识[ \t]+后再调用`)
	opaqueChineseBareToolIDLabelPattern            = regexp.MustCompile(`(?i)时传入的[ \t]+ID[ \t]*`)
	opaqueChineseIDBeforeInputPattern              = regexp.MustCompile(`(?i)ID[ \t]*(这个输入)`)
	opaqueChineseInputIDCorrespondencePattern      = regexp.MustCompile(`(?i)这个[ \t]*ID[ \t]*对应`)
	opaqueChineseFunctionIDCallPlaceholderPattern  = regexp.MustCompile(`(?i)(get_function)[ \t]*\([ \t]*(?:functionId|function_id)[ \t]*=[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item|该目标|这个输入)[\x60"]?[ \t]*\)`)
	opaqueChineseOpaqueIDPhrasePattern             = regexp.MustCompile(`(?i)真实不透明[ \t]*(?:ID|标识符)`)
	opaqueChineseShapePlaceholderPattern           = regexp.MustCompile(`(?i)[（(][ \t]*形如[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item|该目标|这个输入)[\x60"]?[ \t]*[）)]`)
	opaqueChinesePrefixExamplePattern              = regexp.MustCompile(`(?i)前缀[ \t]*[\x60"]?fn_[\x60"]?[ \t]*\+[ \t]*(?:[0-9]+[ \t]*位[ \t]*)?十六进制(?:字符)?`)
	opaqueChineseCorrespondingInputPattern         = regexp.MustCompile(`(?i)对应的[ \t]+这个输入`)
	opaqueChineseCorrespondingCardReferencePattern = regexp.MustCompile(`(?i)对应的[ \t]+the ID shown in the adjacent result card`)
	opaqueChineseTargetBeforeInputPattern          = regexp.MustCompile(`(?i)时传入的目标[ \t\x60"]*这个输入[ \t\x60"]*`)
	opaqueChineseRawFunctionIDPattern              = regexp.MustCompile(`(?i)[\x60"]?fn_[0-9a-f]{8,}[\x60"]?`)
	opaqueChineseRawFunctionPrefixPattern          = regexp.MustCompile(`(?i)[\x60"]?fn_[\x60"]?`)
	opaqueChineseFunctionShapePattern              = regexp.MustCompile(`(?i)(函数)[ \t]*(?:ID|标识符)?[ \t]*[（(][ \t]*形如[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|[A-Za-z]+_[.]{3,}|the requested item|the referenced item|该目标)[\x60"]?[ \t]*[）)]`)
	opaqueChineseFunctionShapeStartPattern         = regexp.MustCompile(`(?i)函数[ \t]*(?:ID|标识符)?[ \t]*[（(][ \t]*形如[ \t]*[\x60"]?`)
	opaqueChineseFabricatedInputPattern            = regexp.MustCompile(`(?i)((?:而[ \t]*)?)(这个)[ \t]*(?:ID|标识符)[ \t]*是虚构的`)
	opaqueChineseMissingIDDirectCallPattern        = regexp.MustCompile(`(?i)(一个不存在但格式正确的)[ \t]*(?:ID|标识符)[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|[A-Za-z]+_[.]{3,}|the requested item|the referenced item|该目标)[\x60"]?[ \t]*(调用)`)
	// The model can emit the missing-ID phrase before it has decided whether to say “调用” or
	// another verb. Redact the standalone reference too, so a live delta never exposes the
	// placeholder while waiting for the sentence suffix.
	// 模型可能在决定后续动词前就先发出缺失 ID 短语；独立短语也要先收敛，不能等后缀才保护 live delta。
	opaqueChineseMissingIDStandaloneReferencePattern          = regexp.MustCompile(`(?i)(一个不存在但格式正确的)[ \t]*(?:ID|标识符)[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|[A-Za-z]+_[.]{3,}|the requested item|the referenced item|该目标)[\x60"]?`)
	opaqueChineseNonexistentIDDirectCallPattern               = regexp.MustCompile(`(?i)(一个不存在的)[ \t]*(?:ID|标识符|标识)[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|[A-Za-z]+_[.]{3,}|the requested item|the referenced item|该目标)[\x60"]?[ \t]*(调用)`)
	opaqueChineseNonexistentIDDirectCallStartPattern          = regexp.MustCompile(`(?i)一个不存在的[ \t]*(?:ID|标识符|标识)?[ \t]*[\x60"]?`)
	opaqueChineseFabricatedIDDirectCallPattern                = regexp.MustCompile(`(?i)用这个虚构的[ \t]*(?:ID|标识符|标识)?[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|[A-Za-z]+_[.]{3,}|the requested item|the referenced item|该目标)[\x60"]?[ \t]*(调用)`)
	opaqueChineseFabricatedIDDirectCallStartPattern           = regexp.MustCompile(`(?i)用这个虚构的[ \t]*(?:ID|标识符|标识)?[ \t]*[\x60"]?`)
	opaqueChineseMissingIDInvocationPattern                   = regexp.MustCompile(`(?i)(一个不存在但格式正确的)[ \t]*(?:ID|标识符)[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|[A-Za-z]+_[.]{3,}|the requested item|the referenced item|该目标)[\x60"]?[ \t]*(来调用)`)
	opaqueChineseMissingIDInvocationStartPattern              = regexp.MustCompile(`(?i)一个不存在但格式正确的[ \t]*(?:ID|标识符)?[ \t]*[\x60"]?`)
	opaqueChineseMissingIDColonPattern                        = regexp.MustCompile(`(?i)((?:使用|传入)(?:了)?一个不存在但格式正确的)[ \t]*(?:ID|标识符)[ \t]*[：:][ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item|该目标)[\x60"]?`)
	opaqueChineseMissingIDColonStartPattern                   = regexp.MustCompile(`(?i)(?:使用|传入)(?:了)?一个不存在但格式正确的[ \t]*(?:ID|标识符)[ \t]*[：:][ \t]*[\x60"]?`)
	opaqueChineseMissingIDColonBarePattern                    = regexp.MustCompile(`(?i)(一个不存在但格式正确的)[ \t]*(?:ID|标识符)[ \t]*[：:][ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item|该目标)[\x60"]?`)
	opaqueChineseMissingIDColonBareStartPattern               = regexp.MustCompile(`(?i)一个不存在但格式正确的[ \t]*(?:ID|标识符)[ \t]*[：:][ \t]*[\x60"]?`)
	opaqueChineseFoundActualIDPattern                         = regexp.MustCompile(`(?i)找到实际存在的[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|[A-Za-z]+_[.]{3,}|the requested item|the referenced item|该目标)[\x60"]?[ \t]*(?:ID|标识符)[ \t]*后`)
	opaqueChineseFoundActualIDStartPattern                    = regexp.MustCompile(`(?i)找到实际存在的[ \t]*[\x60"]?`)
	opaqueChineseIDFunctionNotCreatedPattern                  = regexp.MustCompile(`(?i)((?:而[ \t]*)?)该[ \t]*ID[ \t]*对应的函数从未被创建过`)
	opaqueChineseIDFunctionNotCreatedStartPattern             = regexp.MustCompile(`(?i)(?:而[ \t]*)?该[ \t]*ID[ \t]*`)
	opaqueChineseIDFabricatedFunctionPattern                  = regexp.MustCompile(`(?i)该[ \t]*(?:ID|标识符)[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|[A-Za-z]+_[.]{3,}|the requested item|the referenced item|该目标)[\x60"]?[ \t]*(是一个[^。\r\n]{0,160}(?:函数标识符|标识符)[^。\r\n]*)`)
	opaqueChineseIDFabricatedFunctionStartPattern             = regexp.MustCompile(`(?i)该[ \t]*(?:ID|标识符)[ \t]*[\x60"]?`)
	opaqueChineseRegisteredIDFunctionPattern                  = regexp.MustCompile(`(?i)(工作区中没有注册过)[ \t]*(?:这个|该)[ \t]*(?:ID|标识符)[ \t]*(对应的函数)`)
	opaqueChineseRegisteredIDFunctionStartPattern             = regexp.MustCompile(`(?i)工作区中没有注册过[ \t]*(?:这个|该)[ \t]*(?:ID|标识符)[ \t]*`)
	opaqueChineseRegisteredFunctionForIDPattern               = regexp.MustCompile(`(?i)(当前工作区(?:中|里)没有注册过对应)[ \t]*(?:这个|该)[ \t]*(?:ID|标识符)[ \t]*(的函数)`)
	opaqueChineseCorrectFunctionIDAfterPattern                = regexp.MustCompile(`(?i)(拿到正确的)[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|[A-Za-z]+_[.]{3,}|the requested item|the referenced item|该目标)[\x60"]?[ \t]*(?:ID|标识符)[ \t]*(后再调用)`)
	opaqueChineseCorrectFunctionIDAfterStartPattern           = regexp.MustCompile(`(?i)拿到正确的[ \t]*[\x60"]?`)
	opaqueChineseIDLookupFunctionPattern                      = regexp.MustCompile(`(?i)((?:系统在)?根据)[ \t]*(?:这个|该)?[ \t]*(?:ID|标识符)[ \t]*(查找函数)`)
	opaqueChineseIDLookupFunctionStartPattern                 = regexp.MustCompile(`(?i)根据[ \t]*`)
	opaqueChineseBareIDFormatPhrasePattern                    = regexp.MustCompile(`(?i)(简而言之(?:——|-))[ \t]*ID[ \t]*格式没问题`)
	opaqueChineseRealIDPattern                                = regexp.MustCompile(`(?i)真实[ \t]*(?:ID|标识符)`)
	opaqueChineseExistingFunctionIDPattern                    = regexp.MustCompile(`(?i)实际存在的函数[ \t]*(?:ID|标识符)`)
	opaqueChineseFunctionCorrespondencePhrasePattern          = regexp.MustCompile(`(?i)(当前工作区(?:中|里)没有任何函数)与此[ \t]*(?:ID|标识符)[ \t]*对应`)
	opaqueChineseDueToCreationPattern                         = regexp.MustCompile(`(?i)(由于)[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item|该目标)[\x60"]?[ \t]*从未被创建过`)
	opaqueChineseDueToCreationStartPattern                    = regexp.MustCompile(`(?i)由于[ \t]*[\x60"]?`)
	opaqueChineseNonexistentIDPhrasePattern                   = regexp.MustCompile(`(?i)((?:不存在的|未注册的|不合法的|非法的|无效的|虚构的[^。\r\n]{0,40}?))[ \t]*ID`)
	opaqueChineseAllZeroIDPattern                             = regexp.MustCompile(`(?i)((?:这个|该))[ \t]*全零的[ \t]*(?:ID|标识符)`)
	opaqueChineseDanglingTargetBeforeInputPattern             = regexp.MustCompile(`(?i)该目标[ \t]+这个输入`)
	opaqueChineseRealMarkerFormatPattern                      = regexp.MustCompile(`(?i)真实标识[ \t]+均?[ \t]*以合法格式开头`)
	opaqueChinesePlaceholderNotFunctionPattern                = regexp.MustCompile(`(?i)(?:` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `|` + regexp.QuoteMeta(legacyEntityPlaceholder) + `|该目标)[ \t]*(并不是[^。\r\n]{0,160}(?:函数|标识符)[^。\r\n]*)`)
	opaqueChineseIDNotFunctionStartPattern                    = regexp.MustCompile(`(?i)[\x60"]?(?:` + opaqueEntityIDPatternSource + `|` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `|` + regexp.QuoteMeta(legacyEntityPlaceholder) + `|该目标)[\x60"]?[ \t]*`)
	opaqueChineseIDNotFunctionPattern                         = regexp.MustCompile(`(?i)[\x60"]?(?:` + opaqueEntityIDPatternSource + `|` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `|` + regexp.QuoteMeta(legacyEntityPlaceholder) + `|该目标)[\x60"]?[ \t]*(并不是[^。\r\n]{0,160}(?:函数|标识符)[^。\r\n]*)`)
	opaqueChinesePlaceholderCorrespondencePattern             = regexp.MustCompile(`(?i)当前工作区中(?:并)?没有与[ \t]*(?:这个|该)[ \t]*(?:ID|标识符)[ \t]*对应的函数记录`)
	opaqueChineseGenericIDCorrespondencePattern               = regexp.MustCompile(`(?i)(没有与)[ \t]*(?:这个|该)[ \t]*(?:ID|标识符)[ \t]*对应`)
	opaqueChineseDanglingIDCorrespondencePattern              = regexp.MustCompile(`(?i)该[ \t]*ID[ \t]*对应`)
	opaqueChineseFunctionCorrespondencePattern                = regexp.MustCompile(`(?i)系统中没有任何函数与此[ \t]*(?:ID|标识符)[ \t]*对应`)
	opaqueChineseFunctionCorrespondenceWithThisIDPattern      = regexp.MustCompile(`(?i)系统中并没有任何函数与此[ \t]*(?:ID|标识符)[ \t]*对应`)
	opaqueChineseNonexistentLocatedIDPattern                  = regexp.MustCompile(`(?i)不存在[ \t]*(?:ID|标识符)[ \t]*已定位[ \t]*的[ \t]*(函数|工作流|处理器|代理|触发器|文档|技能|对话|消息|附件|运行)`)
	opaqueChineseFunctionIDLocatedPhrasePattern               = regexp.MustCompile(`(?i)传入[ \t]+functionID[ \t]*已定位`)
	opaqueChineseBareFunctionIDCamelPattern                   = regexp.MustCompile(`(?i)functionID`)
	opaqueChineseBareFabricatedIDLabelPattern                 = regexp.MustCompile(`(?i)虚构[ \t]+ID`)
	opaqueChineseDuplicateInputReferencePattern               = regexp.MustCompile(`(?i)(?:这个|该)[ \t]*ID[ \t]*(这个输入|函数标识)`)
	opaqueChineseDuplicateInputWordPattern                    = regexp.MustCompile(`(?i)(?:这个|该)[ \t]+这个输入`)
	opaqueChineseLookupBareIDPattern                          = regexp.MustCompile(`(?i)根据该[ \t]*ID`)
	opaqueChineseLookupInputBeforeVerbPattern                 = regexp.MustCompile(`(?i)根据这个输入[ \t]+(查找|查询)`)
	opaqueChineseFetchRealInputIDAfterPattern                 = regexp.MustCompile(`(?i)获取真实的[ \t]+这个输入(?:[ \t]+ID)?[ \t]*后再调用`)
	opaqueChineseRealInputIDAfterPattern                      = regexp.MustCompile(`(?i)拿到真实的[ \t]+这个输入(?:[ \t]+ID)?[ \t]*后再调用`)
	opaqueChineseBareTargetIDPhrasePattern                    = regexp.MustCompile(`(?i)该[ \t]+ID[ \t]*`)
	opaqueChineseParenthesizedPrefixStartPattern              = regexp.MustCompile(`(?i)（函数标识前缀[ \t]+开头）`)
	opaqueChinesePrefixStartPhrasePattern                     = regexp.MustCompile(`(?i)函数标识前缀[ \t]+开头`)
	opaqueChineseValidFunctionIDPhrasePattern                 = regexp.MustCompile(`(?i)[ \t]*函数标识以合法格式开头的[ \t]*(?:ID|标识符?)[ \t]*`)
	opaqueChineseCorrectExistingFunctionPhrasePattern         = regexp.MustCompile(`(?i)拿到正确的[ \t]*真实存在的函数标识`)
	opaqueChineseRegisteredFunctionExamplePattern             = regexp.MustCompile(`(?i)例如[ \t]+函数标识以合法格式开头的、系统中已注册的函数(?:标识符)?`)
	opaqueChineseFabricatedNonexistentFunctionPhrasePattern   = regexp.MustCompile(`(?i)虚构的[ \t]*、[ \t]*不存在的[ \t]*(?:函数)?标识符?`)
	opaqueChineseFabricatedWellFormedMissingPhrasePattern     = regexp.MustCompile(`(?i)虚构的[ \t]*、[ \t]*格式合法但(?:实际上)?不存在的[ \t]*(?:函数)?标识符?`)
	opaqueChineseFabricatedInvalidIDPhrasePattern             = regexp.MustCompile(`(?i)虚构的[ \t]*、[ \t]*不合法的[ \t]*(?:ID|标识符?|标识)`)
	opaqueChineseDuplicatedPrefixFormatPattern                = regexp.MustCompile(`(?i)函数标识前缀[ \t]+前缀[ \t]*\+[ \t]*[0-9]+[ \t]*位[ \t]*字符`)
	opaqueChineseMatchingIDPhrasePattern                      = regexp.MustCompile(`(?i)与此[ \t]+ID[ \t]+匹配`)
	opaqueChineseIDFormatValidPhrasePattern                   = regexp.MustCompile(`(?i)ID[ \t]+格式本身[ \t]*是[ \t]*合法的`)
	opaqueChineseBareInputIDPhrasePattern                     = regexp.MustCompile(`(?i)这个[ \t]+ID`)
	opaqueChineseExactIDPhrasePattern                         = regexp.MustCompile(`(?i)确切[ \t]+ID`)
	opaqueChineseFunctionLabelBeforePredicatePattern          = regexp.MustCompile(`(?i)函数标识[ \t]+(不存在|并不存在|已|未|在|对应)`)
	opaqueChineseLabelBeforeTestingPattern                    = regexp.MustCompile(`(?i)标识[ \t]+来测试`)
	opaqueChineseIDBeforeLocationPattern                      = regexp.MustCompile(`(?i)该[ \t]*ID[ \t]*(在|于|中)`)
	opaqueChineseInputBeforeLocationPattern                   = regexp.MustCompile(`(?i)该输入[ \t]*(在|于|中)`)
	opaqueChineseInputBeforeLocationSpacingPattern            = regexp.MustCompile(`(?i)(这个输入|该输入)[ \t]+(在|于|中)`)
	opaqueChineseDuplicateIdentifierInputPattern              = regexp.MustCompile(`(?i)(?:(?:该|这个)[ \t]*)?(?:函数[ \t]*)?标识符?[ \t]+这个输入`)
	opaqueChineseInputBeforeParticleSpacingPattern            = regexp.MustCompile(`(?i)(这个输入|该输入)[ \t]+(的|地|得|对应|并未|未|存在|虽然|但是|并|也|，|。|、|：|；|！|？)`)
	opaqueChineseDuplicateNeutralInputPattern                 = regexp.MustCompile(`(?i)这个输入[ \t]*这个输入`)
	opaqueChineseProvidedInputBeforeFormatPattern             = regexp.MustCompile(`(?i)(您提供的)这个输入[ \t]*在格式上是(?:正确|合法)的[ \t]*(?:[（(]符合[^\r\n）)]{0,120}[）)])?`)
	opaqueChineseMissingFunctionLabelBeforePredicatePattern   = regexp.MustCompile(`(?i)对不存在的[ \t]*(?:标识|输入)[ \t]+会`)
	opaqueChineseSubjectInputSpacingPattern                   = regexp.MustCompile(`(?i)(说明|表示|意味着|发现|表明|虽然)[ \t]+(这个输入|该输入)[ \t]+(在|于|中)`)
	opaqueChineseSubjectInputBeforeLocationPattern            = regexp.MustCompile(`(?i)(说明|表示|意味着|发现|表明)[ \t]+(这个输入|该输入)[ \t]*(在|于|中)`)
	opaqueChineseToolTargetMissingFunctionPattern             = regexp.MustCompile(`(?i)调用[ \t]+[\x60]?get_function[\x60]?[ \t]*时传入的目标在系统中并不存在`)
	opaqueChineseDuplicateValidLabelPattern                   = regexp.MustCompile(`(?i)格式合法的[ \t]*合法标识符`)
	opaqueChineseRegisteredInputCorrespondencePattern         = regexp.MustCompile(`(?i)(没有注册过|并没有注册过)[ \t]*这个输入对应的函数`)
	opaqueChineseFunctionLabelAssignmentSpacingPattern        = regexp.MustCompile(`(?i)传入的[ \t]+[\x60]?函数标识[\x60]?[ \t]+为[ \t]+这个输入`)
	opaqueChineseWellFormedFabricatedFunctionSentencePattern  = regexp.MustCompile(`(?i)这个输入[ \t]+是一个格式上合法[（(]符合合法的函数标识格式[）)]但实际上并不存在的虚构的函数标识`)
	opaqueChineseIDFormatCorrectPattern                       = regexp.MustCompile(`(?i)ID[ \t]+格式正确`)
	opaqueChineseFunctionLabelInputColonPattern               = regexp.MustCompile(`(?i)函数标识[ \t]*[:：][ \t]*(这个输入|该输入)`)
	opaqueChineseOpaqueFunctionIDClausePattern                = regexp.MustCompile(`(?i)真实[ \t]+opaque[ \t]+ID[ \t]*[（(][ \t]*即[ \t]*函数标识以合法格式开头的有效标识符[）)]`)
	opaqueChineseValidPrefixFunctionIDPhrasePattern           = regexp.MustCompile(`(?i)函数标识以合法格式开头的有效标识符`)
	opaqueChineseInputFabricatedPattern                       = regexp.MustCompile(`(?i)(这个输入|该输入)[ \t]*是虚构的`)
	opaqueChineseDuplicatePrefixStructurePattern              = regexp.MustCompile(`(?i)标识格式本身合法[（(]符合[ \t]*函数标识前缀[ \t]*前缀[ \t]*(?:加|\+)[ \t]*标识符的结构[）)]`)
	opaqueChineseFunctionLabelInputBeforeFormatPattern        = regexp.MustCompile(`(?i)((?:您提供的)?函数标识)[ \t]+这个输入[ \t]+在格式上是(?:正确|合法)的[ \t]*[（(]符合[^\r\n）)]{0,120}[）)]?`)
	opaqueChineseFunctionFormatParentheticalPattern           = regexp.MustCompile(`(?i)((?:您提供的)?函数标识)[ \t]*在格式上是(?:正确|合法)的[ \t]*[（(]符合[^\r\n）)]{0,120}[）)]`)
	opaqueChineseDuplicatePrefixNamingPattern                 = regexp.MustCompile(`(?i)符合[ \t]*函数标识前缀[ \t]+前缀[ \t]*(?:加|\+)[ \t]*字符(?:的[^\r\n。）]{0,40})?`)
	opaqueChinesePrefixIdentifierStructurePattern             = regexp.MustCompile(`(?i)符合[ \t]*函数标识前缀[ \t]+前缀[ \t]*(?:加|\+)[ \t]*标识符[ \t]*的[ \t]*结构`)
	opaqueChineseProvidedIDPattern                            = regexp.MustCompile(`(?i)(您提供的|提供的)[ \t]+ID`)
	opaqueChineseProvidedSpacingPattern                       = regexp.MustCompile(`(?i)您提供的[ \t]+(函数标识|这个输入)`)
	opaqueChineseThisIDPattern                                = regexp.MustCompile(`(?i)(?:此|该|这个)[ \t]+ID`)
	opaqueChineseFunctionLabelSpacingPattern                  = regexp.MustCompile(`(?i)(函数标识)[ \t]+(在|于|中|的|对应|并未|未|，|。|、|：|；|！|？)`)
	opaqueChineseKnownRealIdentifierAgainPattern              = regexp.MustCompile(`(?i)用已知的真实标识[ \t]*再次调用`)
	opaqueChineseDuplicatedFormatParentheticalPattern         = regexp.MustCompile(`(?i)标识格式本身合法[ \t]*[（(]符合函数标识格式[）)]`)
	opaqueChineseValidFormatHexExplanationPattern             = regexp.MustCompile(`(?i)(这个输入|该输入)[ \t]*的格式[ \t]*是[ \t]*(?:合法|正确)的[ \t]*[（(]以合法格式开头，后跟十六进制字符[）)]`)
	opaqueChineseDuplicateInputAfterValidFormatPattern        = regexp.MustCompile(`(?i)(这个输入格式合法)[ \t]*[，,][ \t]*(?:但|然而)[ \t]*这个输入[ \t]*(?:并未|未)[ \t]*在系统中注册`)
	opaqueChineseValidFormatPrefixParentheticalPattern        = regexp.MustCompile(`(?i)格式上是(?:合法|正确)的[ \t]*[（(]以[ \t]*函数标识前缀[ \t]+为前缀[，,][ \t]*后跟[^\r\n）)]{0,80}[）)]`)
	opaqueChinesePrefixAsPrefixPattern                        = regexp.MustCompile(`(?i)以[ \t]*函数标识前缀[ \t]+为前缀`)
	opaqueChineseTechnicalFormatParentheticalPattern          = regexp.MustCompile(`(?i)[（(][^\r\n）)]{0,120}函数标识前缀[^\r\n）)]{0,120}[）)]`)
	opaqueChinesePrefixTechnicalClausePattern                 = regexp.MustCompile(`(?i)函数标识前缀[ \t]+(?:前缀[ \t]*(?:和|加|\+)[ \t]*)?(?:标准的[ \t]*)?(?:长度|标识符|字符|十六进制)[^，。；）)]{0,60}(?:结构|规范|序列|长度)?`)
	opaqueChineseDanglingIdentifierPattern                    = regexp.MustCompile(`(?i)该[ \t]*(?:函数[ \t]*)?标识符`)
	opaqueChineseRedundantValidFormatPattern                  = regexp.MustCompile(`(?i)格式上是(?:合法|正确)的[ \t]*[（(]格式合法[）)]`)
	opaqueChineseCorrectIDReferencePattern                    = regexp.MustCompile(`(?i)正确的[ \t]+ID`)
	opaqueChineseCorrespondingInputWordOrderPattern           = regexp.MustCompile(`(?i)对应[ \t]*这个输入[ \t]*(?:的[ \t]*)?(函数(?:实体)?)`)
	opaqueChineseMissingFunctionInputWordOrderPattern         = regexp.MustCompile(`(?i)不存在[ \t]*(?:与[ \t]*)?对应[ \t]*这个输入[ \t]*(?:的[ \t]*)?(函数(?:实体)?)`)
	opaqueChinesePublicToolLineBreakPattern                   = regexp.MustCompile("(?i)(调用|使用|通过|查询)[ \\t\\r\\n]+([\\x60]?)(get_function|search_function)([\\x60]?)")
	opaqueChineseToolQueryInputSpacingPattern                 = regexp.MustCompile(`(?i)(调用|查询|使用)[ \t]+(这个输入|该输入)`)
	opaqueChineseValidFormatHexVariantPattern                 = regexp.MustCompile(`(?i)(这个输入|该输入)格式[ \t]*(?:是[ \t]*)?(?:合法|正确)的[ \t]*[（(]以合法格式开头[、,，][ \t]*后跟十六进制字符[）)]`)
	opaqueChineseCorrectNonexistentFunctionIdentifierPattern  = regexp.MustCompile(`(?i)格式正确但不存在的函数标识符`)
	opaqueChineseHostedValidFormatClausePattern               = regexp.MustCompile(`(?i)(这个输入)[ \t]*的格式[ \t]*是[ \t]*(?:合法|正确)的?[ \t]*[（(]符合[ \t]*(?:合法的?[ \t]*)?函数标识格式[）)]`)
	opaqueChineseSystemMissingFunctionPattern                 = regexp.MustCompile(`(?i)(?:系统里|系统中)根本不存在与这个输入对应的(函数(?:实体)?)`)
	opaqueChineseUnregisteredFunctionPattern                  = regexp.MustCompile(`(?i)(?:该|这个)函数[ \t]*(?:并未|未|没有)[ \t]*在系统中注册`)
	opaqueChineseSystemUnregisteredFunctionPattern            = regexp.MustCompile(`(?i)(?:系统中|系统里)[ \t]*(?:并没有|没有|未)[ \t]*注册过?[ \t]*(?:这个|该)函数`)
	opaqueChineseNotFormatProblemPattern                      = regexp.MustCompile(`(?i)(?:并非|不是)[ \t]*(?:ID[ \t]*)?格式[ \t]*(?:有误|错误)`)
	opaqueChineseCatalogMissingRecordPattern                  = regexp.MustCompile(`(?i)当前函数目录中不存在与之对应的函数记录`)
	opaqueChineseSystemFaultCatalogPattern                    = regexp.MustCompile(`(?i)也不是系统故障[，,][ \t]*只是当前函数目录中不存在与之对应的函数记录`)
	opaqueChineseRealIDRecommendationPattern                  = regexp.MustCompile(`(?i)找到真实的[ \t]+ID[ \t]*后再调用`)
	opaqueChineseHostedShapeFormatPattern                     = regexp.MustCompile(`(?i)(这个输入)[ \t]*在格式上是(?:完全)?(?:合法|正确)的?[ \t]*[（(][^\r\n）)]{0,160}函数标识格式[^\r\n）)]{0,160}[）)]`)
	opaqueChineseWorkspaceUnregisteredInputPattern            = regexp.MustCompile(`(?i)(?:它|这个输入)[ \t]*(?:并没有|并未|没有|未)[ \t]*在工作区中注册过?`)
	opaqueChineseWorkspaceCatalogMissingFunctionPattern       = regexp.MustCompile(`(?i)(?:这个输入对应的函数|(?:与)?之对应的函数)[ \t]*(?:在)?当前工作区的函数目录中不存在`)
	opaqueChineseQuotedFormatProblemPattern                   = regexp.MustCompile(`(?i)这不是一个?[ \t]*[\x60"“]?格式错误[\x60"”]?[ \t]*的问题`)
	opaqueChineseSyntaxFormatClausePattern                    = regexp.MustCompile(`(?i)(这个输入)[ \t]*在语法格式上是(?:完全)?(?:合法|正确)的?[ \t]*[—–-]+[ \t]*(?:它[ \t]*)?符合[ \t]*(?:合法的?[ \t]*)?函数标识格式`)
	opaqueChineseSystemUnregisteredInputPattern               = regexp.MustCompile(`(?i)它[ \t]*(?:并未|并没有|未|没有)[ \t]*在系统中注册过?`)
	opaqueChineseCurrentWorkspaceMissingFunctionPattern       = regexp.MustCompile(`(?i)当前工作区(?:中|里)根本不存在与这个输入对应的(函数(?:实体)?)`)
	opaqueChineseFormatErrorQuotePattern                      = regexp.MustCompile(`(?i)不是[ \t]*[\x60"“]?格式错误[\x60"”]?`)
	opaqueChineseRealFunctionRecommendationPattern            = regexp.MustCompile(`(?i)获取真实的函数标识后再调用`)
	opaqueChineseLegalIdentifierParentheticalPattern          = regexp.MustCompile(`(?i)(这个输入)[ \t]*是一个格式合法的函数标识[ \t]*[（(]符合[ \t]*(?:合法的?[ \t]*)?函数标识格式[）)]`)
	opaqueChineseSystemMissingRegisteredFunctionPattern       = regexp.MustCompile(`(?i)(?:系统中|系统里)不存在与这个输入对应的(函数(?:实体)?)`)
	opaqueChineseParameterFormatErrorPattern                  = regexp.MustCompile(`(?i)(?:而非|而不是)[ \t]*参数格式错误`)
	opaqueChineseNoSuchFunctionResultPattern                  = regexp.MustCompile(`(?i)正常的[\x60"“]?查无此函数[\x60"”]?结果`)
	opaqueChineseInputFormatIsLegalPattern                    = regexp.MustCompile(`(?i)(这个输入)[ \t]*在格式上是(?:合法|正确)的`)
	opaqueChineseNotFormatOrIllegalPattern                    = regexp.MustCompile(`(?i)不是格式问题[或和][ \t]*非法`)
	opaqueChineseRedundantWorkspaceExplanationPattern         = regexp.MustCompile(`(?i)[，,][ \t]*而是当前工作区中不存在与之对应的函数实体`)
	opaqueChineseInputFormatResidualPattern                   = regexp.MustCompile(`(?i)(这个输入)在格式合法`)
	opaqueChineseCatalogIDMissingPattern                      = regexp.MustCompile(`(?i)当前函数目录中不存在对应[ \t]*(?:ID|函数标识)[ \t]*的函数`)
	opaqueChineseSimpleFormatSummaryPattern                   = regexp.MustCompile(`(?i)简单来说：[ \t]*函数标识格式正确[，,][^。\r\n]*。`)
	opaqueChineseIDFormatBulletPattern                        = regexp.MustCompile(`(?i)传入的[ \t]+ID[ \t]+在格式上是合法的[ \t]*[（(]符合函数标识格式[）)][。.]`)
	opaqueChineseRegistrationDashExplanationPattern           = regexp.MustCompile(`(?i)(?:这个输入|它)[ \t]*(?:并未|并没有|未|没有)[ \t]*在系统中注册[ \t]*[—–-]+[ \t]*即当前函数目录中不存在与这个输入对应的函数实体`)
	opaqueChineseFormatProblemInputDuplicatePattern           = regexp.MustCompile(`(?i)不是格式问题输入的问题`)
	opaqueChineseNoSuchFunctionResponsePattern                = regexp.MustCompile(`(?i)正常的[\x60"“]?查无此函数[\x60"”]?(?:结果|响应)`)
	opaqueChineseInvalidRequestFormatPhrasePattern            = regexp.MustCompile(`(?i)这不是一个[ \t]*格式错误或无效的请求`)
	opaqueChineseRedundantWorkspaceEntityPhrasePattern        = regexp.MustCompile(`(?i)[，,][ \t]*而是当前工作区中不存在与这个输入对应的函数实体`)
	opaqueChineseLifecycleConclusionPattern                   = regexp.MustCompile(`(?i)简而言之：[ \t]*标识符?格式正确[^。\r\n]*。`)
	opaqueChineseLegalIdentifierShapeParentheticalPattern     = regexp.MustCompile(`(?i)(这个输入)[ \t]*是一个格式合法的函数标识[ \t]*[（(][^\r\n）)]{0,180}[）)]`)
	opaqueChineseInputSystemUnregisteredPattern               = regexp.MustCompile(`(?i)这个输入[ \t]*并未[ \t]*在系统中注册([。！？,， \t])`)
	opaqueChineseIDRequirementExplanationPattern              = regexp.MustCompile(`(?i)get_function[ \t]*要求传入的[ \t]*ID[ \t]*必须指向一个已存在的函数[，,][ \t]*未注册的标识[ \t]*只会返回正常的[\x60"“]?未找到[\x60"”]?结果。`)
	opaqueChineseSimpleFormatErrorPattern                     = regexp.MustCompile(`(?i)这不是一个[ \t]*格式错误`)
	opaqueChineseBareLegalParentheticalPattern                = regexp.MustCompile(`(?i)(这个输入)[ \t]*虽然格式上是(?:合法|正确)的[ \t]*[（(][^\r\n）)]{0,180}[）)]`)
	opaqueChineseUnregisteredCorrespondingFunctionPattern     = regexp.MustCompile(`(?i)在系统中并未注册任何对应的函数`)
	opaqueChineseDashMissingSimpleFunctionPattern             = regexp.MustCompile(`(?i)[—–-]+[ \t]*系统里不存在这个函数`)
	opaqueChineseParameterFormatWrongPattern                  = regexp.MustCompile(`(?i)(?:而不是|不是)[ \t]*参数格式有误`)
	opaqueChineseDirectoryNotFoundReturnClausePattern         = regexp.MustCompile(`(?i)也就是说，[ \t]*系统里不存在任何与之对应的函数实体，因此[ \t]*get_function[ \t]*返回了[\x60"“]?未找到[\x60"”]?。`)
	opaqueChineseConstructedIDInferencePattern                = regexp.MustCompile(`(?i)这属于正常的[\x60"“]?未找到[\x60"”]?响应，而不是格式问题或系统故障[—–-]+ID本身是良好构造的，只是它指向了一个不存在的函数。`)
	opaqueChineseLegalFormatParentheticalAfterPattern         = regexp.MustCompile(`(?i)(这个输入)格式合法[ \t]*[（(][^\r\n）)]{0,180}[）)]`)
	opaqueChineseGrammarGoodIdentifierPhrasePattern           = regexp.MustCompile(`(?i)[，,][ \t]*属于语法良好的函数标识符`)
	opaqueChineseRegistrationReturnPhrasePattern              = regexp.MustCompile(`(?i)系统中并没有注册过与这个输入对应的函数，所以返回的是正常的[\x60"“]?未找到[\x60"”]?结果`)
	opaqueChineseDashFormatProblemWorkspacePhrasePattern      = regexp.MustCompile(`(?i)[—–-][ \t]*这不是格式问题[，,][ \t]*而是这个输入在当前工作区中不存在`)
	opaqueChineseCurrentWorkspaceFunctionReturnClausePattern  = regexp.MustCompile(`(?i)也就是说，[ \t]*当前工作区里不存在与这个输入对应的函数实体，所以返回了正常的[\x60"“]?未找到[\x60"”]?结果。`)
	opaqueChineseNoSuchFunctionSummaryPattern                 = regexp.MustCompile(`(?i)这属于查无此函数，而非格式错误或系统异常。`)
	opaqueChineseProvidedFunctionIdentifierFormatPattern      = regexp.MustCompile(`(?i)您提供的函数标识[ \t]*在格式上是(?:合法|正确)的[ \t]*[（(]符合[ \t]*(?:合法的?[ \t]*)?函数标识格式[）)]`)
	opaqueChineseBoldInputSystemUnregisteredPattern           = regexp.MustCompile(`(?i)这个输入(?:\*{2}|__)?并未[ \t]*在系统中注册(?:\*{2}|__)`)
	opaqueChineseCurrentCatalogReturnClausePattern            = regexp.MustCompile(`(?i)也就是说，[ \t]*当前函数目录里不存在与这个输入对应的函数实体，因此系统返回了[\x60"“]?未找到[\x60"”]?。`)
	opaqueChineseRealFunctionCallRecommendationPattern        = regexp.MustCompile(`(?i)获取真实的函数标识后再进行调用`)
	opaqueChineseProvidedFunctionIdentifierFormatShortPattern = regexp.MustCompile(`(?i)您提供的函数标识格式(?:正确|合法)`)
	opaqueChineseDuplicateRegistrationSentencePattern         = regexp.MustCompile(`(?i)这个输入对应的函数目前未注册[。！？][ \t]*与这个输入对应的函数目前未注册[。！？]`)
	opaqueChineseProvidedIdentifierFormatLegalPattern         = regexp.MustCompile(`(?i)(?:你|您)提供的标识符格式是合法的`)
	opaqueChineseToolCardValidityExplanationPattern           = regexp.MustCompile(`(?i)系统工具卡中列出的才是已注册的有效标识符。`)
	opaqueChineseNotFoundInsteadFormatErrorPattern            = regexp.MustCompile(`(?i)正常的[\x60"“]?未找到[\x60"”]?结果[，,][ \t]*而非格式错误(?:或无效[ \t]+ID[ \t]*的问题)?`)
	opaqueChineseCurrentWorkspaceAnyFunctionPattern           = regexp.MustCompile(`(?i)它并没有在当前工作区中注册过任何函数`)
	opaqueChineseWorkspaceDirectoryRecordSummaryPattern       = regexp.MustCompile(`(?i)也就是说，这不是格式问题，而是一个正常的[\x60"“]?未找到[\x60"”]?结果[—–-]+工作区的函数目录里不存在与之对应的函数记录。`)
	opaqueChineseLegalFunctionParentheticalPattern            = regexp.MustCompile(`(?i)(这个输入)[ \t]*虽然格式上是合法的函数标识[ \t]*(?:[（(][^\r\n）)]{0,180}[）)])?`)
	opaqueChineseSyntaxParameterPhrasePattern                 = regexp.MustCompile(`(?i)它不是一个[ \t]*语法错误或参数格式问题`)
	opaqueChineseRedundantEntityCatalogPhrasePattern          = regexp.MustCompile(`(?i)[，,][ \t]*而是这个输入对应的函数实体根本不存在于当前工作区的函数目录中`)
	opaqueChineseShortConclusionPattern                       = regexp.MustCompile(`(?i)简而言之：[ \t]*函数标识格式正确[，,][ \t]*(?:但[ \t]*)?对应的函数未注册[，,][ \t]*所以查询结果为[\x60"“]?未找到[\x60"”]?。`)
	opaqueChineseRedundantValidFormatMarkdownPattern          = regexp.MustCompile(`(?i)(?:\*{2}|__)?格式上是(?:合法|正确)的(?:\*{2}|__)?[ \t]*[（(]格式合法[）)]`)
	opaqueChineseSpeculativeFunctionLifecyclePattern          = regexp.MustCompile(`(?i)这个输入指向一个从未被创建[（(]或已被删除[）)]的函数`)
	opaqueChineseInvalidIDProblemPattern                      = regexp.MustCompile(`(?i)格式错误[ \t]*或[ \t]*无效[ \t]+ID[ \t]*的[ \t]*问题`)
	opaqueChineseInvalidIDPattern                             = regexp.MustCompile(`(?i)无效[ \t]+ID`)
	opaqueChineseInputUnregisteredFunctionPattern             = regexp.MustCompile(`(?i)这个输入并未在系统中注册过任何函数`)
	opaqueChineseRealMarkerBeforeAfterPattern                 = regexp.MustCompile(`(?i)真实标识[ \t]+后再调用`)
	// Hosted reasoning sometimes debates a value with "实际的 ID 应该是 …". Replace the
	// complete machine-value clause with an adjacent-card pointer rather than leaving either the
	// opaque id or the internal placeholder in the user-facing transcript.
	// 托管 reasoning 有时会用「实际的 ID 应该是……」讨论值；整段改成指向相邻卡片，不能留下
	// opaque id 或内部 placeholder。
	opaqueChineseIDShouldBePattern            = regexp.MustCompile(`(?i)((?:实际[ \t]*的[ \t]*)?ID)[ \t]*(?:应该是|应为)[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `)([\x60"]?)`)
	opaqueChineseIDShouldBePlaceholderPattern = regexp.MustCompile(`(?i)((?:实际[ \t]*的[ \t]*)?ID)[ \t]*(?:应该是|应为)[ \t]*[\x60"]?(?:the requested item|the referenced item)([\x60"]?)`)
	opaqueChineseIDShouldBePrefixPattern      = regexp.MustCompile(`(?i)((?:实际[ \t]*的[ \t]*)?ID)[ \t]*(?:应该是|应为)[ \t]*[\x60"]?$`)
	// A malformed model phrase can join the human label and opaque value, e.g. "IDfn_…".
	// The ID prefix is still machine data and must be removed even without a word boundary before
	// the entity prefix.
	// 模型有时把人话标签与机器值粘成「IDfn_……」；即使机器前缀前没有词边界，也必须清掉。
	opaqueAdjacentIDPattern                      = regexp.MustCompile(`(?i)\bID(?:[\x60"]?` + opaqueEntityIDPatternSource + `)([\x60"]?)`)
	opaqueHypotheticalIDPlaceholderPattern       = regexp.MustCompile(`(?i)[ \t]*\([ \t]*which (?:would|should) be something like[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item)[\x60"]?[ \t]*\)`)
	opaqueHypotheticalIDPlaceholderPrefixPattern = regexp.MustCompile(`(?i)[ \t]*\([ \t]*which (?:would|should) be something like[ \t]*[\x60"]?`)
	// English reasoning may repeat the same machine value as a sentence rather than a field row.
	// Keep the fact that a record exists, but send the exact value to the adjacent execution card.
	opaqueExecutionIDAssignmentPattern = regexp.MustCompile(`(?i)\b((?:the\s+)?(?:execution|function execution|execution record))[ \t]+id[ \t]*(?:is|was|=|:)[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item)[\x60"]?`)
	// Hosted models also emit the same field as camelCase ("executionId"). Keep the
	// user-facing fact while never exposing either the opaque value or its placeholder.
	// 托管模型也会把同一字段写成 camelCase「executionId」。保留执行记录事实，但不让
	// opaque 值或内部 placeholder 进入用户正文。
	opaqueExecutionIDCamelAssignmentPattern            = regexp.MustCompile(`(?i)\b((?:the\s+)?(?:execution|function[ \t]+execution|execution[ \t]+record))id[ \t]*(?:is|was|=|:)[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item)[\x60"]?`)
	opaqueExecutionIDReferencePlaceholderPattern       = regexp.MustCompile(`(?is)\bexecutionId\b[^\r\n]{0,160}?[\x60"]?(?:the requested item|the referenced item)[\x60"]?`)
	opaqueEnglishNamedIDPlaceholderAssignmentPattern   = regexp.MustCompile(`(?i)\b((?:its|the|this|that|the[ \t]+function|the[ \t]+execution|the[ \t]+record)[ \t]+id)[ \t]*(?:is|was|=)[ \t]*[\x60"]?(?:the requested item|the referenced item)[\x60"]?`)
	opaqueEnglishGenericIDPlaceholderAssignmentPattern = regexp.MustCompile(`(?i)\b(id|identifier)[ \t]*(?:is|was|=)[ \t]*[\x60"]?(?:the requested item|the referenced item)[\x60"]?`)
	opaqueEnglishGenericIDAssignmentPattern            = regexp.MustCompile(`(?i)\b(id|identifier)[ \t]*(?:is|was|=)[ \t]*[\x60"]?(?:the requested item|the referenced item)[\x60"]?`)
	opaqueEnglishGenericIDAssignmentPrefixPattern      = regexp.MustCompile(`(?i)\b(?:id|identifier)[ \t]*(?:is|was|=)[ \t]*[\x60"]?`)
	opaqueEnglishFunctionPlaceholderNamedPattern       = regexp.MustCompile(`(?i)\b((?:the[ \t]+)?function)[ \t]*:[ \t]*[\x60"]?(?:the requested item|the referenced item)[\x60"]?[ \t]+named[ \t]+`)
	// Search reasoning may report "I found it: <opaque placeholder>". Keep the useful fact that
	// the search succeeded, but never expose the value-shaped placeholder in either stream.
	// 搜索 reasoning 可能写「I found it: <opaque placeholder>」。保留“已找到”的事实，不能把像值的
	// placeholder 送进实时流或耐久正文。
	opaqueEnglishFoundFunctionPlaceholderPattern  = regexp.MustCompile(`(?i)(\b(?:the|a)\s+function\s+was\s+found)[ \t]*(?:[—-][ \t]*done)?[,:]?[ \t]*(?:it's|it is)[ \t]*[\x60"]?(?:the requested item|the referenced item)[\x60"]?`)
	opaqueEnglishDonePlaceholderPattern           = regexp.MustCompile(`(?i)(\bdone)[ \t]*[-—:][ \t]*[\x60"]?(?:the requested item|the referenced item)[\x60"]?`)
	opaqueEnglishFoundPlaceholderPattern          = regexp.MustCompile(`(?i)\b((?:i|we)[ \t]+found)(?:[ \t]+it)?[ \t]*:[ \t]*[\x60"]?(?:the requested item|the referenced item)[\x60"]?`)
	opaqueEnglishFoundPlaceholderPrefixPattern    = regexp.MustCompile(`(?i)\b(?:i|we)[ \t]+found(?:[ \t]+it)?[ \t]*:[ \t]*[\x60"]?`)
	opaqueEnglishFoundOpenPrefixPattern           = regexp.MustCompile(`(?i)\b(?:i|we)[ \t]+found(?:[ \t]+it)?[ \t]*$`)
	opaqueExecutionIDCamelAssignmentPrefixPattern = regexp.MustCompile(`(?i)\b((?:the\s+)?(?:execution|function[ \t]+execution|execution[ \t]+record))id[ \t]*(?:is|was|=|:)[ \t]*[\x60"]?`)
	opaqueExecutionIDAssignmentPrefixPattern      = regexp.MustCompile(`(?i)\b((?:the\s+)?(?:execution|function[ \t]+execution|execution[ \t]+record))[ \t]+id[ \t]*(?:is|was|=|:)[ \t]*[\x60"]?`)
	// A model can mention a raw execution ID without an assignment verb, e.g.
	// "call get_function_execution with the execution ID `…`". Replace the whole
	// value-bearing noun phrase so the sentence remains grammatical.
	// 模型也可能直接写「execution ID <value>」而没有 is/冒号；整体改写，避免裸 placeholder 穿出。
	opaqueExecutionIDBarePattern       = regexp.MustCompile(`(?i)\b((?:the\s+)?(?:execution|function[ \t]+execution|execution[ \t]+record))[ \t]+id[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item)[\x60"]?`)
	opaqueExecutionIDBarePrefixPattern = regexp.MustCompile(`(?i)\b((?:the\s+)?(?:execution|function[ \t]+execution|execution[ \t]+record))[ \t]+id[ \t]*[\x60"]?`)
	// The same placeholder may be echoed as an example inside a reasoning sentence,
	// such as "functionId (like `the requested item`)". Keep the example semantic but
	// remove the internal value and the misleading placeholder wording.
	// reasoning 里还会出现「functionId (like `the requested item`)」这种示例回显；保留语义，不保留内部值。
	opaqueIDExamplePlaceholderPattern       = regexp.MustCompile(`(?i)\b([A-Za-z][A-Za-z0-9]*(?:id|identifier))[ \t]*\([ \t]*(?:like|e\.g\.|such as|something like)[ \t]*[\x60"]?(?:` + opaqueEntityIDPatternSource + `|the requested item|the referenced item)[\x60"]?[ \t]*\)`)
	opaqueIDExamplePlaceholderPrefixPattern = regexp.MustCompile(`(?i)\b[A-Za-z][A-Za-z0-9]*(?:id|identifier)[ \t]*\([ \t]*(?:like|e\.g\.|such as|something like)[ \t]*[\x60"]?`)
	// 激活审计的引导句常把 tra_/act_ 直接嵌进普通句子；它不是可复制的 assistant prose，
	// 统一改成指向相邻激活卡的人话，并在整行到齐前暂存，避免占位词闪过实时流。
	opaqueActivationIntroLinePattern = regexp.MustCompile(`(?im)^[ \t]*(?:以下是|here is|this is)[^\r\n]*(?:tra|act)_[A-Za-z0-9]+[^\r\n]*(?:激活|activation)[^\r\n]*$`)
	// A reasoning sentence can expose the same value without a colon, e.g. "versionId changed to
	// the requested item". Keep the fact that a new version exists while removing the unavailable
	// machine-value claim.
	opaqueVersionIDPlaceholderSentencePattern = regexp.MustCompile(`(?i)\bversion[ \t]*id[ \t]+(?:changed|updated|set|is|was)[ \t]+(?:to[ \t]+)?(?:the requested item|the referenced item)\b`)
	// Media receipts commonly label their opaque reference as "Attachment ID". Keep this
	// narrow so the generic field rule does not steal semantic rewrites for Conversation ID or
	// Message ID rows handled by their dedicated search-card rules.
	opaquePlaceholderMediaLabeledLinePattern = regexp.MustCompile(`(?im)^[ \t]*\*\*(attachment|image|media)[ \t]+(id|identifier):\*\*[ \t]*[\x60]?(the requested item|the referenced item)[\x60]?[ \t]*\r?$`)
	// Search results sometimes repeat a redacted ID in prose, e.g. "with id the requested
	// item" or as the first bullet before the human-readable name. Remove only that unavailable
	// machine-value fragment so the reasoning remains factual and fluent.
	// 搜索结果有时会在 prose 中重复已脱敏 ID，例如「with id the requested item」或把它放在
	// 人话名称之前的首个 bullet。只移除不可用的机器值片段，保留事实和流畅度。
	opaqueEntityIDClausePattern       = regexp.MustCompile(`(?i)(?:^|[ \t]+)(?:with|using|having)[ \t]+(?:the[ \t]+)?(?:id|identifier)[ \t]+[\x60"]?(?:the requested item|the referenced item)[\x60"]?`)
	opaqueEntitySearchBulletPattern   = regexp.MustCompile(`(?im)^([ \t]*[-*][ \t]+)[\x60"]?(?:the requested item|the referenced item)[\x60"]?[ \t]*[—-][ \t]*`)
	searchRefWordPattern              = regexp.MustCompile(`(?i)\brefs?\b`)
	searchRefRawValuePattern          = regexp.MustCompile(`(?i)(?:\b` + opaqueEntityIDPatternSource + `(?:\.[A-Za-z0-9_]+)?\b|\b(?:fn|hd|ag|wf|ctl|apf)_[.…]+(?:\.[A-Za-z0-9_]+)?|\b(?:fn|hd|ag|wf|ctl|apf)_<[^>\r\n]+>(?:\.[A-Za-z0-9_<>-]+)?|\bmcp:[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+|\bsearch_blocks\b)`)
	searchBlocksAbbreviatedRefPattern = regexp.MustCompile(`(?i)\b(?:fn|hd|ag|wf|ctl|apf)_[.…]+(?:\.[A-Za-z0-9_]+)?`)
	searchBlocksTemplateRefPattern    = regexp.MustCompile(`(?i)\b(?:fn|hd|ag|wf|ctl|apf)_<[^>\r\n]+>(?:\.[A-Za-z0-9_<>-]+)?`)
	// A search_blocks summary bullet is a semantic unit. Its exact refs stay in the adjacent
	// result card; the prose may retain the kind, count, name and method information only.
	// search_blocks 汇总 bullet 是一个语义单元。精确 ref 留在相邻结果卡，正文只保留类型、数量、名称和方法信息。
	searchBlocksSummaryLinePattern             = regexp.MustCompile(`(?i)^[ \t]*[-*][ \t]*(?:\*{0,3}|_{0,3})(?:agent|function|handler|control|approval|mcp)(?:\*{0,3}|_{0,3})[ \t]*(?:×|x)[ \t]*[0-9]+[ \t]*(?:：|:)[ \t]*`)
	searchBlocksSummaryBoldBulletPrefixPattern = regexp.MustCompile(`(?i)^[ \t]*[-*][ \t]*(?:\*{2,3}|_{2,3})`)
	searchBlocksSummaryBulletOpeningPattern    = regexp.MustCompile(`^[ \t]*[-*][ \t]*$`)
	searchBlocksSummaryCodeOpaqueRefPattern    = regexp.MustCompile("(?i)`(?:the requested item|the referenced item)(?:\\.[A-Za-z0-9_]+)?`")
	searchBlocksSummaryOpaqueRefPattern        = regexp.MustCompile(`(?i)\b(?:the requested item|the referenced item)(?:\.[A-Za-z0-9_]+)?\b`)
	// Search results are pointer data: the exact conversation/message values stay in the adjacent
	// search card, while prose must point there instead of exposing a broken placeholder row.
	// 搜索结果是指针数据：精确对话/消息值留在相邻搜索卡，正文应指向搜索卡而非露出坏占位行。
	opaqueSearchConversationIDLinePattern       = regexp.MustCompile(`(?im)^([ \t]*[-*]?[ \t]*(?:conversation[ \t]+(?:id|identifier)|conversationId)[ \t]*:[ \t]*)` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `[ \t]*$`)
	opaqueSearchConversationTitleMissingPattern = regexp.MustCompile(`(?im)^([ \t]*[-*]?[ \t]*title[ \t]*:[ \t]*)not returned for this hit\.?[ \t]*$`)
	opaqueSearchConversationMessageLinePattern  = regexp.MustCompile(`(?im)^([ \t]*[-*]?[ \t]*(?:message[ \t]+(?:pointer|id)|messageId)[ \t]*:[ \t]*)` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `[ \t]*$`)
	opaqueSearchConversationIDTablePattern      = regexp.MustCompile(`(?im)^([ \t]*\|[^\r\n|]*(?:conversation[ \t]+(?:id|identifier)|conversationId)[^\r\n|]*\|[ \t]*)` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `([ \t]*\|[ \t]*)$`)
	opaqueSearchConversationMessageTablePattern = regexp.MustCompile(`(?im)^([ \t]*\|[^\r\n|]*(?:message[ \t]+(?:pointer|id)|messageId)[^\r\n|]*\|[ \t]*)` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `([ \t]*\|[ \t]*)$`)
	opaqueFlowrunCallIDPlaceholderPattern       = regexp.MustCompile(`(?i)(\b(?:the\s+)?call\s+to\s+[\x60]?get_flowrun[\x60]?\s+)(?:with\s+)?flowrunId\s*[:=]\s*[\x60]?` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `[\x60]?`)
	opaqueFlowrunIDColonPlaceholderPattern      = regexp.MustCompile(`(?i)\bflowrunId\s*:\s*[\x60]?` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `[\x60]?`)
	opaqueFlowrunExampleIDPattern               = regexp.MustCompile(`(?i)\bthe\s+(?:actual|real)\s+fr_[.…]+(?:\s+id)?`)
	opaqueFlowrunArticleExampleIDPattern        = regexp.MustCompile(`(?i)\b(?:a|an)\s+(?:actual|real)\s+[\x60]?fr_[.…]+[\x60]?(?:\s+id)?`)
	opaqueFlowrunMissingTargetSentencePattern   = regexp.MustCompile(`(?i)\bthe\s+requested\s+item\s+(?:does\s+not|doesn['’]t)\s+correspond\s+to\s+any\s+(?:actual\s+)?(?:flowrun|workflow\s+run|run)\s+in\s+this\s+workspace\b`)
	opaqueFlowrunRequestedRunPattern            = regexp.MustCompile(`(?i)\bthe\s+requested\s+item\s+is\s+not\s+a\s+valid,\s+existing\s+flowrun\b`)
	opaqueFlowrunRequestedFlowrunPattern        = regexp.MustCompile(`(?i)\bthe\s+requested\s+flowrun\s+does\s+not\s+correspond\s+to\s+any\s+workflow\s+run\s+in\s+this\s+workspace\b`)
	opaqueFlowrunRequestedFlowrunPhrasePattern  = regexp.MustCompile(`(?im)^(?:[^\r\n]*(?:workflow\s+run|run\s+id|flowrun\s+ids)[^\r\n]*the\s+requested\s+flowrun[^\r\n]*|[^\r\n]*the\s+requested\s+flowrun[^\r\n]*(?:workflow\s+run|run\s+id|flowrun\s+ids)[^\r\n]*)$`)
	opaqueRequestedFlowrunPhrasePattern         = regexp.MustCompile(`(?i)\bthe\s+requested\s+flowrun\b`)
	opaqueFlowrunIDsPhrasePattern               = regexp.MustCompile(`(?i)\bflowrun\s+ids\b`)
	opaqueFlowrunToolCallPattern                = regexp.MustCompile(`(?i)(\bthe\s+)[\x60]?get_flowrun[\x60]?\s+call\b`)
	opaqueFlowrunToolNamePattern                = regexp.MustCompile(`(?i)(\bthe\s+)get_flowrun\s+tool\b`)
	opaqueFlowrunToolNameAnyPattern             = regexp.MustCompile(`(?i)[\x60]?get_flowrun[\x60]?`)
	opaqueFlowrunCallToToolPattern              = regexp.MustCompile(`(?i)\bcall\s+to\s+[\x60]?get_flowrun[\x60]?`)
	opaqueFlowrunWithPlaceholderPattern         = regexp.MustCompile(`(?i)\bno\s+workflow\s+run\s+exists\s+with\s+the\s+requested\s+item\b`)
	opaqueFlowrunWithIDPlaceholderPattern       = regexp.MustCompile(`(?i)\bwith\s+id\s+[\x60]?` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `[\x60]?`)
	opaqueFlowrunNoMatchWithPlaceholderPattern  = regexp.MustCompile(`(?i)(\bthere\s+is\s+no\s+workflow\s+run\b[^\r\n]*?)\s+with\s+the\s+requested\s+item\b`)
	opaqueFlowrunZeroPlaceholderPattern         = regexp.MustCompile(`(?i)\bthe\s+requested\s+item\s+is\s+all\s+zeroes\s+after\s+the\s+run\s+id\s+prefix\b`)
	opaqueFlowrunLinePlaceholderPattern         = regexp.MustCompile(`(?im)^(?:[^\r\n]*(?:workflow\s+run|run\s+id|search_flowruns)[^\r\n]*` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `[^\r\n]*|[^\r\n]*` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `[^\r\n]*(?:workflow\s+run|run\s+id|search_flowruns)[^\r\n]*)$`)
	opaqueFlowrunFailureLinePlaceholderPattern  = regexp.MustCompile(`(?im)^(?:[^\r\n]*(?:placeholder|made-up|fabricated|invalid|doesn['’]t\s+exist)[^\r\n]*` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `[^\r\n]*|[^\r\n]*` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `[^\r\n]*(?:placeholder|made-up|fabricated|invalid|doesn['’]t\s+exist)[^\r\n]*)$`)
	// Hosted models sometimes duplicate the article while reasoning about a missing machine
	// identifier, e.g. "the the requested item id". This is not a valid user-facing phrase and
	// the trailing "id" makes the generic placeholder rule miss it; point to the adjacent result
	// card instead of leaking the internal placeholder through SSE or durable close.
	// 托管模型有时会在推理里把缺失机器标识写成「the the requested item id」。重复冠词加上尾部
	// id 会绕过通用 placeholder 规则；统一指向相邻结果卡，不能穿过 SSE 或 durable close。
	opaqueDuplicatedRequestedItemIDPattern = regexp.MustCompile(`(?i)\bthe\s+the\s+requested\s+item(?:\s+(?:id|identifier))?\b`)
	opaqueRequestedItemIDPattern           = regexp.MustCompile(`(?i)\bthe\s+requested\s+item\s+(?:id|identifier)\b`)
	opaqueRequestedItemPattern             = regexp.MustCompile(`(?i)` + regexp.QuoteMeta(opaqueEntityPlaceholder))
	// The chat prompt uses <section> delimiters. A hosted model can accidentally echo only
	// the closing delimiter into reasoning; it is protocol debris, not user content.
	// chat prompt 用 <section> 分隔上下文；托管模型偶尔会把孤立闭合标签回显进 reasoning，这不是用户内容。
	opaqueLeadingPromptSectionClosePattern      = regexp.MustCompile(`(?is)^\s*</(?:section|think|analysis)>\s*`)
	opaqueChineseDossierErrorFieldPattern       = regexp.MustCompile("(?i)([（(][^）)\\r\\n`*_]{0,80})[`*_]*errorMsg[`*_]*[ \\t]*(?:为空|is[ \\t]+empty)")
	opaqueEnglishDossierErrorFieldPattern       = regexp.MustCompile("(?im)^([ \\t]*(?:[-*•][ \\t]+|[0-9]+[.)][ \\t]+)?)(?:\\*{1,3}|_{1,3}|`)?errorMsg(?:\\*{1,3}|_{1,3}|`)?[ \\t]*:[ \\t]*(?:\\\"\\\"|''|null|nil|none|empty)[ \\t]*(\\r?$)")
	opaqueEnglishDossierMachineFieldNamePattern = regexp.MustCompile(`(?i)\b(errorMsg|elapsedMs|okCount|failedCount)\b`)
	opaqueEnglishDossierFieldListNamePattern    = regexp.MustCompile(`(?i)\b(executionId|functionId|versionId|conversationId|messageId|toolCallId)\b([、,，;；]|[ \t]+(?:等|and|or|etc|identifiers?))`)
	opaqueEnglishDossierFieldLinePattern        = regexp.MustCompile(`(?im)^([ \t]*[-*]?[ \t]*)(executionId|functionId|versionId|conversationId|messageId|toolCallId)([ \t]*:[ \t]*)([^\r\n]*)$`)
	opaqueEnglishDossierInlineFieldNamePattern  = regexp.MustCompile(`(?i)\b(executionId|functionId|versionId|conversationId|messageId|toolCallId)\b`)
	opaqueChineseDossierHistoryCountsPattern    = regexp.MustCompile(`(?i)[（(][^0-9）)]*okCount[^0-9）)]*([0-9]+)[^0-9）)]*failedCount[^0-9）)]*([0-9]+)[^）)]*[）)]`)
	opaqueFlowrunQuotedSuppliedIDPattern        = regexp.MustCompile(`(?i)[\x60](the supplied run id)[\x60]`)
	opaqueFlowrunSentenceStartSuppliedIDPattern = regexp.MustCompile(`(?i)([.!?]\s+)(?:[\x60])?the supplied run id`)
	opaqueFlowrunValueSuppliedIDPattern         = regexp.MustCompile(`(?i)\bthe\s+value\s+the\s+supplied\s+run\s+id\s+looks\s+like\b`)
	opaqueFlowrunLabelPattern                   = regexp.MustCompile(`(?i)\bflowrunId\b|\bflowrun\s+ID\b`)
	opaqueFlowrunPrefixPhrasePattern            = regexp.MustCompile(`(?i)\bthe\s+` + "`?" + `fr_` + "`?" + `\s+prefix\b`)
	opaqueEntityPrefixPhrasePattern             = regexp.MustCompile(`(?i)\bthe\s+` + "`?" + `(?:ws|fn|fnv|fne|fnenv|hd|hdv|hcl|hdenv|hdi|ag|agv|agx|wf|wfv|ctl|ctlv|apf|apfv|trg|tra|trf|tr|cv|msg|blk|att|mdr|mpr|spc|tp|vce|aki|mrp|rel|noti|sr|se|mcp|mcl|doc|mem|todo|fr|frn|sk|act)_` + "`?" + `\s+prefix\b`)
	// Hold a human-readable entity noun at the end of a delta until the following token arrives.
	// Otherwise a provider chunk boundary between "workflow " and "wf_…" would make the later
	// redaction unable to remove the duplicate noun from already-emitted SSE text.
	entityNounPrefixPattern            = regexp.MustCompile(`(?i)(?:\bthe\s+)?(?:workflow|function|handler|agent|trigger|conversation|document|skill|workspace|message|flowrun|run|attachment)\s+(?:\*{1,3}|_{1,3}|` + "`" + `)?$`)
	isoTimestampPattern                = regexp.MustCompile(`\b\d{4}-\d{2}-\d{2}(?:T| )\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2}| UTC)?\b`)
	lastMessageAtFieldPattern          = regexp.MustCompile(`(?i)\blast\s*message\s*at\b\s*[:|=]\s*` + isoTimestampPattern.String())
	nextFireAtFieldPattern             = regexp.MustCompile(`(?i)(?:\bnext[_ ]?fire[_ ]?at\b|\bnext\s+fire(?:\s+time)?\b|下次触发时间)[ \t]*[:：=|][ \t]*` + isoTimestampPattern.String())
	mcpConnectionTimestampLabelPattern = regexp.MustCompile(`(?im)^([ \t]*(?:[-•][ \t]+)?(?:\*\*connected at:\*\*|\*connected at:\*|connected at[ \t]*[:|]|connectedat[ \t]*[:|]|connection time[ \t]*[:|]|reconnected at[ \t]*[:|])[ \t]*)` + regexp.QuoteMeta(opaqueTimestampPlaceholder) + `([ \t]*)$`)
	longIntegerPattern                 = regexp.MustCompile(`\b\d{10,}\b`)
	longHexPattern                     = regexp.MustCompile(`\b[0-9a-fA-F]{32,}\b`)
	positionLinePrefixPattern          = regexp.MustCompile(`(?i)^\s*[-*]?\s*position\s+[0-9]+\s*:`)
	relationIntroChinesePattern        = regexp.MustCompile(`(?m)^([ \t]*以下是)[ \t]*` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?" + `[ \t]*（([^）\r\n]+)）`)
	relationIntroEnglishPattern        = regexp.MustCompile(`(?im)^([ \t]*(?:here are|these are)[ \t]+[^\r\n]*?\bfor[ \t]+)` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?" + `[ \t]*\(([^)\r\n]+)\)`)
	relationToolIntroTypedPattern      = regexp.MustCompile("(?ims)^([ \\t]*`?get_relations`?[ \\t]+对[ \\t]+)`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?[ \\t\\r\\n]*（([^）]+)）[ \\t\\r\\n]*(在)")
	relationToolIntroBarePattern       = regexp.MustCompile("(?ims)^([ \\t]*`?get_relations`?[ \\t]+对[ \\t]+)`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?[ \\t\\r\\n]*(在)")
	relationAgainstIntroTypedPattern   = regexp.MustCompile("(?ims)^([ \\t]*针对[ \\t]+)`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?[ \\t\\r\\n]*[（(]([^）)]+)[）)][ \\t\\r\\n]*(的|在)")
	relationAgainstIntroBarePattern    = regexp.MustCompile("(?ims)^([ \\t]*针对[ \\t]+)`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?[ \\t\\r\\n]*(的|在)")
	relationIntroBareTargetPattern     = regexp.MustCompile(`(?ims)^([ \t]*以下是)[ \t\r\n]*` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?" + `[ \t\r\n]*(在|下|的|关系)`)
	relationIntroTargetFirstPattern    = regexp.MustCompile(`(?ims)^([ \t]*以下是)[ \t\r\n]*` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?" + `[ \t\r\n]*\(([^)]+)\)[ \t]*`)
	relationIntroTypedTargetPattern    = regexp.MustCompile(`(?ims)^([ \t]*以下是[ \t]*(?:函数|工作流|处理器|代理|触发器|文档|技能|function|workflow|handler|agent|trigger|document|skill)[ \t\r\n]*)` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?" + `[ \t\r\n]*（([^）]+)）[ \t]*`)
	relationOpaqueFieldPattern         = regexp.MustCompile(`(?is)[（(,，;；][ \t\r\n]*(?:fromId|toId|edgeId|from ID|to ID|edge ID|边 ID)[ \t\r\n]*=[ \t\r\n]*` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?" + `[ \t\r\n]*[)）]?`)
	relationRecordedTimePattern        = regexp.MustCompile(`(?ims)^[ \t]*(?:[-*•][ \t]+)?(?:创建时间|创建/更新时间)(?:均为|为|[：:])[ \t\r\n]*` + "`?" + regexp.QuoteMeta(opaqueTimestampPlaceholder) + "`?" + `[。.]?[ \t\r\n]*|^[ \t]*(?:[-*•][ \t]+)?(?:created at|updated at|created/updated)[：:][ \t\r\n]*` + "`?" + regexp.QuoteMeta(opaqueTimestampPlaceholder) + "`?" + `[。.]?[ \t\r\n]*`)
	relationMalformedEquipPattern      = regexp.MustCompile("(?im)^([ \\t]*[-*•]?[ \\t]*)该函数被技能[ \\t]+`?([^`\\r\\n]+)`?[ \\t]+通过[ \\t]+`?equip`?[ \\t]+关系装备.*$")
)

// redactOpaqueMachineValues protects the user-facing assistant prose. Tool blocks remain
// untouched: their exact values are the audit/source-of-truth surface and are already rendered
// separately by the product.
func redactOpaqueMachineValues(text string) string {
	text, restoreExactLastMessageAt := protectExplicitLastMessageAt(text)
	text, restoreExactNextFireAt := protectExplicitNextFireAt(text)
	text, restorePublicToolNames := protectPublicToolNames(text)
	// Keep old durable assistant blocks readable after the placeholder vocabulary changes.
	text = strings.ReplaceAll(text, legacyEntityPlaceholder, opaqueEntityPlaceholder)
	text = opaqueLeadingPromptSectionClosePattern.ReplaceAllString(text, "")
	text = redactChineseDossierDanglingTableFragments(text)
	text = isoTimestampPattern.ReplaceAllString(text, opaqueTimestampPlaceholder)
	text = opaqueDuplicatedRequestedItemIDPattern.ReplaceAllString(text, "the ID shown in the adjacent result card")
	text = opaqueRequestedItemIDPattern.ReplaceAllString(text, "the ID shown in the adjacent result card")
	// 中文紧凑执行卷宗的机器字段整行不进入 assistant prose；精确值只在相邻结构化卷宗卡中展示。
	text = opaqueChineseAuditMachineFieldContinuationPattern.ReplaceAllString(text, "")
	text = opaqueChineseAuditMachineFieldPattern.ReplaceAllString(text, "")
	text = opaqueChineseAuditBoldColonMachineFieldPattern.ReplaceAllString(text, "")
	text = opaqueChineseAuditInlineMachineFieldPattern.ReplaceAllString(text, "${1}执行记录（精确 ID 见相邻执行卡）")
	text = opaqueChineseBareExecutionIDPattern.ReplaceAllString(text, "${1}（精确 ID 见相邻执行卡）")
	text = opaqueChineseLocatedPlaceholderParentheticalPattern.ReplaceAllString(text, "（已找到）")
	text = opaqueChineseDossierTimingPlaceholderRowPattern.ReplaceAllString(text, "")
	text = redactChineseDossierPlaceholderTableRows(text)
	text = redactChineseDossierPointerTableRows(text)
	text = redactEmptyChineseToolCallDossierSections(text)
	text = redactEmptyChineseDossierListSections(text)
	text = redactChineseDossierSummaryFields(text)
	text = redactChineseDossierFieldLines(text)
	text = redactEnglishDossierMachineFieldNames(text)
	text = redactEnglishDossierFieldListNames(text)
	text = redactEnglishDossierFieldLines(text)
	text = redactEnglishDossierInlineFieldNames(text)
	text = redactChineseAuditTableRows(text)
	text = opaqueChineseToolQueryIDPattern.ReplaceAllString(text, "${1}目标函数")
	text = opaqueChineseNoMatchingFunctionIDPattern.ReplaceAllString(text, "${1}与其匹配")
	text = opaqueChineseActualFunctionIDPattern.ReplaceAllString(text, "获取实际可用的函数${2}")
	text = opaqueChineseFunctionIDCallPlaceholderPattern.ReplaceAllString(text, "${1}")
	text = opaqueChineseOpaqueIDPhrasePattern.ReplaceAllString(text, "函数标识")
	text = opaqueChineseShapePlaceholderPattern.ReplaceAllString(text, "（函数标识格式）")
	text = opaqueChinesePrefixExamplePattern.ReplaceAllString(text, "合法的函数标识格式")
	text = opaqueChineseToolIDAssignmentPattern.ReplaceAllString(text, "${1}时传入的目标")
	text = opaqueChineseToolIDTimeReferencePattern.ReplaceAllString(text, "${1}时传入的目标")
	text = opaqueChineseToolNameBeforeTimeTargetPattern.ReplaceAllString(text, "${1} 时传入的目标")
	text = opaqueChineseBareToolIDLabelPattern.ReplaceAllString(text, "时传入的目标")
	// Typed Chinese entity assignments must win over the broader "... ID 为 ..." rule below;
	// otherwise a quoted value is rewritten to "文档 ID 已定位" before the typed pass can remove
	// the redundant machine-field label.
	// 带实体类型的中文 ID 赋值必须先于下方通用「…… ID 为……」规则，否则带引号的值会先变成
	// 「文档 ID 已定位」，让专用规则失去机会移除多余的机器字段标签。
	text = opaqueChineseExactIDAssignmentPlaceholderPattern.ReplaceAllString(text, "${1}文档")
	text = opaqueChineseExactIDAssignmentPattern.ReplaceAllString(text, "${1}文档")
	text = opaqueChineseLocatedIDAssignmentPlaceholderPattern.ReplaceAllString(text, "${1}${2}")
	text = opaqueChineseLocatedIDAssignmentPattern.ReplaceAllString(text, "${1}${2}")
	text = opaqueChineseDecoratedIDAssignmentPlaceholderPattern.ReplaceAllString(text, "${1}已定位")
	text = opaqueChineseDecoratedIDAssignmentPattern.ReplaceAllString(text, "${1}已定位")
	text = opaqueChineseIDAssignmentPlaceholderPattern.ReplaceAllString(text, "${1}已定位")
	text = opaqueChineseIDAssignmentPattern.ReplaceAllString(text, "${1}已定位")
	text = opaqueChineseLocatedBareIDPlaceholderPattern.ReplaceAllString(text, "${1}ID 已定位")
	text = opaqueChineseLocatedBareIDPattern.ReplaceAllString(text, "${1}ID 已定位")
	text = opaqueChineseBareIDPlaceholderAssignmentPattern.ReplaceAllString(text, "${1}ID 已定位")
	text = opaqueChineseBareIDAssignmentPattern.ReplaceAllString(text, "${1}ID 已定位")
	text = opaqueChineseToolValueBeforeIDPattern.ReplaceAllString(text, "${1} 后")
	text = opaqueChineseToolPlaceholderIDReferencePattern.ReplaceAllString(text, "${1} 后")
	text = opaqueChineseFunctionInputAfterMentionPattern.ReplaceAllString(text, "后")
	text = opaqueChineseMissingIDColonPattern.ReplaceAllString(text, "${1}函数标识")
	text = opaqueChineseRawValueBeforeIDPattern.ReplaceAllString(text, "这个输入")
	text = opaqueChineseTargetBeforeIDPattern.ReplaceAllString(text, "${1}${2} ID")
	text = opaqueChineseToolIDReferencePattern.ReplaceAllString(text, "${1} 后")
	text = opaqueChineseToolReferencePattern.ReplaceAllString(text, "${1} 后")
	text = opaqueChineseConjoinedReferencePattern.ReplaceAllString(text, "后")
	text = opaqueChineseIDReferencePattern.ReplaceAllString(text, "${1}的目标见相邻工具卡")
	text = opaqueChineseQualifiedIDReferencePattern.ReplaceAllString(text, "${1}")
	text = opaqueChineseMissingIDColonBarePattern.ReplaceAllString(text, "${1}函数标识")
	text = opaqueChineseMissingIDExplanationPattern.ReplaceAllString(text, "该函数引用格式正确，但实际并不存在")
	text = opaqueChineseMissingIDSentencePattern.ReplaceAllString(text, "${1}${2}")
	text = opaqueChineseAnyMissingIDSentencePattern.ReplaceAllString(text, "${1}${2}")
	text = opaqueChineseMissingIDParentheticalSentencePattern.ReplaceAllString(text, "${1}${2}")
	text = opaqueChineseMissingIDLabelInSentencePattern.ReplaceAllString(text, "${1}${2}")
	text = opaqueChineseMissingIDLabelPattern.ReplaceAllString(text, "${1}${2}")
	text = opaqueChineseGenericMissingIDLabelPattern.ReplaceAllString(text, "${1}输入${2}")
	text = opaqueChineseIDFabricatedFunctionPattern.ReplaceAllString(text, "这个输入${1}")
	text = opaqueChineseFabricatedIDExplanationPattern.ReplaceAllString(text, "该 ID ${1}")
	text = opaqueChineseIDFormatParentheticalPattern.ReplaceAllString(text, "${1}")
	text = opaqueChineseIDPrefixFormatPattern.ReplaceAllString(text, "格式合法")
	text = opaqueChineseIDFormatStructurePattern.ReplaceAllString(text, "符合合法的函数标识格式")
	text = opaqueChineseIDFormatPrefixPattern.ReplaceAllString(text, "${1}函数标识前缀")
	text = opaqueChineseIDPrefixParentheticalPattern.ReplaceAllString(text, "${1}格式合法${2}")
	text = opaqueChineseIDPrefixPhrasePattern.ReplaceAllString(text, "以合法格式开头")
	text = opaqueChineseDanglingIDExplanationPattern.ReplaceAllString(text, "${1}这个输入是一个")
	text = opaqueChineseFunctionShapePattern.ReplaceAllString(text, "${1}标识")
	text = opaqueChineseFabricatedInputPattern.ReplaceAllString(text, "${1}${2}输入是虚构的")
	text = opaqueChineseMissingIDDirectCallPattern.ReplaceAllString(text, "${1}函数标识${2}")
	text = opaqueChineseNonexistentIDDirectCallPattern.ReplaceAllString(text, "${1}函数标识${2}")
	text = opaqueChineseFabricatedIDDirectCallPattern.ReplaceAllString(text, "用一个不存在的函数标识${1}")
	text = opaqueChineseMissingIDInvocationPattern.ReplaceAllString(text, "${1}标识${2}")
	text = opaqueChineseMissingIDStandaloneReferencePattern.ReplaceAllString(text, "${1}函数标识")
	text = opaqueChineseFoundActualIDPattern.ReplaceAllString(text, "找到实际存在的函数后")
	text = opaqueChineseIDFunctionNotCreatedPattern.ReplaceAllString(text, "${1}这个输入对应的函数从未被创建过")
	text = opaqueChineseRegisteredIDFunctionPattern.ReplaceAllString(text, "${1}与这个输入对应的函数")
	text = opaqueChineseRegisteredFunctionForIDPattern.ReplaceAllString(text, "${1}${2}")
	text = opaqueChineseCorrectFunctionIDAfterPattern.ReplaceAllString(text, "${1}函数${2}")
	text = opaqueChineseIDLookupFunctionPattern.ReplaceAllString(text, "${1}这个输入${2}")
	text = opaqueChineseBareIDFormatPhrasePattern.ReplaceAllString(text, "${1}格式没问题")
	text = opaqueChineseFunctionIDNaturalRequirementPattern.ReplaceAllString(text, "${1}")
	text = opaqueChineseFunctionIDRequirementPattern.ReplaceAllString(text, "${1}")
	text = opaqueChineseFunctionIDDirectoryRequirementPattern.ReplaceAllString(text, "${1}")
	text = opaqueChineseFunctionIDBroadRequirementPattern.ReplaceAllString(text, "${1}")
	text = opaqueChineseBareFunctionIDLabelPattern.ReplaceAllString(text, "函数标识")
	text = opaqueChineseInputIDLabelPattern.ReplaceAllString(text, "这个输入")
	text = opaqueChineseIDBeforeInputPattern.ReplaceAllString(text, "${1}")
	text = opaqueChineseValidInputPattern.ReplaceAllString(text, "有效的函数标识")
	text = opaqueChineseRealMarkerFollowPattern.ReplaceAllString(text, "拿到真实标识后再调用")
	text = opaqueChineseCorrespondingInputPattern.ReplaceAllString(text, "对应的函数标识")
	text = opaqueChineseCorrespondingCardReferencePattern.ReplaceAllString(text, "对应的函数标识")
	text = opaqueChineseTargetBeforeInputPattern.ReplaceAllString(text, "时传入的目标")
	text = opaqueChineseRealIDPattern.ReplaceAllString(text, "真实标识")
	text = opaqueChineseExistingFunctionIDPattern.ReplaceAllString(text, "实际存在的函数")
	text = opaqueChineseFunctionCorrespondencePhrasePattern.ReplaceAllString(text, "${1}与之对应")
	text = opaqueChineseDueToCreationPattern.ReplaceAllString(text, "由于这个输入从未被创建过")
	text = opaqueChineseNonexistentIDPhrasePattern.ReplaceAllString(text, "${1}标识")
	text = opaqueChineseAllZeroIDPattern.ReplaceAllString(text, "${1}输入")
	text = opaqueChineseRealMarkerFormatPattern.ReplaceAllString(text, "真实标识均符合合法格式")
	text = opaqueChineseDanglingTargetBeforeInputPattern.ReplaceAllString(text, "这个输入")
	text = opaqueChineseIDNotFunctionPattern.ReplaceAllString(text, "这个输入${1}")
	text = opaqueChinesePlaceholderNotFunctionPattern.ReplaceAllString(text, "这个输入${1}")
	text = opaqueChinesePlaceholderCorrespondencePattern.ReplaceAllString(text, "当前工作区中没有与之对应的函数记录")
	text = opaqueChineseGenericIDCorrespondencePattern.ReplaceAllString(text, "${1}之对应")
	text = opaqueChineseDanglingIDCorrespondencePattern.ReplaceAllString(text, "之对应")
	text = opaqueChineseFunctionCorrespondencePattern.ReplaceAllString(text, "系统中没有任何函数与之对应")
	text = opaqueChineseFunctionCorrespondenceWithThisIDPattern.ReplaceAllString(text, "系统中并没有任何函数与这个输入对应")
	text = opaqueChineseInputIDCorrespondencePattern.ReplaceAllString(text, "这个输入对应")
	text = opaqueChineseGenericMissingIDSentencePattern.ReplaceAllString(text, "${1} ${2}")
	text = opaqueChineseGenericMissingIDPlaceholderLocationPattern.ReplaceAllString(text, "${1}输入${2}")
	text = opaqueChineseGenericMissingIDLocationPattern.ReplaceAllString(text, "${1}输入${2}")
	text = opaqueChineseIDShouldBePlaceholderPattern.ReplaceAllString(text, "${1} 见相邻工具卡")
	text = opaqueChineseIDShouldBePattern.ReplaceAllString(text, "${1} 见相邻工具卡")
	text = opaqueAdjacentIDPattern.ReplaceAllString(text, "ID 见相邻工具卡${1}")
	text = opaqueChineseGenericIDAssignmentPattern.ReplaceAllString(text, "${1} 已定位")
	text = opaqueChineseNonexistentLocatedIDPattern.ReplaceAllString(text, "不存在的${1}")
	text = opaqueHypotheticalIDPlaceholderPattern.ReplaceAllString(text, "")
	text = opaqueExecutionIDCamelAssignmentPattern.ReplaceAllString(text, "${1} ID is available in the adjacent execution card")
	text = opaqueExecutionIDAssignmentPattern.ReplaceAllString(text, "${1} is available in the adjacent execution card")
	text = opaqueExecutionIDReferencePlaceholderPattern.ReplaceAllStringFunc(text, func(match string) string {
		if containsHan(match) {
			return "执行 ID 的精确值见相邻执行卡"
		}
		return "the execution ID is available in the adjacent execution card"
	})
	text = opaqueEnglishNamedIDPlaceholderAssignmentPattern.ReplaceAllString(text, "${1} is shown in the adjacent result card")
	text = opaqueEnglishGenericIDPlaceholderAssignmentPattern.ReplaceAllString(text, "${1} is available in the adjacent result card")
	text = opaqueEnglishFunctionPlaceholderNamedPattern.ReplaceAllString(text, "${1} named ")
	text = opaqueEnglishFoundFunctionPlaceholderPattern.ReplaceAllString(text, "${1}.")
	text = opaqueEnglishDonePlaceholderPattern.ReplaceAllString(text, "${1}")
	text = opaqueEnglishFoundPlaceholderPattern.ReplaceAllString(text, "${1} it")
	text = opaqueExecutionIDBarePattern.ReplaceAllString(text, "${1} ID from the adjacent execution card")
	text = opaqueIDExamplePlaceholderPattern.ReplaceAllString(text, "${1} (like a real ID)")
	text = opaqueActivationIntroLinePattern.ReplaceAllStringFunc(text, func(line string) string {
		if containsHan(line) {
			return "以下是该激活审计记录的完整字段："
		}
		return "Here is the complete activation record."
	})
	text = redactMCPConnectionTimestampLabelLines(text)
	text = opaqueWebhookEndpointPattern.ReplaceAllString(text, "See the exact webhook endpoint in the trigger card.")
	text = opaqueWebhookEndpointPlaceholderPattern.ReplaceAllString(text, "See the exact webhook endpoint in the trigger card.")
	text = opaqueFlowrunIDTableRowPattern.ReplaceAllString(text, "| **Run** | Current run |")
	text = opaqueFlowrunIDPlaceholderTableRowPattern.ReplaceAllString(text, "| **Run** | Current run |")
	text = opaqueVersionTableRowPattern.ReplaceAllString(text, "| **Version** | Current version |")
	text = opaqueVersionPlaceholderTableRowPattern.ReplaceAllString(text, "| **Version** | Current version |")
	text = opaquePinnedRefsTableRowPattern.ReplaceAllString(text, "| **References** | Internal references |")
	text = opaqueRefPlaceholderTableRowPattern.ReplaceAllString(text, "| **Ref** | Internal reference |")
	text = opaqueNodeRecordPlaceholderTableRowPattern.ReplaceAllString(text, "| **Node record** | Internal record |")
	text = opaquePinnedRefsHeadingPattern.ReplaceAllString(text, "**References:** Internal references")
	text = opaquePinnedRefsBulletPattern.ReplaceAllString(text, "- Internal approval references")
	text = opaqueVersionIDActualLinePattern.ReplaceAllString(text, "")
	text = opaqueEntityIDNameParentheticalPattern.ReplaceAllString(text, "${1}")
	text = opaqueEntityParentheticalPattern.ReplaceAllString(text, "")
	text = opaqueFlowrunReportTitlePattern.ReplaceAllString(text, "${1} Report")
	text = opaqueFlowrunTitlePattern.ReplaceAllString(text, "${1}")
	text = opaqueFlowrunAssignmentPattern.ReplaceAllString(text, "the current run")
	text = opaqueFlowrunReportTitlePlaceholderPattern.ReplaceAllString(text, "${1} Report")
	text = opaqueFlowrunReportForPlaceholderPattern.ReplaceAllString(text, "${1} report")
	text = opaqueFlowrunTitlePlaceholderPattern.ReplaceAllString(text, "${1}")
	text = opaqueFlowrunAssignmentPlaceholderPattern.ReplaceAllString(text, "the current run")
	text = opaqueReportDecoratedPattern.ReplaceAllString(text, "${1} report")
	text = opaqueReportForPattern.ReplaceAllString(text, "${1} report")
	text = opaqueFlowrunSummaryTargetPattern.ReplaceAllString(text, "${1}:")
	text = opaquePinnedReferenceNaturalPattern.ReplaceAllString(text, "Pinned reference: The function version is pinned.")
	text = opaqueTypedIDSubjectPattern.ReplaceAllString(text, "${1}requested ${2}")
	text = opaqueAttachmentIDAssignmentPattern.ReplaceAllString(text, "${1} is ready")
	text = opaqueMediaAttachmentAssignmentPattern.ReplaceAllString(text, "${1} is ready")
	text = opaqueEnglishNonexistentIDReferencePattern.ReplaceAllString(text, "${1} function reference")
	text = opaqueEnglishExactIDReferencePattern.ReplaceAllString(text, "${1} function reference")
	text = opaqueChineseExactIDAssignmentPattern.ReplaceAllString(text, "${1}文档")
	text = opaqueEnglishExactIDAssignmentPattern.ReplaceAllString(text, "${1} document")
	text = opaqueEnglishItsIDAssignmentPattern.ReplaceAllString(text, "${1}the document")
	text = opaqueJSONIDFieldPattern.ReplaceAllString(text, "${1}document${3}")
	text = opaqueJSONNamedIDFieldPattern.ReplaceAllString(text, "${1}${2}${3}see adjacent result card${5}")
	text = opaqueJSONNamedTimeFieldPlaceholderPattern.ReplaceAllString(text, "${1}${2}${3}see adjacent result card${4}")
	text = opaqueEnglishIDAssignmentPattern.ReplaceAllString(text, "${1}")
	text = opaqueIDFieldPattern.ReplaceAllString(text, "")
	text = opaqueChineseLocatedIDAssignmentPattern.ReplaceAllString(text, "${1}${2}")
	text = opaqueChineseDecoratedIDAssignmentPattern.ReplaceAllString(text, "${1}已定位")
	text = opaqueChineseIDAssignmentPattern.ReplaceAllString(text, "${1}已定位")
	text = opaqueIDSubjectPattern.ReplaceAllStringFunc(text, func(match string) string {
		if match != "" && unicode.IsUpper([]rune(match)[0]) {
			return "The requested item"
		}
		return "the requested item"
	})
	text = entityIDPattern.ReplaceAllString(text, opaqueEntityPlaceholder)
	// Skill activation can render session and directory values as labeled prose rather than a
	// Markdown table. Once the generic ID pass turns a workspace/session id into a placeholder,
	// leaving that placeholder inside a path creates a value-shaped path that cannot be copied or
	// trusted. Keep the label, and point to the adjacent activation card instead.
	// Skill 激活也可能把 session/目录值渲染成带标签的普通文本而非 Markdown 表格。通用 ID 脱敏把
	// workspace/session id 换成 placeholder 后，若仍把它留在路径里，就会变成既不可复制又不诚实的
	// 「看起来像值」路径。保留字段语义，指向相邻 activation card。
	text = redactOpaqueSkillContextLines(text)
	// Run before relation-field cleanup: relation tables also use Field/Value, but activation
	// records have a separate structured card that can carry exact ID/time truth.
	text = redactActivationDetailTableRows(text)
	text = opaquePlaceholderIDParentheticalPattern.ReplaceAllString(text, "")
	text = searchBlocksAbbreviatedRefPattern.ReplaceAllString(text, opaqueEntityPlaceholder)
	text = searchBlocksTemplateRefPattern.ReplaceAllString(text, opaqueEntityPlaceholder)
	text = opaqueVersionIDPlaceholderSentencePattern.ReplaceAllString(text, "version reference updated")
	text = opaqueVersionIDPlaceholderLinePattern.ReplaceAllString(text, "")
	text = redactOpaquePlaceholderParentheticalLists(text)
	text = opaquePositionPlaceholderNamePattern.ReplaceAllString(text, "${1}${2}")
	text = opaqueChineseExactIDAssignmentPlaceholderPattern.ReplaceAllString(text, "${1}文档")
	text = opaqueEnglishExactIDAssignmentPlaceholderPattern.ReplaceAllString(text, "${1} document")
	text = opaqueEnglishItsIDAssignmentPlaceholderPattern.ReplaceAllString(text, "${1}the document")
	text = opaqueJSONIDFieldPlaceholderPattern.ReplaceAllString(text, "${1}document${2}")
	text = opaqueJSONNamedIDFieldPlaceholderPattern.ReplaceAllString(text, "${1}${2}${3}see adjacent result card${4}")
	text = opaqueJSONNamedTimeFieldPlaceholderPattern.ReplaceAllString(text, "${1}${2}${3}see adjacent result card${4}")
	text = opaqueEnglishIDAssignmentPlaceholderPattern.ReplaceAllString(text, "${1}")
	text = opaqueIDFieldPlaceholderPattern.ReplaceAllString(text, "")
	text = opaqueChineseLocatedIDAssignmentPlaceholderPattern.ReplaceAllString(text, "${1}${2}")
	text = opaqueChineseDecoratedIDAssignmentPlaceholderPattern.ReplaceAllString(text, "${1}已定位")
	text = opaqueChineseIDAssignmentPlaceholderPattern.ReplaceAllString(text, "${1}已定位")
	// A raw opaque ref can become the neutral placeholder only at the generic ID pass above;
	// repeat the structured-row cleanup after that pass so the final close snapshot cannot retain
	// a placeholder merely because its source prefix was not known to the first pass.
	text = opaqueFlowrunIDPlaceholderTableRowPattern.ReplaceAllString(text, "| **Run** | Current run |")
	text = redactFlowrunSearchRows(text)
	text = redactSearchBlocksTableRows(text)
	text = opaqueFlowrunChineseWorkflowListPattern.ReplaceAllString(text, "${1}该运行${2}该工作流${3}")
	text = opaqueFlowrunChineseStatusListPattern.ReplaceAllString(text, "${1}该运行记录${2}")
	text = opaqueFlowrunStatusListPlaceholderPattern.ReplaceAllString(text, "${1}")
	text = opaqueFlowrunStatusLinePattern.ReplaceAllStringFunc(text, func(line string) string {
		if !strings.Contains(line, opaqueEntityPlaceholder) {
			return line
		}
		line = opaqueFlowrunStatusPlaceholderRunPattern.ReplaceAllString(line, "")
		line = opaqueFlowrunStatusEmptyDetailPattern.ReplaceAllString(line, "")
		return line
	})
	text = opaqueVersionPlaceholderTableRowPattern.ReplaceAllString(text, "| **Version** | Current version |")
	text = opaqueVersionIDPlaceholderLinePattern.ReplaceAllString(text, "")
	text = opaqueRefPlaceholderTableRowPattern.ReplaceAllString(text, "| **Ref** | Internal reference |")
	text = opaqueNodeRecordPlaceholderTableRowPattern.ReplaceAllString(text, "| **Node record** | Internal record |")
	text = opaquePinnedRefsPlaceholderTableRowPattern.ReplaceAllString(text, "| Internal reference | Current version |")
	text = opaquePinnedRefAnnotatedPlaceholderTableRowPattern.ReplaceAllString(text, "| Internal approval reference | Current version |")
	text = redactOpaquePlaceholderLabeledLines(text)
	text = opaqueFlowrunOverviewIDPlaceholderPattern.ReplaceAllString(text, "- Run: Current run")
	text = opaqueFlowrunOverviewVersionPlaceholderPattern.ReplaceAllString(text, "- Version: Current version")
	text = opaquePinnedRefsPlaceholderBulletPattern.ReplaceAllString(text, "- Internal approval references")
	text = opaquePinnedRefsNaturalBulletPattern.ReplaceAllString(text, "- Internal approval references")
	text = opaquePinnedRefsNaturalSentencePattern.ReplaceAllString(text, "**References:** Internal approval reference is pinned to the current version.")
	text = redactSearchRefPlaceholderSentences(text)
	text = redactSearchBlocksSummaryLines(text)
	text = redactRelationIntro(text)
	text = redactRelationReasoningIDs(text)
	text = redactRelationReasoningEdges(text)
	text = redactRelationPlaceholderParentheticals(text)
	text = redactRelationTableRows(text)
	text = redactRelationFieldTableRows(text)
	text = redactRelationIDLines(text)
	text = redactRelationEntityLines(text)
	text = redactRelationOpaqueFieldAssignments(text)
	text = redactRelationMachineFieldAssignments(text)
	text = relationStandalonePlaceholderLinePattern.ReplaceAllString(text, "")
	text = relationRecordedCamelTimePattern.ReplaceAllString(text, "")
	text = redactRelationCamelTimeLines(text)
	text = redactRelationChineseTimeLines(text)
	text = relationOpaqueFieldPattern.ReplaceAllString(text, "")
	text = relationRecordedTimePattern.ReplaceAllString(text, "")
	text = redactRelationAllowedToolsLines(text)
	text = relationMalformedEquipPattern.ReplaceAllString(text, "${1}该函数被技能 ${2} 通过 equip 关系装备。")
	text = opaqueTriggerIDPlaceholderLinePattern.ReplaceAllStringFunc(text, func(match string) string {
		if containsHan(text) {
			return "精确触发器 ID 见旁边的触发器卡片。"
		}
		return redactTriggerIDPlaceholderLine(match)
	})
	text = opaqueFlowrunSummaryTargetPattern.ReplaceAllString(text, "${1}:")
	text = opaquePinnedReferenceNaturalPattern.ReplaceAllString(text, "Pinned reference: The function version is pinned.")
	text = opaqueFlowrunIDFieldPlaceholderPattern.ReplaceAllString(text, "**Requested ID:** Supplied run ID")
	text = opaquePlaceholderMediaLabeledLinePattern.ReplaceAllString(text, "")
	text = opaquePlaceholderLabeledLinePattern.ReplaceAllString(text, "")
	text = opaquePlaceholderBoldColonLabeledLinePattern.ReplaceAllString(text, "")
	text = opaqueFlowrunCallIDPlaceholderPattern.ReplaceAllString(text, "${1}for the supplied run")
	text = opaqueFlowrunIDColonPlaceholderPattern.ReplaceAllString(text, "run ID: supplied run ID")
	text = opaqueFlowrunMissingTargetSentencePattern.ReplaceAllString(text, "The supplied run ID does not correspond to any flowrun in this workspace")
	text = opaqueFlowrunTargetPlaceholderPattern.ReplaceAllString(text, "${1}the requested run")
	text = opaqueFlowrunIDPlaceholderPattern.ReplaceAllString(text, "for the requested run")
	text = opaqueFlowrunMissingIDPattern.ReplaceAllString(text, "${1}the requested run${2}")
	text = opaqueFlowrunNoMatchPattern.ReplaceAllString(text, "${1} matching the request")
	text = opaqueFlowrunRequestedIDRowPattern.ReplaceAllString(text, "| **Requested ID** | Supplied run ID |")
	text = opaqueFlowrunRequestedRunPattern.ReplaceAllString(text, "The requested run is not a valid, existing flowrun")
	text = opaqueFlowrunRequestedFlowrunPattern.ReplaceAllString(text, "The supplied run ID does not correspond to any workflow run in this workspace")
	text = opaqueFlowrunRequestedFlowrunPhrasePattern.ReplaceAllStringFunc(text, func(line string) string {
		return opaqueRequestedFlowrunPhrasePattern.ReplaceAllString(line, "the supplied run ID")
	})
	text = opaqueFlowrunIDsPhrasePattern.ReplaceAllString(text, "run IDs")
	text = opaqueFlowrunToolCallPattern.ReplaceAllString(text, "${1}run lookup")
	text = opaqueFlowrunToolNamePattern.ReplaceAllString(text, "${1}run lookup tool")
	text = opaqueFlowrunCallToToolPattern.ReplaceAllString(text, "run lookup")
	text = opaqueFlowrunToolNameAnyPattern.ReplaceAllString(text, "run lookup")
	text = opaqueFlowrunWithPlaceholderPattern.ReplaceAllString(text, "no workflow run exists for the supplied run")
	text = opaqueFlowrunWithIDPlaceholderPattern.ReplaceAllString(text, "for the supplied run ID")
	text = opaqueFlowrunNoMatchWithPlaceholderPattern.ReplaceAllString(text, "${1} matching the supplied run")
	text = opaqueFlowrunZeroPlaceholderPattern.ReplaceAllString(text, "The supplied run ID has an all-zero suffix after the run ID prefix")
	text = opaqueFlowrunLinePlaceholderPattern.ReplaceAllStringFunc(text, func(line string) string {
		return opaqueRequestedItemPattern.ReplaceAllStringFunc(line, func(match string) string {
			if match != "" && unicode.IsUpper([]rune(match)[0]) {
				return "The supplied run ID"
			}
			return "the supplied run ID"
		})
	})
	text = opaqueFlowrunFailureLinePlaceholderPattern.ReplaceAllStringFunc(text, func(line string) string {
		return opaqueRequestedItemPattern.ReplaceAllStringFunc(line, func(match string) string {
			if match != "" && unicode.IsUpper([]rune(match)[0]) {
				return "The supplied run ID"
			}
			return "the supplied run ID"
		})
	})
	text = opaqueFlowrunQuotedSuppliedIDPattern.ReplaceAllString(text, "$1")
	text = opaqueFlowrunSentenceStartSuppliedIDPattern.ReplaceAllString(text, "${1}The supplied run ID")
	text = opaqueFlowrunValueSuppliedIDPattern.ReplaceAllString(text, "the supplied run ID looks like")
	text = opaqueFlowrunPrefixPhrasePattern.ReplaceAllString(text, "the run ID prefix")
	text = opaqueFlowrunExampleIDPattern.ReplaceAllString(text, "the run ID")
	text = opaqueFlowrunArticleExampleIDPattern.ReplaceAllString(text, "a real run ID")
	text = opaqueFlowrunLabelPattern.ReplaceAllString(text, "run ID")
	text = opaqueEntityPrefixPhrasePattern.ReplaceAllString(text, "the ID prefix")
	text = opaquePlaceholderParentheticalPattern.ReplaceAllString(text, "")
	text = opaqueEntityTypedPlaceholderParentheticalPattern.ReplaceAllString(text, "")
	text = opaqueEntityNounDecoratedPlaceholderPattern.ReplaceAllString(text, "${1}${2}${3}")
	text = opaqueEntityNounPlaceholderPattern.ReplaceAllString(text, "${1}${2}")
	text = opaqueEntityChineseNounPlaceholderPattern.ReplaceAllString(text, "${1}")
	text = opaqueEntityIDClausePattern.ReplaceAllString(text, "")
	text = opaqueEntitySearchBulletPattern.ReplaceAllString(text, "$1")
	text = opaqueSearchConversationIDLinePattern.ReplaceAllString(text, "${1}See the exact conversation in the search card.")
	text = opaqueSearchConversationTitleMissingPattern.ReplaceAllString(text, "${1}See the exact conversation in the search card.")
	text = opaqueSearchConversationMessageLinePattern.ReplaceAllString(text, "${1}See the exact matching message in the search card.")
	text = opaqueSearchConversationIDTablePattern.ReplaceAllString(text, "${1}See the exact conversation in the search card.${2}")
	text = opaqueSearchConversationMessageTablePattern.ReplaceAllString(text, "${1}See the exact matching message in the search card.${2}")
	// A workspace id inside a filesystem path becomes a placeholder after the generic entity
	// pass. Do not leave that placeholder embedded in a path-looking value: it is neither safe to
	// copy nor honest to present as a path. Keep the field and point to the exact tool card.
	// workspace id 经过通用实体脱敏后会落在文件路径中。不能把占位符嵌在路径里，既不可复制也不诚实；
	// 保留字段语义并明确指向精确 tool card。
	text = redactOpaquePathTableRows(text)
	// Skill activation summaries may use a two-column semantic table instead of labeled prose.
	// Handle Session/Directory rows before the generic table-cell fallback, so a placeholder
	// cannot survive as a value-shaped cell or as a fake path.
	// skill 激活摘要也可能用二列表格表达字段。先处理 Session/Directory 行，再走通用表格兜底，
	// 不能让 placeholder 以值或伪路径的形状留在助手正文。
	text = redactOpaqueSkillContextTableRows(text)
	// A model must not claim that every field was copied verbatim when opaque fields were
	// intentionally redirected to the adjacent activation card. Rewrite that contradiction at
	// the same deterministic user-facing boundary as the value redaction.
	// 如果 opaque 字段已被指向相邻激活卡，模型不能再声称「全部逐字原样、未替换」。在同一出口
	// 把这类自相矛盾的声明改成可验证的人话。
	text = redactSkillVerbatimClaimLines(text)
	// A placeholder inside a Markdown table is still not a user-facing value. During streaming,
	// replace the cell with an honest unavailable marker; the complete close pass below can remove
	// an entirely unavailable ID column instead of leaving a misleading header behind.
	// Markdown 表格里的 placeholder 仍不是用户值。流式阶段先替换为诚实的不可用标记；完整 close 再移除整列。
	// Activation detail tables are special: the exact trigger ID and creation time remain available
	// in the adjacent structured activation card. Point those rows there before the generic trigger
	// handler can send the user to the less-specific trigger card.
	// activation 详情表的精确值仍在旁边的结构化活动卡片中，必须先于通用 trigger 行处理。
	text = redactActivationDetailTableRows(text)
	text = redactTriggerIDPlaceholderTableRows(text)
	text = redactOpaquePlaceholderTableCells(text)
	// A two-column Field/Value table encodes an ID as a row rather than a column. Remove an
	// unavailable ID row too; otherwise the earlier cell pass turns it into `ID | -` and the
	// user still sees a misleading machine-field placeholder row.
	// 二列表格把 ID 编成行而不是列。不可用的 ID 行也要移除；否则上一步只会把它变成 `ID | -`，
	// 用户仍会看到误导性的机器字段行。
	text = redactOpaquePlaceholderFieldTableRows(text)
	// Attachment metadata has a useful exact timestamp in the adjacent tool card. Do not leave a
	// table cell that looks like a value but only says "the recorded time"; point the reader to the
	// exact, copyable card instead while keeping the global timestamp redaction boundary intact.
	text = redactAttachmentTimestampTableRows(text)
	// MCP lifecycle metadata has the same exact value in the structured status card. Point the
	// prose row there instead of leaving the vague global timestamp placeholder.
	text = redactMCPConnectionTimestampTableRows(text)
	text = redactMCPCallTimingTableRows(text)
	// Execution audit timing has the exact values in the adjacent execution card. Point timing
	// rows there instead of leaving the generic "the recorded time" phrase as if it were data.
	// 执行审计的精确时间在旁边的执行卡中；时间行应明确指向卡片，不能把通用占位语伪装成字段值。
	text = redactExecutionTimingTableRows(text)
	text = removeOpaquePlaceholderIDColumns(text)
	text = longIntegerPattern.ReplaceAllString(text, opaqueIntegerPlaceholder)
	text = longHexPattern.ReplaceAllString(text, opaqueHashPlaceholder)
	if containsHan(text) {
		// A hosted model may invent a Chinese explanation around the neutral placeholder rather
		// than using one of the known field grammars. The placeholder is still an internal token in
		// that context, so never let it survive the final user-facing pass.
		// 托管模型可能在已知字段句式之外自行解释中性 placeholder。此时它仍是内部 token，最终用户面绝不放行。
		text = strings.ReplaceAll(text, "`"+opaqueEntityPlaceholder+"`", "该目标")
		text = strings.ReplaceAll(text, "\""+opaqueEntityPlaceholder+"\"", "该目标")
		text = strings.ReplaceAll(text, opaqueEntityPlaceholder, "该目标")
		text = strings.ReplaceAll(text, "`"+legacyEntityPlaceholder+"`", "该目标")
		text = strings.ReplaceAll(text, "\""+legacyEntityPlaceholder+"\"", "该目标")
		text = strings.ReplaceAll(text, legacyEntityPlaceholder, "该目标")
		text = opaqueChineseRawFunctionIDPattern.ReplaceAllString(text, "函数标识")
		text = opaqueChineseRawFunctionPrefixPattern.ReplaceAllString(text, "函数标识前缀")
		text = opaqueChineseFunctionIDLocatedPhrasePattern.ReplaceAllString(text, "传入的目标已准备好")
		text = opaqueChineseBareFunctionIDCamelPattern.ReplaceAllString(text, "函数标识")
		text = opaqueChineseBareFabricatedIDLabelPattern.ReplaceAllString(text, "虚构的函数标识")
		text = opaqueChineseDuplicateInputReferencePattern.ReplaceAllString(text, "${1}")
		text = opaqueChineseDuplicateInputWordPattern.ReplaceAllString(text, "这个输入")
		text = opaqueChineseLookupBareIDPattern.ReplaceAllString(text, "根据这个输入")
		text = opaqueChineseLookupInputBeforeVerbPattern.ReplaceAllString(text, "根据这个输入${1}")
		text = opaqueChineseFetchRealInputIDAfterPattern.ReplaceAllString(text, "获取真实存在的函数标识后再调用")
		text = opaqueChineseRealInputIDAfterPattern.ReplaceAllString(text, "真实标识后再调用")
		text = opaqueChineseParenthesizedPrefixStartPattern.ReplaceAllString(text, "（格式合法）")
		text = opaqueChinesePrefixStartPhrasePattern.ReplaceAllString(text, "函数标识以合法格式开头")
		text = opaqueChineseValidFunctionIDPhrasePattern.ReplaceAllString(text, "真实存在的函数标识")
		text = opaqueChineseCorrectExistingFunctionPhrasePattern.ReplaceAllString(text, "拿到真实存在的函数标识")
		text = opaqueChineseRegisteredFunctionExamplePattern.ReplaceAllString(text, "例如系统中已注册的函数")
		text = opaqueChineseFabricatedWellFormedMissingPhrasePattern.ReplaceAllString(text, "格式合法但尚未注册的函数标识")
		text = opaqueChineseFabricatedNonexistentFunctionPhrasePattern.ReplaceAllString(text, "未注册的函数标识")
		text = opaqueChineseFabricatedInvalidIDPhrasePattern.ReplaceAllString(text, "虚构的、未注册的函数标识")
		text = opaqueChineseDuplicatedPrefixFormatPattern.ReplaceAllString(text, "合法的函数标识格式")
		text = opaqueChineseMatchingIDPhrasePattern.ReplaceAllString(text, "与之匹配")
		text = opaqueChineseIDFormatValidPhrasePattern.ReplaceAllString(text, "标识格式本身合法")
		text = opaqueChineseBareInputIDPhrasePattern.ReplaceAllString(text, "这个输入")
		text = opaqueChineseExactIDPhrasePattern.ReplaceAllString(text, "函数标识")
		text = opaqueChineseFunctionLabelBeforePredicatePattern.ReplaceAllString(text, "函数标识${1}")
		text = opaqueChineseLabelBeforeTestingPattern.ReplaceAllString(text, "标识来测试")
		text = opaqueChineseIDBeforeLocationPattern.ReplaceAllString(text, "这个输入${1}")
		text = opaqueChineseInputBeforeLocationPattern.ReplaceAllString(text, "这个输入${1}")
		text = opaqueChineseInputBeforeLocationSpacingPattern.ReplaceAllString(text, "${1}${2}")
		text = opaqueChineseBareTargetIDPhrasePattern.ReplaceAllString(text, "这个输入")
		text = opaqueChineseMissingFunctionLabelBeforePredicatePattern.ReplaceAllString(text, "对不存在的函数标识会")
		text = opaqueChineseRealMarkerBeforeAfterPattern.ReplaceAllString(text, "真实标识后再调用")
		// “该目标” is internal placeholder vocabulary, not user-facing copy. Keep the fallback
		// readable even when a provider's sentence shape was not recognized earlier.
		// 「该目标」是内部占位词，不是用户文案；未知句式也必须回落到可读的人话。
		text = strings.ReplaceAll(text, "该目标", "这个输入")
		text = opaqueChineseTargetBeforeInputPattern.ReplaceAllString(text, "时传入的目标")
		text = opaqueChineseTimeTargetBeforePredicatePattern.ReplaceAllString(text, "时传入的目标${1}")
		// Machine values are replaced earlier in this pass, so the final neutral wording can only
		// be normalized after every value-specific rule has run. Remove the spaces left on both sides
		// of that neutral subject and close the last provider-specific recommendation shape.
		// 机器值在本 pass 前段才被替换，因此中性主语要等所有值规则完成后再收口，清掉两侧残留空格，
		// 并处理托管模型最后留下的推荐句式。
		text = opaqueChineseFetchRealInputIDAfterPattern.ReplaceAllString(text, "获取真实存在的函数标识后再调用")
		text = opaqueChineseSubjectInputSpacingPattern.ReplaceAllString(text, "${1}${2}${3}")
		text = opaqueChineseSubjectInputBeforeLocationPattern.ReplaceAllString(text, "${1}${2}${3}")
		text = opaqueChineseInputBeforeLocationSpacingPattern.ReplaceAllString(text, "${1}${2}")
		text = opaqueChineseMissingFunctionLabelBeforePredicatePattern.ReplaceAllString(text, "对不存在的函数标识会")
		text = opaqueChineseToolTargetMissingFunctionPattern.ReplaceAllString(text, "调用 get_function 时传入的函数标识在系统中并不存在")
		text = opaqueChineseDuplicateValidLabelPattern.ReplaceAllString(text, "格式合法的函数标识")
		text = opaqueChineseRegisteredInputCorrespondencePattern.ReplaceAllString(text, "${1}与这个输入对应的函数")
		text = opaqueChineseFunctionLabelAssignmentSpacingPattern.ReplaceAllString(text, "传入的函数标识为这个输入")
		text = opaqueChineseFunctionLabelInputBeforeFormatPattern.ReplaceAllString(text, "${1}格式正确")
		text = opaqueChineseDuplicateIdentifierInputPattern.ReplaceAllString(text, "这个输入")
		text = opaqueChineseProvidedInputBeforeFormatPattern.ReplaceAllString(text, "${1}函数标识格式正确")
		text = opaqueChineseInputBeforeParticleSpacingPattern.ReplaceAllString(text, "${1}${2}")
		text = opaqueChineseWellFormedFabricatedFunctionSentencePattern.ReplaceAllString(text, "这个输入是一个格式合法但尚未注册的函数标识")
		text = opaqueChineseIDFormatCorrectPattern.ReplaceAllString(text, "函数标识格式正确")
		text = opaqueChineseFunctionFormatParentheticalPattern.ReplaceAllString(text, "${1}格式正确")
		text = opaqueChineseDuplicatePrefixNamingPattern.ReplaceAllString(text, "符合函数标识格式")
		text = opaqueChinesePrefixIdentifierStructurePattern.ReplaceAllString(text, "符合函数标识格式")
		text = opaqueChineseProvidedIDPattern.ReplaceAllString(text, "${1}函数标识")
		text = opaqueChineseProvidedSpacingPattern.ReplaceAllString(text, "您提供的${1}")
		text = opaqueChineseThisIDPattern.ReplaceAllString(text, "这个输入")
		text = opaqueChineseInputBeforeParticleSpacingPattern.ReplaceAllString(text, "${1}${2}")
		text = opaqueChineseFunctionLabelSpacingPattern.ReplaceAllString(text, "${1}${2}")
		text = opaqueChineseDuplicateNeutralInputPattern.ReplaceAllString(text, "这个输入")
		text = opaqueChineseKnownRealIdentifierAgainPattern.ReplaceAllString(text, "找到已注册的函数后再调用")
		text = opaqueChineseDuplicatedFormatParentheticalPattern.ReplaceAllString(text, "函数标识格式合法")
		text = opaqueChineseValidFormatHexExplanationPattern.ReplaceAllString(text, "${1}格式合法")
		text = opaqueChineseDuplicateInputAfterValidFormatPattern.ReplaceAllString(text, "${1}，但尚未在系统中注册")
		text = opaqueChineseValidFormatPrefixParentheticalPattern.ReplaceAllString(text, "格式合法")
		text = opaqueChinesePrefixAsPrefixPattern.ReplaceAllString(text, "以函数标识格式开头")
		text = opaqueChineseTechnicalFormatParentheticalPattern.ReplaceAllString(text, "（格式合法）")
		text = opaqueChinesePrefixTechnicalClausePattern.ReplaceAllString(text, "函数标识格式")
		text = opaqueChineseDanglingIdentifierPattern.ReplaceAllString(text, "这个输入")
		text = opaqueChineseRedundantValidFormatPattern.ReplaceAllString(text, "格式合法")
		text = opaqueChineseCorrectIDReferencePattern.ReplaceAllString(text, "正确的函数标识")
		text = opaqueChineseMissingFunctionInputWordOrderPattern.ReplaceAllString(text, "不存在与这个输入对应的${1}")
		text = opaqueChineseCorrespondingInputWordOrderPattern.ReplaceAllString(text, "与这个输入对应的${1}")
		text = opaqueChinesePublicToolLineBreakPattern.ReplaceAllString(text, "${1} ${2}${3}${4}")
		text = opaqueChineseToolQueryInputSpacingPattern.ReplaceAllString(text, "${1}${2}")
		text = opaqueChineseValidFormatHexVariantPattern.ReplaceAllString(text, "${1}格式合法")
		text = opaqueChineseCorrectNonexistentFunctionIdentifierPattern.ReplaceAllString(text, "格式合法但尚未注册的函数标识")
		text = opaqueChineseHostedValidFormatClausePattern.ReplaceAllString(text, "${1}格式合法")
		text = opaqueChineseSystemMissingFunctionPattern.ReplaceAllString(text, "与这个输入对应的${1}目前未注册")
		text = opaqueChineseUnregisteredFunctionPattern.ReplaceAllString(text, "这个输入对应的函数目前未注册")
		text = opaqueChineseSystemUnregisteredFunctionPattern.ReplaceAllString(text, "这个输入对应的函数目前未注册")
		text = opaqueChineseSystemFaultCatalogPattern.ReplaceAllString(text, "也不是系统故障")
		text = opaqueChineseCatalogMissingRecordPattern.ReplaceAllString(text, "目前未注册")
		text = opaqueChineseNotFormatProblemPattern.ReplaceAllString(text, "不是格式问题")
		text = opaqueChineseRealIDRecommendationPattern.ReplaceAllString(text, "找到已注册的函数后再调用")
		text = opaqueChineseHostedShapeFormatPattern.ReplaceAllString(text, "${1}格式合法")
		text = opaqueChineseWorkspaceUnregisteredInputPattern.ReplaceAllString(text, "这个输入对应的函数目前未注册")
		text = opaqueChineseWorkspaceCatalogMissingFunctionPattern.ReplaceAllString(text, "这个输入对应的函数目前未注册")
		text = opaqueChineseQuotedFormatProblemPattern.ReplaceAllString(text, "这不是格式问题")
		text = opaqueChineseSyntaxFormatClausePattern.ReplaceAllString(text, "${1}格式合法")
		text = opaqueChineseSystemUnregisteredInputPattern.ReplaceAllString(text, "这个输入对应的函数目前未注册")
		text = opaqueChineseCurrentWorkspaceMissingFunctionPattern.ReplaceAllString(text, "与这个输入对应的${1}目前未注册")
		text = opaqueChineseFormatErrorQuotePattern.ReplaceAllString(text, "不是格式问题")
		text = opaqueChineseRealFunctionRecommendationPattern.ReplaceAllString(text, "找到已注册的函数后再调用")
		text = opaqueChineseLegalIdentifierParentheticalPattern.ReplaceAllString(text, "${1}格式合法")
		text = opaqueChineseSystemMissingRegisteredFunctionPattern.ReplaceAllString(text, "与这个输入对应的${1}目前未注册")
		text = opaqueChineseParameterFormatErrorPattern.ReplaceAllString(text, "也不是格式问题")
		text = opaqueChineseNoSuchFunctionResultPattern.ReplaceAllString(text, "正常的\"未找到\"结果")
		text = opaqueChineseInputFormatIsLegalPattern.ReplaceAllString(text, "${1}格式合法")
		text = opaqueChineseNotFormatOrIllegalPattern.ReplaceAllString(text, "不是格式问题")
		text = opaqueChineseRedundantWorkspaceExplanationPattern.ReplaceAllString(text, "。")
		text = opaqueChineseInputFormatResidualPattern.ReplaceAllString(text, "${1}格式合法")
		text = opaqueChineseCatalogIDMissingPattern.ReplaceAllString(text, "这个输入对应的函数目前未注册")
		text = opaqueChineseSimpleFormatSummaryPattern.ReplaceAllString(text, "")
		text = opaqueChineseIDFormatBulletPattern.ReplaceAllString(text, "这个输入格式合法。")
		text = opaqueChineseRegistrationDashExplanationPattern.ReplaceAllString(text, "这个输入对应的函数目前未注册")
		text = opaqueChineseFormatProblemInputDuplicatePattern.ReplaceAllString(text, "不是格式问题")
		text = opaqueChineseNoSuchFunctionResponsePattern.ReplaceAllString(text, "正常的\"未找到\"结果")
		text = opaqueChineseInvalidRequestFormatPhrasePattern.ReplaceAllString(text, "这不是格式问题")
		text = opaqueChineseRedundantWorkspaceEntityPhrasePattern.ReplaceAllString(text, "。")
		text = opaqueChineseLifecycleConclusionPattern.ReplaceAllString(text, "")
		text = opaqueChineseLegalIdentifierShapeParentheticalPattern.ReplaceAllString(text, "${1}格式合法")
		text = opaqueChineseInputSystemUnregisteredPattern.ReplaceAllString(text, "这个输入对应的函数目前未注册${1}")
		text = opaqueChineseIDRequirementExplanationPattern.ReplaceAllString(text, "")
		text = opaqueChineseSimpleFormatErrorPattern.ReplaceAllString(text, "这不是格式问题")
		text = opaqueChineseBareLegalParentheticalPattern.ReplaceAllString(text, "${1}格式合法")
		text = opaqueChineseUnregisteredCorrespondingFunctionPattern.ReplaceAllString(text, "这个输入对应的函数目前未注册")
		text = opaqueChineseDashMissingSimpleFunctionPattern.ReplaceAllString(text, "。")
		text = opaqueChineseParameterFormatWrongPattern.ReplaceAllString(text, "不是格式问题")
		text = opaqueChineseDirectoryNotFoundReturnClausePattern.ReplaceAllString(text, "")
		text = opaqueChineseConstructedIDInferencePattern.ReplaceAllString(text, "这属于正常的\"未找到\"响应，不是格式问题。")
		text = opaqueChineseLegalFormatParentheticalAfterPattern.ReplaceAllString(text, "${1}格式合法")
		text = opaqueChineseGrammarGoodIdentifierPhrasePattern.ReplaceAllString(text, "。")
		text = opaqueChineseRegistrationReturnPhrasePattern.ReplaceAllString(text, "这个输入对应的函数目前未注册")
		text = opaqueChineseDashFormatProblemWorkspacePhrasePattern.ReplaceAllString(text, "。这不是格式问题")
		text = opaqueChineseCurrentWorkspaceFunctionReturnClausePattern.ReplaceAllString(text, "")
		text = opaqueChineseNoSuchFunctionSummaryPattern.ReplaceAllString(text, "这是正常的\"未找到\"结果，不是格式问题。")
		text = opaqueChineseProvidedFunctionIdentifierFormatPattern.ReplaceAllString(text, "这个输入格式合法")
		text = opaqueChineseBoldInputSystemUnregisteredPattern.ReplaceAllString(text, "这个输入对应的函数目前未注册")
		text = opaqueChineseCurrentCatalogReturnClausePattern.ReplaceAllString(text, "")
		text = opaqueChineseRealFunctionCallRecommendationPattern.ReplaceAllString(text, "找到已注册的函数后再调用")
		text = opaqueChineseProvidedFunctionIdentifierFormatShortPattern.ReplaceAllString(text, "这个输入格式合法")
		text = opaqueChineseDuplicateRegistrationSentencePattern.ReplaceAllString(text, "这个输入对应的函数目前未注册。")
		text = opaqueChineseProvidedIdentifierFormatLegalPattern.ReplaceAllString(text, "这个输入格式合法")
		text = opaqueChineseToolCardValidityExplanationPattern.ReplaceAllString(text, "")
		text = opaqueChineseNotFoundInsteadFormatErrorPattern.ReplaceAllString(text, "正常的\"未找到\"结果，不是格式问题")
		text = opaqueChineseCurrentWorkspaceAnyFunctionPattern.ReplaceAllString(text, "这个输入对应的函数目前未注册")
		text = opaqueChineseWorkspaceDirectoryRecordSummaryPattern.ReplaceAllString(text, "这是正常的\"未找到\"结果，不是格式问题。")
		text = opaqueChineseLegalFunctionParentheticalPattern.ReplaceAllString(text, "${1}格式合法")
		text = opaqueChineseSyntaxParameterPhrasePattern.ReplaceAllString(text, "这不是格式问题")
		text = opaqueChineseRedundantEntityCatalogPhrasePattern.ReplaceAllString(text, "。")
		text = opaqueChineseShortConclusionPattern.ReplaceAllString(text, "")
		text = opaqueChineseRedundantValidFormatMarkdownPattern.ReplaceAllString(text, "格式合法")
		text = opaqueChineseSpeculativeFunctionLifecyclePattern.ReplaceAllString(text, "这个输入对应的函数目前未注册")
		text = opaqueChineseInvalidIDProblemPattern.ReplaceAllString(text, "格式错误的问题")
		text = opaqueChineseInvalidIDPattern.ReplaceAllString(text, "格式不正确的输入")
		text = opaqueChineseFunctionLabelInputColonPattern.ReplaceAllString(text, "函数标识为${1}")
		text = opaqueChineseOpaqueFunctionIDClausePattern.ReplaceAllString(text, "格式合法的函数标识")
		text = opaqueChineseValidPrefixFunctionIDPhrasePattern.ReplaceAllString(text, "格式合法的函数标识")
		text = opaqueChineseInputFabricatedPattern.ReplaceAllString(text, "${1}尚未注册")
		text = opaqueChineseDuplicatePrefixStructurePattern.ReplaceAllString(text, "函数标识格式合法")
		text = opaqueChineseInputUnregisteredFunctionPattern.ReplaceAllString(text, "系统中没有注册与这个输入对应的函数")
		text = localizedOpaqueTimestampPlaceholderPattern.ReplaceAllString(text, opaqueTimestampChinesePlaceholder)
	} else if strings.Contains(text, "get_function") {
		// English reasoning can keep the internal placeholder when the provider discusses a tool
		// call entirely in English. It is not a user-facing value; use a natural function reference
		// phrase while preserving the existing generic English placeholder contract elsewhere.
		// 英文 reasoning 若整块只讨论 get_function，可能保留内部 placeholder；这里仅收口该工具场景，
		// 不改变其他实体英文占位词的既有脱敏契约。
		text = strings.ReplaceAll(text, opaqueEntityPlaceholder, "the supplied function identifier")
		text = strings.ReplaceAll(text, legacyEntityPlaceholder, "the supplied function identifier")
	}
	text = restorePublicToolNames(text)
	text = restoreExactLastMessageAt(text)
	return restoreExactNextFireAt(text)
}

func protectPublicToolNames(text string) (string, func(string) string) {
	text = strings.ReplaceAll(text, "todo_read", protectedTodoReadToolName)
	text = strings.ReplaceAll(text, "todo_write", protectedTodoWriteToolName)
	return text, func(value string) string {
		value = strings.ReplaceAll(value, protectedTodoReadToolName, "todo_read")
		return strings.ReplaceAll(value, protectedTodoWriteToolName, "todo_write")
	}
}

func redactOpaqueSkillContextLines(text string) string {
	lines := strings.Split(text, "\n")
	for index, line := range lines {
		if !strings.Contains(line, opaqueEntityPlaceholder) && !strings.Contains(line, legacyEntityPlaceholder) {
			continue
		}
		colon := strings.IndexAny(line, ":：")
		if colon < 0 {
			continue
		}
		label := strings.ToLower(strings.Trim(strings.TrimSpace(line[:colon]), "`*_ "))
		label = strings.ReplaceAll(label, " ", "")
		prefix := line[:colon+1]
		switch label {
		case "session", "sessionid", "会话", "会话id":
			lines[index] = prefix + " See the exact session in the activation card."
		case "directory", "dir", "path", "cwd", "claude_skill_dir", "skill_dir", "目录", "路径":
			lines[index] = prefix + " " + opaquePathTableHint
		}
	}
	return strings.Join(lines, "\n")
}

func redactOpaqueSkillContextTableRows(text string) string {
	lines := strings.Split(text, "\n")
	for i, line := range lines {
		cells, ok := markdownTableCells(line)
		if !ok || len(cells) < 2 {
			continue
		}
		label := normalizeSkillContextFieldLabel(cells[0])
		hint := ""
		switch label {
		case "session", "sessionid", "会话", "会话id":
			hint = "See the exact session in the activation card."
		case "directory", "dir", "path", "cwd", "claude_skill_dir", "skill_dir", "目录", "路径":
			hint = opaquePathTableHint
		}
		if hint == "" {
			continue
		}
		changed := false
		for column := 1; column < len(cells); column++ {
			value := cells[column]
			if !strings.Contains(value, opaqueEntityPlaceholder) && !strings.Contains(value, legacyEntityPlaceholder) {
				continue
			}
			cells[column] = hint
			changed = true
			break
		}
		if changed {
			lines[i] = formatMarkdownTableRow(cells)
		}
	}
	return strings.Join(lines, "\n")
}

func normalizeSkillContextFieldLabel(label string) string {
	value := strings.ToLower(strings.Trim(strings.TrimSpace(label), "`*_ "))
	return strings.ReplaceAll(value, " ", "")
}

func redactSkillVerbatimClaimLines(text string) string {
	lines := strings.Split(text, "\n")
	for index, line := range lines {
		if !isSkillVerbatimClaimLine(line) {
			continue
		}
		prefix := line[:len(line)-len(strings.TrimLeft(line, " \t"))]
		if containsHan(text) {
			lines[index] = prefix + "可安全展示的人话字段已原样引用；精确的 Session 和 Directory 请查看相邻激活工具卡。"
		} else {
			lines[index] = prefix + "Human-readable fields are quoted above; exact Session and Directory values remain in the adjacent activation card."
		}
	}
	return strings.Join(lines, "\n")
}

func isSkillVerbatimClaimLine(line string) bool {
	lower := strings.ToLower(line)
	hasActivationContext := strings.Contains(lower, "activation") || strings.Contains(line, "激活")
	if !hasActivationContext {
		return false
	}
	for _, marker := range []string{
		"verbatim",
		"quoted exactly",
		"quoted raw",
		"without substitution",
		"without replacing",
		"without fabrication",
		"原样",
		"逐字",
		"未做任何替换",
		"未做替换",
		"未臆造",
	} {
		if strings.Contains(lower, marker) || strings.Contains(line, marker) {
			return true
		}
	}
	return false
}

func redactTriggerIDPlaceholderLine(line string) string {
	if containsHan(line) {
		return "精确触发器 ID 见旁边的触发器卡片。"
	}
	return "See the exact trigger ID in the adjacent trigger card."
}

func redactOpaquePlaceholderParentheticalLists(text string) string {
	return opaquePlaceholderParentheticalListPattern.ReplaceAllStringFunc(text, func(parenthetical string) string {
		inner := parenthetical[1 : len(parenthetical)-1]
		if !strings.ContainsAny(inner, ",;") {
			// The dedicated exact-placeholder rule below owns a parenthetical with no
			// human list item; keeping it here preserves its leading-space cleanup.
			return parenthetical
		}
		parts := strings.FieldsFunc(inner, func(r rune) bool { return r == ',' || r == ';' })
		kept := make([]string, 0, len(parts))
		for _, part := range parts {
			part = strings.TrimSpace(part)
			if strings.Trim(part, "`") == opaqueEntityPlaceholder || strings.Trim(part, "`") == legacyEntityPlaceholder {
				continue
			}
			if part != "" {
				kept = append(kept, part)
			}
		}
		if len(kept) == 0 {
			return ""
		}
		return "(" + strings.Join(kept, ", ") + ")"
	})
}

// redactRelationIntro removes the duplicated opaque target from the natural-language summary.
// The human name and kind remain useful; the exact entity/ref values stay in the adjacent
// get_relations result card.
//
// 关系摘要中重复的 opaque target 没有用户价值。保留实体类型和名称，精确值留在相邻关系结果卡。
func redactRelationIntro(text string) string {
	text = relationToolIntroCurrentPattern.ReplaceAllStringFunc(text, func(match string) string {
		parts := relationToolIntroCurrentPattern.FindStringSubmatch(match)
		if len(parts) != 4 {
			return match
		}
		label := "该函数"
		typed := strings.TrimSpace(parts[2])
		if typed != "" {
			typed = strings.Trim(typed, "\x60 ")
			lower := strings.ToLower(typed)
			switch {
			case strings.HasPrefix(lower, "function:"):
				label = "函数 " + strings.TrimSpace(typed[len("function:"):])
			case strings.HasPrefix(typed, "函数"):
				label = typed
			case strings.HasPrefix(lower, "function"):
				label = "函数 " + strings.TrimSpace(typed[len("function"):])
			default:
				label = typed
			}
		}
		prefix := ""
		if strings.HasPrefix(strings.TrimSpace(parts[1]), "以下是") {
			prefix = "以下是 "
		}
		return prefix + label + " " + parts[3]
	})
	text = relationIntroAgainstTypedPattern.ReplaceAllStringFunc(text, func(match string) string {
		parts := relationIntroAgainstTypedPattern.FindStringSubmatch(match)
		if len(parts) != 4 {
			return match
		}
		return strings.TrimRight(parts[1], " \t") + strings.TrimSpace(parts[2]) + " " + parts[3]
	})
	text = relationToolIntroTypedPattern.ReplaceAllString(text, "${2} ${3}")
	text = relationToolIntroBarePattern.ReplaceAllString(text, "该函数${2}")
	text = relationAgainstIntroTypedPattern.ReplaceAllString(text, "${1}${2} ${3}${4}")
	text = relationAgainstIntroBarePattern.ReplaceAllString(text, "${1}该函数${2}")
	text = relationIntroTypedTargetPattern.ReplaceAllStringFunc(text, func(match string) string {
		parts := relationIntroTypedTargetPattern.FindStringSubmatch(match)
		if len(parts) != 3 {
			return match
		}
		return strings.TrimRight(parts[1], " \t\r\n") + " " + strings.TrimSpace(parts[2]) + " "
	})
	text = relationIntroBareTargetPattern.ReplaceAllString(text, "${1}该函数${2}")
	text = relationIntroTargetFirstPattern.ReplaceAllString(text, "${1} ${2} ")
	text = relationIntroChinesePattern.ReplaceAllString(text, "${1}${2} ")
	return relationIntroEnglishPattern.ReplaceAllString(text, "${1}${2}")
}

const relationTableRefHint = "精确 ref 见关系卡"
const relationTableRefHintEnglish = "Exact ref is in the relation card."

var (
	relationToolIntroCurrentPattern               = regexp.MustCompile("(?ims)^([ \\t]*(?:以下是[ \\t]+)?[\\x60]?get_relations[\\x60]?[ \\t]+对[ \\t]+)[\\x60]?(?:the requested item|the referenced item)[\\x60]?[ \\t]*(?:[（(][ \\t]*([^）)]*)[）)])?[ \\t]*(在|下|的|关系|返回)")
	relationIDLinePattern                         = regexp.MustCompile("(?ims)^([ \\t]*[-*•]?[ \\t]*(?:关系 id|relation id)[ \\t]*[:：][ \\t\\r\\n]*)[\\x60]?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "[\\x60]?[ \\t]*$")
	relationEmptyDirectionTargetPattern           = regexp.MustCompile("[ \\t]*[（(][ \\t]*[←→][ \\t]*[）)]")
	relationReasoningIDPattern                    = regexp.MustCompile("(?im)(\\bget_relations\\b[^\\r\\n]*?)(?:,?[ \\t]*)id[ \\t]*[:=][ \\t]*[\\x60\"]?(?:the requested item|the referenced item)[\\x60\"]?([,.;]|$)")
	relationReasoningEdgePattern                  = regexp.MustCompile("(?im)(\\bEdge[ \\t]+)[\\x60]?(?:the requested item|the referenced item)[\\x60]?([:.,;])")
	relationReasoningPlaceholderLinePattern       = regexp.MustCompile("(?im)^([ \\t]*[-*•][ \\t]*)[\\x60]?(?:the requested item|the referenced item)[\\x60]?[ \\t]*$")
	relationStandalonePlaceholderLinePattern      = regexp.MustCompile("(?im)^[ \\t]*[\\x60]?(?:the requested item|the referenced item)[\\x60]?[ \\t]*$")
	relationEndpointIDHeaderPattern               = regexp.MustCompile("(?i)[ \\t]*(?:/|／)[ \\t]*id")
	relationMachineFieldAssignmentPattern         = regexp.MustCompile("(?i)[\\x60\\\"]?(?:fromId|toId|edgeId|from ID|to ID|edge ID|边 ID)[\\x60\\\"]?[ \\t]*[=:：][ \\t]*[^,，;；\\r\\n）)]*")
	relationIntroAgainstTypedPattern              = regexp.MustCompile("(?ims)^([ \\t]*以下是)[ \\t]*对[ \\t]+[\\x60]?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "[\\x60]?[ \\t\\r\\n]*（([^）]+)）[ \\t\\r\\n]*(在|下|的|关系)")
	relationOpaquePlaceholderParentheticalPattern = regexp.MustCompile("[ \\t]*[（(][ \\t]*[\\x60]?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "[\\x60]?[ \\t]*[）)]")
	relationEndpointMachineRefPattern             = regexp.MustCompile(`(?i)[ \t]*[（(][^）)]*(?:fromId|toId|edgeId|from ID|to ID|edge ID|边 ID)[^）)]*[）)]`)
	relationEntityPlaceholderLinePattern          = regexp.MustCompile("(?im)^([ \\t]*实体[：:][ \\t]*)[\\x60]?(?:the requested item|the referenced item)[\\x60]?[ \\t]*(?:[（(]([^）)]*)[）)])?[ \\t]*$")
	relationAllowedToolsLinePattern               = regexp.MustCompile("(?im)^([ \\t]*[-*•][ \\t]*)[^\\r\\n]*allowedTools[^\\r\\n]*$")
	relationOpaqueFieldAssignmentPattern          = regexp.MustCompile("(?is)[（(,，;；][ \\t]*(?:id|fromId|toId|edgeId|from ID|to ID|edge ID|边 ID)[ \\t]*[=:：][ \\t]*[\\x60]?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "[\\x60]?[ \\t]*[)）]?")
	relationRecordedCamelTimePattern              = regexp.MustCompile("(?ims)^[ \\t]*(?:[-*•][ \\t]+)?(?:createdAt|updatedAt)[：:][ \\t\\r\\n]*[\\x60]?" + regexp.QuoteMeta(opaqueTimestampPlaceholder) + "[\\x60]?[。.]?[ \\t\\r\\n]*")
)

func redactRelationIDLines(text string) string {
	return relationIDLinePattern.ReplaceAllStringFunc(text, func(match string) string {
		parts := relationIDLinePattern.FindStringSubmatch(match)
		if len(parts) != 2 {
			return match
		}
		prefix := strings.TrimLeft(parts[1], " 	")
		indent := parts[1][:len(parts[1])-len(prefix)]
		if containsHan(match) {
			if len(prefix) > 0 && strings.ContainsRune("-*•", rune(prefix[0])) {
				return indent + string(prefix[0]) + " 精确关系引用见关系卡"
			}
			return indent + "精确关系引用见关系卡"
		}
		if len(prefix) > 0 && strings.ContainsRune("-*•", rune(prefix[0])) {
			return indent + string(prefix[0]) + " Exact relation ref is in the relation card."
		}
		return "Exact relation ref is in the relation card."
	})
}

func redactRelationDirectionCell(cell string) string {
	cell = strings.ReplaceAll(cell, "\x60"+opaqueEntityPlaceholder+"\x60", "")
	cell = strings.ReplaceAll(cell, "\x60"+legacyEntityPlaceholder+"\x60", "")
	cell = strings.ReplaceAll(cell, opaqueEntityPlaceholder, "")
	cell = strings.ReplaceAll(cell, legacyEntityPlaceholder, "")
	cell = relationEmptyDirectionTargetPattern.ReplaceAllString(cell, "")
	return strings.TrimSpace(cell)
}

func redactRelationEndpointHeader(header string) string {
	return relationEndpointIDHeaderPattern.ReplaceAllString(header, "")
}

func redactRelationEndpointCell(cell string, includesID bool) string {
	cell = removeRelationPlaceholder(cell)
	// Endpoint labels are for people; machine refs belong in the relation card.
	cell = relationEndpointMachineRefPattern.ReplaceAllString(cell, "")
	cell = relationMachineFieldAssignmentPattern.ReplaceAllString(cell, "")
	cell = normalizeRelationEndpointDisplay(cell)
	if !includesID {
		return cell
	}
	parts := strings.Split(cell, "·")
	if len(parts) >= 3 {
		for index := range parts[:len(parts)-1] {
			parts[index] = strings.TrimSpace(parts[index])
		}
		return strings.Join(parts[:len(parts)-1], " · ")
	}
	return cell
}

func normalizeRelationEndpointDisplay(cell string) string {
	cell = strings.ReplaceAll(cell, "（，", "（")
	cell = strings.ReplaceAll(cell, "，）", "）")
	cell = strings.ReplaceAll(cell, "(,", "(")
	cell = strings.ReplaceAll(cell, ", )", ")")

	open := strings.IndexAny(cell, "（(")
	close := strings.LastIndexAny(cell, "）)")
	if open < 0 || close <= open {
		return cell
	}
	openRune, _ := utf8.DecodeRuneInString(cell[open:])
	closeRune, _ := utf8.DecodeRuneInString(cell[close:])
	inner := strings.TrimSpace(cell[open+len(string(openRune)) : close])
	parts := strings.FieldsFunc(inner, func(r rune) bool { return r == '，' || r == ',' })
	if len(parts) == 0 {
		return strings.TrimSpace(cell[:open]) + cell[close+len(string(closeRune)):]
	}
	kind := strings.TrimSpace(parts[0])
	if len(parts) == 1 {
		nestedName := strings.Trim(parts[0], "\x60*_ ")
		outerName := strings.TrimSpace(cell[:open])
		if colon := strings.LastIndexAny(outerName, ":："); colon >= 0 {
			colonRune, _ := utf8.DecodeRuneInString(outerName[colon:])
			outerName = strings.TrimSpace(outerName[colon+len(string(colonRune)):])
		}
		normalizedOuter := strings.Trim(outerName, "\x60*_ ")
		if nestedName == normalizedOuter || strings.HasSuffix(normalizedOuter, " "+nestedName) {
			return strings.TrimSpace(cell[:open])
		}
		return strings.TrimSpace(cell[:open]) + string(openRune) + kind + string(closeRune)
	}
	nestedName := strings.Trim(strings.TrimSpace(strings.Join(parts[1:], " ")), "\x60*_ ")
	outerName := strings.TrimSpace(cell[:open])
	if colon := strings.LastIndexAny(outerName, ":："); colon >= 0 {
		colonRune, _ := utf8.DecodeRuneInString(outerName[colon:])
		outerName = strings.TrimSpace(outerName[colon+len(string(colonRune)):])
	}
	outerName = strings.Trim(outerName, "\x60*_ ")
	if nestedName != "" && nestedName == outerName {
		return strings.TrimSpace(cell[:open]) + string(openRune) + kind + string(closeRune)
	}
	return cell
}

func redactRelationReasoningIDs(text string) string {
	return relationReasoningIDPattern.ReplaceAllStringFunc(text, func(match string) string {
		parts := relationReasoningIDPattern.FindStringSubmatch(match)
		if len(parts) != 3 {
			return match
		}
		return parts[1] + parts[2]
	})
}

func redactRelationReasoningEdges(text string) string {
	return relationReasoningEdgePattern.ReplaceAllStringFunc(text, func(match string) string {
		parts := relationReasoningEdgePattern.FindStringSubmatch(match)
		if len(parts) != 3 {
			return match
		}
		return strings.TrimRight(parts[1], " \t") + parts[2]
	})
}

func redactRelationPlaceholderParentheticals(text string) string {
	text = relationReasoningPlaceholderLinePattern.ReplaceAllStringFunc(text, func(match string) string {
		parts := relationReasoningPlaceholderLinePattern.FindStringSubmatch(match)
		if len(parts) != 2 {
			return match
		}
		if strings.ContainsRune(parts[1], '•') {
			return parts[1] + "目标函数"
		}
		return parts[1] + "该关系"
	})
	return relationOpaquePlaceholderParentheticalPattern.ReplaceAllString(text, "")
}

func redactRelationCamelTimeLines(text string) string {
	lines := strings.Split(text, "\n")
	result := lines[:0]
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if (strings.HasPrefix(trimmed, "• createdAt") || strings.HasPrefix(trimmed, "• updatedAt")) &&
			strings.Contains(line, opaqueTimestampPlaceholder) {
			continue
		}
		result = append(result, line)
	}
	return strings.Join(result, "\n")
}

func redactRelationEntityLines(text string) string {
	return relationEntityPlaceholderLinePattern.ReplaceAllStringFunc(text, func(match string) string {
		parts := relationEntityPlaceholderLinePattern.FindStringSubmatch(match)
		if len(parts) != 3 {
			return match
		}
		name := strings.TrimSpace(parts[2])
		if name == "" {
			name = "目标函数"
		}
		return parts[1] + name
	})
}

func redactRelationAllowedToolsLines(text string) string {
	return relationAllowedToolsLinePattern.ReplaceAllStringFunc(text, func(match string) string {
		if strings.Contains(match, "该函数被技能") {
			return match
		}
		parts := relationAllowedToolsLinePattern.FindStringSubmatch(match)
		if len(parts) != 2 {
			return match
		}
		return parts[1] + "该技能已将该函数作为可调用能力。"
	})
}

func redactRelationChineseTimeLines(text string) string {
	lines := strings.Split(text, "\n")
	result := lines[:0]
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		isTime := strings.HasPrefix(trimmed, "• 创建时间") ||
			strings.HasPrefix(trimmed, "• 更新时间") ||
			strings.HasPrefix(trimmed, "创建时间") ||
			strings.HasPrefix(trimmed, "更新时间")
		if isTime && strings.Contains(line, opaqueTimestampPlaceholder) {
			continue
		}
		result = append(result, line)
	}
	return strings.Join(result, "\n")
}

func redactRelationOpaqueFieldAssignments(text string) string {
	return relationOpaqueFieldAssignmentPattern.ReplaceAllStringFunc(text, func(match string) string {
		switch {
		case strings.ContainsRune(match, '）'):
			return "）"
		case strings.ContainsRune(match, ')'):
			return ")"
		default:
			return ""
		}
	})
}

func redactRelationMachineFieldAssignments(text string) string {
	text = relationMachineFieldAssignmentPattern.ReplaceAllString(text, "")
	text = regexp.MustCompile(`(?m)[（(][ \t]*[）)]`).ReplaceAllString(text, "")
	text = regexp.MustCompile(`[ \t]*[,，][ \t]*[,，]`).ReplaceAllString(text, ", ")
	return text
}

func redactRelationTableRows(text string) string {
	lines := strings.Split(text, "\n")
	for i := 0; i+2 < len(lines); {
		header, ok := markdownTableCells(lines[i])
		if !ok {
			i++
			continue
		}
		separator, ok := markdownTableCells(lines[i+1])
		if !ok || len(separator) != len(header) || !isMarkdownTableSeparator(separator) {
			i++
			continue
		}

		endpointColumns := make([]int, 0, 2)
		endpointColumnsWithID := make(map[int]bool)
		directionColumn, refColumn := -1, -1
		refIsMachineColumn := false
		for column, cell := range header {
			label := strings.ToLower(strings.Trim(strings.TrimSpace(cell), "`*_ "))
			switch label {
			case "方向", "direction":
				directionColumn = column
			case "引用", "ref", "reference", "references":
				refColumn = column
			case "端点 id", "边 id", "endpoint id", "edge id":
				refColumn = column
				refIsMachineColumn = true
			}
			if strings.Contains(label, "端点") || strings.Contains(label, "endpoint") || strings.Contains(label, "起点") || strings.Contains(label, "终点") || strings.Contains(label, "from") || strings.Contains(label, "to") {
				endpointColumns = append(endpointColumns, column)
				if strings.Contains(label, "/ id") || strings.Contains(label, "/id") {
					endpointColumnsWithID[column] = true
					header[column] = redactRelationEndpointHeader(header[column])
				}
			}
			if strings.Contains(label, "关系") && strings.Contains(label, "id") {
				refColumn = column
				refIsMachineColumn = true
			}
		}
		if len(endpointColumns) == 0 {
			i += 2
			continue
		}
		if refIsMachineColumn {
			if containsHan(text) {
				header[refColumn] = "关系引用"
			} else {
				header[refColumn] = "Relation ref"
			}
			lines[i] = formatMarkdownTableRow(header)
		}

		lastRow := i + 1
		for row := i + 2; row < len(lines); row++ {
			cells, rowOK := markdownTableCells(lines[row])
			if !rowOK || len(cells) != len(header) {
				break
			}
			lastRow = row
			for _, endpointColumn := range endpointColumns {
				cells[endpointColumn] = redactRelationEndpointCell(cells[endpointColumn], endpointColumnsWithID[endpointColumn])
			}
			if directionColumn >= 0 && (strings.Contains(cells[directionColumn], opaqueEntityPlaceholder) || strings.Contains(cells[directionColumn], legacyEntityPlaceholder)) {
				cells[directionColumn] = redactRelationDirectionCell(cells[directionColumn])
			}
			if refColumn >= 0 && (refIsMachineColumn || strings.Contains(cells[refColumn], opaqueEntityPlaceholder) || strings.Contains(cells[refColumn], legacyEntityPlaceholder) || strings.Contains(cells[refColumn], "rel_") || strings.TrimSpace(cells[refColumn]) == "-") {
				cells[refColumn] = relationFieldRefHint(text)
			}
			lines[row] = formatMarkdownTableRow(cells)
		}
		i = lastRow + 1
	}
	// A streamed row can arrive after its header has already been emitted in an earlier SSE
	// delta. Keep the same narrow relation signature as a fallback so that row-level redaction
	// does not depend on retaining the whole Markdown table in memory.
	for index, line := range lines {
		cells, ok := markdownTableCells(line)
		if !ok || len(cells) < 5 || (!strings.Contains(cells[1], "→") && !strings.Contains(cells[1], "←") && !strings.Contains(cells[1], "入边") && !strings.Contains(cells[1], "出边") && !strings.Contains(strings.ToLower(cells[1]), "into the function") && !strings.Contains(strings.ToLower(cells[1]), "out of")) {
			continue
		}
		kind := strings.Trim(strings.TrimSpace(cells[2]), "`*_ ")
		if kind != "equip" && kind != "link" && kind != "create" && kind != "edit" {
			continue
		}
		refColumn := 4
		if len(cells) >= 6 {
			cells[3] = redactRelationEndpointCell(cells[3], true)
			cells[4] = redactRelationEndpointCell(cells[4], true)
			refColumn = len(cells) - 1
		} else {
			if !strings.Contains(cells[3], "→") && !strings.Contains(cells[3], "←") &&
				!strings.Contains(cells[4], opaqueEntityPlaceholder) && !strings.Contains(cells[4], legacyEntityPlaceholder) &&
				!strings.Contains(cells[4], "rel_") && strings.TrimSpace(cells[4]) != "-" {
				continue
			}
			cells[3] = redactRelationEndpointCell(cells[3], false)
		}
		cells[1] = redactRelationDirectionCell(cells[1])
		if strings.TrimSpace(cells[refColumn]) == "-" || strings.Contains(cells[refColumn], opaqueEntityPlaceholder) || strings.Contains(cells[refColumn], legacyEntityPlaceholder) || strings.Contains(cells[refColumn], "rel_") {
			cells[refColumn] = relationFieldRefHint(text)
		}
		lines[index] = formatMarkdownTableRow(cells)
	}
	return strings.Join(lines, "\n")
}

func redactRelationFieldTableRows(text string) string {
	lines := strings.Split(text, "\n")
	result := make([]string, 0, len(lines))
	for i := 0; i < len(lines); {
		header, ok := markdownTableCells(lines[i])
		if !ok || len(header) < 2 {
			result = append(result, lines[i])
			i++
			continue
		}
		if i+1 >= len(lines) {
			result = append(result, lines[i])
			i++
			continue
		}
		separator, separatorOK := markdownTableCells(lines[i+1])
		if !separatorOK || len(separator) != len(header) || !isMarkdownTableSeparator(separator) || !isRelationFieldTableHeader(header) {
			result = append(result, lines[i])
			i++
			continue
		}

		result = append(result, lines[i], lines[i+1])
		for i += 2; i < len(lines); i++ {
			cells, rowOK := markdownTableCells(lines[i])
			if !rowOK || len(cells) != len(header) {
				break
			}
			label := strings.ToLower(strings.Trim(strings.TrimSpace(cells[0]), "`*_ "))
			switch strings.ReplaceAll(label, " ", "") {
			case "边id", "起点引用", "终点引用", "起点id", "终点id":
				cells[1] = relationFieldRefHint(text)
				result = append(result, formatMarkdownTableRow(cells))
			case "创建时间", "更新时间", "createdat", "updatedat", "created/updated":
				// These values are not rendered in the relation card; do not show a vague or
				// partially redacted timestamp in the assistant narrative.
				if isActivationCreatedAtHint(cells[1]) {
					result = append(result, formatMarkdownTableRow(cells))
				} else {
					continue
				}
			default:
				result = append(result, lines[i])
			}
		}
	}
	// The header may already have been emitted in an earlier provider delta. Redact standalone
	// relation field rows as well so a later chunk cannot expose an opaque value without table
	// context.
	for index, line := range result {
		cells, ok := markdownTableCells(line)
		if !ok || len(cells) < 2 {
			continue
		}
		label := strings.ReplaceAll(strings.ToLower(strings.Trim(strings.TrimSpace(cells[0]), "`*_ ")), " ", "")
		switch label {
		case "边id", "起点引用", "终点引用", "起点id", "终点id":
			cells[1] = relationFieldRefHint(text)
			result[index] = formatMarkdownTableRow(cells)
		case "创建时间", "更新时间", "createdat", "updatedat", "created/updated":
			if !isActivationCreatedAtHint(cells[1]) {
				result[index] = ""
			}
		}
	}
	return strings.Join(result, "\n")
}

func isRelationFieldTableHeader(cells []string) bool {
	if len(cells) < 2 {
		return false
	}
	first := strings.ToLower(strings.Trim(strings.TrimSpace(cells[0]), "`*_ "))
	second := strings.ToLower(strings.Trim(strings.TrimSpace(cells[1]), "`*_ "))
	return (first == "字段" || first == "field") && (second == "值" || second == "value")
}

func isRelationFieldTableRow(line string) bool {
	cells, ok := markdownTableCells(line)
	if !ok || len(cells) < 2 {
		return false
	}
	label := strings.ReplaceAll(strings.ToLower(strings.Trim(strings.TrimSpace(cells[0]), "*_ ")), " ", "")
	switch label {
	case "边id", "起点引用", "终点引用", "起点id", "终点id", "创建时间", "更新时间", "createdat", "updatedat", "created/updated":
		return true
	default:
		return false
	}
}

func relationFieldRefHint(text string) string {
	if containsHan(text) {
		return relationTableRefHint
	}
	return relationTableRefHintEnglish
}

func isActivationCreatedAtHint(value string) bool {
	return strings.Contains(value, activationCreatedAtTableHint) || strings.Contains(value, "精确创建时间见旁边的活动卡片。")
}

func removeRelationPlaceholder(cell string) string {
	cell = strings.ReplaceAll(cell, "`"+opaqueEntityPlaceholder+"`", "")
	cell = strings.ReplaceAll(cell, "`"+legacyEntityPlaceholder+"`", "")
	cell = strings.ReplaceAll(cell, opaqueEntityPlaceholder, "")
	cell = strings.ReplaceAll(cell, legacyEntityPlaceholder, "")
	cell = strings.ReplaceAll(cell, "（,", "（")
	cell = strings.ReplaceAll(cell, "(,", "(")
	cell = strings.ReplaceAll(cell, ", ）", "）")
	cell = strings.ReplaceAll(cell, ", )", ")")
	return strings.TrimSpace(cell)
}

// redactSearchRefPlaceholderSentences keeps search results actionable after the generic opaque-ID
// pass. Exact workflow refs live in the adjacent search_blocks card; leaving "the requested item"
// in a sentence that promises copyable refs is both misleading and unusable. Table rows are left to
// the structured-table redactor below, which has the column context needed to remove only the bad
// cell instead of replacing the whole row.
//
// 通用 opaque-ID 脱敏后，搜索结果正文仍必须可操作。精确 workflow ref 留在相邻 search_blocks 卡；
// 若一句承诺「这些 ref 可以复制」却留下「the requested item」，既误导又不可用。表格行交给下方
// 的结构化表格脱敏器处理，它知道列语义，能只移除坏单元而不整行替换。
func redactSearchRefPlaceholderSentences(text string) string {
	lines := strings.Split(text, "\n")
	for i, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "|") {
			continue
		}
		lowerLine := strings.ToLower(line)
		refClaim := searchRefWordPattern.MatchString(line) ||
			strings.Contains(lowerLine, "search_blocks") ||
			strings.Contains(lowerLine, "workflow node") ||
			strings.Contains(line, "workflow 节点")
		if !refClaim ||
			(!strings.Contains(line, opaqueEntityPlaceholder) && !strings.Contains(line, legacyEntityPlaceholder)) {
			continue
		}

		// Preserve any sentence that follows the ref claim (for example, a helpful offer to
		// inspect a block), while replacing only the sentence containing the unusable values.
		// 保留 ref 句后面的提示语，只替换含不可用值的那一句。
		sentenceEnd := firstSentenceEndOutsideCode(line)
		sentence, suffix := line, ""
		if sentenceEnd >= 0 {
			sentence, suffix = line[:sentenceEnd], line[sentenceEnd:]
		}
		leading := line[:len(line)-len(strings.TrimLeft(line, " \t"))]
		body := strings.TrimLeft(sentence, " \t")
		bullet := ""
		if strings.HasPrefix(body, "- ") || strings.HasPrefix(body, "* ") {
			bullet, body = body[:2], body[2:]
		}
		if containsHan(body) {
			body = "这些可接线 ref 的精确值见相邻 search_blocks 结果卡，可直接复制到 workflow 节点。"
		} else {
			body = "The exact refs are in the adjacent search_blocks result card and can be copied into workflow nodes."
		}
		lines[i] = leading + bullet + body + suffix
	}
	return strings.Join(lines, "\n")
}

// redactSearchBlocksSummaryLines keeps category summaries factual without exposing an
// unavailable ref placeholder. The exact value remains available in the adjacent tool card.
// It intentionally does not touch Markdown tables, whose ref column has its own redactor.
//
// search_blocks 汇总行不能把脱敏后的占位符当成实体名展示。精确值仍在相邻 tool card；表格由
// 独立的 ref 列规则处理，这里只处理带类型计数的 prose bullet。
func redactSearchBlocksSummaryLines(text string) string {
	lines := strings.Split(text, "\n")
	for index, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "|") || !searchBlocksSummaryLinePattern.MatchString(line) {
			continue
		}
		if !strings.Contains(line, opaqueEntityPlaceholder) && !strings.Contains(line, legacyEntityPlaceholder) {
			continue
		}

		hint := "Exact refs are in the adjacent search_blocks result card"
		if containsHan(line) || strings.Contains(line, "：") {
			hint = "精确 ref 见相邻 search_blocks 结果卡"
		}
		line = searchBlocksSummaryCodeOpaqueRefPattern.ReplaceAllString(line, hint)
		line = searchBlocksSummaryOpaqueRefPattern.ReplaceAllString(line, hint)
		lines[index] = line
	}
	return strings.Join(lines, "\n")
}

func firstSentenceEndOutsideCode(s string) int {
	inCode := false
	for index, r := range s {
		switch r {
		case '`':
			inCode = !inCode
		case '。', '.', '!', '?':
			if !inCode {
				return index + len(string(r))
			}
		}
	}
	return -1
}

func splitSearchRefPrefix(text string) (prefix, held string, ok bool) {
	lineStart := strings.LastIndexByte(text, '\n') + 1
	line := text[lineStart:]
	if line == "" || strings.HasPrefix(strings.TrimSpace(line), "|") ||
		!searchRefWordPattern.MatchString(line) || !searchRefRawValuePattern.MatchString(line) {
		return "", "", false
	}

	inCode := false
	parenDepth := 0
	for _, r := range line {
		switch r {
		case '`':
			inCode = !inCode
		case '(':
			if !inCode {
				parenDepth++
			}
		case ')':
			if !inCode && parenDepth > 0 {
				parenDepth--
			}
		}
	}
	if inCode || parenDepth > 0 {
		return "", text, true
	}

	if end := firstSentenceEndOutsideCode(line); end >= 0 {
		return text[:lineStart+end], text[lineStart+end:], true
	}
	return "", text, true
}

func containsHan(s string) bool {
	for _, r := range s {
		if unicode.Is(unicode.Han, r) {
			return true
		}
	}
	return false
}

const attachmentTimestampTableHint = "See the exact upload time in the attachment card."
const mcpConnectionTimestampTableHint = "See the exact connection time in the MCP status card."
const mcpCallTimingTableHint = "See the exact timing in the MCP call card."
const mcpCallTimingTableHintChinese = "精确时间见旁边的 MCP 调用卡片。"

const exactLastMessageAtMarker = "__ANSELM_EXACT_LAST_MESSAGE_AT__"

// protectExplicitLastMessageAt makes the narrow, user-requested timestamp exception survive
// the generic machine-value redactor. The marker is deliberately non-numeric so later ID,
// integer, hash, and timestamp passes cannot mistake it for another opaque value.
func protectExplicitLastMessageAt(text string) (string, func(string) string) {
	values := make([]string, 0, 4)
	protect := func(value string) string {
		values = append(values, value)
		return exactLastMessageAtMarker
	}

	lines := strings.Split(text, "\n")
	for i := 0; i+2 < len(lines); {
		header, ok := markdownTableCells(lines[i])
		if !ok {
			i++
			continue
		}
		separator, ok := markdownTableCells(lines[i+1])
		if !ok || len(separator) != len(header) || !isMarkdownTableSeparator(separator) {
			i++
			continue
		}

		lastMessageAtColumn := -1
		for column, cell := range header {
			label := strings.ToLower(strings.Trim(strings.TrimSpace(cell), "`*_ "))
			label = strings.ReplaceAll(label, " ", "")
			if label == "lastmessageat" {
				lastMessageAtColumn = column
				break
			}
		}
		if lastMessageAtColumn < 0 {
			i += 2
			continue
		}

		lastRow := i + 1
		for row := i + 2; row < len(lines); row++ {
			cells, rowOK := markdownTableCells(lines[row])
			if !rowOK || len(cells) != len(header) {
				break
			}
			lastRow = row
			matches := isoTimestampPattern.FindAllStringIndex(cells[lastMessageAtColumn], -1)
			for matchIndex := len(matches) - 1; matchIndex >= 0; matchIndex-- {
				match := matches[matchIndex]
				value := cells[lastMessageAtColumn][match[0]:match[1]]
				cells[lastMessageAtColumn] = cells[lastMessageAtColumn][:match[0]] + protect(value) + cells[lastMessageAtColumn][match[1]:]
			}
			if len(matches) > 0 {
				lines[row] = formatMarkdownTableRow(cells)
			}
		}
		i = lastRow + 1
	}
	text = strings.Join(lines, "\n")

	text = lastMessageAtFieldPattern.ReplaceAllStringFunc(text, func(match string) string {
		location := isoTimestampPattern.FindStringIndex(match)
		if location == nil {
			return match
		}
		return match[:location[0]] + protect(match[location[0]:location[1]]) + match[location[1]:]
	})

	return text, func(redacted string) string {
		for _, value := range values {
			redacted = strings.Replace(redacted, exactLastMessageAtMarker, value, 1)
		}
		return redacted
	}
}

const exactNextFireAtMarker = "__ANSELM_EXACT_NEXT_FIRE_AT__"

// protectExplicitNextFireAt preserves a trigger's requested next-fire instant while the generic
// machine-value pass still redacts unrelated timestamps. `nextFireAt` is a user-facing runtime
// fact, not an audit timestamp: replacing it with "相应时间" makes an otherwise healthy trigger
// report unusable. Both the JSON-shaped field and the translated Field/Value row are accepted.
// protectExplicitNextFireAt 在通用机器值脱敏仍覆盖其它时间戳时保留用户明确要看的触发时刻。
// nextFireAt 是运行时事实而非审计时间；改成「相应时间」会让健康状态报告失去用途。JSON 字段
// 与翻译后的「字段/值」表行都支持。
func protectExplicitNextFireAt(text string) (string, func(string) string) {
	values := make([]string, 0, 4)
	protect := func(value string) string {
		values = append(values, value)
		return exactNextFireAtMarker
	}

	lines := strings.Split(text, "\n")
	for index, line := range lines {
		cells, ok := markdownTableCells(line)
		if !ok || len(cells) < 2 {
			continue
		}
		label := explicitNextFireLabel(cells[0])
		if !label {
			continue
		}
		changed := false
		for column := 1; column < len(cells); column++ {
			matches := isoTimestampPattern.FindAllStringIndex(cells[column], -1)
			for matchIndex := len(matches) - 1; matchIndex >= 0; matchIndex-- {
				match := matches[matchIndex]
				value := cells[column][match[0]:match[1]]
				cells[column] = cells[column][:match[0]] + protect(value) + cells[column][match[1]:]
				changed = true
			}
		}
		if changed {
			lines[index] = formatMarkdownTableRow(cells)
		}
	}
	text = strings.Join(lines, "\n")

	text = nextFireAtFieldPattern.ReplaceAllStringFunc(text, func(match string) string {
		location := isoTimestampPattern.FindStringIndex(match)
		if location == nil {
			return match
		}
		return match[:location[0]] + protect(match[location[0]:location[1]]) + match[location[1]:]
	})

	return text, func(redacted string) string {
		for _, value := range values {
			redacted = strings.Replace(redacted, exactNextFireAtMarker, value, 1)
		}
		return redacted
	}
}

func explicitNextFireLabel(cell string) bool {
	label := strings.ToLower(strings.Trim(strings.TrimSpace(cell), "`*_ "))
	label = strings.ReplaceAll(label, " ", "")
	label = strings.ReplaceAll(label, "_", "")
	return label == "nextfireat" || label == "nextfire" || label == "nextfiretime" || label == "下次触发时间"
}

func redactMCPConnectionTimestampLabelLines(text string) string {
	return mcpConnectionTimestampLabelPattern.ReplaceAllString(text, "${1}"+mcpConnectionTimestampTableHint+"${2}")
}

func redactAttachmentTimestampTableRows(text string) string {
	lines := strings.Split(text, "\n")
	for i := 0; i+2 < len(lines); {
		header, ok := markdownTableCells(lines[i])
		if !ok {
			i++
			continue
		}
		separator, ok := markdownTableCells(lines[i+1])
		if !ok || len(separator) != len(header) || !isMarkdownTableSeparator(separator) {
			i++
			continue
		}

		timestampColumn := -1
		for column, cell := range header {
			label := strings.ToLower(strings.Trim(strings.TrimSpace(cell), "`*_ "))
			if label == "uploaded" || label == "upload time" || label == "uploaded at" || label == "created at" || label == "createdat" {
				timestampColumn = column
				break
			}
		}
		if timestampColumn < 0 {
			i += 2
			continue
		}

		changed := false
		lastRow := i + 1
		for row := i + 2; row < len(lines); row++ {
			cells, rowOK := markdownTableCells(lines[row])
			if !rowOK || len(cells) != len(header) {
				break
			}
			lastRow = row
			if isOpaqueTimestampPlaceholderCell(cells[timestampColumn]) {
				cells[timestampColumn] = attachmentTimestampTableHint
				lines[row] = formatMarkdownTableRow(cells)
				changed = true
			}
		}
		if !changed {
			i = lastRow + 1
			continue
		}
		i = lastRow + 1
	}
	return strings.Join(lines, "\n")
}

func redactMCPConnectionTimestampTableRows(text string) string {
	lines := strings.Split(text, "\n")
	for i := 0; i+2 < len(lines); {
		header, ok := markdownTableCells(lines[i])
		if !ok {
			i++
			continue
		}
		separator, ok := markdownTableCells(lines[i+1])
		if !ok || len(separator) != len(header) || !isMarkdownTableSeparator(separator) {
			i++
			continue
		}

		timestampColumn := -1
		for column, cell := range header {
			label := strings.ToLower(strings.Trim(strings.TrimSpace(cell), "`*_ "))
			if label == "connected at" || label == "connectedat" || label == "connection time" || label == "reconnected at" {
				timestampColumn = column
				break
			}
		}
		if timestampColumn < 0 {
			i += 2
			continue
		}

		changed := false
		lastRow := i + 1
		for row := i + 2; row < len(lines); row++ {
			cells, rowOK := markdownTableCells(lines[row])
			if !rowOK || len(cells) != len(header) {
				break
			}
			lastRow = row
			if isOpaqueTimestampPlaceholderCell(cells[timestampColumn]) {
				cells[timestampColumn] = mcpConnectionTimestampTableHint
				lines[row] = formatMarkdownTableRow(cells)
				changed = true
			}
		}
		if !changed {
			i = lastRow + 1
			continue
		}
		i = lastRow + 1
	}
	return strings.Join(lines, "\n")
}

func redactMCPCallTimingTableRows(text string) string {
	// The structured call card remains the exact source; prose can only point to it after the
	// generic timestamp pass. This avoids a label-looking placeholder in a field/value table.
	// 结构化调用卡才是精确来源；普通文本先经过通用时间脱敏，再指回调用卡，避免表格里出现像字段名的占位值。
	lines := strings.Split(text, "\n")
	for i := 0; i+2 < len(lines); {
		header, ok := markdownTableCells(lines[i])
		if !ok {
			i++
			continue
		}
		separator, ok := markdownTableCells(lines[i+1])
		if !ok || len(separator) != len(header) || !isMarkdownTableSeparator(separator) {
			i++
			continue
		}

		lastRow := i + 1
		labels := make(map[string]bool)
		for row := i + 2; row < len(lines); row++ {
			cells, rowOK := markdownTableCells(lines[row])
			if !rowOK || len(cells) != len(header) {
				break
			}
			lastRow = row
			if len(cells) > 0 {
				labels[normalizeMCPCallFieldLabel(cells[0])] = true
			}
		}
		if !isMCPCallDetailTable(labels) {
			i = lastRow + 1
			continue
		}

		tableHasHan := containsHan(strings.Join(lines[i:lastRow+1], "\n"))
		for row := i + 2; row <= lastRow; row++ {
			cells, rowOK := markdownTableCells(lines[row])
			if !rowOK || len(cells) < 2 || !isMCPCallTimingField(cells[0]) {
				continue
			}
			for column := 1; column < len(cells); column++ {
				if !isOpaqueTimestampPlaceholderCell(cells[column]) {
					continue
				}
				if tableHasHan {
					cells[column] = mcpCallTimingTableHintChinese
				} else {
					cells[column] = mcpCallTimingTableHint
				}
				lines[row] = formatMarkdownTableRow(cells)
				break
			}
		}
		i = lastRow + 1
	}
	return strings.Join(lines, "\n")
}

const (
	executionTimingTableHint   = "See the exact execution time in the adjacent execution card."
	executionTimingTableHintCN = "精确执行时间见旁边的执行卡片。"
)

func redactExecutionTimingTableRows(text string) string {
	lines := strings.Split(text, "\n")
	for i := 0; i+2 < len(lines); {
		header, ok := markdownTableCells(lines[i])
		if !ok || len(header) < 2 {
			i++
			continue
		}
		separator, ok := markdownTableCells(lines[i+1])
		if !ok || len(separator) != len(header) || !isMarkdownTableSeparator(separator) {
			i++
			continue
		}

		lastRow := i + 1
		timingRows := make([]int, 0, 4)
		hasStarted, hasEnded, hasElapsed := false, false, false
		tableHasHan := containsHan(strings.Join(lines[i:i+2], "\n"))
		for row := i + 2; row < len(lines); row++ {
			cells, rowOK := markdownTableCells(lines[row])
			if !rowOK || len(cells) != len(header) {
				break
			}
			lastRow = row
			tableHasHan = tableHasHan || containsHan(lines[row])
			label := normalizeMCPCallFieldLabel(cells[0])
			switch label {
			case "startedat", "starttime", "开始时间", "开始时刻":
				hasStarted = true
				timingRows = append(timingRows, row)
			case "endedat", "endtime", "结束时间", "结束时刻":
				hasEnded = true
				timingRows = append(timingRows, row)
			case "elapsed", "elapsedms", "duration", "耗时", "持续时间":
				hasElapsed = true
				timingRows = append(timingRows, row)
			}
		}
		if !(hasStarted && hasEnded) && !(hasStarted && hasElapsed) {
			i = lastRow + 1
			continue
		}
		for _, row := range timingRows {
			cells, rowOK := markdownTableCells(lines[row])
			if !rowOK {
				continue
			}
			for column := 1; column < len(cells); column++ {
				if !isOpaqueTimestampPlaceholderCell(cells[column]) {
					continue
				}
				if tableHasHan {
					cells[column] = executionTimingTableHintCN
				} else {
					cells[column] = executionTimingTableHint
				}
				lines[row] = formatMarkdownTableRow(cells)
				break
			}
		}
		i = lastRow + 1
	}
	return strings.Join(lines, "\n")
}

func normalizeMCPCallFieldLabel(label string) string {
	value := strings.ToLower(strings.Trim(strings.TrimSpace(label), "`*_ "))
	value = strings.ReplaceAll(value, " ", "")
	value = strings.ReplaceAll(value, "-", "")
	return value
}

func isMCPCallDetailTable(labels map[string]bool) bool {
	server := labels["server"] || labels["服务器"] || labels["serverid"]
	tool := labels["tool"] || labels["工具"]
	status := labels["status"] || labels["状态"]
	return server && tool && status
}

func isMCPCallTimingField(label string) bool {
	switch normalizeMCPCallFieldLabel(label) {
	case "startedat", "starttime", "开始时间", "endedat", "endtime", "结束时间", "createdat", "createdtime", "创建时间":
		return true
	default:
		return false
	}
}

func isOpaqueTimestampPlaceholderCell(cell string) bool {
	value := strings.ToLower(strings.Trim(strings.TrimSpace(cell), "`*_ "))
	return value == opaqueTimestampPlaceholder || value == opaqueTimestampChinesePlaceholder
}

func redactOpaquePlaceholderTableCells(text string) string {
	lines := strings.Split(text, "\n")
	for i, line := range lines {
		cells, ok := markdownTableCells(line)
		if !ok || len(cells) < 3 {
			continue
		}
		changed := false
		for j, cell := range cells {
			if isOpaquePlaceholderTableCell(cell) {
				cells[j] = "-"
				changed = true
			}
		}
		if changed {
			lines[i] = formatMarkdownTableRow(cells)
		}
	}
	return strings.Join(lines, "\n")
}

func redactOpaquePlaceholderFieldTableRows(text string) string {
	lines := strings.Split(text, "\n")
	kept := make([]string, 0, len(lines))
	for _, line := range lines {
		cells, ok := markdownTableCells(line)
		if ok && len(cells) >= 2 {
			label := strings.ToLower(strings.Trim(strings.TrimSpace(cells[0]), "`*_ "))
			if (label == "id" || label == "identifier") && isUnavailableOpaqueTableCell(cells[1]) {
				// Physically remove the row. Leaving an empty line splits the Markdown table and
				// makes the next meaningful row disappear from the rendered table.
				continue
			}
		}
		kept = append(kept, line)
	}
	return strings.Join(kept, "\n")
}

const opaquePathTableHint = "See the exact path in the tool card."

func redactOpaquePathTableRows(text string) string {
	lines := strings.Split(text, "\n")
	for i, line := range lines {
		cells, ok := markdownTableCells(line)
		if !ok || len(cells) < 2 {
			continue
		}
		label := strings.ToLower(strings.Trim(strings.TrimSpace(cells[0]), "`*_ "))
		if label != "cwd" && label != "claude_skill_dir" && label != "skill_dir" && label != "path" && label != "directory" && label != "dir" {
			continue
		}
		changed := false
		for column := 1; column < len(cells); column++ {
			value := cells[column]
			if (strings.Contains(value, opaqueEntityPlaceholder) || strings.Contains(value, legacyEntityPlaceholder)) && strings.Contains(value, "/") {
				cells[column] = opaquePathTableHint
				changed = true
			}
		}
		if changed {
			lines[i] = formatMarkdownTableRow(cells)
		}
	}
	return strings.Join(lines, "\n")
}

func redactOpaquePlaceholderLabeledLines(text string) string {
	lines := strings.Split(text, "\n")
	inFlowrunOverview := false
	kept := make([]string, 0, len(lines))
	for _, line := range lines {
		trimmed := strings.ToLower(strings.TrimSpace(line))
		if strings.Contains(trimmed, "flowrun overview") {
			inFlowrunOverview = true
			kept = append(kept, line)
			continue
		}
		if inFlowrunOverview && trimmed == "" {
			inFlowrunOverview = false
			kept = append(kept, line)
			continue
		}
		if !inFlowrunOverview && opaquePlaceholderLabeledLinePattern.MatchString(line) {
			continue
		}
		kept = append(kept, line)
	}
	return strings.Join(kept, "\n")
}

func removeOpaquePlaceholderIDColumns(text string) string {
	lines := strings.Split(text, "\n")
	for i := 0; i+2 < len(lines); {
		header, ok := markdownTableCells(lines[i])
		if !ok {
			i++
			continue
		}
		separator, ok := markdownTableCells(lines[i+1])
		if !ok || len(separator) != len(header) || !isMarkdownTableSeparator(separator) {
			i++
			continue
		}
		idColumn := -1
		for column, cell := range header {
			if isOpaqueIDHeaderCell(cell) {
				idColumn = column
				break
			}
		}
		if idColumn < 0 {
			i += 2
			continue
		}

		rows := make([]int, 0, 4)
		for row := i + 2; row < len(lines); row++ {
			cells, rowOK := markdownTableCells(lines[row])
			if !rowOK || len(cells) != len(header) {
				break
			}
			rows = append(rows, row)
		}
		if len(rows) == 0 {
			i += 2
			continue
		}
		allUnavailable := true
		for _, row := range rows {
			cells, _ := markdownTableCells(lines[row])
			if !isUnavailableOpaqueTableCell(cells[idColumn]) {
				allUnavailable = false
				break
			}
		}
		if !allUnavailable {
			i = rows[len(rows)-1] + 1
			continue
		}
		lines[i] = formatMarkdownTableRow(removeMarkdownTableCell(header, idColumn))
		lines[i+1] = formatMarkdownTableRow(removeMarkdownTableCell(separator, idColumn))
		for _, row := range rows {
			cells, _ := markdownTableCells(lines[row])
			lines[row] = formatMarkdownTableRow(removeMarkdownTableCell(cells, idColumn))
		}
		i = rows[len(rows)-1] + 1
	}
	return strings.Join(lines, "\n")
}

func markdownTableCells(line string) ([]string, bool) {
	trimmed := strings.TrimSpace(line)
	if !strings.HasPrefix(trimmed, "|") {
		return nil, false
	}
	trimmed = strings.TrimPrefix(trimmed, "|")
	if strings.HasSuffix(trimmed, "|") {
		trimmed = strings.TrimSuffix(trimmed, "|")
	}
	return strings.Split(trimmed, "|"), true
}

func formatMarkdownTableRow(cells []string) string {
	for i := range cells {
		cells[i] = strings.TrimSpace(cells[i])
	}
	return "| " + strings.Join(cells, " | ") + " |"
}

func removeMarkdownTableCell(cells []string, index int) []string {
	result := make([]string, 0, len(cells)-1)
	result = append(result, cells[:index]...)
	return append(result, cells[index+1:]...)
}

func isMarkdownTableSeparator(cells []string) bool {
	for _, cell := range cells {
		value := strings.Trim(strings.TrimSpace(cell), ":")
		if len(value) < 3 || strings.Trim(value, "-") != "" {
			return false
		}
	}
	return true
}

func isOpaqueIDHeaderCell(cell string) bool {
	value := strings.ToLower(strings.TrimSpace(cell))
	value = strings.Trim(value, "`*_ ")
	return value == "id" || value == "identifier" || strings.HasSuffix(value, " id")
}

func isUnavailableOpaqueTableCell(cell string) bool {
	value := strings.ToLower(strings.TrimSpace(cell))
	value = strings.Trim(value, "`*_ ")
	return value == "" || value == "-" || value == "n/a" || isOpaquePlaceholderTableCell(cell)
}

func isOpaquePlaceholderTableCell(cell string) bool {
	value := strings.ToLower(strings.TrimSpace(cell))
	value = strings.Trim(value, "`*_ ")
	return value == opaqueEntityPlaceholder || value == legacyEntityPlaceholder
}

const (
	flowrunSearchRowHint         = "See the run card"
	searchBlocksRefRowHint       = "See the exact ref in the search_blocks result card."
	triggerIDTableRowHint        = "See the exact trigger ID in the adjacent trigger card."
	activationIDTableRowHint     = "See the exact activation ID in the adjacent activation card."
	activationCreatedAtTableHint = "See the exact creation time in the adjacent activation card."
	activationIDTableRowHintCN   = "精确激活 ID 见旁边的活动卡片。"
	activationTriggerIDTableHint = "精确触发器 ID 见旁边的活动卡片。"
)

func normalizeActivationFieldLabel(label string) string {
	value := strings.TrimSpace(label)
	if annotation := strings.IndexAny(value, "（("); annotation >= 0 {
		value = strings.TrimSpace(value[:annotation])
	}
	value = strings.ToLower(strings.Trim(value, "`*_ "))
	value = strings.Join(strings.Fields(value), " ")
	value = strings.ReplaceAll(value, "triggerid", "trigger id")
	value = strings.ReplaceAll(value, "activationid", "activation id")
	value = strings.ReplaceAll(value, "activationidentifier", "activation identifier")
	value = strings.ReplaceAll(value, "createdat", "created at")
	switch strings.ReplaceAll(value, " ", "") {
	case "激活id", "激活记录id":
		return "id"
	case "触发器id", "触发器标识":
		return "触发器 id"
	case "类型", "触发器类型":
		return "kind"
	case "是否触发":
		return "fired"
	case "创建时间":
		return "created at"
	}
	return value
}

// redactActivationDetailTableRows keeps the assistant's structured summary honest without
// leaking opaque values into prose. It only touches a table with the activation-specific kind /
// fired shape, so a generic Trigger ID table keeps its existing trigger-card guidance.
func redactActivationDetailTableRows(text string) string {
	lines := strings.Split(text, "\n")
	for i := 0; i+2 < len(lines); {
		header, ok := markdownTableCells(lines[i])
		if !ok || len(header) != 2 {
			i++
			continue
		}
		separator, ok := markdownTableCells(lines[i+1])
		if !ok || len(separator) != 2 || !isMarkdownTableSeparator(separator) {
			i++
			continue
		}
		headerKey := normalizeActivationFieldLabel(header[0])
		headerValue := normalizeActivationFieldLabel(header[1])
		if (headerKey != "field" && headerKey != "字段" && headerKey != "key") ||
			(headerValue != "value" && headerValue != "值") {
			i += 2
			continue
		}

		lastRow := i + 1
		rows := make([]int, 0, 8)
		hasKind, hasFired, hasTriggerID, hasCreatedAt := false, false, false, false
		for row := i + 2; row < len(lines); row++ {
			cells, rowOK := markdownTableCells(lines[row])
			if !rowOK || len(cells) != 2 {
				break
			}
			rows = append(rows, row)
			lastRow = row
			switch normalizeActivationFieldLabel(cells[0]) {
			case "kind":
				hasKind = true
			case "fired":
				hasFired = true
			case "trigger id", "trigger identifier", "触发器 id", "触发器标识":
				hasTriggerID = true
			case "created at", "created time", "creation time", "创建时间":
				hasCreatedAt = true
			}
		}
		if !hasKind || !hasFired || (!hasTriggerID && !hasCreatedAt) {
			i = lastRow + 1
			continue
		}

		for _, row := range rows {
			cells, _ := markdownTableCells(lines[row])
			switch normalizeActivationFieldLabel(cells[0]) {
			case "id", "identifier", "activation id", "activation identifier":
				if isUnavailableOpaqueTableCell(cells[1]) {
					if containsHan(text) {
						cells[1] = activationIDTableRowHintCN
					} else {
						cells[1] = activationIDTableRowHint
					}
					lines[row] = formatMarkdownTableRow(cells)
				}
			case "trigger id", "trigger identifier", "触发器 id", "触发器标识":
				if isUnavailableOpaqueTableCell(cells[1]) {
					if containsHan(text) {
						cells[1] = activationTriggerIDTableHint
					} else {
						cells[1] = activationIDTableRowHint
					}
					lines[row] = formatMarkdownTableRow(cells)
				}
			case "created at", "created time", "creation time", "创建时间":
				if isOpaqueTimestampPlaceholderCell(cells[1]) {
					if containsHan(text) {
						cells[1] = "精确创建时间见旁边的活动卡片。"
					} else {
						cells[1] = activationCreatedAtTableHint
					}
					lines[row] = formatMarkdownTableRow(cells)
				}
			}
		}
		i = lastRow + 1
	}
	return strings.Join(lines, "\n")
}

func redactTriggerIDPlaceholderTableRows(text string) string {
	lines := strings.Split(text, "\n")
	for i, line := range lines {
		cells, ok := markdownTableCells(line)
		if !ok || len(cells) < 2 {
			continue
		}
		label := strings.ToLower(strings.Trim(strings.TrimSpace(cells[0]), "`*_ "))
		label = strings.Join(strings.Fields(label), " ")
		if label != "trigger id" && label != "trigger identifier" && label != "触发器 id" && label != "触发器标识" {
			continue
		}
		if !isUnavailableOpaqueTableCell(cells[1]) {
			continue
		}
		if containsHan(line) {
			cells[1] = "精确触发器 ID 见旁边的触发器卡片。"
		} else {
			cells[1] = triggerIDTableRowHint
		}
		lines[i] = formatMarkdownTableRow(cells)
	}
	return strings.Join(lines, "\n")
}

// redactFlowrunSearchRows applies the run-card hint only to a table whose header identifies a
// Run ID column. A generic numeric table is not enough context: search_blocks tables also start
// rows with numbers, but their ref column points to a block card rather than a flowrun card.
// 只有表头明确声明 Run ID 时才指向 run card。单凭数字首列不够，search_blocks 结果表也以数字开头，
// 但它的 ref 应指向构建块结果卡而不是 flowrun 卡。
func redactFlowrunSearchRows(text string) string {
	lines := strings.Split(text, "\n")
	for i := 0; i+2 < len(lines); {
		header, ok := markdownTableCells(lines[i])
		if !ok {
			i++
			continue
		}
		separator, ok := markdownTableCells(lines[i+1])
		if !ok || len(separator) != len(header) || !isMarkdownTableSeparator(separator) {
			i++
			continue
		}

		runIDColumn := -1
		for column, cell := range header {
			label := strings.ToLower(strings.Trim(strings.TrimSpace(cell), "`*_ "))
			label = strings.Join(strings.Fields(label), " ")
			if label == "run id" || label == "flowrun id" || label == "flow run id" {
				runIDColumn = column
				break
			}
		}
		if runIDColumn < 0 {
			i += 2
			continue
		}

		lastRow := i + 1
		for row := i + 2; row < len(lines); row++ {
			cells, rowOK := markdownTableCells(lines[row])
			if !rowOK || len(cells) != len(header) {
				break
			}
			lastRow = row
			if isOpaquePlaceholderTableCell(cells[runIDColumn]) {
				cells[runIDColumn] = flowrunSearchRowHint
				lines[row] = formatMarkdownTableRow(cells)
			}
		}
		i = lastRow + 1
	}
	return strings.Join(lines, "\n")
}

// redactSearchBlocksTableRows treats the adjacent tool card as the only exact-ref surface for a
// search_blocks result table. This also catches a handler method suffix such as
// "the requested item.place" after the generic entity-id pass; replacing only the cell keeps the
// table honest without leaking or inventing a copyable machine value.
// search_blocks 结果表的精确 ref 只保留在相邻 tool card。通用实体 ID 脱敏后即使变成
// 「the requested item.place」这类带方法后缀的坏值，也只替换 ref 单元格，既不泄露也不伪造。
func redactSearchBlocksTableRows(text string) string {
	lines := strings.Split(text, "\n")
	for i := 0; i+2 < len(lines); {
		header, ok := markdownTableCells(lines[i])
		if !ok {
			i++
			continue
		}
		separator, ok := markdownTableCells(lines[i+1])
		if !ok || len(separator) != len(header) || !isMarkdownTableSeparator(separator) {
			i++
			continue
		}

		refColumn, kindColumn, nameColumn, snippetColumn := -1, -1, -1, -1
		for column, cell := range header {
			label := strings.ToLower(strings.Trim(strings.TrimSpace(cell), "`*_ "))
			label = strings.Join(strings.Fields(label), " ")
			switch label {
			case "ref":
				refColumn = column
			case "kind", "type":
				kindColumn = column
			case "name":
				nameColumn = column
			case "snippet", "description":
				snippetColumn = column
			}
		}
		if refColumn < 0 || kindColumn < 0 || nameColumn < 0 || snippetColumn < 0 {
			i += 2
			continue
		}

		lastRow := i + 1
		for row := i + 2; row < len(lines); row++ {
			cells, rowOK := markdownTableCells(lines[row])
			if !rowOK || len(cells) != len(header) {
				break
			}
			lastRow = row
			cells[refColumn] = searchBlocksRefRowHint
			lines[row] = formatMarkdownTableRow(cells)
		}
		i = lastRow + 1
	}
	return strings.Join(lines, "\n")
}

// textRedactor keeps the trailing token until a delimiter arrives. Provider deltas are allowed
// to split an opaque value across chunks; holding one token makes the protection independent of
// that wire chunking while preserving normal streaming for completed words.
type textRedactor struct {
	pending                  string
	relationIntro            string
	hasHan                   bool
	executionDossier         bool
	stripLeadingSectionClose bool
	associationSection       bool
	associationTablePending  string
	getFunctionMentioned     bool
}

func (r *textRedactor) Write(delta string) (result string) {
	// Whole-table redaction has the complete dossier context at durable close, but live deltas
	// can deliver a single provenance/timing row after its heading was already emitted. Remember
	// the block context so the final live pass can apply the same semantic row rewrite.
	// 完整表格在 durable close 时有全量上下文；live delta 可能在标题已发出后才单独到达关联/时间行。
	// 记录当前 block 语境，让 live 最终出口也执行同一套语义行改写。
	lowerDelta := strings.ToLower(delta)
	if strings.Contains(delta, "执行审计档案") ||
		strings.Contains(delta, "完整执行档案") ||
		strings.Contains(lowerDelta, "execution audit dossier") ||
		strings.Contains(lowerDelta, "tool-call") ||
		strings.Contains(lowerDelta, "provenance") {
		r.executionDossier = true
	}
	defer func() {
		result = r.redactLive(result)
	}()
	if containsHan(delta) {
		r.hasHan = true
	}
	if strings.Contains(delta, "关联标识") || strings.Contains(delta, "关联追踪") || strings.Contains(delta, "关联上下文") || strings.Contains(delta, "关联信息") {
		r.associationSection = true
	}
	if r.associationTablePending != "" {
		if dossierTableHasDataRow(delta) {
			pending := r.associationTablePending + delta
			r.associationTablePending = ""
			r.associationSection = false
			return r.Write(pending)
		}
		if strings.TrimSpace(delta) == "" {
			r.associationTablePending += delta
			return ""
		}
		pending := r.associationTablePending
		r.associationTablePending = ""
		r.associationSection = false
		return appendEmptyDossierPointer(redactOpaqueMachineValues(pending)) + r.Write(delta)
	}
	if r.associationSection && isEmptyDossierTableHeaderChunk(delta) {
		r.associationTablePending = delta
		return ""
	}
	if r.relationIntro != "" || (r.pending == "" && strings.HasPrefix(strings.TrimSpace(delta), "以下是") && !strings.Contains(delta, "\n")) {
		r.relationIntro += delta
		if newline := strings.IndexByte(r.relationIntro, '\n'); newline >= 0 {
			intro := r.relationIntro[:newline+1]
			rest := r.relationIntro[newline+1:]
			r.relationIntro = ""
			safe := redactOpaqueMachineValues(intro)
			if rest != "" {
				safe += r.Write(rest)
			}
			return safe
		}
		return ""
	}
	r.pending += delta
	if r.pending == "" {
		return ""
	}
	sawGetFunctionMention := strings.Contains(strings.ToLower(r.pending), "get_function")
	if sawGetFunctionMention {
		r.getFunctionMentioned = true
	}
	// A provider can release the assignment prefix in one delta and the neutral placeholder
	// in the next. Once the complete execution-ID phrase is present, rewrite the whole pending
	// value before any ordinary token-boundary rule can emit the placeholder by itself.
	// provider 可能先发执行 ID 引导语、下一帧才发中性 placeholder。整段齐了就先重写，不能让
	// 普通 token 边界把孤立 placeholder 作为 live delta 发出去。
	if prefix, held, ok := splitExecutionIDPlaceholderValue(r.pending); ok {
		r.pending = held
		return prefix
	}
	if r.stripLeadingSectionClose {
		trimmed := strings.TrimLeft(r.pending, " \t\r\n")
		lowerTrimmed := strings.ToLower(trimmed)
		for _, closingTag := range []string{"</section>", "</think>", "</analysis>"} {
			if strings.HasPrefix(closingTag, lowerTrimmed) && lowerTrimmed != closingTag {
				// The provider may split the prompt/thinking delimiter itself. Hold the short
				// prefix so no partial tag flashes into a live reasoning delta.
				return ""
			}
			if strings.HasPrefix(lowerTrimmed, closingTag) {
				r.pending = strings.TrimLeft(trimmed[len(closingTag):], " \t\r\n")
				r.stripLeadingSectionClose = false
				if r.pending == "" {
					return ""
				}
				return r.Write("")
			}
		}
		r.stripLeadingSectionClose = false
	}
	if prefix, held, ok := splitJSONIDFieldPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitJSONNamedFieldPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitEnglishItsIDAssignmentPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	// Keep an opaque ID plus its following human-name parenthetical together. If the provider
	// splits after the opening parenthesis, the generic ID pass must not flash a marker first.
	// 机器 ID 后紧跟人名括号时要整体暂存，避免 provider 在左括号处分块后先闪出 placeholder。
	if prefix, held, ok := splitEntityIDNameParentheticalPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	// Exact-ID sentences may be split across a line break before the value arrives. Keep the
	// bounded assignment together until either the complete value is present or Flush handles it.
	// 「确切 ID」句式可能在值之前跨换行分块；值到齐前暂存有限长度的整段赋值。
	if prefix, held, ok := splitExactIDAssignmentPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitEnglishExactIDReferencePrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitEnglishNonexistentIDReferencePrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitChineseToolIDAssignmentPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	// The execution record label can arrive as camelCase. Hold its bounded assignment
	// until the opaque value is complete so the prefix cannot flash before the rewrite.
	// executionId 也可能被 provider 拆成前缀和值；值到齐前暂存整段短赋值，避免前缀先闪出。
	if prefix, held, ok := splitExecutionIDCamelAssignmentPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	// The spaced form has the same streaming hazard as camelCase. The complete-sentence
	// rewrite is not enough when the provider sends the label and placeholder separately.
	// 带空格的「execution id」同样会在 provider 分帧时先吐出前缀；完整句改写不足以保护中间帧。
	if prefix, held, ok := splitExecutionIDAssignmentPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	// A bare execution ID phrase has no assignment verb for the ordinary helper to key on.
	// Hold it only while the value is incomplete; once the full phrase is present, let the
	// normal rewrite emit it immediately.
	// 裸 execution ID 句式没有 is/冒号；只在值未到齐时暂存，完整后立即交给普通重写。
	if prefix, held, ok := splitExecutionIDBareAssignmentPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	// Examples such as "functionId (like `…`)" have the same split risk. Do not hold a
	// completed example, otherwise a no-newline reasoning block would wait until close.
	// 「functionId (like `…`)」也有跨帧风险，但完整示例不应等到 close 才显示。
	if prefix, held, ok := splitIDExamplePlaceholderPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	// Keep a hypothetical parenthetical together until its placeholder arrives. Otherwise
	// "which should be something like" can be emitted before the context-aware rewrite removes
	// the entire machine-value aside.
	// 假设性括号要等占位值到齐；否则「which should be something like」会先于整段清理漏出。
	if prefix, held, ok := splitHypotheticalIDPlaceholderPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitChineseToolQueryIDPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitChineseToolReferencePrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitChineseToolValueBeforeIDPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if r.getFunctionMentioned && !sawGetFunctionMention {
		trimmed := strings.TrimLeft(r.pending, " \t")
		if opaqueChineseFunctionReferenceAfterMentionStartPattern.MatchString(trimmed) {
			if prefix, held, ok := splitChineseFunctionInputAfterMentionPrefix(r.pending); ok {
				r.pending = held
				return redactOpaqueMachineValues(prefix)
			}
			if opaqueChineseFunctionReferenceAfterMentionPattern.MatchString(trimmed) {
				r.getFunctionMentioned = false
			}
		} else if trimmed != "" {
			r.getFunctionMentioned = false
		}
	}
	if prefix, held, ok := splitChineseMissingIDColonPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitChineseMissingIDColonBarePrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitChineseRawValueBeforeIDPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitChineseIDLookupFunctionPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitChineseGenericMissingIDSentencePrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitChineseAnyMissingIDSentencePrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitChineseNoMatchingFunctionIDPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitChineseActualFunctionIDPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitChineseDueToCreationPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitChineseIDFormatPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitChineseIDFormatStructurePrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitChineseFunctionShapePrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitChineseIDFabricatedFunctionPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitChineseRegisteredIDFunctionPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitChineseFabricatedIDDirectCallPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitChineseNonexistentIDDirectCallPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitChineseMissingIDInvocationPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitChineseFoundActualIDPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitChineseCorrectFunctionIDAfterPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitChineseIDFunctionNotCreatedPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitChineseFunctionIDNaturalRequirementPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	// Chinese prose may use a non-domain noun such as "执行 ID 是 …". Hold the
	// generic assignment too; the domain-specific prefix above intentionally cannot know
	// every Chinese noun that can precede an opaque identifier.
	// 中文 prose 也可能写「执行 ID 是 …」。领域前缀无法穷举所有名词，因此通用赋值同样
	// 在值到齐前暂存，避免反引号和 placeholder 跨帧漏出。
	if prefix, held, ok := splitChineseBareIDAssignmentPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	// Mixed Chinese/English reasoning often splits after a generic "ID 是" prefix. Keep that
	// prefix until the placeholder arrives even when the preceding noun was emitted in an earlier
	// provider delta; otherwise the next delta can expose "the requested item" by itself.
	// 中英混合 reasoning 常在「ID 是」之后分帧；即使前面的名词已在上一帧发出，也要暂存通用前缀，
	// 否则下一帧单独出现的「the requested item」会穿过实时 SSE。
	// A hosted model may use the stronger advisory form "实际的 ID 应该是 …". Hold
	// that form too; otherwise the prefix can escape before the placeholder arrives.
	// 托管模型也可能使用更强的「实际的 ID 应该是……」句式；同样暂存，不能让前缀先逃出。
	if prefix, held, ok := splitChineseIDShouldBePrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	// A Chinese failure explanation can split after the entity label, e.g. "该函数 ID " +
	// "不存在。". Hold that short machine-field prefix until its predicate arrives so the live
	// stream cannot briefly expose the awkward label before the complete sentence is normalized.
	// 中文失败说明可能在实体标签后分帧，例如「该函数 ID 」+「不存在。」；先暂存这个短机器字段前缀，
	// 等谓词到齐后统一归一化，避免实时流短暂露出不自然的机器字段。
	if prefix, held, ok := splitChineseMissingIDLabelPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	// Tool-bound ID references need a stronger guard than the generic "传入 ID" rule. The tool
	// name and conjunction can arrive before the quoted value, and releasing them would make the
	// later complete rewrite impossible to apply without a visible "并传入的目标" artifact.
	// 绑定工具名的 ID 引用比通用「传入 ID」需要更强的暂存：工具名和并列短语可能先于带引号的值到达，
	// 若提前释放，后续完整改写就会留下「并传入的目标」这种可见脱敏痕迹。
	if prefix, held, ok := splitChineseToolIDReferencePrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	// The second mention in a fabricated-ID explanation can arrive one delta before "是一个…".
	// Hold a value-shaped suffix until that predicate arrives, otherwise the generic pass changes
	// it to a visible neutral marker before the explanation-specific rewrite can make it natural.
	// “虚构 ID”解释里的第二次值可能比「是一个……」早一帧到达；先暂存句尾值，避免通用规则提前改成
	// 可见的中性 marker，让完整解释句能统一改写成自然的人话。
	if r.hasHan || containsHan(r.pending) {
		if prefix, held, ok := splitChineseIDNotFunctionPrefix(r.pending); ok {
			r.pending = held
			return redactOpaqueMachineValues(prefix)
		}
		if prefix, held, ok := splitChineseFabricatedIDExplanationPrefix(r.pending); ok {
			r.pending = held
			return redactOpaqueMachineValues(prefix)
		}
	}
	if prefix, held, ok := splitChineseIDReferencePrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitChineseGenericIDAssignmentPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	// Hold an English opaque-ID assignment until its value arrives. Otherwise a provider delta
	// ending at "the document ID: `" can emit the introducer before the complete clause is safe.
	// 英文 opaque-ID 赋值也要等值到齐，避免 provider 在「the document ID: `」处分块时先吐出引导语。
	if prefix, held, ok := splitEnglishIDAssignmentPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	// Hold a split "I found it: `" prefix until the placeholder arrives. Without this guard the
	// next provider delta can expose the complete placeholder after the useful sentence already
	// escaped the redactor's bounded buffer.
	// 「I found it: `」可能在 placeholder 到来前单独分帧；先暂存整句，防止有用前缀先逃出有限缓冲区。
	if prefix, held, ok := splitEnglishFoundPlaceholderPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	// Hold a Chinese opaque-ID assignment until its value arrives. Without this guard a provider
	// delta ending at "文档 ID 为 `" would reach the stream before the whole assignment can be
	// rewritten to the natural "文档已定位" form.
	// 中文 opaque-ID 赋值必须等值到齐；否则 provider 在「文档 ID 为 `」处分块时，会先把不完整的
	// 引导语送进流，整段就无法统一改写成自然的「文档已定位」。
	if prefix, held, ok := splitChineseIDAssignmentPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitToolNamePrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	// A search_blocks answer often lists several refs in one parenthetical. Hold that sentence
	// until the code span and sentence boundary are complete; otherwise a delta split inside
	// "hd_<id>.place" can release the first half before the ref-aware rewrite sees the whole claim.
	// search_blocks 结果常把多个 ref 放在同一个括号里。等代码跨度和句边界完整后再放行，避免
	// provider 恰好在「hd_<id>.place」中间分块，导致 ref 句先吐出半截。
	if prefix, held, ok := splitSearchRefPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	// Summary bullets can contain a placeholder without mentioning "ref". Hold the whole bullet
	// until its newline so a provider chunk cannot emit the placeholder before the summary-aware
	// rewrite sees the category, count and human-readable name together.
	// 汇总 bullet 即使不写「ref」也可能含有 placeholder。暂存到换行，避免 provider 分块先把坏值吐给 SSE。
	if prefix, held, ok := splitSearchBlocksSummaryPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	// Attachment upload-time tables need their header and data rows together: the exact timestamp
	// is redacted globally, then the row is rewritten to point at the adjacent tool card. Hold the
	// bounded table until its row boundary is known so a provider chunk cannot strand the row without
	// its header context.
	if prefix, held, ok := splitAttachmentTimestampTablePrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitMCPConnectionTimestampTablePrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitMCPConnectionTimestampLabelPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitFieldValueTableHeaderPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitActivationDetailTablePrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	// Relation summaries and their Markdown rows are semantic units. Hold the current bounded
	// line until its newline so a split placeholder or relation ref cannot leak to the messages
	// stream before the relation-specific rewrite sees the complete context.
	if prefix, held, ok := splitRelationPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	// A provider may shorten the English field to "id is …" after the entity name has
	// already appeared. Run this generic guard after relation-specific buffering so a
	// relation query keeps its richer field-level rewrite.
	if prefix, held, ok := splitEnglishGenericIDAssignmentPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitLastMessageAtTablePrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitLastMessageAtFieldPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitNextFireAtTablePrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	if prefix, held, ok := splitNextFireAtFieldPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	// Media reasoning can introduce an attachment id or repeat the original/edited
	// attachment across provider chunks. Hold the bounded assignment until the opaque
	// value is complete so the live SSE stream cannot expose a partial placeholder.
	// 媒体 reasoning 可能跨 provider 分块介绍附件 ID 或重复原图/改图。暂存有限长度的赋值句，
	// 确保实时 SSE 不会先吐出半截 placeholder。
	if prefix, held, ok := splitMediaAttachmentAssignmentPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	// Keep a duplicated placeholder phrase intact until the following token arrives. The provider
	// may split "the the requested item" from its trailing "id"; releasing the first half would
	// expose a value-shaped placeholder before the complete phrase can be redirected.
	// 重复 placeholder 可能在尾部 id 前分帧；先整体暂存，避免第一半先穿过 SSE。
	if prefix, held, ok := splitDuplicatedRequestedItemIDPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	// Markdown table rows carrying opaque values are semantic units, not ordinary prose. A
	// provider can split the row after an opening backtick or between the two cells; holding the
	// incomplete line prevents a bad placeholder from appearing in an intermediate SSE frame.
	if r.executionDossier {
		if prefix, held, ok := splitExecutionDossierTableFragmentPrefix(r.pending); ok {
			r.pending = held
			return redactOpaqueMachineValues(prefix)
		}
	}
	if prefix, held, ok := splitStructuredLinePrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	// A Chinese response can receive the generic timestamp placeholder in a later provider
	// chunk than the surrounding Han text. Keep the language decision on the redactor, not on
	// the current chunk, so `the recorded time` cannot flash in an otherwise Chinese sentence.
	if r.hasHan && strings.Contains(r.pending, opaqueTimestampPlaceholder) {
		safe := redactOpaqueMachineValues(r.pending)
		r.pending = ""
		return safe
	}
	if r.executionDossier {
		if prefix, held, ok := splitExecutionDossierBulletPrefix(r.pending); ok {
			r.pending = held
			return redactOpaqueMachineValues(prefix)
		}
	}
	// Do not emit a partial legacy/current placeholder. Otherwise a provider split such as
	// "the referenced" + " item" can briefly put the bad phrase on the live SSE stream before
	// the durable close has a chance to normalize the complete block.
	if prefix, held, ok := splitPlaceholderPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}

	runes := []rune(r.pending)
	cut := len(runes)
	for cut > 0 && isTokenContinuation(runes[cut-1]) {
		cut--
	}
	if cut == 0 {
		return ""
	}

	// Keep an unfinished parenthetical together with its opener. Entity IDs often arrive in
	// separate provider deltas; emitting the opener first would make the later placeholder
	// impossible to recognize as a redundant target. The bound prevents an unclosed ordinary
	// parenthesis from stalling the whole response indefinitely.
	emitted := string(runes[:cut])
	open := strings.LastIndex(emitted, "(")
	if fullWidthOpen := strings.LastIndex(emitted, "（"); fullWidthOpen > open {
		open = fullWidthOpen
	}
	close := strings.LastIndex(emitted, ")")
	if fullWidthClose := strings.LastIndex(emitted, "）"); fullWidthClose > close {
		close = fullWidthClose
	}
	if open >= 0 && close < open && len([]rune(emitted[open:])) <= 128 {
		prefix := []rune(emitted[:open])
		cut = len(prefix)
		if cut > 0 && unicode.IsSpace(prefix[cut-1]) {
			// Keep the separator with the parenthetical so removing the whole
			// chunk cannot leave a doubled space across provider deltas.
			cut--
		}
		emitted = string(runes[:cut])
	}
	if loc := entityNounPrefixPattern.FindStringIndex(emitted); loc != nil && loc[1] == len(emitted) {
		// Keep the noun plus separator in pending. If the next token is an ordinary word, the
		// following Write will release it; if it is an opaque id, the complete phrase is redacted
		// before any part reaches the messages stream.
		emitted = emitted[:loc[0]]
		pending := string(runes[runeIndexAtByteOffset(emitted, loc[0]):cut])
		r.pending = pending + string(runes[cut:])
		return redactOpaqueMachineValues(emitted)
	}
	if loc := opaqueIDSubjectPrefixPattern.FindStringIndex(emitted); loc != nil && loc[1] == len(emitted) {
		// Hold "The ID `" together with the following token so a chunk boundary
		// cannot turn the eventual redaction into "The ID the referenced item".
		emitted = emitted[:loc[0]]
		pending := string(runes[runeIndexAtByteOffset(emitted, loc[0]):cut])
		r.pending = pending + string(runes[cut:])
		return redactOpaqueMachineValues(emitted)
	}
	if loc := opaqueEntityIDClausePrefixPattern.FindStringIndex(emitted); loc != nil && loc[1] == len(emitted) {
		// Hold "with id `" together with the following opaque value. Otherwise a provider
		// chunk boundary can expose the machine-value introducer before the clause is removed.
		// 将「with id `」与后续 opaque value 一起暂存，避免 provider 分块先露出机器值引导语。
		emitted = emitted[:loc[0]]
		pending := string(runes[runeIndexAtByteOffset(emitted, loc[0]):cut])
		r.pending = pending + string(runes[cut:])
		return redactOpaqueMachineValues(emitted)
	}
	if loc := opaqueEntityIDClauseOpenPrefixPattern.FindStringIndex(emitted); loc != nil && loc[1] == len(emitted) {
		// Hold "with " / "using " / "having " so a following delta can complete the
		// identifier clause before the generic token-boundary path releases it.
		// 暂存「with 」/「using 」/「having 」，让下一帧先补齐标识符短语，再统一清理。
		emitted = emitted[:loc[0]]
		pending := string(runes[runeIndexAtByteOffset(emitted, loc[0]):cut])
		r.pending = pending + string(runes[cut:])
		return redactOpaqueMachineValues(emitted)
	}
	if loc := opaqueTypedIDSubjectPrefixPattern.FindStringIndex(emitted); loc != nil && loc[1] == len(emitted) {
		// Keep "The flowrun with ID `" together with the following token for
		// the same whole-subject rewrite across provider chunk boundaries.
		emitted = emitted[:loc[0]]
		pending := string(runes[runeIndexAtByteOffset(emitted, loc[0]):cut])
		r.pending = pending + string(runes[cut:])
		return redactOpaqueMachineValues(emitted)
	}
	if loc := flowRunSubjectPrefixPattern.FindStringIndex(emitted); loc != nil && loc[1] == len(emitted) {
		// "The flow run ..." is commonly split after "The flow ". Keep that
		// compound-noun prefix until we know whether the next token is "run".
		emitted = emitted[:loc[0]]
		pending := string(runes[runeIndexAtByteOffset(emitted, loc[0]):cut])
		r.pending = pending + string(runes[cut:])
		return redactOpaqueMachineValues(emitted)
	}
	if loc := opaqueReportForPrefixPattern.FindStringIndex(emitted); loc != nil && loc[1] == len(emitted) {
		// Hold "flowrun report for " until the ID arrives so a streamed
		// placeholder does not leave "report for the referenced item" behind.
		emitted = emitted[:loc[0]]
		pending := string(runes[runeIndexAtByteOffset(emitted, loc[0]):cut])
		r.pending = pending + string(runes[cut:])
		return redactOpaqueMachineValues(emitted)
	}
	if loc := opaqueFlowrunSummaryForPrefixPattern.FindStringIndex(emitted); loc != nil && loc[1] == len(emitted) {
		// Hold "Run summary for the " until the target arrives; otherwise a provider frame boundary
		// can expose the target placeholder before the summary-specific rewrite sees the whole line.
		emitted = emitted[:loc[0]]
		pending := string(runes[runeIndexAtByteOffset(emitted, loc[0]):cut])
		r.pending = pending + string(runes[cut:])
		return redactOpaqueMachineValues(emitted)
	}
	r.pending = string(runes[cut:])
	return redactOpaqueMachineValues(emitted)
}

func (r *textRedactor) redactLive(text string) string {
	text = redactOpaqueMachineValues(text)
	// A Chinese reasoning block can split an English placeholder onto its own provider delta.
	// The complete-block redactor has Han context, but the isolated live chunk does not; carry
	// the block language state here so the internal placeholder never flashes between frames.
	// 中文 reasoning 可能把英文 placeholder 单独切到下一帧。完整 block 有中文上下文，但孤立
	// live chunk 没有；这里沿用 block 语言状态，避免内部词在帧间闪现。
	if r.hasHan {
		text = strings.ReplaceAll(text, opaqueEntityPlaceholder, "这个输入")
		text = strings.ReplaceAll(text, legacyEntityPlaceholder, "这个输入")
	}
	if !r.executionDossier {
		return text
	}
	text = redactChineseDossierFieldLinesInContext(text)
	text = redactEnglishDossierFieldLinesInContext(text)
	text = redactEnglishDossierInlineFieldNamesInContext(text)
	text = redactEnglishExecutionPointerRows(text)
	return redactStandaloneExecutionTimingRows(text)
}

// redactCompleteUserBlock applies the same context-aware redaction used for live deltas to the
// complete durable block. The close snapshot must not fall back to the generic pass: a dossier
// may have already been made readable live by pointing exact values to its adjacent card, while
// the generic pass would turn that wording back into a neutral placeholder.
// redactCompleteUserBlock 对完整 durable block 复用 live 的上下文脱敏。close 不能退回通用 pass：
// dossier 的实时文本可能已被改写为「精确值见相邻卡片」，通用 pass 会把它重新变成中性 placeholder。
func redactCompleteUserBlock(raw string) string {
	if !hasExecutionDossierContext(raw) {
		return normalizeChineseFunctionNotFoundCopy(redactOpaqueMachineValues(raw))
	}
	r := textRedactor{stripLeadingSectionClose: true}
	r.executionDossier = true
	result := r.Write(raw)
	result += r.Flush()
	return normalizeChineseFunctionNotFoundCopy(r.redactLive(result))
}

// normalizeChineseFunctionNotFoundCopy gives the complete get_function failure block one stable
// product-facing shape. Hosted models may explain the same fact with implementation details, but
// those details are neither useful to the user nor safe to preserve after opaque-value redaction.
// 仅在完整收尾块上归一化，避免流式中间帧先替换成整段文案、随后又接上 provider 尾巴。
func normalizeChineseFunctionNotFoundCopy(text string) string {
	if !containsHan(text) ||
		!strings.Contains(text, "未找到") ||
		!strings.Contains(text, "函数") ||
		!strings.Contains(text, "注册") {
		return text
	}
	lowerText := strings.ToLower(text)
	if !strings.Contains(text, "函数未找到") && !strings.Contains(lowerText, "function not found") {
		return text
	}
	return "调用 `get_function` 返回了\"未找到\"结果。\n\n" +
		"实际原因说明：\n\n" +
		"这个输入格式合法，但对应的函数目前未注册。\n" +
		"这是正常的\"未找到\"结果，不是格式问题。\n\n" +
		"如需查找已有函数，可使用 `search_function` 按关键词检索。"
}

func hasExecutionDossierContext(text string) bool {
	lowerText := strings.ToLower(text)
	return strings.Contains(text, "执行审计档案") ||
		strings.Contains(text, "完整执行档案") ||
		strings.Contains(lowerText, "execution audit dossier") ||
		strings.Contains(lowerText, "tool-call details") ||
		strings.Contains(lowerText, "provenance")
}

func (r *textRedactor) Flush() string {
	if r.relationIntro != "" {
		intro := redactOpaqueMachineValues(r.relationIntro)
		r.relationIntro = ""
		return intro + r.Flush()
	}
	if r.associationTablePending != "" {
		pending := r.associationTablePending
		r.associationTablePending = ""
		r.associationSection = false
		return appendEmptyDossierPointer(redactOpaqueMachineValues(pending)) + r.Flush()
	}
	if r.pending == "" {
		return ""
	}
	emitted := redactOpaqueMachineValues(r.pending)
	r.pending = ""
	return emitted
}

// regexp.FindStringIndex returns byte offsets, while the pending buffer is split as runes so a
// multi-byte user-facing prefix cannot turn a byte offset into an invalid slice bound.
// regexp.FindStringIndex 返回字节下标，但 pending 按 rune 切分；多字节人话前缀不能直接拿字节下标切 rune。
func runeIndexAtByteOffset(text string, byteOffset int) int {
	return utf8.RuneCountInString(text[:byteOffset])
}

func isTokenContinuation(r rune) bool {
	return unicode.IsLetter(r) || unicode.IsDigit(r) || strings.ContainsRune("_:+./-=", r)
}

func splitExecutionIDPlaceholderValue(text string) (prefix, held string, ok bool) {
	bestStart, bestEnd := -1, -1
	for _, pattern := range []*regexp.Regexp{
		opaqueExecutionIDBarePattern,
		opaqueExecutionIDReferencePlaceholderPattern,
	} {
		loc := pattern.FindStringIndex(text)
		if loc == nil || (bestStart >= 0 && loc[0] >= bestStart) {
			continue
		}
		bestStart, bestEnd = loc[0], loc[1]
	}
	if bestStart < 0 {
		return "", "", false
	}
	matched := text[bestStart:bestEnd]
	// The entity-ID pattern deliberately accepts a value prefix so it can match IDs
	// split across provider deltas. If the match opened a code span but has not seen
	// its closing delimiter, do not split at that prefix: the following delta still
	// belongs to the same opaque value and must not be emitted as plain text.
	// entity ID 正则故意允许值前缀以适配跨帧分块；若反引号尚未闭合，不能在半值处分割，
	// 否则下一帧的 ID 尾巴会作为普通文本进入 live SSE。
	if strings.Count(matched, "`")%2 == 1 || strings.Count(matched, "\"")%2 == 1 {
		return "", "", false
	}
	prefix = redactOpaqueMachineValues(text[:bestEnd])
	if strings.Contains(prefix, opaqueEntityPlaceholder) || strings.Contains(prefix, legacyEntityPlaceholder) {
		return "", "", false
	}
	return prefix, text[bestEnd:], true
}

func splitPlaceholderPrefix(text string) (prefix, held string, ok bool) {
	for _, phrase := range []string{legacyEntityPlaceholder, opaqueEntityPlaceholder} {
		for start := len(text) - 1; start >= 0; start-- {
			suffix := text[start:]
			if len(suffix) >= len(phrase) || !strings.HasPrefix(phrase, suffix) {
				continue
			}
			// A partial placeholder is only meaningful at a token boundary. Without this
			// guard, the tail "th" of an ordinary word such as "with" is mistaken for
			// the beginning of "the requested item" and splits the preceding word.
			if start > 0 {
				previous, _ := utf8.DecodeLastRuneInString(text[:start])
				if isTokenContinuation(previous) {
					continue
				}
			}
			holdStart := start
			lowerPrefix := strings.ToLower(text[:start])
			for _, marker := range []string{"get_flowrun", "flowrunid", "run summary for", "flowrun summary for", "flow run summary for"} {
				if markerStart := strings.LastIndex(lowerPrefix, marker); markerStart >= 0 {
					holdStart = markerStart
					break
				}
			}
			if holdStart == start && start > 0 && text[start-1] == '`' {
				holdStart--
			}
			// If the partial placeholder is inside an ID-labelled parenthetical, hold the
			// opening parenthesis too. Otherwise the next chunk cannot remove the complete
			// machine-value parenthetical after the placeholder arrives.
			if open := strings.LastIndex(text[:holdStart], "("); open >= 0 && strings.LastIndex(text[:holdStart], ")") < open {
				inner := strings.TrimSpace(text[open+1 : holdStart])
				inner = strings.TrimSpace(strings.TrimLeft(inner, "`"))
				label := strings.TrimSpace(strings.TrimSuffix(inner, ":"))
				if strings.EqualFold(label, "id") || strings.EqualFold(label, "identifier") {
					holdStart = open
					for holdStart > 0 {
						previous, size := utf8.DecodeLastRuneInString(text[:holdStart])
						if !unicode.IsSpace(previous) {
							break
						}
						holdStart -= size
					}
				}
			}
			return text[:holdStart], text[holdStart:], true
		}
	}
	return "", "", false
}

func splitDuplicatedRequestedItemIDPrefix(text string) (prefix, held string, ok bool) {
	const phrase = "the the requested item"
	trimmed := strings.TrimRight(text, " \t")
	lower := strings.ToLower(trimmed)
	start := strings.LastIndex(lower, phrase)
	if start < 0 || start+len(phrase) != len(lower) {
		return "", "", false
	}
	return text[:start], text[start:], true
}

func splitChineseIDAssignmentPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseIDAssignmentPrefixPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitEntityIDNameParentheticalPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueEntityIDNameParentheticalPrefixPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if opaqueEntityIDNameParentheticalPattern.MatchString(suffix) {
			continue
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitEnglishItsIDAssignmentPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueEnglishItsIDAssignmentPrefixPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if strings.Contains(suffix, "\n") {
			if opaqueEnglishItsIDAssignmentPattern.MatchString(suffix) || opaqueEnglishItsIDAssignmentPlaceholderPattern.MatchString(suffix) {
				continue
			}
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitJSONIDFieldPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueJSONIDFieldPrefixPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if strings.Contains(suffix, "\n") {
			if opaqueJSONIDFieldPattern.MatchString(suffix) || opaqueJSONIDFieldPlaceholderPattern.MatchString(suffix) {
				continue
			}
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitJSONNamedFieldPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueJSONNamedFieldPrefixPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if strings.Contains(suffix, "\n") {
			if opaqueJSONNamedIDFieldPattern.MatchString(suffix) ||
				opaqueJSONNamedIDFieldPlaceholderPattern.MatchString(suffix) ||
				opaqueJSONNamedTimeFieldPlaceholderPattern.MatchString(suffix) {
				continue
			}
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitExactIDAssignmentPrefix(text string) (prefix, held string, ok bool) {
	for _, pair := range []struct {
		prefix      *regexp.Regexp
		actual      *regexp.Regexp
		placeholder *regexp.Regexp
	}{
		{prefix: opaqueChineseExactIDAssignmentPrefixPattern, actual: opaqueChineseExactIDAssignmentPattern, placeholder: opaqueChineseExactIDAssignmentPlaceholderPattern},
		{prefix: opaqueEnglishExactIDAssignmentPrefixPattern, actual: opaqueEnglishExactIDAssignmentPattern, placeholder: opaqueEnglishExactIDAssignmentPlaceholderPattern},
	} {
		for _, loc := range pair.prefix.FindAllStringIndex(text, -1) {
			suffix := text[loc[0]:]
			if len([]rune(suffix)) > 256 {
				continue
			}
			if pair.actual.MatchString(suffix) || pair.placeholder.MatchString(suffix) {
				continue
			}
			return text[:loc[0]], suffix, true
		}
	}
	return "", "", false
}

func splitEnglishExactIDReferencePrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueEnglishExactIDReferenceStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if match := opaqueEnglishExactIDReferencePattern.FindStringIndex(suffix); match != nil &&
			opaqueMatchHasBalancedQuotes(suffix, opaqueEnglishExactIDReferencePattern) {
			if strings.TrimSpace(suffix[match[1]:]) == "" {
				return text[:loc[0]], suffix, true
			}
			continue
		}
		trimmed := strings.TrimSpace(suffix)
		if strings.HasSuffix(trimmed, "with the exact ID") || strings.Contains(suffix, "`") ||
			strings.Contains(suffix, `"`) || entityIDPattern.MatchString(suffix) ||
			strings.Contains(suffix, opaqueEntityPlaceholder) || strings.Contains(suffix, legacyEntityPlaceholder) {
			return text[:loc[0]], suffix, true
		}
	}
	return "", "", false
}

func splitEnglishNonexistentIDReferencePrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueEnglishNonexistentIDReferenceOpenPrefixPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 || opaqueEnglishNonexistentIDReferencePattern.MatchString(suffix) {
			continue
		}
		return text[:loc[0]], suffix, true
	}
	for _, loc := range opaqueEnglishNonexistentIDReferenceStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if match := opaqueEnglishNonexistentIDReferencePattern.FindStringIndex(suffix); match != nil &&
			opaqueMatchHasBalancedQuotes(suffix, opaqueEnglishNonexistentIDReferencePattern) {
			if strings.TrimSpace(suffix[match[1]:]) == "" {
				return text[:loc[0]], suffix, true
			}
			continue
		}
		trimmed := strings.TrimSpace(suffix)
		if strings.HasSuffix(trimmed, "with the nonexistent ID") || strings.Contains(suffix, "`") ||
			strings.Contains(suffix, `"`) || entityIDPattern.MatchString(suffix) ||
			strings.Contains(suffix, opaqueEntityPlaceholder) || strings.Contains(suffix, legacyEntityPlaceholder) {
			return text[:loc[0]], suffix, true
		}
	}
	return "", "", false
}

func splitEnglishIDAssignmentPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueEnglishIDAssignmentPrefixPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitEnglishGenericIDAssignmentPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueEnglishGenericIDAssignmentPrefixPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if strings.Contains(suffix, "\n") || len([]rune(suffix)) > 256 {
			continue
		}
		if opaqueEnglishGenericIDAssignmentPattern.MatchString(suffix) {
			continue
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitExecutionIDCamelAssignmentPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueExecutionIDCamelAssignmentPrefixPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if strings.Contains(suffix, "\n") || len([]rune(suffix)) > 256 {
			continue
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitExecutionIDAssignmentPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueExecutionIDAssignmentPrefixPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if strings.Contains(suffix, "\n") || len([]rune(suffix)) > 256 {
			continue
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitExecutionIDBareAssignmentPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueExecutionIDBarePrefixPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		// A Markdown dossier row can put emphasis markers directly after the field label,
		// e.g. `Execution ID** | ...`. That is a table cell, not an unfinished prose
		// assignment; leave it intact so the Field/Value table buffer retains row context.
		// Markdown 卷宗表格会把强调标记直接贴在字段名后，例如 `Execution ID** | ...`。
		// 这是表格单元格而不是未完成散文赋值，必须交给 Field/Value 表格缓冲保留行上下文。
		prefixEnd := opaqueExecutionIDBarePrefixPattern.FindStringIndex(suffix)
		if prefixEnd != nil {
			remainder := strings.TrimLeft(suffix[prefixEnd[1]:], " \t")
			if strings.HasPrefix(remainder, "**") || strings.HasPrefix(remainder, "__") {
				continue
			}
		}
		// The bare prefix also matches the start of the ordinary "execution ID is …"
		// form. Leave those to the more specific assignment helper above.
		if opaqueExecutionIDAssignmentPrefixPattern.MatchString(suffix) {
			continue
		}
		if opaqueExecutionIDBarePattern.MatchString(suffix) {
			// The opaque-ID regex intentionally accepts prefixes of a value so it can
			// match a complete ID after provider chunking. When an opening code quote
			// is still unmatched, that prefix is not complete: hold the whole clause
			// or the remaining suffix, otherwise the next delta can leak the ID tail.
			// provider 若只发了左反引号和半个 ID，不能把半值当完整值脱敏后放行，
			// 否则下一帧的后半段会绕过整句重写直接进入 live SSE。
			if strings.Count(suffix, "`")%2 == 1 || strings.Count(suffix, "\"")%2 == 1 {
				return text[:loc[0]], suffix, true
			}
			continue
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitIDExamplePlaceholderPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueIDExamplePlaceholderPrefixPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if opaqueIDExamplePlaceholderPattern.MatchString(suffix) {
			continue
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitHypotheticalIDPlaceholderPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueHypotheticalIDPlaceholderPrefixPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if opaqueHypotheticalIDPlaceholderPattern.MatchString(suffix) {
			continue
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitChineseBareIDAssignmentPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseBareIDAssignmentPrefixPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if strings.Contains(suffix, "\n") || len([]rune(suffix)) > 256 {
			continue
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitChineseGenericIDAssignmentPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseGenericIDAssignmentPrefixPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if strings.Contains(suffix, "\n") || len([]rune(suffix)) > 256 {
			continue
		}
		if opaqueChineseGenericIDAssignmentPattern.MatchString(suffix) {
			continue
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitChineseIDShouldBePrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseIDShouldBePrefixPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if strings.Contains(suffix, "\n") || len([]rune(suffix)) > 256 {
			continue
		}
		if opaqueChineseIDShouldBePattern.MatchString(suffix) || opaqueChineseIDShouldBePlaceholderPattern.MatchString(suffix) {
			continue
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitChineseToolIDReferencePrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseToolIDReferenceStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if opaqueMatchHasBalancedQuotes(suffix, opaqueChineseToolIDReferencePattern) {
			continue
		}
		if strings.Contains(suffix, "\n") || len([]rune(suffix)) > 256 {
			continue
		}
		// The provider may have emitted the opening code quote but not the value/closing quote.
		// Keep the complete tool phrase until the value is available.
		if strings.Count(suffix, "`")%2 == 1 || strings.Count(suffix, "\"")%2 == 1 {
			return text[:loc[0]], suffix, true
		}
		return text[:loc[0]], suffix, true
	}
	for _, loc := range opaqueChineseToolIDTimeReferenceStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if strings.Contains(suffix, "\n") || len([]rune(suffix)) > 256 {
			continue
		}
		if strings.Count(suffix, "`")%2 == 1 || strings.Count(suffix, `"`)%2 == 1 {
			return text[:loc[0]], suffix, true
		}
		if opaqueChineseToolIDTimeReferencePattern.MatchString(suffix) {
			hasOpaqueValue := entityIDPattern.MatchString(suffix) ||
				strings.Contains(suffix, opaqueEntityPlaceholder) ||
				strings.Contains(suffix, legacyEntityPlaceholder) ||
				strings.Contains(suffix, "the requested item") ||
				strings.Contains(suffix, "the referenced item") ||
				strings.Contains(suffix, "该目标")
			// The tool name's closing code quote and the value's opening quote can make the
			// count even while the value's closing quote is still in the next delta.
			// 工具名的结束反引号和 ID 的开始反引号会让计数暂时为偶数，但值的结束反引号仍在下一帧。
			if hasOpaqueValue && (strings.Count(suffix, "`") == 2 || strings.Count(suffix, `"`) == 2) {
				return text[:loc[0]], suffix, true
			}
			continue
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitChineseToolIDAssignmentPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseToolIDAssignmentOpenPrefixPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if strings.Contains(suffix, "\n") || len([]rune(suffix)) > 256 || opaqueChineseToolIDAssignmentPattern.MatchString(suffix) {
			continue
		}
		return text[:loc[0]], suffix, true
	}
	for _, loc := range opaqueChineseToolIDAssignmentStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if strings.Contains(suffix, "\n") || len([]rune(suffix)) > 256 {
			continue
		}
		trimmed := strings.TrimSpace(suffix)
		if strings.HasSuffix(trimmed, "ID 为") || strings.HasSuffix(trimmed, "ID 是") ||
			strings.HasSuffix(trimmed, "ID:") || strings.HasSuffix(trimmed, "ID：") ||
			strings.Contains(suffix, "`") || strings.Contains(suffix, `"`) ||
			entityIDPattern.MatchString(suffix) || strings.Contains(suffix, opaqueEntityPlaceholder) ||
			strings.Contains(suffix, legacyEntityPlaceholder) || strings.Contains(suffix, "该目标") {
			return text[:loc[0]], suffix, true
		}
	}
	return "", "", false
}

func opaqueMatchHasBalancedQuotes(text string, pattern *regexp.Regexp) bool {
	loc := pattern.FindStringIndex(text)
	if loc == nil {
		return false
	}
	match := text[loc[0]:loc[1]]
	return strings.Count(match, "`")%2 == 0 && strings.Count(match, "\"")%2 == 0
}

func splitChineseToolQueryIDPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseToolQueryIDStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if opaqueMatchHasBalancedQuotes(suffix, opaqueChineseToolQueryIDPattern) {
			continue
		}
		if len([]rune(suffix)) > 256 {
			continue
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitChineseToolReferencePrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseToolReferenceStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if opaqueMatchHasBalancedQuotes(suffix, opaqueChineseToolReferencePattern) {
			continue
		}
		trimmed := strings.TrimSpace(suffix)
		if strings.HasSuffix(trimmed, "传入") || strings.HasSuffix(trimmed, "传入了") ||
			strings.Contains(suffix, "`") || strings.Contains(suffix, "\"") ||
			entityIDPattern.MatchString(suffix) || strings.Contains(suffix, opaqueEntityPlaceholder) ||
			strings.Contains(suffix, legacyEntityPlaceholder) || strings.Contains(suffix, "该目标") {
			return text[:loc[0]], suffix, true
		}
	}
	return "", "", false
}

func splitChineseGenericMissingIDSentencePrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseGenericMissingIDSentenceStartPattern.FindAllStringIndex(text, -1) {
		if opaqueChineseRawValueBeforeIDPattern.MatchString(text) {
			// The opaque value immediately before this label owns the whole phrase; let its
			// narrow rewrite run before the generic sentence buffer splits at "这个 ID".
			// 标签前紧邻的 opaque 值属于同一短语，先让窄规则整体处理，不能在「这个 ID」处分帧。
			continue
		}
		if opaqueChineseToolValueBeforeIDPattern.MatchString(text) {
			// A complete tool-bound phrase earlier in the same delta owns this ID label. Let the
			// tool-specific rewrite consume the whole sentence instead of holding the trailing
			// "这个 ID" and emitting the already-redacted value before it.
			// 同一 delta 前面若已有完整的工具绑定短语，应由工具规则整体消费，不能只暂存尾部
			//「这个 ID」而把已经脱敏的值先吐到 live 流。
			continue
		}
		if opaqueChinesePlaceholderCorrespondencePattern.MatchString(text) {
			// The later "这个 ID" belongs to the complete workspace-correspondence sentence;
			// keep its context intact so the semantic rewrite can remove the field as one unit.
			// 后面的「这个 ID」属于完整的工作区对应关系句，必须保留上下文，让语义规则整体移除字段。
			continue
		}
		if opaqueChineseGenericIDCorrespondencePattern.MatchString(text) {
			// The same boundary applies to the shorter "没有与该 ID 对应" variant.
			// 较短的「没有与该 ID 对应」句式也必须保持完整，不能在 ID 标签处提前分帧。
			continue
		}
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if opaqueChineseGenericMissingIDSentencePattern.MatchString(suffix) ||
			opaqueChineseGenericMissingIDLocationPattern.MatchString(suffix) ||
			opaqueChineseGenericMissingIDPlaceholderLocationPattern.MatchString(suffix) {
			continue
		}
		if !strings.Contains(suffix, "`") && !strings.Contains(suffix, "\"") &&
			!entityIDPattern.MatchString(suffix) && !strings.Contains(suffix, "该目标") {
			continue
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitChineseToolValueBeforeIDPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseToolValueBeforeIDStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if opaqueChineseToolValueBeforeIDPattern.MatchString(suffix) &&
			opaqueMatchHasBalancedQuotes(suffix, opaqueChineseToolValueBeforeIDPattern) {
			continue
		}
		trimmed := strings.TrimSpace(suffix)
		if strings.HasSuffix(trimmed, "传入了") || strings.Contains(suffix, "`") ||
			strings.Contains(suffix, "\"") || entityIDPattern.MatchString(suffix) ||
			strings.Contains(suffix, opaqueEntityPlaceholder) || strings.Contains(suffix, legacyEntityPlaceholder) ||
			strings.Contains(suffix, "该目标") {
			return text[:loc[0]], suffix, true
		}
	}
	return "", "", false
}

func splitChineseFunctionInputAfterMentionPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseFunctionReferenceAfterMentionStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if match := opaqueChineseFunctionReferenceAfterMentionPattern.FindStringIndex(suffix); match != nil &&
			opaqueMatchHasBalancedQuotes(suffix, opaqueChineseFunctionReferenceAfterMentionPattern) {
			// The value is now complete. Replace the whole machine-field phrase with the
			// sentence connective immediately, leaving punctuation and later prose pending.
			// 值已完整到达，立即把整段机器字段替换成连接词；标点和后续正文继续暂存。
			return text[:loc[0]] + "后", suffix[match[1]:], true
		}
		trimmed := strings.TrimSpace(suffix)
		if strings.HasSuffix(trimmed, "传入") || strings.HasSuffix(trimmed, "传入了") || strings.Contains(suffix, "`") ||
			strings.Contains(suffix, "\"") || entityIDPattern.MatchString(suffix) ||
			strings.Contains(suffix, opaqueEntityPlaceholder) || strings.Contains(suffix, legacyEntityPlaceholder) ||
			strings.Contains(suffix, "该目标") || strings.Contains(suffix, "这个") || strings.Contains(suffix, "该") {
			return text[:loc[0]], suffix, true
		}
	}
	return "", "", false
}

func splitChineseRawValueBeforeIDPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseRawValueBeforeIDStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if match := opaqueChineseRawValueBeforeIDPattern.FindStringIndex(suffix); match != nil &&
			opaqueMatchHasBalancedQuotes(suffix, opaqueChineseRawValueBeforeIDPattern) {
			// Keep a complete value-plus-label phrase when the provider stopped exactly at
			// the label. The generic token boundary would otherwise emit the raw value and
			// leave the trailing "这个 ID" for the next delta.
			// provider 若恰好在标签末尾停帧，仍要暂存完整短语；否则通用 token 边界会先吐出
			// 裸值，再把尾部「这个 ID」留给下一帧。
			if strings.TrimSpace(suffix[match[1]:]) == "" {
				return text[:loc[0]], suffix, true
			}
			continue
		}
		valueLoc := entityIDPattern.FindStringIndex(suffix)
		if valueLoc == nil {
			continue
		}
		tail := strings.TrimLeft(suffix[valueLoc[1]:], "`\" \t")
		if strings.HasPrefix(tail, "这个") || strings.HasPrefix(tail, "该") {
			return text[:loc[0]], suffix, true
		}
	}
	return "", "", false
}

func splitChineseMissingIDColonPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseMissingIDColonStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if match := opaqueChineseMissingIDColonPattern.FindStringIndex(suffix); match != nil &&
			opaqueMatchHasBalancedQuotes(suffix, opaqueChineseMissingIDColonPattern) {
			if strings.TrimSpace(suffix[match[1]:]) == "" {
				return text[:loc[0]], suffix, true
			}
			continue
		}
		trimmed := strings.TrimSpace(suffix)
		if strings.HasSuffix(trimmed, "：") || strings.HasSuffix(trimmed, ":") ||
			strings.Contains(suffix, "`") || strings.Contains(suffix, "\"") ||
			entityIDPattern.MatchString(suffix) || strings.Contains(suffix, opaqueEntityPlaceholder) ||
			strings.Contains(suffix, legacyEntityPlaceholder) || strings.Contains(suffix, "该目标") {
			return text[:loc[0]], suffix, true
		}
	}
	return "", "", false
}

func splitChineseMissingIDColonBarePrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseMissingIDColonBareStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if match := opaqueChineseMissingIDColonBarePattern.FindStringIndex(suffix); match != nil &&
			opaqueMatchHasBalancedQuotes(suffix, opaqueChineseMissingIDColonBarePattern) {
			if strings.TrimSpace(suffix[match[1]:]) == "" {
				return text[:loc[0]], suffix, true
			}
			continue
		}
		trimmed := strings.TrimSpace(suffix)
		if strings.HasSuffix(trimmed, "一个不存在但格式正确的") || strings.HasSuffix(trimmed, "ID") ||
			strings.HasSuffix(trimmed, "标识符") || strings.Contains(suffix, "：") || strings.Contains(suffix, ":") ||
			strings.Contains(suffix, "`") || strings.Contains(suffix, `"`) || entityIDPattern.MatchString(suffix) ||
			strings.Contains(suffix, opaqueEntityPlaceholder) || strings.Contains(suffix, legacyEntityPlaceholder) ||
			strings.Contains(suffix, "该目标") {
			return text[:loc[0]], suffix, true
		}
	}
	return "", "", false
}

func splitChineseIDNotFunctionPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseIDNotFunctionStartPattern.FindAllStringIndex(text, -1) {
		if !opaqueChineseFabricatedIDExplanationContextPattern.MatchString(text[:loc[0]]) {
			continue
		}
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if opaqueChineseIDNotFunctionPattern.MatchString(suffix) &&
			opaqueMatchHasBalancedQuotes(suffix, opaqueChineseIDNotFunctionPattern) {
			continue
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitChineseAnyMissingIDSentencePrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseAnyMissingIDSentenceStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if opaqueMatchHasBalancedQuotes(suffix, opaqueChineseAnyMissingIDSentencePattern) ||
			(opaqueChineseMissingIDParentheticalSentencePattern.MatchString(suffix) &&
				opaqueMatchHasBalancedQuotes(suffix, opaqueChineseMissingIDParentheticalSentencePattern)) {
			continue
		}
		if len([]rune(suffix)) > 256 {
			continue
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitChineseNoMatchingFunctionIDPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseNoMatchingFunctionIDStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if opaqueMatchHasBalancedQuotes(suffix, opaqueChineseNoMatchingFunctionIDPattern) {
			continue
		}
		if len([]rune(suffix)) > 256 {
			continue
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitChineseActualFunctionIDPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseActualFunctionIDStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if opaqueMatchHasBalancedQuotes(suffix, opaqueChineseActualFunctionIDPattern) {
			continue
		}
		if len([]rune(suffix)) > 256 {
			continue
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitChineseDueToCreationPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseDueToCreationStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if opaqueMatchHasBalancedQuotes(suffix, opaqueChineseDueToCreationPattern) {
			continue
		}
		trimmed := strings.TrimSpace(suffix)
		if strings.HasSuffix(trimmed, "由于") || strings.Contains(suffix, "`") ||
			strings.Contains(suffix, "\"") || entityIDPattern.MatchString(suffix) ||
			strings.Contains(suffix, opaqueEntityPlaceholder) || strings.Contains(suffix, legacyEntityPlaceholder) ||
			strings.Contains(suffix, "该目标") {
			return text[:loc[0]], suffix, true
		}
	}
	return "", "", false
}

func splitChineseIDFormatPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseIDFormatPrefixStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if match := opaqueChineseIDFormatPrefixPattern.FindStringIndex(suffix); match != nil &&
			opaqueMatchHasBalancedQuotes(suffix, opaqueChineseIDFormatPrefixPattern) {
			tail := strings.TrimSpace(suffix[match[1]:])
			if tail == "" || tail == "前缀" || strings.EqualFold(tail, "prefix") {
				return text[:loc[0]], suffix, true
			}
			continue
		}
		trimmed := strings.TrimSpace(suffix)
		if strings.HasSuffix(trimmed, "格式为") || strings.Contains(suffix, "`") ||
			strings.Contains(suffix, `"`) || strings.Contains(suffix, "fn_") {
			return text[:loc[0]], suffix, true
		}
	}
	return "", "", false
}

func splitChineseIDFormatStructurePrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseIDFormatStructureStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if opaqueChineseIDFormatStructurePattern.MatchString(suffix) {
			continue
		}
		trimmed := strings.TrimSpace(suffix)
		if strings.HasSuffix(trimmed, "格式上符合") || strings.HasSuffix(trimmed, "符合") ||
			strings.Contains(suffix, "`") || strings.Contains(suffix, `"`) ||
			strings.Contains(suffix, "fn_") || strings.Contains(suffix, opaqueEntityPlaceholder) ||
			strings.Contains(suffix, legacyEntityPlaceholder) || strings.Contains(suffix, "该目标") {
			return text[:loc[0]], suffix, true
		}
	}
	return "", "", false
}

func splitChineseFunctionShapePrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseFunctionShapeStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if opaqueMatchHasBalancedQuotes(suffix, opaqueChineseFunctionShapePattern) {
			continue
		}
		trimmed := strings.TrimSpace(suffix)
		if strings.HasSuffix(trimmed, "形如") || strings.Contains(suffix, "`") ||
			strings.Contains(suffix, "\"") || entityIDPattern.MatchString(suffix) ||
			strings.Contains(suffix, opaqueEntityPlaceholder) || strings.Contains(suffix, legacyEntityPlaceholder) ||
			strings.Contains(suffix, "该目标") {
			return text[:loc[0]], suffix, true
		}
	}
	return "", "", false
}

func splitChineseIDFabricatedFunctionPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseIDFabricatedFunctionStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if opaqueMatchHasBalancedQuotes(suffix, opaqueChineseIDFabricatedFunctionPattern) {
			continue
		}
		trimmed := strings.TrimSpace(suffix)
		if strings.HasSuffix(trimmed, "ID") || strings.Contains(suffix, "`") ||
			strings.Contains(suffix, "\"") || entityIDPattern.MatchString(suffix) ||
			strings.Contains(suffix, opaqueEntityPlaceholder) || strings.Contains(suffix, legacyEntityPlaceholder) ||
			strings.Contains(suffix, "该目标") {
			return text[:loc[0]], suffix, true
		}
	}
	return "", "", false
}

func splitChineseRegisteredIDFunctionPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseRegisteredIDFunctionStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if opaqueChineseRegisteredIDFunctionPattern.MatchString(suffix) {
			continue
		}
		trimmed := strings.TrimSpace(suffix)
		if strings.HasSuffix(trimmed, "ID") || strings.Contains(suffix, "对应的函数") {
			return text[:loc[0]], suffix, true
		}
	}
	return "", "", false
}

func splitChineseFabricatedIDDirectCallPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseFabricatedIDDirectCallStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if opaqueChineseFabricatedIDDirectCallPattern.MatchString(suffix) &&
			opaqueMatchHasBalancedQuotes(suffix, opaqueChineseFabricatedIDDirectCallPattern) {
			continue
		}
		trimmed := strings.TrimSpace(suffix)
		if (strings.HasPrefix(trimmed, "用这个虚构的") && !strings.Contains(trimmed, "调用")) || strings.Contains(suffix, "`") ||
			strings.Contains(suffix, `"`) || entityIDPattern.MatchString(suffix) ||
			strings.Contains(suffix, opaqueEntityPlaceholder) || strings.Contains(suffix, legacyEntityPlaceholder) ||
			strings.Contains(suffix, "该目标") {
			return text[:loc[0]], suffix, true
		}
	}
	return "", "", false
}

func splitChineseNonexistentIDDirectCallPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseNonexistentIDDirectCallStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if match := opaqueChineseNonexistentIDDirectCallPattern.FindStringIndex(suffix); match != nil &&
			opaqueMatchHasBalancedQuotes(suffix, opaqueChineseNonexistentIDDirectCallPattern) {
			if strings.TrimSpace(suffix[match[1]:]) == "" {
				return text[:loc[0]], suffix, true
			}
			continue
		}
		trimmed := strings.TrimSpace(suffix)
		if strings.HasPrefix(trimmed, "一个不存在的") || strings.Contains(suffix, "`") ||
			strings.Contains(suffix, `"`) || entityIDPattern.MatchString(suffix) ||
			strings.Contains(suffix, opaqueEntityPlaceholder) || strings.Contains(suffix, legacyEntityPlaceholder) ||
			strings.Contains(suffix, "该目标") {
			return text[:loc[0]], suffix, true
		}
	}
	return "", "", false
}

func splitChineseMissingIDInvocationPrefix(text string) (prefix, held string, ok bool) {
	if opaqueChineseMissingIDColonPattern.MatchString(text) {
		// The colon form owns the inner "一个不存在但格式正确的 ID" phrase. Do not
		// split at that inner prefix after the outer rule has already seen the full value.
		// 冒号句式拥有内部「一个不存在但格式正确的 ID」短语；外层值已完整时不能再从内部前缀切开。
		return "", "", false
	}
	for _, loc := range opaqueChineseMissingIDInvocationStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if opaqueMatchHasBalancedQuotes(suffix, opaqueChineseMissingIDDirectCallPattern) ||
			opaqueMatchHasBalancedQuotes(suffix, opaqueChineseMissingIDInvocationPattern) {
			continue
		}
		trimmed := strings.TrimSpace(suffix)
		if strings.HasSuffix(trimmed, "不存在但格式正确的") || strings.HasSuffix(trimmed, "ID") ||
			strings.Contains(suffix, "`") || strings.Contains(suffix, "\"") || entityIDPattern.MatchString(suffix) ||
			strings.Contains(suffix, opaqueEntityPlaceholder) || strings.Contains(suffix, legacyEntityPlaceholder) ||
			strings.Contains(suffix, "该目标") {
			return text[:loc[0]], suffix, true
		}
	}
	return "", "", false
}

func splitChineseFoundActualIDPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseFoundActualIDStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if opaqueMatchHasBalancedQuotes(suffix, opaqueChineseFoundActualIDPattern) {
			continue
		}
		trimmed := strings.TrimSpace(suffix)
		if strings.HasSuffix(trimmed, "找到实际存在的") || strings.Contains(suffix, "`") ||
			strings.Contains(suffix, "\"") || entityIDPattern.MatchString(suffix) ||
			strings.Contains(suffix, opaqueEntityPlaceholder) || strings.Contains(suffix, legacyEntityPlaceholder) ||
			strings.Contains(suffix, "该目标") {
			return text[:loc[0]], suffix, true
		}
	}
	return "", "", false
}

func splitChineseCorrectFunctionIDAfterPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseCorrectFunctionIDAfterStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if match := opaqueChineseCorrectFunctionIDAfterPattern.FindStringIndex(suffix); match != nil &&
			opaqueMatchHasBalancedQuotes(suffix, opaqueChineseCorrectFunctionIDAfterPattern) {
			if strings.TrimSpace(suffix[match[1]:]) == "" {
				return text[:loc[0]], suffix, true
			}
			continue
		}
		trimmed := strings.TrimSpace(suffix)
		if strings.HasPrefix(trimmed, "拿到正确的") || strings.Contains(suffix, "`") ||
			strings.Contains(suffix, `"`) || entityIDPattern.MatchString(suffix) ||
			strings.Contains(suffix, opaqueEntityPlaceholder) || strings.Contains(suffix, legacyEntityPlaceholder) ||
			strings.Contains(suffix, "该目标") {
			return text[:loc[0]], suffix, true
		}
	}
	return "", "", false
}

func splitChineseIDLookupFunctionPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseIDLookupFunctionStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if match := opaqueChineseIDLookupFunctionPattern.FindStringIndex(suffix); match != nil &&
			opaqueMatchHasBalancedQuotes(suffix, opaqueChineseIDLookupFunctionPattern) {
			if strings.TrimSpace(suffix[match[1]:]) == "" {
				return text[:loc[0]], suffix, true
			}
			continue
		}
		trimmed := strings.TrimSpace(suffix)
		if strings.HasPrefix(trimmed, "根据") || strings.Contains(suffix, "该 ID") ||
			strings.Contains(suffix, "这个 ID") || strings.Contains(suffix, opaqueEntityPlaceholder) ||
			strings.Contains(suffix, legacyEntityPlaceholder) || strings.Contains(suffix, "该目标") {
			return text[:loc[0]], suffix, true
		}
	}
	return "", "", false
}

func splitChineseIDFunctionNotCreatedPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseIDFunctionNotCreatedStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if len([]rune(suffix)) > 256 {
			continue
		}
		if opaqueChineseIDFunctionNotCreatedPattern.MatchString(suffix) {
			continue
		}
		trimmed := strings.TrimSpace(suffix)
		if strings.HasSuffix(trimmed, "ID") || strings.Contains(suffix, "对应的函数") || strings.Contains(suffix, "该目标") {
			return text[:loc[0]], suffix, true
		}
	}
	return "", "", false
}

func splitChineseFunctionIDNaturalRequirementPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseFunctionIDNaturalRequirementStartPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if strings.Contains(suffix, "\n") || len([]rune(suffix)) > 256 {
			continue
		}
		if opaqueChineseFunctionIDNaturalRequirementPattern.MatchString(suffix) {
			continue
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitChineseFabricatedIDExplanationPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseFabricatedIDExplanationPrefixPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if !opaqueChineseFabricatedIDExplanationContextPattern.MatchString(text[:loc[0]]) {
			continue
		}
		if opaqueMatchHasBalancedQuotes(suffix, opaqueChineseFabricatedIDExplanationPattern) {
			continue
		}
		if strings.Contains(suffix, "\n") || len([]rune(suffix)) > 256 {
			continue
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitChineseMissingIDLabelPrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseMissingIDLabelPrefixPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if strings.Contains(suffix, "\n") || len([]rune(suffix)) > 256 {
			continue
		}
		if opaqueChineseMissingIDLabelPattern.MatchString(suffix) || opaqueChineseMissingIDLabelInSentencePattern.MatchString(suffix) {
			continue
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitChineseIDReferencePrefix(text string) (prefix, held string, ok bool) {
	for _, loc := range opaqueChineseIDReferencePrefixPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if strings.Contains(suffix, "\n") || len([]rune(suffix)) > 256 {
			continue
		}
		if opaqueChineseIDReferencePattern.MatchString(suffix) {
			continue
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitEnglishFoundPlaceholderPrefix(text string) (prefix, held string, ok bool) {
	if loc := opaqueEnglishFoundOpenPrefixPattern.FindStringIndex(text); loc != nil {
		suffix := text[loc[0]:]
		if !strings.Contains(suffix, "\n") && len([]rune(suffix)) <= 256 {
			return text[:loc[0]], suffix, true
		}
	}
	for _, loc := range opaqueEnglishFoundPlaceholderPrefixPattern.FindAllStringIndex(text, -1) {
		suffix := text[loc[0]:]
		if strings.Contains(suffix, "\n") || len([]rune(suffix)) > 256 {
			continue
		}
		if opaqueEnglishFoundPlaceholderPattern.MatchString(suffix) {
			continue
		}
		return text[:loc[0]], suffix, true
	}
	return "", "", false
}

func splitMediaAttachmentAssignmentPrefix(text string) (prefix, held string, ok bool) {
	for _, pair := range []struct {
		prefix *regexp.Regexp
		full   *regexp.Regexp
	}{
		{prefix: opaqueAttachmentIDAssignmentPrefixPattern, full: opaqueAttachmentIDAssignmentPattern},
		{prefix: opaqueMediaAttachmentAssignmentPrefixPattern, full: opaqueMediaAttachmentAssignmentPattern},
	} {
		for _, loc := range pair.prefix.FindAllStringIndex(text, -1) {
			suffix := text[loc[0]:]
			if strings.Contains(suffix, "\n") || len([]rune(suffix)) > 256 {
				continue
			}
			if match := pair.full.FindStringIndex(suffix); match != nil {
				// The ID regex deliberately accepts opaque values of different lengths. If
				// the match reaches the buffer end on a token character, it may still be a
				// provider-split suffix rather than a complete value; wait for a delimiter.
				tail := suffix[match[1]:]
				if !strings.ContainsAny(tail, " \t\r\n") {
					last, _ := utf8.DecodeLastRuneInString(suffix)
					if match[1] == len(suffix) || !isTokenContinuation(last) || strings.ContainsAny(tail, ".,;:!?)]}\"'") {
						return text[:loc[0]], suffix, true
					}
				}
				continue
			}
			return text[:loc[0]], suffix, true
		}
	}
	return "", "", false
}

func splitSearchBlocksSummaryPrefix(text string) (prefix, held string, ok bool) {
	lineStart := strings.LastIndexByte(text, '\n') + 1
	line := text[lineStart:]
	if line == "" || len([]rune(line)) > 512 {
		return "", "", false
	}
	if !searchBlocksSummaryLinePattern.MatchString(line) &&
		!searchBlocksSummaryBoldBulletPrefixPattern.MatchString(line) &&
		!searchBlocksSummaryBulletOpeningPattern.MatchString(line) {
		return "", "", false
	}
	return text[:lineStart], line, true
}

func splitRelationPrefix(text string) (prefix, held string, ok bool) {
	lineStart := strings.LastIndexByte(text, '\n') + 1
	line := text[lineStart:]
	if len([]rune(line)) > 1024 {
		return "", "", false
	}
	if edgeStart := strings.LastIndex(strings.ToLower(text), "edge "); edgeStart >= 0 {
		edgeLineStart := strings.LastIndexByte(text[:edgeStart], '\n') + 1
		edgeSuffix := text[edgeLineStart:]
		if len([]rune(edgeSuffix)) <= 1024 {
			if newline := strings.IndexByte(edgeSuffix, '\n'); newline >= 0 {
				end := edgeLineStart + newline + 1
				return text[:end], text[end:], true
			}
			return text[:edgeLineStart], edgeSuffix, true
		}
	}
	if strings.Contains(text, "| 字段 | 值 |") && strings.HasPrefix(strings.TrimSpace(line), "|") {
		return text[:lineStart], line, true
	}
	relationFieldRowPresent := false
	for _, candidate := range strings.Split(text, "\n") {
		if isRelationFieldTableRow(candidate) {
			relationFieldRowPresent = true
			break
		}
	}
	if isRelationFieldTableRow(line) {
		return text[:lineStart], line, true
	}
	if relationFieldRowPresent && strings.HasSuffix(text, "\n") {
		lines := strings.Split(strings.TrimSuffix(text, "\n"), "\n")
		if len(lines) > 0 && isRelationFieldTableRow(lines[len(lines)-1]) {
			return "", text, true
		}
	}
	if introStart := strings.Index(strings.ToLower(text), "get_relations"); introStart >= 0 {
		intro := text[introStart:]
		if !strings.Contains(intro, "在 depth") && len([]rune(intro)) <= 1024 {
			return text[:introStart], intro, true
		}
	}
	if introStart := strings.LastIndex(text, "以下是"); introStart >= 0 {
		intro := text[introStart:]
		if !strings.Contains(intro, "关系边") && !strings.Contains(strings.ToLower(intro), "relationship edges") && len([]rune(intro)) <= 1024 {
			return text[:introStart], intro, true
		}
	}
	for _, marker := range []string{"关系 id", "relation id"} {
		if markerStart := strings.LastIndex(strings.ToLower(text), marker); markerStart >= 0 {
			lineStart := strings.LastIndexByte(text[:markerStart], '\n') + 1
			suffix := text[lineStart:]
			if len([]rune(suffix)) <= 1024 && !strings.HasSuffix(suffix, "\n") {
				return text[:lineStart], suffix, true
			}
		}
	}
	trimmed := strings.TrimSpace(line)
	if strings.HasPrefix(trimmed, "|") && (strings.Contains(line, "边 ID") || strings.Contains(line, "起点引用") || strings.Contains(line, "终点引用") || strings.Contains(line, "创建时间") || strings.Contains(line, "更新时间")) {
		return text[:lineStart], line, true
	}
	if !relationFieldRowPresent {
		for _, field := range []string{"fromId", "toId", "edgeId", "from ID", "to ID", "edge ID", "边 ID", "创建时间", "创建/更新时间"} {
			if fieldStart := strings.LastIndex(strings.ToLower(text), strings.ToLower(field)); fieldStart >= 0 {
				suffix := text[fieldStart:]
				lowerSuffix := strings.ToLower(suffix)
				isTimeField := strings.Contains(field, "创建")
				if (isTimeField && (strings.Contains(suffix, ":") || strings.Contains(suffix, "：") || strings.Contains(suffix, "均为") || strings.Contains(suffix, "为")) && !strings.Contains(suffix, opaqueTimestampPlaceholder)) ||
					(!isTimeField && !strings.Contains(suffix, "\n") && strings.Contains(suffix, "=")) ||
					(strings.Contains(suffix, opaqueEntityPlaceholder) &&
						(!strings.Contains(suffix, "）") && !strings.Contains(suffix, ")") ||
							((strings.Contains(lowerSuffix, "创建时间") || strings.Contains(lowerSuffix, "创建/更新时间")) && !strings.Contains(suffix, opaqueTimestampPlaceholder)))) {
					holdStart := fieldStart
					if previous, size := utf8.DecodeLastRuneInString(text[:fieldStart]); strings.ContainsRune("（(,，;；", previous) {
						holdStart -= size
					}
					return text[:holdStart], text[holdStart:], true
				}
			}
		}
	}
	if line == "" {
		return "", "", false
	}
	lowerLine := strings.ToLower(line)
	isSummary := strings.HasPrefix(trimmed, "以下是") || strings.HasPrefix(lowerLine, "here are") || strings.HasPrefix(lowerLine, "these are") || strings.Contains(line, "关系边") || strings.Contains(lowerLine, "relationship edges")
	isRelationTable := strings.Contains(text, "端点") && (strings.Contains(text, "引用") || strings.Contains(lowerLine, "reference"))
	isTable := strings.HasPrefix(trimmed, "|") &&
		(strings.Contains(line, "端点") || strings.Contains(lowerLine, "endpoint") || strings.Contains(line, "引用") || strings.Contains(lowerLine, "reference") || isRelationTable)
	if !isSummary && !isTable {
		return "", "", false
	}
	return text[:lineStart], line, true
}

func splitToolNamePrefix(text string) (prefix, held string, ok bool) {
	const phrase = "get_flowrun"
	lower := strings.ToLower(text)
	for start := len(text) - 1; start >= 0; start-- {
		suffix := lower[start:]
		if len(suffix) >= len(phrase) || !strings.HasPrefix(phrase, suffix) {
			continue
		}
		// Only hold a partial tool name at a token boundary. Without this guard, the
		// suffix "ge" in an ordinary word such as "lastMessage" is mistaken for the
		// beginning of "get_flowrun", and the preceding table header is emitted early.
		if start > 0 {
			previous, _ := utf8.DecodeLastRuneInString(text[:start])
			if isTokenContinuation(previous) {
				continue
			}
		}
		holdStart := start
		if holdStart > 0 && text[holdStart-1] == '`' {
			holdStart--
		}
		return text[:holdStart], text[holdStart:], true
	}
	return "", "", false
}

func splitAttachmentTimestampTablePrefix(text string) (prefix, held string, ok bool) {
	lines := strings.SplitAfter(text, "\n")
	offset := 0
	for i := 0; i+1 < len(lines); i++ {
		headerLine := strings.TrimSuffix(lines[i], "\n")
		separatorLine := strings.TrimSuffix(lines[i+1], "\n")
		header, headerOK := markdownTableCells(headerLine)
		separator, separatorOK := markdownTableCells(separatorLine)
		if !headerOK || !separatorOK || len(separator) != len(header) || !isMarkdownTableSeparator(separator) {
			offset += len(lines[i])
			continue
		}

		timestampColumn := -1
		for column, cell := range header {
			label := strings.ToLower(strings.Trim(strings.TrimSpace(cell), "`*_ "))
			if label == "uploaded" || label == "upload time" || label == "uploaded at" || label == "created at" || label == "createdat" {
				timestampColumn = column
				break
			}
		}
		if timestampColumn < 0 {
			offset += len(lines[i])
			continue
		}

		row := i + 2
		rowEnd := row
		for rowEnd < len(lines) {
			candidate := strings.TrimSuffix(lines[rowEnd], "\n")
			cells, rowOK := markdownTableCells(candidate)
			if !rowOK || len(cells) != len(header) {
				break
			}
			rowEnd++
		}
		if rowEnd == row {
			return "", text, true
		}

		prefixEnd := 0
		for j := 0; j < rowEnd; j++ {
			prefixEnd += len(lines[j])
		}
		if prefixEnd == len(text) {
			return "", text, true
		}
		return text[:prefixEnd], text[prefixEnd:], true
	}
	return "", "", false
}

func splitActivationDetailTablePrefix(text string) (prefix, held string, ok bool) {
	lines := strings.SplitAfter(text, "\n")
	lineCount := len(lines)
	if lineCount > 0 && lines[lineCount-1] == "" {
		// SplitAfter represents a trailing delimiter as an empty sentinel. It is not a
		// table boundary; the next provider chunk may still contain another row.
		lineCount--
	}
	for i := 0; i+1 < len(lines); i++ {
		headerLine := strings.TrimSuffix(lines[i], "\n")
		separatorLine := strings.TrimSuffix(lines[i+1], "\n")
		header, headerOK := markdownTableCells(headerLine)
		separator, separatorOK := markdownTableCells(separatorLine)
		if headerOK && len(header) == 2 && isFieldValueTableHeader(header) &&
			(!separatorOK || len(separator) != 2 || !isMarkdownTableSeparator(separator)) &&
			i+1 == lineCount-1 && strings.HasPrefix(strings.TrimSpace(separatorLine), "|") {
			// The provider can split the separator itself. Keep the Field/Value header
			// attached to that partial line; otherwise the generic line streamer emits
			// the header before activation context can be recognized.
			prefixEnd := 0
			for j := 0; j < i; j++ {
				prefixEnd += len(lines[j])
			}
			return text[:prefixEnd], text[prefixEnd:], true
		}
		if !headerOK || !separatorOK || len(header) != 2 || len(separator) != 2 || !isMarkdownTableSeparator(separator) {
			continue
		}
		if !isFieldValueTableHeader(header) {
			continue
		}

		// Keep the whole Field/Value table together until its row boundary is known. The
		// activation-specific rows arrive one provider chunk at a time in the real gateway;
		// releasing the header or the first row early loses the context needed to rewrite an
		// unavailable triggerId/createdAt cell before it reaches the live messages stream.
		rowEnd := i + 2
		hasID, hasKind, hasFired, hasTriggerID, hasCreatedAt := false, false, false, false, false
		for rowEnd < lineCount {
			candidate := strings.TrimSuffix(lines[rowEnd], "\n")
			cells, rowOK := markdownTableCells(candidate)
			if !rowOK || len(cells) != 2 {
				break
			}
			switch normalizeActivationFieldLabel(cells[0]) {
			case "id", "identifier", "activation id", "activation identifier":
				hasID = true
			case "kind":
				hasKind = true
			case "fired":
				hasFired = true
			case "trigger id", "trigger identifier", "触发器 id", "触发器标识":
				hasTriggerID = true
			case "created at", "created time", "creation time", "创建时间":
				hasCreatedAt = true
			}
			rowEnd++
		}
		activationCandidate := hasID || hasKind || hasFired || hasTriggerID || hasCreatedAt
		activationSignature := hasKind && hasFired && (hasTriggerID || hasCreatedAt)
		if rowEnd < lineCount && strings.HasPrefix(strings.TrimSpace(lines[rowEnd]), "|") &&
			!strings.HasSuffix(lines[rowEnd], "\n") {
			// The first data row can begin in the same provider chunk that completes
			// the separator. Keep the header and separator attached to that partial row.
			return "", text, true
		}
		if rowEnd == i+2 {
			if rowEnd == lineCount {
				return "", text, true
			}
			continue
		}
		if rowEnd == lineCount {
			return "", text, true
		}
		if activationCandidate && !activationSignature {
			nextLine := strings.TrimSpace(lines[rowEnd])
			if hasTriggerID || hasCreatedAt || strings.HasPrefix(nextLine, "|") {
				return "", text, true
			}
			// A plain Field/Value table with only an ID row has reached a real
			// non-table boundary; release it normally rather than stalling an
			// unrelated table forever.
		}
		prefixEnd := 0
		for j := 0; j < rowEnd; j++ {
			prefixEnd += len(lines[j])
		}
		if prefixEnd == len(text) {
			return "", text, true
		}
		return text[:prefixEnd], text[prefixEnd:], true
	}
	return "", "", false
}

func splitFieldValueTableHeaderPrefix(text string) (prefix, held string, ok bool) {
	if text == "" || !strings.HasSuffix(text, "\n") {
		return "", "", false
	}
	lineEnd := len(text) - 1
	lineStart := strings.LastIndexByte(text[:lineEnd], '\n') + 1
	line := text[lineStart:lineEnd]
	if line == "" {
		return "", "", false
	}
	header, headerOK := markdownTableCells(line)
	if !headerOK || !isFieldValueTableHeader(header) {
		return "", "", false
	}
	return text[:lineStart], text[lineStart:], true
}

func isFieldValueTableHeader(cells []string) bool {
	if len(cells) != 2 {
		return false
	}
	headerKey := normalizeActivationFieldLabel(cells[0])
	if headerKey != "field" && headerKey != "字段" && headerKey != "key" {
		return false
	}
	headerValue := normalizeActivationFieldLabel(cells[1])
	return headerValue == "value" || headerValue == "值"
}

func splitMCPConnectionTimestampTablePrefix(text string) (prefix, held string, ok bool) {
	lines := strings.SplitAfter(text, "\n")
	for i := 0; i+1 < len(lines); i++ {
		headerLine := strings.TrimSuffix(lines[i], "\n")
		separatorLine := strings.TrimSuffix(lines[i+1], "\n")
		header, headerOK := markdownTableCells(headerLine)
		separator, separatorOK := markdownTableCells(separatorLine)
		if !headerOK || !separatorOK || len(separator) != len(header) || !isMarkdownTableSeparator(separator) {
			continue
		}

		timestampColumn := -1
		for column, cell := range header {
			label := strings.ToLower(strings.Trim(strings.TrimSpace(cell), "`*_ "))
			if label == "connected at" || label == "connectedat" || label == "connection time" || label == "reconnected at" {
				timestampColumn = column
				break
			}
		}
		if timestampColumn < 0 {
			continue
		}

		row := i + 2
		rowEnd := row
		for rowEnd < len(lines) {
			candidate := strings.TrimSuffix(lines[rowEnd], "\n")
			cells, rowOK := markdownTableCells(candidate)
			if !rowOK || len(cells) != len(header) {
				break
			}
			rowEnd++
		}
		if rowEnd == row {
			return "", text, true
		}

		prefixEnd := 0
		for j := 0; j < rowEnd; j++ {
			prefixEnd += len(lines[j])
		}
		if prefixEnd == len(text) {
			return "", text, true
		}
		return text[:prefixEnd], text[prefixEnd:], true
	}
	return "", "", false
}

func splitMCPConnectionTimestampLabelPrefix(text string) (prefix, held string, ok bool) {
	lineStart := strings.LastIndexByte(text, '\n') + 1
	line := text[lineStart:]
	if line == "" || len([]rune(line)) > 512 {
		return "", "", false
	}
	lower := strings.ToLower(line)
	// A Markdown label can be split before its final character (for example,
	// "**Connected a" + "t:** ..."). Hold a plausible label prefix before the
	// generic token flusher gets a chance to emit the partial line.
	if !strings.Contains(line, "\n") && hasMCPConnectionTimestampLabelPrefix(line) {
		return text[:lineStart], line, true
	}
	if !strings.Contains(lower, "connected at") && !strings.Contains(lower, "connectedat") &&
		!strings.Contains(lower, "connection time") && !strings.Contains(lower, "reconnected at") {
		return "", "", false
	}
	if !strings.ContainsAny(line, ":|") {
		return "", "", false
	}
	if newline := strings.IndexByte(line, '\n'); newline >= 0 {
		return text[:lineStart+newline+1], text[lineStart+newline+1:], true
	}
	return text[:lineStart], line, true
}

func splitLastMessageAtFieldPrefix(text string) (prefix, held string, ok bool) {
	lineStart := strings.LastIndexByte(text, '\n') + 1
	line := text[lineStart:]
	if line == "" || len([]rune(line)) > 512 {
		return "", "", false
	}
	lower := strings.ToLower(line)
	if !strings.Contains(lower, "lastmessageat") && !strings.Contains(lower, "last message at") {
		return "", "", false
	}
	if !strings.ContainsAny(line, ":|=") {
		return "", "", false
	}
	if newline := strings.IndexByte(line, '\n'); newline >= 0 {
		return text[:lineStart+newline+1], text[lineStart+newline+1:], true
	}
	return text[:lineStart], line, true
}

func splitLastMessageAtTablePrefix(text string) (prefix, held string, ok bool) {
	lines := strings.SplitAfter(text, "\n")
	offset := 0
	for i := 0; i < len(lines); i++ {
		headerLine := strings.TrimSuffix(lines[i], "\n")
		header, headerOK := markdownTableCells(headerLine)
		if !headerOK {
			offset += len(lines[i])
			continue
		}

		lastMessageAtColumn := -1
		potentialLastMessageAtColumn := -1
		for column, cell := range header {
			label := strings.ToLower(strings.Trim(strings.TrimSpace(cell), "`*_ "))
			label = strings.ReplaceAll(label, " ", "")
			if label == "lastmessageat" {
				lastMessageAtColumn = column
				break
			}
			if column == len(header)-1 && len(label) >= 4 && strings.HasPrefix("lastmessageat", label) {
				potentialLastMessageAtColumn = column
			}
		}
		if lastMessageAtColumn < 0 {
			if potentialLastMessageAtColumn >= 0 {
				// The provider can split the header itself ("lastMessage" + "At"). Hold the
				// possible table until the next line distinguishes a real lastMessageAt column
				// from an ordinary header such as "last". Without this, the header and separator
				// escape before the timestamp-bearing rows arrive.
				if i+1 >= len(lines) {
					return text[:offset], text[offset:], true
				}
				separator, separatorOK := markdownTableCells(strings.TrimSuffix(lines[i+1], "\n"))
				if !separatorOK || len(separator) != len(header) || !isMarkdownTableSeparator(separator) {
					return text[:offset], text[offset:], true
				}
			}
			offset += len(lines[i])
			continue
		}
		// Keep a recognized lastMessageAt header attached to its unfinished separator. Without this
		// branch, a provider split after the header's newline emits the header first, then loses the
		// column context before the timestamp row arrives.
		if i+1 >= len(lines) {
			return text[:offset], text[offset:], true
		}
		separatorLine := strings.TrimSuffix(lines[i+1], "\n")
		separator, separatorOK := markdownTableCells(separatorLine)
		if !separatorOK || len(separator) != len(header) || !isMarkdownTableSeparator(separator) {
			return text[:offset], text[offset:], true
		}

		row := i + 2
		rowEnd := row
		for rowEnd < len(lines) {
			candidate := strings.TrimSuffix(lines[rowEnd], "\n")
			cells, rowOK := markdownTableCells(candidate)
			if !rowOK || len(cells) != len(header) {
				trimmed := strings.TrimSpace(candidate)
				if rowEnd == len(lines)-1 && strings.HasPrefix(trimmed, "|") &&
					!strings.HasSuffix(lines[rowEnd], "\n") {
					// A provider may start the next row in a separate delta ("| Alpha"). Keep the
					// entire table until that row closes; otherwise later cells lose the header context.
					return text[:offset], text[offset:], true
				}
				break
			}
			if rowEnd == len(lines)-1 && !strings.HasSuffix(lines[rowEnd], "\n") &&
				strings.TrimSpace(cells[lastMessageAtColumn]) == "" {
				// A provider can finish the title cell and its delimiter before it starts the
				// timestamp cell ("| Alpha planning |"). It has the right cell count but is not
				// a complete row; releasing it would redact the timestamp in the next delta.
				return text[:offset], text[offset:], true
			}
			rowEnd++
		}
		if rowEnd == row {
			return "", text, true
		}

		prefixEnd := 0
		for j := 0; j < rowEnd; j++ {
			prefixEnd += len(lines[j])
		}
		if prefixEnd == len(text) {
			return "", text, true
		}
		return text[:prefixEnd], text[prefixEnd:], true
	}
	return "", "", false
}

func splitNextFireAtFieldPrefix(text string) (prefix, held string, ok bool) {
	lineStart := strings.LastIndexByte(text, '\n') + 1
	line := text[lineStart:]
	if line == "" || len([]rune(line)) > 512 {
		return "", "", false
	}
	if !nextFireAtFieldPattern.MatchString(line) &&
		!strings.Contains(strings.ToLower(line), "nextfireat") &&
		!strings.Contains(line, "下次触发时间") {
		return "", "", false
	}
	if !strings.ContainsAny(line, ":：|=") {
		return "", "", false
	}
	if newline := strings.IndexByte(line, '\n'); newline >= 0 {
		return text[:lineStart+newline+1], text[lineStart+newline+1:], true
	}
	return text[:lineStart], line, true
}

func splitNextFireAtTablePrefix(text string) (prefix, held string, ok bool) {
	lines := strings.SplitAfter(text, "\n")
	offset := 0
	for _, raw := range lines {
		line := strings.TrimSuffix(raw, "\n")
		cells, rowOK := markdownTableCells(line)
		if rowOK && len(cells) >= 2 && explicitNextFireLabel(cells[0]) && !strings.HasSuffix(raw, "\n") {
			return text[:offset], text[offset:], true
		}
		offset += len(raw)
	}
	return "", "", false
}

func hasMCPConnectionTimestampLabelPrefix(line string) bool {
	normalized := strings.ToLower(strings.TrimSpace(strings.TrimLeft(line, "-•*_` \t")))
	for _, prefix := range []string{"connected", "connection", "reconnected"} {
		if strings.HasPrefix(normalized, prefix) {
			return true
		}
	}
	return false
}

func splitStructuredLinePrefix(text string) (prefix, held string, ok bool) {
	if newline := strings.LastIndexByte(text, '\n'); newline >= 0 {
		completed := text[:newline+1]
		offset := 0
		for _, line := range strings.SplitAfter(completed, "\n") {
			if isDanglingDossierTableLine(strings.TrimSuffix(line, "\n")) {
				return text[:offset], text[offset:], true
			}
			offset += len(line)
		}
		for _, line := range strings.Split(completed, "\n") {
			if opaquePlaceholderLabeledLinePattern.MatchString(line) ||
				opaquePlaceholderBoldColonLabeledLinePattern.MatchString(line) ||
				opaqueVersionIDPlaceholderLinePattern.MatchString(line) ||
				opaqueChineseAuditMachineFieldPattern.MatchString(line) ||
				opaqueChineseAuditBoldColonMachineFieldPattern.MatchString(line) ||
				opaqueEnglishDossierErrorFieldPattern.MatchString(line) ||
				opaqueActivationIntroLinePattern.MatchString(line) ||
				opaqueTriggerIDPlaceholderLinePattern.MatchString(line) ||
				isSkillVerbatimClaimLine(line) ||
				hasSkillContextLinePrefix(line) ||
				hasTriggerIDLinePrefix(line) ||
				hasActivationTimestampLinePrefix(line) {
				return completed, text[newline+1:], true
			}
		}
	}
	lineStart := strings.LastIndexByte(text, '\n') + 1
	line := text[lineStart:]
	if line == "" || len([]rune(line)) > 512 {
		return "", "", false
	}
	if hasOpaquePlaceholderLabeledPrefix(line) || hasChineseAuditMachineFieldPrefix(line) || hasEnglishDossierMachineFieldPrefix(line) || hasOpaqueActivationIntroPrefix(line) || isSkillVerbatimClaimLine(line) || hasSkillContextLinePrefix(line) || hasTriggerIDLinePrefix(line) || hasActivationTimestampLinePrefix(line) {
		return text[:lineStart], line, true
	}
	lower := strings.ToLower(line)
	hasTable := strings.Contains(line, "|")
	isPositionLine := positionLinePrefixPattern.MatchString(line)
	isFlowrunStatusLine := opaqueFlowrunStatusLinePattern.MatchString(line) && strings.Contains(lower, opaqueEntityPlaceholder)
	isWebhookEndpointLine := strings.Contains(lower, "/api/v1/webhooks/")
	if !hasTable && !strings.Contains(line, "`") &&
		!isFlowrunStatusLine &&
		!isWebhookEndpointLine &&
		!strings.Contains(lower, opaqueEntityPlaceholder) &&
		!strings.Contains(lower, legacyEntityPlaceholder) &&
		!strings.Contains(lower, "flowrun report") &&
		!strings.Contains(lower, "flowrun id") &&
		!strings.Contains(lower, "workflow run") &&
		!strings.Contains(lower, "call to") &&
		!strings.Contains(lower, "does not correspond") &&
		!strings.Contains(lower, "fr_") &&
		!strings.Contains(lower, "wfv_") &&
		!strings.Contains(lower, "apf_") &&
		!strings.Contains(lower, "apfv_") &&
		!strings.Contains(lower, "fnv_") {
		return "", "", false
	}
	if !hasTable &&
		!isPositionLine &&
		!isFlowrunStatusLine &&
		!isWebhookEndpointLine &&
		!strings.Contains(lower, "flowrun report") &&
		!strings.Contains(lower, "flowrun overview") &&
		!strings.Contains(lower, "flowrun id") &&
		!strings.Contains(lower, "get_flowrun") &&
		!strings.Contains(lower, "call to") &&
		!strings.Contains(lower, "workflow run") &&
		!strings.Contains(lower, "does not correspond") &&
		!strings.Contains(lower, "pinned refs") &&
		!strings.Contains(lower, "approval form") &&
		!strings.Contains(lower, "fr_") &&
		!strings.Contains(lower, "fnv_") &&
		!strings.HasPrefix(strings.TrimSpace(lower), "- id:") &&
		!strings.HasPrefix(strings.TrimSpace(lower), "- version:") &&
		!strings.Contains(lower, opaqueEntityPlaceholder) &&
		!strings.Contains(lower, legacyEntityPlaceholder) {
		if !(strings.HasPrefix(strings.TrimSpace(lower), "-") && (strings.Contains(line, "->") || strings.Contains(line, "→"))) {
			return "", "", false
		}
	}
	return text[:lineStart], line, true
}

func splitExecutionDossierBulletPrefix(text string) (prefix, held string, ok bool) {
	lineStart := strings.LastIndexByte(text, '\n') + 1
	line := text[lineStart:]
	if line == "" || strings.Contains(line, "\n") || len([]rune(line)) > 512 {
		return "", "", false
	}
	trimmed := strings.TrimLeft(line, " \t")
	if !strings.HasPrefix(trimmed, "- **") && !strings.HasPrefix(trimmed, "- __") &&
		!strings.HasPrefix(trimmed, "* **") && !strings.HasPrefix(trimmed, "* __") {
		return "", "", false
	}
	return text[:lineStart], line, true
}

func splitExecutionDossierTableFragmentPrefix(text string) (prefix, held string, ok bool) {
	lineStart := strings.LastIndexByte(text, '\n') + 1
	line := text[lineStart:]
	if line == "" || strings.Contains(line, "\n") || len([]rune(line)) > 512 {
		return "", "", false
	}
	trimmed := strings.TrimLeft(line, " \t")
	if (strings.HasPrefix(trimmed, "| **") || strings.HasPrefix(trimmed, "| __")) &&
		strings.Count(trimmed, "|") < 2 {
		return text[:lineStart], line, true
	}
	return "", "", false
}

func isDanglingDossierTableLine(line string) bool {
	trimmed := strings.TrimSpace(line)
	if !strings.HasPrefix(trimmed, "|") {
		return false
	}
	fragment := strings.TrimSpace(strings.TrimPrefix(trimmed, "|"))
	fragment = strings.Trim(fragment, "*_` ")
	return strings.EqualFold(fragment, "记录") || strings.EqualFold(fragment, "record")
}

func hasSkillContextLinePrefix(line string) bool {
	trimmed := strings.TrimSpace(strings.TrimLeft(line, "-*•_` \t"))
	colon := strings.IndexAny(trimmed, ":：")
	if colon < 0 {
		return false
	}
	label := strings.ToLower(strings.Trim(strings.TrimSpace(trimmed[:colon]), "`*_ "))
	label = strings.ReplaceAll(label, " ", "")
	switch label {
	case "session", "sessionid", "directory", "dir", "path", "cwd", "claude_skill_dir", "skill_dir", "会话", "会话id", "目录", "路径":
		return true
	default:
		return false
	}
}

func hasTriggerIDLinePrefix(line string) bool {
	trimmed := strings.TrimSpace(strings.TrimLeft(line, "-*•_` \t"))
	trimmed = strings.TrimLeft(trimmed, "*_")
	if colon := strings.IndexAny(trimmed, ":："); colon >= 0 && normalizeActivationFieldLabel(trimmed[:colon]) == "trigger id" {
		return true
	}
	return strings.HasPrefix(trimmed, "触发器")
}

func hasActivationTimestampLinePrefix(line string) bool {
	trimmed := strings.TrimSpace(strings.TrimLeft(line, "-*•_` \t"))
	colon := strings.IndexAny(trimmed, ":：")
	if colon < 0 {
		return false
	}
	switch normalizeActivationFieldLabel(trimmed[:colon]) {
	case "created at", "created time", "creation time":
		return true
	default:
		return false
	}
}

func hasOpaquePlaceholderLabeledPrefix(line string) bool {
	trimmedLine := strings.ToLower(strings.TrimSpace(line))
	for _, prefix := range []string{"**attachment id", "**attachment identifier", "**image id", "**image identifier", "**media id", "**media identifier", "attachment id", "attachment identifier", "image id", "image identifier", "media id", "media identifier"} {
		if strings.HasPrefix(prefix, trimmedLine) && trimmedLine != prefix {
			return true
		}
	}
	colon := strings.IndexByte(line, ':')
	if colon < 0 {
		return false
	}
	label := strings.Trim(strings.TrimSpace(line[:colon]), "`*_ ")
	label = strings.TrimSpace(strings.TrimLeft(label, "-*0123456789.) "))
	lowerLabel := strings.ToLower(label)
	isMediaLabel := lowerLabel == "attachment id" || lowerLabel == "attachment identifier" || lowerLabel == "image id" || lowerLabel == "image identifier" || lowerLabel == "media id" || lowerLabel == "media identifier"
	switch lowerLabel {
	case "id", "identifier", "version id", "version identifier", "path", "label", "name":
	default:
		if !isMediaLabel {
			return false
		}
	}
	value := strings.Trim(strings.TrimSpace(line[colon+1:]), "`*_ ")
	if isMediaLabel {
		return true
	}
	for _, phrase := range []string{opaqueEntityPlaceholder, legacyEntityPlaceholder} {
		if value != "" && len(value) < len(phrase) && strings.HasPrefix(phrase, strings.ToLower(value)) {
			return true
		}
	}
	return false
}

func hasChineseAuditMachineFieldPrefix(line string) bool {
	trimmed := strings.TrimSpace(strings.TrimLeft(line, "-*•_` \t"))
	colon := strings.IndexAny(trimmed, ":：")
	if colon < 0 {
		return false
	}
	label := strings.Trim(strings.TrimSpace(trimmed[:colon]), "`*_ ")
	return isChineseAuditMachineFieldLabel(label)
}

func hasEnglishDossierMachineFieldPrefix(line string) bool {
	trimmed := strings.TrimSpace(strings.TrimLeft(line, "-*•_` \t"))
	lower := strings.ToLower(trimmed)
	if lower == "" || len(lower) > len("errormsg") {
		return false
	}
	if strings.HasPrefix("errormsg", lower) {
		return true
	}
	return opaqueEnglishDossierErrorFieldPattern.MatchString(line)
}

func hasOpaqueActivationIntroPrefix(line string) bool {
	trimmed := strings.TrimSpace(line)
	lower := strings.ToLower(trimmed)
	if !(strings.HasPrefix(trimmed, "以下是") || strings.HasPrefix(lower, "here is") || strings.HasPrefix(lower, "this is")) {
		return false
	}
	return strings.Contains(lower, "tra_") || strings.Contains(lower, "act_")
}

func isChineseAuditMachineFieldLabel(label string) bool {
	value := strings.ToLower(strings.Trim(strings.TrimSpace(label), "`*_ "))
	if annotation := strings.IndexAny(value, "（("); annotation >= 0 {
		value = strings.TrimSpace(value[:annotation])
	}
	value = strings.ReplaceAll(value, " ", "")
	for _, field := range []string{
		"执行id", "版本id", "会话id", "消息id", "工具调用id", "节点id", "运行id",
		"函数id", "处理器id", "代理id", "工作流id", "触发器id", "对话id", "文档id",
		"技能id", "附件id", "开始时间", "结束时间", "创建时间", "记录创建时间", "更新时间",
	} {
		if value == field {
			return true
		}
	}
	return false
}

func redactChineseAuditTableRows(text string) string {
	lines := strings.Split(text, "\n")
	remove := make(map[int]bool)
	for index := 0; index+1 < len(lines); {
		header, headerOK := markdownTableCells(lines[index])
		separator, separatorOK := markdownTableCells(lines[index+1])
		if !headerOK || !separatorOK || len(header) != 2 || len(separator) != 2 ||
			!isFieldValueTableHeader(header) || !isMarkdownTableSeparator(separator) {
			index++
			continue
		}
		end := index + 2
		hasExecutionIdentity := false
		for end < len(lines) {
			cells, rowOK := markdownTableCells(lines[end])
			if !rowOK || len(cells) < 2 {
				break
			}
			if isChineseAuditIdentityFieldLabel(cells[0]) {
				hasExecutionIdentity = true
			}
			end++
		}
		if hasExecutionIdentity {
			for row := index + 2; row < end; row++ {
				cells, rowOK := markdownTableCells(lines[row])
				if rowOK && len(cells) >= 2 && isChineseAuditMachineFieldLabel(cells[0]) {
					remove[row] = true
				}
			}
		}
		index = end
	}
	kept := make([]string, 0, len(lines)-len(remove))
	for index, line := range lines {
		if !remove[index] {
			kept = append(kept, line)
		}
	}
	return strings.Join(kept, "\n")
}

func redactChineseDossierPlaceholderTableRows(text string) string {
	lines := strings.Split(text, "\n")
	kept := make([]string, 0, len(lines))
	for index, line := range lines {
		cells, ok := markdownTableCells(line)
		if !ok || len(cells) < 2 {
			kept = append(kept, line)
			continue
		}
		label := strings.ToLower(strings.Trim(strings.TrimSpace(cells[0]), "`*_ "))
		label = strings.ReplaceAll(label, " ", "")
		machineLabel := label == "版本" || label == "开始" || label == "结束" || label == "记录创建时间"
		// Execution dossiers commonly render identity fields as a two-column Markdown
		// table. Unlike ordinary prose, each row is independently safe to remove once its
		// value is unavailable; waiting for the full table would let a live delta leak it.
		// 执行审计档案常把身份字段写成两列表格。值不可用时逐行移除即可，不必等整张表，
		// 否则单个 live delta 会先把机器占位发给用户。
		if !machineLabel {
			switch label {
			case "执行id", "函数id", "版本id", "会话id", "对话id", "消息id", "工具调用id", "节点id", "运行id",
				"executionid", "functionid", "versionid":
				machineLabel = true
			}
		}
		if !machineLabel && (label == "开始时间" || label == "结束时间") {
			machineLabel = isChineseDossierTimelineRow(lines, index)
		}
		value := cells[1]
		badValue := strings.Contains(value, opaqueEntityPlaceholder) ||
			strings.Contains(value, legacyEntityPlaceholder) ||
			strings.Contains(value, opaqueTimestampPlaceholder) ||
			strings.Contains(value, opaqueTimestampChinesePlaceholder) ||
			entityIDPattern.MatchString(value)
		if machineLabel && badValue {
			continue
		}
		kept = append(kept, line)
	}
	return strings.Join(kept, "\n")
}

func isChineseDossierTimelineRow(lines []string, rowIndex int) bool {
	for index := rowIndex - 1; index >= 0 && rowIndex-index <= 12; index-- {
		trimmed := strings.TrimSpace(lines[index])
		lowerTrimmed := strings.ToLower(trimmed)
		if strings.Contains(trimmed, "计时") || strings.Contains(trimmed, "时间线") ||
			strings.Contains(trimmed, "时间信息") || strings.Contains(lowerTrimmed, "timing") {
			return true
		}
		if trimmed == "" {
			continue
		}
		cells, ok := markdownTableCells(lines[index])
		if !ok || len(cells) < 2 {
			continue
		}
		if isMarkdownTableSeparator(cells) {
			continue
		}
		header := strings.ToLower(strings.Trim(strings.TrimSpace(cells[0]), "`*_ "))
		header = strings.ReplaceAll(header, " ", "")
		if header == "时间点" {
			return true
		}
	}
	return false
}

func redactChineseDossierPointerTableRows(text string) string {
	lines := strings.Split(text, "\n")
	lowerText := strings.ToLower(text)
	executionDossier := strings.Contains(text, "执行审计档案") ||
		strings.Contains(text, "完整执行档案") ||
		strings.Contains(lowerText, "execution audit dossier") ||
		strings.Contains(lowerText, "tool-call details")
	for index, line := range lines {
		cells, ok := markdownTableCells(line)
		if !ok || len(cells) < 2 {
			continue
		}
		label := strings.ToLower(strings.Trim(strings.TrimSpace(cells[0]), "`*_ "))
		label = strings.ReplaceAll(label, " ", "")
		var hint string
		var humanLabel string
		switch label {
		case "消息":
			hint = "See the exact message in the execution card."
		case "工具调用":
			hint = "See the exact tool call in the execution card."
		case "conversationid", "conversationidentifier":
			if !executionDossier {
				continue
			}
			hint = "See the exact conversation in the execution card."
			humanLabel = "Conversation"
		case "messageid", "messageidentifier":
			if !executionDossier {
				continue
			}
			hint = "See the exact message in the execution card."
			humanLabel = "Message"
		case "toolcallid", "toolcallidentifier":
			if !executionDossier {
				continue
			}
			hint = "See the exact tool call in the execution card."
			humanLabel = "Tool call"
		default:
			continue
		}
		for column := 1; column < len(cells); column++ {
			value := cells[column]
			if !strings.Contains(value, opaqueEntityPlaceholder) &&
				!strings.Contains(value, legacyEntityPlaceholder) &&
				!entityIDPattern.MatchString(value) {
				continue
			}
			if humanLabel != "" {
				cells[0] = humanLabel
			}
			cells[column] = hint
			lines[index] = formatMarkdownTableRow(cells)
			break
		}
	}
	return strings.Join(lines, "\n")
}

func redactEnglishExecutionPointerRows(text string) string {
	lines := strings.Split(text, "\n")
	for index, line := range lines {
		cells, ok := markdownTableCells(line)
		if !ok || len(cells) < 2 {
			continue
		}
		label := strings.ToLower(strings.Trim(strings.TrimSpace(cells[0]), "`*_ "))
		label = strings.ReplaceAll(label, " ", "")
		var hint, humanLabel string
		switch label {
		case "conversationid", "conversationidentifier":
			hint = "See the exact conversation in the execution card."
			humanLabel = "Conversation"
		case "messageid", "messageidentifier":
			hint = "See the exact message in the execution card."
			humanLabel = "Message"
		case "toolcallid", "toolcallidentifier":
			hint = "See the exact tool call in the execution card."
			humanLabel = "Tool call"
		default:
			continue
		}
		for column := 1; column < len(cells); column++ {
			if !strings.Contains(cells[column], opaqueEntityPlaceholder) &&
				!strings.Contains(cells[column], legacyEntityPlaceholder) &&
				!entityIDPattern.MatchString(cells[column]) {
				continue
			}
			cells[0] = humanLabel
			cells[column] = hint
			lines[index] = formatMarkdownTableRow(cells)
			break
		}
	}
	return strings.Join(lines, "\n")
}

func redactStandaloneExecutionTimingRows(text string) string {
	lines := strings.Split(text, "\n")
	for index, line := range lines {
		cells, ok := markdownTableCells(line)
		if !ok || len(cells) < 2 {
			continue
		}
		label := normalizeMCPCallFieldLabel(cells[0])
		if label != "startedat" && label != "starttime" && label != "endedat" && label != "endtime" {
			continue
		}
		for column := 1; column < len(cells); column++ {
			if !isOpaqueTimestampPlaceholderCell(cells[column]) {
				continue
			}
			cells[column] = executionTimingTableHint
			lines[index] = formatMarkdownTableRow(cells)
			break
		}
	}
	return strings.Join(lines, "\n")
}

func redactEmptyChineseToolCallDossierSections(text string) string {
	lines := strings.Split(text, "\n")
	dossierContext := strings.Contains(text, "执行审计档案") ||
		strings.Contains(text, "完整执行档案") ||
		strings.Contains(strings.ToLower(text), "execution audit dossier")
	for index := 0; index < len(lines); index++ {
		heading := strings.ToLower(lines[index])
		toolCallHeading := strings.Contains(heading, "工具调用详情") ||
			strings.Contains(heading, "tool-call details")
		provenanceHeading := strings.Contains(heading, "溯源信息") ||
			strings.Contains(heading, "provenance")
		associationHeading := strings.Contains(heading, "关联标识") ||
			strings.Contains(heading, "关联追踪") ||
			strings.Contains(heading, "关联上下文") ||
			strings.Contains(heading, "关联信息")
		if !toolCallHeading && !(provenanceHeading && dossierContext) && !(associationHeading && dossierContext) {
			continue
		}
		header := -1
		for candidate := index + 1; candidate < len(lines) && candidate <= index+8; candidate++ {
			if strings.TrimSpace(lines[candidate]) == "" {
				continue
			}
			cells, ok := markdownTableCells(lines[candidate])
			if !ok || len(cells) < 2 {
				break
			}
			header = candidate
			break
		}
		if header < 0 || header+1 >= len(lines) {
			continue
		}
		separator, ok := markdownTableCells(lines[header+1])
		if !ok || !isMarkdownTableSeparator(separator) {
			continue
		}
		hasData := false
		for row := header + 2; row < len(lines); row++ {
			if strings.TrimSpace(lines[row]) == "" {
				continue
			}
			cells, rowOK := markdownTableCells(lines[row])
			if !rowOK || len(cells) < 2 || isMarkdownTableSeparator(cells) {
				break
			}
			hasData = true
			break
		}
		if hasData {
			continue
		}
		lines = append(lines[:header+2], append([]string{"| 详情 | 精确消息和工具调用见上方执行卡片。 |"}, lines[header+2:]...)...)
		index = header + 2
	}
	return strings.Join(lines, "\n")
}

// redactEmptyChineseDossierListSections turns a location-only association list into an honest
// pointer. A model may choose bullets instead of a table; after opaque IDs are removed, leaving
// only "对话已定位" looks like a complete detail section while providing no usable next step.
// 模型也可能用列表而不是表格表达关联信息。机器值移除后若只剩「对话已定位」，用户会误以为
// 详情已经完整展示；这里补上相邻执行卡入口，保持与空表语义一致。
func redactEmptyChineseDossierListSections(text string) string {
	lines := strings.Split(text, "\n")
	for index := 0; index < len(lines); index++ {
		heading := strings.TrimSpace(lines[index])
		lowerHeading := strings.ToLower(heading)
		if !strings.HasPrefix(heading, "#") ||
			(!strings.Contains(heading, "消息与工具调用详情") &&
				!strings.Contains(lowerHeading, "message and tool-call details")) {
			continue
		}
		end := index + 1
		for end < len(lines) && !strings.HasPrefix(strings.TrimSpace(lines[end]), "#") {
			end++
		}
		sawStatus := false
		locationOnly := true
		pointerPresent := false
		for _, line := range lines[index+1 : end] {
			trimmed := strings.TrimSpace(line)
			if trimmed == "" {
				continue
			}
			if strings.Contains(trimmed, "精确消息和工具调用见上方执行卡片") {
				pointerPresent = true
				break
			}
			if !strings.HasPrefix(trimmed, "-") {
				locationOnly = false
				break
			}
			status := strings.TrimSpace(strings.TrimLeft(trimmed, "-*• "))
			if !isDossierLocationStatus(status) {
				locationOnly = false
				break
			}
			sawStatus = true
		}
		if pointerPresent || !sawStatus || !locationOnly {
			continue
		}
		insert := end
		for insert > index+1 && strings.TrimSpace(lines[insert-1]) == "" {
			insert--
		}
		lines = append(lines[:insert], append([]string{"- 精确消息和工具调用见上方执行卡片。"}, lines[insert:]...)...)
		index = insert
	}
	return strings.Join(lines, "\n")
}

func isDossierLocationStatus(status string) bool {
	switch strings.ToLower(strings.TrimSpace(status)) {
	case "对话已定位", "会话已定位", "消息已定位", "工具调用已定位", "对话已关联", "会话已关联",
		"conversation located", "session located", "message located", "tool call located":
		return true
	default:
		return false
	}
}

func redactChineseDossierSummaryFields(text string) string {
	text = opaqueEnglishDossierErrorFieldPattern.ReplaceAllString(text, "${1}错误信息为空${2}")
	text = opaqueChineseDossierErrorFieldPattern.ReplaceAllStringFunc(text, func(match string) string {
		parts := opaqueChineseDossierErrorFieldPattern.FindStringSubmatch(match)
		if len(parts) != 2 {
			return match
		}
		return parts[1] + "错误信息为空"
	})
	return opaqueChineseDossierHistoryCountsPattern.ReplaceAllStringFunc(text, func(match string) string {
		parts := opaqueChineseDossierHistoryCountsPattern.FindStringSubmatch(match)
		if len(parts) != 3 {
			return match
		}
		return "（成功记录：" + parts[1] + "，失败记录：" + parts[2] + "）"
	})
}

func redactChineseDossierFieldLines(text string) string {
	lowerText := strings.ToLower(text)
	if !strings.Contains(text, "执行审计档案") &&
		!strings.Contains(text, "工具调用详情") &&
		!strings.Contains(lowerText, "tool-call details") &&
		!strings.Contains(lowerText, "execution audit dossier") {
		return text
	}
	return redactChineseDossierFieldLinesInContext(text)
}

func redactChineseDossierFieldLinesInContext(text string) string {
	return opaqueChineseDossierFieldLinePattern.ReplaceAllStringFunc(text, func(line string) string {
		parts := opaqueChineseDossierFieldLinePattern.FindStringSubmatch(line)
		if len(parts) != 7 {
			return line
		}
		label := strings.ReplaceAll(strings.TrimSpace(parts[3]), " ", "")
		var humanLabel string
		switch label {
		case "执行ID", "执行标识":
			humanLabel = "本次执行"
		case "函数版本ID", "函数版本标识":
			humanLabel = "函数版本"
		case "函数ID", "函数标识":
			humanLabel = "函数"
		case "版本ID", "版本标识":
			humanLabel = "版本"
		case "会话ID", "会话标识":
			humanLabel = "当前会话"
		case "对话ID", "对话标识":
			humanLabel = "当前对话"
		case "消息ID", "消息标识":
			humanLabel = "当前消息"
		case "工具调用ID", "工具调用标识":
			humanLabel = "工具调用"
		case "节点ID", "节点标识":
			humanLabel = "节点"
		case "运行ID", "运行标识":
			humanLabel = "运行"
		default:
			return line
		}
		return parts[1] + parts[2] + humanLabel + parts[4] + parts[5] + strings.TrimSpace(parts[6])
	})
}

func redactEnglishDossierMachineFieldNames(text string) string {
	return opaqueEnglishDossierMachineFieldNamePattern.ReplaceAllStringFunc(text, func(field string) string {
		switch strings.ToLower(field) {
		case "errormsg":
			return "错误信息"
		case "elapsedms":
			return "耗时"
		case "okcount":
			return "成功记录数"
		case "failedcount":
			return "失败记录数"
		default:
			return field
		}
	})
}

func redactEnglishDossierFieldListNames(text string) string {
	return opaqueEnglishDossierFieldListNamePattern.ReplaceAllStringFunc(text, func(field string) string {
		parts := opaqueEnglishDossierFieldListNamePattern.FindStringSubmatch(field)
		if len(parts) != 3 {
			return field
		}
		var label string
		switch strings.ToLower(parts[1]) {
		case "executionid":
			label = "执行标识"
		case "functionid":
			label = "函数标识"
		case "versionid":
			label = "版本标识"
		case "conversationid":
			label = "会话标识"
		case "messageid":
			label = "消息标识"
		case "toolcallid":
			label = "工具调用标识"
		default:
			label = parts[1]
		}
		return label + parts[2]
	})
}

func redactEnglishDossierFieldLines(text string) string {
	lowerText := strings.ToLower(text)
	if !strings.Contains(text, "执行审计档案") &&
		!strings.Contains(lowerText, "execution audit dossier") &&
		!strings.Contains(lowerText, "tool-call details") &&
		!strings.Contains(lowerText, "provenance") {
		return text
	}
	return redactEnglishDossierFieldLinesInContext(text)
}

func redactEnglishDossierFieldLinesInContext(text string) string {
	return opaqueEnglishDossierFieldLinePattern.ReplaceAllStringFunc(text, func(line string) string {
		parts := opaqueEnglishDossierFieldLinePattern.FindStringSubmatch(line)
		if len(parts) != 5 {
			return line
		}
		label := ""
		switch strings.ToLower(parts[2]) {
		case "executionid":
			label = "执行标识"
		case "functionid":
			label = "函数标识"
		case "versionid":
			label = "版本标识"
		case "conversationid":
			label = "会话标识"
		case "messageid":
			label = "消息标识"
		case "toolcallid":
			label = "工具调用标识"
		default:
			return line
		}
		return parts[1] + label + "：" + strings.TrimSpace(parts[4])
	})
}

func redactEnglishDossierInlineFieldNames(text string) string {
	lowerText := strings.ToLower(text)
	if !strings.Contains(text, "执行审计档案") &&
		!strings.Contains(lowerText, "execution audit dossier") &&
		!strings.Contains(lowerText, "tool-call details") &&
		!strings.Contains(lowerText, "provenance") {
		return text
	}
	return redactEnglishDossierInlineFieldNamesInContext(text)
}

func redactEnglishDossierInlineFieldNamesInContext(text string) string {
	return opaqueEnglishDossierInlineFieldNamePattern.ReplaceAllStringFunc(text, func(field string) string {
		switch strings.ToLower(field) {
		case "executionid":
			return "execution record reference"
		case "functionid":
			return "function reference"
		case "versionid":
			return "version reference"
		case "conversationid":
			return "conversation reference"
		case "messageid":
			return "message reference"
		case "toolcallid":
			return "tool-call reference"
		default:
			return field
		}
	})
}

func redactChineseDossierDanglingTableFragments(text string) string {
	lowerText := strings.ToLower(text)
	if !strings.Contains(text, "执行审计档案") && !strings.Contains(text, "完整执行档案") &&
		!strings.Contains(lowerText, "execution audit dossier") &&
		!(strings.Contains(text, "| **记录") && strings.Contains(text, "关联上下文")) {
		return text
	}
	lines := strings.Split(text, "\n")
	remove := make(map[int]bool)
	for index, line := range lines {
		trimmed := strings.TrimSpace(line)
		if !strings.HasPrefix(trimmed, "|") {
			continue
		}
		fragment := strings.TrimSpace(strings.TrimPrefix(trimmed, "|"))
		fragment = strings.Trim(fragment, "*_` ")
		if strings.ToLower(fragment) != "记录" && strings.ToLower(fragment) != "record" {
			continue
		}
		for next := index + 1; next < len(lines); next++ {
			candidate := strings.TrimSpace(lines[next])
			if candidate == "" {
				continue
			}
			lowerCandidate := strings.ToLower(candidate)
			if strings.HasPrefix(candidate, "#") &&
				(strings.Contains(candidate, "关联") || strings.Contains(lowerCandidate, "traceability") || strings.Contains(lowerCandidate, "context")) {
				remove[index] = true
			}
			break
		}
	}
	kept := make([]string, 0, len(lines)-len(remove))
	for index, line := range lines {
		if !remove[index] {
			kept = append(kept, line)
		}
	}
	return strings.Join(kept, "\n")
}

func appendEmptyDossierPointer(text string) string {
	trimmed := strings.TrimRight(text, "\r\n")
	if trimmed == "" {
		return "| 详情 | 精确消息和工具调用见上方执行卡片。 |\n"
	}
	return trimmed + "\n| 详情 | 精确消息和工具调用见上方执行卡片。 |\n"
}

func isEmptyDossierTableHeaderChunk(text string) bool {
	lines := strings.Split(strings.TrimSpace(text), "\n")
	if len(lines) != 2 {
		return false
	}
	header, headerOK := markdownTableCells(lines[0])
	separator, separatorOK := markdownTableCells(lines[1])
	return headerOK && len(header) >= 2 && separatorOK && isMarkdownTableSeparator(separator)
}

func dossierTableHasDataRow(text string) bool {
	for _, line := range strings.Split(text, "\n") {
		if strings.TrimSpace(line) == "" {
			continue
		}
		cells, ok := markdownTableCells(line)
		if !ok || len(cells) < 2 || isMarkdownTableSeparator(cells) {
			continue
		}
		if strings.Contains(line, "|") && !isEmptyDossierTableHeaderChunk(line) {
			return true
		}
	}
	return false
}

func isChineseAuditIdentityFieldLabel(label string) bool {
	value := strings.ToLower(strings.Trim(strings.TrimSpace(label), "`*_ "))
	if annotation := strings.IndexAny(value, "（("); annotation >= 0 {
		value = strings.TrimSpace(value[:annotation])
	}
	value = strings.ReplaceAll(value, " ", "")
	switch value {
	case "执行id", "函数id", "版本id", "会话id", "对话id", "消息id", "工具调用id", "节点id", "运行id":
		return true
	default:
		return false
	}
}
