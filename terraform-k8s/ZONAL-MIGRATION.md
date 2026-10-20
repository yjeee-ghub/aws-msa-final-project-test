# AZ별 노드 그룹과 저장소 배치

현재 설계는 서울 2a·2c의 AZ별 노드 그룹입니다. `terraform/eks.tf`의 node_pools가 최소·초기·최대를 결정합니다. 2a는 2대, 2c는 2~3대로 전체 기본 4대·최대 5대입니다. `keep_legacy_node_group=false`가 기본이며 새 구축에서 이전 다중 AZ 그룹을 추가할 필요는 없습니다.

EBS는 AZ에 속하므로 모니터링 Pod를 다른 AZ에 배치하는 것만으로 디스크를 붙일 수 없습니다. Grafana·Prometheus의 배치 조건과 확장 여유를 함께 확인합니다. 단일 Pod·단일 AZ 디스크가 AZ 전체 장애에서 무중단인 것은 아닙니다.

```powershell
kubectl get nodes -L eks.amazonaws.com/nodegroup,final-node-pool,topology.kubernetes.io/zone
kubectl get pods,pvc -n monitoring -o wide
kubectl get events -n monitoring --sort-by=.lastTimestamp
```

다른 기존 환경의 노드 그룹을 실제 이전하는 작업은 현 state·디스크·용량·drain 조건을 별도로 검토해야 합니다. 현재 구성의 신규 구축 절차에 과거 이전 단계를 섞지 않습니다. [구축 순서](../docs/learning/STUDY-NOTES.md) · [문제 해결](../docs/TROUBLESHOOTING.md)
