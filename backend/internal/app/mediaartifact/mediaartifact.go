// Package mediaartifact turns a sandboxed producer's DECLARATION of a file it wrote into the one
// media currency the rest of the system speaks (ADR 0014 不变量①).
//
// It lives in its own package because it has two callers that must behave IDENTICALLY: function
// and handler. They are the two producers that run as USER CODE in a venv sandbox, and that single
// fact is what makes them different in kind from every other producer — a tool, an MCP adapter or
// the read-aloud path all run in-process, hold a workspace ctx and an attachment store, and can
// therefore mint an `attachmentId` themselves. Sandboxed user code cannot. All it can do is write
// a file and say so.
//
// A second copy of this collector living in `handler` would be a second copy of the path-escape
// check, the content sniff and the mime whitelist — three security decisions, forked. 强化地基,
// 不在模块内重抄 (原则 #8).
//
// mediaartifact 把沙箱产地对「我写了这个文件」的**声明**,变成系统其余部分早已会说的那种媒体货币
// (ADR 0014 不变量①)。
//
// 它单独成包,是因为它有**两个必须行为完全一致**的调用方:function 与 handler。它们是仅有的两个
// 以**用户代码**身份跑在 venv 沙箱里的产地,而这一个事实使它们与其余产地**种类不同**——工具、MCP
// 适配器、朗读路径全都在进程内跑,手里有 workspace ctx 和附件库,**能自己铸出** `attachmentId`;
// 沙箱里的用户代码不能,它能做的只有写下一个文件、然后说一声。
//
// 让 `handler` 里再有一份这个采集器,等于让路径逃逸检查、内容嗅探、mime 白名单**这三个安全决定各
// 分叉一次**。强化地基、不在模块内重抄(原则 #8)。
package mediaartifact

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	fspathpkg "github.com/sunweilin/anselm/backend/internal/pkg/fspath"
	mediarefpkg "github.com/sunweilin/anselm/backend/internal/pkg/mediaref"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// Media artifacts produced by user code (WRK-082 批E). A function runs in a venv sandbox with no
// workspace ctx, no HTTP and no blob path — it therefore CANNOT mint an `attachmentId` itself.
// That single fact shapes everything here: the function DECLARES a file it wrote, and this
// collector turns the declaration into the one media currency the rest of the system already
// speaks (不变量①).
//
// 用户代码产出的媒体产物(批E)。function 在 venv 沙箱里跑,没有 workspace ctx、没有 HTTP、没有 blob
// 路径——故它**不可能**自己铸出 `attachmentId`。这一个事实决定了这里的一切:函数**声明**它写下的文件,
// 而本采集器把声明变成系统其余部分早已会说的那一种媒体货币(不变量①)。

const (
	// MediaKey is the declaration's field name: `{"$media": "chart.png"}`. A `$`-prefixed key
	// cannot collide with a data field a function would naturally return.
	//
	// MediaKey 是声明的字段名。`$` 前缀键不会与函数自然会返回的数据字段撞名。
	MediaKey = "$media"

	// artifactMaxBytes caps ONE artifact (same tier as the image download cap).
	artifactMaxBytes = 32 << 20
)

// maxArtifacts bounds one run's collected artifacts. It is deliberately mediaref.MaxRefs: the
// consumption chokepoint expands at most that many, so collecting more would persist attachments
// nothing downstream will ever show.
//
// maxArtifacts 界一次运行采集的产物数。刻意取 mediaref.MaxRefs:消费咽喉最多展开这么多,采多了就是
// 落一堆下游永远不会显示的附件。
const maxArtifacts = mediarefpkg.MaxRefs

