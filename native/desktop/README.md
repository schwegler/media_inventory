# Media Inventory — Desktop App

A cross-platform desktop application that wraps the **Media Inventory** Rails 8 web app using [Tauri 2](https://v2.tauri.app). Builds native binaries for macOS, Windows, and Linux.

## Prerequisites

### All Platforms

- **Rust** (stable) — install via [rustup](https://rustup.rs)
- **Node.js** (v18+) and **npm**

### macOS

- **Xcode Command Line Tools**: `xcode-select --install`

### Windows

- **Microsoft Visual Studio C++ Build Tools**
- **WebView2** (pre-installed on Windows 10/11)
- See [Tauri Windows prerequisites](https://v2.tauri.app/start/prerequisites/#windows)

### Linux

- Development libraries for WebKit2GTK 4.1 and related packages:

  ```bash
  # Debian/Ubuntu
  sudo apt install libwebkit2gtk-4.1-dev build-essential curl wget file \
    libxdo-dev libssl-dev libayatana-appindicator3-dev librsvg2-dev

  # Fedora
  sudo dnf install webkit2gtk4.1-devel openssl-devel curl wget file \
    libappindicator-gtk3-devel librsvg2-devel

  # Arch
  sudo pacman -S webkit2gtk-4.1 base-devel curl wget file openssl \
    libappindicator-gtk3 librsvg
  ```

- See [Tauri Linux prerequisites](https://v2.tauri.app/start/prerequisites/#linux)

## Setup

```bash
# From native/desktop/
npm install
```

## Development

Start the Rails server first, then launch the Tauri dev window:

```bash
# Terminal 1 — start the Rails server (from project root)
bin/rails server

# Terminal 2 — start the Tauri dev window (from native/desktop/)
npm run dev
```

In dev mode, Tauri loads `http://localhost:3000` directly via the `devUrl` setting. If the Rails server isn't running, the app displays a fallback page with auto-retry.

## Production Build

```bash
npm run build
```

This compiles the Rust backend and bundles a platform-specific installer:

| Platform | Output |
|----------|--------|
| macOS    | `.dmg` and `.app` bundle |
| Windows  | `.msi` and `.exe` installer |
| Linux    | `.deb` and `.AppImage` |

Built artifacts are located in `src-tauri/target/release/bundle/`.

## Configuring for Production URL

To point the app at a deployed server instead of localhost:

1. **Edit `src-tauri/tauri.conf.json`**:
   - Change `build.frontendDist` to your production URL (e.g., `"https://media-inventory.example.com"`)
   - Remove or leave `build.devUrl` (it's only used during `tauri dev`)

2. **Update the CSP** in `app.security.csp` to allow your production domain in `connect-src`, `script-src`, etc.

3. **Rebuild**: `npm run build`

## Project Structure

```
native/desktop/
├── package.json                 # Node dependencies & scripts
├── README.md
├── src/
│   └── index.html               # Fallback page (server unreachable)
└── src-tauri/
    ├── tauri.conf.json           # Tauri configuration
    ├── Cargo.toml                # Rust dependencies
    ├── build.rs                  # Tauri build script
    ├── capabilities/
    │   └── default.json          # Window permissions
    └── src/
        ├── main.rs               # Application entry point
        └── lib.rs                # Tauri setup & commands
```

## Icons

Default Tauri icons are referenced in `tauri.conf.json`. To use custom icons, generate them with:

```bash
npx @tauri-apps/cli icon path/to/your-icon.png
```

This creates all required sizes in `src-tauri/icons/`.
