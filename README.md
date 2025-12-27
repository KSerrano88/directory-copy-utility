# Directory Copy Utility

A PowerShell-based GUI application for incremental directory copying with:

- Multi-threaded SHA-256 checksums
- Incremental copy logic
- Checksum validation
- Logging
- WPF GUI with progress bar
- EXE packaging via ps2exe
- MSI installer packaging via WiX

## Project Structure
src/ CopyWithGUI.ps1     # Main GUI application 
Build-CopyUtility.ps1    # Builds EXE using ps2exe 
DirectoryCopy.wxs        # WiX installer definition 
build-installer.cmd      # Builds MSI installer 
copyutil.ico             # Optional icon

## Build EXE
pwsh ./src/Build-CopyUtility.ps1

## Build MSI
cd src build-installer.cmd

## Create ZIP Package
pwsh ./MakeZip.ps1

## License
MIT
