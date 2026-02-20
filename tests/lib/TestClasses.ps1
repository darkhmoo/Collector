# --- Test Framework Core Classes ---
# Purpose: Provide object-oriented foundation for integrity testing.

class TestResult {
    [string]$Group
    [string]$TestName
    [string]$Status
    [long]$DurationMs
    [string]$Details

    TestResult([string]$group, [string]$name, [string]$status, [long]$ms, [string]$details) {
        $this.Group = $group
        $this.TestName = $name
        $this.Status = $status
        $this.DurationMs = $ms
        $this.Details = $details
    }
}

class BaseTest {
    [string]$Name
    [string]$Group

    BaseTest([string]$name, [string]$group) {
        $this.Name = $name
        $this.Group = $group
    }

    # Virtual-like method to be overridden
    [string] Execute() {
        throw "Execute() method must be implemented by derived class: $($this.GetType().Name)"
    }

    [TestResult] Run() {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $details = $this.Execute()
            $sw.Stop()
            return [TestResult]::new($this.Group, $this.Name, "Passed", $sw.ElapsedMilliseconds, $details)
        }
        catch {
            $sw.Stop()
            return [TestResult]::new($this.Group, $this.Name, "Failed", $sw.ElapsedMilliseconds, $_.Exception.Message)
        }
    }
}

class TestRunner {
    [BaseTest[]]$Tests = @()
    [TestResult[]]$Results = @()
    [datetime]$StartTime

    TestRunner() {
        $this.StartTime = Get-Date
    }

    [void] AddTest([BaseTest]$test) {
        $this.Tests += $test
    }

    [void] RunAll() {
        foreach ($test in $this.Tests) {
            Write-Host "[TEST] [$($test.Group)] $($test.Name) " -NoNewline
            $res = $test.Run()
            if ($res.Status -eq "Passed") {
                Write-Host "PASSED" -ForegroundColor Green -NoNewline
                Write-Host " ($($res.DurationMs)ms)" -ForegroundColor Gray
            }
            else {
                Write-Host "FAILED" -ForegroundColor Red
                Write-Host "       Reason: $($res.Details)" -ForegroundColor DarkRed
            }
            $this.Results += $res
        }
    }

    [void] ShowSummary() {
        $endTime = Get-Date
        $totalDuration = [math]::Round(($endTime - $this.StartTime).TotalSeconds, 2)
        $passed = ($this.Results | Where-Object { $_.Status -eq "Passed" }).Count
        $failed = ($this.Results | Where-Object { $_.Status -eq "Failed" }).Count
        $total = $this.Results.Count
        $passRate = if ($total -gt 0) { [math]::Round(($passed / $total) * 100, 1) } else { 0 }

        Write-Host "`n" + ("=" * 75) -ForegroundColor Cyan
        Write-Host "  TEST RESULTS SUMMARY (Class-based Engine)" -ForegroundColor White -Bold
        Write-Host ("=" * 75) + "`n" -ForegroundColor Cyan

        $this.Results | Select-Object Group, TestName, Status, @{N = "MS"; E = { $_.DurationMs } }, Details | Format-Table -AutoSize
        
        $summaryColor = if ($failed -gt 0) { "Red" } else { "Green" }
        Write-Host ("-" * 75)
        Write-Host "  Suite Summary:" -Bold
        Write-Host "  Total Tests : $total"
        Write-Host "  Passed      : $passed" -ForegroundColor Green
        Write-Host "  Failed      : $failed" -ForegroundColor $summaryColor
        Write-Host "  Pass Rate   : $passRate%" -ForegroundColor $summaryColor
        Write-Host "  Duration    : ${totalDuration}s"
        Write-Host ("=" * 75) + "`n"
    }
}

# SIG # Begin signature block
# MIIFiwYJKoZIhvcNAQcCoIIFfDCCBXgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUOoxI5bzLlhuR7vUP7XtUAdOv
# E/SgggMcMIIDGDCCAgCgAwIBAgIQGWEUqQpfT6JPYbwYRk6SXjANBgkqhkiG9w0B
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUNI2UYCPFVXJ4WELT/pSENGbFoNcwDQYJ
# KoZIhvcNAQEBBQAEggEAVoiozx2YlIqs5GkTW+7Db8GqT+zkp2GIXcPWL+/roog7
# iYbSapuPeM/ISvzJym5wX8IZYqljd1k8D8hNMx7i5XbA/Vb5YOS77XcDg0BkaXi1
# 6o7+GDKFq4rU3HECCdinezUYvOSNCwQLEZU+6Xx4V3Y5sAuWzZBT8Pf40erWACLk
# FDQk82/nZPRoAJAcox3SyJW62hU7TiDOKMqGNGCr9xQYTIrjiGgZzdySGZd6P+uc
# /kkw0dHScmNqSqQG0PV8EG6GDlxQ1VL/AdubCztokGZrinVWB1RIc+us6+pwn1ii
# uKirCgiNpnT8IUpWd/EkV4///i9Cgyes50pGD1AxyQ==
# SIG # End signature block
