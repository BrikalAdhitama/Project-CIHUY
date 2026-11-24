$ErrorActionPreference = 'Stop'
$frontendRoot = Split-Path -Parent $PSScriptRoot
$errors = [System.Collections.Generic.List[string]]::new()
$signingPath = Join-Path $frontendRoot 'android/key.properties'
if (-not (Test-Path -LiteralPath $signingPath)) {
    $errors.Add('android/key.properties belum tersedia.')
} else {
    $properties = @{}
    foreach ($line in Get-Content -LiteralPath $signingPath) {
        if ($line -match '^\s*(storeFile|storePassword|keyAlias|keyPassword)\s*=(.*)$') { $properties[$Matches[1]] = $Matches[2].Trim() }
    }
    foreach ($name in @('storeFile','storePassword','keyAlias','keyPassword')) {
        if ([string]::IsNullOrWhiteSpace($properties[$name])) { $errors.Add("Signing: $name belum diisi.") }
    }
    if ($properties['storeFile']) {
        $storePath = $properties['storeFile'].Replace('\\','\').Replace('\:',':')
        if (-not [IO.Path]::IsPathRooted($storePath)) { $storePath = Join-Path $frontendRoot "android/app/$storePath" }
        if (-not (Test-Path -LiteralPath $storePath)) { $errors.Add('Berkas upload keystore tidak ditemukan.') }
    }
}
foreach ($file in @('supabase.local.json', 'release.local.json')) {
    $path = Join-Path $frontendRoot $file
    if (-not (Test-Path -LiteralPath $path)) { $errors.Add("$file belum tersedia."); continue }
    $config = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ($file -eq 'supabase.local.json') {
        if ($config.SUPABASE_URL -notmatch '^https://[^/\s]+') { $errors.Add('SUPABASE_URL harus HTTPS.') }
        if ($config.SUPABASE_PUBLISHABLE_KEY -notmatch '^sb_publishable_.+') { $errors.Add('Gunakan publishable key Supabase, bukan secret/service role.') }
        if ($config.GOOGLE_WEB_CLIENT_ID -notmatch '^\d+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$') { $errors.Add('GOOGLE_WEB_CLIENT_ID tidak valid.') }
    } else {
        if ([string]::IsNullOrWhiteSpace($config.DEVELOPER_NAME)) { $errors.Add('DEVELOPER_NAME belum diisi.') }
        if ($config.SUPPORT_EMAIL -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') { $errors.Add('SUPPORT_EMAIL belum valid.') }
        foreach ($field in @('PRIVACY_POLICY_URL','ACCOUNT_DELETION_URL')) {
            $uri = $null
            if (-not [Uri]::TryCreate([string]$config.$field, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https' -or $uri.IsLoopback -or $uri.Host -match '(^|\.)(example\.(com|org|net)|invalid|test)$') {
                $errors.Add("$field harus URL HTTPS publik yang sebenarnya.")
            }
        }
    }
}
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Output "BELUM SIAP: $_" }
    exit 1
}
Write-Output 'Konfigurasi lokal lengkap. Tetap verifikasi sertifikat, URL publik, OAuth Play, layanan server, dan pengujian perangkat sebelum upload.'
