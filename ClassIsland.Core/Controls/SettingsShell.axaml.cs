using Avalonia;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Labs.Input;
using Avalonia.Styling;
using FluentAvalonia.UI.Controls;
using FluentAvalonia.UI.Navigation;

namespace ClassIsland.Core.Controls;

/// <summary>
/// 桌面端与移动端共用的应用设置导航界面。
/// </summary>
public partial class SettingsShell : UserControl
{
    public static readonly StyledProperty<string> TitleProperty =
        AvaloniaProperty.Register<SettingsShell, string>(nameof(Title), "应用设置");

    public SettingsShell()
    {
        InitializeComponent();
    }

    public string Title
    {
        get => GetValue(TitleProperty);
        set => SetValue(TitleProperty, value);
    }

    public NavigationView NavigationViewControl => NavigationView;

    public Frame NavigationFrameControl => NavigationFrame;

    public Grid RootGridControl => RootGrid;

    public object ExperimentalSettingsContent => this.FindResource("ExperimentalSettings")!;

    public event EventHandler<NavigationViewItemInvokedEventArgs>? NavigationItemInvoked;
    public event EventHandler<NavigationViewBackRequestedEventArgs>? NavigationBackRequested;
    public event EventHandler<RoutedEventArgs>? NavigationLoaded;
    public event EventHandler<NavigationEventArgs>? FrameNavigated;
    public event EventHandler<NavigatingCancelEventArgs>? FrameNavigating;
    public event EventHandler<RoutedEventArgs>? BackClicked;
    public event EventHandler<RoutedEventArgs>? TogglePaneClicked;
    public event EventHandler<RoutedEventArgs>? RestartClicked;
    public event EventHandler<ExecutedRoutedEventArgs>? OpenDrawerCommandExecuted;
    public event EventHandler<ExecutedRoutedEventArgs>? CloseDrawerCommandExecuted;
    public event EventHandler<ExecutedRoutedEventArgs>? RestartCommandExecuted;
    public event EventHandler<RoutedEventArgs>? ExperimentalSettingsClicked;
    public event EventHandler<RoutedEventArgs>? DebugWindowRuleClicked;
    public event EventHandler<RoutedEventArgs>? AddDesktopShortcutClicked;
    public event EventHandler<RoutedEventArgs>? AddStartMenuShortcutClicked;
    public event EventHandler<RoutedEventArgs>? AddClassSwapShortcutClicked;
    public event EventHandler<RoutedEventArgs>? DataTransferClicked;
    public event EventHandler<RoutedEventArgs>? OpenManagementSettingsClicked;
    public event EventHandler<RoutedEventArgs>? JoinManagementClicked;
    public event EventHandler<RoutedEventArgs>? ExitManagementClicked;
    public event EventHandler<RoutedEventArgs>? AppLogsClicked;
    public event EventHandler<RoutedEventArgs>? ExportDiagnosticInfoClicked;
    public event EventHandler<RoutedEventArgs>? RestartToRecoveryClicked;
    public event EventHandler<RoutedEventArgs>? OpenLogFolderClicked;
    public event EventHandler<RoutedEventArgs>? OpenDataFolderClicked;
    public event EventHandler<RoutedEventArgs>? OpenAppFolderClicked;

    private void OnNavigationItemInvoked(
        object? sender,
        NavigationViewItemInvokedEventArgs e) =>
        NavigationItemInvoked?.Invoke(sender ?? this, e);

    private void OnNavigationBackRequested(
        object? sender,
        NavigationViewBackRequestedEventArgs e) =>
        NavigationBackRequested?.Invoke(sender ?? this, e);

    private void OnNavigationLoaded(object? sender, RoutedEventArgs e) =>
        NavigationLoaded?.Invoke(sender ?? this, e);

    private void OnFrameNavigated(object? sender, NavigationEventArgs e) =>
        FrameNavigated?.Invoke(sender ?? this, e);

    private void OnFrameNavigating(object? sender, NavigatingCancelEventArgs e) =>
        FrameNavigating?.Invoke(sender ?? this, e);

    private void OnBackClicked(object? sender, RoutedEventArgs e) =>
        BackClicked?.Invoke(sender ?? this, e);

    private void OnTogglePaneClicked(object? sender, RoutedEventArgs e) =>
        TogglePaneClicked?.Invoke(sender ?? this, e);

    private void OnRestartClicked(object? sender, RoutedEventArgs e) =>
        RestartClicked?.Invoke(sender ?? this, e);

    private void OnOpenDrawerCommandExecuted(object? sender, ExecutedRoutedEventArgs e) =>
        OpenDrawerCommandExecuted?.Invoke(sender ?? this, e);

    private void OnCloseDrawerCommandExecuted(object? sender, ExecutedRoutedEventArgs e) =>
        CloseDrawerCommandExecuted?.Invoke(sender ?? this, e);

    private void OnRestartCommandExecuted(object? sender, ExecutedRoutedEventArgs e) =>
        RestartCommandExecuted?.Invoke(sender ?? this, e);

    private void OnExperimentalSettingsClicked(object? sender, RoutedEventArgs e) =>
        ExperimentalSettingsClicked?.Invoke(sender ?? this, e);

    private void OnDebugWindowRuleClicked(object? sender, RoutedEventArgs e) =>
        DebugWindowRuleClicked?.Invoke(sender ?? this, e);

    private void OnAddDesktopShortcutClicked(object? sender, RoutedEventArgs e) =>
        AddDesktopShortcutClicked?.Invoke(sender ?? this, e);

    private void OnAddStartMenuShortcutClicked(object? sender, RoutedEventArgs e) =>
        AddStartMenuShortcutClicked?.Invoke(sender ?? this, e);

    private void OnAddClassSwapShortcutClicked(object? sender, RoutedEventArgs e) =>
        AddClassSwapShortcutClicked?.Invoke(sender ?? this, e);

    private void OnDataTransferClicked(object? sender, RoutedEventArgs e) =>
        DataTransferClicked?.Invoke(sender ?? this, e);

    private void OnOpenManagementSettingsClicked(object? sender, RoutedEventArgs e) =>
        OpenManagementSettingsClicked?.Invoke(sender ?? this, e);

    private void OnJoinManagementClicked(object? sender, RoutedEventArgs e) =>
        JoinManagementClicked?.Invoke(sender ?? this, e);

    private void OnExitManagementClicked(object? sender, RoutedEventArgs e) =>
        ExitManagementClicked?.Invoke(sender ?? this, e);

    private void OnAppLogsClicked(object? sender, RoutedEventArgs e) =>
        AppLogsClicked?.Invoke(sender ?? this, e);

    private void OnExportDiagnosticInfoClicked(object? sender, RoutedEventArgs e) =>
        ExportDiagnosticInfoClicked?.Invoke(sender ?? this, e);

    private void OnRestartToRecoveryClicked(object? sender, RoutedEventArgs e) =>
        RestartToRecoveryClicked?.Invoke(sender ?? this, e);

    private void OnOpenLogFolderClicked(object? sender, RoutedEventArgs e) =>
        OpenLogFolderClicked?.Invoke(sender ?? this, e);

    private void OnOpenDataFolderClicked(object? sender, RoutedEventArgs e) =>
        OpenDataFolderClicked?.Invoke(sender ?? this, e);

    private void OnOpenAppFolderClicked(object? sender, RoutedEventArgs e) =>
        OpenAppFolderClicked?.Invoke(sender ?? this, e);
}
