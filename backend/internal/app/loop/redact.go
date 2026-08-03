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
	entityIDPattern = regexp.MustCompile(`\b(?:ws|fn|fnv|hd|ag|wf|trg|tr|cv|msg|blk|att|aki|hdenv|hdv|tp|doc|mem|todo|fr|frn|wfv|apf|apfv|act|sk)_[A-Za-z0-9]+\b`)
	// Models sometimes repeat an opaque target in parentheses after already naming it, e.g.
	// "workflow nightly (wf_...)". Removing that redundant parenthetical is more fluent than
	// leaving "(the referenced item)" in user-facing prose; standalone ids still use the placeholder.
	opaqueEntityParentheticalPattern = regexp.MustCompile("\\s*\\(\\s*`?(?:ws|fn|fnv|hd|ag|wf|trg|tr|cv|msg|blk|att|aki|hdenv|hdv|tp|doc|mem|todo|fr|frn|wfv|apf|apfv|act|sk)_[A-Za-z0-9]+`?\\s*\\)")
	// A streamed parenthetical can be redacted in two passes (the id arrives after the opening
	// parenthesis). Remove the placeholder form too, so a chunk-boundary miss cannot leave
	// "name (the referenced item)" in the final prose.
	opaquePlaceholderParentheticalPattern = regexp.MustCompile(`\s*\(\s*` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?" + `\s*\)`)
	// When a model puts an opaque id immediately after an already human-readable entity noun,
	// replacing it with a second noun makes broken prose ("the workflow the referenced item").
	// Drop only the placeholder in that narrow context; standalone ids still retain an honest
	// neutral replacement.
	//
	// 模型把 opaque id 紧跟在已有人话实体名后时，替换成第二个名词会形成坏句子（"the workflow the
	// referenced item"）。只在这个窄上下文移除 placeholder；独立 ID 仍保留诚实的中性替代。
	opaqueEntityNounPlaceholderPattern = regexp.MustCompile(`(?i)\b(the\s+)?(workflow|function|handler|agent|trigger|conversation|document|skill|workspace|message|flowrun|run|attachment)\s+` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `\b`)
	// Markdown emphasis can sit between the noun and the opaque target, e.g. "workflow **wf_…**".
	// Keep the emphasis attached to the meaningful noun by removing only the decoration around the
	// placeholder. The plain pattern above intentionally handles "**workflow wf_…**" so its outer
	// emphasis remains intact.
	opaqueEntityNounDecoratedPlaceholderPattern = regexp.MustCompile(
		`(?i)\b(the\s+)?(workflow|function|handler|agent|trigger|conversation|document|skill|workspace|message|flowrun|run|attachment)\s+(?:\*{1,3}|_{1,3}|` + "`" + `)\s*` + regexp.QuoteMeta(opaqueEntityPlaceholder) + `\s*(?:\*{1,3}|_{1,3}|` + "`" + `)([[:space:][:punct:]]|$)`)
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
	flowRunSubjectPrefixPattern       = regexp.MustCompile(`(?i)\b(?:the\s+)?flow\s+$`)
	opaqueReportForPattern            = regexp.MustCompile(`(?i)\b(flow\s+run|flowrun|workflow|function|handler|agent|trigger|conversation|document|skill|workspace|message|run|attachment)\s+report\s+for\s+` + "`?" + `(?:ws|fn|hd|ag|wf|trg|tr|cv|msg|blk|att|aki|hdenv|hdv|tp|doc|mem|todo|fr|act|sk)_[A-Za-z0-9]+` + "`?")
	opaqueReportForPrefixPattern      = regexp.MustCompile(`(?i)(?:\b(?:flow\s+run|flowrun|workflow|function|handler|agent|trigger|conversation|document|skill|workspace|message|run|attachment)\s+report\s+for\s+)$`)
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
	opaqueFlowrunSearchRowPlaceholderPattern           = regexp.MustCompile("(?im)^([ \\t]*\\|[ \\t]*[0-9]+[ \\t]*\\|)[ \\t]*(?:`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?)[ \\t]*(\\|[^\\r\\n]*$)")
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
	opaqueFlowrunTargetPlaceholderPattern       = regexp.MustCompile(`(?i)(\bget_flowrun\b` + "`?" + `\s+for\s+)` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?")
	opaqueFlowrunIDPlaceholderPattern           = regexp.MustCompile(`(?i)(?:\bwith\s+)?flowrunId\s+` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?")
	opaqueFlowrunMissingIDPattern               = regexp.MustCompile(`(?i)(\bthe\s+id\s+doesn['’]t\s+exist\s+[—-]\s+)` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?(\\s+appears)")
	opaqueFlowrunNoMatchPattern                 = regexp.MustCompile(`(?i)(\bthere\s+is\s+no\s+workflow\s+run)\s+with\s+` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?")
	opaqueFlowrunRequestedIDRowPattern          = regexp.MustCompile(`(?im)^[ \t]*\|[^\r\n|]*(?:requested\s+id|flow\s*run\s*id)[^\r\n|]*\|[ \t]*` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?" + `[ \t]*\|[ \t]*$`)
	opaqueFlowrunIDFieldPlaceholderPattern      = regexp.MustCompile(`(?im)^[ \t]*\*{0,2}flowrun\s+id\*{0,2}:\*{0,2}[ \t]+` + "`?" + regexp.QuoteMeta(opaqueEntityPlaceholder) + "`?" + `[ \t]*$`)
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
	entityNounPrefixPattern = regexp.MustCompile(`(?i)(?:\bthe\s+)?(?:workflow|function|handler|agent|trigger|conversation|document|skill|workspace|message|flowrun|run|attachment)\s+(?:\*{1,3}|_{1,3}|` + "`" + `)?$`)
	isoTimestampPattern     = regexp.MustCompile(`\b\d{4}-\d{2}-\d{2}(?:T| )\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2}| UTC)?\b`)
	longIntegerPattern      = regexp.MustCompile(`\b\d{10,}\b`)
	longHexPattern          = regexp.MustCompile(`\b[0-9a-fA-F]{32,}\b`)
)

// redactOpaqueMachineValues protects the user-facing assistant prose. Tool blocks remain
// untouched: their exact values are the audit/source-of-truth surface and are already rendered
// separately by the product.
func redactOpaqueMachineValues(text string) string {
	// Keep old durable assistant blocks readable after the placeholder vocabulary changes.
	text = strings.ReplaceAll(text, legacyEntityPlaceholder, opaqueEntityPlaceholder)
	text = isoTimestampPattern.ReplaceAllString(text, opaqueTimestampPlaceholder)
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
	text = opaqueIDSubjectPattern.ReplaceAllStringFunc(text, func(match string) string {
		if match != "" && unicode.IsUpper([]rune(match)[0]) {
			return "The requested item"
		}
		return "the requested item"
	})
	text = entityIDPattern.ReplaceAllString(text, opaqueEntityPlaceholder)
	// A raw opaque ref can become the neutral placeholder only at the generic ID pass above;
	// repeat the structured-row cleanup after that pass so the final close snapshot cannot retain
	// a placeholder merely because its source prefix was not known to the first pass.
	text = opaqueFlowrunIDPlaceholderTableRowPattern.ReplaceAllString(text, "| **Run** | Current run |")
	text = opaqueFlowrunSearchRowPlaceholderPattern.ReplaceAllString(text, "${1} See the run card ${2}")
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
	text = opaqueRefPlaceholderTableRowPattern.ReplaceAllString(text, "| **Ref** | Internal reference |")
	text = opaqueNodeRecordPlaceholderTableRowPattern.ReplaceAllString(text, "| **Node record** | Internal record |")
	text = opaquePinnedRefsPlaceholderTableRowPattern.ReplaceAllString(text, "| Internal reference | Current version |")
	text = opaquePinnedRefAnnotatedPlaceholderTableRowPattern.ReplaceAllString(text, "| Internal approval reference | Current version |")
	text = opaqueFlowrunOverviewIDPlaceholderPattern.ReplaceAllString(text, "- Run: Current run")
	text = opaqueFlowrunOverviewVersionPlaceholderPattern.ReplaceAllString(text, "- Version: Current version")
	text = opaquePinnedRefsPlaceholderBulletPattern.ReplaceAllString(text, "- Internal approval references")
	text = opaquePinnedRefsNaturalBulletPattern.ReplaceAllString(text, "- Internal approval references")
	text = opaquePinnedRefsNaturalSentencePattern.ReplaceAllString(text, "**References:** Internal approval reference is pinned to the current version.")
	text = opaqueFlowrunSummaryTargetPattern.ReplaceAllString(text, "${1}:")
	text = opaquePinnedReferenceNaturalPattern.ReplaceAllString(text, "Pinned reference: The function version is pinned.")
	text = opaqueFlowrunIDFieldPlaceholderPattern.ReplaceAllString(text, "**Requested ID:** Supplied run ID")
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
	text = opaqueEntityNounDecoratedPlaceholderPattern.ReplaceAllString(text, "${1}${2}${3}")
	text = opaqueEntityNounPlaceholderPattern.ReplaceAllString(text, "${1}${2}")
	text = longIntegerPattern.ReplaceAllString(text, opaqueIntegerPlaceholder)
	return longHexPattern.ReplaceAllString(text, opaqueHashPlaceholder)
}

// textRedactor keeps the trailing token until a delimiter arrives. Provider deltas are allowed
// to split an opaque value across chunks; holding one token makes the protection independent of
// that wire chunking while preserving normal streaming for completed words.
type textRedactor struct {
	pending string
}

func (r *textRedactor) Write(delta string) string {
	r.pending += delta
	if r.pending == "" {
		return ""
	}
	if prefix, held, ok := splitToolNamePrefix(r.pending); ok {
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
			return text[:holdStart], text[holdStart:], true
		}
	}
	return "", "", false
}

func splitToolNamePrefix(text string) (prefix, held string, ok bool) {
	const phrase = "get_flowrun"
	lower := strings.ToLower(text)
	for start := len(text) - 1; start >= 0; start-- {
		suffix := lower[start:]
		if len(suffix) >= len(phrase) || !strings.HasPrefix(phrase, suffix) {
			continue
		}
		holdStart := start
		if holdStart > 0 && text[holdStart-1] == '`' {
			holdStart--
		}
		return text[:holdStart], text[holdStart:], true
	}
	return "", "", false
}

func splitStructuredLinePrefix(text string) (prefix, held string, ok bool) {
	lineStart := strings.LastIndexByte(text, '\n') + 1
	line := text[lineStart:]
	if line == "" || len([]rune(line)) > 512 {
		return "", "", false
	}
	lower := strings.ToLower(line)
	hasTable := strings.Contains(line, "|")
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
