using System;
using System.Windows.Input;
using Avalonia;
using Avalonia.VisualTree;
using ClassIsland.Models.EventArgs;
using Linearstar.Windows.RawInput;

namespace ClassIsland.Abstractions;

/// <summary>
/// 主界面组件所需的宿主能力，由桌面窗口和 portable 容器共同实现。
/// </summary>
public interface IMainWindowHost
{
    event EventHandler<MousePosChangedEventArgs>? MousePosChanged;
    event EventHandler<RawInputEventArgs>? RawInputEvent;
    event EventHandler<MainWindowAnimationEventArgs>? MainWindowAnimationEvent;

    ICommand ShowComponentSettingsCommand { get; }
    ICommand OpenMainWindowLineSettingsCommand { get; }
    ICommand RemoveMainWindowLineCommand { get; }
    ICommand CloseContainerComponentCommand { get; }

    void GetCurrentDpi(out double dpiX, out double dpiY, Visual? visual = null);
    void AcquireTopmostLock(object owner);
    void ReleaseTopmostLock(object owner);
}
