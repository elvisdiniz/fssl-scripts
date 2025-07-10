#!/bin/sh

set -e
set -u

# Function to print info messages
info() {
    printf "\033[1;34m%s\033[0m\n" "$1"
}

# Function to print error messages
error() {
    printf "\033[1;31m%s\033[0m\n" "$1" >&2
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Helper to run commands as root or with sudo if not root
run_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

add_eza_apt_repository() {
    if ! command_exists gpg; then
        info "gpg is not installed. Installing it now..."
        case "$ID" in
        "debian" | "ubuntu")
            run_as_root apt-get install -y gpg
            ;;
        *)
            error "Unsupported Linux distribution for gpg installation: $ID"
            exit 1
            ;;
        esac
    fi

    run_as_root mkdir -p /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/gierens.gpg ]; then
        info "Downloading gierens.gpg keyring..."
        curl -sL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | run_as_root gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    fi
    if [ ! -f /etc/apt/sources.list.d/gierens.list ]; then
        info "Creating eza repository list file..."
        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | run_as_root tee /etc/apt/sources.list.d/gierens.list
    fi
    run_as_root chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    run_as_root apt update
    info "Added eza repository and updated package list."
}

install_jq() {
    if ! command_exists jq; then
        info "jq is not installed. Installing it now..."
        case "$ID" in
        "debian" | "ubuntu")
            run_as_root apt-get install -y jq
            ;;
        "fedora")
            run_as_root dnf install -y jq
            ;;
        *)
            error "Unsupported Linux distribution for jq installation: $ID"
            exit 1
            ;;
        esac
    fi
}

# Function to install the latest version of chezmoi from GitHub releases
install_chezmoi() {
    install_jq

    info "Checking for the latest version of chezmoi..."
    local latest_version=$(curl -s "https://api.github.com/repos/twpayne/chezmoi/releases/latest" | jq -r '.tag_name' | sed 's/v//')

    if command_exists chezmoi; then
        local current_version=$(chezmoi --version | cut -d ' ' -f 3 | sed 's/v//;s/,//')
        if [ "$current_version" = "$latest_version" ]; then
            info "chezmoi is already up to date (version $current_version)."
            return
        else
            info "A new version of chezmoi is available: $latest_version (you have $current_version)."
        fi
    fi

    info "Installing the latest version of chezmoi..."

    local machine=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
    local download_url=""
    local file_ext=""

    case "$ID" in
    "debian" | "ubuntu")
        file_ext="deb"
        download_url="https://github.com/twpayne/chezmoi/releases/download/v${latest_version}/chezmoi_${latest_version}_linux_${machine}.${file_ext}"
        ;;
    "fedora")
        file_ext="rpm"
        local arch=$(uname -m)
        download_url="https://github.com/twpayne/chezmoi/releases/download/v${latest_version}/chezmoi-${latest_version}-${arch}.rpm"
        ;;
    *)
        error "Unsupported Linux distribution for chezmoi installation: $ID"
        exit 1
        ;;
    esac

    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    info "Downloading chezmoi from ${download_url}"
    curl -L "$download_url" -o "chezmoi.${file_ext}"

    case "$ID" in
    "debian" | "ubuntu")
        run_as_root dpkg -i "chezmoi.${file_ext}"
        ;;
    "fedora")
        run_as_root rpm -i "chezmoi.${file_ext}"
        ;;
    esac

    cd -
    rm -rf "$temp_dir"
}

# Function to install the latest version of fastfetch from GitHub releases
install_fastfetch() {
    install_jq

    info "Checking for the latest version of fastfetch..."
    local latest_version=$(curl -s "https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest" | jq -r '.tag_name')

    if command_exists fastfetch; then
        local current_version=$(fastfetch --version | cut -d ' ' -f 2 | cut -d '-' -f 1)
        if [ "$current_version" = "$latest_version" ]; then
            info "fastfetch is already up to date (version $current_version)."
            return
        else
            info "A new version of fastfetch is available: $latest_version (you have $current_version)."
        fi
    fi

    info "Installing the latest version of fastfetch..."

    local machine=$(uname -m | sed 's/x86_64/amd64/;s/arm64/aarch64/')
    local download_url=""
    local file_ext=""

    case "$ID" in
    "debian" | "ubuntu")
        file_ext="deb"
        download_url="https://github.com/fastfetch-cli/fastfetch/releases/download/${latest_version}/fastfetch-linux-${machine}.${file_ext}"
        ;;
    *)
        error "Unsupported Linux distribution for fastfetch installation: $ID"
        exit 1
        ;;
    esac

    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    info "Downloading fastfetch from ${download_url}"
    curl -L "$download_url" -o "fastfetch.${file_ext}"

    case "$ID" in
    "debian" | "ubuntu")
        run_as_root dpkg -i "fastfetch.${file_ext}"
        ;;
    esac

    cd -
    rm -rf "$temp_dir"
}

