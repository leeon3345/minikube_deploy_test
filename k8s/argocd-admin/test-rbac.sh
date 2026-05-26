#!/bin/bash
# ════════════════════════════════════════════════════════
#  Grad-Deploy — RBAC 권한 검증 스크립트
#  실행: bash k8s/argocd-admin/test-rbac.sh <프로젝트명> <토큰>
# ════════════════════════════════════════════════════════
set -e

PROJ=$1
TOKEN=$2
ARGOCD_SERVER="https://localhost:8080"
EXPECTED_PROJECT_NAME="minikube_deploy_test-project"
ACTUAL_PROJECT_NAME="$PROJ-project"

if [ -z "$PROJ" ] || [ -z "$TOKEN" ]; then
  echo "사용법: bash test-rbac.sh <프로젝트명> <토큰>"
  echo "예시: bash test-rbac.sh my-app eyJhbGci..."
  exit 1
fi

if [ "$ACTUAL_PROJECT_NAME" != "$EXPECTED_PROJECT_NAME" ]; then
  echo "✕ 프로젝트명 불일치"
  echo "  expected: $EXPECTED_PROJECT_NAME"
  echo "  actual:   $ACTUAL_PROJECT_NAME"
  echo "  hint: 생성된 프로젝트명과 테스트 입력값(PROJ)을 일치시키세요."
  echo "  tip: 실제 프로젝트가 minikube-test2-project 라면"
  echo "       bash test-rbac.sh minikube-test2 <token> 으로 실행해야 합니다."
  exit 1
fi

echo "▶ $PROJ 프로젝트 권한 검증 중..."
echo "서버: https://$ARGOCD_SERVER"
echo ""

echo "1. 프로젝트 정보 조회 테스트"
if curl -s -k -H "Authorization: Bearer $TOKEN" "https://$ARGOCD_SERVER/api/v1/projects/$EXPECTED_PROJECT_NAME" | grep -q "$PROJ"; then
  echo "  ✓ 프로젝트 조회 성공"
else
  echo "  ✕ 프로젝트 조회 실패 (권한 없음 또는 프로젝트명 불일치)"
fi

echo "2. 애플리케이션 목록 조회 테스트"
if curl -s -k -H "Authorization: Bearer $TOKEN" "https://$ARGOCD_SERVER/api/v1/applications?project=$EXPECTED_PROJECT_NAME" | grep -q "items"; then
  echo "  ✓ 애플리케이션 목록 조회 성공"
else
  echo "  ✕ 애플리케이션 목록 조회 실패 (권한 없음 또는 프로젝트명 불일치)"
fi
