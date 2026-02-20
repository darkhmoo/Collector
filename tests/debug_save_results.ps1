# Debug Script for Save-Results
$ErrorActionPreference = "Stop"

Write-Host "DEBUG: Starting Save-Results Test" -ForegroundColor Magenta

# 1. Define paths (Relative to tests directory)
$scriptRoot = Split-Path -Parent $PSScriptRoot
$libPath = Join-Path $scriptRoot "lib"
$outputPath = Join-Path $scriptRoot "result"

if (-not (Test-Path -Path $outputPath -PathType Container)) {
    New-Item -Path $outputPath -ItemType Directory -Force | Out-Null
}

Write-Host "DEBUG: Script Root: $scriptRoot"
Write-Host "DEBUG: Output Path: $outputPath"

# 2. Load Libraries
try {
    . (Join-Path $libPath "Common.ps1")
    . (Join-Path $libPath "OutputManager.ps1")
    . (Join-Path $libPath "Reporters.ps1") # For Export-EventLogFiles and ConvertTo-HtmlReport logic
    # Also need to load EventLogReporter if separate, but Reporters.ps1 usually loads them.
    # Let's check Reporters.ps1 content later if needed. Assuming it loads sub-reporters.
    # Actually, verify if Reporters.ps1 loads EventLogReporter.ps1
    $eventLogReporterPath = Join-Path $libPath "reporters\EventLogReporter.ps1"
    if (Test-Path $eventLogReporterPath) {
        . $eventLogReporterPath
    }
    
    # Also load HtmlReporter if it exists
    $htmlReporterPath = Join-Path $libPath "reporters\HtmlReporter.ps1"
    if (Test-Path $htmlReporterPath) {
        . $htmlReporterPath
    }

    Write-Host "DEBUG: Libraries Loaded Successfully" -ForegroundColor Green
}
catch {
    Write-Error "DEBUG: Failed to load libraries: $_"
    exit 1
}

# 3. Create Dummy Data
$dummyReport = [PSCustomObject]@{
    ExecutionTime = "00:00:01"
    Info          = @{
        Hostname = "DEBUG-HOST"
        OS       = "Debug OS"
    }
    Logs          = @{
        EventLogs = @{} # Empty for now
    }
}

# 4. Attempt Save
Write-Host "DEBUG: Calling Save-Results..." -ForegroundColor Cyan
try {
    Save-Results `
        -auditReport $dummyReport `
        -outputFormat @("HTML", "JSON") `
        -eventLogFormat "HTML" `
        -outputDirectory $outputPath `
        -isDebugMode $true `
        -zipResults $false `
        -encryptionKey $null 
        
    Write-Host "DEBUG: Save-Results Completed" -ForegroundColor Green
}
catch {
    Write-Error "DEBUG: Save-Results Failed: $_"
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
}

# 5. Check Files
Write-Host "DEBUG: Checking for files..."
$files = Get-ChildItem -Path $outputPath -Filter "result_*.html"
if ($files) {
    Write-Host "SUCCESS: Found $($files.Count) HTML files." -ForegroundColor Green
    $files | Select-Object Name, LastWriteTime
}
else {
    Write-Host "FAILURE: No HTML files found." -ForegroundColor Red
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU71HUWcCJVt7FeAsQVx/cpm3y
# Kk6gggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
# AQsFADAkMSIwIAYDVQQDDBlDb2xsZWN0b3ItSW50ZXJuYWwtU2lnbmVyMB4XDTI2
# MDIxMzE2MzExMloXDTI3MDIxMzE2NTExMlowJDEiMCAGA1UEAwwZQ29sbGVjdG9y
# LUludGVybmFsLVNpZ25lcjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
# ANvUNS+3ZOqv6/Wjx4K6mUvzpMqoAAToxWCryus4grdBQG7zH2M/2en1b750HzGs
# Xhr2macyH+9rVzsYHYF5llyxw08XQ6X36vMbJEVoR+5KOf/zJrA2c480Rdc2m1BH
# BDNkhKC7/P4pCaYYi+sxe68Ind6KYjIIL8wRMFRy77FZRiL3iUINYK3yMEnSrkfK
# DVtAM26Urogj/zfmozn05f3q9nk7wnlSAzBFgYrqZ0LAClDEiqrN5W2S2Tz465uN
# jkLiBJ3R+fJf6duLybme+A6uqmmVRTukL8/uUB19fJw7lx1OfmIBoJQ0p6myy8hS
# Wz/kgKl2drA3emG4e6BpckECAwEAAaNGMEQwDgYDVR0PAQH/BAQDAgeAMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBTAAzQigManKpFUSzB+/+hZM7g9AjAN
# BgkqhkiG9w0BAQsFAAOCAQEAA9jrmfv21FtuqvRvy4gz7aUuHI/o0dtaia/3QYKI
# Q04YkCTVMP63j/d2ISNM1Xwn8qnRBr93jO0hI+lpf9ELW2hnJwyaHqhJzQsBvBM6
# CowvqaPa+S9+9Hc7sY2aVGWcSXJwXcqy6pzkOHuzPouTk0hfsekRRivafQYH5Xeh
# Ui7+fQmPLrZmLQPOLx8mAMaLsPUYDAE8j99aa2ulg6KZYO7F0zy0Veqjs+8pSIIE
# V0H2+ApOKEbZP4NWUeaFq9vycZwURZPjYrNSckbJ5M9jTANbNaMs2ZAEZ+HrpPSt
# wvUWonVftmZpq3dJ2ClpXnDwUz/yYEJ1dzUT9YDZDDbOVzGCAdkwggHVAgEBMDgw
# JDEiMCAGA1UEAwwZQ29sbGVjdG9yLUludGVybmFsLVNpZ25lcgIQGWEUqQpfT6JP
# YbwYRk6SXjAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU8pqxFWwX3pzRpnLUEsnK0qZan3gwDQYJ
# KoZIhvcNAQEBBQAEggEAeVAmWewyviRwsXdVDSSZ+ZJqRYTWUXAmvdIYhFV4MVT6
# ZasZR4tDJpvb22a5sQydthy0BvJr9oAyEWZ0lOGF5EG2JyhA1jbXNIS/OQ0v0912
# XdBO+EAed6n5GFw2XsdkPXk9see3rJ6kH0FChlVy4lDKAYLJoBEdJzhpvIzv6Hhw
# qsgp9lmAWXLYfAckI4K5c+iZ0aoMadq70coWHdZMadRQcczxA6vtNiozsv/SxUaG
# MyImOLv48HsGa589J7RUndo2lmXdBgrp8jT2ThCQ2dVOxX73ZTMDP3h0eyRwhTKI
# /iTvl0XM8/A9XqnRz9XBeBA0zo6PuMBaTBeKJjpkrg==
# SIG # End signature block
