# 🛡️ Howdy Patcher

### Windows Hello™ Style Face Unlock for Debian 13, Ubuntu 24.04+ & Modern Linux

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Linux](https://img.shields.io/badge/Platform-Linux-blue.svg)](https://www.linux.org/)
[![Debian](https://img.shields.io/badge/Debian-13+-red.svg)](https://www.debian.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04+-orange.svg)](https://ubuntu.com/)
[![Python](https://img.shields.io/badge/Python-3.10+-green.svg)](https://python.org/)

> **TL;DR:** [Howdy](https://github.com/boltgolt/howdy) face recognition broken on modern Linux? Run this script to fix it instantly.

---

## ⚡ One-Line Fix

```bash
curl -fsSL https://raw.githubusercontent.com/blamairia/howdy-patcher/main/howdy-patcher.sh -o howdy-patcher.sh && chmod +x howdy-patcher.sh && sudo ./howdy-patcher.sh
```

---

## 🔥 Are You Getting These Errors?

### ❌ `ModuleNotFoundError: No module named 'ConfigParser'`
```
Traceback (most recent call last):
  File "/lib/security/howdy/pam.py", line 10, in <module>
    import ConfigParser
ModuleNotFoundError: No module named 'ConfigParser'
```

### ❌ `externally-managed-environment` during installation
```
error: externally-managed-environment
× This environment is externally managed
```

### ❌ GStreamer camera errors
```
[ WARN:0@2.941] global cap_gstreamer.cpp:2839 handleMessage OpenCV | GStreamer warning: Embedded video playback halted
[ WARN:0@2.941] global cap_gstreamer.cpp:1698 open OpenCV | GStreamer warning: unable to start pipeline
```

### ❌ Sudo works without password after installing Howdy
Your PAM is failing silently and falling back to permit-all!

### ❌ Face recognition not working on Debian 13 / Ubuntu 24.04
The old Howdy package is incompatible with Python 3.10+

**👆 If you're experiencing ANY of these — this patcher fixes them all!**

---

## 🤔 What is Howdy?

[Howdy](https://github.com/boltgolt/howdy) provides **Windows Hello™ style facial authentication for Linux**. It uses your IR camera to recognize your face and log you in — no password needed!

**The Problem:** The packaged version (v2.6.1) doesn't work on modern systems like Debian 13 "Trixie" or Ubuntu 24.04+ because:
- It uses Python 2 syntax (`ConfigParser`) but modern systems only have Python 3 (`configparser`)
- The PAM module crashes silently, making `sudo` work without ANY authentication
- OpenCV defaults to GStreamer which doesn't work with many IR cameras

**The Solution:** This patcher automatically fixes all these issues in seconds.

---

## 🔧 What Gets Fixed

| Issue | Before | After |
|-------|--------|-------|
| **Python Module** | `import ConfigParser` (Python 2) | `import configparser` (Python 3) |
| **Camera Backend** | GStreamer (broken) | V4L2 (works) |
| **dlib Dependency** | Blocked by PEP 668 | Installed with workaround |

---

## 🚀 Installation

### Quick Install
```bash
curl -fsSL https://raw.githubusercontent.com/blamairia/howdy-patcher/main/howdy-patcher.sh -o howdy-patcher.sh
chmod +x howdy-patcher.sh
sudo ./howdy-patcher.sh
```

### From Source
```bash
git clone https://github.com/blamairia/howdy-patcher.git
cd howdy-patcher
sudo ./howdy-patcher.sh
```

---

## 📋 Requirements

- ✅ **Howdy v2.6.1** installed (from `.deb` package, PPA, or gdebi)
- ✅ **Linux** with Python 3.10+ (Debian 13, Ubuntu 24.04, Fedora 39+, etc.)
- ✅ **Root/sudo** access
- ✅ IR Camera (usually `/dev/video2`)

---

## 💻 Supported Distributions

| Distribution | Version | Status |
|--------------|---------|--------|
| Debian | 13 "Trixie" | ✅ Tested |
| Ubuntu | 24.04 LTS | ✅ Supported |
| Ubuntu | 24.10+ | ✅ Supported |
| Linux Mint | 22+ | ✅ Supported |
| Fedora | 39+ | ✅ Supported |
| Arch Linux | Rolling | ⚠️ Use AUR package instead |

---

## 🔄 After Patching

1. **Find your IR camera:**
   ```bash
   v4l2-ctl --list-devices
   ```
   Look for "IR" in the name (usually `/dev/video2`)

2. **Configure Howdy:**
   ```bash
   sudo howdy config
   ```
   Set `device_path = /dev/video2` (your IR camera path)

3. **Add your face:**
   ```bash
   sudo howdy add
   ```

4. **Test it:**
   ```bash
   sudo howdy test   # Visual test with camera feed
   sudo -i           # Real authentication test
   ```

---

## 🔙 Rollback

The patcher creates a timestamped backup. To restore:

```bash
# Find your backup
ls /lib/security/howdy-backup-*

# Restore it
sudo ./restore-howdy.sh /lib/security/howdy-backup-YYYYMMDD-HHMMSS
```

---

## 📝 Manual Fixes

If you prefer to apply fixes manually:

### Fix 1: Python 3 Compatibility (pam.py)
```bash
sudo sed -i 's/^import ConfigParser$/import configparser as ConfigParser/' /lib/security/howdy/pam.py
```

### Fix 2: V4L2 Camera Backend (video_capture.py)
Edit `/lib/security/howdy/recorders/video_capture.py`:
```python
# Change this:
self.internal = cv2.VideoCapture(
    self.config.get("video", "device_path")
)

# To this:
self.internal = cv2.VideoCapture(
    self.config.get("video", "device_path"), cv2.CAP_V4L2
)
```

### Fix 3: Install dlib (PEP 668 bypass)
```bash
sudo pip3 install dlib --break-system-packages
```

---

## 🔗 Related Howdy Issues

This patcher was created to solve these open issues:

- [#912 - Howdy can't import module ConfigParser](https://github.com/boltgolt/howdy/issues/912)
- [#954 - externally-managed-environment error](https://github.com/boltgolt/howdy/issues/954)
- [#1027 - Python 2 commands in pam script](https://github.com/boltgolt/howdy/issues/1027)
- [#935 - Ubuntu 24.04 LTS issues](https://github.com/boltgolt/howdy/issues/935)
- [#890 - Ubuntu 24.04 LTS](https://github.com/boltgolt/howdy/issues/890)
- [#1046 - Howdy PAM module fails on Ubuntu 25.04](https://github.com/boltgolt/howdy/issues/1046)

---

## 🤝 Contributing

Contributions welcome! Please open an issue or PR.

Found this helpful? ⭐ Star the repo!

---

## 📄 License

MIT License - see [LICENSE](LICENSE) file.

---

## 🙏 Credits

- **[Howdy](https://github.com/boltgolt/howdy)** by boltgolt — The amazing Windows Hello™ style facial authentication for Linux
- This patcher was created after encountering these issues on Debian 13 "Trixie"

---

## 🔍 SEO Keywords

`howdy not working debian 13` · `howdy ubuntu 24.04 fix` · `ModuleNotFoundError ConfigParser howdy` · `howdy pam.py error` · `howdy externally-managed-environment` · `howdy GStreamer error` · `howdy facial recognition linux fix` · `windows hello linux debian` · `face unlock ubuntu` · `howdy v4l2` · `howdy python 3` · `sudo no password howdy` · `howdy IR camera not working`

---

> **Note:** The [dev branch](https://github.com/boltgolt/howdy/tree/dev) of Howdy has been completely rewritten and includes these fixes natively. This patcher is specifically for users stuck on the packaged v2.6.1 version.
