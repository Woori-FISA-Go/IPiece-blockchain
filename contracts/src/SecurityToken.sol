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
     * @notice 특정 주소가 토큰을 보유하고 전송할 수 있도록 승인되었는지 확인하기 위한 매핑입니다.
     */
    mapping(address => bool) public whitelist;
    
    /**
     * @notice 계정이 화이트리스트에 추가되었을 때 발생하는 이벤트입니다.
     * @param account 화이트리스트에 추가된 계정 주소.
     */
    event AddedToWhitelist(address indexed account);
    
    /**
     * @notice 토큰의 이름, 심볼, 초기 발행량, 그리고 초기 소유자를 설정합니다.
     * @param _name 토큰의 이름 (일반적으로 IP 캐릭터의 이름).
     * @param _supply 초기에 발행될 총 토큰의 수량.
     * @param initialOwner 컨트랙트의 초기 소유자가 될 주소. 이 주소는 자동으로 화이트리스트에 추가됩니다.
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _supply,
        address initialOwner
    ) 
        ERC20(_name, _symbol) 
        Ownable(initialOwner)  // initialOwner를 Owner로 설정
    {
        // 소수점이 없으므로, _supply를 그대로 발행합니다.
        _mint(initialOwner, _supply);
        whitelist[initialOwner] = true;     // initialOwner를 화이트리스트에 추가
        emit AddedToWhitelist(initialOwner);
    }

    /**
     * @dev 토큰의 소수점 자릿수를 반환합니다.
     * 소수점 거래를 지원하지 않으므로 0을 반환합니다.
     */
    function decimals() public view virtual override returns (uint8) {
        return 0;
    }
    
    /**
     * @notice 새로운 주소를 화이트리스트에 추가하여 토큰을 보유하고 전송할 수 있도록 허용합니다.
     * @dev 컨트랙트 소유자만 호출할 수 있습니다.
     * @param account 화이트리스트에 추가할 주소.
     */
    function addToWhitelist(address account) external onlyOwner {
        whitelist[account] = true;
        emit AddedToWhitelist(account);
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

    /**
     * @notice `from` 주소의 토큰을 `to` 주소로 전송합니다.
     * @dev 표준 ERC20 `transferFrom` 함수를 오버라이드합니다.
     * 이 기능은 제한적이며, 보내는 사람과 받는 사람 모두 화이트리스트에 등록되어 있어야 합니다.
     * @param from 토큰을 보낼 주소.
     * @param to 토큰을 받을 주소.
     * @param amount 전송할 토큰의 양.
     * @return 작업 성공 여부를 나타내는 불리언 값.
     */
    function transferFrom(address from, address to, uint256 amount) 
        public override returns (bool) 
    {
        require(whitelist[from], "Not whitelisted");
        require(whitelist[to], "Recipient not whitelisted");
        return super.transferFrom(from, to, amount);
    }
}