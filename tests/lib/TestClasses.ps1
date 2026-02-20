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
