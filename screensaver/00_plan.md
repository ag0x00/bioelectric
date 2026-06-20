## 1. Core Technical Requirements

To ensure the web animation works as a screensaver, the code must handle these specific "screensaver behaviors":

* **Self-Termination:** The app must close immediately on mouse movement, click, or keypress (though the OS wrapper usually handles this).
* **Multi-Monitor Support:** The animation should span or duplicate across all connected screens.
* **Resource Management:** Screensavers should trigger "Low Power" modes or limit frame rates to avoid taxing the GPU while the user is away.
* **Offline Capability:** All assets (JS libraries, images) must be local; no external CDNs.

---

## 2. Implementation Plan

### Phase A: The Web Package (Platform Agnostic)

Before building the wrappers, the HTML/JS needs to be "hardened."

* **Engineers Task:** Optimize the `requestAnimationFrame` loop. Ensure the CSS uses `overflow: hidden` and `margin: 0` to prevent scrollbars.
* **AI Prompt Tip:** "Refactor this HTML/JS animation to be a self-contained local directory. Ensure it scales responsively to any aspect ratio (4:3, 16:9, 32:9)."

### Phase B: macOS Implementation (`.saver` bundle)

macOS screensavers are written in Swift or Objective-C using the `ScreenSaver` framework.

* **The Tech:** Use a `WKWebView` (WebKit) to load the local `index.html`.
* **Engineer's Tool:** Xcode.
* **The Goal:** Create a `.saver` file that can be dropped into `~/Library/Screen Savers`.

### Phase C: Windows Implementation (`.scr` file)

Windows screensavers are essentially `.exe` files renamed to `.scr`.

* **The Tech:** C# / .NET with **WebView2** (which uses the Microsoft Edge engine).
* **Engineer's Tool:** Visual Studio.
* **The Goal:** An executable that handles the `/s` (start), `/p` (preview), and `/c` (configure) command-line arguments.

---

## 3. Testing Strategy for a Mac User

Since you are on a Mac, testing the Windows version requires a specific setup.

| Platform | Testing Method |
| --- | --- |
| **macOS** | Double-click the generated `.saver` file. macOS will ask to install it. Open **System Settings > Wallpapers & Screen Saver** to preview. |
| **Windows** | Use **Parallels Desktop** or **VMware Fusion** (both run Windows on Mac). You can drag the `.scr` file into the virtual Windows environment, right-click it, and select "Test." |
| **Performance** | Use Chrome DevTools (Command+Option+I) on your original HTML to check the **"Rendering" tab**. Look for "Frame Rendering Stats" to ensure it stays at 60fps without spiking CPU. |

---

## 4. Summary Table for Your Engineer

| Feature | macOS Requirement | Windows Requirement |
| --- | --- | --- |
| **Engine** | WKWebView (Native Safari) | WebView2 (Native Edge) |
| **File Format** | `.saver` (Bundle) | `.scr` (Executable) |
| **Interactive** | Handle `hitTest` to ignore mouse | Handle `WM_MOUSEMOVE` to exit |
| **Settings** | `ScreenSaverDefaults` | Registry keys or `.json` |

