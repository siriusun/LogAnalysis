#BF log export tool 2.0 2025-03-27
# 优化版本：多线程处理、减少IO、改进临时文件存储、文件缺失记录

Function Get-FileName {  
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
        Remove-Item -Recurse -Force $NewFolderName
    }
    New-Item -Path $work_pth -ItemType Directory -Name $NewFolderName | Out-Null
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

Write-Host @"
*************************************************************
***            BIO-FLASH Log Exported by Agent            ***
*************************************************************

"@

Write-Host "Starting to decompress Source Logs?" -ForegroundColor Yellow -BackgroundColor Black
$flag = Read-Host "Y/y for Yes, N/n for Next step "
if ($flag -eq "Y" -or $flag -eq "y") {
    # 开始计时
    $startTime = Get-Date
    Write-Host "Process started at: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
    
    $source_log_packages = Get-ChildItem -Path ($work_pth.ToString() + "\DownloadLogs\") | Where-Object { $_.Extension -like ".rar" -or $_.Extension -like ".zip" -or $_.Extension -like ".7z" }
    if ($null -eq $source_log_packages) {
        "No log files found. Any Key to Exit..."
        [System.Console]::ReadKey() | Out-Null ; Exit
    }

    # 创建输出目录
    New-Folder("InstrumentLog")
    New-Folder("testvl_report")
    
    # 创建临时目录（在当前工作目录中）
    $tempDirName = "BF_Temp_" + [Guid]::NewGuid().ToString().Substring(0, 8)
    $tempDir = Join-Path $work_pth $tempDirName
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    # 创建RunspacePool以进行多线程处理
    $sessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    $maxThreads = [int]$env:NUMBER_OF_PROCESSORS + 1
    $runspacePool = [runspacefactory]::CreateRunspacePool(1, $maxThreads, $sessionState, $Host)
    $runspacePool.Open()
    
    $runspaces = @()
    $progressCounter = 0
    
    # 创建线程安全的哈希表来记录缺少文件的包
    $missingFiles = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
    
    # 处理脚本块定义
    $scriptBlock = {
        param (
            $packagePath, 
            $packageBaseName, 
            $workPath, 
            $tempDirPath,
            $missingFilesDict
        )

        # 为每个包创建特定的临时目录
        $packageTempDir = Join-Path $tempDirPath $packageBaseName
        New-Item -ItemType Directory -Path $packageTempDir -Force | Out-Null
        
        $result = @{
            PackageName          = $packageBaseName
            Status               = "Completed"
            MissingInstrumentLog = $false
            MissingReport        = $false
        }
        
        try {
            # 一次提取所有需要的文件（减少IO操作）
            $extractCmd = "7z.exe e `"$packagePath`" -o`"$packageTempDir`" -ir!`"InstrumentLog.*`" -ir!`"*Report*htm`" -aos"
            Invoke-Expression $extractCmd | Out-Null
            
            # 处理InstrumentLog文件
            $tempLog = Get-ChildItem -Path $packageTempDir -Recurse -Filter "InstrumentLog*" -ErrorAction SilentlyContinue
            
            if ($tempLog) {
                if ($tempLog.Extension -eq ".json") {
                    $destJson = Join-Path $workPath "JsonLogs" ($packageBaseName + ".json")
                    Copy-Item -Path $tempLog.FullName -Destination $destJson -Force
                }
                else {
                    $destTxt = Join-Path $workPath "InstrumentLog" ($packageBaseName + ".txt")
                    Copy-Item -Path $tempLog.FullName -Destination $destTxt -Force
                }
            }
            else {
                $result.MissingInstrumentLog = $true
            }
            
            # 处理报告文件
            $tempReport = Get-ChildItem -Path $packageTempDir -Recurse -Filter "*Report*" -ErrorAction SilentlyContinue
            if ($tempReport) {
                $destHtml = Join-Path $workPath "testvl_report" ($packageBaseName + ".html")
                Copy-Item -Path $tempReport.FullName -Destination $destHtml -Force
            }
            else {
                $result.MissingReport = $true
            }
            
            # 检查是否有文件缺失，如果有则添加到缺失文件字典中
            if ($result.MissingInstrumentLog -or $result.MissingReport) {
                $missingInfo = @{
                    MissingInstrumentLog = $result.MissingInstrumentLog
                    MissingReport        = $result.MissingReport
                }
                $missingFilesDict[$packageBaseName] = $missingInfo
            }
        }
        finally {
            # 清理包特定的临时目录
            if (Test-Path $packageTempDir) {
                Remove-Item -Recurse -Force $packageTempDir -ErrorAction SilentlyContinue
            }
        }
        
        # 返回结果
        return $result
    }
    
    # 确保JsonLogs目录存在（用于存储JSON文件）
    New-Folder("JsonLogs")
    
    # 创建并启动所有任务
    foreach ($package in $source_log_packages) {
        "-" * 100
        
        # 检查并修复文件名中扩展名前的空格问题
        $originalName = $package.FullName
        $baseName = $package.BaseName
        
        # 检查文件名是否有扩展名前的空格
        if ($originalName -match " \.[^\\\/]*$") {
            try {
                # 获取修正后的文件名
                $correctedName = $originalName -replace " \.", "."
                $correctedBaseName = $baseName.TrimEnd()
                
                Write-Host "发现扩展名前有空格的文件: $originalName" -ForegroundColor Yellow
                Write-Host "尝试重命名为: $correctedName" -ForegroundColor Yellow
                
                # 重命名文件
                Rename-Item -Path $originalName -NewName $correctedName -ErrorAction Stop
                
                # 更新包对象的路径
                $package = Get-Item -Path $correctedName
                $baseName = $correctedBaseName
                
                Write-Host "文件重命名成功" -ForegroundColor Green
            }
            catch {
                Write-Host "文件重命名失败: $_" -ForegroundColor Red
                # 继续使用原始文件名
            }
        }
        
        Write-Host ("Queuing: " + $package.BaseName) -BackgroundColor Black -ForegroundColor Yellow
        
        $powerShell = [powershell]::Create().AddScript($scriptBlock).AddParameters(@{
                packagePath      = $package.FullName
                packageBaseName  = $baseName  # 使用可能更新的baseName
                workPath         = $work_pth
                tempDirPath      = $tempDir
                missingFilesDict = $missingFiles
            })
        
        $powerShell.RunspacePool = $runspacePool
        
        $runspaces += [PSCustomObject]@{
            PowerShell = $powerShell
            Handle     = $powerShell.BeginInvoke()
            Package    = $package.BaseName
            Started    = Get-Date
        }
    }
    
    # 监控和处理完成的任务
    do {
        $completedRunspaces = @($runspaces | Where-Object { $_.Handle.IsCompleted })
        
        foreach ($runspace in $completedRunspaces) {
            $result = $runspace.PowerShell.EndInvoke($runspace.Handle)
            $packageName = $result.PackageName
            
            $progressCounter++
            
            # 使用不同颜色显示是否有文件缺失
            if ($result.MissingInstrumentLog -or $result.MissingReport) {
                Write-Host ("Completed [$progressCounter/$($source_log_packages.Count)]: " + $packageName) -ForegroundColor Yellow
                Write-Host ("  Missing files: " + 
                    $(if ($result.MissingInstrumentLog) { "InstrumentLog" } else { "" }) + 
                    $(if ($result.MissingInstrumentLog -and $result.MissingReport) { ", " } else { "" }) + 
                    $(if ($result.MissingReport) { "Report" } else { "" })) -ForegroundColor Red
            }
            else {
                Write-Host ("Completed [$progressCounter/$($source_log_packages.Count)]: " + $packageName) -ForegroundColor Green
            }
            
            $runspace.PowerShell.Dispose()
        }
        
        # 从跟踪集合中移除已完成的
        $runspaces = @($runspaces | Where-Object { -not $_.Handle.IsCompleted })
        
        # 简短暂停以减少CPU使用
        if ($runspaces.Count -gt 0) {
            Start-Sleep -Milliseconds 100
        }
    } while ($runspaces.Count -gt 0)
    
    # 关闭RunspacePool
    $runspacePool.Close()
    $runspacePool.Dispose()
    
    # 清理主临时目录
    if (Test-Path $tempDir) {
        Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
        Write-Host "Temporary directory cleaned up: $tempDirName" -ForegroundColor Yellow
    }
    
    # 计算并显示总耗时
    $endTime = Get-Date
    $duration = $endTime - $startTime
    Write-Host "`nProcess completed at: $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
    Write-Host "Total processing time: $($duration.Hours.ToString('00')):$($duration.Minutes.ToString('00')):$($duration.Seconds.ToString('00'))" -ForegroundColor Cyan
    Write-Host "Total packages processed: $($source_log_packages.Count)" -ForegroundColor Cyan
    
    # 显示文件缺失摘要
    $missingCount = $missingFiles.Count
    if ($missingCount -gt 0) {
        Write-Host "`n文件缺失摘要:" -ForegroundColor Red
        Write-Host "总共有 $missingCount 个压缩包存在文件缺失问题" -ForegroundColor Red
        
        # 创建对象数组用于Format-Table显示
        $missingFilesList = @()
        foreach ($package in $missingFiles.Keys) {
            $info = $missingFiles[$package]
            $missingFilesList += [PSCustomObject]@{
                压缩包名称           = $package
                缺少InstrumentLog = if ($info.MissingInstrumentLog) { "是" } else { "否" }
                缺少Report        = if ($info.MissingReport) { "是" } else { "否" }
            }
        }
        
        # 使用Format-Table输出到终端
        $missingFilesList | Format-Table -AutoSize
    }
    else {
        Write-Host "`n所有压缩包均包含完整的文件。" -ForegroundColor Green
    }
}

$json_logs = Get-ChildItem -Recurse -Path ($work_pth + "\JsonLogs\") -Filter *.json
"`n"
Write-Host  "JSON logs: " $json_logs.Length
"`n"

Write-Host "**********  BIOFLASH Logs Generated  **********" -ForegroundColor Yellow -BackgroundColor Black
"Any Key to Exit..."
[System.Console]::ReadKey() | Out-Null ; Exit