# Function to install the latest version of zoxide from GitHub releases
install_zoxide() {
    install_jq

    info "Checking for the latest version of zoxide..."
    local latest_version=$(curl -s "https://api.github.com/repos/ajeetdsouza/zoxide/releases/latest" | jq -r '.tag_name' | sed 's/v//')

    if command_exists zoxide; then
        local current_version=$(zoxide --version | cut -d ' ' -f 2)
        if [ "$current_version" = "$latest_version" ]; then
            info "zoxide is already up to date (version $current_version)."
            return
        else
            info "A new version of zoxide is available: $latest_version (you have $current_version)."
        fi
    fi

    info "Installing the latest version of zoxide..."

    local machine=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
    local download_url=""
    local file_ext=""

    case "$ID" in
    "debian" | "ubuntu")
        file_ext="deb"
        download_url="https://github.com/ajeetdsouza/zoxide/releases/download/v${latest_version}/zoxide_${latest_version}-1_${machine}.${file_ext}"
        ;;
    *)
        error "Unsupported Linux distribution for zoxide installation: $ID"
        exit 1
        ;;
    esac

    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    info "Downloading zoxide from ${download_url}"
    curl -L "$download_url" -o "zoxide.${file_ext}"

    case "$ID" in
    "debian" | "ubuntu")
        run_as_root dpkg -i "zoxide.${file_ext}"
        ;;
    esac

    cd -
    rm -rf "$temp_dir"
}

install_bottom() {
    install_jq

    info "Checking for the latest version of bottom..."
    local latest_version=$(curl -s "https://api.github.com/repos/ClementTsang/bottom/releases/latest" | jq -r '.tag_name')

    if command_exists btm; then
        local current_version=$(btm --version | cut -d ' ' -f 2)
        if [ "$current_version" = "$latest_version" ]; then
            info "bottom is already up to date (version $current_version)."
            return
        else
            info "A new version of bottom is available: $latest_version (you have $current_version)."
        fi
    fi

    info "Installing the latest version of bottom..."

    local machine=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
    local download_url=""
    local file_ext=""

    case "$ID" in
    "debian" | "ubuntu")
        file_ext="deb"
        download_url="https://github.com/ClementTsang/bottom/releases/download/${latest_version}/bottom_${latest_version}-1_${machine}.${file_ext}"
        ;;
    *)
        error "Unsupported Linux distribution for bottom installation: $ID"
        exit 1
        ;;
    esac

    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    info "Downloading bottom from ${download_url}"
    curl -L "$download_url" -o "bottom.${file_ext}"

    case "$ID" in
    "debian" | "ubuntu")
        run_as_root dpkg -i "bottom.${file_ext}"
        ;;
    esac

    cd -
    rm -rf "$temp_dir"
}

# Function to install packages on Arch Linux
setup_arch() {
    info "Installing packages for Arch Linux..."
    run_as_root pacman -Syu --noconfirm
    run_as_root pacman -S --noconfirm --needed \
        chezmoi starship eza bat curl wget git vim fastfetch fzf fd ripgrep neovim bottom fish zoxide zsh tmux sudo
}

# Function to install packages on Debian/Ubuntu
setup_debian_ubuntu() {
    info "Installing packages for Debian/Ubuntu..."
    add_eza_apt_repository
    run_as_root apt-get update
    local packages="bat curl eza wget git vim fzf fd-find ripgrep neovim fish zsh tmux"
    if [ "$ID" = "debian" ]; then
        if [ "$VERSION_ID" -ge 13 ]; then
            packages="$packages fastfetch btm zoxide starship"
        else
            install_zoxide
            install_fastfetch
            install_bottom
        fi
    fi
    if [ "$ID" = "ubuntu" ]; then
        packages="$packages zoxide btm"
        if [ "$(echo "$VERSION_ID" | cut -d. -f1)" -ge 25 ]; then
            packages="$packages starship fastfetch"
        else
            install_fastfetch
        fi
    fi
    run_as_root apt-get install -y $packages
    install_chezmoi
}

# Function to install packages on Alpine Linux
setup_alpine() {
    info "Installing packages for Alpine Linux..."
    run_as_root apk update
    run_as_root apk add chezmoi starship eza bat curl wget git vim fastfetch fzf fd ripgrep neovim bottom fish zoxide zsh tmux sudo
}

# Function to install packages on Fedora
setup_fedora() {
    info "Installing packages for Fedora..."
    local packages="bat curl wget git vim fastfetch fzf fd-find ripgrep neovim fish zoxide zsh tmux"
    if [ "$VERSION_ID" -lt 42 ]; then
        packages="$packages eza"
    fi
    run_as_root dnf install -y $packages
    install_chezmoi
}

