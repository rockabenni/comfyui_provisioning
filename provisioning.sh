#!/bin/bash

APT_PACKAGES=()

PIP_PACKAGES=()

NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
)

CHECKPOINT_MODELS=()

UNET_MODELS=()
LORA_MODELS=()
VAE_MODELS=()
ESRGAN_MODELS=()
CONTROLNET_MODELS=()

function provisioning_start() {
    if [[ ! -d /opt/environments/python ]]; then 
        export MAMBA_BASE=true
    fi
    source /opt/ai-dock/etc/environment.sh
    source /opt/ai-dock/bin/venv-set.sh comfyui

    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_get_pip_packages
    provisioning_get_models \
        "/workspace/comfyui/models/checkpoints" \
        "${CHECKPOINT_MODELS[@]}"
    provisioning_get_models \
        "/workspace/comfyui/models/unet" \
        "${UNET_MODELS[@]}"
    provisioning_get_models \
        "/workspace/comfyui/models/lora" \
        "${LORA_MODELS[@]}"
    provisioning_get_models \
        "/workspace/comfyui/models/controlnet" \
        "${CONTROLNET_MODELS[@]}"
    provisioning_get_models \
        "/workspace/comfyui/models/vae" \
        "${VAE_MODELS[@]}"
    provisioning_get_models \
        "/workspace/comfyui/models/esrgan" \
        "${ESRGAN_MODELS[@]}"
    provisioning_print_end
}

# Alle weiteren Funktionen bleiben gleich...

provisioning_start
