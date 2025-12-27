param(
    [string]$Output = "DirectoryCopyUtility.zip"
)

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcPath = Join-Path $projectRoot "src"

if (-not (Test-Path $srcPath)) {
    Write-Host "ERROR: src folder not found." -ForegroundColor Red
    exit 1
}

Write-Host "Creating ZIP package..." -ForegroundColor Cyan

$itemsToZip = @(
    (Join-Path $projectRoot "README.md"),
    (Join-Path $projectRoot ".gitignore"),
    $srcPath
)

if (Test-Path $Output) {
    Remove-Item $Output -Force
}

Compress-Archive -Path $itemsToZip -DestinationPath $Output -Force

Write-Host "ZIP package created: $Output" -ForegroundColor Green