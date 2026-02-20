# 📘 Multi-Output Format Usage Guide

## Overview
The System Information Collector can now output results in **JSON**, **HTML**, and **CSV** formats. Event logs can be saved in **HTML** or **CSV** formats separately.

---

## 🎯 Key Features

### 1. Multi-Output Format Support
- **JSON**: Structured data, ideal for API integration.
- **HTML**: Visual report, easy to review directly in a browser.
- **CSV**: Spreadsheet-ready for analysis and data processing.

### 2. ALL Keyword
- Specifying `ALL` automatically generates the report in JSON, HTML, and CSV formats.

### 3. Event Log Format Selection
- **HTML**: Color-coded event logs (categorized by Critical/Error/Warning).
- **CSV**: Allows for filtering and detailed analysis in Excel.

---

## 📝 Usage Examples

### Basic Execution (HTML only)
```powershell
.\system_information_collector_for_windows.ps1
```
**Output**: `result_yyyyMMddHHmmss.html` + Event Log HTML files.

---

### Generate in JSON Format
```powershell
.\system_information_collector_for_windows.ps1 -OutputFormat JSON
```
**Output**: `result_yyyyMMddHHmmss.json`

---

### Generate both HTML and JSON
```powershell
.\system_information_collector_for_windows.ps1 -OutputFormat HTML,JSON
```
**Output**: 
- `result_yyyyMMddHHmmss.html`
- `result_yyyyMMddHHmmss.json`

---

### Run Specific Modules Only (e.g., Hardware, Network)
```powershell
.\system_information_collector_for_windows.ps1 -Modules Hardware,Network
```

### Specify Result Output Path (Auto-creation supported)
```powershell
.\system_information_collector_for_windows.ps1 -OutputPath C:\Diagnostics
```

---

### Generate All Formats (ALL keyword)
```powershell
.\system_information_collector_for_windows.ps1 -OutputFormat ALL
```
**Output**: 
- `result_yyyyMMddHHmmss.json`
- `result_yyyyMMddHHmmss.html`
- `result_yyyyMMddHHmmss.csv` (Summary)
- `result_yyyyMMddHHmmss_Hardware.csv`
- `result_yyyyMMddHHmmss_Network.csv`
- `result_yyyyMMddHHmmss_OSConfig.csv`
- `result_yyyyMMddHHmmss_Services.csv`
- `result_yyyyMMddHHmmss_Performance.csv`
- `result_yyyyMMddHHmmss_Logs.csv`
- `result_yyyyMMddHHmmss_Security.csv`
- `result_yyyyMMddHHmmss_HighAvailability.csv`
- `result_yyyyMMddHHmmss_ActiveDirectory.csv`
- `result_yyyyMMddHHmmss_Virtualization.csv`
- `result_yyyyMMddHHmmss_Inventory.csv`

---

### Generate Event Logs as CSV
```powershell
.\system_information_collector_for_windows.ps1 -EventLogFormat CSV
```
**Output**: Event logs saved as CSV files.
- `Log_System.csv`
- `Log_Application.csv`
- `Log_Security.csv`

---

### Combine All Options
```powershell
.\system_information_collector_for_windows.ps1 -OutputFormat ALL -EventLogFormat CSV -DebugMode
```
**Output**: 
- All output formats (JSON, HTML, CSV).
- Event logs in CSV format.
- Debug log file generated.
- Intermediate files are preserved.

---

## 📊 Output File Structure

### HTML Output
- **Main Report**: `result_yyyyMMddHHmmss.html`
  - All categories displayed in a collapsible format.
  - Color-coding and responsive design.
  
- **Event Logs** (when EventLogFormat=HTML):
  - `Log_System.html` - Categorized by Critical/Error/Warning colors.
  - `Log_Application.html`
  - `Log_Security.html`

### JSON Output
- **Single File**: `result_yyyyMMddHHmmss.json`
  - All system information saved in a hierarchical structure.
  - Supports nested objects up to Depth 5.

### CSV Output
- **Summary File**: `result_yyyyMMddHHmmss.csv`
  - Number of items per category and a list of generated filenames.
  
- **Per-Category Files**: 
  - `result_yyyyMMddHHmmss_Hardware.csv`
  - `result_yyyyMMddHHmmss_Network.csv`
  - etc.
  - Each file saves the flattened data for that specific category.

- **Event Logs** (when EventLogFormat=CSV):
  - `Log_System.csv`
  - `Log_Application.csv`
  - `Log_Security.csv`

- `result_yyyyMMddHHmmss.zip` (Generated when `-Compress` is specified)

