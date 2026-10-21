# Sawaal design system — "sticker book"

Built for players from 5 to 75, so everything is big, bright and obvious to tap.

- **Signature:** every tappable thing is a *sticker*: thick ink outline (2.5 px), hard offset shadow with no blur, and it sinks into its shadow when pressed (`Sticker` in `widgets.dart`).
- **Colour:** mint paper `#E4F4EC`, ink `#1C1B2E`, tangerine `#FF7A2F` for the main action, sunflower `#FFD23F` for selection and lifelines, right `#2BC46F`, wrong `#FF5263`. Each of the 10 topics has its own sticker colour (`Cat` in `data/questions.dart`). Dark mode and a high-contrast mode (black on white, 3.5 px outlines) are included.
- **Type:** Baloo 2 (round, friendly, covers Devanagari) for headings and buttons; Mukta for questions and body. Text size has Normal / Large / Extra large in Settings.
- **Layout:** two-column "pairs" that grow with their content, so nothing clips at large text sizes.
- **Motion:** only the press-in of stickers and the timer bar.
- **Language:** every screen in English and Hindi; questions can be read aloud.
