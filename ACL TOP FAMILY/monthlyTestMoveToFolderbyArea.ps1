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

$fses = Import-Csv "D:\Sync_ColorCloud\ServiceFSElist.csv"
$fseDic = @{}

foreach ($_ in $fses) {
    $fseDic[$_.NameCN] = $_.Area
}

$area = "凝血维修基本知识月考2021.xx-北区", "凝血维修基本知识月考2021.xx-南区", "凝血维修基本知识月考2021.xx-西区", "凝血维修基本知识月考2021.xx-东1区", "凝血维修基本知识月考2021.xx-东2区"
foreach ($_ in $area) {
    New-Folder $_
}

$papers = Get-ChildItem -Path $work_pth -Filter *.docx
foreach ($_ in $papers){
    $fse = $fseDic[$_.Name.Split("—")[1].Split(".")[0]]
    switch ($fse) {
        "North" { Move-Item -Path $_.Fullname -Destination $work_pth -join "\凝血维修基本知识月考2021.xx-北区" }
        "South" { Move-Item -Path $_.Fullname -Destination $work_pth -join "\凝血维修基本知识月考2021.xx-南区" }
        "West" { Move-Item -Path $_.Fullname -Destination $work_pth -join "\凝血维修基本知识月考2021.xx-西区" }
        "East1" { Move-Item -Path $_.Fullname -Destination $work_pth -join "\凝血维修基本知识月考2021.xx-东1区" }
        "East2" { Move-Item -Path $_.Fullname -Destination $work_pth -join "\凝血维修基本知识月考2021.xx-东2区" }
    }
}