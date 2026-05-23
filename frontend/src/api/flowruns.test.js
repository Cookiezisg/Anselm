// api/flowruns — flow run + approval hooks.

import { beforeEach, describe, expect, it, vi } from "vitest";
import { waitFor } from "@testing-library/react";
import { setupFetchSpy, renderMutation } from "./_testHarness.js";
import {
  useCancelFlowRun, useApproveNode, useRejectNode, useTriageFlowRun,
} from "./flowruns.js";

let calls;
beforeEach(async () => {
  calls = setupFetchSpy();
  const bridge = await import("../bridge/wails.js");
  await bridge.initBaseUrl();
});

describe("useCancelFlowRun", () => {
  it("deletesFlowRunById", async () => {
    const { result } = await renderMutation(useCancelFlowRun);
    result.current.mutate("fr_1");
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/flowruns/fr_1", method: "DELETE" });
  });
});

describe("useApproveNode / useRejectNode", () => {
  it("useApproveNode_postsApprovalDecisionApprove", async () => {
    const { result } = await renderMutation(useApproveNode);
    result.current.mutate({ runId: "fr_1", nodeId: "frn_a", reason: "ok" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/flowruns/fr_1/approvals/frn_a", method: "POST" });
    expect(JSON.parse(calls[0].body)).toEqual({ decision: "approve", reason: "ok" });
  });

  it("useRejectNode_postsApprovalDecisionReject", async () => {
    const { result } = await renderMutation(useRejectNode);
    result.current.mutate({ runId: "fr_1", nodeId: "frn_a", reason: "bad" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(JSON.parse(calls[0].body)).toEqual({ decision: "reject", reason: "bad" });
  });
});

describe("useTriageFlowRun", () => {
  it("postsTriageActionSuffix", async () => {
    const { result } = await renderMutation(useTriageFlowRun);
    result.current.mutate("fr_x");
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/flowruns/fr_x:triage", method: "POST" });
  });
});
