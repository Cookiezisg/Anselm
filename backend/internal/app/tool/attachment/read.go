package attachment

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"strings"

	attachmentapp "github.com/sunweilin/anselm/backend/internal/app/attachment"
	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

const (
	readAttachmentDefaultLimitChars = 80_000
	readAttachmentMaxLimitChars     = 120_000
	readAttachmentAutoIndexChars    = 40_000
	readAttachmentIndexChunkChars   = 8_000
	readAttachmentIndexMaxChunks    = 200
	readAttachmentIndexPreviewChars = 160

	readAttachmentDefaultSearchContextChars = 800
	readAttachmentMaxSearchContextChars     = 2_000
	readAttachmentDefaultSearchMatches      = 5
	readAttachmentMaxSearchMatches          = 10
	readAttachmentMaxQueryChars             = 512
)

const readAttachmentDescription = `Read an uploaded attachment by its opaque id. The required argument key is exactly "id" (for example {"id":"att_..."}); do not use "attachmentId". Large text/docs: index:boolean; offset,limitChars,contextChars,maxMatches:integer; query:string. Emit JSON types (never quote booleans/integers). Find ids via list_attachments. Text and document files (PDF/Office) are text-extracted; index:true returns a compact chunk/page map, while offset/limitChars page bounded slices and query returns bounded literal-match snippets. Images/audio/video return descriptors; use inspect_media for bounded media evidence.`

var readAttachmentSchema = json.RawMessage(`{
	"type": "object",
	"required": ["id"],
	"properties": {
		"id": {"type": "string", "description": "Required opaque uploaded attachment id. Use this exact key: id, not attachmentId."},
		"index": {"type": "boolean", "description": "When true for text/document attachments, return a compact chunk/page index with offsets and previews instead of body text. Use this before reading a large file; pass offset with nextOffset to continue the index."},
		"offset": {"type": "integer", "minimum": 0, "description": "Character offset into the extracted text page or index. Use nextOffset from a previous result to continue."},
		"limitChars": {"type": "integer", "minimum": 1, "maximum": 120000, "description": "Maximum characters to return in page mode. Defaults to 80000; capped at 120000."},
		"query": {"type": "string", "maxLength": 512, "description": "Optional literal text query. When present, returns bounded snippets around matches instead of a page."},
		"contextChars": {"type": "integer", "minimum": 1, "maximum": 2000, "description": "Characters of surrounding context on each side of a query match. Defaults to 800; capped at 2000."},
		"maxMatches": {"type": "integer", "minimum": 1, "maximum": 10, "description": "Maximum query matches to return. Defaults to 5; capped at 10."}
	}
}`)

// ReadAttachment implements the read_attachment system tool.
//
// ReadAttachment 是 read_attachment 系统工具的实现。
type ReadAttachment struct {
	svc       *attachmentapp.Service
	textCache TextCache
}

func (t *ReadAttachment) Name() string                { return "read_attachment" }
func (t *ReadAttachment) Description() string         { return readAttachmentDescription }
func (t *ReadAttachment) Parameters() json.RawMessage { return readAttachmentSchema }

func (t *ReadAttachment) ValidateInput(args json.RawMessage) error {
	var a readArgs
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("read_attachment: bad args: %w", err)
	}
	if strings.TrimSpace(a.ID) == "" {
		return ErrIDRequired
	}
	if a.Offset < 0 {
		return fmt.Errorf("read_attachment: offset must be >= 0")
	}
	if a.LimitChars < 0 || a.LimitChars > readAttachmentMaxLimitChars {
		return fmt.Errorf("read_attachment: limitChars must be 0/default or between 1 and %d", readAttachmentMaxLimitChars)
	}
	if len([]rune(strings.TrimSpace(a.Query))) > readAttachmentMaxQueryChars {
		return fmt.Errorf("read_attachment: query must be <= %d characters", readAttachmentMaxQueryChars)
	}
	if a.ContextChars < 0 || a.ContextChars > readAttachmentMaxSearchContextChars {
		return fmt.Errorf("read_attachment: contextChars must be 0/default or between 1 and %d", readAttachmentMaxSearchContextChars)
	}
	if a.MaxMatches < 0 || a.MaxMatches > readAttachmentMaxSearchMatches {
		return fmt.Errorf("read_attachment: maxMatches must be 0/default or between 1 and %d", readAttachmentMaxSearchMatches)
	}
	return nil
}

