package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"reflect"
	"testing"
)

func TestSplitStreams(t *testing.T) {
	got := splitStreams("messages, entities, ,notifications")
	want := []string{"messages", "entities", "notifications"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("splitStreams = %v, want %v", got, want)
	}
}

func TestListWorkspaces(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/v1/workspaces" {
			t.Fatalf("path = %s", r.URL.Path)
		}
		if r.Header.Get("Authorization") != "Bearer token" {
			t.Fatalf("authorization missing")
		}
		_, _ = w.Write([]byte(`{"data":[{"id":"ws_one"},{"id":"ws_two"}]}`))
	}))
	defer server.Close()
	got, err := listWorkspaces(context.Background(), server.URL, "token")
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"ws_one", "ws_two"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("ids = %v, want %v", got, want)
	}
}
