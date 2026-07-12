using Avalonia.Controls;
using ClassIsland.Core.Abstractions.Controls;
using ClassIsland.Core.Attributes;
using ClassIsland.Core.Enums.SettingsWindow;

namespace ClassIsland.Views.SettingPages;

[SettingsPageInfo(PageId, "日志", "\ue510", "\ue510", SettingsPageCategory.Internal)]
[Group("classisland.mobile")]
[FullWidthPage]
public sealed class PortableLogsSettingsPage : SettingsPageBase
{
    public const string PageId = "mobile-logs";

    public PortableLogsSettingsPage(AppLogsWindow appLogsWindow)
    {
        Content = PortableWindowEmbedding.Embed(appLogsWindow, new ContentControl());
    }
}
