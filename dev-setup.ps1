#Requires -RunAsAdministrator

function installChocolatey {
    if (!(Test-Path "$($env:ProgramData)\chocolatey\choco.exe")) {
        Write-Output "installing chocolatey..."
        try {
            [System.Net.ServicePointManager]::SecurityProtocol = 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        }
        catch {
            Write-Output $_.Exception.Message
        }
    }
    else {
        Write-Output "chocolatey is already installed"
    }

    $env:Path += ";$env:ALLUSERSPROFILE\chocolatey\bin"
    choco feature enable -n=allowGlobalConfirmation *> $null
    choco feature enable -n=failOnAutoUninstaller *> $null
    choco feature enable -n=useRememberedArgumentsForUpgrades *> $null
}

function installTools {
    # choco upgrade poshgit
    #choco upgrade netfx-4.8-devpack
    #choco upgrade netfx-4.6.2-devpack
    #choco upgrade netfx-4.7.1-devpack
    choco upgrade 7zip.install
    # choco upgrade vscode
    # choco upgrade googlechrome
    choco upgrade notepadplusplus
    # choco upgrade LinkShellExtension
    #choco upgrade vswhere
    #choco upgrade nuget.commandline
    # choco upgrade conemu
    choco upgrade beyondcompare
    choco upgrade sysinternals
    #choco upgrade visualstudio2019professional
    #choco upgrade visualstudio2022professional
    #choco upgrade visualstudio2019-remotetools
    #choco upgrade microsoft-windows-terminal
    # choco upgrade NugetPackageExplorer
    choco upgrade Everything
    # choco upgrade vcredist2010

    # choco upgrade sql-server-2022
    # choco upgrade sql-server-management-studio

    ### Front-end Dev Tools ###
    # choco upgrade nodejs-lts
    # $env:Path += ";$env:ProgramFiles\nodejs"
    # npm install -g npmlist
    # npm install -g grunt@0.4.5
    # npm install -g grunt-cli@1.2.0
}

function removeDuplicatesFromPath {
    $path = (([System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::User)).replace(';;', ';').split(';') | Select-Object -Unique) -join ';'
    [System.Environment]::SetEnvironmentVariable('PATH', $path, [System.EnvironmentVariableTarget]::User)
    $path = (([System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::Machine)).replace(';;', ';').split(';') | Select-Object -Unique) -join ';'
    [System.Environment]::SetEnvironmentVariable('PATH', $path, [System.EnvironmentVariableTarget]::Machine)
}

function setupDeveloperPath {
    if ($null -eq (Get-Command "vswhere.exe" -ErrorAction SilentlyContinue)) { 
        if ($null -eq (Get-Command "choco" -ErrorAction SilentlyContinue)) { 
            installChocolatey
        }
        choco install vswhere *> $null
    }

    $path = (([System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::Machine)).replace(';;', ';').split(';') | Select-Object -Unique) -join ';'
    $msbuildPath = vswhere -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe | Select-Object -First 1 | Split-Path
    if ($msbuildPath) {
        $path = "$msbuildPath;$path"
    }

    $rmExePath = "C:\Program Files\git\usr\bin"
    if (Test-Path $rmExePath) {
        $path = $path += ";$rmExePath"
    }

    [System.Environment]::SetEnvironmentVariable('PATH', $path, [System.EnvironmentVariableTarget]::Machine)
    removeDuplicatesFromPath
    refreshEnv *> $null
}

installChocolatey
installTools
#setupDeveloperPath
