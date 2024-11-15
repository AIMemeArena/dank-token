// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/DANKFairLaunch.sol";
import "../src/DANKToken.sol";

contract DANKFairLaunchTest is Test {
    DANKFairLaunch public fairLaunch;
    DANKToken public dankToken;
    
    address public owner = address(this);
    address public feeCollector = address(0x999);
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public carol = address(0x3);

    uint256 public constant INITIAL_MINT = 420_690_000_000 * 1e18;
    uint256 public constant FAIR_LAUNCH_AMOUNT = 105_172_500_000 * 1e18; // 25% of supply
    
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 ethAmount, uint256 dankAmount);

    function setUp() public {
        // Deploy contracts
        dankToken = new DANKToken();
        fairLaunch = new DANKFairLaunch(address(dankToken), feeCollector);

        // Setup initial states
        dankToken.mint(address(fairLaunch), FAIR_LAUNCH_AMOUNT);
        
        // Fund test users
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
        vm.deal(carol, 1 ether);
    }

    function testInitializePool() public {
        fairLaunch.initializePool();
        assertTrue(fairLaunch.initialized());
        assertEq(fairLaunch.endTime(), block.timestamp + 5 days);
    }

    function testCannotInitializeTwice() public {
        fairLaunch.initializePool();
        vm.expectRevert("Already initialized");
        fairLaunch.initializePool();
    }

    function testStaking() public {
        fairLaunch.initializePool();
        
        vm.startPrank(alice);
        uint256 stakeAmount = 0.5 ether;
        
        vm.expectEmit(true, false, false, true);
        emit Staked(alice, stakeAmount);
        
        fairLaunch.stake{value: stakeAmount}();
        
        assertEq(fairLaunch.userStakes(alice), stakeAmount);
        assertTrue(fairLaunch.hasStaked(alice));
        vm.stopPrank();
    }

    function testStakingLimits() public {
        fairLaunch.initializePool();
        
        vm.startPrank(alice);
        vm.expectRevert("Exceeds max stake");
        fairLaunch.stake{value: 0.6 ether}();
        vm.stopPrank();
    }

    function testMultipleStakers() public {
        fairLaunch.initializePool();
        
        // Alice stakes
        vm.prank(alice);
        fairLaunch.stake{value: 0.3 ether}();
        
        // Bob stakes
        vm.prank(bob);
        fairLaunch.stake{value: 0.4 ether}();
        
        assertEq(fairLaunch.totalETHStaked(), 0.7 ether);
    }

    function testWithdrawal() public {
        fairLaunch.initializePool();
        
        // Stake
        vm.startPrank(alice);
        fairLaunch.stake{value: 0.5 ether}();
        vm.stopPrank();
        
        // Advance time
        vm.warp(block.timestamp + 5 days + 1);
        
        // Calculate expected rewards
        uint256 expectedRewards = fairLaunch.calculateRewards(alice);
        
        // Track balances before withdrawal
        uint256 ethBefore = alice.balance;
        uint256 dankBefore = dankToken.balanceOf(alice);
        
        vm.prank(alice);
        fairLaunch.withdraw();
        
        // Verify balances after withdrawal
        assertEq(alice.balance, ethBefore + 0.5 ether);
        assertEq(dankToken.balanceOf(alice), dankBefore + expectedRewards);
    }

    function testCannotWithdrawEarly() public {
        fairLaunch.initializePool();
        
        vm.prank(alice);
        fairLaunch.stake{value: 0.5 ether}();
        
        vm.expectRevert("Pool not ended");
        vm.prank(alice);
        fairLaunch.withdraw();
    }

    function testEmergencyWithdraw() public {
        fairLaunch.initializePool();
        
        vm.startPrank(alice);
        fairLaunch.stake{value: 0.5 ether}();
        
        uint256 balanceBefore = alice.balance;
        fairLaunch.emergencyWithdraw();
        
        assertEq(alice.balance, balanceBefore + 0.5 ether);
        assertEq(fairLaunch.userStakes(alice), 0);
        assertFalse(fairLaunch.hasStaked(alice));
        vm.stopPrank();
    }

    function testPauseUnpause() public {
        fairLaunch.initializePool();
        fairLaunch.pause();
        
        vm.expectRevert("Pausable: paused");
        vm.prank(alice);
        fairLaunch.stake{value: 0.5 ether}();
        
        fairLaunch.unpause();
        
        vm.prank(alice);
        fairLaunch.stake{value: 0.5 ether}();
        assertTrue(fairLaunch.hasStaked(alice));
    }

    // Fuzz testing
    function testFuzz_StakingAmount(uint256 amount) public {
        // Bound amount between 0 and max stake
        amount = bound(amount, 0, 0.5 ether);
        
        fairLaunch.initializePool();
        vm.deal(alice, amount);
        
        vm.prank(alice);
        if (amount > 0) {
            fairLaunch.stake{value: amount}();
            assertEq(fairLaunch.userStakes(alice), amount);
        } else {
            vm.expectRevert("Zero stake");
            fairLaunch.stake{value: amount}();
        }
    }

    // Invariant tests
    function invariant_totalStakedNeverExceedsBalance() public {
        assertLe(address(fairLaunch).balance, fairLaunch.totalETHStaked());
    }
} 