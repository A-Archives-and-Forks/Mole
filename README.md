<div align="center">
  <img src="https://cdn.tw93.fun/pic/cole.png" alt="Mole Logo" width="120" height="120" style="border-radius:50%" />
  <h1 style="margin: 12px 0 6px;">Mole</h1>
  <p><em>🦡 Dig deep like a mole to clean your Mac.</em></p>
</div>

<p align="center">
  <a href="https://github.com/tw93/mole/stargazers"><img src="https://img.shields.io/github/stars/tw93/mole?style=flat-square" alt="Stars"></a>
  <a href="https://github.com/tw93/mole/releases"><img src="https://img.shields.io/github/v/tag/tw93/mole?label=version&style=flat-square" alt="Version"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square" alt="License"></a>
  <a href="https://github.com/tw93/mole/commits"><img src="https://img.shields.io/github/commit-activity/m/tw93/mole?style=flat-square" alt="Commits"></a>
  <a href="https://twitter.com/HiTw93"><img src="https://img.shields.io/badge/follow-Tw93-red?style=flat-square&logo=Twitter" alt="Twitter"></a>
  <a href="https://t.me/+GclQS9ZnxyI2ODQ1"><img src="https://img.shields.io/badge/chat-Telegram-blueviolet?style=flat-square&logo=Telegram" alt="Telegram"></a>
</p>

## Highlights

- 🐦 **Deep System Cleanup** - Remove hidden caches, logs, and temp files in one sweep
- 📦 **Thorough Uninstall** - 22+ locations cleaned vs 1 standard, beats CleanMyMac/Lemon
- ⚡️ **Fast & Lightweight** - Terminal-based, zero bloat, arrow-key navigation with pagination
- 🧹 **Massive Space Recovery** - Reclaim 100GB+ of wasted disk space

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/tw93/mole/main/install.sh | bash
```

Or via Homebrew:

```bash
brew install tw93/tap/mole
```

> Pick one method to avoid conflicts, new users check [小白使用指南](./GUIDE.md)

## Usage

```bash
mole                      # Interactive main menu
mole clean                # Deep system cleanup
mole clean --dry-run      # Preview cleanup (no deletions)
mole uninstall            # Interactive app uninstaller
mole update               # Update to latest version
mole --help               # Show help
```

> Installed via Homebrew? Use `brew upgrade mole` to update

## Examples

### Deep System Cleanup

```bash
$ mole clean

Starting user-level cleanup...

▶ System essentials
  ✓ User app cache (28 items) (45.2GB)
  ✓ User app logs (15 items) (2.1GB)
  ✓ Trash (12.3GB)

▶ Browser cleanup
  ✓ Chrome cache (8 items) (8.4GB)
  ✓ Safari cache (2.1GB)
  ✓ Arc cache (3.2GB)

▶ Extended developer caches
  ✓ Xcode derived data (9.1GB)
  ✓ Node.js cache (4 items) (14.2GB)
  ✓ VS Code cache (1.4GB)

▶ Applications
  ✓ JetBrains cache (3.8GB)
  ✓ Slack cache (2.2GB)
  ✓ Discord cache (1.8GB)

====================================================================
🎉 CLEANUP COMPLETE!
💾 Space freed: 95.50GB | Free space now: 223.5GB
📊 Files cleaned: 6420 | Categories processed: 6
====================================================================
```

### Smart App Uninstaller

```bash
$ mole uninstall

Select Apps to Remove

▶ ☑ Adobe Creative Cloud      (12.4G) | Old
  ☐ WeChat                    (2.1G) | Recent
  ☐ Final Cut Pro             (3.8G) | Recent

🗑️  Uninstalling: Adobe Creative Cloud
  ✓ Removed application
  ✓ Cleaned 52 related files

====================================================================
🎉 UNINSTALLATION COMPLETE!
🗑️ Apps uninstalled: 1 | Space freed: 12.8GB
====================================================================
```

## What Mole Cleans

| Category | Targets | Typical Recovery |
|----------|---------|------------------|
| **System** | App caches, logs, trash, crash reports, Spotlight cache | 20-50GB |
| **Browsers** | Safari, Chrome, Edge, Arc, Firefox, Brave cache | 5-15GB |
| **Developer** | npm, pip, Docker, Homebrew, Xcode, Android Studio | 15-40GB |
| **Cloud Storage** | Dropbox, Google Drive, OneDrive, Baidu Netdisk cache | 5-20GB |
| **Office Apps** | Microsoft Office, iWork, WPS Office cache | 2-8GB |
| **Media Apps** | Spotify, Music, VLC, IINA, video players cache | 3-12GB |
| **Communication** | Slack, Discord, Teams, WeChat, Zoom cache | 3-10GB |
| **Virtualization** | VMware, Parallels, VirtualBox, Vagrant cache | 5-15GB |

**Protect Important Files:** Create `~/.config/mole/whitelist` to preserve critical caches:

```bash
# View current whitelist
mole clean --whitelist

# Example: Protect Playwright browsers and build tools
echo '~/Library/Caches/ms-playwright*' >> ~/.config/mole/whitelist
```

## What Mole Uninstalls

| Category | What Gets Removed | Locations |
|----------|------------------|-----------|
| **App Bundle** | Main application executable | `/Applications/` |
| **User Data** | Support files, caches, preferences, logs, containers, saved states | `~/Library/` (12 locations) |
| **Web Data** | WebKit storage, HTTP storage, cookies | `~/Library/WebKit/`, `~/Library/HTTPStorages/` |
| **Extensions** | Plugins, scripts, services, frameworks, QuickLook generators | `~/Library/Internet Plug-Ins/`, `~/Library/Services/` |
| **System** | Launch daemons, helper tools, system preferences, install receipts | `/Library/`, `/var/db/receipts/` (requires sudo) |

## FAQ

1. **Will Mole delete important files?** - No. Mole has built-in protection and skips system-critical files.
2. **Can I undo cleanup operations?** - Cache files are safe to delete and will regenerate automatically.
3. **How often should I run cleanup?** - Once a month is sufficient. Run when disk space is low.
4. **Is it safe to use?** - Yes. The tool previews what will be deleted before any action (`--dry-run`).

## Support

- ⭐️ **Star this repo** if Mole helped you recover disk space
- 🐛 **Report issues** via [GitHub Issues](https://github.com/tw93/mole/issues)
- 💬 **Share with friends** who need to clean their Macs
- 🐱 I have two cats, <a href="https://miaoyan.app/cats.html?name=Mole" target="_blank">feed them canned food</a> if you'd like

## License

MIT License - feel free to enjoy and participate in open source.