# Function to install packages on FreeBSD
setup_freebsd() {
    info "Installing packages for FreeBSD..."
    run_as_root pkg update
    run_as_root pkg install -y chezmoi starship eza bat curl wget git vim fastfetch fzf fd ripgrep neovim bottom fish zoxide zsh tmux sudo
}

# Function to install packages on macOS
setup_macos() {
    info "Installing packages for macOS..."
    if ! command_exists brew; then
        error "Homebrew is not installed. Please install it first."
        exit 1
    fi
    brew install chezmoi starship eza bat curl wget git vim fastfetch fzf fd ripgrep neovim bottom fish zoxide zsh tmux
}

# Function to set up a new user
setup_user() {
    local username=$1
    local os_type=$2
    local linux_distro_id=$3

    info "Setting up user: $username"

    if [ "$os_type" = "darwin" ]; then
        error "User setup is not supported on macOS."
        return
    fi

    local admin_group=""

    # Determine admin group and commands based on OS
    case "$os_type" in
    "linux")
        admin_group="sudo"
        if [ "$linux_distro_id" = "alpine" ]; then
            admin_group="wheel"
        fi

        # Create admin group if it doesn't exist
        if ! getent group "$admin_group" >/dev/null; then
            info "Creating group '$admin_group'..."
            if [ "$linux_distro_id" = "alpine" ]; then
                run_as_root addgroup "$admin_group"
            else
                run_as_root groupadd "$admin_group"
            fi
        fi

        # Create user if it doesn't exist
        if ! id "$username" >/dev/null 2>&1; then
            info "Creating user '$username'..."
            if [ "$linux_distro_id" = "alpine" ]; then
                # -D: no password, -s: shell
                run_as_root adduser -D -s $(which zsh) "$username"
            else
                # -m: create home, -s: shell
                run_as_root useradd -m -s $(which zsh) "$username"
            fi
            info "User '$username' created."
        else
            info "User '$username' already exists."
        fi

        # Add user to admin group
        info "Adding user '$username' to group '$admin_group'..."
        if [ "$linux_distro_id" = "alpine" ]; then
            run_as_root addgroup "$username" "$admin_group"
        else
            run_as_root usermod -aG "$admin_group" "$username"
        fi
        ;;
    "freebsd")
        admin_group="wheel" # 'wheel' is the convention on FreeBSD

        # Ensure wheel group exists
        if ! pw group show "$admin_group" >/dev/null 2>&1; then
            info "Creating group '$admin_group'..."
            run_as_root pw groupadd "$admin_group"
        fi

        # Create user if it doesn't exist
        if ! id "$username" >/dev/null 2>&1; then
            info "Creating user '$username'..."
            # -m: create home, -s: shell
            run_as_root pw useradd "$username" -s $(which zsh) -m
            info "User '$username' created."
        else
            info "User '$username' already exists."
        fi

        # Add user to wheel group
        info "Adding user '$username' to group '$admin_group'..."
        run_as_root pw usermod "$username" -G "$admin_group"
        ;;
    *)
        error "User setup is not supported on this operating system: $os_type"
        return
        ;;
    esac

    # Set password for the user
    info "Please set a password for $username:"
    run_as_root passwd "$username"

    info "User $username setup complete."
}

# Main installation logic
main() {
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local linux_distro_id=""
    if [ "$os" = "linux" ]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            linux_distro_id=$ID
        else
            error "Cannot determine Linux distribution because /etc/os-release is not present."
            exit 1
        fi
    fi

    local username=""
    if [ "${1:-}" = "-u" ] || [ "${1:-}" = "--user" ]; then
        if [ -z "${2:-}" ]; then
            error "Argument for $1 is missing"
            exit 1
        fi
        username="$2"
        shift 2
    fi

    machine=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')

    if ! command_exists wget; then
        error "wget is not installed. Please install it first."
        exit 1
    fi

    if ! command_exists curl; then
        error "curl is not installed. Please install it first."
        exit 1
    fi

    case "$os" in
    "linux")
        case "$ID" in
        "arch")
            setup_arch
            ;;
        "debian" | "ubuntu")
            setup_debian_ubuntu
            ;;
        "alpine")
            setup_alpine
            ;;
        "fedora")
            setup_fedora
            ;;
        *)
            error "Unsupported Linux distribution: $ID"
            exit 1
            ;;
        esac
        ;;
    "darwin")
        setup_macos
        ;;
    "freebsd")
        setup_freebsd
        ;;
    *)
        error "Unsupported operating system: $os"
        exit 1
        ;;
    esac
    info "Package installation complete."

    if [ -n "$username" ]; then
        setup_user "$username" "$os" "$linux_distro_id"
    fi
}

main "$@"
