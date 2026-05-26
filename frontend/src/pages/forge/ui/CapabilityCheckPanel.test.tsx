// CapabilityCheckPanel — expandable panel triggering POST
// /workflows/{id}:capability-check. Renders allReady badge or missing
// items list per response shape.

import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

vi.mock("@entities/workflow", () => ({
  useCapabilityCheck: vi.fn(),
}));

import { useCapabilityCheck } from "@entities/workflow";
import { useToastStore } from "../../../shared/ui/toastStore.ts";
import { CapabilityCheckPanel } from "./CapabilityCheckPanel.tsx";

const mockUseCapabilityCheck = useCapabilityCheck as any;

beforeEach(() => {
  useToastStore.setState({ toasts: [] });
  mockUseCapabilityCheck.mockReturnValue({
    mutateAsync: vi.fn().mockResolvedValue({ ok: true, issues: [], items: [] }),
    isPending: false,
  });
});

describe("CapabilityCheckPanel", () => {
  it("idleState_showsTriggerButton_panelHidden", () => {
    render(<CapabilityCheckPanel workflowId="wf_1" />);
    expect(screen.getByText("Capability check")).toBeInTheDocument();
    expect(screen.queryByText("能力检查")).toBeNull();
  });

  it("triggerClick_opensPanel_andShowsResult", async () => {
    render(<CapabilityCheckPanel workflowId="wf_1" />);
    await userEvent.click(screen.getByText("Capability check"));
    await waitFor(() => expect(screen.getByText("能力检查")).toBeInTheDocument());
    expect(screen.getByText("全部就绪")).toBeInTheDocument();
  });

  it("missingItems_listedWithMissingBadge", async () => {
    mockUseCapabilityCheck.mockReturnValue({
      mutateAsync: vi.fn().mockResolvedValue({
        ok: false,
        issues: ["api_key"],
        items: [
          { kind: "apikey", name: "OpenAI", ready: false, reason: "not configured" },
          { kind: "function", name: "fetcher", ready: true },
        ],
      }),
      isPending: false,
    });
    render(<CapabilityCheckPanel workflowId="wf_1" />);
    await userEvent.click(screen.getByText("Capability check"));
    await waitFor(() => expect(screen.getByText(/1 项缺失/)).toBeInTheDocument());
    expect(screen.getByText("OpenAI")).toBeInTheDocument();
    expect(screen.getByText("not configured")).toBeInTheDocument();
    expect(screen.getByText("fetcher")).toBeInTheDocument();
  });

  it("emptyItems_showsNoCapabilitiesNeeded", async () => {
    mockUseCapabilityCheck.mockReturnValue({
      mutateAsync: vi.fn().mockResolvedValue({ ok: true, issues: [], items: [] }),
      isPending: false,
    });
    render(<CapabilityCheckPanel workflowId="wf_1" />);
    await userEvent.click(screen.getByText("Capability check"));
    await waitFor(() => expect(screen.getByText(/不需要外部能力/)).toBeInTheDocument());
  });

  it("pendingState_buttonShowsSpinner_andIsDisabled", () => {
    mockUseCapabilityCheck.mockReturnValue({
      mutateAsync: vi.fn(),
      isPending: true,
    });
    render(<CapabilityCheckPanel workflowId="wf_1" />);
    expect(screen.getByText(/检查中/)).toBeInTheDocument();
    expect((screen.getByText(/检查中/).closest("button") as HTMLButtonElement)!.disabled).toBe(true);
  });

  it("checkError_pushesErrorToast", async () => {
    mockUseCapabilityCheck.mockReturnValue({
      mutateAsync: vi.fn().mockRejectedValue(new Error("backend down")),
      isPending: false,
    });
    render(<CapabilityCheckPanel workflowId="wf_1" />);
    await userEvent.click(screen.getByText("Capability check"));
    await waitFor(() => expect(useToastStore.getState().toasts.length).toBeGreaterThan(0));
    expect(useToastStore.getState().toasts[0].kind).toBe("error");
  });

  it("closeButton_collapsesPanel", async () => {
    render(<CapabilityCheckPanel workflowId="wf_1" />);
    await userEvent.click(screen.getByText("Capability check"));
    await waitFor(() => expect(screen.getByText("能力检查")).toBeInTheDocument());
    const closeBtn = screen.getByText("能力检查").closest(".cap-panel-head")!.querySelector(".icon-btn")!;
    await userEvent.click(closeBtn);
    await waitFor(() => expect(screen.queryByText("能力检查")).toBeNull());
  });

  it("capabilitiesKeyAlias_alsoRenders", async () => {
    mockUseCapabilityCheck.mockReturnValue({
      mutateAsync: vi.fn().mockResolvedValue({
        ok: true,
        issues: [],
        capabilities: [{ type: "mcp", id: "github", ready: true }],
      }),
      isPending: false,
    });
    render(<CapabilityCheckPanel workflowId="wf_1" />);
    await userEvent.click(screen.getByText("Capability check"));
    await waitFor(() => expect(screen.getByText("github")).toBeInTheDocument());
  });
});
