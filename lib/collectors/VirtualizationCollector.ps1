<#
.SYNOPSIS
    Virtualization Information Collector (Class-based)
#>

<#
.SYNOPSIS
    Safely retrieves the status of a specific Windows service.
#>
function Get-VirtualizationServiceStatusSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$serviceName
    )

    try {
        $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$serviceName'" -ErrorAction Stop
        if (-not $service) {
            return [PSCustomObject]@{
                Name      = $serviceName
                Exists    = $false
                State     = $null
                StartMode = $null
                Message   = "Service not found"
            }
        }

        [PSCustomObject]@{
            Name      = $serviceName
            Exists    = $true
            State     = $service.State
            StartMode = $service.StartMode
            Message   = $null
        }
    }
    catch {
        [PSCustomObject]@{
            Name      = $serviceName
            Exists    = $false
            State     = $null
            StartMode = $null
            Message   = $_.Exception.Message
        }
    }
}

class VirtualizationCollector : BaseCollector {
    VirtualizationCollector() : base("Virtualization", "Resources") {}

    [PSObject] Collect() {
        $this.LogStart()
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        $data = [PSCustomObject]@{
            HyperV            = $this.GetHyperVInfo()
            WindowsContainers = $this.GetWindowsContainerInfo()
            WSL               = $this.GetWslInfo()
        }

        $sw.Stop()
        $this.LogEnd($sw.ElapsedMilliseconds)
        return $data
    }

    [PSObject] GetWindowsContainerInfo() {
        $containerFeature = [PSCustomObject]@{ Name = "Containers"; Installed = $null; State = $null; Source = $null; Error = $null }
        $nativeRuntimeInfo = [PSCustomObject]@{ Available = $false; Containers = @(); Error = $null }
        $dockerRuntimeInfo = [PSCustomObject]@{ CliAvailable = $false; DaemonReachable = $false; VersionDetails = $null; Containers = @(); Images = @(); Error = $null }

        # 1. Feature Check
        try {
            if (Get-Command -Name Get-WindowsFeature -ErrorAction SilentlyContinue) {
                $feature = Get-WindowsFeature -Name Containers -ErrorAction Stop
                $containerFeature.Installed = [bool]$feature.Installed
                $containerFeature.State = $feature.InstallState.ToString()
                $containerFeature.Source = "Get-WindowsFeature"
            }
            else {
                $optionalFeature = Get-CimInstance -ClassName Win32_OptionalFeature -Filter "Name='Containers'" -ErrorAction Stop
                if ($optionalFeature) {
                    $containerFeature.Installed = ($optionalFeature.InstallState -eq 1)
                    $containerFeature.State = if ($optionalFeature.InstallState -eq 1) { "Enabled" } else { "Disabled" }
                }
                else {
                    $containerFeature.Installed = $false
                    $containerFeature.State = "NotFound"
                }
                $containerFeature.Source = "Win32_OptionalFeature"
            }
        }
        catch { $containerFeature.Error = $_.Exception.Message }

        # 2. Native Runtime
        if (Get-Command -Name Get-Container -ErrorAction SilentlyContinue) {
            try { $nativeRuntimeInfo.Available = $true; $nativeRuntimeInfo.Containers = @(Get-Container -ErrorAction Stop | Select-Object Name, Id, State, RuntimeType) }
            catch { $nativeRuntimeInfo.Error = $_.Exception.Message }
        }

        # 3. Docker Runtime
        if (Get-Command -Name docker -ErrorAction SilentlyContinue) {
            $dockerRuntimeInfo.CliAvailable = $true
            try {
                $dockerVersion = & docker version --format '{{json .}}' 2>&1
                if ($LASTEXITCODE -eq 0 -and $dockerVersion) {
                    $dockerRuntimeInfo.VersionDetails = ($dockerVersion | Out-String).Trim() | ConvertFrom-Json
                    $dockerRuntimeInfo.DaemonReachable = $true
                }
                else { $dockerRuntimeInfo.Error = ($dockerVersion | Out-String).Trim() }
            }
            catch { $dockerRuntimeInfo.Error = $_.Exception.Message }

            if ($dockerRuntimeInfo.DaemonReachable) {
                try {
                    $psOutput = & docker ps -a --format '{{json .}}' 2>&1
                    if ($LASTEXITCODE -eq 0) { $dockerRuntimeInfo.Containers = @($psOutput | Where-Object { $_ -and $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json }) }
                }
                catch { $dockerRuntimeInfo.Error += "; PS failed: $_" }
                try {
                    $imagesOutput = & docker images --format '{{json .}}' 2>&1
                    if ($LASTEXITCODE -eq 0) { $dockerRuntimeInfo.Images = @($imagesOutput | Where-Object { $_ -and $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json }) }
                }
                catch { $dockerRuntimeInfo.Error += "; Images failed: $_" }
            }
        }

        return [PSCustomObject]@{
            ContainersFeature = $containerFeature
            RuntimeServices   = [PSCustomObject]@{
                HostNetworkService = Get-VirtualizationServiceStatusSafe -serviceName "hns"
                HostComputeService = Get-VirtualizationServiceStatusSafe -serviceName "vmcompute"
                DockerService      = Get-VirtualizationServiceStatusSafe -serviceName "docker"
                ContainerdService  = Get-VirtualizationServiceStatusSafe -serviceName "containerd"
            }
            NativeRuntime     = $nativeRuntimeInfo
            DockerRuntime     = $dockerRuntimeInfo
        }
    }

