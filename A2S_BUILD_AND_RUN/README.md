# A2S-AI (Build and Run)

```
git clone https://github.com/a2s-ai/A2S_claude-code.git

cd A2S_claude-code/A2S_BUILD_AND_RUN/

./docker_build_and_run.sh
```

# noVNC Browser Access

* http://ip-address:10001/vnc.html

# claude-code-novnc

<img src="./claude-code-novnc.png" />

# A2S-AI Features

* Docker‑based Claude Code environment
* Easy noVNC browser access
* Playwright MCP Chromium support
* Filesystem MCP support
* Claude Code MCP memory support
* Example of using an alternative MiniMax‑M2 vLLM model (privacy first)

# A2S GPU Server - vLLM with MiniMax-M2.1-AWQ

* Ubuntu 24 LTS VM with 4 x NVIDIA RTX 6000A

## vLLM (Docker) Settings with 194K (full) Context

```
root@ai-ubuntu24gpu-large:/opt# cat run-vllm-max_a2s-ai_MiniMax-M2.1-AWQ.sh
#!/bin/sh

export HUGGING_FACE_HUB_TOKEN=hf_XXX-XXX-XXX-XXX
export CUDA_VISIBLE_DEVICES="0,1,2,3"

docker network create vllm-minimax

docker run \
       --name vllm-minimax \
       --network vllm-minimax \
       --gpus all \
       --runtime=nvidia \
       --ipc=host \
       --restart unless-stopped -d --init \
       -p 8000:8000 \
       -v /data/opt/vllm:/root/.cache/huggingface \
       vllm/vllm-openai:nightly \
         --model a2s-ai/MiniMax-M2.1-AWQ \
         --served-model-name MiniMax-M2.1-AWQ \
         --tensor-parallel-size 4 \
         --enable-auto-tool-choice \
         --tool-call-parser minimax_m2 \
         --reasoning-parser minimax_m2_append_think \
         --max-model-len 194560 \
         --enable-expert-parallel \
         --trust-remote-code

# EOF
root@ai-ubuntu24gpu-large:/opt#
```

