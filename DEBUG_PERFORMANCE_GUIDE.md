# 📊 디버그 모드 - 단계별 성능 추적 가이드

## 개요
디버그 모드에서는 각 수집 단계의 **실행 시간**, **메모리 사용량**, **수집 항목 수**를 상세히 추적하고 시각적으로 표시합니다.

---

## 🚀 사용 방법

### 기본 실행 (디버그 모드 OFF)
```powershell
.\system_information_collector_for_windows.ps1
```
**출력**: 기본 진행 상황만 표시

### 디버그 모드 실행
```powershell
.\system_information_collector_for_windows.ps1 -DebugMode
```
**출력**: 상세한 성능 추적 정보 + 요약 테이블

---

## 📊 출력 예시

### 실행 중 출력
```
[Start] Starting System Environment Analysis (PSVer: 5.1.19041.5247)...
[DEBUG] Debug Mode Enabled: Logging to C:\...\debug_log_20251201144958.txt
[DEBUG] Performance tracking enabled

[1/8 Hardware] Starting collection...
[1/8 Hardware] Memory before: 125.45MB
[1/8 Hardware] Executing script block...
[1/8 Hardware] Memory after: 142.78MB (Delta: 17.33MB)
[1/8 Hardware] ✓ Completed in 00:00:03.456 - Type: object, Items: 11

[2/8 Network] Starting collection...
[2/8 Network] Memory before: 142.78MB
[2/8 Network] Executing script block...
[2/8 Network] Memory after: 158.92MB (Delta: 16.14MB)
[2/8 Network] ✓ Completed in 00:00:02.789 - Type: object, Items: 9

... (계속) ...

[Complete] Data collection finished.
Total Execution Time: 00:00:45.678

╔════════════════════════════════════════════════════════════════╗
║              PERFORMANCE SUMMARY (Debug Mode)                 ║
╠════════════════════════════════════════════════════════════════╣
║ 1/8 Hardware                     3,456ms  7.6% ███
║ 2/8 Network                      2,789ms  6.1% ███
║ 3/8 OS & Config                  4,123ms  9.0% ████
║ 4/8 Services                     5,678ms 12.4% ██████
║ 5/8 Performance                  3,234ms  7.1% ███
║ 6/8 Logs                        12,456ms 27.3% █████████████
║ 7/8 Security                     8,901ms 19.5% █████████
║ 8/8 High Availability            5,041ms 11.0% █████
╠════════════════════════════════════════════════════════════════╣
║ TOTAL                           45,678ms 100.0%
╚════════════════════════════════════════════════════════════════╝

[Memory] Start: 125.45MB, End: 198.34MB, Delta: 72.89MB
```

---

## 📈 성능 요약 테이블 설명

### 컬럼 설명
| 컬럼 | 설명 | 예시 |
|------|------|------|
| **Name** | 수집 단계 이름 | `1/8 Hardware` |
| **Duration (ms)** | 실행 시간 (밀리초) | `3,456ms` |
| **Percentage** | 전체 시간 대비 비율 | `7.6%` |
| **Bar** | 시각적 막대 그래프 | `███` |

### 색상 코딩
- **노란색** (Yellow): 20% 이상 소요 - 병목 지점
- **흰색** (White): 10-20% 소요 - 주의 필요
- **회색** (DarkGray): 10% 미만 - 정상

---

## 🔍 성능 분석 방법

### 1. 병목 지점 식별
가장 많은 시간을 소요하는 단계를 확인:
```
║ 6/8 Logs                        12,456ms 27.3% █████████████  ← 병목!
```
→ 로그 수집이 전체 시간의 27%를 차지

### 2. 메모리 사용량 분석
```
[Memory] Start: 125.45MB, End: 198.34MB, Delta: 72.89MB
```
- **Delta가 크면**: 메모리 집약적 작업
- **Delta가 작으면**: CPU 집약적 작업

### 3. 단계별 메모리 증가 확인
```
[1/8 Hardware] Memory after: 142.78MB (Delta: 17.33MB)
[2/8 Network] Memory after: 158.92MB (Delta: 16.14MB)
```
→ 각 단계에서 얼마나 메모리를 사용하는지 추적

---

## 📁 디버그 로그 파일

### 파일 위치
```
debug_log_yyyyMMddHHmmss.txt
```

### 로그 파일 내용
```
[2025-12-01 14:49:58.123] [Info] [Start] Starting System Environment Analysis...
[2025-12-01 14:49:58.234] [Debug] [DEBUG] Performance tracking enabled
[2025-12-01 14:49:58.345] [Info] [1/8 Hardware] Starting collection...
[2025-12-01 14:49:58.456] [Debug] [1/8 Hardware] Memory before: 125.45MB
[2025-12-01 14:49:58.567] [Debug] [1/8 Hardware] Executing script block...
[2025-12-01 14:50:01.901] [Debug] [1/8 Hardware] Memory after: 142.78MB (Delta: 17.33MB)
[2025-12-01 14:50:01.912] [Info] [1/8 Hardware] ✓ Completed in 00:00:03.456 - Type: object, Items: 11
...
```

