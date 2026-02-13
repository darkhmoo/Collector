# 🔒 보안 및 성능 검토 보고서

## 📅 검토 일자
2025-12-01

---

## 🔐 보안 검토

### 1. 파일 시스템 접근

#### ⚠️ 발견된 이슈
| 위치 | 이슈 | 심각도 | 권장 조치 |
|------|------|--------|-----------|
| `LogCollector.ps1` | 하드코딩된 경로 사용 (`C:\Windows\...`) | 중간 | 경로 존재 여부 검증 강화 |
| `SecurityCollector.ps1` | `$env:TEMP` 사용 시 정리 누락 가능 | 낮음 | Try-Finally로 임시 파일 정리 보장 |
| `HACollector.ps1` | 클러스터 로그 파일 경로 검증 부족 | 중간 | 경로 검증 추가 |

#### ✅ 권장 사항
```powershell
# Before
$pendingPath = 'C:\Windows\SoftwareDistribution\ReportingEvents\Pending.xml'
if (Test-Path $pendingPath) { ... }

# After (보안 강화)
$pendingPath = Join-Path $env:SystemRoot 'SoftwareDistribution\ReportingEvents\Pending.xml'
if ((Test-Path $pendingPath) -and (Test-Path $pendingPath -PathType Leaf)) {
    try {
        $content = Get-Content $pendingPath -Raw -ErrorAction Stop
    }
    catch {
        Write-Log "Failed to read $pendingPath : $_" -Color Red
    }
}
```

---

### 2. 명령 실행

#### ⚠️ 발견된 이슈
| 위치 | 이슈 | 심각도 | 권장 조치 |
|------|------|--------|-----------|
| `OSCollector.ps1` | `w32tm` 외부 명령 실행 | 낮음 | 출력 검증 추가 |
| `SecurityCollector.ps1` | `secedit` 실행 후 파일 정리 | 중간 | Try-Finally 사용 |

#### ✅ 권장 사항
```powershell
# secedit 보안 강화
$secPolPath = Join-Path $env:TEMP "secpol_$(Get-Random).cfg"
try {
    secedit /export /cfg $secPolPath | Out-Null
    if (Test-Path $secPolPath) {
        $content = Get-Content $secPolPath -ErrorAction Stop
        return $content
    }
}
catch {
    Write-Log "Policy export failed: $_" -Color Red
}
finally {
    if (Test-Path $secPolPath) {
        Remove-Item $secPolPath -Force -ErrorAction SilentlyContinue
    }
}
```

---

### 3. 데이터 노출

#### ⚠️ 발견된 이슈
| 위치 | 이슈 | 심각도 | 권장 조치 |
|------|------|--------|-----------|
| `SecurityCollector.ps1` | 계정 정보 수집 | 높음 | 민감 정보 마스킹 옵션 추가 |
| `LogCollector.ps1` | 이벤트 로그에 민감 정보 포함 가능 | 중간 | 필터링 옵션 제공 |
| 전체 | ZIP 파일 암호화 없음 | 높음 | 암호화 옵션 추가 권장 |

#### ✅ 권장 사항
```powershell
# 민감 정보 마스킹 옵션 추가
param(
    [Switch]$MaskSensitiveData
)

if ($MaskSensitiveData) {
    # 계정 이름, 비밀번호 등 마스킹
    $accounts = $accounts | ForEach-Object {
        $_.Name = $_.Name -replace '(.{2}).*(.{2})', '$1***$2'
        $_
    }
}
```

---

### 4. 권한 관리

#### ✅ 양호한 부분
- `Assert-AdminPrivileges`로 관리자 권한 검증
- 권한 부족 시 명확한 에러 메시지

#### ⚠️ 개선 사항
- 특정 작업만 관리자 권한 필요 → 부분적 실행 허용 고려

---

## ⚡ 성능 병목 지점

### 1. 이벤트 로그 수집 (LogCollector.ps1)

#### 🔴 병목 지점
```powershell
Get-WinEvent -FilterHashtable @{
    LogName = $logName; 
    Level = 1, 2, 3; 
    StartTime = (Get-Date).AddDays(-7)
} -ErrorAction SilentlyContinue | Select-Object -First 100 *
```

