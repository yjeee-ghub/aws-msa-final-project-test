# 🔎 트러블슈팅 기록

**증상 → 원인 근거 → 조치 → 재검증 → 재발 방지** 순서로 정리합니다. 아래 1~4는 2026-10-19 실제 실행에서 관찰한 사례, 5~7은 이후 운영에 사용할 점검 절차, 8은 2026-10-20 재구축에서 실제 관찰한 설치 순서 문제입니다. 증거의 범위는 [검증 결과](VALIDATION.md)에 구분합니다.

## 1. 앱 Pod Pending: 노드 자원 부족

**증상** — 초기 배포에서 일부 앱이 Pending이었고 이벤트에 `Insufficient memory`, `Too many pods`가 표시됐습니다.

**원인 근거** — 기존 노드 4대의 스케줄링 여유와 Pod 수 제약이 부족했습니다. Pod의 requests는 배치 기준이며 실제 사용량만 보고 판단할 수 없습니다.

```powershell
kubectl get pods -n soldesk -o wide
kubectl get events -n soldesk --sort-by=.lastTimestamp
kubectl get nodes
kubectl logs deployment/cluster-autoscaler -n kube-system --tail=100
```

**조치** — 구성된 CA가 2c 노드 그룹을 확장하도록 동작했습니다. 기본 4대에서 최대 범위인 5대로 증가했습니다. 자원 제한을 무조건 없애거나 앱을 삭제하는 방법을 사용하지 않았습니다.

**재검증** — 새 노드 Ready → Pod IP 할당 → 앱 startup·readiness → 5개 Deployment 정상 → 실제 HTTPS 검사를 확인했습니다. 새 노드 초기화 중 CNI IP 할당·startupProbe 일시 실패는 이후 회복됐고 최종 앱 재시작 수는 0이었습니다.

**재발 방지** — 전체 requests·노드 Pod 한도·AZ별 확장 범위를 함께 확인합니다. 현재 최대 5대 이후 추가 부하를 모두 처리할 수 있다는 보장은 없습니다.

## 2. Lambda 생성 실패: 예약 동시 실행 한도

**증상** — 주문 메일 함수에 예약 동시 실행 2개를 설정하는 단계가 거부됐습니다.

**원인 근거** — 계정의 미예약 동시 실행 여유를 유지해야 하는 AWS 한도 조건이었습니다. 코드 오류와 계정 quota 오류를 구분했습니다.

**조치** — Lambda 예약 동시 실행을 해제하고 SQS event source mapping의 `maximum_concurrency=2`로 해당 큐의 소비 동시 실행을 제한했습니다. 함수에 예약한 실행 슬롯과 SQS에서 동시에 호출할 수 있는 수는 다른 설정입니다.

```powershell
aws lambda get-function-configuration --function-name Final-order-email --region ap-northeast-2 --query '{State:State,Update:LastUpdateStatus}'
aws lambda list-event-source-mappings --function-name Final-order-email --region ap-northeast-2 --query 'EventSourceMappings[].{State:State,Scaling:ScalingConfig}'
```

**재검증** — 수정한 Terraform 계획을 확인하고 생성 실패 자원을 다시 적용했습니다. 함수·mapping이 생성되고, SES 인증 후 Enabled로 전환됐으며 실제 주문 메일 이벤트의 SENT를 확인했습니다.

**재발 방지** — 계정 실행 한도와 소비자 설정을 사전에 확인합니다. SQS 소비 상한이 계정 전체 Lambda 부하를 통제하는 것은 아닙니다.

## 3. CI 실패: 이미 고정된 digest를 테스트가 잘못 처리

**증상** — 일부 서비스의 이미지 태그를 갱신하는 회귀 검사에서 실패했습니다.

**원인 근거** — 테스트가 “변경 줄 수는 항상 2개”, “갱신 후 manifest 전체에 digest가 없어야 한다”는 가정을 하고 있었습니다. 다른 서비스의 고정 digest는 유지되어야 하므로 현재 릴리스 구조와 맞지 않았습니다.

**조치** — 선택한 서비스 블록의 새 태그·이전 digest 제거를 검사하고, 선택하지 않은 서비스 블록은 그대로인지 비교했습니다. digest가 있는 경우와 없는 경우를 함께 확인했습니다.

```powershell
python -m unittest discover -s tests -v
```

**재검증** — Python 18개 검사와 PR 필수 CI가 성공했고, 최신 commit을 팀원이 승인한 후 정상 병합했습니다. Java 소스 변경이나 검사 우회로 해결하지 않았습니다.

**재발 방지** — 줄 수처럼 구현 모양에 의존한 검사보다 “선택 서비스만 변경되고 나머지는 보존되는가”라는 동작을 검증합니다.

## 4. 운영 이메일 오타·미확인 구독

**증상** — 잘못 입력한 주소로 SNS·SES 인증이 진행되어 올바른 주소에 다시 연결해야 했습니다.

**원인 근거** — 이메일 오타와 구독 확인 미완료 상태였습니다. AWS에서 미확인 SNS 이메일 구독의 직접 삭제가 거부됐습니다.

**조치** — 다른 구독자가 없고 이번 구축이 생성한 토픽임을 확인한 뒤 해당 운영 토픽만 재생성하고 Terraform을 재조정했습니다. 올바른 주소로 다시 인증했습니다. 이는 당시 조건을 확인한 일회성 복구이며, 공유 토픽의 일반적인 정리 방법은 아닙니다.

```powershell
aws sns list-subscriptions-by-topic --topic-arn arn:aws:sns:ap-northeast-2:193644343848:Final-operations-alerts --query 'Subscriptions[].{Endpoint:Endpoint,Subscription:SubscriptionArn}'
aws sesv2 get-email-identity --email-identity yoonjoung429@gmail.com --query '{Verified:VerifiedForSendingStatus,Status:VerificationStatus}'
```

