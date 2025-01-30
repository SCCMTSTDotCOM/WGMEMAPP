#how to get winget app ids
#https://winget.run/
PARAM(
    #Install,Uninstall,Repair
    $Action,
    $AppID,
    [switch]
    $UninstallPrevious
    
)

function Get-WingetPath {
    $WingetPath = Get-ChildItem -Path "C:\Program Files\WindowsApps" -Directory | where {$_.Name -like "Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe"} | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($WingetPath){return $($WingetPath.fullname)} else {Throw "Winget is not installed"}
}

function Install-WingetAppUpdates {
    param (
        $ID,
        [switch]
        $UninstallPrevious
    )
    if ($Name -and $ID){Throw "Only Specify a Name OR an ID"}
    $Wingetpath = Get-WingetPath
    Set-Location $Wingetpath
    if ($UninstallPrevious){
        $installtext = .\winget.exe upgrade --id $ID -e --accept-source-agreements --scope machine --silent --force --uninstall-previous | out-string 
    } else {
        $installtext = .\winget.exe upgrade --id $ID -e --accept-source-agreements --scope machine --silent --force | out-string 
    }

    $resultstext = $installtext -split "`r?`n" | Where-Object { $_ -match '\w' }
    $resultstext | foreach { if ($_ -like "*error occured*"){
            $Err = $val.IndexOf("$_")
            Throw "$resultstext[$Err + 1]"
            Exit 1
        } 
        if ($_ -like "*Successfully installed*"){Write-Host "$Name $_"}
    }
}

function Get-WingetInstalledApps {
    $apps  = @()
    $start = $false
    # Navigate to the correct directory for winget.exe
    $Wingetpath = Get-WingetPath
    Set-Location $Wingetpath
    .\winget.exe upgrade --accept-source-agreements --include-unknown | ForEach-Object {
        if ($psitem -match '^([-]+)$') {
            $start = $true
        } elseif ($start -eq $true) {
            $apps += $psitem
        }
    }

    # Remove the last line
    $apps = $apps[0..($apps.Length - 2)]

    # Define regex pattern to handle optional id, version, and available fields
    $pattern = "^(?<name>.+?)\s+(?<id>[\w\.\-\+]+)?\s+(v?(?<version>[\.\d]+)?)?\s+(v?(?<available>[\.\d]+)?)?\s+(?<source>\w+)?$"

    # Parse and convert each app into a structured object
    $parsedApps = @()
    foreach ($line in $apps) {
        if ($line -match $pattern) {
            $parsedApps += [PSCustomObject]@{
                name      = $matches['name'].Trim()
                id        = if ($matches['id']) { $matches['id'] } else { "N/A" }
                version   = if ($matches['version']) { $matches['version'] } else { "N/A" }
                available = if ($matches['available']) { $matches['available'] } else { "N/A" }
                source    = if ($matches['source']) { $matches['source'] } else { "N/A" }
            }
        }
    }

    return $parsedApps
}

function Install-WinGetApp {
    PARAM(
        $ID
    )
    $Wingetpath = Get-WingetPath
    Set-Location $Wingetpath
    $installtext = .\winget.exe install --ID "$ID" -e --silent --scope machine | out-string 
    $resultstext = $installtext -split "`r?`n" | Where-Object { $_ -match '\w' }
    $resultstext | foreach { if ($_ -like "*error occured*"){
            $Err = $val.IndexOf("$_")
            Throw "$resultstext[$Err + 1]"
            Exit 1
        } 
        if ($_ -like "*Successfully installed*"){Write-Host "$ID $_"}
    }
}

function Uninstall-WinGetApp {
    PARAM(
        $ID
    )
    $Wingetpath = Get-WingetPath
    Set-Location $Wingetpath
    $installtext = .\winget.exe uninstall --ID "$ID" -e --silent --scope machine | out-string 
    $resultstext = $installtext -split "`r?`n" | Where-Object { $_ -match '\w' }
    $resultstext | foreach { if ($_ -like "*error occured*"){
            $Err = $val.IndexOf("$_")
            throw "$resultstext[$Err + 1]"
            Exit 1
        } 
        if ($_ -like "*Successfully uninstalled*"){Write-Host "$ID $_"}
    }
}


switch ($Action) {
    "Install" { 
        $AppInstall = Get-WingetInstalledApps | Where {$_.ID -like "$AppID"}
        IF ($AppInstall){
            Install-WingetAppUpdates -ID $AppID -UninstallPrevious:$UninstallPrevious
        } else { Install-WinGetApp -ID $AppID }
    }
    "Uninstall" { Uninstall-WinGetApp -ID $AppID }
    "Repair" { Uninstall-WinGetApp -ID $AppID
        Install-WingetAppUpdates -ID $AppID
    }
    Default {
        $AppInstall = Get-WingetInstalledApps | Where {$_.ID -like "$AppID"}
        IF ($AppInstall){
            Install-WingetAppUpdates -ID $AppID -UninstallPrevious:$UninstallPrevious
        } else { Install-WinGetApp -ID $AppID }
    }
}