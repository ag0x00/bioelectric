## Project Overview: Web-to-Native Screensaver Wrapper

**Objective:** Package an existing HTML5/JS/CSS animation into native screensaver formats for macOS (`.saver`) and Windows (`.scr`).
**Core Tech:** Native WebView wrappers (WebKit for Mac, WebView2 for Windows) to ensure maximum performance and modern web feature support.

---

## 1. Technical Specifications

### A. macOS Implementation (Swift/Xcode)

* **Framework:** Use the `ScreenSaver` framework. Subclass `ScreenSaverView`.
* **Engine:** `WKWebView`.
* **Requirement:** Must be built as a **Universal Binary** (supporting both Intel and Apple Silicon `arm64`).
* **Lifecycle:** Ensure the WebView stops rendering when `stopAnimation()` is called to save CPU/Battery.
* **Sandboxing:** Enable App Sandboxing with "Outgoing Connections" (if the animation needs internet) or restricted local file access.

### B. Windows Implementation (C#/.NET)

* **Framework:** WinForms or WPF wrapper.
* **Engine:** **WebView2 Evergreen Runtime**.
* **Command Line Arguments:** Must correctly handle:
* `/s`: Start screensaver (full screen).
* `/p`: Show small preview in the Windows Screen Saver Settings dialog.
* `/c`: Show settings (optional).


* **Exit Logic:** Must terminate on `MouseMove`, `MouseDown`, or `KeyDown`.

---

## 2. Production & Distribution Requirements

*This section is the most critical for "anyone" to be able to use the software safely.*

### A. Security & Trust (Code Signing)

* **macOS Notarization:** * The `.saver` bundle must be signed with a **Developer ID Application** certificate.
* The final installer must be submitted to the Apple Notary Service via `notarytool` to avoid Gatekeeper "Malicious Software" warnings.


* **Windows Authenticode:** * The `.exe` (renamed to `.scr`) must be signed with a standard or **EV (Extended Validation) Code Signing Certificate**.
* Without this, Microsoft SmartScreen will block the file for users.



### B. The Installer Experience

* **macOS Installer:** Build a `.pkg` (Flat Package) using `pkgbuild`.
* **Target Path:** `/Library/Screen Savers` (all users) or `~/Library/Screen Savers` (current user).


* **Windows Installer:** Use **Inno Setup** or **NSIS**.
* The installer must check for the presence of the **WebView2 Runtime** and offer to download it if missing.
* It should copy the `.scr` to `C:\Windows\System32` or the AppData folder and register it in the Windows Registry.



---

## 3. Behavioral Requirements

| Feature | Requirement |
| --- | --- |
| **Multi-Monitor** | Animation must detect and span across all connected displays (or duplicate, based on settings). |
| **Asset Loading** | All assets (JS/CSS/Images) must be local. Zero dependency on external CDNs to allow offline play. |
| **Performance** | Cap frame rate at 60fps. Implement a 30fps "Battery Saver" mode if possible. |
| **Interaction** | On Mac, ignore mouse clicks if they are "hit testing." On Windows, exit immediately. |

---

## 4. Delivery & Acceptance Criteria

1. **Source Code:** Full Xcode and Visual Studio projects.
2. **Binaries:** Signed `.saver` and `.scr` files.
3. **Installers:** A notarized `.pkg` for Mac and a signed `.exe` installer for Windows.
4. **Documentation:** A brief "readme" on how to update the `web_content` folder for future animation changes.

