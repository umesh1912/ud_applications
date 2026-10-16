# Dark Theme Automator (Figma plugin)

Turns the colours of a light design into **colour variables with Light and Dark modes**,
binds every layer to them, and lets you flip a screen to dark with one click.

## What it does

1. **Scan** the selection or the whole page. Every solid colour is collected from fills,
   strokes, text (including text with several colours) and drop/inner shadows.
   Colours are grouped by *role*: background, text, icon, border, shadow.
   The same hex can need two dark values (white page → dark, white text on a blue button → stays white),
   so a colour gets one variable per role.
2. **Review** the list. Each row shows Light → Dark, a suggested name
   (`background/primary`, `text/secondary`, `text/on-color`, `background/blue` …) and how many layers use it
   (click the count to select them). Text and icon rows show their contrast on the dark page background
   (green ≥ 4.5:1, orange ≥ 3:1, red below). Rename, change the dark colour, or untick a row.
   *Dark tone* switches the dark backgrounds between Dim (#1E1E1E-ish), Dark (#121212-ish) and Black.
3. **Create variables & bind.** Creates (or updates) a collection with Light and Dark modes,
   sets each variable's scopes (text colours only show up in the text colour picker, etc.)
   and binds all the layers. Colours that already exist as a local variable are reused
   ("reuse" tick on the row).
4. **Use it:** *Light* / *Dark* sets the mode on the selected layers (or the page),
   *Dark copy* duplicates the selected screens next to the originals in dark mode,
   *Export JSON* saves the variables as design tokens (W3C format, one set per mode).

Dark values are worked out in OKLCH so hues stay the same: page and card backgrounds become dark
with lighter "elevated" cards, dark text becomes light grey in the same order, brand colours keep
their hue and links/coloured text get lighter so they read on dark, and shadows get stronger.

Left alone: layers already bound to variables, gradients and images, and (unless you tick the option)
layers using paint styles — converting those detaches the style.

Multiple modes in a collection need a paid Figma plan (Professional or above).

## Install (development)

1. In the Figma desktop app: **Plugins → Development → Import plugin from manifest…**
2. Pick `figma_plugins/dark_theme_automator/manifest.json`.
3. Run it from **Plugins → Development → Dark Theme Automator**.

`code.js` is committed, so no build is needed to try it.

## Working on it

See [../README.md](../README.md): build and tests run from `figma_plugins/`.

- `../shared/color.ts` – colour maths and the light → dark rules (unit tested)
- `src/code.ts` – scanning, variables, binding, modes, export
- `ui.html` – the plugin window
- `test/plugin.test.ts` – runs the built `code.js` against a fake Figma API

Before publishing to the Community, replace `"id"` in `manifest.json` with the id Figma gives you.
