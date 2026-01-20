#!/bin/bash
#
# howdy-patcher.sh - Fix Howdy v2.6.1 for Modern Linux Systems
# 
# Fixes Python 2→3 compatibility issues and GStreamer backend problems
# for Howdy facial authentication on Debian 13, Ubuntu 24.04+, and similar.
#
# Author: Billel Lamairia (https://github.com/blamairia)
# License: MIT
# Repository: https://github.com/blamairia/howdy-patcher
#
# Related Howdy Issues:
#   - https://github.com/boltgolt/howdy/issues/912  (ConfigParser)
#   - https://github.com/boltgolt/howdy/issues/954  (PEP 668)
#   - https://github.com/boltgolt/howdy/issues/1027 (Python 2 commands)
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

HOWDY_PATH="/lib/security/howdy"
BACKUP_DIR="/lib/security/howdy-backup-$(date +%Y%m%d-%H%M%S)"

# Print banner
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              🛡️  Howdy Patcher for Modern Linux               ║"
echo "║         Fix Python 3 & Camera Backend Compatibility          ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ This script must be run as root (sudo)${NC}"
    exit 1
fi

# Check if Howdy is installed
if [[ ! -d "$HOWDY_PATH" ]]; then
    echo -e "${RED}❌ Howdy not found at $HOWDY_PATH${NC}"
    echo -e "${YELLOW}   Please install Howdy first: https://github.com/boltgolt/howdy${NC}"
    exit 1
fi

# Check Howdy version
if [[ -f "$HOWDY_PATH/pam.py" ]]; then
    echo -e "${GREEN}✓ Found Howdy installation (legacy v2.6.x structure)${NC}"
else
    echo -e "${YELLOW}⚠ Modern Howdy detected (v3.0+). This patcher is for v2.6.x only.${NC}"
    echo -e "${YELLOW}  The newer version already has these fixes built-in.${NC}"
    exit 0
fi

# Create backup
echo -e "\n${BLUE}📦 Creating backup at $BACKUP_DIR${NC}"
cp -r "$HOWDY_PATH" "$BACKUP_DIR"
echo -e "${GREEN}✓ Backup created${NC}"

# ═══════════════════════════════════════════════════════════════
# FIX 1: Python 2 → Python 3 ConfigParser Compatibility
# ═══════════════════════════════════════════════════════════════
echo -e "\n${BLUE}🔧 Fix 1: Patching pam.py for Python 3 compatibility...${NC}"

PAM_FILE="$HOWDY_PATH/pam.py"
if grep -q "import ConfigParser$" "$PAM_FILE" 2>/dev/null; then
    sed -i 's/^import ConfigParser$/import configparser as ConfigParser/' "$PAM_FILE"
    echo -e "${GREEN}✓ Patched ConfigParser import in pam.py${NC}"
else
    echo -e "${YELLOW}⚠ pam.py already patched or different format${NC}"
fi

# ═══════════════════════════════════════════════════════════════
# FIX 2: Force V4L2 Camera Backend (instead of GStreamer)
# ═══════════════════════════════════════════════════════════════
echo -e "\n${BLUE}🔧 Fix 2: Patching video_capture.py for V4L2 backend...${NC}"

VIDEO_CAPTURE_FILE="$HOWDY_PATH/recorders/video_capture.py"
if [[ -f "$VIDEO_CAPTURE_FILE" ]]; then
    # Check if already patched
    if grep -q "cv2.CAP_V4L2" "$VIDEO_CAPTURE_FILE" 2>/dev/null; then
        echo -e "${YELLOW}⚠ video_capture.py already patched with V4L2 backend${NC}"
    else
        # Find and patch the VideoCapture line
        # Original: self.internal = cv2.VideoCapture(self.config.get("video", "device_path"))
        # Patched:  self.internal = cv2.VideoCapture(self.config.get("video", "device_path"), cv2.CAP_V4L2)
        sed -i 's/self.internal = cv2.VideoCapture($/self.internal = cv2.VideoCapture(/; /cv2.VideoCapture(/{n;s/self.config.get("video", "device_path")/self.config.get("video", "device_path"), cv2.CAP_V4L2/}' "$VIDEO_CAPTURE_FILE"
        
        # Alternative simpler approach - find the exact pattern
        if ! grep -q "cv2.CAP_V4L2" "$VIDEO_CAPTURE_FILE"; then
            python3 << 'PYTHON_PATCH'
