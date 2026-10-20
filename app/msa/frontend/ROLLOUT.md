# 프런트엔드 롤링 업데이트 실습

롤링 업데이트는 새 Pod를 준비하면서 기존 Pod를 순서대로 교체하는 방식입니다. 현재 [Deployment](k8s/depl_svc.yml)는 replica 2, maxSurge 1, maxUnavailable 0, minReadySeconds 10을 사용합니다. 새 Pod가 준비되지 않으면 기존 Pod를 유지하며, 배치 여유가 필요합니다.

평소 배포는 코드 PR → CI → 릴리스 PR → 팀원 승인 → Argo CD 반영 순서입니다. main 직접 push나 실행 중인 Deployment의 임의 이미지 변경으로 실습하지 않습니다. [배포 흐름](../../../docs/02-deployment.md)

각각 별도 창에서 관찰합니다.

```powershell
kubectl get pods -n soldesk -l app=frontend -o wide --watch
kubectl get rs -n soldesk -l app=frontend --watch
```

배포 PR 병합 전 내부 검증 러너를 준비하고, 병합 후 rollout과 HTTPS를 확인합니다.

```powershell
kubectl rollout status deployment/frontend-depl -n soldesk --timeout=300s
./scripts/ops/Test-DeploymentHttps.ps1
```

진행 실패 시간 제한은 자동 롤백을 뜻하지 않습니다. PDB도 모든 장애의 요청 손실을 방지하지 않습니다. [검증 계획](../../../docs/10-live-validation.md)에 따라 접속 오류 수·교체 시간·ALB health를 함께 기록합니다.
