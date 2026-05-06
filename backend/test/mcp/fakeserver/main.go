// fakeserver — minimal stdio MCP server used by pipeline tests.
//
// Exposes 3 tools that drive every code path the production stdio
// Client cares about:
//
//   - echo:  returns its input verbatim (happy path)
//   - fail:  always responds with isError:true (drives the §5.6
//            consecutive-failure → degraded transition)
//   - crash: writes a marker to stderr then os.Exit(1)s before
//            responding (drives subprocess-death detection)
//
// Built once per `go test` invocation (TestMain in the sibling
// _test.go) so the binary launches cheaply across scenarios.
//
// fakeserver ——pipeline 测试用的最小 stdio MCP server。3 个 tool 覆盖生产
// Client 关心的全部码径：echo 顺路、fail 累失败 → degraded 转换、crash 子
// 进程死。每次 `go test` 由相邻 _test.go 的 TestMain 一次性 build。
package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/modelcontextprotocol/go-sdk/mcp"
)

func main() {
	server := mcp.NewServer(&mcp.Implementation{
		Name:    "forgify-fake-mcp",
		Version: "0.0.1",
	}, nil)

	type echoArgs struct {
		Text string `json:"text" jsonschema:"text to echo back"`
	}
	mcp.AddTool(server, &mcp.Tool{
		Name:        "echo",
		Description: "Echo the input back verbatim.",
	}, func(_ context.Context, _ *mcp.CallToolRequest, args echoArgs) (*mcp.CallToolResult, any, error) {
		return &mcp.CallToolResult{
			Content: []mcp.Content{&mcp.TextContent{Text: args.Text}},
		}, nil, nil
	})

	mcp.AddTool(server, &mcp.Tool{
		Name:        "fail",
		Description: "Always return isError:true (failure-counter tests).",
	}, func(_ context.Context, _ *mcp.CallToolRequest, _ struct{}) (*mcp.CallToolResult, any, error) {
		return &mcp.CallToolResult{
			IsError: true,
			Content: []mcp.Content{&mcp.TextContent{Text: "intentional failure"}},
		}, nil, nil
	})

	mcp.AddTool(server, &mcp.Tool{
		Name:        "crash",
		Description: "Exit the subprocess immediately (crash-detection tests).",
	}, func(_ context.Context, _ *mcp.CallToolRequest, _ struct{}) (*mcp.CallToolResult, any, error) {
		fmt.Fprintln(os.Stderr, "fakeserver: crash tool invoked, exiting")
		os.Exit(1)
		return nil, nil, nil
	})

	if err := server.Run(context.Background(), &mcp.StdioTransport{}); err != nil {
		log.Printf("fakeserver: %v", err)
		os.Exit(1)
	}
}
