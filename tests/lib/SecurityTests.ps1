# --- Security Test Classes ---

class AuthenticodeTest : BaseTest {
    AuthenticodeTest() : base("Authenticode Signature Verification", "Security") {}

    [string] Execute() {
        $collectors = Get-ChildItem -Path "$PSScriptRoot\..\..\lib\collectors\*.ps1"
        foreach ($file in $collectors) {
            $sig = Get-AuthenticodeSignature -FilePath $file.FullName
            if ($sig.Status -ne "Valid") {
                throw "Signature invalid for $($file.Name): $($sig.Status)"
            }
        }
        return "$($collectors.Count) modules verified"
    }
}

class DLPMaskingTest : BaseTest {
    DLPMaskingTest() : base("DLP Sensitive Data Masking", "Security") {}

    [string] Execute() {
        $testMap = @{
            "my password is 123"  = $true
            "API_SECRET_KEY: abc" = $true
            "Normal system log"   = $false
        }
        foreach ($key in $testMap.Keys) {
            $masked = Get-MaskedValue -inputString $key
            if ($testMap[$key] -and $masked -notlike "*Masked*") { throw "Failed to mask: $key" }
            if (-not $testMap[$key] -and $masked -ne $key) { throw "Incorrectly masked: $key" }
        }
        return "DLP logic verified"
    }
}
