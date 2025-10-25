// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRebaseToken {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function getUserInterestRate(address account) external view returns (uint256);
    function mintWithInterestRate(address to, uint256 amount, uint256 interestRate) external;
    function principalBalanceOf(address account) external view returns (uint256);
    function getUserLastUpdateTimestamp(address account) external view returns (uint256);
    function getInterestRate() external view returns (uint256);
    function grantMintAndBurnRole(address account) external;
}
