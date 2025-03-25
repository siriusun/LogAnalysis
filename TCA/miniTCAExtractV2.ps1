#此脚本用于批量提取miniTCA日志 2023/12/01

$Pth = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $Pth

function New-Folder ($FolderName) {
    # 确保文件夹名不为空
    if ([string]::IsNullOrWhiteSpace($FolderName)) {
        Write-Host "Error: Empty folder name" -ForegroundColor Red
        return
    }
    
    $folderPath = Join-Path -Path $Pth -ChildPath $FolderName
    
    if (Test-Path $folderPath) {
        Remove-Item -Recurse $folderPath
    }
    
    try {
        New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
        Write-Host "Created folder: $FolderName" -ForegroundColor Green
    }
    catch {
        Write-Host "Error creating folder: $FolderName" -ForegroundColor Red
    }
}

# 定义日志类型字典, 包含编号和对应的日志名称
$LogTypes = @{
    '1' = 'BypassTag'
    '2' = 'ErrorMsg'
    '3' = 'LasConf'
    '4' = 'LasStatistics'
    '5' = 'SWVersions'
    '6' = 'TCActions'
    '7' = 'TCAInfo'
}

Write-Host 
"
*********************************
***    miniTCA tool V1.0      ***
*********************************
`n`n"

Write-Host "Starting extract miniTcaLogs" -ForegroundColor Yellow -BackgroundColor Black
"`n"

$year_month = Read-Host "Input Year-Month Pattern (yyyy-mm) to filter, 0 for all logs "

if ($year_month -eq "0") {
    $year_month = "*"
}

$FormatVar = 0
while (1) {
    if ($FormatVar -ge 1) {
        write-host	"`n"
    }
    $FormatVar++
    
    # 显示选项菜单
    write-host "Select logs to Generate:" -ForegroundColor Yellow -BackgroundColor Black
    $menuText = "`n"
    
    # 动态生成菜单项
    foreach ($key in $LogTypes.Keys | Sort-Object) {
        $menuText += "    $key : $($LogTypes[$key])`n"
    }
    $menuText += "    0 : Quit`n"
    Write-Host $menuText
    
    write-host "You can select multiple options by entering combined digits (e.g. 123)" -ForegroundColor Green
    $Select = read-host ">>"

    if ($Select -eq "0") {
        Exit
    }
    
    # 验证输入
    $SelectArray = $Select.ToCharArray()
    $validInput = $true
    
    foreach ($digit in $SelectArray) {
        if (-not $LogTypes.ContainsKey([string]$digit)) {
            $validInput = $false
            break
        }
    }
    
    if (-not $validInput) {
        Write-Host "请正确输入数字 1-7!" -ForegroundColor Red
        Continue
    }
    
    # 创建所有需要的文件夹并收集所有日志模式
    $LogPatterns = @()
    $FolderNames = @()
    
    # 处理用户选择
    foreach ($digit in $SelectArray) {
        # 确保将字符转为字符串
        $digitStr = [string]$digit
        
        # 确保字典中有这个键
        if ($LogTypes.ContainsKey($digitStr)) {
            $logName = $LogTypes[$digitStr]
            $LogTxt = "$logName*$year_month*.txt"
            $LogFoldName = $logName
            
            # 只有文件夹名不为空时才创建
            if (-not [string]::IsNullOrWhiteSpace($LogFoldName)) {
                New-Folder($LogFoldName)
                
                $LogPatterns += $LogTxt
                $FolderNames += $LogFoldName
            }
        }
    }
    
    Write-Host "Starting extraction of selected log types..." -ForegroundColor Yellow
    "`n`n"
    
    # 获取所有压缩文件
    $compressedExtensions = @(".zip", ".rar", ".7z")
    $LogsFileZips = Get-ChildItem -Recurse -Path (Join-Path -Path $Pth -ChildPath "DownloadLogs") | 
                    Where-Object { $_.Extension -in $compressedExtensions }
    
    if ($LogsFileZips.Count -eq 0) {
        Write-Host "No compressed files found in the DownloadLogs directory!" -ForegroundColor Red
        Continue
    }
    
    # 创建进度条
    $totalArchives = $LogsFileZips.Count
    $progress = 0
    
    # 处理每个压缩文件，一次性提取所有选定的日志类型
    foreach ($ZipLog in $LogsFileZips) {
        $progress++
        $progressPercentage = [int](($progress / $totalArchives) * 100)
        
        Write-Progress -Activity "Extracting Logs" -Status "Processing archive $progress of $totalArchives" `
                      -PercentComplete $progressPercentage
        
        # 显示当前处理的压缩文件
        Write-Host ("-" * 80) -ForegroundColor DarkGray
        Write-Host "Processing: $(Split-Path $ZipLog.FullName -Leaf) [$progress/$totalArchives]" -ForegroundColor Yellow
        
        # 对每种日志类型进行处理
        foreach ($i in 0..($LogPatterns.Count-1)) {
            $LogTxt = $LogPatterns[$i]
            $LogFoldName = $FolderNames[$i]
            
            Write-Host "  - Extracting $LogFoldName patterns" -ForegroundColor Cyan
            
            # 7z命令
            $outputPath = Join-Path -Path $Pth -ChildPath $LogFoldName
            7z.exe e $ZipLog.FullName "-o$outputPath" "-ir!$LogTxt" -y | Out-Null
        }
        
        Write-Host ("-" * 80) -ForegroundColor DarkGray
        "`n"
    }
    
    Write-Progress -Activity "Extracting Logs" -Completed
    Write-Host "All files extracted successfully!" -ForegroundColor Green
}