    [PSObject] GetHyperVInfo() {
        $hypervFeature = [PSCustomObject]@{ Name = "Hyper-V"; Installed = $null; State = $null; Source = $null; Error = $null }
        $hostData = [PSCustomObject]@{ Available = $false; Details = $null; Error = $null }
        $vmsData = [PSCustomObject]@{ Available = $false; List = @(); Error = $null }
        $vSwitchData = [PSCustomObject]@{ Available = $false; List = @(); Error = $null }

        try {
            if (Get-Command -Name Get-WindowsFeature -ErrorAction SilentlyContinue) {
                $feature = Get-WindowsFeature -Name Hyper-V -ErrorAction Stop
                $hypervFeature.Installed = [bool]$feature.Installed
                $hypervFeature.State = $feature.InstallState.ToString()
                $hypervFeature.Source = "Get-WindowsFeature"
            }
            else {
                $optional = Get-CimInstance -ClassName Win32_OptionalFeature -Filter "Name='Microsoft-Hyper-V-All'" -ErrorAction Stop
                if ($optional) {
                    $hypervFeature.Installed = ($optional.InstallState -eq 1)
                    $hypervFeature.State = if ($optional.InstallState -eq 1) { "Enabled" } else { "Disabled" }
                }
                $hypervFeature.Source = "Win32_OptionalFeature"
            }
        }
        catch { $hypervFeature.Error = $_.Exception.Message }

        if (Get-Command -Name Get-VMHost -ErrorAction SilentlyContinue) {
            try { $hostData.Available = $true; $hostData.Details = Get-VMHost -ErrorAction Stop | Select-Object * } catch { $hostData.Error = $_.Exception.Message }
        }
        if (Get-Command -Name Get-VM -ErrorAction SilentlyContinue) {
            try { $vmsData.Available = $true; $vmsData.List = @(Get-VM -ErrorAction Stop | Select-Object Name, State, Status, Version, CPUUsage, MemoryAssigned, Uptime) } catch { $vmsData.Error = $_.Exception.Message }
        }
        if (Get-Command -Name Get-VMSwitch -ErrorAction SilentlyContinue) {
            try { $vSwitchData.Available = $true; $vSwitchData.List = @(Get-VMSwitch -ErrorAction Stop | Select-Object Name, SwitchType, NetAdapterInterfaceDescription) } catch { $vSwitchData.Error = $_.Exception.Message }
        }

        return [PSCustomObject]@{
            HyperVFeature   = $hypervFeature
            RuntimeServices = [PSCustomObject]@{
                Vmms      = Get-VirtualizationServiceStatusSafe -serviceName "vmms"
                VmCompute = Get-VirtualizationServiceStatusSafe -serviceName "vmcompute"
            }
            HostDetails     = $hostData
            VirtualMachines = $vmsData
            VirtualSwitches = $vSwitchData
        }
    }

