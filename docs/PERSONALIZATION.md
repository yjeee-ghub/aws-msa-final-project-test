# 개인화 설정 · main 기준

기준일: 2026-10-19. 이 문서는 현재 설정과 실행 전 남은 항목을 구분합니다.

| 항목 | 반영 값 |
| --- | --- |
| 작업 경로 | `C:\aws-msa-final-project-test` |
| GitHub 저장소 | https://github.com/yjeee-ghub/aws-msa-final-project-test |
| Git clone URL | `https://github.com/yjeee-ghub/aws-msa-final-project-test.git` |
| 기준 브랜치 | `main` |
| AWS 계정 | `193644343848` |
| 서울 ECR | `193644343848.dkr.ecr.ap-northeast-2.amazonaws.com` |
| state 버킷 | `final-tfstate-193644343848-ap-northeast-2` |
| 상품 이미지 버킷 | `final-product-images-193644343848-ap-northeast-2` |
| OIDC subject 기본값 | `repo:yjeee-ghub@336437888/aws-msa-final-project-test@1425157293:ref:refs/heads/main` |

## 반영 범위

- Terraform bootstrap·infra·k8s·remote_state, ECR·IAM/SNS ARN, 계정 guard, CI·게시/태그 갱신·운영 스크립트와 모의 테스트의 계정값을 함께 변경했습니다.
- Argo CD URL과 GitHub 사용자명, main 기준 CI/PR, 저장소 보호 스크립트의 대상 저장소를 반영했습니다.
- 이미지 게시와 배포 조회 역할은 동일한 main OIDC subject 변수를 사용합니다. 새 저장소의 공개 메타데이터 owner ID `336437888`, repository ID `1425157293`과 2026-10-19 생성일을 확인했습니다. 2026-07-15 이후 신규 저장소의 GitHub 기본 형식에 맞췄으며, 실제 OIDC 토큰 교환은 후속 검증입니다. subject 사용자화·environment 도입 시 실제 claim과 신뢰 정책을 함께 검토합니다.
- 기존 test2 분기 전제는 현재 운영 설명에서 제거했습니다. 안내 파일은 `docs/11-delivery.md`, 입력 예시는 각 Terraform 루트의 `personal.tfvars.example`로 정리했습니다.
- 로컬 폴더에 .git이 없어 실제 로컬 브랜치·origin은 아직 없습니다. 저장소 초기화·commit·push·보호 규칙 적용은 하지 않았습니다. GitHub API상 기본 브랜치는 main이며 확인 시 원격 브랜치 목록은 비어 있었습니다.

## 실행 전에 남은 항목

- AWS 프로필은 기존 default입니다. 실제 프로필·IAM 관리자 ARN·관리 CIDR·권한을 확인해야 합니다. 계정 제한은 `193644343848`로 유지합니다.
- 원본 `syong.store` 도메인·DNS·ACM·관리자 이메일 기본값은 아직 개인 도메인으로 바꾸지 않았습니다. Java 기본 이메일도 Java 유지 조건에 따라 그대로입니다. 원본 도메인으로 접속·메일 검증하지 않습니다.
- DB 주소·인증서 ARN·도메인·SES 발신/수신 인증·GitHub App·Actions 변수·Secret을 준비합니다. 토큰·비밀번호는 문서/Git에 넣지 않습니다.
- state bucket 이름과 key를 bootstrap → infra backend → k8s backend/remote_state에서 대조합니다. 이번에는 init·migrate·plan·apply를 하지 않았고 원본 state를 가져오지 않았습니다.
- 새 계정의 ECR에는 원본 SHA 이미지가 자동 복사되지 않습니다. main의 최초 full_build 후 승인 배포 PR과 실제 이미지 digest를 확인합니다. 원본 RELEASES의 SHA를 새 계정에서 곧바로 롤백할 수 있다고 가정하지 않습니다.
- main push는 조건 충족 시 ECR 게시·배포 PR 생성을 실행할 수 있습니다. deploy-check는 ENABLE_DEPLOY_CHECKS=true 이후 동작합니다. 준비되지 않은 상태로 push/동기화하지 않습니다.

## 보존한 내용

Java 소스·패키지·서비스 로직·DB 구조, 원본 LICENSE, 과거 Actions 링크와 실제 실습 기록은 유지했습니다. 과거 기록은 원본 이력으로 표시하고 현재 계정에서 성공한 것으로 바꾸지 않았습니다. 자원명 Final·namespace soldesk는 이번 요청에 없는 변경이라 유지합니다.

## 검증 구분

개인화 파일의 정합성·로컬 회귀 검사와 AWS/GitHub/EKS 실제 실행은 별도입니다. 이번 작업은 로컬 코드 정비이며 리소스 생성·삭제, 이메일 발송, 실제 이미지 게시·배포, 원격 설정 변경은 포함하지 않습니다.

원본 출처: https://github.com/yonginfra/aws-msa-final-project

OIDC 형식 근거: https://docs.github.com/en/actions/reference/security/oidc
