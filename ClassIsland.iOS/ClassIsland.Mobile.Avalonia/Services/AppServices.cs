namespace ClassIsland.Mobile.Avalonia.Services;

public static class AppServices
{
    private static IMobilePlatform _platform = new UnsupportedMobilePlatform();

    public static IMobilePlatform Platform
    {
        get => _platform;
        set => _platform = value ?? throw new ArgumentNullException(nameof(value));
    }
}
