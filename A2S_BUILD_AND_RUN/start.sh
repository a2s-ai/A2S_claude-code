#!/usr/bin/env bash
# Developed: Daniel Plominski for A2S.AI (18.01.2026)

set -euo pipefail

export DISPLAY=:1

echo "=== Starting X + VNC + noVNC ==="

DISPLAY_NUM="${DISPLAY_NUM:-1}"
DISPLAY=":${DISPLAY_NUM}"
RESOLUTION="${RESOLUTION:-1600x900}"
DEPTH="${DEPTH:-16}"

VNC_PORT="${VNC_PORT:-5900}"
NOVNC_PORT="${NOVNC_PORT:-10001}"

# Set VNC Password
VNC_PASSWORD="${VNC_PASSWORD:-claude}"
X11VNC_PASSFILE="/tmp/x11vnc.pass"

cleanup() {
  echo "=== Cleanup ==="
  pkill -P $$ || true
  rm -f /tmp/.X*-lock 2>/dev/null || true
  rm -rf /tmp/.X11-unix 2>/dev/null || true
}
trap cleanup EXIT

# Clean up stale X locks/sockets
rm -f /tmp/.X${DISPLAY_NUM}-lock 2>/dev/null || true
rm -f /tmp/.X11-unix/X${DISPLAY_NUM} 2>/dev/null || true

# Fix: /etc/hosts for sudo
HOSTNAME="$(hostname)"
if ! grep -q "$HOSTNAME" /etc/hosts; then
  sudo echo "127.0.0.1 $HOSTNAME" >> /etc/hosts
fi

# Ensure X11 socket dir exists (required for non-root Xvfb)
sudo mkdir -p /tmp/.X11-unix
sudo chmod 1777 /tmp/.X11-unix

echo "Starting Xvfb on ${DISPLAY}..."
Xvfb "${DISPLAY}" -screen 0 "${RESOLUTION}x${DEPTH}" -ac +extension GLX +render -noreset &
XVFB_PID=$!

# Xvfb take a deep breath
for i in {1..20}; do
  if xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
done
if ! xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
  echo "ERROR: Xvfb did not become ready"
  exit 1
fi
echo "Xvfb ready (pid=${XVFB_PID})"

export DISPLAY="${DISPLAY}"

# Tiling Window
mkdir -p /home/node/.local/bin

cat <<'EOF' > /home/node/.local/bin/wmctrl-autosplit.sh
#!/bin/sh
# Developed: Daniel Plominski for A2S.AI (23.01.2026)

# static res (Xvfb)
SCREEN_W=1600
SCREEN_H=900
HALF_W=800

handle_windows() {
  wmctrl -lx | while read wid desk cls host title; do
    case "$cls" in
      *x-terminal-emulator.X-terminal-emulator*)
        wmctrl -i -r "$wid" -b remove,maximized_vert,maximized_horz
        wmctrl -i -r "$wid" -e 0,0,0,$HALF_W,$SCREEN_H
        ;;
      *chromium.Chromium*)
        wmctrl -i -r "$wid" -b remove,maximized_vert,maximized_vert
        wmctrl -i -r "$wid" -e 0,$HALF_W,0,$HALF_W,$SCREEN_H
        ;;
      *google-chrome.Google-chrome*)
        wmctrl -i -r "$wid" -b remove,maximized_vert,maximized_vert
        wmctrl -i -r "$wid" -e 0,$HALF_W,0,$HALF_W,$SCREEN_H
        ;;
    esac
  done
}

# initial run
handle_windows

# listen for new windows
xprop -root -spy _NET_CLIENT_LIST | while read _; do
  sleep 0.2
  handle_windows
done
EOF

chmod +x /home/node/.local/bin/wmctrl-autosplit.sh
chown -R node:node /home/node/.local/bin

# Openbox Autostart Config (NODE)
mkdir -p /home/node/.config/openbox

cat <<'EOF' > /home/node/.config/openbox/autostart
#!/bin/sh
# Developed: Daniel Plominski for A2S.AI (23.01.2026)

/home/node/.local/bin/wmctrl-autosplit.sh &
sleep 0.5

tmux -S /tmp/claude.sock new -s claude -d
sleep 0.5

/tmux_ctl_send.sh /start_claude.sh
sleep 0.5

/tmux_ctl_send.sh C-m
sleep 0.5

#terminator &
EOF

chmod +x /home/node/.config/openbox/autostart
chown -R node:node /home/node/.config

# Openbox Autostart Config (ROOT)
sudo mkdir -p /root/.config/openbox
sudo cp /home/node/.config/openbox/autostart /root/.config/openbox/autostart
sudo chmod +x /root/.config/openbox/autostart
sudo chown -R root:root /root/.config

