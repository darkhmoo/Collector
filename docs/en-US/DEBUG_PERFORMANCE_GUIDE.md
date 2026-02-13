# 📊 Debug Mode - Step-by-Step Performance Tracking Guide

## Overview
In Debug Mode, the collector provides detailed tracking and visual representation of **execution time**, **memory usage**, and the **number of items collected** for each stage.

---

## 🚀 How to Use

### Standard Execution (Debug Mode OFF)
```powershell
.\system_information_collector_for_windows.ps1
```
**Output**: Displays only basic progress information.

### Execution in Debug Mode
```powershell
.\system_information_collector_for_windows.ps1 -DebugMode
```
**Output**: Detailed performance tracking data + Summary Table.

### Execution in Parallel Mode (-Parallel)
```powershell
.\system_information_collector_for_windows.ps1 -Parallel -DebugMode
```
**Characteristics**:
- Since modules run simultaneously in separate threads, the `TOTAL` time is reduced. However, the sum of individual module durations may exceed the total wall-clock time.
- Log messages may be interleaved (mixed), but the final summary table is accurately aggregated.

---

## 📊 Output Examples

### Real-time Progress Output
```
[Start] Starting System Environment Analysis (PSVer: 5.1.19041.5247)...
[DEBUG] Debug Mode Enabled: Logging to C:\...\debug_log_20251201144958.txt
[DEBUG] Performance tracking enabled

[1/11 Hardware] Starting collection...
[1/11 Hardware] Memory before: 125.45MB
[1/11 Hardware] Executing script block...
[1/11 Hardware] Memory after: 142.78MB (Delta: 17.33MB)
[1/11 Hardware] ✓ Completed in 00:00:03.456 - Type: object, Items: 11

[2/11 Network] Starting collection...
[2/11 Network] Memory before: 142.78MB
[2/11 Network] Executing script block...
[2/11 Network] Memory after: 158.92MB (Delta: 16.14MB)
[2/11 Network] ✓ Completed in 00:00:02.789 - Type: object, Items: 9

... (Continued) ...

[Complete] Data collection finished.
Total Execution Time: 00:00:45.678

╔════════════════════════════════════════════════════════════════╗
║              PERFORMANCE SUMMARY (Debug Mode)                 ║
╠════════════════════════════════════════════════════════════════╣
║ 1/11 Hardware                    3,456ms  7.6% ███
║ 2/11 Network                     2,789ms  6.1% ███
║ 3/11 OS & Config                 4,123ms  9.0% ████
║ 4/11 Virtualization              3,456ms  7.6% ███
║ 5/11 Services                    5,678ms 12.4% ██████
║ 6/11 Performance                 3,234ms  7.1% ███
║ 7/11 Logs                       12,456ms 27.3% █████████████
║ 8/11 Security                    8,901ms 19.5% █████████
║ 9/11 Inventory                   2,500ms  5.5% ██
║ 10/11 ActiveDirectory             2,123ms  4.6% ██
║ 11/11 High Availability           5,041ms 11.0% █████
╠════════════════════════════════════════════════════════════════╣
║ TOTAL                           45,678ms 100.0%
╚════════════════════════════════════════════════════════════════╝

[Memory] Start: 125.45MB, End: 198.34MB, Delta: 72.89MB
```

---

## 📈 Performance Summary Table Explanation

### Column Description
| Column | Description | Example |
|------|------|------|
| **Name** | Name of the collection stage | `1/11 Hardware` |
| **Duration (ms)** | Execution time in milliseconds | `3,456ms` |
| **Percentage** | Ratio compared to total time | `7.6%` |
| **Bar** | Visual progress bar | `███` |

### Color Coding
- **Yellow**: Duration > 20% - Potential bottleneck.
- **White**: Duration 10-20% - Worth monitoring.
- **DarkGray**: Duration < 10% - Healthy.

---

## 🔍 Performance Analysis Methods

### 1. Identifying Bottlenecks
Locate the stage consuming the most time:
```
║ 7/11 Logs                       12,456ms 27.3% █████████████  ← Bottleneck!
```
→ Log collection accounts for 27% of total execution time.

### 2. Memory Usage Analysis
```
[Memory] Start: 125.45MB, End: 198.34MB, Delta: 72.89MB
```
- **Large Delta**: Memory-intensive task.
- **Small Delta**: CPU-intensive task.

### 3. Incremental Memory Tracking
```
[1/11 Hardware] Memory after: 142.78MB (Delta: 17.33MB)
[2/11 Network] Memory after: 158.92MB (Delta: 16.14MB)
```
→ Track how much memory each individual stage consumes.

---

## 📁 Debug Log File

### File Location
```
debug_log_yyyyMMddHHmmss.txt
```

### Log File Content
```
[2025-12-01 14:49:58.123] [Info] [Start] Starting System Environment Analysis...
[2025-12-01 14:49:58.234] [Debug] [DEBUG] Performance tracking enabled
[2025-12-01 14:49:58.345] [Info] [1/11 Hardware] Starting collection...
[2025-12-01 14:49:58.456] [Debug] [1/11 Hardware] Memory before: 125.45MB
[2025-12-01 14:49:58.567] [Debug] [1/11 Hardware] Executing script block...
[2025-12-01 14:50:01.901] [Debug] [1/11 Hardware] Memory after: 142.78MB (Delta: 17.33MB)
[2025-12-01 14:50:01.912] [Info] [1/11 Hardware] ✓ Completed in 00:00:03.456 - Type: object, Items: 11
...
```

