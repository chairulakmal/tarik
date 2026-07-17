import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { NextIntlClientProvider } from "next-intl";
import ForgotPasswordPage from "./page";
import en from "@/i18n/en.json";

// Exemplar page test: mock the API module, drive the form, assert the
// success state. Copy this pattern for other form pages.
vi.mock("@/lib/api", () => ({
  auth: {
    requestPasswordReset: vi.fn().mockResolvedValue({ data: { message: "ok" } }),
  },
}));

import { auth } from "@/lib/api";

describe("ForgotPasswordPage", () => {
  it("submits the email and shows the sent notice", async () => {
    render(
      <NextIntlClientProvider locale="en" messages={en}>
        <ForgotPasswordPage />
      </NextIntlClientProvider>
    );

    fireEvent.change(screen.getByLabelText(en.auth.email), {
      target: { value: "someone@example.com" },
    });
    fireEvent.click(screen.getByRole("button", { name: en.auth.sendResetLink }));

    await waitFor(() => {
      expect(screen.getByText(en.auth.resetSent)).toBeInTheDocument();
    });
    expect(auth.requestPasswordReset).toHaveBeenCalledWith("someone@example.com");
  });
});
