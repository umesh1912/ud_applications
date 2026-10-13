# shadcn/ui Design System

Built from the Figma community file **"@shadcn_ui - Design System (Community)"** (attached as a .fig; author credit on its cover: "made with love by @skirano", v1.0.0). It is a Figma rendition of the shadcn/ui React component library — "Beautifully designed components built with RadixUI and Tailwind CSS". No codebase or live URL was supplied; the .fig is the only source, and its values win over the public library wherever they differ.

The file has six pages: **Cover**, **Components** (27 doc frames, one per component), **Typography**, **Colors** (slate only), **Primitives** (the 18 variant sets the components are built from) and **Icons** (877 glyphs).

There is one "product" surface: component documentation. It is recreated in `ui_kits/docs/`.

## Index

- `styles.css` — global entry; `@import`s only.
- `tokens/` — `colors.css`, `typography.css` (vars + `.type-*` classes), `spacing.css` (spacing, radii, shadows), `fonts.css`.
- `components/components.css` — all component classes (`.sc-*`), incl. hover/focus states.
- `components/<group>/` — React components (`.jsx` + `.d.ts` + `.prompt.md`) and one or more `*.card.html` previews.
- `components/icons/` — `Icon.jsx`, `icon-data.js` (877 glyphs), `Icon.d.ts` (name list).
- `guidelines/` — foundation specimen cards (Colors, Type, Spacing, Brand).
- `ui_kits/docs/` — interactive Cover + component-doc frames.
- `assets/` — `aspect-ratio-photo.png` (Aspect Ratio demo), `avatar.jpg` (Avatar).
- `thumbnail.html`, `SKILL.md`.

## Components

Families (Figma component sets → our component):
accordion Item → **AccordionItem** · avatar → **Avatar** · button → **Button** · checkbox → **Checkbox** · collapsible → **Collapsible** · input → **Input** · menu item → **MenuItem** · menu section title → **MenuSectionTitle** · menubar item → **MenubarItem** · navigation menu content → **NavigationMenuContent** · navigation menu content item → **NavigationMenuContentItem** · navigation menu item → **NavigationMenuItem** · radio button → **RadioButton** · section items → **SectionItems** · switch → **Switch** · tab item → **TabItem** · table item → **TableItem** · textarea → **Textarea**

