// ForgePane — list ↔ detail router. focusEntity probes 3 detail endpoints
// in parallel; first non-null wins (determines kind).

import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

vi.mock("./ForgeList.jsx", () => ({
  ForgeList: ({ onOpen }) => (
    <div data-testid="list">
      <button onClick={() => onOpen({ id: "fn_x", kind: "function", name: "Pick" })}>
        open function
      </button>
      <button onClick={() => onOpen({ id: "hd_x", kind: "handler", name: "PickH" })}>
        open handler
      </button>
      <button onClick={() => onOpen({ id: "wf_x", kind: "workflow", name: "PickW" })}>
        open workflow
      </button>
    </div>
  ),
}));

vi.mock("./FunctionDetail.jsx", () => ({
  FunctionDetail: ({ forge, onBack }) => (
    <div data-testid="fn-detail">
      fn-{forge.id}-{forge.name}
      <button onClick={onBack}>back</button>
    </div>
  ),
}));

vi.mock("./HandlerDetail.jsx", () => ({
  HandlerDetail: ({ forge, onBack }) => (
    <div data-testid="hd-detail">
      hd-{forge.id}
      <button onClick={onBack}>back</button>
    </div>
  ),
}));

vi.mock("./WorkflowDetail.jsx", () => ({
  WorkflowDetail: ({ forge, onBack }) => (
    <div data-testid="wf-detail">
      wf-{forge.id}
      <button onClick={onBack}>back</button>
    </div>
  ),
}));

vi.mock("../../api/forge.js", () => ({
  useFunction: vi.fn(),
  useHandler: vi.fn(),
  useWorkflow: vi.fn(),
}));

import { useFunction, useHandler, useWorkflow } from "../../api/forge.js";
import { useUIStore } from "../../store/ui.js";
import { ForgePane } from "./ForgePane.jsx";

beforeEach(() => {
  useUIStore.setState({ focusEntity: {} });
  useFunction.mockReturnValue({ data: null });
  useHandler.mockReturnValue({ data: null });
  useWorkflow.mockReturnValue({ data: null });
});

describe("ForgePane", () => {
  it("noFocus_rendersList", () => {
    render(<ForgePane />);
    expect(screen.getByTestId("list")).toBeInTheDocument();
    expect(screen.queryByTestId("fn-detail")).toBeNull();
  });

  it("clickFunctionRow_opensFunctionDetail", async () => {
    render(<ForgePane />);
    await userEvent.click(screen.getByText("open function"));
    await waitFor(() => expect(screen.getByTestId("fn-detail")).toBeInTheDocument());
    expect(screen.getByText("fn-fn_x-Pick")).toBeInTheDocument();
  });

  it("clickHandlerRow_opensHandlerDetail", async () => {
    render(<ForgePane />);
    await userEvent.click(screen.getByText("open handler"));
    await waitFor(() => expect(screen.getByTestId("hd-detail")).toBeInTheDocument());
  });

  it("clickWorkflowRow_opensWorkflowDetail", async () => {
    render(<ForgePane />);
    await userEvent.click(screen.getByText("open workflow"));
    await waitFor(() => expect(screen.getByTestId("wf-detail")).toBeInTheDocument());
  });

  it("backFromDetail_returnsToList", async () => {
    render(<ForgePane />);
    await userEvent.click(screen.getByText("open function"));
    await waitFor(() => expect(screen.getByTestId("fn-detail")).toBeInTheDocument());
    await userEvent.click(screen.getByText("back"));
    await waitFor(() => expect(screen.getByTestId("list")).toBeInTheDocument());
  });

  it("focusEntityForge_functionProbeWins_opensFunctionDetail", async () => {
    useUIStore.setState({ focusEntity: { forge: "fn_focus" } });
    useFunction.mockReturnValue({ data: { id: "fn_focus", name: "F" } });
    render(<ForgePane />);
    await waitFor(() => expect(screen.getByTestId("fn-detail")).toBeInTheDocument());
    expect(useUIStore.getState().focusEntity.forge).toBeUndefined();
  });

  it("focusEntityForge_handlerProbeWins_opensHandlerDetail", async () => {
    useUIStore.setState({ focusEntity: { forge: "hd_focus" } });
    useHandler.mockReturnValue({ data: { id: "hd_focus", name: "H" } });
    render(<ForgePane />);
    await waitFor(() => expect(screen.getByTestId("hd-detail")).toBeInTheDocument());
  });

  it("focusEntityForge_workflowProbeWins_opensWorkflowDetail", async () => {
    useUIStore.setState({ focusEntity: { forge: "wf_focus" } });
    useWorkflow.mockReturnValue({ data: { id: "wf_focus", name: "W" } });
    render(<ForgePane />);
    await waitFor(() => expect(screen.getByTestId("wf-detail")).toBeInTheDocument());
  });

  it("focusEntityForge_noProbeReturns_staysOnList", () => {
    useUIStore.setState({ focusEntity: { forge: "fn_ghost" } });
    render(<ForgePane />);
    expect(screen.getByTestId("list")).toBeInTheDocument();
    expect(screen.queryByTestId("fn-detail")).toBeNull();
  });
});
