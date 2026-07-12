using Avalonia;
using Avalonia.iOS;
using ClassIsland.Mobile.Avalonia.Services;
using ClassIsland.Services;
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

    [Export("application:didFinishLaunchingWithOptions:")]
    public new bool FinishedLaunching(UIApplication application, NSDictionary launchOptions)
    {
        try
        {
            return base.FinishedLaunching(application, launchOptions);
        }
        catch (Exception exception)
        {
            PersistStartupException(exception);
            ShowStartupFailure(exception);
            return true;
        }
    }

    private static void PersistStartupException(Exception exception)
    {
        CrashReportService.PersistEmergency(exception);

        try
        {
            var documentsPath = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
            var reportsPath = Path.Combine(documentsPath, "Logs", "CrashReports");
            Directory.CreateDirectory(reportsPath);
            var reportPath = Path.Combine(
                reportsPath,
                $"Startup-{DateTimeOffset.UtcNow:yyyyMMdd-HHmmss-fff}.log");
            var report = $"""
                         ClassIsland iOS startup failure
                         Time: {DateTimeOffset.Now:yyyy-MM-dd HH:mm:ss zzz}
                         System: {UIDevice.CurrentDevice.SystemName} {UIDevice.CurrentDevice.SystemVersion}
                         ================================

                         {exception}
                         """;
            File.WriteAllText(reportPath, report);
        }
        catch
        {
            // The native fallback below still exposes the exception when storage is unavailable.
        }
    }

    private void ShowStartupFailure(Exception exception)
    {
        try
        {
            var rootView = new UIView(UIScreen.MainScreen.Bounds)
            {
                BackgroundColor = UIColor.SystemBackground
            };
            var textView = new UITextView(rootView.Bounds)
            {
                AutoresizingMask = UIViewAutoresizing.FlexibleWidth | UIViewAutoresizing.FlexibleHeight,
                BackgroundColor = UIColor.SystemBackground,
                TextColor = UIColor.Label,
                Font = UIFont.SystemFontOfSize(15),
                Editable = false,
                Selectable = true,
                AlwaysBounceVertical = true,
                TextContainerInset = new UIEdgeInsets(32, 24, 32, 24),
                Text = $"""
                       ClassIsland 启动失败

                       完整日志已保存到“文件”App 中的 ClassIsland/Logs/CrashReports。

                       {exception}
                       """
            };
            rootView.AddSubview(textView);

            var viewController = new UIViewController
            {
                View = rootView
            };
            var window = new UIWindow(UIScreen.MainScreen.Bounds)
            {
                RootViewController = viewController
            };
            Window = window;
            window.MakeKeyAndVisible();
        }
        catch
        {
            // There is no safer UI surface if UIKit itself cannot create the fallback view.
        }
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
