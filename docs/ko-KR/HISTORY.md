# 📜 프로젝트 변경 이력 (Project History)

본 문서는 **Windows 시스템 정보 수집기** 프로젝트의 주요 변경 사항, 기능 개선 및 보안 패치 이력을 기록합니다.

---

## 🚀 버전 요약 (Version Summary)

| 날짜 | 주요 변경 요약 | 상태 |
| :--- | :--- | :--- |
| **2026-02-14** | 클래스 기반 프로바이더 모델 도입, Authenticode 서명 검증 및 플러그인 엔진 고도화, 범용 마스킹 DLP 적용 | **최신** |
| **2026-02-14** | 병렬 수집, 암호화(`-Encrypt`, AES-256), 압축(`-Compress`) 및 다국어 지원 기능 추가 | 안정 |
| **2026-02-13** | 시스템 정보(BitLocker·스케줄러·인벤토리) 전면 확장, WSL 수집, 커널·핸들 누수 진단, 보안·사용자 정보 강화 및 클린 코드 최적화 | 안정 |
| **2025-12-01** | 단일 책임 원칙(SRP) 기반 모듈화 및 보안 강화 | 안정 |
| **2024.x** | 초기 VBScript 기반 수집기에서 PowerShell로 이전 | 레거시 |

---

## 📅 2026-02-14 : 아키텍처 고도화 및 보안 하드닝

### 💡 요약
- 객체 지향적 설계를 위한 **클래스 기반 프로바이더 모델** 도입.
- **디지털 서명(Authenticode)** 기반의 플러그인 보안 무결성 확보.
- 초정밀 보안 감사를 통한 **데이터 유출 방지(DLP)** 강화.

### [아키텍처 및 코어]
- **클래스 기반 프로바이더 모델 (Class-based Provider Model)**: `BaseCollector` 클래스를 기반으로 한 수집 모듈 표준화 (`lib/Classes.ps1` 도입).
- **동적 플러그인 엔진**: `lib/collectors/` 폴더 내 스크립트 자동 인식 및 라이브 타입 로딩 구현.
- **자원 관리 최적화**: .NET 객체에 대한 명시적 `Dispose()` 및 `RunspacePool` 상태 동기화 결함 수정.

### [보안 하드닝 (Security Hardening)]
- **Authenticode 서명 검증**: 플러그인 로드 전 디지털 서명을 필수로 검증하여 임의 코드 실행 방지.
- **범용 마스킹 엔진 (Universal Masking)**: `Get-MaskedValue`를 통해 민감 정보(비밀번호, 환경 변수 등)를 전 구간 자동 은닉.
- **암호학적 강화**: PBKDF2 반복 횟수를 100,000회로 상향하고 `ZeroFreeBSTR`을 이용해 메모리 내 비밀번호를 즉시 소거.
- **최소 권한 감사**: `Win32_LSAAccount` 등 민감 속성에 대해 화이트리스트 기반 필터링 적용.

### [안정성 및 품질]
- **전수 보안 감사**: 100회 이상의 정밀 조사를 통해 잠재적 취약점 및 메모리 누수 지점 해결.
- **오류 격리**: 모듈별 '우아한 실패' 로직 검증 및 예외 스택 트레이스 기록 기능 강화.

---

## 📅 2026-02-13 : WSL 수집 기능 추가 및 문서 최적화 (2026-02-13)

### [기능 추가]
- **WSL 정보 수집**: `VirtualizationCollector.ps1`에 `Get-WslInfo` 함수 추가.
    - `wsl --list --verbose`를 통한 배포판 목록 및 버전 수집.
    - `wsl --status`를 통한 기본 배포판 및 커널 버전 확인.
    - WSL 관련 Windows 기능(`Microsoft-Windows-Subsystem-Linux`, `VirtualMachinePlatform`) 상태 조사.

### [문서 최적화]
- **PowerShell 클린 코드 가이드 리팩토링**: `docs/CLEAN_CODE_GUIDE.md`를 PowerShell 표준에 맞춰 전면 개편.
- **문서 일관성 확보**: `README.md`, `ANALYSIS.md`에 설계 철학 및 기술 표준 섹션 반영.

---

## 📅 2026-02-13 : 기능 강화 및 데이터 무결성 최적화

### 💡 요약
- 전체 인코딩 통일 및 버그 수정, 저장 경로 제어(-OutputPath) 및 도움말 시스템 도입.
- 실행 흐름 안정화 

### [기능 추가]
- **-OutputPath 도입**: 결과 파일 저장 위치를 자유롭게 지정 가능 (미존재 시 자동 생성).
- **-Modules 도입**: 특정 카테고리(Hardware, Network 등)만 선택적으로 수집 가능.
- **표준 도움말(Get-Help)**: 스크립트 상단에 상세 기술 블록 추가 (예제 및 파라미터 설명).
- **압축 최적화**: ZIP 생성 시 `-CompressionLevel Optimal` 적용으로 저장 용량 절감.

