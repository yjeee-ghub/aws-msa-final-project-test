# 🛠️ 구축 및 재현 절차

현재 프로젝트의 의존성을 기준으로 정리한 실행 지도입니다. **현재 정상 운영 중인 환경에 최초 구축을 반복하지 않습니다.** 명령의 자세한 의미·콘솔 클릭·정상 결과는 [복습 노트](learning/STUDY-NOTES.md), 실제 확인한 결과는 [검증 문서](VALIDATION.md)에 있습니다.

실행 중인 환경에서 직접 관찰·검증·캡처하려면 [교육 복습노트_검증 및 시나리오](learning/교육%20복습노트_검증%20및%20시나리오.md)를 순서대로 따라갑니다.

## 1. 무엇을 어디서 만드는가?

| 방식 | 담당 | 주의 |
| :--- | :--- | :--- |
| AWS 콘솔·이메일 | 기존 도메인 위임 확인, SNS 확인, SES 인증·선택 생성 | 사람이 소유권·구독을 확인 |
| GitHub 콘솔 | 팀원·보호 규칙·Actions 변수·선택 App | 파일 push만으로 적용되지 않음 |
| Terraform bootstrap | state 전용 S3 | 프로젝트와 별도로 보관 |
| Terraform AWS | VPC·EKS·RDS·ECR·IAM·메시징·ACM·DNS | 의존성·state 관리 |
| Terraform Kubernetes | Helm 도구·Secret·RBAC·Argo Application·관리 Ingress | EKS 생성 이후 |
| Argo CD | `app/msa` 앱 선언 | 승인된 main을 반영 |
| ALB Controller / EBS CSI | Ingress의 ALB / PVC의 EBS 생성 | 관련 Controller·IAM 선행 |

기존 Route 53 zone과 SES ID를 재사용할 수 있습니다. 수동 생성한 자원을 Terraform resource로 관리하려면 import가 필요합니다. 같은 자원을 두 방식으로 새로 만들지 않습니다.

## 2. 사전 확인

PowerShell 7·Git·AWS CLI·Terraform·kubectl·gh가 필요합니다. 로컬 테스트용 JDK 17·Node·Python·Git Bash와 로컬 이미지 빌드용 Docker는 구분합니다. Actions 빌드에 PC Docker 실행은 필수가 아닙니다.

```powershell
Set-Location 'C:\aws-msa-final-project-test'
git status --short --branch
aws sts get-caller-identity --profile default
terraform version
kubectl version --client
gh auth status
```

계정 `193644343848`, 리전 서울, profile `default`, 클러스터 `Final-eks`를 확인합니다. 계정 인증 성공만으로 모든 IAM·Kubernetes 권한이 확인된 것은 아닙니다.

## 3. 도메인·state·초기 변수

Route 53의 `aws-yjeee.com` zone·등록기관 NS를 확인합니다. state S3는 `terraform-state-bootstrap` 또는 콘솔 생성+import 중 한 경로로 준비합니다. 기존 state를 버리고 새 기록으로 중복 생성하지 않습니다.

```powershell
terraform '-chdir=terraform-state-bootstrap' init
terraform '-chdir=terraform-state-bootstrap' plan '-out=bootstrap.tfplan'
# 최초 생성 계획을 검토한 경우:
terraform '-chdir=terraform-state-bootstrap' apply bootstrap.tfplan
```

두 루트의 tfvars에는 관리 IP `/32`, IAM principal, 메일·저장소 등을 준비합니다. 첫 구축에서는 다음 스위치를 끕니다.

| 루트 | 초기 false | 이유 |
| :--- | :--- | :--- |
| terraform | enable_website_dns·enable_management_dns | ALB가 아직 없음 |
| terraform | customer_email_enabled | SES 인증·소비자 준비 전 |
| terraform-k8s | enable_app_sync | 이미지·Secret 준비 전 |
| terraform-k8s | enable_management_ingress | 운영 도구 설치·인증서 준비 전 |

파일 생성·콘솔 S3 import·SES 두 방식은 [복습 노트](learning/STUDY-NOTES.md)에 있습니다. 실제 tfvars는 Git에서 제외합니다.

## 4. AWS 인프라 → 인증

```powershell
terraform '-chdir=terraform' init
terraform '-chdir=terraform' validate
terraform '-chdir=terraform' plan '-out=infra.tfplan'
terraform '-chdir=terraform' apply infra.tfplan
```

콘솔에서 EKS·노드·비공개 RDS·역할·ACM Issued·SNS/SQS·비활성 소비자를 확인합니다. SNS 구독 메일과 SES 인증 메일의 링크를 각각 승인합니다. Verified·실제 구독 ARN을 확인한 뒤 진행합니다.

## 5. 클러스터 도구 → Secret → 관리자

