param(
    [switch]$CreateNewKey,
    [string]$Keytool = 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe'
)
$ErrorActionPreference = 'Stop'
if (-not $CreateNewKey) {
    throw 'Untuk aplikasi BARU, jalankan dengan -CreateNewKey. Untuk aplikasi yang pernah diunggah, gunakan upload key yang sudah terdaftar dan isi android/key.properties.'
}
$frontendRoot = Split-Path -Parent $PSScriptRoot
$keyPath = Join-Path $frontendRoot 'android/upload-keystore.jks'
$propertiesPath = Join-Path $frontendRoot 'android/key.properties'
if ((Test-Path -LiteralPath $keyPath) -or (Test-Path -LiteralPath $propertiesPath)) {
    throw 'Keystore atau key.properties sudah ada. Tidak ada berkas yang ditimpa.'
}
if (-not (Test-Path -LiteralPath $Keytool)) { throw 'Keytool tidak ditemukan. Isi parameter -Keytool dengan lokasi JDK.' }
$randomBytes = New-Object byte[] 32
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($randomBytes)
$rng.Dispose()
$password = [Convert]::ToBase64String($randomBytes)
$previousPassword = $env:CIHUY_UPLOAD_STORE_PASSWORD
try {
    $env:CIHUY_UPLOAD_STORE_PASSWORD = $password
    & $Keytool -genkeypair -noprompt -keystore $keyPath -storetype JKS -alias upload -keyalg RSA -keysize 2048 -validity 10000 -dname 'CN=CIHUY Upload' -storepass:env CIHUY_UPLOAD_STORE_PASSWORD -keypass:env CIHUY_UPLOAD_STORE_PASSWORD
    if ($LASTEXITCODE -ne 0) { throw 'Pembuatan keystore gagal. Periksa berkas sebelum mencoba lagi.' }
    $properties = "storePassword=$password`nkeyPassword=$password`nkeyAlias=upload`nstoreFile=../upload-keystore.jks`n"
    [IO.File]::WriteAllText($propertiesPath, $properties, [Text.UTF8Encoding]::new($false))
    Write-Output 'Upload keystore dan android/key.properties dibuat. Password tidak dicetak. Cadangkan keduanya di tempat aman di luar repository.'
} finally {
    $env:CIHUY_UPLOAD_STORE_PASSWORD = $previousPassword
    $password = $null
    $properties = $null
}
