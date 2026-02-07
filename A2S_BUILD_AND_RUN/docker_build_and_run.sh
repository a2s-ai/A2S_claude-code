#!/bin/sh
# Developed: Daniel Plominski for A2S.AI (18.01.2026)

docker build -t claude-code-novnc .

docker run \
       -it \
       -d \
       --restart unless-stopped \
       -e ANTHROPIC_BASE_URL="https://minimax-m2.a2s.ai/v1" \
       -e ANTHROPIC_API_KEY="dummy" \
       -e ANTHROPIC_AUTH_TOKEN="dummy" \
       -e ANTHROPIC_MODEL="MiniMax-M2.1-AWQ" \
       -e ANTHROPIC_DEFAULT_OPUS_MODEL="MiniMax-M2.1-AWQ" \
       -e ANTHROPIC_DEFAULT_SONNET_MODEL="MiniMax-M2.1-AWQ" \
       -e ANTHROPIC_DEFAULT_HAIKU_MODEL="MiniMax-M2.1-AWQ" \
       -e IS_SANDBOX=1 \
       --cap-add=SYS_ADMIN \
       --security-opt seccomp=unconfined \
       --shm-size=1g \
       -p 127.0.0.1:10001:10001 \
       --name claude-code-novnc-1 \
       -e NOVNC_PORT=10001 \
       -e VNC_PASSWORD=claude \
       claude-code-novnc

#       -v /etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro \
#       -v /CEPH/projects:/workspace/projects \
#       -v /CEPH/templates:/workspace/templates:ro \

#       -v /etc/hosts:/etc/hosts:ro \

# EOF
