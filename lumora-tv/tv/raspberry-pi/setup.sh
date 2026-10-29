#!/usr/bin/env bash
# Lumora TV box — turns a Raspberry Pi into a box that boots straight into Lumora.
#
# Plug the Pi into a spare HDMI input on your TV. Your TV's own system stays on its
# usual input, so switching between the two is just the remote's Input/Source button.
#
# Tested target: Raspberry Pi 4 or 5 running Raspberry Pi OS (Desktop, Bookworm or newer).
# Run from the folder you copied Lumora into:   bash tv/raspberry-pi/setup.sh
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
APP_DIR="$HOME/lumora"

if [ ! -f "$SRC_DIR/index.html" ]; then
  echo "Can't find index.html next to the tv/ folder ($SRC_DIR). Run this from inside the lumora-tv folder." >&2
  exit 1
fi

echo "==> Copying Lumora to $APP_DIR"
mkdir -p "$APP_DIR"
cp "$SRC_DIR/index.html" "$APP_DIR/index.html"

echo "==> Installing packages (HDMI-CEC tools so your TV remote works, Widevine for streaming sites)"
sudo apt-get update
sudo apt-get install -y v4l-utils
# Widevine lets Chromium play DRM sites such as Netflix or Disney+. Not every service supports it on a Pi.
sudo apt-get install -y libwidevinecdm0 || echo "   (Widevine package not available on this OS release — streaming sites with DRM may not play)"

CHROMIUM="$(command -v chromium-browser || command -v chromium || true)"
if [ -z "$CHROMIUM" ]; then
  sudo apt-get install -y chromium-browser || sudo apt-get install -y chromium
  CHROMIUM="$(command -v chromium-browser || command -v chromium)"
fi

echo "==> Setting up offline voice for the Lumora Assistant (speech is recognised on the Pi)"
VOICE_OK=0
if sudo apt-get install -y python3-venv libportaudio2 unzip wget \
  && python3 -m venv "$APP_DIR/voice-venv" \
  && "$APP_DIR/voice-venv/bin/pip" install --quiet vosk sounddevice websockets; then
  cp "$SRC_DIR/tv/raspberry-pi/voice-server.py" "$APP_DIR/voice-server.py"
  if [ ! -d "$APP_DIR/vosk-model" ]; then
    MODEL=vosk-model-small-en-us-0.15   # about 40 MB; other languages: https://alphacephei.com/vosk/models
    wget -q -O "/tmp/$MODEL.zip" "https://alphacephei.com/vosk/models/$MODEL.zip" \
      && unzip -q -o "/tmp/$MODEL.zip" -d "$APP_DIR" && mv "$APP_DIR/$MODEL" "$APP_DIR/vosk-model" && rm -f "/tmp/$MODEL.zip"
  fi
  [ -d "$APP_DIR/vosk-model" ] && VOICE_OK=1
fi
[ "$VOICE_OK" = 1 ] || echo "   (Offline voice couldn't be set up — the assistant still works by typing)"

echo "==> Writing the launcher"
cat > "$APP_DIR/start-lumora.sh" <<EOF
#!/usr/bin/env bash
# Starts Lumora full screen and restarts it if the browser ever closes.
exec 9>"\$HOME/.lumora.lock"
flock -n 9 || exit 0          # already running
# Offline voice for the assistant (only listens when you ask it to).
if [ -x "$APP_DIR/voice-venv/bin/python" ] && [ -d "$APP_DIR/vosk-model" ]; then
  ( while true; do "$APP_DIR/voice-venv/bin/python" "$APP_DIR/voice-server.py"; sleep 3; done ) &
fi
while true; do
  "$CHROMIUM" --kiosk --noerrdialogs --disable-infobars --no-first-run \\
    --disable-session-crashed-bubble --password-store=basic \\
    --check-for-update-interval=31536000 --autoplay-policy=no-user-gesture-required \\
    "file://$APP_DIR/index.html?tv=1"
  sleep 2
done
EOF
chmod +x "$APP_DIR/start-lumora.sh"

echo "==> Starting Lumora automatically when the desktop loads"
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/lumora.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Lumora
Exec=$APP_DIR/start-lumora.sh
X-GNOME-Autostart-enabled=true
EOF
# labwc (the default desktop on newer Raspberry Pi OS) also reads its own autostart file.
if [ -d "$HOME/.config/labwc" ] || command -v labwc >/dev/null 2>&1; then
  mkdir -p "$HOME/.config/labwc"
  touch "$HOME/.config/labwc/autostart"
  grep -q start-lumora "$HOME/.config/labwc/autostart" || echo "$APP_DIR/start-lumora.sh &" >> "$HOME/.config/labwc/autostart"
fi

echo "==> Letting your TV remote control the Pi over HDMI-CEC"
sudo tee /etc/systemd/system/lumora-cec.service >/dev/null <<'EOF'
[Unit]
Description=Register the Pi as a playback device so the TV remote's arrows, OK and Back reach Lumora
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'for d in /dev/cec*; do [ -e "$d" ] && cec-ctl -d "$d" --playback --osd-name Lumora || true; done'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable lumora-cec.service

echo "==> Booting to the desktop automatically and keeping the screen awake"
if command -v raspi-config >/dev/null 2>&1; then
  sudo raspi-config nonint do_boot_behaviour B4 || true   # desktop, auto-login
  sudo raspi-config nonint do_blanking 1 || true          # no screen blanking
fi

cat <<EOF

Done. Reboot to start Lumora:   sudo reboot

  * Switch between Lumora and your TV's own system with the remote's Input / Source button.
  * Arrows, OK and Back on your TV remote reach Lumora over HDMI-CEC (turn on CEC in the TV's
    settings; brands call it Anynet+, SimpLink, Bravia Sync, etc.). If your TV doesn't pass keys
    through, a cheap USB "air mouse" remote works and also drives the on-screen cursor.
  * Lumora Assistant: plug in a USB microphone (or a voice remote that works as a USB mic), then press the
    mic button or V. Speech is recognised offline on the Pi. Your TV's own built-in mic stays with the TV.
  * To update Lumora later, copy the new index.html and run this script again.
  * To stop it starting automatically:  rm ~/.config/autostart/lumora.desktop
    (and remove the start-lumora line from ~/.config/labwc/autostart if present).
EOF
