# Plasma Island

<p align="center">
  <strong>All-in-one dynamic status pill & 3-zone top bar widget for KDE Plasma 6</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/KDE%20Plasma-6.0%2B-1d99f3?style=flat-square&logo=kde&logoColor=white" alt="KDE Plasma 6.0+">
  <img src="https://img.shields.io/badge/Qt-6-41cd52?style=flat-square&logo=qt&logoColor=white" alt="Qt 6">
  <img src="https://img.shields.io/badge/Version-1.1.0-8b5cf6?style=flat-square" alt="Version 1.1.0">
  <a href="https://store.kde.org/p/2382766"><img src="https://img.shields.io/badge/KDE%20Store-Plasma%20Island-1d99f3?style=flat-square&logo=kde&logoColor=white" alt="KDE Store"></a>
  <img src="https://img.shields.io/badge/License-GPL--2.0--or--later-blue?style=flat-square" alt="License GPL-2.0-or-later">
</p>

**Plasma Island** is a lightweight, customizable KDE Plasma 6 applet (`com.anzu.plasma-island`) that brings together a clock, weather, virtual workspace switcher, MPRIS media player with a mirrored soundwave visualizer, and a single-fork hardware/system status monitor into one clean capsule or full-width 3-zone bar.

---

## Preview

![Plasma Island Preview](assets/preview.png)

---

## Features

- **Clock** — 12h/24h format, optional seconds, and locale-aware date.
- **Weather** — Live temperature and conditions (`°C`/`°F`) with manual city or auto-location.
- **Workspaces** — Virtual desktop indicator with click switching, scroll cycling, and optional hide-empty toggle.
- **Media Player** — Album art, scrolling title, playback controls, auto-hide option, and a real-time bass-reactive waveform.
- **System Status** — Wi-Fi, Bluetooth toggle, battery, volume (mute & scroll), network speed, CPU, temperature, RAM, and quick Settings/KRunner shortcuts.
- **Appearance** — Full-width 3-zone bar or compact pill, Dark & Light modes, `0%–100%` opacity, custom colors, and 8 theme presets.

---

## Requirements

- **KDE Plasma 6.0+** & **Qt 6** (`qt6-declarative`, `kirigami`, `kcmutils`, `plasma5support`)
- Runtime CLI utilities (all optional per module):
  - `playerctl` — Media Player (`plasma-browser-integration` recommended for browser thumbnails)
  - `parec` + `python3` — Live PipeWire FFT waveform analyzer (optional; falls back to procedural pulse)
  - `nmcli` (NetworkManager) — Wi-Fi SSID detection
  - `wpctl` (WirePlumber / PipeWire) — Volume indicator & scroll control
  - `qdbus6` — Virtual desktop switching
  - `rfkill` / `busctl` / `bluetoothctl` — Bluetooth status & toggle

---

## Installation

### From KDE Store
Install directly via **Add or Manage Widgets → Get New... → Download New Plasma Widgets** (search **Plasma Island**), or download from [store.kde.org/p/2382766](https://store.kde.org/p/2382766).

### From Source
```bash
git clone https://github.com/anzutm/kde-plasma-island.git
cd kde-plasma-island
kpackagetool6 -t Plasma/Applet -i .
```

### Upgrade Existing Installation
```bash
kpackagetool6 -t Plasma/Applet -u .
systemctl --user restart plasma-plasmashell.service
```

### Development Symlink (Live Edits)
```bash
ln -s "$(pwd)" ~/.local/share/plasma/plasmoids/com.anzu.plasma-island
systemctl --user restart plasma-plasmashell.service
```

### Uninstall
```bash
kpackagetool6 -t Plasma/Applet -r com.anzu.plasma-island
```

---

## Usage

1. Right-click your **Desktop** or **Top Panel** → **Add or Manage Widgets...**
2. Search for **Plasma Island** and add it.
3. For a full-width desktop bar, enter **Edit Mode** and resize the widget horizontally to span your screen (or place it inside a full-width Top Panel).
4. Right-click the widget → **Configure Plasma Island...** to customize **Clock & Weather**, **Appearance**, and **Modules**.

---

## Project Structure

```text
kde-plasma-island/
├── assets/
│   └── preview.png
├── contents/
│   ├── config/
│   │   ├── config.qml
│   │   └── main.xml
│   ├── icons/
│   │   └── plasma-island.svg
│   ├── scripts/
│   │   └── audio_bass.py
│   ├── screenshot.png
│   └── ui/
│       ├── main.qml
│       ├── ClockWidget.qml
│       ├── WeatherWidget.qml
│       ├── WorkspaceWidget.qml
│       ├── MediaWidget.qml
│       ├── StatusWidget.qml
│       ├── ConfigGeneral.qml
│       ├── ConfigAppearance.qml
│       └── ConfigModules.qml
├── LICENSE
├── metadata.json
└── README.md
```

---

## License

Licensed under the [GPL-2.0-or-later](LICENSE) license. See [`metadata.json`](metadata.json) for plugin metadata.
