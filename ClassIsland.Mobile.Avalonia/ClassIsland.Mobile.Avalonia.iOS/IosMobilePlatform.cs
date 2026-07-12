using ClassIsland.Mobile.Avalonia.Services;
using Foundation;
using System.Runtime.InteropServices;
using UIKit;
using UniformTypeIdentifiers;
using UserNotifications;

namespace ClassIsland.Mobile.Avalonia.iOS;

internal sealed partial class IosMobilePlatform : IMobilePlatform
{
    private const string NativeLibrary = "__Internal";

    private UIDocumentPickerViewController? _activePicker;
    private DocumentPickerDelegate? _activePickerDelegate;

    public MobilePlatformCapabilities Capabilities { get; } = CreateCapabilities();

    public Task<ImportedFile?> PickProfileAsync(CancellationToken cancellationToken = default)
    {
        var completion = new TaskCompletionSource<ImportedFile?>(
            TaskCreationOptions.RunContinuationsAsynchronously);

        UIApplication.SharedApplication.BeginInvokeOnMainThread(() =>
        {
            var presenter = FindTopViewController();
            if (presenter is null)
            {
                completion.TrySetException(
                    new InvalidOperationException("无法找到用于显示文件选择器的页面。"));
                return;
            }

            var picker = new UIDocumentPickerViewController(
                [UTTypes.Json, UTTypes.Data],
                asCopy: true);
            var pickerDelegate = new DocumentPickerDelegate(completion, ClearActivePicker);
            picker.Delegate = pickerDelegate;
            picker.AllowsMultipleSelection = false;
            _activePicker = picker;
            _activePickerDelegate = pickerDelegate;
            presenter.PresentViewController(picker, true, null);
        });

        if (cancellationToken.CanBeCanceled)
        {
            cancellationToken.Register(() => completion.TrySetCanceled(cancellationToken));
        }

        return completion.Task;
    }

    public Task<PlatformOperationResult> RequestNotificationPermissionAsync(
        CancellationToken cancellationToken = default)
    {
        var completion = new TaskCompletionSource<PlatformOperationResult>(
            TaskCreationOptions.RunContinuationsAsynchronously);
        UNUserNotificationCenter.Current.RequestAuthorization(
            UNAuthorizationOptions.Alert |
            UNAuthorizationOptions.Badge |
            UNAuthorizationOptions.Sound,
            (approved, error) =>
            {
                if (error is not null)
                {
                    completion.TrySetResult(
                        PlatformOperationResult.Failure($"通知权限请求失败：{error.LocalizedDescription}"));
                    return;
                }

                completion.TrySetResult(approved
                    ? PlatformOperationResult.Success("通知权限已授权")
                    : PlatformOperationResult.Failure("通知权限未授权，请在系统设置中开启"));
            });

        if (cancellationToken.CanBeCanceled)
        {
            cancellationToken.Register(() => completion.TrySetCanceled(cancellationToken));
        }

        return completion.Task;
    }

    public Task<PlatformOperationResult> UpdateLiveActivityAsync(
        LiveActivityState state,
        CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();

        try
        {
            var result = NativeUpdateLiveActivity(LiveActivityJson.Serialize(state));
            return Task.FromResult(CreateLiveActivityResult(result, "实时活动更新已提交"));
        }
        catch (Exception exception) when (IsNativeBridgeException(exception))
        {
            return Task.FromResult(
                PlatformOperationResult.Failure("ActivityKit 原生桥未随应用一起加载。"));
        }
    }

    public Task<PlatformOperationResult> EndLiveActivityAsync(
        CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();

        try
        {
            var result = NativeEndLiveActivity();
            return Task.FromResult(CreateLiveActivityResult(result, "实时活动结束请求已提交"));
        }
        catch (Exception exception) when (IsNativeBridgeException(exception))
        {
            return Task.FromResult(
                PlatformOperationResult.Failure("ActivityKit 原生桥未随应用一起加载。"));
        }
    }

