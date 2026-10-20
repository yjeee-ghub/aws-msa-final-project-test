# ✅ 실행 검증 결과

기준일 **2026-10-19 (KST)** / 당시 저장소 main / AWS `193644343848` / `Final-eks`에서 확인한 기록입니다. 아래 출력·API·Actions 결과는 해당 날짜의 실행 근거를 유지합니다.

2026-10-20에는 환경을 재구축해 기본 기동 상태만 확인했습니다. [재시작 기록](OVERNIGHT-RESTART.md)을 참조하세요. 최종 기능 검증·캡처·장애 훈련 결과는 아직 추가하지 않았습니다.

## 1. 배포·이미지·실제 서비스

| 항목 | 기대값 | 관찰 결과 | 근거 |
| :--- | :--- | :--- | :--- |
| 팀원 검토 | 최신 변경의 타인 승인 | yonginfra가 58d111f 승인 | [PR #1](https://github.com/yjeee-ghub/aws-msa-final-project-test/pull/1) |
| Git 반영 | 보호 규칙 충족 후 병합 | 배포 commit 94915e5 | Git 기록·PR |
| Argo CD | 같은 revision·Synced·Healthy | 해당 상태 확인 | kubectl 출력 |
| 앱 이미지 | 선언한 digest와 일치 | 5개 Deployment 비교 통과 | [검증 job](https://github.com/yjeee-ghub/aws-msa-final-project-test/actions/runs/39236432516) |
| 앱 가용성 | 원하는 replica 준비 | frontend 2, 나머지 각 1 | Deployment·Pod 출력 |
| 외부 요청 | 유효 TLS·HTML·상품 JSON | 검사 통과 | 같은 검증 job |
| 관리 화면 | Argo·Grafana HTTPS 정상 | HTTP 200 확인 | 실행 당시 HTTP 출력 |

배포 commit 전체 값은 `94915e5c8eb56143ab556b0136396ba9fc95eec2`입니다. 서비스별 이미지의 source와 digest는 [release.json](../deploy/release.json)에 기록합니다. 배포 commit과 이미지 소스 commit은 다른 개념입니다.

## 2. 주문·재고·이미지 대조

테스트 상품 ID `1`, 주문 ID `1`. 상품 이름은 `Deployment verification product`이며 실제 결제는 없습니다.

| 순서 | 동작 | API·화면 결과 | 재고 |
| :--- | :--- | :--- | :--- |
| 1 | 관리자 로그인 | 성공·개인 이메일 확인 | — |
| 2 | 상품·1픽셀 PNG 등록 | 상품 생성·S3 업로드 | 10 |
| 3 | 이미지 URL 조회 | HTTPS 200 | 10 |
| 4 | 수량 1 주문 | ORDERED, 주문 ID 1 | 9 |
| 5 | 같은 Idempotency-Key·같은 내용 재요청 | 기존 주문 ID 1 반환 | 9 유지 |

이 대조는 실제 HTTP/API 결과입니다. 현재 계정에서 SQL SELECT로 같은 행을 직접 조회한 캡처는 아직 없습니다. 복습 시 [클러스터 내부 MySQL 클라이언트](08-rds-restore-lab.md)로 읽기 조회를 추가할 수 있습니다. RDS를 공개로 바꾸거나 다른 프로젝트의 ID·재고 결과를 재사용하지 않습니다.

## 3. 주문 메일·큐

| 확인 | 관찰 | 해석 |
| :--- | :--- | :--- |
| SES 이메일 ID | Verified=true | 해당 이메일 인증 완료 |
| 운영 SNS 구독 | 실제 SubscriptionArn | 이메일 구독 확인 완료 |
| DynamoDB | 이벤트 d93b3782-c615-4142-8207-8bff87dd98e3, SENT | 소비자가 SES 발송 수락 후 처리 기록 |
| SQS | 대기 0·처리 중 0 | 확인 시점 미처리 메시지 없음 |
| DLQ | 메시지 0 | 확인 시점 실패 보관 메시지 없음 |

SES 수락은 받은편지함 도착 증거와 다릅니다. Outbox SENT는 SNS 수락, 소비자 SENT는 SES 수락 후 기록입니다. 각 단계의 의미를 구분합니다. 재처리·만료 구간에서 정확히 한 번 발송을 보장하지 않습니다.

## 4. 자동 확장·기동

초기 4개 t3.small에서 `Insufficient memory`·`Too many pods`로 일부 앱이 Pending이었습니다. CA가 2c 그룹에 노드를 추가해 전체 5대가 됐고 앱이 Ready가 됐습니다. 새 노드 초기화 중 CNI IP 할당·startupProbe의 일시적 실패도 회복됐습니다. 최종 앱 재시작 수는 0이었습니다.

회원 HPA는 CPU 목표 60%, 1~3 replica 설정과 지표 조회를 확인했습니다. **현재 계정에서 부하를 준 HPA 확장·축소 완료 기록은 없습니다.** CA의 초기 배치 확장과 HPA 부하 실습을 같은 결과로 표현하지 않습니다.

## 5. 비밀값·운영 도구·정합성

- ExternalSecret `database-credentials`: Ready=true. RDS 관리형 비밀번호와 ESO 연동 확인.
- Argo·Grafana·Prometheus·Alertmanager·ALB Controller·ESO·CA 등 설치 Pod 정상 확인.
- 검증 job에서 GitHub OIDC를 통한 AWS 조회 역할 인증·내부 EKS 조회 성공.
- 검증 러너는 종료 후 GitHub 등록이 해제됐고 완료 Pod·등록용 Secret도 삭제.
- 최종 AWS Terraform 122개·Kubernetes Terraform 18개 resource에서 No changes 확인.
- Python 회귀 검사 18개, 프런트엔드 7개 검사 및 Actions 필수 CI 성공.

구성의 보안 제한은 manifest·정책으로 확인했습니다. Secret 조회·쓰기 API의 실제 거부를 모두 시험한 침투·권한 부정 테스트까지 완료했다는 의미는 아닙니다.

## 6. 완료와 후속 실습 구분

| 구분 | 상태 |
| :--- | :--- |
| 승인 배포·실제 기능·배포 검증 | 위 결과 확인 |
| GitHub App | 미설정; 봇 PR 검사 실행 승인 발생 가능 |
| 검증 러너 자동 공급·정리 | 미구현; 수동 명령 사용 |
| 후속 PR #2 | 당시 자동 생성·미병합·action_required, 현재 배포와 별개 |
| HPA 부하·DB 중단·강제 DLQ·키 회전·DB 복원·실제 롤백 | 별도 실습 대상 |

상태는 확인 시점의 기록입니다. [증거 목록](EVIDENCE.md)의 링크와 최신 CLI·콘솔 결과를 대조하세요.

## 7. 발표용 5가지 장애 훈련 기록란

아래는 추가할 실행 결과의 자리이며 완료 기록이 아닙니다. 상세 계획·명령·콘솔 작업·증상·원인·복구·재검증·증거는 [5가지 시나리오 문서](10-live-validation.md)에 같은 ID로 작성합니다.

| ID | 훈련 | 현재 상태 | 결과·근거 |
| :--- | :--- | :--- | :--- |
| SC-01 | 잘못된 이미지 → 버전 복구 | 미실행 | 실행 후 작성 |
| SC-02 | 특정 API 오류 → 로그 분석·수정 | 미실행 | 실행 후 작성 |
| SC-03 | 부하 증가 → 확장·축소 | 미실행 | 초기 CA 확장 관찰과 별개, 실행 후 작성 |
| SC-04 | DB 연결 차단 → 연결 복구 | 미실행 | 비밀번호 회전과 별개, 실행 후 작성 |
| SC-05 | 데이터 복원 → 데이터·앱 확인 | 미실행 | DB·데이터·별도 앱을 단계별 확인 후 작성 |


[홈](../README.md) · [문제 해결](TROUBLESHOOTING.md) · [복습](learning/STUDY-NOTES.md)
