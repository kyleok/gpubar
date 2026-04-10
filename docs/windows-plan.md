# Windows GPUBar Plan

## Goal

Ship a Windows companion app in the same repository, with the existing macOS app unchanged, and publish both from the same tag-based GitHub Release flow.

## Repo Layout

- `Sources/GPUBar/` — existing macOS Swift app
- `windows/GPUBar.Windows/` — Windows desktop app (.NET 8, WPF)
- `windows/installer/` — Inno Setup packaging

## Windows MVP Scope

- Tray app with live GPU availability status
- Main window with:
  - overview
  - per-cluster details
  - pending jobs
  - top users
  - settings
- Same API contract as the macOS app (`/api/gpu/status?key=...`)
- Persisted local settings in `%AppData%/GPUBar/settings.json`
- Notifications when free GPUs cross a threshold
- `gpubar://configure` deep-link handling
- Optional launch at login via the current-user Run registry key

## Release Strategy

One tag creates one GitHub Release with:

- macOS zip (`GPUBar-<version>-macos.zip`)
- Windows portable zip (`GPUBar-<version>-windows-x64.zip`)
- Windows installer (`GPUBar-Setup-<version>.exe`)

## Validation Strategy

- Local macOS build still runs through Swift build/package script
- Windows build is validated on GitHub Actions (`windows-latest`) with `dotnet publish`
- Installer is generated on GitHub Actions with Inno Setup

## Known Tradeoffs

- The Windows app is a native rewrite, not a shared UI codebase
- The Windows tray can show a count badge in the icon, but not true menu-bar text like macOS
- Deep-link registration is done both in-app and in the installer for robustness
