# --- Helper Functions ---

<#
.SYNOPSIS
    Safely executes Get-CimInstance with error handling and projection.
.PARAMETER className
    The name of the WMI class to query.
.PARAMETER namespace
    The WMI namespace (default: root\cimv2).
.PARAMETER filter
    WQL filter string.
.PARAMETER selectProperties
    Properties to select (default: *).
.PARAMETER excludeProperties
    Properties to exclude (default: Cim*).
.PARAMETER whereBlock
    Optional scriptblock for client-side filtering.
#>
function Get-CimSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$className,
        
        [Parameter(Mandatory = $false)]
        [string]$namespace = 'root\cimv2',
        
        [Parameter(Mandatory = $false)]
        [string]$filter,
        
        [Parameter(Mandatory = $false)]
        [string[]]$selectProperties = '*',
        
        [Parameter(Mandatory = $false)]
        [string[]]$excludeProperties = 'Cim*',
        
        [Parameter(Mandatory = $false)]
        [scriptblock]$whereBlock
    )

    try {
        $cimParams = @{
            ClassName   = $className
            Namespace   = $namespace
            ErrorAction = 'Stop'
        }
        if ($filter) { $cimParams.Filter = $filter }

        $instances = Get-CimInstance @cimParams
        if ($whereBlock) {
            $instances = $instances | Where-Object $whereBlock
        }

        $instances | Select-Object -Property $selectProperties -ExcludeProperty $excludeProperties
    }
    catch {
        # Edge Case: WMI Repository Corruption or Service Down
        $hresultCode = $_.Exception.HResult
        $hresultMsg = ''
        if ($hresultCode) {
            $hresultMsg = ' (HRESULT: 0x{0:X})' -f $hresultCode
        }
        $exceptionMsg = $_.Exception.Message
        
        # Define known optional classes that might be missing on some systems
        # This approach avoids regex encoding issues with localized error messages
        $optionalClasses = @(
            'Win32_DtcClusterDefaultResource', 
            'Win32_AccountStore', 
            'Win32_LSAAccount', 
            'AntivirusProduct',
            'Win32_OptionalFeature'
        )
        
        # Downgrade errors for optional classes to Debug
        if ($className -in $optionalClasses -or $hresultCode -eq -2147217392) {
            $logMsg = '    (Optional) Class {0} not found. Skipping.' -f $className
            Write-Log -message $logMsg -color DarkGray -level Debug
        }
        else {
            $logMsg = '    ! Get-CimSafe failed for {0}: {1}{2}' -f $className, $exceptionMsg, $hresultMsg
            Write-Log -message $logMsg -color Yellow -level Warning
        }
        
        if ($script:DebugMode) {
            Write-Log -message ('    [Stack] {0}' -f $_.ScriptStackTrace) -color DarkYellow -level Debug
        }
        return @() 
    }
}


<#
.SYNOPSIS
    Writes output to console and optionally to a debug log file.
.PARAMETER message
    The log message.
.PARAMETER color
    Foreground color for console output.
.PARAMETER level
    Log level (Debug, Info, Warning, Error).
#>
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$message,
        
        [Parameter(Mandatory = $false)]
        [ConsoleColor]$color = "White",
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Debug", "Info", "Warning", "Error")]
        [string]$level = "Info"
    )

    # Honor DebugMode flag from calling script
    if ($level -eq "Debug" -and -not $script:DebugMode) {
        return
    }

    # Console Output (using Write-Host for colored output, or Write-Information for streams)
    Write-Host $message -ForegroundColor $color

    # File Logging
    if ($script:DebugMode -and $script:DebugLogFile) {
        $timeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $logEntry = "[$timeStamp] [$level] $message"
        try {
            # Concurrency protection for parallel logging
            $retryCount = 0
            $success = $false
            while (-not $success -and $retryCount -lt 3) {
                try {
                    Add-Content -Path $script:DebugLogFile -Value $logEntry -Encoding UTF8 -ErrorAction Stop
                    $success = $true
                }
                catch {
                    $retryCount++
                    Start-Sleep -Milliseconds (10 * $retryCount)
                }
            }
        }
        catch {
            # If it still fails, we don't want to crash the collection
            # Write-Warning may also fail if redirected, so we use a silent approach or just continue
        }
    }
}

