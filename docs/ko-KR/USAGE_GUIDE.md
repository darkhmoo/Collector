# 📘 다중 출력 형식 사용 가이드

## 개요
시스템 정보 수집 스크립트는 이제 **JSON**, **HTML**, **CSV** 형식으로 결과를 출력할 수 있으며, 이벤트 로그는 **HTML** 또는 **CSV** 형식으로 별도 저장할 수 있습니다.

---

## 🎯 주요 기능

### 1. 다중 출력 형식 지원
- **JSON**: 구조화된 데이터, API 연동에 적합
- **HTML**: 시각적 보고서, 브라우저에서 바로 확인
- **CSV**: 엑셀 분석, 데이터 처리에 적합

### 2. ALL 키워드
- `ALL` 지정 시 JSON, HTML, CSV 모든 형식으로 자동 생성

### 3. 이벤트 로그 형식 선택
- **HTML**: 색상 코딩된 이벤트 로그 (Critical/Error/Warning 구분)
- **CSV**: 엑셀에서 필터링 및 분석 가능

---

## 📝 사용 예제

### 기본 사용 (HTML만 생성)
```powershell
.\system_information_collector_for_windows.ps1
```
**결과**: `result_yyyyMMddHHmmss.html` + 이벤트 로그 HTML 파일들

---

### JSON 형식으로 생성
```powershell
.\system_information_collector_for_windows.ps1 -OutputFormat JSON
```
**결과**: `result_yyyyMMddHHmmss.json`

---

### HTML과 JSON 동시 생성
```powershell
.\system_information_collector_for_windows.ps1 -OutputFormat HTML,JSON
```
**결과**: 
- `result_yyyyMMddHHmmss.html`
- `result_yyyyMMddHHmmss.json`

---

### 특정 모듈만 실행 (예: Hardware, Network)
```powershell
.\system_information_collector_for_windows.ps1 -Modules Hardware,Network
```

### 결과 저장 경로 지정 (자동 생성 포함)
```powershell
.\system_information_collector_for_windows.ps1 -OutputPath C:\Diagnostics
```

---

### 모든 형식 생성 (ALL 키워드)
```powershell
.\system_information_collector_for_windows.ps1 -OutputFormat ALL
```
**결과**: 
- `result_yyyyMMddHHmmss.json`
- `result_yyyyMMddHHmmss.html`
- `result_yyyyMMddHHmmss.csv` (요약)
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

### 이벤트 로그를 CSV로 생성
```powershell
.\system_information_collector_for_windows.ps1 -EventLogFormat CSV
```
**결과**: 이벤트 로그가 CSV 파일로 저장됨
- `Log_System.csv`
- `Log_Application.csv`
- `Log_Security.csv`

---

### 모든 옵션 조합
```powershell
.\system_information_collector_for_windows.ps1 -OutputFormat ALL -EventLogFormat CSV -DebugMode
```
**결과**: 
- 모든 출력 형식 (JSON, HTML, CSV)
- 이벤트 로그 CSV 형식
- 디버그 로그 파일 생성
- 중간 파일 삭제 안 함

---

## 📊 출력 파일 구조

### HTML 출력
- **메인 보고서**: `result_yyyyMMddHHmmss.html`
  - 모든 카테고리를 접을 수 있는 형식으로 표시
  - 색상 코딩, 반응형 디자인
  
- **이벤트 로그** (EventLogFormat=HTML 시):
  - `Log_System.html` - Critical/Error/Warning 색상 구분
  - `Log_Application.html`
  - `Log_Security.html`

### JSON 출력
- **단일 파일**: `result_yyyyMMddHHmmss.json`
  - 전체 시스템 정보를 계층 구조로 저장
  - Depth 5까지 중첩 객체 지원

### CSV 출력
- **요약 파일**: `result_yyyyMMddHHmmss.csv`
  - 각 카테고리별 항목 수와 파일명 목록
  
- **카테고리별 파일**: 
  - `result_yyyyMMddHHmmss_Hardware.csv`
  - `result_yyyyMMddHHmmss_Network.csv`
  - 등등...
  - 각 파일은 해당 카테고리의 데이터를 평탄화하여 저장

- **이벤트 로그** (EventLogFormat=CSV 시):
  - `Log_System.csv`
  - `Log_Application.csv`
  - `Log_Security.csv`

- `result_yyyyMMddHHmmss.zip` (사용자가 `-Compress` 지정 시 생성)

### 🔐 보안 암호화 (AES-256)
`-Encrypt` 옵션 사용 시 모든 결과 파일은 암호화됩니다:
- **AES-256 (PBKDF2 10만 회)**: 강력한 키 유도 기술을 적용하여 무차별 대입 공격을 방어합니다.
- `result_yyyyMMddHHmmss.json.aes`
- `result_yyyyMMddHHmmss.html.aes`
- 암호화된 파일은 전용 도구(`utils/Decrypt-Results.ps1`)로만 복구 가능합니다.

