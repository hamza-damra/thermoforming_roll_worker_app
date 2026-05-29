#requires -Version 5.1
<#
.SYNOPSIS
  Builds the Roll Worker DEBUG ARM64-v8a release APK pointing at the
  local DDNS backend (hamzadamra.ddns.net:8080).

.DESCRIPTION
  Uses APP_ENV=debug so AppConfig selects the debugBaseUrl
  (http://hamzadamra.ddns.net:8080) automatically.

  Output:
    build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
    build/app/outputs/flutter-apk/taleeb-roll-worker-arm64-v8a-release-debug.apk
#>

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

flutter build apk --release `
  --target-platform android-arm64 `
  --split-per-abi `
  --dart-define=APP_ENV=debug `
  --dart-define=API_BASE_URL=http://hamzadamra.ddns.net:8080 `
  --dart-define=DEVICE_KEY=taleeb-device-key-2025-default

if ($LASTEXITCODE -ne 0) {
  throw "flutter build apk failed with exit code $LASTEXITCODE"
}

$src = Join-Path $repoRoot 'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk'
$dst = Join-Path $repoRoot 'build/app/outputs/flutter-apk/taleeb-roll-worker-arm64-v8a-release-debug.apk'

if (-not (Test-Path $src)) {
  throw "Expected APK not found: $src"
}

Copy-Item -LiteralPath $src -Destination $dst -Force

$size = (Get-Item $dst).Length
$sha  = (Get-FileHash -Path $dst -Algorithm SHA256).Hash
Write-Host ""
Write-Host "Debug APK built:"
Write-Host "  path  : $dst"
Write-Host "  size  : $size bytes"
Write-Host "  sha256: $sha"
Write-Host ""
Write-Host "DEBUG build -- points at http://hamzadamra.ddns.net:8080"
