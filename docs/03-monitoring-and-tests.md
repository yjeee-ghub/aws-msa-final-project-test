# 모니터링과 알림

모니터링은 **현재 상태를 수집하고, 의미 있는 이상을 발견하고, 대응할 사람에게 전달하는 과정**입니다. “알림 설정이 있다”와 “실제로 받아봤다”는 다르므로 결과는 [실행 기록](VALIDATION.md)에 구분합니다.

## 어떤 도구에서 무엇을 보는가?

| 도구 | 역할 | 확인할 질문 |
| --- | --- | --- |
| Prometheus | Kubernetes·앱 지표 수집 및 알림 조건 평가 | CPU·메모리·Ready 수가 어떤가? |
| Grafana | 지표를 그래프로 표현 | 언제부터 상태가 달라졌나? |
| Alertmanager | 알림 묶기·전달 | 어떤 운영 알림을 누구에게 보낼까? |
| CloudWatch | AWS 지표·로그·경보 | RDS·SQS·Lambda에서 문제가 생겼나? |
| CloudTrail | AWS API 작업 감사 기록 | 누가 어떤 자원을 변경했나? |
| Kubernetes 이벤트 | 배치·시작·Probe 등 상태 변화 | Pod가 Pending인 이유가 무엇인가? |

## 알림 경로는 운영과 주문을 분리

```text
운영: Prometheus → Alertmanager ──────────────┐
      CloudWatch 경보 / 노드 시작·종료 이벤트 ─┼→ 운영 SNS → 확인된 이메일 구독
                                            │
주문: 주문 Outbox → 주문 SNS → SQS → Lambda → SES → 주문 회원 이메일
```

SNS의 **토픽**은 메시지 채널이고 **구독**은 수신 대상 등록입니다. SNS가 모든 장애를 스스로 감지하는 것은 아닙니다. 고객 주문 메일은 운영 SNS의 직접 이메일 구독과 별개입니다.

## SQS와 DLQ

SQS는 처리할 메시지를 보관하는 대기열입니다. 처리 중에는 visibility timeout 동안 다른 소비자에게 숨겨지고, 처리 성공 후 삭제됩니다. 실패가 반복되면 DLQ로 이동합니다. DLQ는 반복 실패 메시지를 보관하는 별도 큐입니다.

메일 소비자는 Lambda입니다. SQS 배치 중 실패 항목을 반환해 해당 메시지를 재시도하며, DynamoDB로 이미 처리한 이벤트를 확인합니다. **SES 수락 직후 기록 전에 종료되는 구간에는 중복 메일 가능성이 남습니다.** 원인 수정과 실제 발송 여부를 확인한 뒤 선택적으로 redrive합니다.

## 자동 확장을 두 단계로 보기

| 기능 | 조절 대상 | 관찰 포인트 |
| --- | --- | --- |
| HPA | 회원 서비스의 Pod 수 | CPU 지표, 최소 1·최대 3 replica |
| Cluster Autoscaler | 노드 그룹의 서버 수 | 자원·배치 조건 때문에 스케줄 불가한 Pod |

Pod가 늘었다고 반드시 노드가 늘어나는 것은 아닙니다. 남은 자원에 배치되면 기존 노드로 처리합니다. 디스크 AZ, taint, Pod IP 제한 때문에 배치가 안 될 수도 있습니다.

```powershell
kubectl get hpa -n soldesk
kubectl top nodes
kubectl top pods -n soldesk
kubectl get nodes
kubectl get events -n soldesk --sort-by=.lastTimestamp
```

관리자가 부여받은 권한으로 실행하는 명령입니다. 검증 러너의 조회 역할에는 모든 운영 명령을 허용하지 않습니다.

## 관찰 후 기록할 항목

증상·발생 시각, 영향을 받은 사용자 기능, 지표와 이벤트, 원인 가설, 조치, 복구 확인, 재발 방지를 함께 기록합니다. 로그·화면 캡처에 비밀번호·토큰·고객 이메일을 넣지 않습니다.

[홈](../README.md) · [문제 해결](TROUBLESHOOTING.md) · [장애 실습](10-live-validation.md)
