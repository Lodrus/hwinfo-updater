$historyUrl = 'https://www.hwinfo.com/version-history/'
$downloadUrlBase = 'https://www.hwinfo.com/files/hwi_'
$destination = 'C:\Program Files\HWiNFO64'
$log = "$destination\lodras_auto_updater.log"
$versionFile = "$destination\version.txt"
$profileName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

Function Write-Log
{
   Param ([string]$message)
   Add-Content $log -value "$(Get-Date -Format "yyyyMMdd-HHmmss"): $message"
}

Function Start-Hwinfo
{
    if (-not (Get-Process HWiNFO64 -ErrorAction SilentlyContinue))
    {
        Write-Log "Starting new HWiNFO64 process"
        Start-Process "$destination\HWiNFO64.exe" -WorkingDirectory $destination
    }
}

# Initialize logging
If (-Not (Test-Path -Path $log)) {New-Item -Path $log}
Else {Add-Content $log -value ('-'*100)}

# Initialize $versionFile
If (-Not (Test-Path -Path $versionFile)) 
{
    New-Item -Path $versionFile
    Set-Content $versionFile -Value "0"
}

Write-Log "Starting auto update"

# Prevent stupid IE initialization errors for the web requests
$keyPath = 'Registry::HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Internet Explorer\Main'
if (!(Test-Path $keyPath)) { New-Item $keyPath -Force | Out-Null }
Set-ItemProperty -Path $keyPath -Name "DisableFirstRunCustomize" -Value 1

# Get the latest version info
Write-Log "Getting version info from site: $historyUrl"
$response = Invoke-WebRequest -Uri $historyUrl
Write-Log "HTTP Response Code: $($response.StatusCode)"
$version = $response.ParsedHtml.GetElementById('tab1').GetElementsByTagName('span')[0].innerText
Write-Log "Found version: $version"
$versionCleaned = $version -replace "[^0-9]"
Write-Log "Formatted version: $versionCleaned"
$source = "$downloadUrlBase$versionCleaned.zip"

# Compare current and new versions
$currentVersion = Get-Content $versionFile
if ($versionCleaned -eq $currentVersion)
{
    Write-Log "Already up to date"
    Start-Hwinfo
    Break
}

$count = 0
do {
    $count++

    # Remove prior zip
    Remove-Item $destination\hwi.zip -ErrorAction Ignore

    # Download new zip
    Write-Log "Downloading zip file from site: $source"
    $dlResponse = Invoke-WebRequest -Uri $source -OutFile "$destination\hwi.zip" -PassThru -Headers @{"Cache-Control"="no-cache"} -DisableKeepAlive -MaximumRedirection 0 -ErrorAction Ignore
    Write-Log "HTTP Response Code: $($dlResponse.StatusCode)"
    if ($dlResponse.StatusCode -eq 200) {break}
    Write-Log "Sleeping for 10 seconds"
    Start-Sleep -Seconds 10
}
while ($count -le 10)

if ($dlResponse.StatusCode -ne 200) {
    Write-Log 'Failed to download the new version'
    break
}

# Shutdown current process
Write-Log "Stopping HWiNFO64 processes"
Get-Process HWiNFO64 -ErrorAction SilentlyContinue | Stop-Process

# Extract new exe and overwrite old one. Remove the stupid 32 bit version
Write-Log "Extracting zip contents"
Expand-Archive -LiteralPath $destination\hwi.zip -DestinationPath $destination -Force
Set-Content $versionFile -Value $versionCleaned
Remove-Item $destination\HWiNFO32.exe

# Start the process up again
Start-Hwinfo
