#requires -Version 5.1
<#
.SYNOPSIS
  Builds the Roll Worker PRODUCTION ARM64-v8a release APK.

.DESCRIPTION
  Every dart-define is set explicitly to make production builds
  reproducible from the script and impossible to confuse with staging:
    APP_ENV=production
    API_BASE_URL=https://taleeb.me
    ALLOW_STAGING_SELF_SIGNED_CERT=false
    DEVICE_KEY=taleeb-device-key-2025-default

  AppConfig also fails fast if APP_ENV=production is ever paired with a
  staging host, so this script cannot silently produce a misconfigured
  production binary.

  Output:
    build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
    build/app/outputs/flutter-apk/taleeb-roll-worker-arm64-v8a-release-production.apk
#>

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

# Keep ErrorActionPreference at default so flutter's stderr warnings
# (treated as NativeCommandError in PowerShell 5.1) do not abort the
# script. We check $LASTEXITCODE explicitly instead.
flutter build apk --release `
  --target-platform android-arm64 `
  --split-per-abi `
  --dart-define=APP_ENV=production `
  --dart-define=API_BASE_URL=https://taleeb.me `
  --dart-define=ALLOW_STAGING_SELF_SIGNED_CERT=false `
  --dart-define=DEVICE_KEY=taleeb-device-key-2025-default

if ($LASTEXITCODE -ne 0) {
  throw "flutter build apk failed with exit code $LASTEXITCODE"
}

$src = Join-Path $repoRoot 'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk'
$dst = Join-Path $repoRoot 'build/app/outputs/flutter-apk/taleeb-roll-worker-arm64-v8a-release-production.apk'

if (-not (Test-Path $src)) {
  throw "Expected APK not found: $src"
}

Copy-Item -LiteralPath $src -Destination $dst -Force

$size = (Get-Item $dst).Length
$sha  = (Get-FileHash -Path $dst -Algorithm SHA256).Hash
Write-Host ""
Write-Host "Production APK built:"
Write-Host "  path  : $dst"
Write-Host "  size  : $size bytes"
Write-Host "  sha256: $sha"
