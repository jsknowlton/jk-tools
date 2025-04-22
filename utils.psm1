# utility functions

function IsAdmin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function ToAdmin {
    if ($Host.Version.Major -gt 1) { $Host.Runspace.ThreadOptions = "ReuseThread" }
    if (-not (IsAdmin)) {
        $currentDirFullPath = Get-Location

        # Handle this differently if powershell core
        if ($Host.Version.Major -ge 7) {
            $newProcess = new-object System.Diagnostics.ProcessStartInfo "pwsh";
            $newProcess.Arguments = "-NoExit -WorkingDirectory $currentDirFullPath"
        }
        else {
            $newProcess = new-object System.Diagnostics.ProcessStartInfo "powershell";
            $newProcess.Arguments = "-NoExit -Command `"cd $currentDirFullPath`""
        }

        $newProcess.Verb = "runas";
        [System.Diagnostics.Process]::Start($newProcess);

        exit
    }
    else {
        Write-Host "Already running in elevated mode"
    }
    
}

function Get-ProjectUrl {
    param (
        [string]$projectPath
    )

    $projectUrl = Select-Xml -Path $projectPath -Namespace @{msb = "http://schemas.microsoft.com/developer/msbuild/2003" } -XPath "//msb:IISUrl" |
    Select-Object -Property @{Name = "IISUrl"; Expression = { $_.Node.InnerXml } } |
    Select-Object -ExpandProperty IISUrl
    return $projectUrl
}

function Get-DotNetVersion {
    param (
        [string]$filePath
    )
    if (-not $filePath) {
        throw "Full path of DLL is required."
    }

    $pathToDll = Resolve-Path $filePath
    if (-not (Test-Path $pathToDll)) {
        throw "Unable to find '$pathToDll'"
    }

    [byte[]]$dllByteArray = [System.IO.File]::ReadAllBytes($pathToDll)
    $result = [Reflection.Assembly]::ReflectionOnlyLoad($dllByteArray).CustomAttributes | Where-Object { $_.AttributeType.Name -eq "TargetFrameworkAttribute" } | Select-Object -ExpandProperty ConstructorArguments | Select-Object -ExpandProperty value
    return $result
}

function IsCorrectFramework {
    return (Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full").Release -ge 394802
}

function Get-TargetFrameworkVersions () {
    Get-ChildItem -Filter *.*proj -Recurse | ForEach-Object {
        $csprojPath = $_.FullName
        $targetFramework = Select-Xml -Path $csprojPath -Namespace @{msb = "http://schemas.microsoft.com/developer/msbuild/2003" } -XPath "//msb:TargetFrameworkVersion" |
        Select-Object -Property @{Name = "TargetFrameworkVersion"; Expression = { $_.Node.InnerXml } } |
        Select-Object -ExpandProperty TargetFrameworkVersion
        $targetFrameworkForNuget = $targetFramework.Replace(".", "").Replace("v", "net")

        Write-Output "$csprojPath ($targetFramework) [$targetFrameworkForNuget]"
    }
    # Select-Xml -Namespace @{msb = "http://schemas.microsoft.com/developer/msbuild/2003" } -XPath "//msb:TargetFrameworkVersion" |
    # Select-Object -Property @{Name = "TargetFrameworkVersion"; Expression = { $_.Node.InnerXml } } |
    # Select-Object -ExpandProperty TargetFrameworkVersion
    # Select-Object -ExpandProperty TargetFrameworkVersion |
    # Group-Object

}

function Get-LatestVersion {
    param (
        [string]$Path = "."
    )
    Get-ChildItem -Path $Path | Where-Object { $_.Extension -in ".dll", ".exe" } | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1 | ForEach-Object {
        $results = [PSCustomObject]@{
            Name        = $_.Name
            FileVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($_.FullName).FileVersion.Replace("RS/64 ", "")
        }
        Write-Output $results | Format-Table
    }
}

function Find-File () {
    param (
        [string]$Search = ""
    )
    
    if ($Search) {
        $start = Get-Date
        $results = @()
        Get-ChildItem -Recurse $($Search) | 
        ForEach-Object { 
            $result = [PSCustomObject]@{
                FullName      = $_.FullName
                LastWriteTime = $_.LastWriteTime
                Length        = $_.Length
                FileVersion   = $_.VersionInfo.FileVersion
            }
            $results += $result
        }
        Write-Output $results | Format-Table
        $end = Get-Date
        $elapsed = $($end - $start).ToString("hh\:mm\:ss\.ff")
        Write-Output "Elapsed = $elapsed"
    }
}
New-Alias ff Find-File

function Get-TFCloakStatus () {
    tf dir /folders | Where-Object { $_.Contains("$") -and -not $_.Contains(":") } | ForEach-Object { $_.substring(1, $_.length - 1) } | ForEach-Object { tf workfold $_ } | Where-Object { $_.Contains("$") }
}

function Get-IpAddress {
    # Get-NetIPAddress -AddressFamily IPv4 | Select-Object -Property InterfaceAlias, IPAddress
    Get-NetIPAddress -AddressFamily IPv4 | Where-Object { -not $_.IPAddress.StartsWith('169.') -and $_.IPAddress -ne '127.0.0.1' } | Select-Object -Property InterfaceAlias, IPAddress
    # Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress.StartsWith('10.') } | Select-Object -Property InterfaceAlias, IPAddress
    # [System.Net.Dns]::GetHostAddresses($env:computername) | ? { $_.AddressFamily -eq "InterNetwork" -and $_.IPAddressToString.StartsWith("10.") } | % { $_.IPAddressToString }
    # ([System.Net.Dns]::GetHostAddresses($env:computername)).IPAddressToString | ?{!$_.Contains(":") -and !$_.StartsWith("192")}
    # ((ipconfig) -match "IPv4").split(":")[1].trim();
}
New-Alias ip Get-IpAddress

# function Update-NugetLocal () {
#     param (
#         [string]$Search = ""
#     )

#     $searchTerm = "*.nupkg"

#     if ($Search -ne "") {
#         $searchTerm = "*$Search*.nupkg"
#     }

#     Get-ChildItem -Recurse $($searchTerm) | Sort-Object Name | ForEach-Object { nuget add $_.FullName -source \\cr-velocityfs-0.tlr.thomson.com\Velocity\NuGet }
# }
# New-Alias unl Update-NugetLocal

function Get-ModulePathList {
    return $env:PSModulePath.replace(';;', ';').split(';') | Select-Object -Unique;
}

function pathAsList {
    return $env:path.replace(';;', ';').split(';') | Select-Object -Unique
}

function removeDuplicatesFromPath {
    $path = (([System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::User)).replace(';;', ';').split(';') | Select-Object -Unique) -join ';'
    [System.Environment]::SetEnvironmentVariable('PATH', $path, [System.EnvironmentVariableTarget]::User)
    $path = (([System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::Machine)).replace(';;', ';').split(';') | Select-Object -Unique) -join ';'
    [System.Environment]::SetEnvironmentVariable('PATH', $path, [System.EnvironmentVariableTarget]::Machine)
    refreshEnv *> $null
}

function ensureVsWhere {
    if ($null -eq (Get-Command "vswhere.exe" -ErrorAction SilentlyContinue)) { 
        if ($null -eq (Get-Command "choco" -ErrorAction SilentlyContinue)) { 
            throw "This command requires 'vswhere.exe' which can be installed using chocolatey, but sadly you do not have chocolatey installed."
        }
        choco install vswhere *> $null
    }
}

function ensureMsbuildInPath {
    # This depends on vswhere.exe being installed and in your path.
    # Install it using chocolatey if you don't have it.
    # What? You don't have chocolatey installed? Leave now! Come back when you have it installed.
    # if ($null -eq (Get-Command "vswhere.exe" -ErrorAction SilentlyContinue)) { 
    #     if ($null -eq (Get-Command "choco" -ErrorAction SilentlyContinue)) { 
    #         throw "This command requires 'vswhere.exe' which can be installed using chocolatey, but sadly you do not have chocolatey installed."
    #     }
    #     choco install vswhere *> $null
    # }
    ensureVsWhere
    # $msbuildPath = vswhere -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe | Select-Object -First 1 | Split-Path
    $msbuildPath = vswhere -latest -find **\bin\msbuild.exe | Select-Object -Unique -First 1 | Split-Path
    # $devenvPath = vswhere -latest -find **\devenv.exe | Select-Object -Unique -First 1 | Split-Path
    $devenvPath = vswhere -latest -property productPath
    $path = (([System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::Machine)).replace(';;', ';').split(';') | Select-Object -Unique) -join ';'
    $newPath = "$msbuildPath;$devenvPath;$path"
    [System.Environment]::SetEnvironmentVariable('PATH', $newPath, [System.EnvironmentVariableTarget]::Machine)
    removeDuplicatesFromPath
}

function bfg {
    java -jar "C:\ProgramData\chocolatey\lib\bfg-repo-cleaner\tools\bfg-1.13.0.jar" $args
}


function mcd ([string]$Path) {
    if (-not $Path) {
        return;
    }
    mkdir $Path -ErrorAction SilentlyContinue
    if (Test-Path $Path) {
        Set-Location $Path
    }
}

function vmdir {
    param (
        [string]$DriveLetter
    )
    if ($DriveLetter -and $DriveLetter.Length -eq 1) {
        Remove-Item "~\VirtualBox VMs" -ErrorAction SilentlyContinue
        $vmPath = "$DriveLetter" + ':\VM'
        New-Item -Path "~\VirtualBox VMs" -ItemType Junction -Value $vmPath
    }
    $virtualBoxLink = Get-ChildItem -Path "~" -Filter "VirtualBox VMs*" | Select-Object Name, Target
    $existingDrives = Get-WmiObject win32_logicaldisk name, volumename, filesystem -Filter drivetype=3 | Select-Object FileSystem, Name, VolumeName

    Write-Output $virtualBoxLink
    Write-Output $existingDrives | Format-Table -Property Name, VolumeName
    
    # @echo off
    # IF %1.==. wmic logicaldisk get name,volumename,description,filesystem & dir /al "%userprofile%\VirtualBox VMs*" & exit /b 0
    # rd "%userprofile%\VirtualBox VMs" 
    # mklink /j "%userprofile%\VirtualBox VMs" %1:\VM

}

function Update-NugetPackages {
    Write-Output "Refreshing nuget packages..."
    # use rm.exe if possible
    if ($null -eq (Get-Command "rm.exe" -ErrorAction SilentlyContinue)) { 
        Remove-Item .\packages -Recurse -Force -ErrorAction SilentlyContinue
    }
    else {
        rm.exe -rf packages
    }
    # nuget locals all -clear
    # nuget restore -nocache
    $sln = Get-SolutionFile
    nuget restore $sln
}
New-Alias rn Update-NugetPackages

function Get-SolutionFile {
    $sln = $(Get-ChildItem *.sln | Select-Object -First 1 | ForEach-Object { $_.FullName })
    if (-not $sln -and (Test-Path './src')) {
        Push-Location './src'
        $sln = Get-SolutionFile
        Pop-Location
    }
    return $sln
}

# function Start-VS2017 {
#     $devenv = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\Common7\IDE\devenv.exe"
#     $sln = Get-SolutionFile
#     # $sln = $(dir *.sln | select -First 1 | % {$_.FullName})
#     & $devenv $sln
# }
# New-Alias vs17 Start-VS2017

function Start-VS2019 {
    ensureVsWhere
    # $devenv = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\Common7\IDE\devenv.exe"
    $devenv = vswhere -property productPath | Where-Object { $_.contains('2019') }
    if ($devenv) {
        $sln = Get-SolutionFile
        & $devenv $sln
    }
}
New-Alias vs19 Start-VS2019

function Start-VS2022 {
    ensureVsWhere
    $devenv = vswhere -property productPath | Where-Object { $_.contains('2022') }
    if ($devenv) {
        $sln = Get-SolutionFile
        & $devenv $sln
    }
}
New-Alias vs22 Start-VS2022

function Start-VSLatest {
    ensureVsWhere
    $devenv = vswhere -latest -property productPath
    if ($devenv) {
        $sln = Get-SolutionFile
        & $devenv $sln
    }
}
New-Alias vs Start-VSLatest

function Clean {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    Get-ChildItem -Recurse -Include 'bin', 'obj', 'publish' |
    ForEach-Object {
        if ((Get-ChildItem $_.Parent.FullName | Where-Object { $_.Name -Like "*.sln" -or $_.Name -Like "*.*proj" }).Length -gt 0) {
            if ($PSCmdlet.ShouldProcess($_, "Delete folder")) {
                Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host deleted $_
            }
        }
    }
}

function Build {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [switch]$Release, 
        [switch]$Rebuild, 
        [switch]$Clean, 
        [switch]$RefreshNugetPackages,
        [switch]$Tail
    )

    $sln = Get-SolutionFile
    if (-not (Test-Path $sln)) {
        throw "No solutions found to build"
    }

    ensureMsbuildInPath

    if ($Clean) {
        Clean
    }

    # Defaults
    $config = "Debug"
    # $platform = "x64"
    $platform = $null

    if ($Release) {
        $config = "Release"
    }

    # Search the .sln file for x64 platform, if not found use default
    # if ($platform -eq "x64") {
    #     if (Get-Content -Raw $sln | ForEach-Object { $_ -notlike '*x64*' }) {
    #         $platform = $null
    #     }
    # }

    if ($RefreshNugetPackages) {
        Update-NugetPackages
    }
    else {
        nuget restore $sln
    }

    $cmd = "msbuild.exe"
    $params = @()
    $params += "$sln"
    if ($Rebuild) {
        $params += "-t:rebuild"
    }
    else {
        $params += "-t:build"
    }
    $params += "-p:StopOnFirstFailure=true"
    $params += "-p:configuration=$config"
    if ($platform) {
        $params += "-p:platform=`"$platform`""
    }
    if ($Tail) {
        $params += "-fl"
    }

    if ($PSCmdlet.ShouldProcess($sln, "$cmd $params")) {
        if ($Tail) {
            Start-Process -FilePath "$env:home/source/repos/jk-tools/baretailpro.exe" -ArgumentList ".\msbuild.log"
        }
        & $cmd $params
        if ($LastExitCode -ne 0) {
            throw "Build Failed: $cmd $params"
        }
        Write-Output "Build Succeeded: $cmd $params"
    
        if ($Release -and (Test-Path .\release-build.ps1)) {
            . .\release-build.ps1
        }
    }
}
function gitBash {
    & 'C:\Program Files\Git\git-bash.exe'
}
New-Alias gb gitBash

function whereis {
    $cmd = "where.exe"
    & $cmd $args
}
New-Alias whence whereis

# function whence {
#     return "$((Get-Command $args[0] -ErrorAction SilentlyContinue).Definition)"
# }

# function msbuild {
#     $cmd = Get-ChildItem -path 'C:\Program Files (x86)\Microsoft Visual Studio' -Recurse msbuild.exe | Sort-Object $_.FullName -Descending | Select-Object -First 1 | %{$_.FullName}
#     # $cmd = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\MSBuild\15.0\Bin\MSBuild.exe"
#     & $cmd $args
# }

function Start-NotepadPlusPlus {
    if (Test-Path "C:\Program Files (x86)\Notepad++\notepad++.exe") {
        Start-Process "C:\Program Files (x86)\Notepad++\notepad++.exe" $args
        return
    }

    if (Test-Path "C:\Program Files\Notepad++\notepad++.exe") {
        Start-Process "C:\Program Files\Notepad++\notepad++.exe" $args
        return
    }
}
New-Alias npp Start-NotepadPlusPlus

function Set-WindowTitle {
    $host.ui.RawUI.WindowTitle = $args[0]
}
New-Alias title Set-WindowTitle

function Get-GitEditor {
    if ($null -eq (Get-Command "git" -ErrorAction SilentlyContinue)) { 
        return
    }
    git config --global --get core.editor
}

function Set-GitEditor {
    param ([switch]$RestoreDefault)

    if ($null -eq (Get-Command "git" -ErrorAction SilentlyContinue)) { 
        return
    }

    if ($RestoreDefault) {
        git config core.editor vim
        Write-Host "Git core editor restored to default"
    }
    else {
        if (Test-Path "C:\Program Files (x86)\Notepad++\notepad++.exe") {
            git config core.editor "'C:\Program Files (x86)\Notepad++\notepad++.exe' -multiInst -notabbar -nosession -noPlugin"    
            Write-Host "Git core editor set to Notepad++"
        }

        if (Test-Path "C:\Program Files\Notepad++\notepad++.exe") {
            git config core.editor "'C:\Program Files\Notepad++\notepad++.exe' -multiInst -notabbar -nosession -noPlugin"    
            Write-Host "Git core editor set to Notepad++"
        }
    }
}


function Get-IISExpress {
    Get-Process -Name iisexpress | Format-Table id, mainwindowtitle -AutoSize
}

# function Get-SolutionPlatform {
#     $slns = Get-ChildItem *.sln -Recurse
#     # $results = @()
#     foreach ($sln in $slns) {
#         $slnContent = Get-Content -Raw $sln
#         $has64bit = $slnContent -match 'x64'
#         $result = @{"Has64bit" = $has64bit; "Filename" = $sln.FullName}
#         Write-Output $result
#         # $results += $result
#         # Write-Output "$has64bit `t $($sln.FullName)"
#     }

#     # $results
# }

function Start-Sleep($seconds) {
    $doneDT = (Get-Date).AddSeconds($seconds)
    while ($doneDT -gt (Get-Date)) {
        $secondsLeft = $doneDT.Subtract((Get-Date)).TotalSeconds
        $percent = ($seconds - $secondsLeft) / $seconds * 100
        Write-Progress -Activity "Sleeping" -Status "Sleeping..." -SecondsRemaining $secondsLeft -PercentComplete $percent
        [System.Threading.Thread]::Sleep(500)
    }
    Write-Progress -Activity "Sleeping" -Status "Sleeping..." -SecondsRemaining 0 -Completed
}

function nullterm {
    $env:term = $null
}

function Get-NextAltDir {
    $parentDirName = Split-Path -Path (Get-Location).Path
    $currentDirName = Split-Path -Path (Get-Location).Path -Leaf
    $parentDirNameLastChar = $parentDirName.Substring($parentDirName.Length - 1)
    $altDirRoot = $parentDirName
    [int]$altDirIndex = 1
    [int]$returnedInt = 0
    [bool]$result = [int]::TryParse($parentDirNameLastChar, [ref]$returnedInt)
    if ($result) {
        $altDirIndex = $returnedInt
        $altDirRoot = $parentDirName -replace ".$"
    }
    # Check to see if higher altdir exists
    $propostedHigherAltDir = "$altDirRoot$($altDirIndex + 1)"
    $nextAltDir = ""
    $higherAltDirExists = Test-Path $propostedHigherAltDir
    if ($higherAltDirExists) {
        $nextAltDir = Join-Path $propostedHigherAltDir $currentDirName
    }
    else {
        $nextAltDir = Join-Path $altDirRoot $currentDirName
    }

    # Check to see if current folder exists in higher altdir
    if (-not (Test-Path $nextAltDir)) {
        $nextAltDir = Join-Path $altDirRoot $currentDirName
    }

    return $nextAltDir
}

function AltDir {
    Set-Location $(Get-NextAltDir)
}

function AltBC {
    $bc = "C:\Program Files\Beyond Compare 5\BCompare.exe"
    if (-not (Test-Path $bc)) {
        return
    }

    $altDir = Get-NextAltDir

    . $bc $altDir $(Get-Location) /filters="-.git\;-.vs\;-packages\;-bin\;-obj\;-.bin\;-Publish\;-build\;-.github\;-.githooks\"
}

function zipMasterMenu {
    pushd ~/source/repos
    rm.exe -rf GRC_MMNet_Archive.7z
    7z.exe a -t7z GRC_MMNet_Archive.7z GRC_MMNet\ -mx0 -xr!bin -xr!obj -xr!packages -xr!'.vs' -xr!'.azuredevops' -xr!'.git'
    popd
}