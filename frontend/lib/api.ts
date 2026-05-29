import { getToken, setToken, clearToken } from "./auth";

const API_URL =
  process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3001";

type ApiResponse<T> = { data: T };
type ApiError = { error: { message: string; code: string } };

async function request<T>(
  path: string,
  options: RequestInit = {}
): Promise<T> {
  const token = getToken();
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(options.headers as Record<string, string>),
  };
  if (token) headers["Authorization"] = `Bearer ${token}`;

  const res = await fetch(`${API_URL}${path}`, { ...options, headers });

  if (!res.ok) {
    const body: ApiError = await res.json().catch(() => ({
      error: { message: res.statusText, code: "unknown" },
    }));
    throw new Error(body.error?.message ?? res.statusText);
  }

  const authHeader = res.headers.get("Authorization");
  if (authHeader?.startsWith("Bearer ")) {
    setToken(authHeader.replace("Bearer ", ""));
  }

  return (await res.json()) as T;
}

export type User = { id: number; email: string; locale: string };

export const auth = {
  signUp: (email: string, password: string) =>
    request<ApiResponse<User>>("/api/v1/auth/sign_up", {
      method: "POST",
      body: JSON.stringify({ user: { email, password } }),
    }),

  signIn: (email: string, password: string) =>
    request<ApiResponse<User>>("/api/v1/auth/sign_in", {
      method: "POST",
      body: JSON.stringify({ user: { email, password } }),
    }),

  signOut: () => {
    const p = request<ApiResponse<Record<string, never>>>(
      "/api/v1/auth/sign_out",
      { method: "DELETE" }
    );
    clearToken();
    return p;
  },

  me: () => request<ApiResponse<User>>("/api/v1/users/me"),

  updateLocale: (locale: string) =>
    request<ApiResponse<User>>("/api/v1/users/me", {
      method: "PATCH",
      body: JSON.stringify({ user: { locale } }),
    }),
};