# Tmux Session Controller
cat <<'EOF' > /home/node/tmux_ctl_send.sh
#!/bin/sh
# Developed: Daniel Plominski for A2S.AI (23.01.2026)

tmux -S /tmp/claude.sock send-keys -t claude "$1"
EOF

chmod +x /home/node/tmux_ctl_send.sh
chown -R node:node /home/node/tmux_ctl_send.sh

sudo cp -fv /home/node/tmux_ctl_send.sh /tmux_ctl_send.sh

# Tmux Print
cat <<'EOF' > /home/node/tmux_print_output.sh
#!/bin/sh
# Developed: Daniel Plominski for A2S.AI (23.01.2026)

tmux -S /tmp/claude.sock capture-pane -t claude -p
EOF

chmod +x /home/node/tmux_print_output.sh
chown -R node:node /home/node/tmux_print_output.sh

sudo cp -fv /home/node/tmux_print_output.sh /tmux_print_output.sh

# ZSH Config
cat <<'EOF' > /home/node/.zshrc

if command -v tmux >/dev/null 2>&1; then
  if [ -z "$TMUX" ] && [ -S /tmp/claude.sock ]; then
    tmux -S /tmp/claude.sock has-session -t claude 2>/dev/null && \
    tmux -S /tmp/claude.sock attach -t claude
  fi
fi

EOF

chown -R node:node /home/node/.zshrc

# Set ZSH as Default
sudo chsh -s /bin/zsh root
sudo chsh -s /bin/zsh node

# Disable "Exit" for OpenBox
cat <<'EOF' > /home/node/openbox_menu.xml
<?xml version="1.0" encoding="UTF-8"?>

<openbox_menu xmlns="http://openbox.org/"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="http://openbox.org/
                file:///usr/share/openbox/menu.xsd">

<menu id="root-menu" label="Openbox 3">
  <item label="Terminal emulator">
    <action name="Execute"><execute>x-terminal-emulator</execute></action>
  </item>
<!-- OFF
  <item label="Web browser">
    <action name="Execute"><execute>x-www-browser</execute></action>
  </item>
-->
  <separator />
  <!-- This requires the presence of the 'obamenu' package to work -->
<!-- OFF
  <menu id="/Debian" />
  <separator />
  <menu id="applications-menu" label="Applications" execute="/usr/bin/obamenu"/>
  <separator />
  <item label="ObConf">
    <action name="Execute"><execute>obconf</execute></action>
  </item>
-->
  <item label="Reconfigure">
    <action name="Reconfigure" />
  </item>
  <item label="Restart">
    <action name="Restart" />
  </item>
  <separator />
<!-- OFF
  <item label="Exit">
    <action name="Exit" />
  </item>
-->
</menu>

</openbox_menu>
EOF
sudo cp -fv /home/node/openbox_menu.xml /etc/xdg/openbox/menu.xml

# Starting: openbox
echo "Starting openbox..."
openbox-session >/tmp/openbox-session.log 2>&1 &
sleep 0.5

# x11vnc Password
X11VNC_AUTH_ARGS=()
if [[ -n "${VNC_PASSWORD}" ]]; then
  # create passfile
  x11vnc -storepasswd "${VNC_PASSWORD}" "${X11VNC_PASSFILE}" >/dev/null
  chmod 600 "${X11VNC_PASSFILE}"
  X11VNC_AUTH_ARGS=(-rfbauth "${X11VNC_PASSFILE}")
  echo "x11vnc: password authentication enabled"
else
  X11VNC_AUTH_ARGS=(-nopw)
  echo "x11vnc: NO PASSWORD (VNC_PASSWORD is empty)"
fi

echo "Starting x11vnc on port ${VNC_PORT}..."
x11vnc \
  -display "${DISPLAY}" \
  -listen 0.0.0.0 \
  -rfbport "${VNC_PORT}" \
  -forever -shared \
  -xkb -noxrecord -noxfixes -noxdamage \
  "${X11VNC_AUTH_ARGS[@]}" \
  >/tmp/x11vnc.log 2>&1 &

# noVNC Proxy (Websockify & Webserver)
echo "Starting noVNC on port ${NOVNC_PORT}..."
/usr/share/novnc/utils/novnc_proxy \
  --vnc "127.0.0.1:${VNC_PORT}" \
  --listen "0.0.0.0:${NOVNC_PORT}" \
  >/tmp/novnc.log 2>&1 &

echo ""
echo "=== Ready ==="
echo "noVNC:   http://<container-ip>:${NOVNC_PORT}/vnc.html"
echo "Display: ${DISPLAY}"
if [[ -n "${VNC_PASSWORD}" ]]; then
  echo "Password: ${VNC_PASSWORD}"
else
  echo "Password: (none)"
fi
echo ""

# Keep the container running in the foreground (NODE)
tail -f /tmp/novnc.log

# EOF
