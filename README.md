# Color Saturation

One dial for how colourful [Gen1Recomp](https://github.com/bryanthaboi/gen1recomp)
is, with the colours themselves left alone.

> **Untested.** The maths is verified but nobody has played with it yet. Released
> as a pre-release for that reason — see [Status](#status).

Install with **Launcher → MODS → Import mod .zip**, then set **SATURATION** in the
mod's options (MODS → the mod → `OPTIONS..`). It reads live; no restart.

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

Three wrapped functions, between them everything the renderer asks for a colour:

| Function | Covers |
| --- | --- |
| `worldGroupColors` | the overworld's eight background palettes |
| `spriteObp` | overworld sprites' OBJ palettes |
| `effectiveColors` | named palettes — battle backdrops, mon colours, menus |

Output is scaled rather than input: `effectiveColors` applies the display mode's
own substitution and the shade map, so scaling on the way in would be discarded
by any mode that forces a palette.

Chroma is scaled about each colour's own luminance using Rec.601 weights — the
same ones the engine's shade classifier uses — so a colour keeps the brightness
rung it already occupied. That is what stops a palette from rendering inside out.

### The bake cache

ADVANCED does not shade at draw time, it **bakes**: tileset atlases and sprite
sheets are rendered once and cached under a key ending in `darkKey()`. Two
saturation settings would otherwise share one cache entry and the second would
show the first one's colours. The engine's own mechanism for this is the
`darkKey` suffix — a dark cave uses it to keep lit and unlit bakes apart — so the
dial rides it.

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

Pre-release, untested in play. The colour maths is verified — luminance is
identical at every setting and chroma scales linearly — but the in-game result
has not been looked at.

Known unknown: whether a change to the dial applies immediately or only after
re-entering a map. If it is the latter, the bake cache needs an explicit
invalidation on `mod.options_changed`.