<#
.SYNOPSIS
    Checks if the script is running with Administrator privileges.
#>
function Assert-AdminPrivileges {
    [CmdletBinding()]
    param()

    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Warning "Not running as Administrator. Some data collection may fail."
        return $false
    }

    return $true
}

<#
.SYNOPSIS
    Verifies system prerequisites before execution.
#>
function Assert-Prerequisites {
    [CmdletBinding()]
    param()

    $minPsVersion = [version]"5.1"
    if ($PSVersionTable.PSVersion -lt $minPsVersion) {
        throw "CRITICAL ERROR: PowerShell $minPsVersion or higher is required. Current: $($PSVersionTable.PSVersion)"
    }

    # WMI Service Health Check (Edge Case: Winmgmt service disabled)
    $wmiService = Get-Service -Name winmgmt -ErrorAction SilentlyContinue
    if ($null -eq $wmiService -or $wmiService.Status -ne "Running") {
        throw "CRITICAL ERROR: Windows Management Instrumentation (winmgmt) service is not running. Status: $($wmiService.Status)"
    }

    $systemDriveLetter = $env:SystemDrive.Substring(0, 1)
    $systemDrive = Get-PSDrive -Name $systemDriveLetter
    
    # Audit Rule: $O(S \times 3)$ space check. Assume S=50MB, so 150MB recommended.
    $requiredSpace = 150MB
    if ($systemDrive.Free -lt $requiredSpace) {
        $freeMB = [math]::Round($systemDrive.Free / 1MB, 2)
        throw "CRITICAL ERROR: Insufficient disk space on $($systemDriveLetter): ($freeMB MB free). At least 150MB required for secure processing."
    }

    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($os -and $os.ProductType -eq 1) {
        Write-Log -message "[Notice] Client OS detected. Optimized for Windows Server." -color Gray -level Info
    }
}

<#
.SYNOPSIS
    Universal data masking for sensitive strings.
#>
function Get-MaskedValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$inputString,
        [string[]]$keywords = @("password", "secret", "key", "token", "credential", "auth", "connectionstring")
    )
    if ([string]::IsNullOrWhiteSpace($inputString)) { return $inputString }
    
    foreach ($word in $keywords) {
        if ($inputString -like "*$word*" -or $inputString -like "*$($word.ToUpper())*") {
            return "******** [Masked for Security]"
        }
    }
    return $inputString
}

<#
.SYNOPSIS
    Ensures singleton execution using a named Mutex.
#>
function Get-ScriptMutex {
    [CmdletBinding()]
    param()

    $mutexName = "Global\SystemInfoCollector_Mutex"
    $isCreatedNew = $false
    try {
        $mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$isCreatedNew)
        
        if (-not $isCreatedNew) {
            $mutex.Dispose()
            # Edge Case: Provide details about the existing process if possible
            $currentProcId = $PID
            $logMsg = "CRITICAL ERROR: Script is already running (Mutex locked: $mutexName). "
            $logMsg += "Check for other powershell.exe instances. Current PID: $currentProcId"
            throw $logMsg
        }
        return $mutex
    }
    catch {
        # Fallback for Mutex creation failures (e.g., access denied to Global namespace)
        if ($_.Exception.Message -like "*Access to the path*is denied*") {
            Write-Log -message "[Warning] Access denied to Global Mutex. Falling back to Local Mutex." -color Yellow -level Warning
            $localMutexName = "Local\SystemInfoCollector_Mutex"
            return New-Object System.Threading.Mutex($true, $localMutexName, [ref]$isCreatedNew)
        }
        throw $_
    }
}

