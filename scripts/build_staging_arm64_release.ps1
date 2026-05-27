#requires -Version 5.1
<#
.SYNOPSIS
  Builds the Roll Worker staging ARM64-v8a release APK and copies it to a
  clearly-named staging artifact.

.DESCRIPTION
  AppConfig already defaults to staging when APP_ENV is unset, but this
  script passes every dart-define explicitly so the artifact is
  unambiguous to anyone reading the build log.

  Output:
    build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
    build/app/outputs/flutter-apk/taleeb-roll-worker-arm64-v8a-release-staging.apk
#>

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

# Keep ErrorActionPreference at default so flutter's stderr warnings
# (treated as NativeCommandError in PowerShell 5.1) do not abort the
# script. We check $LASTEXITCODE explicitly instead.
flutter build apk --release `
  --target-platform android-arm64 `
  --split-per-abi `
  --dart-define=APP_ENV=staging `
  --dart-define=API_BASE_URL=https://138.68.66.215 `
  --dart-define=DEVICE_KEY=taleeb-device-key-2025-default

if ($LASTEXITCODE -ne 0) {
  throw "flutter build apk failed with exit code $LASTEXITCODE"
}

$src = Join-Path $repoRoot 'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk'
$dst = Join-Path $repoRoot 'build/app/outputs/flutter-apk/taleeb-roll-worker-arm64-v8a-release-staging.apk'

if (-not (Test-Path $src)) {
  throw "Expected APK not found: $src"
}

Copy-Item -LiteralPath $src -Destination $dst -Force

$size = (Get-Item $dst).Length
$sha  = (Get-FileHash -Path $dst -Algorithm SHA256).Hash
Write-Host ""
Write-Host "Staging APK built:"
Write-Host "  path  : $dst"
Write-Host "  size  : $size bytes"
Write-Host "  sha256: $sha"
Write-Host ""
Write-Host "STAGING build -- do not distribute as production."