### 🔐 Security Encryption (AES-256)
When using the `-Encrypt` option, all result files are encrypted:
- **AES-256 (100,000 PBKDF2 rounds)**: Applies strong key derivation to defend against brute-force attacks.
- `result_yyyyMMddHHmmss.json.aes`
- `result_yyyyMMddHHmmss.html.aes`
- Encrypted files can only be restored using the dedicated utility (`utils/Decrypt-Results.ps1`).

### 🛡️ Script Integrity & Trust (Authenticode)
This tool utilizes digital signatures to prevent the execution of unauthorized scripts:
1. **Plugin Security**: All scripts in the `lib/collectors/` folder must be digitally signed to be loaded.
2. **Establishing Trust**: For first-time use, run `utils/Setup-Security.ps1` to generate a self-signed certificate and register it as a Trusted Publisher.
   ```powershell
   # Run with Admin privileges
   .\utils\Setup-Security.ps1
   ```
3. **Signature Verification**: If a script with an invalid signature is found, a `Security Warning` is issued, and loading is denied.
4. **Signing Policy**:
   - Default: Re-sign only changed `.ps1` files.
   - Bulk re-sign all scripts only for certificate rotation/renewal, large line-ending or encoding changes, and pre-release integrity sweeps.
5. **Verification Command**: Before commit, verify `Get-AuthenticodeSignature` returns `Valid`.
   ```powershell
   Get-ChildItem -Recurse -File -Filter *.ps1 | ForEach-Object {
       $sig = Get-AuthenticodeSignature -FilePath $_.FullName
       [PSCustomObject]@{ Path = $_.FullName; Status = $sig.Status }
   } | Where-Object { $_.Status -ne 'Valid' }
   ```

---

## 🔍 Format Comparison

| Format | Pros | Cons | Recommended Use |
|------|------|-----------|-----------------|
| **HTML** | ✅ Visually appealing<br>✅ Easy to review in browser<br>✅ Color-coded, collapsible sections | ❌ Hard to process automatically<br>❌ Larger file size | Manual review and investigation |
| **JSON** | ✅ Structured data<br>✅ Ideal for API/SIEM integration<br>✅ Simple programmatic processing | ❌ Harder for humans to read<br>❌ Slower with extremely large datasets | Automation and external integration |
| **CSV** | ✅ Opens directly in Excel<br>✅ Easy filtering/sorting<br>✅ Great for data analysis | ❌ Limited hierarchical representation<br>❌ Generates multiple files | Data analysis and comparison |

---

## 💡 Usage Scenarios

### Scenario 1: Routine System Check
```powershell
.\system_information_collector_for_windows.ps1
```
- Only HTML report generated.
- Quickly confirm status in a browser.

### Scenario 2: Problem Analysis and Reporting
```powershell
.\system_information_collector_for_windows.ps1 -OutputFormat HTML,JSON -EventLogFormat CSV
```
- Visual confirmation via HTML.
- Detailed data archival via JSON.
- Excel analysis via CSV event logs.

### Scenario 3: Automation/Monitoring
```powershell
.\system_information_collector_for_windows.ps1 -OutputFormat JSON
```
- Minimal file size with JSON only.
- Automatically processed by scripts or APIs.

### Scenario 4: Fast Collection in Large Environments (Parallel)
```powershell
.\system_information_collector_for_windows.ps1 -Parallel -OutputFormat ALL
```
- Collects all modules simultaneously using `RunspacePool`.
- Drastically reduces total wait time in high-latency or high-count server environments.

### Scenario 5: Audit/Compliance
```powershell
.\system_information_collector_for_windows.ps1 -OutputFormat ALL -DebugMode
```
- Evidence archival in all formats.
- Includes debug logs.
- Preserves intermediate files.

### Scenario 6: Comparative Analysis of Multiple Servers
```powershell
# Run on each server
.\system_information_collector_for_windows.ps1 -OutputFormat CSV

# Collect CSV files and compare in Excel
```

### Scenario 7: Secure Environment (Data Encryption)
```powershell
.\system_information_collector_for_windows.ps1 -Encrypt -Compress
```
- Prompted for a key upon execution (hidden input).
- Encrypted files are stored inside the ZIP archive.

### Scenario 8: In-depth Diagnosis for AD and Virtualization
```powershell
.\system_information_collector_for_windows.ps1 -OutputFormat HTML
```
- **Active Directory**: Verify Domain Controller status, replication partners, and object counts.
- **Hyper-V/Container**: Check host resources, VM status, and container runtime.
*Note: Data is only collected in environments where the relevant modules (RSAT-AD-PowerShell, Hyper-V) are installed.*

---

## ⚙️ Parameter Details

