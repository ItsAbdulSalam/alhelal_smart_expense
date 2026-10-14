# Run from the Flutter project root.
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

Write-Host '1/3 Building Flutter web (WASM)...' -ForegroundColor Cyan
flutter build web --wasm --release
if ($LASTEXITCODE -ne 0) { throw 'Flutter build failed. Deployment cancelled.' }

$source = Join-Path $PSScriptRoot 'build\web'
$destination = Join-Path $PSScriptRoot 'web_release'
if (-not (Test-Path -LiteralPath (Join-Path $source 'index.html'))) {
    throw 'build\web\index.html not found. Deployment cancelled.'
}

Write-Host '2/3 Refreshing web_release...' -ForegroundColor Cyan
if (Test-Path -LiteralPath $destination) {
    Remove-Item -LiteralPath $destination -Recurse -Force
}
New-Item -ItemType Directory -Path $destination | Out-Null
Copy-Item -Path (Join-Path $source '*') -Destination $destination -Recurse -Force

Write-Host '3/3 Deploying to Vercel production...' -ForegroundColor Cyan
vercel --prod
if ($LASTEXITCODE -ne 0) { throw 'Vercel deployment failed.' }
Write-Host 'Deployment finished.' -ForegroundColor Green
