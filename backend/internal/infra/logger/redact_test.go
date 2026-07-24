package logger

import (
	"bytes"
	"strings"
	"testing"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

// capture builds a logger whose only sink is an in-memory buffer, wrapped by the SAME redaction
// floor production uses. 用同一道生产脱敏底座包一个内存 sink。
func capture() (*zap.Logger, *bytes.Buffer) {
	buf := &bytes.Buffer{}
	ec := zap.NewProductionEncoderConfig()
	core := zapcore.NewCore(zapcore.NewJSONEncoder(ec), zapcore.AddSync(buf), zapcore.DebugLevel)
	return zap.New(redactCore{Core: core}), buf
}

// TestRedaction_NeverLeaksContentOrCredentials is the WRK-078 §3.3 #10 floor: a sensitive key's
// value must not reach the sink — and the sink here stands in for BOTH stderr and the rotating
// support log users are asked to send in.
//
// §3.3 #10 底线:敏感键的值不得抵达 sink——本 sink 同时代表 stderr 与「请把日志发我」的轮转文件。
func TestRedaction_NeverLeaksContentOrCredentials(t *testing.T) {
	cases := []struct {
		key    string
		secret string
	}{
		{"prompt", "PROMPT-SECRET-BODY"},
		{"system_prompt", "SYSTEM-SECRET"},
		{"messages", "MESSAGES-SECRET"},
		{"content", "CONTENT-SECRET"},
		{"transcript", "TRANSCRIPT-SECRET"},
		{"summary", "SUMMARY-SECRET"},
		{"args", "ARGS-SECRET"},
		{"tool_result", "TOOLRESULT-SECRET"},
		{"image_url", "data:image/png;base64,IMGSECRET"},
		{"input_audio", "AUDIO-SECRET"},
		{"signed_url", "https://example.test/o?sig=SIGSECRET"},
		{"fetch_path", "/v1/media/leases/mls_1/content?token=TOKSECRET"},
		{"upstream_body", "UPSTREAM-SECRET"},
		{"api_key", "sk-KEYSECRET"},
		{"gateway_api_key", "sk-COMPOUNDSECRET"}, // suffix rule 后缀规则
		{"refresh_token", "TOKENSECRET"},         // suffix rule 后缀规则
		{"filename", "私密报告.pdf"},
		{"query", "QUERY-SECRET"},
	}
	for _, tc := range cases {
		log, buf := capture()
		log.Info("event", zap.String(tc.key, tc.secret))
		out := buf.String()
		if strings.Contains(out, tc.secret) {
			t.Errorf("key %q leaked its value into the log sink: %s", tc.key, out)
		}
		if !strings.Contains(out, redactedValue) {
			t.Errorf("key %q must be replaced by %s, got: %s", tc.key, redactedValue, out)
		}
	}
}

// A sensitive key carrying a STRUCT must be replaced wholesale — an encoder would otherwise walk
// into it happily. 敏感键携带结构体时必须整体替换,否则编码器会径直展开它。
func TestRedaction_ReplacesStructuredValuesWholesale(t *testing.T) {
	log, buf := capture()
	log.Info("event", zap.Any("body", map[string]any{"nested": "NESTED-SECRET"}))
	if out := buf.String(); strings.Contains(out, "NESTED-SECRET") {
		t.Fatalf("a struct under a sensitive key leaked its interior: %s", out)
	}
}

// Redaction must survive `With` — a logger derived once at construction must not become a
// permanent bypass. 脱敏必须挺过 With:构造时派生一次的 logger 不得成为长期旁路。
func TestRedaction_SurvivesWith(t *testing.T) {
	log, buf := capture()
	log.With(zap.String("prompt", "WITH-SECRET")).Info("event")
	out := buf.String()
	if strings.Contains(out, "WITH-SECRET") {
		t.Fatalf("With() bypassed redaction: %s", out)
	}
	if !strings.Contains(out, redactedValue) {
		t.Fatalf("With() must still redact, got: %s", out)
	}
}

// Non-sensitive diagnostics must survive intact — an over-broad floor that eats ids and counts
// would just get switched off. 非敏感诊断必须原样保留:过宽的底座会被人直接关掉。
func TestRedaction_KeepsOrdinaryDiagnostics(t *testing.T) {
	log, buf := capture()
	log.Info("event",
		zap.String("conversation_id", "cv_123"),
		zap.String("attachment_id", "att_9"),
		zap.Int("step", 4),
		zap.String("route", "text"),
	)
	out := buf.String()
	for _, want := range []string{"cv_123", "att_9", `"step":4`, "text"} {
		if !strings.Contains(out, want) {
			t.Errorf("ordinary diagnostic %q must survive redaction, got: %s", want, out)
		}
	}
}
