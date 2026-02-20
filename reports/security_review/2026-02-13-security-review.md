# 코드 보안 리뷰 보고서 (Collector PowerShell 프로젝트)

## 1) 개요
본 리뷰는 `system_information_collector_for_windows.ps1`를 중심으로, 수집 파이프라인(컬렉터 로드, 공통 유틸리티, 출력 저장, 보안 관련 테스트) 전체를 대상으로 수행한 보안 관점 코드 리뷰 결과입니다.

## 2) 점검 범위
- `lib/Collectors.ps1`
- `utils/Setup-Security.ps1`
- `lib/Common.ps1`
- `lib/OutputManager.ps1`
- `lib/reporters/HtmlReporter.ps1`
- `tests/lib/*.ps1`
- `system_information_collector_for_windows.ps1`

## 3) 핵심 보안 이슈 (심각도)

### [High] 1. 플러그인 인증서 신뢰 정책이 불충분함
- 위치: `lib/Collectors.ps1:22-24`, `utils/Setup-Security.ps1:29-30`
- 증상: 플러그인 로딩은 `Get-AuthenticodeSignature`의 `Status -eq "Valid"`만 검증(`lib/Collectors.ps1:23`)하고, 인증서 신뢰는 현재 사용자의 `Root`/`TrustedPublisher`에 자기서명 cert를 등록(`utils/Setup-Security.ps1:29-30`).
- 위험:
  - 신뢰 체인을 만족하는 다른 임의 인증서가 유입되면 우회 가능.
  - 로컬 사용자 컨텍스트의 self-signed cert는 운영 환경에서 공격 표면이 큼.
- 권고:
  - 허용된 thumbprint allowlist(고정) 또는 CA 체인 정책 적용.
  - signer subject/발급자/만료/폐기 여부를 함께 검증.

### [High] 2. 출력 데이터 마스킹 규칙이 취약
- 위치: `lib/Common.ps1:182-196`
- 증상: 기본 키워드 6개만 소문자/대문자 문자열 비교로 마스킹 결정.
- 위험: 실제 비밀번호/토큰/연결문자열 패턴은 통과 가능(예: `pwd=`, `AKIA...`, 토큰 형식).
- 권고:
  - 키워드 기반이 아닌 정규식/엔트로피 기반 마스킹 레이어 추가.
  - 필드명 기반 + 값 길이/형식 기반 탐지 결합.

### [Medium] 3. 출력 저장 실패가 상위 실행 플로우를 멈추지 않음
- 위치: `lib/OutputManager.ps1:167-170`
- 증상: `Save-Results` 내부에서 예외를 `Write-Error`로 기록 후 반환을 계속함.
- 연관: 메인 흐름은 `system_information_collector_for_windows.ps1:293-301`에서 `Save-Results` 호출 뒤 즉시 성공 반환.
- 위험: 파일 저장 실패가 보고서 수집 성공처럼 오인될 수 있음.
- 권고:
  - `throw` 또는 `$PSCmdlet.ThrowTerminatingError`로 실패를 상위로 전파.
  - 실패 시 종료 코드/에러 로그 출력 정책 통일.

### [Medium] 4. AES-CBC만 사용하며 무결성/인증 부재
- 위치: `lib/OutputManager.ps1:255-263`, `utils/Decrypt-Results.ps1:70-71`
- 증상: 암호화는 CBC + PBKDF2(`100000` 반복) 기반이지만 HMAC 또는 AEAD 미적용.
- 위험: 무결성 위변조 탐지 부재.
- 권고:
  - 암호문에 HMAC/태그 추가 또는 AEAD(예: AES-GCM) 전환.
  - 키 회전 정책 및 nonce/IV 사용 정책 문서화.

### [Medium] 5. 테스트에서 알려진 결함
- 위치: `tests/lib/EdgeCaseTests.ps1:47-50`
- 증상: WMI 예외 주입 후 `Get-CimSafe` 결과를 `$null`로 기대. 실제 구현은 오류 시 빈 배열 `@()` 반환(`lib/Common.ps1:64`).
- 위험: 해당 기능이 기대 동작을 정확히 검증하지 못함 -> 보안 회귀 탐지력 저하.
- 권고:
  - 테스트 기대값을 `@()` 또는 길이 0으로 정합화.
  - API 계약 문서(`$null`/`@()`)를 명시.

### [Medium] 6. Fault Injection restore가 cmdlet/함수 타입에서 깨질 수 있음
- 위치: `tests/lib/EdgeCaseTests.ps1:20-21,17-22`
- 증상: `FaultInjectionEngine`가 원본을 `$original.ScriptBlock`으로 복원.
- 위험: cmdlet처럼 ScriptBlock이 없는 함수는 복원 실패 가능.
- 권고:
  - `Get-Command` 메타데이터의 `CommandType`을 구분해 원복 전략 분기.
  - `ScriptBlock` 백업 실패 시 원본 정의 스냅샷 저장.

### [Low] 7. HTML 템플릿의 외부 리소스 의존
- 위치: `lib/reporters/HtmlReporter.ps1:124`
- 증상: 보고서 렌더 시 Google Fonts CDN 접근(`https://fonts.googleapis.com`).
- 위험: 무단 네트워크 호출 및 환경 제약에서 렌더 실패, 개인 데이터 노출(접근 로그) 우려.
- 권고:
  - 기본 폰트 로컬화 또는 시스템 폰트 사용.

