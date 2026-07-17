import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { NextIntlClientProvider } from "next-intl";
import DemoBanner from "@/components/DemoBanner";
import en from "@/i18n/en.json";

// Exemplar component test: wrap in NextIntlClientProvider with the real
// message catalog so translation keys are exercised, not mocked.
describe("DemoBanner", () => {
  it("renders the localized banner text", () => {
    render(
      <NextIntlClientProvider locale="en" messages={en}>
        <DemoBanner />
      </NextIntlClientProvider>
    );

    expect(screen.getByText(en.demo.banner)).toBeInTheDocument();
  });
});
