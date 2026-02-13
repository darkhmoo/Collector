# 🔄 리팩토링: 이벤트 로그 수집과 보고 분리

## 📅 적용 일자
2025-12-01

---

## 🎯 목적
이벤트 로그의 **수집(Collection)** 로직과 **보고(Reporting)** 로직을 분리하여 코드의 책임 소재를 명확히 하고 유지보수성을 향상시킵니다.

---

## ✅ 변경 사항

### 1. LogCollector.ps1 (수집 담당)
- **제거**: `Export-EventLogs`, `ConvertTo-EventLogHtml`
- **추가**: `Get-EventLogs`
- **변경**: `Get-LogInfo`가 더 이상 파일 형식을 받지 않고, 순수 데이터(Hashtable)만 반환합니다.

```powershell
# 변경 전
EventLogStatus = Export-EventLogs -Format $EventLogFormat

# 변경 후
EventLogs = Get-EventLogs
```

### 2. Reporters.ps1 (보고 담당)
- **이동**: `ConvertTo-EventLogHtml` (LogCollector에서 이동)
- **추가**: `Export-EventLogFiles`
    - 수집된 이벤트 로그 데이터를 받아 HTML 또는 CSV 파일로 저장합니다.

```powershell
function Export-EventLogFiles {
    param($EventLogs, $Format, $OutputDir)
    # ... 파일 생성 로직 ...
}
```

### 3. 메인 스크립트 (흐름 제어)
- **수집 단계**: `Get-LogInfo` 호출 시 파라미터 제거
- **출력 단계**: `Export-EventLogFiles` 명시적 호출

```powershell
# 1. 수집
Logs = Invoke-Collection "6/8 Logs" { Get-LogInfo }

# 2. 출력
if ($auditReport.Logs.EventLogs) {
    Export-EventLogFiles -EventLogs $auditReport.Logs.EventLogs ...
}
```

---

## 📊 효과
1. **단일 책임 원칙(SRP) 준수**: Collector는 수집만, Reporter는 보고만 담당합니다.
2. **유연성 향상**: 수집된 데이터를 나중에 다른 형식으로 출력하거나 가공하기 쉬워졌습니다.
3. **코드 가독성**: 메인 스크립트에서 데이터 흐름(수집 -> 출력)이 더 명확해졌습니다.

---

## ⚠️ 주의 사항
- 메인 JSON 파일에 이벤트 로그 데이터가 포함됩니다. (이전에는 상태 메시지만 포함)
- 대량의 이벤트 로그 수집 시 메모리 사용량이 증가할 수 있으므로 `-MaxEvents` 제한을 유지해야 합니다.

---

**적용 완료일**: 2025-12-01  
**적용자**: Antigravity AI Assistant
