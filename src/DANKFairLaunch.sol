// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract DANKFairLaunch is ReentrancyGuard, Ownable, Pausable {
    // State variables
    IERC20 public immutable dankToken;
    uint256 public constant DURATION = 5 days;
    uint256 public constant MAX_ETH_PER_WALLET = 0.5 ether;
    uint256 public constant FEE_PERCENTAGE = 500; // 5%
    uint256 public constant TOTAL_REWARDS = 105_172_500_000 * 1e18; // 25% of total supply

    uint256 public startTime;
    uint256 public endTime;
    uint256 public totalETHStaked;
    
    mapping(address => uint256) public userStakes;
    mapping(address => bool) public hasStaked;
    
    address public immutable feeCollector;
    bool public initialized;

    // Events
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 ethAmount, uint256 dankAmount);
    event PoolInitialized(uint256 startTime, uint256 endTime);

    constructor(
        address _dankToken,
        address _feeCollector
    ) {
        require(_dankToken != address(0), "Invalid token address");
        require(_feeCollector != address(0), "Invalid fee collector");
        dankToken = IERC20(_dankToken);
        feeCollector = _feeCollector;
    }

    // Initialize pool - can only be called once
    function initializePool() external onlyOwner {
        require(!initialized, "Already initialized");
        startTime = block.timestamp;
        endTime = startTime + DURATION;
        initialized = true;
        emit PoolInitialized(startTime, endTime);
    }

    // Stake ETH
    function stake() external payable nonReentrant whenNotPaused {
        require(initialized, "Pool not initialized");
        require(block.timestamp >= startTime, "Not started");
        require(block.timestamp <= endTime, "Ended");
        require(msg.value > 0, "Zero stake");
        
        uint256 newStake = userStakes[msg.sender] + msg.value;
        require(newStake <= MAX_ETH_PER_WALLET, "Exceeds max stake");

        userStakes[msg.sender] = newStake;
        totalETHStaked += msg.value;
        hasStaked[msg.sender] = true;
    }
} 