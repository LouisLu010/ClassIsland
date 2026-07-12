using System;
using Avalonia.Controls;
using ClassIsland.Core.Controls;

namespace ClassIsland.Views;

/// <summary>
/// 桌面端档案编辑窗口外壳。完整界面由 <see cref="ProfileSettingsView"/> 提供。
/// </summary>
public partial class ProfileSettingsWindow : MyWindow
{
    private readonly ProfileSettingsView _profileSettingsView;
    private bool _isOpen;

    public ProfileSettingsWindow(ProfileSettingsView profileSettingsView)
    {
        _profileSettingsView = profileSettingsView;
        InitializeComponent();
        Content = profileSettingsView;
    }

    public async void Open(Uri? uri = null)
    {
        if (App.IsPortableModeRequested &&
            await App.NavigatePortableAsync("profile", uri))
        {
            return;
        }

        if (!await _profileSettingsView.OpenAsync(uri))
        {
            return;
        }

        if (!_isOpen)
        {
            _isOpen = true;
            Show();
            return;
        }

        if (WindowState == WindowState.Minimized)
        {
            WindowState = WindowState.Normal;
        }

        Activate();
    }

    public void OpenDrawer(string key) => _profileSettingsView.OpenDrawer(key);

    private void Window_OnClosing(object? sender, WindowClosingEventArgs e)
    {
        if (e.CloseReason is WindowCloseReason.ApplicationShutdown or WindowCloseReason.OSShutdown)
        {
            return;
        }

        e.Cancel = true;
        _isOpen = false;
        _profileSettingsView.CloseView();
        Hide();
    }
}