### 🛡️ 스크립트 무결성 및 신뢰 (Authenticode)
본 도구는 인가되지 않은 스크립트 실행을 방지하기 위해 디지털 서명을 활용합니다:
1. **플러그인 보안**: `lib/collectors/` 폴더 내의 모든 스크립트는 디지털 서명이 되어 있어야 로드됩니다.
2. **신뢰 구축**: 처음 사용 시 `utils/Setup-Security.ps1`을 실행하여 자가 서명 인증서를 생성하고 신뢰할 수 있는 게시자로 등록하십시오.
   ```powershell
   # 관리자 권한으로 실행
   .\utils\Setup-Security.ps1
   ```
3. **서명 확인**: 서명이 올바르지 않은 스크립트 발견 시 보안 경고(`Security Warning`)와 함께 로드가 거부됩니다.

---

## 🔍 형식별 장단점

| 형식 | 장점 | 단점 | 권장 용도 |
|------|------|------|-----------|
| **HTML** | ✅ 시각적으로 보기 좋음<br>✅ 브라우저에서 바로 확인<br>✅ 색상 코딩, 접기/펼치기 | ❌ 자동 처리 어려움<br>❌ 파일 크기 큼 | 사람이 직접 검토할 때 |
| **JSON** | ✅ 구조화된 데이터<br>✅ API 연동 용이<br>✅ 프로그래밍 처리 쉬움 | ❌ 사람이 읽기 어려움<br>❌ 대용량 시 느림 | 자동화, API 연동 |
| **CSV** | ✅ 엑셀에서 바로 열림<br>✅ 필터링/정렬 쉬움<br>✅ 데이터 분석 용이 | ❌ 계층 구조 표현 제한<br>❌ 여러 파일 생성 | 데이터 분석, 비교 |

---

## 💡 사용 시나리오

### 시나리오 1: 일상적인 시스템 점검
```powershell
.\system_information_collector_for_windows.ps1
```
- HTML 보고서만 생성
- 빠르게 브라우저에서 확인

### 시나리오 2: 문제 분석 및 보고
```powershell
.\system_information_collector_for_windows.ps1 -OutputFormat HTML,JSON -EventLogFormat CSV
```
- HTML로 시각적 확인
- JSON으로 상세 데이터 보관
- CSV 이벤트 로그로 엑셀 분석

### 시나리오 3: 자동화/모니터링
```powershell
.\system_information_collector_for_windows.ps1 -OutputFormat JSON
```
- JSON만 생성하여 파일 크기 최소화
- 스크립트나 API로 자동 처리

### 시나리오 4: 대기 시간 단축 (병렬 수집)
```powershell
.\system_information_collector_for_windows.ps1 -Parallel -OutputFormat ALL
```
- 모든 모듈을 동시에 수집
- 대규모 서버나 네트워크 지연이 있는 환경에서 권장

### 시나리오 5: 감사 및 컴플라이언스
```powershell
.\system_information_collector_for_windows.ps1 -OutputFormat ALL -DebugMode
```
- 모든 형식의 보고서 증적 확보
- 디버그 로그 포함 및 중간 파일 보존

### 시나리오 5: 여러 서버 비교 분석
```powershell
# 각 서버에서 실행
.\system_information_collector_for_windows.ps1 -OutputFormat CSV

# CSV 파일들을 모아서 엑셀에서 비교 분석
```

### 시나리오 6: 보안 환경 (데이터 암호화)
```powershell
.\system_information_collector_for_windows.ps1 -Encrypt -Compress
```
- 실행 시 키 입력을 요청받음 (화면 숨김)
- 암호화된 파일들이 ZIP 내부에 저장됨

### 시나리오 7: AD 및 가상화 환경 정밀 진단
```powershell
.\system_information_collector_for_windows.ps1 -OutputFormat HTML
```
- **액티브 디렉터리 (AD)**: 도메인 컨트롤러 상태, 복제 파트너, 주요 객체 수 확인
- **가상화 (Hyper-V/Container)**: 호스트 리소스, VM 상태, 컨테이너 런타임 확인
*참고: 해당 모듈(RSAT-AD-PowerShell, Hyper-V) 및 서버 역할이 구성된 환경에서만 데이터가 수집됩니다.*

---

## ⚙️ 파라미터 상세

### -OutputFormat
**타입**: `string[]` (배열)  
**기본값**: `@("HTML")`  
**허용값**: `JSON`, `HTML`, `CSV`, `ALL`

**예제**:
```powershell
# 단일 형식
-OutputFormat HTML

# 다중 형식
-OutputFormat HTML,JSON
-OutputFormat JSON,CSV

# 모든 형식
-OutputFormat ALL
```

