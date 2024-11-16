// SPDX-License-Identifier: Apache 2
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title IDANKFairLaunch
 * @notice Interface for the DANK Fair Launch contract
 */
interface IDANKFairLaunch {
    function stake() external payable;
    function claimTokens() external;
    function emergencyWithdraw() external;
    function getClaimableAmounts(address user) external view returns (uint256, uint256, uint256);
    function calculateTokenAllocation(address user) external view returns (uint256);
}

/**
 * @title DANKFairLaunch
 * @dev Fair launch contract for DANK token distribution 
 * @notice This contract manages a fair launch where users can stake ETH to receive DANK tokens
 */
contract DANKFairLaunch is IDANKFairLaunch, ReentrancyGuard, AccessControl, Pausable {
    // ============ Errors ============
    error InvalidAmount(uint256 provided, uint256 required);
    error InvalidAddress(address provided);
    error InvalidState(string reason);
    error StakingError(string reason);
    error ClaimError(string reason);
    error TransferFailed(string reason);
    error Unauthorized(address caller, string reason);

    // ============ Constants ============
    uint256 public constant DURATION = 1 days;
    uint256 public constant END_BUFFER = 5 minutes;
    uint256 public constant MAX_ETH_PER_WALLET = 0.5 ether;
    uint256 public constant MIN_ETH_STAKE = 0.01 ether;
    uint256 public constant FEE_PERCENTAGE = 500; // 5% = 500 basis points
    uint256 public constant TOTAL_REWARDS = 105_172_500_000 * 1e18;
    uint256 public constant MIN_ALLOCATION = 1000;
    uint256 public constant STAKE_COOLDOWN = 1 hours;
    uint256 private constant PRECISION_SCALE = 1e18;

    // ============ Storage ============
    IERC20 public immutable dankToken;
    address public immutable feeCollector;
    
    uint256 public startTime;
    uint256 public endTime;
    uint256 public totalETHStaked;
    bool public initialized;
    
    mapping(address => uint256) public userStakes;
    mapping(address => bool) public hasStaked;
    mapping(address => bool) public hasClaimed;
    mapping(address => uint256) public lastStakeTime;

    // ============ Events ============
    event Staked(address indexed user, uint256 amount, uint256 timestamp);
    event Withdrawn(address indexed user, uint256 ethAmount, uint256 dankAmount, uint256 timestamp);
    event PoolInitialized(uint256 startTime, uint256 endTime, uint256 timestamp);
    event EmergencyWithdraw(address indexed user, uint256 amount, uint256 timestamp);
    event PoolPaused(address indexed admin, uint256 timestamp);
    event PoolUnpaused(address indexed admin, uint256 timestamp);
    event TokensRecovered(address indexed token, uint256 amount, uint256 timestamp);

    // ============ Roles ============
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /**
     * @notice Contract constructor
     * @param _dankToken Address of the DANK token contract
     * @param _feeCollector Address that will receive the fees
     */
    constructor(address _dankToken, address _feeCollector) {
        if (_dankToken == address(0)) revert InvalidAddress(_dankToken);
        if (_feeCollector == address(0)) revert InvalidAddress(_feeCollector);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);

        dankToken = IERC20(_dankToken);
        feeCollector = _feeCollector;
    }

    /**
     * @notice Initializes the fair launch pool
     * @dev Can only be called once by admin
     */
    function initializePool() external onlyRole(ADMIN_ROLE) {
        if (initialized) revert InvalidState("Already initialized");
        if (dankToken.balanceOf(address(this)) < TOTAL_REWARDS) {
            revert InvalidState("Insufficient tokens");
        }
        
        startTime = block.timestamp;
        endTime = startTime + DURATION;
        initialized = true;
        
        emit PoolInitialized(startTime, endTime, block.timestamp);
    }

    /**
     * @notice Allows users to stake ETH
     * @dev Protected against reentrancy and enforces stake limits
     */
    function stake() external payable nonReentrant whenNotPaused {
        if (!initialized) revert InvalidState("Pool not initialized");
        if (block.timestamp < startTime) revert InvalidState("Not started");
        if (block.timestamp > endTime - END_BUFFER) revert InvalidState("Too close to end");
        if (msg.value < MIN_ETH_STAKE) revert InvalidAmount(msg.value, MIN_ETH_STAKE);
        if (block.timestamp < lastStakeTime[msg.sender] + STAKE_COOLDOWN) {
            revert StakingError("Cooldown active");
        }
        
        uint256 newStake = userStakes[msg.sender] + msg.value;
        if (newStake > MAX_ETH_PER_WALLET) {
            revert InvalidAmount(newStake, MAX_ETH_PER_WALLET);
        }

        userStakes[msg.sender] = newStake;
        totalETHStaked += msg.value;
        hasStaked[msg.sender] = true;
        lastStakeTime[msg.sender] = block.timestamp;

        emit Staked(msg.sender, msg.value, block.timestamp);
    }

    /**
     * @notice Calculates token allocation for a user with improved precision
     * @param user Address of the user
     * @return uint256 Amount of tokens allocated to the user
     */
    function calculateTokenAllocation(address user) public view returns (uint256) {
        if (totalETHStaked == 0 || userStakes[user] == 0) return 0;
        
        uint256 scaledAllocation = (TOTAL_REWARDS * PRECISION_SCALE * userStakes[user]) / totalETHStaked;
        uint256 baseAllocation = scaledAllocation / PRECISION_SCALE;
        
        uint256 remainder = scaledAllocation % PRECISION_SCALE;
        if (remainder > 0) {
            baseAllocation += (remainder * userStakes[user]) / totalETHStaked;
        }
        
        return baseAllocation < MIN_ALLOCATION ? 0 : baseAllocation;
    }

    /**
     * @notice Helper function to calculate precise division
     * @param amount The base amount for calculation
     * @param numerator The numerator for the calculation
     * @param denominator The denominator for the calculation
     * @return The calculated share with precision
     */
    function _calculatePreciseShare(
        uint256 amount,
        uint256 numerator,
        uint256 denominator
    ) internal pure returns (uint256) {
        if (denominator == 0) revert InvalidAmount(denominator, 1);
        
        uint256 scaledAmount = amount * PRECISION_SCALE;
        uint256 scaledShare = (scaledAmount * numerator) / denominator;
        
        return scaledShare / PRECISION_SCALE;
    }

    /**
     * @notice Validates user staking status
     * @param user Address of the user to validate
     */
    function _validateStakeStatus(address user) internal view {
        if (!hasStaked[user]) revert StakingError("No stake found");
        if (hasClaimed[user]) revert ClaimError("Already claimed");
        if (userStakes[user] == 0) revert StakingError("Nothing to claim");
    }

    /**
     * @notice Allows users to claim their tokens and receive ETH back minus fee
     * @dev Implements CEI pattern and includes balance checks
     */
    function claimTokens() external nonReentrant {
        if (block.timestamp <= endTime) revert InvalidState("Fair launch still active");
        _validateStakeStatus(msg.sender);

        uint256 tokenAllocation = calculateTokenAllocation(msg.sender);
        if (tokenAllocation < MIN_ALLOCATION) revert ClaimError("Allocation too small");
        
        uint256 userStake = userStakes[msg.sender];
        if (dankToken.balanceOf(address(this)) < tokenAllocation) {
            revert ClaimError("Insufficient tokens");
        }

        hasClaimed[msg.sender] = true;
        
        uint256 feeAmount = _calculatePreciseShare(userStake, FEE_PERCENTAGE, 10000);
        uint256 remainingETH = userStake - feeAmount;

        (bool feeSuccess, ) = feeCollector.call{value: feeAmount}("");
        if (!feeSuccess) revert TransferFailed("Fee transfer failed");

        (bool ethSuccess, ) = msg.sender.call{value: remainingETH}("");
        if (!ethSuccess) revert TransferFailed("ETH return failed");

        if (!dankToken.transfer(msg.sender, tokenAllocation)) {
            revert TransferFailed("Token transfer failed");
        }

        emit Withdrawn(msg.sender, remainingETH, tokenAllocation, block.timestamp);
    }

    /**
     * @notice Emergency function to allow users to withdraw their staked ETH
     * @dev Only callable when contract is paused
     */
    function emergencyWithdraw() external nonReentrant {
        if (!paused()) revert InvalidState("Contract must be paused");
        _validateStakeStatus(msg.sender);
        
        uint256 userStake = userStakes[msg.sender];
        if (address(this).balance < userStake) {
            revert InvalidState("Insufficient contract balance");
        }

        hasClaimed[msg.sender] = true;
        
        (bool success, ) = msg.sender.call{value: userStake}("");
        if (!success) revert TransferFailed("ETH transfer failed");
        
        emit EmergencyWithdraw(msg.sender, userStake, block.timestamp);
    }

    /**
     * @notice View function to check claimable amounts
     * @param user Address to check claimable amounts for
     * @return tokenAmount Amount of tokens claimable
     * @return ethAmount Amount of ETH returnable
     * @return feeAmount Amount of ETH fee
     */
    function getClaimableAmounts(address user) external view returns (
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 feeAmount
    ) {
        if (!hasStaked[user] || hasClaimed[user]) {
            return (0, 0, 0);
        }

        uint256 userStake = userStakes[user];
        feeAmount = _calculatePreciseShare(userStake, FEE_PERCENTAGE, 10000);
        ethAmount = userStake - feeAmount;
        tokenAmount = calculateTokenAllocation(user);

        return (tokenAmount, ethAmount, feeAmount);
    }

    /**
     * @notice Pauses the contract
     * @dev Only callable by accounts with PAUSER_ROLE
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
        emit PoolPaused(msg.sender, block.timestamp);
    }

    /**
     * @notice Unpauses the contract
     * @dev Only callable by accounts with PAUSER_ROLE
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
        emit PoolUnpaused(msg.sender, block.timestamp);
    }

    /**
     * @notice Recovers stuck tokens after fair launch ends
     * @param token Address of the token to recover
     * @param amount Amount of tokens to recover
     */
    function recoverTokens(address token, uint256 amount) external onlyRole(ADMIN_ROLE) {
        if (token == address(dankToken) && block.timestamp <= endTime + 30 days) {
            revert InvalidState("Cannot withdraw DANK tokens during active period");
        }
        
        if (!IERC20(token).transfer(msg.sender, amount)) {
            revert TransferFailed("Token recovery failed");
        }
        
        emit TokensRecovered(token, amount, block.timestamp);
    }
}