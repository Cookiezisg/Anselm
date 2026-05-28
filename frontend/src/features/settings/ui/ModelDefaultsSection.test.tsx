// ModelDefaultsSection — 3 scenario rows; KeyModelPicker bound per scenario.

import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { createElement } from "react";

const mockUpsertModel = vi.fn();
let apiKeys: any[] = [];
let modelConfigs: any[] = [];

vi.mock("@entities/model-config", () => ({
  useModelConfigs: () => ({ data: modelConfigs }),
  useUpsertModelConfig: () => ({ mutate: mockUpsertModel, mutateAsync: mockUpsertModel, isPending: false }),
}));

vi.mock("@entities/apikey", () => ({
  useApiKeys: () => ({ data: apiKeys }),
}));

import { ModelDefaultsSection } from "./ModelDefaultsSection.tsx";

function wrap({ children }: { children: any }) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } });
  return createElement(QueryClientProvider, { client }, children);
}

beforeEach(() => {
  mockUpsertModel.mockReset().mockResolvedValue({});
  apiKeys = [];
  modelConfigs = [];
});

describe("ModelDefaultsSection", () => {
  it("open_rendersThreeScenarioRows", () => {
    render(<ModelDefaultsSection open={true} onToggle={() => {}} />, { wrapper: wrap });
    expect(screen.getByText("主对话")).toBeInTheDocument();
    expect(screen.getByText("辅助任务")).toBeInTheDocument();
    expect(screen.getByText("Agent")).toBeInTheDocument();
  });

  it("closed_doesNotRenderRows", () => {
    render(<ModelDefaultsSection open={false} onToggle={() => {}} />, { wrapper: wrap });
    expect(screen.queryByText("主对话")).not.toBeInTheDocument();
  });

  it("noKeys_pickerShowsNoKeysPlaceholder", () => {
    render(<ModelDefaultsSection open={true} onToggle={() => {}} />, { wrapper: wrap });
    // 3 rows × placeholder; assert at least one.
    expect(screen.getAllByText("尚未配 API Key").length).toBeGreaterThan(0);
  });

  it("titleAndSubtitle_visible", () => {
    render(<ModelDefaultsSection open={true} onToggle={() => {}} />, { wrapper: wrap });
    expect(screen.getByText("模型默认")).toBeInTheDocument();
    expect(screen.getByText("各场景独立配置")).toBeInTheDocument();
  });

  it("currentConfig_renderedAsSelectedValue", () => {
    apiKeys = [{
      id: "aki_ds",
      provider: "deepseek",
      displayName: "DeepSeek",
      keyMasked: "sk-ds...3f2a",
      testStatus: "ok",
      modelsFound: ["deepseek-chat", "deepseek-reasoner"],
    }];
    modelConfigs = [{ scenario: "dialogue", apiKeyId: "aki_ds", modelId: "deepseek-chat" }];
    render(<ModelDefaultsSection open={true} onToggle={() => {}} />, { wrapper: wrap });
    // Dialogue row should show the picked combo in its trigger.
    const dialogueRow = screen.getByText("主对话").closest(".set-mrow") as HTMLElement;
    expect(dialogueRow).not.toBeNull();
    expect(dialogueRow.textContent).toContain("deepseek-chat");
  });
});
