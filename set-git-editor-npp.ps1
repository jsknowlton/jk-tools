param ([switch]$RestoreDefault)
if ($RestoreDefault) {
    git config core.editor vim
    Write-Host "Git core editor restored to default"
}
else {
    if (Test-Path "C:\Program Files (x86)\Notepad++\notepad++.exe") {
        git config --global core.editor "'C:\Program Files (x86)\Notepad++\notepad++.exe' -multiInst -notabbar -nosession -noPlugin"    
        Write-Host "Git core editor set to Notepad++"
    }

    if (Test-Path "C:\Program Files\Notepad++\notepad++.exe") {
        git config --global core.editor "'C:\Program Files\Notepad++\notepad++.exe' -multiInst -notabbar -nosession -noPlugin"    
        Write-Host "Git core editor set to Notepad++"
    }
}