**문제점**:
- 7일치 이벤트 전체를 쿼리 후 100개만 선택
- `Select-Object -First 100 *`는 모든 속성을 가져옴

**개선안**:
```powershell
Get-WinEvent -FilterHashtable @{
    LogName = $logName; 
    Level = 1, 2, 3; 
    StartTime = (Get-Date).AddDays(-7)
} -MaxEvents 100 -ErrorAction SilentlyContinue | 
Select-Object TimeCreated, Level, Id, ProviderName, Message
```

**예상 성능 향상**: 30-50%

---

### 2. WMI/CIM 쿼리 (모든 Collector)

#### 🟡 병목 지점
```powershell
Get-CimInstance Win32_PerfFormattedData_PerfProc_Process | 
Sort-Object -Property PercentProcessorTime -Descending | 
Select-Object -First 20
```

**문제점**:
- 모든 프로세스 정보를 가져온 후 정렬
- 불필요한 속성까지 모두 로드

**개선안**:
```powershell
Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -Property Name, PercentProcessorTime, WorkingSet |
Sort-Object -Property PercentProcessorTime -Descending |
Select-Object -First 20
```

**예상 성능 향상**: 20-30%

---

### 3. CSV 생성 (Reporters.ps1)

#### 🟡 병목 지점
```powershell
foreach ($cat in $categories) {
    # 카테고리별로 개별 CSV 파일 생성
    $flattenedData | Export-Csv -Path $catFilePath
}
```

**문제점**:
- 여러 번의 파일 I/O
- 대량 데이터 시 메모리 사용량 증가

**개선안**:
```powershell
# 병렬 처리 (PowerShell 7+)
$categories | ForEach-Object -Parallel {
    # CSV 생성 로직
} -ThrottleLimit 4

# 또는 스트리밍 방식
$streamWriter = [System.IO.StreamWriter]::new($catFilePath)
try {
    foreach ($item in $flattenedData) {
        $streamWriter.WriteLine($item)
    }
}
finally {
    $streamWriter.Dispose()
}
```

**예상 성능 향상**: 15-25%

---

### 4. HTML 생성 (Reporters.ps1)

#### 🟢 양호
- 문자열 연결 방식 사용
- 재귀 깊이 제한

#### 💡 추가 최적화 가능
```powershell
# StringBuilder 사용으로 메모리 효율 향상
$sb = [System.Text.StringBuilder]::new()
[void]$sb.Append("<html>...")
$html = $sb.ToString()
```

---

### 5. 압축 (메인 스크립트)

#### 🟡 병목 지점
```powershell
Compress-Archive -Path $generatedFiles -DestinationPath $zipFilePath -Force
```

**문제점**:
- 대용량 파일 압축 시 시간 소요
- 압축 레벨 지정 불가 (기본: Optimal)

**개선안**:
```powershell
# 압축 레벨 조정 (PowerShell 7+)
Compress-Archive -Path $generatedFiles -DestinationPath $zipFilePath `
    -CompressionLevel Fastest -Force

# 또는 .NET API 직접 사용
[System.IO.Compression.ZipFile]::CreateFromDirectory(
    $sourceDir, $zipFilePath, 
    [System.IO.Compression.CompressionLevel]::Fastest, 
    $false
)
```

**예상 성능 향상**: 40-60% (압축률은 약간 감소)

---

## 📊 성능 측정 결과 (예상)

| 작업 | 현재 | 최적화 후 | 개선율 |
|------|------|-----------|--------|
| 이벤트 로그 수집 | ~15초 | ~8초 | 47% |
| WMI/CIM 쿼리 | ~20초 | ~14초 | 30% |
| CSV 생성 | ~10초 | ~7초 | 30% |
| HTML 생성 | ~5초 | ~4초 | 20% |
| 압축 | ~8초 | ~3초 | 63% |
| **전체** | **~60초** | **~40초** | **33%** |

---

## 🐛 디버그 로깅 강화

### 현재 상태
- `Write-Log` 함수로 기본 로깅
- `Invoke-Collection`에서 실행 시간 측정

### 개선 사항

#### 1. 상세 로깅 레벨 추가
```powershell
enum LogLevel {
    Debug = 0
    Info = 1
    Warning = 2
    Error = 3
}

