import { describe, it, expect, vi, beforeEach, type Mock } from "vitest";
import { renderHook, act } from "@testing-library/react";

vi.mock("@entities/session/@x/user", () => ({ useSessionStore: vi.fn() }));
vi.mock("@entities/user", () => ({ useUsers: vi.fn(), useUpdateUser: vi.fn() }));

import { useSessionStore } from "@entities/session/@x/user";
import { useUsers, useUpdateUser } from "@entities/user";
import { useDisplayName } from "./useDisplayName.js";

const mockUseUpdateUser = vi.mocked(useUpdateUser);
const mockUseSessionStore = useSessionStore as unknown as Mock;
const mockUseUsers = vi.mocked(useUsers);

let mutate: Mock;
beforeEach(() => {
  mutate = vi.fn();
  mockUseUpdateUser.mockReturnValue({ mutate } as unknown as ReturnType<typeof useUpdateUser>);
  mockUseSessionStore.mockImplementation(
    (sel: (state: { currentUserId: string | null }) => unknown) =>
      sel({ currentUserId: "u_1" }),
  );
  mockUseUsers.mockReturnValue({
    data: [{ id: "u_1", username: "weilin", displayName: "Weilin" }],
  } as ReturnType<typeof useUsers>);
});

describe("useDisplayName", () => {
  it("returns the active user's displayName", () => {
    const { result } = renderHook(() => useDisplayName());
    expect(result.current[0]).toBe("Weilin");
  });

  it("falls back to username when displayName is missing", () => {
    mockUseUsers.mockReturnValue({ data: [{ id: "u_1", username: "weilin" }] } as ReturnType<typeof useUsers>);
    const { result } = renderHook(() => useDisplayName());
    expect(result.current[0]).toBe("weilin");
  });

  it("returns empty string when no active user matches", () => {
    mockUseSessionStore.mockImplementation(
      (sel: (state: { currentUserId: string | null }) => unknown) =>
        sel({ currentUserId: null }),
    );
    const { result } = renderHook(() => useDisplayName());
    expect(result.current[0]).toBe("");
  });

  it("setValue PATCHes the active user's displayName", () => {
    const { result } = renderHook(() => useDisplayName());
    const setValue = result.current[1] as (next: string) => void;
    act(() => setValue("Mia"));
    expect(mutate).toHaveBeenCalledWith({ id: "u_1", patch: { displayName: "Mia" } });
  });

  it("setValue is a no-op when unchanged or empty", () => {
    const { result } = renderHook(() => useDisplayName());
    const setValue = result.current[1] as (next: string) => void;
    act(() => setValue("Weilin")); // same as current
    act(() => setValue("   "));    // whitespace only
    expect(mutate).not.toHaveBeenCalled();
  });
});
