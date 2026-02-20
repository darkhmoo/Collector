# RCA용 시스템 정보 수집 항목 발굴 보고서

작성일: 2026-02-13
대상: Windows 시스템 정보 수집 프로젝트 (Collector)

## 1. 목적
Windows 장애/성능 저하/보안 사고 RCA(근본 원인 분석) 시점을 가정하여, 현재 수집 항목의 적정성 및 누락 항목을 판별하고, 신규 수집 항목 우선순위를 정의한다.

## 2. 수집 시스템 현황 요약
현재 프로젝트는 다음 11개 수집 카테고리를 제공한다.

- Hardware, Network, OSConfig, Virtualization, Services, Performance, Logs, Security, Inventory, ActiveDirectory, HighAvailability
- 출력: JSON/HTML/CSV/이벤트로그(HTML/CSV), 암호화/압축 옵션 지원
- 핵심 공통 로직: `BaseCollector`, `Get-CimSafe`, `Invoke-Collection`, `Invoke-ParallelCollection`, `Save-Results`

현재 수집은 기본적인 운영 점검(컴플라이언스/자산 점검)에는 유효하나, RCA 관점에서는 **변경 이력 추적성·타임라인 정밀도·인과관계 증거성**이 더 필요하다.

## 3. RCA 단계별 필수 수집 항목 제안

### 3.1 사건 탐지(Detection)
- **이벤트 전개 시점 포착**
  - OS/커널: 마지막 부팅/재부팅 원인, 이벤트 ID 기반 경고
  - 보안: 로그인 실패, 계정 잠금, 인증 실패
  - 시스템: 드라이버/서비스 상태 변경, 스케줄 작업 변경
- 현재 수집 커버 여부
  - 이벤트 로그: `System/Application/Security`는 수집(7일)
  - 보안 정책/방화벽/서비스/프로세스는 부분 수집
  - `Windows Defender`, `BitLocker`, `secedit` 샘플 값 일부 수집
- 부족 항목(추가 필요)
  - Microsoft-Windows-Sysmon, Microsoft-Windows-TerminalServices, Service Fabric/Hyper-V 이벤트를 분리 수집
  - 보안 이벤트(Event ID 분류) 집계 필드 미구현

### 3.2 영향범위 분석(Impact)
- **누가/무엇이 영향받았는지 식별**
  - 장애 시점의 서비스 실패 리스트, 의존 서비스 체인
  - 네트워크 세그먼트별 연결/포트 장애
  - 최근 변경된 작업 스케줄/시작 항목/스크립트
- 현재 수집 커버 여부
  - 서비스/프로세스, 스케줄 작업, 포트/연결, 라우팅/네임 확인 일부 수집
- 부족 항목
  - 서비스 의존성 맵(서비스 간 Dependency) 수집 누락
  - 실행 중인/중지 전후 상태 스냅샷 비교를 위한 이전 스냅샷 참조 키(실행 시각, 실행ID) 미제공
  - 사용자별 활성 세션과 네트워크 인증 토폴로지(세션-소스IP-프로세스) 미완전

### 3.3 원인 추적(Cause)
- **최초 변화 지점 추적**
  - 패치/설치/설정 변경 히스토리
  - 드라이버/레지스트리 변경
  - 권한/구성 변경, 인증 연동 변경
- 현재 수집 커버 여부
  - OSConfig/Dism/Update 정보 일부, WMI 기반 객체 요약 수집
  - 소프트웨어 설치 목록(Inventory) 수집
- 부족 항목
  - 변경 관리 이벤트(Software Change Audit, WMI Event Log, Appx/패키지 설치 로그 정규화) 미충분
  - 레지스트리 변동 추적 키(`HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall`/네트워크/보안 설정 키) 정형 수집 부재
  - AD/도메인 변경 이벤트의 타임라인 정합성 로그 제한

### 3.4 재발방지(Preventive)
- **동일 장애 재현/회귀 분석**
  - baseline(성능/메모리/디스크 I/O)와 장애 구간 비교
  - 병렬 실행 결과의 집계 일관성, 실패 원인 코드
- 현재 수집 커버 여부
  - 기본 성능 카운터, 메모리/CPU/디스크 기본 값 존재
- 부족 항목
  - 장기 추세용 지표(타임라인 메트릭) 미수집
  - 수집 파이프라인 메타데이터(모듈 단위 실패코드, 입력 파라미터 해시) 미표준

## 4. 수집 항목 우선순위(기능 추가)

### P0 (즉시 반영)
1. **실패/타임라인 표준 출력 메타데이터 추가**
   - 수집 시작시각, 종료시각, 실행 파라미터, 노드 식별자, 모듈별 Exit 상태
   - 기대 효과: RCA에서 “무엇이 언제 실패했는지”를 단일 보고서로 확인
