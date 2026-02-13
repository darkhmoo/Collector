<#
.SYNOPSIS
    Security Information Collector (Class-based)
#>

class SecurityCollector : BaseCollector {
    SecurityCollector() : base("Security", "Security") {}

    [PSObject] Collect() {
        $this.LogStart()
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        $securityReport = [PSCustomObject]@{
            FirewallProfile = Get-NetFirewallProfile -ErrorAction SilentlyContinue | Select-Object * -ExcludeProperty "Cim*"
            FirewallRules   = Get-NetFirewallRule -ErrorAction SilentlyContinue | Select-Object * -ExcludeProperty "Cim*"
            AntivirusStatus = Get-CimSafe -Namespace "root\SecurityCenter2" -ClassName "AntivirusProduct"
            BitLockerStatus = $this.GetBitLockerStatus()
            EntraIdStatus   = $this.GetEntraIdStatus()
            AppControl      = [PSCustomObject]@{
                AppLocker = Get-CimSafe -ClassName Win32_Service -Filter "Name='AppIDSvc'" | Select-Object State, StartMode
                WDAC      = Get-CimSafe -ClassName Win32_OptionalFeature -Filter "Name='ConfigCI'" | Select-Object InstallState
            }
            AccountPolicy   = Get-CimSafe -ClassName Win32_AccountStore
            LocalAdmins     = $this.GetLocalAdmins()
            SharedSecret    = Get-CimSafe -ClassName Win32_LSAAccount | Select-Object Name, Domain
            AuditPolicy     = $(try { auditpol /get /category:* } catch { "Audit Policy Unavailable" })
            UserRights      = $this.GetUserRights()
            ActiveDirectory = $this.GetADDomainInfo()
            Accounts        = Get-CimSafe -className Win32_UserAccount -filter "LocalAccount = True"
            Groups          = Get-CimSafe -className Win32_Group -filter "LocalAccount = True"
            GroupUsers      = Get-CimSafe -className Win32_GroupUser
            ActiveSessions  = $this.GetActiveSessions()
        }

        $sw.Stop()
        $this.LogEnd($sw.ElapsedMilliseconds)
        return $securityReport
    }

    [PSObject] GetBitLockerStatus() {
        if (Get-Command -Name Get-BitLockerVolume -ErrorAction SilentlyContinue) {
            try { return Get-BitLockerVolume -ErrorAction Stop | Select-Object MountPoint, VolumeType, EncryptionMethod, ProtectionStatus, LockStatus } catch { return "BitLocker query failed: $_" }
        }
        return "BitLocker module not available"
    }

    [string] GetEntraIdStatus() {
        try { 
            $dsregOutput = & dsregcmd /status 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0) { return $dsregOutput.Trim() } else { return "dsregcmd failed with exit code $LASTEXITCODE" }
        }
        catch { return "dsregcmd not found or failed" }
    }

    [PSObject] GetLocalAdmins() {
        try { 
            $adminSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
            $groupName = $adminSid.Translate([System.Security.Principal.NTAccount]).Value
            return Get-LocalGroupMember -Group $groupName -ErrorAction SilentlyContinue | Select-Object Name, PrincipalSource, ObjectClass 
        }
        catch { return "Failed to query local admins: $_" }
    }

    [PSObject] GetUserRights() {
        $secPolPath = Join-Path -Path $env:TEMP -ChildPath "secpol_export_$(Get-Random).inf"
        try {
            & secedit /export /cfg $secPolPath 2>&1 | Out-Null
            if (Test-Path $secPolPath -PathType Leaf) {
                return Get-Content -Path $secPolPath -Encoding Unicode -ErrorAction Stop | Select-Object -First 100
            }
            return "Secedit export file not found"
        }
        catch { return "Local policy collection failed: $_" }
        finally { if (Test-Path $secPolPath) { Remove-Item $secPolPath -Force } }
    }

    [PSObject] GetADDomainInfo() {
        if (Get-Module -ListAvailable ActiveDirectory) {
            try { return Get-ADDomain -ErrorAction Stop | Select-Object Name, NetBIOSName, DomainMode } catch { return "RSAT/Domain Not Available" }
        }
        return "RSAT/Domain Not Available"
    }

    [string] GetActiveSessions() {
        try {
            $quserOutput = quser 2>&1; if ($LASTEXITCODE -eq 0) { return $quserOutput | Out-String }
            return "No active sessions found or quser failed"
        }
        catch { return "Session collection failed: $_" }
    }
}

function Get-SecurityInfo {
    return ([SecurityCollector]::new()).Collect()
}
# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUpXMHFTniJ1ApiK+mn1VapZX4
# kKWgggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUySK3pvO8OIa14WPhBQYFBsxdXHowDQYJ
# KoZIhvcNAQEBBQAEggEAH5Eos9GFUwT7RnxL8rieCrg80j2hr0fAvwbP4MVHztE3
# PzHDTUl0cCGobIsL5qieiSq7Z4plv/rHoDaDcwTvb+bQ3pyfLSukHLp7GUrafPTv
# dtvz1sdvBUv7RxrrI07uXeFSMQE3GldJK3dQB2kwgNJBskgWGvVTEQWLLYu5kELu
# Kx4BZzlblaaC3JkVjiwuplq0VBiomDQJR5bzovUqaaJjywTerewFEok3V+2wmydd
# D5IxNKM1D1zf1pz5P0TWbC85SaRkA813WkFivu+jCrxiYFKqeOwsoGyinX7tdxcW
# PVH0S5GvaXbkhdOmZm4BqNF6TshrasCDFdB6Szum5w==
# SIG # End signature block
