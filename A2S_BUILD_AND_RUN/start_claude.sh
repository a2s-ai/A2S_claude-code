#!/bin/sh
# Developed: Daniel Plominski for A2S.AI (18.01.2026)

export DISABLE_TELEMETRY=1
export DISABLE_ERROR_REPORTING=1
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
export DISABLE_BUG_COMMAND=1

#// For MiniMax-M2.5-AWQ at 168k on 4x NVIDIA RTX 6000A (compact after 126k)
export CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=75

sudo -u node sh -c "cd /home/node && /usr/local/share/npm-global/bin/claude --dangerously-skip-permissions"

# EOF