### 로그 분석 명령어
```powershell
# 메모리 사용량만 추출
Get-Content debug_log_*.txt | Select-String "Memory"

# 완료된 단계만 추출
Get-Content debug_log_*.txt | Select-String "✓ Completed"

# 오류만 추출
Get-Content debug_log_*.txt | Select-String "Error|✗"

# 실행 시간 순으로 정렬
Get-Content debug_log_*.txt | Select-String "Completed" | 
    ForEach-Object { 
        if ($_ -match "(\d+:\d+:\d+\.\d+)") { 
            [PSCustomObject]@{Line=$_; Time=$matches[1]} 
        } 
    } | Sort-Object Time -Descending
```

---

## 🎯 최적화 가이드

### 병목 지점별 최적화 방법

#### 로그 수집이 느린 경우 (6/8 Logs)
```powershell
# lib/collectors/LogCollector.ps1 수정
# 이벤트 수 줄이기
-MaxEvents 100  →  -MaxEvents 50

# 수집 기간 줄이기
StartTime = (Get-Date).AddDays(-7)  →  AddDays(-3)
```

#### 서비스 수집이 느린 경우 (4/8 Services)
```powershell
# 불필요한 속성 제외
Get-CimInstance Win32_Service | Select-Object Name, State, StartMode
```

#### 보안 정보 수집이 느린 경우 (7/8 Security)
```powershell
# 방화벽 규칙 수 제한
Get-NetFirewallRule | Select-Object -First 100
```

---

## 📊 성능 벤치마크

### 일반적인 실행 시간 (예상)

| 환경 | 전체 시간 | 가장 느린 단계 |
|------|-----------|----------------|
| **워크스테이션** | 30-45초 | Logs (8-12초) |
| **서버 (기본)** | 45-60초 | Logs (12-18초) |
| **서버 (클러스터)** | 60-90초 | HA (15-25초) |
| **대규모 환경** | 90-120초 | Services (20-30초) |

### 메모리 사용량 (예상)

| 환경 | 시작 | 종료 | 증가량 |
|------|------|------|--------|
| **최소** | 100MB | 150MB | 50MB |
| **일반** | 120MB | 200MB | 80MB |
| **대규모** | 150MB | 300MB | 150MB |

---

## 🔧 고급 사용법

### 1. 특정 단계만 프로파일링
```powershell
# Common.ps1의 Invoke-Collection 수정
# 특정 단계에서만 상세 로깅
if ($Name -like "*Logs*") {
    # 추가 디버깅 코드
}
```

### 2. 성능 데이터 CSV로 내보내기
```powershell
# 디버그 모드 실행 후
$script:StepTimings | Export-Csv "performance_report.csv" -NoTypeInformation
```

### 3. 메모리 프로파일링
```powershell
# 각 단계 전후 메모리 스냅샷
$script:StepTimings | Select-Object Name, MemoryBefore, MemoryAfter, MemoryDelta |
    Format-Table -AutoSize
```

---

## 🐛 문제 해결

### Q: 성능 요약이 표시되지 않습니다
**A**: `-DebugMode` 스위치를 사용했는지 확인하세요.
```powershell
.\system_information_collector_for_windows.ps1 -DebugMode
```

### Q: 메모리 정보가 0MB로 표시됩니다
**A**: 디버그 모드가 활성화되지 않았거나, 권한이 부족할 수 있습니다.

### Q: 특정 단계가 매우 느립니다
**A**: 
1. 디버그 로그에서 해당 단계의 세부 로그 확인
2. 해당 Collector 파일에서 쿼리 최적화
3. 불필요한 데이터 수집 제거

### Q: 디버그 로그 파일이 너무 큽니다
**A**: 로그 레벨을 조정하거나, 특정 단계만 로깅하도록 수정

---

## 📝 체크리스트

성능 분석 시 확인할 사항:

- [ ] 전체 실행 시간이 예상 범위 내인가?
- [ ] 병목 지점(20% 이상)이 있는가?
- [ ] 메모리 증가량이 과도하지 않은가?
- [ ] 실패한 단계가 있는가?
- [ ] 디버그 로그에 오류가 있는가?
- [ ] 각 단계의 수집 항목 수가 적절한가?

---

## 🎓 예제 시나리오

### 시나리오 1: 성능 최적화
```powershell
# 1. 디버그 모드로 실행
.\system_information_collector_for_windows.ps1 -DebugMode

# 2. 성능 요약 확인
# → Logs가 30% 이상 차지

# 3. LogCollector.ps1 수정
# → MaxEvents를 100에서 50으로 줄임

# 4. 재실행 및 비교
.\system_information_collector_for_windows.ps1 -DebugMode
# → Logs가 15%로 감소
```

### 시나리오 2: 메모리 누수 확인
```powershell
# 1. 디버그 모드로 여러 번 실행
for ($i=1; $i -le 3; $i++) {
    .\system_information_collector_for_windows.ps1 -DebugMode
    Start-Sleep -Seconds 5
}

# 2. 각 실행의 메모리 증가량 비교
# → 일정하면 정상, 계속 증가하면 누수 의심
```

---

**작성일**: 2025-12-01  
**버전**: 1.0  
**작성자**: Antigravity AI Assistant
