using System.Text.Json;
using System.Text.Json.Serialization;

namespace ClassIsland.Mobile.Avalonia.Services;

public enum LiveActivityPhase
{
    NoSchedule,
    Upcoming,
    InClass,
    BreakTime,
    AfterSchool
}

public enum LiveActivityRegion
{
    LockHeader,
    LockPrimary,
    LockProgress,
    LockFooter,
    ExpandedLeading,
    ExpandedCenter,
    ExpandedTrailing,
    ExpandedBottom,
    CompactLeading,
    CompactTrailing,
    Minimal,
    NotificationTitle,
    NotificationBody
}

public enum LiveActivityComponentKind
{
    Status,
    CurrentLesson,
    Countdown,
    Progress,
    NextLesson,
    ProfileName,
    Weather,
    Clock,
    Date,
    Plugin,
    CustomText
}

public enum LiveActivityWeatherMetric
{
    Condition,
    Humidity,
    Wind,
    AirQuality,
    Pressure,
    FeelsLike
}

public sealed record LiveActivityComponent
{
    public required LiveActivityComponentKind Kind { get; init; }

    public string CustomText { get; init; } = string.Empty;

    public bool IsEmphasized { get; init; }

    public bool ShowsIcon { get; init; } = true;

    public LiveActivityWeatherMetric WeatherMetric { get; init; } =
        LiveActivityWeatherMetric.Condition;

    public bool ClockShowsSeconds { get; init; }

    public bool ClockUsesSystemTime { get; init; }
}

public sealed record LiveActivityLayout
{
    public required IReadOnlyDictionary<LiveActivityRegion, IReadOnlyList<LiveActivityComponent>> Regions
    {
        get;
        init;
    }
}

public sealed record LiveActivityWeather
{
    public string WeatherCode { get; init; } = string.Empty;

    public string Temperature { get; init; } = string.Empty;

    public string Humidity { get; init; } = string.Empty;

    public string WindSpeed { get; init; } = string.Empty;

    public string AirQualityIndex { get; init; } = string.Empty;

    public string Pressure { get; init; } = string.Empty;

    public string FeelsLike { get; init; } = string.Empty;
}

public sealed record LiveActivityPluginPresentation
{
    public string Title { get; init; } = string.Empty;

    public string Value { get; init; } = string.Empty;

    public string SystemImage { get; init; } = "puzzlepiece.extension";
}

public sealed record LiveActivityTimelineEntry
{
    public required DateTimeOffset StartsAt { get; init; }

    public DateTimeOffset? EndsAt { get; init; }

    public required LiveActivityPhase Phase { get; init; }

    public string Headline { get; init; } = string.Empty;

    public string CompactTitle { get; init; } = string.Empty;

    public string Teacher { get; init; } = string.Empty;

    public DateTimeOffset? TimerStart { get; init; }

    public DateTimeOffset? TimerEnd { get; init; }

    public string NextTitle { get; init; } = string.Empty;

    public DateTimeOffset? NextStart { get; init; }
}

public sealed record LiveActivityState
{
    public string ProfileName { get; init; } = "ClassIsland";

    public required LiveActivityPhase Phase { get; init; }

    public string Headline { get; init; } = string.Empty;

    public string CompactTitle { get; init; } = string.Empty;

    public string Teacher { get; init; } = string.Empty;

    public DateTimeOffset? TimerStart { get; init; }

    public DateTimeOffset? TimerEnd { get; init; }

    public string NextTitle { get; init; } = string.Empty;

    public DateTimeOffset? NextStart { get; init; }

    public DateTimeOffset UpdatedAt { get; init; } = DateTimeOffset.Now;

    public double TimeOffsetSeconds { get; init; }

    public uint AccentRgba { get; init; } = 0x05ABE8FF;

    public DateTimeOffset? StaleAt { get; init; }

    public LiveActivityLayout? Layout { get; init; }

    public LiveActivityWeather? Weather { get; init; }

    public LiveActivityPluginPresentation? Plugin { get; init; }

    public IReadOnlyList<LiveActivityTimelineEntry> Timeline { get; init; } = [];
}

public static class LiveActivityJson
{
    private static readonly JsonSerializerOptions SerializerOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        Converters =
        {
            new JsonStringEnumConverter(JsonNamingPolicy.CamelCase),
            new UnixSecondsDateTimeOffsetConverter()
        }
    };

    public static string Serialize(LiveActivityState state) =>
        JsonSerializer.Serialize(state, SerializerOptions);

    private sealed class UnixSecondsDateTimeOffsetConverter : JsonConverter<DateTimeOffset>
    {
        public override DateTimeOffset Read(
            ref Utf8JsonReader reader,
            Type typeToConvert,
            JsonSerializerOptions options) =>
            DateTimeOffset.FromUnixTimeMilliseconds(
                checked((long)Math.Round(reader.GetDouble() * 1000)));

        public override void Write(
            Utf8JsonWriter writer,
            DateTimeOffset value,
            JsonSerializerOptions options) =>
            writer.WriteNumberValue(value.ToUnixTimeMilliseconds() / 1000d);
    }
}
