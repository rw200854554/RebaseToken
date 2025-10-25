// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 interestRate);

    event InterestRateSet(uint256 interestRate);

    bytes32 public constant  MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");

    uint256 public constant PRECISION_FACTOR = 10 ** 18;
    uint256 private s_interestRate = 5e10;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdateTimestamp;

    constructor() ERC20("RebaseToken", "RBT") Ownable(msg.sender) {}

    function balanceOf(address account) public view override returns (uint256) {
        uint256 principalBalance = super.balanceOf(account);
        uint256 growthFactor = _calculateAccumulatedInterestSinceLastUpdate(account);
        return principalBalance * growthFactor / PRECISION_FACTOR;
    }

    function burn(address from, uint256 amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if (amount == type(uint256).max) amount = balanceOf(from);
        _update(from, address(0), amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        // Handle minting case
        if (from == address(0)) {
            _mintAccruedInterest(to);
        }
        // Handle burning case
        else if (to == address(0)) {
            if (value == type(uint256).max) value = balanceOf(from);
            _mintAccruedInterest(from);
        }
        // Handle transfer case
        else {
            _mintAccruedInterest(from);
            _mintAccruedInterest(to);
        }

        // Call the parent _update function
        super._update(from, to, value);
    }

    function _calculateAccumulatedInterestSinceLastUpdate(address account) internal view returns (uint256) {
        uint256 timeDelta = block.timestamp - s_userLastUpdateTimestamp[account];
        if (timeDelta == 0) {
            return PRECISION_FACTOR;
        }
        uint256 interestRate = s_userInterestRate[account];
        if (interestRate == 0) {
            return PRECISION_FACTOR;
        }

        return PRECISION_FACTOR + (interestRate * timeDelta);
    }

    function grantMintAndBurnRole(address account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, account);
    }

    function mintWithInterestRate(address to, uint256 amount, uint256 interestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        if (balanceOf(to) == 0) s_userInterestRate[to] = interestRate;
        _update(address(0), to, amount);
    }


    function mint(address to, uint256 amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if (balanceOf(to) == 0) s_userInterestRate[to] = s_interestRate;
        _update(address(0), to, amount);
    }

    function _mintAccruedInterest(address to) internal {
        uint256 accruedInterest = balanceOf(to) - super.balanceOf(to);
        s_userLastUpdateTimestamp[to] = block.timestamp;
        if (accruedInterest > 0) {
            _update(address(0), to, accruedInterest);
        }
    }

    function principalBalanceOf(address account) public view returns (uint256) {
        return super.balanceOf(account);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        if (amount == type(uint256).max) amount = balanceOf(msg.sender);
        if (balanceOf(to) == 0 && amount > 0) s_userInterestRate[to] = s_userInterestRate[msg.sender];
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (amount == type(uint256).max) amount = balanceOf(from);
        if (balanceOf(to) == 0 && amount > 0) s_userInterestRate[to] = s_userInterestRate[msg.sender];
        return super.transferFrom(from, to, amount);
    }

    // Setter functions ///////////////////////////////

    function setInterestRate(uint256 newInterestRate) external onlyOwner {
        if (newInterestRate > s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(newInterestRate);
        }
        s_interestRate = newInterestRate;
        emit InterestRateSet(newInterestRate);
    }

    // Getter functions ///////////////////////////////
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    function getUserInterestRate(address user) external view returns (uint256) {
        return s_userInterestRate[user];
    }

    function getUserLastUpdateTimestamp(address user) external view returns (uint256) {
        return s_userLastUpdateTimestamp[user];
    }
}
