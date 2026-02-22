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
  chrome_count=0
  chromium_count=0
  term_count=0

  wmctrl -lx | while read wid desk cls host title; do
    case "$cls" in
      *.X-terminal-emulator)
        term_count=$((term_count + 1))
        wmctrl -i -r "$wid" -b remove,maximized_vert,maximized_horz

        if [ "$term_count" -eq 1 ]; then
          wmctrl -i -r "$wid" -e 0,0,0,$HALF_W,$SCREEN_H
        else
          wmctrl -i -r "$wid" -e 0,$HALF_W,0,$HALF_W,$SCREEN_H
        fi
        ;;
      *.Chromium)
        chromium_count=$((chromium_count + 1))
        wmctrl -i -r "$wid" -b remove,maximized_vert,maximized_horz
        wmctrl -i -r "$wid" -e 0,$HALF_W,0,$HALF_W,$SCREEN_H
        ;;
      *.Google-chrome|*.Google-Chrome)
        chrome_count=$((chrome_count + 1))
        wmctrl -i -r "$wid" -b remove,maximized_vert,maximized_horz

        if [ "$chrome_count" -eq 1 ]; then
          wmctrl -i -r "$wid" -e 0,0,0,$HALF_W,$SCREEN_H
        else
          wmctrl -i -r "$wid" -e 0,$HALF_W,0,$HALF_W,$SCREEN_H
        fi
        ;;
      *)
        # unknowns
        wmctrl -i -r "$wid" -b remove,maximized_vert,maximized_horz
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

# Disable "Iconify" for OpenBox
cat <<'EOF' > /home/node/openbox_rc.xml
<?xml version="1.0" encoding="UTF-8"?>

<!-- Do not edit this file, it will be overwritten on install.
        Copy the file to $HOME/.config/openbox/ instead. -->

<openbox_config xmlns="http://openbox.org/3.4/rc"
                xmlns:xi="http://www.w3.org/2001/XInclude">

<resistance>
  <strength>10</strength>
  <screen_edge_strength>20</screen_edge_strength>
</resistance>

<focus>
  <focusNew>yes</focusNew>
  <!-- always try to focus new windows when they appear. other rules do
       apply -->
  <followMouse>no</followMouse>
  <!-- move focus to a window when you move the mouse into it -->
  <focusLast>yes</focusLast>
  <!-- focus the last used window when changing desktops, instead of the one
       under the mouse pointer. when followMouse is enabled -->
  <underMouse>no</underMouse>
  <!-- move focus under the mouse, even when the mouse is not moving -->
  <focusDelay>200</focusDelay>
  <!-- when followMouse is enabled, the mouse must be inside the window for
       this many milliseconds (1000 = 1 sec) before moving focus to it -->
  <raiseOnFocus>no</raiseOnFocus>
  <!-- when followMouse is enabled, and a window is given focus by moving the
       mouse into it, also raise the window -->
</focus>

<placement>
  <policy>Smart</policy>
  <!-- 'Smart' or 'UnderMouse' -->
  <center>yes</center>
  <!-- whether to place windows in the center of the free area found or
       the top left corner -->
  <monitor>Primary</monitor>
  <!-- with Smart placement on a multi-monitor system, try to place new windows
       on: 'Any' - any monitor, 'Mouse' - where the mouse is, 'Active' - where
       the active window is, 'Primary' - only on the primary monitor -->
  <primaryMonitor>1</primaryMonitor>
  <!-- The monitor where Openbox should place popup dialogs such as the
       focus cycling popup, or the desktop switch popup.  It can be an index
       from 1, specifying a particular monitor.  Or it can be one of the
       following: 'Mouse' - where the mouse is, or
                  'Active' - where the active window is -->
</placement>

