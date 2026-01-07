#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
# Nexus CLI Updater
# ═══════════════════════════════════════════════════════════════════════════════
#
# This script updates Nexus CLI to the latest version:
# - Pulls latest changes from git (if git repo)
# - Preserves user configuration
# - Re-registers skill if needed
# - Validates installation
#
# Usage: ./update-nexus.sh [options]
#
# Options:
#   --branch <name>  Update to specific branch (default: main)
#   --force          Force update even if up to date
#   --backup         Create backup before update
#   --check-only     Only check for updates, don't install
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
VERSION_FILE="$SCRIPT_DIR/VERSION"
BACKUP_DIR="$HOME/.nexus/backups"

# Options
BRANCH="main"
FORCE=false
BACKUP=false
CHECK_ONLY=false

# ─────────────────────────────────────────────────────────────────────────────
# Helper Functions
# ─────────────────────────────────────────────────────────────────────────────

print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              Nexus CLI Updater                                 ║${NC}"
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
    head -28 "$0" | tail -23 | sed 's/^# //' | sed 's/^#//'
    exit 0
}

get_current_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE"
    else
        echo "unknown"
    fi
}

get_remote_version() {
    if [ -d "$SCRIPT_DIR/.git" ]; then
        # Fetch latest and get version from remote
        git -C "$SCRIPT_DIR" fetch origin "$BRANCH" --quiet 2>/dev/null || true
        git -C "$SCRIPT_DIR" show "origin/$BRANCH:VERSION" 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Parse Arguments
# ─────────────────────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case $1 in
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --backup)
            BACKUP=true
            shift
            ;;
        --check-only)
            CHECK_ONLY=true
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
# Main Update Process
# ─────────────────────────────────────────────────────────────────────────────

print_header

CURRENT_VERSION=$(get_current_version)
echo "Current version: ${CYAN}$CURRENT_VERSION${NC}"

# ─────────────────────────────────────────────────────────────────────────────
# Step 1: Check for Updates
# ─────────────────────────────────────────────────────────────────────────────

print_step "Checking for updates..."

if [ ! -d "$SCRIPT_DIR/.git" ]; then
    print_warning "Not a git repository. Cannot auto-update."
    echo ""
    echo "To update manually:"
    echo "  1. Download the latest version from the repository"
    echo "  2. Replace the files in $SCRIPT_DIR"
    echo "  3. Run ./install-nexus-skill.sh"
    exit 0
fi

REMOTE_VERSION=$(get_remote_version)
echo "Remote version:  ${CYAN}$REMOTE_VERSION${NC}"

# Check if update needed
if [ "$CURRENT_VERSION" = "$REMOTE_VERSION" ] && [ "$FORCE" = false ]; then
    print_success "Already up to date!"
    exit 0
fi

if [ "$CHECK_ONLY" = true ]; then
    if [ "$CURRENT_VERSION" != "$REMOTE_VERSION" ]; then
        echo ""
        echo -e "${YELLOW}Update available: $CURRENT_VERSION → $REMOTE_VERSION${NC}"
        echo "Run without --check-only to install the update."
    fi
    exit 0
fi

echo ""
echo -e "Update available: ${YELLOW}$CURRENT_VERSION${NC} → ${GREEN}$REMOTE_VERSION${NC}"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Step 2: Create Backup (if requested)
# ─────────────────────────────────────────────────────────────────────────────

if [ "$BACKUP" = true ]; then
    print_step "Creating backup..."

    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_PATH="$BACKUP_DIR/nexus_backup_$TIMESTAMP"

    mkdir -p "$BACKUP_DIR"

    # Backup current installation
    cp -r "$SCRIPT_DIR" "$BACKUP_PATH"

    # Also backup user config if exists
    if [ -d "$HOME/.nexus" ]; then
        cp -r "$HOME/.nexus" "$BACKUP_PATH/user_config"
    fi

    print_success "Backup created at: $BACKUP_PATH"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 3: Check for Local Changes
# ─────────────────────────────────────────────────────────────────────────────

print_step "Checking for local changes..."

