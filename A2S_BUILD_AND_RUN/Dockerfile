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
COPY .claude.json /home/node/.claude.json
COPY .mcp.json /home/node/.mcp.json

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

# Nice fonts 1-2
RUN apt-get update && apt-get install -y --no-install-recommends \
  fonts-noto-color-emoji \
  fonts-noto-extra \
  x11-xkb-utils \
  xkb-data \
  && rm -rf /var/lib/apt/lists/*

# Runtime-Fix for Chromium inside Docker (ROOT) - if not CAP SYS_ADMIN
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

# Compatibility
#RUN ln -sf /usr/local/bin/chromium-wrapper /usr/local/bin/chromium && \
#    ln -sf /usr/local/bin/chromium-wrapper /usr/local/bin/chromium-browser && \
#    ln -sf /usr/local/bin/chromium-wrapper /usr/local/bin/google-chrome && \
#    ln -sf /usr/local/bin/chromium-wrapper /usr/local/bin/google-chrome-stable && \
#    ln -sf /usr/local/bin/chromium-wrapper /usr/local/bin/chrome

# Expose ports
EXPOSE 6080 5900

# Workspace
WORKDIR /workspace

# Start scripts
COPY start.sh /start.sh
RUN chmod +x /start.sh

COPY start_claude.sh /start_claude.sh
RUN chmod +x /start_claude.sh

# Final Context Switch (NODE)
USER node

ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/start.sh"]

# EOF
