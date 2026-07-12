using System;
using System.Threading.Tasks;
using Avalonia.Controls;
using Avalonia.Interactivity;
using ClassIsland.Views.SettingPages;
using ClassIsland.Services;
using Microsoft.Extensions.Logging;

namespace ClassIsland.Views;

/// <summary>
/// 单视图平台根宿主。移动端直接以桌面端原应用设置界面作为主界面。
/// </summary>
public partial class PortableAppView : UserControl
{
    private readonly SettingsView _settingsView;
    private readonly ILogger<PortableAppView> _logger;
    private readonly CrashReportService _crashReportService;
    private bool _initialized;

    public PortableAppView(
        SettingsView settingsView,
        ILogger<PortableAppView> logger,
        CrashReportService crashReportService)
    {
        _settingsView = settingsView;
        _logger = logger;
        _crashReportService = crashReportService;
        InitializeComponent();
        ViewHost.Content = settingsView;
        Loaded += OnLoaded;
        App.PortableNavigationHandler = NavigateAsync;
    }

    private async void OnLoaded(object? sender, RoutedEventArgs e)
    {
        if (_initialized)
        {
            return;
        }

        _initialized = true;
        await _settingsView.EnsureInitializedAsync();
        if (_crashReportService.CurrentReport is not null)
        {
            await _settingsView.NavigateAsync(PortableCrashSettingsPage.PageId);
        }
    }

    public async Task<bool> NavigateAsync(string route, Uri? uri)
    {
        try
        {
            switch (route)
            {
                case "settings":
                    if (uri is null)
                    {
                        await _settingsView.EnsureInitializedAsync();
                    }
                    else
                    {
                        await _settingsView.NavigateUriAsync(uri);
                    }
                    break;
                case "main":
                    await _settingsView.NavigateAsync(PortableMainSettingsPage.PageId, uri);
                    break;
                case "profile":
                    await _settingsView.NavigateAsync(PortableProfileSettingsPage.PageId, uri);
                    break;
                case "data-transfer":
                    await _settingsView.NavigateAsync(PortableDataTransferSettingsPage.PageId, uri);
                    break;
                case "logs":
                    await _settingsView.NavigateAsync(PortableLogsSettingsPage.PageId, uri);
                    break;
                case "crash":
                    await _settingsView.NavigateAsync(PortableCrashSettingsPage.PageId, uri);
                    break;
                default:
                    return false;
            }

            return true;
        }
        catch (Exception exception)
        {
            _logger.LogError(exception, "无法打开 portable 页面 {Route}", route);
            return false;
        }
    }
}
