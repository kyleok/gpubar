using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;

namespace GPUBar.Windows;

public sealed class GpuStatusClient : IDisposable
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    private readonly HttpClient _httpClient;

    public GpuStatusClient(HttpClient? httpClient = null)
    {
        _httpClient = httpClient ?? new HttpClient();
        _httpClient.DefaultRequestHeaders.Accept.Clear();
        _httpClient.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
    }

    public async Task<GpuStatusResponse> FetchAsync(AppSettings settings, CancellationToken cancellationToken = default)
    {
        var baseUri = settings.ApiUrl.TrimEnd('/');
        var requestUri = $"{baseUri}/api/gpu/status?key={Uri.EscapeDataString(settings.ApiKey)}";

        using var request = new HttpRequestMessage(HttpMethod.Get, requestUri);
        using var response = await _httpClient.SendAsync(request, cancellationToken).ConfigureAwait(false);

        if (response.StatusCode == HttpStatusCode.Forbidden)
        {
            throw new GpuStatusException("Invalid API key. Re-pair from the dashboard.", isKeyInvalid: true);
        }

        if (!response.IsSuccessStatusCode)
        {
            throw new GpuStatusException($"HTTP {(int)response.StatusCode} {response.ReasonPhrase}");
        }

        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken).ConfigureAwait(false);
        var decoded = await JsonSerializer.DeserializeAsync<GpuStatusResponse>(stream, JsonOptions, cancellationToken).ConfigureAwait(false);
        if (decoded is null)
        {
            throw new GpuStatusException("GPU status response was empty.");
        }

        return decoded;
    }

    public void Dispose()
    {
        _httpClient.Dispose();
    }
}

public sealed class GpuStatusException : Exception
{
    public GpuStatusException(string message, bool isKeyInvalid = false) : base(message)
    {
        IsKeyInvalid = isKeyInvalid;
    }

    public bool IsKeyInvalid { get; }
}
