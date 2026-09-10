<p align="center"><img src="logo.png" width="120" alt="kindlestar logo"></p>

# 🎹 CC01 — Keyboard Lighting Editor

> 🔧 Web lighting tool for **kindlestar CC01** (75% keyboard; hotswap + solder). Adapted from the sonic170 v2 editor (v47.79): CC01 LED zones = LED0 Caps + LED1 power indicator + left/right LED bars (58 LEDs, LED2-59).

**🌐 中文: [中文](README_zh-CN.md)**

## 📄 Files

| File | Description |
|---|---|
| `cc01-rgb-control.html` | **CC01 web editor** (single file, zero deps, WebHID, offline-capable, current **v1.1**) |
| `sonic170v2-rgb-control.html.bak` | unmodified sonic170 original (rollback reference) |
| `SONIC170_*.bin` / `sonic170_via_*.json` etc. | **leftover sonic170 release assets (to be replaced when publishing)** |

## ✨ Features (v1.2)

- 🎨 Per-pattern config — 8 pattern slots (3 factory + 5 custom, 58-LED bitmap) with own effect/color/brightness/speed
- 🖌️ Rear LED bar pattern editor — 58 LEDs shown as **2×29** (left 29 on one row + right 29 on another, top = right segment / bottom = left segment, keyboard top-view alignment); eraser / fill / invert / clear / Mirror H / Mirror V / Rotate 180° (full-chain mirror) / shift / direction
- 🎞️ Frame animation (58-LED, single slot = pattern 3, ≤20 frames × 174B) — brush/eraser/fill/picker/select/onion/mirror/preview, fps banks 5/10/30/60 (30/60 capped at 20 frames), PNG/GIF import, PNG/sheet/GIF export, library, upload/read-back/clear
- 💡 Power LED (LED1) / CapsLock LED (LED0) / Rear LED bar (LED2-59) independent control (brightness ≤200, matching firmware)
- 🔥 In-browser DFU flashing (adapted to CC01 STM32F072: 128KB = 64 pages × 2KB erase)
- 🌐 EN/CN UI + config import/export + firmware download (embedded cc01_hs v1.2.46)
- ⏫ Update check (repo configurable — asks once on first click; set a default before publishing)

### vs sonic170

| Item | Status |
|---|---|
| Typing feedback effects | removed (not a CC01 feature) |
| LED count/layout | 13×13(169) → rear bar 58 LEDs, **2×29 view** |
| Direction/transforms | redefined for a 58-LED chain: Direction = chain reverse, Mirror H = segment mirror, Mirror V = segment swap, Rotate = 180° full-chain mirror. **Rotate 90° and vertical moves don't exist on a single-chain bar → buttons stay visible but disabled with tooltips** (no fake ops) |
| Animation | 58-LED frames (174B), single slot = pattern 3, ≤20 frames (30/60fps banks capped; value still sent as play rate) |
| DFU | erase switched to F072 (64 × 2KB pages) |
| Update check | repo asked on first click (localStorage `cc01_gh_repo`); asset matching for CC01_hs/CC01_sd |
| Firmware download | embedded cc01_hs v1.2.46; solder (cc01_sd) disabled until dual-board release |
| VIA JSON | embedded CC01_hs_via.json (0x4351:0x0080) |

> ⚠️ **Matching firmware = v1.2.47** (on-board persistence + zone rendering): page controls patterns/effects/animation via value_id 1-46 into the firmware rgb_control zone system; after the 2s boot effect, zone rendering takes over. **Settings now survive power cycles** (custom F0 EEPROM driver with 64-bit programming); master OFF intentionally not persisted (B-plan).

## 🚀 Quick start

1. Open `cc01-rgb-control.html` in Chrome/Edge (double-click, fully offline).
2. Click **Connect** and pick the keyboard (0x4351:0x0080).
3. Edit effects/patterns — live once connected (local preview without connection).
4. Flashing: hold **Esc** while plugging in (bootmagic) → DFU, then:
   `dfu-util -d 0483:df11 -a 0 -s 0x08000000:leave -D CC01_hs_v1.2.45.bin`

> ⚠️ Current firmware v1.2.45 is the bitbang/native-rainbow/indicator verification build (zone rendering paused).
> Pattern & zone control from this page needs the production firmware (rgb_control zone system restored) to affect keyboard lighting; on the verification build, reads work but rendering stays native (expected).

## 📜 License

[MIT](LICENSE) © 2026 kindlestar (kevinxu)
