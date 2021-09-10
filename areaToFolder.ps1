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

$fses = Import-Csv "ServiceFSElist.csv"
$fseDic = @{}

foreach ($fse in $fses) {
    $fseDic[$fse.NameCN] = $fse.Area
}

$areas = "凝血维修基本知识月考2021.xx-北区", "凝血维修基本知识月考2021.xx-南区", "凝血维修基本知识月考2021.xx-西区", "凝血维修基本知识月考2021.xx-东1区", "凝血维修基本知识月考2021.xx-东2区"
foreach ($area in $areas) {
    New-Folder $area
}

$papers = Get-ChildItem -Path $work_pth -Recurse -Filter *.docx
foreach ($paper in $papers){
    $fse = $fseDic[$paper.Name.Split("】")[0].Split("【")[1]]
    switch ($fse) {
        "North" { Move-Item -Path $paper.Fullname -Destination ($work_pth + "\凝血维修基本知识月考2021.xx-北区") }
        "South" { Move-Item -Path $paper.Fullname -Destination ($work_pth + "\凝血维修基本知识月考2021.xx-南区") }
        "West" { Move-Item -Path $paper.Fullname -Destination ($work_pth + "\凝血维修基本知识月考2021.xx-西区") }
        "East1" { Move-Item -Path $paper.Fullname -Destination ($work_pth + "\凝血维修基本知识月考2021.xx-东1区") }
        "East2" { Move-Item -Path $paper.Fullname -Destination ($work_pth + "\凝血维修基本知识月考2021.xx-东2区") }
    }
}