<theme>
  <name>Clearlooks</name>
  <!-- OFF
  <titleLayout>NLIMC</titleLayout>
  -->
  <titleLayout>NLMC</titleLayout>
  <!--
      available characters are NDSLIMC, each can occur at most once.
      N: window icon
      L: window label (AKA title).
      I: iconify
      M: maximize
      C: close
      S: shade (roll up/down)
      D: omnipresent (on all desktops).
  -->
  <keepBorder>yes</keepBorder>
  <animateIconify>yes</animateIconify>
  <font place="ActiveWindow">
    <name>sans</name>
    <size>8</size>
    <!-- font size in points -->
    <weight>bold</weight>
    <!-- 'bold' or 'normal' -->
    <slant>normal</slant>
    <!-- 'italic' or 'normal' -->
  </font>
  <font place="InactiveWindow">
    <name>sans</name>
    <size>8</size>
    <!-- font size in points -->
    <weight>bold</weight>
    <!-- 'bold' or 'normal' -->
    <slant>normal</slant>
    <!-- 'italic' or 'normal' -->
  </font>
  <font place="MenuHeader">
    <name>sans</name>
    <size>9</size>
    <!-- font size in points -->
    <weight>normal</weight>
    <!-- 'bold' or 'normal' -->
    <slant>normal</slant>
    <!-- 'italic' or 'normal' -->
  </font>
  <font place="MenuItem">
    <name>sans</name>
    <size>9</size>
    <!-- font size in points -->
    <weight>normal</weight>
    <!-- 'bold' or 'normal' -->
    <slant>normal</slant>
    <!-- 'italic' or 'normal' -->
  </font>
  <font place="ActiveOnScreenDisplay">
    <name>sans</name>
    <size>9</size>
    <!-- font size in points -->
    <weight>bold</weight>
    <!-- 'bold' or 'normal' -->
    <slant>normal</slant>
    <!-- 'italic' or 'normal' -->
  </font>
  <font place="InactiveOnScreenDisplay">
    <name>sans</name>
    <size>9</size>
    <!-- font size in points -->
    <weight>bold</weight>
    <!-- 'bold' or 'normal' -->
    <slant>normal</slant>
    <!-- 'italic' or 'normal' -->
  </font>
</theme>

<desktops>
  <!-- this stuff is only used at startup, pagers allow you to change them
       during a session

       these are default values to use when other ones are not already set
       by other applications, or saved in your session

       use obconf if you want to change these without having to log out
       and back in -->
  <number>4</number>
  <firstdesk>1</firstdesk>
  <names>
    <!-- set names up here if you want to, like this:
    <name>desktop 1</name>
    <name>desktop 2</name>
    -->
  </names>
  <popupTime>875</popupTime>
  <!-- The number of milliseconds to show the popup for when switching
       desktops.  Set this to 0 to disable the popup. -->
</desktops>

<resize>
  <drawContents>yes</drawContents>
  <popupShow>Nonpixel</popupShow>
  <!-- 'Always', 'Never', or 'Nonpixel' (xterms and such) -->
  <popupPosition>Center</popupPosition>
  <!-- 'Center', 'Top', or 'Fixed' -->
  <popupFixedPosition>
    <!-- these are used if popupPosition is set to 'Fixed' -->

    <x>10</x>
    <!-- positive number for distance from left edge, negative number for
         distance from right edge, or 'Center' -->
    <y>10</y>
    <!-- positive number for distance from top edge, negative number for
         distance from bottom edge, or 'Center' -->
  </popupFixedPosition>
</resize>

<!-- You can reserve a portion of your screen where windows will not cover when
     they are maximized, or when they are initially placed.
     Many programs reserve space automatically, but you can use this in other
     cases. -->
<margins>
  <top>0</top>
  <bottom>0</bottom>
  <left>0</left>
  <right>0</right>
</margins>

<dock>
  <position>TopLeft</position>
  <!-- (Top|Bottom)(Left|Right|)|Top|Bottom|Left|Right|Floating -->
  <floatingX>0</floatingX>
  <floatingY>0</floatingY>
  <noStrut>no</noStrut>
  <stacking>Above</stacking>
  <!-- 'Above', 'Normal', or 'Below' -->
  <direction>Vertical</direction>
  <!-- 'Vertical' or 'Horizontal' -->
  <autoHide>no</autoHide>
  <hideDelay>300</hideDelay>
  <!-- in milliseconds (1000 = 1 second) -->
  <showDelay>300</showDelay>
  <!-- in milliseconds (1000 = 1 second) -->
  <moveButton>Middle</moveButton>
  <!-- 'Left', 'Middle', 'Right' -->
</dock>

