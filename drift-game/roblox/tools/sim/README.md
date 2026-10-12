# Offline game simulation
Runs the real server and client scripts against a small Roblox mock (no Studio needed), to catch errors
that would otherwise leave players stuck on the loading screen.

    python3 bundle.py ../..          && luau bundle.luau          # server: map build + a fake player's purchases
    python3 bundle_client.py ../..   && luau bundle_client.luau   # server + client: menus, driving, garage, photo mode, tandem

Run from this folder with the `luau` CLI. It checks logic only (no rendering, no real physics engine).
