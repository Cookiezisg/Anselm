import { describe, it, expect, vi, beforeEach } from "vitest";
import { useSessionStore } from "./sessionStore";
import { resolveSession } from "./resolve";

vi.mock("../api/session");
import { fetchUsers } from "../api/session";
const mockFetchUsers = vi.mocked(fetchUsers);

function makeUser(id: string) {
  return { id, username: id, displayName: id, avatarColor: "blue", language: "en", lastUsedAt: null, createdAt: "", updatedAt: "" };
}

beforeEach(() => {
  useSessionStore.setState({ currentUserId: null, status: "loading" });
  vi.resetAllMocks();
});

describe("resolveSession", () => {
  it("resolveSession_staleUserId_selectsFirstAndReady", async () => {
    useSessionStore.setState({ currentUserId: "u_gone", status: "loading" });
    mockFetchUsers.mockResolvedValue([makeUser("u_real")]);

    await resolveSession();

    expect(useSessionStore.getState().currentUserId).toBe("u_real");
    expect(useSessionStore.getState().status).toBe("ready");
  });

  it("resolveSession_emptyUsers_onboarding", async () => {
    mockFetchUsers.mockResolvedValue([]);

    await resolveSession();

    expect(useSessionStore.getState().status).toBe("onboarding");
  });

  it("resolveSession_validUserId_keepsAndReady", async () => {
    useSessionStore.setState({ currentUserId: "u_a", status: "loading" });
    mockFetchUsers.mockResolvedValue([makeUser("u_a"), makeUser("u_b")]);

    await resolveSession();

    expect(useSessionStore.getState().currentUserId).toBe("u_a");
    expect(useSessionStore.getState().status).toBe("ready");
  });

  it("resolveSession_nullUserId_selectsFirst", async () => {
    useSessionStore.setState({ currentUserId: null, status: "loading" });
    mockFetchUsers.mockResolvedValue([makeUser("u_x")]);

    await resolveSession();

    expect(useSessionStore.getState().currentUserId).toBe("u_x");
    expect(useSessionStore.getState().status).toBe("ready");
  });
});
