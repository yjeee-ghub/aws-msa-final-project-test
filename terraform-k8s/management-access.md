# 관리 화면 접속

| 주소 | 대상 |
| --- | --- |
| https://server.aws-yjeee.com | 쇼핑몰 |
| https://argocd.aws-yjeee.com | Argo CD |
| https://grafana.aws-yjeee.com | Grafana |

세 도메인은 `final-shared-alb`를 공유합니다. ACM 인증 CNAME과 실제 접속용 A Alias는 역할이 다릅니다. [도메인 구조](../docs/01-architecture.md)

관리 Ingress 준비 → ALB 생성 확인 → DNS 활성화 순서입니다. 초기 설치·비밀번호 확인·port-forward는 [실습 가이드](../docs/learning/STUDY-NOTES.md)를 따릅니다. Prometheus는 외부 공개하지 않습니다.
