// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {IERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {CCIPLocalSimulatorFork} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {Register} from "@chainlink-local/src/ccip/Register.sol";
import {RegistryModuleOwnerCustom} from "@chainlink/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@chainlink/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {TokenPool} from "@chainlink/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "@chainlink/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
contract ConfigurePool is Script {
    function run(address localPool, uint64 remoteChainSelector,
     address remotePool, address remoteToken,
     bool outboundRateLimiter, bool inboundRateLimiter,
     uint128 outboundRate, uint128 inboundRate,
     uint128 outboundCapacity, uint128 inboundCapacity) public {
        vm.startBroadcast();
        TokenPool.ChainUpdate[] memory chainUpdates = new TokenPool.ChainUpdate[](1);
        chainUpdates[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            remotePoolAddress: abi.encode(remotePool),
            remoteTokenAddress: abi.encode(remoteToken),
            allowed: true,
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: outboundRateLimiter, capacity: outboundCapacity, rate: outboundRate}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: inboundRateLimiter, capacity: inboundCapacity, rate: inboundRate})
        });
        TokenPool(localPool).applyChainUpdates(chainUpdates);
        vm.stopBroadcast();
    }
}