# 승인 PR로 이전 이미지 복구

롤백은 이전 정상 이미지로 앱을 되돌리는 작업입니다. 이 프로젝트에서는 Git의 배포 선언이 기준이므로 **이미지 digest와 release.json을 함께 바꾸는 PR**을 만듭니다.

## 실행 전 조건

1. 이전 정상 배포 commit에 5개 서비스의 release.json이 있어야 합니다.
2. 해당 digest의 이미지가 현재 계정 ECR에 남아 있어야 합니다.
3. DB 스키마·API·환경변수의 이전 이미지 호환성을 검토합니다.
4. 작업 트리가 깨끗하고 AWS ECR 조회·gh 인증이 준비돼 있어야 합니다.

현재 저장소에 정상 릴리스가 하나뿐이면 바로 돌아갈 다른 검증 버전은 아직 없는 것입니다. 임의의 과거 SHA를 넣지 않습니다.

```powershell
Set-Location 'C:\aws-msa-final-project-test'
git status --short
git fetch origin main
git log origin/main --oneline -- deploy/release.json
$releaseCommit = Read-Host '복구할 정상 배포 commit 40자리'
python scripts/ops/rollback_release.py --release-commit $releaseCommit
```

스크립트가 ECR 이미지 존재를 확인하고 현재 origin/main에서 새 브랜치를 만듭니다. 이미지 선언과 release.json을 수정해 PR을 생성합니다. PR 생성 권한은 변경·병합 승인 권한과 별개입니다.

## 승인 후 확인

팀원이 DB 호환성과 영향 범위를 확인하고 필수 검사·리뷰를 거쳐 병합합니다. 새 내부 러너를 준비하고 Argo revision·이미지·Ready·HTTPS·상품 API를 확인합니다. [배포 검증 실행 순서](learning/STUDY-NOTES.md)

`kubectl rollout undo`만 실행하면 Argo CD self-heal이 Git 상태로 다시 맞출 수 있습니다. Git 선언을 변경하는 승인 절차를 사용합니다. 이 스크립트는 DB 복원·Terraform 되돌리기·자동 병합을 수행하지 않습니다.

[홈](../README.md) · [배포 흐름](02-deployment.md)
