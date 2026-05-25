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

// Helper: click the primary advance/finish button (always labeled "开始" or "继续").
// Using role+name avoids matching the step sidebar desc text "开始" in the done-step entry.
const clickStart = (screen) => userEvent.click(screen.getByRole("button", { name: /开始/ }));
const clickNext  = (screen) => userEvent.click(screen.getByRole("button", { name: /继续/ }));

// Query the main content pane only, avoiding the sidebar step-desc duplicates.
const pane = () => document.querySelector(".onb-pane");
const inPane = (text) => within(pane()).getByText(text);

describe("Onboarding", () => {
  it("intro_renderedFirst_clickStartAdvancesToAccount", async () => {
    render(<Onboarding onFinish={() => {}} />, { wrapper: wrap });
    // Intro step renders the "你好" heading inside .onb-title (pane only).
    expect(inPane("你好")).toBeInTheDocument();
    await clickStart(screen);
    // Account step heading (pane only).
    expect(inPane("起个名字")).toBeInTheDocument();
  });

  it("account_emptyName_advanceButtonDisabled", async () => {
    render(<Onboarding onFinish={() => {}} />, { wrapper: wrap });
    await clickStart(screen);
    const cont = screen.getByRole("button", { name: /继续/ });
    expect(cont.disabled).toBe(true);
  });

  it("account_filledName_canAdvance", async () => {
    render(<Onboarding onFinish={() => {}} />, { wrapper: wrap });
    await clickStart(screen);
    await userEvent.type(screen.getByPlaceholderText(/私人/), "alice");
    const cont = screen.getByRole("button", { name: /继续/ });
    expect(cont.disabled).toBe(false);
  });

  it("look_swatchClick_updatesAccentPreview", async () => {
    render(<Onboarding onFinish={() => {}} />, { wrapper: wrap });
    await clickStart(screen);
    await userEvent.type(screen.getByPlaceholderText(/私人/), "alice");
    await clickNext(screen);
    // Look step heading (pane only — sidebar also has "挑个色调" in step desc).
    expect(inPane("挑个色调")).toBeInTheDocument();
    // Clicking a swatch other than the default (claude) updates active state.
    // Re-query after click because React re-renders the list on state change.
    expect(document.querySelectorAll(".onb-swatch").length).toBe(5);
    await userEvent.click(document.querySelectorAll(".onb-swatch")[1]); // "Notion 蓝"
    expect(document.querySelectorAll(".onb-swatch")[1].classList.contains("is-active")).toBe(true);
  });

  it("provider_canSkip_proceedToDoneWithoutKey", async () => {
    render(<Onboarding onFinish={() => {}} />, { wrapper: wrap });
    await clickStart(screen);
    await userEvent.type(screen.getByPlaceholderText(/私人/), "alice");
    await clickNext(screen);
    await clickNext(screen);
    // Provider step heading.
    expect(screen.getByText("配一把钥匙")).toBeInTheDocument();
    // No provider chosen → primary advance button is disabled.
    const cont = screen.getByRole("button", { name: /继续/ });
    expect(cont.disabled).toBe(true);
    // Explicit skip lands on done step.
    await userEvent.click(screen.getByRole("button", { name: /稍后再配/ }));
    expect(screen.getByText("好了")).toBeInTheDocument();
  });

  it("provider_clickedNoKey_cannotAdvance", async () => {
    render(<Onboarding onFinish={() => {}} />, { wrapper: wrap });
    await clickStart(screen);
    await userEvent.type(screen.getByPlaceholderText(/私人/), "alice");
    await clickNext(screen);
    await clickNext(screen);
    await userEvent.click(screen.getByText("DeepSeek"));
    // Provider picked, key empty → still disabled.
    expect(screen.getByRole("button", { name: /继续/ }).disabled).toBe(true);
  });

  it("done_clickFinish_callsCreateUserAndInvokesOnFinish", async () => {
    const onFinish = vi.fn();
    render(<Onboarding onFinish={onFinish} />, { wrapper: wrap });
    await clickStart(screen);
    await userEvent.type(screen.getByPlaceholderText(/私人/), "alice");
    await clickNext(screen);
    await clickNext(screen);
    // provider step: no key, use skip button to reach done.
    await userEvent.click(screen.getByRole("button", { name: /稍后再配/ }));
    // On done step the primary button is labeled "开始" again.
    await clickStart(screen);
    await waitFor(() => expect(mockCreateUser).toHaveBeenCalled());
    expect(mockCreateUser.mock.calls[0][0].displayName).toBe("alice");
    await waitFor(() => expect(onFinish).toHaveBeenCalled());
  });

  it("withApiKey_creates BothUserAndKey_andSetsModelFromModelsFound", async () => {
    const onFinish = vi.fn();
    render(<Onboarding onFinish={onFinish} />, { wrapper: wrap });
    await clickStart(screen);
    await userEvent.type(screen.getByPlaceholderText(/私人/), "alice");
    await clickNext(screen);
    await clickNext(screen);
    // Pick provider first — key input is now conditional on selection.
    await userEvent.click(screen.getByText("DeepSeek"));
    const keyInput = screen.getByPlaceholderText(/sk-/);
    const { fireEvent } = await import("@testing-library/react");
    fireEvent.change(keyInput, { target: { value: "sk-test123" } });
    await clickNext(screen);
    // On done step the primary button is labeled "开始".
    await clickStart(screen);
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
    await clickStart(screen);
    await userEvent.type(screen.getByPlaceholderText(/私人/), "alice");
    await clickNext(screen);
    await clickNext(screen);
    await userEvent.click(screen.getByText("DeepSeek"));
    const { fireEvent } = await import("@testing-library/react");
    fireEvent.change(screen.getByPlaceholderText(/sk-/), { target: { value: "sk-bad" } });
    await clickNext(screen);
    await clickStart(screen);
    await waitFor(() => expect(mockCreateKey).toHaveBeenCalled());
    await waitFor(() => expect(onFinish).toHaveBeenCalled());
    // Key written; model-config NOT written when test fails.
    expect(mockSetModel).not.toHaveBeenCalled();
  });

  it("prevButton_goesBackOneStep", async () => {
    render(<Onboarding onFinish={() => {}} />, { wrapper: wrap });
    await clickStart(screen);
    expect(inPane("起个名字")).toBeInTheDocument();
    await userEvent.click(screen.getByText(/上一步/));
    // Back on intro step (pane only).
    expect(inPane("你好")).toBeInTheDocument();
  });

  it("finishMarksOnboardedTrue", async () => {
    render(<Onboarding onFinish={() => {}} />, { wrapper: wrap });
    await clickStart(screen);
    await userEvent.type(screen.getByPlaceholderText(/私人/), "alice");
    await clickNext(screen);
    await clickNext(screen);
    await userEvent.click(screen.getByRole("button", { name: /稍后再配/ }));
    await clickStart(screen);
    await waitFor(() => expect(useSettings.getState().onboarded).toBe(true));
  });
});
