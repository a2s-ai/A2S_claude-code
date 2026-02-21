# Developed: Daniel Plominski for A2S.AI (18.01.2026)

FROM node:20

ARG TZ
ENV TZ="$TZ"

ARG CLAUDE_CODE_VERSION=latest

# noVNC Support
ENV DISPLAY=:1

# Install basic development tools and iptables/ipset
RUN apt-get update && apt-get install -y --no-install-recommends \
  less \
  git \
  procps \
  sudo \
  fzf \
  zsh \
  man-db \
  unzip \
  gnupg2 \
  gh \
  iptables \
  ipset \
  iproute2 \
  dnsutils \
  aggregate \
  jq \
  nano \
  vim \
  sshpass \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Ensure default node user has access to /usr/local/share
RUN mkdir -p /usr/local/share/npm-global && \
  chown -R node:node /usr/local/share

ARG USERNAME=node

# Persist bash history.
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  && mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && chown -R $USERNAME /commandhistory

# Create workspace and config directories and set permissions
RUN mkdir -p /workspace /home/node/.claude && \
  chown -R node:node /workspace /home/node/.claude

# Workspace
WORKDIR /workspace

ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
  wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  sudo dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# Set up non-root user
USER node

# Install global packages
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

# Set the default shell to zsh rather than sh
ENV SHELL=/bin/zsh

# Set the default editor and visual
ENV EDITOR=nano
ENV VISUAL=nano

# Default powerline10k theme
ARG ZSH_IN_DOCKER_VERSION=1.2.0
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
  -p git \
  -p fzf \
  -a "source /usr/share/doc/fzf/examples/key-bindings.zsh" \
  -a "source /usr/share/doc/fzf/examples/completion.zsh" \
  -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  -x

# Install Claude
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# Install Claude MCP Memory
RUN npm install -g @modelcontextprotocol/server-memory

# Example Config
USER root
COPY .claude.json /home/node/.claude.json
RUN chown node:node /home/node/.claude.json

COPY .mcp.json /home/node/.mcp.json
RUN chown node:node /home/node/.mcp.json

RUN mkdir -p /root/.config/claude-code
COPY .claude.json /root/.config/claude-code/claude.json
COPY .mcp.json /root/.config/claude-code/mcp.json
RUN chown -R root:root /root/.config

RUN mkdir -p /home/node/.config/claude-code
COPY .claude.json /home/node/.config/claude-code/claude.json
COPY .mcp.json /home/node/.config/claude-code/mcp.json
RUN chown -R node:node /home/node/.config

# MCP Datapath: Memory (ROOT)
USER root
RUN mkdir -p /DATA/memory && \
  chown -R node:node /DATA

# MCP Config: Memory (NODE)
USER node
RUN claude mcp add memory -- npx -y @modelcontextprotocol/server-memory --memory-path /DATA/memory

# MCP Support: Playwright
RUN npm install -g playwright

# MCP Support: Filesystem
RUN npm install -g @modelcontextprotocol/server-filesystem

# Full "node" user permissions (ROOT)
USER root
RUN echo "node ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/node-claude && \
  chmod 0440 /etc/sudoers.d/node-claude
USER node

# Install Playwright (ROOT)
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
  python3 \
  make \
  g++ \
  libc6 \
  libasound2 \
  libatk-bridge2.0-0 \
  libcairo2 \
  libdbus-1-3 \
  libdrm2 \
  libfontconfig1 \
  libgbm1 \
  libglib2.0-0 \
  libnspr4 \
  libnss3 \
  libx11-xcb1 \
  libxcb1 \
  libxcomposite1 \
  libxdamage1 \
  libxext6 \
  libxfixes3 \
  libxkbcommon0 \
  libxrandr2 \
  libxshmfence1 \
  libxxf86vm1 \
  xvfb \
  x11-utils \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN npx playwright install chromium

ENV PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/ms-playwright/chromium-1200/chrome-linux/chrome

# VNC / GUI Support (ROOT)
USER root
RUN apt-get update && apt-get install -y \
  xvfb \
  x11vnc \
  dbus-x11 \
  terminator \
  tmux \
  novnc \
  websockify \
  python3 \
  python3-numpy \
  python3-novnc \
  python3-websockify \
  tini \
  openbox \
  obconf \
  arc-theme \
  chromium \
  libnss3 \
  libnspr4 \
  libatk1.0-0 \
  libatk-bridge2.0-0 \
  libcups2 \
  libdrm2 \
  libxkbcommon0 \
  libxcomposite1 \
  libxdamage1 \
  libxfixes3 \
  libxrandr2 \
  libgbm1 \
  libasound2 \
  libpango-1.0-0 \
  libcairo2 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Nice fonts 1-2
