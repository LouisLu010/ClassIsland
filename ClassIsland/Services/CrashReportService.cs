using System;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using ClassIsland.Core;

namespace ClassIsland.Services;

public sealed record CrashReport(string CrashInfo, bool IsCritical, bool AllowIgnore);

/// <summary>
/// 保存并恢复移动端崩溃报告。
/// </summary>
public sealed class CrashReportService
{
    private const string PendingReportFileName = ".pending-crash-report";
    private static readonly object FileLock = new();
    private readonly object _reportLock = new();
    private static string? _activeArchiveFileName;
    private CrashReport? _currentReport;

    public event Action<CrashReport?>? ReportChanged;

    public CrashReport? CurrentReport
    {
        get
        {
            lock (_reportLock)
            {
                return _currentReport;
            }
        }
    }

    public CrashReportService()
    {
        _currentReport = LoadPendingReport();
    }

    public void Publish(CrashReport report)
    {
        string crashInfo;
        try
        {
            crashInfo = PersistReport(report.CrashInfo);
        }
        catch
        {
            crashInfo = report.CrashInfo;
        }

        var persistedReport = report with { CrashInfo = crashInfo };

        lock (_reportLock)
        {
            _currentReport = persistedReport;
        }

        TryNotifyReportChanged(persistedReport);
    }

    public void Dismiss()
    {
        lock (FileLock)
        {
            TryDelete(PendingReportPath);
            _activeArchiveFileName = null;
        }

        lock (_reportLock)
        {
            _currentReport = null;
        }

        TryNotifyReportChanged(null);
    }

    /// <summary>
    /// 在完整异常处理链路也可能失败时，先同步保存原始异常。
    /// </summary>
    public static void PersistEmergency(Exception exception)
    {
        try
        {
            PersistReport(exception.ToString());
        }
        catch
        {
            // 崩溃处理不能再抛出异常。
        }
    }

    private static string PersistReport(string crashInfo)
    {
        var reportText = BuildReportText(crashInfo);

        lock (FileLock)
        {
            Directory.CreateDirectory(CrashReportsFolderPath);
            _activeArchiveFileName ??=
                $"Crash-{DateTimeOffset.UtcNow:yyyyMMdd-HHmmss-fff}-{Guid.NewGuid():N}.log";

            var archivePath = Path.Combine(CrashReportsFolderPath, _activeArchiveFileName);
            File.WriteAllText(archivePath, reportText);
            File.WriteAllText(PendingReportPath, _activeArchiveFileName);
        }

        return reportText;
    }

    private static CrashReport? LoadPendingReport()
    {
        try
        {
            lock (FileLock)
            {
                if (!File.Exists(PendingReportPath))
                {
                    return null;
                }

                var archiveFileName = Path.GetFileName(File.ReadAllText(PendingReportPath).Trim());
                if (string.IsNullOrWhiteSpace(archiveFileName))
                {
                    return null;
                }

                var archivePath = Path.Combine(CrashReportsFolderPath, archiveFileName);
                return File.Exists(archivePath)
                    ? new CrashReport(File.ReadAllText(archivePath), false, true)
                    : null;
            }
        }
        catch
        {
            return null;
        }
    }

    private static string BuildReportText(string crashInfo)
    {
        var timestamp = DateTimeOffset.Now.ToString("yyyy-MM-dd HH:mm:ss zzz", CultureInfo.InvariantCulture);
        return $"""
               ClassIsland 崩溃报告
               时间：{timestamp}
               应用版本：{App.AppVersionLong}
               系统：{RuntimeInformation.OSDescription}
               ================================

               {crashInfo}
               """;
    }

    private void TryNotifyReportChanged(CrashReport? report)
    {
        try
        {
            ReportChanged?.Invoke(report);
        }
        catch
        {
            // 崩溃报告界面失效时仍保留磁盘日志。
        }
    }

    private static string CrashReportsFolderPath =>
        Path.Combine(CommonDirectories.AppLogFolderPath, "CrashReports");

    private static string PendingReportPath =>
        Path.Combine(CommonDirectories.AppRootFolderPath, PendingReportFileName);

    private static void TryDelete(string path)
    {
        try
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
        catch
        {
            // 保留报告不会影响应用继续运行。
        }
    }
}
