#此脚本用于批量提取TCA日志中指定文档 2023/11/19
#使用说明，将脚本与日志文件放在同一文件夹运行，日志必须是rar/zip/7z格式，一家医院一个压缩文件                       
#日志文件命名要求：TCA_流水线短号_医院中文标准名称_姓名_六位日期.rar/zip

$Pth = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $Pth

Write-Host 
"
************************************
***    TcaLogs tools DCS V1.0    ***
************************************
`n`n"

Write-Host "Starting extract TcaLogs" -ForegroundColor Yellow -BackgroundColor Black

Write-Host "Any key to continue..."
[System.Console]::ReadKey() | Out-Null

function New-Folder ($FolderName) {
    if (Test-Path $FolderName) {
        Remove-Item -Recurse $FolderName
    }
    New-Item -Path $Pth -ItemType Directory -Name $FolderName
}

function Remove-Folder ($FolderName){
    if (Test-Path $FolderName) {
        Remove-Item -Recurse $FolderName
    }   
}

$TcaLogs = Get-ChildItem -Path ($Pth.ToString() + "\DownloadLogs\") | Where-Object { $_.Extension -in ".zip", ".rar", ".7z" } | Sort-Object -Descending

#创建Log日志文件夹list
$Folder_Lists = @{"ActionsLog" = "*ctions*og*.txt"; "ErrorMessages" = "*rror*essage*.txt"; "BypassTagLogs" = "M21*ACLT_TAG.log"}

foreach($TcaLog in $TcaLogs){
    "`n`n"
    "=" * 100
    Write-Host ("Start to Extract Day log :  " + $TcaLog.Name) -BackgroundColor Black -ForegroundColor Yellow
    New-Folder("TcaLogTemp")
    New-Folder("TcaLogs")
    "-" * 100
    #解压所有的日志到TcaLogTemp
    $7zCom = "-o" + $Pth + "\TcaLogTemp\"
    7z.exe e $TcaLog.FullName $7zCom -r *.zip
    "-" * 100
    $TcaDayLogs = Get-ChildItem -Path ($Pth.ToString() + "\TcaLogTemp\") *zip

    #将一条流水线的解压出来的临时日志加上流水线大号/医院信息转存至TcaLogs
    foreach ($TcaDayLog in $TcaDayLogs) {
        $NewName = $Pth.ToString() + "\TcaLogs\" + $TcaLog.Name.Split(".")[0] + "_" + $TcaDayLog.Name
        Move-Item -Path $TcaDayLog.FullName -Destination $NewName
    }

    #创建Log输出文件夹
    foreach ($Folder_List in $Folder_Lists.Keys) {
        New-Folder($Folder_List)
    }

    $LogsFileZips = Get-ChildItem -Recurse -Path ($Pth.ToString() + "\TcaLogs\") -Filter *.zip

    $flag = 0
    $Step2 = 0
    foreach ($ZipLog in $LogsFileZips) {
        "-" * 100
        Write-Host ("Start to Extract File :  " + ($LogsFileZips.Count - $Step2).ToString()) -BackgroundColor Black -ForegroundColor Yellow

        #7z命令如下：
        foreach ($Folder_List in $Folder_Lists.Keys){
            $7zComTxt = "-o" + $Pth + "\" + $Folder_List + "\"
            7z.exe e  $ZipLog.FullName $7zComTxt $Folder_Lists[$Folder_List]
            $ToRenameLogs = Get-ChildItem -Recurse -Path $Pth -Filter $Folder_Lists[$Folder_List] #这里还可以优化
            if ($null -eq $ToRenameLogs) {
                continue
            }
            foreach ($ToRenameLog in $ToRenameLogs) {
                $flag ++
                $NewFileName = $ZipLog.Name.split(".")[0] + "_" + $flag.ToString() + ".txt"
                Rename-Item -Path $ToRenameLog.FullName -NewName $NewFileName
            }
        }      
        "-" * 100
        "`n`n"
        $Step2 ++    
    }
    7z a -tzip $TcaLog.Name "ActionsLog" "ErrorMessages" "BypassTagLogs"
}

Remove-Folder("TcaLogTemp")
Remove-Folder("TcaLogs")
foreach ($Folder_List in $Folder_Lists.Keys) {
    Remove-Folder($Folder_List)
}

"`n`n"
Write-Host "Any key to exit..." -ForegroundColor Yellow
[System.Console]::ReadKey() | Out-Null ; Exit
