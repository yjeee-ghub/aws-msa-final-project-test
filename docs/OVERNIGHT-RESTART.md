# 학습 환경 종료·재시작 기록과 재구축 절차

2026-10-19에는 실행 인프라를 삭제하고 복구 자료를 보관했으며, **2026-10-20에 해당 백업으로 인프라·데이터·앱을 다시 실행했습니다.** 이 문서는 종료 때 보관한 자료와 실제 재시작 흐름을 함께 설명합니다. AWS 계정 `193644343848`, 서울 리전, 프로젝트 `Final`에 한정합니다. 다른 프로젝트와 기존 도메인 등록·호스팅 영역·관리 IAM 사용자는 삭제하지 않습니다.

## 현재 상태 · 2026-10-20

| 항목 | 재시작 때 확인한 상태 |
| :--- | :--- |
| AWS 대상 | `193644343848` / 서울 / `Final-eks` |
| EKS 노드 | Ready 5대 |
| RDS | 스냅샷 `final-overnight-20261019-212542`에서 복원, available |
| 모니터링 디스크 | Grafana·Prometheus·Alertmanager PVC 3개 Bound, 각 EBS 스냅샷 재사용 |
| DB Secret | ExternalSecret `database-credentials` Ready |
| Argo CD | Synced · Healthy / 앱 revision `94915e5` |
| 외부 쇼핑몰 | HTTPS 200 |
| 관리 화면 | Argo CD HTTPS 200 / Grafana HTTPS 200 |

| 앱 Deployment | 준비 / 원하는 수 |
| :--- | :--- |
| apigateway-depl | 1/1 |
| frontend-depl | 2/2 |
| member-depl | 1/1 |
| ordering-depl | 1/1 |
| product-depl | 1/1 |

이는 **환경 재구축과 기본 기동 확인 기록**입니다. 최종 주문·재고·멱등성·부하·알림 기능 검증, 캡처 수집, 의도적인 장애 훈련은 추후 진행합니다. 이 환경 복원만으로 SC-05의 별도 DB 복원 시나리오나 RTO/RPO 측정을 완료했다고 기록하지 않습니다. [기존 검증 결과](VALIDATION.md)는 2026-10-19 기록을 유지하며, [다섯 장애 시나리오](10-live-validation.md)는 모두 계획 / 미실행입니다.

## 이번 재시작에 사용한 명령

**같은 PC·같은 Windows 사용자**의 PowerShell 7에서 실행합니다. AWS CLI의 `default` 프로필이 유효해야 합니다.

```powershell
Set-Location 'C:\aws-msa-final-project-test'
./scripts/ops/Resume-Project.ps1
```

이 명령은 유료 실행 환경을 다시 만듭니다. EKS·노드·RDS를 새로 생성하므로 수십 분이 걸릴 수 있습니다. 2026-10-20에 아래 순서로 실행을 완료했습니다. 현재 실행 중일 때는 다시 호출하지 않습니다. 스크립트도 manifest가 `running`이면 중복 재구축을 차단합니다. 다음 전체 종료 후에는 최신 스냅샷과 종료 백업 manifest를 먼저 준비해야 합니다.

스크립트는 다음 순서로 실행합니다.

1. AWS 계정·백업 manifest·RDS 스냅샷 상태를 검사합니다.
2. 현재 PC의 공인 IPv4 하나만 EKS 관리 API 허용 CIDR에 반영합니다.
3. 보관한 Terraform state에서 VPC·NAT·EKS·노드·RDS·IAM·이벤트 처리를 재구축합니다. RDS는 빈 DB가 아닌 이번 스냅샷을 사용합니다.
4. kubeconfig를 연결하고, 모니터링 스냅샷 3개를 새 EBS/PV/PVC로 복원합니다. Grafana·Prometheus는 2c, Alertmanager는 2a에 배치합니다.
5. 운영 도구·ESO를 설치합니다. 기존 JWT·내부 통신 키·앱 관리자 Secret을 복원하고 새 RDS 비밀번호가 Secret으로 동기화되는지 확인합니다.
6. Argo 앱 동기화와 관리 Ingress를 켭니다. 보관한 ECR 이미지를 사용하므로 전체 이미지 재빌드가 필요하지 않습니다.
7. 공유 ALB가 active가 되면 도메인 Alias를 새 ALB에 연결합니다.
8. 앱 Healthy·DB Secret Ready·쇼핑몰 HTTPS 응답을 확인합니다.

