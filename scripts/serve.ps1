# Локальный просмотр портала: http://localhost:8080
# Запуск:  powershell -ExecutionPolicy Bypass -File scripts\serve.ps1
param([int]$Port = 8080)
$root = Join-Path (Split-Path -Parent $PSScriptRoot) 'portal'
$types = @{ '.html'='text/html; charset=utf-8'; '.js'='text/javascript; charset=utf-8'; '.css'='text/css; charset=utf-8'; '.json'='application/json; charset=utf-8'; '.svg'='image/svg+xml' }
$listener = New-Object Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Portal: http://localhost:$Port/  (Ctrl+C to stop)"
try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        try {
        $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
        if ($rel -eq '') { $rel = 'index.html' }
        $path = [IO.Path]::GetFullPath((Join-Path $root $rel))
        if ($path.StartsWith($root) -and (Test-Path $path -PathType Leaf)) {
            $bytes = [IO.File]::ReadAllBytes($path)
            $ext = [IO.Path]::GetExtension($path)
            $ctx.Response.ContentType = $(if ($types[$ext]) { $types[$ext] } else { 'application/octet-stream' })
            $ctx.Response.ContentLength64 = $bytes.Length
            if ($ctx.Request.HttpMethod -ne 'HEAD') { $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length) }
        } else { $ctx.Response.StatusCode = 404 }
        } catch { Write-Host "Request error: $($_.Exception.Message)" }
        finally { $ctx.Response.Close() }
    }
} finally { $listener.Stop() }
