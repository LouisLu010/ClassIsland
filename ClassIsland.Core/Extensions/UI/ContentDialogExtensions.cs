using System;
using System.Linq;
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using FluentAvalonia.UI.Controls;

namespace ClassIsland.Core.Extensions.UI;

/// <summary>
/// 为桌面和单视图生命周期选择合适的对话框宿主。
/// </summary>
public static class ContentDialogExtensions
{
    /// <summary>
    /// 使用指定或当前活动的 <see cref="TopLevel"/> 显示对话框。
    /// </summary>
    public static Task<ContentDialogResult> ShowAsyncAuto(
        this ContentDialog dialog,
        TopLevel? topLevel = null)
    {
        ArgumentNullException.ThrowIfNull(dialog);
        return dialog.ShowAsync(topLevel ?? ResolveTopLevel());
    }

    private static TopLevel ResolveTopLevel()
    {
        return Application.Current?.ApplicationLifetime switch
        {
            IClassicDesktopStyleApplicationLifetime desktop =>
                desktop.Windows.FirstOrDefault(window => window.IsActive) ??
                desktop.MainWindow ??
                desktop.Windows.FirstOrDefault() ??
                throw new InvalidOperationException("找不到可用于显示 ContentDialog 的桌面窗口。"),
            ISingleViewApplicationLifetime singleView when singleView.MainView is not null =>
                TopLevel.GetTopLevel(singleView.MainView) ??
                throw new InvalidOperationException("移动端主视图尚未连接到 TopLevel。"),
            _ => throw new InvalidOperationException(
                "当前应用生命周期没有可用于显示 ContentDialog 的 TopLevel。")
        };
    }
}
