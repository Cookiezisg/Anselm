package trigger

import "testing"

func TestDecodeSearchTriggersQuery(t *testing.T) {
	tests := []struct {
		name string
		args string
		want string
	}{
		{name: "canonical query", args: `{"query":"webhookpulse"}`, want: "webhookpulse"},
		{name: "hosted model pattern alias", args: `{"pattern":"webhookpulse"}`, want: "webhookpulse"},
		{name: "canonical query wins", args: `{"query":"cron","pattern":"webhook"}`, want: "cron"},
		{name: "empty query remains list all", args: `{}`, want: ""},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := decodeSearchTriggersQuery(tt.args)
			if err != nil {
				t.Fatalf("decodeSearchTriggersQuery() error = %v", err)
			}
			if got != tt.want {
				t.Fatalf("decodeSearchTriggersQuery() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestDecodeSearchTriggersQueryRejectsNonStringAlias(t *testing.T) {
	if _, err := decodeSearchTriggersQuery(`{"pattern":123}`); err == nil {
		t.Fatal("pattern with a non-string value must fail instead of becoming an empty query")
	}
}
