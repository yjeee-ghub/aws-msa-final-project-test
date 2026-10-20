# 앱과 데이터 처리

앱은 회원·상품·주문·Gateway·프런트엔드로 구성합니다. 운영 환경의 장애와 재시도를 설명할 수 있도록 요청 중복, 재고 처리, 이벤트 발행을 구분합니다.

## 사용자 기능과 인증

- 회원가입·로그인, 상품 조회·관리자 등록, 이미지 업로드, 수량 선택·장바구니·상품별 주문을 제공합니다.
- JWT는 로그인 신원을 증명하는 서명된 토큰입니다. Gateway가 검증하고 클라이언트가 보낸 사용자 ID·권한·내부 인증 헤더를 신뢰하지 않습니다.
- 관리자 화면과 상품 등록 API의 권한을 확인합니다. 관리자 초기 비밀번호는 `final-admin-config`에서 주입합니다.
- 장바구니는 계정별 브라우저 저장소에 보관하고 상품별 주문을 요청합니다. 장바구니 전체가 하나의 원자적 결제·취소 거래는 아닙니다. 실제 결제·배송은 제공하지 않습니다.

## 중복 주문과 재고

**멱등성**은 같은 요청을 반복해도 의도한 효과가 중복 발생하지 않도록 하는 성질입니다. 클라이언트는 주문 요청 전에 `Idempotency-Key`를 만들고 응답 유실·202 처리 중에는 같은 키를 유지합니다.

```text
주문 요청 + Idempotency-Key
 → 회원 확인·상품 재고 예약
 → 주문 상태 진행·재고 확정
 → 주문 완료와 Outbox 기록
```

동일 회원의 같은 키·동일 요청은 기존 주문 결과로 연결합니다. 상품 서비스는 예약 키와 DB 잠금으로 재고를 관리합니다. 일시 장애 시 워커가 처리 중 상태를 재조회하며, 확정 응답 유실이나 보상 중 상태를 구분합니다. 장기 미복구는 주문 상태·상품 예약 상태·로그를 함께 확인해야 합니다.

| API | 의미 |
| --- | --- |
| POST `/ordering-service/ordering/create` | `productId`, `productCount`, `Idempotency-Key`로 주문 |
| GET `/ordering-service/ordering/{id}` | 본인 주문의 결과 조회 |
| GET `/ordering-service/ordering/mine` | 본인 주문 목록 |

생성 응답은 `{id, productId, quantity, status, productName, unitPrice}`입니다. 완료 201, 처리 중 202, 실패 409를 구분합니다. 내부 재고·회원 조회 API는 공유 내부 키로 보호하며 외부 Gateway에서 내부 경로 접근을 제한합니다.

## Outbox와 주문 메일

**Outbox**는 DB에 처리해야 할 이벤트를 함께 저장하고 나중에 발행하는 패턴입니다. 주문 저장 직후 프로세스가 종료되어 알림 발행을 놓치는 구간을 줄입니다.

```text
주문 완료·Outbox 기록 → 발행 워커 → 주문 SNS → SQS
                                                  ↓
                                  DynamoDB ← Lambda → SES
```

Outbox는 PENDING → SENDING → SENT 상태를 관리합니다. 실패 시 재시도하며 정해진 시도 이후 FAILED가 되면 운영자가 원인을 수정하고 해당 이벤트만 재처리합니다. Outbox SENT는 SNS 수락을 뜻합니다.

Lambda는 이벤트 형식을 검사하고 DynamoDB에서 처리 상태를 확인한 뒤 SES로 보냅니다. 처리 기록은 만료 기간이 있으며 SES 수락 후 DynamoDB 기록 전 종료되면 중복 메일 가능성이 남습니다. 정확히 한 번 받은편지함 도착을 보장하지 않습니다.

## 비밀값 전달

| 값 | 관리 경로 |
| --- | --- |
| DB 관리자 비밀번호 | RDS 생성 → Secrets Manager → ESO → `db-credentials/DB_PW` |
| JWT·Refresh·내부 키 | Prepare-Secrets → Terraform write-only → `my-app-secrets` |
| 관리자 비밀번호·메일 | Prepare-Admin → `final-admin-config` |

Secret의 Base64 인코딩 자체는 암호화가 아닙니다. 접근 권한을 제한하고 값·환경변수·state·plan을 Git이나 공유 로그에 올리지 않습니다. Secret을 환경변수로 읽는 앱은 값 교체 뒤 새 Pod가 필요합니다.

## DB 변경과 복구 경계

주문 상태 마이그레이션에는 Flyway가 사용되고 일부 스키마는 Hibernate update로 준비됩니다. 이미지 롤백이 DB 스키마를 되돌리지는 않습니다. 기존 데이터가 있는 DB에 적용할 때는 별도 검증·스냅샷·이전 앱 호환성을 확인합니다. [복원 실습](08-rds-restore-lab.md) · [이미지 롤백](ROLLBACK.md)

[홈](../README.md) · [직접 실행](learning/STUDY-NOTES.md)
