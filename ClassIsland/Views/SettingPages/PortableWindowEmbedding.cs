using System;
using System.Linq;
using Avalonia.Controls;

namespace ClassIsland.Views.SettingPages;

internal static class PortableWindowEmbedding
{
    public static T Embed<T>(Window window, T host) where T : ContentControl
    {
        if (window.Content is not Control content)
        {
            throw new InvalidOperationException($"窗口 {window.GetType().Name} 没有可嵌入的内容。");
        }

        window.Content = null;
        host.DataContext = window.DataContext;
        host.Content = content;
        host.HorizontalContentAlignment = Avalonia.Layout.HorizontalAlignment.Stretch;
        host.VerticalContentAlignment = Avalonia.Layout.VerticalAlignment.Stretch;

        foreach (var style in window.Styles.ToArray())
        {
            window.Styles.Remove(style);
            host.Styles.Add(style);
        }

        foreach (var resource in window.Resources.ToArray())
        {
            window.Resources.Remove(resource.Key);
            host.Resources[resource.Key] = resource.Value;
        }

        return host;
    }
}
