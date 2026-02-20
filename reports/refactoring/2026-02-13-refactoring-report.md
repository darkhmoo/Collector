# Collector PowerShell 프로젝트 리팩토링 보고서

## 1) 목적
현재 수집 엔진의 안정성·테스트 신뢰성·운영 유지보수성을 높이기 위한 구조적 정비를 수행한다.
특히 `논리 오류`, `예외 전파 일관성`, `테스트 계약 불일치`, `위험 연산 제어`의 세 영역을 핵심으로 한다.

## 2) 문제 진단 요약

### 2.1 제일 우선 수정 항목
- HighAvailability 수집 호출이 `-WhatIf`를 전달하지만 수신 함수가 이를 지원하지 않아 실행 바인딩 실패 가능(`system_information_collector_for_windows.ps1:219`, `lib/collectors/HACollector.ps1:82`).
- HA 클러스터 로그 저장 경로가 실행에서 지정한 `-outputPath`와 분리되어 기본 경로 기반으로 생성됨(`system_information_collector_for_windows.ps1:61`, `system_information_collector_for_windows.ps1:219`, `lib/collectors/HACollector.ps1:84`).
- `Save-Results` 예외가 상위로 전달되지 않아 실패 감지 누락.
- EdgeCase 테스트가 실제 함수 시그니처와 불일치(`tests/lib/EdgeCaseTests.ps1:107`).

### 2.2 재사용성/정합성 문제
- Get-CimSafe 실패 시 반환값 계약(`@()`)과 테스트 기대값(`$null`) 불일치(`lib/Common.ps1:64`, `tests/lib/EdgeCaseTests.ps1:48`).
- 네트워크 수집에서 의심 커맨드명 사용(`Get-NfsMountedIt`)으로 모듈/환경별 수집 로직이 깨질 수 있음(`lib/collectors/NetworkCollector.ps1:55`).
- SecurityCollector와 OSCollector의 정보 구조가 섞이면서 일부 민감 항목 처리 로직이 다층화되어 일관성 약화.

## 3) 리팩토링 목표
1. **실패는 조용히 흘러가지 않게**: 모든 핵심 파이프라인에서 실패는 명시적 상태/예외로 반영.
2. **계약 우선(Contract-first)**: 함수 파라미터·반환값·테스트 기대값을 단일 정의.
3. **실행 제어 일관화**: WhatIf/ShouldProcess의 전달·해석을 일관된 경로로 통일.
4. **기능 경계 정리**: 수집/저장/보안/테스트를 분리해 책임을 명확화.
5. **운영 추적성 강화**: 경로·로그·오류 메시지를 구조화.

## 4) 권장 리팩토링 항목 (우선순위)

## 4.1 Critical (즉시 반영)

### A. HighAvailability 모듈의 WhatIf 계약 정렬
- 대상 파일
  - `system_information_collector_for_windows.ps1:219`
  - `lib/collectors/HACollector.ps1:82`
- 현재 문제
  - `Get-HighAvailabilityInfo`가 `-WhatIf` 파라미터를 받지 못함.
- 변경안
  - `Get-HighAvailabilityInfo`를 `CmdletBinding(SupportsShouldProcess=$true)`로 변경.
  - 내부 `HACollector` 생성자에 `OutputPath`를 명시 전달.
  - `Collect()` 내에서 클러스터 로그 생성 같은 외부 변경 연산을 `ShouldProcess`로 감싸기.
- 효과
  - 기본 전체 실행(`ALL`) 중단 리스크 제거.
  - 드라이런 동작 예측 가능.

### B. 저장 실패 전파 구조화
- 대상 파일
  - `lib/OutputManager.ps1:167-170`
- 현재 문제
  - 저장 실패 시 `Write-Error`만 수행 후 진행.
- 변경안
  - `Save-Results`가 반환 객체/bool 또는 커스텀 상태 객체를 반환하도록 변경.
  - 상위 호출부가 실패 상태를 확인해 명시 종료.
- 효과
  - “성공처럼 보이는 실패” 제거.

### C. Test Contract 정렬
- 대상 파일
  - `tests/lib/EdgeCaseTests.ps1:107`
- 현재 문제
  - 테스트가 실제 함수 시그니처와 불일치.
- 변경안
  - `Save-Results` 실제 파라미터(`-auditReport`, `-outputFormat`, `-eventLogFormat`, `-outputDirectory`, `-isDebugMode`, `-zipResults`, `-encryptionKey`)로 정리.
  - 의도한 실패 시나리오(저장 경로 부족)도 주입 가능한 방식으로 재작성.