### -OutputFormat
**Type**: `string[]` (Array)  
**Default**: `@("HTML")`  
**Accepted Values**: `JSON`, `HTML`, `CSV`, `ALL`

**Examples**:
```powershell
# Single format
-OutputFormat HTML

# Multiple formats
-OutputFormat HTML,JSON
-OutputFormat JSON,CSV

# All formats
-OutputFormat ALL
```

### -EventLogFormat
**Type**: `string`  
**Default**: `HTML`  
**Accepted Values**: `HTML`, `CSV`

**Examples**:
```powershell
# HTML format (Default)
-EventLogFormat HTML

# CSV format
-EventLogFormat CSV
```

### -DebugMode
**Type**: `Switch`  
**Default**: `$false`

**Effects**:
- Generates a debug log file (`debug_log_yyyyMMddHHmmss.txt`).
- Does not delete intermediate files.
- Detailed execution time logging.

**Example**:
```powershell
-DebugMode
```

### -Modules
**Type**: `string[]` (Array)
**Default**: `ALL`
**Accepted Values**: `Hardware`, `Network`, `OSConfig`, `Inventory`, `Virtualization`, `Services`, `Performance`, `Logs`, `Security`, `ActiveDirectory`, `HighAvailability`, `ALL`

**Effects**:
- Collects data only for the specified modules.
- If `ALL` is included, all modules are collected.

### -Parallel
**Type**: `Switch`  
**Default**: `$false`

**Effects**:
- Enables **Parallel Collection** mode.
- Uses `RunspacePool` to collect multiple modules simultaneously, reducing total execution time.

### -Compress
**Type**: `Switch`  
**Default**: `$false`

**Effects**:
- Archives all generated result files into a single ZIP archive.
- If encryption is enabled, it archives the encrypted (.aes) files.

### -Encrypt
**Type**: `Switch`  
**Default**: `$false`

**Effects**:
- Encrypts individual report files using the **AES-256** algorithm.
- Triggers a secure prompt for the user to input a password.

**Example**:
```powershell
# Run with encryption and compression
-Encrypt -Compress
```

---

## 🚀 Performance Considerations

### File Size
| Format | Estimated Size (Typical Server) |
|------|--------------------------|
| JSON | 5-10 MB |
| HTML | 3-8 MB |
| CSV (Total) | 10-20 MB (Multiple files) |
| ZIP | 1-3 MB (After compression) |

### Execution Time
- **HTML only**: ~30-60 sec
- **JSON only**: ~30-60 sec
- **CSV only**: ~40-70 sec
- **ALL**: ~60-90 sec

*Actual time varies based on system specifications and volume of data.*

---

## 🔧 Troubleshooting

### Q: Too many CSV files are generated.
**A**: CSV generates a file for each category. If you only need a summary, use JSON or HTML.

### Q: The Event Log HTML is too large.
**A**: Use CSV format or reduce the number of events in `LogCollector.ps1` (default is 100).

### Q: Out of disk space when using the ALL option.
**A**: Select only the formats you require. Original files are automatically deleted after ZIP compression.

### Q: I want to exclude a specific format.
**A**: Currently, you can only specify the formats to include. E.g., `-OutputFormat HTML,JSON` (excludes CSV).

---

## 📌 Maintenance Notes

1. **ZIP File**: All generated files are automatically compressed into a ZIP archive.
2. **File Cleanup**: Intermediate files are auto-deleted when run without `-DebugMode`.
3. **Timestamp**: All filenames include the generation time (`yyyyMMddHHmmss`).
4. **Encoding**: All text files are saved in UTF-8 encoding.
5. **Admin Privileges**: Administrator rights are required to collect certain pieces of information.

---

## 🎓 Advanced Usage

### Calling from a PowerShell Script
```powershell
# Capture result as a variable
$result = .\system_information_collector_for_windows.ps1 -OutputFormat JSON

# Parsing JSON file
$jsonData = Get-Content "result_*.json" | ConvertFrom-Json
$jsonData.Hardware.Processor
```

### Registering as a Scheduled Task
```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File C:\Scripts\system_information_collector_for_windows.ps1 -OutputFormat JSON"
$trigger = New-ScheduledTaskTrigger -Daily -At 2am
Register-ScheduledTask -TaskName "SystemInfoCollection" -Action $action -Trigger $trigger
```

### Running on a Remote Server
```powershell
Invoke-Command -ComputerName Server01 -FilePath .\system_information_collector_for_windows.ps1 `
    -ArgumentList @{OutputFormat=@("JSON"); DebugMode=$false}
```

---

## 📞 Support

If you encounter issues or have feature requests, please register an issue!
