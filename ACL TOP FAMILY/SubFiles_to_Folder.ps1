#$source_path = "D:\TZB Analysis\New folder (2)"
#$dest_path = "D:\TZB Analysis\New folder"

Function Get-FileName {  
    #[System.Reflection.Assembly]::Load("System.Windows.Forms") | Out-Null
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    $OpenFileDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.SelectedPath
}

Write-Host "Select the Source Folder"
$source_path = Get-FileName
Write-Host "Select the Destination Folder"
$dest_path = Get-FileName

$sub_files = Get-ChildItem -Recurse -Path $source_path -Filter *.log

foreach ($sub_file in $sub_files){
    Move-Item -Path $sub_file.FullName -Destination $dest_path
}