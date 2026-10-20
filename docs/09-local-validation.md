# 로컬 검사 방법

로컬 검사는 AWS 실제 배포와 구분합니다. 저장소 루트에서 실행하며 Python·Node.js·JDK 17·Git Bash·Terraform·kubectl을 준비합니다. Docker 이미지를 빌드할 때만 실행 중인 Docker 엔진이 필요합니다. 최신 실제 성공 기록은 [검증 결과](VALIDATION.md)에서 확인합니다.

## Python·프런트엔드

```powershell
Set-Location 'C:\aws-msa-final-project-test'
python -m unittest discover -s tests -v
$testFiles = Get-ChildItem app/msa/frontend/tests -Filter '*.test.cjs' | ForEach-Object FullName
node --test @testFiles
kubectl kustomize app/msa
git diff --check
```

운영 스크립트의 일부 테스트는 PowerShell 설치 여부에 따라 skip될 수 있습니다. 통과 수와 skip 수를 구분합니다. Kustomize 출력에는 비밀값을 넣지 않습니다.

## Java 서비스

Windows의 `bash`가 WSL을 가리킬 수 있으므로 Git Bash 실행 파일을 명시합니다. 설치 경로가 다르면 수정합니다.

```powershell
$gitBash = 'C:\Program Files\Git\bin\bash.exe'
& $gitBash scripts/ci/test-service.sh member
& $gitBash scripts/ci/test-service.sh product
& $gitBash scripts/ci/test-service.sh ordering
& $gitBash scripts/ci/test-service.sh apigateway
```

선택 테스트는 운영 DB 없이 검사할 수 있는 범위입니다. H2 기반 테스트 성공을 실제 MySQL의 DDL·락·장애 복구 검증과 동일하게 보지 않습니다.

## Terraform 구성 검사

CI의 config job은 AWS 인증 없이 backend를 끈 환경에서 세 루트를 검사합니다. **운영 폴더의 backend 연결을 로컬 검사 목적으로 바꾸지 않습니다.** AWS 접속이 가능한 기존 운영 폴더에서는 초기화된 설정에 대해 validate를 실행하면 됩니다.

```powershell
terraform fmt -check -recursive terraform terraform-k8s terraform-state-bootstrap
terraform '-chdir=terraform-state-bootstrap' validate
terraform '-chdir=terraform' validate
terraform '-chdir=terraform-k8s' validate
terraform '-chdir=terraform-k8s' test -no-color
```

처음에는 init으로 provider를 내려받아야 합니다. CI와 같은 무인증 검사는 별도의 깨끗한 검증 복사본에서 `init -backend=false`로 준비합니다. 기존 `.terraform`이나 state를 복사해 운영 환경과 섞지 않습니다.

[홈](../README.md) · [실제 구축](learning/STUDY-NOTES.md)
