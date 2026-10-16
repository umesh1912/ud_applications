# Spacing Tokens (Figma plugin)

Turns the padding, gaps and corner radii in your designs into number variables, and binds them.

1. **Scan** the selection or page. It reads auto-layout padding, item spacing and wrap spacing,
   and corner radii (every corner). It skips:
   - gaps set to *space between* (Figma works those out itself);
   - instances (bind the main component and the instances follow);
   - values that already use variables.
2. **Pick a scale**: 4 pt (2, 4, 8, 12, 16, 20, 24, 28, 32, 40, 48…) or 8 pt (4, 8, 16, 24, 32…).
   With *snap* on, odd values move to the nearest step (13 → 12, 15 → 16). The orange numbers on each
   row show what will change. Click a value to select the layers using it. Corners that make a pill or
   circle become `radius/full`.
3. **Names**: `spacing/16`, `radius/8` or t-shirt sizes `spacing/md`, `radius/sm` (md is 16 for
   spacing and 8 for radius).
4. **Create tokens & bind** makes the FLOAT variables in a collection (new or existing). Spacing
   variables only show in gap/padding fields and radius ones only in corner radius fields. A variable
   that already holds the same value is reused.

Number variables need only one mode, so this works on every Figma plan.
