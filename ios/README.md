# Fordays iOS (SwiftUI)

Native iOS client. The **web PWA** (`../src/`, Cloudflare) stays the companion for Google Calendar and browser use.

## Test in Xcode

1. Open **Xcode** (full app from the App Store).
2. If it asks about the license:
   ```bash
   sudo xcodebuild -license
   ```
3. In Terminal:
   ```bash
   cd ios
   xcodegen generate   # if Fordays.xcodeproj is missing or after editing project.yml
   open Fordays.xcodeproj
   ```
   Or double-click `Fordays.xcodeproj` in Finder.
4. Top of Xcode: choose a simulator (e.g. **iPhone 16**) or your iPhone.
5. Press **⌘R** (Product → Run).

First run downloads the Supabase Swift package (needs network). Sign in with the same account you use on the web.

### Physical iPhone

- **Xcode → Settings → Accounts** → add your Apple ID.
- Target **Fordays** → **Signing & Capabilities** → choose your Team.
- Bundle ID: `app.fordays.ios`.
- On the phone: trust the developer under **Settings → General → VPN & Device Management** if asked.

## Bundle ID

`app.fordays.ios` (same as App Store Connect / TestFlight).

## Still to build out

When-suggestions, covers/Giphy, GCal overlay, push, richer composer.
