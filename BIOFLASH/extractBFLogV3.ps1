# BF log export tool 3.0 - Refactored
# 优化版本：多线程处理、减少IO、改进临时文件存储、文件缺失/错误记录、参数化、健壮性提升

param(
    [Parameter(Mandatory = $false, HelpMessage = "Specify the working directory. Defaults to the script's parent directory.")]
    [string]$WorkPath = (Split-Path -Parent $MyInvocation.MyCommand.Definition),

    [Parameter(Mandatory = $false, HelpMessage = "Name of the directory containing the compressed log packages.")]
    [string]$DownloadLogsDirName = "DownloadLogs",

    [Parameter(Mandatory = $false, HelpMessage = "Name of the output directory for InstrumentLog text files.")]
    [string]$InstrumentLogDirName = "InstrumentLog",

    [Parameter(Mandatory = $false, HelpMessage = "Name of the output directory for report HTML files.")]
    [string]$TestVLReportDirName = "testvl_report",

    [Parameter(Mandatory = $false, HelpMessage = "Name of the output directory for InstrumentLog JSON files.")]
    [string]$JsonLogsDirName = "JsonLogs",

    [Parameter(Mandatory = $false, HelpMessage = "Full path to 7z.exe if not in PATH.")]
    [string]$SevenZipPath = "7z.exe", # Default assumes 7z.exe is in PATH

    [Parameter(Mandatory = $false, HelpMessage = "Maximum number of concurrent threads.")]
    [int]$MaxThreads = ($env:NUMBER_OF_PROCESSORS + 1)
)

# --- Script Configuration & Constants ---
$InstrumentLogFilter = "InstrumentLog*" # Covers .txt, .json, etc.
$ReportFilter = "*Report*htm" # Covers .htm, .html

# --- Helper Functions ---

Function Get-TargetFolderInteractive {
    # Keep the interactive folder selection if needed
    try {
        [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
        $FolderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $FolderBrowserDialog.Description = "Select the Working Directory (containing $DownloadLogsDirName)"
        if ($FolderBrowserDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            return $FolderBrowserDialog.SelectedPath
        }
        else {
            Write-Warning "Folder selection cancelled."
            return $null
        }
    }
    catch {
        Write-Error "Failed to load Windows Forms for folder selection: $_"
        return $null
    }
}

# Ensures a directory exists and is empty. Creates it if not present, deletes content if it exists.
function Ensure-EmptyDirectory {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath
    )
    try {
        if (Test-Path $DirectoryPath) {
            Write-Verbose "Removing existing directory: $DirectoryPath"
            Remove-Item -Recurse -Force $DirectoryPath -ErrorAction Stop
        }
        Write-Verbose "Creating directory: $DirectoryPath"
        New-Item -Path $DirectoryPath -ItemType Directory -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error "Failed to ensure empty directory '$DirectoryPath': $_"
        throw "Failed to prepare directory: $DirectoryPath. Check permissions and path validity." # Re-throw to stop script if critical directories fail
    }
}

# --- Initial Setup & Validation ---

# Check if 7z is available
$SevenZipExe = Get-Command $SevenZipPath -ErrorAction SilentlyContinue
if (-not $SevenZipExe) {
    Write-Error "7z.exe not found at '$SevenZipPath' or in PATH. Please install 7-Zip or specify the correct path using the -SevenZipPath parameter."
    Exit 1
}
else {
    $SevenZipPath = $SevenZipExe.Source # Use the full path found
    Write-Host "Using 7-Zip: $SevenZipPath" -ForegroundColor Cyan
}

# Determine and validate WorkPath if not provided via parameter
if ($PSBoundParameters.ContainsKey('WorkPath') -eq $false) {
    # If default path is used, confirm or allow selection
    Write-Host "Current default Work Path: $WorkPath"
    Write-Host "Is this correct?`n1 : Yes, use this path`n2 : No, select another folder"
    while ($True) {
        $pathSelection = Read-Host ">>"
        if ($pathSelection -eq 1) {
            break
        }
        elseif ($pathSelection -eq 2) {
            Write-Host "Select the Working Directory..." -ForegroundColor Yellow -BackgroundColor Black
            $selectedPath = Get-TargetFolderInteractive
            if ($selectedPath) {
                $WorkPath = $selectedPath
                break
            }
            else {
                Write-Error "Folder selection failed or was cancelled. Exiting."
                Exit 1
            }
        }
        else {
            Write-Host "Input 1 or 2!!" -BackgroundColor Blue -ForegroundColor Red
        }
    }
}

