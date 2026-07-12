namespace ClassIsland.Mobile.Avalonia.Services;

public sealed record MobilePlatformCapabilities
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
}

public sealed record ImportedFile(string FileName, byte[] Content);

public sealed record PlatformOperationResult(bool Succeeded, string Message)
{
    public static PlatformOperationResult Success(string message) => new(true, message);

    public static PlatformOperationResult Failure(string message) => new(false, message);
}

public interface IMobilePlatform
{
    MobilePlatformCapabilities Capabilities { get; }

    Task<ImportedFile?> PickProfileAsync(CancellationToken cancellationToken = default);

    Task<PlatformOperationResult> RequestNotificationPermissionAsync(
        CancellationToken cancellationToken = default);

    Task<PlatformOperationResult> UpdateLiveActivityAsync(
        LiveActivityState state,
        CancellationToken cancellationToken = default);

    Task<PlatformOperationResult> EndLiveActivityAsync(
        CancellationToken cancellationToken = default);
}

internal sealed class UnsupportedMobilePlatform : IMobilePlatform
{
    public MobilePlatformCapabilities Capabilities { get; } = new();

    public Task<ImportedFile?> PickProfileAsync(CancellationToken cancellationToken = default) =>
        Task.FromResult<ImportedFile?>(null);

    public Task<PlatformOperationResult> RequestNotificationPermissionAsync(
        CancellationToken cancellationToken = default) =>
        Task.FromResult(PlatformOperationResult.Failure("当前平台不支持系统通知。"));

    public Task<PlatformOperationResult> UpdateLiveActivityAsync(
        LiveActivityState state,
        CancellationToken cancellationToken = default) =>
        Task.FromResult(PlatformOperationResult.Failure("当前平台尚未接入实时活动桥。"));

    public Task<PlatformOperationResult> EndLiveActivityAsync(
        CancellationToken cancellationToken = default) =>
        Task.FromResult(PlatformOperationResult.Failure("当前平台尚未接入实时活动桥。"));
}
