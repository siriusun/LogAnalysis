#此脚本用于批量提取 DBExtract1.21.exe 生成的TOP最新日志，并以SN命令|2021-01-22

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
***  ACL_Top Logs tools V3.0  ***
*********************************`n`n"

Write-Host "Starting Generate TopLogs?" -ForegroundColor Yellow -BackgroundColor Black

$flag = Read-Host "Y/y for Yes, N/n for Quit"
if ($flag -eq "N" -or $flag -eq "n"){
    Exit
}

$CmprFiles1 = Get-ChildItem -Path ($pth.ToString() + "\DownloadLogs\") | Where-Object { $_.Extension -like ".rar" -or $_.Extension -like ".zip" -or $_.Extension -like ".7z" }
if ($null -eq $CmprFiles1){
    "No log files found. Any Key to Exit..."
    [System.Console]::ReadKey() | Out-Null ; Exit
}

New-Folder("SourceLogs")
New-Folder("GeneralLogs")
New-Folder("BadLogs")
New-Folder("ProDX")

Get-TopLogs

$DBEzipLogs = Get-ChildItem -Path ($pth + "\SourceLogs\") -Recurse DBX_*.zip
foreach ($DBEzipLog in $DBEzipLogs) {
    $SaNmae = "CHINA_ACLTOP_7X0_" + $DBEzipLog.Name.Split("_")[1] + "_0000028003X_" + $DBEzipLog.Name
    Rename-Item -Path $DBEzipLog.FullName -NewName $SaNmae
}

$TopHash = @{}
$AllZipTopLogs = Get-ChildItem -Path ($pth + "\SourceLogs\") -Recurse -Filter *DBX*.zip

foreach ($ZipTopLog in $AllZipTopLogs) {
    $ZipTopLogArray = $ZipTopLog.Name.Split("_")
    if ($ZipTopLogArray[0] -ne "CHINA"){
        Move-BadLogs
    }
    elseif ($ZipTopLogArray[3] -ne $ZipTopLogArray[6]) {
        Move-BadLogs
    }
}

$AllZipTopLogs = Get-ChildItem -Path ($pth + "\SourceLogs\") -Recurse -Filter *DBX*.zip
$i = 0
foreach ($ZipTopLog in $AllZipTopLogs) {
    $i ++
    $TopHash[$ZipTopLog.Name.Split("_")[3]] = $i
}

$k = 0
$Step2 = 0
foreach ($Sn in $TopHash.Keys) {
    $k ++
    "-" * 100
    $TopLog = (Get-ChildItem -Recurse -Path ($pth + "\SourceLogs\") -Filter ("*" + $Sn + "*DBX*.zip") | Sort-Object -Descending)[0]
    Write-Host (">>>>: " + ($TopHash.Count - $Step2).ToString() + "  " + $TopLog.FullName) -BackgroundColor Black -ForegroundColor Yellow
    $NameWithSN = $k.ToString() + "_" + $Sn + "_" + $TopLog.Name.Split("_")[7] + ".txt"
    
    $7zComTxt = "-o" + $pth + "\GeneralLogs\"
    7z.exe e $TopLog.FullName -pfixmeplease $7zComTxt GeneralLog.txt -aos
    Rename-Item -Path (Get-ChildItem -Path $pth -Recurse -Filter GeneralLog.txt).FullName -NewName $NameWithSN
    Move-Item -Path $TopLog.FullName -Destination ($pth.ToString() + "\ProDX\")
    "-" * 100
    "`n`n"
    $Step2 ++
}

Write-Host ((Get-ChildItem -Path ($pth.ToString() + "\BadLogs\")).Count.ToString()  + " bad logs" + " "*100) -BackgroundColor Black -ForegroundColor Yellow
"`n"
Write-Host "**********  TopLogs Generated  **********" -ForegroundColor Yellow -BackgroundColor Black
"Any Key to Exit..."
[System.Console]::ReadKey() | Out-Null ; Exit