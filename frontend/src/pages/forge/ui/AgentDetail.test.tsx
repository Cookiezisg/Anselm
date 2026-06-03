// AgentDetail — Definition/Runs tabs + prompt/skill/tools/knowledge view +
// split diff + VersionRail. pendingV swaps action buttons to Accept/Revert;
// an inline invoke drawer runs the agent synchronously.

import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

vi.mock("@entities/agent", () => ({
  useAgent: vi.fn(),
  useAgentVersions: vi.fn(),
  useAgentExecutions: vi.fn(),
  useInvokeAgent: vi.fn(),
}));

vi.mock("@features/forge-review", () => ({
  useForgeReview: vi.fn(),
  useForgeBatchDelete: vi.fn(),
}));

vi.mock("@shared/model", () => ({
  useForgeProgress: (selector: (s: any) => any) => selector({ active: {} }),
}));

vi.mock("@/widgets/entity-rel-meta/EntityRelMeta.tsx", () => ({
  EntityRelMeta: (): null => null,
}));

vi.mock("@/widgets/entity-link", () => ({
  EntityLink: ({ id }: { id: any }) => <span data-testid="entity-link">{id}</span>,
}));

vi.mock("@/widgets/ask-ai-trigger/AskAiTrigger.tsx", () => ({
  AskAiTrigger: ({ entityId }: { entityId: any }) => <div data-testid="ask-ai">ask-{entityId}</div>,
}));

vi.mock("@/widgets/version-rail/VersionRail.tsx", () => ({
  VersionRail: ({ versions }: { versions: any[] }) => <div data-testid="version-rail">rail-{versions.length}</div>,
  SplitDiff: ({ leftSrc, rightSrc }: { leftSrc: any; rightSrc: any }) => (
    <div data-testid="split-diff">{leftSrc}|{rightSrc}</div>
  ),
}));

import {
  useAgent, useAgentVersions, useAgentExecutions, useInvokeAgent,
} from "@entities/agent";
import { useForgeReview } from "@features/forge-review";
import { useToastStore } from "@shared/ui/toastStore";
import { AgentDetail } from "./AgentDetail.tsx";

const mockUseAgent = useAgent as any;
const mockUseAgentVersions = useAgentVersions as any;
const mockUseAgentExecutions = useAgentExecutions as any;
const mockUseInvokeAgent = useInvokeAgent as any;
const mockUseForgeReview = useForgeReview as any;

const AG = { id: "ag_1", name: "TriageBot", desc: "routes tickets", status: "ready" };

const VERSIONS_READY = [
  {
    id: "agv_1", label: "v1", state: "current",
    prompt: "You are a triage agent.",
    skill: "sk_triage",
    knowledge: ["doc_1"],
    tools: [{ ref: "fn_search", name: "search" }, { ref: "mcp:slack/post", name: "post" }],
    outputSchema: { kind: "enum", enums: ["urgent", "normal"] },
  },
];

const VERSIONS_PENDING = [
  ...VERSIONS_READY,
  {
    id: "agv_2", label: "v2", state: "pending",
    prompt: "You are a strict triage agent.",
    skill: "sk_triage",
    knowledge: ["doc_1", "doc_2"],
    tools: [{ ref: "fn_search", name: "search" }],
    outputSchema: { kind: "free_text" },
  },
];

const EXECUTIONS = [
  { id: "agx_1", status: "ok", triggeredBy: "test", elapsedMs: 1200, startedAt: "2026-06-03T10:00:00Z" },
  { id: "agx_2", status: "failed", triggeredBy: "chat", elapsedMs: 800, startedAt: "2026-06-03T11:00:00Z" },
];

beforeEach(() => {
  useToastStore.setState({ toasts: [] });
  mockUseAgent.mockReturnValue({ data: AG });
  mockUseAgentVersions.mockReturnValue({ data: VERSIONS_READY });
  mockUseAgentExecutions.mockReturnValue({ data: { executions: [] } });
  mockUseInvokeAgent.mockReturnValue({ mutateAsync: vi.fn(), isPending: false });
  mockUseForgeReview.mockReturnValue({ accept: vi.fn(), reject: vi.fn(), revert: vi.fn() });
});

