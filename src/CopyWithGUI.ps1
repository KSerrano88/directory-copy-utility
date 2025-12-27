Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# For concurrent collections and Parallel
Add-Type -AssemblyName System.Core

# -----------------------------
# XAML GUI
# -----------------------------
[xml]$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Directory Copy Utility"
        Height="500" Width="700"
        WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>   <!-- Row 0: Source -->
            <RowDefinition Height="Auto"/>   <!-- Row 1: Target -->
            <RowDefinition Height="Auto"/>   <!-- Row 2: Progress -->
            <RowDefinition Height="Auto"/>   <!-- Row 3: Buttons -->
            <RowDefinition Height="*"/>      <!-- Row 4: Log -->
            <RowDefinition Height="Auto"/>   <!-- Row 5: Close -->
        </Grid.RowDefinitions>

        <!-- Source -->
        <StackPanel Orientation="Horizontal" Grid.Row="0" Margin="0,0,0,10">
            <Label Content="Source Path:" Width="100" VerticalAlignment="Center"/>
            <TextBox Name="SourceBox" Width="450" Margin="0,0,10,0"/>
            <Button Name="BrowseSource" Content="Browse" Width="80"/>
        </StackPanel>

        <!-- Target -->
        <StackPanel Orientation="Horizontal" Grid.Row="1" Margin="0,0,0,10">
            <Label Content="Target Path:" Width="100" VerticalAlignment="Center"/>
            <TextBox Name="TargetBox" Width="450" Margin="0,0,10,0"/>
            <Button Name="BrowseTarget" Content="Browse" Width="80"/>
        </StackPanel>

        <!-- Progress -->
        <StackPanel Grid.Row="2" Margin="0,0,0,10">
            <ProgressBar Name="ProgressBar" Height="20" Minimum="0" Maximum="100"/>
            <Label Name="ProgressLabel" Content="Progress: 0%" HorizontalAlignment="Left"/>
            <Label Name="StatusLabel" Content="Status: Idle" HorizontalAlignment="Left"/>
        </StackPanel>

        <!-- Control buttons -->
        <StackPanel Orientation="Horizontal" Grid.Row="3" Margin="0,0,0,10">
            <Button Name="StartButton" Content="Start Copy" Width="120" Height="30" Margin="0,0,10,0"/>
            <Button Name="DryRunButton" Content="Dry Run (No Copy)" Width="160" Height="30"/>
        </StackPanel>

        <!-- Log output -->
        <TextBox Name="LogBox" Grid.Row="4" Margin="0,0,0,10"
                 VerticalScrollBarVisibility="Auto"
                 HorizontalScrollBarVisibility="Auto"
                 TextWrapping="Wrap"
                 AcceptsReturn="True"
                 IsReadOnly="True"/>

        <!-- Close -->
        <Button Name="CloseButton" Grid.Row="5" Content="Close"
                Width="120" Height="30" HorizontalAlignment="Right"/>
    </Grid>
</Window>
"@

# Load XAML
$reader = New-Object System.Xml.XmlNodeReader $XAML
$Window = [Windows.Markup.XamlReader]::Load($reader)

# Get controls
$SourceBox     = $Window.FindName("SourceBox")
$TargetBox     = $Window.FindName("TargetBox")
$BrowseSource  = $Window.FindName("BrowseSource")
$BrowseTarget  = $Window.FindName("BrowseTarget")
$StartButton   = $Window.FindName("StartButton")
$DryRunButton  = $Window.FindName("DryRunButton")
$LogBox        = $Window.FindName("LogBox")
$CloseButton   = $Window.FindName("CloseButton")
$ProgressBar   = $Window.FindName("ProgressBar")
$ProgressLabel = $Window.FindName("ProgressLabel")
$StatusLabel   = $Window.FindName("StatusLabel")

# -----------------------------
# Logging helpers
# -----------------------------
$global:LogFile = $null

function Initialize-LogFile {
    param(
        [string]$TargetPath
    )
    if (-not (Test-Path $TargetPath)) {
        New-Item -ItemType Directory -Path $TargetPath | Out-Null
    }
    $logDir = Join-Path $TargetPath "Logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir | Out-Null
    }
    $global:LogFile = Join-Path $logDir ("copy_log_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
}

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp  $Message"

    # GUI
    $LogBox.AppendText("$line`r`n")
    $LogBox.ScrollToEnd()

    # File
    if ($global:LogFile) {
        Add-Content -Path $global:LogFile -Value $line
    }
}