function Write-Log {
    param(
        [string]$Message,
        [LogLevel]$Level = [LogLevel]::Info,
        [ConsoleColor]$Color = "White"
    )
    
    if ($Script:DebugMode -or $Level -ge [LogLevel]::Info) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $levelText = $Level.ToString().ToUpper()
        $logMessage = "[$timestamp] [$levelText] $Message"
        
        Write-Host $logMessage -ForegroundColor $Color
        
        if ($Script:DebugLogFile) {
            Add-Content -Path $Script:DebugLogFile -Value $logMessage -Encoding UTF8
        }
    }
}
```

#### 2. 단계별 로깅
```powershell
function Invoke-Collection {
    param(
        [string]$Name,
        [scriptblock]$ScriptBlock
    )
    
    Write-Log "[$Name] Starting collection..." -Level Debug -Color Cyan
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        Write-Log "[$Name] Executing script block..." -Level Debug -Color DarkGray
        $result = & $ScriptBlock
        $sw.Stop()
        
        $itemCount = if ($result -is [Array]) { $result.Count } 
                     elseif ($result -is [PSCustomObject]) { 
                         ($result | Get-Member -MemberType NoteProperty).Count 
                     } else { 1 }
        
        Write-Log "[$Name] Completed in $($sw.Elapsed.ToString('hh\:mm\:ss\.fff')) - Collected $itemCount items" `
            -Level Info -Color Green
        
        return $result
    }
    catch {
        $sw.Stop()
        Write-Log "[$Name] Failed after $($sw.Elapsed.ToString('hh\:mm\:ss\.fff')): $_" `
            -Level Error -Color Red
        Write-Log "[$Name] Stack trace: $($_.ScriptStackTrace)" -Level Debug -Color DarkRed
        return "Error: $_"
    }
}
```

#### 3. 메모리 사용량 추적
```powershell
function Get-MemoryUsage {
    $process = Get-Process -Id $PID
    return [PSCustomObject]@{
        WorkingSet = [math]::Round($process.WorkingSet64 / 1MB, 2)
        PrivateMemory = [math]::Round($process.PrivateMemorySize64 / 1MB, 2)
    }
}

# 각 단계 전후로 메모리 측정
$memBefore = Get-MemoryUsage
# ... 작업 수행 ...
$memAfter = Get-MemoryUsage
Write-Log "Memory usage: Before=$($memBefore.WorkingSet)MB, After=$($memAfter.WorkingSet)MB, Delta=$([math]::Round($memAfter.WorkingSet - $memBefore.WorkingSet, 2))MB" `
    -Level Debug -Color Magenta
```

---

## 🔧 권장 개선 사항 우선순위

### 🔴 높음 (즉시 적용 권장)
1. ✅ 이벤트 로그 쿼리 최적화 (`-MaxEvents` 사용)
2. ✅ 민감 정보 보호 (ZIP 암호화 옵션)
3. ✅ Try-Finally로 임시 파일 정리 보장
4. ✅ 디버그 로깅 강화

### 🟡 중간 (다음 버전에서 적용)
5. WMI/CIM 쿼리 속성 제한
6. CSV 생성 병렬 처리
7. 압축 레벨 조정 옵션
8. 메모리 사용량 추적

### 🟢 낮음 (장기 계획)
9. StringBuilder 사용
10. 민감 정보 마스킹 옵션
11. 부분적 관리자 권한 실행

---

## 📝 다음 단계

1. **보안 강화 패치 적용**
   - 임시 파일 정리 보장
   - 경로 검증 강화
   - ZIP 암호화 옵션 추가

2. **성능 최적화**
   - 이벤트 로그 쿼리 개선
   - WMI 쿼리 최적화
   - 압축 옵션 추가

3. **디버그 기능 강화**
   - 로깅 레벨 추가
   - 메모리 추적
   - 상세한 오류 정보

4. **테스트**
   - 성능 벤치마크
   - 보안 스캔
   - 메모리 누수 검사

---

## 📊 체크리스트

- [ ] 보안 이슈 수정
- [ ] 성능 병목 해결
- [ ] 디버그 로깅 강화
- [ ] 단위 테스트 작성
- [ ] 문서 업데이트
- [ ] 코드 리뷰

---

생성일: 2025-12-01  
검토자: Antigravity AI Assistant
