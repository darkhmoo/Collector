
# --- Helper Functions ---

<#
.SYNOPSIS
    Safely executes Get-CimInstance with error handling and selection.
.PARAMETER ClassName
    The CIM class name.
.PARAMETER Namespace
    The CIM namespace (default: root\cimv2).
.PARAMETER Filter
    WQL filter string.
.PARAMETER SelectProperties
    Properties to select (default: *).
.PARAMETER ExcludeProperties
    Properties to exclude (default: Cim*).
.PARAMETER WhereBlock
    Optional script block for client-side filtering (Where-Object).
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
    Writes output to console and optionally to a log file in debug mode.
.PARAMETER Message
    The message to log.
.PARAMETER Color
    Console text color.
.PARAMETER Level
    Log level: Debug, Info, Warning, Error (default: Info)
#>
function Write-Log {
    param(
        [string]$Message,
        [ConsoleColor]$Color = "White",
        [ValidateSet("Debug", "Info", "Warning", "Error")]
        [string]$Level = "Info"
    )

    # Only show Debug messages in DebugMode
    if ($Level -eq "Debug" -and -not $Script:DebugMode) {
        return
    }

    # Console Output
    Write-Host $Message -ForegroundColor $Color

    # File Output (Debug Mode Only)
    if ($Script:DebugMode -and $Script:DebugLogFile) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $logEntry = "[$timestamp] [$Level] $Message"
        Add-Content -Path $Script:DebugLogFile -Value $logEntry -Encoding UTF8
    }
}

<#
.SYNOPSIS
    Checks if the script is running with Administrator privileges.
.DESCRIPTION
    If not running as Admin, attempts to self-elevate using 'RunAs'.
    Exits the current process if elevation fails or is required.
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
.DESCRIPTION
    Checks for:
    - Minimum PowerShell Version (5.1)
    - Free Disk Space (50MB)
    - OS Type (Windows Server)
#>
function Assert-Prerequisites {
    # Version Check
    $MinPSVersion = [version]"5.1"
    if ($PSVersionTable.PSVersion -lt $MinPSVersion) {
        throw "CRITICAL ERROR: PowerShell $MinPSVersion or higher is required."
    }

    # Disk Space Check
    $drive = Get-PSDrive -Name $env:SystemDrive.Substring(0, 1)
    if ($drive.Free -lt 50MB) {
        throw "CRITICAL ERROR: Free disk space is less than 50MB."
    }

    # OS Check
    if ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1) {
        Write-Warning "This script is designed for Windows Server. Client OS detected."
    }
}

<#
    .SYNOPSIS
        Ensures singleton execution using a named Mutex.
    .OUTPUTS
        System.Threading.Mutex
    #>
function Get-ScriptMutex {
    $mutexName = "Global\SystemInfoCollector_Mutex"
    try {
        [void][System.Threading.Mutex]::OpenExisting($mutexName)
        throw "CRITICAL ERROR: Script is already running."
    }
    catch [System.Threading.WaitHandleCannotBeOpenedException] {
        return New-Object System.Threading.Mutex($true, $mutexName)
    }
}

<#
.SYNOPSIS
    Wrapper for executing collection blocks with timing, error handling, and detailed debugging.
.PARAMETER Name
    The display name of the collection step.
.PARAMETER ScriptBlock
    The code block to execute.
#>
function Invoke-Collection {
    param(
        [string]$Name,
        [scriptblock]$ScriptBlock
    )
    
    Write-Log "[$Name] Starting collection..." -Color Cyan -Level Info
    
    # Memory tracking in debug mode
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
        
        # Count collected items
        $itemCount = 0
        $itemType = "unknown"
        
        if ($null -eq $result) {
            $itemType = "null"
        }
        elseif ($result -is [String] -and $result.StartsWith("Error:")) {
            $itemType = "error"
            $itemCount = 0
        }
        elseif ($result -is [Array]) {
            $itemCount = $result.Count
            $itemType = "array"
        }
        elseif ($result -is [PSCustomObject]) {
            $itemCount = ($result | Get-Member -MemberType NoteProperty).Count
            $itemType = "object"
        }
        elseif ($result -is [Hashtable]) {
            $itemCount = $result.Count
            $itemType = "hashtable"
        }
        else {
            $itemCount = 1
            $itemType = $result.GetType().Name
        }
        
        # Memory tracking in debug mode
        if ($Script:DebugMode) {
            $process = Get-Process -Id $PID
            $memAfter = [math]::Round($process.WorkingSet64 / 1MB, 2)
            $memDelta = [math]::Round($memAfter - $memBefore, 2)
            Write-Log "[$Name] Memory after: ${memAfter}MB (Delta: ${memDelta}MB)" -Color DarkGray -Level Debug
            
            # Track timing for summary
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
        
        Write-Log "[$Name] ✓ Completed in $($sw.Elapsed.ToString('hh\:mm\:ss\.fff')) - Type: $itemType, Items: $itemCount" `
            -Color Green -Level Info
        
        return $result
    }
    catch {
        $sw.Stop()
        Write-Log "[$Name] ✗ Failed after $($sw.Elapsed.ToString('hh\:mm\:ss\.fff')): $_" `
            -Color Red -Level Error
        
        if ($Script:DebugMode) {
            Write-Log "[$Name] Stack trace: $($_.ScriptStackTrace)" -Color DarkRed -Level Debug
            Write-Log "[$Name] Exception type: $($_.Exception.GetType().FullName)" -Color DarkRed -Level Debug
            
            # Track failed step timing
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
