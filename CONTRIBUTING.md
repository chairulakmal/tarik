# Contributing

Thanks for considering a contribution. This project is a template — changes ripple into every repo generated from it, so the bar for correctness and documentation is deliberately high.

## Setup

```bash
bin/setup   # deps, .env with generated secrets, Docker, DB
bin/dev     # Rails (3001) + Next.js (3000) via foreman
```

Prerequisites are pinned in `.tool-versions` (Ruby, Node). Docker must be running.

## Before opening a PR

- **Open an issue first for anything non-trivial** so the approach can be discussed before you invest time.
- **Run both suites** — green is required:
  ```bash
  cd api && bundle exec rspec && bundle exec rubocop
  cd frontend && npm test && npm run lint && npx tsc --noEmit
  ```
- **Follow the conventions** in [AGENTS.md](AGENTS.md) — they are the project's source of truth. The hard rules (service objects for payments, i18n keys for every string, `proxy.ts` not `middleware.ts`, no `pay` gem) are non-negotiable.
- **Every user-facing string needs EN and JA keys.** A PR that adds English-only strings is incomplete.
- **Update the docs you touch.** If a change alters behavior described in README, SPEC.md, or `docs/`, the same PR updates them.

## Scope

Good candidates: bug fixes, doc corrections, DX improvements, dependency bumps with passing suites. The template intentionally stays small — new features that most SaaS products don't need (multi-tenancy, admin panels, GraphQL) are out of scope; see SPEC.md → Non-goals.

## License

By contributing you agree your work is licensed under the [MIT License](LICENSE).
