// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

/**
 * @title KRW 토큰 (KRWT)
 * @author IPiece 프로젝트
 * @notice IPiece 플랫폼의 기축 통화인 KRWT(원화 연동 토큰) 컨트랙트입니다.
 * 모든 토큰 구매 및 배당금 지급에 사용됩니다.
 * @dev 표준 ERC20 기반의 토큰이며, 소유자(Owner)에 의해 발행(mint) 및 소각(burn)이 제어됩니다.
 */
contract KRWT is ERC20Capped, Ownable {
    /**
     * @dev 토큰의 이름, 심볼, 초기 소유자를 설정하고 최대 발행량을 설정합니다.
     */
    constructor(uint256 cap) ERC20("Korean Won Token", "KRWT") Ownable(msg.sender) ERC20Capped(cap) {}

    /**
     * @notice ERC20 표준의 decimals() 함수를 오버라이드하여 0을 반환합니다.
     * @return 0 (소수점 없음)
     */
    function decimals() public view virtual override returns (uint8) {
        return 0;
    }

    /**
     * @notice 지정된 주소에 새로운 KRWT 토큰을 발행합니다.
     * @dev 컨트랙트 소유자만 호출할 수 있습니다.
     * @param to 새로 발행된 토큰을 받을 주소.
     * @param amount 발행할 토큰의 양.
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    /**
     * @notice 지정된 주소에서 KRWT 토큰을 소각(제거)합니다.
     * @dev 컨트랙트 소유자만 호출할 수 있습니다.
     * @param from 소각할 토큰을 보유하고 있는 주소.
     * @param amount 소각할 토큰의 양.
     */
    function burn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }
}