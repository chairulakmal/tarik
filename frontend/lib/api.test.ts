import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { auth } from "@/lib/api";

// Exemplar test for the API client: stub global fetch, assert the
// Authorization header contract in both directions.
function jsonResponse(
  body: unknown,
  { status = 200, headers = {} }: { status?: number; headers?: Record<string, string> } = {}
) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...headers },
  });
}

describe("api client", () => {
  const fetchMock = vi.fn();

  beforeEach(() => {
    localStorage.clear();
    fetchMock.mockReset();
    vi.stubGlobal("fetch", fetchMock);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("attaches the stored token as a Bearer header", async () => {
    localStorage.setItem("auth_token", "stored-token");
    fetchMock.mockResolvedValue(jsonResponse({ data: { id: 1 } }));

    await auth.me();

    const [, options] = fetchMock.mock.calls[0];
    expect(options.headers["Authorization"]).toBe("Bearer stored-token");
  });

  it("stores the token returned in the Authorization response header", async () => {
    fetchMock.mockResolvedValue(
      jsonResponse(
        { data: { id: 1, email: "a@example.com", locale: "en" } },
        { headers: { Authorization: "Bearer fresh-token" } }
      )
    );

    await auth.signIn("a@example.com", "a_long_enough_password");

    expect(localStorage.getItem("auth_token")).toBe("fresh-token");
  });

  it("throws the API error envelope message on failure", async () => {
    fetchMock.mockResolvedValue(
      jsonResponse(
        { error: { message: "Invalid email or password", code: "invalid_credentials" } },
        { status: 401 }
      )
    );

    await expect(auth.signIn("a@example.com", "wrong")).rejects.toThrow(
      "Invalid email or password"
    );
  });
});
