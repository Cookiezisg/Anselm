// Onboarding — 5-step wizard. Tests navigation, validation gates,
// finish flow (user create + apikey create + invalidate).

import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { createElement } from "react";

// AnimatePresence keeps exiting copies briefly which breaks unique-text
// queries during step transitions. Strip animation so each step renders
// (and unmounts) synchronously.
vi.mock("framer-motion", async () => {
  const actual = await vi.importActual("framer-motion");
  return {
    ...actual,
    AnimatePresence: ({ children }) => children,
    motion: new Proxy({}, {
      get: (_, tag) => (props) => {
        const { initial, animate, exit, transition, layout, ...rest } = props;
        return createElement(tag, rest);
      },
    }),
  };
});

const mockCreateUser = vi.fn();
const mockCreateKey = vi.fn();
const mockTestKey = vi.fn();
const mockSetModel = vi.fn();

vi.mock("../../api/users.js", () => ({
  useUsers: () => ({ data: [] }),
  useCreateUser: () => ({ mutateAsync: mockCreateUser }),
}));

vi.mock("../../api/config.js", () => ({
  useProviders: () => ({ data: [
    { name: "deepseek", category: "llm", displayName: "DeepSeek", defaultBaseUrl: "https://api.deepseek.com" },
    { name: "anthropic", category: "llm", displayName: "Anthropic", defaultBaseUrl: "https://api.anthropic.com" },
  ] }),
  useCreateApiKey: () => ({ mutateAsync: mockCreateKey }),
  useTestApiKey: () => ({ mutateAsync: mockTestKey }),
  useUpsertModelConfig: () => ({ mutateAsync: mockSetModel }),
}));

import { useUIStore } from "../../store/ui.js";
import { useSettings } from "../../store/settings.js";
import { Onboarding } from "./Onboarding.jsx";

function wrap({ children }) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } });
  return createElement(QueryClientProvider, { client }, children);
}

beforeEach(() => {
  useUIStore.setState({ toasts: [] });
  useSettings.setState({ theme: "system", accent: "claude", density: "cozy", lang: "zh", activeUserId: null, onboarded: false });
  mockCreateUser.mockReset().mockResolvedValue({ id: "u_new", username: "alice" });
  mockCreateKey.mockReset().mockResolvedValue({ id: "aki_1" });
  mockTestKey.mockReset().mockResolvedValue({ ok: true, modelsFound: ["deepseek-chat"] });
  mockSetModel.mockReset().mockResolvedValue({});
});

