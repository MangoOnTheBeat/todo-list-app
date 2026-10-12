# Kaido Drift — Roblox

A Roblox version of the browser game *Kaido Drift*: a midnight Japanese mountain pass, a drivable
rear-wheel-drive drift car with Easy Drift assist, drift scoring that banks as credits, an 8-car
garage saved with DataStoreService, and multiplayer drifting.

## Get it into Studio

**Option A: Rojo (live sync into your open place)**
1. Install the Rojo plugin in Studio and the Rojo CLI (7.4+).
2. In this folder run `rojo serve`, then press **Connect** in the Rojo plugin.
3. Scripts sync to `ReplicatedStorage.Kaido`, `ServerScriptService.KaidoServer` and
   `StarterPlayer.StarterPlayerScripts.KaidoClient`, and `Lighting.Technology` is set to **Future**.

**Option B: open the prebuilt place**
Open `build/KaidoDrift.rbxlx` in Studio (File → Open from File). Rebuild it with
`rojo build default.project.json -o build/KaidoDrift.rbxlx`.

Then:
- **Game Settings → Security → Enable Studio Access to API Services**, so saving works in Studio.
  Without it the game still runs, but progress only lasts for the session (you'll see a warning in Output).
- Optional: put a looping engine sample in `Config.ENGINE_SOUND_ID` (and a tyre squeal in
  `SKID_SOUND_ID`). Pitch and volume already follow RPM and slide; when the IDs are empty the game is silent.

## How to test

1. **Play** (F5). Output should print `[Kaido] map built in …s: 884 road segments, 8837 studs (2.47 km), … trees`
   and then `[Kaido] server ready`. The title screen shows "Building the mountain pass…" until then.
2. Title → **GARAGE**: 8 cars with power, weight and grip bars. Only the PS13 is owned at first.
3. Title → **PLAY**: you spawn on the grid before the torii gate in the village.
   - Keyboard: W/S gas and brake (hold S when stopped to reverse), A/D steer, Space handbrake, C camera, R reset.
   - Gamepad: RT gas, LT brake, left stick steer, B/X/RB handbrake, Y camera, Select reset.
   - Phone/tablet (or Studio's device emulator): left stick steers; GAS, BRAKE and HB buttons on the right.
4. Drift: at 60–80 km/h, hold gas and steer hard (Easy Drift flicks the tail out), or tap the handbrake.
   Then let go of the steering: the assist countersteers and holds the slide. Lift off the gas to straighten.
   The score shows at the top centre; after 1.4 s without sliding it banks as credits (score ÷ 10).
   Hitting a rail, lamp, tree or building loses the drift.
5. Multiplayer: **Test → Clients and Servers → 2 players**. Each player sees the other's car, wheels,
   smoke and skid marks. Drifting within 30 studs of another drifting car gives the ×1.5 TANDEM bonus.
   The player list shows **Best Drift** and **Credits**, and the board in the village plaza shows the global top 10.

## Layout

| Path | What |
|---|---|
| `src/shared/Track.lua` | Centreline of the 2.47 km loop (hairpin ladder, S-bends, lakeside run). Pure Luau. |
| `src/shared/Cars.lua` | Garage catalogue (torque, gears, mass, grip μ, steering lock, price). |
| `src/shared/CarBuilder.lua` | Builds a 90s coupe from parts (pop-ups, wing, ducktail…), plus its wheel geometry. |
| `src/shared/Config.lua` | Physics scale, drift rules, sound IDs, colours. |
| `src/server/MapBuilder.lua` | Terrain, lake, Mt. Fuji, road, guardrails, lamps, cedar forest, lantern village, torii. |
| `src/server/PlayerData.lua` | DataStore: credits, owned cars, selected car, best drift, Easy Drift setting. |
| `src/server/Leaderboard.lua` | leaderstats and the global top-10 board (OrderedDataStore). |
| `src/server/Main.server.lua` | Lighting, remotes, spawning and seating, network ownership, drift banking with sanity caps. |
| `src/client/Drive.lua` | Raycast-suspension RWD drift physics on the client that owns the car. |
| `src/client/Drift.lua` | Score = km/h × angle × 0.5 per second × bonuses, multiplier +0.5 every 1.6 s (max ×5). |
| `src/client/Visuals.lua` | Wheels, steering wheel, tyre smoke, skid marks and engine pitch for every car. |
| `src/client/CameraRig.lua` | Title orbit, chase cam, first-person cockpit. |
| `src/client/UI.lua` | Title, garage, HUD (score, speedometer/gear/RPM, minimap), touch controls. |
| `tools/drift_sim.py` | Offline planar port of the tyre model, used to tune the drift feel. |
| `tools/track_check.luau` | Prints track length, tightest radius, max grade and closest approach between sections. |

## Tuning

- Overall grip and handling: `LAT_GRIP`, the `rearGrip` factors and the Easy Drift block in `Drive.lua`.
- Car character: the per-car numbers in `Cars.lua`.
- Speed and weight feel: `Config.GRAVITY` (52; plain Roblox is 196.2) and `Config.ACC`.
