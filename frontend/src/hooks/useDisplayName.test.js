import { describe, it, expect, vi, beforeEach } from "vitest";
import { renderHook, act } from "@testing-library/react";

vi.mock("../store/settings.js", () => ({ useSettings: vi.fn() }));
vi.mock("../api/users.js", () => ({ useUsers: vi.fn(), useUpdateUser: vi.fn() }));

import { useSettings } from "../store/settings.js";
import { useUsers, useUpdateUser } from "../api/users.js";
import { useDisplayName } from "./useDisplayName.js";

let mutate;
beforeEach(() => {
  mutate = vi.fn();
  useUpdateUser.mockReturnValue({ mutate });
  useSettings.mockImplementation((sel) => sel({ activeUserId: "u_1" }));
  useUsers.mockReturnValue({ data: [{ id: "u_1", username: "weilin", displayName: "Weilin" }] });
});

describe("useDisplayName", () => {
  it("returns the active user's displayName", () => {
    const { result } = renderHook(() => useDisplayName());
    expect(result.current[0]).toBe("Weilin");
  });

  it("falls back to username when displayName is missing", () => {
    useUsers.mockReturnValue({ data: [{ id: "u_1", username: "weilin" }] });
    const { result } = renderHook(() => useDisplayName());
    expect(result.current[0]).toBe("weilin");
  });

  it("returns empty string when no active user matches", () => {
    useSettings.mockImplementation((sel) => sel({ activeUserId: null }));
    const { result } = renderHook(() => useDisplayName());
    expect(result.current[0]).toBe("");
  });

  it("setValue PATCHes the active user's displayName", () => {
    const { result } = renderHook(() => useDisplayName());
    act(() => result.current[1]("Mia"));
    expect(mutate).toHaveBeenCalledWith({ id: "u_1", patch: { displayName: "Mia" } });
  });

  it("setValue is a no-op when unchanged or empty", () => {
    const { result } = renderHook(() => useDisplayName());
    act(() => result.current[1]("Weilin")); // same as current
    act(() => result.current[1]("   "));     // whitespace only
    expect(mutate).not.toHaveBeenCalled();
  });
});