    private static MobilePlatformCapabilities CreateCapabilities()
    {
        var supportsLiveActivities = false;
        var supportsDynamicIsland = false;

        if (OperatingSystem.IsIOSVersionAtLeast(16, 1))
        {
            try
            {
                supportsLiveActivities = NativeLiveActivityIsEnabled() == 1;
                supportsDynamicIsland = supportsLiveActivities && NativeDynamicIslandIsAvailable() == 1;
            }
            catch (Exception exception) when (IsNativeBridgeException(exception))
            {
                supportsLiveActivities = false;
                supportsDynamicIsland = false;
            }
        }

        return new MobilePlatformCapabilities
        {
            SupportsFileImport = true,
            SupportsFileExport = true,
            SupportsSystemNotifications = true,
            SupportsLiveActivities = supportsLiveActivities,
            SupportsDynamicIsland = supportsDynamicIsland,
            SupportsDataTransfer = true,
            SupportsAppLogs = true
        };
    }

    private static PlatformOperationResult CreateLiveActivityResult(int result, string successMessage) =>
        result switch
        {
            0 => PlatformOperationResult.Success(successMessage),
            1 => PlatformOperationResult.Failure("当前系统版本不支持实时活动。"),
            2 => PlatformOperationResult.Failure("系统已关闭实时活动权限。"),
            3 => PlatformOperationResult.Failure("实时活动数据无效。"),
            _ => PlatformOperationResult.Failure("ActivityKit 未能处理实时活动请求。")
        };

    private static bool IsNativeBridgeException(Exception exception) =>
        exception is DllNotFoundException or EntryPointNotFoundException or TypeInitializationException;

    [LibraryImport(NativeLibrary, EntryPoint = "ClassIslandLiveActivityIsEnabled")]
    private static partial int NativeLiveActivityIsEnabled();

    [LibraryImport(NativeLibrary, EntryPoint = "ClassIslandDynamicIslandIsAvailable")]
    private static partial int NativeDynamicIslandIsAvailable();

    [LibraryImport(
        NativeLibrary,
        EntryPoint = "ClassIslandLiveActivityUpdate",
        StringMarshalling = StringMarshalling.Utf8)]
    private static partial int NativeUpdateLiveActivity(string stateJson);

    [LibraryImport(NativeLibrary, EntryPoint = "ClassIslandLiveActivityEnd")]
    private static partial int NativeEndLiveActivity();

    private static UIViewController? FindTopViewController()
    {
        var root = UIApplication.SharedApplication.ConnectedScenes
            .OfType<UIWindowScene>()
            .SelectMany(scene => scene.Windows)
            .FirstOrDefault(window => window.IsKeyWindow)
            ?.RootViewController;

        while (root is not null)
        {
            if (root.PresentedViewController is { } presented)
            {
                root = presented;
                continue;
            }

            if (root is UINavigationController { VisibleViewController: { } visible })
            {
                root = visible;
                continue;
            }

            if (root is UITabBarController { SelectedViewController: { } selected })
            {
                root = selected;
                continue;
            }

            return root;
        }

        return null;
    }

    private void ClearActivePicker()
    {
        _activePicker = null;
        _activePickerDelegate = null;
    }

    private sealed class DocumentPickerDelegate(
        TaskCompletionSource<ImportedFile?> completion,
        Action completed) : UIDocumentPickerDelegate
    {
        public override async void DidPickDocument(
            UIDocumentPickerViewController controller,
            NSUrl[] urls)
        {
            try
            {
                var url = urls.FirstOrDefault();
                if (url?.Path is null)
                {
                    completion.TrySetResult(null);
                    return;
                }

                var hasSecurityAccess = url.StartAccessingSecurityScopedResource();
                try
                {
                    var content = await File.ReadAllBytesAsync(url.Path);
                    completion.TrySetResult(new ImportedFile(
                        url.LastPathComponent ?? "ImportedProfile.json",
                        content));
                }
                finally
                {
                    if (hasSecurityAccess)
                    {
                        url.StopAccessingSecurityScopedResource();
                    }
                }
            }
            catch (Exception exception)
            {
                completion.TrySetException(exception);
            }
            finally
            {
                completed();
            }
        }

        public override void WasCancelled(UIDocumentPickerViewController controller)
        {
            completion.TrySetResult(null);
            completed();
        }
    }
}