### [보안 및 안정성]
- **암호화 기능**: AES-256 알고리즘을 사용한 개별 리포트 보안 암호화(`-Encrypt`) 기능 추가.
- **보안 입력**: 암호화 키 입력 시 화면에 노출되지 않는 `SecureString` 인터페이스 구현.
- **복호화 도구**: 암호화된 파일을 복구하기 위한 `utils/Decrypt-Results.ps1` 제공.
- **병렬 수집**: `-Parallel` 스위치를 통한 고성능 멀티스레드 수집 및 상태 동기화 결함 수정.
- **싱글톤 실행 보장**: `Get-ScriptMutex` 로직 개선으로 중복 실행 및 파일 충돌 방지.
- **안전한 임시 파일**: `SecurityCollector` 내 `secedit` 사용 시 임시 파일 생성 및 `finally` 블록을 이용한 확실한 삭제 보장.
- **예외 처리 강화**: `Invoke-Collection` 내 예외 발생 시 스택 트레이스 등 상세 디버그 정보 기록.
- **출력 정규화**: `generatedFiles` 목록 매 실행 시 초기화 및 출력 경로 유효성 검증 강화.

### [데이터 무결성 및 인코딩]
- **UTF-8 with BOM 통일**: 모든 `.ps1` 파일을 BOM 포함 UTF-8로 변환하여 PowerShell 5.1 한국어 환경 호환성 확보.
- **명시적 인코딩 적용**: `Get-Content`, `Set-Content`, `Export-Csv` 등 모든 입출력에 `-Encoding UTF8` 또는 `Default` 명시.
- **HTML 안정화**: 리포트 출력 시 특수 문자(HTML Encoding) 처리로 깨짐 방지.

### [문서 및 규정]
- **규칙 업데이트**: 코드 수정 시 `docs/HISTORY.md` 동시 업데이트 및 한국어 문서 작성 규칙 명문화.
- **모듈 현행화**: `ActiveDirectory`, `Virtualization` 모듈 정보(총 10개)를 `ANALYSIS.md` 및 `README.md`에 반영.

#### 7. 로컬 계정 및 세션 수집 강화 (2026-02-13)
- **AD 참조 원천 차단**: `Win32_UserAccount` 및 `Win32_Group` 조회 시 `LocalAccount = True` 필터를 적용하여 도메인 컨트롤러 통신 배제 및 로컬 계정만 수집.
- **실시간 세션 수집**: `quser.exe`를 활용하여 현재 시스템에 로그인한 사용자(콘솔, RDP) 상태 및 세션 정보 수집 로직 추가.
- **동적 매핑**: 로컬 그룹 구성원(`Win32_GroupUser`) 정보를 포함하여 보안 분석 역량 강화.

#### 8. 공유 서비스(SMB/NFS) 및 클라이언트 수집 추가 (2026-02-13)
- **SMB 통합 진단**: `Win32_Share`와 함께 `Get-SmbSession`, `Get-SmbOpenFile`을 연동하여 활성 공유 및 클라이언트 접속 파일 현황 수집.
- **NFS 연동**: NFS 서버(`Get-NfsShare`) 및 클라이언트 마운트(`Get-NfsMountedIt`) 정보를 수집하여 이기종 파일 공유 환경 진단 지원.
- **가용성 보호**: `NfsService` 등 관련 모듈 미설치 시에도 에러 없이 수집을 지속하는 방어 로직 적용.

### [보안 감사 결과]
- **경로 주입 차단**: `-OutputPath` 검증 및 `Join-Path` 사용으로 경로 조작 방지.
- **XSS 방어 완료**: 모든 HTML 리포트 데이터에 `HtmlEncode` 적용 확인 및 보완.
- **임시 파일 관리**: 예외 발생 시에도 임시 파일 삭제를 보장하는 원자적 구조 확립.
- **설계 표준 준수**: SRP 기반 모듈화 및 `Invoke-Collection`을 통한 에러 격리 상태 우수.

---

## 📅 2025-12-01 : 아키텍처 혁신 (SRP 모듈화)

### 💡 요약
- 단일 스크립트 구조에서 10개 독립 모듈 체계로 전환하여 유지보수성 극대화.
- 보안 검토 및 성능 병목 현상 집중 해결 (성능 약 47% 향상).

### [아키텍처]
- **모듈화 (SRP)**: `lib/collectors/` 하위에 도메인별 컬렉터 분리 (Hardware, Network, OS, Service, Performance, Log, Security, HA, AD, Virtualization).
- **리포터 분리**: 데이터 수집과 포맷 변환(HTML, CSV, JSON) 로직의 완전한 독립성 확보.

### [성능 최적화]
- **로그 수집 개선**: 이벤트 로그 쿼리 시 `-MaxEvents` 옵션 및 속성 필터링 적용으로 속도 대폭 향상.
- **메모리 효율**: 대용량 로그 파일 처리 시 파일 크기 제한(10MB) 및 스트리밍 처리 도입.
- **WMI 효율화**: 불필요한 속성 제외 및 필요한 정보만 투사(Projection).

### [보안 강화]
- **권한 검증**: `Assert-AdminPrivileges`를 통한 관리자 권한 필수 체크.
- **경로 보호**: 환경 변수(`$env:SystemRoot`) 기반의 경로 사용으로 경로 조작 시도 원천 차단.
- **민감 데이터**: 로깅 시 민감 정보 포함 여부 검토 및 최소화.

---

## 📅 2024.x ~ : 초기
- **핵심 수집 구현**: OS, 하드웨어, 네트워크 기초 정보 수집 기능 정립.

---

## 📚 관련 자료 리스트
- [분석 보고서 (ANALYSIS.md)](./ANALYSIS.md)
- [사용자 가이드 (USAGE_GUIDE.md)](./USAGE_GUIDE.md)
- [디버그 및 성능 가이드 (DEBUG_PERFORMANCE_GUIDE.md)](./DEBUG_PERFORMANCE_GUIDE.md)
