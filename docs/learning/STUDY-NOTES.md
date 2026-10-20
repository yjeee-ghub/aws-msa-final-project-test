# 📖 교육·복습 노트 — 실행 순서와 설계 원리

**목표: 설정 이유를 이해하면서 계정 준비 → AWS → EKS 도구 → 이미지 → 승인 배포 → DNS → 실제 검증까지 직접 실행합니다.**

대상은 `yjeee-ghub/aws-msa-final-project-test` / `main` / AWS `193644343848` / 서울입니다. 다른 계정으로 복사하는 범용 템플릿은 아닙니다. 이미 실행 중인 현재 환경을 확인하려면 **0 → 1 → 17**의 조회부터 진행하세요. 16단계는 실제 테스트 데이터를 만드는 별도 기능 실습입니다. 신규 구축 절차를 반복하거나 기존 tfvars를 덮어쓰지 않습니다.


이미 백업 후 종료한 환경을 다시 만드는 절차와 2026-10-20 실행 기록은 [종료·재시작 안내](../OVERNIGHT-RESTART.md)에 있습니다. 아래 최초 구축 명령을 반복하기 전에 현재 상태를 먼저 확인합니다.

## 두 노트를 함께 사용하는 방법

이 노트는 **명령어의 대상 → 설정이 필요한 이유 → 연결되는 기능 → 정상 결과**를 실행 순서에 붙여 읽는 설명서입니다. 최초 구축 명령을 그대로 유지하되 이미 운영 중인 환경에서는 조회·개념 이해부터 시작합니다.

[교육 복습노트_검증 및 시나리오](교육%20복습노트_검증%20및%20시나리오.md)는 사이트·콘솔·Postman·Grafana에서 직접 검증하고 캡처하는 순서입니다. 본 노트가 원리를 설명하고, 실행서는 구체적인 관찰·조작·복구·기록을 안내합니다. 발표 과제·질문 풀기 없이 실제 작업과 설명을 연결합니다.

### 프로젝트를 읽는 세 가지 흐름

```text
사용자: DNS → ALB → frontend / Gateway → 회원·상품·주문 → RDS·S3
배포: 코드 PR → 테스트 → ECR → 릴리스 PR 승인 → Argo → EKS → 내부 검증
운영: 지표·이벤트·로그 → 원인 구분 → 복구 → 같은 기능·데이터 재검사
```

사용자 요청 경로, 변경 경로, 상태 확인 경로는 서로 연결되지만 동일하지 않습니다. 다음 단계마다 어느 경로를 다루는지 구분하면 기술 이름이 실제 동작으로 이어집니다.

## 읽는 방법

[구축 지도](../SETUP.md)는 순서만 빠르게 보는 문서입니다. 이 노트는 각 단계의 **목적 → 명령·콘솔 작업 → 정상 기준 → 다음 단계**를 직접 연습합니다. 정상 기준은 기대 상태이며 실제 성공 증거와는 다릅니다. [현재 검증 결과](../VALIDATION.md)와 구분해서 읽으세요.

## 전체 순서와 누가 만드는지

| 순서 | 작업 | 방식 | 다음 단계로 가는 기준 |
| --- | --- | --- | --- |
| 0–2 | 기존 환경·도구·계정 확인 | 명령 + 콘솔 | 대상 계정·관리 권한·현재 state 확인 |
| 3 | 도메인·인증 방식 결정 | 콘솔 | 기존 public zone·NS 위임·메일 주소 확인 |
| 4 | state 보관 S3 | Terraform 또는 콘솔+import 중 하나 | 보관 버킷 준비·소유 state 일치 |
| 5–6 | 초기 변수·AWS 인프라 | Terraform | EKS·RDS·ECR·역할·ACM 준비 |
| 7 | SNS·SES 이메일 확인 | 이메일 + 콘솔 | 운영 구독·메일 ID 인증 성공 |
| 8–9 | Kubernetes 도구·Secret·관리자 | 명령 | ESO Ready, 앱 sync는 아직 off |
| 10 | GitHub 변수·보호·선택 App | GitHub 콘솔 + gh | 게시 역할·팀원·검사 준비 |
| 11–12 | 이미지 준비·릴리스 승인 | Actions + 팀원 리뷰 | ECR 이미지·승인된 manifest |
| 13 | 앱·관리 Ingress | Terraform·Argo | 앱 Ready·ALB 주소 생성 |
| 14 | DNS·메일 소비자 활성화 | Terraform | HTTPS·소비자 Enabled |
| 15 | 내부 러너·배포 검증 | 명령 + Actions | 검증 성공·일회용 자원 정리 |
| 16–17 | 실제 주문·운영 점검 | 브라우저 + 명령 | 기능·메일·큐·plan 확인 |
| 18 | 학습·정리 | 선택 실습 | 결과 기록·불필요한 자원 정리 |

콘솔로 연습하기 좋은 것은 도메인 위임, SES 이메일 ID, GitHub 설정입니다. VPC·EKS·IAM처럼 의존성이 많은 자원은 Terraform으로 만들고 콘솔에서 구조를 확인합니다. 같은 자원을 두 방식으로 중복 생성하지 않습니다.

## 0. 현재 실행 중인지부터 확인
### 이 단계의 원리 · 폴더·Git·AWS·Kubernetes는 서로 다른 대상

PowerShell에서 폴더를 바꾸면 상대 경로의 기준만 바뀝니다. GitHub 저장소, AWS 계정, Kubernetes 클러스터가 함께 바뀌는 것은 아닙니다. 같은 프로젝트 폴더를 복사해도 같은 S3 backend를 쓰면 동일한 실제 환경을 관리합니다. 먼저 네 가지 대상이 맞는지 연결해야 합니다.

`git status`는 로컬 파일·브랜치, `git remote -v`는 연결할 원격 저장소, `aws sts get-caller-identity`는 AWS 신원, `kubectl config current-context`는 Kubernetes 접속 대상을 보여줍니다. 인증 성공·관리 권한·네트워크 접속도 별개입니다. 계정 번호가 맞아도 IAM 정책이 부족하거나 EKS의 Access Entry가 없으면 다음 작업이 거부될 수 있습니다.

이 프로젝트의 정상 기준은 저장소 main, 계정 193644343848, 서울, Final-eks입니다. 검증할 때 문서 commit·이미지를 만든 source SHA·Argo가 반영한 배포 commit을 각각 적습니다. 문서 PR만 병합한 최신 HEAD가 현재 앱 revision과 다른 것은 그 자체로 장애가 아닙니다.


| 왜 이 단계인가? | 정상 기준 |
| :--- | :--- |
| 현재 폴더·계정·state가 어떤 환경을 가리키는지 확인 | 조회 성공·Account 일치; 이미 실행 중이면 재생성 생략 |

```powershell
Set-Location 'C:\aws-msa-final-project-test'
git status --short --branch
git remote -v
aws sts get-caller-identity --profile default
aws eks describe-cluster --name Final-eks --region ap-northeast-2 --query 'cluster.{Name:name,Status:status,Version:version}'
```

`AccessDenied`·인증 만료·네트워크 오류를 “자원이 없다”로 해석하지 않습니다. 현재 계정에서 이미 정상 실행 중이면 구축을 건너뛰고 조회·복습합니다. 같은 backend를 사용하는 다른 PC도 같은 환경을 관리합니다.

## 1. 실행 도구 준비
### 이 단계의 원리 · 명령을 적는 도구와 명령이 실행되는 장소

CLI는 Command Line Interface로, 텍스트 명령으로 기능을 사용하는 인터페이스입니다. GUI는 화면의 버튼·표·그래프로 같은 대상을 다루는 방식입니다. GUI는 구조를 관찰하고 패널을 만들 때 편하고, CLI는 정확한 대상 이름·버전·반복 가능한 조작을 남기기 좋습니다.

PowerShell은 명령을 해석하는 셸입니다. `aws`는 AWS API, `kubectl`은 Kubernetes API, `terraform`은 선언과 실제 자원의 변경, `gh`는 GitHub를 다룹니다. `git`은 파일 버전 관리입니다. 서로 대신하는 도구가 아닙니다.

Docker CLI와 Docker 엔진도 다릅니다. PC에 `docker` 명령이 있어도 엔진이 꺼져 있으면 로컬 이미지 빌드는 안 됩니다. 반면 이 프로젝트의 Actions 빌드는 GitHub 러너에서 수행하므로 PC Docker가 없어도 그 CI를 실행할 수 있습니다. JDK는 Java 빌드, JRE는 실행 환경이며 Dockerfile은 두 단계를 나눕니다.


| 왜 이 단계인가? | 정상 기준 |
| :--- | :--- |
| 명령을 수행할 로컬 도구와 실제 실행 엔진을 구분 | PowerShell 7, 필요한 CLI의 버전 출력 |

PowerShell **7**을 사용합니다. 처음 설치할 때 Windows 패키지 관리자를 사용할 수 있습니다. 아래는 설치 예시이며 이미 설치된 도구는 건너뜁니다.

```powershell
# 새 PC에 필요한 경우만 실행
winget install --id Microsoft.PowerShell --exact
winget install --id Git.Git --exact
winget install --id Amazon.AWSCLI --exact
winget install --id Hashicorp.Terraform --exact
winget install --id Kubernetes.kubectl --exact
winget install --id GitHub.cli --exact
```

설치 후 PowerShell 7을 새로 열어 PATH를 반영합니다. 현재 코드의 CI는 Terraform 1.16.2, kubectl 1.35 계열을 사용하며 Terraform 요구 범위는 1.12 이상 2 미만입니다. 실습 때 EKS·RDS 버전의 가용 여부도 확인합니다.

```powershell
$PSVersionTable.PSVersion
git --version
aws --version
terraform version
kubectl version --client
gh --version
```

직접 로컬 테스트를 하려면 JDK 17·Node.js·Python·Git Bash를 추가합니다. 직접 로컬 이미지 빌드를 할 때만 실행 중인 Docker 엔진이 필요합니다. Actions 빌드는 GitHub에서 하므로 PC Docker가 필수는 아닙니다. Helm CLI는 직접 chart를 점검할 때 사용하고 Terraform의 Helm provider 설치와는 별개입니다.

## 2. AWS·GitHub 인증과 저장소
### 이 단계의 원리 · 신원을 증명한 뒤 권한을 받음

AWS profile은 PC에 저장한 인증 설정의 이름입니다. IAM은 Identity and Access Management로 AWS에서 누가 무엇을 할 수 있는지 정합니다. ARN은 Amazon Resource Name으로 사용자·역할·클러스터 등 대상을 구분하는 식별자입니다. ARN은 비밀번호가 아닙니다.

STS는 Security Token Service이며 역할을 사용할 때 임시 자격증명을 발급합니다. IAM role은 사람·작업이 정해진 조건으로 빌려 쓰는 권한 묶음입니다. assumed-role ARN은 현재 세션을 나타내므로 EKS 관리 principal에 넣을 원래 IAM role ARN과 구분합니다.

