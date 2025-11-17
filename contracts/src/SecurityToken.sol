// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title IP 권리를 위한 증권형 토큰
 * @author IPiece 프로젝트
 * @notice 특정 지적 재산(IP) 캐릭터의 지분 소유권을 나타냅니다.
 * 모든 토큰 전송은 규제 준수를 위해 화이트리스트에 등록된 주소로만 제한됩니다.
 * @dev ERC20과 Ownable을 상속받습니다. `transfer` 함수를 오버라이드하여 화이트리스트 정책을 강제합니다.
 */
contract SecurityToken is ERC20, Ownable {
    /**
     * @notice 이 토큰이 나타내는 IP 캐릭터의 이름입니다.
     */
    string public characterName;

    /**
     * @notice 특정 주소가 토큰을 보유하고 전송할 수 있도록 승인되었는지 확인하기 위한 매핑입니다.
     */
    mapping(address => bool) public whitelist;
    
    /**
     * @notice 토큰의 이름과 초기 발행량을 설정하고, 컨트랙트 배포자를 화이트리스트에 등록합니다.
     * @param _name 토큰의 이름 (일반적으로 IP 캐릭터의 이름).
     * @param _supply 초기에 발행될 총 토큰의 수량.
     */
    constructor(string memory _name, uint256 _supply) ERC20(_name, "IPT") Ownable(msg.sender) {
        characterName = _name;
        _mint(msg.sender, _supply * 10 ** 18);
        whitelist[msg.sender] = true;
    }
    
    /**
     * @notice 새로운 주소를 화이트리스트에 추가하여 토큰을 보유하고 전송할 수 있도록 허용합니다.
     * @dev 컨트랙트 소유자만 호출할 수 있습니다.
     * @param investor 화이트리스트에 추가할 주소.
     */
    function addToWhitelist(address investor) external onlyOwner {
        whitelist[investor] = true;
    }
    
    /**
     * @notice 호출자의 토큰을 지정된 주소로 전송합니다.
     * @dev 표준 ERC20 `transfer` 함수를 오버라이드합니다.
     * 이 기능은 제한적이며, 보내는 사람과 받는 사람 모두 화이트리스트에 등록되어 있어야 합니다.
     * @param to 토큰을 받을 주소.
     * @param amount 전송할 토큰의 양.
     * @return 작업 성공 여부를 나타내는 불리언 값.
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        require(whitelist[msg.sender], "Not whitelisted");
        require(whitelist[to], "Recipient not whitelisted");
        return super.transfer(to, amount);
    }
}