2. **이벤트 로그 집합 확장**
   - Application/Security/System 외에 RCA 핵심 providers 추가
   - Microsoft-Windows-Security-Auditing, Microsoft-Windows-Kernel-Power, Microsoft-Windows-DNS-Client, FailoverClusters 핵심 채널 선별 수집
3. **시작/종료/변경 이력 보강**
   - 최신 설치/업데이트/서비스 변경 로그, 패치 실패 이벤트 정규화

### P1 (단계 반영)
1. **서비스 의존성/세션-프로세스-포트 연계 수집**
   - 서비스 StartType/RecoveryOptions/Dependency, RDP/WinRM/SQL/DB 관련 포트-프로세스 매핑
2. **네트워크 계층 RCA 개선 수집**
   - NFS/SMB 권한 이벤트, DNS/DHCP 캐시 변화, ARP/route churn 짧은 구간 수집
3. **보안 구성 점검 강화**
   - 로컬 관리자 계정 변경 이력, 권한 상승 히트맵, LAPS/자격증명 정책 점검 값

### P2 (장기)
1. **변경 추적 비교형 스키마 추가**
   - 이전 수집본과 key-value diff 계산용 공통 필드(설치 목록, 서비스맵, 네트워크맵)
2. **장기 성능/이벤트 상관분석 리포트**
   - 수집 간격별 baseline 갱신 + 이상치 표기
3. **RCA 패키지 템플릿 자동 생성**
   - 수집본을 기반으로 사건 요약(요약/근거/추정 원인) 초안 생성

## 5. 실패 시 로그/알람 포맷 표준(안)
- 권장 Prefix
  - `[RCADetect]`, `[RCAImpact]`, `[RCACause]`, `[RCAPrevent]`, `[RCAFail]`
- 표준 필드
  - `Timestamp`, `Module`, `Category`, `Node`, `ErrorCode`, `Context`, `ImpactScore`, `NextAction`

예시:
- `[RCADetect] Module=EventLog ErrorCode=EVENT_GAP Node=Server01 Context=SecurityLogLast7d`
- `[RCAFail] Module=SaveResults ErrorCode=OUTPUT_WRITE_FAIL Node=Server01 Context=CSV output path permission`

## 6. 테스트 케이스(우선)

### T01-탐지 재현
- 1시간 전 실패 이벤트 주입 → Detection 카테고리에서 재현 시점 포함 여부 확인

### T02-서비스 영향 평가
- 중요 서비스 3개 강제 중단 후 수집 결과에서 영향범위 추정 항목 채워짐 확인

### T03-시간축 정합성
- 동일 호스트에서 2회 수집 후 변경 키 값(diff 기준) 일치 확인

### T04-권한/경로 실패
- 권한 없는 경로에 저장 시 `RCAFail` 발생 및 종료코드 반영

### T05-수집 연계 누락
- NFS/SMB 권한 로그 환경에서 NFS 항목 폴백 코드 및 원인코드 출력 확인

### T06-병렬 예외 격리
- 특정 모듈에서 타임아웃 주입 시 전체 파이프라인이 중단되지 않고 실패 컨텍스트만 남는지 확인

### T07-보안 변경 감지
- 로컬 그룹/권한 정책 변경 후 수집본에서 변경 징후 표시 확인

### T08-이벤트 공급자 확장
- 확장 이벤트 채널의 존재/미존재 상태가 명시적으로 기록되는지 확인

### T09-패키지 무결성
- 수집본(manifest 포함) SHA 비교 후 외부 변조 탐지 로그 확인

### T10-성능 회귀 추적
- 장애 구간 CPU/Memory spike와 이벤트 발생 시간을 상호 정합하는지 확인

### T11-데이터 품질
- 문자열 마스킹 적용 대상에 대해 민감정보가 누락/오탐 없이 처리되는지 확인

## 7. 시간/공간 복잡도
- 기본 수집: O(M + ΣCi)
- 로그/이벤트 채널 확장 시: O(M + ΣCi + E), E=추가 이벤트 채널 수집 비용
- 병렬 병합/메타데이터 정규화: O(M + R), R=모듈별 결과 갯수
- 저장/manifest/해시: O(S), S=산출물 크기

## 8. 의존성/버전
- PowerShell: 5.1+
- OS: Windows Server 2016+, Windows 10/11
- .NET: Stopwatch, Mutex, Crypto API
- 모듈: `ActiveDirectory`, `FailoverClusters`, Hyper-V/Containers(옵션), Docker, WSL(선택)

## 9. 자체 검토
- 본 보고서는 코드 실행 없이 수집 항목 기준으로 RCA 적합성을 점검한 문서다.
- 현재 수집 범위는 운영 점검엔 충분하나, RCA용으로는 **타임라인 이벤트, 변경 이력 정합성, 실패 메타데이터 표준화**가 필수 보강 항목이다.
- 우선순위는 P0 항목을 먼저 반영하고, 이후 P1/P2 항목을 단계적으로 추가하는 것이 바람직하다.