<keyboard>
  <chainQuitKey>C-g</chainQuitKey>

  <!-- Keybindings for desktop switching -->
  <keybind key="C-A-Left">
    <action name="GoToDesktop"><to>left</to><wrap>no</wrap></action>
  </keybind>
  <keybind key="C-A-Right">
    <action name="GoToDesktop"><to>right</to><wrap>no</wrap></action>
  </keybind>
  <keybind key="C-A-Up">
    <action name="GoToDesktop"><to>up</to><wrap>no</wrap></action>
  </keybind>
  <keybind key="C-A-Down">
    <action name="GoToDesktop"><to>down</to><wrap>no</wrap></action>
  </keybind>
  <keybind key="S-A-Left">
    <action name="SendToDesktop"><to>left</to><wrap>no</wrap></action>
  </keybind>
  <keybind key="S-A-Right">
    <action name="SendToDesktop"><to>right</to><wrap>no</wrap></action>
  </keybind>
  <keybind key="S-A-Up">
    <action name="SendToDesktop"><to>up</to><wrap>no</wrap></action>
  </keybind>
  <keybind key="S-A-Down">
    <action name="SendToDesktop"><to>down</to><wrap>no</wrap></action>
  </keybind>
  <keybind key="W-F1">
    <action name="GoToDesktop"><to>1</to></action>
  </keybind>
  <keybind key="W-F2">
    <action name="GoToDesktop"><to>2</to></action>
  </keybind>
  <keybind key="W-F3">
    <action name="GoToDesktop"><to>3</to></action>
  </keybind>
  <keybind key="W-F4">
    <action name="GoToDesktop"><to>4</to></action>
  </keybind>
  <keybind key="W-d">
    <action name="ToggleShowDesktop"/>
  </keybind>

  <!-- Keybindings for windows -->
  <keybind key="A-F4">
    <action name="Close"/>
  </keybind>
  <keybind key="A-Escape">
    <action name="Lower"/>
    <action name="FocusToBottom"/>
    <action name="Unfocus"/>
  </keybind>
  <keybind key="A-space">
    <action name="ShowMenu"><menu>client-menu</menu></action>
  </keybind>
  <!-- Take a screenshot of the current window with scrot when Alt+Print are pressed -->
  <keybind key="A-Print">
    <action name="Execute"><command>scrot -s</command></action>
  </keybind>

  <!-- Keybindings for window switching -->
  <keybind key="A-Tab">
    <action name="NextWindow">
      <finalactions>
        <action name="Focus"/>
        <action name="Raise"/>
        <action name="Unshade"/>
      </finalactions>
    </action>
  </keybind>
  <keybind key="A-S-Tab">
    <action name="PreviousWindow">
      <finalactions>
        <action name="Focus"/>
        <action name="Raise"/>
        <action name="Unshade"/>
      </finalactions>
    </action>
  </keybind>
  <keybind key="C-A-Tab">
    <action name="NextWindow">
      <panels>yes</panels><desktop>yes</desktop>
      <finalactions>
        <action name="Focus"/>
        <action name="Raise"/>
        <action name="Unshade"/>
      </finalactions>
    </action>
  </keybind>

  <!-- Keybindings for window switching with the arrow keys -->
  <keybind key="W-S-Right">
    <action name="DirectionalCycleWindows">
      <direction>right</direction>
    </action>
  </keybind>
  <keybind key="W-S-Left">
    <action name="DirectionalCycleWindows">
      <direction>left</direction>
    </action>
  </keybind>
  <keybind key="W-S-Up">
    <action name="DirectionalCycleWindows">
      <direction>up</direction>
    </action>
  </keybind>
  <keybind key="W-S-Down">
    <action name="DirectionalCycleWindows">
      <direction>down</direction>
    </action>
  </keybind>

  <!-- Keybindings for running applications -->
  <keybind key="W-e">
    <action name="Execute">
      <startupnotify>
        <enabled>true</enabled>
        <name>Konqueror</name>
      </startupnotify>
      <command>kfmclient openProfile filemanagement</command>
    </action>
  </keybind>
  <!-- Launch scrot when Print is pressed -->
  <keybind key="Print">
    <action name="Execute"><command>scrot</command></action>
  </keybind>
</keyboard>

