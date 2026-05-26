#!/bin/bash
# ════════════════════════════════════════════════════════
#  Grad-Deploy — Argo CD GitHub SSO 초기화 스크립트
#  실행: bash k8s/argocd-admin/setup.sh
#
#  사전 준비:
#    1) GitHub OAuth App 생성 (README 참고)
#    2) CLIENT_ID, CLIENT_SECRET 환경변수 설정 후 실행
#       export ARGOCD_CLIENT_ID="Ov23li..."
#       export ARGOCD_CLIENT_SECRET="abc123..."
# ════════════════════════════════════════════════════════
set -euo pipefail

ARGOCD_NS="argocd"

echo "▶ 1단계: argocd-cm 적용 (GitHub SSO dex 설정)"
kubectl apply -f "$(dirname "$0")/argocd-cm.yaml" -n "${ARGOCD_NS}"

echo "▶ 2단계: argocd-rbac-cm 적용 (RBAC 정책)"
kubectl apply -f "$(dirname "$0")/argocd-rbac-cm.yaml" -n "${ARGOCD_NS}"

echo "▶ 3단계: GitHub OAuth Client Secret 주입"
# Client Secret 은 절대 Git 에 커밋하지 마세요.
# argocd-secret 에 직접 patch 합니다.
if [ -z "${ARGOCD_CLIENT_SECRET:-}" ]; then
  echo "  ⚠ ARGOCD_CLIENT_SECRET 환경변수가 없습니다."
  read -rsp "  GitHub OAuth Client Secret 입력: " ARGOCD_CLIENT_SECRET
  echo ""
fi

kubectl patch secret argocd-secret -n "${ARGOCD_NS}" \
  --type='json' \
  -p="[{\"op\":\"add\",\"path\":\"/data/dex.github.clientSecret\",\"value\":\"$(echo -n ${ARGOCD_CLIENT_SECRET} | base64 | tr -d '\n')\"}]"
echo "  ✓ Client Secret 주입 완료"

echo "▶ 4단계: dex 및 server 재시작 (설정 반영)"
kubectl rollout restart deployment argocd-dex-server -n "${ARGOCD_NS}"
kubectl rollout restart deployment argocd-server -n "${ARGOCD_NS}"
kubectl rollout status deployment argocd-dex-server -n "${ARGOCD_NS}" --timeout=60s
kubectl rollout status deployment argocd-server -n "${ARGOCD_NS}" --timeout=60s

echo "▶ 5단계: deploy-role 전용 토큰 발급 안내"
EXPECTED_PROJECT_NAME="minikube_deploy_test-project"
PROJECT_NAME="${ARGOCD_PROJECT:-$EXPECTED_PROJECT_NAME}"

if [ -n "${ARGOCD_PROJECT:-}" ] && [ "$PROJECT_NAME" != "$EXPECTED_PROJECT_NAME" ]; then
  echo "✕ 프로젝트명 불일치"
  echo "  expected: $EXPECTED_PROJECT_NAME"
  echo "  actual:   $PROJECT_NAME"
  echo "  hint: ARGOCD_PROJECT 값을 비우거나, 실제 Argo CD project name 으로 맞추세요."
  exit 1
fi

echo "  expected project: $EXPECTED_PROJECT_NAME"
echo "  selected project : $PROJECT_NAME"
cat <<EOF
  ────────────────────────────────────────────────────
  GitHub Secret ARGOCD_TOKEN 에는 admin 토큰 대신
  deploy-role 전용 토큰을 등록해야 합니다. (최소 권한 원칙)

  발급 방법 (Argo CD CLI):
    argocd login https://localhost:8080
    argocd proj role create-token "$PROJECT_NAME" deploy-role

  발급한 토큰을 GitHub Repository Secret 에 등록:
    gh secret set ARGOCD_TOKEN --body "<발급된 토큰>"
  ────────────────────────────────────────────────────
EOF

echo ""
echo "✅ Argo CD GitHub SSO 설정 완료"
echo "   브라우저에서 https://https://localhost:8080 접속 후"
echo "   'Login with GitHub' 버튼으로 SSO 인증을 확인하세요."