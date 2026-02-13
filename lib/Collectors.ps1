<#
.SYNOPSIS
    Main Collector Loader
.DESCRIPTION
    Loads all individual collector modules and provides a unified interface.
    This file follows the Single Responsibility Principle by delegating
    specific collection tasks to dedicated modules.
#>

# --- Dynamic Plugin Engine ---
# This refactor allows for 'Plug-and-Play' functionality.
# Simply dropping a .ps1 file into the 'collectors' directory makes it active.

$collectorPath = Join-Path -Path $PSScriptRoot -ChildPath "collectors"

if (Test-Path $collectorPath) {
    Get-ChildItem -Path $collectorPath -Filter "*.ps1" | ForEach-Object {
        $filePath = $_.FullName
        Write-Log -message "  [Security] Verifying: $($_.Name)" -color Cyan -level Debug
        
        # Security Hardening: Authenticode Verification
        $sig = Get-AuthenticodeSignature -FilePath $filePath
        if ($sig.Status -eq "Valid") {
            try {
                . $filePath
                Write-Log -message "    ✓ Authenticode Valid. Module loaded." -color Green -level Debug
            }
            catch {
                Write-Error "Failed to load collector module $($_.Name): $_"
            }
        }
        else {
            Write-Log -message "    ! SECURITY WARNING: Rejecting unsigned or untrusted plugin: $($_.Name) (Status: $($sig.Status))" -color Red -level Error
            Write-Warning "Plugin '$($_.Name)' rejected due to invalid signature. Run 'utils\Setup-Security.ps1' to sign it."
        }
    }
}
else {
    Write-Error "Collector path not found: $collectorPath"
}

# Export functions only when loaded as a module.
if ($ExecutionContext.SessionState.Module) {
    Export-ModuleMember -Function @(
        'Get-HardwareInfo',
        'Get-NetworkInfo',
        'Get-OSConfig',
        'Get-VirtualizationInfo',
        'Get-ServiceInfo',
        'Get-PerformanceInfo',
        'Get-LogInfo',
        'Get-SecurityInfo',
        'Get-InventoryInfo',
        'Get-ActiveDirectoryInfo',
        'Get-HighAvailabilityInfo'
    )
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUXNOmJNwXsJUsFKXIlEr1Bmpc
# isygggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUNPRLEO3vM8g7xux+V5X5uyWQfEYwDQYJ
# KoZIhvcNAQEBBQAEggEAplzlONxOx4LsvwQ1v+eEWfzAqHU0i4t3wU66ITr7tgVY
# PNwpZFGNB75YZmuuLxffR32LL8WC4zRpwZwCwPCx/0hGjjcfH8IihyLPJmziraNe
# BUVIX1yBctps6f+vxetkoJxOaxDZnoKQMDFJcNd60vve0c9IZLYn9651hHLO0piQ
# LX33YVzUVGdYpA1hP6AxEgg5QMljubUCMHZQKseYDgmPYjqFNiR0KOvOAjaudukK
# 5YSgr+8N7gatAN4zERPFeoPiv3fuHbwSHKAy9MKeG5wL2CHObSsSVbVWBUMqbPLu
# +ANSCVW6arOrg4xp9k85yZedu8Cqx60uvvEf6vv+BQ==
# SIG # End signature block