RUN apt-get update && apt-get install -y --no-install-recommends \
  fontconfig \
  fonts-dejavu-core \
  fonts-dejavu-extra \
  fonts-liberation \
  fonts-noto-core \
  fonts-noto-ui-core \
  locales \
  && rm -rf /var/lib/apt/lists/*

# Locale (EN & DE)
RUN sed -i 's/# *de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen && \
    sed -i 's/# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

RUN locale-gen de_DE.UTF-8 && \
  update-locale LANG=de_DE.UTF-8

RUN locale-gen en_US.UTF-8 && \
  update-locale LANG=en_US.UTF-8

# Nice fonts 2-2
RUN apt-get update && apt-get install -y --no-install-recommends \
  fonts-firacode \
  fonts-noto-color-emoji \
  fonts-noto-extra \
  x11-xkb-utils \
  xkb-data \
  wmctrl \
  && rm -rf /var/lib/apt/lists/*

# Extra Packages (nice to have)
RUN apt-get update && apt-get install -y --no-install-recommends \
  python3-pip \
  python3-pandas \
  libxml2-utils \
  awscli \
  && rm -rf /var/lib/apt/lists/*

# Runtime-Fix for Chromium inside Docker (ROOT) - if no CAP SYS_ADMIN
USER root
RUN cat <<'EOF' > /usr/local/bin/chromium-wrapper
#!/bin/sh
exec /usr/bin/chromium \
  --no-sandbox \
  --disable-dev-shm-usage \
  --user-data-dir=/home/node/.config/chromium \
  "$@"
EOF
RUN chmod 0755 /usr/local/bin/chromium-wrapper

# Compatibility - if no CAP SYS_ADMIN
#RUN ln -sf /usr/local/bin/chromium-wrapper /usr/local/bin/chromium && \
#    ln -sf /usr/local/bin/chromium-wrapper /usr/local/bin/chromium-browser && \
#    ln -sf /usr/local/bin/chromium-wrapper /usr/local/bin/google-chrome && \
#    ln -sf /usr/local/bin/chromium-wrapper /usr/local/bin/google-chrome-stable && \
#    ln -sf /usr/local/bin/chromium-wrapper /usr/local/bin/chrome

# Claude Code: create statusline
RUN cat <<'EOF' > /home/node/.claude/statusline.sh
#!/bin/bash
# Developed: Daniel Plominski for A2S.AI (21.02.2026)

input=$(cat 2>/dev/null) || input=""

# Validate JSON before parsing
if echo "$input" | jq -e . >/dev/null 2>&1; then
  PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' 2>/dev/null | cut -d. -f1)
  SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 0' 2>/dev/null)
  COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0' 2>/dev/null)
fi

# Ensure numeric defaults for empty/invalid values
PCT="${PCT:-0}"
SIZE="${SIZE:-0}"
COST="${COST:-0}"
[[ "$PCT" =~ ^[0-9]+$ ]] || PCT=0
[[ "$SIZE" =~ ^[0-9]+$ ]] || SIZE=0
[[ "$COST" =~ ^[0-9.]+$ ]] || COST=0

SIZE_K=$(awk -v s="$SIZE" 'BEGIN { if (s >= 1000) printf "%.0fk", s/1000; else printf "%d", s }')

if [ "$PCT" -ge 80 ]; then
  CLR='\033[01;31m'
elif [ "$PCT" -ge 50 ]; then
  CLR='\033[01;33m'
else
  CLR='\033[01;32m'
fi
RST='\033[00m'

printf '\033[01;32m%s@%s\033[00m:\033[01;34m%s\033[00m | %b%s%%%b of %s | $%s' "$(whoami)" "$(hostname -s)" "$(pwd)" "$CLR" "$PCT" "$RST" "$SIZE_K" "$COST"
EOF
RUN chmod 0755 /home/node/.claude/statusline.sh
RUN chown node:node /home/node/.claude/statusline.sh

COPY settings.json /home/node/.claude/settings.json
RUN chmod 0644 /home/node/.claude/settings.json
RUN chown node:node /home/node/.claude/settings.json

# Expose ports
EXPOSE 10001 5900

# Workspace
WORKDIR /workspace

# Start scripts
COPY start.sh /start.sh
RUN chmod +x /start.sh

COPY start_claude.sh /start_claude.sh
RUN chmod +x /start_claude.sh

# Final Context Switch (NODE)
USER node

# Link workspace
#/RUN ln -s /workspace /home/node/workspace

WORKDIR /home/node/workspace

RUN mkdir -p /home/node/workspace/projects
RUN mkdir -p /home/node/workspace/templates

ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/start.sh"]

# EOF
