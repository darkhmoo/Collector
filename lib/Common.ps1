# --- Helper Functions ---

<#
.SYNOPSIS
    Safely executes Get-CimInstance with error handling and projection.
#>
function Get-CimSafe {
    param(
        [string]$ClassName,
        [string]$Namespace = "root\cimv2",
        [string]$Filter,
        [string[]]$SelectProperties = "*",
        [string[]]$ExcludeProperties = "Cim*",
        [scriptblock]$WhereBlock
    )

    try {
        $params = @{
            ClassName   = $ClassName
            Namespace   = $Namespace
            ErrorAction = "Stop"
        }
        if ($Filter) { $params.Filter = $Filter }

        $cmd = Get-CimInstance @params
        if ($WhereBlock) {
            $cmd = $cmd | Where-Object $WhereBlock
        }

        $cmd | Select-Object -Property $SelectProperties -ExcludeProperty $ExcludeProperties
    }
    catch {
        return "Error: $_"
    }
}

<#
.SYNOPSIS
    Writes output to console and optionally to a debug log file.
#>
function Write-Log {
    param(
        [string]$Message,
        [ConsoleColor]$Color = "White",
        [ValidateSet("Debug", "Info", "Warning", "Error")]
        [string]$Level = "Info"
    )

    if ($Level -eq "Debug" -and -not $Script:DebugMode) {
        return
    }

    Write-Host $Message -ForegroundColor $Color

    if ($Script:DebugMode -and $Script:DebugLogFile) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $logEntry = "[$timestamp] [$Level] $Message"
        try {
            Add-Content -Path $Script:DebugLogFile -Value $logEntry -Encoding UTF8 -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to write debug log file '$Script:DebugLogFile': $($_.Exception.Message)"
        }
    }
}

<#
.SYNOPSIS
    Checks if the script is running with Administrator privileges.
#>
function Assert-AdminPrivileges {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "Not running as Administrator. Some data collection may fail."
        exit 1
    }
}

<#
.SYNOPSIS
    Verifies system prerequisites before execution.
#>
function Assert-Prerequisites {
    $minPSVersion = [version]"5.1"
    if ($PSVersionTable.PSVersion -lt $minPSVersion) {
        throw "CRITICAL ERROR: PowerShell $minPSVersion or higher is required."
    }

    $systemDriveLetter = $env:SystemDrive.Substring(0, 1)
    $drive = Get-PSDrive -Name $systemDriveLetter
    if ($drive.Free -lt 50MB) {
        throw "CRITICAL ERROR: Free disk space is less than 50MB."
    }

    if ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1) {
        Write-Warning "This script is designed for Windows Server. Client OS detected."
    }
}

<#
.SYNOPSIS
    Ensures singleton execution using a named Mutex.
#>
function Get-ScriptMutex {
    $mutexName = "Global\SystemInfoCollector_Mutex"
    $createdNew = $false
    $mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)
    if (-not $createdNew) {
        $mutex.Dispose()
        throw "CRITICAL ERROR: Script is already running."
    }

    return $mutex
}

<#
.SYNOPSIS
    Executes collection blocks with timing, memory snapshot, and error handling.
#>
function Invoke-Collection {
    param(
        [string]$Name,
        [scriptblock]$ScriptBlock
    )

    Write-Log "[$Name] Starting collection..." -Color Cyan -Level Info

    $memBefore = 0
    $memAfter = 0
    if ($Script:DebugMode) {
        $process = Get-Process -Id $PID
        $memBefore = [math]::Round($process.WorkingSet64 / 1MB, 2)
        Write-Log "[$Name] Memory before: ${memBefore}MB" -Color DarkGray -Level Debug
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        Write-Log "[$Name] Executing script block..." -Color DarkGray -Level Debug
        $result = & $ScriptBlock
        $sw.Stop()

        $itemCount = 0
        $itemType = "unknown"

        if ($null -eq $result) {
            $itemType = "null"
        }
        elseif ($result -is [string] -and $result.StartsWith("Error:")) {
            $itemType = "error"
        }
        elseif ($result -is [array]) {
            $itemCount = $result.Count
            $itemType = "array"
        }
        elseif ($result -is [PSCustomObject]) {
            $itemCount = ($result | Get-Member -MemberType NoteProperty).Count
            $itemType = "object"
        }
        elseif ($result -is [hashtable]) {
            $itemCount = $result.Count
            $itemType = "hashtable"
        }
        else {
            $itemCount = 1
            $itemType = $result.GetType().Name
        }

        if ($Script:DebugMode) {
            $process = Get-Process -Id $PID
            $memAfter = [math]::Round($process.WorkingSet64 / 1MB, 2)
            $memDelta = [math]::Round($memAfter - $memBefore, 2)
            Write-Log "[$Name] Memory after: ${memAfter}MB (Delta: ${memDelta}MB)" -Color DarkGray -Level Debug

            if ($null -eq $script:StepTimings) {
                $script:StepTimings = @()
            }
            $script:StepTimings += [PSCustomObject]@{
                Name              = $Name
                DurationMs        = $sw.ElapsedMilliseconds
                DurationFormatted = $sw.Elapsed.ToString('hh\:mm\:ss\.fff')
                ItemCount         = $itemCount
                ItemType          = $itemType
                MemoryBefore      = $memBefore
                MemoryAfter       = $memAfter
                MemoryDelta       = $memDelta
            }
        }

        Write-Log "[$Name] Completed in $($sw.Elapsed.ToString('hh\:mm\:ss\.fff')) - Type: $itemType, Items: $itemCount" -Color Green -Level Info
        return $result
    }
    catch {
        $sw.Stop()
        Write-Log "[$Name] Failed after $($sw.Elapsed.ToString('hh\:mm\:ss\.fff')): $_" -Color Red -Level Error

        if ($Script:DebugMode) {
            Write-Log "[$Name] Stack trace: $($_.ScriptStackTrace)" -Color DarkRed -Level Debug
            Write-Log "[$Name] Exception type: $($_.Exception.GetType().FullName)" -Color DarkRed -Level Debug

            if ($null -eq $script:StepTimings) {
                $script:StepTimings = @()
            }
            $script:StepTimings += [PSCustomObject]@{
                Name              = "$Name (FAILED)"
                DurationMs        = $sw.ElapsedMilliseconds
                DurationFormatted = $sw.Elapsed.ToString('hh\:mm\:ss\.fff')
                ItemCount         = 0
                ItemType          = "error"
                MemoryBefore      = $memBefore
                MemoryAfter       = $memAfter
                MemoryDelta       = 0
            }
        }

        return "Error: $_"
    }
}
