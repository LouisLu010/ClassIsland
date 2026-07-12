using System;
using System.Diagnostics;
using System.Web;
using System.Windows;
using Avalonia;
using Avalonia.Interactivity;
using ClassIsland.Core;
using ClassIsland.Core.Controls;
using ClassIsland.Services;

namespace ClassIsland.Views;

/// <summary>
/// CrashWindow.xaml 的交互逻辑
/// </summary>
public partial class CrashWindow : MyWindow
{
    public static readonly StyledProperty<string> CrashInfoProperty = AvaloniaProperty.Register<CrashWindow, string>(
        nameof(CrashInfo));

    public string CrashInfo
    {
        get => GetValue(CrashInfoProperty);
        set => SetValue(CrashInfoProperty, value);
    }

    public static readonly StyledProperty<bool> IsCriticalProperty = AvaloniaProperty.Register<CrashWindow, bool>(
        nameof(IsCritical));

    public bool IsCritical
    {
        get => GetValue(IsCriticalProperty);
        set => SetValue(IsCriticalProperty, value);
    }

    public static readonly StyledProperty<bool> AllowIgnoreProperty = AvaloniaProperty.Register<CrashWindow, bool>(
        nameof(AllowIgnore), true);

    public bool AllowIgnore
    {
        get => GetValue(AllowIgnoreProperty);
        set => SetValue(AllowIgnoreProperty, value);
    }

    public bool IsEmbedded { get; set; }

    public bool CanRestart =>
        !App.IsPortableModeRequested || App.CurrentPlatformCapabilities.SupportsApplicationRestart;

    public bool CanDebug => !OperatingSystem.IsIOS();

    public event EventHandler? DismissRequested;

    public CrashWindow()
    {
        InitializeComponent();
        DataContext = this;
    }

    private void ButtonIgnore_OnClick(object sender, RoutedEventArgs e)
    {
        if (IsEmbedded)
        {
            DismissRequested?.Invoke(this, EventArgs.Empty);
            return;
        }

        Close();
    }

    private void ButtonExit_OnClick(object sender, RoutedEventArgs e)
    {
        if (IsCritical)
        {
            Environment.Exit(1);
        }
        else
        {
            AppBase.Current.Stop();
        }
    }

    private void ButtonRestart_OnClick(object sender, RoutedEventArgs e)
    {
        if (!CanRestart)
        {
            return;
        }

        AppBase.Current.Restart();
    }

    private void ButtonCopy_OnClick(object sender, RoutedEventArgs e)
    {
        TextBoxCrashInfo.Focus();
        TextBoxCrashInfo.SelectAll();
        TextBoxCrashInfo.Copy();
    }

    private async void ButtonFeedback_OnClick(object sender, RoutedEventArgs e)
    {
        var uri = new UriBuilder(
            $"https://github.com/ClassIsland/ClassIsland/issues/new");
        uri.Query = 
            $"template=BugReport.yml&stacktrace={HttpUtility.UrlEncode(CrashInfo)}&app_version={HttpUtility.UrlEncode(App.AppVersionLong)}&os_version={HttpUtility.UrlEncode(Environment.OSVersion.Version.ToString())}";

        if (App.IsPortableModeRequested)
        {
            try
            {
                await App.LaunchPortableUriAsync(uri.Uri);
            }
            catch
            {
                // 崩溃报告界面不能因为系统浏览器不可用而再次崩溃。
            }

            return;
        }

        Process.Start(new ProcessStartInfo()
        {
            FileName = uri.ToString(),
            UseShellExecute = true
        });
    }

    private void ButtonDebug_OnClick(object sender, RoutedEventArgs e)
    {
        if (Debugger.Launch())
        {
            Close();
        }
    }
}
