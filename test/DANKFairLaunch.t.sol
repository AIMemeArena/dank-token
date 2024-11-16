// SPDX-License-Identifier: Apache 2
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/DANKFairLaunch.sol";
import "../src/DankToken.sol";

// Define custom errors from the contract
error StakingError(string reason);

contract DANKFairLaunchTest is Test {
    DankToken public dankToken;
    DANKFairLaunch public fairLaunch;
    
    address public owner = address(this);
    address public feeCollector = address(0x999);
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public carol = address(0x3);

    uint256 public constant INITIAL_MINT = 420_690_000_000 * 1e18;
    uint256 public constant FAIR_LAUNCH_AMOUNT = 105_172_500_000 * 1e18;
    
    function setUp() public {
        // Start at timestamp 1000
        vm.warp(1000);
        
        dankToken = new DankToken(
            "DANK Token",
            "DANK",
            address(this),
            INITIAL_MINT
        );

        fairLaunch = new DANKFairLaunch(address(dankToken), feeCollector);
        
        // Grant roles
        fairLaunch.grantRole(fairLaunch.ADMIN_ROLE(), address(this));
        fairLaunch.grantRole(fairLaunch.PAUSER_ROLE(), address(this));
        
        dankToken.transfer(address(fairLaunch), FAIR_LAUNCH_AMOUNT);
        
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(carol, 10 ether);
    }

    function testInitializePool() public {
        fairLaunch.initializePool();
        assertTrue(fairLaunch.initialized());
        assertEq(fairLaunch.endTime(), block.timestamp + 5 days);
    }

    function testStaking() public {
        fairLaunch.initializePool();
        
        // Set initial timestamp and ensure no cooldown
        vm.warp(block.timestamp + 3601);
        
        vm.startPrank(alice);
        fairLaunch.stake{value: 0.3 ether}();
        
        assertEq(fairLaunch.userStakes(alice), 0.3 ether);
        assertTrue(fairLaunch.hasStaked(alice));
        
        // Advance time past cooldown (1 hour + 1 second)
        vm.warp(block.timestamp + 3601);
        
        // Second stake should now work
        fairLaunch.stake{value: 0.2 ether}();
        assertEq(fairLaunch.userStakes(alice), 0.5 ether);
        vm.stopPrank();
    }

    function testMultipleStakers() public {
        fairLaunch.initializePool();
        
        // Ensure no cooldown for first stake
        vm.warp(block.timestamp + 3601);
        
        // Alice stakes
        vm.prank(alice);
        fairLaunch.stake{value: 0.3 ether}();
        
        // Bob stakes after cooldown
        vm.warp(block.timestamp + 3601);
        vm.prank(bob);
        fairLaunch.stake{value: 0.4 ether}();
        
        assertEq(fairLaunch.totalETHStaked(), 0.7 ether);
    }

    function testClaimTokens() public {
        fairLaunch.initializePool();
        
        // Ensure no cooldown for stake
        vm.warp(block.timestamp + 3601);
        
        vm.startPrank(alice);
        fairLaunch.stake{value: 0.5 ether}();
        
        // Advance time past end (5 days + 1 second)
        vm.warp(block.timestamp + 5 days + 1);
        
        uint256 initialEthBalance = alice.balance;
        uint256 initialDankBalance = dankToken.balanceOf(alice);
        
        (uint256 expectedTokens, uint256 expectedEth,) = fairLaunch.getClaimableAmounts(alice);
        
        fairLaunch.claimTokens();
        
        assertEq(alice.balance, initialEthBalance + expectedEth);
        assertEq(dankToken.balanceOf(alice), initialDankBalance + expectedTokens);
        vm.stopPrank();
    }

    function testEmergencyWithdraw() public {
        fairLaunch.initializePool();
        
        // Ensure no cooldown for stake
        vm.warp(block.timestamp + 3601);
        
        vm.startPrank(alice);
        fairLaunch.stake{value: 0.5 ether}();
        
        uint256 initialBalance = alice.balance;
        vm.stopPrank();
        
        // Pause contract
        fairLaunch.pause();
        
        vm.prank(alice);
        fairLaunch.emergencyWithdraw();
        
        assertEq(alice.balance, initialBalance + 0.5 ether);
        assertTrue(fairLaunch.hasClaimed(alice));
    }

    function testFailStakeAfterEnd() public {
        fairLaunch.initializePool();
        vm.warp(block.timestamp + 5 days - 4 minutes);
        
        vm.prank(alice);
        fairLaunch.stake{value: 0.5 ether}();
    }

    function testFailStakeOverLimit() public {
        fairLaunch.initializePool();
        
        vm.prank(alice);
        fairLaunch.stake{value: 0.6 ether}(); // Over 0.5 ETH limit
    }

    function testFailStakeBelowMinimum() public {
        fairLaunch.initializePool();
        
        vm.prank(alice);
        fairLaunch.stake{value: 0.009 ether}(); // Below 0.01 ETH minimum
    }

    function testPauseUnpause() public {
        fairLaunch.initializePool();
        
        // Ensure no cooldown
        vm.warp(block.timestamp + 3601);
        
        fairLaunch.pause();
        assertTrue(fairLaunch.paused());
        
        // OpenZeppelin's Pausable uses a custom error now
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        vm.prank(alice);
        fairLaunch.stake{value: 0.5 ether}();
        
        fairLaunch.unpause();
        assertFalse(fairLaunch.paused());
        
        vm.prank(alice);
        fairLaunch.stake{value: 0.5 ether}();
        assertTrue(fairLaunch.hasStaked(alice));
    }

    function testRecoverTokens() public {
        fairLaunch.initializePool();
        
        // Advance time past fair launch end + 30 days
        vm.warp(block.timestamp + 5 days + 30 days + 1);
        
        uint256 initialBalance = dankToken.balanceOf(address(this));
        uint256 recoveryAmount = 1000;
        
        fairLaunch.recoverTokens(address(dankToken), recoveryAmount);
        assertEq(dankToken.balanceOf(address(this)), initialBalance + recoveryAmount);
    }

    function testStakingCooldown() public {
        fairLaunch.initializePool();
        
        // Ensure we're past any initial cooldown
        vm.warp(block.timestamp + 3601);
        uint256 initialTime = block.timestamp;
        
        vm.startPrank(alice);
        
        // First stake
        fairLaunch.stake{value: 0.3 ether}();
        
        // Try staking immediately after (should fail)
        vm.expectRevert(abi.encodeWithSelector(StakingError.selector, "Cooldown active"));
        fairLaunch.stake{value: 0.1 ether}();
        
        // Advance time but not enough (30 minutes)
        vm.warp(initialTime + 1800);
        
        // Should still fail
        vm.expectRevert(abi.encodeWithSelector(StakingError.selector, "Cooldown active"));
        fairLaunch.stake{value: 0.1 ether}();
        
        // Advance time past cooldown (1 hour + 1 second)
        vm.warp(initialTime + 3601);
        
        // This should now succeed
        fairLaunch.stake{value: 0.1 ether}();
        
        vm.stopPrank();
    }

    function testFeeCollection() public {
        fairLaunch.initializePool();
        
        vm.warp(block.timestamp + 3601);
        
        uint256 initialFeeCollectorBalance = feeCollector.balance;
        
        vm.prank(alice);
        fairLaunch.stake{value: 0.5 ether}();
        
        // Advance past end time
        vm.warp(block.timestamp + 5 days + 1);
        
        vm.prank(alice);
        fairLaunch.claimTokens();
        
        // Check fee collector received correct amount
        assertGt(feeCollector.balance, initialFeeCollectorBalance);
    }

    function testMultipleClaimsProportions() public {
        fairLaunch.initializePool();
        
        vm.warp(block.timestamp + 3601);
        
        // Alice stakes 0.3 ETH
        vm.prank(alice);
        fairLaunch.stake{value: 0.3 ether}();
        
        // Bob stakes 0.2 ETH
        vm.prank(bob);
        fairLaunch.stake{value: 0.2 ether}();
        
        // Advance past end time
        vm.warp(block.timestamp + 5 days + 1);
        
        // Get expected amounts
        (uint256 aliceTokens,,) = fairLaunch.getClaimableAmounts(alice);
        (uint256 bobTokens,,) = fairLaunch.getClaimableAmounts(bob);
        
        // Verify proportions (Alice should get 60%, Bob 40% of tokens)
        assertEq(aliceTokens * 2, bobTokens * 3);
    }

    function testFailDoubleInitialize() public {
        fairLaunch.initializePool();
        vm.expectRevert("Already initialized");
        fairLaunch.initializePool();
    }

    function testFailClaimBeforeEnd() public {
        fairLaunch.initializePool();
        
        vm.prank(alice);
        fairLaunch.stake{value: 0.3 ether}();
        
        vm.expectRevert("Fair launch not ended");
        fairLaunch.claimTokens();
    }

    function testEventEmissions() public {
        fairLaunch.initializePool();
        
        vm.warp(block.timestamp + 3601);
        
        // First, check Staked event
        vm.expectEmit(true, false, false, true, address(fairLaunch));
        emit Staked(alice, 0.3 ether, block.timestamp);
        
        vm.prank(alice);
        fairLaunch.stake{value: 0.3 ether}();
        
        // Advance past end time
        vm.warp(block.timestamp + 5 days + 1);
        
        // Calculate expected amounts
        (uint256 expectedTokenAmount, uint256 expectedEthReturn,) = fairLaunch.getClaimableAmounts(alice);
        
        // Then check Withdrawn event (note: contract emits Withdrawn, not Claimed)
        vm.expectEmit(true, false, false, true, address(fairLaunch));
        emit Withdrawn(alice, expectedEthReturn, expectedTokenAmount, block.timestamp);
        
        vm.prank(alice);
        fairLaunch.claimTokens();
    }

    // Update event definitions to match contract exactly
    event Staked(address indexed user, uint256 amount, uint256 timestamp);
    event Withdrawn(address indexed user, uint256 ethAmount, uint256 dankAmount, uint256 timestamp);
}