- 효과
  - 테스트가 실행 가능하고 실제 버그를 검증.

## 4.2 High (다음 단계)

### D. HAOutput 경로 전달 정합성 정리
- 대상 파일
  - `system_information_collector_for_windows.ps1:61`, `lib/collectors/HACollector.ps1:84`
- 변경안
  - `Get-HighAvailabilityInfo`에 `-OutputPath` 매개변수 추가.
  - `main outputPath`를 그대로 전달.
- 효과
  - 클러스터 로그가 의도한 디렉터리에 일관되게 저장.

### E. Network NFS 명령체크 및 폴백 정교화
- 대상 파일
  - `lib/collectors/NetworkCollector.ps1:55`
- 변경안
  - `Get-NfsMountedIt` 존재성 및 호출명 정합성 확인.
  - 실패 유형(모듈 미설치/권한 부족/실제 cmdlet 부재)을 구분해 메시지 구조화.
- 효과
  - 네트워크 수집 신뢰도 개선, 운영 분석 정밀도 향상.

### F. Get-CimSafe 계약 문서 및 테스트 강제
- 대상 파일
  - `lib/Common.ps1:64`, `tests/lib/EdgeCaseTests.ps1:47`
- 변경안
  - 실패 시 반환 타입을 문서화(`@()`), 테스트는 `Count`/타입 기반으로 검증.
  - null/빈 배열 분기 로직을 호출부 표준화.
- 효과
  - 예외 처리 일관성.

## 4.3 Medium/Low (최적화 단계)

### G. 공통 유틸 경계 정리
- `OSCollector`의 `Get-SystemHealthInfo`와 보안 수집의 마스킹/로그 처리 분리를 통해 보안/운영 책임을 분리.
- `Common.ps1`의 마스킹 정책을 전역 설정/패턴 테이블 기반으로 교체(키워드 단일 문자열 탐지에서 정규식·형식 기반 결합).

### H. 결과 생성 후 정리(cleanup) 책임 분리
- `Save-Results` 내부 파일 생성/암호화/압축/정리 코드를 하위 함수로 분리(`Save-Raw`, `Encrypt-Report`, `Archive-Report`, `Cleanup-TemporaryOutput`).
- 병렬/직렬 경로 모두 동일한 사이클을 보장.

### I. 컬렉터 로더 정책 개선
- `lib/Collectors.ps1`에서 플러그인 서명 검증에 trust policy(허용 thumbprint allowlist) 추상화하여 테스트 가능하게 분리.

## 5) 단계별 실행 계획

### 1차 패치 (1일)
- High 항목 A, B, C, D 동시 반영.
- 대상 테스트: `tests/Comprehensive.Tests.ps1` 전체 통과 + EdgeCase 3개 보강.

### 2차 패치 (1~2일)
- 항목 E, F, H 반영.
- 성능 영향 분석: 컬렉터별 실행시간 5회 반복.

### 3차 패치 (1일)
- 항목 G, I를 보조 작업으로 반영.
- 문서 업데이트: `docs/*` 스키마/옵션 동기화(필요 시).

## 6) 리팩토링 산출물 기준
- 코드 변경은 기존 동작을 보존하되 실패 처리, 경로 처리, 테스트 계약만 변경.
- 변경 후 지표
  - 실패 시 예외 전파율: `0` 누락(즉 실패가 조용히 무시되지 않음)
  - EdgeCase 테스트 통과율: `100%`
  - 기본 실행(ALL)에서 예외성 중단률 감소.

## 7) 리스크 및 대응
- WhatIf/ShouldProcess를 추가할 때 기존 실행 스크립트 호환성 이슈: 실행 옵션 테스트 시나리오 추가로 완화.
- HACollector가 클러스터 환경에서만 동작하므로 로그 생성 부분은 Dry-run/예외 메시지 동작을 운영 환경에서 사전 검증.

## 8) 결론
논리 오류 보고서에서 확인된 치명 리스크(특히 HighAvailability 호출 경로)는 즉시 조치해야 한다. 1차 패치에서 실행 중단 및 계약 불일치 문제를 제거하고, 2차에서 모듈 책임 분리와 테스트 정합성을 고도화하면 코드 안정성/유지보수성이 크게 향상된다.
