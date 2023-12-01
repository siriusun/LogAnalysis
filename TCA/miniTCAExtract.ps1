#此脚本用于批量提取miniTCA日志 2023/12/01

$Pth = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $Pth

function New-Folder ($FolderName) {
    if (Test-Path $FolderName) {
        Remove-Item -Recurse $FolderName
    }
    New-Item -Path $Pth -ItemType Directory -Name $FolderName
}

Write-Host 
"
*********************************
***    miniTCA tool V1.0      ***
*********************************
`n`n"

Write-Host "Starting extract miniTcaLogs" -ForegroundColor Yellow -BackgroundColor Black

Write-Host "Any key to continue..."
[System.Console]::ReadKey() | Out-Null

"`n"

$FormatVar = 0
while (1) {
    if ($FormatVar -ge 1) {
        write-host	"`n"
    }
    $FormatVar ++
    #选择要输入的Log类型
    write-host "Select logs to Generate:" -ForegroundColor Yellow -BackgroundColor Black
    "
    1 : BypassTag
    2 : ErrorMsg
    3 : LasConf
    4 : LasStatistics
    5 : SWVersions
    6 : TCActions
    7 : TCAInfo
    8 : Quit
    "
    $Select = read-host ">>"

    #定义要查找Log关键字
    if ($Select -eq 1) {
        $LogTxt = "BypassTag*.txt"
    }
    elseif ($Select -eq 2) {
        $LogTxt = "ErrorMsg*.txt"
    }
    elseif ($Select -eq 3) {
        $LogTxt = "LasConf*.txt"
    }
    elseif ($Select -eq 4) {
        $LogTxt = "LasStatistics*.txt"
    }
    elseif ($Select -eq 5) {
        $LogTxt = "SWVersions*.txt"
    }
    elseif ($Select -eq 6) {
        $LogTxt = "TCActions*.txt"
    }
    elseif ($Select -eq 7) {
        $LogTxt = "TCAInfo*.txt"
    }
    elseif ($Select -eq 8) {
        Exit
    }
    else {
        Write-Host "请正确输入!!!"
        Continue
    }

    #创建Log输出文件夹
    $LogFoldName = $LogTxt.Replace("*.txt","")
    New-Folder($LogFoldName)
    "`n`n"
    
    $LogsFileZips = Get-ChildItem -Recurse -Path ($Pth.ToString() + "\DownloadLogs\") | Where-Object {$_.Extension -in ".zip", ".rar", ".7z"} 

    $Step = 0
    foreach ($ZipLog in $LogsFileZips) {
        "-" * 100
        Write-Host ("Start to Extract File :  " + ($LogsFileZips.Count - $Step).ToString()) -BackgroundColor Black -ForegroundColor Yellow
        #7z命令如下：
        $7zComTxt = "-o" + $Pth + "\" + $LogFoldName + "\"
        7z.exe e  $ZipLog.FullName $7zComTxt -r $LogTxt 
        "-" * 100
        "`n"
        $Step ++
    }
    Write-Host ("Finish to Extract File :  $LogFoldName") -ForegroundColor Yellow
}