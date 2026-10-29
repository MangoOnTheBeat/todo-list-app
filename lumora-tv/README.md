# Lumora OS — concept TV interface

Lumora is a web app: one file, `index.html`, that runs full screen in a browser and is driven by a TV remote, keyboard, mouse or touch. It is a concept and is not affiliated with Apple, Netflix, Disney, Google or any other brand shown in it. You sign in and pay for services such as Disney+ on their own official sites.

## Using it on your TV

Lumora can't replace the system built into your TV. Smart TVs (Samsung Tizen, LG webOS, Google TV and others) have locked firmware, and trying to flash it can brick the TV and void the warranty. These options work:

| | What you need | How you "swap OS" | Effort |
|---|---|---|---|
| **0. Google TV device + Lumora app** (best: a real home screen) | A Google TV Streamer or Chromecast with Google TV, plugged into an HDMI port | Lumora *is* the home screen; the TV's own system stays on its HDMI input | About 20 minutes |
| **1. TV web browser** | Nothing extra | Open or close the browser | 5 minutes |
| **2. Lumora TV box** (recommended) | Raspberry Pi 4/5, power supply, microSD, HDMI cable | Remote's **Input / Source** button | About 30 minutes |
| **3. App on an LG or Samsung TV** | A PC and the TV maker's free developer tools | Open Lumora from the TV's app list | About 1 hour (advanced) |

### 0. Lumora as the home screen on a Google TV device (recommended)

Your Hisense U7 runs VIDAA, which can't install Android apps. A Google TV device plugged into one of the TV's HDMI ports can, and there Lumora replaces the home screen. Netflix, YouTube, Disney+ and the rest run as the real apps, at full quality, with their own sign-in and subscriptions.

1. **Get the app.** Open the repository on GitHub, go to *Actions → Lumora Android TV app*, open the latest green run and download **lumora-tv-apk** (a zip with `app-debug.apk` inside).
2. **Install it.** On the Google TV, open *Settings → System → About* and press *Android TV OS build* 7 times to turn on developer options. Then use either:
   - **Downloader** (free from Google Play): allow it under *Settings → Apps → Security & restrictions → Unknown sources*, put the APK online, and open its link in Downloader.
   - **adb** from a computer on the same Wi-Fi: turn on *Developer options → USB debugging* (or *Wireless debugging*), then run `adb connect <tv-ip>` and `adb install app-debug.apk`.
3. **Make it the home screen.** Google TV has no setting to change the home screen, so this needs adb (it's fully reversible):
   ```
   adb shell pm disable-user --user 0 com.google.android.apps.tv.launcherx
   adb shell pm disable-user --user 0 com.google.android.tungsten.setupwraith
   ```
   Press Home and choose **Lumora**, then **Always**. **To go back to Google TV's own home screen:**
   ```
   adb shell pm enable com.google.android.apps.tv.launcherx
   adb shell pm enable com.google.android.tungsten.setupwraith
   ```
   If you'd rather not use adb, open Lumora from the app list instead. Everything works, but the Home button goes to Google TV's home screen.
4. **Optional: show what's playing in Control Centre.** Android only lets an app read the current song or video once you grant it notification access. On most Google TV devices there's no menu for this, so run:
   `adb shell cmd notification allow_listener app.lumora.tv/app.lumora.tv.MediaListener`
   Play, pause and skip already work without it.
5. **Optional: real new releases in For You.** Make a free account at themoviedb.org, go to *Settings → API* to get a key, and type it into *Lumora Settings → For You*.

**Switching between Lumora and VIDAA:** press **Input** on the Hisense remote and choose the Google TV's HDMI port for Lumora, or *TV / Home* for VIDAA. With HDMI-CEC on (*Settings → System → HDMI & CEC* on the Hisense), the Hisense remote's arrows, OK and Back control Lumora, and switching the TV off also puts the Google TV to sleep.

**Power and resume.** If the TV is switched off and back on within the resume window (*Settings → Power & Startup*, 1 minute by default), Lumora returns to the same screen and item. An app that was open stays open, because Android keeps it running while asleep. Lumora's own *Turn off* plays the switch-off animation and goes to standby; your remote's power button switches the TV itself off. A full power cut restarts the Google TV, which usually takes longer than a minute, so a longer resume window helps there.

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
