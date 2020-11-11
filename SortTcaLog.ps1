$Pth = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $Pth

$TcaLogs = Get-ChildItem -Path ($Pth.ToString() + "\DownloadLogs\") -Filter TCALOG_167*
[Int64]$Flag = Read-Host "Please input start order number :"

foreach ($TcaLog in $TcaLogs){
    $NewSortName = $Flag.ToString() + "_" + $TcaLog.Name
    Write-Host $TcaLog.FullName
    Rename-Item -Path $TcaLog.FullName -NewName $NewSortName
    $Flag ++
}
"Any Key to Exit..."
[System.Console]::ReadKey() | Out-Null ; Exit