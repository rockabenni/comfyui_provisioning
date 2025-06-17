#!/bin/bash

# Custom provisioning for AI-Girl Studio

APT_PACKAGES=()
PIP_PACKAGES=("jupyterlab")

# 1. Custom Nodes
NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/cubiq/ComfyUI_essentials"
    "https://github.com/continue-revolution/ComfyUI-AnimateDiff"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
    "https://github.com/Fannovel16/comfyui_controlnet_aux"
    "https://github.com/WASasquatch/was-node-suite-comfyui"
    "https://github.com/catacolabs/ComfyUI-Catalog"
    "https://github.com/Derfuu/ComfyUI-Manager-Civitai-Helper"
    "https://github.com/ltdrdata/ComfyUI-FaceRestoration"
    "https://github.com/ssitu/ComfyUI_TiledDiffusion"
    "https://github.com/cubiq/ComfyUI_LCM"
    "https://github.com/Fannovel16/IPAdapter-ComfyUI"
    "https://github.com/ashen-sensored/ComfyUI-RefControl"
)

# 2. Models
CHECKPOINT_MODELS=(
  "https://civitai.com/api/download/models/1522905?type=Model&format=SafeTensor&size=pruned&fp=fp16"
)

VAE_MODELS=(
    "https://huggingface.co/stabilityai/sd-vae-ft-ema-original/resolve/main/vae-ft-ema-560000-ema-pruned.safetensors"
    "https://huggingface.co/madebyollin/sdxl-vae-fp16-fix/resolve/main/sdxl-vae-fp16-fix.safetensors"
)

ESRGAN_MODELS=(
    "https://civitai.com/api/download/models/130071?type=Model&format=SafeTensor&size=full"
    "https://huggingface.co/uwg/upscaler/resolve/main/4x-AnimeSharp.pth"
    "https://huggingface.co/uwg/upscaler/resolve/main/3x_RealisticRescaler.pth"
    "https://huggingface.co/uwg/upscaler/resolve/main/2x_FaceDetailerESRGAN.pth"
)

CONTROLNET_MODELS=(
    "https://huggingface.co/lllyasviel/ControlNet/resolve/main/models/control_sd15_openpose.pth"
    "https://huggingface.co/lllyasviel/ControlNet/resolve/main/models/control_sd15_depth.pth"
    "https://huggingface.co/lllyasviel/ControlNet/resolve/main/models/control_sd15_canny.pth"
    "https://huggingface.co/lllyasviel/ControlNet/resolve/main/models/control_sd15_softedge.pth"
)

UNET_MODELS=()
LORA_MODELS=(
    "https://huggingface.co/h94/IP-Adapter/resolve/main/ip-adapter_sd15.safetensors"
    "https://huggingface.co/h94/IP-Adapter/resolve/main/ip-adapter-plus_sd15.safetensors"
)

function provisioning_download() {
    local url="$1"
    local dir="$2"
    local filename=$(basename "$url")
    local target="$dir/$filename"
    if [[ -f "$target" ]]; then
        echo "✔️ $filename already exists – skipping download"
    else
        echo "⬇️ Downloading $filename..."
        wget -q --show-progress -O "$target" "$url"
    fi
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="${WORKSPACE}/ComfyUI/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                echo "🔄 Updating node: $repo"
                (cd "$path" && git pull)
                [[ -e $requirements ]] && pip_install -r "$requirements"
            else
                echo "✔️ Node exists: $repo (no auto-update)"
            fi
        else
            echo "📦 Cloning node: $repo"
            git clone "$repo" "$path" --recursive
            [[ -e $requirements ]] && pip_install -r "$requirements"
        fi
    done
}

function provisioning_start() {
    if [[ ! -d /opt/environments/python ]]; then export MAMBA_BASE=true; fi
    source /opt/ai-dock/etc/environment.sh
    source /opt/ai-dock/bin/venv-set.sh comfyui

    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_get_pip_packages
    provisioning_get_models "${WORKSPACE}/ComfyUI/models/checkpoints" "${CHECKPOINT_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/ComfyUI/models/unet" "${UNET_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/ComfyUI/models/lora" "${LORA_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/ComfyUI/models/controlnet" "${CONTROLNET_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/ComfyUI/models/vae" "${VAE_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/ComfyUI/models/esrgan" "${ESRGAN_MODELS[@]}"
    provisioning_print_end

    echo "🧱 Creating directory structure..."
    mkdir -p /workspace/apps/comfyui
    mkdir -p /workspace/apps/kohya_ss
    mkdir -p /workspace/data/lyni_love/{loras,datasets,trained,outputs,video,voice}

    echo "⬇️ Setting up kohya_ss if not exists..."
    if [[ ! -d /workspace/apps/kohya_ss ]]; then
        git clone https://github.com/bmaltais/kohya_ss /workspace/apps/kohya_ss
        pip_install -r /workspace/apps/kohya_ss/requirements.txt
    fi

    echo "🔧 Writing startup scripts..."
    cat << 'EOF' > /workspace/start_comfyui.sh
#!/bin/bash
cd /workspace/ComfyUI
python3 main.py --listen 0.0.0.0 --port 3000 \
--output-directory /workspace/data/lyni_love/outputs
EOF
    chmod +x /workspace/start_comfyui.sh

    cat << 'EOF' > /workspace/start_kohya_gui.sh
#!/bin/bash
cd /workspace/apps/kohya_ss
python3 kohya_gui.py --server_port 7860 --share
EOF
    chmod +x /workspace/start_kohya_gui.sh

    cat << 'EOF' > /workspace/start_jupyter.sh
#!/bin/bash
cd /workspace
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token=''
EOF
    chmod +x /workspace/start_jupyter.sh

    echo "✅ All tools ready."
    echo "  - ComfyUI:        bash /workspace/start_comfyui.sh (port 3000)"
    echo "  - Kohya GUI:      bash /workspace/start_kohya_gui.sh (port 7860)"
    echo "  - JupyterLab:     bash /workspace/start_jupyter.sh (port 8888)"
}

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

function provisioning_get_models() {
    if [[ -z $2 ]]; then return 1; fi
    dir="$1"
    mkdir -p "$dir"
    shift
    arr=("$@")
    echo "📦 Downloading ${#arr[@]} model(s) to $dir"
    for url in "${arr[@]}"; do
        provisioning_download "$url" "$dir"
    done
}

function provisioning_print_header() {
    echo -e "\n##############################################"
    echo "# AI-GIRL STUDIO PROVISIONING STARTED        #"
    echo -e "##############################################\n"
}

function provisioning_print_end() {
    echo -e "\n✅ Provisioning complete! All tools are ready.\n"
}

# 🚀 Fire it up!
provisioning_start
