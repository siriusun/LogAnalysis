$Pth = Split-Path -Parent $MyInvocation.MyCommand.Definition
$GeneralLogs = Get-ChildItem -Path ($Pth + "\GeneralLogs\") -Filter *.txt

foreach ($GeneralLog in $GeneralLogs){
	$GeneralLog.FullName.ToString()
    Rename-Item -Path $GeneralLog.FullName ("T" + $GeneralLog.Name.Split("_")[1])
}
"Any Key to Exit..."
[System.Console]::ReadKey() | Out-Null ; Exit