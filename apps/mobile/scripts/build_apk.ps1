# Build Script for CaseFlow Flutter APK
# This script ensures all required environment variables are passed during the build.

$SUPABASE_URL = "https://asrjqsnyezvcakvkokcl.supabase.co"
$SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzcmpxc255ZXp2Y2Frdmtva2NsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5NTQ1MjYsImV4cCI6MjA4NzUzMDUyNn0._W7YwzwxA2m83VxITvQMDVUSbTlnJi1Ij389Sxp-Mls"

Write-Host "Starting Build: CaseFlow AI APK (Release Mode)..." -ForegroundColor Cyan
Write-Host "Output being logged to: build_diagnostic.log" -ForegroundColor Gray

# Using full path to ensure it runs even if PATH is missing
# Redirecting both output (1) and errors (2) to build_diagnostic.log
# Run Flutter build with environment variables correctly injected
Write-Host "Building Release APK v1.4.1+8..." -ForegroundColor Cyan
& C:\flutter\bin\flutter.bat build apk --release `
    --dart-define=SUPABASE_URL=$SUPABASE_URL `
    --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY `
    > build_diagnostic.log 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build Successful!" -ForegroundColor Green
    Write-Host "Moving APK to project root..." -ForegroundColor Gray
    Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "..\CaseFlow-Dossier-FINAL.apk"
    Write-Host "Final APK: CaseFlow-Dossier-FINAL.apk" -ForegroundColor Green
} else {
    Write-Host "Build Failed. Check the errors above." -ForegroundColor Red
}
