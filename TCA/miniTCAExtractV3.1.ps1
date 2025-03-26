# 此脚本用于批量提取miniTCA日志 2023/12/01
# V3.1 - 优化版：利用压缩包内路径，使用 7z x 直接提取，可选并行 (需要 PowerShell 7+)
#        新增：按日志类型控制是否应用年月过滤

# --- 配置 ---
# 设置为 $true 以启用并行处理 (需要 PowerShell 7 或更高版本)
# 设置为 $false 以使用优化的顺序处理 (兼容所有版本)
$EnableParallelProcessing = $true
# 并行处理时的最大并发任务数 (建议等于或略大于CPU核心数)
$ParallelThrottleLimit = [System.Environment]::ProcessorCount

# --- 脚本初始化 ---
$Pth = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $Pth

# 检查 PowerShell 版本 (如果启用了并行)
if ($EnableParallelProcessing -and $PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "并行处理需要 PowerShell 7 或更高版本。将回退到顺序处理模式。"
    $EnableParallelProcessing = $false
}

# 检查 7-Zip 是否可用
$sevenZipPath = Get-Command 7z.exe -ErrorAction SilentlyContinue
if (-not $sevenZipPath) {
    Write-Error "错误：找不到 7z.exe。请确保已安装 7-Zip 并且其路径已添加到系统环境变量 PATH 中。"
    Exit
}
Write-Host "使用 7-Zip: $($sevenZipPath.Source)" -ForegroundColor DarkGray

# --- 函数定义 ---
function New-Folder ($FolderName) {
    # 确保文件夹名不为空
    if ([string]::IsNullOrWhiteSpace($FolderName)) {
        Write-Host "内部错误：尝试创建空名称的文件夹" -ForegroundColor Red
        return $false # 返回失败状态
    }

    $folderPath = Join-Path -Path $Pth -ChildPath $FolderName

    # 如果存在，先删除旧文件夹 (确保是干净的输出)
    if (Test-Path $folderPath) {
        Write-Host "正在清理旧文件夹: $FolderName" -ForegroundColor DarkYellow
        try {
            Remove-Item -Recurse -Force $folderPath -ErrorAction Stop
        }
        catch {
            Write-Host "错误：无法清理旧文件夹 '$FolderName'。请检查权限或文件是否被占用。$_" -ForegroundColor Red
            return $false # 返回失败状态
        }
    }

    # 创建新文件夹
    try {
        New-Item -Path $folderPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
        return $true # 返回成功状态
    }
    catch {
        Write-Host "错误：创建文件夹 '$FolderName' 失败。$_" -ForegroundColor Red
        return $false # 返回失败状态
    }
}

# 定义日志类型字典, 包含编号和对应的日志名称 (这些名称必须与压缩包内的文件夹名匹配)
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

# --- 新增：定义年月过滤开关 ---
# 使用日志类型名称作为键 (必须与 $LogTypes 中的值匹配)
# 1 = 对此类型应用年月过滤 (如果用户输入了 yyyy-mm)
# 0 = 对此类型不应用年月过滤 (提取所有 .txt 文件，即使输入了 yyyy-mm)
# 注意：如果用户全局输入 '0' (即 $year_month = '*'), 则所有类型都不会应用年月过滤。
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
# 验证 FilterSwitches 是否包含了 LogTypes 中的所有有效项
foreach ($key in $LogTypes.Keys) {
    $logName = $LogTypes[$key]
    if (-not [string]::IsNullOrWhiteSpace($logName) -and -not $FilterSwitches.ContainsKey($logName)) {
        Write-Warning "警告：日志类型 '$logName' 未在 `$FilterSwitches` 中定义开关，将默认不应用年月过滤。"
        # 可以选择添加默认值: $FilterSwitches[$logName] = 0
    }
}


# --- 用户交互与设置 ---
Write-Host "
*********************************
***    miniTCA tool V3.1      ***
*********************************
`n`n"

Write-Host "Starting extract miniTcaLogs" -ForegroundColor Yellow -BackgroundColor Black
"`n"

$year_month = $(Get-Date).AddMonths(-1).ToString("yyyy-MM")

write-host "默认年月过滤模式 (上个月): " -NoNewline
write-host $year_month -ForegroundColor Black -BackgroundColor Yellow

$patter_check = Read-Host "按 'y' 使用默认模式, 按其他任意键手动输入"

if ($patter_check -notin "y", "Y") {
    $year_month = Read-Host "输入年月过滤模式 (yyyy-mm), 或输入 '0' 提取所有时间的日志"
}