GitHub 웹 로그인·gh 인증은 GitHub용입니다. AWS profile을 만들었다고 gh가 로그인되거나 앱 JWT가 생기지 않습니다. 로컬 구축 운영자, 이미지 게시 job, 배포 검증 job, 상품 서비스 Pod는 각각 다른 신원·권한 경로를 사용합니다. 실행용 역할을 좁혔다고 로컬 운영자 계정까지 최소 권한화됐다고 판단하지는 않습니다.


| 왜 이 단계인가? | 정상 기준 |
| :--- | :--- |
| AWS profile·GitHub 로그인·Git 원격을 연결 | 의도한 IAM principal과 repository 확인 |

AWS 콘솔 오른쪽 위 계정 ID가 `193644343848`인지 확인합니다. 기존 `default` 프로필을 재사용합니다. 새 PC는 계정에서 허용한 SSO 또는 IAM 인증으로 프로필을 준비합니다. IAM 키 방식이라면 `aws configure --profile default`의 입력창을 사용하고 키를 명령 인수·Git·문서에 붙이지 않습니다.

```powershell
$env:AWS_PROFILE = 'default'
$env:AWS_REGION = 'ap-northeast-2'
$env:AWS_PAGER = ''
aws sts get-caller-identity
gh auth login --hostname github.com --git-protocol https --web
gh auth status
```

작업 폴더가 이미 있으면 다시 clone하지 않습니다. 변경 사항이 있는 작업 트리에서 무조건 pull하지도 않습니다.

```powershell
# 폴더가 없을 때만:
# git clone https://github.com/yjeee-ghub/aws-msa-final-project-test.git C:\aws-msa-final-project-test
Set-Location 'C:\aws-msa-final-project-test'
git status --short
git fetch origin
```

관리자 ARN은 실제 IAM user 또는 role ARN이어야 합니다. STS 응답이 `assumed-role/...`이면 그 세션 ARN을 그대로 EKS 관리자 principal에 넣지 말고 대응하는 IAM role ARN을 확인합니다. 현재 구축 때는 `arn:aws:iam::193644343848:user/eks-user`를 사용했습니다.

## 3. 콘솔에서 도메인·이메일 준비
### 이 단계의 원리 · 주소 찾기와 HTTPS 신뢰 준비

DNS는 Domain Name System으로 사람이 읽는 이름을 접속 대상으로 찾는 체계입니다. Route 53 hosted zone은 특정 도메인의 DNS 레코드 묶음입니다. NS는 그 도메인의 DNS를 답할 네임서버이며 등록기관의 위임과 public zone이 맞아야 외부에서도 찾습니다.

CNAME은 다른 DNS 이름을 가리키는 레코드입니다. 여기서는 `_문자.… → …acm-validations.aws`가 ACM의 도메인 소유권·갱신 확인용입니다. A 레코드의 Alias는 서비스 이름을 ALB에 연결하는 AWS 기능입니다. 비슷하게 보이지만 인증과 실제 접속이라는 역할이 다르므로 둘 다 유지합니다.

ACM은 AWS Certificate Manager로 TLS 인증서를 관리합니다. TLS는 통신 암호화와 서버 신뢰 확인에 쓰이고 HTTPS는 TLS를 사용하는 HTTP입니다. 이 프로젝트는 ALB와 같은 서울 리전의 ACM 인증서를 사용합니다. server·argocd·grafana 서브도메인을 연결한 것이며 루트 aws-yjeee.com에 별도 홈페이지를 연결했다는 뜻은 아닙니다.

SES는 메일 발송 서비스이고 주소 검증은 도메인 HTTPS 인증과 다릅니다. SNS 구독 확인도 별개입니다. 한 메일에서 링크를 눌렀다고 세 인증이 동시에 완료되지 않습니다.


| 왜 이 단계인가? | 정상 기준 |
| :--- | :--- |
| DNS 위임·메일 소유권·수동/코드 소유 방식을 정함 | 기존 public zone과 올바른 주소 확인 |

AWS 콘솔의 리전은 서울을 사용합니다. Route 53은 글로벌 서비스입니다.

| 콘솔 위치 | 직접 할 일 | 확인 |
| --- | --- | --- |
| Route 53 → Hosted zones | 기존 `aws-yjeee.com` public zone 열기 | ID `Z0695291O7B7FDL23LFH` |
| 도메인 등록기관의 NS 설정 | 위 zone의 네임서버와 위임값 대조 | 다른 zone을 중복 생성하지 않음 |
| SES → Verified identities | 아래 두 방식 중 하나 결정 | `yoonjoung429@gmail.com` 사용 |

```powershell
Resolve-DnsName aws-yjeee.com -Type NS
```

**SES 방식 A — 오늘 구축한 방식:** `manage_ses_identities=true`로 Terraform이 이메일 ID를 만들고, 7단계에서 받은 인증 링크를 누릅니다. 콘솔에서는 상태를 관찰합니다.

**SES 방식 B — 새 환경에서 콘솔 생성 연습:** 서울 SES → Verified identities → Create identity → Email address에서 발신자·테스트 수신자 주소를 생성하고 인증 메일을 누릅니다. 이때 첫 infra apply 전부터 `manage_ses_identities=false`를 사용합니다. 같은 주소면 한 ID면 됩니다.

현재 Terraform이 이미 관리하는 ID에 방식 B를 적용하려고 true를 false로 바꾸면 삭제 계획이 생길 수 있습니다. **실행 중인 환경에서는 기존 소유 방식을 유지합니다.** SES sandbox에서는 수신자도 인증이 필요합니다. 임의 고객 발송은 운영 전환 여부를 별도로 확인합니다.

ACM 인증서·검증 CNAME은 Terraform이 생성합니다. 이 단계에서 같은 인증서를 콘솔로 하나 더 만들 필요는 없습니다.

## 4. state 전용 S3 준비
### 이 단계의 원리 · 코드와 실제 자원의 연결 기록

Terraform 코드는 원하는 구성이고 state는 어떤 resource 주소가 어떤 실제 자원을 관리하는지 기억하는 기록입니다. backend는 그 기록의 저장 장소입니다. state를 지워도 실제 자원은 남으며, 연결을 잃어 중복 생성·이름 충돌이 생길 수 있습니다.

보관 버킷을 생성하는 bootstrap 자체는 먼저 원격 보관소가 없으므로 local state를 사용합니다. 이후 AWS·Kubernetes 루트는 같은 버킷의 다른 key에 state를 저장합니다. 이는 환경 두 개가 아니라 역할이 다른 관리 기록 두 개입니다. Kubernetes 루트가 infra output을 읽으므로 AWS 생성이 선행합니다.

S3 versioning은 과거 객체 버전 보관, encryption은 저장 암호화, public access block은 공개 차단, TLS 정책은 전송 경로 제한입니다. 각각 다른 방어입니다. `.tflock` 잠금은 동시에 apply하는 충돌을 줄입니다. 주문 메일의 DynamoDB와 달리 이 state 잠금은 S3 네이티브 기능을 사용합니다.

import는 이미 존재하는 자원을 코드의 resource 주소에 연결합니다. 실제 설정을 모두 코드와 동일하게 바꿔주는 명령이 아니므로 import 뒤 plan을 읽습니다. `data`는 기존 대상을 조회하는 선언이며 직접 생성·삭제하는 resource와 다릅니다.


| 왜 이 단계인가? | 정상 기준 |
| :--- | :--- |
| Terraform이 실제 자원을 기억할 보관소를 먼저 준비 | 버킷 보안·versioning·bootstrap state 일치 |

state는 Terraform의 자원 관리 기록입니다. **현재 버킷·bootstrap state가 이미 있으면 재사용**하고, 없을 때 아래 A 또는 B 중 한 가지만 선택합니다. [state 설명](../07-terraform-state.md)

### A. Terraform으로 생성

```powershell
terraform '-chdir=terraform-state-bootstrap' init
terraform '-chdir=terraform-state-bootstrap' validate
terraform '-chdir=terraform-state-bootstrap' plan '-out=bootstrap.tfplan'
# 계획이 이 프로젝트의 신규 보관 버킷 구성인지 읽은 뒤 실행
terraform '-chdir=terraform-state-bootstrap' apply bootstrap.tfplan
```

bootstrap은 local state를 쓰므로 해당 state·backup을 개인 보안 위치에 보관합니다. Git에는 올리지 않습니다.

### B. 콘솔로 만들고 Terraform에 등록하는 학습 경로

**같은 이름 버킷이 아직 없을 때만** S3 콘솔 → Create bucket에서 다음처럼 설정합니다.

| 설정 | 값 |
| --- | --- |
| 이름·리전 | `final-tfstate-193644343848-ap-northeast-2` · 서울 |
| Object Ownership | Bucket owner enforced, ACL 비활성 |
| Block Public Access | 모두 켬 |
| Versioning | 켬 |
| Default encryption | SSE-S3 |

생성 후 Properties·Permissions에서 값을 확인합니다. 아래 명령은 실제 설정을 Terraform의 각 resource에 연결합니다. 이미 state에 있는 주소는 다시 import하지 않습니다.

```powershell
terraform '-chdir=terraform-state-bootstrap' init
terraform '-chdir=terraform-state-bootstrap' import aws_s3_bucket.state final-tfstate-193644343848-ap-northeast-2
terraform '-chdir=terraform-state-bootstrap' import aws_s3_bucket_versioning.state final-tfstate-193644343848-ap-northeast-2
terraform '-chdir=terraform-state-bootstrap' import aws_s3_bucket_server_side_encryption_configuration.state final-tfstate-193644343848-ap-northeast-2
terraform '-chdir=terraform-state-bootstrap' import aws_s3_bucket_public_access_block.state final-tfstate-193644343848-ap-northeast-2
terraform '-chdir=terraform-state-bootstrap' import aws_s3_bucket_ownership_controls.state final-tfstate-193644343848-ap-northeast-2
# Bucket policy는 아직 만들지 않았다면 import하지 않습니다. Terraform이 TLS 필수 정책을 추가합니다.
terraform '-chdir=terraform-state-bootstrap' plan '-out=bootstrap.tfplan'
terraform '-chdir=terraform-state-bootstrap' apply bootstrap.tfplan
```

콘솔에서 bucket policy도 이미 만들었다면 apply 전에 `aws_s3_bucket_policy.state` 주소로 같은 버킷 이름을 import해 총 6개 주소를 연결합니다. 존재하지 않는 정책을 import하지 않습니다. S3 콘솔에서 최종 정책의 `aws:SecureTransport=false` 거부를 확인합니다.

## 5. 처음 적용할 변수 준비
### 이 단계의 원리 · 의존성 때문에 처음에는 기능을 끔

앱은 이미지와 DB Secret이 있어야 실행되고, DNS는 ALB가 있어야 연결되며, 메일 소비자는 SES 인증 후 켜야 합니다. 그래서 초기 스위치는 단순 선택 사항이 아니라 준비되지 않은 대상을 먼저 사용하지 않게 하는 순서 제어입니다.

`.tfvars`는 Terraform 변수 입력 파일입니다. `TF_VAR_변수명` 환경변수도 입력 경로이며 이 노트는 비밀번호·키를 현재 프로세스에서 전달합니다. 파일에 값이 있어도 연결된 계정·backend가 자동으로 검증되는 것은 아니므로 사전 확인과 plan이 필요합니다.