Write-Host "Final Work Path: $WorkPath" -ForegroundColor Yellow -BackgroundColor Black
try {
    Set-Location $WorkPath -ErrorAction Stop
}
catch {
    Write-Error "Failed to set location to '$WorkPath': $_"
    Exit 1
}

$DownloadLogsPath = Join-Path $WorkPath $DownloadLogsDirName
if (-not (Test-Path $DownloadLogsPath -PathType Container)) {
    Write-Error "Download logs directory not found: '$DownloadLogsPath'. Please ensure it exists or specify the correct name/path."
    Exit 1
}

# --- Main Processing Logic ---

Write-Host @"

*************************************************************
***            BIO-FLASH Log Extraction Tool             ***
*************************************************************

"@

Write-Host "Start processing logs from '$DownloadLogsPath'?" -ForegroundColor Yellow -BackgroundColor Black
$flag = Read-Host "Y/y for Yes, N/n to Exit "
if ($flag -ne "Y" -and $flag -ne "y") {
    Write-Host "Operation cancelled by user."
    Exit 0
}

# --- Start Processing ---
$startTime = Get-Date
Write-Host "Process started at: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan

$sourceLogPackages = Get-ChildItem -Path $DownloadLogsPath | Where-Object { $_.Extension -like ".rar" -or $_.Extension -like ".zip" -or $_.Extension -like ".7z" }
if ($null -eq $sourceLogPackages -or $sourceLogPackages.Count -eq 0) {
    Write-Warning "No compressed log files (.rar, .zip, .7z) found in '$DownloadLogsPath'."
    Write-Host "Any Key to Exit..."
    [System.Console]::ReadKey() | Out-Null
    Exit 0
}
else {
    Write-Host "Found $($sourceLogPackages.Count) packages to process."
}

# Prepare Output Directories
$InstrumentLogPath = Join-Path $WorkPath $InstrumentLogDirName
$TestVLReportPath = Join-Path $WorkPath $TestVLReportDirName
$JsonLogsPath = Join-Path $WorkPath $JsonLogsDirName

Ensure-EmptyDirectory $InstrumentLogPath
Ensure-EmptyDirectory $TestVLReportPath
Ensure-EmptyDirectory $JsonLogsPath

# Prepare Temporary Directory (unique name)
$tempDirName = "BF_Extract_Temp_" + [Guid]::NewGuid().ToString().Substring(0, 8)
$tempDir = Join-Path $WorkPath $tempDirName
Ensure-EmptyDirectory $tempDir # Create the main temp dir

# --- Threading Setup ---
$sessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$runspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads, $sessionState, $Host)
$runspacePool.Open()

$runspaces = @()
$progressCounter = 0

# Create thread-safe dictionary for results (including errors and missing files)
$resultsCollection = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()

