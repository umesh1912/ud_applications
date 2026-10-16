# Contrast Checker (Figma plugin)

Checks the contrast of every text layer against WCAG 2 (AA or AAA) and fixes the ones that fail.

- **Real backgrounds.** It works out the colour behind each text layer: layers below it (a button
  rectangle next to the label, not just its parent), its frames, translucent overlays blended on top,
  and finally the canvas.
- **Any mode.** When a file has variable collections with several modes (for example the Light/Dark
  collection from Dark Theme Automator), pick a mode and the check uses those variable values without
  changing your file. Great for checking a dark theme before you ship it.
- **Right threshold.** AA: 4.5:1 for body text, 3:1 for large text (24px, or 18.66px bold).
  AAA: 7:1 and 4.5:1. Each colour within a text layer is checked on its own.
- **Fixes.** *Fix* swaps in the nearest colour that passes (same hue, only lightness changes).
  When the text colour is a variable, *Fix variable* changes that variable for the mode being checked,
  so every use of it gets fixed. *Fix all unlinked* fixes every failing layer that isn't using a variable.
- Click a row to select the layer. Text on images is flagged "on image" so you can check it by eye.