ephemeral 입력은 Terraform 기록에 보존하지 않도록 하는 값의 수명 설정, write-only 속성은 읽어 state에 저장하지 않고 전달하는 속성입니다. 두 기능을 쓴다고 Kubernetes Secret이나 프로세스 메모리에서 값이 사라지는 것은 아닙니다. 다른 인프라 정보를 포함한 state·plan도 보호합니다.

GitHub OIDC subject는 신원 조건입니다. 현재 저장소의 owner/repository ID·main 조건을 AWS trust와 맞춥니다. 단순히 문자열이 긴 태그가 아니라 어느 작업에 역할을 내줄지를 정하는 보안 경계입니다.


| 왜 이 단계인가? | 정상 기준 |
| :--- | :--- |
| 서로 의존하는 기능을 준비 전에는 끄고 입력을 저장 | 비밀값 없는 local tfvars, 초기 스위치 false |

현재 환경의 tfvars는 이미 존재하므로 **다음 블록으로 덮어쓰지 않습니다.** 새 구축 시 두 파일이 없을 때만 만듭니다. 실제 파일은 Git에서 제외합니다.

```powershell
$taskIp = (Invoke-RestMethod 'https://checkip.amazonaws.com').Trim()
$taskAdminArn = 'arn:aws:iam::193644343848:user/eks-user'
if (Test-Path terraform/terraform.tfvars) { throw '기존 tfvars를 먼저 검토하세요.' }
@"
eks_public_access_cidrs = ["$taskIp/32"]
eks_admin_principal_arn = "$taskAdminArn"
alert_email = "yoonjoung429@gmail.com"
manage_db_password = true
customer_email_sender = "yoonjoung429@gmail.com"
customer_email_test_recipients = ["yoonjoung429@gmail.com"]
manage_ses_identities = true
customer_email_enabled = false
enable_website_dns = false
enable_management_dns = false
"@ | Set-Content terraform/terraform.tfvars -Encoding utf8
```

3단계 SES 방식 B라면 생성 전에 `manage_ses_identities=false`로 수정합니다. DNS·메일 소비자는 의존성이 준비될 때까지 false입니다.

```powershell
if (Test-Path terraform-k8s/terraform.tfvars) { throw '기존 tfvars를 먼저 검토하세요.' }
@'
github_repo_url = "https://github.com/yjeee-ghub/aws-msa-final-project-test.git"
github_revision = "main"
github_username = "yjeee-ghub"
github_repository_private = false
app_secret_revision = 2
enable_app_sync = false
enable_management_ingress = false
'@ | Set-Content terraform-k8s/terraform.tfvars -Encoding utf8
```

공개 저장소는 Argo 읽기 토큰이 필요 없습니다. 실제 private 저장소라면 관련 변수·읽기 토큰을 별도로 준비합니다. 현재 예시는 공개 저장소 기준입니다.

이 저장소의 OIDC subject 기본값은 아래와 같습니다. GitHub의 저장소 ID·owner ID·브랜치와 AWS 역할 신뢰 정책이 맞아야 합니다.

```text
repo:yjeee-ghub@336437888/aws-msa-final-project-test@1425157293:ref:refs/heads/main
```

```powershell
gh api repos/yjeee-ghub/aws-msa-final-project-test --jq '{id,owner_id:.owner.id,default_branch,private}'
```

새 저장소로 복제하거나 subject 설정·GitHub Environment를 바꾸면 실제 claim을 다시 확인합니다. 단순히 예전 형식의 `repo:owner/repo:ref:...`를 추정해서 넣지 않습니다.

## 6. AWS 인프라 생성
### 이 단계의 원리 · 네트워크·서버·데이터를 순서대로 연결

VPC는 전용 네트워크, subnet은 그 안의 IP 공간, AZ는 리전 안의 분리된 가용 영역입니다. CIDR의 `/32`는 IPv4 한 주소를 뜻합니다. public subnet은 인터넷 게이트웨이 경로를, private app subnet은 외부 직접 접속 없이 발신할 NAT 경로 등을 사용합니다. DB subnet은 DB 배치를 위한 별도 영역입니다.

IGW는 Internet Gateway, NAT는 Network Address Translation입니다. NAT Gateway는 private 자원의 인터넷 발신을 중계합니다. private이라고 인터넷에 절대 나가지 않는다는 뜻은 아닙니다. GitHub·이미지·패키지 접근과 공개 웹사이트의 수신 경로는 구분합니다. 현재 단일 NAT는 비용과 장애 경로의 절충입니다.

EKS는 AWS가 Kubernetes 관리 영역을 제공하는 서비스입니다. 노드는 앱을 실제로 실행할 EC2 서버이며 node group·ASG가 수명과 수를 관리합니다. 관리 API는 사용자의 쇼핑몰 주소와 별개입니다. private endpoint를 열고 외부 public endpoint는 관리 IP로 제한합니다.

SG(Security Group)는 허용 기반의 stateful 네트워크 규칙입니다. RDS 3306은 프로젝트 EKS 보안그룹에서 들어오는 경로를 허용합니다. private DB와 제한된 SG를 함께 사용하며, DB가 같은 VPC에 있다고 모든 연결이 자동으로 허용되는 것은 아닙니다.

RDS는 관리형 관계형 DB, MySQL은 여기서 사용하는 엔진입니다. member·product·ordering은 물리 RDS를 공유해도 서비스별 요청·트랜잭션 경계가 따로 있습니다. HTTP로 여러 서비스를 호출하는 과정이 모두 하나의 DB transaction이 되는 것은 아닙니다.

`init → validate → plan → apply`는 준비·구성 검사·차이 계산·실제 변경입니다. plan이 성공해도 권한·계정 한도·실제 용량 때문에 apply가 실패할 수 있어 콘솔 상태·waiter·재검증이 뒤따릅니다.


| 왜 이 단계인가? | 정상 기준 |
| :--- | :--- |
| 코드의 자원과 의존성을 실제 AWS에 생성 | Apply complete + EKS/RDS/ACM 등 콘솔 상태 확인 |

```powershell
terraform '-chdir=terraform' init
terraform '-chdir=terraform' workspace show
terraform '-chdir=terraform' validate
terraform '-chdir=terraform' plan '-out=infra.tfplan'
# 계정·생성·변경·삭제 대상을 검토한 뒤:
terraform '-chdir=terraform' apply infra.tfplan
terraform '-chdir=terraform' output
```

콘솔에서 결과를 따라가며 확인합니다.

| 콘솔 | 확인할 자원·설정 |
| --- | --- |
| VPC | Final-VPC, 두 AZ의 public·private·DB subnet, NAT·route table |
| EKS | Final-eks, AZ별 node group, private endpoint + 관리 IP 제한 |
| RDS | final-ordermsa-db, 비공개, MySQL, 관리형 Secret |
| ECR | 5개 서비스 저장소, 이미지 태그 덮어쓰기 제한 |
| IAM | 게시·조회·서비스별 역할, GitHub OIDC 신뢰 조건 |
| ACM | 웹사이트·관리 도메인 인증서 Issued |
| Route 53 | ACM 검증 CNAME 생성; 아직 서비스 A Alias는 없음 |
| SNS·SQS·Lambda·DynamoDB | 운영·주문 경로 분리, 소비자는 아직 비활성 |
| CloudTrail·CloudWatch | 관리 이력·EKS 로그·경보 구성 |

ACM 인증은 DNS 위임이 맞아야 끝납니다. 실패 시 콘솔 상태를 확인하고 동일 명령을 무조건 반복하지 않습니다. Lambda 예약 실행 한도 오류는 [문제 해결](../TROUBLESHOOTING.md)을 참고합니다.

## 7. 이메일 인증 완료
### 이 단계의 원리 · 메일 소유권과 실제 처리 경로

SNS(Simple Notification Service)는 토픽 메시지를 구독 대상에 전달하고, SQS(Simple Queue Service)는 처리할 메시지를 보관합니다. SES(Simple Email Service)는 실제 이메일 발송을 맡습니다. Lambda는 큐 메시지에 반응해 코드를 실행합니다. 이 역할을 나누면 일시적인 메일 장애가 주문 요청의 즉시 응답과 분리됩니다.

운영 SNS의 이메일 구독은 사람이 받는 경보 경로입니다. 주문 SNS의 구독자는 SQS이고, 주문 회원의 이메일은 이벤트 안에서 전달되어 Lambda→SES에서 사용합니다. 운영 토픽에 이메일을 구독했다고 모든 고객 메일이 직접 발송되는 구조가 아닙니다.

SQS visibility timeout은 처리 중 메시지를 잠시 숨기는 시간입니다. 성공 후 삭제되지 않으면 다시 처리될 수 있어 소비자는 중복을 고려합니다. DLQ(Dead-Letter Queue)는 반복 실패 메시지를 분리 보관합니다. 메시지를 콘솔에서 Receive하는 행동도 처리 흐름에 영향을 줄 수 있습니다.

DynamoDB는 이벤트 처리 기록을 보관하는 키 기반 DB입니다. lease는 처리권을 일정 시간 빌리는 방식, TTL은 보관 만료 기준입니다. SES가 수락한 직후 기록 전에 종료되는 틈은 남으므로 정확히 한 번 메일 도착을 보장하지 않습니다. 구독·주소 인증·발송 수락·도착을 나눠 검증합니다.


| 왜 이 단계인가? | 정상 기준 |
| :--- | :--- |
| AWS가 메일 소유권·구독 수신 의사를 확인 | SNS 실제 구독 ARN·SES Verified=true |

이메일에서 **AWS Notifications → Confirm subscription**, **SES 인증 메일 → 인증 링크**를 각각 누릅니다. 서로 다른 인증입니다.

```powershell
aws sns list-subscriptions-by-topic --topic-arn arn:aws:sns:ap-northeast-2:193644343848:Final-operations-alerts --query 'Subscriptions[].{Email:Endpoint,Subscription:SubscriptionArn}'
aws sesv2 get-email-identity --email-identity yoonjoung429@gmail.com --query '{Verified:VerifiedForSendingStatus,Status:VerificationStatus}'
```

SNS가 `PendingConfirmation`이 아닌 실제 구독 ARN이고 SES가 `Verified=true`여야 합니다. 메일 주소 오타는 apply 전에 확인합니다. 아직 `customer_email_enabled=false`를 유지합니다.

## 8. EKS 연결·비밀값 준비·운영 도구 설치
### 이 단계의 원리 · 클러스터 안의 도구와 Secret 전달

kubeconfig는 접속 대상·인증 방법을 PC에 기록한 설정이며 context는 선택한 클러스터·사용자·namespace 조합입니다. update-kubeconfig는 클러스터 생성 명령이 아닙니다. kubectl과 Terraform Kubernetes provider는 이 접근 경로·AWS 인증을 사용합니다.

namespace는 Kubernetes 자원을 나눠 관리하는 범위입니다. Pod는 컨테이너 실행 단위, Deployment는 원하는 replica·이미지·교체 정책을 유지하는 자원, Service는 Pod가 바뀌어도 찾을 수 있는 주소입니다. selector는 label이 맞는 Pod를 대상에 연결합니다. 잘못된 label은 정상 Pod가 있어도 요청 대상이 없는 원인이 됩니다.