# --- Script Block for Thread ---
$scriptBlock = {
    param (
        [string]$PackageFullName,
        [string]$PackageBaseName,
        [string]$CurrentWorkPath,
        [string]$MainTempDirPath,
        [string]$CmdSevenZipPath,
        [string]$DestInstrumentLogPath,
        [string]$DestTestVLReportPath,
        [string]$DestJsonLogsPath,
        [string]$LogFilter,
        [string]$ReportFilter,
        [System.Collections.Concurrent.ConcurrentDictionary[string, object]]$OutputResultsCollection # Pass the collection
    )

    $packageResult = @{
        PackageName          = $PackageBaseName
        Status               = "Processing" # Initial status
        MissingInstrumentLog = $false
        MissingReport        = $false
        ErrorMessage         = $null
    }

    # Create specific temporary directory for this package
    $packageTempDir = Join-Path $MainTempDirPath $PackageBaseName
    try {
        New-Item -ItemType Directory -Path $packageTempDir -Force -ErrorAction Stop | Out-Null
    }
    catch {
        $packageResult.Status = "Error"
        $packageResult.ErrorMessage = "Failed to create package temp directory '$packageTempDir': $_"
        $OutputResultsCollection[$PackageBaseName] = $packageResult
        return # Cannot proceed
    }

    try {
        # 1. Extract required files using Start-Process for better error handling
        $extractArgs = @(
            "e", # Extract files with full paths (preserves directory structure within archive if needed, though 'e' often flattens)
            "`"$PackageFullName`"",
            "-o`"$packageTempDir`"",
            "-r", # Recurse subdirectories in archive
            "-ir!$LogFilter", # Include InstrumentLog files
            "-ir!$ReportFilter", # Include Report files
            "-aos" # Skip extracting existing files (overwrite if needed? use -aoa)
        )
        Write-Verbose "Executing: $CmdSevenZipPath $extractArgs"
        $process = Start-Process -FilePath $CmdSevenZipPath -ArgumentList $extractArgs -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue # Catch execution errors

        if ($null -eq $process) {
            throw "Failed to start 7z process. Check path and permissions."
        }
        if ($process.ExitCode -ne 0) {
            throw "7z extraction failed with exit code $($process.ExitCode). Check 7z output/logs if possible, or archive integrity."
        }
        Write-Verbose "Extraction successful for $PackageBaseName"
        $packageResult.Status = "ExtractionCompleted"

        # 2. Process InstrumentLog file
        $tempLog = Get-ChildItem -Path $packageTempDir -Recurse -Filter $LogFilter -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($tempLog) {
            $destinationPath = ""
            try {
                if ($tempLog.Extension -eq ".json") {
                    $destinationPath = Join-Path $DestJsonLogsPath ($PackageBaseName + ".json")
                    Copy-Item -Path $tempLog.FullName -Destination $destinationPath -Force -ErrorAction Stop
                }
                else {
                    # Assume .txt or other format for the main InstrumentLog directory
                    $destinationPath = Join-Path $DestInstrumentLogPath ($PackageBaseName + $tempLog.Extension) # Keep original extension
                    Copy-Item -Path $tempLog.FullName -Destination $destinationPath -Force -ErrorAction Stop
                }
                Write-Verbose "Copied $($tempLog.Name) to $destinationPath"
            }
            catch {
                $packageResult.Status = "CopyError"
                $packageResult.ErrorMessage = "Failed to copy InstrumentLog '$($tempLog.Name)' to '$destinationPath': $_"
                # Continue to check report file
            }
        }
        else {
            $packageResult.MissingInstrumentLog = $true
            Write-Verbose "InstrumentLog file not found in extracted files for $PackageBaseName"
        }

        # 3. Process Report file
        $tempReport = Get-ChildItem -Path $packageTempDir -Recurse -Filter $ReportFilter -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($tempReport) {
            $destinationPath = ""
            try {
                $destinationPath = Join-Path $DestTestVLReportPath ($PackageBaseName + $tempReport.Extension) # Keep original extension (.htm or .html)
                Copy-Item -Path $tempReport.FullName -Destination $destinationPath -Force -ErrorAction Stop
                Write-Verbose "Copied $($tempReport.Name) to $destinationPath"
            }
            catch {
                # If already in CopyError state, append message maybe? Or just keep first error.
                if ($packageResult.Status -ne "CopyError") { $packageResult.Status = "CopyError" }
                $packageResult.ErrorMessage = ($packageResult.ErrorMessage + " `n " + "Failed to copy Report '$($tempReport.Name)' to '$destinationPath': $_").Trim()
            }
        }
        else {
            $packageResult.MissingReport = $true
            Write-Verbose "Report file not found in extracted files for $PackageBaseName"
        }

        # Final status update if no errors occurred
        if ($packageResult.Status -notin ("Error", "CopyError")) {
            if ($packageResult.MissingInstrumentLog -or $packageResult.MissingReport) {
                $packageResult.Status = "CompletedWithMissingFiles"
            }
            else {
                $packageResult.Status = "CompletedSuccessfully"
            }
        }

    }
    catch {
        # Catch errors from Start-Process or other operations within the main try block
        $packageResult.Status = "Error"
        $packageResult.ErrorMessage = "Processing failed for '$PackageBaseName': $_"
    }
    finally {
        # Clean up the specific temporary directory for this package
        if (Test-Path $packageTempDir) {
            try {
                Remove-Item -Recurse -Force $packageTempDir -ErrorAction Stop
                Write-Verbose "Cleaned up temp directory: $packageTempDir"
            }
            catch {
                # Log cleanup error but don't overwrite primary result status if it was successful
                Write-Warning "Failed to clean up package temp directory '$packageTempDir': $_"
                if ($packageResult.Status -notin ("Error", "CopyError")) {
                    # Add a note about cleanup failure? Maybe not critical for the result itself.
                }
            }
        }
        # Store the final result for this package
        $OutputResultsCollection[$PackageBaseName] = $packageResult
    }
    # This return is implicit as the last statement's output would be returned,
    # but we are directly modifying the shared collection instead.
}

