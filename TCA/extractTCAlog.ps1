#此脚本用于批量提取TCA日志 2022-04-16
#使用说明，将脚本与日志文件放在同一文件夹运行，日志必须是rar/zip/7z格式，一家医院一个压缩文件
#日志文件命名要求：TCA_流水线短号_医院中文标准名称_姓名日期.rar/zip

$Pth = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $Pth
$allLog = "y" #选择Y导出所有日志，否则只导出一个

function New-Folder ($FolderName) {
    if (Test-Path $FolderName) {
        Remove-Item -Recurse $FolderName
    }
    New-Item -Path $Pth -ItemType Directory -Name $FolderName
}

function Get-TcaLog {
    $TcaLogs = Get-ChildItem -Path ($Pth.ToString() + "\DownloadLogs\") | Where-Object { $_.Extension -in ".zip", ".rar", ".7z" } | Sort-Object -Descending
    $Step1 = 0
    foreach ($TcaLog in $TcaLogs) {
        "-" * 100
        Write-Host ("Start to Extract File :  " + ($TcaLogs.Count - $Step1).ToString()) -BackgroundColor Black -ForegroundColor Yellow
        #解压所有的日志到TcaLogTemp
        $7zCom = "-o" + $Pth + "\TcaLogTemp\"
        7z.exe e $TcaLog.FullName $7zCom -r *.zip

        "-" * 100
        "`n`n"
        $Step1 ++
        $TcaDayLogs = Get-ChildItem -Path ($Pth.ToString() + "\TcaLogTemp\") *zip
        #将一条流水线的解压出来的临时日志加上流水线大号/医院信息转存至TcaLogs
        foreach ($TcaDayLog in $TcaDayLogs) {
            $NewName = $Pth.ToString() + "\TcaLogs\" + $TcaLog.Name.Split(".")[0] + "_" + $TcaDayLog.Name
            Move-Item -Path $TcaDayLog.FullName -Destination $NewName
        }
    }
}

Write-Host 
"*********************************
***    TcaLogs tools V3.0     ***
*********************************`n`n"
write-host "`nLog Export mode: $allLog`n"
Write-Host "Starting extract TcaLogs" -ForegroundColor Yellow -BackgroundColor Black

$flag = Read-Host "Y/y for Yes, N/n for Generate menu"

if ($flag -notin "N", "n") {
    New-Folder("TcaLogTemp")
    New-Folder("TcaLogs")
    Get-TcaLog
}

$FormatVar = 0
while (1) {
    if ($FormatVar -ge 1) {
        write-host	"`n`n"
    }
    $FormatVar ++
    #选择要输入的Log类型
    "`n`n"
    write-host "Select logs to Generate:" -ForegroundColor Yellow -BackgroundColor Black
    "1 : ActionsLog`n2 : ErrorMessages`n3 : BypassTagLogs`n4 : LasPcLogs`n5 : UIdebug`n6 : RouteDebug`n7 : Quit"
    $Select = read-host ">>"

    #定义要查找Log关键字
    if ($Select -eq 1) {
        $LogTxt = "*ctions*og*.txt"
    }
    elseif ($Select -eq 2) {
        $LogTxt = "*rror*essage*.txt"
    }
    elseif ($Select -eq 3) {
        $LogTxt = "M21*ACLT_TAG.log"
    }
    elseif ($Select -eq 4) {
        $LogTxt = "LASPC?.log"
    }
    elseif ($Select -eq 5) {
        $LogTxt = "uidebug*.txt"
    }
    elseif ($Select -eq 6) {
        $LogTxt = "RouterDebug*.txt"
    }
    elseif ($Select -eq 7) {
        Exit
    }
    else {
        Write-Host "请正确输入!!!"
        Continue
    }

    #创建Log类型哈希表
    $SelectTable = @{"1" = "ActionsLog"; "2" = "ErrorMessages"; "3" = "BypassTagLogs"; "4" = "LasPcLogs"; "5" = "UIdebug"; "6" = "RouterDebug"}
    $LogFoldName = $SelectTable[$Select]


    #创建Log输出文件夹
    New-Folder($LogFoldName)
    $LogsFileZips = Get-ChildItem -Recurse -Path ($Pth.ToString() + "\TcaLogs\") -Filter *.zip
    $distinct_hosp_hashtable = @{}
    foreach ($ZipLog in $LogsFileZips) {
        $distinct_hosp_hashtable[$ZipLog.Name.Split("_")[1]] = 1
    }
    $flag = 0
    $Step2 = 0
    if ($allLog -in "y" ,"Y") {
        foreach ($ZipLog in $LogsFileZips) {
            "-" * 100
            Write-Host ("Start to Extract File :  " + ($LogsFileZips.Count - $Step2).ToString()) -BackgroundColor Black -ForegroundColor Yellow

            #7z命令如下：
            $7zComTxt = "-o" + $Pth + "\" + $LogFoldName + "\"
            7z.exe e  $ZipLog.FullName $7zComTxt $LogTxt

            "-" * 100
            "`n`n"
            $Step2 ++
            $ToRenameLogs = Get-ChildItem -Recurse -Path $Pth -Filter $LogTxt
            if ($null -eq $ToRenameLogs) {
                continue
            }

            foreach ($ToRenameLog in $ToRenameLogs) {
                $flag ++
                $NewFileName = $ZipLog.Name.split(".")[0]
                if ($NewFileName.Split("_").Count -eq 7) {
                    $NewFileName = $NewFileName + "_" + $flag.ToString() + ".txt"
                }
                else {
                    $NewFileName = $NewFileName + "_abcdefghijk" + "_" + $flag.ToString() + ".txt"
                }
                Rename-Item -Path $ToRenameLog.FullName -NewName $NewFileName
            }
        }
    }
    else {
        foreach ($fathersn in $distinct_hosp_hashtable.Keys) {
            $ZipLog = (Get-ChildItem -Recurse -Path ($Pth.ToString() + "\TcaLogs\") -Filter "*$fathersn*.zip" | Sort-Object -Property Length -Descending)[0]
            "-" * 100
            Write-Host ("Start to Extract File :  " + ($distinct_hosp_hashtable.Count - $Step2).ToString()) -BackgroundColor Black -ForegroundColor Yellow

            #7z命令如下：
            $7zComTxt = "-o" + $Pth + "\" + $LogFoldName + "\"
            7z.exe e  $ZipLog.FullName $7zComTxt $LogTxt

            "-" * 100
            "`n`n"
            $Step2 ++
            $ToRenameLogs = Get-ChildItem -Recurse -Path $Pth -Filter $LogTxt
            if ($null -eq $ToRenameLogs) {
                continue
            }
            
            foreach ($ToRenameLog in $ToRenameLogs) {
                $flag ++
                $NewFileName = $ZipLog.Name.split(".")[0]
                if ($NewFileName.Split("_").Count -eq 7) {
                    $NewFileName = $NewFileName + "_" + $flag.ToString() + ".txt"
                }
                else {
                    $NewFileName = $NewFileName + "_abcdefghijk" + "_" + $flag.ToString() + ".txt"
                }
                Rename-Item -Path $ToRenameLog.FullName -NewName $NewFileName
            }
        } 
    }   
}
