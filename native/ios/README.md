# MediaInventory — Hotwire Native iOS

A native iOS wrapper for the Media Inventory (MediaTracker) Rails 8 web application, built with [Hotwire Native](https://github.com/hotwired/hotwire-native-ios).

## Requirements

- **Xcode 16+**
- **iOS 18.0+** deployment target
- A running Rails server (default: `http://localhost:3000`)

## Getting Started

The checked-in `MediaInventory/Package.swift` declares a regular Swift target, not an iOS application product. There is no `.xcodeproj`/`.xcworkspace`, and the manifest does not declare the JSON/plist resources. Opening it alone does not provide a runnable simulator app.

To complete the wrapper, create an iOS application target in Xcode, integrate the Hotwire Native dependency and these sources, and wire the scene manifest and resources into the app bundle. `AppDelegate` force-unwraps the bundled `path-configuration.json` URL, so resource packaging is required. Build and simulator/device verification remain necessary.

Start Rails with `bin/dev` from the repository root. The DEBUG URL in `MediaInventory/Sources/Configuration/Server.swift` is `http://localhost:3000`; on a physical device, configure a reachable development host instead. The release URL is still a placeholder.

## Configuration

### Server URL

Edit `MediaInventory/Sources/Configuration/Server.swift` to update the development or production URLs:

```swift
enum Server {
    #if DEBUG
    static let url = URL(string: "http://localhost:3000")!
    #else
    static let url = URL(string: "https://your-production-url.com")!
    #endif
}
```

### Path Configuration

The path configuration in `MediaInventory/Sources/Configuration/path-configuration.json` declares:

- **Tabs**: Home, Movies, Albums settings (the current `SceneDelegate` creates one Navigator; it does not build a native tab bar)
- **Rules**: URL pattern matching for navigation behavior (e.g., modal presentation for `/new`, `/edit`, `/login`)

A server-side path configuration is also loaded from `/configurations/ios_v1.json` to allow remote updates without app releases.

### Bundle Identifier

Update the bundle identifier in `MediaInventory/Sources/Resources/Info.plist` from `com.example.MediaInventory` to your actual identifier before submitting to the App Store.

## Project Structure

```
MediaInventory/
├── Package.swift                          # SPM manifest
└── Sources/
    ├── App/
    │   ├── AppDelegate.swift              # App entry point, Hotwire config
    │   └── SceneDelegate.swift            # Window/scene setup with Navigator
    ├── Configuration/
    │   ├── Server.swift                   # Server URL configuration
    │   └── path-configuration.json        # Navigation rules & tab config
    ├── BridgeComponents/
    │   └── FlashMessageComponent.swift    # Native flash message alerts
    └── Resources/
        └── Info.plist                     # App metadata & ATS config
```

## Bridge Components

### FlashMessageComponent

Receives `flash-message` events from the web app's Stimulus Bridge and displays them as native `UIAlertController` alerts. To use this, add a corresponding `bridge-flash-message` Stimulus controller in your Rails app.
