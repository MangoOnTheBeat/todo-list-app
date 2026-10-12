# Kaido Drift — Roblox version

A Roblox remake of the browser drift game: a 5.3 km night mountain pass with hairpins, guardrails,
street lamps, cedar and maple trees, a lake and Kojiri village; a drift car with Easy drift (no hand
brake needed); drift scoring that banks credits; a garage of 6 unlockable cars saved with DataStores;
keyboard, controller and phone controls; chase, far-chase and first-person cameras.

Menu: **Play solo** (just you) or **Play with others** (the public map: everyone in the server who
picked it drives together, with chat).

## Open it
Double-click `KaidoDrift.rbxlx` (Roblox Studio opens it), then press **Play**. The map is built when
the game starts, so the place looks empty in edit mode.

To save progress while testing in Studio: Home → Game Settings → Security → turn on
**Enable Studio Access to API Services** (needs the place published first).

## Publish
File → **Publish to Roblox**, then in Game Settings set it to Public.

## Rebuild from source
`rojo build -o KaidoDrift.rbxlx` in this folder (Rojo 7). Source is in `src/`:
`shared/` (Config, Track, CarPhysics, CarModel), `server/Main.server.luau`, `client/Main.client.luau`.
