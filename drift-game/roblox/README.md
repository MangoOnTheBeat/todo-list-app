# Kaido Drift — Roblox version

A Roblox replica of the browser drift game:
- **The real course:** the browser game's 13.7 km Hakone road with its real climbs and drops, hills beside
  the road, Lake Ashi, Kojiri village (houses, lanterns, vending machines), the torii start gate and
  Mt. Fuji on the horizon.
- **All 13 cars** from the browser game, in its body styles (notchback, hatch, fastback, sedan, roadster)
  with pop-up lamps, ducktails, wings, twin exhausts, rim colours and free paint.
- **Physics:** gearbox (automatic or manual, rev limiter, reverse) and clutch kicks.
- **Drift assists, as in the browser:** Easy drift, High, Medium, Low, Pro.
- **Scoring and HUD, as in the browser:** drift tiers, ×multiplier, ANGLE / SPEED / NEAR WALL / TANDEM bonuses,
  laps, zones, minimap.
- **Settings:** graphics (Auto/Low/Medium/High), time of day with Dawn/Noon/Sunset/Midnight, gearbox, assists,
  camera (chase, far chase, cockpit, hood), steering sensitivity, sound and volume, erase progress.
  Everything is saved to the player's Roblox account (DataStore), not the device.
- **Menu:** Play solo, or Play with others on the public map (everyone who picks it drives together, with chat).
- **Engine sound** synthesised for this game: three rpm layers, off-throttle crackle, turbo blow-off, tyres, wind.

## 1. Open it
Double-click `KaidoDrift.rbxlx` (Roblox Studio opens it) and press **Play**. The map is built when the game
starts, so the place looks empty in edit mode. The first start takes a few seconds while the hills fill in.

## 2. Add the sounds (once)
Roblox only plays audio uploaded to Roblox, so upload the 7 files in `sounds/`:
1. In Studio: **Window → Asset Manager → Bulk Import** (or Creator Hub → Creations → Audio → Upload), pick all 7 `.ogg` files.
2. Open the **Toolbox → Inventory → My Audio** and click each one so it lands in Workspace. Keep their names
   (`kaido_engine_low`, `kaido_engine_mid`, …). The game finds them by name.
   Alternatively paste their IDs into `ReplicatedStorage > Shared > SoundIds`.

## 3. Publish
**File → Publish to Roblox**, then **Game Settings → Security → Enable Studio Access to API Services** (so
progress saves while testing in Studio) and set the game to **Public** in Permissions.

## Rebuild from source
`rojo build -o KaidoDrift.rbxlx` (Rojo 7) in this folder. `tools/make_course.py` regenerates
`src/shared/CourseData.luau` from the browser game; `tools/make_sounds.py` regenerates `sounds/`.
