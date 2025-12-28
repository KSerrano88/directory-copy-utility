param(
    [string]$SourceScript = ".\CopyWithGUI.ps1",
    [string]$OutputExe    = "..\CopyWithGUI.exe",
    [string]$IconPath     = ".\copyutil.ico"   # optional, can be blank or removed
)

if (-not (Test-Path $SourceScript)) {
    Write-Host "Source script not found: $SourceScript" -ForegroundColor Red
    exit 1
}

# Ensure ps2exe is available
if (-not (Get-Command ps2exe -ErrorAction SilentlyContinue)) {
    Write-Host "ps2exe module not found. Install it with: Install-Module ps2exe -Scope CurrentUser" -ForegroundColor Yellow
    exit 1
}

# Build options
$ps2exeParams = @{
    inputFile  = $SourceScript
    outputFile = $OutputExe
    noConsole  = $true
}

if (Test-Path $IconPath) {
    $ps2exeParams.iconFile = $IconPath
}

Write-Host "Building EXE..."
ps2exe @ps2exeParams

Write-Host "Build complete: $OutputExe" -ForegroundColor Green