    [PSObject] GetWslInfo() {
        $wslInfo = [PSCustomObject]@{ Available = $false; Distributions = @(); Status = $null; Features = @(); Error = $null }
        try {
            $featureList = [System.Collections.Generic.List[PSObject]]::new()
            $features = @("Microsoft-Windows-Subsystem-Linux", "VirtualMachinePlatform")
            foreach ($featureName in $features) {
                $featureObj = [PSCustomObject]@{ Name = $featureName; Installed = $false; State = "NotFound" }
                if (Get-Command -Name Get-WindowsFeature -ErrorAction SilentlyContinue) {
                    $f = Get-WindowsFeature -Name $featureName -ErrorAction SilentlyContinue
                    if ($f) { $featureObj.Installed = $f.Installed; $featureObj.State = $f.InstallState.ToString() }
                }
                else {
                    $f = Get-CimInstance -ClassName Win32_OptionalFeature -Filter "Name='$featureName'" -ErrorAction SilentlyContinue
                    if ($f) { $featureObj.Installed = ($f.InstallState -eq 1); $featureObj.State = if ($f.InstallState -eq 1) { "Enabled" } else { "Disabled" } }
                }
                $featureList.Add($featureObj)
            }
            $wslInfo.Features = $featureList.ToArray()
        }
        catch { $wslInfo.Error = "Feature check failed: $($_.Exception.Message)" }

        $wslExe = Get-Command -Name wsl.exe -ErrorAction SilentlyContinue
        if ($wslExe) {
            $wslInfo.Available = $true
            try { $listOutput = & wsl.exe --list --verbose 2>&1 | Out-String; if ($LASTEXITCODE -eq 0 -and $listOutput) { $wslInfo.Distributions = $listOutput.Trim() } } catch { $wslInfo.Error += "; Distro list failed: $($_.Exception.Message)" }
            try { $statusOutput = & wsl.exe --status 2>&1 | Out-String; if ($LASTEXITCODE -eq 0 -and $statusOutput) { $wslInfo.Status = $statusOutput.Trim() } } catch { $wslInfo.Error += "; Status failed: $($_.Exception.Message)" }
        }
        return $wslInfo
    }
}

function Get-VirtualizationInfo {
    return ([VirtualizationCollector]::new()).Collect()
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU7DykQK/f4dN0pUcurUk54hVW
# riSgggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUxdu++4Y/oQZPXUL9NsMEStNxBj4wDQYJ
# KoZIhvcNAQEBBQAEggEAeyz48mT/21Q28sYEUiKpsuV9TozV266IITybO3Rc3KsM
# SQ/3sZFx/ozWCMejgRrUejTsVGfXacflEsNCaKxPUai5KKF4krxShs39p+KXPZfS
# 141Ez9uJO4VVuwjJsKkyUD7FGsAH7q2SLD3mHwStyAeRa1FJYOPcssDATLWTBu1K
# cVRVPbmbAzUBfNUA9HxkdD+UJMtbIhrdQMFWI++/45Si/QnYgfm6Gc40YQZe3hhr
# NBD+aT2FCU08zJ0BNIpuDl1ipEcCa0bcyR5XcOUiusVXwa6xr8ZfNQGRvHTi/FtW
# G2n9pvhlbsKDz+QSIPRXQB7eD1+RmWNHNH7cXbE68g==
# SIG # End signature block
