#ACL TOP log export tool 5.0
# Update log
# 2023-05-19 add tasklist export

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
$date_time =  Get-Date -Format "yyyy-MM-dd_hh-mm-ss"
Start-Transcript "Ps_log_$date_time.txt"

Write-Host 
"*************************************************************
***  ACL TOP log exported by DBExtract.1.21 or SiteAgent  ***
*************************************************************`n`n"

Write-Host "Starting to decompress Source TopLogs?" -ForegroundColor Yellow -BackgroundColor Black
$flag = Read-Host "Y/y for Yes, N/n for Next step "
if ($flag -eq "Y" -or $flag -eq "y") {
    $source_log_packages = Get-ChildItem -Path ($work_pth.ToString() + "\DownloadLogs\") | Where-Object { $_.Extension -like ".rar" -or $_.Extension -like ".zip" -or $_.Extension -like ".7z" }
    if ($null -eq $source_log_packages) {
        "No log files found. Any Key to Exit..."
        [System.Console]::ReadKey() | Out-Null ; Exit
    }

    New-Folder("SourceLogs")
    New-Folder("BadLogs")

    $toplog_DBXs = Get-ChildItem -Path ($work_pth + "\DownloadLogs\") -Recurse -Filter *DBX_*_????-??-??_??-??-??*.zip
    if ($null -ne $toplog_DBXs){
        foreach ($toplog_DBX in $toplog_DBXs) {
            $toplog_DBX_split = $toplog_DBX.Name.Split("_")
            if ($toplog_DBX_split[0] -eq "DBX") {
                $newname0 = $work_pth.ToString() + "\SourceLogs\" + "CHINA_ACLTOP_7X0_" + $toplog_DBX.Name.Split("_")[1] + "_0000028003X_" + $toplog_DBX.Name
                Copy-Item -Path $toplog_DBX.FullName -Destination $newname0
                Continue
            }
            elseif ($toplog_DBX_split[3] -ne $toplog_DBX_split[6]) {
                #move bad logs
                $badlog_fullpath0 = $work_pth.ToString() + "\BadLogs\" + $toplog_DBX.Directory.Name.ToString() + "_" + $toplog_DBX.Name.ToString()
                Copy-Item -Path $toplog_DBX.FullName -Destination $badlog_fullpath0
            }
            else {
                $newname1 = $work_pth.ToString() + "\SourceLogs\" + $toplog_DBX.Name
                Copy-Item -Path $toplog_DBX.FullName -Destination $newname1
            }
        }
    }
    
    $Step1 = 0
    foreach ($source_log_package in $source_log_packages) {
        "-" * 100
        Write-Host (">>>>: " + ($source_log_packages.Count - $Step1).ToString() + "  " + $source_log_package.FullName) -BackgroundColor Black -ForegroundColor Yellow
        $sourceLogs_folder_pth = "-o" + $work_pth + "\SourceLogs\" + $source_log_package.Name.Split(".")[0] + "\"
        7z.exe e $source_log_package.FullName $sourceLogs_folder_pth -r *DBX*.zip -aos
        "-" * 100
        "`n`n"
        $Step1 ++
    }
    
    $toplog_DBXs = Get-ChildItem -Path ($work_pth + "\SourceLogs\") -Recurse -Filter *DBX*.zip

    foreach ($toplog_DBX in $toplog_DBXs) {
        $toplog_DBX_split = $toplog_DBX.Name.Split("_")
        if ($toplog_DBX_split[0] -eq "DBX") {
            $newname2 = "CHINA_ACLTOP_7X0_" + $toplog_DBX.Name.Split("_")[1] + "_0000028003X_" + $toplog_DBX.Name
            Rename-Item -Path $toplog_DBX.FullName -NewName $newname2
            Continue
        }
        elseif ($toplog_DBX_split[3] -ne $toplog_DBX_split[6]) {
            #move bad logs
            $badlog_fullpath1 = $work_pth.ToString() + "\BadLogs\" + $toplog_DBX.Directory.Name.ToString() + "_" + $toplog_DBX.Name.ToString()
            Move-Item -Path $toplog_DBX.FullName -Destination $badlog_fullpath1
        }
    }
}

if ($flag -eq "Y" -or $flag -eq "y") {
    New-Folder("ProDX")
}

"`n"
Write-Host ((Get-ChildItem -Path ($work_pth.ToString() + "\BadLogs\")).Count.ToString() + " bad logs" + " " * 100) -BackgroundColor Black -ForegroundColor Yellow

$FormatVar = 0
While (1) { 
    if ($FormatVar -ge 1) {
        write-host	"`n`n"
    }
    $FormatVar ++
    #Select the log type
    "`n`n"
    write-host "Select logs to Generate:" -ForegroundColor Yellow -BackgroundColor Black
    "1 : GeneralLog`n2 : CountersForAllTest`n3 : InstrumentStatusStatistics`n4 : sw_all_versions`n5 : taskList`n6 : Quit"
    $Select = read-host ">>"

    #define the keyword to generate log
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
        $LogTxt = "sw_all_versions.txt"
    }
    elseif ($Select -eq 5) {
        $LogTxt = "TASKLIST.txt"
    }
    elseif ($Select -eq 6) {
        break
    }
    else {
        Write-Host "Please input number 1-5"
        Continue
    }

    #create the logtype hashtable
    $SelectTable = @{"1" = "GeneralLogs"; "2" = "CountersForAllTest"; "3" = "InstrumentStatus"; "4" = "SoftwareVersions"; "5" = "taskList"}
    $txt_toplog_folder = $SelectTable[$Select]

    #create the output folder
    New-Folder($txt_toplog_folder)

    $i = 0
    #create empty hashtable to store the top sn
    $sn_hashtable = @{}
    $toplog_DBXs = Get-ChildItem -Path ($work_pth + "\SourceLogs\") -Recurse -Filter *DBX*.zip
    foreach ($toplog_DBX in $toplog_DBXs) {
        $i ++
        $sn_hashtable[$toplog_DBX.Name.Split("_")[3]] = $i
    }

    $Step2 = 0
    $text_toplog_fullpath = "-o" + $work_pth + "\" + $txt_toplog_folder + "\"
    foreach ($Sn in $sn_hashtable.Keys) {
        "-" * 100
        $toplog_DBX = (Get-ChildItem -Recurse -Path ($work_pth + "\SourceLogs\") -Filter ("*" + $Sn + "*DBX*.zip") | Sort-Object -Descending)[0]
        Write-Host (">>>>: " + ($sn_hashtable.Count - $Step2).ToString() + "  " + $toplog_DBX.FullName) -BackgroundColor Black -ForegroundColor Yellow
        $toplog_date_SN = $toplog_DBX.Name.Split("_")[7] + "_" + $Sn + ".txt"

        #7z decompress the DBX file to txt_toplog_folder
        7z.exe e $toplog_DBX.FullName -pfixmeplease $text_toplog_fullpath $LogTxt -aos
        $rename_source = Get-ChildItem -Path "$work_pth\$txt_toplog_folder" -Recurse -Filter $LogTxt
        Rename-Item -Path $rename_source.FullName -NewName $toplog_date_SN
        if (!(Test-Path ($work_pth.ToString() + "\ProDX\" + $toplog_DBX.Name))) {
            Copy-Item -Path $toplog_DBX.FullName -Destination ($work_pth.ToString() + "\ProDX\")
        }
        "-" * 100
        "`n`n"
        $Step2 ++
    }
    $ip = Read-Host "Drop the date form filename? Y/y for Yes, N/n for Next " 
    if (@("Y","y") -contains $ip){
        $txt_toplogs = Get-ChildItem -Path ($work_pth + "\$txt_toplog_folder") -Filter *.txt
        foreach ($txt_toplog in $txt_toplogs) {
            $txt_toplog.FullName.ToString()
            Rename-Item -Path $txt_toplog.FullName ("T" + $txt_toplog.Name.Split("_")[1])
        }
    }
}
Stop-Transcript
"`n"
Write-Host "**********  TopLogs Generated  **********" -ForegroundColor Yellow -BackgroundColor Black