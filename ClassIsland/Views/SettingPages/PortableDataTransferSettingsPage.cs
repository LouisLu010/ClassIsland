using ClassIsland.Core.Abstractions.Controls;
using ClassIsland.Core.Attributes;
using ClassIsland.Core.Enums.SettingsWindow;

namespace ClassIsland.Views.SettingPages;

[SettingsPageInfo(PageId, "数据迁移", "\ue083", "\ue083", SettingsPageCategory.Internal)]
[Group("classisland.mobile")]
[FullWidthPage]
[HidePageTitle]
public sealed class PortableDataTransferSettingsPage : SettingsPageBase
{
    public const string PageId = "mobile-data-transfer";

    public PortableDataTransferSettingsPage()
    {
        Content = new DataTransferPage();
    }
}
