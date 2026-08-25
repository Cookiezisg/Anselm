package tool

import (
	"encoding/json"
	"reflect"
	"testing"
)

func TestObjectMapAcceptsNativeAndStringifiedObject(t *testing.T) {
	want := ObjectMap{"points": float64(6), "label": "probe"}
	for _, raw := range []string{
		`{"points":6,"label":"probe"}`,
		`"{\"points\":6,\"label\":\"probe\"}"`,
	} {
		var got ObjectMap
		if err := json.Unmarshal([]byte(raw), &got); err != nil {
			t.Fatalf("object encoding %s should be accepted: %v", raw, err)
		}
		if !reflect.DeepEqual(got, want) {
			t.Fatalf("decoded %s = %#v, want %#v", raw, got, want)
		}
	}
}

func TestObjectMapRejectsNonObjectValues(t *testing.T) {
	for _, raw := range []string{
		`["points",6]`,
		`6`,
		`"not-json"`,
		`"[\"points\",6]"`,
	} {
		var got ObjectMap
		if err := json.Unmarshal([]byte(raw), &got); err == nil {
			t.Errorf("non-object value %s should be rejected, got %#v", raw, got)
		}
	}
}
