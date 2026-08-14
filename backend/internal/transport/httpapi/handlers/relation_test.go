package handlers

import (
	"errors"
	"net/url"
	"testing"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

func TestParseNeighborhoodDepth(t *testing.T) {
	t.Run("absent uses the documented default", func(t *testing.T) {
		got, err := parseNeighborhoodDepth(url.Values{})
		if err != nil || got != 2 {
			t.Fatalf("got depth=%d err=%v, want 2/nil", got, err)
		}
	})

	for _, raw := range []string{"1", "2", "3", "-1"} {
		t.Run("accepts "+raw, func(t *testing.T) {
			got, err := parseNeighborhoodDepth(url.Values{"depth": {raw}})
			if err != nil {
				t.Fatalf("depth=%q: unexpected error: %v", raw, err)
			}
			if raw == "-1" && got != -1 {
				t.Fatalf("depth=%q: got %d", raw, got)
			}
		})
	}

	for _, raw := range []string{"", "foo", "1.5", " 2"} {
		t.Run("rejects "+raw, func(t *testing.T) {
			_, err := parseNeighborhoodDepth(url.Values{"depth": {raw}})
			if !errors.Is(err, errorspkg.ErrInvalidRequest) {
				t.Fatalf("depth=%q: want ErrInvalidRequest, got %v", raw, err)
			}
			var de *errorspkg.Error
			if !errors.As(err, &de) || de.Details["param"] != "depth" || de.Details["got"] != raw {
				t.Fatalf("depth=%q: details=%+v", raw, de)
			}
		})
	}

	if _, err := parseNeighborhoodDepth(url.Values{"depth": {"1", "2"}}); !errors.Is(err, errorspkg.ErrInvalidRequest) {
		t.Fatalf("repeated depth must reject, got %v", err)
	}
}
