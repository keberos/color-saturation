-- Color Saturation
--
-- One dial for how colourful the game is, with the colours themselves left
-- alone. ADVANCED resolves real per-tile colour and can read hot; every
-- palette that tones it down does so by dragging every hue toward one family
-- -- sepia goes warm, ocean goes cool, pocket goes grey. That is a different
-- look, not a quieter version of the same one.
--
-- This scales each colour's distance from grey and nothing else:
--
--     luminance stays exactly where it was
--     hue stays exactly where it was
--     only chroma moves
--
-- So 70 is ADVANCED with the shouting turned down, still the same greens and
-- reds in the same places. 0 is a true greyscale derived from the real
-- colours rather than from a substitute palette, and 150 pushes past vanilla
-- if you want it louder.
--
-- ------- where it hooks
--
-- The same three colour-producing functions Groovy Palette wraps, which are
-- between them everything the renderer asks for a colour:
--
--     worldGroupColors   the overworld's eight background palettes
--     spriteObp          overworld sprites' OBJ palettes
--     effectiveColors    named palettes -- battle backdrops, mon colours, menus
--
-- Output is scaled rather than input: effectiveColors applies the display
-- mode's own substitution and the shade map, so scaling on the way in would
-- be thrown away by any mode that forces a palette.
--
-- ------- the cache
--
-- ADVANCED does not shade at draw time, it BAKES: tileset atlases and sprite
-- sheets are rendered once and cached under a key ending in darkKey(). Two
-- saturation settings would otherwise share one cache entry and the second
-- would show the first one's colours. The engine's own mechanism for this is
-- the darkKey suffix -- a dark cave uses it to keep lit and unlit bakes
-- apart -- so the dial rides it.
--
-- At 100 every wrapper calls straight through and the key is untouched, so
-- leaving it at default costs nothing and cannot invalidate a bake.

return function(mod)
  mod.options:define({
    -- percent: 0 = greyscale, 100 = untouched, 150 = louder than vanilla
    { key = "amount", label = "SATURATION", type = "number",
      default = 100, min = 0, max = 150, step = 5 },
  })

  local PaletteFX = require("src.render.PaletteFX")

  local function amount()
    local ok, value = pcall(function() return mod.options:get("amount") end)
    local n = (ok and tonumber(value)) or 100
    return n / 100
  end

  local function clamp255(v)
    v = math.floor(v + 0.5)
    if v < 0 then return 0 elseif v > 255 then return 255 end
    return v
  end

  -- Scale chroma about the colour's OWN luminance. Rec.601 weights, the same
  -- ones the engine's shade classifier and Groovy's curve use, so a colour
  -- keeps the brightness rung it already occupied -- which is what stops a
  -- palette from reading inside out.
  local function saturate(c, k)
    if type(c) ~= "table" or not c[1] then return c end
    local l = 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3]
    return {
      clamp255(l + (c[1] - l) * k),
      clamp255(l + (c[2] - l) * k),
      clamp255(l + (c[3] - l) * k),
    }
  end

  local function saturateAll(colors, k)
    if type(colors) ~= "table" then return colors end
    local out = {}
    for i, c in ipairs(colors) do out[i] = saturate(c, k) end
    return out
  end

  -- ------- 1. the overworld's background palettes
  if not PaletteFX._colorSaturationOriginalWorld then
    PaletteFX._colorSaturationOriginalWorld = PaletteFX.worldGroupColors
  end
  local originalWorld = PaletteFX._colorSaturationOriginalWorld

  PaletteFX.worldGroupColors = function(data, tileset, mapId, playerCellY)
    local groups = originalWorld(data, tileset, mapId, playerCellY)
    local k = amount()
    if k == 1 or type(groups) ~= "table" then return groups end
    local out = {}
    for i, palette in ipairs(groups) do out[i] = saturateAll(palette, k) end
    return out
  end

  -- ------- 2. overworld sprites
  if not PaletteFX._colorSaturationOriginalObp then
    PaletteFX._colorSaturationOriginalObp = PaletteFX.spriteObp
  end
  local originalObp = PaletteFX._colorSaturationOriginalObp

  PaletteFX.spriteObp = function(spriteDef, seed)
    local colors, group = originalObp(spriteDef, seed)
    local k = amount()
    if k == 1 or not colors then return colors, group end
    return saturateAll(colors, k), group
  end

  -- ------- 3. named palettes
  if not PaletteFX._colorSaturationOriginalColors then
    PaletteFX._colorSaturationOriginalColors = PaletteFX.effectiveColors
  end
  local originalColors = PaletteFX._colorSaturationOriginalColors

  PaletteFX.effectiveColors = function(c)
    local out = originalColors(c)
    local k = amount()
    if k == 1 then return out end
    return saturateAll(out, k)
  end

  -- ------- 4. keep the bakes apart
  if not PaletteFX._colorSaturationOriginalDarkKey then
    PaletteFX._colorSaturationOriginalDarkKey = PaletteFX.darkKey
  end
  local originalDarkKey = PaletteFX._colorSaturationOriginalDarkKey

  PaletteFX.darkKey = function()
    local base = originalDarkKey()
    local k = amount()
    if k == 1 then return base end
    return base .. "#sat:" .. tostring(math.floor(k * 100 + 0.5))
  end
end
