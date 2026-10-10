# Kaido Drift 峠

A browser JDM drift game set across a stylised Japan. Open `index.html` in any modern browser — no build step, no install, no login.

## Map
One 4 km closed loop through three regions:
- **首都高 Shuto Loop** — walled city expressway between lit towers and vertical neon signs.
- **箱根 Hakone Pass** — climbing cedar forest, guardrails, chevrons, tight hairpins (16 m radius), a summit torii gate and paper lanterns.
- **湘南 Shonan Coast** — sakura-lined descent beside the sea with Mt. Fuji on the horizon.

Two times of day: golden hour and midnight.

## Controls
| | Keyboard | Touch | Gamepad |
|---|---|---|---|
| Gas | W / ↑ | GAS | RT |
| Brake / reverse | S / ↓ | BRAKE | LT |
| Steer | A D / ← → | drag on the left half | left stick |
| Hand brake | Space / Shift | HAND BRAKE | A / B / RB |
| Camera | C | CAM | Y |
| Reset car | R | ↺ | X |
| Chat | T or Enter | CHAT | — |
| Pause | Esc / P | II | Start |

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