function Set-Progress {
    param(
        [int]$Percent,
        [string]$Status
    )
    if ($Percent -lt 0) { $Percent = 0 }
    if ($Percent -gt 100) { $Percent = 100 }

    $ProgressBar.Value = $Percent
    $ProgressLabel.Content = "Progress: $Percent%"
    if ($Status) {
        $StatusLabel.Content = "Status: $Status"
    }
}

# -----------------------------
# Multi-threaded directory checksum
# -----------------------------
function Get-DirectoryChecksum {
    param(
        [string]$DirPath
    )

    # Get all files in deterministic order
    $files = Get-ChildItem -Path $DirPath -Recurse -File | Sort-Object FullName

    if ($files.Count -eq 0) {
        # Empty directory → hash of empty input
        $emptyHashAlg = [System.Security.Cryptography.SHA256]::Create()
        $emptyHashAlg.Clear()
        $emptyHashAlg = [System.Security.Cryptography.SHA256]::Create()
        $emptyHashAlg.TransformFinalBlock([byte[]]::new(0), 0, 0) | Out-Null
        return ($emptyHashAlg.Hash | ForEach-Object { $_.ToString("x2") }) -join ""
    }

    # Thread-safe bag for per-file hashes
    $bagType = [System.Collections.Concurrent.ConcurrentBag[string]]
    $fileHashes = New-Object $bagType

    $filesArray = $files.FullName

    # Parallel hashing of individual files
    [System.Threading.Tasks.Parallel]::ForEach($filesArray, {
        param($filePath)

        try {
            $fileHashAlg = [System.Security.Cryptography.SHA256]::Create()
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $hashBytes = $fileHashAlg.ComputeHash($bytes)
            $hex = ($hashBytes | ForEach-Object { $_.ToString("x2") }) -join ""
            $fileHashes.Add($hex)
            $fileHashAlg.Dispose()
        }
        catch {
            # On failure, add a marker hash so checksum changes
            $fileHashes.Add("ERROR_HASH_$filePath")
        }
    })

    # Combine hashes deterministically: sort then hash the concatenated string
    $combined = ($fileHashes.ToArray() | Sort-Object) -join ''
    $finalAlg = [System.Security.Cryptography.SHA256]::Create()
    $combinedBytes = [System.Text.Encoding]::UTF8.GetBytes($combined)
    $finalBytes = $finalAlg.ComputeHash($combinedBytes)
    $finalAlg.Dispose()

    return ($finalBytes | ForEach-Object { $_.ToString("x2") }) -join ""
}

# -----------------------------
# Folder browser helpers
# -----------------------------
$BrowseSource.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $SourceBox.Text = $dialog.SelectedPath
    }
})

$BrowseTarget.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $TargetBox.Text = $dialog.SelectedPath
    }
})

