#此脚本用于批量提取Site Agent生成的TOP最新日志，并以SN命令|2021-03-12
#4.0 增加其它日志导出

$pth = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $pth

function New-Folder {
    param (
        $NewFolderName
    )
    if (Test-Path $NewFolderName) {
        Remove-Item -Recurse $NewFolderName
    }
    New-Item -Path $pth -ItemType Directory -Name $NewFolderName
}

function Get-TopLogs {
    $CmprFiles = Get-ChildItem -Path ($pth.ToString() + "\DownloadLogs\") | Where-Object { $_.Extension -like ".rar" -or $_.Extension -like ".zip" -or $_.Extension -like ".7z"}
    $Step1 = 0
    if ($null -ne $CmprFiles) { 
        foreach ($CmprFile in $CmprFiles) {
            "-" * 100
            Write-Host (">>>>: " + ($CmprFiles.Count - $Step1).ToString() + "  " + $CmprFile.FullName) -BackgroundColor Black -ForegroundColor Yellow
            $CmprPath = "-o" + $pth + "\SourceLogs\" + $CmprFile.Name.Split(".")[0] + "\"
            7z.exe e $CmprFile.FullName $CmprPath -r *DBX*.zip -aos
            "-" * 100
            "`n`n"
            $Step1 ++
        }
    }
}

function Move-BadLogs {
    $Dest = $pth.ToString() + "\BadLogs\" + $ZipTopLog.Directory.Name.ToString() + "_" + $ZipTopLog.Name.ToString()
    Move-Item -Path $ZipTopLog.FullName -Destination $Dest
}

Write-Host 
"*********************************
***  ACL_Top Logs tools V4.0  ***
*********************************`n`n"

Write-Host "Starting to decompress Source TopLogs?" -ForegroundColor Yellow -BackgroundColor Black

$flag = Read-Host "Y/y for Yes, N/n for Next step："
if ($flag -eq "Y" -or $flag -eq "y"){

    $CmprFiles1 = Get-ChildItem -Path ($pth.ToString() + "\DownloadLogs\") | Where-Object { $_.Extension -like ".rar" -or $_.Extension -like ".zip" -or $_.Extension -like ".7z" }
    if ($null -eq $CmprFiles1){
        "No log files found. Any Key to Exit..."
        [System.Console]::ReadKey() | Out-Null ; Exit
    }

    New-Folder("SourceLogs")
    New-Folder("BadLogs")
    
    Get-TopLogs

    $TopHash = @{}
    $AllZipTopLogs = Get-ChildItem -Path ($pth + "\SourceLogs\") -Recurse -Filter *DBX*.zip

    foreach ($ZipTopLog in $AllZipTopLogs) {
        $ZipTopLogArray = $ZipTopLog.Name.Split("_")
        if ($ZipTopLogArray[0] -eq "DBX"){
            $SaNmae = "CHINA_ACLTOP_7X0_" + $ZipTopLog.Name.Split("_")[1] + "_0000028003X_" + $ZipTopLog.Name
            Rename-Item -Path $ZipTopLog.FullName -NewName $SaNmae
        }
        elseif ($ZipTopLogArray[3] -ne $ZipTopLogArray[6]) {
            Move-BadLogs
        }
    }
}

if ($flag -eq "Y" -or $flag -eq "y"){
    New-Folder("ProDX")
}

$FormatVar = 0
While (1){ 

    $TopHash = @{}
    $AllZipTopLogs = Get-ChildItem -Path ($pth + "\SourceLogs\") -Recurse -Filter *DBX*.zip

    if ($FormatVar -ge 1) {
        write-host	"`n`n"
    }
    $FormatVar ++
    #选择要输入的Log类型
    "`n`n"
    write-host "Select logs to Generate:" -ForegroundColor Yellow -BackgroundColor Black
    "1 : GeneralLog`n2 : CountersForAllTest`n3 : InstrumentStatusStatistics`n4 : Quit"
    $Select = read-host ">>"

    #定义要查找Log关键字
    if ($Select -eq 1) {
        $LogTxt = "generalLog.txt"
    }
    elseif ($Select -eq 2) {
        $LogTxt = "countersForAllTestTypesDeterminations.txt"
    }
    elseif ($Select -eq 3) {
        $LogTxt = "instrumentStatusStatistics.txt"
    }
	elseif ($Select -eq 4) {
        break
    }
    else {
        Write-Host "请正确输入!!!"
        Continue
    }

    #创建Log类型哈希表
    $SelectTable = @{"1" = "GeneralLogs"; "2" = "CountersForAllTest"; "3" = "InstrumentStatus"}
    $LogFoldName = $SelectTable[$Select]

    #创建Log输出文件夹
    New-Folder($LogFoldName)

    $AllZipTopLogs = Get-ChildItem -Path ($pth + "\SourceLogs\") -Recurse -Filter *DBX*.zip
    $i = 0
    foreach ($ZipTopLog in $AllZipTopLogs) {
        $i ++
        $TopHash[$ZipTopLog.Name.Split("_")[3]] = $i
    }

    $Step2 = 0
    foreach ($Sn in $TopHash.Keys) {
        "-" * 100
        $TopLog = (Get-ChildItem -Recurse -Path ($pth + "\SourceLogs\") -Filter ("*" + $Sn + "*DBX*.zip") | Sort-Object -Descending)[0]
        Write-Host (">>>>: " + ($TopHash.Count - $Step2).ToString() + "  " + $TopLog.FullName) -BackgroundColor Black -ForegroundColor Yellow
        $NameWithSN = $TopLog.Name.Split("_")[7] + "_" + $Sn + ".txt"
    
        $7zComTxt = "-o" + $pth + "\" + $LogFoldName + "\"
        7z.exe e $TopLog.FullName -pfixmeplease $7zComTxt $LogTxt -aos
        Rename-Item -Path (Get-ChildItem -Path $pth -Recurse -Filter $LogTxt).FullName -NewName $NameWithSN
        if (!(Test-Path ($pth.ToString() + "\ProDX\" + $TopLog.Name))){
            Copy-Item -Path $TopLog.FullName -Destination ($pth.ToString() + "\ProDX\")
        }
        "-" * 100
        "`n`n"
        $Step2 ++
    }
}
"`n"
Write-Host ((Get-ChildItem -Path ($pth.ToString() + "\BadLogs\")).Count.ToString()  + " bad logs" + " "*100) -BackgroundColor Black -ForegroundColor Yellow
"`n"
Write-Host "**********  TopLogs Generated  **********" -ForegroundColor Yellow -BackgroundColor Black
"Any Key to Exit..."
[System.Console]::ReadKey() | Out-Null ; Exit
