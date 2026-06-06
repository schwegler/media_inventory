# MediaInventory — Hotwire Native iOS

A native iOS wrapper for the Media Inventory (MediaTracker) Rails 8 web application, built with [Hotwire Native](https://github.com/hotwired/hotwire-native-ios).

## Requirements

- **Xcode 16+**
- **iOS 18.0+** deployment target
- A running Rails server (default: `http://localhost:3000`)

## Getting Started

1. **Open the project in Xcode**

   Open `MediaInventory/Package.swift` in Xcode. It will automatically resolve the Hotwire Native dependency via Swift Package Manager.

   ```bash
   open MediaInventory/Package.swift
   ```

2. **Start your Rails server**

   Make sure your Rails app is running locally:

   ```bash
   bin/rails server
   ```

3. **Build and run**

   Select a simulator or connected device (iOS 18+) and press **⌘R** to build and run.

## Configuration

### Server URL

Edit `Sources/Configuration/Server.swift` to update the development or production URLs:

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

The path configuration in `Sources/Configuration/path-configuration.json` controls:

- **Tabs**: Bottom tab bar items (Home, Movies, Albums)
- **Rules**: URL pattern matching for navigation behavior (e.g., modal presentation for `/new`, `/edit`, `/login`)

A server-side path configuration is also loaded from `/configurations/ios_v1.json` to allow remote updates without app releases.

### Bundle Identifier

Update the bundle identifier in `Sources/Resources/Info.plist` from `com.example.MediaInventory` to your actual identifier before submitting to the App Store.

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
