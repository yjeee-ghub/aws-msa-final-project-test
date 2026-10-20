# 배포 흐름과 이미지 고정

배포는 **프로그램을 만들기 → 검토하기 → 실행하기 → 정상인지 확인하기**로 나눕니다. GitHub Actions 성공과 실제 서비스 정상 동작은 각각 확인해야 합니다.

## 먼저 알아둘 용어

| 용어 | 쉬운 뜻 |
| --- | --- |
| CI | 변경한 코드의 테스트·빌드·설정 검사를 자동 실행하는 과정 |
| 이미지 | 앱과 실행 환경을 묶은 컨테이너 패키지 |
| ECR | AWS의 컨테이너 이미지 저장소 |
| 태그 | 이미지의 이름표. 이 프로젝트는 소스 Git 커밋 SHA를 사용 |
| digest | 특정 이미지를 식별하는 `sha256:…` 값 |
| PR | main에 반영할 변경을 검토하는 요청 |
| GitOps | Git의 배포 선언을 기준으로 실제 상태를 맞추는 운영 방식 |
| Helm / Kustomize | 운영 도구를 패키지로 설치 / 앱 YAML의 이미지 등을 조합·변경하는 도구 |

## 두 번의 검토: 소스와 배포

```text
① 작업 브랜치에 코드 수정
   → 코드 PR → required-ci 통과 → 다른 팀원 승인 → main 병합

② main의 변경 서비스 테스트·빌드
   → 테스트한 이미지 산출물을 ECR에 게시
   → source SHA·digest를 기록한 릴리스 PR 생성

③ 릴리스 PR 검사 → 팀원 승인 → main 병합
   → Argo CD가 승인된 이미지로 앱 교체

④ VPC 내부 러너가 배포 버전·이미지·가용성·실제 HTTPS 응답 검사
```

main 보호는 `required-ci`, 다른 사람 승인 1건, 최신 변경 이후 승인, 대화 해결을 요구하며 관리자에게도 적용합니다. PR 파일을 만들었다고 보호 설정이 생기는 것은 아니므로 GitHub 설정을 별도로 적용합니다.

## 테스트한 이미지를 그대로 게시

CI는 관련 서비스를 선택하고 테스트 후 이미지를 만듭니다. main의 이미지 산출물을 `docker save`로 전달하고 게시 단계에서 `docker load`해 ECR에 올립니다. 게시 단계에서 별도로 다시 빌드하지 않습니다.

문서만 수정하면 일반적으로 앱 빌드 대상은 없습니다. CI·공통 테스트·빌드 설정 변경은 여러 서비스를 다시 검사할 수 있습니다. 최초 구축은 `full_build=true`로 5개 이미지를 준비합니다. [실제 선택 로직](../scripts/ci/changed_services.py)

## digest로 고정하는 이유

일반적인 태그는 이름표를 다른 이미지에 붙일 수 있습니다. ECR은 이 프로젝트에서 태그 덮어쓰기를 제한하지만, 배포에서는 digest까지 기록해 어떤 결과물을 쓰는지 명확히 합니다.

```text
member-service:latest             이름표로 선택하는 예시
member-service@sha256:487044…     특정 이미지를 지정하는 예시
```

실제 manifest에는 64자리 전체 digest가 들어갑니다. Kubernetes는 태그와 digest가 함께 있으면 digest를 기준으로 이미지를 선택합니다. “고정”은 업데이트 금지가 아니라 **새 이미지의 식별값도 PR로 검토한다**는 뜻입니다. [Kubernetes 이미지 설명](https://kubernetes.io/docs/concepts/containers/images/)

| 파일 | 기록하는 것 |
| --- | --- |
| [kustomization.yaml](../app/msa/kustomization.yaml) | EKS에 실행할 5개 서비스의 태그·digest |
| [release.json](../deploy/release.json) | 서비스별 소스 SHA·digest, 릴리스 의도와 실행 정보 |

소스 SHA는 “어느 코드로 만들었는가”, digest는 “어느 이미지인가”, 배포 commit은 “어느 Git 배포 선언을 반영했는가”를 뜻합니다. 셋이 항상 같은 값은 아닙니다.

## Argo CD와 Kubernetes의 역할

Argo CD는 main의 `app/msa`를 읽고 변경을 반영합니다. Kubernetes의 Deployment가 Pod를 교체하고 readiness가 정상인 Pod에 요청을 전달합니다. `Synced`는 Git과 맞다는 뜻이고, `Healthy`는 Argo가 판단한 자원 상태가 정상이라는 뜻입니다. 홈페이지와 API까지 확인해야 사용자가 체감하는 정상 여부를 알 수 있습니다.

회원 서비스 HPA가 조절하는 replica 값은 Argo가 임의로 되돌리지 않도록 제외했습니다. 프런트엔드 2개·PDB·종료 대기를 구성하지만 모든 장애의 무중단을 보장하지는 않습니다.

## 자동 생성 PR의 검사와 사람의 승인은 다름

`GITHUB_TOKEN`은 Actions에 자동 제공되는 인증값입니다. 봇이 이 토큰으로 릴리스 PR을 생성하면 PR 검사 실행에 별도 승인이 요구될 수 있습니다. GitHub App 설치 토큰을 사용하면 이 흐름을 자동으로 연결할 수 있습니다. **현재 GitHub App은 미설정입니다.** [GitHub 공식 정책](https://docs.github.com/en/actions/concepts/security/github_token)

이 실행 승인과 팀원의 코드 리뷰 `Approve`는 별개입니다. App을 설치해도 사람의 리뷰·main 보호는 유지합니다. [설정 절차](learning/STUDY-NOTES.md)

## 배포 검증과 복구

내부 러너는 배포를 변경하지 않고 결과를 조회합니다. [왜 내부 러너인가?](14-security-and-verification.md) 검증 실패가 곧 자동 롤백을 뜻하지는 않습니다. 이전 이미지 존재와 DB 호환성을 확인한 뒤 [롤백 PR](ROLLBACK.md)로 복구합니다.

[홈](../README.md) · [보안과 검증 상세](14-security-and-verification.md) · [구축 실습](learning/STUDY-NOTES.md)
