using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using ClassIsland.Core;
using ClassIsland.Core.Abstractions.Services;
using SoundFlow.Abstracts;
using SoundFlow.Abstracts.Devices;

namespace ClassIsland.Services;

/// <summary>
/// 在没有可用原生音频后端的平台上静默忽略播放请求。
/// </summary>
internal sealed class UnavailableAudioService : IAudioService
{
    public AudioEngine AudioEngine =>
        throw new PlatformNotSupportedException("当前平台没有可用的 SoundFlow 原生音频后端。");

    [Obsolete("请使用 TryInitializeDefaultPlaybackDeviceSafeAsync 方法")]
    public AudioPlaybackDevice? TryInitializeDefaultPlaybackDevice() => null;

    [Obsolete("请使用 TryInitializeDefaultPlaybackDeviceSafeAsync 方法")]
    public Task<AudioPlaybackDevice?> TryInitializeDefaultPlaybackDeviceAsync() =>
        Task.FromResult<AudioPlaybackDevice?>(null);

    public Task<RefCounted<AudioPlaybackDevice>.Lease?> TryInitializeDefaultPlaybackDeviceSafeAsync() =>
        Task.FromResult<RefCounted<AudioPlaybackDevice>.Lease?>(null);

    public Task PlayAudioAsync(
        Stream audio,
        float volume,
        CancellationToken? cancellationToken = null)
    {
        audio.Dispose();
        return Task.CompletedTask;
    }

    public Task PlayAudioAsync(
        string filePath,
        float volume,
        CancellationToken? cancellationToken = null) =>
        Task.CompletedTask;

    public void Dispose()
    {
    }
}
