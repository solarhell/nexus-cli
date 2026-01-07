#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
# Nexus CLI Uninstaller
# ═══════════════════════════════════════════════════════════════════════════════
#
# This script removes Nexus CLI from your system, including:
# - Claude Code skill registration
# - Configuration files
# - Temporary files and logs
#
# Usage: ./uninstall-nexus.sh [options]
#
# Options:
#   --keep-config    Keep user configuration files
#   --keep-logs      Keep execution logs
#   --force          Skip confirmation prompts
#   --help           Show this help message
#
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_NAME="nexus"
CLAUDE_COMMANDS_DIR="$HOME/.claude/commands"
SKILL_FILE="$CLAUDE_COMMANDS_DIR/nexus.md"
USER_CONFIG_DIR="$HOME/.nexus"
PROJECT_CONFIG_FILE=".nexus-config.yaml"

# Options
KEEP_CONFIG=false
KEEP_LOGS=false
FORCE=false

# ─────────────────────────────────────────────────────────────────────────────
# Helper Functions
# ─────────────────────────────────────────────────────────────────────────────

print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              Nexus CLI Uninstaller                             ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}▸${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

show_help() {
    head -25 "$0" | tail -20 | sed 's/^# //' | sed 's/^#//'
    exit 0
}

confirm() {
    if [ "$FORCE" = true ]; then
        return 0
    fi

    local prompt="$1 [y/N] "
    read -r -p "$prompt" response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Parse Arguments
# ─────────────────────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case $1 in
        --keep-config)
            KEEP_CONFIG=true
            shift
            ;;
        --keep-logs)
            KEEP_LOGS=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --help|-h)
            show_help
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# ─────────────────────────────────────────────────────────────────────────────
# Main Uninstall Process
# ─────────────────────────────────────────────────────────────────────────────

print_header

echo "This will uninstall Nexus CLI from your system."
echo ""

# Check what will be removed
echo "The following will be removed:"
echo ""

FOUND_ANYTHING=false

if [ -f "$SKILL_FILE" ]; then
    echo -e "  ${RED}•${NC} Claude Code skill: $SKILL_FILE"
    FOUND_ANYTHING=true
fi

if [ "$KEEP_CONFIG" = false ]; then
    if [ -d "$USER_CONFIG_DIR" ]; then
        echo -e "  ${RED}•${NC} User configuration: $USER_CONFIG_DIR"
        FOUND_ANYTHING=true
    fi
    if [ -f "$PROJECT_CONFIG_FILE" ]; then
        echo -e "  ${RED}•${NC} Project configuration: $PROJECT_CONFIG_FILE"
        FOUND_ANYTHING=true
    fi
fi

if [ "$KEEP_LOGS" = false ]; then
    # Check for temp directories in current project
    if [ -d ".nexus-temp" ]; then
        echo -e "  ${RED}•${NC} Temporary files: .nexus-temp/"
        FOUND_ANYTHING=true
    fi
fi

if [ "$FOUND_ANYTHING" = false ]; then
    echo -e "  ${YELLOW}(No Nexus CLI files found to remove)${NC}"
fi

echo ""

# Confirm uninstall
if ! confirm "Do you want to proceed with uninstallation?"; then
    echo ""
    print_warning "Uninstallation cancelled."
    exit 0
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Step 1: Remove Claude Code Skill
# ─────────────────────────────────────────────────────────────────────────────

print_step "Removing Claude Code skill..."

if [ -f "$SKILL_FILE" ]; then
    rm "$SKILL_FILE"
    print_success "Removed $SKILL_FILE"
else
    print_warning "Skill file not found: $SKILL_FILE"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 2: Remove Configuration Files
# ─────────────────────────────────────────────────────────────────────────────

if [ "$KEEP_CONFIG" = false ]; then
    print_step "Removing configuration files..."

    CONFIG_REMOVED=false

    if [ -d "$USER_CONFIG_DIR" ]; then
        rm -rf "$USER_CONFIG_DIR"
        print_success "Removed user configuration: $USER_CONFIG_DIR"
        CONFIG_REMOVED=true
    fi

    if [ -f "$PROJECT_CONFIG_FILE" ]; then
        rm "$PROJECT_CONFIG_FILE"
        print_success "Removed project configuration: $PROJECT_CONFIG_FILE"
        CONFIG_REMOVED=true
    fi

    if [ "$CONFIG_REMOVED" = false ]; then
        print_warning "No configuration files found"
    fi
else
    print_warning "Keeping configuration files (--keep-config)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 3: Remove Temporary Files
# ─────────────────────────────────────────────────────────────────────────────

if [ "$KEEP_LOGS" = false ]; then
    print_step "Removing temporary files..."

    # Remove .nexus-temp from current directory if exists
    if [ -d ".nexus-temp" ]; then
        rm -rf ".nexus-temp"
        print_success "Removed .nexus-temp directory"
    fi

    # Look for .nexus-temp in common project locations
    if [ -d "$HOME/projects" ]; then
        find "$HOME/projects" -name ".nexus-temp" -type d 2>/dev/null | while read -r dir; do
            if confirm "Remove $dir?"; then
                rm -rf "$dir"
                print_success "Removed $dir"
            fi
        done
    fi
else
    print_warning "Keeping logs and temporary files (--keep-logs)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 4: Clean up PATH (if applicable)
# ─────────────────────────────────────────────────────────────────────────────

print_step "Checking for PATH entries..."

# Check shell config files for nexus references
SHELL_CONFIGS=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile" "$HOME/.bash_profile")

for config in "${SHELL_CONFIGS[@]}"; do
    if [ -f "$config" ] && grep -q "nexus-cli" "$config" 2>/dev/null; then
        print_warning "Found nexus-cli reference in $config"
        echo "  You may want to manually remove any related PATH entries"
    fi
done

# ─────────────────────────────────────────────────────────────────────────────
# Complete
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Nexus CLI has been uninstalled successfully!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""

if [ "$KEEP_CONFIG" = true ]; then
    echo "Note: User configuration was preserved at $USER_CONFIG_DIR"
fi

if [ "$KEEP_LOGS" = true ]; then
    echo "Note: Logs and temporary files were preserved"
fi

echo ""
echo "To reinstall, run: ./install-nexus-skill.sh"
echo ""