// artifactMimeAllowed reports whether a sniffed mime may become an attachment. The whitelist is
// the four families the media card family can actually render; anything else stays a file on a
// temp dir that is about to be deleted, and says so in the logs.
//
// artifactMimeAllowed 报告嗅出的 mime 可否成为附件。白名单是一族卡真能渲的四类;其余留在一个即将
// 被删的临时目录里,并在 logs 里说明。
func artifactMimeAllowed(mime string) bool {
	switch {
	case strings.HasPrefix(mime, "image/"),
		strings.HasPrefix(mime, "audio/"),
		strings.HasPrefix(mime, "video/"),
		mime == "application/pdf":
		return true
	}
	return false
}

// ArtifactUploader lands a declared file as a first-class attachment (*attachmentapp.Service
// satisfies it structurally) — the SAME store every other producer writes to (不变量②).
//
// ArtifactUploader 把被声明的文件落成一等附件(*attachmentapp.Service 结构满足)——与其余每个产地
// 写的是**同一间库**(不变量②)。
type ArtifactUploader interface {
	Upload(ctx context.Context, filename, mime string, data []byte) (*attachmentdomain.Attachment, error)
}

// collectArtifacts walks a function's result, replaces every `{"$media": "<path>"}` declaration
// IN PLACE with a MediaRef receipt, and returns the rewritten value plus any human-facing notes.
//
// In place, not appended: the artifact stays on the key it belongs to, so `node.chart` IS the
// picture — rather than "the result has a chart field, and separately an artifacts array you get
// to correlate yourself". That is also why 不变量①③④ come for free: the moment a MediaRef appears,
// the consumption chokepoint, the card family and the workflow edges all already know it.
//
// Failures are per-artifact and LOUD-IN-LOGS but never fatal: one oversized chart must not void a
// run whose numbers are fine. A declaration that cannot be collected is left as it was, so the
// result never claims an artifact exists when it does not.
//
// collectArtifacts 走函数结果,把每个 `{"$media": "<路径>"}` 声明**就地**换成 MediaRef receipt,
// 返回改写后的值与给人看的说明。
//
// **就地**而非追加:产物留在它本该在的那个键上,于是 `node.chart` **就是**那张图——而不是「结果里有个
// chart 字段,另外还有个平级 artifacts 数组要你自己对应」。也正因如此不变量①③④全部免费:MediaRef 一
// 出现,消费咽喉、一族卡、workflow 的边就都已经认识它。
//
// 失败**逐件**、**在 logs 里大声**、但绝不致命:一张超大的图不该让一次数字都算对了的运行作废。采集不了
// 的声明原样留下,故结果绝不会声称一件并不存在的产物存在。
// Source names the producer on the receipt. It is a parameter rather than a constant because the
// receipt has to say WHICH sandbox produced the file — a reader of `{"source":"..."}` in a
// tool_result should be able to tell a function's chart from a handler's, and one shared collector
// must not flatten that into a single lie.
//
// Source 是 receipt 上的产地名。它是参数而非常量,因为 receipt 必须说清是**哪个**沙箱产的——
// tool_result 里读到 `{"source":"..."}` 的人应当分得出函数的图表与 handler 的,而一个共用的采集器
// 不该把这一点压成同一句谎话。
type Source string

const (
	SourceFunction Source = "function_artifact"
	SourceHandler  Source = "handler_artifact"
)

// Collect walks a producer's result, replaces every `{"$media": "<path>"}` declaration IN PLACE
// with a MediaRef receipt, and returns the rewritten value plus human-readable notes for anything
// it refused. A refusal never fails the run: a function that computed the right answer and also
// mis-declared a file has still computed the right answer.
//
// Collect 走产地的结果,把每个 `{"$media": "<路径>"}` 声明**就地**换成 MediaRef receipt,返回改写后
// 的值与一串给人看的拒绝原因。拒绝**绝不**弄废这次运行:一个算对了答案、顺手把文件名写错的函数,
// 仍然是算对了答案。
func Collect(ctx context.Context, up ArtifactUploader, outDir string, source Source, v any) (any, []string) {
	if up == nil || outDir == "" || v == nil {
		return v, nil
	}
	c := &artifactCollector{ctx: ctx, up: up, outDir: outDir, source: source}
	return c.walk(v), c.notes
}

