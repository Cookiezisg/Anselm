package pagination

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"testing"
	"time"
)

func TestEncodeDecodeRoundTrip(t *testing.T) {
	in := Cursor{Key: time.Now().UTC().Truncate(time.Second), ID: "wf_abc"}
	enc, err := EncodeCursor(in)
	if err != nil {
		t.Fatalf("encode: %v", err)
	}
	if enc == "" {
		t.Fatal("non-nil cursor encoded to empty string")
	}
	var out Cursor
	if err := DecodeCursor(enc, &out); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if !out.Key.Equal(in.Key) || out.ID != in.ID {
		t.Fatalf("round trip = %+v, want %+v", out, in)
	}
}

func TestEncodeNilIsEmpty(t *testing.T) {
	if enc, err := EncodeCursor(nil); err != nil || enc != "" {
		t.Fatalf("EncodeCursor(nil) = %q,%v, want \"\",nil", enc, err)
	}
}

func TestDecodeEmptyIsNoop(t *testing.T) {
	var c Cursor
	if err := DecodeCursor("", &c); err != nil {
		t.Fatalf("DecodeCursor(\"\") = %v, want nil", err)
	}
}

func TestDecodeMalformed(t *testing.T) {
	var c Cursor
	if err := DecodeCursor("!!!not base64!!!", &c); !errors.Is(err, ErrMalformedCursor) {
		t.Fatalf("DecodeCursor(malformed) = %v, want ErrMalformedCursor", err)
	}
}

func TestDecodeAcceptsEquivalentPaddedBase64URL(t *testing.T) {
	in := Cursor{Key: time.Date(2026, 8, 4, 13, 10, 24, 0, time.UTC), ID: "cv_abc"}
	raw, err := json.Marshal(in)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	rawCursor := base64.RawURLEncoding.EncodeToString(raw)
	paddedCursor := base64.URLEncoding.EncodeToString(raw)
	if rawCursor == paddedCursor {
		t.Fatalf("test cursor unexpectedly needs no padding: %q", rawCursor)
	}

	for _, cursor := range []string{rawCursor, paddedCursor} {
		var got Cursor
		if err := DecodeCursor(cursor, &got); err != nil {
			t.Fatalf("DecodeCursor(%q) = %v, want nil", cursor, err)
		}
		if !got.Key.Equal(in.Key) || got.ID != in.ID {
			t.Fatalf("DecodeCursor(%q) = %+v, want %+v", cursor, got, in)
		}
	}
}