<mouse>
  <dragThreshold>1</dragThreshold>
  <!-- number of pixels the mouse must move before a drag begins -->
  <doubleClickTime>500</doubleClickTime>
  <!-- in milliseconds (1000 = 1 second) -->
  <screenEdgeWarpTime>400</screenEdgeWarpTime>
  <!-- Time before changing desktops when the pointer touches the edge of the
       screen while moving a window, in milliseconds (1000 = 1 second).
       Set this to 0 to disable warping -->
  <screenEdgeWarpMouse>false</screenEdgeWarpMouse>
  <!-- Set this to TRUE to move the mouse pointer across the desktop when
       switching due to hitting the edge of the screen -->

  <context name="Frame">
    <mousebind button="A-Left" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
    </mousebind>
    <mousebind button="A-Left" action="Click">
      <action name="Unshade"/>
    </mousebind>
    <mousebind button="A-Left" action="Drag">
      <action name="Move"/>
    </mousebind>

    <mousebind button="A-Right" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
      <action name="Unshade"/>
    </mousebind>
    <mousebind button="A-Right" action="Drag">
      <action name="Resize"/>
    </mousebind>

    <mousebind button="A-Middle" action="Press">
      <action name="Lower"/>
      <action name="FocusToBottom"/>
      <action name="Unfocus"/>
    </mousebind>

    <mousebind button="A-Up" action="Click">
      <action name="GoToDesktop"><to>previous</to></action>
    </mousebind>
    <mousebind button="A-Down" action="Click">
      <action name="GoToDesktop"><to>next</to></action>
    </mousebind>
    <mousebind button="C-A-Up" action="Click">
      <action name="GoToDesktop"><to>previous</to></action>
    </mousebind>
    <mousebind button="C-A-Down" action="Click">
      <action name="GoToDesktop"><to>next</to></action>
    </mousebind>
    <mousebind button="A-S-Up" action="Click">
      <action name="SendToDesktop"><to>previous</to></action>
    </mousebind>
    <mousebind button="A-S-Down" action="Click">
      <action name="SendToDesktop"><to>next</to></action>
    </mousebind>
  </context>

  <context name="Titlebar">
    <mousebind button="Left" action="Drag">
      <action name="Move"/>
    </mousebind>
    <mousebind button="Left" action="DoubleClick">
      <action name="ToggleMaximize"/>
    </mousebind>

    <mousebind button="Up" action="Click">
      <action name="if">
        <shaded>no</shaded>
        <then>
          <action name="Shade"/>
          <action name="FocusToBottom"/>
          <action name="Unfocus"/>
          <action name="Lower"/>
        </then>
      </action>
    </mousebind>
    <mousebind button="Down" action="Click">
      <action name="if">
        <shaded>yes</shaded>
        <then>
          <action name="Unshade"/>
          <action name="Raise"/>
        </then>
      </action>
    </mousebind>
  </context>

  <context name="Titlebar Top Right Bottom Left TLCorner TRCorner BRCorner BLCorner">
    <mousebind button="Left" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
      <action name="Unshade"/>
    </mousebind>

    <mousebind button="Middle" action="Press">
      <action name="Lower"/>
      <action name="FocusToBottom"/>
      <action name="Unfocus"/>
    </mousebind>

    <mousebind button="Right" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
      <action name="ShowMenu"><menu>client-menu</menu></action>
    </mousebind>
  </context>

  <context name="Top">
    <mousebind button="Left" action="Drag">
      <action name="Resize"><edge>top</edge></action>
    </mousebind>
  </context>

  <context name="Left">
    <mousebind button="Left" action="Drag">
      <action name="Resize"><edge>left</edge></action>
    </mousebind>
  </context>

  <context name="Right">
    <mousebind button="Left" action="Drag">
      <action name="Resize"><edge>right</edge></action>
    </mousebind>
  </context>

  <context name="Bottom">
    <mousebind button="Left" action="Drag">
      <action name="Resize"><edge>bottom</edge></action>
    </mousebind>

    <mousebind button="Right" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
      <action name="ShowMenu"><menu>client-menu</menu></action>
    </mousebind>
  </context>

  <context name="TRCorner BRCorner TLCorner BLCorner">
    <mousebind button="Left" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
      <action name="Unshade"/>
    </mousebind>
    <mousebind button="Left" action="Drag">
      <action name="Resize"/>
    </mousebind>
  </context>

  <context name="Client">
    <mousebind button="Left" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
    </mousebind>
    <mousebind button="Middle" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
    </mousebind>
    <mousebind button="Right" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
    </mousebind>
  </context>

  <context name="Icon">
    <mousebind button="Left" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
      <action name="Unshade"/>
      <action name="ShowMenu"><menu>client-menu</menu></action>
    </mousebind>
    <mousebind button="Right" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
      <action name="ShowMenu"><menu>client-menu</menu></action>
    </mousebind>
  </context>

  <context name="AllDesktops">
    <mousebind button="Left" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
      <action name="Unshade"/>
    </mousebind>
    <mousebind button="Left" action="Click">
      <action name="ToggleOmnipresent"/>
    </mousebind>
  </context>

  <context name="Shade">
    <mousebind button="Left" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
    </mousebind>
    <mousebind button="Left" action="Click">
      <action name="ToggleShade"/>
    </mousebind>
  </context>

  <context name="Iconify">
    <mousebind button="Left" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
    </mousebind>
    <mousebind button="Left" action="Click">
      <action name="Iconify"/>
    </mousebind>
  </context>

  <context name="Maximize">
    <mousebind button="Left" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
      <action name="Unshade"/>
    </mousebind>
    <mousebind button="Middle" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
      <action name="Unshade"/>
    </mousebind>
    <mousebind button="Right" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
      <action name="Unshade"/>
    </mousebind>
    <mousebind button="Left" action="Click">
      <action name="ToggleMaximize"/>
    </mousebind>
    <mousebind button="Middle" action="Click">
      <action name="ToggleMaximize"><direction>vertical</direction></action>
    </mousebind>
    <mousebind button="Right" action="Click">
      <action name="ToggleMaximize"><direction>horizontal</direction></action>
    </mousebind>
  </context>

  <context name="Close">
    <mousebind button="Left" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
      <action name="Unshade"/>
    </mousebind>
    <mousebind button="Left" action="Click">
      <action name="Close"/>
    </mousebind>
  </context>

  <context name="Desktop">
    <mousebind button="Up" action="Click">
      <action name="GoToDesktop"><to>previous</to></action>
    </mousebind>
    <mousebind button="Down" action="Click">
      <action name="GoToDesktop"><to>next</to></action>
    </mousebind>

    <mousebind button="A-Up" action="Click">
      <action name="GoToDesktop"><to>previous</to></action>
    </mousebind>
    <mousebind button="A-Down" action="Click">
      <action name="GoToDesktop"><to>next</to></action>
    </mousebind>
    <mousebind button="C-A-Up" action="Click">
      <action name="GoToDesktop"><to>previous</to></action>
    </mousebind>
    <mousebind button="C-A-Down" action="Click">
      <action name="GoToDesktop"><to>next</to></action>
    </mousebind>

    <mousebind button="Left" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
    </mousebind>
    <mousebind button="Right" action="Press">
      <action name="Focus"/>
      <action name="Raise"/>
    </mousebind>
  </context>

  <context name="Root">
    <!-- Menus -->
    <mousebind button="Middle" action="Press">
      <action name="ShowMenu"><menu>client-list-combined-menu</menu></action>
    </mousebind>
    <mousebind button="Right" action="Press">
      <action name="ShowMenu"><menu>root-menu</menu></action>
    </mousebind>
  </context>

  <context name="MoveResize">
    <mousebind button="Up" action="Click">
      <action name="GoToDesktop"><to>previous</to></action>
    </mousebind>
    <mousebind button="Down" action="Click">
      <action name="GoToDesktop"><to>next</to></action>
    </mousebind>
    <mousebind button="A-Up" action="Click">
      <action name="GoToDesktop"><to>previous</to></action>
    </mousebind>
    <mousebind button="A-Down" action="Click">
      <action name="GoToDesktop"><to>next</to></action>
    </mousebind>
  </context>
