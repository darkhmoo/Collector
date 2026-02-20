<#
.SYNOPSIS
    Verifies Authenticode signatures for PowerShell scripts.
.DESCRIPTION
    Fails with non-zero exit code when any .ps1 file has a signature status other than Valid.
    Supports repository-wide scan and staged-only scan for pre-commit enforcement.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TargetPath = (Join-Path $PSScriptRoot ".."),

    [Parameter(Mandatory = $false)]
    [switch]$StagedOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-TargetPowerShellFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,

        [Parameter(Mandatory = $false)]
        [switch]$OnlyStaged
    )

    $resolvedRoot = (Resolve-Path -Path $RootPath).Path

    if ($OnlyStaged) {
        $staged = git -C $resolvedRoot diff --cached --name-only --diff-filter=ACMR 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to enumerate staged files. Ensure this runs inside a git repository."
        }

        $files = @()
        foreach ($relative in $staged) {
            if ($relative -and $relative.ToLower().EndsWith(".ps1")) {
                $fullPath = Join-Path -Path $resolvedRoot -ChildPath $relative
                if (Test-Path -Path $fullPath -PathType Leaf) {
                    $files += (Resolve-Path -Path $fullPath).Path
                }
            }
        }
        return $files | Sort-Object -Unique
    }

    return Get-ChildItem -Path $resolvedRoot -Recurse -File -Filter "*.ps1" |
        Select-Object -ExpandProperty FullName |
        Sort-Object -Unique
}

try {
    $files = @(Get-TargetPowerShellFiles -RootPath $TargetPath -OnlyStaged:$StagedOnly)
}
catch {
    Write-Host "[Signature] Verification setup failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 2
}

if (-not $files -or $files.Count -eq 0) {
    Write-Host "[Signature] No .ps1 files found to verify."
    exit 0
}

$invalid = @()
foreach ($file in $files) {
    $sig = Get-AuthenticodeSignature -FilePath $file
    if ($sig.Status -ne "Valid") {
        $invalid += [PSCustomObject]@{
            Status = [string]$sig.Status
            Path   = $file
        }
    }
}

Write-Host "[Signature] Files scanned: $($files.Count)"

if ($invalid.Count -gt 0) {
    Write-Host "[Signature] INVALID_SIGNATURES: $($invalid.Count)" -ForegroundColor Red
    foreach ($entry in $invalid) {
        Write-Host ("  - {0,-16} {1}" -f $entry.Status, $entry.Path) -ForegroundColor Red
    }
    exit 1
}

Write-Host "[Signature] All signatures are valid." -ForegroundColor Green
exit 0

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUZHxp4wy57Wpw3tLMkKYVfdP9
# oTGgggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU7YU1HpSJFc8dnCREkOW5Z0NNesswDQYJ
# KoZIhvcNAQEBBQAEggEAPMuzzvLot8FXta0wJPI8Bm9+Zj95iJrn6qmZQEJAd34I
# fWz/sEj9Nx5h4UT0q/MXY2jIF5VmTC83GODLlBNLhYHnQZhC+mcmywpY9s1hnhUw
# oohVD3iShf5CLu8cUx3a9BNHWCR1RwZc6UCrU1Cwwhv+j7jyHhhKxpzDF8Wi7RCV
# 8JaugC20QwpwUdyeXuEQZRDmZeg++SLAv75olzGF7GakGY2ANs4ShxgkgK6uS+A7
# 5qYuP3Rf6iCr8SIt49aYA1525Fot2i2A3+9WKLHjI1m7BOMZllw+Gos+BNevfiU4
# 7gPb92l8hE+SVgVputgd42KnBJCXVdrdr5E002Wjqw==
# SIG # End signature block
