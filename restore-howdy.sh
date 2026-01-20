#!/bin/bash
#
# restore-howdy.sh - Restore Howdy from backup
#
# Usage: sudo ./restore-howdy.sh [backup-directory]
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

HOWDY_PATH="/lib/security/howdy"

echo -e "${BLUE}🔄 Howdy Restore Tool${NC}\n"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ This script must be run as root (sudo)${NC}"
    exit 1
fi

# Find backup directory
if [[ -n "$1" ]]; then
    BACKUP_DIR="$1"
else
    # Find the most recent backup
    BACKUP_DIR=$(ls -td /lib/security/howdy-backup-* 2>/dev/null | head -1)
fi

if [[ -z "$BACKUP_DIR" || ! -d "$BACKUP_DIR" ]]; then
    echo -e "${RED}❌ No backup directory found${NC}"
    echo -e "${YELLOW}Usage: sudo ./restore-howdy.sh /path/to/backup${NC}"
    echo -e "\nAvailable backups:"
    ls -d /lib/security/howdy-backup-* 2>/dev/null || echo "  (none found)"
    exit 1
fi

echo -e "${YELLOW}Restoring from: $BACKUP_DIR${NC}"
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Restore
rm -rf "$HOWDY_PATH"
cp -r "$BACKUP_DIR" "$HOWDY_PATH"

echo -e "\n${GREEN}✅ Howdy restored from backup${NC}"
