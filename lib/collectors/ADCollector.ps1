<#
.SYNOPSIS
    Active Directory Information Collector (Class-based)
#>

class ADCollector : BaseCollector {
    ADCollector() : base("ActiveDirectory", "Directory") {}

    [PSObject] Collect() {
        $this.LogStart()
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        $computerSystem = Get-CimSafe -className Win32_ComputerSystem
        $adReport = [PSCustomObject]@{
            Environment = [PSCustomObject]@{ PartOfDomain = $false; DomainName = $null; ComputerName = $env:COMPUTERNAME; Message = $null }
            Availability = [PSCustomObject]@{ AdModuleAvailable = $false; Message = $null }
            Domain = $null; Forest = $null; DomainControllers = @(); Trusts = @()
            ObjectSummary = [PSCustomObject]@{ SampleLimit = 5000; UsersSampled = $null; UsersEnabled = $null; UsersDisabled = $null; GroupsSampled = $null; ComputersSampled = $null; OusSampled = $null; Errors = @() }
        }

        if ($computerSystem -is [PSCustomObject]) {
            $adReport.Environment.PartOfDomain = [bool]$computerSystem.PartOfDomain
            $adReport.Environment.DomainName = $computerSystem.Domain
        }

        if (-not $adReport.Environment.PartOfDomain) {
            $adReport.Environment.Message = "Computer is not joined to a domain"
            $this.LogEnd($sw.ElapsedMilliseconds)
            return $adReport
        }

        if (-not (Get-Command -Name Get-ADDomain -ErrorAction SilentlyContinue)) {
            $adReport.Availability.Message = "ActiveDirectory module is not available"
            $this.LogEnd($sw.ElapsedMilliseconds)
            return $adReport
        }

        $adReport.Availability.AdModuleAvailable = $true
        $sampleLimit = $adReport.ObjectSummary.SampleLimit

        try { $adReport.Domain = Get-ADDomain -ErrorAction Stop | Select-Object DNSRoot, NetBIOSName, DomainMode, ParentDomain, PDCEmulator, RIDMaster, InfrastructureMaster }
        catch { $adReport.ObjectSummary.Errors += "Domain query failed: $($_.Exception.Message)" }

        try { $adReport.Forest = Get-ADForest -ErrorAction Stop | Select-Object RootDomain, ForestMode, Domains, Sites, GlobalCatalogs }
        catch { $adReport.ObjectSummary.Errors += "Forest query failed: $($_.Exception.Message)" }

        try { $adReport.DomainControllers = @(Get-ADDomainController -Filter * -ErrorAction Stop | Select-Object HostName, IPv4Address, Site, Forest, OperatingSystem, IsGlobalCatalog, IsReadOnly) }
        catch { $adReport.ObjectSummary.Errors += "DC query failed: $($_.Exception.Message)" }

        try { $adReport.Trusts = @(Get-ADTrust -Filter * -ErrorAction Stop | Select-Object Name, Direction, TrustType, ForestTransitive, IntraForest, Source, Target) }
        catch { $adReport.ObjectSummary.Errors += "Trust query failed: $($_.Exception.Message)" }

        try {
            $users = @(Get-ADUser -Filter * -Properties Enabled -ResultSetSize $sampleLimit -ErrorAction Stop)
            $adReport.ObjectSummary.UsersSampled = $users.Count
            $adReport.ObjectSummary.UsersEnabled = @($users | Where-Object { $_.Enabled }).Count
            $adReport.ObjectSummary.UsersDisabled = @($users | Where-Object { -not $_.Enabled }).Count
        }
        catch { $adReport.ObjectSummary.Errors += "User summary failed: $($_.Exception.Message)" }

        try { $adReport.ObjectSummary.GroupsSampled = @(Get-ADGroup -Filter * -ResultSetSize $sampleLimit -ErrorAction Stop).Count }
        catch { $adReport.ObjectSummary.Errors += "Group summary failed: $($_.Exception.Message)" }

        try { $adReport.ObjectSummary.ComputersSampled = @(Get-ADComputer -Filter * -ResultSetSize $sampleLimit -ErrorAction Stop).Count }
        catch { $adReport.ObjectSummary.Errors += "Computer summary failed: $($_.Exception.Message)" }

        try { $adReport.ObjectSummary.OusSampled = @(Get-ADOrganizationalUnit -Filter * -ResultSetSize $sampleLimit -ErrorAction Stop).Count }
        catch { $adReport.ObjectSummary.Errors += "OU summary failed: $($_.Exception.Message)" }

        $sw.Stop()
        $this.LogEnd($sw.ElapsedMilliseconds)
        return $adReport
    }
}

function Get-ActiveDirectoryInfo {
    return ([ADCollector]::new()).Collect()
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUsPKPY+Ib31GdWLx++yMneFz3
# B3mgggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUMML05W51VeaVP7dIimE3KayInt0wDQYJ
# KoZIhvcNAQEBBQAEggEAGpyI6Mx7zuPHEae6EyeDzj3esyzStGm67bcly9KjbYGb
# jacPXxAHdUNlmmMkEZXwk9+cV9oUGjz7kmWkk8IVFbFsqfA3kdNQLNspvXombiMz
# k3kLCaQFY5Pnx6ClNJsP01XRKI0FWtykwr0alBKVUM6F0sDxZiubyxX8aPg30CdP
# 2vC54XHAtz19qAfsFdbbOLnJqcRdi4Iytf2IOv4HKTTq4uu26Bwef2aNLdlAMm1Q
# kjZ8o+Rg/9Rao9G50Saf4ZIXfoE52JKg5hILoE/BZJECpUG/X8a0l7eb3EIOXDtD
# jPQAaTQR5PeI+GqpiQvWd6ia75S7UyO2r1O8T+LxtQ==
# SIG # End signature block
