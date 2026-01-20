# 🛡️ Howdy Patcher

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Linux](https://img.shields.io/badge/Platform-Linux-blue.svg)](https://www.linux.org/)
[![Debian](https://img.shields.io/badge/Debian-13+-red.svg)](https://www.debian.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04+-orange.svg)](https://ubuntu.com/)

**Fix [Howdy](https://github.com/boltgolt/howdy) v2.6.1 for modern Linux systems** — Patches Python 3 compatibility issues and camera backend problems.

## 🔥 The Problem

Howdy v2.6.1 (the version packaged by most Linux distributions) has critical issues on modern systems:

| Issue | Error Message | Affected Systems |
|-------|---------------|------------------|
| **Python 2 Legacy Code** | `ModuleNotFoundError: No module named 'ConfigParser'` | Debian 13+, Ubuntu 24.04+ |
| **GStreamer Backend Failure** | `GStreamer warning: unable to start pipeline` | Systems with V4L2-only cameras |
| **PEP 668 Restriction** | `externally-managed-environment` error during install | Python 3.11+ systems |

**Related Howdy Issues:**
- [#912 - Howdy can't import module ConfigParser](https://github.com/boltgolt/howdy/issues/912)
- [#954 - externally-managed-environment error](https://github.com/boltgolt/howdy/issues/954)
- [#1027 - Python 2 commands in pam script](https://github.com/boltgolt/howdy/issues/1027)
- [#935 - Ubuntu 24.04 LTS issues](https://github.com/boltgolt/howdy/issues/935)
- [#890 - Ubuntu 24.04 LTS](https://github.com/boltgolt/howdy/issues/890)

## ✅ The Solution

This patcher automatically applies three fixes:

1. **Python 3 Compatibility** — Changes `import ConfigParser` to `import configparser as ConfigParser`
2. **V4L2 Camera Backend** — Forces OpenCV to use V4L2 instead of GStreamer
3. **dlib Installation** — Installs dlib with PEP 668 bypass if missing

## 🚀 Quick Start

```bash
# Download and run the patcher
curl -fsSL https://raw.githubusercontent.com/blamairia/howdy-patcher/main/howdy-patcher.sh -o howdy-patcher.sh
chmod +x howdy-patcher.sh
sudo ./howdy-patcher.sh
```

Or clone and run:

```bash
git clone https://github.com/blamairia/howdy-patcher.git
cd howdy-patcher
sudo ./howdy-patcher.sh
```

## 📋 Requirements

- **Howdy v2.6.1** installed (from `.deb` package or PPA)
- **Linux** with Python 3.10+
- **Root/sudo** access

## 🔧 What It Does

```
╔═══════════════════════════════════════════════════════════════╗
║              🛡️  Howdy Patcher for Modern Linux               ║
║         Fix Python 3 & Camera Backend Compatibility          ║
╚═══════════════════════════════════════════════════════════════╝

✓ Found Howdy installation (legacy v2.6.x structure)

📦 Creating backup at /lib/security/howdy-backup-20260120-161500

🔧 Fix 1: Patching pam.py for Python 3 compatibility...
✓ Patched ConfigParser import in pam.py

🔧 Fix 2: Patching video_capture.py for V4L2 backend...
✓ Patched video_capture.py to use V4L2 backend

🔧 Fix 3: Checking dlib installation...
✓ dlib is already installed

🔍 Verifying patches...
✓ pam.py loads correctly
✓ video_capture.py loads correctly

═══════════════════════════════════════════════════════════════
✅ All patches applied successfully!

Next steps:
  1. Configure your IR camera: sudo howdy config
     Set device_path to your IR camera (usually /dev/video2)
  2. Add your face: sudo howdy add
  3. Test it: sudo howdy test
═══════════════════════════════════════════════════════════════
```

## 🔄 After Patching

1. **Find your IR camera:**
   ```bash
   v4l2-ctl --list-devices
   ```
   Look for a device with "IR" in the name (usually `/dev/video2`)

2. **Configure Howdy:**
   ```bash
   sudo howdy config
   ```
   Set `device_path = /dev/video2` (or your IR camera path)

3. **Add your face:**
   ```bash
   sudo howdy add
   ```

4. **Test it:**
   ```bash
   sudo howdy test   # Visual test
   sudo -i           # Real authentication test
   ```

## 🔙 Rollback

The patcher creates a timestamped backup. To restore:

```bash
sudo cp -r /lib/security/howdy-backup-YYYYMMDD-HHMMSS/* /lib/security/howdy/
```

## 📝 Manual Fixes

If you prefer to apply fixes manually:

### Fix 1: pam.py
```bash
sudo sed -i 's/^import ConfigParser$/import configparser as ConfigParser/' /lib/security/howdy/pam.py
```

### Fix 2: video_capture.py
Edit `/lib/security/howdy/recorders/video_capture.py` and change:
```python
self.internal = cv2.VideoCapture(
    self.config.get("video", "device_path")
)
```
To:
```python
self.internal = cv2.VideoCapture(
    self.config.get("video", "device_path"), cv2.CAP_V4L2
)
```

### Fix 3: dlib
```bash
sudo pip3 install dlib --break-system-packages
```

## 🤝 Contributing

Contributions welcome! Please open an issue or PR.

## 📄 License

MIT License - see [LICENSE](LICENSE) file.

## 🙏 Credits

- [Howdy](https://github.com/boltgolt/howdy) by boltgolt - The amazing Windows Hello™ style facial authentication for Linux
- This patcher was created after encountering these issues on Debian 13 (Trixie)

---

**Note:** The [dev branch](https://github.com/boltgolt/howdy/tree/dev) of Howdy has been rewritten and includes these fixes natively. This patcher is specifically for users stuck on the v2.6.1 package.
