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

"Any key to continue..."
[System.Console]::ReadKey() | Out-Null

$fseList = Import-Csv "ServiceFSElist.csv"

$areas = 
        "Hemo Monthly Exam 2022-xx North", 
        "Hemo Monthly Exam 2022-xx South", 
        "Hemo Monthly Exam 2022-xx West" , 
        "Hemo Monthly Exam 2022-xx East1", 
        "Hemo Monthly Exam 2022-xx East2",
        "Hemo Monthly Exam 2022-xx Henan"

$papers = Get-ChildItem -Path $work_pth -Recurse -Filter *.docx

if ($null -eq $papers){
    "`nNo report founded, any key to exit..."
    [System.Console]::ReadKey() | Out-Null ; Exit
}

foreach ($area in $areas) {
    New-Folder $area
}

foreach ($paper in $papers){
	$nameCN = $paper.Name.Split("】")[0].Split("【")[1]
	$fse =  ($fseList | Where-Object -Property NameCN -Like $nameCN).Area
    if($null -eq $fse){
        "`n"
        Write-Host ($nameCN + " not found")
        continue
    }
    foreach($area in $areas){ 
        if($area -Like ("*" + $fse)){
            Move-Item -Path $paper.Fullname -Destination ($work_pth + "\" + $area)
        }
    }
}
"`nAny key to exit..."
[System.Console]::ReadKey() | Out-Null ; Exit