import re

file_path = "/lib/security/howdy/recorders/video_capture.py"

with open(file_path, 'r') as f:
    content = f.read()

# Pattern to match the VideoCapture instantiation without V4L2
pattern = r'(self\.internal = cv2\.VideoCapture\(\s*\n\s*self\.config\.get\("video", "device_path"\)\s*\n\s*\))'
replacement = '''self.internal = cv2.VideoCapture(
                                self.config.get("video", "device_path"), cv2.CAP_V4L2
                        )'''

if 'cv2.CAP_V4L2' not in content:
    # Try simpler pattern
    content = re.sub(
        r'self\.config\.get\("video", "device_path"\)\s*\)',
        'self.config.get("video", "device_path"), cv2.CAP_V4L2)',
        content,
        count=1  # Only first occurrence (the else branch)
    )
    
    with open(file_path, 'w') as f:
        f.write(content)
    print("Patched successfully")
else:
    print("Already patched")
PYTHON_PATCH
        fi
        echo -e "${GREEN}✓ Patched video_capture.py to use V4L2 backend${NC}"
    fi
else
    echo -e "${RED}❌ video_capture.py not found${NC}"
fi

# ═══════════════════════════════════════════════════════════════
# FIX 3: Install dlib if missing (PEP 668 workaround)
# ═══════════════════════════════════════════════════════════════
echo -e "\n${BLUE}🔧 Fix 3: Checking dlib installation...${NC}"

if python3 -c "import dlib" 2>/dev/null; then
    echo -e "${GREEN}✓ dlib is already installed${NC}"
else
    echo -e "${YELLOW}⚠ dlib not found. Installing (this may take 5-10 minutes)...${NC}"
    pip3 install dlib --break-system-packages 2>/dev/null || {
        echo -e "${RED}❌ Failed to install dlib. Please install manually:${NC}"
        echo -e "${YELLOW}   sudo pip3 install dlib --break-system-packages${NC}"
    }
fi

# ═══════════════════════════════════════════════════════════════
# Verification
# ═══════════════════════════════════════════════════════════════
echo -e "\n${BLUE}🔍 Verifying patches...${NC}"

ERRORS=0

# Check pam.py
if python3 -c "import sys; sys.path.insert(0, '$HOWDY_PATH'); exec(open('$HOWDY_PATH/pam.py').read().split('def doAuth')[0])" 2>/dev/null; then
    echo -e "${GREEN}✓ pam.py loads correctly${NC}"
else
    echo -e "${RED}❌ pam.py has errors${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check video_capture.py
if python3 -c "import sys; sys.path.insert(0, '$HOWDY_PATH'); from recorders.video_capture import VideoCapture" 2>/dev/null; then
    echo -e "${GREEN}✓ video_capture.py loads correctly${NC}"
else
    echo -e "${YELLOW}⚠ video_capture.py may have issues (check manually)${NC}"
fi

# Summary
echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✅ All patches applied successfully!${NC}"
    echo -e "\n${YELLOW}Next steps:${NC}"
    echo -e "  1. Configure your IR camera: ${BLUE}sudo howdy config${NC}"
    echo -e "     Set ${YELLOW}device_path${NC} to your IR camera (usually /dev/video2)"
    echo -e "  2. Add your face: ${BLUE}sudo howdy add${NC}"
    echo -e "  3. Test it: ${BLUE}sudo howdy test${NC}"
    echo -e "\n${YELLOW}Backup location:${NC} $BACKUP_DIR"
else
    echo -e "${RED}❌ Some patches failed. Check errors above.${NC}"
    echo -e "${YELLOW}To restore: sudo cp -r $BACKUP_DIR/* $HOWDY_PATH/${NC}"
fi
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
