using ClassIsland.Core.Abstractions.Services;
using ClassIsland.Mobile.Avalonia.Services;
using ClassIsland.Services;
using ClassIsland.Shared.Enums;
using ClassIsland.Shared.Models.Profile;

namespace ClassIsland.Mobile.Avalonia.iOS;

internal sealed class ClassIslandLiveActivityStateFactory(
    ILessonsService lessonsService,
    IProfileService profileService,
    IExactTimeService exactTimeService,
    IWeatherService weatherService,
    SettingsService settingsService)
{
    private const int MaximumFutureTransitions = 32;

    public LiveActivityState? Create()
    {
        var exactNow = exactTimeService.GetCurrentLocalDateTime();
        var now = ToDateTimeOffset(exactNow);
        var classPlan = lessonsService.GetClassPlanByDate(exactNow) ?? lessonsService.CurrentClassPlan;
        if (classPlan is null)
        {
            return null;
        }

        var entries = BuildTimeline(classPlan, profileService.Profile, exactNow.Date);
        var current = entries.LastOrDefault(entry =>
            entry.StartsAt <= now &&
            (entry.EndsAt is null || now < entry.EndsAt));
        if (current is null || current.Phase is LiveActivityPhase.NoSchedule or LiveActivityPhase.AfterSchool)
        {
            return null;
        }

        var future = entries
            .Where(entry => entry.StartsAt > now)
            .Take(MaximumFutureTransitions)
            .ToList();
        var afterSchool = entries.LastOrDefault(entry =>
            entry.Phase == LiveActivityPhase.AfterSchool && entry.StartsAt > now);
        if (afterSchool is not null && future.All(entry => entry.StartsAt != afterSchool.StartsAt))
        {
            if (future.Count >= MaximumFutureTransitions)
            {
                future.RemoveAt(future.Count - 1);
            }
            future.Add(afterSchool);
            future.Sort((left, right) => left.StartsAt.CompareTo(right.StartsAt));
        }

        var localNow = DateTime.Now;
        return new LiveActivityState
        {
            ProfileName = Clip(profileService.Profile.Name, 48, "ClassIsland"),
            Phase = current.Phase,
            Headline = current.Headline,
            CompactTitle = current.CompactTitle,
            Teacher = current.Teacher,
            TimerStart = current.TimerStart,
            TimerEnd = current.TimerEnd,
            NextTitle = current.NextTitle,
            NextStart = current.NextStart,
            UpdatedAt = now,
            TimeOffsetSeconds = (exactNow - localNow).TotalSeconds,
            StaleAt = ToDateTimeOffset(exactNow.Date.AddDays(1).AddMinutes(5)),
            Weather = CreateWeatherPresentation(),
            Timeline = future
        };
    }

    private IReadOnlyList<LiveActivityTimelineEntry> BuildTimeline(
        ClassPlan classPlan,
        Profile profile,
        DateTime date)
    {
        var dayStart = ToDateTimeOffset(date);
        var nextDay = ToDateTimeOffset(date.AddDays(1));
        var allClassItems = classPlan.TimeLayout?.Layouts
            .Where(item => item.TimeType == 0)
            .ToList() ?? [];

        var scheduled = classPlan.ValidTimeLayoutItems
            .Where(item => item.TimeType is 0 or 1)
            .OrderBy(item => item.StartTime)
            .Select(item => CreateScheduledEntry(
                classPlan,
                profile,
                allClassItems,
                item,
                date))
            .ToList();

        if (scheduled.Count == 0)
        {
            return
            [
                new LiveActivityTimelineEntry
                {
                    StartsAt = dayStart,
                    EndsAt = nextDay,
                    Phase = LiveActivityPhase.NoSchedule,
                    Headline = "今日无课",
                    CompactTitle = "无"
                }
            ];
        }

        var result = new List<LiveActivityTimelineEntry>();
        var firstClass = scheduled.FirstOrDefault(entry => entry.Phase == LiveActivityPhase.InClass);
        if (firstClass is not null && firstClass.StartsAt > dayStart)
        {
            result.Add(new LiveActivityTimelineEntry
            {
                StartsAt = dayStart,
                EndsAt = firstClass.StartsAt,
                Phase = LiveActivityPhase.Upcoming,
                Headline = firstClass.Headline,
                CompactTitle = firstClass.CompactTitle,
                Teacher = firstClass.Teacher,
                TimerStart = dayStart,
                TimerEnd = firstClass.StartsAt
            });
        }

        for (var index = 0; index < scheduled.Count; index++)
        {
            var entry = scheduled[index];
            var nextClass = scheduled
                .Skip(index + 1)
                .FirstOrDefault(candidate => candidate.Phase == LiveActivityPhase.InClass);
            result.Add(entry with
            {
                NextTitle = nextClass?.Headline ?? string.Empty,
                NextStart = nextClass?.StartsAt
            });

            if (index + 1 >= scheduled.Count || entry.EndsAt is not { } end)
            {
                continue;
            }

            var next = scheduled[index + 1];
            if (next.StartsAt <= end)
            {
                continue;
            }

            var gapNextClass = scheduled
                .Skip(index + 1)
                .FirstOrDefault(candidate => candidate.Phase == LiveActivityPhase.InClass);
            result.Add(new LiveActivityTimelineEntry
            {
                StartsAt = end,
                EndsAt = next.StartsAt,
                Phase = LiveActivityPhase.BreakTime,
                Headline = "课间休息",
                CompactTitle = "休",
                TimerStart = end,
                TimerEnd = next.StartsAt,
                NextTitle = gapNextClass?.Headline ?? string.Empty,
                NextStart = gapNextClass?.StartsAt
            });
        }

        var finalEnd = scheduled
            .Select(entry => entry.EndsAt)
            .OfType<DateTimeOffset>()
            .Max();
        result.Add(new LiveActivityTimelineEntry
        {
            StartsAt = finalEnd,
            EndsAt = nextDay,
            Phase = LiveActivityPhase.AfterSchool,
            Headline = "今日课程结束",
            CompactTitle = "完"
        });

        return result.OrderBy(entry => entry.StartsAt).ToList();
    }

    private static LiveActivityTimelineEntry CreateScheduledEntry(
        ClassPlan classPlan,
        Profile profile,
        List<TimeLayoutItem> allClassItems,
        TimeLayoutItem item,
        DateTime date)
    {
        var start = ToDateTimeOffset(date.Add(item.StartTime));
        var end = ToDateTimeOffset(date.Add(item.EndTime));
        if (item.TimeType == 1)
        {
            return new LiveActivityTimelineEntry
            {
                StartsAt = start,
                EndsAt = end,
                Phase = LiveActivityPhase.BreakTime,
                Headline = Clip(item.BreakNameText, 48, "课间休息"),
                CompactTitle = "休",
                TimerStart = start,
                TimerEnd = end
            };
        }

        var classIndex = allClassItems.IndexOf(item);
        var subject = classIndex >= 0 && classIndex < classPlan.Classes.Count &&
                      profile.Subjects.TryGetValue(classPlan.Classes[classIndex].SubjectId, out var value)
            ? value
            : Subject.Fallback;
        var headline = Clip(subject.Name, 48, "课程");
        return new LiveActivityTimelineEntry
        {
            StartsAt = start,
            EndsAt = end,
            Phase = LiveActivityPhase.InClass,
            Headline = headline,
            CompactTitle = Clip(subject.Initial, 2, Clip(headline, 2, "课")),
            Teacher = Clip(subject.TeacherName, 48),
            TimerStart = start,
            TimerEnd = end
        };
    }

    private LiveActivityWeather? CreateWeatherPresentation()
    {
        if (!weatherService.IsWeatherRefreshed)
        {
            return null;
        }

        var weather = settingsService.Settings.LastWeatherInfo;
        return new LiveActivityWeather
        {
            WeatherCode = weather.Current.Weather,
            Temperature = weather.Current.Temperature.ToString(),
            Humidity = weather.Current.Humidity.ToString(),
            WindSpeed = weather.Current.Wind.Speed.ToString(),
            AirQualityIndex = weather.Aqi.Aqi,
            Pressure = weather.Current.Pressure.ToString(),
            FeelsLike = weather.Current.FeelsLike.ToString()
        };
    }

    private static DateTimeOffset ToDateTimeOffset(DateTime value)
    {
        if (value.Kind == DateTimeKind.Utc)
        {
            return new DateTimeOffset(value);
        }

        var local = DateTime.SpecifyKind(value, DateTimeKind.Unspecified);
        return new DateTimeOffset(local, TimeZoneInfo.Local.GetUtcOffset(local));
    }

    private static string Clip(string? value, int maximumLength, string fallback = "")
    {
        var normalized = value?.Trim() ?? string.Empty;
        if (normalized.Length == 0)
        {
            normalized = fallback;
        }
        return normalized.Length <= maximumLength
            ? normalized
            : normalized[..maximumLength];
    }
}
