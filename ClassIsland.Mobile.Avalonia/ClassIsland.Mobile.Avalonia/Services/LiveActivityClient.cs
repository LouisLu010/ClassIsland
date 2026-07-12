namespace ClassIsland.Mobile.Avalonia.Services;

public static class LiveActivityClient
{
    public static bool IsSupported =>
        AppServices.Platform.Capabilities.SupportsLiveActivities;

    public static bool IsDynamicIslandSupported =>
        AppServices.Platform.Capabilities.SupportsDynamicIsland;

    public static Task<PlatformOperationResult> UpdateAsync(
        LiveActivityState state,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(state);
        return AppServices.Platform.UpdateLiveActivityAsync(state, cancellationToken);
    }

    public static Task<PlatformOperationResult> EndAsync(
        CancellationToken cancellationToken = default) =>
        AppServices.Platform.EndLiveActivityAsync(cancellationToken);
}
