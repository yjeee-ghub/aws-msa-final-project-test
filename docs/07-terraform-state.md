# Terraform state와 기존 자원 관리

state는 **Terraform 코드의 resource 주소와 실제 AWS·Kubernetes 자원의 연결 기록**입니다. 코드만 복사해도 이미 존재하는 자원을 자동으로 이어받지는 않습니다.

## 세 루트의 순서

```text
terraform-state-bootstrap → 보관 S3 생성
          ↓
terraform → AWS 인프라 생성·S3에 infra state 저장
          ↓
terraform-k8s → infra 출력 조회·운영 도구 생성·k8s state 저장
```

| 루트 | 기록 위치 |
| --- | --- |
| terraform-state-bootstrap | 해당 폴더의 local state; 개인 보안 백업 필요 |
| terraform | S3 `final/infra/terraform.tfstate` |
| terraform-k8s | S3 `final/k8s/terraform.tfstate` |

보관 버킷은 `final-tfstate-193644343848-ap-northeast-2`입니다. 버전 관리·AES256 암호화·퍼블릭 차단·TLS 정책·삭제 보호를 구성합니다. 다른 두 루트의 destroy에 포함하지 않습니다.

## 잠금은 공동 편집 충돌 방지

S3 backend의 `use_lockfile=true`로 `.tflock` 객체를 사용합니다. 이 잠금에는 DynamoDB를 쓰지 않습니다. 주문 메일 중복 처리용 DynamoDB는 별도 용도입니다. [HashiCorp S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3)

잠금 오류는 다른 사람이 apply 중인지 먼저 확인합니다. `-lock=false`나 잠금 객체 삭제로 무조건 우회하지 않습니다. state 읽기 권한은 인프라 정보 접근 권한이므로 운영자에게 제한합니다.

## 기존 환경에서는 init → state 조회 → plan

```powershell
terraform '-chdir=terraform' init
terraform '-chdir=terraform' workspace show
terraform '-chdir=terraform' state list
aws eks update-kubeconfig --name Final-eks --region ap-northeast-2
. ./terraform-k8s/Prepare-Secrets.ps1
terraform '-chdir=terraform-k8s' init
terraform '-chdir=terraform-k8s' state list
```

같은 S3 backend를 쓰는 두 PC는 같은 환경을 관리합니다. 다른 폴더에서 실행한다고 별도 실습 환경이 되는 것은 아닙니다. 이미 자원이 있는데 state가 비어 보이면 계정·backend key·workspace부터 확인합니다.

## 콘솔에서 만들었으면 import

콘솔에서 생성한 S3·인증서·DNS 등을 코드의 resource로 관리하려면 해당 주소와 실제 식별자로 import합니다. 그 후 plan에서 필요한 차이를 확인합니다. `data` 조회만 하는 기존 Route 53 zone은 해당 zone의 resource import 대상이 아닙니다. [Terraform import](https://developer.hashicorp.com/terraform/cli/import)

state 버킷의 콘솔 생성·6개 resource import 예시는 [실습 가이드](learning/STUDY-NOTES.md)에 있습니다. 기존 state에 등록된 자원을 다시 import하지 않습니다.

## local state에서 S3로 옮기는 별도 작업

현재 프로젝트는 S3 backend를 사용합니다. 별도의 local state 환경을 옮겨야 한다면 실행을 중단하고 원본 local state·backup·backend 설정을 보관한 뒤 목적지 key가 비었는지 확인합니다. 원본 메타데이터를 유지한 채 `terraform init -migrate-state`로 이전하고 resource 목록·lineage·serial·plan을 대조합니다. 빈 state로 `-reconfigure`해서 기존 자원 위에 apply하지 않습니다.

## plan과 비밀값

`validate`는 문법·구성 확인이고 `plan`은 실제 state와의 차이 계산입니다. plan 성공이 apply 성공을 보장하지는 않습니다. 저장한 plan은 민감한 정보를 포함할 수 있으므로 Git에 올리지 않습니다. write-only·ephemeral 입력은 같은 PowerShell에 준비하고 plan·apply를 이어서 실행합니다. [전체 순서](learning/STUDY-NOTES.md)

[홈](../README.md)
