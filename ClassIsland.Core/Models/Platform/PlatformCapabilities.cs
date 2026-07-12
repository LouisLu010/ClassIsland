namespace ClassIsland.Core.Models.Platform;

/// <summary>
/// 描述当前宿主可提供的系统能力，供共享界面决定功能是否可用。
/// </summary>
public sealed record PlatformCapabilities
{
    public bool SupportsFileImport { get; init; }
    public bool SupportsFileExport { get; init; }
    public bool SupportsSystemNotifications { get; init; }
    public bool SupportsLiveActivities { get; init; }
    public bool SupportsDynamicIsland { get; init; }
    public bool SupportsMultipleWindows { get; init; }
    public bool SupportsOpeningFolders { get; init; }
    public bool SupportsShortcuts { get; init; }
    public bool SupportsWindowManagement { get; init; }
    public bool SupportsApplicationRestart { get; init; }
    public bool SupportsRecoveryMode { get; init; }
    public bool SupportsDynamicPlugins { get; init; }
    public bool SupportsDataTransfer { get; init; }
    public bool SupportsAppLogs { get; init; }
    public bool SupportsManagementEnrollment { get; init; }

    public static PlatformCapabilities Desktop { get; } = new()
    {
        SupportsFileImport = true,
        SupportsFileExport = true,
        SupportsSystemNotifications = true,
        SupportsMultipleWindows = true,
        SupportsOpeningFolders = true,
        SupportsShortcuts = true,
        SupportsWindowManagement = true,
        SupportsApplicationRestart = true,
        SupportsRecoveryMode = true,
        SupportsDynamicPlugins = true,
        SupportsDataTransfer = true,
        SupportsAppLogs = true,
        SupportsManagementEnrollment = true
    };

    public static PlatformCapabilities PortableFallback { get; } = new();
}
