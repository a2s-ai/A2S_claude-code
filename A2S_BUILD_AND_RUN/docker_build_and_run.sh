#!/bin/sh
# Developed: Daniel Plominski for A2S.AI (18.01.2026)

docker build -t claude-code-novnc .

docker run \
       -it \
       --restart unless-stopped \
       -v /etc/hosts:/etc/hosts:ro \
       -e ANTHROPIC_BASE_URL="https://minimax-m2.a2s.ai/v1" \
       -e ANTHROPIC_API_KEY="dummy" \
       -e ANTHROPIC_MODEL="MiniMax-M2.1-AWQ" \
       -v /DATA:/DATA \
       -e IS_SANDBOX=1 \
       -p 10001:10001 \
       -e VNC_PASSWORD=claude \
       --cap-add=SYS_ADMIN \
       --security-opt seccomp=unconfined \
       --shm-size=1g \
       claude-code-novnc

# EOF
