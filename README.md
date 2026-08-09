# Color Saturation

One dial for how colourful [Gen1Recomp](https://github.com/bryanthaboi/gen1recomp)
is, with the colours themselves left alone.

Install with **Launcher → MODS → Import mod .zip**. **SATURATION** appears both
in the mod's own options (MODS → the mod → `OPTIONS..`) and directly under
**COLORS** on the main OPTIONS menu. It reads live; no restart.

## Why

ADVANCED resolves real per-tile colour and can read hot. Every palette that tones
it down does so by dragging every hue toward one family — sepia goes warm, ocean
goes cool, pocket goes grey. That is a *different look*, not a quieter version of
the same one.

This scales each colour's distance from grey and nothing else:

- luminance stays exactly where it was
- hue stays exactly where it was
- only chroma moves

So **70** is ADVANCED with the shouting turned down — the same greens and reds in
the same places. **0** is a true greyscale derived from the real colours rather
than from a substitute palette. **150** pushes past vanilla if you want it louder.

Worth seeing the difference at 0: each colour greys to *its own* brightness —
`(255,58,8)` → 111, `(58,189,25)` → 131 — where a four-rung greyscale palette
quantises everything onto four fixed values.

| Setting | red `(255, 58, 8)` | chroma |
| --- | --- | --- |
| 100 | (255, 58, 8) | 247 |
| 70 | (212, 74, 39) | 173 |
| 50 | (183, 85, 60) | 123 |
| 0 | (111, 111, 111) | 0 |

## How it works

Four wrapped functions, between them everything the renderer asks for a colour:

| Function | Covers |
| --- | --- |
| `worldGroupColors` | the overworld's eight background palettes |
| `spriteObp` | overworld sprites' OBJ palettes |
| `monPal` | a Pokémon's own colours |
| `effectiveColors` | named palettes — battle backdrops, menus, HUD |

Output is scaled rather than input: `effectiveColors` applies the display mode's
own substitution and the shade map, so scaling on the way in would be discarded
by any mode that forces a palette.

Chroma is scaled about each colour's own luminance using Rec.601 weights — the
same ones the engine's shade classifier uses — so a colour keeps the brightness
rung it already occupied. That is what stops a palette from rendering inside out.

### The bake caches, and why the dial doesn't touch audio

ADVANCED does not shade at draw time, it **bakes** — and into more than one
cache. Map atlases key on `darkKey()`, so extending that suffix keeps two
saturation settings apart, but only for maps loaded *after* a change; the map
you're standing in keeps its atlas. Sprite bakes key on image path and palette
group alone and know nothing about colour, so they'd never rebuild on their own.

Both are flushed by hand on an actual change — but only the caches that can
hold a baked colour (map atlases, sprite bakes, HUD tiles, battle state, map
loader). Early builds flushed *everything* via the engine's general-purpose
`Assets.invalidate()`, which also resets `Sound`/`ChipAudio` and stopped the
music. The flush is also deferred until the menus close, so dragging the dial
through several steps costs one rebuild, not one per step.

At **100** every wrapper calls straight through and the key is untouched, so
leaving it at default costs nothing and cannot invalidate a bake.

## Notes

- Requires `engine_internals`; it patches engine functions rather than shipping art.
- No ROM data or game assets are included.
- Set COLORS to **ADVANCED** for the intended effect. Groovy Palette can stay
  installed — it only intervenes when one of *its* palettes is selected, so on
  ADVANCED it stays out of the way.
- On a four-shade mode (OG, CLASSIC) the dial has little to do: those palettes
  carry almost no chroma to scale.

## Status

**Verified in-game.** Confirmed working across the overworld, interiors and
character sprites, with the dial reachable straight from the OPTIONS menu and
no impact on music or audio.
