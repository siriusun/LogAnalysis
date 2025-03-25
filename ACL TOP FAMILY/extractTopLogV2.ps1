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

    $toplog_DBXs = Get-ChildItem -Path ($work_pth + "\DownloadLogs\") -Recurse -Filter *DBX_*_????-??-??_??-??-??*.zip
    if ($null -ne $toplog_DBXs) {
        foreach ($toplog_DBX in $toplog_DBXs) {
            $newname = $work_pth.ToString() + "\SourceLogs\" + $toplog_DBX.Name
            Copy-Item -Path $toplog_DBX.FullName -Destination $newname
        }
    }
    
    $source_log_packages = Get-ChildItem -Path ($work_pth.ToString() + "\DownloadLogs\") -Recurse -Include *.rar, *.zip, *.7z | Where-Object { $_.Name -notcontains "DBX" }
    $Step1 = 0
    foreach ($source_log_package in $source_log_packages) {
        "-" * 100
        Write-Host (">>>>: " + ($source_log_packages.Count - $Step1).ToString() + "  " + $source_log_package.FullName) -BackgroundColor Black -ForegroundColor Yellow
        $sourceLogs_folder_pth = "-o" + $work_pth + "\SourceLogs\" + $source_log_package.Name.Split(".")[0] + "\"
        7z.exe e $source_log_package.FullName $sourceLogs_folder_pth -ir!*DBX*.zip -aos
        "-" * 100
        "`n`n"
        $Step1 ++
    }
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
    Write-Host "`nSelect logs to Generate (input multiple numbers without spaces, e.g. 123):" -ForegroundColor Yellow -BackgroundColor Black
    Write-Host "1 : GeneralLog"
    Write-Host "2 : sw_all_versions"
    Write-Host "3 : taskList"
    Write-Host "4 : CountersForAllTest"
    Write-Host "5 : InstrumentStatusStatistics"
    Write-Host "6 : globalDefinitions"
    Write-Host "7 : HIL"
    Write-Host "8 : Quit"
}

function Invoke-LogExtraction {
    param (
        [string]$selections,
        [string]$work_pth
    )

    $logTypes = Get-LogTypeInfo

    # 添加错误处理和日志
    Write-Host "Scanning DBX files in: $work_pth\SourceLogs" -ForegroundColor Cyan

    # 获取所有DBX文件
    $toplog_DBXs = Get-ChildItem -Path ($work_pth + "\SourceLogs\") -Recurse -Filter *DBX*.zip
    if ($null -eq $toplog_DBXs -or $toplog_DBXs.Count -eq 0) {
        Write-Host "No DBX files found in SourceLogs directory!" -ForegroundColor Red
        return
    }

    Write-Host "Found $($toplog_DBXs.Count) DBX files" -ForegroundColor Green

    # 创建字典跟踪每个SN对应的日志文件
    $snLogDict = @{}

    # 预处理所有DBX文件，按SN分组
    foreach ($toplog_DBX in $toplog_DBXs) {
        $nameParts = $toplog_DBX.Name.Split("_")
        
        # 解析不同格式的日志文件名，支持两种格式
        # 格式1: CHINA_ACLTOP_700LAS_15120236_00000280000_DBX_15120236_2025-03-01_13-00-03_-480
        # 格式2: DBX_15120236_2025-03-01_13-00-03_-480
        $sn = $null
        $dateTime = $null
        
        if ($nameParts[0] -eq "DBX" -and $nameParts.Length -ge 4) {
            # 格式2: DBX_15120236_2025-03-01_13-00-03_-480
            $sn = $nameParts[1]
            $dateTime = $nameParts[2]
        }
        elseif ($nameParts.Length -ge 8 -and $nameParts[5] -eq "DBX") {
            # 格式1: CHINA_ACLTOP_700LAS_15120236_00000280000_DBX_15120236_2025-03-01_13-00-03_-480
            $sn = $nameParts[6]
            $dateTime = $nameParts[7]
        }
        else {
            Write-Host "Unrecognized file name format: $($toplog_DBX.Name), skipping..." -ForegroundColor Yellow
            continue
        }
        
        if (-not $snLogDict.ContainsKey($sn)) {
            $snLogDict[$sn] = @()
        }
        $snLogDict[$sn] += $toplog_DBX
    }

    # 过滤并获取选中的日志类型（添加调试信息和类型修复）
    Write-Host "You selected: $selections" -ForegroundColor Cyan
    $selectedLogTypes = @()

    foreach ($char in $selections.ToCharArray()) {
        # 转换字符为字符串以确保类型匹配
        $keyStr = $char.ToString()
        Write-Host "Processing selection: $keyStr" -ForegroundColor DarkGray
    
        # 显示已有的键以帮助调试
        Write-Host "  Available keys: $($logTypes.Keys -join ', ')" -ForegroundColor DarkGray
    
        if ($keyStr -ne '8' -and $logTypes.ContainsKey($keyStr)) {
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

    # 创建所有需要的目标文件夹
    foreach ($logType in $selectedLogTypes) {
        New-Folder $logType.name
        Write-Host "Created folder for $($logType.name)" -ForegroundColor Green
    }

    # 显示处理信息（修复语法）
    Write-Host "Will extract $($selectedLogTypes.Count) log types from each DBX file" -ForegroundColor Cyan

    # 处理每个DBX文件
    $processedCount = 0
    foreach ($toplog_DBX in $toplog_DBXs) {
        $processedCount++
        Write-Host "`nProcessing file $processedCount of $($toplog_DBXs.Count): $($toplog_DBX.Name)" -ForegroundColor Cyan
    
        # 解析文件名以获取SN和日期时间
        $nameParts = $toplog_DBX.Name.Split("_")
        $sn = $null
        $dateTime = $null
        
        if ($nameParts[0] -eq "DBX" -and $nameParts.Length -ge 4) {
            # 格式2: DBX_15120236_2025-03-01_13-00-03_-480
            $sn = $nameParts[1]
            $dateTime = $nameParts[2]
        }
        elseif ($nameParts.Length -ge 8 -and $nameParts[5] -eq "DBX") {
            # 格式1: CHINA_ACLTOP_700LAS_15120236_00000280000_DBX_15120236_2025-03-01_13-00-03_-480
            $sn = $nameParts[6]
            $dateTime = $nameParts[7]
        }
        else {
            Write-Host "Invalid filename format: $($toplog_DBX.Name), skipping..." -ForegroundColor Yellow
            continue
        }
    
        # 创建临时目录
        $tempFolderName = "temp_extract_" + [System.Guid]::NewGuid().ToString()
        $tempPath = Join-Path $work_pth $tempFolderName
        New-Item -ItemType Directory -Path $tempPath -Force | Out-Null

        try {
            # 构建要提取的文件参数列表
            $extractParams = @()
            foreach ($logType in $selectedLogTypes) {
                $extractParams += "-ir!$($logType.file)"
            }
        
            # 显示当前处理的DBX文件
            Write-Host "Extracting logs from: $($toplog_DBX.Name) for SN: $sn" -ForegroundColor Yellow
        
            # 最简单方案 - 使用调用操作符
            # $startTime = Get-Date
            $7zArgs = @("e", $toplog_DBX.FullName, "-pfixmeplease", "-o$tempPath", "-aos") + $extractParams
            $7zOutput = & 7z.exe $7zArgs 2>&1
            $exitCode = $LASTEXITCODE
            # $endTime = Get-Date
        
            # 检查结果
            if ($exitCode -eq 0) {
                # 计数成功提取的文件
                $extractedCount = 0
            
                # 移动并重命名提取的文件到对应目录
                foreach ($logType in $selectedLogTypes) {
                    $sourceFile = Join-Path $tempPath $logType.file
                    if (Test-Path $sourceFile) {
                        $targetFolder = Join-Path $work_pth $logType.name
                        $targetFile = Join-Path $targetFolder "${sn}_${dateTime}.txt"
                    
                        # 检查文件大小
                        $fileSize = (Get-Item $sourceFile).Length
                        if ($fileSize -gt 3) {
                            Move-Item $sourceFile $targetFile -Force
                            Write-Host "  + $($logType.name): $fileSize bytes" -ForegroundColor Green
                            $extractedCount++
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
            
                Write-Host "Extracted $extractedCount of $($selectedLogTypes.Count) log types" -ForegroundColor $(if ($extractedCount -gt 0) { "Green" } else { "Yellow" })
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
            # 清理临时目录
            if (Test-Path $tempPath) {
                Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # 总结提取结果
    Write-Host "`n--- Extraction Summary ---" -ForegroundColor Cyan
    foreach ($logType in $selectedLogTypes) {
        $folderPath = Join-Path $work_pth $logType.name
        $fileCount = (Get-ChildItem -Path $folderPath -File).Count
        Write-Host "$($logType.name): $fileCount files" -ForegroundColor $(if ($fileCount -gt 0) { "Green" } else { "Yellow" })
    }

    Write-Host "`nAll selected log types have been processed" -ForegroundColor Green

    # 列出具有多个压缩日志的SN
    $multipleLogSNs = $snLogDict.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 }

    if ($multipleLogSNs.Count -gt 0) {
        Write-Host "`n--- SNs with Multiple Log Files ---" -ForegroundColor Magenta
        
        # 创建自定义对象集合用于Format-Table
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
        
        # 使用Format-Table显示，-Wrap参数允许文本在单元格内换行
        $tableData | Format-Table -AutoSize -Wrap
    }
    else {
        Write-Host "No SNs with multiple log files found" -ForegroundColor Yellow
    }
}

# 主程序循环
while ($true) {
    Show-Menu
    $selections = Read-Host ">>"

    if ($selections -match '^[1-8]+$') {
        if ($selections.Contains('8')) {
            break
        }
        Invoke-LogExtraction -selections $selections -work_pth $work_pth
    }
    else {
        Write-Host "Please input valid numbers (1-8)" -ForegroundColor Red
    }
}

Write-Host "`n**********  TopLogs Generated  **********" -ForegroundColor Yellow -BackgroundColor Black