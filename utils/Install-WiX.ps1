# -----------------------------
# Install WiX Toolset 3.14 + Add to PATH
# -----------------------------

$wixUrl = "https://github.com/wixtoolset/wix3/releases/download/wix314rtm/wix314.exe"
$installer = "$env:TEMP\wix314.exe"
$wixPath = "C:\Program Files (x86)\WiX Toolset v3.14\bin"

Write-Host "Downloading WiX Toolset..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $wixUrl -OutFile $installer

Write-Host "Installing WiX Toolset..." -ForegroundColor Cyan
Start-Process -FilePath $installer -ArgumentList "/quiet" -Wait

# Add WiX to PATH if missing
if (-not ($env:PATH -split ";" | Where-Object { $_ -eq $wixPath })) {
    Write-Host "Adding WiX to PATH..." -ForegroundColor Cyan
    setx PATH "$env:PATH;$wixPath" | Out-Null
}

Write-Host "Verifying installation..." -ForegroundColor Cyan

$foundCandle = Get-Command candle.exe -ErrorAction SilentlyContinue
$foundLight  = Get-Command light.exe -ErrorAction SilentlyContinue

if ($foundCandle -and $foundLight) {
    Write-Host "WiX installed successfully and is on PATH." -ForegroundColor Green
    Write-Host "candle.exe → $($foundCandle.Source)"
    Write-Host "light.exe  → $($foundLight.Source)"
}
else {
    Write-Host "WiX installed, but PATH may not be updated yet." -ForegroundColor Yellow
    Write-Host "Close and reopen PowerShell, then run:"
    Write-Host "    candle.exe -?"
    Write-Host "    light.exe -?"
}