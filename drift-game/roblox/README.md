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
Double-click `KaidoDrift.rbxl` (Roblox Studio opens it) and press **Play**. The map is built when the game
starts, so the place looks empty in edit mode. The first start takes a few seconds while the hills fill in.

## 2. Add the sounds (once)
Roblox only plays audio that's on Roblox. Two ways:
- **Quickest (no uploading):** in Studio open **Toolbox › Audio** (Creator Store), search "car engine loop",
  click one so it lands in Workspace, and keep "engine" in its name. Do the same for "tire screech" (and
  "wind" if you like). The game finds them by those words and pitches the engine loop with the revs.
- **Full engine (the game's own sounds):** upload the 7 `kaido_*.ogg` files in `sounds/` (Window › Asset
  Manager › Bulk Import), then click each one in Toolbox › Inventory › My Audio, or paste their IDs into
  `ReplicatedStorage › Shared › SoundIds`. These give three rpm layers, crackle on lift-off and turbo blow-off.
Settings › Sound in the game says which one it's using.

## 3. Special cars (Robux)
Three special cars sit in their own garage section, each faster than the fastest credit car:
FD-7 Spirit Rotor (R$ 149), JZA-80 Apex Omega (R$ 249) and R-34 Raijin Z-Tune (R$ 399). They show
"Coming soon" until you put them on sale:
1. Publish the game, then Creator Hub → your game → **Monetization → Passes → Create a Pass** for each car,
   and set its price (the same as `robux` in `ReplicatedStorage › Shared › Config`).
2. Paste each pass ID into `pass = ...` for that car in `Config` and publish again.
Ownership comes from the pass itself, so it works on every device and survives "Erase progress".

## 4. Publish
**File → Publish to Roblox**, then **Game Settings → Security → Enable Studio Access to API Services** (so
progress saves while testing in Studio) and set the game to **Public** in Permissions.

## Tuning the drift feel
Every assist level runs the same tyre physics; assists only steer and catch for you. Values live in
`ReplicatedStorage › Shared › CarPhysics` (`CarPhysics.ASSISTS`) and per car in `Shared › Cars`.

| What you want | Change | Where |
|---|---|---|
| Easier to start a drift (handbrake / flick) | raise `entry` (0–1): the yaw kick when you yank the hand brake or flick | `ASSISTS.<level>.entry` |
| Less spinning out for new players | raise `counter` (auto-countersteer, 0–1) and `damp` (yaw damping) | `ASSISTS.std` / `high` / `touch` |
| Hold angle with throttle more easily | `thrMod = true` feeds throttle to keep the angle; lower `esp` lets you hold more angle | `ASSISTS.<level>` |
| Snappier / slower steering | `steerRate` (how fast the wheels reach your input) | `ASSISTS.<level>.steerRate` |
| Deeper drift angle on a car | `lock` (degrees of steering lock) | `Cars.<car>.lock` |
| More / less grip | `mu` (tyre friction, ~1.0–1.25) | `Cars.<car>.mu` |
| Easier to break traction | more `torque`, or move weight back (`front` lower) | `Cars.<car>` |
| Tyre curve shape | `KPK` (slip ratio peak), `APK` (slip angle peak, radians) | top of `CarPhysics` |

Smoke density follows rear-tyre slip × drift angle (`Main.client` → "tyre smoke"); skid marks keep the last 400
marks on the road (`Fx.setSkidLimit`).

## Scoring
Points = speed × drift angle × time, with bonuses: TANDEM (×1 to ×2, closer is more), NEAR WALL ×1.35,
ANGLE >45° ×1.15, SPEED >110 km/h ×1.15. The **combo** starts at ×1 and goes up ×0.5 every 2.5 s of sliding
and every time you link into the next drift (switching direction, or re-entering within 1.4 s), up to ×6.
Driving straight for 1.4 s banks the chain (one credit per ten points); a crash loses it and resets the combo.

## Track design notes (how the course and city are laid out)
- **Road width:** the pass is 44 studs (12.5 m) wide, about three car-widths: room to drift at 60° without
  the nose or tail touching the rails. City streets are 48 studs; avenues (every 4th street) have 4 lanes.
- **Corners:** the tightest hairpins on the pass have a radius of 25–40 studs (7–11 m); most sweepers are
  40–150 studs. Chevron boards mark every corner under ~50 studs radius, on the outside, pointing the way it turns.
- **Barriers:** guardrails sit just off the asphalt and give a glancing bounce (wall impulse with 30%
  friction), so a light tap keeps your speed; only hard hits (>6.5 m/s into the wall) count as a crash.
  Neon edge lines run along both edges so the road reads at night.
- **Your own layout:** for a new drift section use sweeping 30–60 m radius corners linked by short straights
  (S-bends make the best combos), 1–2 hairpins of 10–15 m radius, and keep barriers ≥2 m off the road edge on the
  outside of fast corners.

## Garage, leaderboards and challenges
- **Upgrades** per car: Engine, Turbo, Tyres, Steering angle (3 levels each) change the real physics numbers.
  **Style:** underglow neon, rim colour, stance kit. Drag the car in the garage to turn it.
- **Leaderboards:** best single drift and total points (OrderedDataStore), on the title screen and on the
  neon gantry over the street at the city start. Needs **Enable Studio Access to API Services** to test in Studio.
- **Daily challenges:** three a day for everyone (new at 00:00 UTC), each paying credits.
- **Photo mode:** pause → Photo mode; drag to orbit, scroll or pinch to zoom.

## Admin panel (only you)
Once the game is published under your account you're the owner, and only the owner sees **Admin panel** on the
title and pause menus (or presses **F2**). In Studio you're always admin. To add someone else, put their Roblox
user ID in `Config.Admins`. Every action is checked again on the server, so other players can't use it even
with a hacked client. It can give or take credits, unlock every garage car, give the special cars, max a car's
upgrades, reset a player's daily challenges, remove a cheater from the leaderboards, teleport to a player on
the public map, kick, and send an announcement to everyone (filtered by Roblox, as its rules require).

## Rebuild from source
`rojo build -o KaidoDrift.rbxl` (Rojo 7) in this folder. `tools/make_course.py` regenerates
`src/shared/CourseData.luau` from the browser game; `tools/make_sounds.py` regenerates `sounds/`.
