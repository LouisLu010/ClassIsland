using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using ClassIsland.Core;
using ClassIsland.Core.Abstractions.Services;
using Microsoft.Extensions.Logging;
using SoundFlow.Abstracts;
using SoundFlow.Abstracts.Devices;

namespace ClassIsland.Services;

/// <summary>
/// 延迟初始化原生音频后端，并在后端不可用时降级为静默实现。
/// </summary>
internal sealed class ResilientAudioService : IAudioService
{
    private readonly Lazy<IAudioService> _service;

    public ResilientAudioService(ILogger<AudioService> logger)
    {
        _service = new Lazy<IAudioService>(() => CreateAudioService(logger));
    }

    private IAudioService Service => _service.Value;

    public AudioEngine AudioEngine => Service.AudioEngine;

    [Obsolete("请使用 TryInitializeDefaultPlaybackDeviceSafeAsync 方法")]
    public AudioPlaybackDevice? TryInitializeDefaultPlaybackDevice() =>
        Service.TryInitializeDefaultPlaybackDevice();

    [Obsolete("请使用 TryInitializeDefaultPlaybackDeviceSafeAsync 方法")]
    public Task<AudioPlaybackDevice?> TryInitializeDefaultPlaybackDeviceAsync() =>
        Service.TryInitializeDefaultPlaybackDeviceAsync();

    public Task<RefCounted<AudioPlaybackDevice>.Lease?> TryInitializeDefaultPlaybackDeviceSafeAsync() =>
        Service.TryInitializeDefaultPlaybackDeviceSafeAsync();

    public Task PlayAudioAsync(
        Stream audio,
        float volume,
        CancellationToken? cancellationToken = null) =>
        Service.PlayAudioAsync(audio, volume, cancellationToken);

    public Task PlayAudioAsync(
        string filePath,
        float volume,
        CancellationToken? cancellationToken = null) =>
        Service.PlayAudioAsync(filePath, volume, cancellationToken);

    public void Dispose()
    {
        if (_service.IsValueCreated)
        {
            _service.Value.Dispose();
        }
    }

    private static IAudioService CreateAudioService(ILogger<AudioService> logger)
    {
        try
        {
            return new AudioService(logger);
        }
        catch (Exception exception)
        {
            logger.LogWarning(exception, "SoundFlow 原生音频后端初始化失败，已禁用音频播放");
            return new UnavailableAudioService();
        }
    }
}
