using Avalonia;
using Avalonia.iOS;
using ClassIsland.Mobile.Avalonia.Services;
using Foundation;
using UIKit;
using DesktopApp = ClassIsland.App;
using AppHost = ClassIsland.Shared.IAppHost;
using DesktopPortableView = ClassIsland.Views.PortableAppView;

namespace ClassIsland.Mobile.Avalonia.iOS;

[Register("AppDelegate")]
#pragma warning disable CA1711
public partial class AppDelegate : AvaloniaAppDelegate<DesktopApp>
#pragma warning restore CA1711
{
    private AvaloniaLiveActivityCoordinator? _liveActivityCoordinator;

    protected override AppBuilder CustomizeAppBuilder(AppBuilder builder)
    {
        AppServices.Platform = new IosMobilePlatform();
        ConfigurePortableCapabilities();
        DesktopApp.PortableUriLauncher = uri =>
            UIApplication.SharedApplication.OpenUrlAsync(
                new NSUrl(uri.AbsoluteUri),
                new UIApplicationOpenUrlOptions());
        DesktopApp.PortableMainViewFactory = () =>
        {
            if (AppServices.Platform.Capabilities.SupportsLiveActivities)
            {
                _liveActivityCoordinator ??= new AvaloniaLiveActivityCoordinator();
                _liveActivityCoordinator.Start();
            }

            return AppHost.GetService<DesktopPortableView>();
        };
        return base.CustomizeAppBuilder(builder)
            .WithInterFont();
    }

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
