# SONIC-170 v2 — Keyboard Lighting Editor

Web-based lighting configuration tool + prebuilt firmware for the SONIC-170 v2 keyboard (hot-swap & soldered editions).

## Features

- **WebHID web tool** (single HTML file, zero dependencies, offline-capable):
  - Per-pattern lighting config (mode / color / brightness / speed saved per pattern slot)
  - 13×13 pad matrix pattern editor with 8 pattern slots
  - Frame animation editor with 2 animation slots (60 frames each)
  - Side strip & CapsLock LED control
  - Typing feedback (Flicker) modes
  - Built-in **DFU firmware flasher** (WebUSB, STM32 DfuSe protocol) — flash firmware without any driver/tool
  - Built-in **GitHub update checker** — download latest firmware & VIA JSON from this repo's releases
  - VIA definition files download (hot-swap & soldered)

- **Firmware** (QMK, STM32F411):
  - `SONIC170_hotswap_v4.8.1.bin` — hot-swap edition
  - `SONIC170_solder_v4.8.1.bin` — soldered edition
  - Enter DFU mode: hold **Esc** while plugging in USB

## Usage

1. Open `sonic170v2灯光编辑工具.html` in **Chrome/Edge** (double-click — keep it as a local file).
2. Click **Connect** and pick the keyboard.
3. Edit lighting, patterns or animations — changes apply instantly.
4. To flash firmware: unplug, hold **Esc**, plug in → **Flash Firmware (DFU)** → connect "STM32 BOOTLOADER" → choose a `.bin`.

> Note: WebHID/WebUSB require Chrome or Edge and a secure context (localhost or https). The page also works offline from a local file.

## Releases

Grab the latest firmware & VIA JSONs from the [Releases](https://github.com/kevinxu/sonic170-v2/releases) page, or use the **Check GitHub Update** button inside the tool.

## License

[MIT](LICENSE) © 2026 kindlestar (kevinxu)
