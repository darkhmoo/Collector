<#
.SYNOPSIS
    OS Information Collector (Class-based)
#>

<#
.SYNOPSIS
    Collects Windows Language Pack information.
#>
function Get-WindowsLanguagePackInfo {
    [CmdletBinding()]
    param()

    $languageInfo = [PSCustomObject]@{
        Registry = @()
        DismIntl = $null
        Errors   = @()
    }

    try {
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\MUI\Languages"
        if (Test-Path $regPath) {
            $languageInfo.Registry = Get-ChildItem -Path $regPath | Select-Object Name
        }
    }
    catch {
        $languageInfo.Errors += "Failed to query MUI registry: $($_.Exception.Message)"
    }

    try {
        if (Get-Command "dism" -ErrorAction SilentlyContinue) {
            $languageInfo.DismIntl = & dism /online /Get-Intl | Out-String
        }
    }
    catch {
        $languageInfo.Errors += "dism /Get-Intl failed: $($_.Exception.Message)"
    }

    return $languageInfo
}

<#
.SYNOPSIS
    Collects installed .NET Framework versions.
#>
function Get-DotNetVersions {
    [CmdletBinding()]
    param()

    $results = [System.Collections.Generic.List[PSObject]]::new()
    try {
        # Modern .NET
        $netPath = "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full"
        if (Test-Path $netPath) {
            $val = Get-ItemProperty -Path $netPath -ErrorAction SilentlyContinue
            if ($val.Release) {
                $results.Add([PSCustomObject]@{ Version = "4.x"; Release = $val.Release; InstallPath = $val.InstallPath })
            }
        }
    }
    catch {
        Write-Log -message "Failed to collect .NET versions: $_" -level Debug
    }
    return $results.ToArray()
}

<#
.SYNOPSIS
    Collects registry entries from common "Run" keys.
#>
function Get-AutoRuns {
    [CmdletBinding()]
    param()

    $runKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    )

    $results = [System.Collections.Generic.List[PSObject]]::new()
    foreach ($path in $runKeys) {
        if (Test-Path $path) {
            $props = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
            $props.PSObject.Properties | Where-Object { $_.Name -notin @("PSPath", "PSParentPath", "PSChildName", "PSDrive", "PSProvider") } | ForEach-Object {
                $results.Add([PSCustomObject]@{ Key = $path; Name = $_.Name; Value = Get-MaskedValue -inputString $_.Value })
            }
        }
    }
    return $results.ToArray()
}

<#
.SYNOPSIS
    Collects environment variables and certificate health.
#>
function Get-SystemHealthInfo {
    [CmdletBinding()]
    param()

    $maskEnv = {
        param($envMap)
        $newMap = [ordered]@{}
        if ($envMap -is [System.Collections.IDictionary]) {
            foreach ($key in $envMap.Keys) {
                # Use universal masker for both key and value
                $isSensitive = (Get-MaskedValue -inputString $key) -like "*Masked*"
                $newMap[$key] = if ($isSensitive) { "******** [Masked for Security]" } else { Get-MaskedValue -inputString $envMap[$key] }
            }
        }
        return $newMap
    }

    [PSCustomObject]@{
        EnvironmentVariables = [PSCustomObject]@{
            System = & $maskEnv ([Environment]::GetEnvironmentVariables("Machine"))
            User   = & $maskEnv ([Environment]::GetEnvironmentVariables("User"))
            Path   = $env:PATH -split ";"
        }
        Certificates         = [PSCustomObject]@{
            Store = Get-ChildItem -Path Cert:\LocalMachine\My -ErrorAction SilentlyContinue | Select-Object Subject, NotAfter, Thumbprint
        }
    }
}

class OSCollector : BaseCollector {
    OSCollector() : base("OSConfig", "OperatingSystem") {}

    [PSObject] Collect() {
        $this.LogStart()
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        $updateBuildNumber = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name UBR -ErrorAction SilentlyContinue).UBR