<#
.SYNOPSIS
    Executes collection blocks with timing, memory snapshot, and error handling.
.PARAMETER taskName
    The name of the collection task.
.PARAMETER collectionBlock
    The scriptblock to execute.
#>
function Invoke-Collection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$taskName,
        
        [Parameter(Mandatory = $true)]
        [scriptblock]$collectionBlock
    )

    Write-Log -message "[$taskName] Starting collection..." -color Cyan -level Info

    $memBefore = 0
    $memAfter = 0
    if ($script:DebugMode) {
        $currentProcess = Get-Process -Id $PID
        $memBefore = [math]::Round($currentProcess.WorkingSet64 / 1MB, 2)
        Write-Log -message "[$taskName] Memory before: ${memBefore}MB" -color DarkGray -level Debug
    }

    $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        Write-Log -message "[$taskName] Executing core collection..." -color DarkGray -level Debug
        $result = & $collectionBlock
        $stopWatch.Stop()

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

        if ($script:DebugMode) {
            $currentProcess = Get-Process -Id $PID
            $memAfter = [math]::Round($currentProcess.WorkingSet64 / 1MB, 2)
            $memDelta = [math]::Round($memAfter - $memBefore, 2)
            Write-Log -message "[$taskName] Memory after: ${memAfter}MB (Delta: ${memDelta}MB)" -color DarkGray -level Debug

            if ($null -eq $script:StepTimings) {
                $script:StepTimings = @()
            }
            $script:StepTimings += [PSCustomObject]@{
                Name              = $taskName
                DurationMs        = $stopWatch.ElapsedMilliseconds
                DurationFormatted = $stopWatch.Elapsed.ToString('hh\:mm\:ss\.fff')
                ItemCount         = $itemCount
                ItemType          = $itemType
                MemoryBefore      = $memBefore
                MemoryAfter       = $memAfter
                MemoryDelta       = $memDelta
            }
        }

        Write-Log -message "[$taskName] Completed in $($stopWatch.Elapsed.ToString('hh\:mm\:ss\.fff')) - Type: $itemType, Items: $itemCount" -color Green -level Info
        return $result
    }
    catch {
        $stopWatch.Stop()
        $errorMessage = "[$taskName] Failed after $($stopWatch.Elapsed.ToString('hh\:mm\:ss\.fff')): $($_.Exception.Message)"
        Write-Log -message $errorMessage -color Red -level Error

        if ($script:DebugMode) {
            Write-Log -message "[$taskName] Full Exception: $_" -color Red -level Debug
            Write-Log -message "[$taskName] Stack trace: $($_.ScriptStackTrace)" -color DarkRed -level Debug
        }

        return "Error: $_"
    }
}

<#
.SYNOPSIS
    Executes multiple collection tasks in parallel using RunspacePool.
.PARAMETER tasks
    An array of PSCustomObjects, each containing 'Key', 'Name' and 'Block'.
.PARAMETER scriptRoot
    The root path of the script for loading libraries.
