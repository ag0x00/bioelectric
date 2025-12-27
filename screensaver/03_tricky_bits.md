### Phase 1: Context Loading (The "Mega-Prompt")

*Run this first to ground Claude in the project reality. Replace `[PATH]` with your actual path.*

> "I have a local directory at `[PATH_TO_WEB_CONTENT]` containing an `index.html`, CSS, and JS files for an animation. I want to wrap this web content into a native screensaver.
> **Global Constraints:**
> 1. **Offline Only:** The wrapper must load files from the local bundle/resources, never from a URL.
> 2. **Zero-Config:** It should work immediately without a settings menu for now.
> 3. **Performance:** The wrapper must clean up (stop the web process) when the screensaver stops.
> 
> 
> We will start with macOS. Do not generate code yet, just acknowledge you understand the context."

---

### Phase 2: macOS Implementation (Swift)

*Claude Code works best with Swift files, but setting up the Xcode project file (`.xcodeproj`) via text generation is messy. Instead, ask it to generate the **Source Code** that you will paste into a template.*

**Step 1: The Class Structure**

> "Create a Swift file named `WebViewScreenSaver.swift`.
> * Import `ScreenSaver` and `WebKit`.
> * Create a class `WebViewScreenSaver` that inherits from `ScreenSaverView`.
> * In `init`, configure a `WKWebView`.
> * **Critical:** Set `configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")` to ensure local HTML works.
> * Load the `index.html` from the bundle using `Bundle(for: type(of: self))`.
> * Implement `hitTest` to return `nil` so mouse events pass through (optional, but good for some setups).
> * Provide the full code."
> 
> 

**Step 2: The Logic Fixes (Common AI Errors)**
*AI often forgets to stop the web process, causing memory leaks.*

> "Update the `WebViewScreenSaver.swift` file.
> * Add `startAnimation()`: Ensure the webview is visible and running.
> * Add `stopAnimation()`: Pause the WebView or load `about:blank` to free up GPU resources.
> * Add `deinit`: Explicitly remove the WebView from the superview."
> 
> 

---

### Phase 3: Windows Implementation (C#)

*Windows is easier for AI because `.csproj` files are readable text (XML), unlike Xcode project files.*

**Step 1: The Project File**

> "Generate a `.NET 6.0` (or later) `.csproj` file for a Windows Forms application.
> * The `<OutputType>` should be `WinExe`.
> * Include the `Microsoft.Web.WebView2` NuGet package reference.
> * Add a post-build event to copy the `web_content` folder to the output directory."
> 
> 

**Step 2: The Entry Point**

> "Create `Program.cs` for this screensaver.
> * It must parse command line arguments:
> * `/s`: Run the screensaver (Full Screen).
> * `/p`: Preview mode (Render inside the handle provided by the OS).
> * `/c`: Configure mode (Show a MessageBox saying 'No settings').
> 
> 
> * For `/s`, launch the main `ScreensaverForm`.
> * For `/p`, launch the form but attach it to the parent window handle (IntPtr) passed in the argument."
> 
> 

**Step 3: The Form Logic**

> "Create `ScreensaverForm.cs`.
> * Initialize a `WebView2` control that fills the screen.
> * **Critical:** Map the environment to a local user data folder (WebView2 needs write access to a folder, usually `%TEMP%` for screensavers).
> * Navigate to `Path.Combine(AppDomain.CurrentDomain.BaseDirectory, 'web_content', 'index.html')`.
> * Add an event listener: On `MouseMove` or `KeyDown`, call `Application.Exit()`."
> 
> 

---

### Phase 4: The Build & Packaging Scripts

*Since you aren't a programmer, ask Claude to write the scripts that "glue" the project together.*

**For macOS (The Build Script)**

> "Write a shell script (`build_mac.sh`) that:
> 1. Compiles the Swift file into a `.saver` bundle using `swiftc` or `xcodebuild`.
> 2. Creates the correct directory structure (`MySaver.saver/Contents/MacOS`).
> 3. Copies the `Info.plist` (generate a basic one for me first) and the `web_content` folder into `Resources`.
> 4. **Note:** Assume I don't have a full Xcode project file, so use command-line compilation instructions."
> 
> 

**For Windows (The Installer Script)**

> "Generate an Inno Setup script (`setup.iss`) for this project.
> 1. It should compile the C# project (assume I have run `dotnet publish`).
> 2. It needs to package the `.exe` (renamed to `.scr`), the `WebView2Loader.dll`, and the `web_content` folder.
> 3. The `[Files]` section must put these in `{app}`.
> 4. The `[Run]` section isn't needed, but ensure it sets the destination directory to local app data or system folder."
> 
> 

---

### Phase 5: Verification (How to check Claude's work)

Since you are "blindly" trusting the code generation, use these prompts to verify:

1. **The "Sanity Check" Prompt:**
> "Review the `WebViewScreenSaver.swift` code you just wrote. Does it handle the case where the `index.html` file is missing? Add a simple error log or red background if the file is not found so I can debug it."


2. **The "Safety" Prompt:**
> "Check the Windows `Program.cs`. Does it correctly parse handles for the `/p` (Preview) mode? If the handle is passed as a command line string, ensure it is converted to an `IntPtr` correctly, or the preview will crash."



### Next Step for You

Start with **Phase 1** (Context Loading) in your Claude Code terminal. Once it acknowledges, move to **Phase 2, Step 1**.

