namespace YtDlpDownloader.Services;

internal static class YtDlpUrlHelper
{
    public static string Normalize(string url)
    {
        if (!Uri.TryCreate(url.Trim(), UriKind.Absolute, out var uri))
        {
            return url.Trim();
        }

        if (IsBilibiliUri(uri) && uri.AbsolutePath.StartsWith("/video/", StringComparison.OrdinalIgnoreCase))
        {
            var builder = new UriBuilder(uri)
            {
                Query = KeepQueryValue(uri.Query, "p"),
                Fragment = ""
            };
            return builder.Uri.ToString();
        }

        return uri.ToString();
    }

    public static void AddSiteArguments(ICollection<string> arguments, string url)
    {
        if (IsBilibiliUrl(url))
        {
            arguments.Add("--referer");
            arguments.Add("https://www.bilibili.com/");
        }
    }

    public static bool IsBilibiliUrl(string url)
    {
        return Uri.TryCreate(url, UriKind.Absolute, out var uri) && IsBilibiliUri(uri);
    }

    private static bool IsBilibiliUri(Uri uri)
    {
        return uri.Host.Equals("bilibili.com", StringComparison.OrdinalIgnoreCase) ||
               uri.Host.EndsWith(".bilibili.com", StringComparison.OrdinalIgnoreCase);
    }

    private static string KeepQueryValue(string query, string key)
    {
        if (string.IsNullOrWhiteSpace(query))
        {
            return "";
        }

        var prefix = key + "=";
        return query
            .TrimStart('?')
            .Split('&', StringSplitOptions.RemoveEmptyEntries)
            .FirstOrDefault(part => part.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) ?? "";
    }
}
