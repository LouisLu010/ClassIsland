using System;
using System.IO;
using System.Threading.Tasks;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Threading;
using ClassIsland.Core;
using ClassIsland.Core.Enums;
using ClassIsland.Core.Models.Platform;
using ClassIsland.Core.Services.Registry;
using ClassIsland.Core.Abstractions.Services;
using ClassIsland.Services;
using ClassIsland.Services.Automation.Triggers;
using ClassIsland.Shared;
using Microsoft.Extensions.Hosting;

namespace ClassIsland;

public partial class App
{
    public static PlatformCapabilities CurrentPlatformCapabilities { get; set; } =
        PlatformCapabilities.Desktop;

    public static void ConfigurePortableCapabilities(
        bool supportsFileImport,
        bool supportsFileExport,
        bool supportsSystemNotifications,
        bool supportsLiveActivities,
        bool supportsDynamicIsland,
        bool supportsMultipleWindows,
        bool supportsOpeningFolders,
        bool supportsShortcuts,
        bool supportsWindowManagement,
        bool supportsApplicationRestart,
        bool supportsRecoveryMode,
        bool supportsDynamicPlugins,
        bool supportsDataTransfer,
        bool supportsAppLogs,
        bool supportsManagementEnrollment)
    {
        CurrentPlatformCapabilities = new PlatformCapabilities
        {
            SupportsFileImport = supportsFileImport,
            SupportsFileExport = supportsFileExport,
            SupportsSystemNotifications = supportsSystemNotifications,
            SupportsLiveActivities = supportsLiveActivities,
            SupportsDynamicIsland = supportsDynamicIsland,
            SupportsMultipleWindows = supportsMultipleWindows,
            SupportsOpeningFolders = supportsOpeningFolders,
            SupportsShortcuts = supportsShortcuts,
            SupportsWindowManagement = supportsWindowManagement,
            SupportsApplicationRestart = supportsApplicationRestart,
            SupportsRecoveryMode = supportsRecoveryMode,
            SupportsDynamicPlugins = supportsDynamicPlugins,
            SupportsDataTransfer = supportsDataTransfer,
            SupportsAppLogs = supportsAppLogs,
            SupportsManagementEnrollment = supportsManagementEnrollment
        };
    }

    public static Func<string, Uri?, Task<bool>>? PortableNavigationHandler { get; set; }

    internal static Task<bool> NavigatePortableAsync(string route, Uri? uri = null) =>
        PortableNavigationHandler?.Invoke(route, uri) ?? Task.FromResult(false);

    /// <summary>
    /// 由移动宿主提供的系统链接启动器。
    /// </summary>
    public static Func<Uri, Task<bool>>? PortableUriLauncher { get; set; }

    internal static Task<bool> LaunchPortableUriAsync(Uri uri) =>
        PortableUriLauncher?.Invoke(uri) ?? Task.FromResult(false);

    /// <summary>
    /// 由 iOS 宿主提供的单视图根控件工厂。
    /// </summary>
    public static Func<Control>? PortableMainViewFactory { get; set; }

    /// <summary>
    /// 在桌面生命周期中预览单视图宿主。
    /// </summary>
    public static bool ForcePortableDesktopHost { get; set; }

    internal static bool IsPortableModeRequested =>
        PortableMainViewFactory is not null &&
        (ForcePortableDesktopHost || System.OperatingSystem.IsIOS());

    private void InitializePortableDirectories()
    {
        Program.InitializeSharedRuntime();
        Environment.CurrentDirectory = AppContext.BaseDirectory;
        PackagingType = System.OperatingSystem.IsIOS() ? "ios-app" : "desktop-preview";
        OperatingSystem = System.OperatingSystem.IsIOS() ? "ios" : "desktop-preview";
        var basePath = System.OperatingSystem.IsIOS()
            ? Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments)
            : Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "ClassIsland",
                "MobilePreview");
        Directory.CreateDirectory(basePath);
        CommonDirectories.AppRootFolderPath = basePath;
        CommonDirectories.OverrideAppDataFolderPath = basePath;
        CommonDirectories.AppPackageRoot = AppContext.BaseDirectory;
        ExecutingEntrance = Environment.ProcessPath ?? string.Empty;
    }

    private bool TryInitializePortableLifetime()
    {
        if (PortableMainViewFactory is null)
        {
            return false;
        }

        var isSingleView = ApplicationLifetime is ISingleViewApplicationLifetime;
        var isDesktopPreview =
            ForcePortableDesktopHost &&
            ApplicationLifetime is IClassicDesktopStyleApplicationLifetime;
        if (!isSingleView && !isDesktopPreview)
        {
            return false;
        }

        Dispatcher.UIThread.UnhandledException -= App_OnDispatcherUnhandledException;
        Dispatcher.UIThread.UnhandledException += App_OnDispatcherUnhandledException;
        TaskScheduler.UnobservedTaskException -= TaskSchedulerOnUnobservedTaskException;
        TaskScheduler.UnobservedTaskException += TaskSchedulerOnUnobservedTaskException;

        InitializePortableHost();
        var mainView = PortableMainViewFactory();

        if (ApplicationLifetime is ISingleViewApplicationLifetime singleView)
        {
            singleView.MainView = mainView;
        }
        else if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            MainWindow = new Window
            {
                Title = "ClassIsland 移动端预览",
                Width = 1240,
                Height = 700,
                MinWidth = 560,
                MinHeight = 520,
                Background = this.FindResource("SolidBackgroundFillColorBaseBrush") as Avalonia.Media.IBrush,
                Content = mainView
            };
            desktop.MainWindow = MainWindow;
        }

        AppBase.CurrentLifetime = ClassIsland.Core.Enums.ApplicationLifetime.Running;
        AppStarted?.Invoke(this, EventArgs.Empty);
        return true;
    }

    private void InitializePortableHost()
    {
        FileFolderService.CreateFolders();
        SettingsWindowRegistryService.Registered.Clear();
        SettingsWindowRegistryService.Groups.Clear();

        IAppHost.Host = Host.CreateDefaultBuilder()
            .UseContentRoot(AppContext.BaseDirectory)
            .ConfigureServices(ConfigureServices)
            .Build();

        var settingsService = GetService<SettingsService>();
        settingsService.LoadSettingsAsync().GetAwaiter().GetResult();
        Settings = settingsService.Settings;

        IThemeService.IsTransientDisabled = Settings.AnimationLevel < 1;
        IThemeService.IsWaitForTransientDisabled = Settings.IsWaitForTransientDisabled;
        IThemeService.AnimationLevel = Settings.AnimationLevel;

        GetService<IProfileService>().LoadProfileAsync().GetAwaiter().GetResult();
        GetService<IExactTimeService>();
        GetService<IWeatherService>();
        GetService<IComponentsService>().LoadManagementConfig().GetAwaiter().GetResult();

        IAppHost.Host.StartAsync().GetAwaiter().GetResult();
        GetService<IAutomationService>();
        GetService<IRulesetService>().NotifyStatusChanged();
        GetService<SignalTriggerHandlerService>();

        var uriNavigationService = GetService<IUriNavigationService>();
        uriNavigationService.HandleAppNavigation(
            "settings",
            args => _ = NavigatePortableAsync("settings", args.Uri));
        uriNavigationService.HandleAppNavigation(
            "profile",
            args => _ = NavigatePortableAsync("profile", args.Uri));
    }
}
