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

    Write-Host $nextAltDir