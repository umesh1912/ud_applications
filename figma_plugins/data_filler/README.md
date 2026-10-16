# Data Filler (Figma plugin)

Fills your designs with real content from Google Sheets, Excel, CSV, JSON or built-in sample data.

## How it works

1. **Name the layers** you want filled with `#` and a column name:

   | Layer | Gets |
   |---|---|
   | `#title` (text) | the text from the *title* column |
   | `#photo` (rectangle, ellipse, frame) | the image at the URL in *photo* |
   | `#color` | a fill colour, when the value is a hex like `#2563EB` |
   | `#badge?` | shown when the value is yes/true/1/anything, hidden when empty/no/0/false |
   | `#user.name` | a value inside nested JSON |
   | `#price` on a frame or button | the frame's first text layer |

   Component properties (text, boolean, variant) are filled by their own name, so instances need no renaming.
   Column names ignore case, spaces, `_` and `-`: *First Name* matches `#firstname`.
2. **Add data:** paste cells copied from Google Sheets/Excel (with the header row), paste CSV/JSON,
   drop a file, or generate sample rows (names, emails, phone numbers, cities, prices in ₹, dates, ratings, avatars…).
   The preview ticks the columns that match a layer, and the layer chips show which fields have no column.
3. **Fill:**
   - several items selected (cards, list rows, screens) → one row each, in visual order;
   - one item selected with *repeat* on → it is copied once per row (inside auto layout the copies follow it,
     otherwise they stack below with the gap you set).
   - *Shuffle* and *Start at row* pick which rows are used.

The last data you used is remembered for next time. Missing fonts, broken image links and variant values
that don't exist are listed at the end instead of stopping the fill.

The plugin needs network access only to download the images in your data.
