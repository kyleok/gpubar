using System.Drawing;
using System.Runtime.InteropServices;
using Forms = System.Windows.Forms;

namespace GPUBar.Windows;

public sealed class TrayManager : IDisposable
{
    private readonly Forms.NotifyIcon _notifyIcon;
    private readonly Action _openAction;
    private readonly Action _refreshAction;
    private readonly Action _exitAction;

    public TrayManager(Action openAction, Action refreshAction, Action exitAction)
    {
        _openAction = openAction;
        _refreshAction = refreshAction;
        _exitAction = exitAction;

        _notifyIcon = new Forms.NotifyIcon
        {
            Visible = true,
            Text = "GPUBar",
            Icon = TrayIconFactory.Create(0, false),
            ContextMenuStrip = BuildMenu(),
        };
        _notifyIcon.DoubleClick += (_, _) => _openAction();
    }

    public void UpdateStatus(int freeGpus, int totalGpus, string? statusText, bool hasError)
    {
        var tooltip = string.IsNullOrWhiteSpace(statusText)
            ? $"GPUBar: {freeGpus} free / {totalGpus} total"
            : $"GPUBar: {statusText}";
        if (tooltip.Length > 63)
        {
            tooltip = tooltip[..63];
        }

        _notifyIcon.Text = tooltip;
        var oldIcon = _notifyIcon.Icon;
        _notifyIcon.Icon = TrayIconFactory.Create(freeGpus, hasError);
        oldIcon?.Dispose();
    }

    public void ShowNotification(string title, string body)
    {
        _notifyIcon.BalloonTipTitle = title;
        _notifyIcon.BalloonTipText = body;
        _notifyIcon.ShowBalloonTip(5000);
    }

    private Forms.ContextMenuStrip BuildMenu()
    {
        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add("Open", null, (_, _) => _openAction());
        menu.Items.Add("Refresh", null, (_, _) => _refreshAction());
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add("Quit", null, (_, _) => _exitAction());
        return menu;
    }

    public void Dispose()
    {
        _notifyIcon.Visible = false;
        _notifyIcon.Dispose();
    }
}

internal static class TrayIconFactory
{
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    private static extern bool DestroyIcon(IntPtr handle);

    public static Icon Create(int freeGpus, bool hasError)
    {
        using var bitmap = new Bitmap(32, 32);
        using var graphics = Graphics.FromImage(bitmap);
        graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        graphics.Clear(Color.Transparent);

        using var background = new SolidBrush(hasError ? Color.Firebrick : freeGpus > 0 ? Color.ForestGreen : Color.DimGray);
        graphics.FillEllipse(background, 1, 1, 30, 30);

        var text = freeGpus > 99 ? "99+" : freeGpus.ToString();
        using var font = new Font("Segoe UI", text.Length >= 3 ? 10f : 14f, FontStyle.Bold, GraphicsUnit.Pixel);
        var format = new StringFormat
        {
            Alignment = StringAlignment.Center,
            LineAlignment = StringAlignment.Center,
        };
        using var textBrush = new SolidBrush(Color.White);
        graphics.DrawString(text, font, textBrush, new RectangleF(0, 0, 32, 32), format);

        var handle = bitmap.GetHicon();
        try
        {
            using var icon = Icon.FromHandle(handle);
            return (Icon)icon.Clone();
        }
        finally
        {
            DestroyIcon(handle);
        }
    }
}
