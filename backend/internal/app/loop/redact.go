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
	opaqueEntityPlaceholder    = "the requested item"
	legacyEntityPlaceholder    = "the referenced item"
	opaqueTimestampPlaceholder = "the recorded time"
	opaqueIntegerPlaceholder   = "the numeric value"
	opaqueHashPlaceholder      = "the recorded digest"
)

var (
	// Entity ids are useful inside tool cards, but they are not useful prose. Keep the
	// prefixes explicit so ordinary snake_case words remain untouched.
	entityIDPattern = regexp.MustCompile(`\b(?:ws|fn|fnv|hd|ag|wf|trg|tr|cv|msg|blk|att|aki|hdenv|hdv|tp|doc|mem|todo|fr|frn|wfv|apf|apfv|act|sk|rel)_[A-Za-z0-9]+\b`)
	// Models sometimes repeat an opaque target in parentheses after already naming it, e.g.
	// "workflow nightly (wf_...)". Removing that redundant parenthetical is more fluent than
	// leaving "(the referenced item)" in user-facing prose; standalone ids still use the placeholder.
	opaqueEntityParentheticalPattern = regexp.MustCompile("\\s*\\(\\s*`?(?:ws|fn|fnv|hd|ag|wf|trg|tr|cv|msg|blk|att|aki|hdenv|hdv|tp|doc|mem|todo|fr|frn|wfv|apf|apfv|act|sk)_[A-Za-z0-9]+`?\\s*\\)")
	// A streamed parenthetical can be redacted in two passes (the id arrives after the opening
	// parenthesis). Remove the placeholder form too, so a chunk-boundary miss cannot leave
	// "name (the referenced item)" in the final prose.
	opaquePlaceholderParentheticalPattern = regexp.MustCompile(`\s*\(\s*` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?" + `\s*\)`)
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
	// Markdown emphasis can sit between the noun and the opaque target, e.g. "workflow **wf_…**".
	// Keep the emphasis attached to the meaningful noun by removing only the decoration around the
	// placeholder. The plain pattern above intentionally handles "**workflow wf_…**" so its outer
	// emphasis remains intact.
	opaqueEntityNounDecoratedPlaceholderPattern = regexp.MustCompile(
		`(?i)\b(the\s+)?(workflow|function|handler|agent|trigger|conversation|document|skill|workspace|message|flowrun|run|attachment)\s+(?:\*{1,3}|_{1,3}|` + "`" + `)\s*` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `\s*(?:\*{1,3}|_{1,3}|` + "`" + `)([[:space:][:punct:]]|$)`)
	opaqueEntityIDClausePrefixPattern = regexp.MustCompile(`(?i)(?:[ \t]+(?:with|using|having)[ \t]+(?:the[ \t]+)?(?:id|identifier)[ \t]+[\x60"]?)$`)
	// Preserve the grammar of sentences that introduce an opaque identifier, e.g.
	// "The ID `fr_…` does not exist". Replacing only the identifier would produce
	// "The ID the referenced item"; the adjacent tool card still contains the exact ID.
	opaqueIDSubjectPattern = regexp.MustCompile(`(?i)\bthe\s+id\s+` + "`?" + `(?:ws|fn|hd|ag|wf|trg|tr|cv|msg|blk|att|aki|hdenv|hdv|tp|doc|mem|todo|fr|act|sk)_[A-Za-z0-9]+` + "`?")
	// Keep the introducer pending when the provider splits immediately before the ID.
	opaqueIDSubjectPrefixPattern = regexp.MustCompile(`(?i)(?:\bthe\s+id\s+` + "`?" + `)$`)
	// Models also introduce a target as "The flowrun ID `fr_…`" or
	// "The flowrun with ID `fr_…`". Replace the
	// whole subject prefix so the result remains a complete noun phrase.
	opaqueTypedIDSubjectPattern       = regexp.MustCompile(`(?i)\b(the\s+)?(flow\s+run|flowrun|workflow|function|handler|agent|trigger|conversation|document|skill|workspace|message|run|attachment)\s+(?:with\s+)?id\s+` + "`?" + `(?:ws|fn|hd|ag|wf|trg|tr|cv|msg|blk|att|aki|hdenv|hdv|tp|doc|mem|todo|fr|act|sk)_[A-Za-z0-9]+` + "`?")
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
	opaqueReportForPattern                       = regexp.MustCompile(`(?i)\b(flow\s+run|flowrun|workflow|function|handler|agent|trigger|conversation|document|skill|workspace|message|run|attachment)\s+report\s+for\s+` + "`?" + `(?:ws|fn|hd|ag|wf|trg|tr|cv|msg|blk|att|aki|hdenv|hdv|tp|doc|mem|todo|fr|act|sk)_[A-Za-z0-9]+` + "`?")
	opaqueReportForPrefixPattern                 = regexp.MustCompile(`(?i)(?:\b(?:flow\s+run|flowrun|workflow|function|handler|agent|trigger|conversation|document|skill|workspace|message|run|attachment)\s+report\s+for\s+)$`)
	// A model may put the opaque run id in a Markdown table. Replacing only the cell with a generic
	// placeholder makes the table look like a broken template; retain the semantic row instead.
	//
	// 模型可能把 opaque run id 放进 Markdown 表格。只把单元格替换成通用 placeholder 会像坏模板；保留语义行。
	opaqueFlowrunIDTableRowPattern = regexp.MustCompile(`(?im)^[ \t]*\|[^\r\n|]*(?:flow\s*run|flowrun|run)[ \t]*id[^\r\n|]*\|[^\r\n|]*` + "`?" + `fr_[A-Za-z0-9]+` + "`?" + `[^\r\n|]*\|[ \t]*$`)
	opaqueReportDecoratedPattern   = regexp.MustCompile(`(?i)\b(flow\s+run|flowrun|workflow|function|handler|agent|trigger|conversation|document|skill|workspace|message|run|attachment)\s+report\s+for\s+(?:\*{1,3}|_{1,3}|` + "`" + `)*` + `(?:ws|fn|hd|ag|wf|trg|tr|cv|msg|blk|att|aki|hdenv|hdv|tp|doc|mem|todo|fr|act|sk)_[A-Za-z0-9]+(?:\*{1,3}|_{1,3}|` + "`" + `)*`)
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
	opaqueFlowrunSummaryTargetPattern                  = regexp.MustCompile(`(?im)^([ \t]*(?:flow\s*run|flowrun|run)[ \t]+summary)[ \t]+for[ \t]+(?:` + "`?" + `(?:ws|fn|fnv|hd|ag|wf|trg|tr|cv|msg|blk|att|aki|hdenv|hdv|tp|doc|mem|todo|fr|frn|wfv|apf|apfv|act|sk)_[A-Za-z0-9]+` + "`?" + `|` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `|` + regexp.QuoteMeta(legacyEntityPlaceholder) + `|the requested run|the supplied run(?: ID)?)[ \t]*:?[ \t]*$`)
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
	// Version IDs are opaque too. Remove the whole field, including any model-added parenthetical,
	// instead of showing a value-shaped placeholder in assistant prose.
	// 版本 ID 同样是不透明机器值。整行连同模型附加的括号说明一起移除，不能渲染成像真实值的占位符。
	opaqueVersionIDPlaceholderLinePattern = regexp.MustCompile(`(?im)^[ \t]*(?:[-*][ \t]+|[0-9]+[.)][ \t]+)?(?:\*{0,2}|_{0,2})?version[ \t]+(?:id|identifier)(?:\*{0,2}|_{0,2})?[ \t]*:[ \t]*[\x60]?(?:the requested item|the referenced item)[\x60]?[^\r\n]*\r?$`)
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
	opaqueEntityIDClausePattern       = regexp.MustCompile(`(?i)[ \t]+(?:with|using|having)[ \t]+(?:the[ \t]+)?(?:id|identifier)[ \t]+[\x60"]?(?:the requested item|the referenced item)[\x60"]?`)
	opaqueEntitySearchBulletPattern   = regexp.MustCompile(`(?im)^([ \t]*[-*][ \t]+)[\x60"]?(?:the requested item|the referenced item)[\x60"]?[ \t]*[—-][ \t]*`)
	searchRefWordPattern              = regexp.MustCompile(`(?i)\brefs?\b`)
	searchRefRawValuePattern          = regexp.MustCompile(`(?i)(?:\b(?:ws|fn|fnv|hd|ag|wf|trg|tr|cv|msg|blk|att|aki|hdenv|hdv|tp|doc|mem|todo|fr|frn|wfv|apf|apfv|act|sk)_[A-Za-z0-9]+(?:\.[A-Za-z0-9_]+)?\b|\b(?:fn|hd|ag|wf|ctl|apf)_[.…]+(?:\.[A-Za-z0-9_]+)?|\b(?:fn|hd|ag|wf|ctl|apf)_<[^>\r\n]+>(?:\.[A-Za-z0-9_<>-]+)?|\bmcp:[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+|\bsearch_blocks\b)`)
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
	opaqueRequestedItemPattern                  = regexp.MustCompile(`(?i)` + regexp.QuoteMeta(opaqueEntityPlaceholder))
	opaqueFlowrunQuotedSuppliedIDPattern        = regexp.MustCompile(`(?i)[\x60](the supplied run id)[\x60]`)
	opaqueFlowrunSentenceStartSuppliedIDPattern = regexp.MustCompile(`(?i)([.!?]\s+)(?:[\x60])?the supplied run id`)
	opaqueFlowrunValueSuppliedIDPattern         = regexp.MustCompile(`(?i)\bthe\s+value\s+the\s+supplied\s+run\s+id\s+looks\s+like\b`)
	opaqueFlowrunLabelPattern                   = regexp.MustCompile(`(?i)\bflowrunId\b|\bflowrun\s+ID\b`)
	opaqueFlowrunPrefixPhrasePattern            = regexp.MustCompile(`(?i)\bthe\s+` + "`?" + `fr_` + "`?" + `\s+prefix\b`)
	opaqueEntityPrefixPhrasePattern             = regexp.MustCompile(`(?i)\bthe\s+` + "`?" + `(?:ws|fn|hd|ag|wf|trg|tr|cv|msg|blk|att|aki|hdenv|hdv|tp|doc|mem|todo|fr|frn|wfv|apf|apfv|act|sk)_` + "`?" + `\s+prefix\b`)
	// Hold a human-readable entity noun at the end of a delta until the following token arrives.
	// Otherwise a provider chunk boundary between "workflow " and "wf_…" would make the later
	// redaction unable to remove the duplicate noun from already-emitted SSE text.
	entityNounPrefixPattern            = regexp.MustCompile(`(?i)(?:\bthe\s+)?(?:workflow|function|handler|agent|trigger|conversation|document|skill|workspace|message|flowrun|run|attachment)\s+(?:\*{1,3}|_{1,3}|` + "`" + `)?$`)
	isoTimestampPattern                = regexp.MustCompile(`\b\d{4}-\d{2}-\d{2}(?:T| )\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2}| UTC)?\b`)
	lastMessageAtFieldPattern          = regexp.MustCompile(`(?i)\blast\s*message\s*at\b\s*[:|=]\s*` + isoTimestampPattern.String())
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
	// Keep old durable assistant blocks readable after the placeholder vocabulary changes.
	text = strings.ReplaceAll(text, legacyEntityPlaceholder, opaqueEntityPlaceholder)
	text = isoTimestampPattern.ReplaceAllString(text, opaqueTimestampPlaceholder)
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
	text = opaqueIDSubjectPattern.ReplaceAllStringFunc(text, func(match string) string {
		if match != "" && unicode.IsUpper([]rune(match)[0]) {
			return "The requested item"
		}
		return "the requested item"
	})
	text = entityIDPattern.ReplaceAllString(text, opaqueEntityPlaceholder)
	text = opaquePlaceholderIDParentheticalPattern.ReplaceAllString(text, "")
	text = searchBlocksAbbreviatedRefPattern.ReplaceAllString(text, opaqueEntityPlaceholder)
	text = searchBlocksTemplateRefPattern.ReplaceAllString(text, opaqueEntityPlaceholder)
	text = opaqueVersionIDPlaceholderSentencePattern.ReplaceAllString(text, "version reference updated")
	text = opaqueVersionIDPlaceholderLinePattern.ReplaceAllString(text, "")
	text = redactOpaquePlaceholderParentheticalLists(text)
	text = opaquePositionPlaceholderNamePattern.ReplaceAllString(text, "${1}${2}")
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
	// A placeholder inside a Markdown table is still not a user-facing value. During streaming,
	// replace the cell with an honest unavailable marker; the complete close pass below can remove
	// an entirely unavailable ID column instead of leaving a misleading header behind.
	// Markdown 表格里的 placeholder 仍不是用户值。流式阶段先替换为诚实的不可用标记；完整 close 再移除整列。
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
	text = removeOpaquePlaceholderIDColumns(text)
	text = longIntegerPattern.ReplaceAllString(text, opaqueIntegerPlaceholder)
	text = longHexPattern.ReplaceAllString(text, opaqueHashPlaceholder)
	return restoreExactLastMessageAt(text)
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
				continue
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
			result[index] = ""
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

func isOpaqueTimestampPlaceholderCell(cell string) bool {
	value := strings.ToLower(strings.Trim(strings.TrimSpace(cell), "`*_ "))
	return value == opaqueTimestampPlaceholder
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
	flowrunSearchRowHint   = "See the run card"
	searchBlocksRefRowHint = "See the exact ref in the search_blocks result card."
)

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
	pending       string
	relationIntro string
}

func (r *textRedactor) Write(delta string) string {
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
	// Relation summaries and their Markdown rows are semantic units. Hold the current bounded
	// line until its newline so a split placeholder or relation ref cannot leak to the messages
	// stream before the relation-specific rewrite sees the complete context.
	if prefix, held, ok := splitRelationPrefix(r.pending); ok {
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
	// Media reasoning can introduce an attachment id or repeat the original/edited
	// attachment across provider chunks. Hold the bounded assignment until the opaque
	// value is complete so the live SSE stream cannot expose a partial placeholder.
	// 媒体 reasoning 可能跨 provider 分块介绍附件 ID 或重复原图/改图。暂存有限长度的赋值句，
	// 确保实时 SSE 不会先吐出半截 placeholder。
	if prefix, held, ok := splitMediaAttachmentAssignmentPrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
	}
	// Markdown table rows carrying opaque values are semantic units, not ordinary prose. A
	// provider can split the row after an opening backtick or between the two cells; holding the
	// incomplete line prevents a bad placeholder from appearing in an intermediate SSE frame.
	if prefix, held, ok := splitStructuredLinePrefix(r.pending); ok {
		r.pending = held
		return redactOpaqueMachineValues(prefix)
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
	if open := strings.LastIndex(emitted, "("); open >= 0 && strings.LastIndex(emitted, ")") < open && len([]rune(emitted[open:])) <= 128 {
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

func (r *textRedactor) Flush() string {
	if r.relationIntro != "" {
		intro := redactOpaqueMachineValues(r.relationIntro)
		r.relationIntro = ""
		return intro + r.Flush()
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

func splitPlaceholderPrefix(text string) (prefix, held string, ok bool) {
	for _, phrase := range []string{legacyEntityPlaceholder, opaqueEntityPlaceholder} {
		for start := len(text) - 1; start >= 0; start-- {
			suffix := text[start:]
			if len(suffix) >= len(phrase) || !strings.HasPrefix(phrase, suffix) {
				continue
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
		for _, line := range strings.Split(completed, "\n") {
			if opaquePlaceholderLabeledLinePattern.MatchString(line) ||
				opaquePlaceholderBoldColonLabeledLinePattern.MatchString(line) ||
				opaqueVersionIDPlaceholderLinePattern.MatchString(line) {
				return completed, text[newline+1:], true
			}
		}
	}
	lineStart := strings.LastIndexByte(text, '\n') + 1
	line := text[lineStart:]
	if line == "" || len([]rune(line)) > 512 {
		return "", "", false
	}
	if hasOpaquePlaceholderLabeledPrefix(line) {
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
