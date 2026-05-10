#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="$(dirname "$0")/install.log"
PYTHON_MIN_VERSION="3.9"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE"
}

log_version() {
    local tool="$1"
    local cmd="$2"
    local version
    version=$(eval "$cmd" 2>/dev/null || echo "unknown")
    log "VERSION CHECK: $tool -> $version"
}

version_gte() {
    # Returns 0 (true) if $1 >= $2
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

# ──────────────────────────────────────────────
# OS detection
# ──────────────────────────────────────────────
detect_os() {
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        OS_ID="${ID:-unknown}"
        OS_LIKE="${ID_LIKE:-}"
    elif command -v sw_vers &>/dev/null; then
        OS_ID="macos"
        OS_LIKE=""
    else
        OS_ID="unknown"
        OS_LIKE=""
    fi
}

is_debian_based() {
    [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" || "$OS_LIKE" == *"debian"* ]]
}

is_macos() {
    [[ "$OS_ID" == "macos" ]]
}

# ──────────────────────────────────────────────
# Docker
# ──────────────────────────────────────────────
check_install_docker() {
    if command -v docker &>/dev/null; then
        log "Docker is already installed — skipping."
    else
        log "Installing Docker..."
        if is_debian_based; then
            sudo apt-get update -qq
            sudo apt-get install -y -qq ca-certificates curl gnupg lsb-release
            sudo install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/"${OS_ID}"/gpg \
                | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
                https://download.docker.com/linux/${OS_ID} \
                $(lsb_release -cs) stable" \
                | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt-get update -qq
            sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io
            sudo usermod -aG docker "$USER" || true
            log "Docker installed."
        elif is_macos; then
            log "macOS detected. Please install Docker Desktop manually from https://docs.docker.com/desktop/mac/"
        else
            log "Unsupported OS for automatic Docker install. Please install manually."
        fi
    fi
}

# ──────────────────────────────────────────────
# Docker Compose (plugin)
# ──────────────────────────────────────────────
check_install_docker_compose() {
    if docker compose version &>/dev/null 2>&1; then
        log "Docker Compose plugin is already installed — skipping."
    elif command -v docker-compose &>/dev/null; then
        log "docker-compose (standalone) is already installed — skipping."
    else
        log "Installing Docker Compose plugin..."
        if is_debian_based; then
            sudo apt-get install -y -qq docker-compose-plugin
            log "Docker Compose plugin installed."
        elif is_macos; then
            log "macOS: Docker Compose ships with Docker Desktop. Please ensure Docker Desktop is installed."
        else
            log "Unsupported OS for automatic Docker Compose install. Please install manually."
        fi
    fi
}

# ──────────────────────────────────────────────
# Python
# ──────────────────────────────────────────────
check_install_python() {
    local py_cmd=""
    for cmd in python3 python; do
        if command -v "$cmd" &>/dev/null; then
            local ver
            ver=$("$cmd" --version 2>&1 | awk '{print $2}')
            if version_gte "$ver" "$PYTHON_MIN_VERSION"; then
                py_cmd="$cmd"
                break
            fi
        fi
    done

    if [ -n "$py_cmd" ]; then
        log "Python >= $PYTHON_MIN_VERSION is already installed ($py_cmd) — skipping."
        PYTHON_CMD="$py_cmd"
    else
        log "Python >= $PYTHON_MIN_VERSION not found. Installing..."
        if is_debian_based; then
            sudo apt-get update -qq
            sudo apt-get install -y -qq python3 python3-dev python3-distutils
            PYTHON_CMD="python3"
            log "Python installed."
        elif is_macos; then
            if command -v brew &>/dev/null; then
                brew install python@3.11
                PYTHON_CMD="python3"
                log "Python installed via Homebrew."
            else
                log "Homebrew not found. Please install Python manually."
                PYTHON_CMD="python3"
            fi
        else
            log "Unsupported OS. Please install Python >= $PYTHON_MIN_VERSION manually."
            PYTHON_CMD="python3"
        fi
    fi
}

# ──────────────────────────────────────────────
# pip
# ──────────────────────────────────────────────
check_install_pip() {
    if "${PYTHON_CMD}" -m pip --version &>/dev/null 2>&1; then
        log "pip is already installed — skipping."
    else
        log "Installing pip..."
        if is_debian_based; then
            sudo apt-get install -y -qq python3-pip
        elif is_macos; then
            "${PYTHON_CMD}" -m ensurepip --upgrade || true
        fi
        log "pip installed."
    fi
}

# ──────────────────────────────────────────────
# Python packages (idempotent via pip install --upgrade)
# ──────────────────────────────────────────────
install_python_package() {
    local pkg="$1"
    local import_name="${2:-$1}"
    if "${PYTHON_CMD}" -c "import ${import_name}" &>/dev/null 2>&1; then
        log "Python package '${pkg}' is already installed — skipping."
    else
        log "Installing Python package '${pkg}'..."
        "${PYTHON_CMD}" -m pip install --quiet "$pkg"
        log "Package '${pkg}' installed."
    fi
}

# ──────────────────────────────────────────────
# Version report
# ──────────────────────────────────────────────
report_versions() {
    log "──── Installed versions ────"
    log_version "Docker"         "docker --version"
    log_version "Docker Compose" "docker compose version 2>/dev/null || docker-compose --version"
    log_version "Python"         "${PYTHON_CMD} --version"
    log_version "pip"            "${PYTHON_CMD} -m pip --version"
    log_version "torch"          "${PYTHON_CMD} -c 'import torch; print(torch.__version__)'"
    log_version "torchvision"    "${PYTHON_CMD} -c 'import torchvision; print(torchvision.__version__)'"
    log_version "Pillow"         "${PYTHON_CMD} -c 'import PIL; print(PIL.__version__)'"
    log_version "Django"         "${PYTHON_CMD} -c 'import django; print(django.__version__)'"
    log "────────────────────────────"
}

# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────
main() {
    log "════ Starting environment setup ════"
    detect_os
    log "Detected OS: $OS_ID"

    check_install_docker
    check_install_docker_compose

    PYTHON_CMD="python3"
    check_install_python
    check_install_pip

    install_python_package "torch"        "torch"
    install_python_package "torchvision"  "torchvision"
    install_python_package "Pillow"       "PIL"
    install_python_package "Django"       "django"

    report_versions
    log "════ Setup complete ════"
}

main "$@"
