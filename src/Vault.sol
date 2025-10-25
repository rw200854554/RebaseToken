// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    IRebaseToken private immutable i_rebaseToken;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    error Vault__RedeemFailed();
    error Vault__DepositIsZero();

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    fallback() external payable {}

    function deposit() external payable {
        uint256 amount = msg.value;
        if (amount == 0) revert Vault__DepositIsZero();

        i_rebaseToken.mint(msg.sender, amount);
        emit Deposit(msg.sender, amount);
    }

    function redeem(uint256 amount) external {
        if (amount == type(uint256).max) amount = i_rebaseToken.balanceOf(msg.sender);
        //check if the user has enough balance
        i_rebaseToken.burn(msg.sender, amount);

        //Interact with the user to redeem the amount
        (bool success,) = (payable(msg.sender)).call{value: amount}("");
        if (!success) revert Vault__RedeemFailed();

        //Emit the event

        emit Redeem(msg.sender, amount);
    }

    function getRebaseToken() external view returns (IRebaseToken) {
        return i_rebaseToken;
    }
}
