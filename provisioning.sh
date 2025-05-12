#!/bin/bash

# Custom provisioning for AI-Girl Studio

APT_PACKAGES=()
PIP_PACKAGES=("jupyterlab")

# 1. Custom Nodes
NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/cubiq/ComfyUI_essentials"
    "https://github.com/continue-revolution/ComfyUI-AnimateDiff"
)

# 2. Models
CHECKPOINT_MODELS=(
    "https://huggingface.co/SG161222/Realistic_Vision_V6.0_B1_noVAE/resolve/main/Realistic_Vision_V6.0_NV_B1.safetensors"
    "https://huggingface.co/cyberdelia/CyberRealistic/resolve/main/CyberRealistic_V8_FP32.safetensors"
    "https://huggingface.co/cyberdelia/CyberRealistic/resolve/main/CyberRealistic_V3.3_FP32.safetensors"
)

VAE_MODELS=(
    "https://huggingface.co/stabilityai/sd-vae-ft-ema-original/resolve/main/vae-ft-ema-560000-ema-pruned.safetensors"
)

ESRGAN_MODELS=(
    "https://huggingface.co/ai-forever/Real-ESRGAN/resolve/main/RealESRGAN_x4.pth"
    "https://huggingface.co/catbox/4x-UltraSharp/resolve/main/4x-UltraSharp.pth"
)

CONTROLNET_MODELS=(
    "https://huggingface.co/webui/ControlNet-modules-safetensors/resolve/main/control_canny-fp16.safetensors"
    "https://huggingface.co/webui/ControlNet-modules-safetensors/resolve/main/control_openpose-fp16.safetensors"
    "https://huggingface.co/kohya-ss/ControlNet-diff-modules/resolve/main/diff_control_sd15_depth_fp16.safetensors"
)

UNET_MODELS=()
LORA_MODELS=()

function provisioning_start() {
    if [[ ! -d /opt/environments/python ]]; then export MAMBA_BASE=true; fi
    source /opt/ai-dock/etc/environment.sh
    source /opt/ai-dock/bin/venv-set.sh comfyui

    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_get_pip_packages
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/ckpt" "${CHECKPOINT_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/unet" "${UNET_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/lora" "${LORA_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/controlnet" "${CONTROLNET_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/vae" "${VAE_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/esrgan" "${ESRGAN_MODELS[@]}"
    provisioning_print_end

    echo "🧱 Creating AI-Girl Studio structure in /workspace..."
    mkdir -p /workspace/apps/comfyui
    mkdir -p /workspace/apps/kohya_ss
    mkdir -p /workspace/data/lyni_love/{loras,datasets,trained,outputs,video,voice}

    echo "⬇️ Cloning kohya_ss into /workspace/apps/kohya_ss..."
    git clone https://github.com/bmaltais/kohya_ss /workspace/apps/kohya_ss
    pip_install -r /workspace/apps/kohya_ss/requirements.txt

    echo "🧠 Creating /workspace/start_comfyui.sh..."
    cat << 'EOF' > /workspace/start_comfyui.sh
#!/bin/bash
cd /opt/ComfyUI
python3 main.py --listen 0.0.0.0 --port 3000 \
--output-directory /workspace/data/lyni_love/outputs
EOF
    chmod +x /workspace/start_comfyui.sh

    echo "🧠 Creating /workspace/start_kohya_gui.sh..."
    cat << 'EOF' > /workspace/start_kohya_gui.sh
#!/bin/bash
cd /workspace/apps/kohya_ss
python3 kohya_gui.py --server_port 7860 --share
EOF
    chmod +x /workspace/start_kohya_gui.sh

    echo "🧠 Creating /workspace/start_jupyter.sh..."
    cat << 'EOF' > /workspace/start_jupyter.sh
#!/bin/bash
cd /workspace
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token=''
EOF
    chmod +x /workspace/start_jupyter.sh

    echo "✅ All start scripts ready. Use the following:"
    echo "  - ComfyUI:        bash /workspace/start_comfyui.sh (port 3000)"
    echo "  - Kohya GUI:      bash /workspace/start_kohya_gui.sh (port 7860)"
    echo "  - JupyterLab:     bash /workspace/start_jupyter.sh (port 8888)"
}

# ----------- Helper functions -----------
function pip_install() {
    if [[ -z $MAMBA_BASE ]]; then
        "$COMFYUI_VENV_PIP" install --no-cache-dir "$@"
    else
        micromamba run -n comfyui pip install --no-cache-dir "$@"
    fi
}

function provisioning_get_apt_packages() {
    if [[ -n $APT_PACKAGES ]]; then
        sudo $APT_INSTALL ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
        pip_install ${PIP_PACKAGES[@]}
    fi
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="/opt/ComfyUI/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                printf "Updating node: %s...\n" "${repo}"
                ( cd "$path" && git pull )
                if [[ -e $requirements ]]; then
                   pip_install -r "$requirements"
                fi
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
            if [[ -e $requirements ]]; then
                pip_install -r "${requirements}"
            fi
        fi
    done
}

function provisioning_get_models() {
    if [[ -z $2 ]]; then return 1; fi
    dir="$1"
    mkdir -p "$dir"
    shift
    arr=("$@")
    printf "Downloading %s model(s) to %s...\n" "${#arr[@]}" "$dir"
    for url in "${arr[@]}"; do
        printf "Downloading: %s\n" "${url}"
        provisioning_download "${url}" "${dir}"
        printf "\n"
    done
}

function provisioning_print_header() {
    printf "\n##############################################\n# AI-GIRL STUDIO PROVISIONING STARTED        #\n##############################################\n\n"
}

function provisioning_print_end() {
    printf "\n✅ Provisioning complete! All tools are ready to start.\n\n"
}

function provisioning_download() {
    if [[ -n $HF_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif [[ -n $CIVITAI_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi
    if [[ -n $auth_token ]]; then
        wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="4M" -P "$2" "$1"
    else
        wget -qnc --content-disposition --show-progress -e dotbytes="4M" -P "$2" "$1"
    fi
}

# 🚀 Fire it up!
provisioning_start