### Log Analysis Commands
```powershell
# Extract memory usage only
Get-Content debug_log_*.txt | Select-String "Memory"

# Extract completed stages only
Get-Content debug_log_*.txt | Select-String "✓ Completed"

# Extract errors only
Get-Content debug_log_*.txt | Select-String "Error|✗"

# Sort by execution time
Get-Content debug_log_*.txt | Select-String "Completed" | 
    ForEach-Object { 
        if ($_ -match "(\d+:\d+:\d+\.\d+)") { 
            [PSCustomObject]@{Line=$_; Time=$matches[1]} 
        } 
    } | Sort-Object Time -Descending
```

---

## 🎯 Optimization Guide

### Optimization per Bottleneck

#### If Log Collection is slow (7/11 Logs)
```powershell
# Modify lib/collectors/LogCollector.ps1
# Reduce max event count
-MaxEvents 100  →  -MaxEvents 50

# Shorten collection period
StartTime = (Get-Date).AddDays(-7)  →  AddDays(-3)
```

#### If Service Collection is slow (5/11 Services)
```powershell
# Exclude unnecessary properties
Get-CimInstance Win32_Service | Select-Object Name, State, StartMode
```

#### If Security Collection is slow (8/11 Security)
```powershell
# Limit number of firewall rules
Get-NetFirewallRule | Select-Object -First 100
```

---

## 📊 Performance Benchmarks

### Typical Execution Time (Expected)

| Environment | Total Time | Slowest Stage |
|------|-----------|----------------|
| **Workstation** | 30-45 sec | Logs (8-12 sec) |
| **Server (Base)** | 45-60 sec | Logs (12-18 sec) |
| **Server (Cluster)** | 60-90 sec | HA (15-25 sec) |
| **Large-scale** | 90-120 sec | Services (20-30 sec) |

### Memory Usage (Expected)

| Environment | Start | End | Increase |
|------|------|------|--------|
| **Minimum** | 100 MB | 150 MB | 50 MB |
| **Normal** | 120 MB | 200 MB | 80 MB |
| **Large-scale** | 150 MB | 300 MB | 150 MB |

---

## 🔧 Advanced Usage

### 1. Profiling a Specific Stage
```powershell
# Modify Invoke-Collection in Common.ps1
# Add detailed logging for a specific stage
if ($Name -like "*Logs*") {
    # Additional debugging code
}
```

### 2. Exporting Performance Data to CSV
```powershell
# After running in Debug Mode
$script:StepTimings | Export-Csv "performance_report.csv" -NoTypeInformation
```

### 3. Memory Profiling
```powershell
# Memory snapshots before/after each stage
$script:StepTimings | Select-Object Name, MemoryBefore, MemoryAfter, MemoryDelta |
    Format-Table -AutoSize
```

---

## 🐛 Troubleshooting

### Q: Performance summary is not displayed.
**A**: Ensure you are using the `-DebugMode` switch.
```powershell
.\system_information_collector_for_windows.ps1 -DebugMode
```

### Q: Memory info shows as 0MB.
**A**: Debug mode might not be active, or you may lack sufficient privileges.

### Q: A specific stage is extremely slow.
**A**: 
1. Check detailed logs for that stage in the debug log file.
2. Optimize queries in the corresponding Collector file.
3. Remove collection of unnecessary data.

---

## 📝 Checklist
Items to verify during performance analysis:
- [ ] Is the total execution time within the expected range?
- [ ] Are there any bottlenecks (> 20%)?
- [ ] is memory growth excessive?
- [ ] Are there any failed stages?
- [ ] Are there errors in the debug log?
- [ ] Is the item count for each stage appropriate?

---

## 🎓 Example Scenarios

### Scenario 1: Performance Optimization
1. Run in Debug Mode.
2. Check Performance Summary (e.g., Logs = 30%).
3. Modify `LogCollector.ps1` (Reduce MaxEvents).
4. Re-run and compare (e.g., Logs = 15%).

### Scenario 2: Memory Leak Check
1. Execute multiple times in Debug Mode.
   ```powershell
   for ($i=1; $i -le 3; $i++) {
       .\system_information_collector_for_windows.ps1 -DebugMode
       Start-Sleep -Seconds 5
   }
   ```
2. Compare the memory increase (Delta) for each run.
   - Consistent Delta = Normal.
   - Continuously increasing Delta = Potential leak suspected.

---

## 📅 Feb 14, 2026 Update History

### Core Logic & Security Implementation
- **Class-based Provider Model**: Standardized collection interfaces via `BaseCollector` inheritance and resource management optimization.
- **Plugin Security Engine**: Implemented mandatory **Authenticode Signature** verification for all plugins in `lib/collectors/`.
- **Universal Data Masking (DLP)**: Integrated the `Get-MaskedValue` engine for automatic concealment of sensitive data across all modules.
- **Encryption & Memory Erasure**: Increased PBKDF2 iterations to 100,000 and implemented `ZeroFreeBSTR` for instant erasure of sensitive data in memory.

---

## 📅 Feb 13, 2026 Update History

### Commit: `6b8deb6`
- **Main Script Stability**: Refactored `system_information_collector_for_windows.ps1` for better flow. Guaranteed Mutex release via `try/finally`.
- **Common Utility Improvements**: Improved Mutex generation and added exception handling for debug logging.
- **Security Hardening**: Strengthened temp file management in `SecurityCollector.ps1`.
- **Output Reliability**: Added output directory validation and HTML encoding for character safety in reporters.
- **Verification**: Passed all parser checks and synchronized with `origin/main`.
