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
-- colours rather than from a substitute palette, and 150 pushes past vanilla.
--
-- ------- where it hooks
--
--     worldGroupColors   the overworld's eight background palettes
--     spriteObp          overworld sprites' OBJ palettes
--     monPal             a Pokemon's own colours
--     effectiveColors    named palettes -- battle backdrops, menus, HUD
--
-- Output is scaled rather than input: effectiveColors applies the display
-- mode's own substitution and the shade map, so scaling on the way in would
-- be thrown away by any mode that forces a palette.
--
-- ------- caches, which is the whole difficulty
--
-- ADVANCED does not shade at draw time, it BAKES, and it bakes into several
-- caches with DIFFERENT keys:
--
--   * TileRenderer's map atlas keys on PaletteFX.darkKey(), so extending
--     that suffix is enough to keep two settings apart -- but only for maps
--     loaded AFTER the change. The map you are standing in keeps the atlas
--     it was loaded with.
--   * SpriteRenderer's OBJ bake keys on `path .. "#obp" .. group` and knows
--     nothing about palettes at all, so it would never rebuild.
--
-- Both were visible in testing: changing the dial recoloured the outdoors
-- (new maps, new atlases) while the building you were standing in and every
-- character sprite stayed as they were until the game restarted.
--
-- So the darkKey suffix is kept for correctness, and the caches that can
-- hold a baked colour are flushed by hand -- NOT via Assets.invalidate(),
-- which is the engine's "everything changed" signal and drags Sound and
-- ChipAudio down with it, stopping the music. See section 6.
--
-- The flush is also deferred to the moment the menus close, so dragging the
-- dial across ten steps costs one rebuild rather than ten.
--
-- At 100 every wrapper calls straight through and the key is untouched, so
-- leaving it at default costs nothing and cannot invalidate a bake.

local MIN, MAX, STEP = 0, 150, 5

