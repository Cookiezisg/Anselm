// ExecutePane — router between ExecuteOverview list and FlowRunDetail.
// Honours focusEntity.execute by probing useFlowRun.

import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";

vi.mock("./ExecuteOverview.jsx", () => ({
  ExecuteOverview: ({ onOpen }) => (
    <div data-testid="overview">
      <button onClick={() => onOpen({ id: "fr_clicked" })}>open run</button>
    </div>
  ),
}));

vi.mock("./FlowRunDetail.jsx", () => ({
  FlowRunDetail: ({ runId, onBack }) => (
    <div data-testid="detail">
      <span>detail-{runId}</span>
      <button onClick={onBack}>back</button>
    </div>
  ),
}));

vi.mock("../../api/flowruns.js", () => ({
  useFlowRun: vi.fn(),
}));

import userEvent from "@testing-library/user-event";
import { useFlowRun } from "../../api/flowruns.js";
import { useUIStore } from "../../store/ui.js";
import { ExecutePane } from "./ExecutePane.jsx";

beforeEach(() => {
  useUIStore.setState({ focusEntity: {} });
  useFlowRun.mockReturnValue({ data: null });
});

describe("ExecutePane", () => {
  it("noOpenRun_rendersOverview", () => {
    render(<ExecutePane />);
    expect(screen.getByTestId("overview")).toBeInTheDocument();
    expect(screen.queryByTestId("detail")).toBeNull();
  });

  it("openRunClick_switchesToDetail", async () => {
    render(<ExecutePane />);
    await userEvent.click(screen.getByText("open run"));
    await waitFor(() => expect(screen.getByTestId("detail")).toBeInTheDocument());
    expect(screen.getByText("detail-fr_clicked")).toBeInTheDocument();
  });

  it("backFromDetail_returnsToOverview", async () => {
    render(<ExecutePane />);
    await userEvent.click(screen.getByText("open run"));
    await waitFor(() => expect(screen.getByTestId("detail")).toBeInTheDocument());
    await userEvent.click(screen.getByText("back"));
    await waitFor(() => expect(screen.getByTestId("overview")).toBeInTheDocument());
  });

  it("focusEntityExecute_setBeforeMount_probesAndOpensDetail", async () => {
    useUIStore.setState({ focusEntity: { execute: "fr_focus" } });
    useFlowRun.mockReturnValue({ data: { id: "fr_focus" } });
    render(<ExecutePane />);
    await waitFor(() => expect(screen.getByText("detail-fr_focus")).toBeInTheDocument());
    // focus should be consumed
    expect(useUIStore.getState().focusEntity.execute).toBeUndefined();
  });

  it("focusEntityExecute_probeNotResolved_staysOnOverview", () => {
    useUIStore.setState({ focusEntity: { execute: "fr_missing" } });
    useFlowRun.mockReturnValue({ data: null });
    render(<ExecutePane />);
    expect(screen.getByTestId("overview")).toBeInTheDocument();
    expect(screen.queryByTestId("detail")).toBeNull();
  });
});
