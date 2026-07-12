using Avalonia;
using ClassIsland.Mobile.Avalonia.Services;
using DesktopApp = ClassIsland.App;
using AppHost = ClassIsland.Shared.IAppHost;
using DesktopPortableView = ClassIsland.Views.PortableAppView;

namespace ClassIsland.Mobile.Avalonia.Desktop;

internal static class Program
{
    [STAThread]
    public static void Main(string[] args)
    {
        try
        {
            ConfigurePortableCapabilities();
            DesktopApp.PortableMainViewFactory =
                () => AppHost.GetService<DesktopPortableView>();
            DesktopApp.PortableUriLauncher = uri =>
            {
                System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                {
                    FileName = uri.AbsoluteUri,
                    UseShellExecute = true
                });
                return Task.FromResult(true);
            };
            DesktopApp.ForcePortableDesktopHost = true;
            BuildAvaloniaApp().StartWithClassicDesktopLifetime(args);
        }
        catch (Exception exception)
        {
            Console.Error.WriteLine(exception);
            throw;
        }
    }

    public static AppBuilder BuildAvaloniaApp() =>
        AppBuilder.Configure<DesktopApp>()
            .UsePlatformDetect()
            .WithInterFont()
#if DEBUG
            .WithDeveloperTools()
#endif
            .LogToTrace();

    private static void ConfigurePortableCapabilities()
    {
        var capabilities = AppServices.Platform.Capabilities;
        DesktopApp.ConfigurePortableCapabilities(
            capabilities.SupportsFileImport,
            capabilities.SupportsFileExport,
            capabilities.SupportsSystemNotifications,
            capabilities.SupportsLiveActivities,
            capabilities.SupportsDynamicIsland,
            capabilities.SupportsMultipleWindows,
            capabilities.SupportsOpeningFolders,
            capabilities.SupportsShortcuts,
            capabilities.SupportsWindowManagement,
            capabilities.SupportsApplicationRestart,
            capabilities.SupportsRecoveryMode,
            capabilities.SupportsDynamicPlugins,
            capabilities.SupportsDataTransfer,
            capabilities.SupportsAppLogs,
            capabilities.SupportsManagementEnrollment);
    }
}
