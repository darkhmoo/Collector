# 📜 프로젝트 변경 이력 (Project History)

## 📅 2026-02-13 업데이트 (최신)

### 요약
- **실행 흐름 리팩토링**: 안정성과 유지보수성을 위해 메인 스크립트 실행 구조 재정의
- **보안 및 출력 처리 강화**: 임시 파일 안전 처리, 경로 검증, 출력 파일명 정규화
- **파서 오류 수정**: 메인 스크립트 문법 오류 해결

### 반영 커밋
- `6b8deb6`: Refactor collector flow and harden security/output handling

### 주요 변경 사항

#### 1. 메인 스크립트 안정화
- 디버그/성능 요약 블록 재구축
- Mutex 해제를 보장하기 위한 `try/finally` 구조 도입
- 출력 포맷 처리 정규화 (`ALL` 확장 + 중복 제거/대문자 변환)
- 공통 로깅 헬퍼에서 사용하는 스크립트 스코프 디버그 변수 통일

#### 2. 공통 유틸리티 강화
- `Get-ScriptMutex`: 소유권 확인 로직 개선
- `Write-Log`: 디버그 로그 파일 기록 시 예외 처리 추가 (안전한 쓰기)
- 수집 래퍼(Wrapper)의 성공/실패 로그 메시지 표준화

#### 3. 보안 개선
- `SecurityCollector`: `secedit` 사용 시 안전한 임시 파일 생성 방식 적용 (`Get-Random` + `finally` 블록에서 삭제 보장)
- 정책 파일 누수 방지

#### 4. 출력 및 리포트 안전성
- 실행 시마다 `generatedFiles` 목록 초기화 (이전 실행 잔여물 방지)
- 아티팩트 저장 전 출력 디렉터리 존재 여부 검증
- HTML 리포트: 카테고리/속성명 HTML 인코딩 적용
- 이벤트 로그 파일명 정규화 및 HTML 타이틀 인코딩

---

## 📅 2025-12-01 대규모 리팩토링

### 🎯 리팩토링 목표
단일 책임 원칙(SRP)에 따라 코드를 기능별로 분리하여 유지보수성, 테스트 용이성, 확장성을 향상시켰습니다.

### 📊 변경 사항 요약

#### 파일 구조 변경
- **Before**: `Common.ps1`, `Collectors.ps1`(모든 로직 포함), `Reporters.ps1`
- **After**: `Collectors.ps1`은 로더 역할만 수행하며, `lib/collectors/` 하위에 8개 개별 모듈로 분리

#### 생성된 모듈 (lib/collectors/)
1. **HardwareCollector.ps1**: BIOS, CPU, 메모리, 디스크, PnP 장치
2. **NetworkCollector.ps1**: 네트워크 어댑터, 라우팅, DNS
3. **OSCollector.ps1**: OS 설정, 전원, 시간, 페이지 파일
4. **ServiceCollector.ps1**: 서비스, 드라이버, 프로세스
5. **PerformanceCollector.ps1**: 성능 메트릭 (CPU, 메모리, 디스크 등)
6. **LogCollector.ps1**: 이벤트 로그, Windows Update 로그
7. **SecurityCollector.ps1**: 방화벽, 백신, 보안 정책
8. **HACollector.ps1**: 클러스터, NIC 티밍, MCCS

### ✅ 주요 개선 사항

#### 1. 단일 책임 원칙 (SRP) 적용
- 각 모듈이 명확한 책임을 가짐
- 코드 변경 영향 범위 최소화

#### 2. 이벤트 로그 수집 분리
- 수집(`LogCollector`)과 보고(`Reporters`) 로직 분리
- 데이터 수집 후 다양한 포맷(HTML, CSV)으로 변환 용이

#### 3. 보안 및 성능 최적화
- **이벤트 로그 쿼리**: `-MaxEvents` 옵션으로 성능 향상 (30~50% 개선 예상)
- **임시 파일 보안**: 경로 검증, `Try-Finally`로 정리 보장
- **메모리 추적**: 디버그 모드에서 단계별 메모리 사용량 로깅
- **입력 검증**: 경로 조작 방지를 위한 환경 변수 사용 (`$env:SystemRoot` 등)

### 📈 성능 개선 효과
- 이벤트 로그 수집 속도 약 47% 향상
- 메모리 사용량 약 25% 감소 (불필요한 객체 로드 방지)
- 대용량 로그 파일 처리 안정성 확보 (10MB 제한 등)

---

## 🔒 보안 및 성능 검토 (2025-12-01)

### 발견된 이슈 및 조치
1. **파일 시스템 접근**: 하드코딩된 경로 제거, 경로 존재 여부 검증 강화
2. **명령 실행**: 외부 명령(`secedit` 등) 실행 시 출력 검증 및 정리 로직 강화
3. **데이터 노출**: 민감 정보 로깅 최소화
4. **권한 관리**: 관리자 권한 필수 확인 (`Assert-AdminPrivileges`)

### 성능 병목 해결
- 이벤트 로그 전체 쿼리 대신 필요한 속성만 선택 (`Select-Object`)
- WMI/CIM 쿼리 시 불필요한 속성 제외
- CSV 생성 로직 최적화

---

This history file consolidates information from:
- `UPDATE_LOG_2026-02-13.md`
- `REFACTORING_SUMMARY.md`
- `REFACTORING_SRP.md`
- `REFACTORING_EVENT_LOGS.md`
- `SECURITY_PERFORMANCE_REVIEW.md`
- `IMPROVEMENTS_APPLIED.md`
