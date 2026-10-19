# 2026-10-19 실행 기록

- 도메인 aws-yjeee.com, 메일 yoonjoung429@gmail.com. EKS·프라이빗 RDS·노드 4대와 운영 도구를 생성했습니다.
- 계정의 Lambda 한도로 예약 동시 실행 2개가 거부됐습니다. 예약을 제거하고 SQS 소비 동시 실행을 2개로 제한해 해결했습니다. Java는 변경하지 않았습니다.
- 잘못된 미확인 SNS 구독은 AWS가 직접 삭제를 거부하여, 다른 구독자가 없던 이번 작업의 알림 토픽만 재생성한 뒤 Terraform으로 정합성을 복구했습니다.
- 공개 GitOps 저장소는 GitHub 토큰을 저장하지 않습니다. 자동 생성한 관리자/JWT 키의 로컬 복구본은 Windows DPAPI로 보호하고 Git에서 제외합니다.
- main은 required-ci 및 다른 사람의 승인 1명이 필요합니다. 최초 테스트·이미지 게시가 성공했고 배포 PR이 배포의 승인 관문입니다.
- EKS 관리 API는 관리 IP로 제한합니다. 배포 검사는 VPC 내부의 임시 runner Pod에서 수행합니다. Pod는 non-root이고 서비스 계정 토큰·호스트 Docker socket·AWS 키가 없습니다. 작업 중 GitHub OIDC로 조회 전용 역할만 받습니다.
- scripts/ops/Start-DeployCheckRunner.ps1은 한 번의 deploy-check 작업용 runner를 등록합니다. 다음 검사 전 새 임시 runner를 시작해야 하며, 작업 종료 후 완료 Pod와 동일 이름의 단기 등록 Secret을 삭제합니다. 검토하지 않은 PR 코드를 이 runner에서 실행하지 않습니다.
- 이 단계는 인프라 설치 기록입니다. 앱 동기화·DNS·주문/메일 검증 성공은 별도로 기록합니다.