```powershell
aws eks update-kubeconfig --name Final-eks --region ap-northeast-2 --profile default
kubectl get nodes
. ./terraform-k8s/Prepare-Secrets.ps1
terraform '-chdir=terraform-k8s' init
terraform '-chdir=terraform-k8s' plan '-out=tools.tfplan'
terraform '-chdir=terraform-k8s' apply tools.tfplan
kubectl wait externalsecret/database-credentials -n soldesk --for=condition=Ready --timeout=180s
./app/msa/Prepare-Admin.ps1
```

같은 PowerShell 창에서 비밀 입력을 준비하고 plan·apply를 실행합니다. RDS 관리형 비밀번호는 Secrets Manager → ESO가 주입합니다. ESO Ready가 아니면 앱부터 켜지 않습니다.

## 6. GitHub·이미지·승인 PR

Actions 변수 `AWS_ROLE_TO_ASSUME`, `AWS_DEPLOY_CHECK_ROLE_ARN`을 Terraform 출력으로 등록합니다. 최초에는 `ENABLE_DEPLOY_CHECKS=false`입니다. 팀원 write·PR 생성 허용·main 보호를 적용합니다. GitHub App은 선택 후속 설정이며 현재 미설정입니다.

ECR에 필요한 digest가 있으면 재사용합니다. 비어 있는 첫 구축이면 main의 전체 빌드를 실행합니다. 같은 SHA의 immutable 태그를 다시 게시하지 않도록 먼저 조회합니다.

```powershell
gh workflow run build-push.yml --ref main -f full_build=true
gh run list --workflow build-push.yml --limit 5
gh pr list
```

테스트·게시 성공 후 릴리스 PR의 source·digest와 CI를 검토하고 **다른 팀원의 실제 승인**을 받아 병합합니다. 자동 검사 실행 승인과 코드 리뷰 승인은 별개입니다.

## 7. 앱·Ingress → ALB → DNS

승인한 manifest·이미지·Secret이 준비되면 k8s tfvars의 `enable_app_sync`, `enable_management_ingress`를 true로 하고 plan·apply합니다.

```powershell
. ./terraform-k8s/Prepare-Secrets.ps1
terraform '-chdir=terraform-k8s' plan '-out=apps.tfplan'
terraform '-chdir=terraform-k8s' apply apps.tfplan
kubectl get application final-apps -n argocd
kubectl get pods -n soldesk
kubectl get ingress -A
```

공유 ALB 주소가 생긴 뒤 infra tfvars의 두 DNS 스위치를 true, SES 인증 후 메일 소비자 스위치를 true로 변경해 plan·apply합니다. 기존 A 레코드가 있으면 state 소유 관계를 확인합니다.

**앱·도구 준비 → ALB 생성 확인 → DNS 연결**이 핵심 순서입니다. 관리 Ingress를 먼저 켜 ALB를 준비하는 것도 같은 의존성을 지키는 방식입니다.

## 8. 내부 검증 → 실제 주문

```powershell
./scripts/ops/Test-DeploymentHttps.ps1
./scripts/ops/Start-DeployCheckRunner.ps1
kubectl get pods -n deploy-check-runners
gh run list --workflow deploy-check.yml --limit 5
```

앱·DNS 준비 후 검증 변수를 true로 켭니다. 이미 검사가 queued/running이면 중복 dispatch하지 않습니다. 대기 작업이 없으면 수동 실행하고 결과를 확인합니다. 일회용 러너의 완료 Pod·등록 Secret은 해당 이름만 정리합니다. **평소 배포에서는 릴리스 PR 병합 전에 러너를 준비**합니다.

이후 브라우저·API로 로그인, 이미지, 주문, 같은 키의 재요청, 재고, 메일 이벤트·큐를 대조합니다. [정확한 명령과 정상 결과](learning/STUDY-NOTES.md)

## 9. 종료·복구

상태 조회·HTTPS·최종 plan을 기록하고 비밀 환경변수를 정리합니다. 장애 실습은 [시나리오](10-live-validation.md), 별도 DB 복원은 [복원 가이드](08-rds-restore-lab.md), 이미지 복구는 [롤백 PR](ROLLBACK.md)을 사용합니다.

환경을 의도적으로 제거할 때는 **앱 sync off → 앱 finalizer 정리 → k8s 도구 제거 → ALB 정리 확인 → AWS 인프라 제거** 순서를 지킵니다. 현재 RDS는 최종 스냅샷 자동 생성을 생략하므로 필요한 수동 백업을 먼저 만듭니다. state 버킷은 보관합니다. 전체 종료 명령은 복습 노트의 마지막 단계에만 모았습니다.

[홈](../README.md) · [복습 노트](learning/STUDY-NOTES.md) · [실제 결과](VALIDATION.md)
