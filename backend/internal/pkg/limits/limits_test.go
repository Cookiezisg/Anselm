package limits

import (
	"reflect"
	"testing"
)

// TestDefault_MatchesPreWiringConstants pins each Default() constant so the operative
// defaults can't drift silently.
//
// TestDefault_MatchesPreWiringConstants 钉住每个 Default() 常量，使生效默认值不致静默漂移。
func TestDefault_MatchesPreWiringConstants(t *testing.T) {
	d := Default()
	if d.Agent.MaxSteps != 25 || d.Agent.InvokeMaxTurns != 10 {
		t.Fatalf("agent defaults drifted: %+v", d.Agent)
	}
	if d.Context.TriggerRatio != 0.80 {
		t.Fatalf("context default drifted: %+v", d.Context)
	}
	if d.Timeout.LLMIdleSec != 150 || d.Timeout.MCPCallSec != 180 || d.Timeout.BashDefaultTimeoutSec != 120 {
		t.Fatalf("timeout defaults drifted: %+v", d.Timeout)
	}
	if d.Tools.ReadDefaultLines != 2000 || d.Tools.BashOutputCapKB != 256 || d.Tools.ToolResultCapKB != 256 {
		t.Fatalf("tools defaults drifted: %+v", d.Tools)
	}
	if d.Guards.AttachmentMaxMB != 50 || d.Guards.WebhookBodyMaxMB != 10 {
		t.Fatalf("guards defaults drifted: %+v", d.Guards)
	}
}

// TestSchema_MatchesStruct pins G5: Schema() stays 1:1 with the Limits struct — every leaf
// field has exactly one FieldSpec keyed by its dotted json path, with a default equal to
// Default(). Adding a Limits field without a spec (or vice versa) fails here.
//
// TestSchema_MatchesStruct 锁 G5:Schema() 与 Limits 结构 1:1——每个叶字段恰有一条按点分 json
// 路径命名的 FieldSpec、默认等于 Default()。加字段不加 spec(或反之)在此失败。
func TestSchema_MatchesStruct(t *testing.T) {
	specs := Schema()
	byKey := make(map[string]FieldSpec, len(specs))
	for _, s := range specs {
		if _, dup := byKey[s.Key]; dup {
			t.Fatalf("duplicate spec key %q", s.Key)
		}
		byKey[s.Key] = s
	}
	d := reflect.ValueOf(Default())
	dt := d.Type()
	leaves := 0
	for i := 0; i < dt.NumField(); i++ {
		group := dt.Field(i).Tag.Get("json")
		grp := d.Field(i)
		gt := grp.Type()
		for j := 0; j < gt.NumField(); j++ {
			key := group + "." + gt.Field(j).Tag.Get("json")
			leaves++
			spec, ok := byKey[key]
			if !ok {
				t.Errorf("Limits field %q has no FieldSpec (schema drifted from struct)", key)
				continue
			}
			if spec.Group != group {
				t.Errorf("%s: spec.Group = %q, want %q", key, spec.Group, group)
			}
			var val float64
			switch f := grp.Field(j); f.Kind() {
			case reflect.Int:
				val = float64(f.Int())
			case reflect.Float64:
				val = f.Float()
			default:
				t.Fatalf("%s: unexpected kind %v", key, f.Kind())
			}
			if spec.Default != val {
				t.Errorf("%s: spec.Default = %v, want %v (Default())", key, spec.Default, val)
			}
		}
	}
	if leaves != len(specs) {
		t.Errorf("Schema has %d specs but Limits has %d leaf fields", len(specs), leaves)
	}
}

func TestWithDefaults_FillsZeros(t *testing.T) {
	l := WithDefaults(Limits{Agent: AgentLimits{MaxSteps: 7}})
	if l.Agent.MaxSteps != 7 {
		t.Fatalf("explicit value overwritten: %+v", l.Agent)
	}
	if l.Agent.InvokeMaxTurns != 10 || l.Timeout.MCPCallSec != 180 || l.Context.TriggerRatio != 0.80 {
		t.Fatalf("zeros not filled: %+v", l)
	}
}

func TestSetProvider_SwapsSource(t *testing.T) {
	defer SetProvider(Default) // restore global state after the test
	custom := Limits{Agent: AgentLimits{MaxSteps: 7}}
	SetProvider(func() Limits { return custom })
	if got := Current().Agent.MaxSteps; got != 7 {
		t.Errorf("Current().MaxSteps = %d, want 7 after SetProvider", got)
	}
}

func TestSetProvider_NilIgnored(t *testing.T) {
	defer SetProvider(Default) // restore global state after the test
	SetProvider(func() Limits { return Limits{Agent: AgentLimits{MaxSteps: 7}} })
	SetProvider(nil) // must be ignored — keep the previous provider
	if got := Current().Agent.MaxSteps; got != 7 {
		t.Errorf("nil SetProvider should be ignored, got MaxSteps=%d", got)
	}
}
