// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
contract RebaseTokenTest is Test {
    RebaseToken public rebaseToken;

    address public user = makeAddr("USER");
    address public owner = makeAddr("OWNER");
    address public user2 = makeAddr("USER2");
    Vault public vault;
    uint256 public ETH_BALANCE = 100 ether;

    function setUp() public {
        vm.deal(owner, ETH_BALANCE);
        vm.startPrank(owner);

        vault = new Vault(IRebaseToken(address(new RebaseToken())));
        rebaseToken = RebaseToken(address(vault.getRebaseToken()));

        rebaseToken.grantMintAndBurnRole(address(vault));
        (bool success,) = (payable(address(vault))).call{value: 1 ether}("");
        require(success, "Vault: Failed to deposit 1 ether");
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        vm.startPrank(owner);
        vm.deal(owner, rewardAmount);
        (bool success,) = payable(address(vault)).call{value: rewardAmount}("");
        //vm.assume(success); // Optionally, assume the transfer succeeds
        vm.stopPrank();
    }

    function test_LinearInterest(uint256 amount, uint256 time) public {
        amount = bound(amount, 1e5, type(uint96).max);
        time = time % 30 days;
        vm.deal(user, amount);
        vm.startPrank(user);
        vault.deposit{value: amount}();
        uint256 initialBalance = rebaseToken.balanceOf(user);
        assertEq(initialBalance, amount, "Initial balance is not equal to the amount");
        vm.warp(block.timestamp + time);
        vm.roll(block.number + 1);
        uint256 firstInterestBalance = rebaseToken.balanceOf(user);
        uint256 firstInterest = firstInterestBalance - initialBalance;
        vm.warp(block.timestamp + time);
        vm.roll(block.number + 1);
        uint256 secondInterestBalance = rebaseToken.balanceOf(user);
        uint256 secondInterest = secondInterestBalance - firstInterestBalance;
        assertApproxEqAbs(firstInterest, secondInterest, 1, "Interest is not linear");

        vm.stopPrank();
    }

    function test_ImmediateRedeem(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.startPrank(user);
        uint256 initialBalance = user.balance;
        assertEq(initialBalance, amount, "Initial balance is not equal to the amount");
        vault.deposit{value: amount}();
        assertEq(user.balance, initialBalance - amount, "User balance is not equal to the amount");
        assertEq(rebaseToken.balanceOf(user), amount, "Rebase token balance is not equal to the amount");
        vault.redeem(type(uint256).max);
        uint256 finalBalance = user.balance;

        assertEq(finalBalance, initialBalance, "Final balance is not equal to 0");
        vm.stopPrank();
    }

    // test the late redeem function of the protocol
    function test_LateRedeem(uint256 amount, uint256 time) public {
        time = time % 30 days;
        time = bound(time, 1 days, 30 days);
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.startPrank(user);
        uint256 initialBalance = user.balance;
        //console.log("Initial balance", initialBalance);
        assertEq(initialBalance, amount, "Initial balance is not equal to the amount");
        vault.deposit{value: amount}();
        assertEq(user.balance, initialBalance - amount, "User balance is not equal to the amount");
        assertEq(rebaseToken.balanceOf(user), amount, "Rebase token balance is not equal to the amount");
        vm.warp(block.timestamp + time);
        vm.roll(block.number + 1);
        vm.stopPrank();
        addRewardsToVault(rebaseToken.balanceOf(user));
        // console.log(address(vault).balance);

        vm.startPrank(user);
        //console.log("Rebasing token balance", rebaseToken.balanceOf(user));
        vault.redeem(type(uint256).max);
        uint256 finalBalance = user.balance;
        //console.log("Final balance", finalBalance);
        assert(finalBalance > initialBalance);
        assertEq(amount * time * rebaseToken.getInterestRate() / 1e18, user.balance - initialBalance);

        vm.stopPrank();
    }

    // test the transfer function
    // If a receiver has no balance, the interest rate should be set to the sender's interest rate
    function test_Transfer(uint256 amount) public {
        // set bounds for the amount
        amount = bound(amount, 1e5, type(uint96).max);

        // deal the amount to the user and deposit it into the vault
        vm.deal(user, amount);
        vm.startPrank(user);
        vault.deposit{value: amount}();
        vm.stopPrank();

        // decrease the interest rate to 4e10
        vm.startPrank(owner);
        rebaseToken.setInterestRate(4e10);
        vm.stopPrank();

        // user transfer the amount to the user2
        vm.startPrank(user);
        rebaseToken.transfer(user2, amount/2);
        rebaseToken.approve(user2, amount/2);
        vm.stopPrank();
        vm.startPrank(user2);
        rebaseToken.transferFrom(user, user2, amount/2);
        vm.stopPrank();

        

        // check the balances of the users and the interest rate
        assertApproxEqAbs(amount, rebaseToken.balanceOf(user2), 1);
        assertEq(rebaseToken.getUserInterestRate(user), rebaseToken.getUserInterestRate(user2));
    }

    function test_PrincipalBalanceOf(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.startPrank(user);
        vault.deposit{value: amount}();
        assertEq(amount, rebaseToken.principalBalanceOf(user));
        vm.warp(block.timestamp + 30 days);
        vm.roll(block.number + 1);
        assertEq(amount, rebaseToken.principalBalanceOf(user));
        assert(rebaseToken.balanceOf(user) > rebaseToken.principalBalanceOf(user));
        vm.stopPrank();
    }

    function test_Getters(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.startPrank(user);
        vault.deposit{value: amount}();
        
        rebaseToken.getInterestRate();
        rebaseToken.getUserInterestRate(user);
        uint256 time1 =rebaseToken.getUserLastUpdateTimestamp(user);
        vm.warp(block.timestamp + 30 days);
        vm.roll(block.number + 1);
        rebaseToken.transfer(user2, amount);
        vm.stopPrank();
        uint256 time2 = rebaseToken.getUserLastUpdateTimestamp(user);
        assert(time2 > time1);
    }

    function testCannotSetInterestRate(address setter) public {
        if (setter == owner) return;
        vm.startPrank(setter);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, setter));
        rebaseToken.setInterestRate(1e10);
        vm.stopPrank();
    }

    function testCannotMintOrBurn(address setter) public {
        if (setter == owner) return;
        vm.startPrank(setter);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, setter, rebaseToken.MINT_AND_BURN_ROLE()));
        rebaseToken.mint(setter,1e18);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, setter, rebaseToken.MINT_AND_BURN_ROLE()));
        rebaseToken.burn(setter,1e18);
        vm.stopPrank();
    }
}
