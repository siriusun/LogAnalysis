#name: extractTopLogV2.ps1
#version: 1.0
#author: SunZhe
#description: Extract TopLog files from DBX files

Function Get-FileName {  
    #[System.Reflection.Assembly]::Load("System.Windows.Forms") | Out-Null
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    $OpenFileDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.SelectedPath
}


function New-Folder {
    param (
        $NewFolderName
    )
    if (Test-Path $NewFolderName) {
        Remove-Item -Recurse $NewFolderName
    }
    New-Item -Path $work_pth -ItemType Directory -Name $NewFolderName
}

while ($True) {
    Write-Host "How to Get Work Path:`n1 : Current Folder`n2 : Select one"
    $pth = Read-Host ">>"

    if ($pth -eq 1) {
        $work_pth = Split-Path -Parent $MyInvocation.MyCommand.Definition
        break
    }
    elseif ($pth -eq 2) {
        Write-Host "Select the Data folder..." -ForegroundColor Yellow -BackgroundColor Black
        $work_pth = Get-FileName
        break
    }
    else {
        Write-Host "Input 1/2!!" -BackgroundColor Blue -ForegroundColor Red
    }
}
Write-Host "Work Path: $work_pth" -ForegroundColor Yellow -BackgroundColor Black
Set-Location $work_pth
# $date_time =  Get-Date -Format "yyyy-MM-dd_hh-mm-ss"
# Start-Transcript "Ps_log_$date_time.txt"

Write-Host 
"*************************************************************
***  ACL TOP log exported by DBExtract.1.21 or SiteAgent  ***
*************************************************************`n`n"

