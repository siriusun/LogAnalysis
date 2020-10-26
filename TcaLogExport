#此脚本用于批量提取TCA日志
#使用说明，将脚本与日志文件放在同一文件夹运行，日志必须是rar/zip格式，一家医院一个压缩文件
#日志文件命名要求：TCALOG_流水线大号_医院中文标准名称.rar/zip

$Pth = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $Pth

#给所有的LOG加上序号
$PreTcaLogs = Get-ChildItem -Path $Pth -Filter TCALOG_167*
$Order = 1
foreach ($PreTcaLog in $PreTcaLogs){
    $NewSortName = $Order.ToString() + "_" + $PreTcaLog.Name
    Rename-Item -Path $PreTcaLog.FullName -NewName $NewSortName
    $Order++
}

#Fuction
function New-Folder ($FolderName) {
    if (Test-Path $FolderName) {
        Remove-Item -Recurse $FolderName
    }
    New-Item -Path $Pth -ItemType Directory -Name $FolderName
}

function Get-TcaLog ($Ext) {
    $TcaLogs = Get-ChildItem -Path $Pth -Filter $Ext
    foreach ($TcaLog in $TcaLogs) {
        $7zCom = "-o" + $Pth + "\TcaLogTemp\"
        7z.exe e $TcaLog.FullName $7zCom -r *.zip

        $TcaDayLogs = Get-ChildItem -Path ($Pth.ToString() + "\TcaLogTemp\") *zip
        foreach ($TcaDayLog in $TcaDayLogs) {
            $NewName = $Pth.ToString() + "\TcaLogs\" + $TcaLog.Name.Split(".")[0] + "_" + $TcaDayLog.Name
            Move-Item -Path $TcaDayLog.FullName -Destination $NewName
        }
    }
}


Write-Host 
"*********************************
***    TcaLogs tools V2.1     ***
*********************************


"
Write-Host "Starting extract TcaLogs" -ForegroundColor Yellow -BackgroundColor Black


$flag = Read-Host "Y/y for Yes, N/n for Quit"

if ($flag -ne "N" -and $flag -ne "n"){
    New-Folder("TcaLogTemp")
    New-Folder("TcaLogs")

    Get-TcaLog("*.rar")
    Get-TcaLog("*.zip")
}

$FormatVar = 0
while (1) {

    if ($FormatVar -ge 1) {
        write-host	"
        
        "
    }
    $FormatVar ++
    #选择要输入的Log类型
    "
    
    "
    write-host "Select logs to Generate:" -ForegroundColor Yellow -BackgroundColor Black
    "1 : ActionsLog`n2 : ErrorMessages`n3 : BypassTagLogs`n4 : Quit"
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
        Exit
    }
    else {
        Write-Host "请正确输入!!!"
        Continue
    }

    #创建Log类型哈希表
    $SelectTable = @{"1" = "ActionsLog"; "2" = "ErrorMessages"; "3" = "BypassTagLogs" }
    $LogFoldName = $SelectTable[$Select]

    #创建Log输出文件夹
    New-Folder($LogFoldName)

    $LogsFileZips = Get-ChildItem -Recurse -Path ($Pth.ToString() + "\TcaLogs\") -Filter *.zip
    $flag = 0
    foreach ($ZipLog in $LogsFileZips) {
        "-" * 100

        #7z命令如下：
        $7zComTxt = "-o" + $Pth + "\" + $LogFoldName + "\"
        7z.exe e  $ZipLog.FullName $7zComTxt $LogTxt

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
        "-" * 100
        "
        
        "
    } 
}
