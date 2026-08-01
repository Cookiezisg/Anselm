package loop

import (
	"regexp"
	"strings"
	"unicode"
)

const opaqueValuePlaceholder = "<opaque value omitted>"

var (
	// Entity ids are useful inside tool cards, but they are not useful prose. Keep the
	// prefixes explicit so ordinary snake_case words remain untouched.
	entityIDPattern     = regexp.MustCompile(`\b(?:ws|fn|hd|ag|wf|tr|cv|msg|blk|att|aki|hdenv|hdv|tp|doc|mem|todo|fr|act|sk)_[A-Za-z0-9]+\b`)
	isoTimestampPattern = regexp.MustCompile(`\b\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})\b`)
	longIntegerPattern  = regexp.MustCompile(`\b\d{10,}\b`)
	longHexPattern      = regexp.MustCompile(`\b[0-9a-fA-F]{32,}\b`)
)

// redactOpaqueMachineValues protects the user-facing assistant prose. Tool blocks remain
// untouched: their exact values are the audit/source-of-truth surface and are already rendered
// separately by the product.
func redactOpaqueMachineValues(text string) string {
	text = isoTimestampPattern.ReplaceAllString(text, opaqueValuePlaceholder)
	text = entityIDPattern.ReplaceAllString(text, opaqueValuePlaceholder)
	text = longIntegerPattern.ReplaceAllString(text, opaqueValuePlaceholder)
	return longHexPattern.ReplaceAllString(text, opaqueValuePlaceholder)
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

	runes := []rune(r.pending)
	cut := len(runes)
	for cut > 0 && isTokenContinuation(runes[cut-1]) {
		cut--
	}
	if cut == len(runes) {
		emitted := redactOpaqueMachineValues(r.pending)
		r.pending = ""
		return emitted
	}
	if cut == 0 {
		return ""
	}

	emitted := string(runes[:cut])
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

func isTokenContinuation(r rune) bool {
	return unicode.IsLetter(r) || unicode.IsDigit(r) || strings.ContainsRune("_:+./-=", r)
}
