using System;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using Microsoft.Web.WebView2.WinForms;

namespace BioElectric;

public partial class ScreensaverForm : Form
{
    private readonly bool _isPreview;
    private Point _lastMouse = Point.Empty;
    private bool _haveMouse;

    public ScreensaverForm(IntPtr previewParent = default)
    {
        _isPreview = previewParent != IntPtr.Zero;

        if (_isPreview)
        {
            // Render inside the small preview pane the OS owns.
            SetWindowLong(Handle, GWL_STYLE, WS_CHILD | WS_VISIBLE);
            SetParent(Handle, previewParent);
            GetClientRect(previewParent, out var r);
            Bounds = new Rectangle(0, 0, r.Right, r.Bottom);
            FormBorderStyle = FormBorderStyle.None;
        }
        else
        {
            FormBorderStyle = FormBorderStyle.None;
            WindowState = FormWindowState.Maximized;
            TopMost = true;
            Cursor.Hide();
        }

        BackColor = Color.Black;
        SetupWebView();
    }

    private async void SetupWebView()
    {
        var webView = new WebView2 { Dock = DockStyle.Fill, DefaultBackgroundColor = Color.Black };
        Controls.Add(webView);

        // WebView2 needs a writable user-data folder; screensavers can't assume one, so use TEMP.
        var userData = Path.Combine(Path.GetTempPath(), "BioElectricSaver");
        var env = await Microsoft.Web.WebView2.Core.CoreWebView2Environment.CreateAsync(null, userData);
        await webView.EnsureCoreWebView2Async(env);

        var index = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "web_content", "index.html");
        if (File.Exists(index))
            webView.CoreWebView2.Navigate(new Uri(index).AbsoluteUri);
        else
            webView.CoreWebView2.NavigateToString(
                "<body style='background:#400;color:#fff;font:14px sans-serif;padding:2em'>" +
                "web_content/index.html not found</body>");

        // Forward input from the web view to our exit handlers (full-screen mode only).
        if (!_isPreview)
        {
            webView.PreviewKeyDown += (_, _) => Application.Exit();
            webView.CoreWebView2.ContainsFullScreenElementChanged += (_, _) => { };
        }
    }

    // --- exit on real user activity (full screen only) ---

    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);
        if (_isPreview) return;
        // Ignore the spurious move Windows fires at launch; only exit on actual movement.
        if (!_haveMouse) { _lastMouse = e.Location; _haveMouse = true; return; }
        if (Math.Abs(e.X - _lastMouse.X) > 8 || Math.Abs(e.Y - _lastMouse.Y) > 8)
            Application.Exit();
    }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        base.OnMouseDown(e);
        if (!_isPreview) Application.Exit();
    }

    protected override void OnKeyDown(KeyEventArgs e)
    {
        base.OnKeyDown(e);
        if (!_isPreview) Application.Exit();
    }

    // --- Win32 interop for preview reparenting ---

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT { public int Left, Top, Right, Bottom; }

    [DllImport("user32.dll")] private static extern IntPtr SetParent(IntPtr child, IntPtr parent);
    [DllImport("user32.dll")] private static extern int SetWindowLong(IntPtr hWnd, int index, int value);
    [DllImport("user32.dll")] private static extern bool GetClientRect(IntPtr hWnd, out RECT rect);

    private const int GWL_STYLE = -16;
    private const int WS_CHILD = 0x40000000;
    private const int WS_VISIBLE = 0x10000000;
}