예상하지 않은 **삭제 또는 교체**가 Terraform 계획에 있으면 apply 전에 멈춥니다. 실패한 단계의 로그는 `.tools/overnight/latest.txt`가 가리키는 폴더에 저장합니다. 실패를 숨긴 채 나머지 단계를 계속 진행하지 않습니다. 중간 실패 시 로그를 확인한 뒤 해당 단계부터 복구해야 하며, 이미 일부 환경이 만들어진 경우 무조건 재실행하지 않습니다.

## 지운 자원과 보관한 자료

| 구분 | 처리 | 이유 |
| :--- | :--- | :--- |
| EKS 클러스터·노드그룹·EC2 | 삭제 | 실행·클러스터 요금 중단 |
| 공유 ALB·Target Group | 삭제 | 사용하지 않는 로드밸런서 정리 |
| NAT Gateway·EIP·VPC·서브넷·연결 자원 | 삭제 | 시간당 비용과 네트워크 잔여 제거 |
| RDS 인스턴스 | 수동 스냅샷 완료 후 삭제 | 데이터 보존과 인스턴스 요금 중단 |
| Grafana·Prometheus·Alertmanager EBS | 스냅샷 보관·원본 볼륨 삭제 | 디스크 데이터를 재사용 |
| Lambda·SQS·주문 SNS·관련 IAM·경보·CloudTrail trail | 삭제 | 실행 환경과 함께 정리 |
| ECR 저장소·이미지 | 보관 | 재시작 때 같은 digest로 빠르게 배포 |
| 상품 이미지 S3·감사 로그 S3 | 내용·접근 보호 설정과 함께 보관 | 상품 파일·로그 보존 |
| Terraform state S3·bootstrap state | 보관 | 남은 자원과 실제 환경을 계속 추적 |
| ACM 인증서·DNS 인증 CNAME·SES 인증 | 보관 | 도메인·이메일 재인증 생략 |
| 운영 SNS 토픽·이메일 구독 | 보관 | 수락한 구독 유지 |
| 이메일 중복 처리 DynamoDB·Lambda 로그 | 보관 | 처리 이력·기존 증거 보존 |
| GitHub OIDC 공급자 | 보관 | 계정의 인증 연결 보존; 실행 IAM 역할은 삭제 |

**완전한 AWS 계정 초기화나 비용 0원 상태가 아닙니다.** S3·ECR·스냅샷·로그 등 보관 데이터의 저장 비용과 기존 도메인/호스팅 영역 비용은 남습니다. 빠른 재구축을 위한 의도적인 보관입니다.

이번 종료는 보관 자료를 Terraform state에서 계속 관리하기 위한 선택적 삭제입니다. 부분 작업 특성상 `terraform output`에 삭제 전 주소·ARN이 남아 있을 수 있으므로 이것을 실행 중이라는 증거로 사용하지 않습니다. 실제 잔여 조회 결과를 기준으로 확인하고, 다음 전체 구축에서 출력값을 갱신합니다. 이전 `deployment.tfplan`이나 삭제 계획 파일은 재사용하지 않습니다. 재시작 스크립트가 현재 상태로 새 계획을 만듭니다.

## 이번 백업과 삭제 확인

- RDS 스냅샷: `final-overnight-20261019-212542`.
- 모니터링 EBS 스냅샷: Grafana 1GiB, Prometheus 5GiB, Alertmanager 1GiB.
- 앱 쓰기·HPA·Argo 자동 동기화를 중지한 뒤 DB 스냅샷을 만들었습니다.
- 모니터링 스냅샷은 실행 중 볼륨의 crash-consistent 복사입니다. 애플리케이션 수준의 정합성 검증이나 실제 복원 훈련을 완료했다는 뜻은 아닙니다.
- 삭제 계획·적용 로그·정확한 잔여 조회 결과는 로컬 백업 폴더의 `shutdown-verification.json`에서 확인합니다. 종료 당시 manifest의 `shutdown-verified`는 잔여 조회 완료 상태였으며, 이번 재시작 뒤에는 `running`으로 갱신했습니다.

