using System;
using Avalonia.Controls;
using ClassIsland.Core.Controls;
using FluentAvalonia.UI.Windowing;

namespace ClassIsland.Views;

/// <summary>
/// 桌面端设置窗口外壳。设置界面与交互逻辑由 <see cref="SettingsView"/> 提供。
/// </summary>
public partial class SettingsWindowNew : MyWindow
{
    private readonly SettingsView _settingsView;
    private bool _isOpened;

    public SettingsWindowNew(SettingsView settingsView)
    {
        _settingsView = settingsView;
        InitializeComponent();
        Content = settingsView;

        TitleBar.ExtendsContentIntoTitleBar = true;
        TitleBar.TitleBarHitTestType = TitleBarHitTestType.Complex;
        TitleBar.Height = 48;
        if (OperatingSystem.IsMacOS())
        {
            ExtendClientAreaToDecorationsHint = true;
            ExtendClientAreaChromeHints = Avalonia.Platform.ExtendClientAreaChromeHints.PreferSystemChrome;
            ExtendClientAreaTitleBarHeightHint = -1;
            SystemDecorations = SystemDecorations.Full;
        }
    }

    protected override async void OnOpened(EventArgs e)
    {
        base.OnOpened(e);
        await _settingsView.EnsureInitializedAsync();
    }

    public async void Open()
    {
        if (App.IsPortableModeRequested &&
            await App.NavigatePortableAsync("settings"))
        {
            return;
        }

        if (!_isOpened)
        {
            if (!await _settingsView.AuthorizeOpenAsync())
            {
                return;
            }

            _isOpened = true;
            Show();
            return;
        }

        if (WindowState == WindowState.Minimized)
        {
            WindowState = WindowState.Normal;
        }

        Activate();
    }

    public async void Open(string key, Uri? uri = null)
    {
        if (App.IsPortableModeRequested)
        {
            uri ??= new Uri($"classisland://app/settings/{key}");
            if (await App.NavigatePortableAsync("settings", uri))
            {
                return;
            }
        }

        await _settingsView.NavigateAsync(key, uri);
        Open();
    }

    public async void OpenUri(Uri uri)
    {
        if (App.IsPortableModeRequested &&
            await App.NavigatePortableAsync("settings", uri))
        {
            return;
        }

        await _settingsView.NavigateUriAsync(uri);
        Open();
    }

    private void SettingsWindowNew_OnClosing(object? sender, WindowClosingEventArgs e)
    {
        if (e.CloseReason is WindowCloseReason.ApplicationShutdown or WindowCloseReason.OSShutdown)
        {
            return;
        }

        e.Cancel = true;
        _isOpened = false;
        Hide();
        _settingsView.SaveOnClose();
    }
}