        $updates = [PSCustomObject]@{
            DismFeatures = $(if (Get-Command "dism" -ErrorAction SilentlyContinue) { & dism /online /get-features /format:table | Out-String } else { "DISM not found" })
            DismCapacity = $(if (Get-Command "dism" -ErrorAction SilentlyContinue) { & dism /online /get-capabilities /format:table | Out-String } else { "DISM not found" })
        }

        $timeSync = [PSCustomObject]@{
            Config = $(if (Get-Command "w32tm" -ErrorAction SilentlyContinue) { & w32tm /query /configuration | Out-String } else { "w32tm not found" })
            Status = $(if (Get-Command "w32tm" -ErrorAction SilentlyContinue) { & w32tm /query /status | Out-String } else { "w32tm not found" })
        }

        $secureBootInfo = try {
            [PSCustomObject]@{
                Supported = $true
                Enabled   = [bool](Confirm-SecureBootUEFI -ErrorAction Stop)
                Message   = $null
            }
        }
        catch {
            [PSCustomObject]@{ Supported = $false; Enabled = $null; Message = $_.Exception.Message }
        }

        $data = [PSCustomObject]@{
            OperatingSystem      = Get-CimSafe -className Win32_OperatingSystem
            RecoveryConfig       = Get-CimSafe -className Win32_OSRecoveryConfiguration
            PowerPlan            = Get-CimSafe -namespace "root\cimv2\power" -className Win32_PowerPlan -whereBlock { $_.IsActive }
            SecureBoot           = $secureBootInfo
            TimeSync             = $timeSync.Status
            PageFileSetting      = Get-CimSafe -className Win32_PageFileSetting
            PageFileUsage        = Get-CimSafe -className Win32_PageFileUsage
            ScheduledJobs        = Get-CimSafe -className Win32_ScheduledJob
            AutoRuns             = Get-AutoRuns
            SystemHealth         = Get-SystemHealthInfo
            DotNetVersions       = Get-DotNetVersions
            UpdateBuildNumber    = $updateBuildNumber
            BootConfig           = Get-CimSafe -className Win32_BootConfiguration
            TimeZone             = Get-CimSafe -className Win32_TimeZone
            QuickFixEngineering  = Get-CimSafe -className Win32_QuickFixEngineering
            OptionalFeatures     = Get-CimSafe -className Win32_OptionalFeature
            WindowsLanguagePacks = Get-WindowsLanguagePackInfo
            DismFeatures         = $updates.DismFeatures
            DismCapacity         = $updates.DismCapacity
            TimeSyncConfig       = $timeSync.Config
        }

        $sw.Stop()
        $this.LogEnd($sw.ElapsedMilliseconds)
        return $data
    }
}

function Get-OSConfig {
    return ([OSCollector]::new()).Collect()

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUQmV+6hrO9xciVisuqsI9P5Kn
# GAmgggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUyNVw5VLyyYtMmDjk7hFXu17zXEIwDQYJ
# KoZIhvcNAQEBBQAEggEAqB0XONXkb9q3wNMeoQEjWq3Za5XXgMvSIDPz8tv1s+uR
# I6oSc6WkeOgZXkYyMdMJEXyFra4JRcfrQyEN0sMQP73gf2vDM7Y+GexGYO9onEed
# a0Q9AjD3C1GtAz3ETb+rNW0t03nA9yr1z9XWfYwpxPWTDblO9Qhm5AOlcUPvbzQm
# 10y/zRmqcc7IzKtZQ7p6ch4H9sbyzkceD3oDLQK4colmgdmIx1QaBhwOHXhGFn5H
# GHn/6EIlgkSuQtj6hcntRRcbDd1dTQ/LyVhXZfh1wU8wjV+vxdxe2n07ixS2WWzU
# MXjvLIZEQkfudW3XVESVREQWGH6lfHaoA8Gi386LoQ==
# SIG # End signature block
