# Lumora OS — concept TV interface

Lumora is a web app: one file, `index.html`, that runs full screen in a browser and is driven by a TV remote, keyboard, mouse or touch. It is a concept and is not affiliated with Apple, Netflix, Disney, Google or any other brand shown in it. You sign in and pay for services such as Disney+ on their own official sites.

## Using it on your TV

Lumora can't replace or "dual boot" the system built into your TV. Smart TVs (Samsung Tizen, LG webOS, Google TV and others) have locked firmware, and trying to flash it can brick the TV and void the warranty. These three options work, from easiest to most complete:

| | What you need | How you "swap OS" | Effort |
|---|---|---|---|
| **1. TV web browser** | Nothing extra | Open or close the browser | 5 minutes |
| **2. Lumora TV box** (recommended) | Raspberry Pi 4/5, power supply, microSD, HDMI cable | Remote's **Input / Source** button | About 30 minutes |
| **3. App on an LG or Samsung TV** | A PC and the TV maker's free developer tools | Open Lumora from the TV's app list | About 1 hour (advanced) |

### 1. In your TV's web browser (quickest)

1. Put `index.html` somewhere your TV can reach. The easiest way is **GitHub Pages**: on GitHub, go to *Settings → Pages*, choose *Deploy from a branch*, pick this branch and the `/ (root)` folder, then save. Lumora will be at `https://<your-username>.github.io/<repo>/lumora-tv/?tv=1`. On a free plan the repository must be public for Pages to work.
2. Open that address in the TV's browser and bookmark it.
3. Press OK on **Control Centre → Full screen**.

`?tv=1` makes streaming apps open in the same tab, so your remote's Back key brings you back to Lumora. TV browsers are often slow and some streaming sites won't play in them, so this is best for trying Lumora out.

### 2. A Lumora TV box: the "dual boot" option (recommended)

This is the closest thing to dual-booting. A Raspberry Pi on a spare HDMI input boots straight into Lumora, while your TV's own system stays on its usual input. Switch between them with the remote's **Input / Source** button. There's nothing to reboot, and the two systems can't break each other.

1. Install **Raspberry Pi OS (Desktop)** on a microSD card with *Raspberry Pi Imager*, then boot the Pi connected to the TV.
2. Copy this `lumora-tv` folder onto the Pi (USB stick or `git clone`).
3. Open a terminal in that folder and run:
   ```bash
   bash tv/raspberry-pi/setup.sh
   sudo reboot
   ```
4. Turn on **HDMI-CEC** in your TV's settings. Brands give it their own name: Samsung *Anynet+*, LG *SimpLink*, Sony *Bravia Sync*, Philips *EasyLink*. Your normal TV remote's arrows, OK and Back then control Lumora. If your TV doesn't pass the keys through, a cheap USB "air mouse" remote works instead, and it also moves the on-screen cursor.

What the script does: it copies Lumora to `~/lumora`, starts Chromium full screen on login (restarting it if it closes), turns off screen blanking, installs Widevine so DRM streaming sites can play, and registers the Pi with the TV over HDMI-CEC.

You should know this before you buy: streaming services usually limit browsers on a Raspberry Pi to lower quality (often 720p or 1080p, with no 4K, HDR or Dolby Vision), and a few won't play at all. For the best picture, watch those services in your TV's own apps on its own input, and use Lumora for everything else.

**True dual boot on the Pi (optional):** if you want a boot menu with two systems on the Pi itself, a multi-boot installer such as **PINN** can put Raspberry Pi OS (with Lumora) next to another system such as **LibreELEC** (Kodi). You pick one when the Pi powers on.

### 3. As an app on an LG or Samsung TV (advanced)

Both companies let you install your own web apps through their free developer modes. This folder includes starter manifests, but they haven't been tested on a real TV yet.

- **LG (webOS):** install the *Developer Mode* app on the TV and the webOS CLI on your PC. Copy `index.html` into `tv/lg-webos/`, then run `ares-package tv/lg-webos` and `ares-install --device <tv> com.lumora.concept_2.0.0_all.ipk`.
- **Samsung (Tizen):** turn on Developer Mode on the TV and install *Tizen Studio* on your PC. Copy `index.html` into `tv/samsung-tizen/`, then build and install that folder as a TV web app, signed with your own Samsung certificate.

Developer-mode installs on LG need renewing every few days unless you extend them in the Developer Mode app. Inside these apps, streaming services open as websites; your TV's own Netflix or YouTube apps stay where they always are on the TV's home screen.

## Remote keys

| Action | Keys |
|---|---|
| Move | Arrows / D-pad |
| Select | OK · Enter |
| Back | Back · Esc · Backspace |
| Home | Home · H |
| App options (move / remove) | Hold OK · Menu · O |
| Remote cursor | C (then arrows move, OK clicks, Back turns it off) |
