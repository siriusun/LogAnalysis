$workPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$textFiles = Get-ChildItem -Recurse -Path $workPath -Filter *.log

$time = Get-Date
$textFiles | ForEach-Object {
    Write-Host $_.FullName
    Get-Content $_ >> "$workPath\one.csv"
}
Write-Host ($(Get-Date) - $time)