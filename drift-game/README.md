# Kaido Drift 峠

A browser JDM drift game set across a stylised Japan. Open `index.html` in any modern browser — no build step, no install, no login.

## Map — real Hakone terrain at 1:1 scale
The world is built from real elevation data for Hakone, Japan, at true scale:
- **Near area (4 × 4 km, ~8 m detail)** around the north end of **Lake Ashi (芦ノ湖)** at Kojiri, including the real lake outline and the Hakone caldera hills.
- **Far area (72 × 72 km, 150 m detail)** with the real **Mt. Fuji** about 27 km to the west-north-west, Sagami Bay, Suruga Bay, and the lowland towns (Odawara, Gotemba, Mishima) shown as night lights.

The **12.3 km** course is fitted onto a 5 × 5 km area of real terrain around the north end of Lake Ashi, about 250 m of real climb. It has 151 corners: S-bends through Kojiri village, a long mountain section of tight switchbacks, and the lakeshore road. The longest straight is under 100 m. It is checked automatically: tightest radius 18 m, at least 88 m between separate stretches of road, never in the lake. A lap takes roughly 10–15 minutes.

**What is real and what isn't:** the terrain, lake and mountains are real data. The road layout, buildings, trees and signs are the game's own design placed on that land; they are not a survey of real roads. The terrain data is public-domain-derived; see Credits.

Time of day runs on a 24-hour clock (Settings slider, or Dawn / Noon / Sunset / Midnight in the pause menu). The sun follows its real mid-October path over Hakone: sunrise ~05:45, ~47° high at noon, sunset ~17:15. Default time is **midnight**: a painted sky with ~9,000 stars and the Milky Way, twinkling bright stars, a textured moon low over the lake, moonlight on Fuji's snow cap, and the glow of distant towns on the horizon.

## Controls
| | Keyboard | Touch | Gamepad |
|---|---|---|---|
| Gas | W / ↑ | GAS | RT |
| Brake / reverse | S / ↓ | BRAKE | LT |
| Steer | A D / ← → | drag on the left half | left stick |
| Hand brake | Space / Shift | HAND BRAKE | A / B |
| Camera (chase · far · **first-person cockpit** · hood) | C or V | CAM | Y |
| Shift up / down (manual gearbox) | E / Q | — | RB / LB |
| Reset car | R | ↺ | X |
| Chat | T or Enter | CHAT | — |
| Pause | Esc / P | II | Start |

## Cameras
Four views: chase, far chase, **cockpit (first person)** and hood. The cockpit has a right-hand-drive interior with a steering wheel that turns with the front wheels, working tachometer and speedometer needles, a shift light, mirror, pillars and seats. In a slide the driver's view looks into the drift.

## Physics (sim-style, inspired by CarX)
CarX Drift Racing's physics code is private, so it is not copied; this is an original simulation of the same kind:
- **Four tyres simulated separately**, each with its own load, slip angle, slip ratio and grip (combined-slip tyre curve with load sensitivity).
- **Weight transfer** front/rear under throttle and braking, and side to side in corners (62 % of roll stiffness at the front), so the inside wheels unload.
- **Locked rear differential** (drift setup): both rear wheels share one speed, which produces wheelspin, power oversteer and the push you feel from a welded diff.
- **Ackermann steering**, real steering lock per car (48–62°), engine torque curves, turbo lag, gearbox, clutch kick, handbrake that locks the rears, brakes that can lock the fronts.
- **No invisible helper forces**: the car only moves because of its tyres.

### Drift assists (Settings)
| Level | What it does |
|---|---|
| **Pro** | Nothing. Pure simulation, raw steering rack, no ABS. |
| **Low** | Light countersteer assist, light drift entry, ABS, speed-sensitive steering for keyboard/touch. |
| **Medium** (default) | Stronger countersteer assist, drift entry, slide damping, stability control past ~65°. |
| **High** | Near-full countersteer assist, strong drift entry and throttle feed, slide damping, stability control, traction control. |
| **Easy drift** (default on phones and tablets) | Full drift entry, throttle feed and countersteer, tuned for an on/off GAS button and thumb steering. No hand brake needed. |