Write-Host "Starting to decompress Source TopLogs?" -ForegroundColor Yellow -BackgroundColor Black
$flag = Read-Host "Y/y for start from DownloadLogs, N/n for SourceLogs"
if ($flag -eq "Y" -or $flag -eq "y") {
    $checklogs = Get-ChildItem -Path ($work_pth.ToString() + "\DownloadLogs\") -Recurse -Include *.rar, *.zip, *.7z
    if ($null -eq $checklogs) {
        "No log files found. Any Key to Exit..."
        [System.Console]::ReadKey() | Out-Null ; Exit
    }

    New-Folder("SourceLogs")

    # Get thread count, default to processor core count
    $maxThreads = [Environment]::ProcessorCount
    Write-Host "Using $maxThreads threads for parallel processing" -ForegroundColor Cyan
    
    # Step 1: Parallel processing of DBX files copying
    Write-Host "Copying DBX files to SourceLogs folder in parallel..." -ForegroundColor Yellow
    $toplog_DBXs = Get-ChildItem -Path ($work_pth + "\DownloadLogs\") -Recurse -Filter *DBX_*_????-??-??_??-??-??*.zip
    if ($null -ne $toplog_DBXs) {
        # Create RunspacePool
        $copySessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        $copyRunspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $maxThreads, $copySessionState, $Host)
        $copyRunspacePool.Open()
        
        # Define copy script block
        $copyScriptBlock = {
            param($sourceFile, $destFolder)
            $destPath = Join-Path $destFolder (Split-Path $sourceFile -Leaf)
            Copy-Item -Path $sourceFile -Destination $destPath
        }
        
        # Create and execute all copy tasks
        $copyHandles = @()
        foreach ($toplog_DBX in $toplog_DBXs) {
            $powershell = [powershell]::Create().AddScript($copyScriptBlock)
            [void]$powershell.AddParameter("sourceFile", $toplog_DBX.FullName)
            [void]$powershell.AddParameter("destFolder", "$work_pth\SourceLogs")
            $powershell.RunspacePool = $copyRunspacePool
            
            $handle = [PSCustomObject]@{
                Powershell = $powershell
                Handle     = $powershell.BeginInvoke()
            }
            $copyHandles += $handle
        }
        
        # Wait for all copies to complete
        Write-Host "Waiting for file copying to complete..." -ForegroundColor Cyan
        do {
            $stillRunning = $false
            foreach ($handle in $copyHandles) {
                if (-not $handle.Handle.IsCompleted) {
                    $stillRunning = $true
                    break
                }
            }
            if ($stillRunning) {
                Start-Sleep -Milliseconds 100
            }
        } while ($stillRunning)
        
        # Clean up resources
        foreach ($handle in $copyHandles) {
            try {
                $null = $handle.Powershell.EndInvoke($handle.Handle)
            }
            finally {
                $handle.Powershell.Dispose()
            }
        }
        $copyRunspacePool.Close()
        $copyRunspacePool.Dispose()
    }
    
    # Step 2: Parallel processing of secondary compressed files
    Write-Host "Processing secondary compressed files in parallel..." -ForegroundColor Yellow
    $source_log_packages = Get-ChildItem -Path ($work_pth.ToString() + "\DownloadLogs\") -Recurse -Include *.rar, *.zip, *.7z | Where-Object { $_.Name -notmatch "DBX" }
    
    if ($source_log_packages.Count -gt 0) {
        # Create RunspacePool
        $extractSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        $extractRunspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $maxThreads, $extractSessionState, $Host)
        $extractRunspacePool.Open()
        
        # Define extraction script block
        $extractScriptBlock = {
            param($packageFile, $outputFolder, $index, $total)
            $packageName = Split-Path $packageFile -Leaf
            $targetFolder = Join-Path $outputFolder (Split-Path $packageFile -LeafBase)
            $remaining = $total - $index
            
            Write-Host (">>>>: $remaining remaining, Processing: $packageName") -BackgroundColor Black -ForegroundColor Yellow
            & 7z.exe e $packageFile "-o$targetFolder" -ir!*DBX*.zip -aos
        }
        
        # Create and execute all extraction tasks
        $extractHandles = @()
        $totalFiles = $source_log_packages.Count
        $counter = 0
        
        foreach ($source_log_package in $source_log_packages) {
            $counter++
            $powershell = [powershell]::Create().AddScript($extractScriptBlock)
            [void]$powershell.AddParameter("packageFile", $source_log_package.FullName)
            [void]$powershell.AddParameter("outputFolder", "$work_pth\SourceLogs")
            [void]$powershell.AddParameter("index", $counter)
            [void]$powershell.AddParameter("total", $totalFiles)
            $powershell.RunspacePool = $extractRunspacePool
            
            $handle = [PSCustomObject]@{
                Index      = $counter
                Powershell = $powershell
                Handle     = $powershell.BeginInvoke()
            }
            $extractHandles += $handle
        }
        
        # Wait for all extractions to complete
        Write-Host "Waiting for file extraction to complete..." -ForegroundColor Cyan
        do {
            $stillRunning = $false
            foreach ($handle in $extractHandles) {
                if (-not $handle.Handle.IsCompleted) {
                    $stillRunning = $true
                    break
                }
            }
            if ($stillRunning) {
                Start-Sleep -Milliseconds 100
            }
        } while ($stillRunning)
        
        # Clean up resources
        foreach ($handle in $extractHandles) {
            try {
                $null = $handle.Powershell.EndInvoke($handle.Handle)
            }
            finally {
                $handle.Powershell.Dispose()
            }
        }
        $extractRunspacePool.Close()
        $extractRunspacePool.Dispose()
    }
    
    Write-Host "All files processing completed!" -ForegroundColor Green
}

function Get-LogTypeInfo {
    $logTypes = @{
        "1" = @{
            "name" = "GeneralLogs"
            "file" = "generalLog.txt"
        }
        "2" = @{
            "name" = "SoftwareVersions"
            "file" = "sw_all_versions.txt"
        }
        "3" = @{
            "name" = "taskList"
            "file" = "TASKLIST.txt"
        }
        "4" = @{
            "name" = "CountersForAllTest"
            "file" = "countersForAllTestTypesDeterminations.txt"
        }
        "5" = @{
            "name" = "InstrumentStatus"
            "file" = "instrumentStatusStatistics.txt"
        }
        "6" = @{
            "name" = "globalDefinitions"
            "file" = "globalDefinitions.txt"
        }
        "7" = @{
            "name" = "HIL"
            "file" = "countersHIL.txt"
        }
    }
    return $logTypes
}

function Show-Menu {
    Write-Host "`nSelect log types to generate (enter multiple numbers, e.g., 123):" -ForegroundColor Yellow -BackgroundColor Black
    
    $logTypes = Get-LogTypeInfo
    
    # Display all log type options dynamically
    foreach ($key in $logTypes.Keys | Sort-Object) {
        Write-Host "$key : $($logTypes[$key].name)"
    }
    
    # Add exit option
    Write-Host "0 : Exit"
}

function Invoke-LogExtraction {
    param (
        [string]$selections,
        [string]$work_pth
    )

    $logTypes = Get-LogTypeInfo

    # Add error handling and logging
    Write-Host "Scanning DBX files in $work_pth\SourceLogs" -ForegroundColor Cyan

    # Get all DBX files
    $toplog_DBXs = Get-ChildItem -Path ($work_pth + "\SourceLogs\") -Recurse -Filter *DBX*.zip
    if ($null -eq $toplog_DBXs -or $toplog_DBXs.Count -eq 0) {
        Write-Host "No DBX files found in SourceLogs directory!" -ForegroundColor Red
        return
    }

    Write-Host "Found $($toplog_DBXs.Count) DBX files" -ForegroundColor Green

    # Create dictionary to track each SN's corresponding log files
    $snLogDict = @{}

    # Preprocess all DBX files, group by SN
    foreach ($toplog_DBX in $toplog_DBXs) {
        $nameParts = $toplog_DBX.Name.Split("_")
        
        # Parse different log filename formats, supporting two formats
        # Format 1: CHINA_ACLTOP_700LAS_15120236_00000280000_DBX_15120236_2025-03-01_13-00-03_-480
        # Format 2: DBX_15120236_2025-03-01_13-00-03_-480
        $sn = $null
        $dateTime = $null
        
        if ($nameParts[0] -eq "DBX" -and $nameParts.Length -ge 4) {
            # Format 2: DBX_15120236_2025-03-01_13-00-03_-480
            $sn = $nameParts[1]
            $dateTime = $nameParts[2]
        }
        elseif ($nameParts.Length -ge 7 -and $toplog_DBX.Name -match "_DBX_") {
            # Format 1: CHINA_ACLTOP_700LAS_15120236_00000280000_DBX_15120236_2025-03-01_13-00-03_-480
            $namepart_sa = $toplog_DBX.Name.Split("_DBX_")[1].Split("_")
            $sn = $namepart_sa[0]
            $dateTime = $namepart_sa[1]
        }
        else {
            Write-Host "Unrecognized filename format: $($toplog_DBX.Name), skipping..." -ForegroundColor Yellow
            continue
        }
        
        if (-not $snLogDict.ContainsKey($sn)) {
            $snLogDict[$sn] = @()
        }
        $snLogDict[$sn] += $toplog_DBX
    }

    # Filter and get selected log types (adding debug info and type fixing)
    Write-Host "You selected: $selections" -ForegroundColor Cyan
    $selectedLogTypes = @()

    foreach ($char in $selections.ToCharArray()) {
        # Convert character to string to ensure type matching
        $keyStr = $char.ToString()
        Write-Host "Processing selection: $keyStr" -ForegroundColor DarkGray
    
        # Display available keys to help debugging
        Write-Host "  Available keys: $($logTypes.Keys -join ', ')" -ForegroundColor DarkGray
    
        if ($keyStr -ne '0' -and $logTypes.ContainsKey($keyStr)) {
            Write-Host "  + Adding log type: $($logTypes[$keyStr].name)" -ForegroundColor Green
            $selectedLogTypes += $logTypes[$keyStr]
        }
        else {
            Write-Host "  - Ignoring invalid selection: $keyStr" -ForegroundColor Yellow
        }
    }

    Write-Host "Selected $($selectedLogTypes.Count) log types" -ForegroundColor Cyan

    if ($selectedLogTypes.Count -eq 0) {
        Write-Host "No valid log types selected!" -ForegroundColor Red
        return
    }

    # Create all needed target folders
    foreach ($logType in $selectedLogTypes) {
        New-Folder $logType.name
        Write-Host "Created folder for $($logType.name)" -ForegroundColor Green
    }

    # Display processing information
    Write-Host "Will extract $($selectedLogTypes.Count) log types from each DBX file" -ForegroundColor Cyan

    # Setup multithreaded processing
    $maxThreads = [Environment]::ProcessorCount
    Write-Host "Using $maxThreads threads for DBX file extraction" -ForegroundColor Cyan
    
    # Implement true multithreading with RunspacePool
    $sessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    $runspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $maxThreads, $sessionState, $Host)
    $runspacePool.Open()
    
    # Define processing function
    $scriptBlock = {
        param(
            [string]$DBXFilePath,
            [string]$workPath,
            [array]$logTypes,
            [int]$jobIndex,
            [int]$totalFiles
        )
        
        # Create file object
        $toplog_DBX = Get-Item -Path $DBXFilePath
        
        Write-Host "`nProcessing file $jobIndex/$totalFiles`: $($toplog_DBX.Name)" -ForegroundColor Cyan
        
        # Parse filename to get SN and date/time
        $nameParts = $toplog_DBX.Name.Split("_")
        $sn = $null
        $dateTime = $null
        
        if ($nameParts[0] -eq "DBX" -and $nameParts.Length -ge 4) {
            # Format 2: DBX_15120236_2025-03-01_13-00-03_-480
            $sn = $nameParts[1]
            $dateTime = $nameParts[2]
        }
        elseif ($nameParts.Length -ge 7 -and $toplog_DBX.Name -match "_DBX_") {
            # 格式1: CHINA_ACLTOP_700LAS_15120236_00000280000_DBX_15120236_2025-03-01_13-00-03_-480
            $namepart_sa = $toplog_DBX.Name.Split("_DBX_")[1].Split("_")
            $sn = $namepart_sa[0]
            $dateTime = $namepart_sa[1]
        }
        else {
            Write-Host "Invalid filename format: $($toplog_DBX.Name), skipping..." -ForegroundColor Yellow
            return
        }
        
        # Create temporary directory
        $tempFolderName = "temp_extract_" + [System.Guid]::NewGuid().ToString()
        $tempPath = Join-Path $workPath $tempFolderName
        New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
        
        try {
            # Build extraction parameters
            $extractParams = @()
            foreach ($logType in $logTypes) {
                $extractParams += "-ir!$($logType.file)"
            }
            
            # Display processing information
            Write-Host "Extracting from $($toplog_DBX.Name), SN: $sn" -ForegroundColor Yellow
            
            # Execute extraction
            $7zArgs = @("e", $toplog_DBX.FullName, "-pfixmeplease", "-o$tempPath", "-aos") + $extractParams
            $7zOutput = & 7z.exe $7zArgs 2>&1
            $exitCode = $LASTEXITCODE
            
            # Process results
            if ($exitCode -eq 0) {
                $extractedCount = 0
                
                # Process each log type
                foreach ($logType in $logTypes) {
                    $sourceFile = Join-Path $tempPath $logType.file
                    if (Test-Path $sourceFile) {
                        $targetFolder = Join-Path $workPath $logType.name
                        $targetFile = Join-Path $targetFolder "${sn}_${dateTime}.txt"
                        
                        # Check file size
                        $fileSize = (Get-Item $sourceFile).Length
                        if ($fileSize -gt 3) {
                            try {
                                Move-Item $sourceFile $targetFile -Force
                                Write-Host "  + $($logType.name): $fileSize bytes" -ForegroundColor Green
                                $extractedCount++
                            }
                            catch {
                                Write-Host "  ! Failed to move file: $($logType.name): $_" -ForegroundColor Yellow
                            }
                        }
                        else {
                            Write-Host "  - $($logType.name): Empty file ($fileSize bytes), skipping" -ForegroundColor Yellow
                            Remove-Item $sourceFile -Force
                        }
                    }
                    else {
                        Write-Host "  - $($logType.name): Not found in archive" -ForegroundColor Yellow
                    }
                }
                
                Write-Host "Extracted $extractedCount/$($logTypes.Count) log types" -ForegroundColor $(if ($extractedCount -gt 0) { "Green" } else { "Yellow" })
            }
            else {
                Write-Host "7-Zip extraction failed with code $exitCode" -ForegroundColor Red
                Write-Host "Error details: $($7zOutput -join "`n")" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "Error processing $($toplog_DBX.FullName): $_" -ForegroundColor Red
            Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
        }
        finally {
            # Clean up temporary directory
            if (Test-Path $tempPath) {
                Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    # Prepare thread processing tasks
    $handles = @()
    $jobIndex = 0
    $totalDBXCount = $toplog_DBXs.Count
    
    foreach ($toplog_DBX in $toplog_DBXs) {
        $jobIndex++
        
        # Create PowerShell object to execute in Runspace
        $powershell = [powershell]::Create().AddScript($scriptBlock)
        
        # Add parameters
        [void]$powershell.AddParameter("DBXFilePath", $toplog_DBX.FullName)
        [void]$powershell.AddParameter("workPath", $work_pth)
        [void]$powershell.AddParameter("logTypes", $selectedLogTypes)
        [void]$powershell.AddParameter("jobIndex", $jobIndex)
        [void]$powershell.AddParameter("totalFiles", $totalDBXCount)
        
        # Assign Runspace
        $powershell.RunspacePool = $runspacePool
        
        # Start asynchronous execution and save handle
        $handle = [PSCustomObject]@{
            Index      = $jobIndex
            Powershell = $powershell
            Handle     = $powershell.BeginInvoke()
        }
        $handles += $handle
    }
    
    # Wait for all threads to complete
    Write-Host "Starting execution of all threads..." -ForegroundColor Cyan
    
    do {
        $stillRunning = $false
        foreach ($handle in $handles) {
            if (-not $handle.Handle.IsCompleted) {
                $stillRunning = $true
                break
            }
        }
        
        if ($stillRunning) {
            Start-Sleep -Milliseconds 500
        }
    } while ($stillRunning)
    
    # Complete all Runspace operations
    foreach ($handle in $handles) {
        try {
            $null = $handle.Powershell.EndInvoke($handle.Handle)
        }
        finally {
            $handle.Powershell.Dispose()
        }
    }
    
    # Clean up RunspacePool
    $runspacePool.Close()
    $runspacePool.Dispose()
    
    # Summarize extraction results
    Write-Host "`n--- Extraction Summary ---" -ForegroundColor Cyan
    foreach ($logType in $selectedLogTypes) {
        $folderPath = Join-Path $work_pth $logType.name
        $fileCount = (Get-ChildItem -Path $folderPath -File).Count
        Write-Host "$($logType.name): $fileCount files" -ForegroundColor $(if ($fileCount -gt 0) { "Green" } else { "Yellow" })
    }

    Write-Host "`nAll selected log types have been processed" -ForegroundColor Green

    # List SNs with multiple log files
    $multipleLogSNs = $snLogDict.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 }

    if ($multipleLogSNs.Count -gt 0) {
        Write-Host "`n--- SNs with Multiple Log Files ---" -ForegroundColor Magenta
        
        # Create custom object collection for Format-Table
        $tableData = $multipleLogSNs | Sort-Object { $_.Value.Count } -Descending | ForEach-Object {
            $sn = $_.Key
            $logs = $_.Value
            $logNames = ($logs | ForEach-Object { $_.Name }) -join "`n"
            
            [PSCustomObject]@{
                "SN"       = $sn
                "Count"    = $logs.Count
                "LogFiles" = $logNames
            }
        }
        
        # Use Format-Table with -Wrap parameter to allow text wrapping within cells
        $tableData | Format-Table -AutoSize -Wrap
    }
    else {
        Write-Host "No SNs with multiple log files found" -ForegroundColor Yellow
    }
}

# Main program loop
while ($true) {
    Show-Menu
    $selections = Read-Host ">>"

    # Get the list of valid keys dynamically
    $logTypes = Get-LogTypeInfo
    $validKeys = ($logTypes.Keys + @("0")) -join ""
    $validPattern = "^[$validKeys]+$"

    if ($selections -match $validPattern) {
        if ($selections.Contains('0')) {
            break
        }
        $startTime = Get-Date
        Invoke-LogExtraction -selections $selections -work_pth $work_pth
        $endTime = Get-Date
        $executionTime = $endTime - $startTime
        Write-Host "Total execution time: $executionTime" -ForegroundColor Green
    }
    else {
        Write-Host "Please enter valid numbers (0-$($logTypes.Keys | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum))" -ForegroundColor Red
    }
}

Write-Host "`n**********  TopLogs Generation Completed  **********" -ForegroundColor Yellow -BackgroundColor Black