func (t *ReadAttachment) Execute(ctx context.Context, argsJSON string) (string, error) {
	var a readArgs
	if err := json.Unmarshal([]byte(argsJSON), &a); err != nil {
		return "", fmt.Errorf("read_attachment: %w", err)
	}
	if err := t.ValidateInput([]byte(argsJSON)); err != nil {
		return "", err
	}
	meta, err := t.svc.Get(ctx, a.ID)
	if err != nil {
		if errors.Is(err, attachmentdomain.ErrNotFound) {
			return fmt.Sprintf("Attachment %q not found. Call list_attachments to see available files.", a.ID), nil
		}
		return "", err
	}
	// Binary/non-text kinds have no useful tool-result text — return a descriptor instead of
	// dumping bytes (a tool result is a plain string back to the model). Text + document kinds go
	// through ToContentParts (the shared text-extraction engine) with NativeDocs off so PDFs/Office
	// are extracted to text rather than handed over as a raw file part the model can't read here.
	//
	// 二进制/非文本类无可用工具结果文本——返回描述符而非倾倒字节（工具结果是回给模型的纯串）。
	// text + document 类走 ToContentParts（共享文本抽取引擎），关 NativeDocs 使 PDF/Office 抽成
	// 文本、而非递交模型在此读不了的原始 file part。
	switch meta.Kind {
	case attachmentdomain.KindText, attachmentdomain.KindDocument:
		text, err := attachmentText(ctx, t.svc, t.textCache, meta)
		if err != nil {
			return "", err
		}
		if a.Index {
			return indexAttachmentText(meta, text, a.Offset), nil
		}
		if strings.TrimSpace(a.Query) != "" {
			return searchAttachmentText(text, a.Query, normalizeSearchContext(a.ContextChars), normalizeSearchMatches(a.MaxMatches)), nil
		}
		if shouldAutoIndexAttachmentText(a, text) {
			return indexAttachmentText(meta, text, 0), nil
		}
		return pageAttachmentText(text, a.Offset, normalizeReadLimit(a.LimitChars)), nil
	case attachmentdomain.KindImage, attachmentdomain.KindAudio, attachmentdomain.KindVideo:
		return mediaReadDescriptor(meta), nil
	default: // other binary — content isn't text-extractable here
		return fmt.Sprintf(
			"Attachment %q (id %s, %s, %d bytes, kind %s): this tool cannot turn its content into text. No extractor is available for this binary kind.",
			meta.Filename, meta.ID, meta.MimeType, meta.SizeBytes, meta.Kind), nil
	}
}

func mediaReadDescriptor(meta *attachmentdomain.Attachment) string {
	base := fmt.Sprintf("Attachment %q (id %s, %s, %d bytes, kind %s): read_attachment cannot turn this media into text or dump raw bytes into the conversation.",
		meta.Filename, meta.ID, meta.MimeType, meta.SizeBytes, meta.Kind)
	switch meta.Kind {
	case attachmentdomain.KindImage:
		return base + " Use inspect_media with a specific question for bounded visual evidence; if the current model route has no vision support, ask the user to describe it or switch to a vision-capable route."
	case attachmentdomain.KindAudio, attachmentdomain.KindVideo:
		return base + " Use inspect_media with a specific question and optional startMs/endMs to get a bounded local metadata capsule. Rich transcript, OCR, scenes, and keyframes are not available from read_attachment."
	default:
		return base
	}
}

func attachmentText(ctx context.Context, svc *attachmentapp.Service, cache TextCache, meta *attachmentdomain.Attachment) (string, error) {
	if meta.Kind == attachmentdomain.KindDocument && cache != nil {
		return cache.DocumentText(ctx, meta.ID, func(extractCtx context.Context, _ *attachmentdomain.Attachment, _ []byte) (string, error) {
			return uncachedAttachmentText(extractCtx, svc, meta.ID)
		})
	}
	return uncachedAttachmentText(ctx, svc, meta.ID)
}

func uncachedAttachmentText(ctx context.Context, svc *attachmentapp.Service, attachmentID string) (string, error) {
	parts, err := svc.ToContentParts(ctx, []string{attachmentID}, attachmentapp.Capabilities{Vision: false, NativeDocs: false})
	if err != nil {
		return "", err
	}
	return flattenText(parts), nil
}

type readArgs struct {
	ID           string `json:"id"`
	Index        bool   `json:"index"`
	Offset       int    `json:"offset"`
	LimitChars   int    `json:"limitChars"`
	Query        string `json:"query"`
	ContextChars int    `json:"contextChars"`
	MaxMatches   int    `json:"maxMatches"`
}

