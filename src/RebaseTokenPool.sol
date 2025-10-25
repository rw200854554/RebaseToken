// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IRebaseToken} from "./interfaces/IRebaseToken.sol";
import {TokenPool} from "@chainlink/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {Pool} from "@chainlink/contracts/src/v0.8/ccip/libraries/Pool.sol";

contract RebaseTokenPool is  TokenPool {
    IRebaseToken public rebaseToken;
    IERC20 public underlying;

    constructor(IERC20 _token, address[] memory _allowList,address _rnmProxy, address _router) 
    TokenPool(_token,_allowList, _rnmProxy, _router) {
        
    }

    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn) external override returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut) {
        _validateLockOrBurn(lockOrBurnIn);
        address originalSender = lockOrBurnIn.originalSender;
        uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(originalSender);
        IRebaseToken(address(i_token)).burn(address(this),lockOrBurnIn.amount);  
        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(userInterestRate)
        });
    }

    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn) external override returns (Pool.ReleaseOrMintOutV1 memory releaseOrMintOut) {
        _validateReleaseOrMint(releaseOrMintIn);
        uint256 userInterestRate = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));
        address receiver = releaseOrMintIn.receiver;
        IRebaseToken(address(i_token)).mintWithInterestRate(receiver, releaseOrMintIn.amount,userInterestRate);
        releaseOrMintOut = Pool.ReleaseOrMintOutV1({
            destinationAmount: releaseOrMintIn.amount
        });
    }

    
}