Controller는 선언과 실제 상태를 계속 맞추는 제어 프로그램입니다. ALB Controller는 Ingress로 ALB를, EBS CSI는 PVC로 디스크를 준비합니다. Helm chart는 관련 설정·자원을 묶은 설치 패키지이며 Terraform Helm provider가 운영 도구를 설치합니다. 앱의 이미지 조합은 Kustomize가 관리하므로 모든 YAML을 같은 도구로 중복 apply하지 않습니다.

ESO(External Secrets Operator)는 외부 Secret을 읽어 Kubernetes Secret으로 동기화합니다. RDS가 만든 비밀번호를 Secrets Manager에 보관하고, 전용 역할을 가진 ESO가 `db-credentials/DB_PW`에 주입합니다. SecretStore는 외부 저장소 연결 방법, ExternalSecret은 어떤 값을 어떤 Secret으로 가져올지의 선언입니다.

IRSA는 IAM Roles for Service Accounts로 EKS의 service account 신원을 AWS 역할에 연결하는 방식입니다. 여기서 사용하는 EKS OIDC issuer와 GitHub job의 OIDC issuer는 다릅니다. 둘 다 임시 신원 연계를 사용하지만 신뢰 대상·subject가 다릅니다.


| 왜 이 단계인가? | 정상 기준 |
| :--- | :--- |
| kubeconfig로 연결하고 운영 도구·비밀값 연동을 설치 | 노드 Ready·도구 Running·ESO Ready |

```powershell
aws eks update-kubeconfig --name Final-eks --region ap-northeast-2 --profile default
kubectl config current-context
kubectl get nodes
. ./terraform-k8s/Prepare-Secrets.ps1
```

Prepare-Secrets는 기존 앱 Secret의 키를 재사용하고 최초에는 안전한 난수로 JWT·내부 키를 만듭니다. 현재 PowerShell의 TF_VAR 환경변수로 전달합니다. **같은 창에서 다음 plan·apply를 실행**하고 환경변수를 출력하지 않습니다. RDS 관리형 모드에서는 DB 비밀번호를 직접 입력하지 않습니다.

```powershell
terraform '-chdir=terraform-k8s' init
terraform '-chdir=terraform-k8s' validate
terraform '-chdir=terraform-k8s' plan '-out=tools.tfplan'
terraform '-chdir=terraform-k8s' apply tools.tfplan
kubectl wait externalsecret/database-credentials -n soldesk --for=condition=Ready --timeout=180s
kubectl get pods -A
```

ALB Controller·Autoscaler·ESO·Prometheus/Grafana/Alertmanager·Argo CD가 준비됩니다. 앱은 sync=false라 아직 배포하지 않습니다. ESO Ready가 아니면 앱부터 켜지 말고 SecretStore·IAM·Secret ARN·이벤트를 확인합니다.

## 9. 관리자 Secret 생성
### 이 단계의 원리 · 사용자 인증과 관리자 초기화

JWT(JSON Web Token)는 사용자가 로그인한 신원을 서명해 전달하는 토큰입니다. 서명은 위변조 확인용이며 token 내용 전체를 암호화한다는 뜻은 아닙니다. 비밀번호·Secret을 JWT에 넣거나 token 전체를 캡처하지 않습니다.

member가 로그인 자격을 확인해 token을 만들고 Gateway가 검증한 사용자 ID·권한을 백엔드에 전달합니다. 브라우저가 임의로 보낸 X-User-Role을 그대로 믿으면 권한을 위조할 수 있으므로 Gateway에서 제거·재구성합니다. 관리자 화면을 숨기는 것과 API 권한 검사는 별개여서 둘 다 필요합니다.

JWT 서명 키, Refresh 키, 내부 서비스 키, 관리자 비밀번호는 용도가 다릅니다. Refresh token은 새 접근 token 발급에, 내부 키는 서비스 사이의 보호된 API에 사용합니다. 공개 저장소를 Argo가 읽는 데 이 키들이 쓰이지는 않습니다.

관리자 Secret은 앱 시작 시 읽는 초기화 입력입니다. Secret만 바꿔도 이미 실행 중인 프로세스 환경변수가 즉시 바뀌지 않습니다. 관련 Pod를 새로 시작하고 실제 로그인으로 확인해야 값 교체가 완료됐다고 할 수 있습니다.


| 왜 이 단계인가? | 정상 기준 |
| :--- | :--- |
| 기본 공개 비밀번호 대신 본인 관리자 값을 주입 | Secret 이름·키 준비; 초기 앱 시작 전에 완료 |

```powershell
./app/msa/Prepare-Admin.ps1
```

숨겨진 입력창에서 12~64자 비밀번호를 입력합니다. 관리자 ID는 `admin`이며 이메일은 개인화한 주소가 들어갑니다. 최초 앱 배포 전에 준비합니다. 이미 실행 중인 관리자 비밀번호를 바꿀 때만 member Deployment를 재시작합니다.

```powershell
# 비밀번호를 의도적으로 변경한 경우만:
# kubectl rollout restart deployment/member-depl -n soldesk
```

당일 자동 실행에서는 관리자·JWT 키의 로컬 복구본도 Windows DPAPI로 보호한 `.tools/runtime-secrets.clixml`에 보관했습니다. 직접 실습에서는 제공된 Secret 준비 스크립트와 기존 Secret 재사용으로 실행할 수 있습니다. 기존 복구본을 다른 계정·다른 PC에서 그대로 해독할 수 있다고 가정하지 않습니다.

## 10. GitHub 변수·팀원·보호 규칙 설정
### 이 단계의 원리 · 검토·자동화 인증·main 보호

PR(Pull Request)은 변경을 합치기 전에 검토하는 요청입니다. branch protection은 main에 바로 반영되지 않도록 검사·리뷰 등의 조건을 서버에서 강제합니다. CODEOWNERS는 검토 담당자를 표현하지만 파일만 추가한다고 보호 규칙이 활성화되지는 않습니다.

CI(Continuous Integration)는 테스트·빌드·설정 검사입니다. CD는 지속 전달·배포 흐름을 뜻하며, 여기서는 사람 승인 후 Argo가 Git 선언을 반영합니다. 코드 리뷰 승인과 봇 PR의 workflow 실행 승인은 다른 관문입니다.

GITHUB_TOKEN은 Actions가 GitHub에 인증하는 기본 임시 토큰입니다. GitHub App 설치 토큰은 별도 App 신원으로 PR 생성 등을 수행합니다. App ID·private key를 준비하면 실행 때 단기 토큰을 발급할 수 있지만 현재 App 연동은 미설정입니다. 이 App이 AWS 역할이나 검사 컴퓨터를 대신 만들어주지는 않습니다.

AWS OIDC(OpenID Connect)는 GitHub가 job 신원을 증명하면 AWS가 trust 조건을 검사해 역할의 임시 자격증명을 내주는 경로입니다. ECR 게시 역할과 EKS 배포 조회 역할을 분리해, 검사 job이 이미지 게시·앱 변경까지 할 필요가 없게 합니다. 권한 설정과 실제 거부 검증도 구분합니다.


| 왜 이 단계인가? | 정상 기준 |
| :--- | :--- |
| 봇 인증과 사람의 리뷰·main 보호를 각각 설정 | 역할 ARN·실제 팀원·required-ci·보호 규칙 일치 |

GitHub 저장소 → Settings → Secrets and variables → Actions에서 아래 **Variables**를 등록합니다. 역할 ARN은 비밀키가 아닙니다.

```powershell
$publishRole = terraform '-chdir=terraform' output -raw github_actions_role_arn
$verifyRole = terraform '-chdir=terraform' output -raw github_deploy_check_role_arn
gh variable set AWS_ROLE_TO_ASSUME --repo yjeee-ghub/aws-msa-final-project-test --body $publishRole
gh variable set AWS_DEPLOY_CHECK_ROLE_ARN --repo yjeee-ghub/aws-msa-final-project-test --body $verifyRole
# 최초 구축에서만. 이미 실행 중인 검증 설정을 이유 없이 끄지 않습니다.
gh variable set ENABLE_DEPLOY_CHECKS --repo yjeee-ghub/aws-msa-final-project-test --body false
```

Settings → Actions → General에서 워크플로의 PR 생성 허용 옵션을 켭니다. 코드의 job별 permissions가 실제 토큰 권한을 제한합니다. Settings → Collaborators에서 팀원을 write 권한으로 초대하고 팀원이 초대를 수락합니다. 코드 작성자 본인의 리뷰는 다른 팀원의 승인 요구를 충족하지 않습니다.

처음에는 `required-ci`가 PR에서 실행되는지 확인한 다음 보호 규칙을 적용합니다. 현재 저장소는 이미 적용돼 있습니다.

```powershell
./scripts/github/Set-ReviewRules.ps1
# 출력 규칙·팀원·지원 요금제·검사 실행을 확인한 뒤 필요한 경우만:
./scripts/github/Set-ReviewRules.ps1 -Apply
```

콘솔에서는 Settings → Branches의 main protection에서 required-ci, 승인 1명, 최신 push 이후 승인, 관리자 적용·강제 push 차단을 확인합니다. `.github/CODEOWNERS`도 실제 담당자와 맞춥니다.

### 선택: GitHub App 생성·연동

**현재 미적용인 후속 자동화입니다.** 이 단계를 하지 않아도 릴리스 PR을 만들 수 있지만 기본 토큰으로 만든 PR 검사에 실행 승인이 생길 수 있습니다. 사람의 코드 리뷰와는 다릅니다.

1. GitHub 계정 Settings → Developer settings → GitHub Apps → New GitHub App.
2. 프로젝트용 고유 이름·홈페이지 URL을 입력합니다. webhook으로 러너를 만들지 않는 현재 용도라면 webhook을 비활성화합니다.
3. Repository permissions: Contents와 Pull requests를 Read and write, Metadata는 기본 Read로 둡니다. 불필요한 관리 권한은 주지 않습니다.
4. App 생성 후 App ID를 확인하고 Private key를 생성해 개인 보안 경로에 저장합니다.
5. Install App에서 **이 저장소만** 선택합니다.
6. 저장소 Actions Variables에 `RELEASE_APP_ID`, Actions Secrets에 `RELEASE_APP_PRIVATE_KEY`를 등록합니다. 키 본문은 Secret 입력창에만 넣습니다.

