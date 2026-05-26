# Nginx Ingress Controller 설치 안내

## kind 전용 설치 (extraPortMappings 필요)

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# 설치 완료 대기
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

## 접속 확인

kind-config.yaml의 extraPortMappings에 hostPort:80을 매핑했으면
http://localhost/{path} 로 접속 가능합니다.

## 서비스별 Ingress 경로

Grad-Deploy가 자동 생성한 `k8s/projects/minikube-test2/overlays/production/ingress.yaml`을 확인하세요.
