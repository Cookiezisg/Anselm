package mcp

import "testing"

// TestPlan_PrefersNodeOverDotnet: Azure-like entry (NuGet package first, npm second). Plan
// must pick the npm one (node beats dotnet) so we never pull a .NET SDK when an npm copy exists.
//
// TestPlan_PrefersNodeOverDotnet：Azure 式条目（NuGet 包在前、npm 在后）。Plan 必须挑 npm 那个
// （node 压过 dotnet），有 npm 版就别拉 .NET SDK。
func TestPlan_PrefersNodeOverDotnet(t *testing.T) {
	e := RegistryEntry{Packages: []Package{
		{Name: "Azure.Mcp"},  // name ".Mcp" → dotnet
		{Name: "@azure/mcp"}, // "@scope" → node
	}}
	plan, ok := e.Plan()
	if !ok {
		t.Fatal("expected a plan")
	}
	if plan.Runtime != RuntimeNode {
		t.Fatalf("want node, got %q", plan.Runtime)
	}
	if plan.Command != "npx" {
		t.Fatalf("want npx, got %q", plan.Command)
	}
}

func TestPlan_PythonUvx(t *testing.T) {
	e := RegistryEntry{Packages: []Package{{Name: "markitdown-mcp", RuntimeHint: "uvx"}}}
	plan, ok := e.Plan()
	if !ok || plan.Runtime != RuntimePython || plan.Command != "uvx" {
		t.Fatalf("want python/uvx, got ok=%v runtime=%q cmd=%q", ok, plan.Runtime, plan.Command)
	}
	if len(plan.Args) == 0 || plan.Args[0] != "markitdown-mcp" {
		t.Fatalf("want args [markitdown-mcp ...], got %v", plan.Args)
	}
}

func TestPlan_DockerImageBare(t *testing.T) {
	e := RegistryEntry{Packages: []Package{{Name: "ghcr.io/x/y:1", RuntimeHint: "docker"}}}
	plan, ok := e.Plan()
	if !ok || plan.Runtime != RuntimeDocker || plan.Command != "ghcr.io/x/y:1" {
		t.Fatalf("want docker bare image, got ok=%v runtime=%q cmd=%q", ok, plan.Runtime, plan.Command)
	}
}

// TestPlan_RemoteWhenNoPackage: no packages but a remote endpoint → remote plan; a blank
// transport defaults to streamable-http; header placeholders surface as required env.
//
// TestPlan_RemoteWhenNoPackage：无 package 但有 remote 端点 → remote plan；transport 空默认
// streamable-http；header 占位符浮现为必填 env。
func TestPlan_RemoteWhenNoPackage(t *testing.T) {
	e := RegistryEntry{Remotes: []Remote{{
		URL:     "https://app.example.com/mcp",
		Headers: []Header{{Value: "Bearer {API_TOKEN}", IsSecret: true}},
	}}}
	plan, ok := e.Plan()
	if !ok || !plan.Remote {
		t.Fatal("expected remote plan")
	}
	if plan.Transport != TransportStreamableHTTP {
		t.Fatalf("want default streamable-http, got %q", plan.Transport)
	}
	if len(plan.EnvVars) != 1 || plan.EnvVars[0].Name != "API_TOKEN" {
		t.Fatalf("want API_TOKEN env from placeholder, got %v", plan.EnvVars)
	}
}

func TestPlan_NoRunnable(t *testing.T) {
	e := RegistryEntry{Packages: []Package{{Name: "weird", RuntimeHint: "rust"}}}
	if _, ok := e.Plan(); ok {
		t.Fatal("expected no runnable package")
	}
}

func TestServer_IsRemote(t *testing.T) {
	if (&Server{URL: "https://x"}).IsRemote() != true {
		t.Fatal("url-bearing server should be remote")
	}
	if (&Server{Command: "npx"}).IsRemote() != false {
		t.Fatal("command-bearing server should be stdio")
	}
}