백업 폴더 위치를 확인하는 명령입니다. **암호화된 백업 파일을 출력·Git 업로드하지 않습니다.**

```powershell
Get-Content .tools/overnight/latest.txt
```

앱 Secret·관리자 설정·삭제 전 state·RDS 자격증명은 `protected-backup.clixml`에 Windows DPAPI로 보호했습니다. 같은 PC·같은 Windows 사용자로 해독하며 파일 접근 ACL도 제한했습니다. `.tools/`와 실제 tfvars는 Git 제외 대상입니다. 이 폴더를 지우거나 다른 PC로 프로젝트만 복사하면 자동 복구에 필요한 설정이 없어집니다.

## 재시작하면서 바뀐 값과 유지한 값

- **같은 것:** 도메인 주소, 앱 데이터와 관리자 계정, 이미지 digest, 상품 파일, JWT·내부 키, 인증 완료된 이메일·운영 구독.
- **새로 생성되는 것:** EKS endpoint/CA, EC2·NAT·ALB 식별자, RDS endpoint·관리 비밀번호/Secret ARN, Pod와 EBS 볼륨 식별자. Terraform·ESO·DNS가 새 값을 연결합니다.
- Grafana는 기존 DB 디스크와 로그인 Secret을 복원합니다. Argo 초기 관리자 비밀번호는 새 설치에서 생성되므로 [복습 노트](learning/STUDY-NOTES.md)의 조회 절차를 사용합니다.
- 수집 중단 시간은 그래프에 빈 구간으로 남습니다. 새 클러스터와 이전 클러스터의 시각·노드·Pod를 구분합니다.
- 로컬 tfvars의 `db_snapshot_identifier`는 복원 후에도 유지합니다. 임의로 제거해 DB 교체 계획을 만들지 않습니다. `grafana_existing_claim`도 복원한 PVC를 사용하는 동안 유지합니다.

모니터링 기록을 복원하지 않고 새 대시보드 환경으로 시작하고 싶을 때만 다음 옵션을 선택합니다. 이 경우 기존 Grafana 비밀번호 대신 새 Secret의 비밀번호를 확인합니다.

```powershell
# 일반 재시작 명령과 동시에 실행하지 않습니다.
./scripts/ops/Resume-Project.ps1 -SkipMonitoringHistory
```

## GitHub 검사와 다음 학습

이번 종료 때 로컬 GitHub CLI는 로그인이 없어 저장소의 `ENABLE_DEPLOY_CHECKS` 값을 변경하지 못했습니다. Git push·workflow dispatch는 하지 않았으며, VPC 러너와 AWS 실행/검증 IAM 역할은 종료 자원과 함께 제거했습니다. 2026-10-20에는 기존 Windows Git Credential Manager 인증을 메모리에서만 재사용해 GitHub 작업을 진행했습니다. 새 토큰을 저장소나 문서에 기록하지 않습니다. 일반 PowerShell에서 gh 단독 명령을 사용할 때는 별도의 gh 로그인 상태를 확인합니다. CI/리뷰 승인 규칙은 우회하지 않습니다.

재시작 스크립트는 PR 병합·새 이미지 출시·장애 훈련·주문 생성·일회용 내부 러너 실행을 자동으로 수행하지 않습니다. 정상 복구 뒤 [교육 복습노트_검증 및 시나리오](learning/교육%20복습노트_검증%20및%20시나리오.md)의 정상 기준 확인부터 진행합니다.

구조와 최초 구축을 이해하려면 [교육·복습 노트](learning/STUDY-NOTES.md), 전체 구축은 [SETUP](SETUP.md)을 참조합니다.

RDS 복원 옵션 참고: [AWS 스냅샷 복원](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_RestoreFromSnapshot.html), [Terraform DB 인스턴스](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance).