// UnmarshalJSON tolerates the stringified scalar values emitted by some managed tool callers
// while keeping the public schema strongly typed. The attachmentId alias is accepted only as a
// compatibility seam for hosted callers that copy the inspect_media naming; the canonical wire
// key remains id and is called out explicitly in the schema and description.
func (a *readArgs) UnmarshalJSON(data []byte) error {
	var raw struct {
		ID           string          `json:"id"`
		AttachmentID string          `json:"attachmentId"`
		Index        json.RawMessage `json:"index"`
		Offset       json.RawMessage `json:"offset"`
		LimitChars   json.RawMessage `json:"limitChars"`
		Query        string          `json:"query"`
		ContextChars json.RawMessage `json:"contextChars"`
		MaxMatches   json.RawMessage `json:"maxMatches"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	index, err := decodeLooseBool(raw.Index)
	if err != nil {
		return fmt.Errorf("index: %w", err)
	}
	offset, err := decodeLooseInt(raw.Offset)
	if err != nil {
		return fmt.Errorf("offset: %w", err)
	}
	limitChars, err := decodeLooseInt(raw.LimitChars)
	if err != nil {
		return fmt.Errorf("limitChars: %w", err)
	}
	contextChars, err := decodeLooseInt(raw.ContextChars)
	if err != nil {
		return fmt.Errorf("contextChars: %w", err)
	}
	maxMatches, err := decodeLooseInt(raw.MaxMatches)
	if err != nil {
		return fmt.Errorf("maxMatches: %w", err)
	}
	id := strings.TrimSpace(raw.ID)
	if id == "" {
		id = strings.TrimSpace(raw.AttachmentID)
	}
	*a = readArgs{
		ID:           id,
		Index:        index,
		Offset:       offset,
		LimitChars:   limitChars,
		Query:        raw.Query,
		ContextChars: contextChars,
		MaxMatches:   maxMatches,
	}
	return nil
}

func decodeLooseBool(raw json.RawMessage) (bool, error) {
	if len(raw) == 0 || string(raw) == "null" {
		return false, nil
	}
	var value bool
	if err := json.Unmarshal(raw, &value); err == nil {
		return value, nil
	}
	var text string
	if err := json.Unmarshal(raw, &text); err != nil {
		return false, fmt.Errorf("must be boolean, got %s", string(raw))
	}
	value, err := strconv.ParseBool(strings.TrimSpace(text))
	if err != nil {
		return false, fmt.Errorf("must be boolean, got %q", text)
	}
	return value, nil
}

func decodeLooseInt(raw json.RawMessage) (int, error) {
	if len(raw) == 0 || string(raw) == "null" {
		return 0, nil
	}
	var value int
	if err := json.Unmarshal(raw, &value); err == nil {
		return value, nil
	}
	var text string
	if err := json.Unmarshal(raw, &text); err != nil {
		return 0, fmt.Errorf("must be integer, got %s", string(raw))
	}
	value, err := strconv.Atoi(strings.TrimSpace(text))
	if err != nil {
		return 0, fmt.Errorf("must be integer, got %q", text)
	}
	return value, nil
}

// flattenText joins the text of every text part into one tool-result string. ToContentParts on a
// text/document attachment yields exactly text parts (inline text, extracted text, or a degrade
// note); a non-text part would have no string body, so it is skipped.
//
// flattenText 把每个 text part 的文本拼成一个工具结果串。text/document 附件经 ToContentParts 恰得
// text part（内联文本、抽取文本或降级提示）；非 text part 无串体，跳过。
func flattenText(parts []llminfra.ContentPart) string {
	var sb strings.Builder
	for _, p := range parts {
		if p.Type == llminfra.PartText {
			if sb.Len() > 0 {
				sb.WriteString("\n")
			}
			sb.WriteString(p.Text)
		}
	}
	return sb.String()
}

func normalizeReadLimit(limit int) int {
	if limit <= 0 {
		return readAttachmentDefaultLimitChars
	}
	if limit > readAttachmentMaxLimitChars {
		return readAttachmentMaxLimitChars
	}
	return limit
}

func shouldAutoIndexAttachmentText(a readArgs, text string) bool {
	return !a.Index &&
		a.Offset == 0 &&
		a.LimitChars == 0 &&
		strings.TrimSpace(a.Query) == "" &&
		len([]rune(text)) > readAttachmentAutoIndexChars
}

func normalizeSearchContext(contextChars int) int {
	if contextChars <= 0 {
		return readAttachmentDefaultSearchContextChars
	}
	if contextChars > readAttachmentMaxSearchContextChars {
		return readAttachmentMaxSearchContextChars
	}
	return contextChars
}

func normalizeSearchMatches(maxMatches int) int {
	if maxMatches <= 0 {
		return readAttachmentDefaultSearchMatches
	}
	if maxMatches > readAttachmentMaxSearchMatches {
		return readAttachmentMaxSearchMatches
	}
	return maxMatches
}

func pageAttachmentText(text string, offset, limit int) string {
	runes := []rune(text)
	total := len(runes)
	if offset >= total {
		return fmt.Sprintf("No attachment text at offset %d. totalChars=%d. Re-read from a smaller offset or call list_attachments if you may have the wrong id.", offset, total)
	}
	end := offset + limit
	if end > total {
		end = total
	}
	body := string(runes[offset:end])
	if offset == 0 && end == total {
		return body
	}
	next := ""
	if end < total {
		next = fmt.Sprintf(" nextOffset=%d", end)
	}
	return fmt.Sprintf("%s\n\n[read_attachment pagination: offset=%d chars=%d totalChars=%d%s]", body, offset, end-offset, total, next)
}

type attachmentTextIndex struct {
	AttachmentID string                `json:"attachmentId"`
	Filename     string                `json:"filename"`
	Kind         string                `json:"kind"`
	TotalChars   int                   `json:"totalChars"`
	Offset       int                   `json:"offset"`
	ChunkChars   int                   `json:"chunkChars"`
	Chunks       []attachmentTextChunk `json:"chunks"`
	Truncated    bool                  `json:"truncated"`
	NextOffset   int                   `json:"nextOffset,omitempty"`
	Usage        string                `json:"usage"`
}

type attachmentTextChunk struct {
	Index     int    `json:"index"`
	Offset    int    `json:"offset"`
	Chars     int    `json:"chars"`
	PageStart int    `json:"pageStart,omitempty"`
	PageEnd   int    `json:"pageEnd,omitempty"`
	Preview   string `json:"preview"`
}

type textRegion struct {
	start int
	end   int
	page  int
}

func indexAttachmentText(meta *attachmentdomain.Attachment, text string, offset int) string {
	runes := []rune(text)
	total := len(runes)
	if offset < 0 {
		offset = 0
	}
	if offset > total {
		offset = total
	}
	chunks, truncated, nextOffset := chunkAttachmentText(text, offset, readAttachmentIndexChunkChars, readAttachmentIndexMaxChunks)
	out := attachmentTextIndex{
		AttachmentID: meta.ID,
		Filename:     meta.Filename,
		Kind:         meta.Kind,
		TotalChars:   total,
		Offset:       offset,
		ChunkChars:   readAttachmentIndexChunkChars,
		Chunks:       chunks,
		Truncated:    truncated,
		NextOffset:   nextOffset,
		Usage:        "Pick a chunk offset and call read_attachment with offset+limitChars, or use query for literal search. Index output intentionally omits full body text.",
	}
	raw, err := json.Marshal(out)
	if err != nil {
		return fmt.Sprintf("read_attachment index unavailable for %q: %v", meta.Filename, err)
	}
	return string(raw)
}

func chunkAttachmentText(text string, offset, chunkChars, maxChunks int) ([]attachmentTextChunk, bool, int) {
	if chunkChars <= 0 {
		chunkChars = readAttachmentIndexChunkChars
	}
	if maxChunks <= 0 {
		maxChunks = readAttachmentIndexMaxChunks
	}
	runes := []rune(text)
	total := len(runes)
	if offset < 0 {
		offset = 0
	}
	if offset > total {
		offset = total
	}
	regions := pageTextRegions(text)
	if len(regions) == 0 {
		regions = []textRegion{{start: 0, end: total}}
	}
	chunks := make([]attachmentTextChunk, 0, min(maxChunks, len(regions)))
	for _, region := range regions {
		if region.end <= offset {
			continue
		}
		start := region.start
		if start < offset {
			start = offset
		}
		for ; start < region.end; start += chunkChars {
			if len(chunks) >= maxChunks {
				return chunks, true, start
			}
			end := start + chunkChars
			if end > region.end {
				end = region.end
			}
			chunk := attachmentTextChunk{
				Index:   len(chunks) + 1,
				Offset:  start,
				Chars:   end - start,
				Preview: chunkPreview(runes[start:end]),
			}
			if region.page > 0 {
				chunk.PageStart = region.page
				chunk.PageEnd = region.page
			}
			chunks = append(chunks, chunk)
		}
	}
	return chunks, false, 0
}

func pageTextRegions(text string) []textRegion {
	total := len([]rune(text))
	lines := strings.SplitAfter(text, "\n")
	regions := []textRegion{}
	offset := 0
	currentPage := 0
	currentStart := 0
	seenPage := false
	for _, line := range lines {
		lineRunes := len([]rune(line))
		if page, ok := parsePageMarker(line); ok {
			if seenPage || offset > currentStart {
				regions = append(regions, textRegion{start: currentStart, end: offset, page: currentPage})
			}
			seenPage = true
			currentPage = page
			currentStart = offset
		}
		offset += lineRunes
	}
	if seenPage {
		regions = append(regions, textRegion{start: currentStart, end: total, page: currentPage})
		return regions
	}
	return nil
}

func parsePageMarker(line string) (int, bool) {
	trimmed := strings.TrimSpace(line)
	if !strings.HasPrefix(trimmed, "# Page ") {
		return 0, false
	}
	rest := strings.TrimSpace(strings.TrimPrefix(trimmed, "# Page "))
	page := 0
	for _, r := range rest {
		if r < '0' || r > '9' {
			break
		}
		page = page*10 + int(r-'0')
	}
	return page, page > 0
}

func chunkPreview(runes []rune) string {
	text := strings.TrimSpace(string(runes))
	if text == "" {
		return ""
	}
	lines := strings.Split(text, "\n")
	preview := ""
	for _, line := range lines {
		if trimmed := strings.TrimSpace(line); trimmed != "" {
			preview = strings.Join(strings.Fields(trimmed), " ")
			break
		}
	}
	pr := []rune(preview)
	if len(pr) <= readAttachmentIndexPreviewChars {
		return preview
	}
	return string(pr[:readAttachmentIndexPreviewChars]) + "…"
}

type textMatch struct {
	start int
	end   int
}

func searchAttachmentText(text, query string, contextChars, maxMatches int) string {
	query = strings.TrimSpace(query)
	runes := []rune(text)
	totalChars := len(runes)
	matches, totalMatches := findLiteralRuneMatches(runes, query, maxMatches)
	if totalMatches == 0 {
		return fmt.Sprintf("No matches for query %q in attachment text. totalChars=%d. Try a different query or read_attachment with offset/limitChars to page through the text.", query, totalChars)
	}
	var sb strings.Builder
	fmt.Fprintf(&sb, "read_attachment search: query=%q matches=%d returned=%d totalChars=%d contextChars=%d", query, totalMatches, len(matches), totalChars, contextChars)
	for i, m := range matches {
		start := m.start - contextChars
		if start < 0 {
			start = 0
		}
		end := m.end + contextChars
		if end > totalChars {
			end = totalChars
		}
		prefix := ""
		if start > 0 {
			prefix = "…"
		}
		suffix := ""
		if end < totalChars {
			suffix = "…"
		}
		fmt.Fprintf(&sb, "\n\n[match %d offset=%d chars=%d]\n%s%s%s", i+1, m.start, end-start, prefix, string(runes[start:end]), suffix)
	}
	if totalMatches > len(matches) {
		fmt.Fprintf(&sb, "\n\n[read_attachment search truncated: returned=%d of %d matches; narrow query or raise maxMatches up to %d]", len(matches), totalMatches, readAttachmentMaxSearchMatches)
	}
	return sb.String()
}

func findLiteralRuneMatches(haystack []rune, query string, maxMatches int) ([]textMatch, int) {
	needle := []rune(strings.ToLower(strings.TrimSpace(query)))
	if len(needle) == 0 || len(haystack) == 0 || len(needle) > len(haystack) {
		return nil, 0
	}
	lowerHaystack := []rune(strings.ToLower(string(haystack)))
	matches := make([]textMatch, 0, maxMatches)
	total := 0
	for i := 0; i <= len(lowerHaystack)-len(needle); {
		if hasRunePrefix(lowerHaystack[i:], needle) {
			total++
			if len(matches) < maxMatches {
				matches = append(matches, textMatch{start: i, end: i + len(needle)})
			}
			i += len(needle)
			continue
		}
		i++
	}
	return matches, total
}

func hasRunePrefix(haystack, prefix []rune) bool {
	if len(prefix) > len(haystack) {
		return false
	}
	for i, r := range prefix {
		if haystack[i] != r {
			return false
		}
	}
	return true
}