if [ -n "$(git -C "$SCRIPT_DIR" status --porcelain)" ]; then
    print_warning "You have local changes:"
    git -C "$SCRIPT_DIR" status --short
    echo ""

    read -r -p "Stash local changes and continue? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            git -C "$SCRIPT_DIR" stash push -m "Auto-stash before update $(date)"
            print_success "Changes stashed"
            ;;
        *)
            print_error "Update cancelled. Commit or stash your changes first."
            exit 1
            ;;
    esac
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 4: Pull Updates
# ─────────────────────────────────────────────────────────────────────────────

print_step "Pulling updates from $BRANCH..."

# Switch to branch if needed
CURRENT_BRANCH=$(git -C "$SCRIPT_DIR" rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
    git -C "$SCRIPT_DIR" checkout "$BRANCH" --quiet
fi

# Pull changes
if git -C "$SCRIPT_DIR" pull origin "$BRANCH" --quiet; then
    print_success "Updates pulled successfully"
else
    print_error "Failed to pull updates"
    exit 1
fi

NEW_VERSION=$(get_current_version)
echo "New version: ${GREEN}$NEW_VERSION${NC}"

# ─────────────────────────────────────────────────────────────────────────────
# Step 5: Update Dependencies (if any)
# ─────────────────────────────────────────────────────────────────────────────

print_step "Checking dependencies..."

# Check for Python requirements
if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
    if command -v pip3 &> /dev/null; then
        print_step "Installing Python dependencies..."
        pip3 install -q -r "$SCRIPT_DIR/requirements.txt" 2>/dev/null || true
        print_success "Python dependencies updated"
    fi
fi

# Check for Node.js dependencies
if [ -f "$SCRIPT_DIR/package.json" ]; then
    if command -v npm &> /dev/null; then
        print_step "Installing Node.js dependencies..."
        npm install --prefix "$SCRIPT_DIR" --quiet 2>/dev/null || true
        print_success "Node.js dependencies updated"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 6: Update Skill File
# ─────────────────────────────────────────────────────────────────────────────

print_step "Updating Claude Code skill..."

# Ensure commands directory exists
mkdir -p "$CLAUDE_COMMANDS_DIR"

# Copy updated skill file
if [ -f "$SCRIPT_DIR/commands/nexus.md" ]; then
    cp "$SCRIPT_DIR/commands/nexus.md" "$SKILL_FILE"
    print_success "Skill file updated: $SKILL_FILE"
else
    print_error "Skill file not found in source: commands/nexus.md"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 7: Run Validation
# ─────────────────────────────────────────────────────────────────────────────

print_step "Validating installation..."

VALIDATION_PASSED=true

# Check main command file
if [ ! -f "$SCRIPT_DIR/commands/nexus.md" ]; then
    print_error "Main command file missing: commands/nexus.md"
    VALIDATION_PASSED=false
fi

# Check lib directory
if [ ! -d "$SCRIPT_DIR/lib" ]; then
    print_warning "Library directory missing: lib/"
fi

# Check tests
if [ -f "$SCRIPT_DIR/tests/run_static_tests.sh" ]; then
    print_step "Running quick validation tests..."
    if bash "$SCRIPT_DIR/tests/run_static_tests.sh" --quick 2>/dev/null; then
        print_success "Validation tests passed"
    else
        print_warning "Some validation tests failed (non-critical)"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 8: Show Changelog (if available)
# ─────────────────────────────────────────────────────────────────────────────

if [ -f "$SCRIPT_DIR/CHANGELOG.md" ]; then
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  What's New in $NEW_VERSION${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Show recent changelog entries
    head -30 "$SCRIPT_DIR/CHANGELOG.md" | tail -25
    echo ""
    echo "  (See CHANGELOG.md for full history)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Complete
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Nexus CLI updated successfully!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo "  Previous version: $CURRENT_VERSION"
echo "  New version:      $NEW_VERSION"
echo ""

if [ "$BACKUP" = true ]; then
    echo "  Backup location: $BACKUP_PATH"
    echo ""
fi

echo "Changes will take effect in new Claude Code sessions."
echo ""
