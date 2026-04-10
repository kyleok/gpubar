namespace GPUBar.Windows;

internal static class UriActivation
{
    public static bool TryApply(string? rawArgument, AppSettings settings)
    {
        if (string.IsNullOrWhiteSpace(rawArgument))
        {
            return false;
        }

        if (!Uri.TryCreate(rawArgument, UriKind.Absolute, out var uri))
        {
            return false;
        }

        if (!string.Equals(uri.Scheme, "gpubar", StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(uri.Host, "configure", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        var updated = false;
        foreach (var pair in ParseQuery(uri.Query))
        {
            switch (pair.Key)
            {
                case "api":
                    settings.ApiUrl = pair.Value;
                    updated = true;
                    break;
                case "core":
                    settings.CoreUrl = pair.Value;
                    updated = true;
                    break;
                case "key":
                    settings.ApiKey = pair.Value;
                    updated = true;
                    break;
                case "user":
                    settings.Username = pair.Value;
                    updated = true;
                    break;
            }
        }

        return updated;
    }

    private static IEnumerable<KeyValuePair<string, string>> ParseQuery(string query)
    {
        foreach (var part in query.TrimStart('?').Split('&', StringSplitOptions.RemoveEmptyEntries))
        {
            var pieces = part.Split('=', 2);
            var key = Uri.UnescapeDataString(pieces[0]).Trim().ToLowerInvariant();
            var value = pieces.Length > 1 ? Uri.UnescapeDataString(pieces[1]) : string.Empty;
            if (!string.IsNullOrWhiteSpace(key))
            {
                yield return new KeyValuePair<string, string>(key, value);
            }
        }
    }
}
