$work_pth = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $work_pth

function New-Folder {
    param (
        $NewFolderName
    )
    if (Test-Path $NewFolderName) {
        Remove-Item -Recurse $NewFolderName
    }
    New-Item -Path $work_pth -ItemType Directory -Name $NewFolderName
}

"Start processing exam report to area folder..."
"Any key to continue..."
[System.Console]::ReadKey() | Out-Null

$prefixed = "Hemo monthly exam 2022-xx "
$fseList = Import-Csv "ServiceFSElist.csv"
$areas = ("North", "South", "West" , "East1", "East2","Henan")
$papers = Get-ChildItem -Path $work_pth -Recurse -Filter *.docx

if ($null -eq $papers){
    "`nNo report founded, any key to exit..."
    [System.Console]::ReadKey() | Out-Null ; Exit
}

foreach ($area in $areas) {
    New-Folder ($prefixed + $area)
}

foreach ($paper in $papers){
	$nameCN = $paper.Name.Split("】")[0].Split("【")[1]
    $fseIndex = $fseList.NameCN.IndexOf($nameCN)
    if($fseIndex -lt 0){
        "`n"
        Write-Host ($nameCN + " not found")
        continue
    }
    $fseArea = $fseList.Area[$fseIndex]
    Move-Item -Path $paper.Fullname -Destination ($work_pth + "\" + $prefixed + $fseArea)
}

"`nAny key to exit..."
[System.Console]::ReadKey() | Out-Null ; Exit