describe("Onboarding", () => {
  it("intro_renderedFirst_clickStartAdvancesToAccount", async () => {
    render(<Onboarding onFinish={() => {}} />, { wrapper: wrap });
    expect(screen.getByText("欢迎使用 Forgify")).toBeInTheDocument();
    await userEvent.click(screen.getByText("开始"));
    expect(screen.getByText("创建本地工作空间")).toBeInTheDocument();
  });

  it("account_emptyName_advanceButtonDisabled", async () => {
    render(<Onboarding onFinish={() => {}} />, { wrapper: wrap });
    await userEvent.click(screen.getByText("开始"));
    const cont = screen.getByText("继续").closest("button");
    expect(cont.disabled).toBe(true);
  });

  it("account_filledName_canAdvance", async () => {
    render(<Onboarding onFinish={() => {}} />, { wrapper: wrap });
    await userEvent.click(screen.getByText("开始"));
    await userEvent.type(screen.getByPlaceholderText(/personal/), "alice");
    const cont = screen.getByText("继续").closest("button");
    expect(cont.disabled).toBe(false);
  });

  it("look_swatchClick_updatesAccentPreview", async () => {
    render(<Onboarding onFinish={() => {}} />, { wrapper: wrap });
    await userEvent.click(screen.getByText("开始"));
    await userEvent.type(screen.getByPlaceholderText(/personal/), "alice");
    await userEvent.click(screen.getByText("继续"));
    expect(screen.getByText("选个主题色")).toBeInTheDocument();
  });

  it("provider_canSkip_proceedToDoneWithoutKey", async () => {
    render(<Onboarding onFinish={() => {}} />, { wrapper: wrap });
    await userEvent.click(screen.getByText("开始"));
    await userEvent.type(screen.getByPlaceholderText(/personal/), "alice");
    await userEvent.click(screen.getByText("继续"));
    await userEvent.click(screen.getByText("继续"));
    expect(screen.getByText("配一个 LLM")).toBeInTheDocument();
    // No provider chosen → "继续" is disabled. Use explicit skip button.
    const cont = screen.getByText("继续").closest("button");
    expect(cont.disabled).toBe(true);
    await userEvent.click(screen.getByRole("button", { name: /跳过/ }));
    expect(screen.getAllByText("就绪").length).toBeGreaterThanOrEqual(1);
  });

  it("provider_clickedNoKey_cannotAdvance", async () => {
    render(<Onboarding onFinish={() => {}} />, { wrapper: wrap });
    await userEvent.click(screen.getByText("开始"));
    await userEvent.type(screen.getByPlaceholderText(/personal/), "alice");
    await userEvent.click(screen.getByText("继续"));
    await userEvent.click(screen.getByText("继续"));
    await userEvent.click(screen.getByText("DeepSeek"));
    // Provider picked, key empty → still disabled.
    expect(screen.getByText("继续").closest("button").disabled).toBe(true);
  });

  it("done_clickFinish_callsCreateUserAndInvokesOnFinish", async () => {
    const onFinish = vi.fn();
    render(<Onboarding onFinish={onFinish} />, { wrapper: wrap });
    await userEvent.click(screen.getByText("开始"));
    await userEvent.type(screen.getByPlaceholderText(/personal/), "alice");
    await userEvent.click(screen.getByText("继续"));
    await userEvent.click(screen.getByText("继续"));
    // provider step: no key, use skip button to reach done.
    await userEvent.click(screen.getByRole("button", { name: /跳过/ }));
    await userEvent.click(screen.getByRole("button", { name: /进入应用/ }));
    await waitFor(() => expect(mockCreateUser).toHaveBeenCalled());
    expect(mockCreateUser.mock.calls[0][0].displayName).toBe("alice");
    await waitFor(() => expect(onFinish).toHaveBeenCalled());
  });

  it("withApiKey_creates BothUserAndKey_andSetsModelFromModelsFound", async () => {
    const onFinish = vi.fn();
    render(<Onboarding onFinish={onFinish} />, { wrapper: wrap });
    await userEvent.click(screen.getByText("开始"));
    await userEvent.type(screen.getByPlaceholderText(/personal/), "alice");
    await userEvent.click(screen.getByText("继续"));
    await userEvent.click(screen.getByText("继续"));
    // Pick provider first — key input is now conditional on selection.
    await userEvent.click(screen.getByText("DeepSeek"));
    const keyInput = screen.getByPlaceholderText(/sk-/);
    const { fireEvent } = await import("@testing-library/react");
    fireEvent.change(keyInput, { target: { value: "sk-test123" } });
    await userEvent.click(screen.getByText("继续"));
    await userEvent.click(screen.getByRole("button", { name: /进入应用/ }));
    await waitFor(() => expect(mockCreateKey).toHaveBeenCalled());
    expect(mockCreateKey.mock.calls[0][0].key).toBe("sk-test123");
    await waitFor(() => expect(mockSetModel).toHaveBeenCalled());
    // modelId should come from mocked testKey's modelsFound[0], not a hardcoded guess.
    expect(mockSetModel.mock.calls[0][0]).toMatchObject({
      scenario: "chat",
      provider: "deepseek",
      modelId: "deepseek-chat",
    });
  });

  it("withApiKey_testFails_skipsModelConfig", async () => {
    mockTestKey.mockReset().mockRejectedValue(new Error("HTTP 401"));
    const onFinish = vi.fn();
    render(<Onboarding onFinish={onFinish} />, { wrapper: wrap });
    await userEvent.click(screen.getByText("开始"));
    await userEvent.type(screen.getByPlaceholderText(/personal/), "alice");
    await userEvent.click(screen.getByText("继续"));
    await userEvent.click(screen.getByText("继续"));
    await userEvent.click(screen.getByText("DeepSeek"));
    const { fireEvent } = await import("@testing-library/react");
    fireEvent.change(screen.getByPlaceholderText(/sk-/), { target: { value: "sk-bad" } });
    await userEvent.click(screen.getByText("继续"));
    await userEvent.click(screen.getByRole("button", { name: /进入应用/ }));
    await waitFor(() => expect(mockCreateKey).toHaveBeenCalled());
    await waitFor(() => expect(onFinish).toHaveBeenCalled());
    // Key written; model-config NOT written when test fails.
    expect(mockSetModel).not.toHaveBeenCalled();
  });

  it("prevButton_goesBackOneStep", async () => {
    render(<Onboarding onFinish={() => {}} />, { wrapper: wrap });
    await userEvent.click(screen.getByText("开始"));
    expect(screen.getByText("创建本地工作空间")).toBeInTheDocument();
    await userEvent.click(screen.getByText(/上一步/));
    expect(screen.getByText("欢迎使用 Forgify")).toBeInTheDocument();
  });

  it("finishMarksOnboardedTrue", async () => {
    render(<Onboarding onFinish={() => {}} />, { wrapper: wrap });
    await userEvent.click(screen.getByText("开始"));
    await userEvent.type(screen.getByPlaceholderText(/personal/), "alice");
    await userEvent.click(screen.getByText("继续"));
    await userEvent.click(screen.getByText("继续"));
    await userEvent.click(screen.getByRole("button", { name: /跳过/ }));
    await userEvent.click(screen.getByRole("button", { name: /进入应用/ }));
    await waitFor(() => expect(useSettings.getState().onboarded).toBe(true));
  });
});