</mouse>

<menu>
  <!-- You can specify more than one menu file in here and they are all loaded,
       just don't make menu ids clash or, well, it'll be kind of pointless -->

  <!-- default menu file (or custom one in $HOME/.config/openbox/) -->
  <!-- system menu files on Debian systems -->
  <file>/var/lib/openbox/debian-menu.xml</file>
  <file>menu.xml</file>
  <hideDelay>200</hideDelay>
  <!-- if a press-release lasts longer than this setting (in milliseconds), the
       menu is hidden again -->
  <middle>no</middle>
  <!-- center submenus vertically about the parent entry -->
  <submenuShowDelay>100</submenuShowDelay>
  <!-- time to delay before showing a submenu after hovering over the parent
       entry.
       if this is a negative value, then the delay is infinite and the
       submenu will not be shown until it is clicked on -->
  <submenuHideDelay>400</submenuHideDelay>
  <!-- time to delay before hiding a submenu when selecting another
       entry in parent menu
       if this is a negative value, then the delay is infinite and the
       submenu will not be hidden until a different submenu is opened -->
  <showIcons>yes</showIcons>
  <!-- controls if icons appear in the client-list-(combined-)menu -->
  <manageDesktops>yes</manageDesktops>
  <!-- show the manage desktops section in the client-list-(combined-)menu -->
