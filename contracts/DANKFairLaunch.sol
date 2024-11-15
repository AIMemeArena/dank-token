// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract DANKFairLaunch is ReentrancyGuard, Ownable(msg.sender), Pausable {
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

        // Collect fee first
        uint256 netStakeAmount = _collectFee(msg.value);

        userStakes[msg.sender] = newStake;
        totalETHStaked += netStakeAmount;
        hasStaked[msg.sender] = true;

        emit Staked(msg.sender, netStakeAmount);
    }

    // Calculate rewards based on stake and time
    function calculateRewards(address user) public view returns (uint256) {
        if (!hasStaked[user]) return 0;
        if (totalETHStaked == 0) return 0;
        
        uint256 userShare = (userStakes[user] * 1e18) / totalETHStaked;
        return (TOTAL_REWARDS * userShare) / 1e18;
    }

    // Withdraw stake and rewards after pool ends
    function withdraw() external nonReentrant {
        require(block.timestamp > endTime, "Pool not ended");
        require(hasStaked[msg.sender], "Nothing staked");

        uint256 ethAmount = userStakes[msg.sender];
        uint256 dankAmount = calculateRewards(msg.sender);

        // Reset user state before transfers
        userStakes[msg.sender] = 0;
        hasStaked[msg.sender] = false;

        // Transfer rewards first
        bool success = dankToken.transfer(msg.sender, dankAmount);
        require(success, "DANK transfer failed");

        // Transfer ETH
        (bool ethSuccess,) = msg.sender.call{value: ethAmount}("");
        require(ethSuccess, "ETH transfer failed");

        emit Withdrawn(msg.sender, ethAmount, dankAmount);
    }

    // Fee collection in stake function
    function _collectFee(uint256 amount) internal returns (uint256) {
        uint256 fee = (amount * FEE_PERCENTAGE) / 10000;
        (bool success,) = feeCollector.call{value: fee}("");
        require(success, "Fee transfer failed");
        return amount - fee;
    }

    // Emergency functions
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function emergencyWithdraw() external nonReentrant {
        require(hasStaked[msg.sender], "Nothing staked");
        uint256 amount = userStakes[msg.sender];
        
        // Reset state before transfer
        userStakes[msg.sender] = 0;
        hasStaked[msg.sender] = false;
        
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    // Required to receive ETH
    receive() external payable {}

    // View functions for frontend
    function getUserStake(address user) external view returns (uint256) {
        return userStakes[user];
    }

    function getPoolInfo() external view returns (
        uint256 _totalStaked,
        uint256 _startTime,
        uint256 _endTime,
        bool _initialized
    ) {
        return (
            totalETHStaked,
            startTime,
            endTime,
            initialized
        );
    }
} 