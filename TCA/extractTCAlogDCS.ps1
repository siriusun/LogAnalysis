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
$Folder_Lists = @{"TCActions" = "?ctions?og*.txt"; "ErrorMsg" = "?rror?essage*.txt"; "BypassTag" = "M21*ACLT_TAG.log"; "LasStatistics" = "LasStatistics.txt"}
$Folder_Lists_forOneFile = @{"TCAInfo" = "Controller_systeminfo.txt"; "LasConf" = "LasConf.ini"; "SWVersions" = "Versions.txt"}

foreach($TcaLog in $TcaLogs){
    "`n`n"
    "=" * 100
    Write-Host ("Start to Extract Day log: " + $TcaLog.Name) -BackgroundColor Black -ForegroundColor Yellow
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
        $NewName = $Pth.ToString() + "\TcaLogs\" + $TcaLog.Name.Split(".")[0] + "_" + $TcaDayLog.Name.Split("_")[0] + "_" + $TcaDayLog.Name.Split("_")[1] + ".zip"
        Move-Item -Path $TcaDayLog.FullName -Destination $NewName
    }

    #创建Log输出文件夹
    foreach ($Folder_List in $Folder_Lists.Keys) {
        New-Folder($Folder_List)
    }
    foreach ($Folder in $Folder_Lists_forOneFile.Keys) {
        New-Folder($Folder)
    }

    $LogsFileZips = Get-ChildItem -Recurse -Path ($Pth.ToString() + "\TcaLogs\") -Filter *.zip

    $flag = 0
    foreach ($ZipLog in $LogsFileZips) {
        "-" * 100

        #7z命令如下：
        foreach ($Folder_List in $Folder_Lists.Keys){
            "`n"
            Write-Host ("Start to Extract $Folder_List in: " + $ZipLog.Name.ToString()) -BackgroundColor Black -ForegroundColor Yellow
            $7zComTxt = "-o" + $Pth + "\" + $Folder_List + "\"
            7z.exe e  $ZipLog.FullName $7zComTxt $Folder_Lists[$Folder_List]
            $ToRenameLogs = Get-ChildItem -Recurse -Path ($Pth + "\" + $Folder_List) -Filter $Folder_Lists[$Folder_List]
            if ($null -eq $ToRenameLogs) {
                continue
            }
            foreach ($ToRenameLog in $ToRenameLogs) {
                $flag ++
                $NewFileName = $Folder_List + "_" + $ZipLog.Name.split(".")[0] + "_" + $flag.ToString() + "_" + $ToRenameLog.BaseName + ".txt"
                Rename-Item -Path $ToRenameLog.FullName -NewName $NewFileName
            }
        }      
        "-" * 100
        "`n`n"
    }

    $theOneZip = (Get-ChildItem -Recurse -Path ($Pth.ToString() + "\TcaLogs\") -Filter *.zip | Sort-Object  -Property Length -Descending)[0]
    "-" * 100

    #7z命令如下：
    foreach ($Folder in $Folder_Lists_forOneFile.Keys){
        "`n"
        Write-Host ("Start to Extract $Folder in:  " + $theOneZip.Name.ToString()) -BackgroundColor Black -ForegroundColor Yellow
        $7zComTxt = "-o" + $Pth + "\" + $Folder + "\"
        7z.exe e  $theOneZip.FullName $7zComTxt $Folder_Lists_forOneFile[$Folder]
        $ToRenameLog = Get-ChildItem -Recurse -Path ($Pth + "\" + $Folder)  -Filter $Folder_Lists_forOneFile[$Folder]
        if ($null -eq $ToRenameLogs) {
            continue
        }

        $NewFileName = $Folder + "_" + $theOneZip.Name.split(".")[0] + ".txt"
        Rename-Item -Path $ToRenameLog.FullName -NewName $NewFileName
    }      
    "-" * 100
    "`n`n"
    7z a -tzip $TcaLog.Name $Folder_Lists.Keys $Folder_Lists_forOneFile.Keys
}

Remove-Folder("TcaLogTemp")
Remove-Folder("TcaLogs")
foreach ($Folder_List in $Folder_Lists.Keys) {
    Remove-Folder($Folder_List)
}
foreach ($Folder in $Folder_Lists_forOneFile.Keys) {
    Remove-Folder($Folder)
}

"`n`n"
Write-Host "Any key to exit..." -ForegroundColor Yellow
[System.Console]::ReadKey() | Out-Null ; Exit
