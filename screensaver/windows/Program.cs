using System;
using System.Windows.Forms;

namespace BioElectric;

// Screensaver entry point. Windows invokes the .scr with:
//   /s            run full screen
//   /p <hwnd>     render a preview inside the given parent window handle
//   /c            show configuration (we have none)
// no args         treated as /s
static class Program
{
    [STAThread]
    static void Main(string[] args)
    {
        ApplicationConfiguration.Initialize();

        var mode = args.Length > 0 ? args[0].TrimStart('/', '-').ToLowerInvariant() : "s";
        // first char only: "/p", "/p:1234", "/c" all collapse to p / c / s
        var flag = mode.Length > 0 ? mode[0] : 's';

        switch (flag)
        {
            case 'c':
                MessageBox.Show("BioElectric screensaver has no settings.", "BioElectric",
                    MessageBoxButtons.OK, MessageBoxIcon.Information);
                break;

            case 'p':
                var handle = ParsePreviewHandle(args);
                if (handle != IntPtr.Zero)
                    Application.Run(new ScreensaverForm(previewParent: handle));
                break;

            case 's':
            default:
                Application.Run(new ScreensaverForm());
                break;
        }
    }

    // Handle can arrive as "/p 1234" (next arg) or "/p:1234" (same arg).
    private static IntPtr ParsePreviewHandle(string[] args)
    {
        string? raw = null;
        if (args.Length > 1) raw = args[1];
        else
        {
            var colon = args[0].IndexOf(':');
            if (colon >= 0) raw = args[0][(colon + 1)..];
        }
        return long.TryParse(raw, out var h) ? new IntPtr(h) : IntPtr.Zero;
    }
}
