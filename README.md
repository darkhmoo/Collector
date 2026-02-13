# System Information Collector for Windows

## 📋 프로젝트 개요
Windows Server 및 Workstation 환경에서 상세한 시스템 정보를 수집하고 분석하는 PowerShell 기반 도구입니다. 하드웨어, 네트워크, OS 설정, 보안 구성, 이벤트 로그 등을 자동으로 수집하여 JSON, HTML, CSV 등 다양한 형식의 보고서를 생성합니다.

## 🚀 주요 기능
- **다중 포맷 지원**: JSON (API 연동), HTML (시각적 보고서), CSV (엑셀 분석)
- **모듈화 된 수집**: 하드웨어, 네트워크, OS, 서비스, 성능, 로그, 보안, HA 등 8개 영역별 독립 컬렉터
- **보안 강화**: 민감 정보 보호, 경로 검증, 임시 파일 안전 처리
- **성능 최적화**: 이벤트 로그 쿼리 튜닝, 메모리 효율적 관리
- **디버그 모드**: 상세 실행 로그 및 성능 프로파일링 제공

## 📦 설치 및 실행

### 필수 요구 사항
- **OS**: Windows Server 2016+ 또는 Windows 10/11
- **PowerShell**: 5.1 이상
- **권한**: 관리자 권한 (Administrator) 필수

### 빠른 실행
PowerShell을 관리자 권한으로 실행한 후:

```powershell
# 저장소를 클론하거나 스크립트를 다운로드한 디렉터리로 이동
cd C:\Path\To\Collector

# HTML 보고서 생성 (기본값)
.\system_information_collector_for_windows.ps1

# JSON 및 HTML 모두 생성
.\system_information_collector_for_windows.ps1 -OutputFormat HTML,JSON
```

## 📚 문서 (Docs)

상세한 사용법과 기술 문서는 `docs/` 디렉터리에 있습니다.

- **[사용 가이드 (Usage Guide)](docs/USAGE_GUIDE.md)**: 파라미터 설명, 출력 형식, 시나리오별 사용법
- **[디버그 및 성능 가이드 (Debug & Performance)](docs/DEBUG_PERFORMANCE_GUIDE.md)**: 성능 튜닝, 트러블슈팅, 로깅 분석
- **[스크립트 분석 (Analysis)](docs/ANALYSIS.md)**: 내부 아키텍처, 코드 구조, 데이터 흐름 상세

## 📜 변경 이력 (History)

프로젝트의 리팩토링 및 업데이트 내역은 별도 문서로 관리됩니다.

- **[변경 이력 (History)](docs/HISTORY.md)**: 2025년 12월 대규모 리팩토링 및 이후 업데이트 로그
