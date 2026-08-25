package handler

import (
	"context"
	"reflect"
	"sync"
	"testing"
	"time"

	handlerdomain "github.com/sunweilin/anselm/backend/internal/domain/handler"
)

type managerTestClient struct{}

func (managerTestClient) Init(context.Context, map[string]any) error { return nil }
func (managerTestClient) StreamCall(context.Context, string, map[string]any, string, func(any)) (any, error) {
	return nil, nil
}
func (managerTestClient) Shutdown(context.Context) error { return nil }
func (managerTestClient) Crashed() bool                  { return false }

// TestInstanceManager_SingleFlightColdSpawn proves that concurrent callers share one expensive
// cold spawn instead of creating duplicate residents and discarding all but one.
func TestInstanceManager_SingleFlightColdSpawn(t *testing.T) {
	started := make(chan struct{})
	release := make(chan struct{})
	var mu sync.Mutex
	spawns := 0
	want := &Instance{ID: "hdi_singleflight", Client: managerTestClient{}}
	m := newInstanceManager(func(context.Context, string) (*Instance, error) {
		mu.Lock()
		spawns++
		if spawns == 1 {
			close(started)
		}
		mu.Unlock()
		<-release
		return want, nil
	}, nil)

	const callers = 5
	instances := make(chan *Instance, callers)
	errs := make(chan error, callers)
	for i := 0; i < callers; i++ {
		go func() {
			inst, err := m.Get(context.Background(), "hd_singleflight")
			instances <- inst
			errs <- err
		}()
	}
	select {
	case <-started:
	case <-time.After(2 * time.Second):
		t.Fatal("cold spawn did not start")
	}
	mu.Lock()
	if spawns != 1 {
		mu.Unlock()
		t.Fatalf("concurrent callers started %d spawns before the first settled", spawns)
	}
	mu.Unlock()
	close(release)

	for i := 0; i < callers; i++ {
		if err := <-errs; err != nil {
			t.Fatalf("caller %d failed: %v", i, err)
		}
		if got := <-instances; got != want {
			t.Fatalf("caller %d received a different resident: got=%p want=%p", i, got, want)
		}
	}
	mu.Lock()
	defer mu.Unlock()
	if spawns != 1 {
		t.Fatalf("cold batch must pay for one spawn, got %d", spawns)
	}
}

// TestFilterConfigToSchemaDropsOrphans locks the spawn choke point's config boundary: stored
// values may outlive a version, but only arguments declared by the active schema reach __init__.
func TestFilterConfigToSchemaDropsOrphans(t *testing.T) {
	config := map[string]any{"token": "keep", "old_key": "drop"}
	got := filterConfigToSchema(config, []handlerdomain.InitArgSpec{{Name: "token"}})
	if !reflect.DeepEqual(got, map[string]any{"token": "keep"}) {
		t.Fatalf("active schema filter = %#v, want only declared token", got)
	}
	if !reflect.DeepEqual(config, map[string]any{"token": "keep", "old_key": "drop"}) {
		t.Fatalf("filter must not rewrite stored config, got %#v", config)
	}
}
