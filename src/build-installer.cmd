@echo off
setlocal

set WXS=DirectoryCopy.wxs
set MSI=DirectoryCopyUtility.msi

if not exist "%WXS%" (
  echo %WXS% not found.
  exit /b 1
)

echo Cleaning old outputs...
del /q DirectoryCopy.wixobj 2>nul
del /q %MSI% 2>nul

echo Running candle...
candle.exe "%WXS%"
if errorlevel 1 (
  echo candle failed.
  exit /b 1
)

echo Running light...
light.exe DirectoryCopy.wixobj -o "%MSI%"
if errorlevel 1 (
  echo light failed.
  exit /b 1
)

echo.
echo Build complete: %MSI%
endlocal