using Avalonia.Interactivity;
using ClassIsland.Core.Abstractions.Controls;
using ClassIsland.Core.Attributes;
using ClassIsland.Core.Enums.SettingsWindow;

namespace ClassIsland.Views.SettingPages;

[SettingsPageInfo(PageId, "档案", "\ue699", "\ue699", SettingsPageCategory.Internal)]
[Group("classisland.mobile")]
[FullWidthPage]
[HidePageTitle]
public sealed class PortableProfileSettingsPage : SettingsPageBase
{
    public const string PageId = "mobile-profile";

    private readonly ProfileSettingsView _profileSettingsView;

    public PortableProfileSettingsPage(ProfileSettingsView profileSettingsView)
    {
        _profileSettingsView = profileSettingsView;
        Content = profileSettingsView;
        Loaded += OnLoaded;
        Unloaded += OnUnloaded;
    }

    private async void OnLoaded(object? sender, RoutedEventArgs e)
    {
        await _profileSettingsView.OpenAsync(NavigationUri);
    }

    private void OnUnloaded(object? sender, RoutedEventArgs e)
    {
        _profileSettingsView.CloseView();
    }
}
