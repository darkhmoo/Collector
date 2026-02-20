# --- Edge Case & Fault Injection Test Classes ---
# Purpose: Simulate enterprise-level edge cases and failures.

# --- 1. Fault Injection Helper ---

class FaultInjectionEngine {
    static [hashtable]$OriginalFunctions = @{}

    static [void] Inject([string]$FunctionName, [scriptblock]$FakeLogic) {
        if (-not [FaultInjectionEngine]::OriginalFunctions.ContainsKey($FunctionName)) {
            $existingGlobalFunction = Get-Item -Path "function:global:$FunctionName" -ErrorAction SilentlyContinue
            [FaultInjectionEngine]::OriginalFunctions[$FunctionName] = [PSCustomObject]@{
                HadGlobalFunction = ($null -ne $existingGlobalFunction)
                GlobalScriptBlock = if ($existingGlobalFunction) {
                    [scriptblock]::Create($existingGlobalFunction.ScriptBlock.ToString())
                }
                else {
                    $null
                }
            }
        }
        # Force override in global scope
        Set-Item -Path "function:global:$FunctionName" -Value $FakeLogic
    }

    static [void] Restore([string]$FunctionName) {
        if ([FaultInjectionEngine]::OriginalFunctions.ContainsKey($FunctionName)) {
            $original = [FaultInjectionEngine]::OriginalFunctions[$FunctionName]
            if ($original.HadGlobalFunction -and $null -ne $original.GlobalScriptBlock) {
                Set-Item -Path "function:global:$FunctionName" -Value $original.GlobalScriptBlock
            }
            else {
                Remove-Item -Path "function:global:$FunctionName" -ErrorAction SilentlyContinue
            }
            [FaultInjectionEngine]::OriginalFunctions.Remove($FunctionName)
        }
    }

    static [void] RestoreAll() {
        $names = @([FaultInjectionEngine]::OriginalFunctions.Keys)
        foreach ($name in $names) {
            $original = [FaultInjectionEngine]::OriginalFunctions[$name]
            if ($original.HadGlobalFunction -and $null -ne $original.GlobalScriptBlock) {
                Set-Item -Path "function:global:$name" -Value $original.GlobalScriptBlock
            }
            else {
                Remove-Item -Path "function:global:$name" -ErrorAction SilentlyContinue
            }
        }
        [FaultInjectionEngine]::OriginalFunctions.Clear()
    }
}

# --- 2. Phase 1 (P0) Test Classes ---

class WmiCorruptionTest : BaseTest {
    WmiCorruptionTest() : base("WMI Repository Corruption Simulation", "EdgeCase-P0") {}

    [string] Execute() {
        # Inject failure into Get-CimInstance
        [FaultInjectionEngine]::Inject("Get-CimInstance", {
                throw [System.Management.ManagementException]::new("WMI Repository is corrupted (HRESULT: 0x80041010)")
            })

        try {
            # This should be caught by Get-CimSafe in Common.ps1
            $res = Get-CimSafe -className "Win32_OperatingSystem"
            if ($null -ne $res) {
                throw "Get-CimSafe failed to return null during WMI corruption."
            }
            return "Get-CimSafe gracefully handled WMI corruption"
        }
        finally {
            [FaultInjectionEngine]::Restore("Get-CimInstance")
        }
    }
}

class TamperedSignatureTest : BaseTest {
    TamperedSignatureTest() : base("Tampered Script Signature Detection", "EdgeCase-P0") {}

    [string] Execute() {
        $tempFile = Join-Path $env:TEMP "tamper_test_$([guid]::NewGuid().ToString().Substring(0,8)).ps1"
        $content = "Write-Host 'Original Content'"
        $content | Out-File $tempFile -Encoding utf8
        
        try {
            # 1. Sign the file
            $cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -like "*Collector*" } | Select-Object -First 1
            if ($null -eq $cert) { throw "Test certificate not found. Run Setup-Security.ps1 first." }
            
            Set-AuthenticodeSignature -FilePath $tempFile -Certificate $cert | Out-Null
            
            # 2. Tamper the file (Append a space)
            Add-Content $tempFile " "
            
            # 3. Verify
            $sig = Get-AuthenticodeSignature -FilePath $tempFile
            if ($sig.Status -eq "Valid") {
                throw "Security failure: Tampered signature was still marked as Valid."
            }
            
            return "Tampered signature correctly detected as $($sig.Status)"
        }
        finally {
            if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
        }
    }
}

class DiskFullSimulationTest : BaseTest {
    DiskFullSimulationTest() : base("Storage Quota/Disk Full Simulation", "EdgeCase-P0") {}

    [string] Execute() {
        # Simulate critically low disk space for the output drive pre-check.
        [FaultInjectionEngine]::Inject("Get-PSDrive", {
                param([string]$Name)
                return [PSCustomObject]@{
                    Name = $Name
                    Free = 1024
                }
            })

        try {
            $dummyReport = [PSCustomObject]@{
                Logs = @{ EventLogs = @{} }
            }

            # Attempt to save results (should fail due to low-space guard).
            try {
                Save-Results `
                    -auditReport $dummyReport `
                    -outputFormat @("JSON") `
                    -eventLogFormat "HTML" `
                    -outputDirectory $env:TEMP `
                    -isDebugMode $false `
                    -zipResults $false `
                    -encryptionKey $null
                throw "Save-Results should have blocked the save due to low disk space."
            }
            catch {
                if ($_.Exception.Message -like "*Insufficient space*") {
                    return "Disk full guard correctly blocked the operation"
                }
                throw "Unexpected error: $($_.Exception.Message)"
            }
        }
        finally {
            [FaultInjectionEngine]::Restore("Get-PSDrive")
        }
    }
}
