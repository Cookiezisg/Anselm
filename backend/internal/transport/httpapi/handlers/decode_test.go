package handlers

import (
	"errors"
	"net/http/httptest"
	"strings"
	"testing"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

func TestDecodeJSONRejectsTrailingValues(t *testing.T) {
	for _, body := range []string{
		`{"name":"one"}{"name":"two"}`,
		`{"name":"one"} null`,
		`{"name":"one"} trailing`,
	} {
		t.Run(strings.ReplaceAll(body, " ", "_"), func(t *testing.T) {
			r := httptest.NewRequest("POST", "/", strings.NewReader(body))
			var got struct {
				Name string `json:"name"`
			}
			if err := decodeJSON(r, &got); !errors.Is(err, errorspkg.ErrInvalidRequest) {
				t.Fatalf("decodeJSON(%q) = %v, want INVALID_REQUEST", body, err)
			}
			if got.Name != "one" {
				t.Fatalf("first value was not decoded before trailing validation: %q", got.Name)
			}
		})
	}
}

func TestDecodeJSONAcceptsWhitespaceAfterValue(t *testing.T) {
	r := httptest.NewRequest("POST", "/", strings.NewReader("{\"name\":\"one\"}\n\t "))
	var got struct {
		Name string `json:"name"`
	}
	if err := decodeJSON(r, &got); err != nil {
		t.Fatalf("decodeJSON with trailing whitespace: %v", err)
	}
	if got.Name != "one" {
		t.Fatalf("name = %q, want one", got.Name)
	}
}

func TestDecodeJSONOptionalStillAllowsEmptyBody(t *testing.T) {
	r := httptest.NewRequest("POST", "/", strings.NewReader(""))
	var got map[string]any
	if err := decodeJSONOptional(r, &got); err != nil {
		t.Fatalf("empty optional body: %v", err)
	}
}
