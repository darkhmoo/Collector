# 🔄 리팩토링: 단일 책임 원칙(SRP) 적용 및 모듈화

## 📅 적용 일자
2025-12-01

---

## 🎯 목적
코드의 유지보수성과 확장성을 높이기 위해 **단일 책임 원칙(SRP)**을 적용하여 거대해진 `Reporters.ps1`과 메인 스크립트의 출력 로직을 분리합니다.

---

## ✅ 변경 사항

### 1. Reporters 모듈화 (`lib/reporters/`)
기존의 `Reporters.ps1`을 기능별로 세분화하여 별도 모듈로 분리했습니다.

| 모듈명 | 역할 | 주요 함수 |
|--------|------|-----------|
| **HtmlReporter.ps1** | HTML 보고서 생성 | `Get-HtmlTable`, `ConvertTo-HtmlReport` |
| **CsvReporter.ps1** | CSV 보고서 생성 | `ConvertTo-CsvReport` |
| **EventLogReporter.ps1** | 이벤트 로그 보고서 생성 | `Export-EventLogFiles`, `ConvertTo-EventLogHtml` |

`lib/Reporters.ps1`은 이제 이 모듈들을 로드하는 **로더(Loader)** 역할만 수행합니다.

### 2. OutputManager 도입 (`lib/OutputManager.ps1`)
메인 스크립트에 혼재되어 있던 **출력 생성, 파일 저장, 압축, 정리** 로직을 별도 모듈로 분리했습니다.

- **함수**: `Save-Results`
- **역할**:
    - JSON, HTML, CSV 파일 저장
    - 이벤트 로그 파일 내보내기
    - 결과 파일 압축 (ZIP)
    - 임시 파일 정리

### 3. 메인 스크립트 간소화
`system_information_collector_for_windows.ps1`의 코드가 대폭 간소화되었습니다.

```powershell
# 변경 전
# ... 복잡한 if/else 블록으로 각 포맷별 저장 로직 ...
# ... 압축 로직 ...
# ... 정리 로직 ...

# 변경 후
Save-Results `
    -AuditReport $auditReport `
    -OutputFormat $OutputFormat `
    -EventLogFormat $EventLogFormat `
    -OutputDirectory $PSScriptRoot `
    -DebugMode $DebugMode
```

---

## 📊 효과
1. **가독성 향상**: 각 파일이 하나의 명확한 목적을 가지게 되어 코드를 이해하기 쉬워졌습니다.
2. **유지보수 용이성**: 특정 기능(예: HTML 스타일 변경)을 수정할 때 해당 파일만 수정하면 됩니다.
3. **재사용성**: `OutputManager`나 `Reporter` 모듈을 다른 스크립트에서도 쉽게 재사용할 수 있습니다.
4. **테스트 용이성**: 각 모듈을 독립적으로 테스트하기 쉬워졌습니다.

---

**적용 완료일**: 2025-12-01  
**적용자**: Antigravity AI Assistant
