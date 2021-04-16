Function Get-FileName {  
    #[System.Reflection.Assembly]::Load("System.Windows.Forms") | Out-Null
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}

Write-Host "Select the Trace File:"
$trace_file = Get-FileName
$work_path = Split-Path -Parent $trace_file
Set-Location $work_path
Write-Host "Select function to filter the Trace:"
$select = Read-Host "1: E1427 in Clean Cup`n2: E1419 in Special Location`n>>"

if ($select -eq 1) {
    Select-String -Raw -Pattern "\|Reagent Arm\|Clean Step - Start\|.*\|7\|0\|0\||\|Reagent Arm\|AspLldCheck\|" -Path $trace_file | Select-String -Raw -Context 0,1 -Pattern "\|Clean Step - Start\|" > CleanCupR1.csv 
    Select-String -Raw -Pattern "\|Start Arm\|Clean Step - Start\|.*\|7\|0\|0\||\|Start Arm\|AspLldCheck\|" -Path $trace_file | Select-String -Raw -Context 0,1 -Pattern "\|Clean Step - Start\|" > CleanCupR2.csv
}
