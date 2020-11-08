#此脚本用于批量提取Site Agent生成的TOP最新日志，并以SN命令|2020-10-26

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
    $CmprFiles = Get-ChildItem -Path $pth | Where-Object {$_.Extension -like ".rar" -or $_.Extension -like ".zip"}
    $Step1 = 0
    if ($null -ne $CmprFiles) { 
        foreach ($CmprFile in $CmprFiles) {
            "-" * 100
            Write-Host (">>>>: " + ($CmprFilesNum.Count - $Step1).ToString() + "  " + $CmprFile.FullName) -BackgroundColor Black -ForegroundColor Yellow
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

$CmprFiles1 = Get-ChildItem *.[zr][ia][pr]
if ($null -eq $CmprFiles1){
    "No log files found. Any Key to Exit..."
    [System.Console]::ReadKey() | Out-Null ; Exit
}

New-Folder("SourceLogs")
New-Folder("GeneralLogs")
New-Folder("BadLogs")

Get-TopLogs

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
    "-" * 100
    "`n`n"
    $Step2 ++
}

"`n`n"
Write-Host "**********  TopLogs Generated  **********" -ForegroundColor Yellow -BackgroundColor Black
"Any Key to Exit..."
[System.Console]::ReadKey() | Out-Null ; Exit
