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

#获取Downloads文件夹中日志压缩包列表
$TcaLogs = Get-ChildItem -Path ($Pth.ToString() + "\DownloadLogs\") | Where-Object { $_.Extension -in ".zip", ".rar", ".7z" } | Sort-Object -Descending

if ($null -eq $TcaLogs){
    "`n"
    Write-Host "Please put TCA Log in DownloadLogs folder. Any key to exit..." -ForegroundColor Red
    [System.Console]::ReadKey() | Out-Null ; Exit
}

$log_name_is_correct = 1
foreach ($TcaLog in $TcaLogs){
    if ($TcaLog.Name -notmatch "^TCA_H\d\d\d_[\u4e00-\u9fa5]+_[\u4e00-\u9fa5]{2,3}_2(3|4|5)(0[1-9]|1[0-2])(0[1-9]|1\d|2[0-9]|3[01])\.(zip|ZIP|rar|RAR|7z|7Z)$"){
        $logname = $TcaLog.Name
        "`n"
        Write-Host "Please using standard format to name the TCA log:" -ForegroundColor Yellow
        Write-Host $logname -ForegroundColor Red
        $log_name_is_correct = 0
    }
}
if ($log_name_is_correct -eq 0){
    "`n"
    Write-Host "Any key to exit..."
    [System.Console]::ReadKey() | Out-Null ; Exit
}

#创建Log日志文件夹字典, $Folder_Lists 是需要导出每天的，$Folder_Lists_forOneFile 是需要导出体积最大日志中的个别文档的；
#需要增加日志文档导出，只要在这里设置好文件夹名称与检索关键词即可，*？使用要合理设置，仔细检查
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
    &"tools\7z.exe" e $TcaLog.FullName $7zCom -r *.zip
    "-" * 100
    $TcaDayLogs = Get-ChildItem -Path ($Pth.ToString() + "\TcaLogTemp\") *zip

    #将一条流水线的解压出来的临时日志加上流水线大号/医院信息转存至TcaLogs
    $count = 1
    foreach ($TcaDayLog in $TcaDayLogs) {
        $NewName = $Pth.ToString() + "\TcaLogs\" + $TcaLog.Name.Split(".")[0] + "_" + $TcaDayLog.Name.Split("_")[0] + "_" + $TcaDayLog.Name.Split("_")[1] + $count.ToString() + ".zip"
        Write-Host "Move log: $NewName"
        Move-Item -Path $TcaDayLog.FullName -Destination $NewName
        $count ++
    }

    #创建Log输出文件夹
    foreach ($Folder_List in $Folder_Lists.Keys) {
        New-Folder($Folder_List)
    }
    foreach ($Folder in $Folder_Lists_forOneFile.Keys) {
        New-Folder($Folder)
    }

    #获取TcaLogs中已命名好的日志压缩包
    $LogsFileZips = Get-ChildItem -Recurse -Path ($Pth.ToString() + "\TcaLogs\") -Filter *.zip

    $flag = 0
    foreach ($ZipLog in $LogsFileZips) {
        "-" * 100

        #根据$Folder_Lists中关键词内容，分别提取每天TCA日志中相应文档，保存至相应文件夹并命名
        foreach ($Folder_List in $Folder_Lists.Keys){
            "`n"
            Write-Host ("Start to Extract $Folder_List in: " + $ZipLog.Name.ToString()) -BackgroundColor Black -ForegroundColor Yellow
            $7zComTxt = "-o" + $Pth + "\" + $Folder_List + "\"
            &"tools\7z.exe" e  $ZipLog.FullName $7zComTxt $Folder_Lists[$Folder_List]
            #获取需要命名的日志，只有未命名的日志才会被执行，如需后加内容，要注意$Folder_Lists与$Folder_Lists_forOneFile中关键词设置，小心*？号使用，确保过滤准确
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

    #根据$Folder_Lists_forOneFile中关键词内容，提取最大的那个TCA日志中相应文档，保存至相应文件夹并命名
    foreach ($Folder in $Folder_Lists_forOneFile.Keys){
        "`n"
        Write-Host ("Start to Extract $Folder in:  " + $theOneZip.Name.ToString()) -BackgroundColor Black -ForegroundColor Yellow
        $7zComTxt = "-o" + $Pth + "\" + $Folder + "\"
        &"tools\7z.exe" e  $theOneZip.FullName $7zComTxt $Folder_Lists_forOneFile[$Folder]
        $ToRenameLog = Get-ChildItem -Recurse -Path ($Pth + "\" + $Folder)  -Filter $Folder_Lists_forOneFile[$Folder]
        if ($null -eq $ToRenameLogs) {
            continue
        }

        $NewFileName = $Folder + "_" + $theOneZip.Name.split(".")[0] + ".txt"
        Rename-Item -Path $ToRenameLog.FullName -NewName $NewFileName
    }      
    "-" * 100
    "`n`n"
    #将导出的日志打包，可以直接用文件夹名称列表将所需打包文件夹包含进来
    &"tools\7z.exe" a -tzip ("mini" + $TcaLog.Name) $Folder_Lists.Keys $Folder_Lists_forOneFile.Keys
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
