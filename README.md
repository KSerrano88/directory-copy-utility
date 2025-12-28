# Directory Copy Utility

A PowerShell-based GUI application for incremental directory copying with:

- Multi-threaded SHA-256 checksums
- Incremental copy logic
- Checksum validation
- Logging
- WPF GUI with progress bar
- EXE packaging via ps2exe
- MSI installer packaging via WiX

## Prerequisites

- Windows PowerShell 5.1 or later
- .NET Framework (for WPF GUI)
- ps2exe module for building EXE
- WiX Toolset for building MSI installer

## Project Structure

```
directory-copy-utility/
├── README.md
├── bin/
│   ├── Build-CopyUtility.ps1    # Script to build EXE using ps2exe
│   ├── CopyWithGUI.ps1          # Main GUI application script
│   ├── DirectoryCopy.wxs        # WiX installer definition
│   ├── build-installer.cmd      # Batch script to build MSI installer
│   ├── copyutil.ico             # Optional icon for the application
│   ├── DirectoryCopy.wixobj     # WiX object file (generated)
│   ├── DirectoryCopyUtility.wixpdb  # WiX debug file (generated)
│   └── cab1.cab                 # Cabinet file (generated)
└── utils/
    ├── Install-WiX.ps1          # Script to install WiX Toolset
    └── MakeZip.ps1              # Script to create ZIP archive
```

## Getting Started

### Running the Application Directly

1. Ensure PowerShell execution policy allows running scripts: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`
2. Navigate to the `bin` directory
3. Run the GUI: `.\CopyWithGUI.ps1`

### Building the EXE

1. Install ps2exe module: `Install-Module ps2exe -Scope CurrentUser`
2. Navigate to the `bin` directory
3. Run: `.\Build-CopyUtility.ps1`
4. The EXE will be created in the `bin` directory

### Building the MSI Installer

1. Install WiX Toolset: Run `.\utils\Install-WiX.ps1` or download from https://wixtoolset.org/
2. Navigate to the `bin` directory
3. Run: `.\build-installer.cmd`
4. The MSI will be created as `DirectoryCopyUtility.msi`

### Testing the Installer

- Install: `msiexec /i .\DirectoryCopyUtility.msi`
- Uninstall: `msiexec /x .\DirectoryCopyUtility.msi`

## Usage

The GUI allows you to select source and destination directories, configure copy options, and monitor progress with checksum validation.

## License

MIT
