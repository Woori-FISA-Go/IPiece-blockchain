#!/bin/bash

source .env

while true; do
    clear
    echo "════════════════════════════════════════"
    echo "🎨 IPiece 토큰 관리 시스템"
    echo "════════════════════════════════════════"
    echo ""
    echo "1. 모든 토큰 목록 보기"
    echo "2. 새 토큰 생성"
    echo "3. 토큰 상세 정보"
    echo "4. 토큰 전송"
    echo "5. 화이트리스트 추가"
    echo "6. 배당 분배"
    echo "7. Admin 잔고 확인"
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
            read -p "상세 정보를 볼 토큰의 주소: " TOKEN
            ./token_info.sh $TOKEN
            ;;
        4)
            ./transfer_token.sh
            ;;
        5)
            ./manage_whitelist.sh
            ;;
        6)
            ./distribute_dividend.sh
            ;;
        7)
            echo "════════════════════════════════════════"
            echo "💰 Admin 잔고"
            echo "════════════════════════════════════════"
            echo ""
            ETH_BAL_WEI=$(cast balance $ADMIN_ADDRESS --rpc-url $BESU_RPC_URL)
            echo "ETH: $(cast --to-unit $ETH_BAL_WEI ether)"
            echo ""
            KRWT_BAL_WEI=$(cast call $KRWT_CONTRACT_ADDRESS "balanceOf(address)" $ADMIN_ADDRESS --rpc-url $BESU_RPC_URL)
            echo "KRWT: $(cast --to-unit $KRWT_BAL_WEI ether)"
            echo ""
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
