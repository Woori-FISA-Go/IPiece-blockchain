// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract TokenSale is Ownable, ReentrancyGuard {
    IERC20 public securityToken;
    IERC20 public krwt;

    uint256 public price; // Number of KRWT per one SecurityToken (with 18 decimals)
    uint256 public softCap; // Minimum KRWT to be raised
    uint256 public hardCap; // Maximum KRWT to be raised
    uint256 public startTime;
    uint256 public endTime;

    uint256 public totalKrwtRaised;
    mapping(address => uint256) public contributions;
    address[] public contributors;

    bool public isFinalized;

    event TokensPurchased(address indexed buyer, uint256 krwtAmount, uint256 tokenAmount);
    event SaleFinalized(uint256 totalRaised);
    event RefundsProcessed();

    constructor(
        address _securityTokenAddress,
        address _krwtAddress,
        uint256 _price,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _startTime,
        uint256 _endTime
    ) Ownable(msg.sender) {
        require(_securityTokenAddress != address(0) && _krwtAddress != address(0), "Zero address");
        require(_price > 0, "Price must be > 0");
        require(_softCap > 0 && _hardCap >= _softCap, "Invalid caps");
        require(_startTime >= block.timestamp && _endTime > _startTime, "Invalid times");

        securityToken = IERC20(_securityTokenAddress);
        krwt = IERC20(_krwtAddress);
        price = _price;
        softCap = _softCap;
        hardCap = _hardCap;
        startTime = _startTime;
        endTime = _endTime;
    }

    function buyTokens(uint256 krwtAmount) external nonReentrant {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Sale not active");
        require(krwtAmount > 0, "Amount must be > 0");
        require(totalKrwtRaised + krwtAmount <= hardCap, "Hard cap exceeded");

        if (contributions[msg.sender] == 0) {
            contributors.push(msg.sender);
        }

        // Pull KRWT from the buyer's wallet to this contract
        require(krwt.transferFrom(msg.sender, address(this), krwtAmount), "KRWT transfer failed");
        
        contributions[msg.sender] += krwtAmount;
        totalKrwtRaised += krwtAmount;

        uint256 tokenAmount = (krwtAmount * (10**18)) / price;
        emit TokensPurchased(msg.sender, krwtAmount, tokenAmount);
    }

    function finalizeSale() external onlyOwner nonReentrant {
        require(block.timestamp > endTime, "Sale not ended");
        require(!isFinalized, "Sale already finalized");

        isFinalized = true;

        if (totalKrwtRaised >= softCap) {
            // Sale successful: distribute tokens
            for (uint256 i = 0; i < contributors.length; i++) {
                address contributor = contributors[i];
                uint256 krwtContributed = contributions[contributor];
                uint256 tokenAmount = (krwtContributed * (10**18)) / price;
                
                require(securityToken.transfer(contributor, tokenAmount), "Token transfer failed");
            }
            // Transfer raised KRWT to owner
            krwt.transfer(owner(), totalKrwtRaised);
        } else {
            // Sale failed: refund KRWT (Push model)
            for (uint256 i = 0; i < contributors.length; i++) {
                address contributor = contributors[i];
                uint256 krwtContributed = contributions[contributor];
                require(krwt.transfer(contributor, krwtContributed), "Refund failed");
            }
            emit RefundsProcessed();
        }
        emit SaleFinalized(totalKrwtRaised);
    }

    // Helper function to check contract's token balance
    function getSecurityTokenBalance() external view returns (uint256) {
        return securityToken.balanceOf(address(this));
    }
}
