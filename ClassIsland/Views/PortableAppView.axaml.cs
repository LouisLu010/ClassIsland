using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Animation;
using Avalonia.Animation.Easings;
using Avalonia.Controls;
using Avalonia.Controls.Platform;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Media;
using Avalonia.Styling;
using Avalonia.VisualTree;
using ClassIsland.Core.Assists;
using ClassIsland.Views.SettingPages;
using ClassIsland.Services;
using Microsoft.Extensions.Logging;

namespace ClassIsland.Views;

/// <summary>
/// 单视图平台根宿主。移动端直接以桌面端原应用设置界面作为主界面。
/// </summary>
public partial class PortableAppView : UserControl
{
    private const double InputPaneClearance = 12;

    private readonly SettingsView _settingsView;
    private readonly ILogger<PortableAppView> _logger;
    private readonly CrashReportService _crashReportService;
    private IInputPane? _inputPane;
    private TimeSpan _inputPaneAnimationDuration;
    private IEasing? _inputPaneAnimationEasing;
    private CancellationTokenSource? _inputPaneAnimationCancellation;
    private int _navigationProgressVersion;
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
        Unloaded += OnUnloaded;
        App.PortableNavigationHandler = NavigateAsync;
    }

    private async void OnLoaded(object? sender, RoutedEventArgs e)
    {
        AttachInputPane();
        RemoveHandler(GotFocusEvent, OnDescendantGotFocus);
        AddHandler(GotFocusEvent, OnDescendantGotFocus, RoutingStrategies.Bubble, true);
        RemoveHandler(PointerPressedEvent, OnDescendantPointerPressed);
        AddHandler(
            PointerPressedEvent,
            OnDescendantPointerPressed,
            RoutingStrategies.Tunnel | RoutingStrategies.Bubble,
            true);
        SizeChanged -= OnHostSizeChanged;
        SizeChanged += OnHostSizeChanged;

        if (_initialized)
        {
            return;
        }

        _initialized = true;
        await RunNavigationWithProgressAsync(async () =>
        {
            await _settingsView.EnsureInitializedAsync();
            if (_crashReportService.CurrentReport is not null)
            {
                await _settingsView.NavigateAsync(PortableCrashSettingsPage.PageId);
            }
        });
    }

    private void OnUnloaded(object? sender, RoutedEventArgs e)
    {
        DetachInputPane();
        RemoveHandler(GotFocusEvent, OnDescendantGotFocus);
        RemoveHandler(PointerPressedEvent, OnDescendantPointerPressed);
        SizeChanged -= OnHostSizeChanged;
        ResetPageContentOffset();
    }

    public async Task<bool> NavigateAsync(string route, Uri? uri)
    {
        try
        {
            var navigated = true;
            await RunNavigationWithProgressAsync(async () =>
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
                        navigated = false;
                        break;
                }
            });

            return navigated;
        }
        catch (Exception exception)
        {
            _logger.LogError(exception, "无法打开 portable 页面 {Route}", route);
            return false;
        }
    }

    private async Task RunNavigationWithProgressAsync(Func<Task> navigation)
    {
        var version = ++_navigationProgressVersion;
        NavigationProgressBar.IsVisible = true;
        try
        {
            await navigation();
        }
        finally
        {
            if (version == _navigationProgressVersion)
            {
                NavigationProgressBar.IsVisible = false;
            }
        }
    }

    private void AttachInputPane()
    {
        DetachInputPane();
        _inputPane = TopLevel.GetTopLevel(this)?.InputPane;
        if (_inputPane is not null)
        {
            _inputPane.StateChanged += OnInputPaneStateChanged;
        }
    }

    private void DetachInputPane()
    {
        if (_inputPane is not null)
        {
            _inputPane.StateChanged -= OnInputPaneStateChanged;
            _inputPane = null;
        }

        CancelInputPaneAnimation();
    }

    private void OnInputPaneStateChanged(object? sender, InputPaneStateEventArgs e)
    {
        if (!ReferenceEquals(sender, _inputPane))
        {
            return;
        }

        if (e.NewState == InputPaneState.Open)
        {
            _inputPaneAnimationDuration = e.AnimationDuration;
            _inputPaneAnimationEasing = e.Easing;
        }

        var targetOffset = e.NewState == InputPaneState.Open
            ? CalculatePageContentOffset(e.EndRect)
            : 0;
        _ = AnimatePageContentOffsetAsync(targetOffset, e.AnimationDuration, e.Easing);
    }

    private void OnDescendantGotFocus(object? sender, GotFocusEventArgs e) =>
        UpdatePageContentOffsetForOpenInputPane();

    private void OnDescendantPointerPressed(object? sender, PointerPressedEventArgs e) =>
        PointerStateAssist.SetIsTouchMode(this, e.Pointer.Type == PointerType.Touch);

    private void OnHostSizeChanged(object? sender, SizeChangedEventArgs e) =>
        UpdatePageContentOffsetForOpenInputPane();

    private void UpdatePageContentOffsetForOpenInputPane()
    {
        if (_inputPane is not { State: InputPaneState.Open } || _inputPaneAnimationEasing is null)
        {
            return;
        }

        var targetOffset = CalculatePageContentOffset(_inputPane.OccludedRect);
        _ = AnimatePageContentOffsetAsync(
            targetOffset,
            _inputPaneAnimationDuration,
            _inputPaneAnimationEasing);
    }

    private double CalculatePageContentOffset(Rect occludedRect)
    {
        if (occludedRect.Width <= 0 || occludedRect.Height <= 0)
        {
            return 0;
        }

        var topLevel = TopLevel.GetTopLevel(this);
        if (topLevel?.FocusManager?.GetFocusedElement() is not Visual focusedElement ||
            !PageContentRoot.IsVisualAncestorOf(focusedElement))
        {
            return 0;
        }

        var focusedTextBox = focusedElement as TextBox ??
                             focusedElement.GetVisualAncestors().OfType<TextBox>().FirstOrDefault();
        var avoidanceElement = focusedTextBox ?? focusedElement;
        var focusedTopInContent = avoidanceElement.TranslatePoint(default, PageContentRoot);
        var focusedBottomInContent = avoidanceElement.TranslatePoint(
            new Point(0, avoidanceElement.Bounds.Height),
            PageContentRoot);
        var contentTopInTopLevel = PageContentRoot.TranslatePoint(default, topLevel);
        if (focusedTopInContent is null || focusedBottomInContent is null || contentTopInTopLevel is null)
        {
            return 0;
        }

        var currentOffset = PageContentRoot.RenderTransform is TranslateTransform transform
            ? transform.Y
            : 0;
        var unshiftedContentTop = contentTopInTopLevel.Value.Y - currentOffset;
        var unshiftedFocusedTop = unshiftedContentTop + focusedTopInContent.Value.Y;
        var unshiftedFocusedBottom = unshiftedContentTop + focusedBottomInContent.Value.Y;
        var targetOffset = Math.Min(
            0,
            occludedRect.Top - InputPaneClearance - unshiftedFocusedBottom);
        var topVisibilityLimit = Math.Min(0, InputPaneClearance - unshiftedFocusedTop);
        return Math.Max(targetOffset, topVisibilityLimit);
    }

    private async Task AnimatePageContentOffsetAsync(
        double targetOffset,
        TimeSpan duration,
        IEasing easing)
    {
        if (PageContentRoot.RenderTransform is not TranslateTransform transform)
        {
            return;
        }

        var startOffset = transform.Y;
        CancelInputPaneAnimation();
        if (duration <= TimeSpan.Zero || Math.Abs(startOffset - targetOffset) < 0.01)
        {
            transform.Y = targetOffset;
            return;
        }

        var cancellation = new CancellationTokenSource();
        _inputPaneAnimationCancellation = cancellation;
        var animation = new Animation
        {
            Duration = duration,
            Easing = new InputPaneAnimationEasing(easing),
            FillMode = FillMode.Forward,
            Children =
            {
                new KeyFrame
                {
                    Cue = new Cue(0),
                    Setters =
                    {
                        new Setter(TranslateTransform.YProperty, startOffset)
                    }
                },
                new KeyFrame
                {
                    Cue = new Cue(1),
                    Setters =
                    {
                        new Setter(TranslateTransform.YProperty, targetOffset)
                    }
                }
            }
        };

        try
        {
            await animation.RunAsync(transform, cancellation.Token);
        }
        catch (OperationCanceledException)
        {
            return;
        }
        finally
        {
            if (ReferenceEquals(_inputPaneAnimationCancellation, cancellation))
            {
                _inputPaneAnimationCancellation = null;
                if (!cancellation.IsCancellationRequested)
                {
                    transform.Y = targetOffset;
                }
            }

            cancellation.Dispose();
        }
    }

    private void CancelInputPaneAnimation()
    {
        _inputPaneAnimationCancellation?.Cancel();
        _inputPaneAnimationCancellation = null;
    }

    private void ResetPageContentOffset()
    {
        CancelInputPaneAnimation();
        if (PageContentRoot.RenderTransform is TranslateTransform transform)
        {
            transform.Y = 0;
        }
    }

    private sealed class InputPaneAnimationEasing(IEasing easing) : Easing
    {
        public override double Ease(double progress) => easing.Ease(progress);
    }
}
