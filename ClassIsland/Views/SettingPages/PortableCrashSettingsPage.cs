using System;
using Avalonia.Controls;
using Avalonia.Threading;
using ClassIsland.Core.Abstractions.Controls;
using ClassIsland.Core.Attributes;
using ClassIsland.Core.Enums.SettingsWindow;
using ClassIsland.Services;

namespace ClassIsland.Views.SettingPages;

[SettingsPageInfo(PageId, "崩溃报告", "\ue783", "\ue783", SettingsPageCategory.Internal)]
[Group("classisland.mobile")]
[FullWidthPage]
[HidePageTitle]
public sealed class PortableCrashSettingsPage : SettingsPageBase
{
    public const string PageId = "mobile-crash-report";

    private readonly CrashWindow _crashWindow;
    private readonly CrashReportService _crashReportService;

    public PortableCrashSettingsPage(CrashReportService crashReportService)
    {
        _crashReportService = crashReportService;
        _crashWindow = new CrashWindow
        {
            IsEmbedded = true
        };
        _crashWindow.DismissRequested += CrashWindowOnDismissRequested;
        _crashReportService.ReportChanged += CrashReportServiceOnReportChanged;
        ApplyReport(_crashReportService.CurrentReport);
        Content = PortableWindowEmbedding.Embed(_crashWindow, new ContentControl());
    }

    private void CrashReportServiceOnReportChanged(CrashReport? report)
    {
        if (Dispatcher.UIThread.CheckAccess())
        {
            ApplyReport(report);
            return;
        }

        Dispatcher.UIThread.Post(() => ApplyReport(report));
    }

    private async void CrashWindowOnDismissRequested(object? sender, EventArgs e)
    {
        _crashReportService.Dismiss();
        await App.NavigatePortableAsync(
            "settings",
            new Uri("classisland://app/settings/general"));
    }

    private void ApplyReport(CrashReport? report)
    {
        _crashWindow.CrashInfo = report?.CrashInfo ?? "当前没有待处理的崩溃报告。";
        _crashWindow.IsCritical = report?.IsCritical ?? false;
        _crashWindow.AllowIgnore = report?.AllowIgnore ?? true;
    }
}
