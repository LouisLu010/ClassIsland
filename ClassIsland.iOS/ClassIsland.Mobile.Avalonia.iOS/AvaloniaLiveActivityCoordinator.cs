using System.ComponentModel;
using Avalonia.Threading;
using ClassIsland.Core.Abstractions.Services;
using ClassIsland.Mobile.Avalonia.Services;
using ClassIsland.Services;
using ClassIsland.Shared;
using Foundation;
using UIKit;

namespace ClassIsland.Mobile.Avalonia.iOS;

internal sealed class AvaloniaLiveActivityCoordinator : IDisposable
{
    private readonly ILessonsService _lessonsService;
    private readonly IProfileService _profileService;
    private readonly IWeatherService _weatherService;
    private readonly SettingsService _settingsService;
    private readonly ClassIslandLiveActivityStateFactory _stateFactory;
    private readonly NSObject _activeObserver;
    private int _synchronizationQueued;
    private bool _disposed;

    public AvaloniaLiveActivityCoordinator()
    {
        _lessonsService = IAppHost.GetService<ILessonsService>();
        _profileService = IAppHost.GetService<IProfileService>();
        _weatherService = IAppHost.GetService<IWeatherService>();
        _settingsService = IAppHost.GetService<SettingsService>();
        _stateFactory = new ClassIslandLiveActivityStateFactory(
            _lessonsService,
            _profileService,
            IAppHost.GetService<IExactTimeService>(),
            _weatherService,
            _settingsService);

        _lessonsService.CurrentTimeStateChanged += OnStateChanged;
        _weatherService.PropertyChanged += OnPropertyChanged;
        _settingsService.Settings.PropertyChanged += OnPropertyChanged;
        if (_profileService is INotifyPropertyChanged profileNotifications)
        {
            profileNotifications.PropertyChanged += OnPropertyChanged;
        }

        _activeObserver = NSNotificationCenter.DefaultCenter.AddObserver(
            UIApplication.DidBecomeActiveNotification,
            _ => QueueSynchronization());
    }

    public void Start() => QueueSynchronization();

    private void OnStateChanged(object? sender, EventArgs eventArgs) =>
        QueueSynchronization();

    private void OnPropertyChanged(object? sender, PropertyChangedEventArgs eventArgs) =>
        QueueSynchronization();

    private void QueueSynchronization()
    {
        if (_disposed || Interlocked.Exchange(ref _synchronizationQueued, 1) != 0)
        {
            return;
        }

        Dispatcher.UIThread.Post(async () =>
        {
            try
            {
                await Task.Delay(150);
                await SynchronizeAsync();
            }
            catch (Exception exception)
            {
                System.Diagnostics.Debug.WriteLine(
                    $"实时活动同步失败：{exception.Message}");
            }
            finally
            {
                Interlocked.Exchange(ref _synchronizationQueued, 0);
            }
        });
    }

    private async Task SynchronizeAsync()
    {
        var state = _stateFactory.Create();
        var result = state is null
            ? await LiveActivityClient.EndAsync()
            : await LiveActivityClient.UpdateAsync(state);
        if (!result.Succeeded)
        {
            System.Diagnostics.Debug.WriteLine(result.Message);
        }
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        _lessonsService.CurrentTimeStateChanged -= OnStateChanged;
        _weatherService.PropertyChanged -= OnPropertyChanged;
        _settingsService.Settings.PropertyChanged -= OnPropertyChanged;
        if (_profileService is INotifyPropertyChanged profileNotifications)
        {
            profileNotifications.PropertyChanged -= OnPropertyChanged;
        }
        _activeObserver.Dispose();
    }
}
