Here is the `Info.plist` content you need. This file acts as the ID card for your screensaver; without it, macOS won't know your code exists or how to load it.

### 1. The `Info.plist` Content

Save this as a file named `Info.plist` in your project root.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>MyWebSaver</string>
    
    <key>CFBundleIdentifier</key>
    <string>com.yourname.mywebsaver</string>
    
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    
    <key>LSMinimumSystemVersion</key>
    <string>10.13</string>
    
    <key>NSPrincipalClass</key>
    <string>MyWebSaver.WebViewScreenSaver</string>
</dict>
</plist>

```

### 2. The "Gotcha" to Watch Out For

The most common error when generating this via AI is a mismatch in the **`NSPrincipalClass`** key.

* **The Problem:** Swift puts your classes inside a "Module."
* **The Fix:** In the XML above, I used `MyWebSaver.WebViewScreenSaver`.
* `MyWebSaver` = The name of the binary/module (set during compilation).
* `WebViewScreenSaver` = The name of the class in your Swift file.



### 3. The Claude Code Prompt to Build It

Now, run this prompt in Claude Code. It tells the AI exactly how to compile the Swift code so that it matches the Plist I just gave you.

> "I have the `Info.plist` ready. Now, write a terminal command to compile the `WebViewScreenSaver.swift` file into a macOS bundle.
> **Constraints:**
> 1. Use `swiftc` directly (no Xcode project).
> 2. **Critical:** You must use the flag `-module-name MyWebSaver` so it matches my Plist's principal class.
> 3. The output must be a bundle structure: `MyWebSaver.saver/Contents/MacOS/MyWebSaver`.
> 4. Ensure you copy `Info.plist` to `MyWebSaver.saver/Contents/` and the `web_content` folder to `MyWebSaver.saver/Contents/Resources/`.
> 
> 
> Generate the full shell script commands to do this."

**Next Step:** Run the prompt above. Once it generates the script, you can execute it in your terminal to create your first testable `.saver` file.