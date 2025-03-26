# This script is used for batch extraction of miniTCA logs 2023/12/01
# V3.1 - Optimized version: Using archive internal paths, using 7z x for direct extraction, optional parallel processing (requires PowerShell 7+)
#        New feature: Control whether to apply year-month filtering by log type

# --- Configuration ---
# Set to $true to enable parallel processing (requires PowerShell 7 or higher)
# Set to $false to use optimized sequential processing (compatible with all versions)
$EnableParallelProcessing = $true
# Maximum number of concurrent tasks for parallel processing (recommended to be equal to or slightly greater than CPU core count)
$ParallelThrottleLimit = [System.Environment]::ProcessorCount

# --- Script Initialization ---
$Pth = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $Pth

# Check PowerShell version (if parallel is enabled)
if ($EnableParallelProcessing -and $PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "Parallel processing requires PowerShell 7 or higher. Falling back to sequential processing mode."
    $EnableParallelProcessing = $false
}

# Check if 7-Zip is available
$sevenZipPath = Get-Command 7z.exe -ErrorAction SilentlyContinue
if (-not $sevenZipPath) {
    Write-Error "Error: Cannot find 7z.exe. Please ensure 7-Zip is installed and its path is added to the system PATH environment variable."
    Exit
}
Write-Host "Using 7-Zip: $($sevenZipPath.Source)" -ForegroundColor DarkGray

# --- Function Definitions ---
function New-Folder ($FolderName) {
    # Ensure folder name is not empty
    if ([string]::IsNullOrWhiteSpace($FolderName)) {
        Write-Host "Internal error: Attempted to create a folder with an empty name" -ForegroundColor Red
        return $false # Return failure status
    }

    $folderPath = Join-Path -Path $Pth -ChildPath $FolderName

    # If exists, delete old folder first (ensure clean output)
    if (Test-Path $folderPath) {
        Write-Host "Cleaning up old folder: $FolderName" -ForegroundColor DarkYellow
        try {
            Remove-Item -Recurse -Force $folderPath -ErrorAction Stop
        }
        catch {
            Write-Host "Error: Unable to clean up old folder '$FolderName'. Check permissions or if files are in use. $_" -ForegroundColor Red
            return $false # Return failure status
        }
    }

    # Create new folder
    try {
        New-Item -Path $folderPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
        return $true # Return success status
    }
    catch {
        Write-Host "Error: Failed to create folder '$FolderName'. $_" -ForegroundColor Red
        return $false # Return failure status
    }
}

# Define log types dictionary, including number and corresponding log name (these names must match folder names in the archive)
$LogTypes = @{
    '1' = 'BypassTag'
    '2' = 'ErrorMsg'
    '3' = 'LasConf'
    '4' = 'LasStatistics'
    '5' = 'SWVersions'
    '6' = 'TCActions'
    '7' = 'TCAConf' 
    '8' = 'TCAInfo'
}

# --- New: Define year-month filtering switches ---
# Use log type names as keys (must match values in $LogTypes)
# 1 = Apply year-month filtering for this type (if user inputs yyyy-mm)
# 0 = Do not apply year-month filtering (extract all .txt files, even if yyyy-mm is input)
# Note: If user globally inputs '0' (i.e., $year_month = '*'), then no type will have year-month filtering applied.
$FilterSwitches = @{
    'BypassTag'     = 1
    'ErrorMsg'      = 1
    'LasConf'       = 0
    'LasStatistics' = 1
    'SWVersions'    = 0
    'TCActions'     = 1
    'TCAConf'       = 0
    'TCAInfo'       = 0
}
# Validate that FilterSwitches contains all valid items from LogTypes
foreach ($key in $LogTypes.Keys) {
    $logName = $LogTypes[$key]
    if (-not [string]::IsNullOrWhiteSpace($logName) -and -not $FilterSwitches.ContainsKey($logName)) {
        Write-Warning "Warning: Log type '$logName' is not defined in `$FilterSwitches`, will default to not applying year-month filtering."
        # Can choose to add default value: $FilterSwitches[$logName] = 0
    }
}


# --- User Interaction and Settings ---
Write-Host "
*********************************
***    miniTCA tool V3.1      ***
*********************************
`n`n"

Write-Host "Starting extract miniTcaLogs" -ForegroundColor Yellow -BackgroundColor Black
"`n"

$year_month = $(Get-Date).AddMonths(-1).ToString("yyyy-MM")

write-host "Default year-month filter mode (last month): " -NoNewline
write-host $year_month -ForegroundColor Black -BackgroundColor Yellow

$patter_check = Read-Host "Press 'y' to use default mode, press any other key to enter manually"

