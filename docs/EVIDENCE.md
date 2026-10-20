# 📎 증거 목록과 기록 기준

현재 프로젝트의 **검증 근거·설정 근거·설명용 그림·추가할 캡처**를 구분합니다. 기준일은 2026-10-19이며 다른 프로젝트의 상품 ID·부하 수치·캡처를 현재 성공 증거로 옮기지 않습니다.

실습할 때 찍을 화면·파일명·ID 연결 순서는 [검증·시나리오 실행 노트](learning/교육%20복습노트_검증%20및%20시나리오.md)에서 안내합니다. 기존 실행 증거와 앞으로 새로 수집할 자료를 구분합니다.

## 1. 실행 근거

| ID | 확인한 것 | 근거 위치 | 해석 |
| :--- | :--- | :--- | :--- |
| RUN-01 | 최초 이미지 테스트·게시 | [Actions 39232228401](https://github.com/yjeee-ghub/aws-msa-final-project-test/actions/runs/39232228401) | 테스트한 이미지 산출물 게시 |
| RUN-02 | 최종 릴리스 PR 검사 | [Actions 39235149248](https://github.com/yjeee-ghub/aws-msa-final-project-test/actions/runs/39235149248) | required-ci 및 서비스 검사 성공 |
| RUN-03 | 최신 변경의 팀원 승인·병합 | [PR #1](https://github.com/yjeee-ghub/aws-msa-final-project-test/pull/1) | yonginfra 승인, 배포 commit 94915e5 |
| RUN-04 | 내부 러너의 실제 배포 검사 | [Actions 39236432516](https://github.com/yjeee-ghub/aws-msa-final-project-test/actions/runs/39236432516) | revision·이미지·replica·TLS·HTML·상품 API 통과 |
| RUN-05 | 주문·재고·메일 처리 | [검증 결과](VALIDATION.md) 및 실행 당시 API/CLI 출력 | 같은 주문 ID·재고 10→9→9, 이벤트 SENT |
| RUN-06 | CA 확장·최종 상태·No changes | [검증 결과](VALIDATION.md) 및 실행 당시 CLI 출력 | 노드 4→5, 두 Terraform 루트 정합성 |

RUN-05의 개인 PC 원본은 `.tools/functional-smoke-result.json`에 있습니다. `.tools`는 Git에서 제외되어 공개 저장소 링크가 아닙니다. 공개 요약만 VALIDATION에 기록합니다. 아직 원본 CLI 출력·콘솔 화면을 저장소의 캡처 파일로 모두 보관한 상태는 아닙니다.

## 2. 설정 근거

| 확인할 설계 | 소스 |
| :--- | :--- |
| 5개 이미지 source·digest | [release.json](../deploy/release.json) · [Kustomize](../app/msa/kustomization.yaml) |
| 검증 항목·main 조건 | [deploy-check workflow](../.github/workflows/deploy-check.yml) · [check_release.py](../scripts/ops/check_release.py) |
| 일회용·non-root·SA token 제한 | [러너 생성](../scripts/ops/Start-DeployCheckRunner.ps1) |
| AWS 조회 역할·EKS 연결 | [AWS deploy_check](../terraform/deploy_check.tf) |
| Kubernetes 조회 범위 | [RBAC](../terraform-k8s/deploy_check.tf) |
| 운영 도구·EBS 크기·배치 | [monitoring values](../app/msa/k8s/k8s-monitoring/monitoring-values.yml) |
| state 암호화·잠금 | [bootstrap](../terraform-state-bootstrap/main.tf) · [backend](../terraform/backend.tf) |

설정이 존재하는 것과 악용·권한 거부·장애 복구를 실제 시험한 것은 다릅니다. 문서의 정상 기대값은 실험 결과를 대신하지 않습니다.

## 3. 설명용 구성도

- [시스템 구성 SVG](images/system-architecture.svg): 현재 ALB·EKS·비공개 RDS 구조.
- [배포 흐름 SVG](images/delivery-flow.svg): 소스 검사·릴리스 승인·Argo·실제 검증 흐름.

직접 작성한 설계 그림이며 AWS 콘솔 캡처나 실험 출력 이미지가 아닙니다.

## 4. 다음 복습에서 수집할 화면

| 파일명 제안 | 캡처할 내용 | 완료 판정 |
| :--- | :--- | :--- |
| 01-approved-release.png | PR 최신 commit·팀원 승인·검사·병합 | 같은 배포 선언의 흐름 연결 |
| 02-argocd-healthy.png | Application revision·Synced·Healthy | 승인된 배포 commit과 일치 |
| 03-deployments-ready.png | 5개 Deployment·이미지·replica | 동일 시점 가용성 |
| 04-order-idempotency.png | 주문 ID·재고 재조회 결과 | 같은 키·같은 주문·재고 한 번 차감 |
| 05-mail-processing.png | 해당 eventId SENT·큐/DLQ·메일 수신 | API 수락과 실제 도착 구분 |
| 06-ca-events.png | Pending 사유·CA 확장·새 노드 Ready | 같은 실험 시점 연결 |
| 07-observability.png | Prometheus targets·Grafana·관련 지표 | 실제 수집 상태·조회 시각 |
| 08-terraform-plan.png | 두 루트의 No changes | 코드·state·실환경 정합성 |

이 목록은 **추가할 계획**이며 현재 파일이 존재한다는 뜻은 아닙니다. 로그인 비밀번호·JWT·AWS 키·Secret 내용·이메일 구독 해지 링크는 캡처에서 제외합니다. 가림 처리 사본과 원본은 구분하고, 중간 실패 화면을 최종 정상 상태로 소개하지 않습니다.

## 5. 장애 훈련 5가지의 증거 입력란

[장애 시나리오](10-live-validation.md)의 ID와 연결합니다. 아래 파일명은 제안이며 아직 파일·실행 근거는 없습니다. 실제 실행 후 같은 행에 로그·PR·측정 결과와 공개 가능한 캡처 링크를 추가합니다.

| ID | 확보할 증거 | 파일명 제안 | 현재 링크·상태 |
| :--- | :--- | :--- | :--- |
| SC-01 | 정상 digest·실패/차단·복구 PR·반영 버전·API | `sc-01-before.png`, `sc-01-failure.png`, `sc-01-recovered.png` | 미실행 / 추가 예정 |
| SC-02 | 정상·실패 요청·원인 로그·수정 PR·동일 요청 성공 | `sc-02-request.png`, `sc-02-cause.png`, `sc-02-recovered.png` | 미실행 / 추가 예정 |
| SC-03 | 동일 부하 조건·응답 측정·HPA/CA·축소·정리 | `sc-03-baseline.png`, `sc-03-scale-out.png`, `sc-03-scale-in.png` | 미실행 / 추가 예정 |
| SC-04 | 정상 연결·승인한 차단 설정·오류·원복·데이터 기능 | `sc-04-blocked.png`, `sc-04-probes.png`, `sc-04-recovered.png` | 미실행 / 추가 예정 |
| SC-05 | 기준 데이터·스냅샷·별도 endpoint·SELECT·테스트 앱 | `sc-05-baseline.png`, `sc-05-data.png`, `sc-05-app.png` | 미실행 / 추가 예정 |

파일이 생긴 뒤에만 Markdown 링크를 추가합니다. 이미 확보한 일반 주문·초기 확장 출력과 새로운 장애 훈련의 시점을 혼합하지 않습니다.


[홈](../README.md) · [검증 결과](VALIDATION.md) · [장애 시나리오](10-live-validation.md)
