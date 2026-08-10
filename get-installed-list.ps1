Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
Select-Object DisplayName, DisplayVersion, InstallDate |
Where-Object { $_.DisplayName -ne $null } |
Format-Table -AutoSize