# --- Task Dispatching ---
foreach ($package in $sourceLogPackages) {
    $originalName = $package.FullName
    $baseName = $package.BaseName
    $correctedName = $originalName

    # Check and attempt to fix filename with space before extension
    if ($originalName -match " \.[^\\\/]*$") {
        try {
            $correctedName = $originalName -replace " \.", "."
            $correctedBaseName = $baseName.TrimEnd()

            Write-Host "Found space before extension: '$originalName'" -ForegroundColor Yellow
            Write-Host "Attempting rename to: '$correctedName'" -ForegroundColor Yellow

            Rename-Item -Path $originalName -NewName $correctedName -ErrorAction Stop
            $package = Get-Item -Path $correctedName # Update the file object
            $baseName = $correctedBaseName          # Update the base name for this iteration
            Write-Host "Rename successful for '$correctedName'" -ForegroundColor Green
        }
        catch {
            Write-Warning "Rename failed for '$originalName': $_. Processing with original name."
            # Keep original $package and $baseName
            $correctedName = $originalName # Revert correctedName if rename failed
        }
    }

    Write-Host ("Queuing: " + $baseName) -BackgroundColor Black -ForegroundColor White

    $powerShell = [powershell]::Create().AddScript($scriptBlock).AddParameters(@{
            PackageFullName         = $package.FullName # Use the potentially updated full name
            PackageBaseName         = $baseName         # Use the potentially updated base name
            CurrentWorkPath         = $WorkPath
            MainTempDirPath         = $tempDir
            CmdSevenZipPath         = $SevenZipPath
            DestInstrumentLogPath   = $InstrumentLogPath
            DestTestVLReportPath    = $TestVLReportPath
            DestJsonLogsPath        = $JsonLogsPath
            LogFilter               = $InstrumentLogFilter
            ReportFilter            = $ReportFilter
            OutputResultsCollection = $resultsCollection # Pass the shared dictionary
        })

    $powerShell.RunspacePool = $runspacePool

    $runspaces += [PSCustomObject]@{
        PowerShell = $powerShell
        Handle     = $powerShell.BeginInvoke()
        Package    = $baseName # Store the base name for reporting
    }
}

# --- Monitor and Collect Results ---
$totalPackages = $sourceLogPackages.Count
do {
    $completedRunspaces = @($runspaces | Where-Object { $_.Handle.IsCompleted })

    foreach ($runspace in $completedRunspaces) {
        try {
            # EndInvoke captures any exceptions thrown *from* the runspace/scriptblock itself
            $runspace.PowerShell.EndInvoke($runspace.Handle)
        }
        catch {
            # This catches errors during EndInvoke or unhandled exceptions from the thread
            Write-Warning "Error retrieving result for package '$($runspace.Package)': $_"
            # Ensure a result object exists even if EndInvoke failed, marking it as an error
            if (-not $resultsCollection.ContainsKey($runspace.Package)) {
                $resultsCollection[$runspace.Package] = @{
                    PackageName          = $runspace.Package
                    Status               = "Error"
                    ErrorMessage         = "Failed during result retrieval: $_"
                    MissingInstrumentLog = $false # Unknown
                    MissingReport        = $false      # Unknown
                }
            }
        }

        $progressCounter++
        $packageName = $runspace.Package # Get package name from the tracking object
        $result = $resultsCollection[$packageName] # Get the result object populated by the script block

        # --- Enhanced Progress Reporting ---
        $statusColor = "Green" # Default for success
        $statusMessage = "$($result.Status)"
        $details = ""

        switch ($result.Status) {
            "CompletedSuccessfully" { $statusColor = "Green" }
            "CompletedWithMissingFiles" {
                $statusColor = "Yellow"
                $missingItems = @()
                if ($result.MissingInstrumentLog) { $missingItems += "InstrumentLog" }
                if ($result.MissingReport) { $missingItems += "Report" }
                $details = " (Missing: $($missingItems -join ', '))"
            }
            "Error" {
                $statusColor = "Red"
                $details = " (Error: $($result.ErrorMessage -split '[`r`n]')[0])" # Show first line of error
            }
            "CopyError" {
                $statusColor = "Red"
                $details = " (Copy Error: $($result.ErrorMessage -split '[`r`n]')[0])"
            }
            default {
                # Handle unexpected status or Processing if somehow retrieved early
                $statusColor = "Magenta"
                $details = " (Status: $($result.Status))"
            }
        }

        Write-Host ("[$progressCounter/$totalPackages] Package: " + $packageName + " - Status: " + $statusMessage + $details) -ForegroundColor $statusColor

        # Dispose PowerShell instance
        $runspace.PowerShell.Dispose()
    }

    # Remove completed runspaces from the tracking list
    $runspaces = @($runspaces | Where-Object { -not $_.Handle.IsCompleted })

    # Brief pause to reduce CPU load
    if ($runspaces.Count -gt 0) {
        Start-Sleep -Milliseconds 200
    }
} while ($runspaces.Count -gt 0)

