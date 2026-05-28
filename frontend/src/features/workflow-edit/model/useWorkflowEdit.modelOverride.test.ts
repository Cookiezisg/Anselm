// useWorkflowEdit — set_node_model_override op coverage.
// Verifies diffToOps emits the dedicated op when an existing agent/llm
// node's modelOverride flips, and that nodeToSpec round-trips modelOverride.
//
// 验证现存节点 modelOverride 翻转时 diffToOps 发 set_node_model_override op;
// 同时 nodeToSpec 对 modelOverride 字段做 round-trip。

import { describe, expect, it, vi } from "vitest";
import { diffToOps, nodeToSpec, type CanvasNode, type CanvasGraph } from "./useWorkflowEdit";

vi.mock("@entities/workflow", () => ({
  useEditWorkflow: () => ({ mutate: vi.fn(), isPending: false }),
}));

function makeAgent(id: string, override?: { apiKeyId: string; modelId: string } | null): CanvasNode {
  return {
    id,
    kind: "agent",
    label: id,
    notes: "",
    config: {},
    onError: "",
    timeout: 0,
    x: 100,
    y: 200,
    modelOverride: override ?? null,
  };
}

// ── diffToOps: set_node_model_override branch ────────────────────────────

describe("diffToOps — set_node_model_override", () => {
  it("emitsOp_whenAgentNodeGetsOverride", () => {
    const orig: CanvasGraph = { nodes: [makeAgent("n1", null)], edges: [] };
    const next: CanvasGraph = {
      nodes: [makeAgent("n1", { apiKeyId: "aki_test", modelId: "claude-haiku-4-5" })],
      edges: [],
    };
    const ops = diffToOps(orig, next);
    const overrideOps = ops.filter((o) => o.op === "set_node_model_override");
    expect(overrideOps).toHaveLength(1);
    expect(overrideOps[0]).toMatchObject({
      op: "set_node_model_override",
      nodeId: "n1",
      modelOverride: { apiKeyId: "aki_test", modelId: "claude-haiku-4-5" },
    });
  });

  it("emitsOpWithNull_whenOverrideIsCleared", () => {
    const orig: CanvasGraph = {
      nodes: [makeAgent("n1", { apiKeyId: "aki_test", modelId: "m_1" })],
      edges: [],
    };
    const next: CanvasGraph = { nodes: [makeAgent("n1", null)], edges: [] };
    const ops = diffToOps(orig, next);
    const overrideOps = ops.filter((o) => o.op === "set_node_model_override");
    expect(overrideOps).toHaveLength(1);
    expect(overrideOps[0]).toMatchObject({
      op: "set_node_model_override",
      nodeId: "n1",
      modelOverride: null,
    });
  });

  it("doesNotEmitOp_whenOverrideUnchanged", () => {
    const ref = { apiKeyId: "aki_test", modelId: "m_1" };
    const orig: CanvasGraph = { nodes: [makeAgent("n1", { ...ref })], edges: [] };
    const next: CanvasGraph = { nodes: [makeAgent("n1", { ...ref })], edges: [] };
    const ops = diffToOps(orig, next);
    const overrideOps = ops.filter((o) => o.op === "set_node_model_override");
    expect(overrideOps).toHaveLength(0);
  });

  it("treatsNullAndUndefinedAsEquivalent", () => {
    const orig: CanvasGraph = { nodes: [{ ...makeAgent("n1"), modelOverride: undefined }], edges: [] };
    const next: CanvasGraph = { nodes: [makeAgent("n1", null)], edges: [] };
    const ops = diffToOps(orig, next);
    const overrideOps = ops.filter((o) => o.op === "set_node_model_override");
    expect(overrideOps).toHaveLength(0);
  });

  it("doesNotEmitForNewlyAddedNode_overrideCarriedInAddNode", () => {
    // New nodes carry modelOverride inline via add_node.node — we must NOT
    // also emit a set_node_model_override since the backend would reject
    // the second op (node-already-has-override on add).
    //
    // 新节点 modelOverride 走 add_node.node 内联,不能再发 set_node_model_override。
    const orig: CanvasGraph = { nodes: [], edges: [] };
    const next: CanvasGraph = {
      nodes: [makeAgent("n1", { apiKeyId: "aki_test", modelId: "m_1" })],
      edges: [],
    };
    const ops = diffToOps(orig, next);
    expect(ops.some((o) => o.op === "add_node")).toBe(true);
    expect(ops.some((o) => o.op === "set_node_model_override")).toBe(false);
  });
});

// ── nodeToSpec: modelOverride mapping ────────────────────────────────────

describe("nodeToSpec — modelOverride", () => {
  it("includesModelOverride_whenSet", () => {
    const n = makeAgent("n1", { apiKeyId: "aki_a", modelId: "m_a" });
    const spec = nodeToSpec(n) as Record<string, unknown>;
    expect(spec.modelOverride).toEqual({ apiKeyId: "aki_a", modelId: "m_a" });
  });

  it("omitsModelOverride_whenNull", () => {
    const n = makeAgent("n1", null);
    const spec = nodeToSpec(n);
    expect(spec).not.toHaveProperty("modelOverride");
  });

  it("omitsModelOverride_whenUndefined", () => {
    const n: CanvasNode = { ...makeAgent("n1"), modelOverride: undefined };
    const spec = nodeToSpec(n);
    expect(spec).not.toHaveProperty("modelOverride");
  });
});
