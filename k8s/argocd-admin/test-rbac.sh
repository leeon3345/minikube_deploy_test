#!/bin/bash
# ════════════════════════════════════════════════════════
#  Grad-Deploy — RBAC 권한 검증 스크립트
#  실행: bash k8s/argocd-admin/test-rbac.sh <프로젝트명> <토큰>
# ════════════════════════════════════════════════════════
set -e

PROJ=$1
TOKEN=$2
ARGOCD_SERVER="https://localhost:8080"

if [ -z "$PROJ" ] || [ -z "$TOKEN" ]; then
  echo "사용법: bash test-rbac.sh <프로젝트명> <토큰>"
  echo "예시: bash test-rbac.sh my-app eyJhbGci..."
  exit 1
fi

echo "▶ $PROJ 프로젝트 권한 검증 중..."
echo "서버: https://$ARGOCD_SERVER"
echo ""

echo "1. 프로젝트 정보 조회 테스트"
if curl -s -k -H "Authorization: Bearer $TOKEN" "https://$ARGOCD_SERVER/api/v1/projects/$PROJ-project" | grep -q "$PROJ"; then
  echo "  ✓ 프로젝트 조회 성공"
else
  echo "  ✕ 프로젝트 조회 실패 (권한 없음)"
fi

echo "2. 애플리케이션 목록 조회 테스트"
if curl -s -k -H "Authorization: Bearer $TOKEN" "https://$ARGOCD_SERVER/api/v1/applications?project=$PROJ-project" | grep -q "items"; then
  echo "  ✓ 애플리케이션 목록 조회 성공"
else
  echo "  ✕ 애플리케이션 목록 조회 실패 (권한 없음)"
fi
