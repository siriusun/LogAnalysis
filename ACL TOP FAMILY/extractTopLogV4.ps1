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

    # 获取线程数量，默认使用处理器核心数量
    $maxThreads = [Environment]::ProcessorCount
    Write-Host "使用 $maxThreads 个线程并行处理" -ForegroundColor Cyan
    
    # 步骤1: 并行处理 DBX 文件复制
    Write-Host "并行复制 DBX 文件到 SourceLogs 文件夹..." -ForegroundColor Yellow
    $toplog_DBXs = Get-ChildItem -Path ($work_pth + "\DownloadLogs\") -Recurse -Filter *DBX_*_????-??-??_??-??-??*.zip
    if ($null -ne $toplog_DBXs) {
        # 创建RunspacePool
        $copySessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        $copyRunspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $maxThreads, $copySessionState, $Host)
        $copyRunspacePool.Open()
        
        # 定义复制脚本块
        $copyScriptBlock = {
            param($sourceFile, $destFolder)
            $destPath = Join-Path $destFolder (Split-Path $sourceFile -Leaf)
            Copy-Item -Path $sourceFile -Destination $destPath
        }
        
        # 创建并执行所有复制任务
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
        
        # 等待所有复制完成
        Write-Host "等待文件复制完成..." -ForegroundColor Cyan
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
        
        # 清理资源
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
    
    # 步骤2: 并行处理二级压缩文件解压
    Write-Host "并行处理二级压缩文件..." -ForegroundColor Yellow
    $source_log_packages = Get-ChildItem -Path ($work_pth.ToString() + "\DownloadLogs\") -Recurse -Include *.rar, *.zip, *.7z | Where-Object { $_.Name -notmatch "DBX" }
    
    if ($source_log_packages.Count -gt 0) {
        # 创建RunspacePool
        $extractSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        $extractRunspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $maxThreads, $extractSessionState, $Host)
        $extractRunspacePool.Open()
        
        # 定义解压脚本块
        $extractScriptBlock = {
            param($packageFile, $outputFolder, $index, $total)
            $packageName = Split-Path $packageFile -Leaf
            $targetFolder = Join-Path $outputFolder (Split-Path $packageFile -LeafBase)
            $remaining = $total - $index
            
            Write-Host (">>>>: $remaining 剩余  正在处理: $packageName") -BackgroundColor Black -ForegroundColor Yellow
            & 7z.exe e $packageFile "-o$targetFolder" -ir!*DBX*.zip -aos
        }
        
        # 创建并执行所有解压任务
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
        
        # 等待所有解压完成
        Write-Host "等待解压文件完成..." -ForegroundColor Cyan
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
        
        # 清理资源
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
    
    Write-Host "所有文件处理完成！" -ForegroundColor Green
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
    Write-Host "`n选择要生成的日志类型 (输入多个数字，例如123):" -ForegroundColor Yellow -BackgroundColor Black
    
    $logTypes = Get-LogTypeInfo
    
    # Display all log type options dynamically
    foreach ($key in $logTypes.Keys | Sort-Object) {
        Write-Host "$key : $($logTypes[$key].name)"
    }
    
    # Add exit option
    Write-Host "0 : 退出"
}

function Invoke-LogExtraction {
    param (
        [string]$selections,
        [string]$work_pth
    )

    $logTypes = Get-LogTypeInfo

    # 添加错误处理和日志
    Write-Host "扫描 $work_pth\SourceLogs 中的DBX文件" -ForegroundColor Cyan

    # 获取所有DBX文件
    $toplog_DBXs = Get-ChildItem -Path ($work_pth + "\SourceLogs\") -Recurse -Filter *DBX*.zip
    if ($null -eq $toplog_DBXs -or $toplog_DBXs.Count -eq 0) {
        Write-Host "在SourceLogs目录中未找到DBX文件！" -ForegroundColor Red
        return
    }

    Write-Host "找到 $($toplog_DBXs.Count) 个DBX文件" -ForegroundColor Green

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
        elseif ($nameParts.Length -ge 7 -and $toplog_DBX.Name -match "_DBX_") {
            # 格式1: CHINA_ACLTOP_700LAS_15120236_00000280000_DBX_15120236_2025-03-01_13-00-03_-480
            $namepart_sa = $toplog_DBX.Name.Split("_DBX_")[1].Split("_")
            $sn = $namepart_sa[0]
            $dateTime = $namepart_sa[1]
        }
        else {
            Write-Host "无法识别的文件名格式: $($toplog_DBX.Name), 跳过..." -ForegroundColor Yellow
            continue
        }
        
        if (-not $snLogDict.ContainsKey($sn)) {
            $snLogDict[$sn] = @()
        }
        $snLogDict[$sn] += $toplog_DBX
    }

    # 过滤并获取选中的日志类型（添加调试信息和类型修复）
    Write-Host "您选择了: $selections" -ForegroundColor Cyan
    $selectedLogTypes = @()

    foreach ($char in $selections.ToCharArray()) {
        # 转换字符为字符串以确保类型匹配
        $keyStr = $char.ToString()
        Write-Host "处理选择: $keyStr" -ForegroundColor DarkGray
    
        # 显示已有的键以帮助调试
        Write-Host "  可用键: $($logTypes.Keys -join ', ')" -ForegroundColor DarkGray
    
        if ($keyStr -ne '0' -and $logTypes.ContainsKey($keyStr)) {
            Write-Host "  + 添加日志类型: $($logTypes[$keyStr].name)" -ForegroundColor Green
            $selectedLogTypes += $logTypes[$keyStr]
        }
        else {
            Write-Host "  - 忽略无效选择: $keyStr" -ForegroundColor Yellow
        }
    }

    Write-Host "已选择 $($selectedLogTypes.Count) 种日志类型" -ForegroundColor Cyan

    if ($selectedLogTypes.Count -eq 0) {
        Write-Host "未选择有效的日志类型！" -ForegroundColor Red
        return
    }

    # 创建所有需要的目标文件夹
    foreach ($logType in $selectedLogTypes) {
        New-Folder $logType.name
        Write-Host "为 $($logType.name) 创建了文件夹" -ForegroundColor Green
    }

    # 显示处理信息
    Write-Host "将从每个DBX文件中提取 $($selectedLogTypes.Count) 种日志类型" -ForegroundColor Cyan

    # 设置多线程处理
    $maxThreads = [Environment]::ProcessorCount
    Write-Host "使用 $maxThreads 个线程并行处理DBX文件解压" -ForegroundColor Cyan
    
    # 使用RunspacePool实现真正的多线程处理
    $sessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    $runspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $maxThreads, $sessionState, $Host)
    $runspacePool.Open()
    
    # 定义处理函数
    $scriptBlock = {
        param(
            [string]$DBXFilePath,
            [string]$workPath,
            [array]$logTypes,
            [int]$jobIndex,
            [int]$totalFiles
        )
        
        # 创建文件对象
        $toplog_DBX = Get-Item -Path $DBXFilePath
        
        Write-Host "`n处理文件 $jobIndex/$totalFiles`: $($toplog_DBX.Name)" -ForegroundColor Cyan
        
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
            Write-Host "无效的文件名格式: $($toplog_DBX.Name), 跳过..." -ForegroundColor Yellow
            return
        }
        
        # 创建临时目录
        $tempFolderName = "temp_extract_" + [System.Guid]::NewGuid().ToString()
        $tempPath = Join-Path $workPath $tempFolderName
        New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
        
        try {
            # 构建提取参数
            $extractParams = @()
            foreach ($logType in $logTypes) {
                $extractParams += "-ir!$($logType.file)"
            }
            
            # 显示处理信息
            Write-Host "从 $($toplog_DBX.Name) 提取日志, SN: $sn" -ForegroundColor Yellow
            
            # 执行解压
            $7zArgs = @("e", $toplog_DBX.FullName, "-pfixmeplease", "-o$tempPath", "-aos") + $extractParams
            $7zOutput = & 7z.exe $7zArgs 2>&1
            $exitCode = $LASTEXITCODE
            
            # 处理结果
            if ($exitCode -eq 0) {
                $extractedCount = 0
                
                # 处理每种日志类型
                foreach ($logType in $logTypes) {
                    $sourceFile = Join-Path $tempPath $logType.file
                    if (Test-Path $sourceFile) {
                        $targetFolder = Join-Path $workPath $logType.name
                        $targetFile = Join-Path $targetFolder "${sn}_${dateTime}.txt"
                        
                        # 检查文件大小
                        $fileSize = (Get-Item $sourceFile).Length
                        if ($fileSize -gt 3) {
                            try {
                                Move-Item $sourceFile $targetFile -Force
                                Write-Host "  + $($logType.name): $fileSize 字节" -ForegroundColor Green
                                $extractedCount++
                            }
                            catch {
                                Write-Host "  ! 移动文件失败: $($logType.name): $_" -ForegroundColor Yellow
                            }
                        }
                        else {
                            Write-Host "  - $($logType.name): 空文件 ($fileSize 字节), 跳过" -ForegroundColor Yellow
                            Remove-Item $sourceFile -Force
                        }
                    }
                    else {
                        Write-Host "  - $($logType.name): 未在归档中找到" -ForegroundColor Yellow
                    }
                }
                
                Write-Host "提取了 $extractedCount/$($logTypes.Count) 种日志类型" -ForegroundColor $(if ($extractedCount -gt 0) { "Green" } else { "Yellow" })
            }
            else {
                Write-Host "7-Zip解压失败，返回代码 $exitCode" -ForegroundColor Red
                Write-Host "错误详情: $($7zOutput -join "`n")" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "处理 $($toplog_DBX.FullName) 时出错: $_" -ForegroundColor Red
            Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
        }
        finally {
            # 清理临时目录
            if (Test-Path $tempPath) {
                Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    # 准备线程处理任务
    $handles = @()
    $jobIndex = 0
    $totalDBXCount = $toplog_DBXs.Count
    
    foreach ($toplog_DBX in $toplog_DBXs) {
        $jobIndex++
        
        # 创建PowerShell对象以在Runspace中执行
        $powershell = [powershell]::Create().AddScript($scriptBlock)
        
        # 添加参数
        [void]$powershell.AddParameter("DBXFilePath", $toplog_DBX.FullName)
        [void]$powershell.AddParameter("workPath", $work_pth)
        [void]$powershell.AddParameter("logTypes", $selectedLogTypes)
        [void]$powershell.AddParameter("jobIndex", $jobIndex)
        [void]$powershell.AddParameter("totalFiles", $totalDBXCount)
        
        # 分配Runspace
        $powershell.RunspacePool = $runspacePool
        
        # 开始异步执行并保存句柄
        $handle = [PSCustomObject]@{
            Index      = $jobIndex
            Powershell = $powershell
            Handle     = $powershell.BeginInvoke()
        }
        $handles += $handle
    }
    
    # 等待所有线程完成
    Write-Host "开始执行所有线程..." -ForegroundColor Cyan
    
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
    
    # 完成所有Runspace操作
    foreach ($handle in $handles) {
        try {
            $null = $handle.Powershell.EndInvoke($handle.Handle)
        }
        finally {
            $handle.Powershell.Dispose()
        }
    }
    
    # 清理RunspacePool
    $runspacePool.Close()
    $runspacePool.Dispose()
    
    # 总结提取结果
    Write-Host "`n--- 提取摘要 ---" -ForegroundColor Cyan
    foreach ($logType in $selectedLogTypes) {
        $folderPath = Join-Path $work_pth $logType.name
        $fileCount = (Get-ChildItem -Path $folderPath -File).Count
        Write-Host "$($logType.name): $fileCount 个文件" -ForegroundColor $(if ($fileCount -gt 0) { "Green" } else { "Yellow" })
    }

    Write-Host "`n所有选定的日志类型已处理完毕" -ForegroundColor Green

    # 列出具有多个压缩日志的SN
    $multipleLogSNs = $snLogDict.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 }

    if ($multipleLogSNs.Count -gt 0) {
        Write-Host "`n--- 具有多个日志文件的SN ---" -ForegroundColor Magenta
        
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
        Write-Host "未发现具有多个日志文件的SN" -ForegroundColor Yellow
    }
}

# 主程序循环
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
        Write-Host "总执行时间: $executionTime" -ForegroundColor Green
    }
    else {
        Write-Host "请输入有效的数字 (0-$($logTypes.Keys | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum))" -ForegroundColor Red
    }
}

Write-Host "`n**********  TopLogs 生成完成  **********" -ForegroundColor Yellow -BackgroundColor Black