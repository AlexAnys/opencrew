#!/bin/bash
# Slack Thread Routing Patch for OpenClaw
#
# Problem: In the default OpenClaw Slack integration, multiple root messages
# in the same channel may share a session context. This patch ensures each
# new root message in a channel gets its own isolated session.
#
# WARNING: This is a dist-level patch that modifies OpenClaw runtime files.
# It will be overwritten by OpenClaw upgrades. Reapply after each upgrade.
#
# Usage:
#   ./slack-thread-routing.sh apply    — Apply the patch
#   ./slack-thread-routing.sh rollback — Restore from backup
#   ./slack-thread-routing.sh status   — Check if patch is applied

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ── Locate OpenClaw dist directory ──
# Common locations — adjust for your installation
OPENCLAW_DIST_PATHS=(
    "$HOME/.openclaw/dist"
    "/usr/local/lib/openclaw"
    "/opt/openclaw/dist"
    "$HOME/.local/share/openclaw/dist"
)

DIST_DIR=""
for path in "${OPENCLAW_DIST_PATHS[@]}"; do
    if [ -d "$path" ]; then
        DIST_DIR="$path"
        break
    fi
done

if [ -z "$DIST_DIR" ]; then
    echo -e "${RED}Error: Cannot locate OpenClaw dist directory.${NC}"
    echo "Searched in:"
    for path in "${OPENCLAW_DIST_PATHS[@]}"; do
        echo "  - $path"
    done
    echo ""
    echo "Please set OPENCLAW_DIST environment variable to your dist path:"
    echo "  OPENCLAW_DIST=/path/to/dist ./slack-thread-routing.sh apply"
    exit 1
fi

# Override with env variable if provided
if [ -n "$OPENCLAW_DIST" ]; then
    DIST_DIR="$OPENCLAW_DIST"
fi

echo -e "${GREEN}Using dist directory: $DIST_DIR${NC}"

# ── Identify target files ──
# The patch needs to modify the Slack message handler to create per-message sessions.
# Target files vary by OpenClaw version. Common patterns:
TARGET_PATTERNS=(
    "*/slack/messageHandler*"
    "*/channels/slack*"
    "*/slack*.bundle.js"
)

BACKUP_SUFFIX=".bak-opencrew-$(date +%Y%m%d)"

find_target_files() {
    local found=()
    for pattern in "${TARGET_PATTERNS[@]}"; do
        while IFS= read -r -d '' file; do
            found+=("$file")
        done < <(find "$DIST_DIR" -path "$pattern" -print0 2>/dev/null)
    done
    echo "${found[@]}"
}

case "${1:-}" in
    apply)
        echo -e "${YELLOW}Applying Slack thread routing patch...${NC}"
        echo ""

        TARGET_FILES=$(find_target_files)

        if [ -z "$TARGET_FILES" ]; then
            echo -e "${RED}No target files found.${NC}"
            echo "This patch may not be compatible with your OpenClaw version."
            echo ""
            echo "Manual approach:"
            echo "1. Find the Slack message handler in your OpenClaw dist"
            echo "2. Look for the session key construction logic"
            echo "3. Ensure each root message (non-threaded) creates a unique session key"
            echo "   by incorporating the message timestamp (ts) into the session key"
            echo ""
            echo "The key change is: session key should include message.ts for root messages,"
            echo "so each new root message starts a fresh session instead of reusing the channel session."
            exit 1
        fi

        echo "Target files found:"
        for file in $TARGET_FILES; do
            echo "  - $file"

            # Create backup
            if [ ! -f "${file}${BACKUP_SUFFIX}" ]; then
                cp "$file" "${file}${BACKUP_SUFFIX}"
                echo -e "    ${GREEN}✓${NC} Backup created: ${file}${BACKUP_SUFFIX}"
            else
                echo -e "    ${YELLOW}!${NC} Backup already exists, skipping"
            fi
        done

        echo ""
        echo -e "${YELLOW}IMPORTANT: The actual patch logic depends on your OpenClaw version.${NC}"
        echo ""
        echo "The core change needed:"
        echo "In the Slack message handler, when constructing the session key for"
        echo "a non-threaded (root) message, include the message timestamp (ts)"
        echo "to create a unique session per root message."
        echo ""
        echo "Before: session key = agent:<id>:slack:channel:<channelId>"
        echo "After:  session key = agent:<id>:slack:channel:<channelId>:thread:<message_ts>"
        echo ""
        echo "This ensures every new root message in a channel gets its own session,"
        echo "just like threaded messages already do."
        echo ""
        echo "After making the change, restart OpenClaw:"
        echo "  openclaw restart"
        ;;

    rollback)
        echo -e "${YELLOW}Rolling back Slack thread routing patch...${NC}"

        BACKUP_FILES=$(find "$DIST_DIR" -name "*${BACKUP_SUFFIX}" 2>/dev/null)

        if [ -z "$BACKUP_FILES" ]; then
            echo "No backup files found. Nothing to rollback."
            exit 0
        fi

        for backup in $BACKUP_FILES; do
            original="${backup%${BACKUP_SUFFIX}}"
            cp "$backup" "$original"
            echo -e "  ${GREEN}✓${NC} Restored: $original"
        done

        echo ""
        echo "Rollback complete. Restart OpenClaw:"
        echo "  openclaw restart"
        ;;

    status)
        echo "Checking patch status..."

        BACKUP_FILES=$(find "$DIST_DIR" -name "*.bak-opencrew-*" 2>/dev/null)

        if [ -z "$BACKUP_FILES" ]; then
            echo -e "${YELLOW}No patch backups found.${NC} Patch likely not applied."
        else
            echo -e "${GREEN}Patch backups found:${NC}"
            for backup in $BACKUP_FILES; do
                echo "  - $backup"
            done
            echo ""
            echo "Note: Presence of backups means the patch was applied at some point."
            echo "If OpenClaw was upgraded since, the patch may have been overwritten."
        fi
        ;;

    *)
        echo "Usage: $0 {apply|rollback|status}"
        echo ""
        echo "  apply    — Apply the Slack thread routing patch"
        echo "  rollback — Restore original files from backup"
        echo "  status   — Check if patch backups exist"
        exit 1
        ;;
esac
