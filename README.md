<p align="center"><img src="logo.png" width="120" alt="kindlestar logo"></p>

# 🎹 SONIC-170 v2 — Keyboard Lighting Editor

> 🔧 Built by **kindlestar** for the **SONIC-170 v2** custom mechanical keyboard — a custom **PCBA design** together with its companion web configuration tool.
> 🙏 Special thanks to **阿姆骡** for the inspiration and early testing.

<p align="center"><img src="Sonic170-v2.jpg" width="640" alt="SONIC-170 v2 keyboard"></p>

**🌐 中文说明：[简体中文](README_zh-CN.md)**

This repository contains everything you need to configure and reflash the SONIC-170 v2 keyboard:

| 📄 File | ℹ️ Description |
|---|---|
| `sonic170v2-rgb-control.html` | Web editor — single file, zero dependencies, offline-capable (WebHID/WebUSB) |
| `SONIC170_hotswap_v4.8.1.bin` | Firmware — hot-swap edition |
| `SONIC170_solder_v4.8.1.bin` | Firmware — soldered edition |
| `sonic170_via_hotswap.json` | VIA definition — hot-swap edition |
| `sonic170_via_solder.json` | VIA definition — soldered edition |

## ✨ Features

- 🎨 **Per-pattern lighting** — each of the 8 pattern slots remembers its own mode, color, brightness and speed; switching patterns loads each one's own look, and it survives reboots
- 🧩 **13×13 pad matrix editor** — 8 pattern slots (3 factory + 5 custom)
- 🎞️ **Frame animation** — 2 animation slots, up to 60 frames each, bindable to patterns
- 💡 **Side strip & CapsLock LED** independent control
- ⌨️ **Typing feedback (Flicker)** modes
- 🔥 **Built-in DFU flasher** (WebUSB, STM32 DfuSe) — no drivers or tools; flash firmware right from the browser, including a "clear settings & animations" repair option
- 🚀 **Built-in GitHub updater** — one-click download of the latest firmware & VIA JSONs from this repo's releases
- 🌐 Bilingual UI (中文 / English)

## 🚀 Getting Started

1. 📂 Open `sonic170v2-rgb-control.html` in **Chrome or Edge** (double-click the file — it works fully offline).
2. 🔌 Click **Connect** and pick the keyboard.
3. 🎚️ Edit lighting, patterns or animations — every change applies instantly.
4. ⚡ To flash firmware: unplug, hold **Esc**, plug back in → **Flash Firmware (DFU)** → connect the "STM32 BOOTLOADER" device → choose the `.bin`.

> 💡 WebHID / WebUSB require a Chromium browser; the tool works from a local file, `localhost` or `https`.

## 📦 Releases

Latest firmware and VIA definitions are published as [GitHub Releases](https://github.com/709208969/sonic170-v2/releases). The in-tool **Check GitHub Update** button does this for you (repo: `709208969/sonic170-v2`).

## 📜 License

[MIT](LICENSE) © 2026 kindlestar (kevinxu)