return function(mod)
  mod.options:define({
    -- percent: 0 = greyscale, 100 = untouched, 150 = louder than vanilla
    { key = "amount", label = "SATURATION", type = "number",
      default = 100, min = MIN, max = MAX, step = STEP },
  })

  local PaletteFX = require("src.render.PaletteFX")

  local function amount()
    local ok, value = pcall(function() return mod.options:get("amount") end)
    local n = (ok and tonumber(value)) or 100
    if n < MIN then n = MIN elseif n > MAX then n = MAX end
    return n / 100
  end

  local function clamp255(v)
    v = math.floor(v + 0.5)
    if v < 0 then return 0 elseif v > 255 then return 255 end
    return v
  end

  -- Scale chroma about the colour's OWN luminance. Rec.601 weights, the same
  -- ones the engine's shade classifier uses, so a colour keeps the brightness
  -- rung it already occupied -- which is what stops a palette reading inside
  -- out.
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

  -- ------- 3. Pokemon colours
  --
  -- Their pics are baked from monPal directly. Under the WIDE battle layout
  -- there is no zone pass over the battle surface, so they never reach
  -- effectiveColors and would otherwise stay fully saturated while the world
  -- around them dimmed.
  if not PaletteFX._colorSaturationOriginalMonPal then
    PaletteFX._colorSaturationOriginalMonPal = PaletteFX.monPal
  end
  local originalMonPal = PaletteFX._colorSaturationOriginalMonPal

  PaletteFX.monPal = function(data, species, transformed)
    local colors = originalMonPal(data, species, transformed)
    local k = amount()
    if k == 1 or not colors then return colors end
    return saturateAll(colors, k)
  end

  -- ------- 4. named palettes
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

  -- ------- 5. keep the bakes apart
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

  -- ------- 6. flush what darkKey cannot reach, once, on the way out
  --
  -- 0.2.0 called Assets.invalidate() the moment the value moved. That is the
  -- engine's "everything changed" signal and it runs EVERY registered
  -- invalidator -- including Sound and ChipAudio, which stops the music --
  -- and it did so on every 5% step while the dial was being dragged. Hence
  -- silence and a stutter per keypress.
  --
  -- So: only the caches that can actually hold a baked colour, and only once
  -- the player is back in the world rather than on each step.
  local INVALIDATORS = {
    { "src.render.TileRenderer",   "invalidate" },     -- map atlases
    { "src.render.SpriteRenderer", "invalidate" },     -- OBJ sprite bakes
    { "src.render.HudTiles",       "invalidate" },
    { "src.battle.BattleState",    "invalidate" },
    { "src.world.MapLoader",       "invalidateAll" },  -- future map loads
  }

  local pending = false

  local function flushNow()
    for _, entry in ipairs(INVALIDATORS) do
      pcall(function()
        local mod_ = require(entry[1])
        local fn = mod_ and mod_[entry[2]]
        if type(fn) == "function" then fn() end
      end)
    end
  end

  mod.events:on("mod.options_changed", function(ev)
    if ev and ev.mod == "color-saturation" then pending = true end
  end)

  -- The flush lands on the first overworld frame where the overworld is
  -- itself the top of the stack -- i.e. the menus are closed. That is
  -- "on confirm" without needing a hook the menu does not offer, and it
  -- collapses a whole drag of the dial into one rebuild.
  local Overworld = require("src.world.OverworldController")

  if not Overworld._colorSaturationOriginalUpdate then
    Overworld._colorSaturationOriginalUpdate = Overworld.update
  end
  local originalUpdate = Overworld._colorSaturationOriginalUpdate

  function Overworld:update(dt)
    if pending then
      local ok, top = pcall(function()
        local Game = require("src.core.Game")
        return Game.stack and Game.stack.top and Game.stack:top()
      end)
      if ok and top == self then
        pending = false
        pcall(flushNow)
      end
    end
    return originalUpdate(self, dt)
  end

  -- ------- 7. a row on the OPTIONS menu, next to COLORS
  --
  -- mod.options has get but no set, so the value is written the same way the
  -- mod manager writes it: into save.options.modOptions (persisted) and
  -- loader.modOptions (live), then the same event fires so both screens and
  -- the cache flush agree no matter which one moved it.
  local function currentPercent()
    local ok, value = pcall(function() return mod.options:get("amount") end)
    local n = (ok and tonumber(value)) or 100
    if n < MIN then n = MIN elseif n > MAX then n = MAX end
    return n
  end

  local function setPercent(game, n)
    if n < MIN then n = MIN elseif n > MAX then n = MAX end
    local save = game and game.save
    if save and save.options then
      save.options.modOptions = save.options.modOptions or {}
      local t = save.options.modOptions
      t["color-saturation"] = t["color-saturation"] or {}
      t["color-saturation"].amount = n
    end
    local loader = game and game.mods
    if loader then
      loader.modOptions = loader.modOptions or {}
      loader.modOptions["color-saturation"] =
        loader.modOptions["color-saturation"] or {}
      loader.modOptions["color-saturation"].amount = n
      if loader.events then
        loader.events:emit("mod.options_changed",
          { mod = "color-saturation", key = "amount", value = n })
      end
    end
    -- deliberately does not flush here: the row is being stepped, and the
    -- rebuild waits until the menus close (see the pending flag above)
    pending = true
  end

  mod.hooks:wrap("ui.options.rows", function(next, game, rows)
    local out = next(game, rows)
    if type(out) ~= "table" then return out end
    local row = {
      id = "color_saturation",
      label = "SATURATION",
      value = function() return tostring(currentPercent()) end,
      -- stepping is owned here rather than inherited, so the ends of the
      -- range are reachable: it clamps at MIN and MAX instead of wrapping
      step = function(g, dir)
        local now = currentPercent()
        local want = now + dir * STEP
        if want < MIN then want = MIN elseif want > MAX then want = MAX end
        if want == now then return false end
        setPercent(g or game, want)
        return true
      end,
    }
    for i, r in ipairs(out) do
      if type(r) == "table" and r.id == "colors" then
        table.insert(out, i + 1, row)
        return out
      end
    end
    out[#out + 1] = row
    return out
  end)
end
