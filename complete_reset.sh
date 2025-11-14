#!/bin/bash

echo "════════════════════════════════════════"
echo "🔄 전체 시스템 리셋 및 재배포"
echo "════════════════════════════════════════"
echo ""

echo "1. Foundry 캐시 및 빌드 아티팩트 삭제 중..."
rm -rf contracts/cache
rm -rf contracts/out
echo "   ✅ 완료"
echo ""

echo "2. 최종 배포 스크립트 실행 중..."
./final_deploy.sh

echo ""
echo "✅ 모든 작업이 완료되었습니다."
echo "════════════════════════════════════════"