Drift entry: steering firmly (over ~65 %) with the gas on above ~30 km/h kicks the rear out once per steer input, so a drift starts without the hand brake; it also links direction changes. Throttle feed eases the gas past ~26° of slide so a held GAS button holds the angle instead of spinning. Countersteer assist turns the front wheels toward where the front of the car is travelling, but only in a real slide (the car rotating against its path), so normal cornering is untouched. Slide damping slows sudden angle changes; it never pulls the car to a set angle. Measured with an automated driver trying 120 driving styles, the share that can hold a 6-second drift rises from 0 % on Pro to ~44 % on High.

## Drifting and progression
Kick the rear out with the hand brake (or full throttle + steering), then hold the slide with throttle and countersteer. Score = speed × angle, with a combo multiplier up to ×5 and bonuses for **TANDEM** (drifting next to an AI car), **NEAR WALL**, **ANGLE** (> 45°) and **SPEED** (> 110 km/h). Hitting a wall hard loses the unbanked drift. Every 10 points banked = 1 credit; a full lap pays 500 credits.

Credits unlock 6 more cars in the garage (starter: **Hoshi PS13 Spirit**, a 1989 pop-up-lamp coupe). Paint is free for owned cars.

## Play modes
- **Solo**: just you; no AI, no chat. Works with no internet connection: `dist/kaido-drift.html` is fully self-contained (three.js bundled in), so it runs even opened straight from disk. When served from the server it also installs as an app (Add to Home Screen) and keeps working offline.
- **With AI drivers**: seven AI drivers labelled AI, with AI chat.
- **Online**: join a Kaido Drift server, see other players' cars live (ghost cars, no collisions) and chat with them. `/mute name` and `/unmute name` hide a player's messages.

## Running the online server
```
cd drift-game
npm install
npm run build      # makes dist/kaido-drift.html, manifest, service worker
npm start          # PORT=8080 by default
```
Open `http://localhost:8080`. Online mode connects to the same address automatically (`ws://host/ws`).

To make it public, deploy this folder to any Node host that supports WebSockets (for example Render, Railway, Fly.io or a VPS): build command `npm install && npm run build`, start command `npm start`. Use HTTPS so the game connects over `wss://`. `/health` reports players and rooms.

Server safeguards: 16 players per room (new rooms open automatically), position updates checked and clamped, chat rate limit (about one message every 2 s, bursts of 3), 120-character limit, word filter (extend with `BLOCKED_WORDS=word1,word2`), links blocked, names cleaned and made unique, at most 4 connections per IP.

**Online play does not work inside the claude.ai preview**, which blocks network connections; use the server address.

## Saving
Progress saves automatically to the browser's `localStorage` on the device — no account, no cookies. Settings → *Move progress to another device* gives a copyable transfer code (`KD1.…`, checksummed) that can be imported in another browser.

A web page cannot read a hardware ID (HWID); browsers block that on purpose, and fingerprinting a device to identify someone would need consent under privacy laws such as GDPR/ePrivacy. The random player ID in local storage plus the transfer code gives the same "no login" result legally.

## Legal
- All car names, makers and designs are fictional (Hoshi, Kaze, Akagi). No real manufacturer names, logos or trademarked model names are used; chassis-style codes are era references only. The in-game legal screen says the project is unaffiliated with any manufacturer.
- The other drivers and their chat lines are computer-controlled and labelled **AI** everywhere they appear.
- No cookies, analytics, ads or trackers. The only third-party requests are three.js from jsDelivr and fonts from Google Fonts (disclosed in-game).
- three.js is MIT licensed; Dela Gothic One and Chakra Petch are SIL OFL. Everything else is original and generated in the browser.

## Graphics
Roadside detail: textured asphalt with a normal map (worn markings, cracks, patches), gravel shoulders, red/white kerbs on the inside of corners, W-beam guardrails with amber reflectors, yellow curve-warning signs before corners, utility poles with sagging wires, grass and silver-grass verges, rocks on steep banks, rounded cedar and maple trees, drifting clouds tinted by the time of day, and fine relief on the terrain.
three.js r160: ACES tone mapping, physical sky with image-based reflections, clear-coat car paint, soft shadows, bloom, instanced forests and city, tyre smoke and skid marks. Quality tiers (Low / Medium / High) are picked automatically per device and drop a step if the frame rate falls below ~38 fps.

## Credits
Elevation: Terrain Tiles on AWS (Mapzen / Linux Foundation), derived from NASA SRTM, USGS GMTED2010 and NOAA ETOPO1.