if ($year_month -eq "0") {
    $year_month = "*" # 使用通配符匹配所有日期
    Write-Host "将提取所有时间的日志 (忽略各类型过滤开关)。" -ForegroundColor Yellow
}
else {
    if ($year_month -notmatch "^\d{4}-\d{2}$" -and $year_month -ne "*") {
        Write-Warning "输入的格式可能不正确，期望格式为 yyyy-mm 或 *"
    }
    Write-Host "全局年月过滤模式设置为 '$year_month'。" -ForegroundColor Yellow
    Write-Host "注意：此过滤仅对开关设置为 1 的类型生效。" -ForegroundColor DarkYellow
}

# --- 主处理循环 ---
$FormatVar = 0
while (1) {
    if ($FormatVar -ge 1) {
        write-host "`n"
    }
    $FormatVar++

    # 显示选项菜单
    write-host "选择要提取的日志类型 (名称需匹配压缩包内文件夹):" -ForegroundColor Yellow -BackgroundColor Black
    $menuText = "`n"
    $sortedKeys = $LogTypes.Keys | Sort-Object { [int]$_ } # 按数字顺序排序
    foreach ($key in $sortedKeys) {
        # 显示当前过滤状态
        $logName = $LogTypes[$key]
        $filterStatus = "(过滤: 关)" # 默认显示
        if ($FilterSwitches.ContainsKey($logName) -and $FilterSwitches[$logName] -eq 1) {
            $filterStatus = "(过滤: 开)"
        }
        $menuText += "    $key : $logName $filterStatus`n" -f $key, $logName, $filterStatus
    }
    $menuText += "    0 : 退出`n"
    Write-Host $menuText

    write-host "可输入多个数字组合进行多选 (例如 123)" -ForegroundColor Green
    $Select = read-host ">>"

    if ($Select -eq "0") {
        Write-Host "脚本退出。"
        Exit
    }

    # 验证输入
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
        Write-Host "输入无效！请输入菜单中显示的数字，或 '0' 退出。" -ForegroundColor Red
        Continue
    }

    # --- 准备提取参数和环境 ---
    Write-Host "`n准备提取..." -ForegroundColor Cyan

    $IncludeSwitches = @()      # 存储 7z 的 -ir! 参数
    $SelectedFolderNames = @()  # 存储选中的文件夹名称，用于报告
    $ExtractionPlan = @{}       # 存储每个选中类型的实际提取模式

    # 1. 清理/创建目标文件夹，并构建 7z 包含参数 (根据开关决定模式)
    $allFoldersCreated = $true
    foreach ($key in $selectedLogKeys | Sort-Object { [int]$_ }) {
        $logFolderName = $LogTypes[$key]

        if (-not [string]::IsNullOrWhiteSpace($logFolderName)) {
            # 清理并创建输出文件夹
            if (-not (New-Folder($logFolderName))) {
                Write-Error "无法创建必要的输出文件夹 '$logFolderName'，提取中止。"
                $allFoldersCreated = $false
                break
            }
            $SelectedFolderNames += $logFolderName

            # 确定是否应用年月过滤
            $applyDateFilterForThisType = $false
            if ($FilterSwitches.ContainsKey($logFolderName)) {
                # 应用过滤 = 开关为1 且 全局模式不是 "*"
                $applyDateFilterForThisType = ($FilterSwitches[$logFolderName] -eq 1 -and $year_month -ne "*")
            }
            else {
                Write-Warning "类型 '$logFolderName' 的过滤开关未定义，默认不应用年月过滤。"
            }

            # 构建文件匹配模式
            $filePattern = if ($applyDateFilterForThisType) {
                "*$year_month*.txt" # 应用年月过滤
            }
            else {
                "*.txt" # 不应用年月过滤 (提取所有 .txt)
            }
            $ExtractionPlan[$logFolderName] = $filePattern # 记录实际使用的模式

            # 构建 7z 包含参数
            $includePattern = "$logFolderName\$filePattern"
            $IncludeSwitches += "-ir!$includePattern"

        }
        else {
            Write-Warning "跳过键 '$key'，因为其日志名称为空。"
        }
    }

    # 如果文件夹创建失败，则返回菜单
    if (-not $allFoldersCreated) {
        Continue
    }

    # 显示最终的提取计划
    Write-Host "提取计划:" -ForegroundColor Cyan
    foreach ($folderName in $SelectedFolderNames) {
        Write-Host " - $folderName : 将提取 '$($ExtractionPlan[$folderName])'" -ForegroundColor Green
    }
    # Write-Host "7z 包含参数: $($IncludeSwitches -join ' ')" # 调试信息
    Write-Host "输出文件夹已准备就绪。" -ForegroundColor Green
    "`n"

    # 2. 查找压缩文件
    $downloadLogsPath = Join-Path -Path $Pth -ChildPath "DownloadLogs"
    if (-not (Test-Path $downloadLogsPath)) {
        Write-Error "错误：找不到 'DownloadLogs' 目录 '$downloadLogsPath'。请确保该目录存在于脚本所在位置。"
        Continue
    }

    $compressedExtensions = @(".zip", ".rar", ".7z")
    Write-Host "正在 '$downloadLogsPath' 及其子目录中搜索压缩文件..." -ForegroundColor Cyan
    $LogsFileZips = Get-ChildItem -Recurse -Path $downloadLogsPath -File |
    Where-Object { $compressedExtensions -contains $_.Extension }

    if ($LogsFileZips.Count -eq 0) {
        Write-Warning "在 '$downloadLogsPath' 目录及其子目录中未找到支持的压缩文件 (.zip, .rar, .7z)。"
        Continue
    }
    Write-Host "找到 $($LogsFileZips.Count) 个压缩文件。" -ForegroundColor Green

    # --- 执行提取 ---
    Write-Host "开始提取过程... ($($LogsFileZips.Count) 个文件)" -ForegroundColor Yellow

    $startTime = Get-Date
    $processedCount = 0
    $totalArchives = $LogsFileZips.Count

    # --- 选择处理方式：并行或顺序 ---
    # (并行和顺序处理的核心逻辑不变，因为 $IncludeSwitches 已经根据开关构建好了)
    if ($EnableParallelProcessing) {
        # --- 并行处理 (PowerShell 7+) ---
        Write-Host "使用并行处理 (最大并发: $ParallelThrottleLimit)..." -ForegroundColor Magenta

        $LogsFileZips | ForEach-Object -Parallel {
            $zipFile = $_
            $currentPth = $using:Pth
            $currentIncludeSwitches = $using:IncludeSwitches
            $total = $using:totalArchives
            $sevenZipExe = $using:sevenZipPath.Source

            $currentCount = [System.Threading.Interlocked]::Increment([ref]$using:processedCount)
            Write-Host "[线程 $ThreadId] 正在处理 $($zipFile.Name) ($currentCount/$total)..." -ForegroundColor DarkCyan

            $arguments = @('x', $zipFile.FullName, "-o$currentPth") + $currentIncludeSwitches + @('-y')

            try {
                & $sevenZipExe $arguments # | Out-Null
            }
            catch {
                Write-Error "[线程 $ThreadId] 处理压缩文件 $($zipFile.Name) 时出错: $_"
            }
        }

    }
    else {
        # --- 顺序处理 (优化版) ---
        Write-Host "使用顺序处理..." -ForegroundColor Magenta

        foreach ($ZipLog in $LogsFileZips) {
            $processedCount++
            $progressPercentage = [int](($processedCount / $totalArchives) * 100)

            Write-Progress -Activity "提取日志" -Status "处理文件 $processedCount of $totalArchives : $($ZipLog.Name)" `
                -PercentComplete $progressPercentage

            Write-Host ("-" * 60) -ForegroundColor DarkGray
            Write-Host "处理: $($ZipLog.Name) [$processedCount/$totalArchives]" -ForegroundColor DarkCyan

            $arguments = @('x', $ZipLog.FullName, "-o$Pth") + $IncludeSwitches + @('-y')

            try {
                & $sevenZipPath.Source $arguments # | Out-Null
                # if ($LASTEXITCODE -ne 0) { Write-Warning "7z 处理 $($ZipLog.Name) 可能有错误 (退出码: $LASTEXITCODE)" }
            }
            catch {
                Write-Warning "处理压缩文件 $($ZipLog.Name) 时出错: $_"
            }
            Write-Host ("-" * 60) -ForegroundColor DarkGray
        }
        Write-Progress -Activity "提取日志" -Completed
    }

    # --- 清理和总结 ---
    $endTime = Get-Date
    $duration = $endTime - $startTime

    Write-Host "`n提取过程完成！" -ForegroundColor Green
    Write-Host "总耗时: $($duration.ToString()) ($($duration.TotalSeconds.ToString('F2')) 秒)" -ForegroundColor Green

    Write-Host "所有选定的日志文件已根据各类型过滤设置提取到对应的文件夹中。" -ForegroundColor Green
    # 循环将继续
}

# --- 脚本结束 ---
