<#
.SYNOPSIS
    High Availability Information Collector (Class-based)
#>

<#
.SYNOPSIS
    Collects MCCS (Mantech Cluster) Information.
#>
function Get-MCCSInfo {
    [CmdletBinding()]
    param()
    try {
        $mccsService = Get-Service -Name "*MCCS*" -ErrorAction SilentlyContinue
        $mccsPathExists = Test-Path "C:\Program Files\Mantech\MCCS"
        if ($mccsService -or $mccsPathExists) { 
            return [PSCustomObject]@{ 
                Installed   = $true
                Services    = $mccsService
                PathExists  = $mccsPathExists
                Registry    = Get-ItemProperty "HKLM:\SOFTWARE\Mantech\MCCS" -ErrorAction SilentlyContinue
                ConfigFiles = if ($mccsPathExists) { Get-ChildItem "C:\Program Files\Mantech\MCCS\conf" -ErrorAction SilentlyContinue | Select-Object Name, Length, LastWriteTime } else { $null }
            } 
        }
        return "Not Detected"
    }
    catch { return "Error: $_" }
}

class HACollector : BaseCollector {
    [string]$OutputPath

    HACollector([string]$outputPath) : base("HighAvailability", "Availability") {
        $this.OutputPath = $outputPath
    }

    [PSObject] Collect() {
        $this.LogStart()
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        $data = [PSCustomObject]@{
            Cluster     = $this.GetClusterInfo()
            NicTeaming  = Get-NetLbfoTeam -ErrorAction SilentlyContinue | Select-Object * -ExcludeProperty "Cim*"
            MCCS        = Get-MCCSInfo
            ExternalSan = [PSCustomObject]@{
                Hdlm      = Get-Service -Name "*HDLM*" -ErrorAction SilentlyContinue | Select-Object *
                PowerPath = Get-Service -Name "*PowerPath*" -ErrorAction SilentlyContinue | Select-Object *
            }
        }

        $sw.Stop()
        $this.LogEnd($sw.ElapsedMilliseconds)
        return $data
    }

    [PSObject] GetClusterInfo() {
        if (-not (Get-Module -ListAvailable -Name FailoverClusters)) { return "Cluster Feature Not Installed" }
        try {
            $clusterObject = Get-Cluster -ErrorAction Stop
            $logDest = if ($this.OutputPath) { $this.OutputPath } else { $PSScriptRoot }
            
            Write-Log -message "  - Generating Cluster Log into $logDest..." -color Gray
            Get-ClusterLog -Destination $logDest -TimeSpan 15 -UseLocalTime -ErrorAction SilentlyContinue

            $clusterFiles = Get-ChildItem -Path $logDest -Filter "*cluster.log" -ErrorAction SilentlyContinue
            return [PSCustomObject]@{
                ClusterObject       = $clusterObject | Select-Object *
                Nodes               = Get-ClusterNode | Select-Object *
                Groups              = Get-ClusterGroup | Select-Object *
                Resources           = Get-ClusterResource | Select-Object *
                Networks            = Get-ClusterNetwork | Select-Object *
                MsClusterEvents     = Get-CimSafe -namespace "root\MSCluster" -className MSCluster_Event
                MsClusterDisks      = Get-CimSafe -namespace "root\MSCluster" -className MSCluster_Disk
                ClusterLogGenerated = ($clusterFiles.Count -gt 0)
                ClusterLogFiles     = ($clusterFiles.Name -join ", ")
            }
        }
        catch { return "Cluster Feature Installed but Not Configured or WMI Error: $_" }
    }
}

function Get-HighAvailabilityInfo {
    # Backward compatibility wrapper
    return ([HACollector]::new($script:outputPath)).Collect()
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUbM7uEjZhpro5oBzpoHVGg2Q8
# QumgggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUEyEIZHP8obZdnxiupEQrJVnEL6wwDQYJ
# KoZIhvcNAQEBBQAEggEAW1P3BCx/OJmR0ISSewZKNDoXkrWYBkgjnGAJYywZ5CUF
# jCW49sOdyrgzJLtBy8MRgSHbPKP9AwCO3KptQZEl3RlTVKadc64oxFOh/hNIktb5
# t3MBgVBY3GFmxp3uecQ4n7l2MSpjEjNFyn9upjudNvwTjcdn+D8UfHNLSu7g/fah
# WpjHbuCSEo2hdmyKD8rVVAYg3OFQf6We6MBA0YoyFp8Zk6A56/HBi/wi0LtZOrjG
# 03eSJDd/+1lCro75YZFWUbHa6/aE0NDn5ZGi/OGyzyJ5ujNNnz+8oOGUUt7aI08w
# m8gKl8pAngDSHEZHYlxFWAZ+Mf/575MBQDru6Jz0XQ==
# SIG # End signature block
