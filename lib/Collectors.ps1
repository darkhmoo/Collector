<#
.SYNOPSIS
    Main Collector Loader
.DESCRIPTION
    Loads all individual collector modules and provides a unified interface.
    This file follows the Single Responsibility Principle by delegating
    specific collection tasks to dedicated modules.
#>

# Load all collector modules
$collectorPath = Join-Path -Path $PSScriptRoot -ChildPath "collectors"

. "$collectorPath\HardwareCollector.ps1"
. "$collectorPath\NetworkCollector.ps1"
. "$collectorPath\OSCollector.ps1"
. "$collectorPath\ServiceCollector.ps1"
. "$collectorPath\PerformanceCollector.ps1"
. "$collectorPath\LogCollector.ps1"
. "$collectorPath\SecurityCollector.ps1"
. "$collectorPath\HACollector.ps1"

# Export all collector functions
Export-ModuleMember -Function @(
    'Get-HardwareInfo',
    'Get-NetworkInfo',
    'Get-OSConfig',
    'Get-ServiceInfo',
    'Get-PerformanceInfo',
    'Get-LogInfo',
    'Get-SecurityInfo',
    'Get-HighAvailabilityInfo'
)
