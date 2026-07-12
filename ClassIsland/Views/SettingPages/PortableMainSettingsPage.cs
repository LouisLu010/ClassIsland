using System;
using System.Windows.Input;
using Avalonia;
using Avalonia.Controls;
using Avalonia.VisualTree;
using ClassIsland.Abstractions;
using ClassIsland.Core.Abstractions.Controls;
using ClassIsland.Core.Attributes;
using ClassIsland.Core.Enums.SettingsWindow;
using ClassIsland.Models.EventArgs;
using Linearstar.Windows.RawInput;

namespace ClassIsland.Views.SettingPages;

[SettingsPageInfo(PageId, "主界面", "\uec85", "\uec85", SettingsPageCategory.Internal)]
[Group("classisland.mobile")]
[FullWidthPage]
[HidePageTitle]
public sealed class PortableMainSettingsPage : SettingsPageBase
{
    public const string PageId = "mobile-main";

    public PortableMainSettingsPage(MainWindow mainWindow)
    {
        Content = PortableWindowEmbedding.Embed(
            mainWindow,
            new MainWindowContentHost(mainWindow));
    }

    private sealed class MainWindowContentHost(MainWindow mainWindow) :
        ContentControl,
        IMainWindowHost
    {
        protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
        {
            base.OnAttachedToVisualTree(e);
            mainWindow.InitializePortableHost(this);
            mainWindow.UpdatePortableHostBounds(Bounds.Size);
        }

        protected override void OnSizeChanged(SizeChangedEventArgs e)
        {
            base.OnSizeChanged(e);
            mainWindow.UpdatePortableHostBounds(e.NewSize);
        }

        public event EventHandler<MousePosChangedEventArgs>? MousePosChanged
        {
            add => mainWindow.MousePosChanged += value;
            remove => mainWindow.MousePosChanged -= value;
        }

        public event EventHandler<RawInputEventArgs>? RawInputEvent
        {
            add => mainWindow.RawInputEvent += value;
            remove => mainWindow.RawInputEvent -= value;
        }

        public event EventHandler<MainWindowAnimationEventArgs>? MainWindowAnimationEvent
        {
            add => mainWindow.MainWindowAnimationEvent += value;
            remove => mainWindow.MainWindowAnimationEvent -= value;
        }

        public ICommand ShowComponentSettingsCommand => mainWindow.ShowComponentSettingsCommand;
        public ICommand OpenMainWindowLineSettingsCommand => mainWindow.OpenMainWindowLineSettingsCommand;
        public ICommand RemoveMainWindowLineCommand => mainWindow.RemoveMainWindowLineCommand;
        public ICommand CloseContainerComponentCommand => mainWindow.CloseContainerComponentCommand;

        public void GetCurrentDpi(out double dpiX, out double dpiY, Visual? visual = null) =>
            mainWindow.GetCurrentDpi(out dpiX, out dpiY, visual ?? this);

        public void AcquireTopmostLock(object owner) => mainWindow.AcquireTopmostLock(owner);

        public void ReleaseTopmostLock(object owner) => mainWindow.ReleaseTopmostLock(owner);
    }
}
