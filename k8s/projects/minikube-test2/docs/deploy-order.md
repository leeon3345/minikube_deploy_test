# Grad-Deploy 배포 순서 안내

## 아키텍처 개요

```
Git Push (서비스 폴더 추가)
    └─► GitHub Actions (이미지 빌드 + 태그 갱신)
              └─► Argo CD ApplicationSet (폴더 감시)
                        └─► Application 자동 생성 (서비스당 1개)
                                  └─► K8s 클러스터 자동 배포
```

**기존 방식과의 차이:**
- 기존: 서비스 추가 시마다 `argo-app.yaml` 수동 편집 + `kubectl apply` 필요
- 신규: `k8s/projects/minikube-test2/services/<새서비스폴더>` 커밋만 하면 Argo CD가 Application을 자동 생성

---

## 첫 배포 — 플랫폼 담당자 전용 (최초 1회)

아래 3단계는 **한 번만** 수동으로 apply합니다. 이후에는 Git Push만으로 자동 배포됩니다.

### 0단계 — Argo CD Admin 설정 (GitHub SSO·RBAC)

```bash
# argocd namespace에 적용 (Application sync 대상 아님)
kubectl apply -f k8s/argocd-admin/ -n argocd

# GitHub OAuth App이 준비되어 있어야 합니다.
# argocd-secret에 GitHub OAuth Client Secret 추가:
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData":{"dex.github.clientSecret":"<YOUR_CLIENT_SECRET>"}}'
```

> ⚠️ `k8s/argocd-admin/` 내 파일은 Application sync 대상에서 **반드시 제외**하세요.
> AppProject.clusterResourceWhitelist가 ConfigMap 수정을 허용하지 않습니다.

### 1단계 — AppProject 생성

```bash
kubectl apply -f k8s/projects/minikube-test2/argo-project.yaml -n argocd
```

- `minikube-test2-project` 프로젝트를 먼저 생성합니다.
- 이 단계를 건너뛰면 ApplicationSet sync 시 "project not found" 오류가 발생합니다.

### 2단계 — ApplicationSet 생성

```bash
kubectl apply -f k8s/projects/minikube-test2/argo-appset.yaml -n argocd
```

- Argo CD가 `k8s/projects/minikube-test2/services/*` 경로를 폴더 단위로 감시합니다.
- 폴더가 있으면 즉시 Application을 자동 생성합니다.
- 이후 서비스 폴더를 추가·삭제하면 Application이 자동으로 생성·삭제됩니다.

### 3단계 — ResourceQuota + LimitRange 적용

```bash
kubectl apply -f k8s/projects/minikube-test2/base/resource-quota.yaml -n default
```

- namespace `default`의 자원 상한을 설정합니다.
- AppProject `namespaceResourceBlacklist`에 의해 Application이 이 파일을 수정·삭제할 수 없습니다.

---

## 이후 배포 — 개발자 (반복)

### 신규 서비스 추가

```bash
# 1. 서비스 폴더 생성 (Grad-Deploy UI에서 자동 생성됨)
mkdir -p k8s/projects/minikube-test2/services/<new-service>
# deployment.yaml, service.yaml 등 배치

# 2. Git Push
git add k8s/projects/minikube-test2/services/<new-service>
git commit -m "feat: add <new-service>"
git push origin main

# → Argo CD ApplicationSet이 폴더를 감지하고 Application 자동 생성
```

### 이미지 태그 갱신 (CI가 자동 처리)

main 브랜치 push → GitHub Actions → `kustomization.yaml` 이미지 태그 갱신 → Argo CD 자동 sync

수동 sync:
```bash
argocd app sync minikube-test2-<서비스명> --server <ARGOCD_SERVER>
```

---

### 🚨 트러블슈팅 가이드 (장애 발생 시)

문제가 발생했을 때 다음 명령어들로 상태를 확인하세요:

1. **Argo CD 배포 상태 확인**
   ```bash
   # 특정 서비스 헬스 체크 완료 대기 (명확한 가시성)
   argocd app wait minikube-test2-<서비스명> --health
   # 동기화 문제가 있을 경우 강제 동기화 수행
   argocd app sync minikube-test2-<서비스명> --force
   # 또는 전체 애플리케이션 상태 확인
   argocd app list | grep minikube-test2
   ```

2. **Kubernetes 파드(Pod) 상태 확인**
   ```bash
   kubectl get pods -n default
   kubectl describe pod <파드이름> -n default
   ```

3. **로그 확인**
   ```bash
   kubectl logs -f deployment/<서비스명> -n default
   ```

---

## 파일 구조

```
k8s/
├── argocd-admin/                      # 플랫폼 전용 — sync 대상 제외
│   ├── argocd-cm.yaml                 # GitHub SSO OIDC 설정
│   └── argocd-rbac-cm.yaml            # RBAC policy.csv
└── projects/
    └── minikube-test2/                       # 팀별 독립 경로 (Multi-tenant)
        ├── argo-project.yaml          # AppProject (0단계)
        ├── argo-appset.yaml           # ApplicationSet (1단계) ← 핵심
        ├── argo-app.yaml              # 단일 Application (레거시 참조용)
        ├── base/
        │   └── resource-quota.yaml   # ResourceQuota + LimitRange (2단계)
        ├── services/                  # ApplicationSet Git Generator 감시 경로
        │   └── <svcName>/            # 서비스 폴더 추가 = Application 자동 생성
        │       ├── deployment.yaml
        │       ├── service.yaml
        │       ├── hpa.yaml           # HPA 활성화 시
        │       └── nginx-conf.yaml    # nginx/react-nginx 타입 시
        ├── overlays/
        │   └── production/
        │       ├── kustomization.yaml
        │       ├── networkpolicy.yaml
        │       └── ingress.yaml       # kind/local 환경만
        └── docs/
            ├── deploy-order.md        # 이 파일
            └── ingress-setup.md
.github/
└── workflows/
    └── ci.yaml                        # 이미지 빌드 + Argo CD sync 트리거
Dockerfile.<svcName>                   # 서비스별 Dockerfile
kind-config.yaml                       # kind 클러스터 설정 (kind/local)
```
