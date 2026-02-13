<#
.SYNOPSIS
    Software Inventory Collector (Class-based)
#>

<#
.SYNOPSIS
    Collects installed software information from the registry.
#>
function Get-InstalledSoftware {
    [CmdletBinding()]
    param()

    $uninstallKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $softwareList = [System.Collections.Generic.List[PSObject]]::new()

    foreach ($keyPath in $uninstallKeys) {
        try {
            $items = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                if (-not $item.DisplayName) { continue }
                $softwareList.Add([PSCustomObject]@{
                        DisplayName     = $item.DisplayName
                        DisplayVersion  = $item.DisplayVersion
                        Publisher       = $item.Publisher
                        InstallDate     = $item.InstallDate
                        InstallLocation = $item.InstallLocation
                        UninstallString = $item.UninstallString
                        RegistryPath    = $item.PSPath
                    })
            }
        }
        catch {}
    }

    # Deduplication
    $hashSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $uniqueSoftware = [System.Collections.Generic.List[PSObject]]::new()
    foreach ($sw in ($softwareList | Sort-Object DisplayName)) {
        $uniqueKey = "$($sw.DisplayName)_$($sw.DisplayVersion)_$($sw.Publisher)"
        if ($hashSet.Add($uniqueKey)) { $uniqueSoftware.Add($sw) }
    }
    return $uniqueSoftware.ToArray()
}

class InventoryCollector : BaseCollector {
    InventoryCollector() : base("Inventory", "Resources") {}

    [PSObject] Collect() {
        $this.LogStart()
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        $data = [PSCustomObject]@{
            InstalledSoftware = Get-InstalledSoftware
            AppxPackages      = $this.GetWindowsAppxPackages()
        }

        $sw.Stop()
        $this.LogEnd($sw.ElapsedMilliseconds)
        return $data
    }

    [PSObject] GetWindowsAppxPackages() {
        try {
            if (Get-Command -Name Get-AppxPackage -ErrorAction SilentlyContinue) {
                return @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Select-Object Name, Publisher, Version, InstallLocation, PackageFamilyName)
            }
            return "Get-AppxPackage cmdlet not available"
        }
        catch { return "Failed to collect Appx packages: $($_.Exception.Message)" }
    }
}

function Get-InventoryInfo {
    return ([InventoryCollector]::new()).Collect()
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUiLGsReFf6wI5JQii72LXMscP
# w4qgggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUKPHfUhsYTC/pCB/U61akYxlHDYUwDQYJ
# KoZIhvcNAQEBBQAEggEATUL1mcBCc4jU4/osVRtmGmct5QnSBZRH+oLDvk2Cgw48
# 0kTmna+KVP6kjUz2txb9KRfUQyGMq1ed9nhYXJNzs1GBIuJEXUHPcBjEkti+gHHU
# iIEVaZLkbeD1wTWUc3GOcfPUC1xZUuqHfZmGzXch8ny49q4dFz9bC0RusnW9SfcO
# ku476ITbUB8YmVB6DV/buz8BEeikgq9w/OskXJccg5C7szzbWKMpBVtwlPU4ERJO
# 7BEa+PHVUjJ3+UkEcRKajm9JIUfZL4OW9sVgCMII0JxITmETcSNtVvA/TQK/ShOP
# 8ZW2BC8eiW2iQzze/GQX+NxztIW9sQIASJi/hSZFRA==
# SIG # End signature block
