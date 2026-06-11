package response

import (
	"errors"
	"net/http/httptest"
	"testing"

	errorspkg "github.com/sunweilin/forgify/backend/internal/pkg/errors"
)

func TestParsePageDefault(t *testing.T) {
	p, err := ParsePage(httptest.NewRequest("GET", "/x", nil))
	if err != nil || p.Limit != DefaultLimit || p.Cursor != "" {
		t.Errorf("default = %+v, err=%v", p, err)
	}
}

func TestParsePageCursorAndLimit(t *testing.T) {
	p, err := ParsePage(httptest.NewRequest("GET", "/x?cursor=abc&limit=10", nil))
	if err != nil || p.Cursor != "abc" || p.Limit != 10 {
		t.Errorf("parsed = %+v, err=%v", p, err)
	}
}

func TestParsePageClampsToMax(t *testing.T) {
	p, _ := ParsePage(httptest.NewRequest("GET", "/x?limit=99999", nil))
	if p.Limit != MaxLimit {
		t.Errorf("limit = %d, want clamped to %d", p.Limit, MaxLimit)
	}
}

func TestParsePageMalformedLimit(t *testing.T) {
	for _, bad := range []string{"abc", "0", "-5"} {
		_, err := ParsePage(httptest.NewRequest("GET", "/x?limit="+bad, nil))
		if !errors.Is(err, errorspkg.ErrInvalidRequest) {
			t.Errorf("limit=%q → err=%v, want ErrInvalidRequest", bad, err)
		}
	}
}