**재검증** — 올바른 주소의 실제 SNS 구독 ARN·SES Verified 상태를 확인했습니다.

**재발 방지** — apply 전 이메일·구독자를 확인하고 기존 수신자가 있는 공유 자원을 재생성하는 조치를 그대로 따라 하지 않습니다.

## 5. 검증 job Queued 또는 봇 PR action_required — 점검 절차

| 상태 | 먼저 구분할 것 | 확인 |
| :--- | :--- | :--- |
| deploy-check가 Queued | 일회용 러너가 새 작업을 받을 준비가 됐나? | Pod·GitHub runner 라벨·online 상태 |
| bot PR의 action_required | workflow 실행 승인인가? | Actions 실행 안내 |
| PR의 REVIEW_REQUIRED | 코드 리뷰 승인이 필요한가? | 최신 변경에 대한 팀원 Approve |

```powershell
gh run list --workflow deploy-check.yml --limit 5
kubectl get pods -n deploy-check-runners
gh api repos/yjeee-ghub/aws-msa-final-project-test/actions/runners --jq '.runners[] | {name,status,busy}'
```

검증 때문에 EKS API를 전체 공개하지 않습니다. [러너 시작·정리와 App 설정](learning/STUDY-NOTES.md)

## 6. 503·Grafana Pending·새 Secret 미반영 — 점검 절차

```powershell
kubectl get ingress -A
kubectl get pods,pvc -n monitoring -o wide
kubectl get pods -n argocd
kubectl get externalsecret -n soldesk
./scripts/ops/Test-DeploymentHttps.ps1
```

503은 DNS·리스너·ALB 대상 health·Service·Pod Ready 순으로 좁힙니다. Grafana가 Pending이면 requests와 EBS AZ·PVC도 확인합니다. 메모리 문제와 데이터 보존 문제는 별개입니다.

Secret 갱신만으로 실행 중인 환경변수가 바뀌지는 않습니다. ESO와 새 버전을 확인한 다음 관련 Deployment를 순차 재시작하고 연결·기능을 검증합니다.

## 7. 주문 메일 미수신 — 점검 절차

```text
주문 완료 → Outbox → SNS 발행 → SQS 대기·DLQ
 → Lambda 오류·처리 기록 → SES 인증·수락 → 받은편지함
```

알림 경로·실제 수신자·이벤트 ID·각 단계 SENT의 의미를 확인합니다. 원인 수정 전에 메시지를 무조건 재발송하지 않습니다. [메일 구조](11-delivery.md)


## 8. 재구축 때 ESO 설치 실패: ALB webhook 준비 순서

**증상** — External Secrets Helm 설치에서 `mservice.elbv2.k8s.aws` 호출이 실패하고 `no endpoints available for service "aws-load-balancer-webhook-service"` 오류가 발생했습니다.

**원인 근거** — ALB Controller와 ESO가 병렬 설치되면서 admission webhook 설정은 등록됐지만 처리할 Controller endpoint가 아직 준비되지 않은 시점에 ESO 차트가 Service를 생성했습니다. 이후 조회에서는 Controller Pod 1/1 Running과 webhook endpoint를 확인했습니다. RDS 자격증명이 틀린 문제와 구분합니다.

**조치** — `terraform-k8s/external_secrets.tf`에서 ESO가 `helm_release.load_balancer_controller` 뒤에 설치되도록 `depends_on`을 추가했습니다. Controller의 기존 `wait=true`와 연결하고, ESO에는 `atomic=true`를 추가해 설치 실패 처리를 보완했습니다. 준비된 인프라·복원 디스크를 재사용해 Terraform을 다시 적용했습니다.

첫 실패 때 Helm 릴리스가 클러스터에 남았지만 Terraform state에는 없어 재시도에서 `cannot re-use a name that is still in use`가 발생했습니다. 동일한 namespace·release의 failed 상태와 state 주소 부재를 확인한 뒤 기존 릴리스를 import하고 업그레이드했습니다. state나 namespace를 지우는 방식으로 처리하지 않았습니다.

```powershell
# 이 이름 충돌과 state 부재를 확인한 경우에만 사용하는 복구 명령
. ./terraform-k8s/Prepare-Secrets.ps1
terraform '-chdir=terraform-k8s' state list
kubectl get secret -n external-secrets -l owner=helm,name=external-secrets -o 'custom-columns=NAME:.metadata.name,STATUS:.metadata.labels.status'
terraform '-chdir=terraform-k8s' import 'helm_release.external_secrets[0]' 'external-secrets/external-secrets'
# 이후 새 plan에서 예상한 ESO 업데이트만 검토해 적용합니다.
```

**재확인** — 운영 도구 설치 후 ExternalSecret `database-credentials` Ready와 앱 기동을 확인했습니다. 이는 실제 재구축 문제를 해결한 운영 기록이며, 다섯 의도적 장애 시나리오를 완료한 결과나 최종 검증 캡처는 아닙니다.

**재발 방지** — webhook을 등록하는 Controller 설치 완료를 해당 webhook이 가로채는 리소스 생성보다 앞에 둡니다. 단순한 고정 sleep 대신 Terraform 의존 관계로 순서를 표현합니다.

CA 차트도 Service를 생성하는 것을 확인해 `terraform-k8s/cluster_autoscaler.tf`에 같은 Controller 의존 관계를 추가했습니다. 모니터링·Argo는 기존 의존 관계를 통해 그 뒤에 설치됩니다.


[홈](../README.md) · [실제 결과](VALIDATION.md) · [복습 노트](learning/STUDY-NOTES.md)
