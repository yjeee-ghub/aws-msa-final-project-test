# 앱 배포 안내

앱 배포는 main의 이미지 digest 선언을 Argo CD가 반영하는 방식입니다.

- [코드·이미지·승인·배포 전체 흐름](../../docs/02-deployment.md)
- [콘솔과 PowerShell로 구축·실행](../../docs/learning/STUDY-NOTES.md)
- [내부 검증 러너와 권한](../../docs/14-security-and-verification.md)
- [롤백 PR](../../docs/ROLLBACK.md)

`app/msa/legacy`와 참고용 수동 설치 YAML을 현재 Helm·Terraform 구성과 중복 적용하지 않습니다. 앱의 적용 대상은 [kustomization.yaml](kustomization.yaml)입니다.
