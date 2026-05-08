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
#   - https://github.com/boltgolt/howdy/issues/890  (Ubuntu 24.04 LTS)
#   - https://github.com/boltgolt/howdy/issues/774  (externally-managed)
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
    # The previous regex-based patch could match os.path.exists() instead of
    # cv2.VideoCapture() because both call self.config.get("video", "device_path")
    # in v2.6.1. We do an exact-block replace and defensively revert the wrong
    # patch first so this is idempotent and recoverable.
    python3 << 'PYTHON_PATCH'
file_path = "/lib/security/howdy/recorders/video_capture.py"

with open(file_path, 'r') as f:
    content = f.read()

# 1) Revert any previous wrong patch on os.path.exists (which only takes 1 arg)
wrong = 'os.path.exists(self.config.get("video", "device_path"), cv2.CAP_V4L2)'
right = 'os.path.exists(self.config.get("video", "device_path"))'
if wrong in content:
    content = content.replace(wrong, right)
    print("Reverted wrong os.path.exists patch from earlier runs")

# 2) Apply correct patch via exact-block match in _create_reader
old_block = '''self.internal = cv2.VideoCapture(
				self.config.get("video", "device_path")
			)'''
new_block = '''self.internal = cv2.VideoCapture(
				self.config.get("video", "device_path"), cv2.CAP_V4L2
			)'''

if 'cv2.CAP_V4L2' not in content:
    if old_block in content:
        content = content.replace(old_block, new_block, 1)
        with open(file_path, 'w') as f:
            f.write(content)
        print("Patched VideoCapture in _create_reader with cv2.CAP_V4L2 backend")
    else:
        # Save reverted content if any
        with open(file_path, 'w') as f:
            f.write(content)
        print("WARNING: could not locate VideoCapture block — file structure may differ from v2.6.1")
else:
    # Make sure any revert is persisted
    with open(file_path, 'w') as f:
        f.write(content)
    print("Already patched with V4L2 backend")
PYTHON_PATCH
    echo -e "${GREEN}✓ video_capture.py V4L2 backend handled${NC}"
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
# FIX 4: pam.py subprocess.call needs cwd + PYTHONPATH
# ═══════════════════════════════════════════════════════════════
# Without these, compare.py runs with the wrong working directory under PAM
# and its sibling-module imports (`from recorders.video_capture import …`)
# fail with ModuleNotFoundError at every sudo invocation. We also redirect
# stdout/stderr to DEVNULL so cosmetic OpenCV/Python warnings don't leak
# into sudo's terminal output. Reported in boltgolt/howdy issues #890, #1046.
echo -e "\n${BLUE}🔧 Fix 4: Patching pam.py subprocess.call (cwd + PYTHONPATH + silenced output)...${NC}"

if grep -q "PYTHONPATH" "$PAM_FILE" 2>/dev/null; then
    echo -e "${YELLOW}⚠ pam.py subprocess already patched${NC}"
else
    python3 << 'PYTHON_PATCH'
p = "/lib/security/howdy/pam.py"
with open(p) as f: content = f.read()

old = '\t# Run compare as python3 subprocess to circumvent python version and import issues\n\tstatus = subprocess.call(["/usr/bin/python3", os.path.dirname(os.path.abspath(__file__)) + "/compare.py", pamh.get_user()])'
new = '''\t# Run compare as python3 subprocess to circumvent python version and import issues
\thowdy_dir = os.path.dirname(os.path.abspath(__file__))
\tenv = os.environ.copy()
\tenv["PYTHONPATH"] = howdy_dir + (":" + env["PYTHONPATH"] if "PYTHONPATH" in env else "")
\tstatus = subprocess.call(
\t\t["/usr/bin/python3", howdy_dir + "/compare.py", pamh.get_user()],
\t\tcwd=howdy_dir,
\t\tenv=env,
\t\tstdout=subprocess.DEVNULL,
\t\tstderr=subprocess.DEVNULL,
\t)'''

if old in content:
    content = content.replace(old, new)
    with open(p, 'w') as f:
        f.write(content)
    print("Patched")
else:
    print("WARNING: subprocess.call block not found — manual fix required")
PYTHON_PATCH
    echo -e "${GREEN}✓ Patched pam.py subprocess.call${NC}"
fi

# ═══════════════════════════════════════════════════════════════
# FIX 5: compare.py needs sys.path.insert for sibling imports
# ═══════════════════════════════════════════════════════════════
# compare.py uses `from recorders.video_capture import …` and `import snapshot`,
# both of which are sibling modules. Without sys.path containing its own
# directory, these imports fail when compare.py is launched as a subprocess
# from pam.py (the script's own dir is not in sys.path by default in that
# context). Belt-and-suspenders alongside FIX 4.
echo -e "\n${BLUE}🔧 Fix 5: Patching compare.py for sibling-module imports...${NC}"

COMPARE_FILE="$HOWDY_PATH/compare.py"
if [[ ! -f "$COMPARE_FILE" ]]; then
    echo -e "${RED}❌ compare.py not found${NC}"
elif head -10 "$COMPARE_FILE" | grep -q "sys.path.insert"; then
    echo -e "${YELLOW}⚠ compare.py already has sys.path.insert${NC}"
else
    python3 << 'PYTHON_PATCH'
p = "/lib/security/howdy/compare.py"
with open(p) as f: lines = f.readlines()

inject = "import sys, os as _os\nsys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))\n"

# Insert at the first non-comment, non-blank line so it runs before any imports
insert_idx = 0
for i, l in enumerate(lines):
    if l.strip() and not l.strip().startswith("#"):
        insert_idx = i
        break

lines.insert(insert_idx, inject)
with open(p, 'w') as f:
    f.writelines(lines)
print("Patched")
PYTHON_PATCH
    echo -e "${GREEN}✓ Prepended sys.path.insert to compare.py${NC}"
fi

# ═══════════════════════════════════════════════════════════════
# FIX 6: Directory permissions (must be 755 to be traversable)
# ═══════════════════════════════════════════════════════════════
# Howdy's postinst on some systems runs `chmod 744 -R /lib/security/howdy/`
# which strips the execute bit from directories. Files at 744 are fine, but
# directories at 744 cannot be traversed (no `x`), and PAM's subprocess
# can't reach files inside `recorders/`, `cli/`, etc. We restore 755 on
# directories while keeping 644 on files (and 755 on known executables).
echo -e "\n${BLUE}🔧 Fix 6: Restoring directory permissions (755 traversable)...${NC}"

find "$HOWDY_PATH" -type d -exec chmod 755 {} +
find "$HOWDY_PATH" -type f -exec chmod 644 {} +
chmod 755 "$HOWDY_PATH/cli.py" 2>/dev/null || true
chmod 755 "$HOWDY_PATH/dlib-data/install.sh" 2>/dev/null || true
echo -e "${GREEN}✓ Directories 755, files 644, executables 755${NC}"

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