describe("AgentDetail", () => {
  it("header_showsNameAndKindChip", () => {
    render(<AgentDetail forge={AG} onBack={() => {}} />);
    expect(screen.getByText("TriageBot")).toBeInTheDocument();
    expect(screen.getByText("ag_1")).toBeInTheDocument();
    expect(screen.getByText("Agent")).toBeInTheDocument();
  });

  it("readyState_showsInvokeButton_andAskAi", () => {
    render(<AgentDetail forge={AG} onBack={() => {}} />);
    // agent.runBtn (zh) = "调用"; appears on the header invoke button
    expect(screen.getAllByText("调用").length).toBeGreaterThan(0);
    expect(screen.getByTestId("ask-ai")).toBeInTheDocument();
  });

  it("definitionTab_showsPromptSkillToolsKnowledge", () => {
    render(<AgentDetail forge={AG} onBack={() => {}} />);
    expect(screen.getByText("You are a triage agent.")).toBeInTheDocument();
    expect(screen.getByText("sk_triage")).toBeInTheDocument();
    // tools: fn_search is linkable (EntityLink), mcp post renders its name
    expect(screen.getByText("post")).toBeInTheDocument();
    // knowledge doc_1 routed through EntityLink mock
    expect(screen.getAllByTestId("entity-link").length).toBeGreaterThan(0);
  });

  it("definitionTab_enumOutputSchema_rendersEnums", () => {
    render(<AgentDetail forge={AG} onBack={() => {}} />);
    expect(screen.getByText("urgent")).toBeInTheDocument();
    expect(screen.getByText("normal")).toBeInTheDocument();
  });

  it("runsTab_empty_showsPlaceholder", async () => {
    render(<AgentDetail forge={AG} onBack={() => {}} />);
    await userEvent.click(screen.getByText("运行"));
    // agent.runsPlaceholder (zh) = "调用记录会显示在这里"
    expect(screen.getByText("调用记录会显示在这里")).toBeInTheDocument();
  });

  it("runsTab_withExecutions_rendersRows", async () => {
    mockUseAgentExecutions.mockReturnValue({ data: { executions: EXECUTIONS } });
    render(<AgentDetail forge={AG} onBack={() => {}} />);
    await userEvent.click(screen.getByText("运行"));
    expect(screen.getByText("agx_1")).toBeInTheDocument();
    expect(screen.getByText("agx_2")).toBeInTheDocument();
    expect(screen.getByText("ok")).toBeInTheDocument();
    expect(screen.getByText("failed")).toBeInTheDocument();
  });

  it("pendingState_showsAcceptAndRevert", () => {
    mockUseAgentVersions.mockReturnValue({ data: VERSIONS_PENDING });
    render(<AgentDetail forge={AG} onBack={() => {}} />);
    expect(screen.getAllByText("接受").length).toBeGreaterThan(0);
    expect(screen.getAllByText("还原").length).toBeGreaterThan(0);
  });

  it("acceptClick_callsAcceptAction", async () => {
    mockUseAgentVersions.mockReturnValue({ data: VERSIONS_PENDING });
    const accept = vi.fn();
    mockUseForgeReview.mockReturnValue({ accept, reject: vi.fn(), revert: vi.fn() });
    render(<AgentDetail forge={AG} onBack={() => {}} />);
    await userEvent.click(screen.getAllByText("接受")[0]);
    expect(accept).toHaveBeenCalled();
  });

  it("rejectClick_callsRejectAction", async () => {
    mockUseAgentVersions.mockReturnValue({ data: VERSIONS_PENDING });
    const reject = vi.fn();
    mockUseForgeReview.mockReturnValue({ accept: vi.fn(), reject, revert: vi.fn() });
    render(<AgentDetail forge={AG} onBack={() => {}} />);
    await userEvent.click(screen.getAllByText("还原")[0]);
    expect(reject).toHaveBeenCalled();
  });

  it("backButton_callsOnBack", async () => {
    const onBack = vi.fn();
    render(<AgentDetail forge={AG} onBack={onBack} />);
    await userEvent.click(screen.getByText(/返回/));
    expect(onBack).toHaveBeenCalled();
  });

  it("pendingDiff_promptChange_rendersSplitDiff", () => {
    mockUseAgentVersions.mockReturnValue({ data: VERSIONS_PENDING });
    const { container } = render(<AgentDetail forge={AG} onBack={() => {}} />);
    expect(container.textContent).toContain("Diff");
    // prompt + knowledge + outputSchema all changed → at least one SplitDiff
    expect(screen.getAllByTestId("split-diff").length).toBeGreaterThan(0);
  });

  it("invokeClick_opensInvokeDrawer", async () => {
    render(<AgentDetail forge={AG} onBack={() => {}} />);
    // header invoke button is the first "调用"
    await userEvent.click(screen.getAllByText("调用")[0]);
    // drawer title agent.invoke.title (zh) = "调用智能体"
    await waitFor(() => expect(screen.getByText("调用智能体")).toBeInTheDocument());
  });

  it("invokeDrawer_submit_callsInvokeAndShowsResult", async () => {
    const mutateAsync = vi.fn().mockResolvedValue({
      executionId: "agx_9", ok: true, output: { verdict: "urgent" },
      status: "ok", steps: 3, tokensIn: 50, tokensOut: 20, elapsedMs: 1500,
    });
    mockUseInvokeAgent.mockReturnValue({ mutateAsync, isPending: false });
    render(<AgentDetail forge={AG} onBack={() => {}} />);
    await userEvent.click(screen.getAllByText("调用")[0]);
    // submit button inside drawer (agent.invoke.submit = "调用")
    const submitBtn = screen.getAllByText("调用").find((el) => el.closest(".drawer-foot"));
    await userEvent.click(submitBtn!);
    await waitFor(() => expect(mutateAsync).toHaveBeenCalledWith({ id: "ag_1", input: {} }));
    // Result JSON renders in the drawer's result pre (.run-drawer-result).
    await waitFor(() => {
      const pre = document.querySelector(".run-drawer-result");
      expect(pre?.textContent).toContain("urgent");
    });
  });
});
