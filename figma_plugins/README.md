# Figma plugins

Four plugins that work together on a design system:

| Plugin | Folder | What it does |
|---|---|---|
| **Dark Theme Automator** | `dark_theme_automator` | Turns every colour into Light/Dark colour variables, binds the layers, switches screens to dark. |
| **Data Filler** | `data_filler` | Fills layers named `#name`, `#photo`, `#price`… from Google Sheets, CSV, JSON or sample data; repeats a card once per row. |
| **Contrast Checker** | `contrast_checker` | Checks every text layer against what is really behind it, in any mode (Light/Dark), against WCAG AA/AAA, and fixes it. |
| **Spacing Tokens** | `spacing_tokens` | Turns auto-layout padding, gaps and corner radii into number variables on a 4 or 8 pt scale and binds them. |

A good order for a new file: **Spacing Tokens** → **Dark Theme Automator** → **Data Filler** (real content) →
**Contrast Checker** in Light and in Dark.

## Install in Figma

1. Open the Figma **desktop** app.
2. **Plugins → Development → Import plugin from manifest…**
3. Choose `figma_plugins/<plugin>/manifest.json`. Repeat for each plugin you want.
4. Run them from **Plugins → Development**.

Each plugin's built `code.js` is committed, so you don't need to build anything to use them.

## Working on them

```bash
cd figma_plugins
npm install
npm run watch        # rebuilds every plugin's code.js on save
npm run typecheck
npm test             # builds, then runs all tests
```

- `shared/color.ts` – colour maths (OKLCH, WCAG contrast, dark variants, contrast fixes)
- `shared/fake-figma.ts` – a small fake of the Figma API used by the tests
- `<plugin>/src/` – the plugin code, bundled into `<plugin>/code.js`
- `<plugin>/ui.html` – the plugin window
- `<plugin>/test/` – unit tests and end-to-end tests against the fake Figma

Before publishing a plugin to the Community, replace `"id"` in its `manifest.json` with the id Figma gives you.