## 4) 시간/공간 복잡도
- 플러그인 로드(`lib/Collectors.ps1`): O(N), N=collector 파일 수.
- 컬렉션 실행:
  - 개별 콜렉터 비용 합산 O(ΣCi).
  - 병렬 실행 시 `Invoke-ParallelCollection`은 runspace 수를 `min(모듈 수, CPU*2)`로 제한.
- 저장 단계(`Save-Results`):
  - 출력 형식별 직렬화/암호화 연산 O(R*S), R=레코드 수, S=출력 크기.
  - ZIP은 파일 수 M에 대해 O(M).
- 공간복잡도:
  - 컬렉션 데이터 구조 O(R*S).
  - 저장본 파일 수(기본 JSON/HTML/CSV + 이벤트 로그) + 압축본/암호문 잠재적 O(total_output_size).

## 5) 제안 테스트 케이스 (10개)

### T1. 허용 목록 없는 유효 서명 플러그인 거부 (Security)
- 목적: 공격자 서명/위장 서명 플러그인 차단.
- 기대 동작: `Collect` 단계에서 거부 로그 출력.
- 기대 로그: `[Security] Verifying: ...`, `! SECURITY WARNING: Rejecting unsigned or untrusted plugin: ...`

### T2. 자가 서명 인증서 등록 경로 점검 (Security)
- 목적: `CurrentUser` 루트/신뢰 게시자 강제 추가로 인한 신뢰 확대 리스크 검증.
- 기대 동작: 보안 정책 문서 위반(경고) 또는 허용 목록 미적용으로 로드 실패.

### T3. DLP 마스킹 정밀도 (DLP)
- 입력: `db_password=abc`, `apikey=AKIA...`, `api_secret_key` 등.
- 기대 동작: 마스킹 미적용 문자열이 실제로 `[Masked for Security]` 또는 유사 문자열로 변경.
- 실패 시 로그: 테스트 실패 메시지 + `Get-MaskedValue` 반환값 미마스킹.

### T4. WMI 접근 실패 처리 (EdgeCase)
- 주입: `Get-CimInstance` 예외 발생.
- 기대 동작: `Get-CimSafe`는 에러 로그를 남기고 빈 배열 반환.
- 실패 시 로그: `Get-CimSafe failed for Win32_OperatingSystem`

### T5. WMI 복원 테스트 정합성 (EdgeCase)
- 목적: 기존 `WmiCorruptionTest` 기대값 검증 보완.
- 기대 동작: 결과는 `@()`이고 `Count`가 0인지 확인.
- 실패 시 로그: "Get-CimSafe failed ..." or test assertion failure.

### T6. 저장소 경로 없음 또는 권한 없음 (Output)
- 목적: 출력 경로 부재/권한 부족에서 실패 전파.
- 기대 동작: `Save-Results`에서 예외 전파되어 상위 실패 처리.
- 실패 로그: `Output generation failed: ...` 및 메인 단계 오류 종료.

### T7. 디스크 부족 시 예외 처리 (Output)
- 환경: 가용 공간 <150MB.
- 기대 동작: 예외를 발생시켜 실행 종료 또는 명확한 실패 반환.
- 실패 로그: `CRITICAL ERROR: Insufficient space in ...`

### T8. 암호화/복호화 무결성 검증 (Crypto)
- 절차: 저장 후 파일 변조 -> `Decrypt-Results` 수행.
- 기대 동작: 복호화 실패 또는 인증 실패(무결성 체크 도입 시).
- 실패 로그: `Decryption failed. Incorrect key or corrupted file.`

### T9. 병렬 타임아웃
- 주입: 특정 모듈이 300초 초과.
- 기대 동작: `Error: Task timed out after 300s` 수집 값 표기.
- 실패 로그: `[Parallel] <module> timed out or failed to complete.`

### T10. 동시 실행 Mutex 정책 (Concurrency)
- 목적: 중복 실행 차단 일관성 확인.
- 기대 동작: 두 번째 실행에서 즉시 차단 메시지.
- 실패 로그: `CRITICAL ERROR: Script is already running (Mutex locked: ... )`

## 6) 의존성/버전
- PowerShell: `5.1` 이상 (스크립트의 `#Requires -Version 5.1` 확인).
- Windows API/클래스: `System.Threading.Mutex`, `System.Security.Cryptography`, `System.IO.Compression.ZipFile`(암시).
- 외부 모듈: 별도 외부 PowerShell 모듈 의존 없음 (현재 코드 기준).
- 서명 도구: `New-SelfSignedCertificate`, `Set-AuthenticodeSignature`, `Get-AuthenticodeSignature`, `Import-Certificate`.

## 7) 위험 우선순위 조치 로드맵
1. 즉시: `Save-Results` 실패 전파, fault-injection 복원 로직 수정, 테스트 기대값 정합화.
2. 1단계: 마스킹 규칙 강화 + allowlist 기반 플러그인 서명 정책.
3. 2단계: AES 무결성 계층( HMAC/AEAD ) 추가 및 무결성 테스트 반영.
4. 3단계: HTML 외부 의존성 제거 및 환경별 정책 문서 보강.

## 8) 자가 검토 결과
- 본 보고서는 요청 항목(테스트 케이스 10개, 복잡도, 실패 로그, 의존성/버전, 한국어 보고서 형식)을 반영했습니다.
- 코드 수정은 수행하지 않았으며, 단지 코드 보안 리뷰 산출물만 분리 디렉토리에 저장했습니다.
