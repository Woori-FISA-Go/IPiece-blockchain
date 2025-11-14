#!/bin/bash

source .env

while true; do
    clear
    echo "════════════════════════════════════════"
    echo "🎨 IPiece 토큰 관리 시스템"
    echo "════════════════════════════════════════"
    echo ""
    echo "--- 토큰 관리 ---"
    echo "1. 모든 토큰 목록 보기"
    echo "2. 새 토큰 생성"
    echo "3. 토큰 상세 정보"
    echo "4. 토큰 전송"
    echo "5. 화이트리스트 추가"
    echo ""
    echo "--- 배당 관리 ---"
    echo "6. 배당 가이드 보기"
    echo "7. 배당 사전 시뮬레이션"
    echo "8. 배당 실행"
    echo "9. 배당 결과 확인"
    echo ""
    echo "--- 시스템 관리 ---"
    echo "10. Admin 잔고 확인"
    echo "11. KRWT 발행 (테스트용)"
    echo "12. 🔄 전체 시스템 리셋 및 재배포"
    echo "0. 종료"
    echo ""
    echo "════════════════════════════════════════"
    read -p "선택: " CHOICE
    echo ""
    
    case $CHOICE in
        1)
            ./list_tokens.sh
            ;;
        2)
            ./create_token.sh
            ;;
        3)
            read -p "상세 정보를 볼 토큰의 주소: " TOKEN_ARGS
            ./token_info.sh $TOKEN_ARGS
            ;;
        4)
            ./transfer_token.sh
            ;;
        5)
            ./manage_whitelist.sh
            ;;
        6)
            ./dividend_guide.sh
            ;;
        7)
            ./check_before_dividend.sh
            ;;
        8)
            ./distribute_dividend.sh
            ;;
        9)
            ./check_dividend_result.sh
            ;;
        10)
            echo "════════════════════════════════════════"
            echo "💰 Admin 잔고"
            echo "════════════════════════════════════════"
            echo ""
            ETH_BAL_WEI=$(cast balance $ADMIN_ADDRESS --rpc-url $BESU_RPC_URL)
            echo "ETH: $(cast --to-unit $ETH_BAL_WEI ether)"
            echo ""
            KRWT_BAL_HEX=$(cast call $KRWT_CONTRACT_ADDRESS "balanceOf(address)" $ADMIN_ADDRESS --rpc-url $BESU_RPC_URL)
            echo "KRWT: $((16#${KRWT_BAL_HEX#0x}))"
            echo ""
            ;;
        11)
            ./mint_krwt.sh
            ;;
        12)
            ./complete_reset.sh
            echo "리셋 및 재배포가 완료되었습니다."
            echo "새로운 컨트랙트 주소를 .env 파일에 업데이트해야 합니다."
            echo "배포 로그를 확인하고, .env 파일을 수동으로 수정한 후 프로그램을 다시 시작해주세요."
            exit 0
            ;;
        0)
            echo "종료합니다."
            exit 0
            ;;
        *)
            echo "잘못된 선택입니다."
            ;;
    esac
    
    echo ""
    read -p "계속하려면 Enter를 누르세요..."
done