# -----------------------------
# Core copy logic
# -----------------------------
function Invoke-Copy {
    param(
        [string]$SourcePath,
        [string]$TargetPath,
        [bool]$DryRun = $false
    )

    Write-Log "----------------------------------------"
    Write-Log "Run started. DryRun = $DryRun"
    Write-Log "Source: $SourcePath"
    Write-Log "Target: $TargetPath"

    if (-not (Test-Path $SourcePath)) {
        Write-Log "ERROR: Source path does not exist."
        Set-Progress -Percent 0 -Status "Error"
        return
    }

    if (-not (Test-Path $TargetPath)) {
        Write-Log "Target path does not exist. Creating it."
        New-Item -ItemType Directory -Path $TargetPath | Out-Null
    }

    Initialize-LogFile -TargetPath $TargetPath

    $ChecksumFile = Join-Path $TargetPath "directory_checksums.json"
    if (-not (Test-Path $ChecksumFile)) {
        '{}' | Out-File $ChecksumFile
    }

    $ChecksumTable = Get-Content $ChecksumFile | ConvertFrom-Json
    if (-not $ChecksumTable) {
        # Ensure it's a PSCustomObject
        $ChecksumTable = [pscustomobject]@{}
    }

    $directories = Get-ChildItem -Path $SourcePath -Directory | Sort-Object Name
    $totalDirs = $directories.Count

    if ($totalDirs -eq 0) {
        Write-Log "No directories found in source."
        Set-Progress -Percent 0 -Status "Idle"
        return
    }

    $dirIndex = 0
    Set-Progress -Percent 0 -Status "Processing"

    foreach ($dir in $directories) {
        $dirIndex++
        $sourceDir = $dir.FullName
        $targetDir = Join-Path $TargetPath $dir.Name

        Write-Log "Processing directory: $($dir.Name)"

        # Compute source checksum
        $sourceChecksum = Get-DirectoryChecksum -DirPath $sourceDir
        Write-Log "Source checksum: $sourceChecksum"

        $previousChecksum = $ChecksumTable.$($dir.Name)

        if ($previousChecksum -eq $sourceChecksum) {
            Write-Log "No changes detected for '$($dir.Name)'. Skipping."
        }
        else {
            if ($DryRun) {
                Write-Log "DRY RUN: Would copy '$sourceDir' to '$targetDir'."
                Write-Log "DRY RUN: Would update checksum to $sourceChecksum."
            }
            else {
                Write-Log "Changes detected. Copying directory..."
                try {
                    if (Test-Path $targetDir) {
                        # Overwrite existing directory
                        Remove-Item -Path $targetDir -Recurse -Force
                    }
                    Copy-Item -Path $sourceDir -Destination $targetDir -Recurse -Force -ErrorAction Stop
                }
                catch {
                    Write-Log "ERROR: Copy failed for '$($dir.Name)': $($_.Exception.Message)"
                    continue
                }

                # Validate checksum on target
                $targetChecksum = Get-DirectoryChecksum -DirPath $targetDir
                Write-Log "Target checksum: $targetChecksum"

                if ($targetChecksum -eq $sourceChecksum) {
                    Write-Log "Checksum validation successful for '$($dir.Name)'."
                    # Update checksum table
                    $ChecksumTable | Add-Member -NotePropertyName $dir.Name -NotePropertyValue $sourceChecksum -Force
                    $ChecksumTable | ConvertTo-Json | Out-File $ChecksumFile
                    Write-Log "Updated checksum entry for '$($dir.Name)'."
                }
                else {
                    Write-Log "ERROR: Checksum mismatch after copy for '$($dir.Name)'."
                }
            }
        }

        # Update progress by directory count
        $percent = [math]::Round(($dirIndex / $totalDirs) * 100)
        Set-Progress -Percent $percent -Status "Processing ($dirIndex of $totalDirs)"

        Write-Log "Completed directory: $($dir.Name)"
        Write-Log ""
    }

    Set-Progress -Percent 100 -Status "Complete"
    Write-Log "Run complete. Directories processed: $totalDirs"
    Write-Log "----------------------------------------"
}

# -----------------------------
# Button events
# -----------------------------
$StartButton.Add_Click({
    $SourcePath = $SourceBox.Text.Trim()
    $TargetPath = $TargetBox.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($SourcePath) -or
        [string]::IsNullOrWhiteSpace($TargetPath)) {
        Write-Log "ERROR: Source and Target paths are required."
        return
    }

    $StartButton.IsEnabled  = $false
    $DryRunButton.IsEnabled = $false
    try {
        Invoke-Copy -SourcePath $SourcePath -TargetPath $TargetPath -DryRun:$false
    }
    finally {
        $StartButton.IsEnabled  = $true
        $DryRunButton.IsEnabled = $true
    }
})

$DryRunButton.Add_Click({
    $SourcePath = $SourceBox.Text.Trim()
    $TargetPath = $TargetBox.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($SourcePath) -or
        [string]::IsNullOrWhiteSpace($TargetPath)) {
        Write-Log "ERROR: Source and Target paths are required."
        return
    }

    $StartButton.IsEnabled  = $false
    $DryRunButton.IsEnabled = $false
    try {
        Invoke-Copy -SourcePath $SourcePath -TargetPath $TargetPath -DryRun:$true
    }
    finally {
        $StartButton.IsEnabled  = $true
        $DryRunButton.IsEnabled = $true
    }
})

$CloseButton.Add_Click({
    $Window.Close()
})

# -----------------------------
# Show window
# -----------------------------
$Window.ShowDialog() | Out-Null