workflow는 설정이 있으면 App 설치 토큰을 임시 발급받아 릴리스 PR 생성에 사용합니다. 키 파일을 Git에 넣거나 채팅으로 보내지 않습니다. App이 사람 리뷰를 대신하거나 내부 러너를 생성해 주는 것은 아닙니다. [공식 토큰 action](https://github.com/actions/create-github-app-token)

## 11. 이미지가 이미 있으면 재사용, 없으면 최초 전체 빌드
### 이 단계의 원리 · 소스를 이미지로 만들고 결과물을 추적

이미지는 프로그램·라이브러리·실행 환경을 묶은 패키지이고 컨테이너는 그 이미지로 실행 중인 프로세스입니다. ECR(Elastic Container Registry)은 보관소, EKS는 실행 환경입니다. ECR에 이미지가 있다고 Pod가 자동 생성되는 것은 아닙니다.

Dockerfile의 JDK 단계는 Gradle로 JAR를 만들고 JRE 단계는 그 결과를 실행합니다. 빌드할 때 의존성·기반 이미지가 달라질 수 있으므로 같은 소스에서 매번 재빌드한 결과가 같다고 가정하지 않습니다. 이 CI는 테스트 후 저장한 이미지 산출물을 게시 단계에 전달해 다시 빌드하지 않습니다.

tag는 이름표입니다. commit SHA 태그는 소스 추적에 좋고 ECR immutable 설정은 덮어쓰기를 제한합니다. digest는 이미지 manifest의 SHA-256 식별값으로 특정 결과물을 선택합니다. 소스 SHA와 digest는 둘 다 길어도 서로 다른 값입니다. Kustomize에 digest를 지정하면 승인한 이미지를 명확히 선택할 수 있습니다.

`deploy/release.json`은 서비스별 source·digest를 기록하고 `kustomization.yaml`은 실제 이미지 선택에 사용합니다. 다섯 서비스가 반드시 같은 source SHA일 필요는 없습니다. 이전 버전 선언이 Git에 있어도 ECR에서 해당 이미지를 지웠다면 바로 복구할 수 없으므로 보관 정책이 필요합니다.


| 왜 이 단계인가? | 정상 기준 |
| :--- | :--- |
| 실행할 이미지가 현재 ECR에 있는지 먼저 확인 | 5개 서비스의 필요한 digest 존재 또는 최초 게시 성공 |

```powershell
Get-Content deploy/release.json
aws ecr describe-images --repository-name member-service --query 'imageDetails[].{Tags:imageTags,Digest:imageDigest}'
```

5개 서비스 모두 manifest의 digest가 현재 ECR에 있는지 확인합니다. 이미 준비돼 있으면 불필요하게 full build를 반복하지 않습니다. ECR 태그가 immutable이므로 같은 SHA로 다시 게시하면 충돌할 수 있습니다.

새 ECR이 비어 있거나 새 소스의 전체 게시가 필요할 때 GitHub → Actions → Test and publish changed services → Run workflow → main, full_build=true를 선택합니다.

```powershell
# 필요한 최초 구축 시만:
gh workflow run build-push.yml --ref main -f full_build=true
gh run list --workflow build-push.yml --limit 5
```

테스트·빌드·ECR 게시 성공 후 봇의 `release/...` PR을 확인합니다. 최초 구축 중 main이 바뀌면 오래된 소스를 게시하지 않도록 거부될 수 있습니다. 실패 원인을 보고 새 main 기준으로 다시 준비합니다.

## 12. 배포 PR 검사·리뷰·병합
### 이 단계의 원리 · 코드 변경과 배포할 조합을 나눠 검토

소스 PR을 검토해 main에 합친 다음 CI가 이미지를 만들고, 릴리스 PR은 그 이미지를 배포 선언에 넣는 작업입니다. 빌드 성공만으로 고객 요청이 정상인지 알 수 없고, 코드 승인만으로 실제 배포 조합이 검토됐다고 할 수 없어 관문을 나눕니다.

릴리스 PR의 파일에는 source·digest·실행 정보가 들어갑니다. 팀원은 변경 서비스, CI, DB/API 호환성, 이전 이미지 보관을 확인합니다. 필수 검사를 통과한 최신 변경에 다른 사람이 승인해야 정상 병합합니다. 보호 우회나 본인 대신 자동 승인을 사용하지 않습니다.

GitOps는 Git 선언을 실제 운영 상태의 기준으로 사용하는 방식입니다. Argo CD가 Git을 읽어 동기화하고 self-heal은 사람이 직접 바꾼 앱 설정을 다시 Git과 맞출 수 있습니다. 따라서 운영 앱의 실패 실습·복구도 소유 경계를 지켜야 합니다. 별도 lab namespace는 운영 Argo가 관리하는 앱과 구분한 연습 공간입니다.

Git 기록을 되돌리는 것, 실행 이미지 조합을 바꾸는 것, DB 데이터를 복원하는 것은 서로 다른 복구입니다. 이미지 rollback PR이 데이터·Terraform까지 원복시키는 것이 아닙니다.


| 왜 이 단계인가? | 정상 기준 |
| :--- | :--- |
| 소스와 별개로 실행할 이미지 조합을 검토 | 검사 성공·최신 변경 타인 승인·정상 병합 |

GitHub PR 화면에서 서비스별 source·digest, CI 결과, DB 호환성을 확인합니다. 기본 GITHUB_TOKEN으로 만든 PR 검사가 `action_required`이면 Actions의 실행 승인 안내를 먼저 처리합니다. GitHub App 방식은 이 추가 승인 문제를 줄입니다. 팀원의 `Approve`는 별도로 필요합니다.

```powershell
gh pr list --repo yjeee-ghub/aws-msa-final-project-test
$prNumber = Read-Host '반영할 배포 PR 번호'
gh pr checks $prNumber
gh pr view $prNumber --json reviewDecision,headRefOid,mergeable
# 실제 팀원 승인과 required-ci 성공 후에만, 보호 우회 옵션 없이:
gh pr merge $prNumber --merge
```

이미 병합된 PR #1을 다시 처리하지 않습니다. 병합 후 작업 트리가 깨끗할 때 main을 갱신합니다.

```powershell
git status --short
git switch main
git pull --ff-only origin main
```

## 13. 앱 동기화·관리 Ingress 활성화
### 이 단계의 원리 · 원하는 상태가 실제 요청 가능한 상태가 되기까지

Deployment는 ReplicaSet을 통해 지정한 Pod를 유지합니다. RollingUpdate는 새 Pod를 준비하면서 기존 Pod를 교체합니다. maxSurge는 잠시 추가할 수 있는 수, maxUnavailable은 준비되지 않아도 허용하는 수입니다. 프런트엔드는 replica 2·surge 1·unavailable 0이지만 새 Pod를 놓을 공간이 없으면 진행이 멈출 수 있습니다.

startupProbe는 초기 시작을 기다리고, readinessProbe는 요청을 받을 준비를 판단하고, livenessProbe는 프로세스를 재시작할지 판단합니다. DB 단절을 readiness에 반영하고 liveness와 분리하면 DB 때문에 앱을 끝없이 재시작하는 악순환을 줄입니다. 다만 DB 초기 연결에 실패해 앱 자체가 기동하지 못하면 Probe URL도 안 열릴 수 있습니다.

Running은 프로세스가 실행 중이라는 상태이고 Ready·사용 가능 replica·실제 API 성공은 별도입니다. PDB(Pod Disruption Budget)는 유지할 최소 수 등의 자발적 eviction 제약이며 갑작스러운 서버 장애나 모든 Pod 삭제·모든 rollout을 막는 만능 보장이 아닙니다.

CPU requests는 배치와 HPA 비율 기준, limits는 사용 상한입니다. 1000m는 CPU 1개, 500m는 반 코어입니다. request 500m에 300m를 쓰면 CPU HPA 기준 약 60%입니다. 메모리 한도를 넘겨 OOMKilled가 될 수 있고, Exit 137만으로 OOM을 확정하지 않고 종료 reason을 함께 봅니다.

HPA(Horizontal Pod Autoscaler)는 Metrics Server 지표로 Pod 수를 바꿉니다. 현재는 member 1~3개·60%이며 Prometheus 자체가 이 HPA의 직접 공급자가 아닙니다. CA(Cluster Autoscaler)는 배치할 수 없는 Pod·requests·배치 조건으로 노드를 조절합니다. CPU가 높거나 Pod가 늘었다는 사실만으로 항상 노드가 추가되는 것은 아닙니다.


| 왜 이 단계인가? | 정상 기준 |
| :--- | :--- |
| 준비된 이미지·Secret을 Argo가 앱으로 실행 | Synced/Healthy·앱 Ready·공유 ALB 주소 |

`terraform-k8s/terraform.tfvars`의 아래 두 값만 수정합니다. 기존 다른 값은 유지합니다.

```hcl
enable_app_sync = true
enable_management_ingress = true
```

```powershell
. ./terraform-k8s/Prepare-Secrets.ps1
terraform '-chdir=terraform-k8s' plan '-out=apps.tfplan'
terraform '-chdir=terraform-k8s' apply apps.tfplan
kubectl annotate application final-apps -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl get application final-apps -n argocd
kubectl get deployments,pods -n soldesk
kubectl get ingress -A
```

Deployment별로 준비 완료를 확인합니다. Pending이면 이미지가 아니라 메모리·Pod 수·AZ 제약 문제일 수도 있습니다.

```powershell
kubectl rollout status deployment/member-depl -n soldesk --timeout=300s
kubectl rollout status deployment/product-depl -n soldesk --timeout=300s
kubectl rollout status deployment/ordering-depl -n soldesk --timeout=300s
kubectl rollout status deployment/apigateway-depl -n soldesk --timeout=300s
kubectl rollout status deployment/frontend-depl -n soldesk --timeout=300s
aws elbv2 describe-load-balancers --names final-shared-alb --query 'LoadBalancers[].{DNS:DNSName,State:State.Code}'
```

일반 후속 배포에서 sync는 이미 켜져 있으므로 매번 Terraform을 실행해 켤 필요가 없습니다. 당시 구축에서는 관리 Ingress를 먼저 켜 ALB를 준비한 후 앱을 켰습니다. 이 문서는 앱·도구 준비 후 ALB 생성 확인이라는 동일 의존성을 따릅니다.

## 14. ALB가 생긴 다음 DNS·메일 소비자 활성화
### 이 단계의 원리 · 사용자 요청의 실제 경로

브라우저는 DNS로 server 주소를 찾고 ALB의 HTTPS listener에 연결합니다. listener는 수신 port·TLS 처리를, rule은 host·path에 따른 target group 선택을 맡습니다. target group health와 Kubernetes readiness가 모두 요청 전달에 영향을 줍니다.

Ingress는 외부 HTTP 요청 규칙이고 ALB Controller는 그것을 AWS ALB로 구현합니다. Service의 selector가 앱 Pod를 찾고, ALB target-type ip는 Pod IP로 전달합니다. `/`는 frontend, `/member-service`·`/product-service`·`/ordering-service`는 apigateway로 가며 Gateway의 StripPrefix가 접두어를 제거한 뒤 실제 백엔드 경로로 보냅니다.

따라서 외부 상품 API는 `/product-service/product/list`, 상품 Pod에 직접 port-forward한 API는 `/product/list`입니다. 같은 앱도 어느 입구를 쓰는지에 따라 경로가 달라집니다. localhost port-forward는 공개 DNS·ALB·외부 TLS를 거치지 않으므로 그것만 성공했다고 외부 접속까지 검증한 것은 아닙니다.

외부 HTTPS는 ALB의 인증서로 보호하고 Argo backend는 내부 HTTPS를 사용합니다. 모든 서비스 간 통신에 mTLS가 적용된 구조는 아닙니다. 현재 JDBC URL에는 `useSSL=false`가 있어 DB 연결의 네트워크 제한과 전송 TLS를 구분해야 합니다. private RDS라는 사실이 DB 전송 암호화까지 자동 보장하는 것은 아닙니다.


| 왜 이 단계인가? | 정상 기준 |
| :--- | :--- |
| ALB 생성 후 실제 접속 주소·인증된 메일 소비자를 연결 | DNS Alias·HTTPS 200·mapping Enabled |

먼저 기존 A 레코드가 있는지 확인합니다. 같은 이름이 이미 존재하면 state에서 관리 중인지 확인하고, 미관리 기존 레코드는 import 검토 후 진행합니다. 새 이름으로 중복 생성하거나 덮어쓰지 않습니다.

```powershell
aws route53 list-resource-record-sets --hosted-zone-id Z0695291O7B7FDL23LFH --query "ResourceRecordSets[?Type=='A']"
terraform '-chdir=terraform' state list
```

`terraform/terraform.tfvars`에서 아래 값만 true로 수정합니다. SES Verified가 아직 false라면 메일 소비자는 켜지 않습니다.

```hcl
enable_website_dns = true
enable_management_dns = true
customer_email_enabled = true
```

```powershell
terraform '-chdir=terraform' plan '-out=connect.tfplan'
terraform '-chdir=terraform' apply connect.tfplan
./scripts/ops/Test-DeploymentHttps.ps1
Invoke-WebRequest 'https://argocd.aws-yjeee.com/healthz' | Select-Object StatusCode
Invoke-WebRequest 'https://grafana.aws-yjeee.com/api/health' | Select-Object StatusCode
```

Route 53 콘솔에 서비스별 A Alias와 ACM 인증 CNAME이 함께 보이는 것이 정상입니다. DNS 전파·ALB 대상 health를 기다린 뒤 재확인하고 TLS 검증을 생략해서 성공 처리하지 않습니다.

## 15. 내부 일회용 러너로 배포 검증
### 이 단계의 원리 · 내부 검사 컴퓨터의 수명과 권한

runner는 Actions job의 명령을 실제 실행하는 컴퓨터입니다. GitHub 표준 러너는 우리 관리 PC IP도 VPC 내부도 아니므로 제한한 EKS 관리 API에 직접 닿기 어렵습니다. 그래서 승인된 main을 검사하는 일회용 Pod를 내부에 띄웁니다. 앱 배포 자체는 여전히 Argo가 맡습니다.

러너는 GitHub로 나가 작업을 받아오며 외부에서 러너에 들어오는 별도 port를 열 필요는 없습니다. 네트워크 도달 가능성과 권한은 다릅니다. GitHub OIDC→IAM 조회 역할→EKS Access Entry→Kubernetes RBAC를 거쳐 지정 Deployment·final-apps만 읽도록 구성합니다. API 인증 성공이 관리자 권한을 의미하지 않습니다.

SA는 ServiceAccount로 Pod의 Kubernetes 신원입니다. 자동 token 주입을 끄고 job의 의도한 인증 경로를 사용합니다. non-root는 컨테이너를 일반 사용자로 실행하고 privilege escalation·Linux capabilities·system call 범위도 제한합니다. 호스트 Docker socket을 주지 않아 노드 컨테이너 엔진 제어 경로를 줄입니다. 컨테이너가 완전한 보안 격리 경계가 된다는 뜻은 아닙니다.

한 job 후 GitHub 등록이 해제되는 것과 Pod·등록 Secret 삭제는 별개입니다. 현재 자동 공급·정리 컨트롤러는 없으므로 다음 검사 전에 새 러너가 필요합니다. 기존 queued 작업이 있는데 새 workflow를 또 보내면 중복·취소·러너 수명 혼동이 생길 수 있어 먼저 목록을 봅니다.

검증은 Argo의 정확한 revision·Synced·Healthy, 선언한 다섯 이미지·replica, TLS·HTML·상품 JSON을 대조합니다. 이것은 실제 주문·메일 도착·DB 복원을 대신하지 않습니다. 검사가 실패해도 자동으로 DB나 이미지를 되돌리지 않습니다.


| 왜 이 단계인가? | 정상 기준 |
| :--- | :--- |
| 승인된 버전이 실제 실행되는지 내부 경로에서 검사 | job 성공·등록 해제·완료 Pod/Secret 정리 |

첫 구축에서는 DNS·앱이 정상인 지금 활성화합니다. 후속 배포에서는 **릴리스 PR을 병합하기 전에 러너를 시작**하면 push 검사가 작업을 받을 수 있습니다. [러너·OIDC의 의미](../14-security-and-verification.md)

```powershell
gh auth status
./scripts/ops/Start-DeployCheckRunner.ps1
kubectl get pods -n deploy-check-runners
gh api repos/yjeee-ghub/aws-msa-final-project-test/actions/runners --jq '.runners[] | {name,status,busy}'
gh variable set ENABLE_DEPLOY_CHECKS --repo yjeee-ghub/aws-msa-final-project-test --body true
```

현재 러너는 1개 job을 처리합니다. 이미 main push로 검사가 queued/running이면 수동 실행을 추가하지 말고 그 작업을 확인합니다. 첫 구축처럼 자동 검사가 skip됐고 기다리는 작업이 없을 때만 수동 실행합니다.

```powershell
gh run list --workflow deploy-check.yml --limit 5
# 실행할 작업이 없을 때만:
gh workflow run deploy-check.yml --ref main
gh run list --workflow deploy-check.yml --limit 5
$runId = Read-Host '이번 검증 실행 ID'
gh run watch $runId --exit-status
```

검사는 Argo revision·동기화·Healthy·5개 이미지·replica·TLS·HTML·상품 JSON을 확인합니다. 검증 러너는 배포 수정·Secret 조회를 하지 않습니다.

성공 후 완료된 **이번 러너 이름만** 지정해 정리합니다. 사용 중인 러너를 지우지 않습니다.

```powershell
kubectl get pods -n deploy-check-runners
$runnerName = Read-Host '이번에 완료된 deploy-check-... Pod 이름'
$runnerPhase = kubectl get pod $runnerName -n deploy-check-runners -o jsonpath='{.status.phase}'
if ($runnerPhase -notin @('Succeeded','Failed')) { throw '아직 완료된 Pod가 아닙니다.' }
kubectl delete pod $runnerName -n deploy-check-runners
kubectl delete secret $runnerName -n deploy-check-runners
```

정상 일회용 러너는 GitHub 등록이 자동 해제됩니다. 기동 실패로 등록이 남으면 GitHub Settings → Actions → Runners에서 해당 이름만 확인해 정리합니다. 현재는 이 생성·정리 절차가 자동화되지 않았습니다.

## 16. 브라우저와 명령어로 실제 기능 확인
### 이 단계의 원리 · 주문 한 번이 여러 상태를 통과함

사용자의 HTTP 주문은 Gateway에서 인증되고 주문 서비스가 회원·상품 서비스를 호출합니다. 재고는 예약·확정·해제 상태를 구분하고 주문도 처리 중·확정 중·보상 중·완료/실패 등을 관리합니다. 서비스 응답 유실이나 프로세스 장애에서 이미 수행한 작업과 아직 수행하지 않은 작업을 구분해야 하기 때문입니다.

멱등성은 같은 요청을 반복해도 효과가 중복되지 않는 성질입니다. Idempotency-Key는 동일 회원의 요청을 구분하며 같은 내용의 재시도에 유지합니다. 새 주문에 매번 같은 키를 쓰거나, 응답을 못 받았다고 새 키로 다시 보내면 의도와 달라집니다. 202는 처리 중이므로 같은 주문을 조회하고, 201·ORDERED와 실패를 구분합니다.

DB transaction은 한 DB 작업 묶음의 원자성을 다루고, HTTP를 건너 여러 서비스까지 자동으로 확장되는 보장은 아닙니다. 이 앱의 상태·예약·보상·복구 worker는 중간 실패를 나눠 처리합니다. 복구가 끝나기 전에 무조건 재고를 되돌리면 이미 확정한 작업과 충돌할 수 있어 상태별 판단이 필요합니다.

Outbox는 주문 처리와 관련 이벤트를 DB에 기록하고 나중에 발행하는 방식입니다. 주문은 저장됐는데 SNS 전송 직전에 프로세스가 종료돼 이벤트를 놓치는 구간을 줄입니다. 발행 worker가 재시도하고 영구 실패는 해당 이벤트의 원인 분석·선택 재처리가 필요합니다.

검증은 화면 메시지보다 재조회 결과를 기준으로 합니다. 같은 productId의 재고·두 orderId·Outbox eventId·DynamoDB SENT·메일 주문 번호를 연결하면 사용자 동작과 처리 경로가 하나로 이어집니다. 테스트 결과를 다른 계정·다른 날짜의 ID와 섞지 않습니다.


| 왜 이 단계인가? | 정상 기준 |
| :--- | :--- |
| 화면과 API의 실제 업무 결과를 대조 | 같은 주문 ID·재고 10→9→9·이미지 조회·메일 처리 |

브라우저에서 쇼핑몰 → 관리자 로그인 → 테스트 상품·이미지 등록 → 주문 → 주문 내역을 확인합니다. 관리자 ID는 `admin`, 비밀번호는 9단계에서 입력한 값입니다. Secret의 원문을 보고서에 적지 않습니다.

중복 요청은 다음 명령으로 정확히 비교할 수 있습니다. 이 실습은 **테스트 상품 1개·주문 1개를 실제로 생성하며 인증된 주소로 주문 메일을 보낼 수 있습니다.** 한 번 성공했다면 같은 실습을 반복할 필요는 없습니다. PowerShell 7과 준비된 관리자 Secret을 사용합니다.

```powershell
$base = 'https://server.aws-yjeee.com'
$s = kubectl get secret final-admin-config -n soldesk -o json | ConvertFrom-Json
$pw = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($s.data.'admin-password'))
$loginBody = @{loginId='admin';password=$pw} | ConvertTo-Json
$login = Invoke-RestMethod "$base/member-service/member/doLogin" -Method Post -ContentType application/json -Body $loginBody
$headers = @{Authorization="Bearer $($login.token)"}
$pw=$null; $loginBody=$null; $s=$null

# 간단한 1픽셀 PNG. 외부 이미지를 내려받지 않고 업로드 확인
$imagePath = Join-Path $env:TEMP ('deployment-test-'+[guid]::NewGuid().ToString('N')+'.png')
[IO.File]::WriteAllBytes($imagePath,[Convert]::FromBase64String('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aWhoAAAAASUVORK5CYII='))
$form = @{name='Deployment verification product';category='TEST';description='DevOps smoke test';price='1000';stockQuantity='10';imageFile=(Get-Item $imagePath)}
$productId = Invoke-RestMethod "$base/product-service/product/create" -Method Post -Headers $headers -Form $form
Remove-Item -LiteralPath $imagePath

$headers['Idempotency-Key'] = 'rehearsal-'+[guid]::NewGuid().ToString('N')
$orderBody = @{productId=$productId;productCount=1} | ConvertTo-Json
$order = Invoke-RestMethod "$base/ordering-service/ordering/create" -Method Post -Headers $headers -ContentType application/json -Body $orderBody
# 202 처리 중이면 같은 주문 ID를 조회. 새 키로 재주문하지 않음
for ($i=0; $i -lt 30 -and $order.status -notin @('ORDERED','FAILED'); $i++) {
    Start-Sleep -Seconds 2
    $order = Invoke-RestMethod "$base/ordering-service/ordering/$($order.id)" -Headers $headers
}
if ($order.status -ne 'ORDERED') { throw '주문 상태·로그를 확인하세요.' }
$repeat = Invoke-RestMethod "$base/ordering-service/ordering/create" -Method Post -Headers $headers -ContentType application/json -Body $orderBody
$product = Invoke-RestMethod "$base/product-service/product/$productId"
if ($order.id -ne $repeat.id -or $product.stockQuantity -ne 9) { throw '멱등성·재고 검증 실패' }
$order | Select-Object id,status,quantity
$product | Select-Object id,name,stockQuantity,imageUrl
$headers=$null; $login=$null
```

HTTP 응답 본문이나 환경변수 전체를 공유하지 않습니다. 상품 이미지 URL을 브라우저로 열고, 테스트 상품·주문 번호와 재고만 기록합니다.

메일의 처리 상태와 큐를 확인합니다. 주문 직후에는 비동기 처리 대기 시간이 있습니다.

```powershell
aws dynamodb scan --table-name Final-order-email-dedup --projection-expression 'eventId,#s' --expression-attribute-names '{"#s":"status"}'
aws sqs get-queue-attributes --queue-url https://sqs.ap-northeast-2.amazonaws.com/193644343848/Final-order-notifications --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible
aws sqs get-queue-attributes --queue-url https://sqs.ap-northeast-2.amazonaws.com/193644343848/Final-order-notifications-dlq --attribute-names ApproximateNumberOfMessages
```

SES 수락·DynamoDB SENT와 실제 받은편지함 도착은 별개입니다. 실습 규모가 커지면 전체 scan보다 해당 eventId 조회를 사용합니다.

## 17. 관리 화면·현재 상태·최종 정합성
### 이 단계의 원리 · 정상 판단에 쓰는 세 종류의 관측

metric은 시간에 따라 수집하는 숫자, log는 사건·오류 메시지 기록, event는 Kubernetes 자원의 배치·시작·실패 변화입니다. 그래프의 이상 시각으로 범위를 좁히고 그 시각의 event·log를 읽는 방식으로 함께 사용합니다.

Prometheus는 HTTP endpoint에서 지표를 주기적으로 수집하고 시계열로 보관합니다. ServiceMonitor는 Prometheus Operator가 어떤 Service·port·path를 수집할지 정하는 선언입니다. 이 프로젝트는 soldesk의 monitoring 라벨을 가진 Service와 `/actuator/prometheus`를 사용합니다. Pod annotation만으로 모든 대상이 자동 수집된다고 가정하지 않습니다.

Grafana는 Prometheus 등 데이터 소스에 질의해 패널을 그립니다. 대시보드 저장과 원래 시계열 저장은 다른 일입니다. PromQL은 지표 질의 언어이며 label·시간 범위·수집 주기가 맞아야 의미가 있습니다. `up=0`과 series 없음, 요청이 없어 0인 것과 수집 실패를 구분합니다. CPU·memory·HTTP·Ready를 같은 절대 시각으로 비교합니다.

Alertmanager는 Prometheus가 평가한 알림을 묶어 전달하고 SNS가 수신 대상에 보냅니다. CloudWatch는 AWS 지표·로그·경보, CloudTrail은 누가 어떤 AWS API 작업을 했는지의 감사 기록입니다. EKS control plane 로그가 있다고 앱 stdout도 모두 CloudWatch에 수집된 것은 아닙니다.

마지막 plan의 No changes는 Terraform이 관리하는 코드·state·자원의 정합성입니다. 그 밖의 lab 자원이나 고객 기능까지 모두 정상이라는 뜻은 아닙니다. 별도 HTTP·데이터·잔여 자원 조회를 함께 기록합니다.


| 왜 이 단계인가? | 정상 기준 |
| :--- | :--- |
| 사용자 기능과 인프라 정합성을 구분해 마지막 확인 | 현재 상태·No changes·비밀 환경변수 정리 |

비밀번호를 잊었을 때만 본인 인증 PC에서 아래 원문을 확인합니다. 출력은 다른 사람에게 공유하지 않습니다.

```powershell
# Argo CD: admin / 아래 초기 비밀번호
$s = kubectl get secret argocd-initial-admin-secret -n argocd -o json | ConvertFrom-Json
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($s.data.password))
# Grafana: 아래 아이디와 비밀번호
$s = kubectl get secret monitoring-grafana -n monitoring -o json | ConvertFrom-Json
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($s.data.'admin-user'))
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($s.data.'admin-password'))
$s=$null
```

Argo 초기 Secret을 지웠거나 비밀번호를 변경한 환경에서는 해당 초기값을 사용할 수 없습니다. 도메인 문제와 도구 내부 문제를 구분하려면 별도 창에서 port-forward로 확인합니다.

```powershell
# 각각 별도 창에서 사용. 종료는 Ctrl+C.
kubectl port-forward service/argocd-server -n argocd 8080:443
# https://localhost:8080 — 내부 인증서이므로 브라우저의 로컬 인증서 경고 가능
kubectl port-forward service/monitoring-grafana -n monitoring 3000:80
# http://localhost:3000
```

```powershell
kubectl get application final-apps -n argocd
kubectl get deployments,pods,hpa -n soldesk
kubectl get nodes
kubectl get externalsecret -n soldesk
terraform '-chdir=terraform' plan
. ./terraform-k8s/Prepare-Secrets.ps1
terraform '-chdir=terraform-k8s' plan
git status --short
```

No changes는 코드와 해당 state의 관리 자원이 일치한다는 뜻입니다. 고객 기능 전체의 정상 여부를 대신하지는 않습니다. 일시적 경고는 최근 이벤트·현재 Ready·실제 기능을 함께 보고 판단합니다.

작업을 마친 창에서 임시 입력 환경변수를 정리합니다. 기존 Secret은 삭제하지 않습니다.

```powershell
foreach ($key in @('TF_VAR_jwt_secret','TF_VAR_jwt_refresh_secret','TF_VAR_internal_service_token','TF_VAR_db_password','TF_VAR_github_token')) {
    Remove-Item "Env:$key" -ErrorAction SilentlyContinue
}
```

## 18. 학습 실습과 종료 순서
### 이 단계의 원리 · 구축과 종료는 반대 의존성

Ingress가 ALB를 소유하고 Controller가 삭제를 처리하므로, Controller·EKS부터 지우면 finalizer가 남거나 AWS 자원이 고아가 될 수 있습니다. finalizer는 삭제 전에 정리해야 할 작업을 기다리게 하는 장치입니다. 앱 sync를 끄고 앱·Ingress를 정리한 다음 도구·클러스터·네트워크로 내려갑니다.

PVC는 디스크 요청이고 PV는 실제 연결 자원입니다. 현재 StorageClass의 reclaim Delete는 PVC 제거가 EBS 데이터 삭제로 이어질 수 있다는 뜻입니다. Pod 재생성·PVC 삭제·백업 복구는 같은 작업이 아닙니다. DB는 현재 자동 최종 snapshot을 생략하는 삭제 설정이므로 의도적 종료 전에 보존 결정을 해야 합니다.

state·CloudTrail·상품 S3·ECR·별도 복원 DB는 보존·정리 조건이 다릅니다. force_destroy나 state 삭제로 오류를 없애는 것보다 실제 자원을 확인합니다. 실습을 마친다고 운영 환경 전체를 반드시 지워야 하는 것은 아니며, 검증용 임시 자원 정리와 전체 비용 종료를 구분합니다.


| 왜 이 단계인가? | 정상 기준 |
| :--- | :--- |
| 필요한 실습과 비용 종료를 구분하고 역순으로 정리 | 데이터 보존·종속 자원 제거·state 보관 |

추가 장애 실습은 [시나리오](../10-live-validation.md), 복원은 [별도 DB 복원](../08-rds-restore-lab.md), 배포 복구는 [롤백 PR](../ROLLBACK.md)을 따릅니다. 이번 구축에서 실제 수행한 것과 연습 계획을 분리해 기록합니다.

이 단계는 **비용을 중단하기 위해 환경을 의도적으로 제거할 때만** 진행합니다. 단순 복습이라면 조회만 합니다. 데이터 백업·이미지 보관·DB 최종 스냅샷 여부를 먼저 정하고, 삭제 계획을 검토합니다.

1. 진행 중인 CI·배포를 정리하고 ENABLE_DEPLOY_CHECKS를 false로 둡니다.
2. k8s tfvars의 `enable_app_sync=false`를 plan·apply합니다. 관리 Ingress는 이 시점에 유지합니다.
3. ALB Controller·EKS를 유지한 채 앱 Application을 삭제하고 앱 Ingress 정리를 기다립니다.
4. Kubernetes Terraform을 destroy해 관리 Ingress·운영 도구를 정리합니다.
5. ALB 삭제를 확인한 다음 DNS 조회 플래그를 false로 넘겨 AWS 인프라 destroy 계획을 만듭니다.
6. 상품·로그 S3, ECR, 복원 실습 DB 등 데이터 때문에 거부되는 자원은 해당 자원만 확인·백업·선택 정리합니다.
7. state 버킷과 bootstrap state는 보관합니다. 보호 설정을 제거해 무조건 삭제하지 않습니다.

```powershell
# 위의 의도적 종료·백업 조건을 충족한 경우만 실행
gh variable set ENABLE_DEPLOY_CHECKS --repo yjeee-ghub/aws-msa-final-project-test --body false
. ./terraform-k8s/Prepare-Secrets.ps1
# tfvars의 enable_app_sync=false를 저장한 뒤:
terraform '-chdir=terraform-k8s' plan '-out=stop-sync.tfplan'
terraform '-chdir=terraform-k8s' apply stop-sync.tfplan
kubectl delete application final-apps -n argocd --wait=true --timeout=10m
kubectl get ingress -A
terraform '-chdir=terraform-k8s' plan -destroy '-out=remove-tools.tfplan'
# 계획 검토 후:
terraform '-chdir=terraform-k8s' apply remove-tools.tfplan
aws elbv2 describe-load-balancers
terraform '-chdir=terraform' plan -destroy '-var=enable_website_dns=false' '-var=enable_management_dns=false' '-out=remove-infra.tfplan'
# 계획·DB 보관 조건 검토 후:
terraform '-chdir=terraform' apply remove-infra.tfplan
./scripts/ops/Get-ProjectResidue.ps1
```

`terraform-k8s`에는 Application이 state에 남아 있으므로 앱 수동 삭제 후 중간에 보통 apply를 다시 하면 Application이 재생성될 수 있습니다. 다음 의도한 작업은 destroy 계획입니다. 현재 RDS 코드는 deletion_protection=false, skip_final_snapshot=true이므로 삭제 시 자동 최종 스냅샷을 만들지 않습니다. 필요한 수동 스냅샷·복원 검증을 먼저 끝내고, 보존할 DB가 있다면 이 종료 절차를 실행하지 않습니다. 조회 권한 실패를 “잔여 자원 없음”으로 처리하지 않습니다.

## 공식 참고

- [EKS 관리 API 접근](https://docs.aws.amazon.com/eks/latest/userguide/config-cluster-endpoint.html)
- [S3 backend와 잠금](https://developer.hashicorp.com/terraform/language/backend/s3)
- [기존 자원 import](https://developer.hashicorp.com/terraform/cli/import)
- [GITHUB_TOKEN과 워크플로 실행](https://docs.github.com/en/actions/concepts/security/github_token)
- [OIDC 인증](https://docs.github.com/en/actions/concepts/security/openid-connect)

[홈](../../README.md) · [현재 검증 결과](../VALIDATION.md)


## 19. 핵심 용어·약어 사전

본문의 실행 단계와 함께 읽습니다. 같은 “토큰”, “정상”, “배포”라도 담당하는 계층이 다릅니다.

| 용어 | 정의·프로젝트에서의 역할 |
| :--- | :--- |
| MSA | Microservices Architecture. 회원·상품·주문 등을 분리한 앱 구성. 모든 데이터·장애가 자동으로 분리된다는 뜻은 아님 |
| API / HTTP | 프로그램의 요청 인터페이스 / 웹 요청·응답 프로토콜 |
| HTTPS / TLS | TLS로 보호하는 HTTP / 통신 암호화·신뢰 확인 프로토콜 |
| DNS / NS | 이름을 찾는 체계 / 해당 도메인의 DNS를 답할 네임서버 |
| Route 53 / hosted zone | AWS DNS 서비스 / 도메인 레코드 묶음 |
| CNAME / A Alias | 다른 DNS 이름을 가리킴 / AWS 대상에 이름을 연결. 여기서는 ACM 인증과 ALB 접속 역할 구분 |
| ACM | AWS Certificate Manager. 외부 HTTPS 인증서 발급·갱신 |
| VPC / subnet / AZ | 전용 네트워크 / IP 영역 / 리전 안의 분리된 가용 영역 |
| CIDR / /32 | IP 주소 범위 표현 / IPv4 한 주소 |
| IGW / NAT | 인터넷 게이트웨이 / 주소 변환. private 발신 경로와 public 수신 경로 구분 |
| SG | Security Group. 허용 기반 stateful 네트워크 접근 규칙 |
| ALB / listener / target group | HTTP 로드밸런서 / 수신 규칙·port / 전달 대상·health 묶음 |
| EKS / EC2 | 관리형 Kubernetes / 노드 등 가상 서버 |
| node / Pod | 컨테이너를 실행할 서버 / Kubernetes 실행 단위 |
| Deployment / ReplicaSet | 원하는 앱·교체 상태 / 해당 replica를 유지하는 자원 |
| Service / selector / label | 안정된 내부 주소 / 대상 선택 조건 / 자원에 붙이는 이름표 |
| Ingress / Controller | 외부 HTTP 경로 선언 / 선언을 실제 상태로 구현하는 제어 프로그램 |
| namespace | Kubernetes 자원을 나누는 관리 범위. 그 자체가 완전한 네트워크 격리는 아님 |
| kubeconfig / context | 로컬 접속 설정 / 현재 선택한 대상·사용자·namespace 조합 |
| Helm / chart | Kubernetes 패키지 설치 도구 / 설치할 자원과 입력의 묶음 |
| Kustomize | 앱 YAML의 자원·이미지 등을 조합하는 도구 |
| image / container / ECR | 실행 패키지 / 실행 중인 프로세스 / AWS 이미지 저장소 |
| tag / digest / SHA | 이미지 이름표 / 특정 이미지 식별값 / Git·해시에 사용하는 식별값. 용도별로 구분 |
| CI / CD / PR | 지속 통합 검사 / 전달·배포 흐름 / 변경 검토 요청 |
| GitOps / Argo CD | Git 선언 기준 운영 / Git과 실제 앱을 동기화하는 도구 |
| sync / self-heal / health | 선언 반영 / 선언과 다른 상태 복구 / 도구가 판단한 자원 건강 |
| rollout / rollback | 버전 교체 과정 / 이전 버전으로 복구. DB 복원과 다름 |
| PDB | Pod Disruption Budget. 자발적 eviction의 가용 수 제한 |
| startup / readiness / liveness | 초기 기동 대기 / 요청 준비 / 프로세스 재시작 판단 |
| requests / limits / m / Mi / Gi | 자원 예약·배치 기준 / 상한 / CPU 천분 단위 / 이진 메모리 단위 |
| HPA / CA / ASG | Pod 수 조절 / 노드 수 조절 / EC2 수·수명 관리 그룹 |
| IAM / ARN / STS | AWS 신원·권한 / 자원 식별자 / 임시 자격증명 발급 서비스 |
| OIDC / trust policy | 외부 신원 증명 체계 / 어떤 신원에 AWS 역할을 줄지의 조건 |
| SA / IRSA / RBAC | Pod 서비스 계정 / EKS SA와 IAM 역할 연결 / Kubernetes 역할 기반 접근 제어 |
| Secret / ConfigMap | 민감 설정 전달 자원 / 일반 설정 전달 자원. Secret Base64는 암호화가 아님 |
| Secrets Manager / ESO | AWS 비밀값 관리 / 외부 비밀값을 Kubernetes Secret에 연동 |
| JWT / claim / refresh token | 서명된 로그인 토큰 / 토큰 안의 신원 속성 / 접근 토큰 갱신용 토큰 |
| GitHub App / GITHUB_TOKEN | 별도 자동화 신원 / Actions의 기본 인증 토큰 |
| runner / job / ephemeral | 명령 실행 컴퓨터 / 작업 묶음 / 한 작업 후 종료하는 수명 방식 |
| non-root / capabilities / seccomp | 일반 사용자 실행 / 추가 Linux 권한 / 시스템 호출 제한 |
| SQL / JDBC / JPA | DB 질의 언어 / Java DB 연결 / Java 객체·DB 매핑 체계 |
| RDS / MySQL / snapshot | 관리형 DB / 사용 엔진 / 특정 시점의 복원용 백업 |
| Flyway / migration | 버전별 DB 변경 도구 / 스키마 변경 절차 |
| transaction / row lock | DB 작업 묶음 / 같은 행 동시 변경을 통제하는 잠금 |
| idempotency / reservation / compensation | 반복 요청 효과 중복 방지 / 재고 확보 / 중간 실패를 보상하는 처리 |
| Outbox | DB에 이벤트를 기록하고 후속 worker가 발행하는 패턴 |
| SNS / topic / subscription | 메시지 전달 서비스 / 채널 / 수신 대상 등록 |
| SQS / visibility timeout / DLQ | 메시지 큐 / 처리 중 숨김 시간 / 반복 실패 보관 큐 |
| Lambda / SES / DynamoDB | 이벤트 실행 코드 / 메일 발송 / 처리 상태 키 기반 저장소 |
| lease / TTL / retry | 한시적 처리권 / 만료 기준 / 실패 후 재시도 |
| EBS / CSI / StorageClass | AWS 블록 디스크 / 디스크 연결 인터페이스 / 생성·바인딩 규칙 |
| PVC / PV / RWO | 저장 요청 / 연결된 저장 자원 / 한 노드의 읽기·쓰기 마운트 모드 |
| metric / log / event | 수치 시계열 / 사건 메시지 / 자원 상태 변화 기록 |
| Prometheus / PromQL / ServiceMonitor | 지표 수집·질의 / 질의 언어 / 수집 대상 선언 |
| Grafana / panel / data source | 시각화 도구 / 그래프·표 단위 / 지표를 가져오는 연결 |
| Alertmanager / CloudWatch / CloudTrail | 알림 전달 제어 / AWS 지표·로그·경보 / AWS API 감사 기록 |
| OOM / p95 / VU | 메모리 부족 / 95% 요청의 지연 경계 / 부하 도구의 가상 사용자 |
| RTO / RPO | 목표 복구 소요 시간 / 허용 데이터 손실 시점 목표. 실측값과 목표를 구분 |

## 20. EBS·PVC를 현재 설정으로 이해하기

| 이름 | 뜻 | 이 프로젝트 |
| :--- | :--- | :--- |
| EBS CSI Driver | Kubernetes가 AWS 디스크를 만들고 붙이는 도구 | Terraform이 전용 IAM 역할·EKS addon 준비 |
| StorageClass | 어떤 디스크를 언제 만들지 정한 규칙 | final-gp3, 암호화, WaitForFirstConsumer |
| PVC | 앱의 저장 공간 요청 | Grafana 1Gi·Prometheus 5Gi·Alertmanager 1Gi |
| PV / EBS | 연결된 실제 저장 자원 / AWS 디스크 | PVC 바인딩과 AZ 확인 |
| ReclaimPolicy | PVC 해제 후 실제 디스크 처리 | 현재 final-gp3는 Delete |

WaitForFirstConsumer는 첫 소비 Pod의 배치를 고려한 뒤 같은 AZ에 볼륨을 준비하는 방식입니다. 이미 만든 EBS가 다른 AZ로 자유롭게 이동한다는 뜻은 아닙니다. PVC Bound와 Pod Ready를 함께 확인합니다.

```powershell
kubectl get csidriver ebs.csi.aws.com
kubectl get storageclass final-gp3
kubectl get pvc -n monitoring
kubectl get pv
kubectl get pods -n monitoring -o wide
kubectl get nodes -L topology.kubernetes.io/zone
```

EC2 콘솔 → Volumes에서 PV의 EBS 식별자·AZ·암호화·연결 상태를 대조합니다. 이 자원은 PVC·CSI가 생성하므로 학습 중 임의로 같은 디스크를 하나 더 만들거나 연결하지 않습니다. 현재 Delete 정책에서 PVC 삭제는 데이터 디스크 삭제로 이어질 수 있습니다. Pod 재시작 후 저장 보존과 백업·AZ 장애 복구는 서로 다른 검증입니다.

## 공식 설명·연결 문서

실제 실행 단계와 현재 저장소 코드를 기준으로 읽고, 도구 버전·콘솔 화면이 달라졌을 때 공식 문서로 확인합니다.

- [Kubernetes 이미지·digest](https://kubernetes.io/docs/concepts/containers/images/)
- [Kubernetes Service](https://kubernetes.io/docs/concepts/services-networking/service/)
- [GitHub OIDC](https://docs.github.com/en/actions/concepts/security/openid-connect)
- [GitHub 러너 보안](https://docs.github.com/en/actions/reference/security/secure-use)
- [EKS 관리 API 접근](https://docs.aws.amazon.com/eks/latest/userguide/config-cluster-endpoint.html)
- [Terraform S3 backend·잠금](https://developer.hashicorp.com/terraform/language/backend/s3)
- [실제 실행 결과](../VALIDATION.md) · [증거 목록](../EVIDENCE.md)

[홈](../../README.md) · [GUI·명령어 검증 실습](교육%20복습노트_검증%20및%20시나리오.md)