Standalone components:
accordion → **Accordion** · alter dialog → **AlertDialog** (also exported as **AlterDialog**) · command → **Command** · context menu → **ContextMenu** · dialog → **Dialog** · dropdown menu → **DropdownMenu** · hover card → **HoverCard** · label → **Label** · menubar → **Menubar** · menubar and content → **MenubarAndContent** · navigation menu → **NavigationMenu** · navigation menu and content → **NavigationMenuAndContent** · popover → **Popover** · progress → **Progress** · radio group → **RadioGroup** · scroll-area → **ScrollArea** · scroll list item → **ScrollListItem** · select → **Select** · select options → **SelectOptions** · separator → **Separator** · slider → **Slider** · tabs → **Tabs** · tab card → **TabCard** · tabs and content → **TabsAndContent** · tooltip → **Tooltip** · inline code → **InlineCode** · input/small → **InputSmall** · palette → **Palette** · poster → **Poster** · table → **Table** · icon/* (877) → **Icon**

Groups: `actions/` Button · `forms/` Input, InputSmall, Textarea, Checkbox, Label, RadioButton, RadioGroup, Switch, Select, SelectOptions, Slider · `menus/` MenuItem, MenuSectionTitle, SectionItems, DropdownMenu, ContextMenu, Command, Menubar, MenubarItem, MenubarAndContent · `navigation/` NavigationMenu, NavigationMenuItem, NavigationMenuContent, NavigationMenuContentItem, NavigationMenuAndContent, Tabs, TabItem, TabCard, TabsAndContent · `overlays/` Dialog, AlertDialog, AlterDialog, Popover, HoverCard, Tooltip · `disclosure/` Accordion, AccordionItem, Collapsible · `data-display/` Avatar, Table, TableItem, Progress, ScrollArea, ScrollListItem, Separator, InlineCode, Palette, Poster · `icons/` Icon

"Aspect Ratio" is a Components-page frame but not a component in the file (it is a plain image with a 6px radius) — it appears only in the UI kit.

### Intentional additions
- **Checkbox checked state** — the file draws only the empty box; a checkable control needs a checked fill (slate-900 + check glyph).
- **AlterDialog** — alias so the file's own (misspelled) name resolves.
- **Modal backdrop** (UI kit only) — file draws dialog panels without an overlay.
- **Tabs "Password" panel copy** — file only draws the Account panel.

### Value decisions to review
Several fills in the file are Figma's default `#d9d9d9` (unbound styles): avatar initials bg, switch-off track, slider thumb, progress track and bar. They are kept as-is except the **Progress indicator**, which uses slate-900 (borrowed from Slider's range) because track and bar are otherwise identical. **MenubarItem selected** uses slate-100 (file: white, invisible). Input value text is slate-400 in both placeholder and filled states, exactly as drawn. The Command search placeholder is slate-200 at 50% opacity, as drawn.

## CONTENT FUNDAMENTALS

- **Voice:** neutral, developer-facing, descriptive. Component descriptions are one plain sentence stating what the thing is: "Displays a button or a component that looks like a button." "A collection of links for navigating websites." No marketing adjectives except on the cover ("Beautifully designed components…").
- **Person:** product UI addresses the user as *you* ("Make changes to your profile here. Click save when you're done."; "You agree to our Terms of Service and Privacy Policy."). Docs copy avoids pronouns.
- **Casing:** sentence case for buttons, labels and titles ("Save changes", "Edit profile", "Keyboard shortcuts", "Are you sure absolutely sure?"). Doc frame titles are Title Case component names ("Alert Dialog", "Scroll Area").
- **Buttons:** short verbs — Continue, Cancel, Subscribe, Send message, Save changes, View docs.
- **Helper text:** imperative and brief — "Enter your email address", "Set the dimensions for the layer."
- **Sample content** is whimsical and literary (the "Joke Tax" kingdom story in Typography; "1st level of puns: 5 gold coins") or real OSS names (@peduarte, @radix-ui/primitives, @nextjs, @vercel, Pedro Duarte, Colm Tuite).
- **Shortcuts** use Mac glyphs: ⌘P, ⌘⇧B, ⌘[.
- **No emoji** anywhere. Typos from the file are preserved in defaults ("Biling", "Suppor", "Heigh", "Search Emojii", "Is it anymated", "Save changed") — fix them in real product copy.

## VISUAL FOUNDATIONS

- **Color:** monochrome slate. Slate-900 `#0f172a` is the primary (buttons, slider range, text); slate-100 is the universal muted/hover/selected fill; slate-200 borders and rules; slate-300 input borders; slate-500 secondary text; slate-600 doc descriptions. Pure black appears on labels and the focus ring. The only hue is destructive red-500 `#ef4444` and the one decorative gradient on the Poster (pink `#db4e66` → plum `#a24688` → indigo `#4e3aba`). No dark theme is defined.
- **Type:** Inter only (400/500/600/700/800 + italic), Menlo bold for inline code. Headings use negative tracking (-1.2% at 48px down to -0.5% at 20px). UI text is overwhelmingly 14px medium; 16px for accordion triggers, inputs and body; 12px for shortcuts and palette labels.
- **Spacing:** non-grid exact values — 5px menu padding, 6px gaps label→field, 8/12/16/24px inside components, 17px popover/hover-card padding, 25px tab-card padding, 32/64px doc-frame rhythm. Don't snap them.
- **Backgrounds:** flat white everywhere. No textures, patterns, illustrations or full-bleed imagery; the only photo is the Aspect Ratio demo (cool, desaturated, 6px radius).
- **Borders:** drawn as 1px *inset* box-shadows, not CSS borders — slate-200 for cards/popovers, slate-300 for inputs/dialogs/menubar, `#e5e7eb` for checkbox and dividers. Context and menubar menus use a 1px black outline.
- **Shadows:** soft and short. Popover/menus `0 4px 6px rgba(0,0,0,.09)`; dropdown `0 2px 4px rgba(15,23,42,.15)`; tooltip `0 2px 4px rgba(30,41,59,.25)`; hover card `0 4px 4px rgba(174,174,174,.25)`. Plain cards have no shadow.
- **Radii:** 6px default (buttons, inputs, cards, menus, menu-item hover); 8px dialog and focus ring; 3px tab item and inline code; 2px checkbox; 40px bars; 96px circle button.
- **Cards:** white, 6px radius, 1px slate-200 inset, no shadow, 24–25px padding.
- **Hover:** fill-swap to slate-100 (menu items, nav links, nav triggers); link buttons underline; icon buttons flip dark→outline. Primary/destructive/outline have no distinct hover in the file.
- **Focus:** 2px black ring, 2px offset (8px outer radius).
- **Disabled:** 50% opacity (inputs, textarea, menu items).
- **Press / animation:** none specified. Implemented transitions are minimal (150ms switch thumb, 200ms accordion chevron rotate). No bounces, no blur, no transparency effects beyond the 50% loading button.
- **Layout:** doc frames are 792px wide, centered column, 32px side padding, 64px between header and demo. No fixed headers or app chrome exist in the file.

## ICONOGRAPHY

- The Icons page holds **877 outline glyphs** named `icon/<kebab-name>` — the Lucide set (24px grid, ~2px stroke, round caps), outlined to filled paths. All are extracted to `components/icons/icon-data.js` and rendered via `<Icon name="IconMail" size={16} />`; they paint with `currentColor`.
- Components use them at **16px** (12px chevrons in NavigationMenuItem), slate-900 or inherited colour; Command's search glyph at 50% opacity.
- Common glyphs: chevron-down/up/right, chevrons-down-up, check, plus, mail, user, users, credit-card, settings, keyboard, cloud, log-out, calendar, smile, calculator, search.
- No icon font, no PNG icons, no emoji. Unicode is used only for keyboard shortcut glyphs (⌘ ⇧).
- Extraction lost a sub-path on 5 glyphs: Bot, DivideCircle, DivideSquare, Flashlight, Keyboard. If needed, substitute the same names from Lucide's CDN (`lucide-static`) — same stroke family.

## Brand assets

The file contains **no logo**. The cover shows a grey 24px circle (an empty placeholder) beside the name "shadcn/ui" in Inter 600 underlined; wordmarks in this system are therefore set in type. Do not draw a mark.

## Fonts

Inter loads from Google Fonts (`tokens/fonts.css`) — same family as the file, but no binaries were provided, so there are no local `@font-face` files. Menlo is a macOS system font; other platforms fall back to ui-monospace.
