using Microsoft.Win32;

namespace GPUBar.Windows;

internal static class RegistryHelper
{
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ProtocolKeyPath = @"Software\Classes\gpubar";

    public static void ConfigureLaunchAtLogin(bool enabled, string executablePath)
    {
        using var key = Registry.CurrentUser.CreateSubKey(RunKeyPath);
        if (key is null)
        {
            return;
        }

        if (enabled)
        {
            key.SetValue("GPUBar", Quote(executablePath));
        }
        else
        {
            key.DeleteValue("GPUBar", false);
        }
    }

    public static void RegisterProtocolHandler(string executablePath)
    {
        using var key = Registry.CurrentUser.CreateSubKey(ProtocolKeyPath);
        if (key is null)
        {
            return;
        }

        key.SetValue(string.Empty, "URL:GPUBar Protocol");
        key.SetValue("URL Protocol", string.Empty);

        using var defaultIcon = key.CreateSubKey("DefaultIcon");
        defaultIcon?.SetValue(string.Empty, $"{Quote(executablePath)},0");

        using var commandKey = key.CreateSubKey(@"shell\open\command");
        commandKey?.SetValue(string.Empty, $"{Quote(executablePath)} \"%1\"");
    }

    private static string Quote(string value)
    {
        return value.StartsWith('"') ? value : $"\"{value}\"";
    }
}