type artifactCollector struct {
	ctx    context.Context
	up     ArtifactUploader
	outDir string
	source Source
	n      int
	notes  []string
}

func (c *artifactCollector) walk(v any) any {
	switch x := v.(type) {
	case map[string]any:
		if rel, ok := x[MediaKey].(string); ok {
			if receipt := c.collect(rel); receipt != nil {
				return receipt
			}
			return x // uncollectable: leave the declaration untouched / 采不了就原样留着
		}
		out := make(map[string]any, len(x))
		for k, val := range x {
			out[k] = c.walk(val)
		}
		return out
	case []any:
		out := make([]any, len(x))
		for i, val := range x {
			out[i] = c.walk(val)
		}
		return out
	default:
		return v
	}
}

// collect turns one declaration into a receipt, or nil with a logged reason.
//
// collect 把一条声明变成一份 receipt,或返回 nil 并记下原因。
func (c *artifactCollector) collect(rel string) map[string]any {
	rel = strings.TrimSpace(rel)
	if rel == "" {
		return nil
	}
	if c.n >= maxArtifacts {
		c.note("%s: skipped, this run already produced the maximum of %d artifacts", rel, maxArtifacts)
		return nil
	}
	abs := filepath.Join(c.outDir, rel)
	// The declaration comes from USER CODE. `../../.ssh/id_rsa` is not a hypothetical — it is a
	// thing a function will eventually say, by accident or otherwise, so the check is fail-closed
	// and happens before anything is opened.
	// 声明来自**用户代码**。`../../.ssh/id_rsa` 不是假想——它是函数迟早会说出口的东西(无心或有意),
	// 故此检查 fail-closed,且发生在打开任何东西之前。
	if !fspathpkg.Inside(c.outDir, abs) {
		c.note("%s: refused, artifact paths must stay inside the run's output directory", rel)
		return nil
	}
	st, err := os.Stat(abs)
	if err != nil || st.IsDir() {
		c.note("%s: declared but not found in the run's output directory", rel)
		return nil
	}
	if st.Size() > artifactMaxBytes {
		c.note("%s: skipped, %d bytes exceeds the %d-byte artifact cap", rel, st.Size(), int64(artifactMaxBytes))
		return nil
	}
	data, err := os.ReadFile(abs)
	if err != nil || len(data) == 0 {
		c.note("%s: unreadable or empty", rel)
		return nil
	}
	// Sniff the CONTENT: a file named .png that is actually a 200MB core dump must not become an
	// image attachment on the strength of its name.
	// 嗅**内容**:一个叫 .png、其实是 200MB core dump 的文件,不该凭名字变成一张图片附件。
	mime := http.DetectContentType(data)
	if i := strings.IndexByte(mime, ';'); i > 0 {
		mime = strings.TrimSpace(mime[:i])
	}
	if !artifactMimeAllowed(mime) {
		c.note("%s: skipped, %s is not a media type this app can render", rel, mime)
		return nil
	}
	// The collector already knows the producer (it is stamped on the receipt below), so the same
	// name rides ctx into the row's provenance column — one vocabulary, two places, never two lists.
	// 采集器本来就知道产地(下面盖在 receipt 上的就是它),故同一个名字经 ctx 进到行的溯源列——
	// **一套词表、两个去处**,绝不维护两份名单。
	att, err := c.up.Upload(reqctxpkg.SetMediaSource(c.ctx, string(c.source)), filepath.Base(rel), mime, data)
	if err != nil {
		c.note("%s: could not be saved (%v)", rel, err)
		return nil
	}
	c.n++
	return map[string]any{
		mediarefpkg.Key: att.ID,
		"filename":      att.Filename,
		"mime":          att.MimeType,
		"sizeBytes":     att.SizeBytes,
		"source":        string(c.source),
	}
}

func (c *artifactCollector) note(format string, args ...any) {
	c.notes = append(c.notes, "artifact "+fmt.Sprintf(format, args...))
}