</menu>

<applications>
<!--
  # this is an example with comments through out. use these to make your
  # own rules, but without the comments of course.
  # you may use one or more of the name/class/role/title/type rules to specify
  # windows to match

  <application name="the window's _OB_APP_NAME property (see obxprop)"
              class="the window's _OB_APP_CLASS property (see obxprop)"
          groupname="the window's _OB_APP_GROUP_NAME property (see obxprop)"
         groupclass="the window's _OB_APP_GROUP_CLASS property (see obxprop)"
               role="the window's _OB_APP_ROLE property (see obxprop)"
              title="the window's _OB_APP_TITLE property (see obxprop)"
               type="the window's _OB_APP_TYPE property (see obxprob)..
                      (if unspecified, then it is 'dialog' for child windows)">
  # you may set only one of name/class/role/title/type, or you may use more
  # than one together to restrict your matches.

  # the name, class, role, and title use simple wildcard matching such as those
  # used by a shell. you can use * to match any characters and ? to match
  # any single character.

  # the type is one of: normal, dialog, splash, utility, menu, toolbar, dock,
  #    or desktop

  # when multiple rules match a window, they will all be applied, in the
  # order that they appear in this list


    # each rule element can be left out or set to 'default' to specify to not
    # change that attribute of the window

    <decor>yes</decor>
    # enable or disable window decorations

    <shade>no</shade>
    # make the window shaded when it appears, or not

    <position force="no">
      # the position is only used if both an x and y coordinate are provided
      # (and not set to 'default')
      # when force is "yes", then the window will be placed here even if it
      # says you want it placed elsewhere.  this is to override buggy
      # applications who refuse to behave
      <x>center</x>
      # a number like 50, or 'center' to center on screen. use a negative number
      # to start from the right (or bottom for <y>), ie -50 is 50 pixels from
      # the right edge (or bottom). use 'default' to specify using value
      # provided by the application, or chosen by openbox, instead.
      <y>200</y>
      <monitor>1</monitor>
      # specifies the monitor in a xinerama setup.
      # 1 is the first head, or 'mouse' for wherever the mouse is
    </position>

    <size>
      # the size to make the window.
      <width>20</width>
      # a number like 20, or 'default' to use the size given by the application.
      # you can use fractions such as 1/2 or percentages such as 75% in which
      # case the value is relative to the size of the monitor that the window
      # appears on.
      <height>30%</height>
    </size>

    <focus>yes</focus>
    # if the window should try be given focus when it appears. if this is set
    # to yes it doesn't guarantee the window will be given focus. some
    # restrictions may apply, but Openbox will try to

    <desktop>1</desktop>
    # 1 is the first desktop, 'all' for all desktops

    <layer>normal</layer>
    # 'above', 'normal', or 'below'

    <iconic>no</iconic>
    # make the window iconified when it appears, or not

    <skip_pager>no</skip_pager>
    # asks to not be shown in pagers

    <skip_taskbar>no</skip_taskbar>
    # asks to not be shown in taskbars. window cycling actions will also
    # skip past such windows

    <fullscreen>yes</fullscreen>
    # make the window in fullscreen mode when it appears

    <maximized>true</maximized>
    # 'Horizontal', 'Vertical' or boolean (yes/no)
  </application>

  # end of the example
-->
</applications>

</openbox_config>
EOF
sudo cp -fv /home/node/openbox_rc.xml /etc/xdg/openbox/rc.xml

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

# Clean up custom files
sudo rm -f /home/node/openbox_rc.xml
sudo rm -f /home/node/openbox_menu.xml
sudo chown node:node /home/node/tmux_ctl_send.sh
sudo chown node:node /home/node/tmux_print_output.sh

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
