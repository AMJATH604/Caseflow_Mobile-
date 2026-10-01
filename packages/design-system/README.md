# CaseFlow Design System

Shared visual language for `apps/dashboard` (CaseFlow Admin) and
`apps/bardesk` (Bar Association Admin), so both read as one product.

## What's here

| File | Purpose |
| --- | --- |
| `tokens.css` | Every colour, shadow and chart value, for light and dark. The source of truth for the admin surfaces (dashboard, BarDesk): navy and brass. |
| `themes/product.css` | The same token names with the advocate product's values — CaseFlow blue on slate, matching the mobile app. Used by `apps/web` *instead of* `tokens.css`. |
| `tailwind.preset.ts` | Maps those variables onto Tailwind utilities, plus the type scale, radii and animation. Shared by every web app, whichever theme it imports. |

A theme file must define **every** token `tokens.css` defines, in both `:root`
and `.dark`. The preset maps names, not values, so a token a theme forgets
resolves to nothing rather than falling back to the admin colour.

## Consuming it

There is no root `package.json` and no workspace tooling in this repo, so this
is shared as a **Tailwind preset plus a CSS import** rather than an npm package.
That keeps both apps installing and building exactly as they did.

```ts
// apps/<app>/tailwind.config.ts
import designSystem from "../../packages/design-system/tailwind.preset";

export default {
  presets: [designSystem],
  content: ["./src/**/*.{ts,tsx}"],
  plugins: [require("tailwindcss-animate")],
};
```

```css
/* apps/<app>/src/index.css — must be the first line, before @tailwind */
@import "../../../packages/design-system/tokens.css";

@tailwind base;
@tailwind components;
@tailwind utilities;
```

## Rules

**Never hardcode a palette colour.** Use the semantic token, not the raw
Tailwind class:

```tsx
❌ <span className="text-emerald-600">Paid</span>
✅ <span className="text-success">Paid</span>

❌ <div className="bg-slate-900 text-white">
✅ <div className="bg-primary text-primary-foreground">
```

This matters because a hardcoded colour cannot respond to the dark theme. The
app previously carried ~245 such literals, which is why a pastel blue-indigo
body sat on top of a navy-gold shell.

**Adding a colour means two edits.** Add the HSL triplet to *both* the `:root`
and `.dark` blocks in `tokens.css`, then map it in the preset. A token defined
in only one block silently keeps its light value on a dark ground — which is
exactly what had happened to `--success`, `--warning` and `--info`.

**Values are bare HSL triplets** (`220 60% 20%`, no `hsl()` wrapper) so
Tailwind can compose alpha: `bg-primary/10` becomes
`hsl(var(--primary) / 0.1)`.

## The palette

Deep navy, brass gold, warm cream — carried over from the mobile app's splash
screen. Deliberately not the indigo-on-white that most admin panels default to;
navy and gold reads institutional, which suits a legal product.

In dark mode **gold becomes the primary**, because navy cannot carry emphasis
against a navy-black ground.

## Type

- `font-display` — Outfit. Headings.
- `font-sans` — Inter. UI and body.
- `font-serif` — Playfair Display. Brand moments only (login, wordmark).

Figures use `font-variant-numeric: tabular-nums`, applied automatically to
`th`, `td` and anything marked `data-numeric`, so numbers don't jitter as they
update or shift between rows.