#>
function Invoke-ParallelCollection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$tasks,
        
        [Parameter(Mandatory = $true)]
        [string]$scriptRoot,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 3600)]
        [int]$taskTimeoutSeconds = 300,

        [Parameter(Mandatory = $false)]
        [ValidateScript({ $_ -eq 0 -or ($_ -ge 1 -and $_ -le 256) })]
        [int]$maxThreadsOverride = 0
    )

    Write-Log -message "[Parallel] Starting parallel collection for $($tasks.Count) modules (Timeout: ${taskTimeoutSeconds}s)..." -color Cyan -level Info
    
    $results = [ordered]@{}
    $powershells = @()
    $runspaceErrorCount = 0

    $newRunspaceErrorResult = {
        param(
            [string]$moduleName,
            [object]$errorRecord,
            [string]$fallbackMessage,
            [int]$elapsedMs
        )

        $errorMessage = $fallbackMessage
        $errorType = "System.Exception"
        $stackTrace = ""

        if ($errorRecord) {
            $errorException = $null
            if ($errorRecord.PSObject.Properties.Name -contains "Exception") {
                $errorException = $errorRecord.Exception
            }

            if ($errorException) {
                if (-not [string]::IsNullOrWhiteSpace($errorException.Message)) {
                    $errorMessage = $errorException.Message
                }
                if ($errorException.GetType()) {
                    $errorType = $errorException.GetType().FullName
                }
                if (-not [string]::IsNullOrWhiteSpace($errorException.StackTrace)) {
                    $stackTrace = $errorException.StackTrace
                }
            }

            if ([string]::IsNullOrWhiteSpace($stackTrace) -and $errorRecord.PSObject.Properties.Name -contains "ScriptStackTrace" -and -not [string]::IsNullOrWhiteSpace($errorRecord.ScriptStackTrace)) {
                $stackTrace = $errorRecord.ScriptStackTrace
            }
        }

        if ([string]::IsNullOrWhiteSpace($errorMessage)) {
            $errorMessage = "Unknown runspace error."
        }

        return [PSCustomObject]@{
            Data           = "Error: $errorMessage"
            StepTimings    = @()
            GeneratedFiles = @()
            Status         = "RunspaceError"
            TimedOut       = $false
            ElapsedMs      = [Math]::Max(0, [int]$elapsedMs)
            ModuleName     = $moduleName
            ErrorMessage   = $errorMessage
            ErrorType      = $errorType
            StackTrace     = $stackTrace
        }
    }
    
    # 1. RunspacePool Setup
    if ($maxThreadsOverride -gt 0) {
        $maxThreads = [math]::Min($tasks.Count, $maxThreadsOverride)
    }
    else {
        $maxThreads = [math]::Min($tasks.Count, [Environment]::ProcessorCount * 2)
    }
    $maxThreads = [math]::Max($maxThreads, 1)
    $runspacePool = [runspacefactory]::CreateRunspacePool(1, $maxThreads)
    $runspacePool.Open()

    try {
        # 2. Launch Tasks
        foreach ($task in $tasks) {
            if ($task.Block -isnot [scriptblock]) {
                $runspaceErrorCount++
                $blockType = if ($null -eq $task.Block) { "null" } else { $task.Block.GetType().FullName }
                $errorMessage = "Invalid task block. Expected ScriptBlock but got '$blockType'."
                $results[$task.Key] = & $newRunspaceErrorResult -moduleName $task.Name -errorRecord $null -fallbackMessage $errorMessage -elapsedMs 0
                Write-Log -message "[Parallel] [RunspaceError] $($task.Name): $errorMessage" -color Red -level Error
                continue
            }

            $ps = [powershell]::Create().AddScript({
                    param($taskName, $collectionBlock, $rootPath, $debugMode, $debugLog)
                
                    # Initialize runspace-local state to avoid leaking or missing data
                    $script:StepTimings = @()
                    $script:generatedFiles = @()
                
                    # Each runspace is a clean environment, must re-load libraries
                    $script:DebugMode = $debugMode
                    $script:DebugLogFile = $debugLog
                    . (Join-Path $rootPath "lib\Common.ps1")
                    . (Join-Path $rootPath "lib\Collectors.ps1")

                    # Execute Invoke-Collection to maintain logging and timing consistency
                    $result = Invoke-Collection -taskName $taskName -collectionBlock $collectionBlock
                    # Return result along with runspace-local state for aggregation
                    return [PSCustomObject]@{
                        Data           = $result
                        StepTimings    = $script:StepTimings
                        GeneratedFiles = $script:generatedFiles
                    }
                }).AddArgument($task.Name).AddArgument($task.Block).AddArgument($scriptRoot).AddArgument($script:DebugMode).AddArgument($script:DebugLogFile)
            
            $ps.RunspacePool = $runspacePool
            $handle = $ps.BeginInvoke()
            
            $powershells += [PSCustomObject]@{
                Name       = $task.Name
                Key        = $task.Key
                Handle     = $handle
                PowerShell = $ps
            }
        }

        # 3. Wait and Collect Results
        foreach ($taskItem in $powershells) {
            try {
                Write-Log -message "[Parallel] Waiting for $($taskItem.Name)..." -color DarkGray -level Debug
                
                # Wait for handle with timeout protection
                $waitCount = 0
                $maxWaitCount = [Math]::Max(1, [int][Math]::Ceiling(($taskTimeoutSeconds * 1000) / 100))
                While (-not $taskItem.Handle.IsCompleted -and $waitCount -lt $maxWaitCount) { 
                    Start-Sleep -Milliseconds 100 
                    $waitCount++
                }
                
                if ($taskItem.Handle.IsCompleted) {
                    $rawResult = $null
                    try {
                        $rawResult = $taskItem.PowerShell.EndInvoke($taskItem.Handle)
                    }
                    catch {
                        $runspaceErrorCount++
                        $results[$taskItem.Key] = & $newRunspaceErrorResult -moduleName $taskItem.Name -errorRecord $_ -fallbackMessage $_.Exception.Message -elapsedMs 0
                        Write-Log -message "[Parallel] [RunspaceError] $($taskItem.Name): $($_.Exception.Message)" -color Red -level Error
                        if ($script:DebugMode -and -not [string]::IsNullOrWhiteSpace($_.ScriptStackTrace)) {
                            Write-Log -message "[Parallel] [RunspaceError] Stack: $($_.ScriptStackTrace)" -color DarkRed -level Debug
                        }
                        continue
                    }

                    $firstResult = if ($rawResult -is [System.Collections.IList] -and $rawResult.Count -gt 0) { $rawResult[0] } else { $null }

                    if ($firstResult -is [PSCustomObject] -and $firstResult.PSObject.Properties.Name -contains "Data") {
                        if ($firstResult.PSObject.Properties.Name -notcontains "Status") {
                            $firstResult | Add-Member -NotePropertyName Status -NotePropertyValue "Completed"
                        }
                        if ($firstResult.PSObject.Properties.Name -notcontains "TimedOut") {
                            $firstResult | Add-Member -NotePropertyName TimedOut -NotePropertyValue $false
                        }
                        if ($firstResult.PSObject.Properties.Name -notcontains "ElapsedMs") {
                            $elapsedMs = 0
                            if ($firstResult.PSObject.Properties.Name -contains "StepTimings" -and $firstResult.StepTimings) {
                                $elapsedMs = ($firstResult.StepTimings | Measure-Object -Property DurationMs -Sum).Sum
                                if ($null -eq $elapsedMs) { $elapsedMs = 0 }
                            }
                            $firstResult | Add-Member -NotePropertyName ElapsedMs -NotePropertyValue ([int]$elapsedMs)
                        }
                        $results[$taskItem.Key] = $firstResult
                    }
                    else {
                        $streamError = $null
                        try {
                            if ($taskItem.PowerShell.Streams.Error.Count -gt 0) {
                                $streamError = $taskItem.PowerShell.Streams.Error[0]
                            }
                        }
                        catch {}

                        if ($streamError) {
                            $runspaceErrorCount++
                            $results[$taskItem.Key] = & $newRunspaceErrorResult -moduleName $taskItem.Name -errorRecord $streamError -fallbackMessage $streamError.Exception.Message -elapsedMs 0
                            Write-Log -message "[Parallel] [RunspaceError] $($taskItem.Name): $($streamError.Exception.Message)" -color Red -level Error
                        }
                        else {
                            $results[$taskItem.Key] = [PSCustomObject]@{
                                Data           = $firstResult
                                StepTimings    = @()
                                GeneratedFiles = @()
                                Status         = "Completed"
                                TimedOut       = $false
                                ElapsedMs      = 0
                            }
                        }
                    }
                    Write-Log -message "[Parallel] $($taskItem.Name) completed successfully." -color DarkGray -level Debug
                }
                else {
                    $results[$taskItem.Key] = [PSCustomObject]@{
                        Data           = "Error: Task timed out after ${taskTimeoutSeconds}s"
                        StepTimings    = @()
                        GeneratedFiles = @()
                        Status         = "TimedOut"
                        TimedOut       = $true
                        ElapsedMs      = ($taskTimeoutSeconds * 1000)
                    }
                    Write-Log -message "[Parallel] $($taskItem.Name) timed out or failed to complete." -color Red -level Error
                    try { $taskItem.PowerShell.Stop() } catch {}
                }
            }
            finally {
                # Explicit disposal for each task to free resources immediately
                try { $taskItem.PowerShell.Dispose() } catch {}
            }
        }
    }
    catch {
        Write-Error "Parallel execution engine encountered a fatal error: $_"
        throw $_
    }
    finally {
        if ($runspacePool) { 
            try { $runspacePool.Close() } catch {}
            try { $runspacePool.Dispose() } catch {}
        }
        # Audit Fix: Explicitly trigger GC to free up memory from closed runspaces
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }

    if ($runspaceErrorCount -gt 0) {
        Write-Log -message "[Parallel] Runspace exceptions captured: $runspaceErrorCount" -color Yellow -level Warning
    }

    Write-Log -message "[Parallel] Parallel collection complete." -color Green -level Info
    return $results
}

