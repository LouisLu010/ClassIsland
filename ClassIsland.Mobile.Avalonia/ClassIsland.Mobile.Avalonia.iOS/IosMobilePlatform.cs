using ClassIsland.Mobile.Avalonia.Services;
using Foundation;
using UIKit;
using UniformTypeIdentifiers;
using UserNotifications;

namespace ClassIsland.Mobile.Avalonia.iOS;

internal sealed class IosMobilePlatform : IMobilePlatform
{
    private UIDocumentPickerViewController? _activePicker;
    private DocumentPickerDelegate? _activePickerDelegate;

    public MobilePlatformCapabilities Capabilities { get; } = new()
    {
        SupportsFileImport = true,
        SupportsFileExport = true,
        SupportsSystemNotifications = true,
        SupportsDataTransfer = true,
        SupportsAppLogs = true
    };

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
        string stateJson,
        CancellationToken cancellationToken = default) =>
        Task.FromResult(
            PlatformOperationResult.Failure("ActivityKit 原生桥尚未嵌入 Avalonia 宿主。"));

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