if ($patter_check -notin "y", "Y") {
    $year_month = Read-Host "Enter year-month filter mode (yyyy-mm), or enter '0' to extract logs from all times"
}

if ($year_month -eq "0") {
    $year_month = "*" # Use wildcard to match all dates
    Write-Host "Will extract logs from all times (ignoring filter switches for all types)." -ForegroundColor Yellow
}
else {
    if ($year_month -notmatch "^\d{4}-\d{2}$" -and $year_month -ne "*") {
        Write-Warning "Input format may be incorrect, expected format is yyyy-mm or *"
    }
    Write-Host "Global year-month filter mode set to '$year_month'." -ForegroundColor Yellow
    Write-Host "Note: This filtering only applies to types with switch set to 1." -ForegroundColor DarkYellow
}

# --- Main Processing Loop ---
$FormatVar = 0
while (1) {
    if ($FormatVar -ge 1) {
        write-host "`n"
    }
    $FormatVar++

    # Display options menu
    write-host "Select log types to extract (names must match folders in archive):" -ForegroundColor Yellow -BackgroundColor Black
    $menuText = "`n"
    $sortedKeys = $LogTypes.Keys | Sort-Object { [int]$_ } # Sort by numerical order
    foreach ($key in $sortedKeys) {
        # Show current filter status
        $logName = $LogTypes[$key]
        $filterStatus = "(Filter: Off)" # Default display
        if ($FilterSwitches.ContainsKey($logName) -and $FilterSwitches[$logName] -eq 1) {
            $filterStatus = "(Filter: On)"
        }
        $menuText += "    $key : $logName $filterStatus`n" -f $key, $logName, $filterStatus
    }
    $menuText += "    0 : Exit`n"
    Write-Host $menuText

    write-host "You can enter multiple numbers to select multiple types (e.g., 123)" -ForegroundColor Green
    $Select = read-host ">>"

    if ($Select -eq "0") {
        Write-Host "Script exited."
        Exit
    }

    # Validate input
    $SelectArray = $Select.ToCharArray()
    $validInput = $true
    $selectedLogKeys = @()

    foreach ($digit in $SelectArray) {
        $digitStr = [string]$digit
        if (-not $LogTypes.ContainsKey($digitStr)) {
            $validInput = $false
            break
        }
        if ($digitStr -notin $selectedLogKeys) {
            $selectedLogKeys += $digitStr
        }
    }

    if (-not $validInput -or $selectedLogKeys.Count -eq 0) {
        Write-Host "Invalid input! Please enter numbers shown in the menu, or '0' to exit." -ForegroundColor Red
        Continue
    }

    # --- Prepare Extraction Parameters and Environment ---
    Write-Host "`nPreparing extraction..." -ForegroundColor Cyan

    $IncludeSwitches = @()      # Store 7z -ir! parameters
    $SelectedFolderNames = @()  # Store selected folder names for reporting
    $ExtractionPlan = @{}       # Store actual extraction mode for each selected type

    # 1. Clean/create target folders and build 7z include parameters (based on switches to determine mode)
    $allFoldersCreated = $true
    foreach ($key in $selectedLogKeys | Sort-Object { [int]$_ }) {
        $logFolderName = $LogTypes[$key]

        if (-not [string]::IsNullOrWhiteSpace($logFolderName)) {
            # Clean and create output folder
            if (-not (New-Folder($logFolderName))) {
                Write-Error "Unable to create necessary output folder '$logFolderName', extraction aborted."
                $allFoldersCreated = $false
                break
            }
            $SelectedFolderNames += $logFolderName

            # Determine whether to apply year-month filtering
            $applyDateFilterForThisType = $false
            if ($FilterSwitches.ContainsKey($logFolderName)) {
                # Apply filter = switch is 1 AND global mode is not "*"
                $applyDateFilterForThisType = ($FilterSwitches[$logFolderName] -eq 1 -and $year_month -ne "*")
            }
            else {
                Write-Warning "Filter switch for type '$logFolderName' is undefined, defaulting to not applying year-month filtering."
            }

            # Build file matching pattern
            $filePattern = if ($applyDateFilterForThisType) {
                "*$year_month*.txt" # Apply year-month filtering
            }
            else {
                "*.txt" # Don't apply year-month filtering (extract all .txt)
            }
            $ExtractionPlan[$logFolderName] = $filePattern # Record actual pattern used

            # Build 7z include parameter
            $includePattern = "$logFolderName\$filePattern"
            $IncludeSwitches += "-ir!$includePattern"

        }
        else {
            Write-Warning "Skipping key '$key' because its log name is empty."
        }
    }

    # If folder creation failed, return to menu
    if (-not $allFoldersCreated) {
        Continue
    }

    # Display final extraction plan
    Write-Host "Extraction plan:" -ForegroundColor Cyan
    foreach ($folderName in $SelectedFolderNames) {
        Write-Host " - $folderName : Will extract '$($ExtractionPlan[$folderName])'" -ForegroundColor Green
    }
    # Write-Host "7z include parameters: $($IncludeSwitches -join ' ')" # Debug info
    Write-Host "Output folders are ready." -ForegroundColor Green
    "`n"

    # 2. Find compressed files
    $downloadLogsPath = Join-Path -Path $Pth -ChildPath "DownloadLogs"
    if (-not (Test-Path $downloadLogsPath)) {
        Write-Error "Error: Cannot find 'DownloadLogs' directory '$downloadLogsPath'. Please ensure this directory exists in the script location."
        Continue
    }

    $compressedExtensions = @(".zip", ".rar", ".7z")
    Write-Host "Searching for compressed files in '$downloadLogsPath' and its subdirectories..." -ForegroundColor Cyan
    $LogsFileZips = Get-ChildItem -Recurse -Path $downloadLogsPath -File |
    Where-Object { $compressedExtensions -contains $_.Extension }

    if ($LogsFileZips.Count -eq 0) {
        Write-Warning "No supported compressed files (.zip, .rar, .7z) found in '$downloadLogsPath' directory and its subdirectories."
        Continue
    }
    Write-Host "Found $($LogsFileZips.Count) compressed files." -ForegroundColor Green

    # --- Execute Extraction ---
    Write-Host "Starting extraction process... ($($LogsFileZips.Count) files)" -ForegroundColor Yellow

    $startTime = Get-Date
    $processedCount = 0
    $totalArchives = $LogsFileZips.Count

    # --- Choose Processing Method: Parallel or Sequential ---
    # (Core logic for parallel and sequential processing remains unchanged, as $IncludeSwitches is already built based on switches)
    if ($EnableParallelProcessing) {
        # --- Parallel Processing (PowerShell 7+) ---
        Write-Host "Using parallel processing (max concurrency: $ParallelThrottleLimit)..." -ForegroundColor Magenta

        $LogsFileZips | ForEach-Object -Parallel {
            $zipFile = $_
            $currentPth = $using:Pth
            $currentIncludeSwitches = $using:IncludeSwitches
            $total = $using:totalArchives
            $sevenZipExe = $using:sevenZipPath.Source

            $currentCount = [System.Threading.Interlocked]::Increment([ref]$using:processedCount)
            Write-Host "[Thread $ThreadId] Processing $($zipFile.Name) ($currentCount/$total)..." -ForegroundColor DarkCyan

            $arguments = @('x', $zipFile.FullName, "-o$currentPth") + $currentIncludeSwitches + @('-y')

            try {
                & $sevenZipExe $arguments # | Out-Null
            }
            catch {
                Write-Error "[Thread $ThreadId] Error processing compressed file $($zipFile.Name): $_"
            }
        }

    }
    else {
        # --- Sequential Processing (Optimized) ---
        Write-Host "Using sequential processing..." -ForegroundColor Magenta

        foreach ($ZipLog in $LogsFileZips) {
            $processedCount++
            $progressPercentage = [int](($processedCount / $totalArchives) * 100)

            Write-Progress -Activity "Extracting Logs" -Status "Processing file $processedCount of $totalArchives : $($ZipLog.Name)" `
                -PercentComplete $progressPercentage

            Write-Host ("-" * 60) -ForegroundColor DarkGray
            Write-Host "Processing: $($ZipLog.Name) [$processedCount/$totalArchives]" -ForegroundColor DarkCyan

            $arguments = @('x', $ZipLog.FullName, "-o$Pth") + $IncludeSwitches + @('-y')

            try {
                & $sevenZipPath.Source $arguments # | Out-Null
                # if ($LASTEXITCODE -ne 0) { Write-Warning "7z processing $($ZipLog.Name) may have errors (exit code: $LASTEXITCODE)" }
            }
            catch {
                Write-Warning "Error processing compressed file $($ZipLog.Name): $_"
            }
            Write-Host ("-" * 60) -ForegroundColor DarkGray
        }
        Write-Progress -Activity "Extracting Logs" -Completed
    }

    # --- Cleanup and Summary ---
    $endTime = Get-Date
    $duration = $endTime - $startTime

    Write-Host "`nExtraction process complete!" -ForegroundColor Green
    Write-Host "Total time: $($duration.ToString()) ($($duration.TotalSeconds.ToString('F2')) seconds)" -ForegroundColor Green

    Write-Host "All selected log files have been extracted to their respective folders based on type filter settings." -ForegroundColor Green
    # Loop will continue
}

# --- Script End ---
