<#
.SYNOPSIS
    Operating System Information Collector
.DESCRIPTION
    Collects OS and configuration information including power plan, time sync, page file, and features.
#>

<#
.SYNOPSIS
    Collects OS and Configuration information.
#>
function Get-OSConfig {
    [PSCustomObject]@{
        OperatingSystem   = Get-CimSafe -ClassName Win32_OperatingSystem
        RecoveryConfig    = Get-CimSafe -ClassName Win32_OSRecoveryConfiguration
        PowerPlan         = Get-CimSafe -Namespace "root\cimv2\power" -ClassName Win32_PowerPlan -WhereBlock { $_.IsActive }
        TimeSync          = $(try { w32tm /query /status } catch { "Time Sync Info Unavailable" })
        PageFileSetting   = Get-CimSafe -ClassName Win32_PageFileSetting
        PageFileUsage     = Get-CimSafe -ClassName Win32_PageFileUsage
        ScheduledJobs     = Get-CimSafe -ClassName Win32_ScheduledJob
        UpdateBuildNumber = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name UBR -ErrorAction SilentlyContinue).UBR
        BootConfig        = Get-CimSafe -ClassName Win32_BootConfiguration
        TimeZone          = Get-CimSafe -ClassName Win32_TimeZone
        ServerFeatures    = Get-CimSafe -ClassName Win32_ServerFeature
        OptionalFeatures  = Get-CimSafe -ClassName Win32_OptionalFeature
    }
}