# --- Final Cleanup ---
$runspacePool.Close()
$runspacePool.Dispose()

if (Test-Path $tempDir) {
    try {
        Remove-Item -Recurse -Force $tempDir -ErrorAction Stop
        Write-Host "Main temporary directory cleaned up: $tempDirName" -ForegroundColor Yellow
    }
    catch {
        Write-Warning "Failed to clean up main temporary directory '$tempDir': $_"
    }
}

# --- Summary Report ---
$endTime = Get-Date
$duration = $endTime - $startTime
Write-Host "`n--- Processing Summary ---" -ForegroundColor Cyan
Write-Host "Started:   $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "Completed: $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "Duration:  $($duration.ToString('hh\:mm\:ss'))"
Write-Host "Total packages attempted: $totalPackages"

# Detailed Summary Table
$summaryList = @()
$errorCount = 0
$missingCount = 0

foreach ($packageName in $resultsCollection.Keys) {
    $res = $resultsCollection[$packageName]
    $summaryList += [PSCustomObject]@{
        PackageName          = $res.PackageName
        Status               = $res.Status
        MissingInstrumentLog = if ($res.MissingInstrumentLog) { "Yes" } else { "No" }
        MissingReport        = if ($res.MissingReport) { "Yes" } else { "No" }
        ErrorMessage         = $res.ErrorMessage
    }
    if ($res.Status -like "*Error*") { $errorCount++ }
    if ($res.MissingInstrumentLog -or $res.MissingReport) { $missingCount++ } # Count packages with *any* missing file
}

Write-Host "`n--- Results Details ---" -ForegroundColor Cyan
# Sort by PackageName for consistent output
$summaryList = $summaryList | Sort-Object PackageName

# Display using Format-Table
$summaryList | Format-Table -AutoSize -Wrap

# Final counts
Write-Host "`nPackages processed successfully (all files found): $($totalPackages - $errorCount - $missingCount)" -ForegroundColor Green
Write-Host "Packages completed with missing files: $missingCount" -ForegroundColor Yellow
Write-Host "Packages failed with errors: $errorCount" -ForegroundColor Red

# List specific errors if any
if ($errorCount -gt 0) {
    Write-Host "`n--- Packages with Errors ---" -ForegroundColor Red
    $summaryList | Where-Object { $_.Status -like "*Error*" } | Format-Table PackageName, ErrorMessage -AutoSize -Wrap
}

# List specific missing files if any (and no error)
if ($missingCount -gt 0) {
    Write-Host "`n--- Packages with Missing Files (Completed without Errors) ---" -ForegroundColor Yellow
    $summaryList | Where-Object { $_.Status -eq "CompletedWithMissingFiles" } | Format-Table PackageName, MissingInstrumentLog, MissingReport -AutoSize
}

# Count JSON logs found
try {
    $jsonLogs = Get-ChildItem -Path $JsonLogsPath -Filter *.json -File -ErrorAction SilentlyContinue
    Write-Host "`nJSON logs found in '$JsonLogsPath': $($jsonLogs.Count)"
}
catch {
    Write-Warning "Could not count JSON logs in '$JsonLogsPath': $_"
}

Write-Host "`n********** BIOFLASH Log Extraction Finished **********" -ForegroundColor Yellow -BackgroundColor Black
Write-Host "Review the summary above for details on errors or missing files."
Write-Host "Any Key to Exit..."
[System.Console]::ReadKey() | Out-Null ; Exit 0