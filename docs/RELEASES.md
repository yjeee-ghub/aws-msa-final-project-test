# 릴리스 기록

릴리스는 Git의 이미지 선언과 ECR의 실제 이미지가 함께 있어야 재현할 수 있습니다. 태그만 보고 다른 계정의 이미지를 복구 대상으로 선택하지 않습니다.

| 확인일 | 배포 선언 commit | 소스 이미지 기준 | 결과 |
| --- | --- | --- | --- |
| 2026-10-19 | `94915e5c8eb56143ab556b0136396ba9fc95eec2` | 최초 5개 이미지 `e2d12028815781acdd91584599ade4bd17540ca6`, 서비스별 digest는 release.json | 승인·Argo 동기화·실제 배포 검사 성공 |

- [릴리스 선언](../deploy/release.json)
- [배포 이미지 설정](../app/msa/kustomization.yaml)
- [검증 증거](VALIDATION.md)

```powershell
git log --oneline -- deploy/release.json app/msa/kustomization.yaml
Get-Content deploy/release.json
kubectl get application final-apps -n argocd -o jsonpath='{.status.sync.revision}'
```

새 릴리스는 소스·digest·승인 PR·배포 검사 링크를 함께 기록합니다. 여러 서비스가 다른 소스 SHA를 가질 수 있습니다. 현재 기록은 실시간 조회가 아니라 검증 시점의 기록입니다.

[홈](../README.md) · [롤백](ROLLBACK.md)
