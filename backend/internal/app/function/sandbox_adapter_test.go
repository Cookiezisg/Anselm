package function

import "testing"

func TestSplitFunctionStderr(t *testing.T) {
	const traceback = "Traceback (most recent call last):\n  File \"main.py\", line 3\nRuntimeError: boom"
	cases := []struct {
		name      string
		raw       string
		wantLogs  string
		wantError string
	}{
		{
			name:      "print prefix and traceback",
			raw:       "before\nafter\n" + traceback,
			wantLogs:  "before\nafter",
			wantError: traceback,
		},
		{
			name:      "traceback only",
			raw:       traceback,
			wantError: traceback,
		},
		{
			name:      "non traceback stderr stays error",
			raw:       "python failed before traceback",
			wantError: "python failed before traceback",
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			logs, errMsg := splitFunctionStderr(tc.raw)
			if logs != tc.wantLogs || errMsg != tc.wantError {
				t.Fatalf("splitFunctionStderr() = logs=%q error=%q, want logs=%q error=%q", logs, errMsg, tc.wantLogs, tc.wantError)
			}
		})
	}
}
