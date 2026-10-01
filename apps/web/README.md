# CaseFlow Web

The advocate-facing web app — the same product as the CaseFlow mobile app,
for advocates, their juniors and their clerks, at a desk.

```bash
npm install
npm run dev          # http://localhost:5175
npm run typecheck
npm test             # includes the legal fixtures shared with Flutter
npm run build
```

- **Same backend, same data.** One Supabase project with the same RLS as
  mobile. Unset `VITE_SUPABASE_*` falls back to **production** — see
  `.env.example`.
- **Parity is tracked in [PARITY.md](PARITY.md).** Every mobile feature is
  mapped there, or listed as deliberately excluded.
- **Legal rules** are checked against `packages/legal-fixtures`, the same
  worked examples the Flutter tests use. Change the fixture first.
- **Design:** `packages/design-system/themes/product.css` (CaseFlow blue, as on
  mobile) through the shared Tailwind preset. No literal colours — use tokens.
- **Language:** `src/lib/i18n/en.json` / `ta.json` are extracted from the
  mobile app; regenerate them rather than editing. Web-only wording lives in
  `web.en.json` / `web.ta.json`.
