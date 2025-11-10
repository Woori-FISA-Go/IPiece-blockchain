// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SecurityToken} from "./SecurityToken.sol";
import {DividendDistributor} from "./DividendDistributor.sol";

/**
 * @title 토큰 팩토리 (Token Factory)
 * @author IPiece 프로젝트
 * @notice 새로운 IP 상품(SecurityToken과 DividendDistributor 한 세트)을 생성하는 팩토리 컨트랙트입니다.
 * @dev 이 컨트랙트는 새로운 토큰 세트의 배포를 표준화하고 자동화합니다.
 * 생성된 컨트랙트들의 소유권은 지정된 관리자 주소로 이전됩니다.
 */
contract TokenFactory is Ownable {
    /// @notice 모든 배당금 컨트랙트에서 사용할 KRWT 토큰의 고정 주소입니다.
    address public immutable KRWT_TOKEN;
    /// @notice 새로 생성된 SecurityToken 및 DividendDistributor 컨트랙트의 소유권을 이전받을 관리자 주소입니다.
    address public admin;

    /// @notice 이 팩토리를 통해 생성된 모든 SecurityToken 컨트랙트의 주소를 저장하는 배열입니다.
    address[] public allSecurityTokens;

    /// @notice 새로운 토큰 세트가 성공적으로 생성되었을 때 발생하며, 백엔드 동기화를 위해 사용됩니다.
    event TokenSetCreated(
        address indexed securityToken,
        address indexed dividendDistributor,
        string name,
        uint256 initialSupply
    );

    /**
     * @notice 팩토리 컨트랙트를 초기화합니다.
     * @param _krwtToken 플랫폼의 KRWT 토큰 컨트랙트 주소.
     * @param _admin 생성될 컨트랙트들의 소유권을 넘겨받을 관리자 주소.
     */
    constructor(address _krwtToken, address _admin) Ownable(msg.sender) {
        require(_krwtToken != address(0), "KRWT address cannot be zero");
        require(_admin != address(0), "Admin address cannot be zero");
        KRWT_TOKEN = _krwtToken;
        admin = _admin;
    }

    /**
     * @notice 새로운 SecurityToken과 이에 연결된 DividendDistributor를 생성합니다.
     * @dev 소유자만 호출할 수 있습니다. 생성된 컨트랙트들의 소유권은 `admin` 주소로 이전됩니다.
     * @param _name 새로 생성할 SecurityToken의 이름.
     * @param _initialSupply 새로 생성할 SecurityToken의 초기 발행량.
     * @return newSecurityTokenAddress 새로 생성된 SecurityToken의 주소.
     * @return newDistributorAddress 새로 생성된 DividendDistributor의 주소.
     */
    function createTokenSet(
        string memory _name,
        uint256 _initialSupply
    ) external onlyOwner returns (address newSecurityTokenAddress, address newDistributorAddress) {
        // 1. 새로운 SecurityToken 배포
        SecurityToken newSecurityToken = new SecurityToken(_name, _initialSupply);
        newSecurityTokenAddress = address(newSecurityToken);

        // 2. 새로운 DividendDistributor를 배포하고 연결
        DividendDistributor newDistributor = new DividendDistributor(
            newSecurityTokenAddress,
            KRWT_TOKEN
        );
        newDistributorAddress = address(newDistributor);

        // 3. 새로 생성된 컨트랙트들의 소유권을 지정된 admin에게 이전
        newSecurityToken.transferOwnership(admin);
        newDistributor.transferOwnership(admin);

        // 4. 새로운 SecurityToken 주소 저장
        allSecurityTokens.push(newSecurityTokenAddress);

        // 5. 백엔드 동기화를 위한 이벤트 발생
        emit TokenSetCreated(
            newSecurityTokenAddress,
            newDistributorAddress,
            _name,
            _initialSupply
        );
    }

    /**
     * @notice 새로 생성될 컨트랙트들의 소유권을 받을 관리자 주소를 변경합니다.
     * @dev 팩토리 컨트랙트의 소유자만 호출할 수 있습니다.
     * @param _newAdmin 새로운 관리자 주소.
     */
    function setAdmin(address _newAdmin) external onlyOwner {
        require(_newAdmin != address(0), "New admin address cannot be zero");
        admin = _newAdmin;
    }

    /**
     * @notice 이 팩토리를 통해 생성된 모든 SecurityToken의 목록을 반환합니다.
     * @return SecurityToken 주소들의 배열.
     */
    function getAllSecurityTokens() external view returns (address[] memory) {
        return allSecurityTokens;
    }
}
