# 내부 배포 검증과 보안

**승인한 프로그램이 실제로 정상 실행되는지 확인하되, 그 검사를 위해 관리 API 접근 범위를 넓히지 않는 것**이 목표입니다. 이 문서는 [배포 흐름](02-deployment.md)의 마지막 검증 단계를 설명합니다.

## 러너는 명령어를 실행하는 컴퓨터

GitHub Actions의 workflow는 작업 지시서, job은 작업 묶음, runner는 실제 명령을 실행하는 컴퓨터입니다. `GitHub-hosted`는 GitHub가 제공하고, `self-hosted`는 우리가 실행 환경을 준비합니다. 이 프로젝트의 내부 러너는 별도 EC2가 아닌 **EKS 안의 Pod**입니다.

| 작업 | 실행 장소 | 이유 |
| --- | --- | --- |
| 코드 검사·이미지 빌드 | GitHub 표준 러너 | 일반 CI에 내부 클러스터 접근 불필요 |
| 승인된 배포의 상태 검사 | 우리 VPC의 일회용 러너 | 제한된 EKS 관리 API를 내부 경로로 조회 |

## 내부에서 검사해야 하는 이유

EKS 관리 API는 Kubernetes 상태를 조회·변경하는 접속점입니다. 쇼핑몰을 보는 HTTPS 주소와 다릅니다. 외부 공개 API는 관리 PC 공인 IP `/32`로 제한하고 private endpoint도 활성화합니다. GitHub 표준 러너는 관리 PC나 우리 VPC에 해당하지 않습니다.

```text
GitHub Actions ← 내부 러너가 인터넷으로 나가 작업을 수신
                    │
               우리 VPC / EKS
                    ├─ EKS 관리 API: Deployment·이미지·Ready 상태
                    ├─ Argo Application: revision·Synced·Healthy
                    └─ 공개 HTTPS: 홈페이지·상품 JSON 응답
```

