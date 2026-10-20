# Valence design system

**Concept: the lab notebook.** Studying science happens on paper — graph grids, highlighted formulas, labelled specimens. Valence borrows that world instead of the generic edtech look (purple gradients, mascots, rounded cards everywhere).

## Signature
Subjects are drawn as **periodic-table element tiles** (`ElementTile`): position number, two-letter symbol, name, and a progress fill line. This is the one bold element; everything around it stays quiet.

## Colour
| Token | Light | Dark ("Blackboard") | Use |
|---|---|---|---|
| paper | `#F5F7F2` | `#0F1626` | Screen background (cool, not cream) |
| sheet | `#FFFFFF` | `#172036` | Cards, sheets, inputs |
| ink | `#16233F` | `#E7ECF6` | Primary text, primary buttons |
| graphite | `#576178` | `#9BA6BD` | Secondary text |
| rule | `#D9DFE8` | `#26314C` | Borders, grid lines |
| highlighter | `#FFE45C` | `#E9CF3A` | The one thing that matters on a screen |

Subject reagents: Physics cobalt `#2F5BEA`, Chemistry sodium flame `#DB8400`, Biology chlorophyll `#23955A`, Maths fuchsine `#C2307A`, Computer Science copper-sulphate `#0E8A9A`.

Feedback: correct `#1F8A4C`, wrong `#C8372D`, marked for review `#7B4FD6`.

**Rule:** highlighter yellow is used at most once or twice per screen — key formula, active nav item, streak, timer, the right answer.

## Type
- **Bricolage Grotesque** — display and titles. Characterful, like hand-lettered lab labels.
- **Atkinson Hyperlegible** — body and UI. Built for legibility; students read for hours.
- Scale ≈ 1.25 from 16px body: 48 / 39 / 31 / 25 / 22 / 20 / 16 / 14 / 12.5.
- Sentence case everywhere. No all-caps labels.

## Shape
Radii encode hierarchy, not decoration: element tiles 6 (printed-table crisp) → cards 14 → bottom sheets 24 → chips pill. Cards have a hairline border and **no shadow** — they sit on the paper like taped-in pages.

## Spacing
4-pt scale: 4, 8, 12, 16, 24, 32. Screen gutter 20.

## Motion
Only in response to the student: revealing a solution step (`AnimatedSize`), selecting an option, page change. 160 ms / 260 ms, ease-out cubic. No decorative entrance animations.

## UX patterns
- **Progressive reveal** on solved examples — "Show next step" so students try before they look.
- **Graph-paper background** only on top-level tabs; reading surfaces (lessons, PDFs) are clean.
- **Errors explain the fix** ("Enter a 10-digit mobile number."), empty states offer the next action.
- **Accessibility:** semantic labels on tiles, timer and palette; 48dp+ targets; dark mode; text scales with system settings.
