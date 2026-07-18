# AGENTS.md (tarik)

Primary agent instructions, tool-agnostic (Claude Code, Cursor, Codex, and any future agent). The most important thing here is the hard-rules table: every change must pass it. Everything else in this file is a pointer; the reference content lives in SPEC.md, README.md, and docs/. Contents: where things live, hard rules, trip-wires, working conventions.

## Where things live

| Question | Answer lives in |
|---|---|
| Architecture, tech decisions, repo layout, env vars, API conventions, build phases, testing strategy, deployment | [SPEC.md](SPEC.md) |
| Quickstart, prerequisites, demo mode, project pitch, commands | [README.md](README.md) |
| Auth flow, client-side route guard rationale, password policy, account lifecycle | [docs/auth.md](docs/auth.md) |
| Railway walkthrough | [docs/deployment.md](docs/deployment.md) |
| Stripe → PAY.JP migration | [docs/payjp-migration.md](docs/payjp-migration.md) |
| End-to-end tests | [docs/playwright.md](docs/playwright.md) |

## Hard Rules

| Context | Rule |
|---|---|
| Payment logic | Service objects only, never in controllers or models *(SPEC.md § Technical Decisions)* |
| i18n strings | Always use translation keys, never hardcode English (or Japanese) in components or views |
| Next.js route guard | `proxy.ts` only, never create `middleware.ts` (silently ignored in v16) |
| Auth guard | Client-side only (JWT in `localStorage`), no cookie mirror, no server-side redirect *(docs/auth.md)* |
| Stripe vs pay gem | Use `stripe` gem directly, never the `pay` gem *(SPEC.md § Technical Decisions)* |
| Raw SQL | Only when ActiveRecord cannot express it |
| TypeScript `any` | Never |
| `.env` | Never commit, `.env.example` only |
| Demo seed | Never run in production: guard with `unless Rails.env.development? \|\| ENV["DEMO_MODE"] == "true"` |
| CI | No merge to `main` without green CI; run tests after any behaviour-affecting change *(SPEC.md § Testing Strategy)* |

## Trip-wires

- **Next.js 16 renamed `middleware.ts` to `proxy.ts`.** A `middleware.ts` file is silently ignored; the exported function must be named `proxy`, `config.matcher` still scopes paths, and it runs in the Node.js runtime by default. `proxy.ts` handles locale routing only, never auth; the reasoning is in [docs/auth.md](docs/auth.md).
- **Phase discipline.** Confirm the current phase (SPEC.md § Progress and § Build Phases) before adding anything; if a request pulls in later-phase work, flag it and ask first.
- **Prefer explicit over clever.** No meta-programming without a strong reason *(SPEC.md § Goals, "Readable over clever")*.

## When to Ask vs Act

- **Act without asking:** editing files, running tests, reading code, running linters.
- **Ask before acting:** destructive operations (drop table, `rm -rf`, `git reset --hard`), pushing to remote, creating PRs, any action visible to others.

---

*tarik: a guiding star for your next(js) Rails app.*
