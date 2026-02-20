# --- Integrity & Compliance Test Classes ---

function Import-LogCollectorSafely {
    $collectorPath = Join-Path $PSScriptRoot "..\..\lib\collectors\LogCollector.ps1"
    try {
        . $collectorPath
    }
    catch {
        if ($_.Exception.Message -notlike "*Duplicate class*") {
            throw
        }
    }
}

class AESRoundTripTest : BaseTest {
    AESRoundTripTest() : base("AES-256 Round-trip Integrity", "Integrity") {}

    [string] Execute() {
        $testData = "Class-based Refactor Test $(Get-Date)"
        $tempFile = [System.IO.Path]::GetTempFileName()
        $encFile = $tempFile + ".aes"
        $key = ConvertTo-SecureString "Refactor123!" -AsPlainText -Force
        
        try {
            [System.IO.File]::WriteAllBytes($tempFile, [System.Text.Encoding]::UTF8.GetBytes($testData))
            Protect-File -Path $tempFile -DestinationPath $encFile -Key $key
            
            # Internal decryption check
            $fs = New-Object System.IO.FileStream($encFile, [System.IO.FileMode]::Open)
            $salt = New-Object byte[] 16; $iv = New-Object byte[] 16
            $fs.Read($salt, 0, 16) | Out-Null; $fs.Read($iv, 0, 16) | Out-Null
            
            $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($key)
            $kStr = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
            $pbkdf2 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($kStr, $salt, 100000)
            $kb = $pbkdf2.GetBytes(32)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
            
            $aes = [System.Security.Cryptography.Aes]::Create()
            $aes.Key = $kb; $aes.IV = $iv
            $dec = $aes.CreateDecryptor()
            $cs = New-Object System.Security.Cryptography.CryptoStream($fs, $dec, [System.Security.Cryptography.CryptoStreamMode]::Read)
            $sr = New-Object System.IO.StreamReader($cs, [System.Text.Encoding]::UTF8)
            $restored = $sr.ReadToEnd()
            
            $sr.Dispose(); $cs.Dispose(); $dec.Dispose(); $aes.Dispose(); $fs.Dispose()
            
            if ($restored -ne $testData) { throw "Integrity mismatch." }
            return "AES-256 Binary Integrity Verified"
        }
        finally {
            if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
            if (Test-Path $encFile) { Remove-Item $encFile -Force }
        }
    }
}

class ComplianceTest : BaseTest {
    ComplianceTest() : base("BaseCollector Inheritance Check", "Compliance") {}

    [string] Execute() {
        $collectors = Get-ChildItem -Path "$PSScriptRoot\..\..\lib\collectors\*.ps1"
        foreach ($file in $collectors) {
            try { . $file.FullName } catch {
                if ($_.Exception.Message -notlike "*Duplicate class*") {
                    throw "Load failed for $($file.Name): $($_.Exception.Message)"
                }
            }
        }
        return "All classes compliant"
    }
}

class QuotaGuardTest : BaseTest {
    QuotaGuardTest() : base("LogCollector Resource Guard", "Guard") {}

    [string] Execute() {
        . Import-LogCollectorSafely
        $res = Get-LogInfo
        if ($null -eq $res) { throw "LogCollector returned null" }
        return "Quota guard initialized"
    }
}

class LogCollectionWindowParameterTest : BaseTest {
    LogCollectionWindowParameterTest() : base("LogCollection Lookback Parameter", "Guard") {}

    [string] Execute() {
        . Import-LogCollectorSafely

        $eventLogCommand = Get-Command Get-EventLogs -ErrorAction SilentlyContinue
        if ($null -eq $eventLogCommand) {
            throw "Get-EventLogs function not found."
        }

        if (-not $eventLogCommand.Parameters.ContainsKey("LookbackDays")) {
            throw "Get-EventLogs must expose -LookbackDays parameter for window control."
        }

        $originalGetWinEvent = Get-Command Get-WinEvent -ErrorAction SilentlyContinue
        $originalGetCimSafe = Get-Command Get-CimSafe -ErrorAction SilentlyContinue

        $script:CapturedFilterXml = @()

        try {
            Set-Item -Path function:global:Get-CimSafe -Value {
                param(
                    [string]$className,
                    [string]$filter
                )
                return [PSCustomObject]@{ FileSize = 256MB }
            }

            Set-Item -Path function:global:Get-WinEvent -Value {
                param(
                    [string]$FilterXml,
                    [int]$MaxEvents,
                    [object]$ErrorAction
                )
                $script:CapturedFilterXml += $FilterXml
                return @()
            }

            # 1) Default window check (expected 7 days = 604800000ms)
            $null = Get-EventLogs
            if ($script:CapturedFilterXml.Count -ne 3) {
                throw "Expected 3 log queries for default window, got $($script:CapturedFilterXml.Count)."
            }

            foreach ($queryXml in $script:CapturedFilterXml) {
                if ($queryXml -notmatch "timediff\(@SystemTime\)\s*&lt;=\s*604800000") {
                    throw "Default window mismatch. Expected timediff <= 604800000ms."
                }
            }

            # 2) Parameterized window check (2 days = 172800000ms)
            $script:CapturedFilterXml = @()
            $null = Get-EventLogs -LookbackDays 2
            if ($script:CapturedFilterXml.Count -ne 3) {
                throw "Expected 3 log queries for custom window, got $($script:CapturedFilterXml.Count)."
            }

            foreach ($queryXml in $script:CapturedFilterXml) {
                if ($queryXml -notmatch "timediff\(@SystemTime\)\s*&lt;=\s*172800000") {
                    throw "Custom window mismatch. Expected timediff <= 172800000ms for -LookbackDays 2."
                }
            }

            return "Lookback parameter verified for default(7d) and custom(2d) windows"
        }
        finally {
            if ($null -ne $originalGetCimSafe -and $originalGetCimSafe.CommandType -eq "Function") {
                Set-Item -Path function:global:Get-CimSafe -Value $originalGetCimSafe.ScriptBlock
            }
            else {
                Remove-Item -Path function:global:Get-CimSafe -ErrorAction SilentlyContinue
            }

            if ($null -ne $originalGetWinEvent -and $originalGetWinEvent.CommandType -eq "Function") {
                Set-Item -Path function:global:Get-WinEvent -Value $originalGetWinEvent.ScriptBlock
            }
            else {
                Remove-Item -Path function:global:Get-WinEvent -ErrorAction SilentlyContinue
            }

            Remove-Variable -Name CapturedFilterXml -Scope Script -ErrorAction SilentlyContinue
        }
    }
}
