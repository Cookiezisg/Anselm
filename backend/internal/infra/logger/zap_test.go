package logger

import "testing"

func TestNew_Dev(t *testing.T) {
	log, err := New(true)
	if err != nil {
		t.Fatalf("New(true): %v", err)
	}
	if log == nil {
		t.Fatal("nil logger")
	}
	log.Info("dev logger smoke") // must not panic
	_ = log.Sync()
}

func TestNew_Prod(t *testing.T) {
	log, err := New(false)
	if err != nil {
		t.Fatalf("New(false): %v", err)
	}
	if log == nil {
		t.Fatal("nil logger")
	}
	log.Info("prod logger smoke")
	_ = log.Sync()
}