<#
.SYNOPSIS
    Automatically finds and opens the document matching the system locale ($PSCulture).
.PARAMETER docName
    The name of the document file (e.g., USAGE_GUIDE.md).
.PARAMETER scriptRoot
    The project root path.
#>
function Open-LocalizedDoc {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$docName,
        
        [Parameter(Mandatory = $true)]
        [string]$scriptRoot
    )

    $currentLocale = $PSCulture # e.g., "ko-KR", "en-US"
    $docPath = Join-Path -Path $scriptRoot -ChildPath "docs\$currentLocale\$docName"

    # 1. Check for system locale folder
    if (Test-Path -Path $docPath) {
        Write-Log -message "Locale-matched document found: $currentLocale" -color Cyan
        Invoke-Item -Path $docPath
        return
    }

    # 2. Fallback: Check for Korean documentation
    $koPath = Join-Path -Path $scriptRoot -ChildPath "docs\ko-KR\$docName"
    if (Test-Path -Path $koPath) {
        Write-Log -message "Falling back to ko-KR document." -color Yellow
        Invoke-Item -Path $koPath
        return
    }

    # 3. Fallback: Check for English documentation
    $enPath = Join-Path -Path $scriptRoot -ChildPath "docs\en-US\$docName"
    if (Test-Path -Path $enPath) {
        Write-Log -message "Falling back to en-US document." -color Yellow
        Invoke-Item -Path $enPath
        return
    }

    Write-Error "Document not found: $docName"
}
# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUvdT40gSMQM5fsnDucJtSuhBc
# PqagggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUoD6e5XtURAo3ivez2/vpxh1sg/4wDQYJ
# KoZIhvcNAQEBBQAEggEALE7Re6VsF7z5a5UXzc40ENpT5uOTKb2XJbgozuOQ3qDu
# zJd1rVlKnSA1uXJw4aDE2gPe0ro+j6uKgGIbgXwbHTCfFaFsEkwxJyx4Zes4Wnxw
# QkqwlqEtRHNXYpm9CP3xeQjZjF1VSN2laCF/idDzzAZ/4gPUZU9jgKKd/ec/aD6x
# r6GVJL5z3fq1mZT52X9MzgU5p3u2nnFXNk7x3Zr0lX0apJLtoWEKLpgV2rykoIeG
# NhHmBLxIxRWXSzmb6eqmWJ0qYJVu9x64mTk969Af3FemB3vGalU+MrCtcx5pEaQ8
# 6d1rWGzQKZytKdEJK2xo9kuZZpIdEr3aMpLAnKKqqQ==
# SIG # End signature block
