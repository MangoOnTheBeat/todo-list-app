# Kaido Drift 峠

A browser JDM drift game set across a stylised Japan. Open `index.html` in any modern browser — no build step, no install, no login.

## Map — real Hakone terrain at 1:1 scale
The world is built from real elevation data for Hakone, Japan, at true scale:
- **Near area (4 × 4 km, ~8 m detail)** around the north end of **Lake Ashi (芦ノ湖)** at Kojiri, including the real lake outline and the Hakone caldera hills.
- **Far area (72 × 72 km, 150 m detail)** with the real **Mt. Fuji** about 27 km to the west-north-west, Sagami Bay, Suruga Bay, and the lowland towns (Odawara, Gotemba, Mishima) shown as night lights.

The 5.3 km course was placed on that land by an automated search for the position with the least earthworks and gentlest grades. The road follows the real ground, smoothed and held to 10 % grade. It has three sections: **湖尻 Kojiri village**, the **箱根 Hakone hills** hairpins (about 140 m of climb) and the **芦ノ湖 Lake Ashi shore**. As in real life, Fuji's summit just clears the western caldera rim from the upper hills and is hidden from the lakeshore.

**What is real and what isn't:** the terrain, lake and mountains are real data. The road layout, buildings, trees and signs are the game's own design placed on that land; they are not a survey of real roads. The terrain data is public-domain-derived; see Credits.

Default time is **midnight**: a painted sky with ~9,000 stars and the Milky Way, twinkling bright stars, a textured moon low over the lake, moonlight on Fuji's snow cap, and the glow of distant towns on the horizon. A sunset option remains in Settings.

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

## Physics
- Two-axle vehicle model with a combined-slip tyre curve (grip peaks around 8° of slip, then slides at ~85 %), so throttle, brakes and steering all compete for the same tyre grip.
- Longitudinal weight transfer: braking loads the front tyres, throttle loads the rears.
- The driven rear axle has its own wheel speed: power oversteer, wheelspin, hand-brake lock-up and clutch-in hand-brake turns happen on their own rather than being scripted.
- Per-car engine torque curve, rev limiter, real gear ratios and final drive; automatic or manual gearbox. 0–100 km/h ranges from 4.8 s (JZA-80) to 6.8 s (AE8).
- Speed-sensitive steering with full lock available when countersteering; steering lock from 50° to 60°.
- Wall hits use rigid-body impulses at the corner that touches, so clipping a rail spins the car the way it should.
- **Countersteer assist** (Settings): High / Standard / Low steer the slide angle toward a target set by throttle and steering. **Off** is the raw simulation.

## Drifting and progression
Kick the rear out with the hand brake (or full throttle + steering), then hold the slide with throttle and countersteer. Score = speed × angle, with a combo multiplier up to ×5 and bonuses for **TANDEM** (drifting next to an AI car), **NEAR WALL**, **ANGLE** (> 45°) and **SPEED** (> 110 km/h). Hitting a wall hard loses the unbanked drift. Every 10 points banked = 1 credit; a full lap pays 500 credits.

Credits unlock 6 more cars in the garage (starter: **Hoshi PS13 Spirit**, a 1989 pop-up-lamp coupe). Paint is free for owned cars.

## Saving
Progress saves automatically to the browser's `localStorage` on the device — no account, no cookies. Settings → *Move progress to another device* gives a copyable transfer code (`KD1.…`, checksummed) that can be imported in another browser.

A web page cannot read a hardware ID (HWID); browsers block that on purpose, and fingerprinting a device to identify someone would need consent under privacy laws such as GDPR/ePrivacy. The random player ID in local storage plus the transfer code gives the same "no login" result legally.

## Legal
- All car names, makers and designs are fictional (Hoshi, Kaze, Akagi). No real manufacturer names, logos or trademarked model names are used; chassis-style codes are era references only. The in-game legal screen says the project is unaffiliated with any manufacturer.
- The other drivers and their chat lines are computer-controlled and labelled **AI** everywhere they appear.
- No cookies, analytics, ads or trackers. The only third-party requests are three.js from jsDelivr and fonts from Google Fonts (disclosed in-game).
- three.js is MIT licensed; Dela Gothic One and Chakra Petch are SIL OFL. Everything else is original and generated in the browser.

## Graphics
three.js r160: ACES tone mapping, physical sky with image-based reflections, clear-coat car paint, soft shadows, bloom, instanced forests and city, tyre smoke and skid marks. Quality tiers (Low / Medium / High) are picked automatically per device and drop a step if the frame rate falls below ~38 fps.

## Credits
Elevation: Terrain Tiles on AWS (Mapzen / Linux Foundation), derived from NASA SRTM, USGS GMTED2010 and NOAA ETOPO1.