### -EventLogFormat
**타입**: `string`  
**기본값**: `HTML`  
**허용값**: `HTML`, `CSV`

**예제**:
```powershell
# HTML 형식 (기본)
-EventLogFormat HTML

# CSV 형식
-EventLogFormat CSV
```

### -DebugMode
**타입**: `Switch`  
**기본값**: `$false`

**효과**:
- 디버그 로그 파일 생성 (`debug_log_yyyyMMddHHmmss.txt`)
- 중간 파일 삭제 안 함
- 상세한 실행 시간 로그

**예제**:
```powershell
-DebugMode
```

### -Modules
**타입**: `string[]` (배열)
**기본값**: `ALL`
**허용값**: `Hardware`, `Network`, `OSConfig`, `Inventory`, `Virtualization`, `Services`, `Performance`, `Logs`, `Security`, `ActiveDirectory`, `HighAvailability`, `ALL`

**효과**:
- 지정된 모듈의 데이터만 수집합니다.
- `ALL`이 포함되면 모든 모듈을 수집합니다.

### -Compress
**타입**: `Switch`  
**기본값**: `$false`

**효과**:
- 생성된 모든 결과 파일을 하나의 ZIP 아카이브로 압축합니다.
- 암호화가 활성화된 경우 암호화된 파일(.aes)들을 압축합니다.

### -Encrypt
**타입**: `Switch`  
**기본값**: `$false`

**효과**:
- **AES-256** 알고리즘을 사용하여 개별 리포트 파일을 암호화합니다.
- 실행 시 비밀번호 입력을 위한 보안 프롬프트가 나타납니다.

**예제**:
```powershell
# 암호화 및 압축 실행
-Encrypt -Compress
```

---

## 🚀 성능 고려사항

### 파일 크기
| 형식 | 예상 크기 (일반적인 서버) |
|------|--------------------------|
| JSON | 5-10 MB |
| HTML | 3-8 MB |
| CSV (전체) | 10-20 MB (여러 파일) |
| ZIP | 1-3 MB (압축 후) |

### 실행 시간
- **HTML만**: ~30-60초
- **JSON만**: ~30-60초
- **CSV만**: ~40-70초
- **ALL**: ~60-90초

*실제 시간은 시스템 사양과 수집 데이터량에 따라 다름*

---

## 🔧 문제 해결

### Q: CSV 파일이 너무 많이 생성됩니다
**A**: CSV는 카테고리별로 파일을 생성합니다. 요약만 필요하면 JSON이나 HTML을 사용하세요.

### Q: 이벤트 로그 HTML이 너무 큽니다
**A**: CSV 형식을 사용하거나, LogCollector.ps1에서 이벤트 수를 줄이세요 (현재 100개).

### Q: ALL 옵션 사용 시 디스크 공간 부족
**A**: 필요한 형식만 선택하여 사용하세요. ZIP 압축 후 원본 파일은 자동 삭제됩니다.

### Q: 특정 형식만 제외하고 싶습니다
**A**: 현재는 포함할 형식만 지정 가능합니다. 예: `-OutputFormat HTML,JSON` (CSV 제외)

---

## 📌 참고사항

1. **ZIP 파일**: 모든 생성된 파일은 자동으로 ZIP으로 압축됩니다
2. **파일 정리**: `-DebugMode` 없이 실행 시 중간 파일은 자동 삭제됩니다
3. **타임스탬프**: 모든 파일명에 생성 시간이 포함됩니다 (`yyyyMMddHHmmss`)
4. **인코딩**: 모든 텍스트 파일은 UTF-8 인코딩으로 저장됩니다
5. **관리자 권한**: 일부 정보 수집을 위해 관리자 권한이 필요합니다

---

## 🎓 고급 사용법

### PowerShell 스크립트에서 호출
```powershell
# 결과를 변수로 받기
$result = .\system_information_collector_for_windows.ps1 -OutputFormat JSON

# JSON 파일 파싱
$jsonData = Get-Content "result_*.json" | ConvertFrom-Json
$jsonData.Hardware.Processor
```

### 스케줄 작업으로 등록
```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File C:\Scripts\system_information_collector_for_windows.ps1 -OutputFormat JSON"
$trigger = New-ScheduledTaskTrigger -Daily -At 2am
Register-ScheduledTask -TaskName "SystemInfoCollection" -Action $action -Trigger $trigger
```

### 원격 서버에서 실행
```powershell
Invoke-Command -ComputerName Server01 -FilePath .\system_information_collector_for_windows.ps1 `
    -ArgumentList @{OutputFormat=@("JSON"); DebugMode=$false}
```

---

## 📞 지원

문제가 발생하거나 기능 요청이 있으시면 이슈를 등록해 주세요!
