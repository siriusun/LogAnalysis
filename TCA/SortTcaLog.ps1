$Pth = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $Pth

$TcaLogs = Get-ChildItem -Path ($Pth.ToString() + "\DownloadLogs\") -Filter TCALOG_167*

foreach ($TcaLog in $TcaLogs){
    if ($TcaLog.Name.Split("_")[1][-5] -eq "-") {
        $Order = -join $TcaLog.Name.Split("_")[1][-4..-1]
    }
    else {
        $Order = -join $TcaLog.Name.Split("_")[1][-2..-1]
    }
    $NewSortName = $Order.ToString() + "_" + $TcaLog.Name
    Write-Host $TcaLog.FullName
    Rename-Item -Path $TcaLog.FullName -NewName $NewSortName
}
"Any Key to Exit..."
[System.Console]::ReadKey() | Out-Null ; Exit