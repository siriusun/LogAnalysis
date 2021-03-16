$work_path = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $work_path

./TopLogExport2.0.ps1
"`nPlease check generating date and any key to rename the logs"
[System.Console]::ReadKey() | Out-Null
./RenameGeneralLogs.ps1
C:\Users\sirius\anaconda3\python.exe ./LogToOneFile3.0.py
"`nAny key to exit..."
[System.Console]::ReadKey() | Out-Null ; Exit