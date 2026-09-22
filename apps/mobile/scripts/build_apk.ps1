# Build Script for CaseFlow Flutter APK
#
# Credentials come from the environment, never from this file. It previously
# hardcoded the Supabase key, which put a credential in git for every clone.
#
#   $env:SUPABASE_URL = "https://<project>.supabase.co"
#   $env:SUPABASE_PUBLISHABLE_KEY = "sb_publishable_..."
#   .\scripts\build_apk.ps1

$SUPABASE_URL = $env:SUPABASE_URL
$SUPABASE_PUBLISHABLE_KEY = $env:SUPABASE_PUBLISHABLE_KEY

if (-not $SUPABASE_URL -or -not $SUPABASE_PUBLISHABLE_KEY) {
    Write-Host "Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY in your environment first." -ForegroundColor Red
    exit 1
}
if (-not $SUPABASE_PUBLISHABLE_KEY.StartsWith("sb_publishable_")) {
    Write-Host "SUPABASE_PUBLISHABLE_KEY must be a publishable key (sb_publishable_...), not a legacy JWT key." -ForegroundColor Red
    exit 1
}

Write-Host "Starting Build: CaseFlow AI APK (Release Mode)..." -ForegroundColor Cyan
Write-Host "Output being logged to: build_diagnostic.log" -ForegroundColor Gray

# Using full path to ensure it runs even if PATH is missing
# Redirecting both output (1) and errors (2) to build_diagnostic.log
Write-Host "Building Release APK v1.5.0+14..." -ForegroundColor Cyan
& C:\flutter\bin\flutter.bat build apk --release `
    --dart-define=SUPABASE_URL=$SUPABASE_URL `
    --dart-define=SUPABASE_PUBLISHABLE_KEY=$SUPABASE_PUBLISHABLE_KEY `
    > build_diagnostic.log 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build Successful!" -ForegroundColor Green
    Write-Host "Moving APK to project root..." -ForegroundColor Gray
    Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "..\CaseFlow-v1.5.0-14.apk"
    Write-Host "Final APK: CaseFlow-v1.5.0-14.apk" -ForegroundColor Green
} else {
    Write-Host "Build Failed. Check the errors above." -ForegroundColor Red
}
