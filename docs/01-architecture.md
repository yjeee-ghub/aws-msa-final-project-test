# 프로젝트 구성

이 프로젝트는 **사용자 요청, 앱 실행, 데이터 저장, 배포·운영**을 구분해 구성합니다. 쇼핑몰은 운영을 검증하기 위한 실제 서비스이며, 주요 학습 대상은 AWS 인프라와 DevOps 작업 흐름입니다.

## 사용자 요청이 이동하는 경로

```text
사용자 → Route 53 → 공유 ALB의 HTTPS 리스너
                         ├─ server.aws-yjeee.com → frontend / apigateway
                         │                              ├─ member
                         │                              ├─ product → S3 이미지
                         │                              └─ ordering
                         │                                  ↓
                         │                           비공개 RDS MySQL
                         ├─ argocd.aws-yjeee.com → Argo CD
                         └─ grafana.aws-yjeee.com → Grafana
```

Route 53은 주소를 찾도록 돕는 DNS입니다. ALB는 들어온 도메인·경로에 따라 대상 서비스를 선택하는 로드밸런서입니다. API Gateway는 여기서는 AWS API Gateway 제품이 아니라 **EKS에 실행하는 Spring 기반 apigateway 앱**을 뜻합니다.

## 네트워크와 실행 환경

| 용어 | 뜻 | 배치 |
| --- | --- | --- |
| VPC | AWS에서 구성하는 전용 네트워크 | `10.42.0.0/16` |
| 서브넷 | VPC를 나눈 IP 공간 | 퍼블릭·앱·DB 각각 2개 |
| AZ | 같은 리전 안의 분리된 가용 영역 | 서울 2a·2c |
| 퍼블릭 서브넷 | 인터넷 게이트웨이 경로가 있는 영역 | ALB·NAT |
| 프라이빗 앱 서브넷 | 노드가 공인 IP 없이 실행되는 영역 | EKS 노드·앱 Pod |
| DB 서브넷 | 데이터베이스용 영역 | 외부 공개하지 않는 RDS |
| NAT Gateway | 내부 자원의 인터넷 발신을 중계 | 이미지·패키지·GitHub 접근 등에 사용 |
| 노드 / Pod | 서버 / 서버 위의 컨테이너 실행 단위 | EKS가 관리 |

AZ별 노드 그룹은 2a에 최소·최대 2대, 2c에 최소 2대·최대 3대입니다. 기본 4대에서 최대 5대로 확장합니다. EBS 디스크의 AZ 제약을 고려해 모니터링의 배치 영역과 확장 여유를 맞춥니다.

## 배포와 인프라의 관리 주체

| 관리 주체 | 담당 | 이유 |
| --- | --- | --- |
| Terraform bootstrap | state 보관 S3 | 운영 인프라와 별도로 보관 |
| Terraform AWS 루트 | VPC·EKS·RDS·IAM·ECR·SNS/SQS·Lambda·인증서·DNS 등 | 의존성과 변경 계획 관리 |
| Terraform Kubernetes 루트 | Helm 도구·Secret·RBAC·관리 Ingress·Argo Application | 클러스터 준비 후 설치 |
| Argo CD | `app/msa`의 앱 배포 선언 | Git과 실제 앱 상태를 동기화 |
| AWS 콘솔 | 도메인 위임·메일 인증·상태 관찰 등 | 사람이 확인해야 하는 계정·인증 작업 |

같은 리소스를 콘솔과 Terraform에서 각각 새로 만들지 않습니다. 콘솔에서 만든 자원을 Terraform 소유로 바꾸려면 해당 resource 주소로 import해야 합니다. [직접 구축 순서](learning/STUDY-NOTES.md)

## 도메인에 CNAME과 Alias가 함께 있는 이유

| 레코드 | 예시 | 담당 |
| --- | --- | --- |
| ACM 인증 CNAME | `_문자.server.aws-yjeee.com` → `…acm-validations.aws` | 도메인 소유 확인·인증서 자동 갱신 |
| A 레코드의 Alias | `server.aws-yjeee.com` → 공유 ALB | 실제 접속 주소 연결 |

인증 CNAME은 인증서 발급 후에도 유지합니다. ALB 주소를 읽는 DNS 리소스는 ALB가 생성된 다음 활성화합니다. [AWS ACM 설명](https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html)

## 데이터·메시징·운영 경로

- RDS 비밀번호: RDS → Secrets Manager → External Secrets → 앱 Secret.
- 주문 메일: 주문 DB·Outbox → 주문 SNS → SQS → Lambda → SES. DynamoDB는 이벤트의 메일 처리 상태를 보관합니다.
- 운영 알림: Prometheus·Alertmanager 또는 CloudWatch·노드 이벤트 → 운영 SNS → 구독 이메일.
- 배포 검사: VPC 내부 일회용 러너 → EKS·Argo 상태 조회 + HTTPS 기능 검사.

상품 이미지는 S3의 `products/` 객체를 공개 읽기하도록 구성합니다. state·CloudTrail 버킷과 동일한 공개 정책을 사용하지 않습니다. RDS와 Secret은 외부 공개 대상이 아닙니다.

[홈](../README.md) · [다음: 배포 흐름](02-deployment.md)