내부 러너를 둔다고 인터넷에서 러너로 들어오는 포트를 추가 개방하지 않습니다. 인터넷 발신은 GitHub 접속과 도구 다운로드에도 필요합니다. [EKS endpoint 접근 설명](https://docs.aws.amazon.com/eks/latest/userguide/config-cluster-endpoint.html)

## 일회용의 정확한 의미

```text
PowerShell로 Pod·등록용 Secret 생성
 → GitHub에 --ephemeral 러너 등록
 → 승인된 main의 검증 job 1개 실행
 → 러너 종료·GitHub 등록 해제
 → 운영자가 완료 Pod·등록용 Secret 삭제
```

GitHub 등록 해제와 Kubernetes Pod 삭제는 다른 단계입니다. Pod는 완료 상태로 남을 수 있습니다. 현재 생성·삭제 명령은 제공하지만 자동 공급·정리 컨트롤러는 없습니다. 다음 검사 전에 새 러너가 필요합니다. [실습 명령](learning/STUDY-NOTES.md)

## 네트워크 접근과 권한은 별개

내부에서 API에 닿을 수 있어도 관리자 권한이 생기지는 않습니다. 이 러너의 검증용 역할은 다음처럼 좁게 구성합니다.

| 층 | 허용 |
| --- | --- |
| GitHub job | 저장소 내용 읽기, OIDC 신원 토큰 요청 |
| AWS IAM | 대상 `Final-eks`의 `eks:DescribeCluster` |
| EKS Access Entry | `final-deploy-readers` 그룹 연결 |
| Kubernetes RBAC | soldesk Deployment 읽기·목록·관찰, argocd의 `final-apps` 한 개 읽기 |

검증 역할에는 앱 수정·삭제, Secret 조회 권한을 부여하지 않습니다. 실제 변경은 Argo CD가 담당합니다. 다른 AWS 서비스 역할의 권한까지 이 역할이 대신 받는 것은 아닙니다.

## OIDC: 장기 AWS 키 대신 임시 출입증

**OIDC**는 외부 작업의 신원을 증명하는 방식입니다. GitHub가 저장소·브랜치 등 작업 신원을 증명하면, AWS가 역할의 신뢰 조건을 검사하고 짧게 쓰는 자격증명을 발급합니다.

```text
GitHub의 작업 신원 증명
 → AWS가 audience·subject 조건 확인
 → 검증용 역할의 임시 자격증명 발급
 → EKS 상태 조회
 → 자격증명 만료
```

이 프로젝트는 저장소 main의 정확한 OIDC subject를 사용합니다. ECR 게시 역할과 배포 조회 역할을 분리합니다. 저장소 이름·ID·subject 형식·브랜치 또는 environment를 바꾸면 신뢰 정책도 다시 확인해야 합니다. 임의로 전체 저장소·모든 브랜치를 허용하지 않습니다. [GitHub OIDC](https://docs.github.com/en/actions/concepts/security/openid-connect)

## Pod에 적용한 제한

| 설정 | 뜻 | 목적 |
| --- | --- | --- |
| non-root / UID 1001 | 컨테이너를 일반 사용자로 실행 | 불필요한 관리자 권한 감소 |
| allowPrivilegeEscalation=false | 권한 상승 제한 | 실행 중 추가 권한 획득 경로 축소 |
| capabilities drop ALL | 추가 Linux 권한 제거 | 검사에 필요 없는 능력 제거 |
| RuntimeDefault seccomp | 기본 시스템 호출 제한 | 커널 호출 범위 제한 |
| SA token 자동 주입 해제 | Pod 기본 Kubernetes 자격증명 미주입 | 명시한 OIDC 인증 경로 사용 |
| 호스트 Docker socket 미연결 | 노드 컨테이너 엔진 제어 경로 미제공 | 호스트 제어 위험 감소 |
| CPU·메모리 제한 | 자원 사용 상한 지정 | 검사 작업의 과도한 점유 억제 |

이 설정이 컨테이너를 완전한 보안 경계로 만들지는 않습니다. 특히 내부 러너는 **미검토 PR 코드의 실행 장소로 사용하지 않습니다.** 현재 workflow는 main에 한정합니다. [GitHub 러너 보안](https://docs.github.com/en/actions/reference/security/secure-use)

## 실제 검사 항목

[check_release.py](../scripts/ops/check_release.py)는 ① Argo가 요청한 배포 commit을 반영했는지 ② Synced·Healthy인지 ③ 5개 Deployment 이미지가 선언과 같은지 ④ replica가 준비됐는지 ⑤ 인증서 검증을 포함한 HTTPS가 정상인지 ⑥ HTML과 상품 JSON 형식이 맞는지 확인합니다.

이 검사는 주문 데이터를 만들지 않습니다. 주문·재고·메일 검증은 별도 실습입니다. 검사 실패 시 상태 조회를 통해 원인을 찾으며, 자동으로 DB나 배포를 되돌리지 않습니다.

## 혼동하기 쉬운 인증값

| 값 | 어디에 쓰는가? |
| --- | --- |
| GITHUB_TOKEN | Actions가 GitHub API를 호출하는 기본 토큰 |
| GitHub App 설치 토큰 | App 신원으로 릴리스 PR 생성·검사 트리거; 현재 미설정 |
| 러너 등록 토큰 | 임시 컴퓨터를 해당 저장소의 러너로 등록 |
| OIDC·AWS 임시 자격증명 | job이 AWS 검증 역할로 접근 |
| 앱 JWT | 쇼핑몰 사용자의 로그인 인증 |

서로 다른 용도입니다. GitHub App을 추가해도 내부 러너가 자동으로 생성되거나 팀원 리뷰가 생략되지는 않습니다.

[홈](../README.md) · [배포 흐름](02-deployment.md) · [명령어 실습](learning/STUDY-NOTES.md)
