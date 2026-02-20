# EC-082 구현 로그 (2026-02-20)

대상 이슈: `#1 [P0] EC-082 출력 경로 권한 오류 상위 전파`

## 1) 테스트 구현 계획
- 목표:
  - 저장 권한 오류가 `Save-Results`에서 상위로 전파되는지 검증
  - 메인 스크립트가 치명 오류를 표준 방식으로 종료(`exit 1`)하는 계약을 검증
- 테스트 항목:
  - `SaveResultsWriteFailurePropagationTest`
    - `Set-Content` 강제 실패 주입 후 `Save-Results` 예외 전파 확인
  - `MainScriptFatalExitContractTest`
    - 메인 스크립트에 최상위 `catch` + `exit 1` 계약 존재 여부 확인
- 기대 결과:
  - 쓰기 실패가 `"Output generation failed"` 형태로 상위 전파
  - 메인 스크립트에 치명 오류 핸들링 계약이 존재

## 2) 테스트 작성 결과 (구현 전)
- 추가 테스트:
  - `SaveResultsWriteFailurePropagationTest` (신규)
  - `MainScriptFatalExitContractTest` (신규)
- 실행 결과:
  - `SaveResultsWriteFailurePropagationTest`: Passed
  - `MainScriptFatalExitContractTest`: Failed (`Missing fatal error tracking variable.`)
- 해석:
  - `Save-Results` 예외 전파는 동작 중
  - 메인 스크립트의 최상위 치명 오류 계약(`catch + exit 1`)은 보강 필요

## 3) 코드 구현 계획
- 구현 목표:
  - 메인 실행부에서 치명 오류를 구조적으로 수집하고 종료 코드 `1`을 명시
  - 정리 루틴(`finally`) 실행 보장 후 종료
- 변경 포인트:
  - `system_information_collector_for_windows.ps1`
    - 최상위 실행 블록에 `catch` 추가
    - 치명 오류 시 표준 로그 출력
    - 정리 후 `exit 1`
- 완료 조건:
  - 저장 실패 시 비정상 종료 코드가 보장
  - 기존 정리 동작(Mutex/GC)은 유지

## 4) 코드 구현 결과
- 변경 파일:
  - `system_information_collector_for_windows.ps1`
  - `tests/lib/EdgeCaseTests.ps1`
  - `tests/Comprehensive.Tests.ps1`
  - `README.md`
  - `docs/ko-KR/USAGE_GUIDE.md`
  - `docs/en-US/USAGE_GUIDE.md`
- 구현 내용:
  - 메인 실행부에 `$fatalError` 추적 변수 추가
  - 최상위 `catch`에서 치명 오류를 캡처하고 `[CRITICAL] Fatal execution error` 로그 출력
  - `finally` 정리 후 `if ($fatalError) { exit 1 }`로 종료 코드 계약 명시
  - `SaveResultsWriteFailurePropagationTest` 및 `MainScriptFatalExitContractTest` 추가
  - 종합 테스트 러너에 신규 테스트 등록
- 구현 후 테스트 결과(타깃 2건):
  - `SaveResultsWriteFailurePropagationTest`: Passed
  - `MainScriptFatalExitContractTest`: Passed
