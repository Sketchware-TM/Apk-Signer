#!/usr/bin/env bash

if [[ -t 1 ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[0;33m'
    BLUE=$'\033[0;34m'
    CYAN=$'\033[0;36m'
    NC=$'\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; NC=''
fi

detect_os() {
    if [[ -d "/data/data/com.termux" ]]; then
        OS="TERMUX"
        BIN_DIR="/data/data/com.termux/files/usr/bin"
        PROFILE_FILE="$HOME/.bashrc"
        echo -e "${CYAN}📱 Detected: Termux (Android)${NC}"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="LINUX"
        if [[ "$SHELL" == *"zsh"* ]]; then
            PROFILE_FILE="$HOME/.zshrc"
        else
            PROFILE_FILE="$HOME/.bashrc"
        fi
        if [[ -w "/usr/local/bin" ]]; then
            BIN_DIR="/usr/local/bin"
        else
            BIN_DIR="$HOME/.local/bin"
        fi
        echo -e "${CYAN}🐧 Detected: Linux (shell: $(basename "$SHELL"))${NC}"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="MACOS"
        BIN_DIR="/usr/local/bin"
        PROFILE_FILE="$HOME/.zshrc"
        echo -e "${CYAN}🍎 Detected: macOS${NC}"
    elif [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "cygwin"* ]] || [[ -n "$WSL_DISTRO_NAME" ]]; then
        OS="WINDOWS"
        if [[ -n "$WSL_DISTRO_NAME" ]]; then
            BIN_DIR="/usr/local/bin"
            PROFILE_FILE="$HOME/.bashrc"
        else
            BIN_DIR="$HOME/bin"
            PROFILE_FILE="$HOME/.bashrc"
        fi
        echo -e "${CYAN}🪟 Detected: Windows (Git Bash/WSL)${NC}"
    else
        OS="UNKNOWN"
        BIN_DIR="$HOME/.local/bin"
        PROFILE_FILE="$HOME/.bashrc"
        echo -e "${YELLOW}⚠️  Unknown OS, using fallback${NC}"
    fi
}

find_sign_script() {
    local script_path=""
    if [[ -f "./sign.sh" ]]; then
        script_path="$(pwd)/sign.sh"
    elif [[ -f "$(dirname "$0")/sign.sh" ]]; then
        script_path="$(dirname "$0")/sign.sh"
    elif [[ -f "../sign.sh" ]]; then
        script_path="$(pwd)/../sign.sh"
    else
        script_path=$(find "$HOME" -maxdepth 3 -name "sign.sh" 2>/dev/null | head -1)
    fi
    if [[ -z "$script_path" || ! -f "$script_path" ]]; then
        echo -e "${RED}❌ sign.sh not found!${NC}" >&2
        echo -e "${YELLOW}💡 Make sure sign.sh is in current directory or specify:${NC}" >&2
        echo -e "   ./setup-terminal.sh /path/to/sign.sh" >&2
        exit 1
    fi
    echo "$script_path"
}

create_bin_dir() {
    if [[ "$OS" == "TERMUX" ]]; then
        return 0
    fi

    if [[ ! -d "$BIN_DIR" ]]; then
        echo -e "${YELLOW}📁 Creating directory: $BIN_DIR${NC}"
        mkdir -p "$BIN_DIR" || {
            echo -e "${RED}❌ Failed to create $BIN_DIR${NC}"
            if [[ "$BIN_DIR" != "$HOME/.local/bin" ]]; then
                BIN_DIR="$HOME/.local/bin"
                echo -e "${YELLOW}🔄 Falling back to $BIN_DIR${NC}"
                mkdir -p "$BIN_DIR"
            else
                exit 1
            fi
        }
    fi

    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo -e "${YELLOW}📌 Adding $BIN_DIR to PATH in $PROFILE_FILE${NC}"
        echo "" >> "$PROFILE_FILE"
        echo "# ApkSigner PATH" >> "$PROFILE_FILE"
        echo "export PATH=\"\$PATH:$BIN_DIR\"" >> "$PROFILE_FILE"
        if [[ "$PROFILE_FILE" != "$HOME/.zshrc" ]] && [[ -f "$HOME/.zshrc" ]]; then
            echo "" >> "$HOME/.zshrc"
            echo "# ApkSigner PATH" >> "$HOME/.zshrc"
            echo "export PATH=\"\$PATH:$BIN_DIR\"" >> "$HOME/.zshrc"
        fi
    fi
}

install_script() {
    local source_path="$1"
    local target_name="$2"
    local target_path="$BIN_DIR/$target_name"

    if [[ -f "$target_path" ]] || [[ -L "$target_path" ]]; then
        echo -e "${YELLOW}⚠️  $target_path already exists.${NC}"
        read -p "Overwrite? [y/N]: " overwrite
        [[ ! "$overwrite" =~ ^[Yy]$ ]] && { echo -e "${YELLOW}⏩ Skipping installation.${NC}"; return 0; }
        rm -f "$target_path"
    fi

    echo -e "${YELLOW}📦 Installing $target_name to $BIN_DIR...${NC}"
    cp "$source_path" "$target_path" 2>/dev/null || {
        echo -e "${RED}❌ Failed to copy! Check permissions.${NC}"
        return 1
    }
    chmod +x "$target_path" 2>/dev/null || {
        echo -e "${RED}❌ Failed to set executable bit.${NC}"
        return 1
    }

    if [[ -f "$target_path" ]]; then
        echo -e "${GREEN}✅ Successfully installed: $target_path${NC}"
        return 0
    else
        echo -e "${RED}❌ Installation failed!${NC}"
        return 1
    fi
}

show_usage() {
    cat << EOF
${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${GREEN}🔧 ApkSigner Setup Script${NC}
${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

${YELLOW}USAGE:${NC}
    ./setup-terminal.sh [OPTIONS] [TARGET_NAME]

${YELLOW}OPTIONS:${NC}
    --help, -h      Show this help
    --path DIR      Specify custom bin directory
    --name NAME     Set custom command name (default: apksigner-tool)
    --source PATH   Path to sign.sh (auto-detect if not set)

${YELLOW}EXAMPLES:${NC}
    ./setup-terminal.sh                      # Auto-detect & install
    ./setup-terminal.sh --name sign          # Install as 'sign'
    ./setup-terminal.sh /path/to/sign.sh     # Specify script path
    ./setup-terminal.sh --path ~/bin         # Custom bin directory

${YELLOW}AFTER INSTALL:${NC}
    Run this to make command available:
    source $PROFILE_FILE

    Then use:
    apksigner-tool
    # or custom name if you specified one

${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
EOF
}

main() {
    detect_os

    local custom_source=""
    local custom_name=""
    local custom_bin=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_usage
                exit 0
                ;;
            --path)
                custom_bin="$2"
                shift 2
                ;;
            --name)
                custom_name="$2"
                shift 2
                ;;
            --source)
                custom_source="$2"
                shift 2
                ;;
            *)
                if [[ -f "$1" ]]; then
                    custom_source="$1"
                else
                    custom_name="$1"
                fi
                shift
                ;;
        esac
    done

    echo -e "${GREEN}🔧 ApkSigner Setup Tool${NC}"
    echo ""

    if [[ -n "$custom_bin" ]]; then
        BIN_DIR="$custom_bin"
        echo -e "${YELLOW}📁 Using custom bin directory: $BIN_DIR${NC}"
    fi

    if [[ -n "$custom_source" && -f "$custom_source" ]]; then
        SOURCE_PATH="$custom_source"
        echo -e "${GREEN}✅ Using provided source: $SOURCE_PATH${NC}"
    else
        SOURCE_PATH=$(find_sign_script)
        echo -e "${GREEN}✅ Found sign.sh at: $SOURCE_PATH${NC}"
    fi

    create_bin_dir
    [[ -z "$custom_name" ]] && custom_name="apksigner"

    if install_script "$SOURCE_PATH" "$custom_name"; then
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✅ SETUP COMPLETE!${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${YELLOW}📌 Command: ${CYAN}$custom_name${NC}"
        echo -e "${YELLOW}📁 Location: ${CYAN}$BIN_DIR${NC}"
        echo ""
        echo -e "${BLUE}🔄 Run this to use it now:${NC}"
        if [[ "$OS" == "TERMUX" ]]; then
            echo -e "    ${GREEN}Command is already available, just run '$custom_name'${NC}"
        else
            echo -e "    ${GREEN}source $PROFILE_FILE${NC}"
        fi
        echo ""
        echo -e "${BLUE}📝 Or simply restart your terminal.${NC}"
    else
        echo -e "${RED}❌ Setup failed!${NC}"
        exit 1
    fi
}

main "$@"