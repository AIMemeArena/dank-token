// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/DANKFairLaunch.sol";
import "../src/DankToken.sol";

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
}