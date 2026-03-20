# GPUBar

macOS menu bar app for monitoring GPU cluster availability at a glance.

![GPUBar](docs/screenshot.png)

## Features

- Live free GPU count in menu bar
- Per-cluster and per-node breakdown with usage bars
- Pending jobs queue
- GPU availability notifications
- One-click setup via dashboard deep link
- Auto-refresh (30s–5min)

## Install

**Download** the latest `.zip` from [Releases](../../releases), extract, and move `GPUBar.app` to `/Applications`.

If macOS blocks it:
```bash
xattr -cr /Applications/GPUBar.app
```

## Build from Source

Requires macOS 14+ and Swift 5.9+.

```bash
swift build -c release
```

## License

MIT
