#BF log export tool 1.0 2023/04/25

Function Get-FileName {  
    #[System.Reflection.Assembly]::Load("System.Windows.Forms") | Out-Null
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    $OpenFileDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.SelectedPath
}

function New-Folder {
    param (
        $NewFolderName
    )
    if (Test-Path $NewFolderName) {
        Remove-Item -Recurse $NewFolderName
    }
    New-Item -Path $work_pth -ItemType Directory -Name $NewFolderName
}

while ($True) {
    Write-Host "How to Get Work Path:`n1 : Current Folder`n2 : Select one"
    $pth = Read-Host ">>"

    if ($pth -eq 1) {
        $work_pth = Split-Path -Parent $MyInvocation.MyCommand.Definition
        break
    }
    elseif ($pth -eq 2) {
        Write-Host "Select the Data folder..." -ForegroundColor Yellow -BackgroundColor Black
        $work_pth = Get-FileName
        break
    }
    else {
        Write-Host "Input 1/2!!" -BackgroundColor Blue -ForegroundColor Red
    }
}
Write-Host "Work Path: $work_pth" -ForegroundColor Yellow -BackgroundColor Black
Set-Location $work_pth

Write-Host 
"*************************************************************
***            BIO-FLASH Log Exported by Agent            ***
*************************************************************`n`n"

Write-Host "Starting to decompress Source Logs?" -ForegroundColor Yellow -BackgroundColor Black
$flag = Read-Host "Y/y for Yes, N/n for Next step "
if ($flag -eq "Y" -or $flag -eq "y") {
    $source_log_packages = Get-ChildItem -Path ($work_pth.ToString() + "\DownloadLogs\") | Where-Object { $_.Extension -like ".rar" -or $_.Extension -like ".zip" -or $_.Extension -like ".7z" }
    if ($null -eq $source_log_packages) {
        "No log files found. Any Key to Exit..."
        [System.Console]::ReadKey() | Out-Null ; Exit
    }

    New-Folder("SourceLogs")
    New-Folder("InstrumentLog")
    
    $Step1 = 0
    foreach ($source_log_package in $source_log_packages) {
        "-" * 100
        Write-Host (">>>>: " + ($source_log_packages.Count - $Step1).ToString() + "  " + $source_log_package.FullName) -BackgroundColor Black -ForegroundColor Yellow
        $sourceLogs_folder_pth = "-o" + $work_pth + "\SourceLogs\"
        &'.\7z.exe' e $source_log_package.FullName $sourceLogs_folder_pth -r InstrumentLog* -aos
        $temp_log = Get-ChildItem -Path ($work_pth + "\SourceLogs\") -Recurse -Filter InstrumentLog*
        if ($temp_log.Extension -eq ".json"){
            Rename-Item -Path $temp_log.FullName -NewName ($source_log_package.BaseName + ".json")
        }
        else {
            Move-Item -Path $temp_log.FullName -Destination  ($work_pth.ToString() + "\InstrumentLog\" + $source_log_package.BaseName + ".txt")
        }
        "-" * 100
        "`n`n"
        $Step1 ++
    }
}

$json_logs = Get-ChildItem -Recurse -Path ($work_pth + "\SourceLogs\")
"`n"
Write-Host  "JSON logs: "$json_logs.Count
"`n"

Write-Host "**********  BIOFLASH Logs Generated  **********" -ForegroundColor Yellow -BackgroundColor Black

"`n"

while ($True) {
    Write-Host "Select mode:`n1 : Entire Mode`n2 : Light Mode"
    $mode_select = Read-Host ">>"

    if ($mode_select -eq 1) {
        .\concatBFLOGforEXE.exe
        break
    }
    elseif ($mode_select -eq 2) {
        .\concatBFLOGforEXE.exe -l
        break
    }
    else {
        Write-Host "Input 1/2!!" -BackgroundColor Blue -ForegroundColor Red
    }
}


